-- Migration 18: the daybook core (review 33 A0, A1 and its clarifications;
-- docs/product/daybook.md). Branch daybook-db. Not live.
--
-- Rule changes (A0, founder-approved 14-15 Oct):
-- - Lead and Crew post work (the Crew preset gets create_items); an admin can
--   still switch it off for one person. Viewers never.
-- - Only the author checks or sends back; if the author is no longer an
--   active member, a Space admin acts for them. Never the owner. When the
--   author is also the owner (they gave the work to themselves), a Space
--   admin checks it. check_items is retired: ignored, gone from the presets
--   and from member_rights (old values in custom stay harmless).
-- - The author reassigns; an admin only when the author has left.
-- - Updates (comments): the owner and any Lead or Crew member. Viewers read.
-- - Only the author edits, while Open (locked after Done, reopened by Send
--   back, locked for good after Checked). Every edit is recorded and shown,
--   and tells the owner.
-- - Delete only while nobody else has added anything; after that Cancel
--   (stays in the daybook, CANCELLED). Author, or an admin when the author
--   has left. A Checked item can't be cancelled.
-- - No new work item cards in chat; old card messages stay.
-- - Send-back reason not_as_drawing is now not_as_asked (neutral words).
--
-- Tables (A1): space_posts, one per daybook post of any kind; a work item is
-- a post of kind work_item sharing its id (backfilled for every item).
-- post_edits (append-only) and post_files (a post's own photos and files,
-- not sign-off proof).
--
-- Team posts are seen only by that Team, the Space admins, their author and
-- the work item's owner (review 33 clarification 3). Work items were readable
-- by every member until now; the same rule now applies to work_items, its
-- events, proof photos and attachments, Today and Activity, so a Team item
-- doesn't leak through the old tables.
--
-- Names: the Home feed already has create_post, edit_post and delete_post
-- (table posts). The Space versions are edit_space_post, delete_space_post
-- and cancel_space_post; a Space delete_post(uuid) would have replaced the
-- feed's. Work items are still created with create_work_item (A1).
--
-- Drafts stay on the phone (no table), keyed by the post id the app chose.

-- ---------------------------------------------------------------------------
-- Rights (A0)
-- ---------------------------------------------------------------------------

-- Crew may post work; check_items is no longer a right. A Viewer never
-- posts work, whatever the custom rights say (A0).
create or replace function public.pass_rights(p_pass text, p_custom jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select (case p_pass
    when 'lead' then '{"create_items": true, "add_files": true, "invite": true, "mark_done": true}'
    when 'crew' then '{"create_items": true, "add_files": true, "invite": false, "mark_done": true}'
    else '{"create_items": false, "add_files": false, "invite": false, "mark_done": false}'
  end)::jsonb || (coalesce(p_custom, '{}'::jsonb) - 'mark_done' - 'check_items'
                  - case when p_pass in ('lead', 'crew') then '' else 'create_items' end);
$$;

-- check_items is ignored: nobody "has" it, admins included.
create or replace function public.member_can(p_space uuid, p_profile uuid, p_right text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case
      when p_right = 'check_items' then false
      when p_right = 'chat' then true
      when p_right = 'invite' then
        m.is_admin
        or s.who_can_invite = 'everyone'
        or (s.who_can_invite = 'admins_leads'
            and coalesce((public.pass_rights(m.pass, m.custom) ->> 'invite')::boolean, false))
      when m.is_admin and p_right <> 'mark_done' then true
      else coalesce((public.pass_rights(m.pass, m.custom) ->> p_right)::boolean, false)
    end
    from public.space_members m
    join public.spaces s on s.id = m.space_id
    where m.space_id = p_space
      and m.profile_id = p_profile
      and m.left_at is null
      and s.deleted_at is null
  ), false);
$$;

