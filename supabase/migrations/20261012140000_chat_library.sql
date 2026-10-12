-- Migration 9: Space chat and Library (week 6). DRAFT by the lead,
-- branch chat-library-db. Brief: docs/reviews/2026-10-12-12-chat-library.md.
-- Design: Figma S7k, S8k, S9k, S8b–d (chat), S13k, F1 (Library).
--
-- Chat
-- - Every Space has one "Everyone" thread; every Team has its own thread.
--   Both are made automatically.
-- - Read and write: active members of the Space; a Team thread only for
--   that Team's members and the Space admins. Every pass can chat.
-- - Photos, files and voice notes need the "add files" right (Viewers
--   chat in text only).
-- - Work item steps (raised, done, checked, sent back, reassigned) post a
--   card into the item's Team thread, or Everyone.
-- - Messages are never edited. The author or a Space admin can delete one;
--   it stays as "Message deleted".
--
-- Library
-- - Files per Space, optionally for one Team. Read: members (Team files:
--   that Team and the admins). Add: the "add files" right.
-- - Revisions: a new file can supersede an older one; the old one is kept.
-- - Documents (not photos or voice) posted in chat are added to the
--   Library automatically ("From chat").
-- - Files can be attached to work items ("Used in KCT-021").
--
-- Storage paths in the private bucket "space-files":
--   <space>/<item_id>/<file>          work item photos (migrations 7–8)
--   <space>/chat/<message_id>/<file>  chat attachments
--   <space>/library/<file_id>/<file>  Library files
-- Every write goes through a function; the app only reads the tables.

-- ---------------------------------------------------------------------------
-- Bucket: documents and voice notes too
-- ---------------------------------------------------------------------------

update storage.buckets
set file_size_limit = 26214400,  -- 25 MB (drawings); photos are compressed in the app
    allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/webp', 'image/heic',
      'application/pdf',
      'audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/x-m4a']
where id = 'space-files';

-- ---------------------------------------------------------------------------
-- Threads
-- ---------------------------------------------------------------------------

create table public.threads (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  -- Null is the Everyone thread.
  team_id uuid references public.teams (id) on delete cascade,
  created_at timestamptz not null default now()
);
create unique index threads_everyone_idx on public.threads (space_id) where team_id is null;
create unique index threads_team_idx on public.threads (team_id) where team_id is not null;

create or replace function public.handle_space_thread()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.threads (space_id) values (new.id) on conflict do nothing;
  return new;
end;
$$;

create trigger spaces_everyone_thread
  after insert on public.spaces
  for each row execute function public.handle_space_thread();

create or replace function public.handle_team_thread()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.threads (space_id, team_id) values (new.space_id, new.id)
  on conflict do nothing;
  return new;
end;
$$;

create trigger teams_thread
  after insert on public.teams
  for each row execute function public.handle_team_thread();

insert into public.threads (space_id)
select s.id from public.spaces s
where not exists (select 1 from public.threads t where t.space_id = s.id and t.team_id is null);
insert into public.threads (space_id, team_id)
select tm.space_id, tm.id from public.teams tm
where not exists (select 1 from public.threads t where t.team_id = tm.id);

-- True when the caller may read and write in [p_thread].
create or replace function public.can_use_thread(p_thread uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select public.is_member(t.space_id)
       and (t.team_id is null
            or public.is_space_admin(t.space_id)
            or exists (select 1 from public.team_members m
                       where m.team_id = t.team_id and m.profile_id = auth.uid()))
    from public.threads t where t.id = p_thread
  ), false);
$$;

-- ---------------------------------------------------------------------------
-- Messages
-- ---------------------------------------------------------------------------

create table public.messages (
  -- Chosen by the app, so attachments upload first and a retry never
  -- posts twice.
  id uuid primary key,
  thread_id uuid not null references public.threads (id) on delete cascade,
  space_id uuid not null references public.spaces (id) on delete cascade,
  author_id uuid references public.profiles (id) on delete set null,
  kind text not null check (kind in ('text', 'photo', 'file', 'voice', 'work_item')),
  body text check (length(body) <= 4000),
  reply_to uuid references public.messages (id) on delete set null,
  work_item_id uuid references public.work_items (id) on delete cascade,
  work_item_event_id uuid references public.work_item_events (id) on delete cascade,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references public.profiles (id) on delete set null,
  check ((kind = 'work_item') = (work_item_id is not null))
);
create index messages_thread_idx on public.messages (thread_id, created_at desc);
create index messages_author_idx on public.messages (author_id, created_at desc);

