-- Migration 27: model views from BuildVibes 360 (the Navisworks plugin) into
-- the Space Library (docs/product/model-views.md; reviews 54-model-views and
-- 57). Branch model-views-db. Not live.
--
-- - library_files.source takes 'model_view'.
-- - model_views: one row per published view (thumb, camera, viewpoint,
--   model, Navisworks comments, image size), with the chain key copied from
--   its Library row (space_id, team_id) and its version. Read when its
--   Library file can be read; written only by publish_model_view.
-- - publish_model_view(...): the add_library_file checks for view.jpg, the
--   same for thumb.jpg, the limits of review 57 R4, then V<n> under an
--   advisory lock on (Space, Team, viewpoint) (R2), superseding the newest
--   version not removed (R3). No Activity, push or post (R7).
-- - my_publish_targets(): the Spaces and Teams the caller may publish to.
-- - my_model_views(guids): the caller's published views of those viewpoints,
--   with the work items that use any version (R5).
-- - is_referenced_file and may_read_file also know model_views.thumb_path
--   (R1; members who can read the view can open its thumb). may_upload is
--   unchanged (R6).
-- - Review follow-up: a retry of the same publish returns its version (M1);
--   a hidden account has no publish targets (L1); add_library_file can't
--   name a model view as the older file (L2).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

alter table public.library_files drop constraint library_files_source_check;
alter table public.library_files add constraint library_files_source_check
  check (source in ('upload', 'chat', 'model_view'));

-- Navisworks viewpoint comments: an array of at most 20 objects, each
-- exactly {author, body}, a string (or null) of at most 120 and 1000.
create function public.is_valid_model_view_comments(p_comments jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_c jsonb;
begin
  if p_comments is null or jsonb_typeof(p_comments) <> 'array'
     or jsonb_array_length(p_comments) > 20 then
    return false;
  end if;
  for v_c in select x from jsonb_array_elements(p_comments) x loop
    if jsonb_typeof(v_c) <> 'object'
       or not (v_c ? 'author' and v_c ? 'body')
       or exists (select 1 from jsonb_object_keys(v_c) k where k not in ('author', 'body'))
       or jsonb_typeof(v_c -> 'author') not in ('string', 'null')
       or jsonb_typeof(v_c -> 'body') not in ('string', 'null')
       or length(coalesce(v_c ->> 'author', '')) > 120
       or length(coalesce(v_c ->> 'body', '')) > 1000 then
      return false;
    end if;
  end loop;
  return true;
end;
$$;

create table public.model_views (
  library_file_id uuid primary key references public.library_files (id) on delete cascade,
  thumb_path text not null unique,
  -- Navisworks Viewpoint.GetCamera(): reopens the exact view.
  camera jsonb not null check (jsonb_typeof(camera) = 'object'),
  -- The saved viewpoint's Guid inside the Navisworks file.
  viewpoint_guid uuid not null,
  viewpoint_folder text check (length(viewpoint_folder) between 1 and 200),
  model_title text check (length(model_title) between 1 and 200),
  model_file text check (length(model_file) between 1 and 200),
  comments jsonb not null default '[]'::jsonb
    check (public.is_valid_model_view_comments(comments)),
  image_width integer check (image_width between 1 and 10000),
  image_height integer check (image_height between 1 and 10000),
  navisworks text check (length(navisworks) between 1 and 20),
  -- The chain key (R2), copied from the Library row. No delete action on
  -- the Team: a Team with Library files can't be deleted (delete_team).
  space_id uuid not null references public.spaces (id) on delete cascade,
  team_id uuid references public.teams (id),
  version integer not null check (version >= 1),
  check (thumb_path = space_id::text || '/library/' || library_file_id::text || '/thumb.jpg')
);
-- One V<n> per viewpoint in a Space (Team or whole Space). The whole-Space
-- chain uses the zero uuid, so two whole-Space V1s also collide.
create unique index model_views_chain_idx on public.model_views
  (space_id, coalesce(team_id, '00000000-0000-0000-0000-000000000000'::uuid),
   viewpoint_guid, version);
create index model_views_viewpoint_idx on public.model_views (viewpoint_guid);

-- A thumb the cleanup job has claimed can't be referenced (as
-- refuse_claimed_file does for storage_path, under the same lock).
create function public.refuse_claimed_thumb()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.lock_file_path(new.thumb_path);
  if exists (select 1 from public.file_cleanup_claims c
             where c.storage_path = new.thumb_path) then
    raise exception 'this file was cleaned up; upload it again'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger model_views_thumb_not_claimed
  before insert or update of thumb_path on public.model_views
  for each row execute function public.refuse_claimed_thumb();