-- S17k: no check_items row; an old check_items value doesn't make a pass Custom.
create or replace function public.member_rights(p_space uuid, p_profile uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when public.is_member(p_space) then jsonb_build_object(
    'create_items', public.member_can(p_space, p_profile, 'create_items'),
    'add_files', public.member_can(p_space, p_profile, 'add_files'),
    'invite', public.member_can(p_space, p_profile, 'invite'),
    'mark_done', public.member_can(p_space, p_profile, 'mark_done'),
    'is_custom', (select (m.custom - 'check_items') <> '{}'::jsonb from public.space_members m
                  where m.space_id = p_space and m.profile_id = p_profile)
  ) end;
$$;

-- An older app may still send check_items; it is dropped, not stored. So is
-- create_items on a Viewer pass (a Viewer never posts work).
create or replace function public.set_member_pass(
  p_space uuid,
  p_profile uuid,
  p_pass text,
  p_custom jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_preset jsonb := public.pass_rights(p_pass, '{}');
  v_custom jsonb := '{}'::jsonb;
  v_key text;
  v_value jsonb;
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_pass is null or p_pass not in ('lead', 'crew', 'viewer') then
    raise exception 'choose a pass' using errcode = '22023';
  end if;
  if not public.is_valid_custom_rights(coalesce(p_custom, '{}'::jsonb)) then
    raise exception 'unknown right' using errcode = '22023';
  end if;
  perform public.require_active_member(p_space, p_profile);
  for v_key, v_value in
    select * from jsonb_each(coalesce(p_custom, '{}'::jsonb) - 'check_items'
                             - case when p_pass = 'viewer' then 'create_items' else '' end) loop
    if v_preset -> v_key is distinct from v_value then
      v_custom := v_custom || jsonb_build_object(v_key, v_value);
    end if;
  end loop;
  update public.space_members set pass = p_pass, custom = v_custom
  where space_id = p_space and profile_id = p_profile;
end;
$$;

-- Stored overrides that are now the same as the preset, or retired, go.
update public.space_members set custom = custom - 'check_items' where custom ? 'check_items';
update public.space_members set custom = custom - 'create_items'
where pass = 'crew' and custom -> 'create_items' = 'true'::jsonb;
update public.space_members set custom = custom - 'create_items'
where pass = 'viewer' and custom ? 'create_items';

-- ---------------------------------------------------------------------------
-- Send-back reasons: not_as_drawing becomes not_as_asked (A0)
-- ---------------------------------------------------------------------------

-- The record is append-only; this one rename is the only change ever made
-- to old events, done here with the guard off.
alter table public.work_item_events disable trigger work_item_events_append_only;
alter table public.work_item_events drop constraint work_item_events_reason_check;
update public.work_item_events set reason = 'not_as_asked' where reason = 'not_as_drawing';
alter table public.work_item_events add constraint work_item_events_reason_check
  check (reason is null or reason in ('photo_missing', 'not_as_asked', 'not_finished', 'other'));
alter table public.work_item_events enable trigger work_item_events_append_only;
update public.notifications set payload = jsonb_set(payload, '{reason}', '"not_as_asked"')
where kind = 'item_sent_back' and payload ->> 'reason' = 'not_as_drawing';

-- ---------------------------------------------------------------------------
-- No new work item cards in chat (A0). Old card messages stay, with every
-- guard that treats them specially (no delete, no report, no push).
-- ---------------------------------------------------------------------------

drop trigger work_item_events_card on public.work_item_events;
drop function public.handle_work_item_event_card();

-- ---------------------------------------------------------------------------
-- A quote brought into a post: {author_name, text, at}, nothing else.
-- ---------------------------------------------------------------------------

create or replace function public.is_valid_post_quote(p_quote jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  if jsonb_typeof(p_quote) <> 'object'
     or exists (select 1 from jsonb_object_keys(p_quote) k
                where k not in ('author_name', 'text', 'at'))
     or jsonb_typeof(p_quote -> 'text') is distinct from 'string'
     or length(trim(p_quote ->> 'text')) not between 1 and 3000
     or (p_quote ? 'author_name' and (jsonb_typeof(p_quote -> 'author_name') <> 'string'
                                      or length(p_quote ->> 'author_name') > 120))
     or (p_quote ? 'at' and jsonb_typeof(p_quote -> 'at') <> 'string') then
    return false;
  end if;
  if p_quote ? 'at' then
    perform (p_quote ->> 'at')::timestamptz;
  end if;
  return true;
exception when others then
  return false;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.space_posts (
  -- Chosen by the app, so a retry after a weak signal is the same post.
  id uuid primary key,
  space_id uuid not null references public.spaces (id) on delete cascade,
  -- The audience: null is Everyone, otherwise one Team.
  -- No delete action: a Team with posts can't be deleted (delete_team), so a
  -- Team post can never quietly become an Everyone post.
  team_id uuid references public.teams (id),
  kind text not null
    check (kind in ('work_item', 'checklist', 'announcement', 'activity', 'file', 'report')),
  author_id uuid references public.profiles (id) on delete set null,
  title text not null check (length(trim(title)) between 1 and 200),
  body text check (length(body) <= 5000),
  place_text text check (length(place_text) <= 80),
  due_date date,
  -- Work items under one work item: one level only (create_work_item).
  parent_id uuid references public.space_posts (id) on delete cascade,
  -- Made from a Space chat message.
  source_message_id uuid references public.messages (id) on delete set null,
  -- Words the author chose to bring in from a direct message or a note:
  -- copied text, never a link to the private thread.
  quote jsonb check (quote is null or public.is_valid_post_quote(quote)),
  -- Templates come in migration 20.
  template_id uuid,
  status text not null default 'live' check (status in ('live', 'cancelled')),
  cancelled_by uuid references public.profiles (id) on delete set null,
  cancelled_at timestamptz,
  cancel_note text check (length(cancel_note) <= 500),
  edited_at timestamptz,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((status = 'cancelled') = (cancelled_at is not null)),
  check (parent_id is distinct from id)
);
create index space_posts_space_idx on public.space_posts (space_id, created_at desc)
  where deleted_at is null;
create index space_posts_parent_idx on public.space_posts (parent_id) where parent_id is not null;
create index space_posts_author_idx on public.space_posts (author_id);

create table public.post_edits (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.space_posts (id) on delete cascade,
  editor_id uuid references public.profiles (id) on delete set null,
  -- field -> {from, to}, for showing only ("Edited: due moved from Sun to Mon").
  changes jsonb not null check (jsonb_typeof(changes) = 'object' and changes <> '{}'::jsonb),
  created_at timestamptz not null default now()
);
create index post_edits_post_idx on public.post_edits (post_id, created_at);

create table public.post_files (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.space_posts (id) on delete cascade,
  -- An upload at <space>/posts/<post_id>/<file> in space-files, or a Library file.
  storage_path text unique,
  library_file_id uuid references public.library_files (id) on delete cascade,
  added_by uuid references public.profiles (id) on delete set null,
  sort smallint not null default 0,
  mime text,
  bytes bigint check (bytes is null or bytes >= 0),
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  created_at timestamptz not null default now(),
  check ((storage_path is null) <> (library_file_id is null))
);
create index post_files_post_idx on public.post_files (post_id, sort);
create index post_files_library_idx on public.post_files (library_file_id)
  where library_file_id is not null;

-- Every existing work item is a work_item post with the same id.
insert into public.space_posts (id, space_id, team_id, kind, author_id, title, place_text,
                                due_date, created_at)
select w.id, w.space_id, w.team_id, 'work_item', w.created_by, w.title, w.place_text,
       w.due_date, w.created_at
from public.work_items w;

alter table public.work_items
  add constraint work_items_post_fkey
  foreign key (id) references public.space_posts (id) on delete cascade;

-- ---------------------------------------------------------------------------
-- Guards on the new tables
-- ---------------------------------------------------------------------------

-- post_edits is the record of every change: kept like work_item_events.
create or replace function public.keep_post_edits()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'service_role' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE' then
    -- The post itself went (a cascade).
    if not exists (select 1 from public.space_posts p where p.id = old.post_id) then
      return old;
    end if;
  elsif (to_jsonb(new) - 'editor_id') = (to_jsonb(old) - 'editor_id')
        and new.editor_id is null
        and not exists (select 1 from public.profiles p where p.id = old.editor_id) then
    -- The editor's account was deleted (on delete set null).
    return new;
  end if;
  raise exception 'edits are kept for the record' using errcode = '42501';
end;
$$;

create trigger post_edits_append_only
  before update or delete on public.post_edits
  for each row execute function public.keep_post_edits();

-- A hidden (deleting) account writes nothing new (migration 16).
create trigger space_posts_hidden_writer before insert on public.space_posts
  for each row execute function public.refuse_hidden_writer();
create trigger post_edits_hidden_writer before insert on public.post_edits
  for each row execute function public.refuse_hidden_writer();
create trigger post_files_hidden_writer before insert on public.post_files
  for each row execute function public.refuse_hidden_writer();

-- A file the cleanup has claimed can't be attached (migration 10).
create or replace function public.refuse_claimed_post_file()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.storage_path is null then
    return new;
  end if;
  perform public.lock_file_path(new.storage_path);
  if exists (select 1 from public.file_cleanup_claims c where c.storage_path = new.storage_path) then
    raise exception 'this file was cleaned up; upload it again' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger post_files_not_claimed
  before insert or update of storage_path on public.post_files
  for each row execute function public.refuse_claimed_post_file();

-- ---------------------------------------------------------------------------
-- Who sees a post, who acts for its author
-- ---------------------------------------------------------------------------

-- The caller may see [p_post]: an active member of its Space, the post not
-- deleted, and either Everyone's, or the caller is in its Team, a Space
-- admin, its author or the work item's owner. Every read of a post, a work
-- item and what hangs on them goes through this.
create or replace function public.can_see_space_post(p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.space_posts p
    where p.id = p_post and p.deleted_at is null
      and public.is_member(p.space_id)
      and (p.team_id is null
           or p.author_id = auth.uid()
           or public.is_space_admin(p.space_id)
           or exists (select 1 from public.team_members tm
                      where tm.team_id = p.team_id and tm.profile_id = auth.uid())
           or exists (select 1 from public.work_items w
                      where w.id = p.id and w.owner_id = auth.uid())));
$$;

-- The author is gone from [p_space]: no longer an active member, purged
-- (null), or waiting for their account to be deleted (hidden for 30 days).
create or replace function public.author_is_gone(p_space uuid, p_author uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not public.is_active_member(p_space, p_author)
      or public.is_hidden_account(p_author);
$$;

-- The caller acts for [p_post]'s author: they are the author (an active,
-- not hidden member), or the author is gone and the caller is a Space admin
-- (is_space_admin is hidden-aware).
create or replace function public.acts_for_author(p_post public.space_posts)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and not public.is_hidden_account(auth.uid())
    and public.is_member(p_post.space_id)
    and ((p_post.author_id = auth.uid())
         or (public.author_is_gone(p_post.space_id, p_post.author_id)
             and public.is_space_admin(p_post.space_id)));
$$;

-- A post that is neither cancelled nor deleted.
create or replace function public.post_is_live(p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.space_posts p
                 where p.id = p_post and p.status = 'live' and p.deleted_at is null);
$$;

-- Someone other than the author added something, so Delete has ended
-- (clarification 2): an update, sign-off or any event by another person,
-- any child work item (whoever made it), or a file another person attached.
-- A purged person (null) counts as someone else.
create or replace function public.post_has_others(p_post public.space_posts)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.work_item_events e
                 where e.work_item_id = p_post.id
                   and e.actor_id is distinct from p_post.author_id)
      or exists (select 1 from public.space_posts c
                 where c.parent_id = p_post.id and c.deleted_at is null)
      or exists (select 1 from public.work_item_attachments a
                 where a.work_item_id = p_post.id
                   and a.added_by is distinct from p_post.author_id)
      or exists (select 1 from public.post_files f
                 where f.post_id = p_post.id
                   and f.added_by is distinct from p_post.author_id);
$$;

-- [p_profile] may check or send back [p_item] (Done): never its owner; its
-- author while they are an active member; a Space admin when the author is
-- gone (author_is_gone) or is the owner. The post must be live.
create or replace function public.may_check(p_item public.work_items, p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_profile is not null
    and p_item.owner_id is distinct from p_profile
    and not public.is_hidden_account(p_profile)
    and public.is_active_member(p_item.space_id, p_profile)
    and exists (
      select 1 from public.space_posts p
      join public.spaces s on s.id = p.space_id and s.deleted_at is null
      where p.id = p_item.id and p.status = 'live' and p.deleted_at is null
        and (p.author_id = p_profile
             or ((public.author_is_gone(p.space_id, p.author_id)
                  or p.author_id is not distinct from p_item.owner_id)
                 and exists (select 1 from public.space_members m
                             where m.space_id = p.space_id and m.profile_id = p_profile
                               and m.is_admin and m.left_at is null))));
$$;

-- Why [p_item] needs the caller, or null: 'open_owned' (theirs to sign,
-- including sent back), 'to_check' (Done, theirs to check), 'owner_left'
-- (Open, its owner can no longer sign; for whoever acts for the author).
create or replace function public.item_needs_me(p_item public.work_items, p_post public.space_posts)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_post.status <> 'live' or p_post.deleted_at is not null then null
    when p_item.status = 'open' and p_item.owner_id = auth.uid()
         and public.member_can(p_item.space_id, auth.uid(), 'mark_done') then 'open_owned'
    when p_item.status = 'done' and public.may_check(p_item, auth.uid()) then 'to_check'
    when p_item.status = 'open'
         and not public.member_can(p_item.space_id, p_item.owner_id, 'mark_done')
         and public.acts_for_author(p_post) then 'owner_left'
  end;
$$;

-- A name for Space records: null across a block or for a hidden account,
-- which the app shows as "Former member" (migration 16).
create or replace function public.space_person_name(p_profile uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when public.is_blocked_with(p.id) then null
              else nullif(trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
         end
  from public.profiles p where p.id = p_profile;
$$;

-- ---------------------------------------------------------------------------
-- Reading: the old tables follow the post's visibility
-- ---------------------------------------------------------------------------

drop policy work_items_read on public.work_items;
create policy work_items_read on public.work_items
  for select to authenticated using (public.can_see_space_post(id));

drop policy work_item_events_read on public.work_item_events;
create policy work_item_events_read on public.work_item_events
  for select to authenticated using (public.can_see_space_post(work_item_id));

drop policy work_item_evidence_read on public.work_item_evidence;
create policy work_item_evidence_read on public.work_item_evidence
  for select to authenticated using (public.can_see_space_post(work_item_id));

drop policy work_item_attachments_read on public.work_item_attachments;
create policy work_item_attachments_read on public.work_item_attachments
  for select to authenticated
  using (public.can_read_library_file(library_file_id) and public.can_see_space_post(work_item_id));

alter table public.space_posts enable row level security;
alter table public.post_edits enable row level security;
alter table public.post_files enable row level security;

create policy space_posts_read on public.space_posts
  for select to authenticated using (public.can_see_space_post(id));
create policy post_edits_read on public.post_edits
  for select to authenticated using (public.can_see_space_post(post_id));
-- A Library file shows only to whoever may read it in the Library.
create policy post_files_read on public.post_files
  for select to authenticated
  using (public.can_see_space_post(post_id)
         and (library_file_id is null or public.can_read_library_file(library_file_id)));

revoke all on public.space_posts, public.post_edits, public.post_files from anon, authenticated;
grant select on public.space_posts, public.post_edits, public.post_files to authenticated;
grant all on public.space_posts, public.post_edits, public.post_files to service_role;

-- ---------------------------------------------------------------------------
-- Writing a work item (A1)
-- ---------------------------------------------------------------------------

-- The post's own files: {path, mime, bytes, width, height} for an upload at
-- <space>/posts/<post>/<file> by the caller, or {library_file_id} for a
-- Library file they may read in that Space and Team. At most 10 per post.
create or replace function public.add_post_files(p_post public.space_posts, p_files jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_file jsonb;
  v_path text;
  v_mime text;
  v_lib public.library_files;
  v_count integer := 0;
  v_sort integer;
begin
  if p_files is null or jsonb_typeof(p_files) = 'null' then
    return 0;
  end if;
  if jsonb_typeof(p_files) <> 'array' then
    raise exception 'files must be a list' using errcode = '22023';
  end if;
  select coalesce(max(sort) + 1, 0) into v_sort from public.post_files where post_id = p_post.id;
  if (select count(*) from public.post_files where post_id = p_post.id)
     + jsonb_array_length(p_files) > 10 then
    raise exception 'at most 10 files on a post' using errcode = '22023';
  end if;
  for v_file in select * from jsonb_array_elements(p_files) loop
    if jsonb_typeof(v_file) <> 'object' then
      raise exception 'a file must be an object' using errcode = '22023';
    end if;
    if v_file ? 'library_file_id' then
      select * into v_lib from public.library_files f
      where f.id = (v_file ->> 'library_file_id')::uuid;
      if v_lib.id is null or v_lib.space_id <> p_post.space_id
         or not public.can_read_library_file(v_lib.id) then
        raise exception 'not allowed' using errcode = '42501';
      end if;
      if v_lib.team_id is not null and v_lib.team_id is distinct from p_post.team_id then
        raise exception 'a Team file can only go on that Team''s posts' using errcode = '22023';
      end if;
      insert into public.post_files (post_id, library_file_id, added_by, sort, mime, bytes)
      values (p_post.id, v_lib.id, auth.uid(), v_sort, v_lib.mime, v_lib.bytes);
    else
      v_path := v_file ->> 'path';
      if v_path is null or v_path like '%..%'
         or v_path not like p_post.space_id::text || '/posts/' || p_post.id::text || '/%'
         or array_length(string_to_array(v_path, '/'), 1) <> 4
         or not public.is_my_upload(v_path) then
        raise exception 'not allowed' using errcode = '42501';
      end if;
      v_mime := public.upload_mime(v_path, v_file ->> 'mime');
      if v_mime is null or not (v_mime like 'image/%' or v_mime = 'application/pdf') then
        raise exception 'photos and PDFs only' using errcode = '22023';
      end if;
      insert into public.post_files (post_id, storage_path, added_by, sort, mime, bytes, width, height)
      values (p_post.id, v_path, auth.uid(), v_sort, v_mime,
              nullif(v_file ->> 'bytes', '')::bigint,
              nullif(v_file ->> 'width', '')::integer,
              nullif(v_file ->> 'height', '')::integer);
    end if;
    v_sort := v_sort + 1;
    v_count := v_count + 1;
  end loop;
  return v_count;
exception
  when invalid_text_representation then
    raise exception 'a file is not valid' using errcode = '22023';
end;
$$;

-- Raise a work item: a work_item post and its item, in one step. New in
-- migration 18: a body, a parent (work items under one work item, one level),
-- the chat message it was made from, a quote, and the post's own files.
drop function public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid);

create function public.create_work_item(
  p_space uuid,
  p_title text,
  p_owner uuid,
  p_due date default null,
  p_team uuid default null,
  p_place text default null,
  p_evidence jsonb default '[]'::jsonb,
  p_id uuid default null,
  p_body text default null,
  p_parent uuid default null,
  p_source_message uuid default null,
  p_quote jsonb default null,
  p_files jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid := coalesce(p_id, gen_random_uuid());
  v_post public.space_posts;
  v_parent public.space_posts;
  v_msg public.messages;
  v_thread_team uuid;
  v_team uuid := p_team;
  v_item public.work_items;
  v_number integer;
  v_prefix text;
  v_event uuid;
begin
  -- The same id again (a retry): the same post, if it is the caller's.
  select * into v_post from public.space_posts where id = v_id;
  if v_post.id is not null then
    if v_post.author_id = v_me and v_post.space_id = p_space and v_post.kind = 'work_item' then
      return v_post.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if not public.can(p_space, 'create_items') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if public.folder_has_others_files(p_space, v_id)
     or public.folder_has_others_files_in(p_space::text || '/posts/' || v_id::text || '/') then
    raise exception 'this id is taken' using errcode = '42501';
  end if;
  if p_title is null or length(trim(p_title)) not between 2 and 140 then
    raise exception 'a title of 2 to 140 characters' using errcode = '22023';
  end if;
  if length(p_body) > 5000 then
    raise exception 'at most 5000 characters' using errcode = '22023';
  end if;
  if p_owner is null or not public.member_can(p_space, p_owner, 'mark_done') then
    raise exception 'choose an owner who can sign it as done' using errcode = '22023';
  end if;
  if v_team is not null and not exists (
       select 1 from public.teams t where t.id = v_team and t.space_id = p_space) then
    raise exception 'team not in this Space' using errcode = '22023';
  end if;
  if p_quote is not null and not public.is_valid_post_quote(p_quote) then
    raise exception 'a quote needs its text' using errcode = '22023';
  end if;

  -- Under one work item: a live, top-level work item the caller can see in
  -- this Space. A child of a Team item stays in that Team.
  if p_parent is not null then
    -- For share: a Cancel or Delete of the parent running now finishes
    -- first, and the checks below see its result.
    select * into v_parent from public.space_posts where id = p_parent for share;
    if v_parent.id is null or v_parent.space_id <> p_space or v_parent.kind <> 'work_item'
       or not public.can_see_space_post(v_parent.id) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if v_parent.status <> 'live' or v_parent.parent_id is not null then
      raise exception 'work items go under one live work item, one level only' using errcode = '22023';
    end if;
    if v_parent.team_id is not null then
      if v_team is null then
        v_team := v_parent.team_id;
      elsif v_team <> v_parent.team_id then
        raise exception 'a work item under a Team item stays in that Team' using errcode = '22023';
      end if;
    end if;
  end if;

  -- From a chat message the caller can read; a Team thread's message stays
  -- in that Team, so Team chat never becomes an Everyone post.
  if p_source_message is not null then
    select * into v_msg from public.messages where id = p_source_message;
    if v_msg.id is null or v_msg.space_id <> p_space or v_msg.deleted_at is not null
       or v_msg.kind = 'work_item' or not public.can_use_thread(v_msg.thread_id)
       or public.reported_by_me('message', v_msg.id) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    select t.team_id into v_thread_team from public.threads t where t.id = v_msg.thread_id;
    if v_thread_team is not null then
      if v_team is null then
        v_team := v_thread_team;
      elsif v_team <> v_thread_team then
        raise exception 'a Team chat message stays in that Team' using errcode = '22023';
      end if;
    end if;
  end if;

  insert into public.space_posts (id, space_id, team_id, kind, author_id, title, body,
                                  place_text, due_date, parent_id, source_message_id, quote)
  values (v_id, p_space, v_team, 'work_item', v_me, trim(p_title), nullif(trim(p_body), ''),
          nullif(trim(p_place), ''), p_due, p_parent, p_source_message, p_quote)
  returning * into v_post;

  update public.spaces s
  set next_item_number = s.next_item_number + 1
  where s.id = p_space
  returning s.next_item_number - 1, s.ref_prefix into v_number, v_prefix;

  insert into public.work_items (id, space_id, number, ref, title, owner_id, created_by,
                                 team_id, place_text, due_date)
  values (v_id, p_space, v_number, v_prefix || '-' || lpad(v_number::text, 3, '0'),
          trim(p_title), p_owner, v_me, v_team, nullif(trim(p_place), ''), p_due)
  returning * into v_item;

  insert into public.work_item_events (work_item_id, actor_id, kind)
  values (v_id, v_me, 'raised')
  returning id into v_event;
  perform public.add_evidence(v_item, v_event, p_evidence);
  perform public.add_post_files(v_post, p_files);
  return v_id;
end;
$$;

-- Sign as done: the owner, while the post is live.
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
  if not public.post_is_live(p_item) then
    raise exception 'this work item was cancelled' using errcode = 'P0001';
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

-- Check: the author (or an admin for them), never the owner (may_check).
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

-- Send back: as check_item, with one reason (the four app choices).
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
  -- The 0.9.0 test build still sends the old name; it is stored as the new
  -- one. Remove this once 0.9.0 is retired.
  v_reason text := case when p_reason = 'not_as_drawing' then 'not_as_asked' else p_reason end;
begin
  select * into v_item from public.work_items where id = p_item for update;
  if v_item.id is null or not public.may_check(v_item, v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.status <> 'done' then
    raise exception 'only a done item can be sent back' using errcode = 'P0001';
  end if;
  if v_reason is null
     or v_reason not in ('photo_missing', 'not_as_asked', 'not_finished', 'other') then
    raise exception 'choose a reason' using errcode = '22023';
  end if;
  if v_reason = 'other' and nullif(trim(p_note), '') is null then
    raise exception 'say what is wrong' using errcode = '22023';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, reason, note)
  values (p_item, v_me, 'sent_back', v_reason, nullif(trim(p_note), ''));
  update public.work_items set status = 'open', done_at = null where id = p_item;
end;
$$;

-- Give to someone else: the author; an admin only when the author has left.
create or replace function public.reassign_work_item(p_item uuid, p_owner uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_item public.work_items;
  v_post public.space_posts;
begin
  select * into v_item from public.work_items where id = p_item for update;
  select * into v_post from public.space_posts where id = p_item;
  if v_item.id is null or v_post.id is null or not public.acts_for_author(v_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_post.status <> 'live' or v_post.deleted_at is not null then
    raise exception 'this work item was cancelled' using errcode = 'P0001';
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

-- An update: the owner, and any Lead or Crew member who can see it.
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
  if v_item.id is null or not public.can_see_space_post(p_item)
     or not (v_item.owner_id = auth.uid()
             or public.member_pass(v_item.space_id) in ('lead', 'crew')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.post_is_live(p_item) then
    raise exception 'this work item was cancelled' using errcode = 'P0001';
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

-- A Library file on a work item: its author or owner, while it is live.
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
     or not public.can_see_space_post(p_item)
     or not public.can_read_library_file(p_file)
     or not (auth.uid() in (v_item.created_by, v_item.owner_id)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.post_is_live(p_item) then
    raise exception 'this work item was cancelled' using errcode = 'P0001';
  end if;
  if v_file.team_id is not null and v_file.team_id is distinct from v_item.team_id then
    raise exception 'a Team file can only go on that Team''s items' using errcode = '22023';
  end if;
  insert into public.work_item_attachments (work_item_id, library_file_id, added_by)
  values (p_item, p_file, auth.uid())
  on conflict do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Edit, delete, cancel (A0, A1)
-- ---------------------------------------------------------------------------

-- Two new kinds for the owner's Activity. Their pushes come in migration 19.
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow',
  'post_reply', 'post_useful', 'content_removed', 'appeal_decided'));

-- A post the author may still change: live, not deleted, and for a work
-- item only while Open (Send back reopens it; Checked locks it for good).
create or replace function public.post_is_editable(p_post public.space_posts)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_post.status = 'live' and p_post.deleted_at is null
    and (p_post.kind <> 'work_item'
         or exists (select 1 from public.work_items w
                    where w.id = p_post.id and w.status = 'open'));
$$;

-- Edit [p_id] (the author only). [p_changes] may hold: title, body, place,
-- due (a date, or null to clear), add_files (a list as in add_post_files)
-- and remove_files (post_files ids). Each saved change is one post_edits row
-- ("Edited: due moved from Sun to Mon") and tells a work item's owner.
-- The owner is changed with reassign_work_item; checklist points come in
-- migration 19.
create or replace function public.edit_space_post(p_id uuid, p_changes jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_owner uuid;
  v_diff jsonb := '{}'::jsonb;
  v_title text;
  v_body text;
  v_place text;
  v_due date;
  v_added integer := 0;
  v_removed integer := 0;
  v_edit uuid;
  v_key text;
begin
  select * into v_post from public.space_posts where id = p_id for update;
  -- The author, while they may still post (not lowered to Viewer, posting
  -- not switched off); files need the files right too.
  if v_post.id is null or v_post.author_id is distinct from v_me
     or not public.is_member(v_post.space_id) or public.is_hidden_account(v_me)
     or not public.can(v_post.space_id, 'create_items')
     or ((p_changes ? 'add_files' or p_changes ? 'remove_files')
         and not public.can(v_post.space_id, 'add_files')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_changes is null or jsonb_typeof(p_changes) <> 'object' then
    raise exception 'nothing to change' using errcode = '22023';
  end if;
  for v_key in select jsonb_object_keys(p_changes) loop
    if v_key not in ('title', 'body', 'place', 'due', 'add_files', 'remove_files') then
      raise exception 'that can''t be edited here' using errcode = '22023';
    end if;
  end loop;
  if v_post.kind = 'work_item' then
    perform 1 from public.work_items where id = p_id for update;
  end if;
  if not public.post_is_editable(v_post) then
    raise exception 'this can no longer be edited' using errcode = 'P0001';
  end if;

  if p_changes ? 'title' then
    v_title := trim(p_changes ->> 'title');
    if v_title is null or length(v_title) not between
         (case when v_post.kind = 'work_item' then 2 else 1 end)
         and (case when v_post.kind = 'work_item' then 140 else 200 end) then
      raise exception 'a title of the right length' using errcode = '22023';
    end if;
    if v_title is distinct from v_post.title then
      v_diff := v_diff || jsonb_build_object('title', jsonb_build_object('from', v_post.title, 'to', v_title));
    end if;
  end if;
  if p_changes ? 'body' then
    v_body := nullif(trim(p_changes ->> 'body'), '');
    if length(v_body) > 5000 then
      raise exception 'at most 5000 characters' using errcode = '22023';
    end if;
    if v_body is distinct from v_post.body then
      v_diff := v_diff || jsonb_build_object('body', jsonb_build_object('from', v_post.body, 'to', v_body));
    end if;
  end if;
  if p_changes ? 'place' then
    v_place := nullif(trim(p_changes ->> 'place'), '');
    if length(v_place) > 80 then
      raise exception 'at most 80 characters' using errcode = '22023';
    end if;
    if v_place is distinct from v_post.place_text then
      v_diff := v_diff || jsonb_build_object('place', jsonb_build_object('from', v_post.place_text, 'to', v_place));
    end if;
  end if;
  if p_changes ? 'due' then
    begin
      v_due := nullif(p_changes ->> 'due', '')::date;
    exception when others then
      raise exception 'a due date' using errcode = '22023';
    end;
    if v_due is distinct from v_post.due_date then
      v_diff := v_diff || jsonb_build_object('due', jsonb_build_object('from', v_post.due_date, 'to', v_due));
    end if;
  end if;

  if p_changes ? 'remove_files' then
    if jsonb_typeof(p_changes -> 'remove_files') <> 'array' then
      raise exception 'files must be a list' using errcode = '22023';
    end if;
    -- The post's own files only. An upload goes to the cleanup once nothing
    -- references it.
    with gone as (
      delete from public.post_files f
      where f.post_id = p_id
        and f.id::text in (select jsonb_array_elements_text(p_changes -> 'remove_files'))
      returning 1)
    select count(*) into v_removed from gone;
  end if;
  if p_changes ? 'add_files' then
    v_added := public.add_post_files(v_post, p_changes -> 'add_files');
  end if;
  if v_added > 0 or v_removed > 0 then
    v_diff := v_diff || jsonb_build_object('files', jsonb_build_object('added', v_added, 'removed', v_removed));
  end if;

  if v_diff = '{}'::jsonb then
    return;
  end if;

  update public.space_posts
  set title = coalesce(v_title, title),
      body = case when p_changes ? 'body' then v_body else body end,
      place_text = case when p_changes ? 'place' then v_place else place_text end,
      due_date = case when p_changes ? 'due' then v_due else due_date end,
      edited_at = now()
  where id = p_id;
  -- The work item keeps the same words, for everything that reads it.
  if v_post.kind = 'work_item' then
    update public.work_items
    set title = coalesce(v_title, title),
        place_text = case when p_changes ? 'place' then v_place else place_text end,
        due_date = case when p_changes ? 'due' then v_due else due_date end
    where id = p_id
    returning owner_id into v_owner;
  end if;

  insert into public.post_edits (post_id, editor_id, changes)
  values (p_id, v_me, v_diff)
  returning id into v_edit;
  if v_owner is not null then
    perform public.add_notification(v_owner, 'item_edited', v_me, v_post.space_id, p_id,
                                    p_payload => jsonb_build_object('edit_id', v_edit));
  end if;
end;
$$;

-- Delete [p_id]: the author only, and only while nobody else has added
-- anything (post_has_others). It leaves the daybook for everyone; its own
-- uploads go to the cleanup. After that, Cancel.
create or replace function public.delete_space_post(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post public.space_posts;
begin
  select * into v_post from public.space_posts where id = p_id for update;
  if v_post.id is null or v_post.author_id is distinct from auth.uid()
     or not public.is_member(v_post.space_id) or public.is_hidden_account(auth.uid()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_post.deleted_at is not null then
    return;
  end if;
  if v_post.kind = 'work_item' then
    perform 1 from public.work_items where id = p_id for update;
  end if;
  if public.post_has_others(v_post) then
    raise exception 'someone has added to this; cancel it instead' using errcode = 'P0001';
  end if;
  update public.space_posts set deleted_at = now() where id = p_id;
end;
$$;

-- Cancel [p_id]: the author, or an admin when the author has left. It stays
-- in the daybook with a CANCELLED stamp. A Checked item can't be cancelled.
-- Work items under it are cancelled with it, except those already Checked.
-- Each owner is told.
create or replace function public.cancel_space_post(p_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_row record;
begin
  select * into v_post from public.space_posts where id = p_id for update;
  if v_post.id is null or not public.acts_for_author(v_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_post.deleted_at is not null or v_post.status <> 'live' then
    raise exception 'this was already removed' using errcode = 'P0001';
  end if;
  if length(p_note) > 500 then
    raise exception 'at most 500 characters' using errcode = '22023';
  end if;
  -- Lock the work items first, so a sign-off or check running now finishes
  -- before the Checked test below (and none lands after the cancel).
  perform 1 from public.work_items w
  where w.id = p_id or w.id in (select c.id from public.space_posts c where c.parent_id = p_id)
  order by w.id
  for update;
  if exists (select 1 from public.work_items w where w.id = p_id and w.status = 'checked') then
    raise exception 'checked work can''t be cancelled' using errcode = 'P0001';
  end if;

  for v_row in
    select p.id, p.space_id, w.owner_id
    from public.space_posts p
    left join public.work_items w on w.id = p.id
    where (p.id = p_id or p.parent_id = p_id)
      and p.status = 'live' and p.deleted_at is null
      and (w.id is null or w.status <> 'checked')
    order by p.id
    for update of p
  loop
    update public.space_posts
    set status = 'cancelled', cancelled_by = v_me, cancelled_at = now(),
        cancel_note = case when id = p_id then nullif(trim(p_note), '') end
    where id = v_row.id;
    if v_row.owner_id is not null then
      perform public.add_notification(v_row.owner_id, 'item_cancelled', v_me, v_row.space_id,
                                      v_row.id);
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Needs you (A1): theirs to sign, theirs to check as the author (or as an
-- admin for an author who left), owner-left items for whoever acts for the
-- author, and join requests for admins. No check_items branch any more.
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
    select m.space_id
    from public.space_members m
    join public.spaces s on s.id = m.space_id and s.deleted_at is null
    where m.profile_id = auth.uid() and m.left_at is null
  ),
  items as (
    select w.space_id, w.id, w.created_at, w.done_at, public.item_needs_me(w, p) as need
    from mine
    join public.work_items w on w.space_id = mine.space_id and w.status in ('open', 'done')
    join public.space_posts p on p.id = w.id and p.status = 'live' and p.deleted_at is null
    where public.can_see_space_post(w.id)
  )
  select i.need, i.space_id, i.id, null::uuid,
         case when i.need = 'to_check' then i.done_at else i.created_at end
  from items i
  where i.need is not null
  union all
  select 'join_request', r.space_id, null::uuid, r.id, r.created_at
  from mine
  join public.space_join_requests r
    on r.space_id = mine.space_id and r.status = 'pending'
  where public.is_space_admin(mine.space_id);
$$;

-- ---------------------------------------------------------------------------
-- Reading the daybook (A1)
-- ---------------------------------------------------------------------------

-- One post as the daybook shows it. [p_full] adds what opening it in place
-- needs: the whole record, files, edits and the work items under it.
create or replace function public.space_post_json(p_post public.space_posts, p_full boolean)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', p_post.id,
    'space_id', p_post.space_id,
    'kind', p_post.kind,
    'status', p_post.status,
    'team_id', p_post.team_id,
    'author_id', p_post.author_id,
    'author_name', public.space_person_name(p_post.author_id),
    'title', p_post.title,
    'body', p_post.body,
    'place', p_post.place_text,
    'due_date', p_post.due_date,
    'parent_id', p_post.parent_id,
    'source_message_id', p_post.source_message_id,
    'quote', p_post.quote,
    'created_at', p_post.created_at,
    'edited_at', p_post.edited_at,
    'cancelled_at', p_post.cancelled_at,
    'cancelled_by_name', public.space_person_name(p_post.cancelled_by),
    'cancel_note', p_post.cancel_note,
    'item', (
      select jsonb_build_object(
        'ref', w.ref, 'status', w.status,
        'owner_id', w.owner_id, 'owner_name', public.space_person_name(w.owner_id),
        'done_at', w.done_at, 'checked_at', w.checked_at,
        'checked_by_name', public.space_person_name(w.checked_by))
      from public.work_items w where w.id = p_post.id),
    -- The latest stamp on the slip.
    'stamp', (
      select case
        when p_post.status = 'cancelled' then jsonb_build_object(
          'kind', 'cancelled', 'at', p_post.cancelled_at,
          'by_name', public.space_person_name(p_post.cancelled_by))
        when w.status = 'checked' then jsonb_build_object(
          'kind', 'checked', 'at', w.checked_at, 'by_name', public.space_person_name(w.checked_by))
        when w.status = 'done' then jsonb_build_object(
          'kind', 'done', 'at', w.done_at, 'by_name', public.space_person_name(w.owner_id))
        when last.kind = 'sent_back' then jsonb_build_object(
          'kind', 'sent_back', 'at', last.created_at, 'reason', last.reason,
          'by_name', public.space_person_name(last.actor_id))
      end
      -- Any kind can be cancelled; only work items have the other stamps.
      from (select 1) one
      left join public.work_items w on w.id = p_post.id
      left join lateral (
        select e.kind, e.created_at, e.reason, e.actor_id
        from public.work_item_events e
        where e.work_item_id = w.id and e.kind in ('done', 'checked', 'sent_back')
        order by e.created_at desc, e.id desc limit 1) last on true),
    -- The paper clip: this needs the caller.
    'needs_me', coalesce((
      select public.item_needs_me(w, p_post) is not null
      from public.work_items w where w.id = p_post.id), false),
    'cover_path', (
      select f.storage_path from public.post_files f
      where f.post_id = p_post.id and f.storage_path is not null and f.mime like 'image/%'
      order by f.sort, f.created_at limit 1),
    'children', (
      select jsonb_build_object(
        'total', count(*),
        'checked', count(*) filter (where w.status = 'checked'))
      from public.space_posts c
      join public.work_items w on w.id = c.id
      where c.parent_id = p_post.id and c.deleted_at is null and c.status = 'live'
        and public.can_see_space_post(c.id)
      having count(*) > 0),
    'edits', (
      select jsonb_agg(jsonb_build_object(
               'at', e.created_at, 'by_name', public.space_person_name(e.editor_id),
               'changes', e.changes) order by e.created_at desc)
      from (select * from public.post_edits pe where pe.post_id = p_post.id
            order by pe.created_at desc limit case when p_full then 1000 else 3 end) e)
  )) || case when not p_full then '{}'::jsonb else jsonb_strip_nulls(jsonb_build_object(
    'files', (
      select jsonb_agg(jsonb_build_object(
               'id', f.id, 'path', f.storage_path, 'library_file_id', f.library_file_id,
               'name', lf.name, 'mime', f.mime, 'bytes', f.bytes,
               'width', f.width, 'height', f.height) order by f.sort, f.created_at)
      from public.post_files f
      left join public.library_files lf on lf.id = f.library_file_id
      where f.post_id = p_post.id
        and (f.library_file_id is null or public.can_read_library_file(f.library_file_id))),
    'events', (
      select jsonb_agg(jsonb_build_object(
               'id', e.id, 'kind', e.kind, 'actor_id', e.actor_id,
               'actor_name', public.space_person_name(e.actor_id),
               'note', e.note, 'reason', e.reason,
               'from_owner_name', public.space_person_name(e.from_owner_id),
               'to_owner_name', public.space_person_name(e.to_owner_id),
               'at', e.created_at,
               'photos', (select jsonb_agg(jsonb_build_object(
                                   'path', ev.storage_path, 'taken_at', ev.taken_at,
                                   'place', ev.place_text) order by ev.created_at)
                          from public.work_item_evidence ev where ev.event_id = e.id))
             order by e.created_at, e.id)
      from public.work_item_events e where e.work_item_id = p_post.id),
    'attachments', (
      select jsonb_agg(jsonb_build_object('library_file_id', lf.id, 'name', lf.name,
                                          'mime', lf.mime, 'bytes', lf.bytes)
                       order by a.created_at)
      from public.work_item_attachments a
      join public.library_files lf on lf.id = a.library_file_id
      where a.work_item_id = p_post.id and public.can_read_library_file(lf.id)),
    'under', (
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'title', c.title, 'status', c.status, 'ref', w.ref,
               'item_status', w.status, 'owner_name', public.space_person_name(w.owner_id))
             order by c.created_at, c.id)
      from public.space_posts c
      join public.work_items w on w.id = c.id
      where c.parent_id = p_post.id and c.deleted_at is null
        and public.can_see_space_post(c.id)),
    'parent', (
      select jsonb_build_object('id', pp.id, 'title', pp.title)
      from public.space_posts pp
      where pp.id = p_post.parent_id and public.can_see_space_post(pp.id))
  )) end;
$$;

-- The daybook of [p_space], newest first: [p_limit] posts (at most 100)
-- after the cursor ([p_before], [p_before_id]: the last post of the page
-- before, so posts made at the same moment aren't skipped). Active members
-- only; Team posts only for that Team, the admins, their author and the
-- owner (can_see_space_post).
create or replace function public.daybook_page(
  p_space uuid,
  p_before timestamptz default null,
  p_limit integer default 30,
  p_before_id uuid default null
)
returns table (id uuid, created_at timestamptz, post jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.created_at, public.space_post_json(p, false)
  from public.space_posts p
  where p.space_id = p_space
    and public.is_member(p_space)
    and p.deleted_at is null
    and (p_before is null
         or (p_before_id is null and p.created_at < p_before)
         or (p.created_at, p.id) < (p_before, p_before_id))
    and public.can_see_space_post(p.id)
  order by p.created_at desc, p.id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

-- One post in full, for opening it in place. Null when the caller may not
-- see it.
create or replace function public.post_page(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select public.space_post_json(p, true)
  from public.space_posts p
  where p.id = p_id and public.can_see_space_post(p.id);
$$;

-- ---------------------------------------------------------------------------
-- Files: the post's own folder, <space>/posts/<post_id>/<file>
-- ---------------------------------------------------------------------------

-- A file is in use while a live record points at it. A deleted post's own
-- uploads and photos are released, so the cleanup can take them (Delete is
-- only possible before anyone else added anything).
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
                 where f.storage_path = p_path and p.deleted_at is null);
$$;

-- A Library file a live work item or post uses can't be deleted, and stays
-- when its chat message goes.
create or replace function public.library_file_in_use(p_file uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.work_item_attachments a
                 join public.space_posts p on p.id = a.work_item_id
                 where a.library_file_id = p_file and p.deleted_at is null)
      or exists (select 1 from public.post_files f
                 join public.space_posts p on p.id = f.post_id
                 where f.library_file_id = p_file and p.deleted_at is null);
$$;

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
  if public.library_file_in_use(p_file) then
    raise exception 'a work item uses this file' using errcode = 'P0001';
  end if;
  update public.library_files set deleted_at = now(), deleted_by = auth.uid() where id = p_file;
end;
$$;

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
    and not public.library_file_in_use(f.id);
end;
$$;

-- Uploads (storage policy space_files_insert). New: the post folder.
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
  v_post public.space_posts;
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

  -- A post's own photos and PDFs: <space>/posts/<post>/<file> (migration 18).
  -- Before the post exists, whoever may post; after, its author while it
  -- can still be edited.
  if v_parts[2] = 'posts' then
    if array_length(v_parts, 1) <> 4 or v_parts[4] = ''
       or lower(v_parts[4]) !~ '\.(jpe?g|png|webp|heic|pdf)$' then
      return false;
    end if;
    begin
      v_space := v_parts[1]::uuid;
      v_id := v_parts[3]::uuid;
    exception when invalid_text_representation then
      return false;
    end;
    select * into v_post from public.space_posts where id = v_id;
    if v_post.id is null then
      return public.can(v_space, 'create_items')
        and not exists (select 1 from public.work_items w where w.id = v_id)
        and not public.folder_has_others_files_in(v_parts[1] || '/posts/' || v_parts[3] || '/');
    end if;
    return v_post.space_id = v_space
      and v_post.author_id = auth.uid()
      and public.is_member(v_space)
      and public.can(v_space, 'create_items')
      and public.can(v_space, 'add_files')
      and public.post_is_editable(v_post);
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
      and not exists (select 1 from public.space_posts p where p.id = v_id)
      and not public.folder_has_others_files(v_space, v_id);
  end if;
  return v_item.space_id = v_space
    and public.is_member(v_space)
    and auth.uid() in (v_item.created_by, v_item.owner_id)
    and public.member_pass(v_space) <> 'viewer'
    and public.post_is_live(v_id);
end;
$$;

-- Reads (storage policy space_files_read). Work item photos and post files
-- follow the post's visibility (Team posts included).
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
        and public.can_read_library_file(f.id));
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
-- Teams: a Team with posts stays for the record
-- ---------------------------------------------------------------------------

-- Work items used to post a card into the Team's chat, which kept the Team.
-- Without cards, a Team with daybook posts (deleted or cancelled ones too)
-- is refused here; otherwise as in migration 9.
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
     or exists (select 1 from public.library_files f where f.team_id = p_team)
     or exists (select 1 from public.space_posts p where p.team_id = p_team) then
    raise exception 'this Team has chat, files or posts; it stays in the record'
      using errcode = 'P0001';
  end if;
  delete from public.teams where id = p_team;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.is_valid_post_quote(jsonb),
  public.can_see_space_post(uuid),
  public.author_is_gone(uuid, uuid),
  public.acts_for_author(public.space_posts),
  public.post_is_live(uuid),
  public.post_has_others(public.space_posts),
  public.item_needs_me(public.work_items, public.space_posts),
  public.space_person_name(uuid),
  public.add_post_files(public.space_posts, jsonb),
  public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid, uuid, jsonb, jsonb),
  public.post_is_editable(public.space_posts),
  public.edit_space_post(uuid, jsonb),
  public.delete_space_post(uuid),
  public.cancel_space_post(uuid, text),
  public.space_post_json(public.space_posts, boolean),
  public.daybook_page(uuid, timestamptz, integer, uuid),
  public.post_page(uuid),
  public.library_file_in_use(uuid),
  public.keep_post_edits(),
  public.refuse_claimed_post_file()
  from public, anon;
-- Internal: answers about anyone, or writes without its own checks.
revoke execute on function
  public.is_valid_post_quote(jsonb),
  public.author_is_gone(uuid, uuid),
  public.acts_for_author(public.space_posts),
  public.post_is_live(uuid),
  public.post_has_others(public.space_posts),
  public.item_needs_me(public.work_items, public.space_posts),
  public.space_person_name(uuid),
  public.add_post_files(public.space_posts, jsonb),
  public.post_is_editable(public.space_posts),
  public.space_post_json(public.space_posts, boolean),
  public.library_file_in_use(uuid),
  public.keep_post_edits(),
  public.refuse_claimed_post_file()
  from authenticated;
-- The read rules call it as the signed-in person; it answers only about them.
grant execute on function public.can_see_space_post(uuid) to authenticated;
grant execute on function
  public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid, uuid, jsonb, jsonb),
  public.edit_space_post(uuid, jsonb),
  public.delete_space_post(uuid),
  public.cancel_space_post(uuid, text),
  public.daybook_page(uuid, timestamptz, integer, uuid),
  public.post_page(uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Copies of live functions with one change each
-- ---------------------------------------------------------------------------

-- Today: a work item's events only for whoever may see it (Team posts, deleted posts) (as in 20261013120000_safety.sql, with that change only).
create or replace function public.today_in_spaces(p_day_start timestamptz)
returns table (
  space_id uuid,
  space_name text,
  project_id uuid,
  project_name text,
  -- 'work_item', 'library' or 'chat': the Space tab to open.
  change text,
  work_item_id uuid,
  work_item_ref text,
  work_item_title text,
  event_kind text,
  file_id uuid,
  file_name text,
  thread_id uuid,
  team_id uuid,
  message_kind text,
  message_body text,
  actor_id uuid,
  actor_name text,
  at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select m.space_id, s.name, s.project_id,
           greatest(coalesce(v.seen_at, '-infinity'::timestamptz),
                    public.day_start(p_day_start)) as since
    from public.space_members m
    join public.spaces s on s.id = m.space_id and s.deleted_at is null
    left join public.space_visits v
      on v.space_id = m.space_id and v.profile_id = auth.uid()
    where m.profile_id = auth.uid() and m.left_at is null
  ),
  changes as (
    select mine.space_id, 1 as rank, ev.created_at as at, 'work_item' as change,
           w.id as item, w.ref, w.title, ev.kind as event_kind,
           null::uuid as file, null::text as file_name,
           null::uuid as thread, null::uuid as team,
           null::text as msg_kind, null::text as msg_body, ev.actor_id
    from public.work_item_events ev
    join public.work_items w on w.id = ev.work_item_id
    join mine on mine.space_id = w.space_id
    where ev.created_at > public.day_start(p_day_start)
      and ev.created_at > mine.since
      and ev.actor_id is distinct from auth.uid()
      and public.can_see_space_post(w.id)
    union all
    select mine.space_id, 2, f.created_at, 'library', null, null, null, null,
           f.id, f.name, null, f.team_id, null, null, f.uploaded_by
    from mine
    join public.library_files f
      on f.space_id = mine.space_id and f.created_at > mine.since
    where f.deleted_at is null and f.uploaded_by is distinct from auth.uid()
      and public.can_read_library_file(f.id)
    union all
    -- Each thread you may read once, then its newest message by someone
    -- else since your visit (messages_thread_idx).
    select mine.space_id, 3, msg.created_at, 'chat', null, null, null, null,
           null, null, t.id, t.team_id, msg.kind, left(msg.body, 120),
           msg.author_id
    from mine
    join public.threads t on t.space_id = mine.space_id
    cross join lateral (
      select x.created_at, x.kind, x.body, x.author_id
      from public.messages x
      where x.thread_id = t.id and x.created_at > mine.since
        and x.deleted_at is null and x.author_id is distinct from auth.uid()
        and not public.blocked_between(auth.uid(), x.author_id)
        and not public.reported_by_me('message', x.id)
      order by x.created_at desc
      limit 1
    ) msg
    where public.can_use_thread(t.id)
  ),
  best as (
    select distinct on (c.space_id) c.*
    from changes c
    where not public.blocked_between(auth.uid(), c.actor_id)
    order by c.space_id, c.rank, c.at desc
  )
  select b.space_id, mine.name, mine.project_id, p.name, b.change,
         b.item, b.ref, b.title, b.event_kind, b.file, b.file_name,
         b.thread, b.team, b.msg_kind, b.msg_body, b.actor_id,
         nullif(trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')), ''),
         b.at
  from best b
  join mine on mine.space_id = b.space_id
  left join public.projects p on p.id = mine.project_id
  left join public.profiles a on a.id = b.actor_id
  order by b.at desc;
$$;

-- Activity: work item rows follow the post's visibility (as in 20261013120000_safety.sql, with that change only).
create or replace function public.activity_rows()
returns setof public.activity_row
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select n.*,
           case when n.kind in ('role_confirmed', 'content_removed', 'appeal_decided') then 'record'
                when n.kind = 'follow' then 'network'
                when n.kind in ('post_reply', 'post_useful') then 'posts'
                else 'space' end as group_kind
    from public.notifications n
    where n.profile_id = auth.uid()
      and n.created_at >= now() - interval '7 days'
      and not public.blocked_between(auth.uid(), n.actor_id)
  ),
  shown as (
    select r.*, s.name as space_name, m.pass, w.ref, w.title,
           case when r.kind = 'post_reply' then left(pr.body, 120)
                when r.post_id is not null then left(p.body, 120) end as context,
           jr.status as request_status, cp.project_id, prj.name as project_name,
           nullif(trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')), '')
             as actor_name
    from mine r
    left join public.spaces s on s.id = r.space_id
    left join public.space_members m
      on m.space_id = r.space_id and m.profile_id = auth.uid() and m.left_at is null
    left join public.work_items w on w.id = r.work_item_id
    left join public.posts p on p.id = r.post_id
    left join public.post_replies pr on pr.id = r.reply_id
    left join public.space_join_requests jr on jr.id = r.request_id
    left join public.cv_projects cp on cp.id = (r.payload ->> 'cv_project_id')::uuid
    left join public.projects prj on prj.id = cp.project_id
    left join public.profiles a on a.id = r.actor_id
    where (r.space_id is null or (s.deleted_at is null and m.profile_id is not null))
      -- Requests to join only while you are still an admin.
      and (r.kind <> 'join_request' or m.is_admin)
      -- Post rows only while you may see the post (not across a block).
      and (r.post_id is null or public.can_see_post(r.post_id))
      and (r.reply_id is null or pr.deleted_at is null)
      -- A reply you reported, with its text, leaves your Activity (review 24).
      and (r.reply_id is null or not public.reported_by_me('reply', r.reply_id))
      and (r.kind <> 'role_confirmed' or cp.id is not null)
      -- A work item row only while you may see it (a deleted post leaves).
      and (r.work_item_id is null or public.can_see_space_post(r.work_item_id))
  )
  select x.id, x.kind, x.group_kind, x.space_id, x.space_name, x.pass,
         x.work_item_id, x.ref, x.title, x.post_id, x.reply_id, x.context,
         x.request_id, x.request_status, x.project_id, x.project_name,
         x.actor_id, x.actor_name, x.payload, x.created_at, x.read_at,
         (row_number() over (partition by x.group_kind, x.space_id
                             order by x.created_at, x.id))::int,
         case when x.kind = 'post_useful' then
           array(select u.name from public.useful_names(x.post_id) u) end
  from shown x;
$$;

-- Download my data: the person's daybook posts and edits too (as in 20261013130000_account.sql, with that change only).
create or replace function public.export_my_data(p_request uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
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
                              'created_at', p.created_at, 'deleted_at', p.deleted_at))
                            from public.space_posts p where p.author_id = r.profile_id), '[]'),
    'post_edits', coalesce((select jsonb_agg(jsonb_build_object(
                             'changes', e.changes, 'created_at', e.created_at))
                           from public.post_edits e where e.editor_id = r.profile_id), '[]'),
    'push_settings', (select to_jsonb(ps) from public.push_settings ps where ps.profile_id = r.profile_id)
  )
  from public.data_requests r
  where r.id = p_request;
$$;

-- Moderation: a Library file a live post uses stays when its message is removed (as in 20261013120000_safety.sql, with that change only).
create or replace function public.decide_report(p_id uuid, p_action text, p_reason text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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
$$;