create table public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages (id) on delete cascade,
  storage_path text not null unique,
  mime text not null,
  bytes bigint check (bytes is null or bytes >= 0),
  width integer,
  height integer,
  duration_ms integer check (duration_ms is null or duration_ms between 0 and 600000),
  sort smallint not null default 0
);
create index message_attachments_message_idx on public.message_attachments (message_id);

create table public.thread_reads (
  thread_id uuid not null references public.threads (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (thread_id, profile_id)
);

-- ---------------------------------------------------------------------------
-- Library
-- ---------------------------------------------------------------------------

create table public.library_files (
  -- Chosen by the app (upload first, then register).
  id uuid primary key,
  space_id uuid not null references public.spaces (id) on delete cascade,
  -- A Team's file. A Team that has files or chat can't be deleted (see
  -- delete_team below), so Team files never leak to the whole Space.
  team_id uuid references public.teams (id),
  name text not null check (length(trim(name)) between 1 and 120),
  storage_path text not null unique,
  mime text not null,
  bytes bigint check (bytes is null or bytes >= 0),
  rev_label text check (length(rev_label) <= 20),
  note text check (length(note) <= 300),
  supersedes_id uuid references public.library_files (id) on delete set null,
  source text not null default 'upload' check (source in ('upload', 'chat')),
  source_message_id uuid references public.messages (id) on delete set null,
  uploaded_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references public.profiles (id) on delete set null
);
create index library_files_space_idx on public.library_files (space_id, created_at desc)
  where deleted_at is null;

create table public.work_item_attachments (
  work_item_id uuid not null references public.work_items (id) on delete cascade,
  library_file_id uuid not null references public.library_files (id) on delete cascade,
  added_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (work_item_id, library_file_id)
);
create index work_item_attachments_file_idx on public.work_item_attachments (library_file_id);

-- True when the caller may see [p_file] (not deleted; Team files for that
-- Team and the admins).
create or replace function public.can_read_library_file(p_file uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select f.deleted_at is null
       and public.is_member(f.space_id)
       and (f.team_id is null
            or public.is_space_admin(f.space_id)
            or exists (select 1 from public.team_members m
                       where m.team_id = f.team_id and m.profile_id = auth.uid()))
    from public.library_files f where f.id = p_file
  ), false);
$$;

-- ---------------------------------------------------------------------------
-- Storage: who may upload, read and delete
-- ---------------------------------------------------------------------------

-- True when the caller uploaded [p_path] to space-files.
create or replace function public.is_my_upload(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from storage.objects o
                 where o.bucket_id = 'space-files' and o.name = p_path
                   and o.owner_id = auth.uid()::text);
$$;

-- True when [p_path] is used by a work item, a message or the Library.
create or replace function public.is_referenced_file(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.work_item_evidence e where e.storage_path = p_path)
      or exists (select 1 from public.message_attachments a where a.storage_path = p_path)
      or exists (select 1 from public.library_files f where f.storage_path = p_path);
$$;

-- Loose uploads now exclude chat and Library files too (migration 8 cap).
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
    and not public.is_referenced_file(o.name);
$$;

-- Cleanup list (service role only, migration 8): never a referenced file.
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
    and not public.is_referenced_file(o.name);
$$;

-- Files in <space>/<area>/<id>/ uploaded by someone other than the caller.
create or replace function public.folder_has_others_files_in(p_prefix text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from storage.objects o
    where o.bucket_id = 'space-files'
      and o.name like p_prefix || '%'
      and o.owner_id is distinct from auth.uid()::text);
$$;

-- Everything the caller uploaded to space-files in the last 24 hours.
create or replace function public.uploads_today()
returns table (files bigint, bytes bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select count(*), coalesce(sum((o.metadata ->> 'size')::bigint), 0)
  from storage.objects o
  where o.bucket_id = 'space-files' and o.owner_id = auth.uid()::text
    and o.created_at > now() - interval '1 day';
$$;

-- The stored type of an upload, when storage recorded one; else [p_claimed].
create or replace function public.upload_mime(p_path text, p_claimed text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select nullif(o.metadata ->> 'mimetype', '') from storage.objects o
     where o.bucket_id = 'space-files' and o.name = p_path),
    p_claimed);
