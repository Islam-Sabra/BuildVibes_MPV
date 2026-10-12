-- Migration 7: work items (week 5). Draft on branch work-items-db; the lead
-- reviews the SQL before it goes live.
-- Spec: docs/reviews/2026-10-12-08-work-items.md (rules 1-12) and
-- docs/product/data-model.md §7. Design: docs/design/work/ (S20, W2-W5) and
-- docs/design/profile/ (RE1, RE2).
--
-- Steps: Open -> Done (the owner signs) -> Checked (closed), or sent back
-- to Open with a reason. Status changes only through the functions below;
-- the app can read the tables (members only) but never writes to them.
-- work_item_events is append-only.
--
-- Review 09 (12 Oct): photos must exist, be the caller's own and never be
-- replaced; uploads only by an item's creator or owner; reassigning;
-- the public photo is the owner's Done photo; blocks and deleted Spaces
-- hide shown work.

-- ---------------------------------------------------------------------------
-- References: KCT-001 (rule 7)
-- ---------------------------------------------------------------------------

alter table public.spaces
  add column ref_prefix text check (ref_prefix ~ '^[A-Z]{2,4}$'),
  add column next_item_number integer not null default 1
    check (next_item_number >= 1);

-- Latin initials of [p_name], 2 to 4 capitals: "Kuwait City Tower" -> KCT,
-- "Tower" -> TO. Null when the name has fewer than two Latin letters.
create or replace function public.latin_initials(p_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_words text[];
  v_out text := '';
  v_word text;
begin
  v_words := regexp_split_to_array(
    upper(regexp_replace(coalesce(p_name, ''), '[^A-Za-z]+', ' ', 'g')), ' ');
  foreach v_word in array v_words loop
    if v_word <> '' and length(v_out) < 4 then
      v_out := v_out || left(v_word, 1);
    end if;
  end loop;
  if length(v_out) = 1 then
    -- One word: its first two letters.
    v_out := left(array_to_string(array_remove(v_words, ''), ''), 2);
  end if;
  return case when length(v_out) between 2 and 4 then v_out end;
end;
$$;

-- The project's initials, else the Space's, else BV.
create or replace function public.space_ref_prefix(p_name text, p_project uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    public.latin_initials((select p.name from public.projects p where p.id = p_project)),
    public.latin_initials(p_name),
    'BV');
$$;

create or replace function public.set_space_ref_prefix()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.ref_prefix is null then
    new.ref_prefix := public.space_ref_prefix(new.name, new.project_id);
  end if;
  return new;
end;
$$;

create trigger spaces_ref_prefix before insert on public.spaces
  for each row execute function public.set_space_ref_prefix();

-- Spaces made before this migration.
update public.spaces s
set ref_prefix = public.space_ref_prefix(s.name, s.project_id)
where s.ref_prefix is null;

alter table public.spaces alter column ref_prefix set not null;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.work_items (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  number integer not null check (number >= 1),
  ref text not null check (ref ~ '^[A-Z]{2,4}-[0-9]{3,}$'),
  title text not null check (length(trim(title)) between 2 and 140),
  owner_id uuid references public.profiles (id) on delete set null,
  created_by uuid references public.profiles (id) on delete set null,
  team_id uuid references public.teams (id) on delete set null,
  place_text text check (length(place_text) <= 80),
  due_date date,
  status text not null default 'open' check (status in ('open', 'done', 'checked')),
  done_at timestamptz,
  checked_by uuid references public.profiles (id) on delete set null,
  checked_at timestamptz,
  -- The owner shows it on the profile (RE2). Off by default (rule 10).
  shown boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (space_id, number),
  check (shown = false or status = 'checked')
);
create index work_items_space_idx on public.work_items (space_id, status);
create index work_items_owner_idx on public.work_items (owner_id, status);

create trigger work_items_updated_at before update on public.work_items
  for each row execute function public.set_updated_at();

create table public.work_item_events (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null references public.work_items (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  kind text not null
    check (kind in ('raised', 'done', 'checked', 'sent_back', 'comment', 'reassigned')),
  note text check (length(note) <= 1000),
  reason text
    check (reason is null or reason in ('photo_missing', 'not_as_drawing', 'not_finished', 'other')),
  created_at timestamptz not null default now(),
  check ((kind = 'sent_back') = (reason is not null))
);
create index work_item_events_item_idx on public.work_item_events (work_item_id, created_at);

-- Photos on the raised and done events. Files live in the private bucket
-- space-files at <space_id>/<item_id>/<file>.
create table public.work_item_evidence (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.work_item_events (id) on delete cascade,
  work_item_id uuid not null references public.work_items (id) on delete cascade,
  storage_path text not null unique,
  kind text not null default 'photo' check (kind in ('photo')),
  taken_at timestamptz,
  place_text text check (length(place_text) <= 80),
  created_at timestamptz not null default now()
);
create index work_item_evidence_item_idx on public.work_item_evidence (work_item_id);

-- Events are the record: nobody updates or deletes them (rule 1). Two
-- exceptions: changes made by a foreign key (an account or a Space is
-- hard-deleted, so the actor is cleared or the rows go with it), and the
-- service role for support work. The app never gets either.
create or replace function public.keep_work_item_events()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if pg_trigger_depth() > 1 or current_user = 'service_role' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception 'work item events are kept for the record' using errcode = '42501';
end;
$$;

create trigger work_item_events_append_only
  before update or delete on public.work_item_events
  for each row execute function public.keep_work_item_events();

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Who may check or send back [p_item]: its creator, or a member with the
-- check_items right (admins have it). Never its owner (rule 5).
create or replace function public.may_check(p_item public.work_items, p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_profile is not null
    and p_item.owner_id is distinct from p_profile
    and exists (select 1 from public.space_members m
                where m.space_id = p_item.space_id and m.profile_id = p_profile
                  and m.left_at is null)
    and (p_item.created_by = p_profile
         or public.member_can(p_item.space_id, p_profile, 'check_items'));
$$;

-- Adds photos to an event. [p_evidence] is a JSON array of
-- {"path", "taken_at", "place"}; every path must sit in the item's folder.
create or replace function public.add_evidence(
  p_item public.work_items,
  p_event uuid,
  p_evidence jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_photo jsonb;
  v_path text;
  v_count integer := 0;
begin
  if p_evidence is null or jsonb_typeof(p_evidence) <> 'array' then
    return 0;
  end if;
  if jsonb_array_length(p_evidence) > 6 then
    raise exception 'at most 6 photos' using errcode = '22023';
  end if;
  for v_photo in select * from jsonb_array_elements(p_evidence) loop
    v_path := v_photo ->> 'path';
    if v_path is null
       or v_path not like p_item.space_id::text || '/' || p_item.id::text || '/%'
       or v_path like '%..%' then
      raise exception 'photo not in this item''s folder' using errcode = '22023';
    end if;
    -- The file must exist and be the caller's own upload (review 09).
    if not exists (select 1 from storage.objects o
                   where o.bucket_id = 'space-files' and o.name = v_path
                     and o.owner_id = auth.uid()::text) then
      raise exception 'photo not uploaded' using errcode = '22023';
    end if;
    insert into public.work_item_evidence (event_id, work_item_id, storage_path, taken_at, place_text)
    values (p_event, p_item.id, v_path,
            nullif(v_photo ->> 'taken_at', '')::timestamptz,
            nullif(trim(v_photo ->> 'place'), ''));
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Functions: the only way to change a work item
-- ---------------------------------------------------------------------------

-- W2. [p_id] is chosen by the app, so photos can be uploaded to the item's
-- folder first and a retry after a lost connection doesn't make a second
-- item: the same id returns the item already made.
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
  -- One owner, an active member whose pass lets them mark their own items
  -- done. A Viewer can't own an item (rule 3).
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

-- W4. The owner, while Open, with a photo or a note (rule 4).
create or replace function public.sign_done(
  p_item uuid,
  p_note text default null,
  p_evidence jsonb default '[]'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_item public.work_items;
  v_event uuid;
  v_photos integer;
begin
  select * into v_item from public.work_items where id = p_item for update;
  if v_item.id is null or v_item.owner_id is distinct from v_me
     or not public.member_can(v_item.space_id, v_me, 'mark_done') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.status <> 'open' then
    raise exception 'only an open item can be signed as done' using errcode = 'P0001';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, note)
  values (p_item, v_me, 'done', nullif(trim(p_note), ''))
  returning id into v_event;
  v_photos := public.add_evidence(v_item, v_event, p_evidence);
  if v_photos = 0 and nullif(trim(p_note), '') is null then
    raise exception 'add a photo or a note' using errcode = '22023';
  end if;
  update public.work_items set status = 'done', done_at = now() where id = p_item;
end;
$$;

-- Check and close. Only while Done, never by the owner (rule 5).
create or replace function public.check_item(p_item uuid)
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
  if v_item.id is null or not public.may_check(v_item, v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.status <> 'done' then
    raise exception 'only a done item can be checked' using errcode = 'P0001';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind)
  values (p_item, v_me, 'checked');
  update public.work_items
  set status = 'checked', checked_by = v_me, checked_at = now()
  where id = p_item;
end;
$$;

-- W5. Back to Open with a reason; "other" needs a note (rule 6).
create or replace function public.send_back(
  p_item uuid,
  p_reason text,
  p_note text default null
)
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
  if v_item.id is null or not public.may_check(v_item, v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.status <> 'done' then
    raise exception 'only a done item can be sent back' using errcode = 'P0001';
  end if;
  if p_reason is null
     or p_reason not in ('photo_missing', 'not_as_drawing', 'not_finished', 'other') then
    raise exception 'choose a reason' using errcode = '22023';
  end if;
  if p_reason = 'other' and nullif(trim(p_note), '') is null then
    raise exception 'say what is wrong' using errcode = '22023';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, reason, note)
  values (p_item, v_me, 'sent_back', p_reason, nullif(trim(p_note), ''));
  update public.work_items set status = 'open', done_at = null where id = p_item;
end;
$$;

-- Give an Open item to another owner, for example when the owner left
-- (review 09). The creator or a member with the check right; the new
-- owner must be able to mark items done.
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
  insert into public.work_item_events (work_item_id, actor_id, kind)
  values (p_item, v_me, 'reassigned');
  update public.work_items set owner_id = p_owner where id = p_item;
end;
$$;

-- Discussion: any active member of the Space.
create or replace function public.add_comment(p_item uuid, p_note text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.work_items;
  v_id uuid;
begin
  select * into v_item from public.work_items where id = p_item;
  if v_item.id is null or not public.is_member(v_item.space_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if nullif(trim(p_note), '') is null then
    raise exception 'write a comment' using errcode = '22023';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, note)
  values (p_item, auth.uid(), 'comment', trim(p_note))
  returning id into v_id;
  return v_id;
end;
$$;

-- RE2: the owner of a Checked item shows it on the profile, or hides it.
create or replace function public.set_shown_work(p_item uuid, p_shown boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.work_items;
begin
  select * into v_item from public.work_items where id = p_item for update;
  if v_item.id is null or v_item.owner_id is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.status <> 'checked' then
    raise exception 'only checked work can be shown' using errcode = 'P0001';
  end if;
  update public.work_items set shown = coalesce(p_shown, false) where id = p_item;
end;
$$;

-- ---------------------------------------------------------------------------
-- Needs you (rule 9)
-- ---------------------------------------------------------------------------

-- Open items I own, Done items I may check, join requests I can confirm,
-- and Open items I raised whose owner left. Home (week 7) reuses it.
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
  select 'open_owned', w.space_id, w.id, null::uuid, w.created_at
  from public.work_items w
  join public.spaces s on s.id = w.space_id and s.deleted_at is null
  where w.status = 'open' and w.owner_id = auth.uid()
    and public.is_member(w.space_id)
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
  -- "Owner left · reassign": the owner is no longer an active member.
  select 'owner_left', w.space_id, w.id, null::uuid, w.created_at
  from public.work_items w
  join public.spaces s on s.id = w.space_id and s.deleted_at is null
  where w.status = 'open' and w.created_by = auth.uid()
    and public.is_member(w.space_id)
    and not exists (select 1 from public.space_members m
                    where m.space_id = w.space_id and m.profile_id = w.owner_id
                      and m.left_at is null);
$$;

-- My Spaces (S1) now counts everything that needs you in each Space.
drop function public.my_spaces();
create function public.my_spaces()
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
  select s.id, s.name, s.kind, s.access, s.project_id, p.name, p.type_id,
         m.pass, m.is_admin,
         case when m.is_admin then (
           select count(*)::int from public.space_join_requests r
           where r.space_id = s.id and r.status = 'pending') else 0 end,
         m.confirmed_at,
         (select count(*)::int from public.needs_you() n where n.space_id = s.id)
  from public.space_members m
  join public.spaces s on s.id = m.space_id
  left join public.projects p on p.id = s.project_id
  where m.profile_id = auth.uid() and m.left_at is null and s.deleted_at is null
  order by m.confirmed_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Shown work on profiles (rule 10)
-- ---------------------------------------------------------------------------

-- The first photo of the owner's latest Done sign-off, or none. Never a
-- photo from when the item was raised (review 09).
create or replace function public.shown_work_photo(p_item uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select e.storage_path
  from public.work_item_evidence e
  join public.work_item_events ev on ev.id = e.event_id and ev.kind = 'done'
  join public.work_items w on w.id = e.work_item_id
  where e.work_item_id = p_item and w.shown and w.status = 'checked'
    and ev.actor_id = w.owner_id
  order by ev.created_at desc, e.created_at
  limit 1;
$$;

-- RE1: what anyone signed in sees. Only these fields: never the Space
-- name, the discussion or the files. Hidden when either side blocked the
-- other, as profiles are.
create view public.public_shown_work as
  select w.id as work_item_id,
         w.owner_id as profile_id,
         w.title,
         w.place_text,
         public.shown_work_photo(w.id) as photo_path,
         nullif(trim(coalesce(c.first_name, '') || ' ' || coalesce(c.last_name, '')), '')
           as checked_by_name,
         w.checked_at,
         p.name as project_name
  from public.work_items w
  join public.spaces s on s.id = w.space_id and s.deleted_at is null
  left join public.projects p on p.id = s.project_id
  left join public.profiles c on c.id = w.checked_by
  where w.shown and w.status = 'checked'
    and w.owner_id is not null
    and not public.is_blocked_with(w.owner_id);

-- ---------------------------------------------------------------------------
-- Evidence photos: private bucket "space-files" (rule 11)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('space-files', 'space-files', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

-- The Space a path belongs to: <space_id>/<item_id>/<file>. Null when the
-- path doesn't start with an id.
create or replace function public.space_of_path(p_name text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return split_part(p_name, '/', 1)::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

-- True when [p_name] is the shown photo of a Checked item in a Space
-- that still exists. Starts from the evidence row (unique index on the
-- path), so it never scans every shown item.
create or replace function public.is_shown_photo(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.work_item_evidence e
    join public.work_items w on w.id = e.work_item_id
    join public.spaces s on s.id = w.space_id and s.deleted_at is null
    where e.storage_path = p_name
      and w.shown and w.status = 'checked'
      and w.owner_id is not null
      and not public.is_blocked_with(w.owner_id)
      and public.shown_work_photo(w.id) = p_name);
$$;

-- Delete (through the Storage API): your own upload, and never a file
-- that is evidence on a work item (review 09).
create or replace function public.may_delete_file(p_name text, p_owner text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_owner = auth.uid()::text
    and not exists (select 1 from public.work_item_evidence e where e.storage_path = p_name);
$$;

-- Who may upload to [p_name] = <space_id>/<item_id>/<file> (review 09):
-- the item's creator or owner, or, for an item not made yet, a member
-- who can raise items. Never a Viewer, never outside an item folder.
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
  select * into v_item from public.work_items where id = v_item_id;
  if v_item.id is null then
    return public.can(v_space, 'create_items');
  end if;
  return v_item.space_id = v_space
    and public.is_member(v_space)
    and auth.uid() in (v_item.created_by, v_item.owner_id)
    and public.member_pass(v_space) <> 'viewer';
end;
$$;

create policy space_files_read on storage.objects
  for select to authenticated
  using (bucket_id = 'space-files'
         and (public.is_member(public.space_of_path(name)) or public.is_shown_photo(name)));
create policy space_files_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'space-files' and public.may_upload(name));
-- No update policy: a photo is never replaced or renamed. Every upload
-- has a new name (<uuid>.jpg), so a retry is a new file.
-- Delete: your own leftovers only, never a file that is evidence.
create policy space_files_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'space-files' and public.may_delete_file(name, owner_id));

-- ---------------------------------------------------------------------------
-- Row-level security and grants
-- ---------------------------------------------------------------------------

alter table public.work_items enable row level security;
alter table public.work_item_events enable row level security;
alter table public.work_item_evidence enable row level security;

-- Active members of the Space only; anyone else reads nothing (rule 8).
create policy work_items_read on public.work_items
  for select to authenticated using (public.is_member(space_id));
create policy work_item_events_read on public.work_item_events
  for select to authenticated
  using (exists (select 1 from public.work_items w
                 where w.id = work_item_id and public.is_member(w.space_id)));
create policy work_item_evidence_read on public.work_item_evidence
  for select to authenticated
  using (exists (select 1 from public.work_items w
                 where w.id = work_item_id and public.is_member(w.space_id)));

revoke all on public.work_items, public.work_item_events, public.work_item_evidence
  from anon, authenticated;
grant select on public.work_items, public.work_item_events, public.work_item_evidence
  to authenticated;
-- Support work only (the service role never reaches the app). Events stay
-- append-only for everyone else; see keep_work_item_events().
grant all on public.work_items, public.work_item_events, public.work_item_evidence
  to service_role;

revoke all on public.public_shown_work from anon, authenticated;
grant select on public.public_shown_work to authenticated;

revoke execute on function
  public.latin_initials(text),
  public.space_ref_prefix(text, uuid),
  public.set_space_ref_prefix(),
  public.keep_work_item_events(),
  public.may_check(public.work_items, uuid),
  public.add_evidence(public.work_items, uuid, jsonb),
  public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid),
  public.sign_done(uuid, text, jsonb),
  public.check_item(uuid),
  public.send_back(uuid, text, text),
  public.add_comment(uuid, text),
  public.reassign_work_item(uuid, uuid),
  public.set_shown_work(uuid, boolean),
  public.needs_you(),
  public.my_spaces(),
  public.shown_work_photo(uuid),
  public.space_of_path(text),
  public.is_shown_photo(text),
  public.may_upload(text),
  public.may_delete_file(text, text)
  from public, anon, authenticated;

grant execute on function
  public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid),
  public.sign_done(uuid, text, jsonb),
  public.check_item(uuid),
  public.send_back(uuid, text, text),
  public.add_comment(uuid, text),
  public.reassign_work_item(uuid, uuid),
  public.set_shown_work(uuid, boolean),
  public.needs_you(),
  public.my_spaces(),
  -- Policies and the public view call these as the signed-in user.
  -- shown_work_photo returns a path only for shown, Checked work.
  public.space_of_path(text),
  public.is_shown_photo(text),
  public.may_upload(text),
  public.may_delete_file(text, text),
  public.shown_work_photo(uuid)
  to authenticated;