alter table public.model_views enable row level security;
create policy model_views_read on public.model_views
  for select to authenticated using (public.can_read_library_file(library_file_id));
revoke all on public.model_views from anon, authenticated;
grant select on public.model_views to authenticated;

-- ---------------------------------------------------------------------------
-- Files: the thumb is in use, and readable like its view (R1)
-- ---------------------------------------------------------------------------

-- As in 20261015120000_daybook.sql, byte for byte, with the model_views
-- branch added at the end.
create or replace function public.is_referenced_file(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.work_item_evidence e
                 join public.space_posts p on p.id = e.work_item_id
                 where e.storage_path = p_path and p.deleted_at is null)
      or exists (select 1 from public.message_attachments a where a.storage_path = p_path)
      or exists (select 1 from public.library_files f where f.storage_path = p_path)
      or exists (select 1 from public.post_files f
                 join public.space_posts p on p.id = f.post_id
                 where f.storage_path = p_path and p.deleted_at is null)
      or exists (select 1 from public.model_views mv where mv.thumb_path = p_path);
$$;

-- As in 20261015120000_daybook.sql, byte for byte, with one addition: in a
-- Library folder, a model view's thumb is readable by whoever can read
-- the model view.
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
  if v_parts[2] in ('chat', 'library', 'posts') then
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
          and m.deleted_at is null and public.can_use_thread(m.thread_id)
          and not public.reported_by_me('message', m.id))
        -- A document from chat that stays in the Library (for example
        -- because a work item uses it) after its message was deleted.
        or exists (
        select 1 from public.library_files f
        where f.storage_path = p_name and f.space_id = v_space
          and public.can_read_library_file(f.id));
    end if;
    if v_parts[2] = 'posts' then
      return exists (
        select 1 from public.post_files f
        join public.space_posts p on p.id = f.post_id
        where f.storage_path = p_name and p.id = v_id and p.space_id = v_space
          and public.can_see_space_post(p.id));
    end if;
    return exists (
      select 1 from public.library_files f
      where f.storage_path = p_name and f.id = v_id and f.space_id = v_space
        and public.can_read_library_file(f.id))
      or exists (
      select 1 from public.model_views mv
      where mv.thumb_path = p_name and mv.library_file_id = v_id and mv.space_id = v_space
        and public.can_read_library_file(mv.library_file_id));
  end if;
  begin
    v_space := v_parts[1]::uuid;
    v_id := v_parts[2]::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return exists (select 1 from public.work_items w
                 where w.id = v_id and w.space_id = v_space)
    and public.can_see_space_post(v_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Publishing
-- ---------------------------------------------------------------------------

-- The advisory lock key of one chain: a viewpoint in a Space, in one Team
-- or the whole Space.
create function public.model_view_chain_key(p_space uuid, p_team uuid, p_viewpoint uuid)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select hashtextextended('model-view:' || p_space::text || ':'
                          || coalesce(p_team::text, 'space') || ':' || p_viewpoint::text, 0);
$$;

-- BuildVibes 360 "Publish": register view.jpg and thumb.jpg the caller
-- uploaded to <space>/library/<p_id>/ as a Model view in the Library.
-- The checks are add_library_file's, for both files. A retry with the
-- same id by the same caller, for the same files, viewpoint, Space and
-- Team, returns the version already published (review 57 follow-up, M1). The version is V<n>, n = 1 + the earlier model views of
-- this viewpoint in this Space/Team, removed ones included (never reused);
-- it supersedes the newest of those not removed. Nothing is posted and
-- nobody is notified.
create function public.publish_model_view(
  p_id uuid,
  p_space uuid,
  p_team uuid,
  p_name text,
  p_note text,
  p_image_path text,
  p_thumb_path text,
  p_bytes bigint,
  p_camera text,
  p_viewpoint_guid uuid,
  p_viewpoint_folder text,
  p_model_title text,
  p_model_file text,
  p_comments text,
  p_image_width integer,
  p_image_height integer,
  p_navisworks text
)
returns table (library_file_id uuid, rev_label text)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_folder text := p_space::text || '/library/' || p_id::text || '/';
  v_name text := trim(coalesce(p_name, ''));
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_vp_folder text := nullif(trim(coalesce(p_viewpoint_folder, '')), '');
  v_model_title text := nullif(trim(coalesce(p_model_title, '')), '');
  v_model_file text := nullif(trim(coalesce(p_model_file, '')), '');
  v_navisworks text := nullif(trim(coalesce(p_navisworks, '')), '');
  v_camera jsonb;
  v_comments jsonb;
  v_version integer;
  v_supersedes uuid;
  v_done public.library_files;
  v_constraint text;
begin
  if p_id is null or p_space is null or not public.can(p_space, 'add_files') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_team is not null and not exists (
       select 1 from public.teams t where t.id = p_team and t.space_id = p_space
         and (public.is_space_admin(p_space)
              or exists (select 1 from public.team_members m
                         where m.team_id = t.id and m.profile_id = auth.uid()))) then
    raise exception 'not allowed for this Team' using errcode = '42501';
  end if;
  if p_viewpoint_guid is null then
    raise exception 'the viewpoint is not valid' using errcode = '22023';
  end if;

  -- One publish of a chain at a time (R2): the second waits here, then
  -- sees the first (a retry of it, or the version before it).
  perform pg_advisory_xact_lock(public.model_view_chain_key(p_space, p_team, p_viewpoint_guid));

  -- A retry of the caller's own publish (the reply was lost on a weak
  -- signal) returns what was published. Any other use of the id is refused.
  select f.* into v_done from public.library_files f where f.id = p_id;
  if v_done.id is not null then
    if v_done.source = 'model_view' and v_done.uploaded_by = auth.uid()
       and v_done.space_id = p_space and v_done.team_id is not distinct from p_team
       and v_done.storage_path = p_image_path and v_done.deleted_at is null
       and exists (select 1 from public.model_views mv
                   where mv.library_file_id = p_id and mv.viewpoint_guid = p_viewpoint_guid
                     and mv.thumb_path = p_thumb_path) then
      return query select v_done.id, v_done.rev_label;
      return;
    end if;
    raise exception 'this id is taken' using errcode = '22023';
  end if;

  if p_image_path is distinct from v_folder || 'view.jpg'
     or p_thumb_path is distinct from v_folder || 'thumb.jpg'
     or not public.is_my_upload(p_image_path)
     or not public.is_my_upload(p_thumb_path) then
    raise exception 'file not uploaded' using errcode = '22023';
  end if;
  if public.upload_mime(p_image_path, 'image/jpeg') is distinct from 'image/jpeg'
     or public.upload_mime(p_thumb_path, 'image/jpeg') is distinct from 'image/jpeg' then
    raise exception 'file type does not match the upload' using errcode = '22023';
  end if;

  -- What the plugin sends (review 57, R4).
  if length(v_name) not between 1 and 120 then
    raise exception 'the title is not valid' using errcode = '22023';
  end if;
  if length(v_note) > 300 or v_note ~ '[\r\n]' then
    raise exception 'the note is not valid' using errcode = '22023';
  end if;
  if length(v_vp_folder) > 200 or length(v_model_title) > 200 or length(v_model_file) > 200
     or length(v_navisworks) > 20 then
    raise exception 'the model details are too long' using errcode = '22023';
  end if;
  if p_image_width not between 1 and 10000 or p_image_height not between 1 and 10000 then
    raise exception 'the image size is not valid' using errcode = '22023';
  end if;
  if p_bytes < 0 then
    raise exception 'the file size is not valid' using errcode = '22023';
  end if;
  if p_camera is null or octet_length(p_camera) > 4096 then
    raise exception 'camera is not valid' using errcode = '22023';
  end if;
  begin
    v_camera := p_camera::jsonb;
  exception when data_exception then
    raise exception 'camera is not valid' using errcode = '22023';
  end;
  if jsonb_typeof(v_camera) is distinct from 'object' then
    raise exception 'camera is not valid' using errcode = '22023';
  end if;
  begin
    v_comments := coalesce(nullif(trim(coalesce(p_comments, '')), ''), '[]')::jsonb;
  exception when data_exception then
    raise exception 'comments are not valid' using errcode = '22023';
  end;
  if not public.is_valid_model_view_comments(v_comments) then
    raise exception 'comments are not valid' using errcode = '22023';
  end if;

  -- Model views are never deleted (only removed from the Library), so the
  -- highest version is the count of earlier ones (R3).
  select coalesce(max(mv.version), 0) + 1 into v_version
  from public.model_views mv
  where mv.space_id = p_space and mv.team_id is not distinct from p_team
    and mv.viewpoint_guid = p_viewpoint_guid;
  select mv.library_file_id into v_supersedes
  from public.model_views mv
  join public.library_files f on f.id = mv.library_file_id
  where mv.space_id = p_space and mv.team_id is not distinct from p_team
    and mv.viewpoint_guid = p_viewpoint_guid and f.deleted_at is null
  order by mv.version desc
  limit 1;

  -- The unique indexes catch what the lock can't: the same id taken at the
  -- same moment by another chain or by add_library_file ("this id is
  -- taken"), or a version that slipped by the lock ("try again").
  begin
    insert into public.library_files
      (id, space_id, team_id, name, storage_path, mime, bytes, rev_label, note,
       supersedes_id, source, uploaded_by)
    values (p_id, p_space, p_team, v_name, p_image_path, 'image/jpeg', p_bytes,
            'V' || v_version, v_note, v_supersedes, 'model_view', auth.uid());
    insert into public.model_views
      (library_file_id, thumb_path, camera, viewpoint_guid, viewpoint_folder, model_title,
       model_file, comments, image_width, image_height, navisworks, space_id, team_id, version)
    values (p_id, p_thumb_path, v_camera, p_viewpoint_guid, v_vp_folder, v_model_title,
            v_model_file, v_comments, p_image_width, p_image_height, v_navisworks,
            p_space, p_team, v_version);
  exception when unique_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint = 'model_views_chain_idx' then
      raise exception 'another version was published at the same moment; try again'
        using errcode = '40001';
    end if;
    raise exception 'this id is taken' using errcode = '22023';
  end;
  return query select p_id, 'V' || v_version;
end;
$$;

-- The plugin's Publish picker: each Space where the caller may add files
-- (team_id null = the whole Space), and each of its Teams the caller is in
-- (every Team for an admin). Never a count.
create function public.my_publish_targets()
returns table (space_id uuid, space_name text, team_id uuid, team_name text)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select s.id, s.name
    from public.space_members m
    join public.spaces s on s.id = m.space_id
    where m.profile_id = auth.uid() and m.left_at is null and s.deleted_at is null
      and public.can(s.id, 'add_files')
      and not public.is_hidden_account(auth.uid())
  )
  select x.space_id, x.space_name, x.team_id, x.team_name
  from (
    select mine.id as space_id, mine.name as space_name,
           null::uuid as team_id, null::text as team_name
    from mine
    union all
    select mine.id, mine.name, t.id, t.name
    from mine
    join public.teams t on t.space_id = mine.id
    where public.is_space_admin(mine.id)
       or exists (select 1 from public.team_members tm
                  where tm.team_id = t.id and tm.profile_id = auth.uid())
  ) x
  order by x.space_name, x.space_id, x.team_id is not null, x.team_name, x.team_id;