$$;

-- Uploads. Chat and Library paths are new; work item paths keep the
-- migration 8 rules (copied unchanged below).
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
  v_id uuid;
  v_item public.work_items;
  v_files bigint;
  v_bytes bigint;
begin
  if p_name like '%..%' then
    return false;
  end if;
  select files, bytes into v_files, v_bytes from public.loose_uploads();
  if v_files >= 400 or v_bytes >= 200 * 1024 * 1024 then
    return false;
  end if;
  -- Every upload counts here, used or not: 300 files or 500 MB a day.
  select files, bytes into v_files, v_bytes from public.uploads_today();
  if v_files >= 300 or v_bytes >= 500 * 1024 * 1024 then
    return false;
  end if;

  -- Chat and Library: <space>/<chat|library>/<id>/<file>
  if v_parts[2] in ('chat', 'library') then
    if array_length(v_parts, 1) <> 4 or v_parts[4] = '' then
      return false;
    end if;
    begin
      v_space := v_parts[1]::uuid;
      v_id := v_parts[3]::uuid;
    exception when invalid_text_representation then
      return false;
    end;
    if not public.can(v_space, 'add_files') then
      return false;
    end if;
    if v_parts[2] = 'chat' then
      -- Only before the message is posted, and only into your own folder.
      return not exists (select 1 from public.messages m where m.id = v_id)
        and not public.folder_has_others_files_in(v_parts[1] || '/chat/' || v_parts[3] || '/');
    end if;
    return not exists (select 1 from public.library_files f where f.id = v_id)
      and not public.folder_has_others_files_in(v_parts[1] || '/library/' || v_parts[3] || '/');
  end if;

  -- Work item photos: <space>/<item_id>/<file> (migration 8). Photos
  -- only (the bucket also takes PDFs and audio now).
  if array_length(v_parts, 1) <> 3 or v_parts[3] = ''
     or lower(v_parts[3]) !~ '\.(jpe?g|png|webp|heic)$' then
    return false;
  end if;
  begin
    v_space := v_parts[1]::uuid;
    v_id := v_parts[2]::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  select * into v_item from public.work_items where id = v_id;
  if v_item.id is null then
    return public.can(v_space, 'create_items')
      and not public.folder_has_others_files(v_space, v_id);
  end if;
  return v_item.space_id = v_space
    and public.is_member(v_space)
    and auth.uid() in (v_item.created_by, v_item.owner_id)
    and public.member_pass(v_space) <> 'viewer';
end;
$$;

-- Reads. Your own uploads; a shown photo; chat files for people who can
-- read the (not deleted) message; Library files for people who can read
-- the file; work item photos for members once the item exists.
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
  v_id uuid;
begin
  if p_owner = auth.uid()::text then
    return true;
  end if;
  if public.is_shown_photo(p_name) then
    return true;
  end if;
  if v_parts[2] in ('chat', 'library') then
    begin
      v_space := v_parts[1]::uuid;
      v_id := v_parts[3]::uuid;
    exception when invalid_text_representation then
      return false;
    end;
    if v_parts[2] = 'chat' then
      return exists (
        select 1 from public.message_attachments a
        join public.messages m on m.id = a.message_id
        where a.storage_path = p_name and m.id = v_id and m.space_id = v_space
          and m.deleted_at is null and public.can_use_thread(m.thread_id))
        -- A document from chat that stays in the Library (for example
        -- because a work item uses it) after its message was deleted.
        or exists (
        select 1 from public.library_files f
        where f.storage_path = p_name and f.space_id = v_space
          and public.can_read_library_file(f.id));
    end if;
    return exists (
      select 1 from public.library_files f
      where f.storage_path = p_name and f.id = v_id and f.space_id = v_space
        and public.can_read_library_file(f.id));
  end if;
  begin
    v_space := v_parts[1]::uuid;
    v_id := v_parts[2]::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return public.is_member(v_space)
    and exists (select 1 from public.work_items w
                where w.id = v_id and w.space_id = v_space);
end;
$$;

