-- Migration 8: work items follow-ups (review 10 part A) and "Work you
-- delivered" (RE2). Draft on branch work-items-followups; the lead reviews
-- the SQL before it goes live.
--
-- 1, 2. Stuck items: an Open item whose owner can no longer sign it (left,
--       removed, or changed to Viewer) goes to its creator, or, when the
--       creator is gone too, to every member who may check.
-- 3.    Photos uploaded before their item exists are readable only by
--       their uploader, and create_work_item refuses an id whose folder
--       holds someone else's files.
-- 4.    Reassigning records the previous and the new owner.
-- 5.    Each person may keep at most about 200 MB (and 400 files) of photos
--       that are not evidence yet. Cleanup of old orphans needs the
--       Storage API; see docs/progress.md.
-- 6.    The append-only rule lets through only the service role and the
--       changes a foreign key makes when a work item, a Space or an
--       account is deleted.
-- Plus: my_delivered_work() for RE2, which works after you left a Space.

-- ---------------------------------------------------------------------------
-- 4. Reassign history
-- ---------------------------------------------------------------------------

alter table public.work_item_events
  add column from_owner_id uuid references public.profiles (id) on delete set null,
  add column to_owner_id uuid references public.profiles (id) on delete set null;

create or replace function public.reassign_work_item(p_item uuid, p_owner uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_item public.work_items;
begin
  select * into v_item from public.work_items where id = p_item for update;
  if v_item.id is null
     or not (
       (v_item.created_by = v_me and public.is_member(v_item.space_id))
       or public.member_can(v_item.space_id, v_me, 'check_items')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.status <> 'open' then
    raise exception 'only an open item can be reassigned' using errcode = 'P0001';
  end if;
  if p_owner is null or not public.member_can(v_item.space_id, p_owner, 'mark_done') then
    raise exception 'choose an owner who can sign it as done' using errcode = '22023';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, from_owner_id, to_owner_id)
  values (p_item, v_me, 'reassigned', v_item.owner_id, p_owner);
  update public.work_items set owner_id = p_owner where id = p_item;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. The record stays append-only, with narrow exceptions
-- ---------------------------------------------------------------------------

-- Allowed: the service role (support work); deleting events whose work
-- item is already gone (a cascade from deleting the item or its Space);
-- and clearing a person from the record when their account is deleted.
-- Anything else, including a future trigger, is refused.
create or replace function public.keep_work_item_events()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_people constant text[] := array['actor_id', 'from_owner_id', 'to_owner_id'];
  v_col text;
begin
  if current_user = 'service_role' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE' then
    if not exists (select 1 from public.work_items w where w.id = old.work_item_id) then
      return old;
    end if;
  elsif (to_jsonb(new) - v_people) = (to_jsonb(old) - v_people) then
    -- Only people columns changed: each must be cleared, for an account
    -- that no longer exists.
    foreach v_col in array v_people loop
      if (to_jsonb(new) ->> v_col) is distinct from (to_jsonb(old) ->> v_col) then
        if (to_jsonb(new) ->> v_col) is not null
           or exists (select 1 from public.profiles p
                      where p.id = (to_jsonb(old) ->> v_col)::uuid) then
          raise exception 'work item events are kept for the record' using errcode = '42501';
        end if;
      end if;
    end loop;
    return new;
  end if;
  raise exception 'work item events are kept for the record' using errcode = '42501';
end;
$$;

-- ---------------------------------------------------------------------------
-- 1, 2. Needs you: stuck items reach someone
-- ---------------------------------------------------------------------------

-- True when [p_profile] is an active member of [p_space].
create or replace function public.is_active_member(p_space uuid, p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.space_members m
                 where m.space_id = p_space and m.profile_id = p_profile
                   and m.left_at is null);
$$;

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
  -- Open items I own and can still sign (a pass changed to Viewer can't).
  select 'open_owned', w.space_id, w.id, null::uuid, w.created_at
  from public.work_items w
  join public.spaces s on s.id = w.space_id and s.deleted_at is null
  where w.status = 'open' and w.owner_id = auth.uid()
    and public.member_can(w.space_id, auth.uid(), 'mark_done')
  union all
  select 'to_check', w.space_id, w.id, null::uuid, w.done_at
  from public.work_items w
  join public.spaces s on s.id = w.space_id and s.deleted_at is null
  where w.status = 'done' and public.may_check(w, auth.uid())
  union all
  select 'join_request', r.space_id, null::uuid, r.id, r.created_at
  from public.space_join_requests r
  join public.spaces s on s.id = r.space_id and s.deleted_at is null
  where r.status = 'pending' and public.is_space_admin(r.space_id)
  union all
  -- "Owner left · reassign": the owner can no longer sign it (left,
  -- removed, account deleted or changed to Viewer). Its creator, while
  -- still a member; otherwise everyone who may check.
  select 'owner_left', w.space_id, w.id, null::uuid, w.created_at
  from public.work_items w
  join public.spaces s on s.id = w.space_id and s.deleted_at is null
  where w.status = 'open'
    and not public.member_can(w.space_id, w.owner_id, 'mark_done')
    and public.is_member(w.space_id)
    and (w.created_by = auth.uid()
         or (not public.is_active_member(w.space_id, w.created_by)
             and public.member_can(w.space_id, auth.uid(), 'check_items')));
$$;

-- ---------------------------------------------------------------------------
-- 3, 5. Photos: no peeking before the item exists; a cap on loose files
-- ---------------------------------------------------------------------------

-- Files of [p_space]/[p_item]/ uploaded by someone other than the caller.
create or replace function public.folder_has_others_files(p_space uuid, p_item uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from storage.objects o
    where o.bucket_id = 'space-files'
      and o.name like p_space::text || '/' || p_item::text || '/%'
      and o.owner_id is distinct from auth.uid()::text);
$$;

-- Your uploads that are not evidence on any work item.
create or replace function public.loose_uploads()
returns table (files bigint, bytes bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select count(*), coalesce(sum((o.metadata ->> 'size')::bigint), 0)
  from storage.objects o
  where o.bucket_id = 'space-files' and o.owner_id = auth.uid()::text
    and not exists (select 1 from public.work_item_evidence e
                    where e.storage_path = o.name);
$$;

-- Who may read [p_name]: your own uploads; members, once the item exists
-- in that Space; anyone signed in, for a shown photo.
create or replace function public.may_read_file(p_name text, p_owner text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_parts text[] := string_to_array(p_name, '/');
  v_space uuid;
  v_item uuid;
begin
  if p_owner = auth.uid()::text then
    return true;
  end if;
  if public.is_shown_photo(p_name) then
    return true;
  end if;
  begin
    v_space := v_parts[1]::uuid;
    v_item := v_parts[2]::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return public.is_member(v_space)
    and exists (select 1 from public.work_items w
                where w.id = v_item and w.space_id = v_space);
end;
$$;

-- Uploads (review 09) plus: nothing for an id someone else already
-- started, and no more than 200 MB or 400 loose files per person.
create or replace function public.may_upload(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_parts text[] := string_to_array(p_name, '/');
  v_space uuid;
  v_item_id uuid;
  v_item public.work_items;
  v_files bigint;
  v_bytes bigint;
begin
  if array_length(v_parts, 1) <> 3 or v_parts[3] = '' or p_name like '%..%' then
    return false;
  end if;
  begin
    v_space := v_parts[1]::uuid;
    v_item_id := v_parts[2]::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  select files, bytes into v_files, v_bytes from public.loose_uploads();
  if v_files >= 400 or v_bytes >= 200 * 1024 * 1024 then
    return false;
  end if;
  select * into v_item from public.work_items where id = v_item_id;
  if v_item.id is null then
    return public.can(v_space, 'create_items')
      and not public.folder_has_others_files(v_space, v_item_id);
  end if;
  return v_item.space_id = v_space
    and public.is_member(v_space)
    and auth.uid() in (v_item.created_by, v_item.owner_id)
    and public.member_pass(v_space) <> 'viewer';
end;
$$;

drop policy space_files_read on storage.objects;
create policy space_files_read on storage.objects
  for select to authenticated
  using (bucket_id = 'space-files' and public.may_read_file(name, owner_id));

-- 3. Refuse an id whose folder holds someone else's files. Same body as
-- migration 7 otherwise.
create or replace function public.create_work_item(
  p_space uuid,
  p_title text,
  p_owner uuid,
  p_due date default null,
  p_team uuid default null,
  p_place text default null,
  p_evidence jsonb default '[]'::jsonb,
  p_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid := coalesce(p_id, gen_random_uuid());
  v_item public.work_items;
  v_number integer;
  v_prefix text;
  v_event uuid;
begin
  select * into v_item from public.work_items where id = v_id;
  if v_item.id is not null then
    if v_item.created_by = v_me and v_item.space_id = p_space then
      return v_item.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if not public.can(p_space, 'create_items') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if public.folder_has_others_files(p_space, v_id) then
    raise exception 'this id is taken' using errcode = '42501';
  end if;
  if p_owner is null or not public.member_can(p_space, p_owner, 'mark_done') then
    raise exception 'choose an owner who can sign it as done' using errcode = '22023';
  end if;
  if p_team is not null and not exists (
       select 1 from public.teams t where t.id = p_team and t.space_id = p_space) then
    raise exception 'team not in this Space' using errcode = '22023';
  end if;

  update public.spaces s
  set next_item_number = s.next_item_number + 1
  where s.id = p_space
  returning s.next_item_number - 1, s.ref_prefix into v_number, v_prefix;

  insert into public.work_items (id, space_id, number, ref, title, owner_id, created_by,
                                 team_id, place_text, due_date)
  values (v_id, p_space, v_number, v_prefix || '-' || lpad(v_number::text, 3, '0'),
          trim(p_title), p_owner, v_me, p_team, nullif(trim(p_place), ''), p_due)
  returning * into v_item;

  insert into public.work_item_events (work_item_id, actor_id, kind)
  values (v_id, v_me, 'raised')
  returning id into v_event;
  perform public.add_evidence(v_item, v_event, p_evidence);
  return v_id;
end;
$$;

-- 5. Loose files older than [p_age], for a cleanup job run with the
-- service role through the Storage API (SQL can't delete storage files).
create or replace function public.orphan_space_files(p_age interval default interval '7 days')
returns table (name text, owner_id text, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select o.name, o.owner_id, o.created_at
  from storage.objects o
  where o.bucket_id = 'space-files'
    and o.created_at < now() - p_age
    and not exists (select 1 from public.work_item_evidence e where e.storage_path = o.name);
$$;

-- ---------------------------------------------------------------------------
-- RE2 · Work you delivered
-- ---------------------------------------------------------------------------

-- Your Checked items, shown or hidden, even from a Space you left: title,
-- place, project, who checked it and when, and your Done photo.
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
         nullif(trim(coalesce(c.first_name, '') || ' ' || coalesce(c.last_name, '')), ''),
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
  public.reassign_work_item(uuid, uuid),
  public.keep_work_item_events(),
  public.is_active_member(uuid, uuid),
  public.needs_you(),
  public.folder_has_others_files(uuid, uuid),
  public.loose_uploads(),
  public.may_read_file(text, text),
  public.may_upload(text),
  public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid),
  public.orphan_space_files(interval),
  public.my_delivered_work()
  from public, anon, authenticated;

grant execute on function
  public.reassign_work_item(uuid, uuid),
  public.needs_you(),
  public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid),
  public.my_delivered_work(),
  -- Only your own files.
  public.loose_uploads(),
  -- Policies call these as the signed-in user.
  public.may_read_file(text, text),
  public.may_upload(text)
  to authenticated;

grant execute on function public.orphan_space_files(interval) to service_role;
