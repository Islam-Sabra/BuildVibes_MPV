-- Migration 21: the personal notebook and My calendar (review 33 A4).
-- Branch notebook-db. Not live. Written by the lead on 15 Oct while the
-- founder's PC was off. It goes live before migration 20: migration 20 is
-- built on this one's copies of the shared functions (export_my_data and
-- the purge), and its later timestamp keeps the pushes in order (review 38).
--
-- - notes: private notes, checklists, to-dos and voice notes. Only their
--   owner reads or writes them; nobody else, not even a Space admin or the
--   people of a Space the note was put in.
-- - note_files: a note's voice recording or photos, in the private bucket
--   notebook-files at <me>/<note_id>/<file>.
-- - save_note, delete_note, set_note_done, pin_note, mark_note_put. "Put in
--   a Space" is done in the app: it opens that Space's writing card with
--   the note's words; when the post is accepted, mark_note_put links the
--   note to it. The post is a separate record and the note stays private.
-- - my_calendar: my work items, checklists and activities across the
--   Spaces I'm in (Team posts as can_see_space_post), and my notebook
--   to-dos, for up to 62 days. The phone sends its own days and midnights,
--   so no time zone is typed in SQL (as home_day).
-- - "Remind me" is a local notification on the phone; remind_at is kept so
--   the app can set it again after a reinstall. No server push.
-- - Download my data and the account purge include the notebook.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

-- A checklist's points: [{text, done}], 1 to 50, text 1 to 300 characters.
create or replace function public.is_valid_note_points(p_points jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_point jsonb;
begin
  if jsonb_typeof(p_points) <> 'array' or jsonb_array_length(p_points) not between 1 and 50 then
    return false;
  end if;
  for v_point in select * from jsonb_array_elements(p_points) loop
    if jsonb_typeof(v_point) <> 'object'
       or exists (select 1 from jsonb_object_keys(v_point) k where k not in ('text', 'done'))
       or jsonb_typeof(v_point -> 'text') is distinct from 'string'
       or length(trim(v_point ->> 'text')) = 0
       or length(v_point ->> 'text') > 300
       or (v_point ? 'done' and jsonb_typeof(v_point -> 'done') <> 'boolean') then
      return false;
    end if;
  end loop;
  return true;
end;
$$;

create table public.notes (
  -- Chosen by the app, so a retry with no signal is the same note.
  id uuid primary key,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('text', 'checklist', 'todo', 'voice')),
  body text check (length(body) <= 5000),
  -- Private, so a plain document is enough: nobody else ticks them.
  points jsonb check (points is null or public.is_valid_note_points(points)),
  due_at timestamptz,
  done_at timestamptz,
  pinned boolean not null default false,
  remind_at timestamptz,
  -- The post this note was put in ("Put in a Space"), while it exists.
  put_in_post_id uuid references public.space_posts (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (kind = 'checklist' or points is null),
  check (kind = 'todo' or (due_at is null and done_at is null))
);
create index notes_owner_idx on public.notes (owner_id, created_at desc);
create index notes_owner_due_idx on public.notes (owner_id, due_at) where due_at is not null;

create table public.note_files (
  id uuid primary key default gen_random_uuid(),
  note_id uuid not null references public.notes (id) on delete cascade,
  storage_path text not null unique,
  kind text not null check (kind in ('photo', 'voice')),
  mime text not null,
  bytes bigint check (bytes is null or bytes >= 0),
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  duration_ms integer check (duration_ms is null or duration_ms >= 0),
  sort smallint not null default 0,
  created_at timestamptz not null default now()
);
create index note_files_note_idx on public.note_files (note_id, sort);

-- A file the cleanup has claimed can't go on a note (migration 10).
create trigger note_files_not_claimed
  before insert or update of storage_path on public.note_files
  for each row execute function public.refuse_claimed_post_file();

-- A hidden (deleting) account writes nothing new (migration 16).
create trigger notes_hidden_writer before insert on public.notes
  for each row execute function public.refuse_hidden_writer();
create trigger note_files_hidden_writer before insert on public.note_files
  for each row execute function public.refuse_hidden_writer();

-- Only the owner, and only to read: every change goes through the functions.
alter table public.notes enable row level security;
alter table public.note_files enable row level security;

create policy notes_read_own on public.notes
  for select to authenticated using (owner_id = auth.uid());
create policy note_files_read_own on public.note_files
  for select to authenticated
  using (exists (select 1 from public.notes n where n.id = note_id and n.owner_id = auth.uid()));

-- A deleted note's id, so a late save from the outbox can't bring it back
-- and deleting doesn't make room under the daily limit (review 38 N3). Only
-- the id stays: the words and files are gone. Nobody reads it.
create table public.deleted_notes (
  id uuid primary key,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null,
  deleted_at timestamptz not null default now()
);
create index deleted_notes_owner_idx on public.deleted_notes (owner_id, created_at);
alter table public.deleted_notes enable row level security;

revoke all on public.notes, public.note_files, public.deleted_notes from anon, authenticated;
grant select on public.notes, public.note_files to authenticated;
grant all on public.notes, public.note_files, public.deleted_notes to service_role;

-- ---------------------------------------------------------------------------
-- Files: bucket notebook-files, <me>/<note_id>/<file>, owner only
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('notebook-files', 'notebook-files', false, 26214400,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic',
              'audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/x-m4a'])
