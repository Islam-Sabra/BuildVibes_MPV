-- Migration 11: chat and Library follow-ups (week 6 part 2).
--
-- 1. Review 13 A: the cleanup never claims a file younger than one day,
--    whatever age the job asks for. An upload still going on a weak site
--    signal is left alone.
-- 2. F1 "Share in chat": a message can point at a Library file that is
--    already there, instead of uploading it again (which would also make a
--    second "From chat" copy in the Library). A Team's file is shared only
--    in that Team's thread, so it never reaches people outside the Team.
--    Sharing a file needs the "add files" right, like posting one: a Viewer
--    chats in text only (review 14).
-- 3. A deleted message keeps no link to a Library file (review 14).

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
    select o.name from public.orphan_space_files(greatest(p_age, interval '1 day')) o
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

-- ---------------------------------------------------------------------------
-- 2. Share a Library file in chat
-- ---------------------------------------------------------------------------

alter table public.messages
  add column library_file_id uuid references public.library_files (id) on delete set null;

create or replace function public.share_library_file(
  p_id uuid,
  p_thread uuid,
  p_file uuid,
  p_body text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_thread public.threads;
  v_file public.library_files;
  v_existing public.messages;
  v_body text := nullif(trim(coalesce(p_body, '')), '');
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  -- A retry with the same id never posts twice.
  select * into v_existing from public.messages where id = p_id;
  if v_existing.id is not null then
    if v_existing.author_id = v_me and v_existing.thread_id = p_thread
       and v_existing.library_file_id = p_file then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_thread from public.threads where id = p_thread;
  if v_thread.id is null or not public.can_use_thread(p_thread) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  -- A Viewer chats in text only: sharing a file is posting one.
  if not public.can(v_thread.space_id, 'add_files') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_file from public.library_files where id = p_file;
  if v_file.id is null or v_file.deleted_at is not null
     or v_file.space_id <> v_thread.space_id
     or not public.can_read_library_file(p_file) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_file.team_id is not null and v_file.team_id is distinct from v_thread.team_id then
    raise exception 'a Team file can only be shared in that Team''s thread'
      using errcode = '22023';
  end if;
  if length(v_body) > 4000 then
    raise exception 'message too long' using errcode = '22023';
  end if;
  if (select count(*) from public.messages m
      where m.author_id = v_me and m.kind <> 'work_item'
        and m.created_at > now() - interval '1 minute') >= 30 then
    raise exception 'too many messages, wait a moment' using errcode = 'P0001';
  end if;
  insert into public.messages (id, thread_id, space_id, author_id, kind, body, library_file_id)
  values (p_id, p_thread, v_thread.space_id, v_me, 'file', v_body, p_file);
  return p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Deleting a message also drops its link to a Library file
-- ---------------------------------------------------------------------------

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
  set deleted_at = now(), deleted_by = auth.uid(), body = null,
      library_file_id = null
  where id = p_id;
  update public.library_files f
  set deleted_at = now(), deleted_by = auth.uid()
  where f.source_message_id = p_id and f.deleted_at is null
    and not exists (select 1 from public.work_item_attachments a where a.library_file_id = f.id);
end;
$$;

revoke execute on function public.share_library_file(uuid, uuid, uuid, text)
  from public, anon;
grant execute on function public.share_library_file(uuid, uuid, uuid, text)
  to authenticated;