$$;

-- What a work item that uses a model view shows in the plugin: its ref,
-- title, status ('open', 'sent_back', 'done', 'checked' or 'cancelled'),
-- id, last activity and the latest sign-off's first photo (or null).
-- Internal: it doesn't check who reads.
create function public.model_view_use_json(p_post public.space_posts)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'ref', w.ref,
    'title', p_post.title,
    'status', case
      when p_post.status = 'cancelled' then 'cancelled'
      when w.status = 'open' and (select e.kind from public.work_item_events e
                                  where e.work_item_id = w.id
                                    and e.kind in ('done', 'checked', 'sent_back')
                                  order by e.created_at desc, e.id desc limit 1) = 'sent_back'
        then 'sent_back'
      else w.status end,
    'item_id', w.id,
    'at', p_post.last_activity_at,
    'proof_path', (select ev.storage_path
                   from (select e.id from public.work_item_events e
                         where e.work_item_id = w.id and e.kind = 'done'
                         order by e.created_at desc, e.id desc limit 1) d
                   join public.work_item_evidence ev on ev.event_id = d.id
                   order by ev.created_at, ev.id
                   limit 1))
  from public.work_items w
  where w.id = p_post.id;
$$;

-- The plugin's "Published" tags: the caller's own published views of
-- these viewpoints that they can still read, newest first. is_current: no
-- newer version of the chain is left in the Library. uses: the work items
-- that use any version of the chain and that the caller may see, the most
-- recent activity first.
create function public.my_model_views(p_viewpoint_guids uuid[])
returns table (library_file_id uuid, viewpoint_guid uuid, title text, rev_label text,
               space_id uuid, space_name text, team_id uuid, team_name text,
               created_at timestamptz, is_current boolean, uses jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select mv.library_file_id, mv.viewpoint_guid, f.name, f.rev_label,
         f.space_id, s.name, f.team_id, t.name, f.created_at,
         not exists (select 1 from public.model_views n
                     join public.library_files nf on nf.id = n.library_file_id
                     where n.space_id = mv.space_id
                       and n.team_id is not distinct from mv.team_id
                       and n.viewpoint_guid = mv.viewpoint_guid
                       and n.version > mv.version and nf.deleted_at is null),
         coalesce((
           select jsonb_agg(public.model_view_use_json(p)
                            order by p.last_activity_at desc, p.id)
           from public.space_posts p
           where p.id in (select a.work_item_id
                          from public.model_views c
                          join public.work_item_attachments a on a.library_file_id = c.library_file_id
                          where c.space_id = mv.space_id
                            and c.team_id is not distinct from mv.team_id
                            and c.viewpoint_guid = mv.viewpoint_guid)
             and public.can_see_space_post(p.id)), '[]'::jsonb)
  from public.model_views mv
  join public.library_files f on f.id = mv.library_file_id
  join public.spaces s on s.id = f.space_id
  left join public.teams t on t.id = f.team_id
  where mv.viewpoint_guid = any(p_viewpoint_guids)
    and f.uploaded_by = auth.uid()
    and public.can_read_library_file(f.id)
  order by f.created_at desc, mv.version desc, mv.library_file_id;
$$;

-- ---------------------------------------------------------------------------
-- Ordinary uploads never continue a model view's versions (review 57
-- follow-up, L2)
-- ---------------------------------------------------------------------------