on conflict (id) do nothing;

-- Upload: into your own folder only, <me>/<uuid>/<name>.<photo or voice
-- extension>, at most 200 files and 200 MB a day (counted in your own
-- folder through Storage's name index).
create or replace function public.may_upload_note_file(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and not public.is_hidden_account(auth.uid())
    and split_part(p_name, '/', 1) = auth.uid()::text
    and array_length(string_to_array(p_name, '/'), 1) = 3
    and split_part(p_name, '/', 2)
        ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and split_part(p_name, '/', 3) ~* '^[^/]+\.(jpg|jpeg|png|webp|heic|m4a|aac|mp3|mp4)$'
    and p_name not like '%..%'
    -- A note that already exists must be the caller's.
    and not exists (select 1 from public.notes n
                    where n.id::text = split_part(p_name, '/', 2)
                      and n.owner_id <> auth.uid())
    and (select count(*) < 200 and coalesce(sum((o.metadata ->> 'size')::bigint), 0) < 209715200
         from storage.objects o
         where o.bucket_id = 'notebook-files'
           and o.name collate "C" >= auth.uid()::text || '/'
           and o.name collate "C" < auth.uid()::text || '0'
           and o.owner_id = auth.uid()::text
           and o.created_at > now() - interval '1 day');
$$;

-- Delete (Storage API): your own file that no note uses.
create or replace function public.may_delete_note_file(p_name text, p_owner text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_owner = auth.uid()::text
    and split_part(p_name, '/', 1) = auth.uid()::text
    and not exists (select 1 from public.note_files f where f.storage_path = p_name);
$$;

-- Read: your own folder only. Nobody else, ever.
create policy notebook_files_read_own on storage.objects
  for select to authenticated
  using (bucket_id = 'notebook-files' and split_part(name, '/', 1) = auth.uid()::text);
create policy notebook_files_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'notebook-files' and public.may_upload_note_file(name));
create policy notebook_files_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'notebook-files' and public.may_delete_note_file(name, owner_id));
-- No update policy: a file is never replaced.

-- ---------------------------------------------------------------------------
-- Writing notes
-- ---------------------------------------------------------------------------

-- Replace [p_note]'s files with [p_files]: [{path, mime?, bytes?, width?,
-- height?, duration_ms?}], at most 10. Each must be the caller's upload in
-- notebook-files at <me>/<note_id>/<file>; its type comes from Storage
-- (the app's claim only when Storage has none). Returns (photos, voices).
create or replace function public.set_note_files(p_note uuid, p_files jsonb,
                                                 out photos integer, out voices integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_file jsonb;
  v_path text;
  v_mime text;
  v_sort integer := 0;
begin
  photos := 0;
  voices := 0;
  if p_files is null or jsonb_typeof(p_files) = 'null' then
    p_files := '[]'::jsonb;
  end if;
  if jsonb_typeof(p_files) <> 'array' or jsonb_array_length(p_files) > 10 then
    raise exception 'at most 10 files on a note' using errcode = '22023';
  end if;
  delete from public.note_files where note_id = p_note;
  for v_file in select * from jsonb_array_elements(p_files) loop
    if jsonb_typeof(v_file) <> 'object' then
      raise exception 'a file must be an object' using errcode = '22023';
    end if;
    v_path := v_file ->> 'path';
    if v_path is null or v_path like '%..%'
       or v_path not like v_me::text || '/' || p_note::text || '/%'
       or array_length(string_to_array(v_path, '/'), 1) <> 3 then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    select coalesce(nullif(o.metadata ->> 'mimetype', ''), v_file ->> 'mime') into v_mime
    from storage.objects o
    where o.bucket_id = 'notebook-files' and o.name = v_path and o.owner_id = v_me::text;
    if not found then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if v_mime like 'image/%' then
      photos := photos + 1;
    elsif v_mime like 'audio/%' then
      voices := voices + 1;
    else
      raise exception 'photos and voice notes only' using errcode = '22023';
    end if;
    insert into public.note_files (note_id, storage_path, kind, mime, bytes, width, height,
                                   duration_ms, sort)
    values (p_note, v_path, case when v_mime like 'audio/%' then 'voice' else 'photo' end, v_mime,
            nullif(v_file ->> 'bytes', '')::bigint,
            nullif(v_file ->> 'width', '')::integer,
            nullif(v_file ->> 'height', '')::integer,
            nullif(v_file ->> 'duration_ms', '')::integer,
            v_sort);
    v_sort := v_sort + 1;
  end loop;
exception
  when invalid_text_representation then
    raise exception 'a file is not valid' using errcode = '22023';
end;
$$;

-- Save [p_id] (new or the caller's own). The words, points, due time and
-- reminder are replaced as given; [p_pinned] null keeps the pin; [p_files]
-- null keeps the files, a list replaces them.
-- - text: words or a photo; checklist: 1 to 50 points; todo: words;
--   voice: one recording.
-- - At most 500 new notes a day (counted under a per-person lock), deleted
--   ones included.
-- - A deleted note stays deleted: saving it again changes nothing and
--   returns null, so the app drops its queued edit.
create or replace function public.save_note(
  p_id uuid,
  p_kind text,
  p_body text default null,
  p_points jsonb default null,
  p_due_at timestamptz default null,
  p_remind_at timestamptz default null,
  p_pinned boolean default null,
  p_files jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_note public.notes;
  v_body text := nullif(trim(p_body), '');
  v_photos integer;
  v_voices integer;
begin
  if v_me is null or public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_id is null then
    raise exception 'a note needs its id' using errcode = '22023';
  end if;
  if exists (select 1 from public.deleted_notes d where d.id = p_id) then
    if exists (select 1 from public.deleted_notes d where d.id = p_id and d.owner_id <> v_me) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    return null;
  end if;
  if p_kind is null or p_kind not in ('text', 'checklist', 'todo', 'voice') then
    raise exception 'choose a kind of note' using errcode = '22023';
  end if;
  if length(v_body) > 5000 then
    raise exception 'at most 5000 characters' using errcode = '22023';
  end if;
  if p_kind = 'checklist' and (p_points is null or not public.is_valid_note_points(p_points)) then
    raise exception 'a checklist has 1 to 50 points' using errcode = '22023';
  end if;
  if p_kind <> 'checklist' and p_points is not null and jsonb_typeof(p_points) <> 'null' then
    raise exception 'only a checklist has points' using errcode = '22023';
  end if;
  if p_kind <> 'todo' and p_due_at is not null then
    raise exception 'only a to-do has a time' using errcode = '22023';
  end if;
  if p_kind = 'todo' and v_body is null then
    raise exception 'write the to-do' using errcode = '22023';
  end if;
  if p_remind_at is not null and p_remind_at > now() + interval '366 days' then
    raise exception 'a reminder within a year' using errcode = '22023';
  end if;

  select * into v_note from public.notes where id = p_id for update;
  if v_note.id is not null and v_note.owner_id <> v_me then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if v_note.id is null then
    -- New: under a per-person lock, so the daily count holds and a retry of
    -- the same id running now becomes an update instead of a duplicate.
    perform pg_advisory_xact_lock(hashtextextended('note:' || v_me::text, 0));
    select * into v_note from public.notes where id = p_id for update;
    if v_note.id is not null and v_note.owner_id <> v_me then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    -- Deleted while this save waited.
    if v_note.id is null and exists (select 1 from public.deleted_notes d where d.id = p_id) then
      return null;
    end if;
  end if;
  if v_note.id is null then
    if (select count(*) from public.notes n
        where n.owner_id = v_me and n.created_at > now() - interval '1 day')
       + (select count(*) from public.deleted_notes d
          where d.owner_id = v_me and d.created_at > now() - interval '1 day') >= 500 then
      raise exception 'that''s 500 notes today; try again tomorrow' using errcode = '54000';
    end if;
    insert into public.notes (id, owner_id, kind, body, points, due_at, remind_at, pinned)
    values (p_id, v_me, p_kind, v_body,
            case when p_kind = 'checklist' then p_points end,
            case when p_kind = 'todo' then p_due_at end,
            p_remind_at, coalesce(p_pinned, false));
  else
    update public.notes
    set kind = p_kind,
        body = v_body,
        points = case when p_kind = 'checklist' then p_points end,
        due_at = case when p_kind = 'todo' then p_due_at end,
        done_at = case when p_kind = 'todo' then done_at end,
        remind_at = p_remind_at,
        pinned = coalesce(p_pinned, pinned),
        updated_at = now()
    where id = p_id;
  end if;

  if p_files is not null then
    select f.photos, f.voices into v_photos, v_voices from public.set_note_files(p_id, p_files) f;
  end if;
  select count(*) filter (where kind = 'photo'), count(*) filter (where kind = 'voice')
  into v_photos, v_voices
  from public.note_files where note_id = p_id;
  if p_kind = 'voice' and v_voices <> 1 then
    raise exception 'a voice note has one recording' using errcode = '22023';
  end if;
  if p_kind <> 'voice' and v_voices > 0 then
    raise exception 'a recording goes in a voice note' using errcode = '22023';
  end if;
  if p_kind = 'text' and v_body is null and v_photos = 0 then
    raise exception 'write something or add a photo' using errcode = '22023';
  end if;
  return p_id;
end;
$$;

-- Delete [p_id] (yours). Its files are released; the app removes them with
-- the Storage API, which may_delete_note_file now allows. Its id is kept
-- in deleted_notes, so it can't come back.
create or replace function public.delete_note(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or public.is_hidden_account(auth.uid()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  insert into public.deleted_notes (id, owner_id, created_at)
  select n.id, n.owner_id, n.created_at from public.notes n
  where n.id = p_id and n.owner_id = auth.uid()
  on conflict do nothing;
  delete from public.notes where id = p_id and owner_id = auth.uid();
end;
$$;

-- Tick or untick a to-do (yours).
create or replace function public.set_note_done(p_id uuid, p_on boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note public.notes;
begin
  select * into v_note from public.notes where id = p_id for update;
  if v_note.id is null or v_note.owner_id <> auth.uid() or public.is_hidden_account(auth.uid()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_note.kind <> 'todo' then
    raise exception 'only a to-do is ticked' using errcode = '22023';
  end if;
  update public.notes
  set done_at = case when coalesce(p_on, true) then coalesce(done_at, now()) end,
      updated_at = now()
  where id = p_id;
end;
$$;

-- Pin or unpin a note (yours).
create or replace function public.pin_note(p_id uuid, p_on boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or public.is_hidden_account(auth.uid()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.notes set pinned = coalesce(p_on, true), updated_at = now()
  where id = p_id and owner_id = auth.uid();
  if not found then
    raise exception 'not allowed' using errcode = '42501';
  end if;
end;
$$;

-- The note was put in a Space as [p_post], a post the caller wrote.
create or replace function public.mark_note_put(p_note uuid, p_post uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or public.is_hidden_account(auth.uid())
     or not exists (select 1 from public.space_posts p
                    where p.id = p_post and p.author_id = auth.uid() and p.deleted_at is null) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.notes set put_in_post_id = p_post, updated_at = now()
  where id = p_note and owner_id = auth.uid();
  if not found then
    raise exception 'not allowed' using errcode = '42501';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- My calendar
-- ---------------------------------------------------------------------------

-- What is mine from [p_from_day] to [p_to_day] (the phone's days, both
-- included) and [p_from] to [p_to] (the phone's midnights, for times):
-- - work_item: live work items I own or wrote, due in those days, not yet
--   Checked;
-- - checklist: live checklists I'm for, due in those days;
-- - activity: live activities I'm in or put in my calendar, starting then;
-- - todo: my notebook to-dos due then (done ones too, shown ticked).
-- Only Spaces I'm still in, and Team posts only as can_see_space_post.
-- With the post's place (null for a to-do). At most 62 days (both ends
-- included). Times first, then due days, then titles.
create or replace function public.my_calendar(
  p_from_day date,
  p_to_day date,
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  kind text,
  space_id uuid,
  space_name text,
  team_id uuid,
  post_id uuid,
  note_id uuid,
  title text,
  place text,
  day date,
  starts_at timestamptz,
  ends_at timestamptz,
  status text,
  needs_me boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_from_day is null or p_to_day is null or p_to_day < p_from_day
     or p_to_day - p_from_day > 61
     or p_from is null or p_to is null or p_to <= p_from
     -- An hour of slack for a change of clock in the phone's time zone.
     or p_to - p_from > interval '62 days 1 hour' then
    raise exception 'choose up to 62 days' using errcode = '22023';
  end if;
  return query
  with mine as (
    select m.space_id, s.name
    from public.space_members m
    join public.spaces s on s.id = m.space_id and s.deleted_at is null
    where m.profile_id = auth.uid() and m.left_at is null
  )
  select 'work_item'::text, p.space_id, mine.name, p.team_id, p.id, null::uuid, p.title,
         p.place_text, p.due_date, null::timestamptz, null::timestamptz, w.status,
         public.item_needs_me(w, p) is not null
  from mine
  join public.space_posts p on p.space_id = mine.space_id
  join public.work_items w on w.id = p.id
  where p.kind = 'work_item' and p.status = 'live' and p.deleted_at is null
    and w.status in ('open', 'done')
    and (w.owner_id = auth.uid() or p.author_id = auth.uid())
    and p.due_date between p_from_day and p_to_day
    and public.can_see_space_post(p.id)
  union all
  select 'checklist', p.space_id, mine.name, p.team_id, p.id, null, p.title,
         p.place_text, p.due_date, null, null, p.status, public.checklist_needs_me(p)
  from mine
  join public.space_posts p on p.space_id = mine.space_id
  where p.kind = 'checklist' and p.status = 'live' and p.deleted_at is null
    and p.due_date between p_from_day and p_to_day
    and exists (select 1 from public.post_people pp
                where pp.post_id = p.id and pp.profile_id = auth.uid())
    and public.can_see_space_post(p.id)
  union all
  select 'activity', p.space_id, mine.name, p.team_id, p.id, null, p.title,
         p.place_text, null, p.starts_at, p.ends_at, p.status, false
  from mine
  join public.space_posts p on p.space_id = mine.space_id
  where p.kind = 'activity' and p.status = 'live' and p.deleted_at is null
    and p.starts_at >= p_from and p.starts_at < p_to
    and (exists (select 1 from public.post_people pp
                 where pp.post_id = p.id and pp.profile_id = auth.uid())
         or exists (select 1 from public.post_acks a
                    where a.post_id = p.id and a.profile_id = auth.uid()
                      and a.kind = 'in_my_calendar'))
    and public.can_see_space_post(p.id)
  union all
  select 'todo', null, null, null, null, n.id,
         coalesce(left(n.body, 200), ''), null, null, n.due_at, null,
         case when n.done_at is null then 'open' else 'done' end, false
  from public.notes n
  where n.owner_id = auth.uid() and n.kind = 'todo'
    and n.due_at >= p_from and n.due_at < p_to
  order by 10 nulls last, 9 nulls last, 7;
end;
$$;

-- ---------------------------------------------------------------------------
-- Cleanup (service role; scheduled with the other cleanups, founder's yes)
-- ---------------------------------------------------------------------------

-- Notebook files no note uses, older than a day (an upload may still be on
-- its way): claimed under the same per-file lock as Space files, then the
-- job deletes them with the Storage API and calls forget_cleanup_claims.
-- A deleted note's recording is private: it mustn't stay behind.
create or replace function public.orphan_note_files(p_age interval default interval '7 days')
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
    select o.name from storage.objects o
    where o.bucket_id = 'notebook-files'
      and o.created_at < now() - greatest(p_age, interval '1 day')
      and not exists (select 1 from public.note_files f where f.storage_path = o.name)
    order by o.created_at
  loop
    perform public.lock_file_path(v_name);
    -- Checked again under the lock: a note may have just used it.
    if not exists (select 1 from public.note_files f where f.storage_path = v_name) then
      insert into public.file_cleanup_claims (storage_path) values (v_name)
      on conflict (storage_path) do nothing;
      name := v_name;
      return next;
    end if;
  end loop;
end;
$$;

-- As in 20261012170000_feed.sql, with notebook-files added.
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
                      where o.bucket_id in ('space-files', 'post-media', 'notebook-files')
                        and o.name = c.storage_path)
    returning 1
  )
  select count(*)::int from gone;
$$;

-- ---------------------------------------------------------------------------
-- After 30 days (service role): the notebook files go with the account
-- ---------------------------------------------------------------------------

-- As in 20261013130000_account.sql, with notebook-files added.
create or replace function public.accounts_due_for_purge()
returns table (profile_id uuid, bucket text, name text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, o.bucket_id, o.name
  from public.profiles p
  left join storage.objects o
    on o.bucket_id in ('avatars', 'post-media', 'notebook-files')
   and o.name collate "C" >= p.id::text || '/'
   and o.name collate "C" < p.id::text || '0'
  where p.deletion_scheduled_at < now() - interval '30 days'
  order by p.id;
$$;

-- As in 20261013130000_account.sql, with notebook-files added.
create or replace function public.purge_account(p_id uuid)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform 1 from public.profiles
  where id = p_id and deletion_scheduled_at < now() - interval '30 days'
  for update;
  if not found then
    return false;
  end if;
  if exists (select 1 from storage.objects o
             where o.bucket_id in ('avatars', 'post-media', 'notebook-files')
               and o.name collate "C" >= p_id::text || '/'
               and o.name collate "C" < p_id::text || '0') then
    return false;
  end if;
  delete from auth.users where id = p_id;
  return true;
end;
$$;


-- ---------------------------------------------------------------------------
-- Download my data: the notebook too (as in 20261015180000_post_kinds.sql,
-- with that change only)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.export_my_data(p_request uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) - 'follower_count' - 'following_count'
                from public.profiles p where p.id = r.profile_id),
    'private', (select to_jsonb(pp) from public.profile_private pp where pp.id = r.profile_id),
    'experience', coalesce((select jsonb_agg(to_jsonb(e)) from public.experience e
                            where e.profile_id = r.profile_id), '[]'),
    'open_to', coalesce((select jsonb_agg(to_jsonb(o)) from public.profile_open_to o
                         where o.profile_id = r.profile_id), '[]'),
    'cv_projects', coalesce((select jsonb_agg(to_jsonb(c)) from public.cv_projects c
                             where c.profile_id = r.profile_id), '[]'),
    'following', coalesce((select jsonb_agg(f.followee_id) from public.follows f
                           where f.follower_id = r.profile_id), '[]'),
    'posts', coalesce((select jsonb_agg(jsonb_build_object(
                         'id', po.id, 'body', po.body, 'lang', po.lang,
                         'created_at', po.created_at, 'deleted_at', po.deleted_at))
                       from public.posts po where po.author_id = r.profile_id), '[]'),
    'replies', coalesce((select jsonb_agg(jsonb_build_object(
                           'id', pr.id, 'post_id', pr.post_id, 'body', pr.body,
                           'created_at', pr.created_at))
                         from public.post_replies pr where pr.author_id = r.profile_id), '[]'),
    'spaces', coalesce((select jsonb_agg(jsonb_build_object(
                          'space', s.name, 'pass', m.pass, 'admin', m.is_admin,
                          'joined_at', m.confirmed_at, 'left_at', m.left_at))
                        from public.space_members m join public.spaces s on s.id = m.space_id
                        where m.profile_id = r.profile_id), '[]'),
    'work_items_raised', coalesce((select jsonb_agg(jsonb_build_object(
                                     'ref', w.ref, 'title', w.title, 'status', w.status,
                                     'created_at', w.created_at))
                                   from public.work_items w where w.created_by = r.profile_id), '[]'),
    'work_items_owned', coalesce((select jsonb_agg(jsonb_build_object(
                                    'ref', w.ref, 'title', w.title, 'status', w.status,
                                    'checked_at', w.checked_at))
                                  from public.work_items w where w.owner_id = r.profile_id), '[]'),
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
                            'id', ms.id, 'kind', ms.kind, 'body', ms.body,
                            'created_at', ms.created_at))
                          from public.messages ms where ms.author_id = r.profile_id), '[]'),
    'work_item_notes', coalesce((select jsonb_agg(jsonb_build_object(
                                   'ref', w.ref, 'kind', e.kind, 'note', e.note,
                                   'created_at', e.created_at))
                                 from public.work_item_events e
                                 join public.work_items w on w.id = e.work_item_id
                                 where e.actor_id = r.profile_id and e.note is not null), '[]'),
    'library_files', coalesce((select jsonb_agg(jsonb_build_object(
                                 'space', s.name, 'name', f.name, 'created_at', f.created_at,
                                 'deleted_at', f.deleted_at))
                               from public.library_files f join public.spaces s on s.id = f.space_id
                               where f.uploaded_by = r.profile_id), '[]'),
    'blocked', coalesce((select jsonb_agg(jsonb_build_object(
                           'profile_id', b.blocked_id, 'created_at', b.created_at))
                         from public.blocks b where b.blocker_id = r.profile_id), '[]'),
    'muted', coalesce((select jsonb_agg(jsonb_build_object(
                         'profile_id', mu.muted_id, 'created_at', mu.created_at))
                       from public.mutes mu where mu.muter_id = r.profile_id), '[]'),
    'useful_marks', coalesce((select jsonb_agg(jsonb_build_object(
                                'target_kind', u.target_kind, 'target_id', u.target_id,
                                'created_at', u.created_at))
                              from public.useful_marks u where u.profile_id = r.profile_id), '[]'),
    'reports_made', coalesce((select jsonb_agg(jsonb_build_object(
                                'target_kind', rp.target_kind, 'reason', rp.reason, 'note', rp.note,
                                'status', rp.status, 'created_at', rp.created_at))
                              from public.reports rp where rp.reporter_id = r.profile_id), '[]'),
    'join_requests', coalesce((select jsonb_agg(jsonb_build_object(
                                 'space', s.name, 'via', j.via, 'status', j.status,
                                 'created_at', j.created_at))
                               from public.space_join_requests j join public.spaces s on s.id = j.space_id
                               where j.profile_id = r.profile_id), '[]'),
    'space_posts', coalesce((select jsonb_agg(jsonb_build_object(
                              'kind', p.kind, 'title', p.title, 'body', p.body,
                              'place', p.place_text, 'due_date', p.due_date,
                              'quote', p.quote, 'status', p.status,
                              'pinned_until', p.pinned_until, 'starts_at', p.starts_at,
                              'ends_at', p.ends_at,
                              'file', (select f.name from public.library_files f
                                       where f.id = p.library_file_id),
                              'created_at', p.created_at, 'deleted_at', p.deleted_at))
                            from public.space_posts p where p.author_id = r.profile_id), '[]'),
    'post_edits', coalesce((select jsonb_agg(jsonb_build_object(
                             'changes', e.changes, 'created_at', e.created_at))
                           from public.post_edits e where e.editor_id = r.profile_id), '[]'),
    'post_acks', coalesce((select jsonb_agg(jsonb_build_object(
                            'post', p.title, 'kind', a.kind, 'created_at', a.created_at))
                          from public.post_acks a join public.space_posts p on p.id = a.post_id
                          where a.profile_id = r.profile_id), '[]'),
    'checklist_ticks', coalesce((select jsonb_agg(jsonb_build_object(
                                  'point', c.text, 'ticked_at', c.ticked_at))
                                from public.checklist_points c where c.ticked_by = r.profile_id), '[]'),
    'post_people', coalesce((select jsonb_agg(jsonb_build_object(
                              'post', p.title, 'created_at', pp.created_at))
                            from public.post_people pp join public.space_posts p on p.id = pp.post_id
                            where pp.profile_id = r.profile_id), '[]'),
    'notes', coalesce((select jsonb_agg(jsonb_build_object(
                        'kind', n.kind, 'body', n.body, 'points', n.points,
                        'due_at', n.due_at, 'done_at', n.done_at, 'pinned', n.pinned,
                        'remind_at', n.remind_at, 'created_at', n.created_at,
                        'files', (select jsonb_agg(f.storage_path order by f.sort)
                                  from public.note_files f where f.note_id = n.id)))
                      from public.notes n where n.owner_id = r.profile_id), '[]'),
    'push_settings', (select to_jsonb(ps) from public.push_settings ps where ps.profile_id = r.profile_id)
  )
  from public.data_requests r
  where r.id = p_request;
$function$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.is_valid_note_points(jsonb),
  public.may_upload_note_file(text),
  public.may_delete_note_file(text, text),
  public.set_note_files(uuid, jsonb),
  public.save_note(uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb),
  public.delete_note(uuid),
  public.set_note_done(uuid, boolean),
  public.pin_note(uuid, boolean),
  public.mark_note_put(uuid, uuid),
  public.my_calendar(date, date, timestamptz, timestamptz),
  public.orphan_note_files(interval),
  public.forget_cleanup_claims(),
  public.accounts_due_for_purge(),
  public.purge_account(uuid),
  public.export_my_data(uuid)
  from public, anon;
-- Internal: writes without its own checks, or the founder's and cron's only.
-- The storage rules call may_upload_note_file and may_delete_note_file as
-- the signed-in person; they answer only about the caller's own folder.
revoke execute on function
  public.set_note_files(uuid, jsonb),
  public.orphan_note_files(interval),
  public.forget_cleanup_claims(),
  public.accounts_due_for_purge(),
  public.purge_account(uuid),
  public.export_my_data(uuid)
  from authenticated;
grant execute on function
  public.is_valid_note_points(jsonb),
  public.may_upload_note_file(text),
  public.may_delete_note_file(text, text),
  public.save_note(uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb),
  public.delete_note(uuid),
  public.set_note_done(uuid, boolean),
  public.pin_note(uuid, boolean),
  public.mark_note_put(uuid, uuid),
  public.my_calendar(date, date, timestamptz, timestamptz)
  to authenticated;
grant execute on function
  public.orphan_note_files(interval),
  public.forget_cleanup_claims(),
  public.accounts_due_for_purge(),
  public.purge_account(uuid),
  public.export_my_data(uuid)
  to service_role;