-- Delete (Storage API): your own upload that nothing uses.
create or replace function public.may_delete_file(p_name text, p_owner text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_owner = auth.uid()::text and not public.is_referenced_file(p_name);
$$;

-- ---------------------------------------------------------------------------
-- Posting and deleting messages
-- ---------------------------------------------------------------------------

-- Post to [p_thread]. [p_attachments] is a JSON array of
--   {"path", "mime", "bytes", "width", "height", "duration_ms"}
-- under <space>/chat/<p_id>/, uploaded by the caller. Returns the id.
-- A retry with the same id returns the message already posted.
create or replace function public.post_message(
  p_id uuid,
  p_thread uuid,
  p_body text default null,
  p_reply_to uuid default null,
  p_attachments jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_thread public.threads;
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_count int := coalesce(jsonb_array_length(p_attachments), 0);
  v_kind text;
  v_att jsonb;
  v_path text;
  v_mime text;
  v_prefix text;
  v_existing public.messages;
  v_n int := 0;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  select * into v_existing from public.messages where id = p_id;
  if v_existing.id is not null then
    if v_existing.author_id = v_me and v_existing.thread_id = p_thread then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_thread from public.threads where id = p_thread;
  if v_thread.id is null or not public.can_use_thread(p_thread) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_body is null and v_count = 0 then
    raise exception 'write something or add a file' using errcode = '22023';
  end if;
  if v_count > 10 then
    raise exception 'at most 10 files' using errcode = '22023';
  end if;
  if (select count(*) from public.messages m
      where m.author_id = v_me and m.kind <> 'work_item'
        and m.created_at > now() - interval '1 minute') >= 30 then
    raise exception 'too many messages, wait a moment' using errcode = 'P0001';
  end if;
  if p_reply_to is not null and not exists (
       select 1 from public.messages m where m.id = p_reply_to and m.thread_id = p_thread) then
    raise exception 'reply to a message in this thread' using errcode = '22023';
  end if;

  v_kind := 'text';
  if v_count > 0 then
    if not public.can(v_thread.space_id, 'add_files') then
      raise exception 'your pass does not allow files' using errcode = '42501';
    end if;
    v_prefix := v_thread.space_id::text || '/chat/' || p_id::text || '/';
    for v_att in select * from jsonb_array_elements(p_attachments) loop
      v_path := v_att ->> 'path';
      if v_path is null or v_path not like v_prefix || '%' or v_path like '%..%'
         or array_length(string_to_array(v_path, '/'), 1) <> 4
         or not public.is_my_upload(v_path) then
        raise exception 'file not uploaded' using errcode = '22023';
      end if;
      v_mime := public.upload_mime(v_path, v_att ->> 'mime');
      if v_mime is distinct from (v_att ->> 'mime') then
        raise exception 'file type does not match the upload' using errcode = '22023';
      end if;
      if v_mime like 'audio/%' then
        if v_count > 1 then
          raise exception 'a voice note is sent on its own' using errcode = '22023';
        end if;
        v_kind := 'voice';
      elsif v_mime like 'image/%' then
        if v_kind = 'text' then v_kind := 'photo'; end if;
      elsif v_mime = 'application/pdf' then
        v_kind := 'file';
      else
        raise exception 'file type not allowed' using errcode = '22023';
      end if;
    end loop;
  end if;

  insert into public.messages (id, thread_id, space_id, author_id, kind, body, reply_to)
  values (p_id, p_thread, v_thread.space_id, v_me, v_kind, v_body, p_reply_to);

  for v_att in select * from jsonb_array_elements(coalesce(p_attachments, '[]'::jsonb)) loop
    insert into public.message_attachments
      (message_id, storage_path, mime, bytes, width, height, duration_ms, sort)
    values (p_id, v_att ->> 'path', v_att ->> 'mime',
            nullif(v_att ->> 'bytes', '')::bigint,
            nullif(v_att ->> 'width', '')::int,
            nullif(v_att ->> 'height', '')::int,
            nullif(v_att ->> 'duration_ms', '')::int,
            v_n);
    -- Documents posted in chat go to the Library too ("From chat").
    if v_att ->> 'mime' = 'application/pdf' then
      insert into public.library_files
        (id, space_id, team_id, name, storage_path, mime, bytes, source,
         source_message_id, uploaded_by)
      values (gen_random_uuid(), v_thread.space_id, v_thread.team_id,
              left(coalesce(nullif(v_att ->> 'name', ''),
                            split_part(v_att ->> 'path', '/', 4)), 120),
              v_att ->> 'path', 'application/pdf',
              nullif(v_att ->> 'bytes', '')::bigint, 'chat', p_id, v_me);
    end if;
    v_n := v_n + 1;
  end loop;

  return p_id;
end;
$$;

-- Delete a message: its author or a Space admin. It stays as "Message
-- deleted" (no text, files hidden). Library copies from that message go
-- too, unless a work item uses them.
create or replace function public.delete_message(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_msg public.messages;
begin
  select * into v_msg from public.messages where id = p_id for update;
  if v_msg.id is null or not public.can_use_thread(v_msg.thread_id)
     or v_msg.kind = 'work_item'
     or not (v_msg.author_id = auth.uid() or public.is_space_admin(v_msg.space_id)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_msg.deleted_at is not null then
    return;
  end if;
  update public.messages
  set deleted_at = now(), deleted_by = auth.uid(), body = null
  where id = p_id;
  update public.library_files f
  set deleted_at = now(), deleted_by = auth.uid()
  where f.source_message_id = p_id and f.deleted_at is null
    and not exists (select 1 from public.work_item_attachments a where a.library_file_id = f.id);
end;
$$;

-- "Read up to now" for the caller in [p_thread].
create or replace function public.mark_thread_read(p_thread uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_use_thread(p_thread) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  insert into public.thread_reads (thread_id, profile_id, last_read_at)
  values (p_thread, auth.uid(), now())
  on conflict (thread_id, profile_id) do update set last_read_at = excluded.last_read_at;
end;
$$;

-- S7k: the caller's threads in [p_space] — Everyone first, then Teams —
-- with the last message and how many are unread (others' messages after
-- your last read). Only threads you can use.
create or replace function public.space_threads(p_space uuid)
returns table (
  thread_id uuid,
  team_id uuid,
  team_name text,
  last_message_id uuid,
  last_kind text,
  last_body text,
  last_author_id uuid,
  last_at timestamptz,
  last_deleted boolean,
  unread integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id, t.team_id, tm.name,
         lm.id, lm.kind, lm.body, lm.author_id, lm.created_at, lm.deleted_at is not null,
         (select count(*)::int from public.messages m
          where m.thread_id = t.id and m.deleted_at is null
            and m.author_id is distinct from auth.uid()
            and m.created_at > coalesce(
              (select r.last_read_at from public.thread_reads r
               where r.thread_id = t.id and r.profile_id = auth.uid()), '-infinity'))
  from public.threads t
  left join public.teams tm on tm.id = t.team_id
  left join lateral (
    select m.* from public.messages m where m.thread_id = t.id
    order by m.created_at desc limit 1) lm on true
  where t.space_id = p_space and public.can_use_thread(t.id)
  order by (t.team_id is not null), lm.created_at desc nulls last, tm.name;
$$;

-- ---------------------------------------------------------------------------
-- Work item cards in chat
-- ---------------------------------------------------------------------------

create or replace function public.handle_work_item_event_card()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.work_items;
  v_thread uuid;
begin
  if new.kind not in ('raised', 'done', 'checked', 'sent_back', 'reassigned') then
    return new;
  end if;
  select * into v_item from public.work_items where id = new.work_item_id;
  -- The item's Team thread, when its owner is in that Team; otherwise
  -- Everyone, so the people working on it always see the card.
  if v_item.team_id is not null and exists (
       select 1 from public.team_members m
       where m.team_id = v_item.team_id and m.profile_id = v_item.owner_id) then
    select t.id into v_thread from public.threads t where t.team_id = v_item.team_id;
  end if;
  if v_thread is null then
    select t.id into v_thread from public.threads t
    where t.space_id = v_item.space_id and t.team_id is null;
  end if;
  if v_thread is null then
    return new;
  end if;
  insert into public.messages (id, thread_id, space_id, author_id, kind,
                               work_item_id, work_item_event_id, created_at)
  values (gen_random_uuid(), v_thread, v_item.space_id, new.actor_id, 'work_item',
          v_item.id, new.id, new.created_at);
  return new;
end;
$$;

create trigger work_item_events_card
  after insert on public.work_item_events
  for each row execute function public.handle_work_item_event_card();

-- ---------------------------------------------------------------------------
-- Library functions
-- ---------------------------------------------------------------------------

-- S13k "Add": register a file you uploaded to <space>/library/<p_id>/.
-- A Team file needs you to be in the Team (or an admin).
create or replace function public.add_library_file(
  p_id uuid,
  p_space uuid,
  p_name text,
  p_path text,
  p_mime text,
  p_bytes bigint default null,
  p_team uuid default null,
  p_rev_label text default null,
  p_note text default null,
  p_supersedes uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can(p_space, 'add_files') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if exists (select 1 from public.library_files f where f.id = p_id) then
    raise exception 'this id is taken' using errcode = '22023';
  end if;
  if p_path is null or p_path not like p_space::text || '/library/' || p_id::text || '/%'
     or p_path like '%..%' or array_length(string_to_array(p_path, '/'), 1) <> 4
     or not public.is_my_upload(p_path) then
    raise exception 'file not uploaded' using errcode = '22023';
  end if;
  if public.upload_mime(p_path, p_mime) is distinct from p_mime then
    raise exception 'file type does not match the upload' using errcode = '22023';
  end if;
  if p_mime is null or not (p_mime like 'image/%' or p_mime = 'application/pdf') then
    raise exception 'file type not allowed' using errcode = '22023';
  end if;
  if p_team is not null and not exists (
       select 1 from public.teams t where t.id = p_team and t.space_id = p_space
         and (public.is_space_admin(p_space)
              or exists (select 1 from public.team_members m
                         where m.team_id = t.id and m.profile_id = auth.uid()))) then
    raise exception 'not allowed for this Team' using errcode = '42501';
  end if;
  if p_supersedes is not null and not exists (
       select 1 from public.library_files f
       where f.id = p_supersedes and f.space_id = p_space
         and f.team_id is not distinct from p_team
         and public.can_read_library_file(f.id)) then
    raise exception 'the older file is not in this Space or Team' using errcode = '22023';
  end if;
  insert into public.library_files
    (id, space_id, team_id, name, storage_path, mime, bytes, rev_label, note,
     supersedes_id, uploaded_by)
  values (p_id, p_space, p_team, trim(p_name), p_path, p_mime, p_bytes,
          nullif(trim(p_rev_label), ''), nullif(trim(p_note), ''), p_supersedes, auth.uid());
  return p_id;
end;
$$;

-- Remove a Library file: its uploader or a Space admin. A file a work item
-- uses stays in the record.
create or replace function public.delete_library_file(p_file uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_file public.library_files;
begin
  select * into v_file from public.library_files where id = p_file for update;
  if v_file.id is null or not public.can_read_library_file(p_file)
     or not (v_file.uploaded_by = auth.uid() or public.is_space_admin(v_file.space_id)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if exists (select 1 from public.work_item_attachments a where a.library_file_id = p_file) then
    raise exception 'a work item uses this file' using errcode = 'P0001';
  end if;
  update public.library_files set deleted_at = now(), deleted_by = auth.uid() where id = p_file;
end;
$$;

-- W2-A / W3 "Attached": attach a Library file to a work item. The item's
-- creator, owner, or a member who may check items. A Team file only on
-- that Team's items (an Everyone file on any item).
create or replace function public.attach_library_file(p_item uuid, p_file uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.work_items;
  v_file public.library_files;
begin
  select * into v_item from public.work_items where id = p_item;
  select * into v_file from public.library_files where id = p_file;
  if v_item.id is null or v_file.id is null
     or v_item.space_id <> v_file.space_id
     or not public.is_member(v_item.space_id)
     or not public.can_read_library_file(p_file)
     or not (auth.uid() in (v_item.created_by, v_item.owner_id)
             or public.can(v_item.space_id, 'check_items')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_file.team_id is not null and v_file.team_id is distinct from v_item.team_id then
    raise exception 'a Team file can only go on that Team''s items' using errcode = '22023';
  end if;
  insert into public.work_item_attachments (work_item_id, library_file_id, added_by)
  values (p_item, p_file, auth.uid())
  on conflict do nothing;
end;
$$;

-- A Team with chat messages or Library files is kept for the record:
-- delete_team refuses it (rename it instead). Otherwise as in migration 6.
create or replace function public.delete_team(p_team uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_space uuid := (select t.space_id from public.teams t where t.id = p_team);
begin
  if v_space is null or not public.is_space_admin(v_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if exists (select 1 from public.messages m join public.threads t on t.id = m.thread_id
             where t.team_id = p_team)
     or exists (select 1 from public.library_files f where f.team_id = p_team) then
    raise exception 'this Team has chat or files; it stays in the record' using errcode = 'P0001';
  end if;
  delete from public.teams where id = p_team;
end;
$$;

-- Work item evidence must be a photo by its stored type too, not only
-- by its name (as in migration 7 otherwise).
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
    if not exists (select 1 from storage.objects o
                   where o.bucket_id = 'space-files' and o.name = v_path
                     and o.owner_id = auth.uid()::text) then
      raise exception 'photo not uploaded' using errcode = '22023';
    end if;
    if coalesce(public.upload_mime(v_path, null), 'image/') not like 'image/%' then
      raise exception 'evidence must be a photo' using errcode = '22023';
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
-- Row-level security and grants
-- ---------------------------------------------------------------------------

alter table public.threads enable row level security;
alter table public.messages enable row level security;
alter table public.message_attachments enable row level security;
alter table public.thread_reads enable row level security;
alter table public.library_files enable row level security;
alter table public.work_item_attachments enable row level security;

create policy threads_read on public.threads
  for select to authenticated using (public.can_use_thread(id));
create policy messages_read on public.messages
  for select to authenticated using (public.can_use_thread(thread_id));
create policy message_attachments_read on public.message_attachments
  for select to authenticated
  using (exists (select 1 from public.messages m
                 where m.id = message_id and m.deleted_at is null
                   and public.can_use_thread(m.thread_id)));
create policy thread_reads_read_own on public.thread_reads
  for select to authenticated using (profile_id = auth.uid());
create policy library_files_read on public.library_files
  for select to authenticated using (public.can_read_library_file(id));
create policy work_item_attachments_read on public.work_item_attachments
  for select to authenticated
  using (public.can_read_library_file(library_file_id)
         and exists (select 1 from public.work_items w
                     where w.id = work_item_id and public.is_member(w.space_id)));

revoke all on public.threads, public.messages, public.message_attachments,
  public.thread_reads, public.library_files, public.work_item_attachments
  from anon, authenticated;
grant select on public.threads, public.messages, public.message_attachments,
  public.thread_reads, public.library_files, public.work_item_attachments
  to authenticated;

revoke execute on function
  public.handle_space_thread(),
  public.handle_team_thread(),
  public.can_use_thread(uuid),
  public.can_read_library_file(uuid),
  public.is_my_upload(text),
  public.is_referenced_file(text),
  public.loose_uploads(),
  public.orphan_space_files(interval),
  public.folder_has_others_files_in(text),
  public.uploads_today(),
  public.upload_mime(text, text),
  public.may_upload(text),
  public.may_read_file(text, text),
  public.may_delete_file(text, text),
  public.post_message(uuid, uuid, text, uuid, jsonb),
  public.delete_message(uuid),
  public.mark_thread_read(uuid),
  public.space_threads(uuid),
  public.handle_work_item_event_card(),
  public.add_library_file(uuid, uuid, text, text, text, bigint, uuid, text, text, uuid),
  public.delete_library_file(uuid),
  public.attach_library_file(uuid, uuid)
  from public, anon, authenticated;

-- Policies call these as the signed-in user.
grant execute on function
  -- Only your own files (as in migration 8).
  public.loose_uploads(),
  public.can_use_thread(uuid),
  public.can_read_library_file(uuid),
  public.may_upload(text),
  public.may_read_file(text, text),
  public.may_delete_file(text, text),
  public.post_message(uuid, uuid, text, uuid, jsonb),
  public.delete_message(uuid),
  public.mark_thread_read(uuid),
  public.space_threads(uuid),
  public.add_library_file(uuid, uuid, text, text, text, bigint, uuid, text, text, uuid),
  public.delete_library_file(uuid),
  public.attach_library_file(uuid, uuid)
  to authenticated;
grant execute on function public.orphan_space_files(interval) to service_role;

-- Live chat (Supabase Realtime respects the policies above).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;
