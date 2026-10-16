-- Migration 22: direct messages (review 33 A5; founder decision F10 in
-- docs/product/space-scenarios.md: we manage, we don't block). Branch
-- dm-db. Not live.
--
-- - Anyone can message anyone, as much as they like, with photos, files
--   and voice notes. Someone with no work link to you (no shared active
--   Space, not following each other both ways) lands in Message requests.
--   Replying opens the thread; declining hides it quietly; blocking stops it.
-- - dm_threads (one per pair), dm_members (each person's state: open,
--   request, declined), dm_messages, dm_attachments, and the private bucket
--   dm-files at <author>/<message>/<file> (not A5's <thread>/...: a new
--   thread's id is only known once the first message is sent, and the
--   account purge finds a person's files by their own folder).
-- - The spam guard: someone who keeps starting threads with new people who
--   never reply gets a warning, then a pause for new people only. The
--   limits live in app_settings (dm_unanswered_limit), changed by SQL with
--   the founder's yes, no release.
-- - Pushes: one per new person for a request (none within 30 days of a
--   decline), and like Space chat for open threads (one per thread every 5
--   minutes, text only if the person chose). No Activity rows. The push
--   function needs its new texts deployed before this goes live.
-- - Reports of a message (dm_message), the account purge, Download my data
--   and the cleanup include direct messages.
--
-- Choices confirmed in review 41:
-- - Files live in the sender's folder; reading one always goes through its
--   message (the two people, no block, not deleted, not reported by you).
-- - A request becomes an open thread as soon as the two get a work link (a
--   shared Space or a mutual follow), and stays open if the link ends.
-- - Decline sits in the request thread's strip (Not in your Spaces ·
--   Decline · Block); Mute in the thread's ⋯ menu.
-- - A purged person's threads stay for the other person ("Former member");
--   a thread with both people purged goes.

-- ---------------------------------------------------------------------------
-- Settings the founder changes by SQL
-- ---------------------------------------------------------------------------

create table public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.app_settings enable row level security;
revoke all on public.app_settings from anon, authenticated;
grant all on public.app_settings to service_role;

insert into public.app_settings (key, value)
values ('dm_unanswered_limit', '{"limit": 50, "warn_at": 40, "days": 30}')
on conflict (key) do nothing;

-- The spam guard's limits, with these defaults if the row is missing or
-- malformed.
create or replace function public.dm_settings()
returns table (lim integer, warn_at integer, days integer)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select (s.value ->> 'limit')::integer from public.app_settings s
                   where s.key = 'dm_unanswered_limit' and jsonb_typeof(s.value -> 'limit') = 'number'), 50),
         coalesce((select (s.value ->> 'warn_at')::integer from public.app_settings s
                   where s.key = 'dm_unanswered_limit' and jsonb_typeof(s.value -> 'warn_at') = 'number'), 40),
         coalesce((select (s.value ->> 'days')::integer from public.app_settings s
                   where s.key = 'dm_unanswered_limit' and jsonb_typeof(s.value -> 'days') = 'number'), 30);
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

-- One thread per pair (a_id < b_id). A purged person becomes null, and the
-- other keeps the thread ("Former member").
create table public.dm_threads (
  id uuid primary key,
  a_id uuid references public.profiles (id) on delete set null,
  b_id uuid references public.profiles (id) on delete set null,
  started_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  unique (a_id, b_id),
  check (a_id < b_id)
);
create index dm_threads_a_idx on public.dm_threads (a_id);
create index dm_threads_b_idx on public.dm_threads (b_id);
create index dm_threads_started_idx on public.dm_threads (started_by, created_at);