-- As in 20261012140000_chat_library.sql, byte for byte, with one branch
-- added after the older-file check: the older file can't be a model view.
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
  if p_supersedes is not null and exists (
       select 1 from public.library_files f
       where f.id = p_supersedes and f.source = 'model_view') then
    raise exception 'a model view''s versions come only from BuildVibes 360' using errcode = '22023';
  end if;
  insert into public.library_files
    (id, space_id, team_id, name, storage_path, mime, bytes, rev_label, note,
     supersedes_id, uploaded_by)
  values (p_id, p_space, p_team, trim(p_name), p_path, p_mime, p_bytes,
          nullif(trim(p_rev_label), ''), nullif(trim(p_note), ''), p_supersedes, auth.uid());
  return p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.is_valid_model_view_comments(jsonb),
  public.refuse_claimed_thumb(),
  public.model_view_chain_key(uuid, uuid, uuid),
  public.model_view_use_json(public.space_posts),
  public.publish_model_view(uuid, uuid, uuid, text, text, text, text, bigint, text, uuid,
                            text, text, text, text, integer, integer, text),
  public.my_publish_targets(),
  public.my_model_views(uuid[])
  from public, anon, authenticated;
grant execute on function
  public.publish_model_view(uuid, uuid, uuid, text, text, text, text, bigint, text, uuid,
                            text, text, text, text, integer, integer, text),
  public.my_publish_targets(),
  public.my_model_views(uuid[])
  to authenticated;
