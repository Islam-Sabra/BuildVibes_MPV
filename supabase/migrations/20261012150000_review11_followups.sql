-- Migration 10: review 11 part A follow-ups, built on migration 9.
--
-- 1. Needs you starts from the caller's own memberships, and My Spaces
--    runs it once instead of once per Space.
-- 2. The upload cap and the daily total look only in the folders of the
--    Spaces the caller has been in (the name index), never the whole
--    bucket. An index on storage.objects (owner_id) isn't possible: the
--    table belongs to supabase_storage_admin.
-- 4. Cleanup safety. SQL can't delete storage files (the Storage API
--    must), so the "not referenced" check can't sit inside the delete.
--    Instead the cleanup claims each file, re-checking under a per-file
--    lock, and nothing can reference a claimed file afterwards.
-- 5. Shown work hides the checker's name when either side blocked the
--    other, as profiles do. The item still shows as Checked.

-- ---------------------------------------------------------------------------
-- 1. Needs you
-- ---------------------------------------------------------------------------

create or replace function public.needs_you()
returns table (
  kind text,
  space_id uuid,
  work_item_id uuid,
  request_id uuid,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  -- Only Spaces I'm in, so nothing scans other Spaces' items.
  with mine as (
    select m.space_id, m.is_admin
    from public.space_members m
    join public.spaces s on s.id = m.space_id and s.deleted_at is null
    where m.profile_id = auth.uid() and m.left_at is null
  )
  -- Open items I own and can still sign (a pass changed to Viewer can't).
  select 'open_owned', w.space_id, w.id, null::uuid, w.created_at
  from mine
  join public.work_items w on w.space_id = mine.space_id
  where w.status = 'open' and w.owner_id = auth.uid()
    and public.member_can(w.space_id, auth.uid(), 'mark_done')
  union all
  select 'to_check', w.space_id, w.id, null::uuid, w.done_at
  from mine
  join public.work_items w on w.space_id = mine.space_id and w.status = 'done'
  where public.may_check(w, auth.uid())
  union all
  select 'join_request', r.space_id, null::uuid, r.id, r.created_at
  from mine
  join public.space_join_requests r
    on r.space_id = mine.space_id and r.status = 'pending'
  where mine.is_admin
  union all
  -- "Owner left · reassign": the owner can no longer sign it. Its creator,
  -- while still a member; otherwise everyone who may check.
  select 'owner_left', w.space_id, w.id, null::uuid, w.created_at
  from mine
  join public.work_items w on w.space_id = mine.space_id and w.status = 'open'
  where not public.member_can(w.space_id, w.owner_id, 'mark_done')
    and (w.created_by = auth.uid()
         or (not public.is_active_member(w.space_id, w.created_by)
             and public.member_can(w.space_id, auth.uid(), 'check_items')));
$$;

create or replace function public.my_spaces()
returns table (
  space_id uuid,
  name text,
  kind text,
  access text,
  project_id uuid,
  project_name text,
  project_type_id text,
  pass text,
  is_admin boolean,
  pending_requests integer,
  joined_at timestamptz,
  needs_you integer
)
language sql
stable
security definer
set search_path = ''
as $$
  -- needs_you() once for all Spaces, then counted per Space.
  with needs as (
    select n.space_id, count(*)::int as n
    from public.needs_you() n
    group by n.space_id
  )
  select s.id, s.name, s.kind, s.access, s.project_id, p.name, p.type_id,
         m.pass, m.is_admin,
         case when m.is_admin then (
           select count(*)::int from public.space_join_requests r
           where r.space_id = s.id and r.status = 'pending') else 0 end,
         m.confirmed_at,
         coalesce(needs.n, 0)
  from public.space_members m
  join public.spaces s on s.id = m.space_id
  left join public.projects p on p.id = s.project_id
  left join needs on needs.space_id = s.id
  where m.profile_id = auth.uid() and m.left_at is null and s.deleted_at is null
  order by m.confirmed_at desc;
$$;

-- ---------------------------------------------------------------------------
-- 2. Upload totals: only the caller's Space folders
-- ---------------------------------------------------------------------------

-- The caller's files in space-files. Every upload path starts with a Space
-- the uploader was a member of (may_upload), so it looks in those folders
-- only, through the (bucket_id, name) index: '<space>/' up to '<space>0'
-- ('0' is the character after '/').
create or replace function public.my_space_files()
returns table (name text, bytes bigint, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select o.name, (o.metadata ->> 'size')::bigint, o.created_at
  from (select distinct m.space_id
        from public.space_members m
        where m.profile_id = auth.uid()) sp
  join storage.objects o
    on o.bucket_id = 'space-files'
   and o.name collate "C" >= sp.space_id::text || '/'
   and o.name collate "C" < sp.space_id::text || '0'
  where o.owner_id = auth.uid()::text;
$$;

create or replace function public.loose_uploads()
returns table (files bigint, bytes bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select count(*), coalesce(sum(f.bytes), 0)
  from public.my_space_files() f
  where not public.is_referenced_file(f.name);
$$;

create or replace function public.uploads_today()
returns table (files bigint, bytes bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select count(*), coalesce(sum(f.bytes), 0)
  from public.my_space_files() f
  where f.created_at > now() - interval '1 day';
$$;

-- ---------------------------------------------------------------------------
-- 4. Cleanup claims
-- ---------------------------------------------------------------------------

-- Files the cleanup job is about to delete. Service role only.
create table public.file_cleanup_claims (
  storage_path text primary key,
  claimed_at timestamptz not null default now()
);
alter table public.file_cleanup_claims enable row level security;
revoke all on public.file_cleanup_claims from anon, authenticated;
grant all on public.file_cleanup_claims to service_role;

-- One lock per file path, shared by claiming and referencing.
create or replace function public.lock_file_path(p_path text)
returns void
language sql
volatile
set search_path = ''
as $$
  select pg_advisory_xact_lock(hashtextextended('space-file:' || p_path, 0));
$$;

-- The cleanup job calls this, then deletes the returned files with the
-- Storage API. Each file is re-checked under its lock, so a file that was
-- referenced after the list was made is skipped.
create or replace function public.claim_orphan_files(
  p_age interval default interval '7 days',
  p_limit integer default 200
)
returns table (name text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  for v_name in
    select o.name from public.orphan_space_files(p_age) o
    order by o.created_at
    limit greatest(p_limit, 0)
  loop
    perform public.lock_file_path(v_name);
    if not public.is_referenced_file(v_name) then
      insert into public.file_cleanup_claims (storage_path)
      values (v_name)
      on conflict (storage_path) do nothing;
      name := v_name;
      return next;
    end if;
  end loop;
end;
$$;

-- After the deletes: drop claims whose file is gone. A claim whose delete
-- failed stays, so that file still can't be referenced; the next run
-- claims and deletes it again.
create or replace function public.forget_cleanup_claims()
returns integer
language sql
volatile
security definer
set search_path = ''
as $$
  with gone as (
    delete from public.file_cleanup_claims c
    where not exists (select 1 from storage.objects o
                      where o.bucket_id = 'space-files' and o.name = c.storage_path)
    returning 1
  )
  select count(*)::int from gone;
$$;

-- Nothing may reference a claimed file: evidence, chat attachments and
-- Library files all pass through here, under the same lock.
create or replace function public.refuse_claimed_file()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.lock_file_path(new.storage_path);
  if exists (select 1 from public.file_cleanup_claims c
             where c.storage_path = new.storage_path) then
    raise exception 'this file was cleaned up; upload it again'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger work_item_evidence_not_claimed
  before insert or update of storage_path on public.work_item_evidence
  for each row execute function public.refuse_claimed_file();
create trigger message_attachments_not_claimed
  before insert or update of storage_path on public.message_attachments
  for each row execute function public.refuse_claimed_file();
create trigger library_files_not_claimed
  before insert or update of storage_path on public.library_files
  for each row execute function public.refuse_claimed_file();

-- ---------------------------------------------------------------------------
-- 5. Shown work across a block: Checked, without the checker's name
-- ---------------------------------------------------------------------------

create or replace view public.public_shown_work as
  select w.id as work_item_id,
         w.owner_id as profile_id,
         w.title,
         w.place_text,
         public.shown_work_photo(w.id) as photo_path,
         case when public.is_blocked_with(w.checked_by) then null
              else nullif(trim(coalesce(c.first_name, '') || ' ' || coalesce(c.last_name, '')), '')
         end as checked_by_name,
         w.checked_at,
         p.name as project_name
  from public.work_items w
  join public.spaces s on s.id = w.space_id and s.deleted_at is null
  left join public.projects p on p.id = s.project_id
  left join public.profiles c on c.id = w.checked_by
  where w.shown and w.status = 'checked'
    and w.owner_id is not null
    and not public.is_blocked_with(w.owner_id);

create or replace function public.my_delivered_work()
returns table (
  work_item_id uuid,
  title text,
  place_text text,
  project_name text,
  checked_by_name text,
  checked_at timestamptz,
  shown boolean,
  photo_path text
)
language sql
stable
security definer
set search_path = ''
as $$
  select w.id, w.title, w.place_text, p.name,
         case when public.is_blocked_with(w.checked_by) then null
              else nullif(trim(coalesce(c.first_name, '') || ' ' || coalesce(c.last_name, '')), '')
         end,
         w.checked_at, w.shown,
         (select e.storage_path
          from public.work_item_evidence e
          join public.work_item_events ev on ev.id = e.event_id
          where e.work_item_id = w.id and ev.kind = 'done' and ev.actor_id = w.owner_id
          order by ev.created_at desc, e.created_at
          limit 1)
  from public.work_items w
  join public.spaces s on s.id = w.space_id and s.deleted_at is null
  left join public.projects p on p.id = s.project_id
  left join public.profiles c on c.id = w.checked_by
  where w.owner_id = auth.uid() and w.status = 'checked'
  order by w.checked_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.my_space_files(),
  public.lock_file_path(text),
  public.claim_orphan_files(interval, integer),
  public.forget_cleanup_claims(),
  public.refuse_claimed_file()
  from public, anon, authenticated;

grant execute on function
  public.claim_orphan_files(interval, integer),
  public.forget_cleanup_claims()
  to service_role;
