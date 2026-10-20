-- Migration 32: who received a Library file, NEW VERSION for me, and
-- search shows only the version in use (review 67, slice 4). Branch
-- claude/test-tw7wuv. Not live; after migrations 29, 30 and 31.
--
-- Received stays on file posts (post_acks, kind 'received'; migration 15).
-- A Library file has no receipts of its own: who received it is who
-- marked Received on a post that carries it (space_posts.library_file_id)
-- and that the caller can see. Faces and names, never a count (rule 3);
-- like post_acks_for, open to every reader of the file (review 36 R1).
-- Someone across a block is left out.
--
-- A file is "in use" when no version the caller can read replaces it
-- (as has_newer in space_post_json).
--
-- No new table.

-- True when no version [p_file]'s reader can read replaces it.
create function public.library_file_in_force(p_file uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (select 1 from public.library_files n
                     where n.supersedes_id = p_file and public.can_read_library_file(n.id));
$$;

-- Who received [p_file], oldest first, mine marked. Nothing unless the
-- caller can read the file.
create function public.library_file_receipts(p_file uuid)
returns table (profile_id uuid, name text, at timestamptz, mine boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select r.profile_id, public.space_person_name(r.profile_id), r.at,
         r.profile_id = auth.uid()
  from (
    select a.profile_id, min(a.created_at) as at
    from public.space_posts p
    join public.post_acks a on a.post_id = p.id and a.kind = 'received'
    where p.library_file_id = p_file and p.deleted_at is null
      and public.can_see_space_post(p.id)
    group by a.profile_id
  ) r
  where public.can_read_library_file(p_file)
    and not public.is_blocked_with(r.profile_id)
  order by r.at, r.profile_id;
$$;

-- The post to mark Received through: the newest live post carrying
-- [p_file] that the caller can see. Null when there is none (a file from
-- chat, or one never posted).
create function public.library_file_post(p_file uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.space_posts p
  where p.library_file_id = p_file and p.kind = 'file'
    and p.status = 'live' and p.deleted_at is null
    and public.can_read_library_file(p_file)
    and public.can_see_space_post(p.id)
  order by p.created_at desc, p.id desc
  limit 1;
$$;

-- The Library list's extras for [p_space]: one row per file in use the
-- caller can read, with up to 4 newest receivers (faces) and new_for_me:
-- it replaces an older version, someone else posted it where I can see,
-- and I haven't marked it Received. Nothing for a non-member.
create function public.library_overview(p_space uuid)
returns table (file_id uuid, new_for_me boolean, received jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select f.id,
         f.supersedes_id is not null
           and exists (select 1 from public.space_posts p
                       where p.library_file_id = f.id and p.kind = 'file'
                         and p.status = 'live' and p.deleted_at is null
                         and p.author_id is distinct from auth.uid()
                         and public.can_see_space_post(p.id))
           and not exists (select 1 from public.space_posts p
                           join public.post_acks a on a.post_id = p.id
                           where p.library_file_id = f.id and p.deleted_at is null
                             and a.kind = 'received' and a.profile_id = auth.uid()),
         coalesce((
           select jsonb_agg(jsonb_build_object('profile_id', r.profile_id,
                                               'name', public.space_person_name(r.profile_id),
                                               'at', r.at)
                            order by r.at desc, r.profile_id)
           from (
             select a.profile_id, min(a.created_at) as at
             from public.space_posts p
             join public.post_acks a on a.post_id = p.id and a.kind = 'received'
             where p.library_file_id = f.id and p.deleted_at is null
               and public.can_see_space_post(p.id)
               and not public.is_blocked_with(a.profile_id)
             group by a.profile_id
             order by min(a.created_at) desc, a.profile_id
             limit 4
           ) r), '[]'::jsonb)
  from public.library_files f
  where f.space_id = p_space and f.deleted_at is null
    and public.is_member(p_space)
    and public.can_read_library_file(f.id)
    and public.library_file_in_force(f.id)
  order by f.created_at desc, f.id desc;
$$;

-- Search: as in 20261016120000_post_pages.sql, with one change: a Library
-- file shows only while it is in use (no readable newer version).
create or replace function public.search_space(p_space uuid, p_q text)
returns table (kind text, id uuid, post_id uuid, thread_id uuid, team_id uuid, post_kind text,
               post_status text, ref text, title text, snippet text, author_name text,
               created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := public.search_fold(regexp_replace(trim(coalesce(p_q, '')), '\s+', ' ', 'g'));
  v_pat text;
  v_threads uuid[];
begin
  if char_length(v_q) > 100 then
    raise exception 'search too long' using errcode = '22023';
  end if;
  if char_length(v_q) < 2 or not public.is_member(p_space) then
    return;
  end if;
  v_pat := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_threads := array(select t.id from public.threads t
                     where t.space_id = p_space and public.can_use_thread(t.id));

  return query
  with hits as (
    (select 'post'::text as kind, p.id, p.id as post_id, null::uuid as thread_id, p.team_id,
            p.kind as post_kind, p.status as post_status, w.ref, p.title,
            case when public.search_fold(p.title) like v_pat then null
                 else public.search_snippet(
                   coalesce(p.body, '') || ' ' || public.blocks_plain_text(p.blocks), v_q)
            end as snippet,
            p.author_id, p.created_at
     from public.space_posts p
     left join public.work_items w on w.id = p.id
     where p.space_id = p_space and p.deleted_at is null
       and p.search_text like v_pat
       and (p.team_id is null or public.can_see_space_post(p.id))
     order by p.created_at desc, p.id desc limit 30)
    union all
    (select 'point', c.id, p.id, null, p.team_id, p.kind, p.status, w.ref, p.title, c.text,
            p.author_id, c.created_at
     from public.checklist_points c
     join public.space_posts p on p.id = c.post_id
     left join public.work_items w on w.id = p.id
     where p.space_id = p_space and p.deleted_at is null
       and c.search_text like v_pat
       and (p.team_id is null or public.can_see_space_post(p.id))
     order by c.created_at desc, c.id desc limit 30)
    union all
    (select 'message', m.id, null, m.thread_id, t.team_id, null, null, null, null,
            public.search_snippet(m.body, v_q), m.author_id, m.created_at
     from public.messages m
     join public.threads t on t.id = m.thread_id
     where m.space_id = p_space and m.thread_id = any (v_threads)
       and m.deleted_at is null and m.body is not null
       and m.search_text like v_pat
       and not public.reported_by_me('message', m.id)
     order by m.created_at desc, m.id desc limit 30)
    union all
    (select 'file', f.id, null, null, f.team_id, null, null, null, f.name, f.rev_label,
            f.uploaded_by, f.created_at
     from public.library_files f
     where f.space_id = p_space and f.deleted_at is null
       and f.search_text like v_pat
       and (f.team_id is null or public.can_read_library_file(f.id))
       and public.library_file_in_force(f.id)
     order by f.created_at desc, f.id desc limit 30)
  )
  select h.kind, h.id, h.post_id, h.thread_id, h.team_id, h.post_kind, h.post_status, h.ref,
         h.title, h.snippet, public.space_person_name(h.author_id), h.created_at
  from hits h
  -- The full rules again on at most 120 rows, so a later change to the
  -- short-cuts above can't leak.
  where (h.post_id is null or public.can_see_space_post(h.post_id))
    and (h.kind <> 'file' or public.can_read_library_file(h.id))
  order by h.created_at desc, h.id desc
  limit 30;
end;
$$;

revoke execute on function
  public.library_file_in_force(uuid),
  public.library_file_receipts(uuid),
  public.library_file_post(uuid),
  public.library_overview(uuid)
  from public, anon;
-- Internal: answers about files the caller may not read.
revoke execute on function public.library_file_in_force(uuid) from authenticated;
grant execute on function
  public.library_file_receipts(uuid),
  public.library_file_post(uuid),
  public.library_overview(uuid)
  to authenticated;