create table public.dm_members (
  thread_id uuid not null references public.dm_threads (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  state text not null check (state in ('open', 'request', 'declined')),
  last_read_at timestamptz,
  declined_at timestamptz,
  -- The request push was sent (or due) for this request: one per new person.
  request_pushed_at timestamptz,
  muted boolean not null default false,
  primary key (thread_id, profile_id)
);
create index dm_members_profile_idx on public.dm_members (profile_id, state);

create table public.dm_messages (
  id uuid primary key,
  thread_id uuid not null references public.dm_threads (id) on delete cascade,
  author_id uuid references public.profiles (id) on delete set null,
  kind text not null check (kind in ('text', 'photo', 'file', 'voice')),
  body text check (char_length(body) <= 3000),
  reply_to uuid references public.dm_messages (id) on delete set null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index dm_messages_thread_idx on public.dm_messages (thread_id, created_at desc, id desc);
create index dm_messages_author_idx on public.dm_messages (author_id, created_at desc);

create table public.dm_attachments (
  message_id uuid not null references public.dm_messages (id) on delete cascade,
  storage_path text primary key,
  name text check (name is null or char_length(name) between 1 and 120),
  mime text not null,
  bytes bigint,
  width integer,
  height integer,
  duration_ms integer,
  sort integer not null default 0
);
create index dm_attachments_message_idx on public.dm_attachments (message_id, sort);

create trigger dm_threads_hidden_writer before insert on public.dm_threads
  for each row execute function public.refuse_hidden_writer();
create trigger dm_members_hidden_writer before insert on public.dm_members
  for each row execute function public.refuse_hidden_writer();
create trigger dm_messages_hidden_writer before insert on public.dm_messages
  for each row execute function public.refuse_hidden_writer();
create trigger dm_attachments_hidden_writer before insert on public.dm_attachments
  for each row execute function public.refuse_hidden_writer();
-- A file the cleanup claimed can't be attached (migration 10).
create trigger dm_attachments_not_claimed before insert or update of storage_path
  on public.dm_attachments for each row execute function public.refuse_claimed_file();

-- The thread's newest message time, for the list.
create or replace function public.handle_dm_message_time()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.dm_threads set last_message_at = new.created_at
  where id = new.thread_id and last_message_at < new.created_at;
  return null;
end;
$$;
create trigger dm_messages_time after insert on public.dm_messages
  for each row execute function public.handle_dm_message_time();

-- ---------------------------------------------------------------------------
-- Who reads what
-- ---------------------------------------------------------------------------

-- An explicit block either way (not the hidden-account rule of
-- blocked_between: a person waiting for deletion stays in the thread as
-- "Former member").
create or replace function public.dm_blocked(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.blocks b
                 where (b.blocker_id = p_a and b.blocked_id = p_b)
                    or (b.blocker_id = p_b and b.blocked_id = p_a));
$$;

-- The other person of [p_thread] for [p_me] (null when purged).
create or replace function public.dm_other(p_thread public.dm_threads, p_me uuid)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case when p_thread.a_id = p_me then p_thread.b_id else p_thread.a_id end;
$$;

-- The caller may read [p_thread]: one of its two people, with no block
-- between them.
create or replace function public.can_read_dm(p_thread uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.dm_threads t
    where t.id = p_thread and auth.uid() in (t.a_id, t.b_id)
      and not public.dm_blocked(auth.uid(), public.dm_other(t, auth.uid())));
$$;

-- A work link: an active Space both are in, or each follows the other.
create or replace function public.dm_work_link(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.space_members m1
                 join public.space_members m2 on m2.space_id = m1.space_id
                 join public.spaces s on s.id = m1.space_id and s.deleted_at is null
                 where m1.profile_id = p_a and m2.profile_id = p_b
                   and m1.left_at is null and m2.left_at is null)
      or (exists (select 1 from public.follows f where f.follower_id = p_a and f.followee_id = p_b)
          and exists (select 1 from public.follows f where f.follower_id = p_b and f.followee_id = p_a));
$$;

-- A person as a thread shows them: no name, photo or line for someone
-- purged, waiting for deletion ("Former member") or across a block.
create or replace function public.dm_person(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p.id is null or p.deletion_scheduled_at is not null or public.dm_blocked(auth.uid(), p.id)
      then jsonb_build_object('id', p_id, 'former', true)
    else jsonb_strip_nulls(jsonb_build_object(
      'id', p.id,
      'name', nullif(trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), ''),
      'photo_path', p.photo_path, 'headline', p.headline,
      'company', coalesce((select c.name from public.companies c where c.id = p.company_id),
                          p.company_name_text)))
  end
  from (select 1) one
  left join public.profiles p on p.id = p_id;
$$;

alter table public.dm_threads enable row level security;
alter table public.dm_members enable row level security;
alter table public.dm_messages enable row level security;
alter table public.dm_attachments enable row level security;

create policy dm_threads_read on public.dm_threads
  for select to authenticated using (public.can_read_dm(id));
-- Your own row only: the other person never learns your state, when you
-- read or whether you muted (no read receipts; a decline isn't told).
create policy dm_members_read on public.dm_members
  for select to authenticated
  using (profile_id = auth.uid() and public.can_read_dm(thread_id));
-- A message you reported is hidden for you at once.
create policy dm_messages_read on public.dm_messages
  for select to authenticated
  using (public.can_read_dm(thread_id) and not public.reported_by_me('dm_message', id));
create policy dm_attachments_read on public.dm_attachments
  for select to authenticated
  using (exists (select 1 from public.dm_messages m
                 where m.id = message_id and m.deleted_at is null
                   and public.can_read_dm(m.thread_id)
                   and not public.reported_by_me('dm_message', m.id)));

revoke all on public.dm_threads, public.dm_members, public.dm_messages, public.dm_attachments
  from anon, authenticated;
grant select on public.dm_threads, public.dm_members, public.dm_messages, public.dm_attachments
  to authenticated;
grant all on public.dm_threads, public.dm_members, public.dm_messages, public.dm_attachments
  to service_role;

-- Live updates in an open thread, through the same read rule.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.dm_messages;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Files: bucket dm-files, <author>/<message>/<file>
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('dm-files', 'dm-files', false, 26214400,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf',
              'audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/x-m4a'])
on conflict (id) do nothing;

-- Upload: into your own folder, for a message not sent yet, a photo, PDF
-- or voice note; within the daily upload cap (shared with Space files).
create or replace function public.may_upload_dm_file(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_parts text[] := string_to_array(p_name, '/');
  v_id uuid;
  v_files bigint;
  v_bytes bigint;
begin
  if auth.uid() is null or public.is_hidden_account(auth.uid()) or p_name like '%..%'
     or array_length(v_parts, 1) <> 3 or v_parts[1] <> auth.uid()::text or v_parts[3] = ''
     or lower(v_parts[3]) !~ '\.(jpe?g|png|webp|heic|pdf|m4a|aac|mp3|mp4)$' then
    return false;
  end if;
  begin
    v_id := v_parts[2]::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  if exists (select 1 from public.dm_messages m where m.id = v_id) then
    return false;
  end if;
  select files, bytes into v_files, v_bytes from public.uploads_today();
  return v_files < 300 and v_bytes < 500 * 1024 * 1024;
end;
$$;

-- Read: a file of a message you may read (the two people, never across a
-- block, not once deleted, not once you reported it), its sender included
-- (review 41); and your own upload before it is sent.
create or replace function public.may_read_dm_file(p_name text, p_owner text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (p_owner = auth.uid()::text
          and not exists (select 1 from public.dm_attachments a where a.storage_path = p_name))
      or exists (select 1 from public.dm_attachments a
                 join public.dm_messages m on m.id = a.message_id
                 where a.storage_path = p_name and m.deleted_at is null
                   and public.can_read_dm(m.thread_id)
                   and not public.reported_by_me('dm_message', m.id));
$$;

create policy dm_files_read on storage.objects
  for select to authenticated
  using (bucket_id = 'dm-files' and public.may_read_dm_file(name, owner_id));
create policy dm_files_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'dm-files' and public.may_upload_dm_file(name));
-- Delete (Storage API): your own file that no live message uses.
create policy dm_files_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'dm-files' and owner_id = auth.uid()::text
         and not exists (select 1 from public.dm_attachments a
                         join public.dm_messages m on m.id = a.message_id
                         where a.storage_path = objects.name and m.deleted_at is null));
-- No update policy: a file is never replaced.

-- Files no live message uses, older than a day: claimed under the per-file
-- lock, then the cleanup job deletes them with the Storage API (as
-- orphan_note_files). A deleted message's files go too.
create or replace function public.orphan_dm_files(p_age interval default interval '7 days')
returns table (name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  for v_name in
    select o.name from storage.objects o
    where o.bucket_id = 'dm-files'
      and o.created_at < now() - greatest(p_age, interval '1 day')
      and not exists (select 1 from public.dm_attachments a
                      join public.dm_messages m on m.id = a.message_id
                      where a.storage_path = o.name and m.deleted_at is null)
      -- Kept while its removal can still be appealed (as orphan_post_media).
      and not exists (select 1 from public.dm_attachments a
                      join public.content_removals c
                        on c.target_kind = 'dm_message' and c.target_id = a.message_id
                      where a.storage_path = o.name
                        and (c.appeal_status = 'open' or c.removed_at > now() - interval '14 days'))
    order by o.created_at
  loop
    perform public.lock_file_path(v_name);
    if not exists (select 1 from public.dm_attachments a
                   join public.dm_messages m on m.id = a.message_id
                   where a.storage_path = v_name and m.deleted_at is null)
      -- Kept while its removal can still be appealed (as orphan_post_media).
       and not exists (select 1 from public.dm_attachments a
                      join public.content_removals c
                        on c.target_kind = 'dm_message' and c.target_id = a.message_id
                      where a.storage_path = v_name
                        and (c.appeal_status = 'open' or c.removed_at > now() - interval '14 days')) then
      insert into public.file_cleanup_claims (storage_path) values (v_name)
      on conflict (storage_path) do nothing;
      name := v_name;
      return next;
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------

-- Distinct people [p_sender] started a thread with in the last [p_days]
-- who are still in request or declined and never wrote back (a deleted
-- reply still counts as a reply).
create or replace function public.dm_unanswered_count(p_sender uuid, p_days integer)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)
  from public.dm_threads t
  join public.dm_members r on r.thread_id = t.id and r.profile_id is distinct from p_sender
  where t.started_by = p_sender
    and t.created_at > now() - make_interval(days => p_days)
    and r.state in ('request', 'declined')
    and not exists (select 1 from public.dm_messages m
                    where m.thread_id = t.id and m.author_id = r.profile_id);
$$;

-- Post a message [p_id] in [p_thread] (internal: start_dm and send_dm).
-- [p_attachments] = [{path, name?, bytes?, width?, height?, duration_ms?}],
-- at most 10, the caller's uploads at <me>/<p_id>/<file>; a voice note on
-- its own. Replying opens a request; the sender writing again after a
-- decline makes it a request again; a work link opens it.
create or replace function public.dm_post(p_id uuid, p_thread uuid, p_body text, p_reply_to uuid,
                                          p_attachments jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_existing public.dm_messages;
  v_thread public.dm_threads;
  v_other uuid;
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_file jsonb;
  v_path text;
  v_mime text;
  v_kind text;
  v_kinds text[] := '{}';
  v_sort integer := 0;
begin
  if p_id is null then
    raise exception 'a message needs its id' using errcode = '22023';
  end if;
  -- The same id again (a retry): the same message, if it is the caller's.
  select * into v_existing from public.dm_messages where id = p_id;
  if v_existing.id is not null then
    if v_existing.author_id = v_me and v_existing.thread_id = p_thread then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  -- One sender at a time per thread, so the states change in order.
  select * into v_thread from public.dm_threads where id = p_thread for update;
  -- A double tap waited here: the first may have just sent it.
  select * into v_existing from public.dm_messages where id = p_id;
  if v_existing.id is not null then
    if v_existing.author_id = v_me and v_existing.thread_id = p_thread then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  v_other := public.dm_other(v_thread, v_me);
  if v_thread.id is null or v_me is null
     or (v_me is distinct from v_thread.a_id and v_me is distinct from v_thread.b_id)
     or v_other is null or public.is_hidden_account(v_me) or public.is_hidden_account(v_other)
     or public.dm_blocked(v_me, v_other) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if char_length(v_body) > 3000 then
    raise exception 'at most 3000 characters' using errcode = '22023';
  end if;
  if p_attachments is null or jsonb_typeof(p_attachments) = 'null' then
    p_attachments := '[]'::jsonb;
  end if;
  if jsonb_typeof(p_attachments) <> 'array' or jsonb_array_length(p_attachments) > 10 then
    raise exception 'at most 10 files' using errcode = '22023';
  end if;
  if (select count(*) <> count(distinct e ->> 'path') from jsonb_array_elements(p_attachments) e) then
    raise exception 'each file once' using errcode = '22023';
  end if;
  if v_body is null and jsonb_array_length(p_attachments) = 0 then
    raise exception 'write something or add a file' using errcode = '22023';
  end if;
  if p_reply_to is not null and not exists (
       select 1 from public.dm_messages m where m.id = p_reply_to and m.thread_id = p_thread) then
    raise exception 'a reply in the same thread' using errcode = '22023';
  end if;
  if (select count(*) from public.dm_messages m
      where m.author_id = v_me and m.created_at > now() - interval '1 minute') >= 30 then
    raise exception 'too many messages, wait a moment' using errcode = 'P0001';
  end if;

  -- The files: the caller's own uploads for this message.
  for v_file in select * from jsonb_array_elements(p_attachments) loop
    v_path := v_file ->> 'path';
    if jsonb_typeof(v_file) <> 'object' or v_path is null
       or v_path not like v_me::text || '/' || p_id::text || '/%'
       or array_length(string_to_array(v_path, '/'), 1) <> 3 then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    select nullif(o.metadata ->> 'mimetype', '') into v_mime from storage.objects o
    where o.bucket_id = 'dm-files' and o.name = v_path and o.owner_id = v_me::text;
    if not found then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    v_kinds := v_kinds || case when v_mime like 'image/%' then 'photo'
                               when v_mime = 'application/pdf' then 'file'
                               when v_mime like 'audio/%' then 'voice' end;
    if v_kinds[array_length(v_kinds, 1)] is null then
      raise exception 'photos, PDFs and voice notes only' using errcode = '22023';
    end if;
  end loop;
  if 'voice' = any (v_kinds) and (array_length(v_kinds, 1) > 1 or v_body is not null) then
    raise exception 'a voice note goes on its own' using errcode = '22023';
  end if;
  v_kind := case when 'voice' = any (v_kinds) then 'voice'
                 when 'file' = any (v_kinds) then 'file'
                 when 'photo' = any (v_kinds) then 'photo'
                 else 'text' end;

  -- The states first, so the push sees them.
  update public.dm_members set state = 'open'
  where thread_id = p_thread and profile_id = v_me and state <> 'open';
  update public.dm_members m
  set state = case when public.dm_work_link(v_me, v_other) then 'open' else 'request' end,
      -- After 30 days a new request is a new person again: one push.
      request_pushed_at = case when m.declined_at < now() - interval '30 days' then null
                               else m.request_pushed_at end
  where m.thread_id = p_thread and m.profile_id = v_other and m.state = 'declined';
  update public.dm_members set state = 'open'
  where thread_id = p_thread and profile_id = v_other and state = 'request'
    and public.dm_work_link(v_me, v_other);

  insert into public.dm_messages (id, thread_id, author_id, kind, body, reply_to)
  values (p_id, p_thread, v_me, v_kind, v_body, p_reply_to);
  for v_file in select * from jsonb_array_elements(p_attachments) loop
    insert into public.dm_attachments (message_id, storage_path, name, mime, bytes, width, height,
                                       duration_ms, sort)
    select p_id, o.name,
           nullif(left(trim(coalesce(v_file ->> 'name', '')), 120), ''),
           o.metadata ->> 'mimetype',
           coalesce(nullif(o.metadata ->> 'size', '')::bigint, nullif(v_file ->> 'bytes', '')::bigint),
           nullif(v_file ->> 'width', '')::integer, nullif(v_file ->> 'height', '')::integer,
           nullif(v_file ->> 'duration_ms', '')::integer, v_sort
    from storage.objects o
    where o.bucket_id = 'dm-files' and o.name = v_file ->> 'path';
    v_sort := v_sort + 1;
  end loop;
  return p_id;
exception
  when invalid_text_representation then
    raise exception 'a file is not valid' using errcode = '22023';
end;
$$;

-- Message [p_to]: finds the pair's thread, or makes [p_thread] (the app's
-- id). With no work link the other person gets a request, and the spam
-- guard applies to this new person: a warning from warn_at people who
-- never replied, and no new person from limit (state 'paused', with the
-- day it frees up). Existing threads are never affected. Returns {thread,
-- state (the other person's), warning, until}.
create or replace function public.start_dm(p_thread uuid, p_to uuid, p_message uuid,
                                           p_body text default null,
                                           p_attachments jsonb default '[]'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_a uuid := least(auth.uid(), p_to);
  v_b uuid := greatest(auth.uid(), p_to);
  v_thread public.dm_threads;
  v_link boolean;
  v_warning boolean := false;
  v_n bigint;
  v_set record;
  v_until timestamptz;
  v_state text;
begin
  if v_me is null or public.is_hidden_account(v_me) or p_to is null or p_to = v_me
     or not exists (select 1 from public.profiles p where p.id = p_to)
     or public.is_hidden_account(p_to) or public.dm_blocked(v_me, p_to) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  -- Both people starting at once make one thread.
  perform pg_advisory_xact_lock(hashtextextended('dm_pair:' || v_a::text || v_b::text, 0));
  select * into v_thread from public.dm_threads where a_id = v_a and b_id = v_b;
  if v_thread.id is not null then
    perform public.dm_post(p_message, v_thread.id, p_body, null, p_attachments);
    select state into v_state from public.dm_members where thread_id = v_thread.id and profile_id = p_to;
    return jsonb_build_object('thread', v_thread.id, 'state', v_state, 'warning', false);
  end if;
  if p_thread is null or exists (select 1 from public.dm_threads t where t.id = p_thread) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  v_link := public.dm_work_link(v_me, p_to);
  if not v_link then
    -- One new person at a time per sender, so two at once can't both pass.
    perform pg_advisory_xact_lock(hashtextextended('dm_start:' || v_me::text, 0));
    select * into v_set from public.dm_settings();
    v_n := public.dm_unanswered_count(v_me, v_set.days);
    if v_n >= v_set.lim then
      select t.created_at + make_interval(days => v_set.days) into v_until
      from public.dm_threads t
      join public.dm_members r on r.thread_id = t.id and r.profile_id is distinct from v_me
      where t.started_by = v_me and t.created_at > now() - make_interval(days => v_set.days)
        and r.state in ('request', 'declined')
        and not exists (select 1 from public.dm_messages m
                        where m.thread_id = t.id and m.author_id = r.profile_id)
      order by t.created_at, t.id
      offset (v_n - v_set.lim) limit 1;
      return jsonb_build_object('thread', null, 'state', 'paused', 'warning', true, 'until', v_until);
    end if;
    v_warning := v_n >= v_set.warn_at;
  end if;

  insert into public.dm_threads (id, a_id, b_id, started_by) values (p_thread, v_a, v_b, v_me);
  insert into public.dm_members (thread_id, profile_id, state)
  values (p_thread, v_me, 'open'),
         (p_thread, p_to, case when v_link then 'open' else 'request' end);
  perform public.dm_post(p_message, p_thread, p_body, null, p_attachments);
  return jsonb_build_object('thread', p_thread, 'state', case when v_link then 'open' else 'request' end,
                            'warning', v_warning);
end;
$$;

-- Send [p_id] in a thread you are in (a reply opens a request).
create or replace function public.send_dm(p_id uuid, p_thread uuid, p_body text default null,
                                          p_reply_to uuid default null,
                                          p_attachments jsonb default '[]'::jsonb)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select public.dm_post(p_id, p_thread, p_body, p_reply_to, p_attachments);
$$;

-- Delete your own message: it shows as "Message deleted"; its files go to
-- the cleanup.
create or replace function public.delete_dm(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_msg public.dm_messages;
begin
  select * into v_msg from public.dm_messages where id = p_id for update;
  if v_msg.id is null or v_msg.author_id is distinct from auth.uid()
     or not public.can_read_dm(v_msg.thread_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_msg.deleted_at is null then
    update public.dm_messages set deleted_at = now(), body = null where id = p_id;
  end if;
end;
$$;

-- Read up to now (never shown to the other person).
create or replace function public.mark_dm_read(p_thread uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_read_dm(p_thread) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.dm_members set last_read_at = now()
  where thread_id = p_thread and profile_id = auth.uid();
end;
$$;

-- Decline a request: it leaves your list quietly; the sender isn't told.
create or replace function public.decline_dm(p_thread uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_state text;
begin
  select m.state into v_state from public.dm_members m
  where m.thread_id = p_thread and m.profile_id = auth.uid() for update;
  if v_state is null or not public.can_read_dm(p_thread) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_state = 'open' or (v_state = 'request' and public.dm_work_link(
       auth.uid(), (select public.dm_other(t, auth.uid()) from public.dm_threads t where t.id = p_thread))) then
    raise exception 'only a request can be declined' using errcode = 'P0001';
  end if;
  update public.dm_members set state = 'declined', declined_at = now()
  where thread_id = p_thread and profile_id = auth.uid() and state = 'request';
end;
$$;

-- No pushes from this thread ([p_on]), or pushes again.
create or replace function public.mute_dm(p_thread uuid, p_on boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_read_dm(p_thread) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.dm_members set muted = coalesce(p_on, true)
  where thread_id = p_thread and profile_id = auth.uid();
end;
$$;

-- A work link made now (joining a Space, a follow back) opens any request
-- between the two, for good: it doesn't go back if the link ends (review
-- 41). Declined threads stay declined.
create or replace function public.dm_open_linked(p_a uuid, p_b uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.dm_members m set state = 'open'
  from public.dm_threads t
  where t.id = m.thread_id and t.a_id = least(p_a, p_b) and t.b_id = greatest(p_a, p_b)
    and m.state = 'request' and public.dm_work_link(p_a, p_b);
$$;

create or replace function public.handle_dm_link_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_other uuid;
begin
  if new.left_at is not null then
    return null;
  end if;
  for v_other in
    select case when t.a_id = new.profile_id then t.b_id else t.a_id end
    from public.dm_members m
    join public.dm_threads t on t.id = m.thread_id
    join public.space_members o
      on o.space_id = new.space_id and o.left_at is null
     and o.profile_id = case when t.a_id = new.profile_id then t.b_id else t.a_id end
    where m.state = 'request' and new.profile_id in (t.a_id, t.b_id)
  loop
    perform public.dm_open_linked(new.profile_id, v_other);
  end loop;
  return null;
end;
$$;
create trigger space_members_dm_link after insert or update of left_at on public.space_members
  for each row execute function public.handle_dm_link_member();

create or replace function public.handle_dm_link_follow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.dm_open_linked(new.follower_id, new.followee_id);
  return null;
end;
$$;
create trigger follows_dm_link after insert on public.follows
  for each row execute function public.handle_dm_link_follow();

-- ---------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------

-- The first Space both are active in, for "Both in …"; never a count.
create or replace function public.dm_shared_space(p_thread uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('space_id', s.id, 'name', s.name)
  from public.dm_threads t
  join public.space_members m1 on m1.profile_id = auth.uid() and m1.left_at is null
  join public.space_members m2 on m2.space_id = m1.space_id
                              and m2.profile_id = public.dm_other(t, auth.uid())
                              and m2.left_at is null
  join public.spaces s on s.id = m1.space_id and s.deleted_at is null
  where t.id = p_thread and public.can_read_dm(t.id)
  order by greatest(m1.confirmed_at, m2.confirmed_at), s.id
  limit 1;
$$;

-- The last message the caller may see in [p_thread], for a list row.
create or replace function public.dm_preview(p_thread uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
           'from_me', m.author_id is not distinct from auth.uid(), 'kind', m.kind,
           'text', left(m.body, 120), 'deleted', m.deleted_at is not null,
           'file_name', (select a.name from public.dm_attachments a where a.message_id = m.id
                         and m.deleted_at is null order by a.sort limit 1),
           'duration_ms', (select a.duration_ms from public.dm_attachments a where a.message_id = m.id
                           and m.deleted_at is null order by a.sort limit 1),
           'at', m.created_at))
  from public.dm_messages m
  where m.thread_id = p_thread and not public.reported_by_me('dm_message', m.id)
  order by m.created_at desc, m.id desc
  limit 1;
$$;

-- One row of the list.
create or replace function public.dm_list_row(p_thread public.dm_threads, p_member public.dm_members)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'thread', p_thread.id,
    'person', public.dm_person(public.dm_other(p_thread, auth.uid())),
    'last_message_at', p_thread.last_message_at,
    'muted', p_member.muted,
    -- A dot, never a number.
    'unread', exists (select 1 from public.dm_messages m
                      where m.thread_id = p_thread.id and m.author_id is distinct from auth.uid()
                        and m.deleted_at is null
                        and m.created_at > coalesce(p_member.last_read_at, '-infinity'::timestamptz)
                        and not public.reported_by_me('dm_message', m.id)),
    'last', public.dm_preview(p_thread.id));
$$;

-- My threads, newest first, after the cursor ([p_before], [p_before_id]),
-- and on the first page the Message requests row (the newest request
-- only, never a count). A request with a work link now is a thread.
create or replace function public.my_dm_threads(p_before timestamptz default null,
                                                p_before_id uuid default null,
                                                p_limit integer default 30)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'threads', coalesce((
      select jsonb_agg(x.row order by x.at desc, x.id desc) from (
        select t.id, t.last_message_at as at, public.dm_list_row(t, m) as row
        from public.dm_members m
        join public.dm_threads t on t.id = m.thread_id
        where m.profile_id = auth.uid()
          and (m.state = 'open'
               or (m.state = 'request' and public.dm_work_link(auth.uid(), public.dm_other(t, auth.uid()))))
          and public.can_read_dm(t.id)
          and (p_before is null or (t.last_message_at, t.id) < (p_before, coalesce(p_before_id, t.id)))
        order by t.last_message_at desc, t.id desc
        limit least(greatest(coalesce(p_limit, 30), 1), 100)) x), '[]'::jsonb),
    'requests', case when p_before is null then (
      select jsonb_build_object('has', true, 'newest', public.dm_list_row(t, m))
      from public.dm_members m
      join public.dm_threads t on t.id = m.thread_id
      where m.profile_id = auth.uid() and m.state = 'request'
        and not public.dm_work_link(auth.uid(), public.dm_other(t, auth.uid()))
        and public.can_read_dm(t.id)
      order by t.last_message_at desc, t.id desc
      limit 1) end));
$$;

-- My Message requests, newest first.
create or replace function public.my_dm_requests()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(x.row order by x.at desc, x.id desc), '[]'::jsonb) from (
    select t.id, t.last_message_at as at, public.dm_list_row(t, m) as row
    from public.dm_members m
    join public.dm_threads t on t.id = m.thread_id
    where m.profile_id = auth.uid() and m.state = 'request'
      and not public.dm_work_link(auth.uid(), public.dm_other(t, auth.uid()))
      and public.can_read_dm(t.id)
    order by t.last_message_at desc, t.id desc
    limit 100) x;
$$;

-- A thread: the other person, my state, the shared Space, and messages
-- newest first after the cursor. Files from someone you haven't answered
-- (request or declined) come with tap_to_show (shown blurred until tapped).
create or replace function public.dm_thread_page(p_thread uuid, p_before timestamptz default null,
                                                 p_before_id uuid default null,
                                                 p_limit integer default 50)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when public.can_read_dm(t.id) then jsonb_build_object(
    'thread', t.id,
    'person', public.dm_person(public.dm_other(t, auth.uid())),
    'state', case when me.state = 'request'
                       and public.dm_work_link(auth.uid(), public.dm_other(t, auth.uid()))
                  then 'open' else me.state end,
    'muted', me.muted,
    'shared_space', public.dm_shared_space(t.id),
    'messages', coalesce((
      select jsonb_agg(x.row order by x.created_at desc, x.id desc) from (
        select m.id, m.created_at, jsonb_strip_nulls(jsonb_build_object(
                 'id', m.id, 'from_me', m.author_id is not distinct from auth.uid(),
                 'kind', m.kind, 'body', m.body, 'deleted', m.deleted_at is not null,
                 'created_at', m.created_at,
                 'reply_to', (select jsonb_strip_nulls(jsonb_build_object(
                                       'id', r.id, 'text', left(r.body, 120),
                                       'from_me', r.author_id is not distinct from auth.uid(),
                                       'deleted', r.deleted_at is not null))
                              from public.dm_messages r
                              where r.id = m.reply_to and not public.reported_by_me('dm_message', r.id)),
                 'tap_to_show', case when (me.state = 'declined'
                                           or (me.state = 'request'
                                               and not public.dm_work_link(auth.uid(), public.dm_other(t, auth.uid()))))
                                          and m.author_id is distinct from auth.uid()
                                          and exists (select 1 from public.dm_attachments a
                                                      where a.message_id = m.id)
                                     then true end,
                 'files', (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                    'path', a.storage_path, 'name', a.name, 'mime', a.mime,
                                    'bytes', a.bytes, 'width', a.width, 'height', a.height,
                                    'duration_ms', a.duration_ms)) order by a.sort)
                           from public.dm_attachments a
                           where a.message_id = m.id and m.deleted_at is null))) as row
        from public.dm_messages m
        where m.thread_id = t.id and not public.reported_by_me('dm_message', m.id)
          and (p_before is null or (m.created_at, m.id) < (p_before, coalesce(p_before_id, m.id)))
        order by m.created_at desc, m.id desc
        limit least(greatest(coalesce(p_limit, 50), 1), 200)) x), '[]'::jsonb)) end
  from public.dm_threads t
  join public.dm_members me on me.thread_id = t.id and me.profile_id = auth.uid()
  where t.id = p_thread;
$$;

-- ---------------------------------------------------------------------------
-- Pushes
-- ---------------------------------------------------------------------------

alter table public.push_queue
  add column dm_thread_id uuid references public.dm_threads (id) on delete cascade;
alter table public.push_queue drop constraint push_queue_kind_check;
alter table public.push_queue add constraint push_queue_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'announcement_new', 'checklist_for_you', 'activity_invited', 'activity_starting',
  'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow', 'post_reply', 'chat_message',
  'dm_message', 'dm_request'));
create index push_queue_dm_thread_idx on public.push_queue (profile_id, dm_thread_id, created_at desc)
  where kind in ('dm_message', 'dm_request');

-- A new message: in an open thread, like Space chat (one push per thread
-- every 5 minutes, the text only if the person chose); a request, one push
-- per new person (none within 30 days of a decline), never with text. Not
-- when muted, declined, across a block or to a hidden account. No Activity
-- row. A push problem never blocks the message.
create or replace function public.handle_dm_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_to public.dm_members;
begin
  begin
    select * into v_to from public.dm_members m
    where m.thread_id = new.thread_id and m.profile_id is distinct from new.author_id;
    if v_to.profile_id is null or v_to.muted or v_to.state = 'declined'
       or public.is_hidden_account(v_to.profile_id)
       or public.dm_blocked(v_to.profile_id, new.author_id) then
      return null;
    end if;
    if v_to.state = 'request' then
      if v_to.request_pushed_at is not null
         and (v_to.declined_at is null or v_to.declined_at >= now() - interval '30 days'
              or v_to.request_pushed_at > v_to.declined_at + interval '30 days') then
        return null;
      end if;
      update public.dm_members set request_pushed_at = now()
      where thread_id = new.thread_id and profile_id = v_to.profile_id;
      if exists (select 1 from public.push_tokens t where t.profile_id = v_to.profile_id) then
        insert into public.push_queue (profile_id, kind, actor_id, dm_thread_id, data)
        values (v_to.profile_id, 'dm_request', new.author_id, new.thread_id,
                jsonb_build_object('dm_thread_id', new.thread_id, 'message_id', new.id));
      end if;
      return null;
    end if;
    insert into public.push_queue (profile_id, kind, actor_id, dm_thread_id, data, message_text)
    select v_to.profile_id, 'dm_message', new.author_id, new.thread_id,
           jsonb_build_object('dm_thread_id', new.thread_id, 'message_id', new.id),
           case when coalesce(ps.message_text, false) and new.kind = 'text' then left(new.body, 200) end
    from (select 1) one
    left join public.push_settings ps on ps.profile_id = v_to.profile_id
    where exists (select 1 from public.push_tokens t where t.profile_id = v_to.profile_id)
      and not exists (select 1 from public.push_queue q
                      where q.profile_id = v_to.profile_id and q.kind = 'dm_message'
                        and q.dm_thread_id = new.thread_id
                        and q.created_at > now() - interval '5 minutes');
  exception when others then
    raise warning 'push queue (direct message %): %', new.id, sqlerrm;
  end;
  return null;
end;
$$;
create trigger dm_messages_push after insert on public.dm_messages
  for each row execute function public.handle_dm_push();

-- A deleted or removed message: its text leaves any push not yet sent.
create or replace function public.handle_dm_deleted_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    update public.push_queue set message_text = null
    where kind = 'dm_message' and data ->> 'message_id' = new.id::text and sent_at is null;
  end if;
  return null;
end;
$$;
create trigger dm_messages_deleted_push after update of deleted_at on public.dm_messages
  for each row execute function public.handle_dm_deleted_push();

-- ---------------------------------------------------------------------------
-- Reports, the purge, the cleanup and the export
-- ---------------------------------------------------------------------------

alter table public.reports drop constraint reports_target_kind_check;
alter table public.reports add constraint reports_target_kind_check
  check (target_kind in ('post', 'reply', 'profile', 'message', 'dm_message'));
alter table public.content_removals drop constraint content_removals_target_kind_check;
alter table public.content_removals add constraint content_removals_target_kind_check
  check (target_kind in ('post', 'reply', 'message', 'dm_message'));

-- Reporting: also a direct message, by the person it was sent to (as in 20261013120000_safety.sql, with that change only).
CREATE OR REPLACE FUNCTION public.report(p_kind text, p_id uuid, p_reason text, p_note text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me uuid := auth.uid();
  v_author uuid;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_id uuid;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_kind not in ('post', 'reply', 'profile', 'message', 'dm_message') then
    raise exception 'post, reply, profile, message or direct message' using errcode = '22023';
  end if;
  if p_reason is null or p_reason not in ('spam', 'harassment', 'misleading', 'fake',
                                          'private_info', 'other') then
    raise exception 'choose a reason' using errcode = '22023';
  end if;
  if p_reason = 'other' and v_note is null then
    raise exception 'say what is wrong' using errcode = '22023';
  end if;
  if length(v_note) > 500 then
    raise exception 'at most 500 characters' using errcode = '22023';
  end if;

  -- Already reported (and so hidden for you now): the same report.
  select r.id into v_id from public.reports r
  where r.reporter_id = v_me and r.target_kind = p_kind and r.target_id = p_id;
  if v_id is not null then
    return v_id;
  end if;

  -- Only what you can see.
  v_author := case p_kind
    when 'post' then (select p.author_id from public.posts p
                      where p.id = p_id and public.can_see_post(p.id))
    when 'reply' then (select r.author_id from public.post_replies r
                       where r.id = p_id and r.deleted_at is null
                         and public.can_see_post(r.post_id)
                         and not public.is_blocked_with(r.author_id))
    when 'message' then (select m.author_id from public.messages m
                         where m.id = p_id and m.deleted_at is null and m.kind <> 'work_item'
                           and public.can_use_thread(m.thread_id))
    when 'dm_message' then (select m.author_id from public.dm_messages m where m.id = p_id and m.deleted_at is null
                              and public.can_read_dm(m.thread_id))
    when 'profile' then (select pr.id from public.profiles pr
                         where pr.id = p_id and not public.is_blocked_with(pr.id))
  end;
  if v_author is null then
    raise exception 'not found' using errcode = '42501';
  end if;
  if v_author = v_me then
    raise exception 'you can''t report your own' using errcode = '22023';
  end if;

  -- At most 20 a day, counted under a per-person lock.
  perform pg_advisory_xact_lock(hashtextextended('report:' || v_me::text, 0));
  -- A double tap: the first call may have just made it.
  select r.id into v_id from public.reports r
  where r.reporter_id = v_me and r.target_kind = p_kind and r.target_id = p_id;
  if v_id is not null then
    return v_id;
  end if;
  if (select count(*) from public.reports r
      where r.reporter_id = v_me and r.created_at > now() - interval '1 day') >= 20 then
    raise exception 'too many reports today' using errcode = 'P0001';
  end if;

  insert into public.reports (reporter_id, target_kind, target_id, reason, note)
  values (v_me, p_kind, p_id, p_reason, v_note)
  returning id into v_id;
  return v_id;
end;
$function$;

-- Moderation: a direct message is removed like a Space message (as in 20261015120000_daybook.sql, with that change only).
CREATE OR REPLACE FUNCTION public.decide_report(p_id uuid, p_action text, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_report public.reports;
  v_author uuid;
  v_body text;
  v_link uuid;
  v_files uuid[] := '{}';
  v_removal uuid;
begin
  if p_action is null or p_action not in ('remove', 'dismiss') then
    raise exception 'remove or dismiss' using errcode = '22023';
  end if;
  select * into v_report from public.reports where id = p_id for update;
  if v_report.id is null then
    raise exception 'no such report' using errcode = 'P0002';
  end if;
  if v_report.status <> 'open' then
    raise exception 'already decided' using errcode = 'P0001';
  end if;
  if p_action = 'dismiss' then
    update public.reports set status = 'dismissed', decided_at = now()
    where target_kind = v_report.target_kind and target_id = v_report.target_id
      and status = 'open';
    return null;
  end if;
  if v_report.target_kind = 'profile' then
    raise exception 'a person is not removed: block, or ask them to leave' using errcode = '22023';
  end if;

  case v_report.target_kind
    when 'post' then
      select author_id, body into v_author, v_body from public.posts
      where id = v_report.target_id and deleted_at is null for update;
      if v_author is not null then
        update public.posts set deleted_at = now(), body = null where id = v_report.target_id;
      end if;
    when 'reply' then
      select author_id, body into v_author, v_body from public.post_replies
      where id = v_report.target_id and deleted_at is null for update;
      if v_author is not null then
        update public.post_replies set deleted_at = now(), body = null where id = v_report.target_id;
      end if;
    when 'message' then
      -- As delete_message: the Library copy from chat goes too (unless a
      -- work item uses it). Kept aside, so a reversed appeal restores both.
      select author_id, body, library_file_id into v_author, v_body, v_link
      from public.messages
      where id = v_report.target_id and deleted_at is null for update;
      if v_author is not null then
        update public.messages set deleted_at = now(), body = null, library_file_id = null
        where id = v_report.target_id;
        select coalesce(array_agg(f.id), '{}') into v_files
        from public.library_files f
        where f.source_message_id = v_report.target_id and f.deleted_at is null
          and not public.library_file_in_use(f.id);
        update public.library_files set deleted_at = now() where id = any(v_files);
      end if;
    when 'dm_message' then
      select author_id, body into v_author, v_body from public.dm_messages
      where id = v_report.target_id and deleted_at is null for update;
      if v_author is not null then
        update public.dm_messages set deleted_at = now(), body = null where id = v_report.target_id;
      end if;
  end case;

  update public.reports set status = 'removed', decided_at = now()
  where target_kind = v_report.target_kind and target_id = v_report.target_id
    and status = 'open';
  -- Already deleted by its author, or the account is gone: nothing to tell.
  if v_author is null then
    return null;
  end if;

  insert into public.content_removals (target_kind, target_id, author_id, reason, report_id)
  values (v_report.target_kind, v_report.target_id, v_author,
          coalesce(p_reason, v_report.reason), v_report.id)
  returning id into v_removal;
  insert into public.removed_content (removal_id, body, library_file_id, library_files)
  values (v_removal, v_body, v_link, v_files);
  perform public.add_notification(v_author, 'content_removed', null,
    p_payload => jsonb_build_object('removal_id', v_removal, 'target_kind', v_report.target_kind));
  return v_removal;
end;
$function$;

-- Appeals: a reversed removal brings a direct message back (as in 20261013120000_safety.sql, with that change only).
CREATE OR REPLACE FUNCTION public.decide_appeal(p_removal uuid, p_action text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_row public.content_removals;
  v_saved public.removed_content;
  v_body text;
begin
  if p_action is null or p_action not in ('uphold', 'reverse') then
    raise exception 'uphold or reverse' using errcode = '22023';
  end if;
  select * into v_row from public.content_removals where id = p_removal for update;
  if v_row.id is null then
    raise exception 'no such removal' using errcode = 'P0002';
  end if;
  if v_row.appeal_status <> 'open' then
    raise exception 'no open appeal' using errcode = 'P0001';
  end if;
  if p_action = 'reverse' then
    select * into v_saved from public.removed_content where removal_id = p_removal;
    v_body := v_saved.body;
    case v_row.target_kind
      when 'post' then
        update public.posts set deleted_at = null, body = v_body where id = v_row.target_id;
      when 'reply' then
        update public.post_replies set deleted_at = null, body = v_body where id = v_row.target_id;
      when 'message' then
        update public.messages
        set deleted_at = null, body = v_body, library_file_id = v_saved.library_file_id
        where id = v_row.target_id;
        update public.library_files set deleted_at = null, deleted_by = null
        where id = any(v_saved.library_files);
      when 'dm_message' then
        update public.dm_messages set deleted_at = null, body = v_body where id = v_row.target_id;
    end case;
  end if;
  update public.content_removals
  set appeal_status = case when p_action = 'reverse' then 'reversed' else 'upheld' end
  where id = p_removal;
  perform public.add_notification(v_row.author_id, 'appeal_decided', null,
    p_payload => jsonb_build_object('removal_id', p_removal, 'target_kind', v_row.target_kind,
                                    'result', case when p_action = 'reverse' then 'reversed' else 'upheld' end));
end;
$function$;

-- Your removed content: a direct message's date (as in 20261013120000_safety.sql, with that change only).
CREATE OR REPLACE FUNCTION public.my_removal(p_id uuid)
 RETURNS TABLE(id uuid, target_kind text, reason text, removed_at timestamp with time zone, posted_at timestamp with time zone, excerpt text, appeal_status text, appeal_at timestamp with time zone, can_appeal boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select c.id, c.target_kind, c.reason, c.removed_at,
         case c.target_kind
           when 'post' then (select created_at from public.posts where id = c.target_id)
           when 'reply' then (select created_at from public.post_replies where id = c.target_id)
           when 'message' then (select created_at from public.messages where id = c.target_id)
           when 'dm_message' then (select created_at from public.dm_messages where id = c.target_id)
         end,
         left(rc.body, 200),
         c.appeal_status, c.appeal_at,
         c.appeal_status = 'none' and c.removed_at > now() - interval '14 days'
  from public.content_removals c
  left join public.removed_content rc on rc.removal_id = c.id
  where c.id = p_id and c.author_id = auth.uid();
$function$;

-- Report alerts: a direct message's author's market (as in 20261013120000_safety.sql, with that change only).
CREATE OR REPLACE FUNCTION public.report_alert(p_id uuid)
 RETURNS TABLE(id uuid, target_kind text, reason text, created_at timestamp with time zone, moderation_email text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select r.id, r.target_kind, r.reason, r.created_at,
         coalesce(
           (select m.email from public.market_moderation m
            join public.profiles a on a.home_market_id = m.market_id
            where a.id = case r.target_kind
              when 'post' then (select author_id from public.posts where id = r.target_id)
              when 'reply' then (select author_id from public.post_replies where id = r.target_id)
              when 'message' then (select author_id from public.messages where id = r.target_id)
              when 'dm_message' then (select author_id from public.dm_messages where id = r.target_id)
              when 'profile' then r.target_id end),
           (select m.email from public.market_moderation m
            join public.profiles rp on rp.home_market_id = m.market_id
            where rp.id = r.reporter_id))
  from public.reports r
  where r.id = p_id;
$function$;

-- Uploads today: Space files and direct message files together (as in 20261012150000_review11_followups.sql, with that change only).
CREATE OR REPLACE FUNCTION public.uploads_today()
 RETURNS TABLE(files bigint, bytes bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select count(*), coalesce(sum(x.bytes), 0)
  from (select f.bytes, f.created_at from public.my_space_files() f
        union all
        -- Direct message files share the cap (migration 22).
        select nullif(o.metadata ->> 'size', '')::bigint, o.created_at
        from storage.objects o
        where o.bucket_id = 'dm-files' and o.owner_id = auth.uid()::text
          and o.name collate "C" >= auth.uid()::text || '/'
          and o.name collate "C" < auth.uid()::text || '0') x
  where x.created_at > now() - interval '1 day';
$function$;

-- The purge lists a person's direct message files too (as in 20261015230000_notebook.sql, with that change only).
CREATE OR REPLACE FUNCTION public.accounts_due_for_purge()
 RETURNS TABLE(profile_id uuid, bucket text, name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select p.id, o.bucket_id, o.name
  from public.profiles p
  left join storage.objects o
    on o.bucket_id in ('avatars', 'post-media', 'notebook-files', 'dm-files')
   and o.name collate "C" >= p.id::text || '/'
   and o.name collate "C" < p.id::text || '0'
  where p.deletion_scheduled_at < now() - interval '30 days'
  order by p.id;
$function$;

-- The purge waits for direct message files too, and clears threads nobody is left in (as in 20261015230000_notebook.sql, with that change only).
CREATE OR REPLACE FUNCTION public.purge_account(p_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform 1 from public.profiles
  where id = p_id and deletion_scheduled_at < now() - interval '30 days'
  for update;
  if not found then
    return false;
  end if;
  if exists (select 1 from storage.objects o
             where o.bucket_id in ('avatars', 'post-media', 'notebook-files', 'dm-files')
               and o.name collate "C" >= p_id::text || '/'
               and o.name collate "C" < p_id::text || '0') then
    return false;
  end if;
  delete from auth.users where id = p_id;
  -- A thread whose two people are both gone goes too.
  delete from public.dm_threads where a_id is null and b_id is null;
  return true;
end;
$function$;

-- Cleanup claims: direct message files too (as in 20261015230000_notebook.sql, with that change only).
CREATE OR REPLACE FUNCTION public.forget_cleanup_claims()
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with gone as (
    delete from public.file_cleanup_claims c
    where not exists (select 1 from storage.objects o
                      where o.bucket_id in ('space-files', 'post-media', 'notebook-files', 'dm-files')
                        and o.name = c.storage_path)
    returning 1
  )
  select count(*)::int from gone;
$function$;

-- Download my data: the direct messages the person sent, and their threads (as in 20261016120000_post_pages.sql, with that change only).
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
                              'blocks', p.blocks, 'template_id', p.template_id,
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
    'post_templates', coalesce((select jsonb_agg(jsonb_build_object(
                                 'name', t.name, 'kind', t.kind, 'blocks', t.blocks,
                                 'fields', t.fields, 'created_at', t.created_at,
                                 'deleted_at', t.deleted_at))
                               from public.post_templates t where t.created_by = r.profile_id), '[]'),
    'dm_messages', coalesce((select jsonb_agg(jsonb_build_object(
                              'thread_id', d.thread_id, 'kind', d.kind, 'body', d.body,
                              'created_at', d.created_at, 'deleted_at', d.deleted_at,
                              'files', (select jsonb_agg(a.name) from public.dm_attachments a
                                        where a.message_id = d.id)))
                            from public.dm_messages d where d.author_id = r.profile_id), '[]'),
    'dm_threads', coalesce((select jsonb_agg(jsonb_build_object(
                             'thread_id', m.thread_id, 'state', m.state,
                             'created_at', t.created_at))
                           from public.dm_members m join public.dm_threads t on t.id = m.thread_id
                           where m.profile_id = r.profile_id), '[]'),
    'push_settings', (select to_jsonb(ps) from public.push_settings ps where ps.profile_id = r.profile_id)
  )
  from public.data_requests r
  where r.id = p_request;
$function$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.dm_settings(),
  public.handle_dm_message_time(),
  public.dm_blocked(uuid, uuid),
  public.dm_other(public.dm_threads, uuid),
  public.can_read_dm(uuid),
  public.dm_work_link(uuid, uuid),
  public.dm_person(uuid),
  public.may_upload_dm_file(text),
  public.may_read_dm_file(text, text),
  public.orphan_dm_files(interval),
  public.dm_unanswered_count(uuid, integer),
  public.dm_post(uuid, uuid, text, uuid, jsonb),
  public.start_dm(uuid, uuid, uuid, text, jsonb),
  public.send_dm(uuid, uuid, text, uuid, jsonb),
  public.delete_dm(uuid),
  public.mark_dm_read(uuid),
  public.decline_dm(uuid),
  public.mute_dm(uuid, boolean),
  public.dm_shared_space(uuid),
  public.dm_preview(uuid),
  public.dm_list_row(public.dm_threads, public.dm_members),
  public.my_dm_threads(timestamptz, uuid, integer),
  public.my_dm_requests(),
  public.dm_thread_page(uuid, timestamptz, uuid, integer),
  public.handle_dm_push(),
  public.handle_dm_deleted_push(),
  public.dm_open_linked(uuid, uuid),
  public.handle_dm_link_member(),
  public.handle_dm_link_follow()
  from public, anon;
-- Internal: answers about anyone, writes without its own checks, or the
-- cleanup's only.
revoke execute on function
  public.dm_settings(),
  public.handle_dm_message_time(),
  public.dm_blocked(uuid, uuid),
  public.dm_other(public.dm_threads, uuid),
  public.dm_work_link(uuid, uuid),
  public.dm_person(uuid),
  public.orphan_dm_files(interval),
  public.dm_unanswered_count(uuid, integer),
  public.dm_post(uuid, uuid, text, uuid, jsonb),
  public.dm_preview(uuid),
  public.dm_list_row(public.dm_threads, public.dm_members),
  public.handle_dm_push(),
  public.handle_dm_deleted_push(),
  public.dm_open_linked(uuid, uuid),
  public.handle_dm_link_member(),
  public.handle_dm_link_follow()
  from authenticated;
-- The read rules and the storage rules call these as the signed-in person.
grant execute on function
  public.can_read_dm(uuid),
  public.may_upload_dm_file(text),
  public.may_read_dm_file(text, text),
  public.start_dm(uuid, uuid, uuid, text, jsonb),
  public.send_dm(uuid, uuid, text, uuid, jsonb),
  public.delete_dm(uuid),
  public.mark_dm_read(uuid),
  public.decline_dm(uuid),
  public.mute_dm(uuid, boolean),
  public.dm_shared_space(uuid),
  public.my_dm_threads(timestamptz, uuid, integer),
  public.my_dm_requests(),
  public.dm_thread_page(uuid, timestamptz, uuid, integer)
  to authenticated;
grant execute on function public.orphan_dm_files(interval) to service_role;
