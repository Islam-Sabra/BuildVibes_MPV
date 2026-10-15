-- Migration 19: the other kinds of post (review 33 A2 and its
-- clarifications; docs/product/daybook.md). Branch post-kinds-db. Not live.
--
-- Checklists, announcements, scheduled activities and file posts, next to
-- work items in the daybook:
-- - space_posts gains pinned_until (announcements), starts_at and ends_at
--   (activities) and library_file_id (file posts). post_others keeps the
--   first tick or acknowledgement by someone other than the author; it
--   ends Delete for good, even if that is undone later, and nobody reads it.
-- - post_people: who a checklist or an activity is for. checklist_points:
--   a checklist's or a work item's points. post_acks: Got it, Received,
--   On my way, In my calendar. activity_reminders: one "starts in 30 min"
--   push per person and start time (service role only).
-- - create_space_post makes the four kinds (the Home feed owns
--   create_post; work items stay with create_work_item). tick_point, ack,
--   post_acks_for (the author only: who, never how many), daybook_extras
--   (pinned announcements and activities on a day) and
--   due_activity_reminders (cron, every 5 minutes; the schedule is in
--   supabase/ops/activity_reminders_cron.sql and goes live with its own yes).
-- - edit_space_post edits points (a ticked point can't be removed or
--   reworded), people, the pin and the activity's time.
-- - Notifications: announcement_new, checklist_for_you, activity_invited,
--   file_new_version, and item_edited / item_cancelled for the people of a
--   checklist or an activity too; notifications.space_post_id points at the
--   post. Pushes for these and for item_edited and item_cancelled (deferred
--   from migration 18), and activity_starting (no Activity row). The push
--   function needs its new texts deployed before this goes live.
--
-- Choices for the lead to confirm (review 36):
-- - Ack faces: the author only (A2), or an admin acting for an author who
--   is gone. The prototype also shows Received faces to others; one helper
--   (may_see_acks) decides.
-- - activity_starting is sent even when the person set the Space to Off
--   (A2: "always"), since they were invited or added it themselves.
-- - A checklist with unticked points is in its people's Needs you
--   (kind checklist_for_you).
-- - On my way is taken from 3 hours before the start to the end (or an
--   hour after the start when there is no end); In my calendar until the end.
-- - Points on a work item are added by editing it (create_work_item is
--   unchanged); its points are ticked and edited only while it is Open.

-- ---------------------------------------------------------------------------
-- Columns on space_posts
-- ---------------------------------------------------------------------------

alter table public.space_posts
  add column pinned_until timestamptz,
  add column starts_at timestamptz,
  add column ends_at timestamptz,
  -- The Library file a file post shares. No delete action: a Library file a
  -- post uses can't be deleted (library_file_in_use).
  add column library_file_id uuid references public.library_files (id),
  add constraint space_posts_pinned_kind check (pinned_until is null or kind = 'announcement'),
  add constraint space_posts_starts_kind check ((starts_at is not null) = (kind = 'activity')),
  add constraint space_posts_ends_after check (ends_at is null or ends_at > starts_at),
  add constraint space_posts_file_kind check ((library_file_id is not null) = (kind = 'file'));

create index space_posts_starts_idx on public.space_posts (starts_at)
  where kind = 'activity' and status = 'live' and deleted_at is null;
create index space_posts_pinned_idx on public.space_posts (space_id, pinned_until)
  where pinned_until is not null and status = 'live' and deleted_at is null;
create index space_posts_library_file_idx on public.space_posts (library_file_id)
  where library_file_id is not null;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

-- Who a checklist or an activity is for. A purged person is for nothing.
create table public.post_people (
  post_id uuid not null references public.space_posts (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'for' check (role in ('for')),
  added_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (post_id, profile_id, role)
);
create index post_people_profile_idx on public.post_people (profile_id);

-- A checklist's or a work item's points. A tick keeps its time when the
-- person who ticked is purged ("Former member").
create table public.checklist_points (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.space_posts (id) on delete cascade,
  sort integer not null,
  text text not null check (length(trim(text)) between 1 and 300),
  ticked_by uuid references public.profiles (id) on delete set null,
  ticked_at timestamptz,
  created_at timestamptz not null default now(),
  check (ticked_by is null or ticked_at is not null)
);
create index checklist_points_post_idx on public.checklist_points (post_id, sort);

-- Got it (announcements), Received (files), On my way and In my calendar
-- (activities). Who, never how many: only the author reads others'.
create table public.post_acks (
  post_id uuid not null references public.space_posts (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('got_it', 'received', 'on_my_way', 'in_my_calendar')),
  created_at timestamptz not null default now(),
  primary key (post_id, profile_id, kind)
);
create index post_acks_profile_idx on public.post_acks (profile_id);

-- Someone other than the author ticked or acknowledged [post_id], at
-- [first_at]. Kept when it is taken back, so Delete stays ended. Read only
-- inside the definer functions: it would tell readers that someone
-- acknowledged, and when.
create table public.post_others (
  post_id uuid primary key references public.space_posts (id) on delete cascade,
  first_at timestamptz not null default now()
);

-- "Starts in 30 min" was sent to this person for this start time. A moved
-- activity is reminded again. Service role only.
create table public.activity_reminders (
  post_id uuid not null references public.space_posts (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  starts_at timestamptz not null,
  sent_at timestamptz not null default now(),
  primary key (post_id, profile_id, starts_at)
);

create trigger post_people_hidden_writer before insert on public.post_people
  for each row execute function public.refuse_hidden_writer();
create trigger checklist_points_hidden_writer before insert on public.checklist_points
  for each row execute function public.refuse_hidden_writer();
create trigger post_acks_hidden_writer before insert on public.post_acks
  for each row execute function public.refuse_hidden_writer();

-- Notifications about a post that isn't a work item (a work item's rows
-- keep using work_item_id, the same id).
alter table public.notifications
  add column space_post_id uuid references public.space_posts (id) on delete cascade;
create index notifications_space_post_idx on public.notifications (space_post_id)
  where space_post_id is not null;

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'announcement_new', 'checklist_for_you', 'activity_invited', 'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow',
  'post_reply', 'post_useful', 'content_removed', 'appeal_decided'));

-- activity_starting is a push only (no Activity row).
alter table public.push_queue drop constraint push_queue_kind_check;
alter table public.push_queue add constraint push_queue_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'announcement_new', 'checklist_for_you', 'activity_invited', 'activity_starting',
  'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow', 'post_reply', 'chat_message'));

-- ---------------------------------------------------------------------------
-- Who sees what
-- ---------------------------------------------------------------------------

-- [p_profile] may see [p_post], as can_see_space_post answers for the
-- signed-in person. For fan-out and cron, where the caller isn't the reader.
create or replace function public.can_see_space_post_as(p_post uuid, p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.space_posts p
    join public.spaces s on s.id = p.space_id and s.deleted_at is null
    join public.space_members m
      on m.space_id = p.space_id and m.profile_id = p_profile and m.left_at is null
    where p.id = p_post and p.deleted_at is null
      and not public.is_hidden_account(p_profile)
      and (p.team_id is null
           or p.author_id = p_profile
           or m.is_admin
           or exists (select 1 from public.team_members tm
                      where tm.team_id = p.team_id and tm.profile_id = p_profile)
           or exists (select 1 from public.work_items w
                      where w.id = p.id and w.owner_id = p_profile)));
$$;

-- Who may read the faces of a post's acknowledgements: its author, or an
-- admin acting for an author who is gone (review 33 A2; one place to
-- change if the lead opens Received faces to more people).
create or replace function public.may_see_acks(p_post public.space_posts)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.can_see_space_post(p_post.id) and public.acts_for_author(p_post);
$$;

-- [p_profile] may be one of the people of a [p_kind] post in [p_space]
-- for [p_team]: an active member, not hidden; Lead or Crew for a
-- checklist (they tick), anyone for an activity (a Viewer attends); for a
-- Team post, in that Team or a Space admin.
create or replace function public.may_be_post_person(p_space uuid, p_team uuid, p_kind text,
                                                    p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.space_members m
    where m.space_id = p_space and m.profile_id = p_profile and m.left_at is null
      and not public.is_hidden_account(p_profile)
      and (p_kind = 'activity' or m.pass in ('lead', 'crew'))
      and (p_team is null or m.is_admin
           or exists (select 1 from public.team_members tm
                      where tm.team_id = p_team and tm.profile_id = p_profile)));
$$;

-- The caller may tick points: an active member with a Lead or Crew pass
-- (never a Viewer, an admin's pass included), not hidden.
create or replace function public.may_tick(p_space uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and not public.is_hidden_account(auth.uid())
    and exists (select 1 from public.space_members m
                join public.spaces s on s.id = m.space_id and s.deleted_at is null
                where m.space_id = p_space and m.profile_id = auth.uid()
                  and m.left_at is null and m.pass in ('lead', 'crew'));
$$;

-- A post's points can still be ticked and changed: a live checklist, or a
-- live work item while Open.
create or replace function public.points_open(p_post public.space_posts)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_post.status = 'live' and p_post.deleted_at is null
    and (p_post.kind = 'checklist'
         or (p_post.kind = 'work_item'
             and exists (select 1 from public.work_items w
                         where w.id = p_post.id and w.status = 'open')));
$$;

alter table public.post_people enable row level security;
alter table public.checklist_points enable row level security;
alter table public.post_acks enable row level security;
alter table public.activity_reminders enable row level security;
alter table public.post_others enable row level security;

create policy post_people_read on public.post_people
  for select to authenticated using (public.can_see_space_post(post_id));
create policy checklist_points_read on public.checklist_points
  for select to authenticated using (public.can_see_space_post(post_id));
-- Your own acknowledgements only; the author reads others' through
-- post_acks_for.
create policy post_acks_read on public.post_acks
  for select to authenticated
  using (profile_id = auth.uid() and public.can_see_space_post(post_id));

revoke all on public.post_people, public.checklist_points, public.post_acks,
  public.activity_reminders, public.post_others from anon, authenticated;
grant select on public.post_people, public.checklist_points, public.post_acks to authenticated;
grant all on public.post_people, public.checklist_points, public.post_acks,
  public.activity_reminders, public.post_others to service_role;

-- ---------------------------------------------------------------------------
-- Points, people and files: shared by create and edit
-- ---------------------------------------------------------------------------

-- A point's text, trimmed, 1 to 300 characters.
create or replace function public.point_text(p_text text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text := trim(p_text);
begin
  if v_text is null or length(v_text) not between 1 and 300 then
    raise exception 'a point of 1 to 300 characters' using errcode = '22023';
  end if;
  return v_text;
end;
$$;

-- Add [p_people] to [p_post] (checklist or activity) and tell each new one
-- (checklist_for_you or activity_invited). Returns how many were added.
create or replace function public.add_post_people(p_post public.space_posts, p_people uuid[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_person uuid;
  v_count integer := 0;
begin
  if p_people is null then
    return 0;
  end if;
  if cardinality(p_people) > 200 then
    raise exception 'at most 200 people' using errcode = '22023';
  end if;
  for v_person in select distinct x from unnest(p_people) x loop
    if v_person is null
       or not public.may_be_post_person(p_post.space_id, p_post.team_id, p_post.kind, v_person) then
      raise exception 'choose people in this Space who can take part' using errcode = '22023';
    end if;
    insert into public.post_people (post_id, profile_id, added_by)
    values (p_post.id, v_person, auth.uid())
    on conflict do nothing;
    if found then
      v_count := v_count + 1;
      perform public.add_notification(
        v_person,
        case when p_post.kind = 'checklist' then 'checklist_for_you' else 'activity_invited' end,
        auth.uid(), p_post.space_id, p_space_post => p_post.id);
    end if;
  end loop;
  return v_count;
end;
$$;

-- The file a file post shares: in this Space, not deleted, readable by the
-- caller, and a Team file only on that Team's post.
create or replace function public.post_library_file(p_space uuid, p_team uuid, p_file uuid)
returns public.library_files
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_file public.library_files;
begin
  select * into v_file from public.library_files f where f.id = p_file;
  if v_file.id is null or v_file.space_id <> p_space or v_file.deleted_at is not null
     or not public.can_read_library_file(v_file.id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_file.team_id is not null and v_file.team_id is distinct from p_team then
    raise exception 'a Team file can only go on that Team''s posts' using errcode = '22023';
  end if;
  return v_file;
end;
$$;

-- ---------------------------------------------------------------------------
-- Posting a checklist, an announcement, an activity or a file (A2)
-- ---------------------------------------------------------------------------

-- [p_people]: a checklist's (one or more, Lead or Crew) or an activity's
-- (any, Viewers too). [p_points]: a checklist's, [{id?, text}], 1 to 50.
-- A file post's title defaults to the file's name. Lead and Crew post
-- (create_items); a file post also needs the files right. The id is the
-- app's, so a retry is the same post.
create or replace function public.create_space_post(
  p_id uuid,
  p_space uuid,
  p_kind text,
  p_title text default null,
  p_body text default null,
  p_team uuid default null,
  p_place text default null,
  p_due date default null,
  p_pinned_until timestamptz default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_library_file uuid default null,
  p_people uuid[] default '{}',
  p_points jsonb default '[]'::jsonb,
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
  v_msg public.messages;
  v_thread_team uuid;
  v_team uuid := p_team;
  v_file public.library_files;
  v_title text := trim(p_title);
  v_point jsonb;
  v_sort integer := 0;
  v_member record;
begin
  -- The same id again (a retry): the same post, if it is the caller's.
  select * into v_post from public.space_posts where id = v_id;
  if v_post.id is not null then
    if v_post.author_id = v_me and v_post.space_id = p_space and v_post.kind = p_kind then
      return v_post.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if p_kind is null or p_kind not in ('checklist', 'announcement', 'activity', 'file') then
    raise exception 'choose a kind of post' using errcode = '22023';
  end if;
  if not public.can(p_space, 'create_items') or public.is_hidden_account(v_me)
     or (p_kind = 'file' and not public.can(p_space, 'add_files')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if public.folder_has_others_files_in(p_space::text || '/posts/' || v_id::text || '/') then
    raise exception 'this id is taken' using errcode = '42501';
  end if;
  if v_team is not null and not exists (
       select 1 from public.teams t where t.id = v_team and t.space_id = p_space) then
    raise exception 'team not in this Space' using errcode = '22023';
  end if;
  if p_quote is not null and not public.is_valid_post_quote(p_quote) then
    raise exception 'a quote needs its text' using errcode = '22023';
  end if;

  -- From a chat message the caller can read; a Team thread's message stays
  -- in that Team (as create_work_item).
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
  -- A Team post only from inside that Team (or a Space admin).
  if v_team is not null and not public.is_space_admin(p_space) and not exists (
       select 1 from public.team_members tm where tm.team_id = v_team and tm.profile_id = v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  -- What each kind takes.
  if (p_pinned_until is not null and p_kind <> 'announcement')
     or ((p_starts_at is not null or p_ends_at is not null) and p_kind <> 'activity')
     or (p_library_file is not null and p_kind <> 'file')
     or (p_due is not null and p_kind <> 'checklist')
     or (nullif(trim(p_place), '') is not null and p_kind <> 'activity')
     or (coalesce(cardinality(p_people), 0) > 0 and p_kind not in ('checklist', 'activity'))
     or (coalesce(jsonb_array_length(case when jsonb_typeof(p_points) = 'array' then p_points end), 0) > 0
         and p_kind <> 'checklist') then
    raise exception 'that doesn''t go on this kind of post' using errcode = '22023';
  end if;
  if p_kind = 'file' then
    if p_library_file is null then
      raise exception 'choose a file' using errcode = '22023';
    end if;
    v_file := public.post_library_file(p_space, v_team, p_library_file);
    v_title := coalesce(nullif(v_title, ''), v_file.name);
  end if;
  if v_title is null or length(v_title) not between 1 and 200 then
    raise exception 'a title of 1 to 200 characters' using errcode = '22023';
  end if;
  if length(p_body) > 5000 then
    raise exception 'at most 5000 characters' using errcode = '22023';
  end if;
  if length(trim(p_place)) > 80 then
    raise exception 'at most 80 characters' using errcode = '22023';
  end if;
  if p_pinned_until is not null
     and (p_pinned_until <= now() or p_pinned_until > now() + interval '90 days') then
    raise exception 'pin it until a day in the next 90 days' using errcode = '22023';
  end if;
  if p_kind = 'activity' then
    if p_starts_at is null or p_starts_at <= now() then
      raise exception 'an activity starts in the future' using errcode = '22023';
    end if;
    if p_ends_at is not null
       and (p_ends_at <= p_starts_at or p_ends_at > p_starts_at + interval '1 day') then
      raise exception 'it ends after it starts, within a day' using errcode = '22023';
    end if;
  end if;
  if p_kind = 'checklist' then
    if coalesce(cardinality(p_people), 0) = 0 then
      raise exception 'choose who the checklist is for' using errcode = '22023';
    end if;
    if p_points is null or jsonb_typeof(p_points) <> 'array'
       or jsonb_array_length(p_points) not between 1 and 50 then
      raise exception 'a checklist has 1 to 50 points' using errcode = '22023';
    end if;
  end if;

  insert into public.space_posts (id, space_id, team_id, kind, author_id, title, body,
                                  place_text, due_date, source_message_id, quote,
                                  pinned_until, starts_at, ends_at, library_file_id)
  values (v_id, p_space, v_team, p_kind, v_me, v_title, nullif(trim(p_body), ''),
          nullif(trim(p_place), ''), p_due, p_source_message, p_quote,
          p_pinned_until, p_starts_at, p_ends_at, p_library_file)
  returning * into v_post;

  if p_kind = 'checklist' then
    for v_point in select * from jsonb_array_elements(p_points) loop
      if jsonb_typeof(v_point) <> 'object' then
        raise exception 'a point must be an object' using errcode = '22023';
      end if;
      insert into public.checklist_points (id, post_id, sort, text)
      values (coalesce(nullif(v_point ->> 'id', '')::uuid, gen_random_uuid()), v_id, v_sort,
              public.point_text(v_point ->> 'text'));
      v_sort := v_sort + 1;
    end loop;
  end if;
  perform public.add_post_people(v_post, p_people);
  perform public.add_post_files(v_post, p_files);

  -- Tell the audience of an announcement, and whoever received an older
  -- version of a new file.
  if p_kind = 'announcement' then
    for v_member in
      select m.profile_id from public.space_members m
      where m.space_id = p_space and m.left_at is null
        and public.can_see_space_post_as(v_id, m.profile_id)
    loop
      perform public.add_notification(v_member.profile_id, 'announcement_new', v_me, p_space,
                                      p_space_post => v_id);
    end loop;
  elsif p_kind = 'file' and v_file.supersedes_id is not null then
    for v_member in
      with recursive older (id) as (
        select v_file.supersedes_id
        union
        select f.supersedes_id from public.library_files f
        join older o on o.id = f.id
        where f.supersedes_id is not null)
      select distinct a.profile_id
      from older o
      join public.space_posts p on p.library_file_id = o.id and p.deleted_at is null
      join public.post_acks a on a.post_id = p.id and a.kind = 'received'
      where public.can_see_space_post_as(v_id, a.profile_id)
    loop
      perform public.add_notification(v_member.profile_id, 'file_new_version', v_me, p_space,
                                      p_space_post => v_id);
    end loop;
  end if;
  return v_id;
exception
  when invalid_text_representation then
    raise exception 'a point id is not valid' using errcode = '22023';
end;
$$;

-- ---------------------------------------------------------------------------
-- Ticking points and acknowledging
-- ---------------------------------------------------------------------------

-- Tick ([p_on]) or untick a point: the author, its people and any Lead or
-- Crew member, never a Viewer. Untick only by whoever ticked it, or the
-- author (an admin when the author is gone). A work item's points only
-- while it is Open. A tick by someone other than the author ends Delete.
create or replace function public.tick_point(p_point uuid, p_on boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post_id uuid := (select c.post_id from public.checklist_points c where c.id = p_point);
  v_post public.space_posts;
  v_point public.checklist_points;
begin
  -- The post first (as edit, delete and cancel), then the point.
  select * into v_post from public.space_posts where id = v_post_id for update;
  if v_post.id is null or not public.can_see_space_post(v_post.id)
     or not public.may_tick(v_post.space_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_post.kind = 'work_item' then
    perform 1 from public.work_items where id = v_post.id for update;
  end if;
  if not public.points_open(v_post) then
    raise exception 'this can no longer be ticked' using errcode = 'P0001';
  end if;
  select * into v_point from public.checklist_points where id = p_point for update;
  if v_point.id is null or v_point.post_id <> v_post.id then
    raise exception 'this point was removed' using errcode = 'P0001';
  end if;

  if coalesce(p_on, true) then
    if v_point.ticked_at is not null then
      return;
    end if;
    update public.checklist_points set ticked_by = v_me, ticked_at = now() where id = p_point;
    if v_me is distinct from v_post.author_id then
      insert into public.post_others (post_id) values (v_post.id) on conflict do nothing;
    end if;
  else
    if v_point.ticked_at is null then
      return;
    end if;
    if v_point.ticked_by is distinct from v_me and not public.acts_for_author(v_post) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    update public.checklist_points set ticked_by = null, ticked_at = null where id = p_point;
  end if;
end;
$$;

-- Got it on an announcement, Received on a file, On my way and In my
-- calendar on an activity: any active member who can read the post,
-- Viewers too. [p_on] false takes your own back. On my way from 3 hours
-- before the start to the end; In my calendar until the end.
create or replace function public.ack(p_post uuid, p_kind text, p_on boolean default true)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_end timestamptz;
begin
  select * into v_post from public.space_posts where id = p_post for update;
  if v_post.id is null or not public.can_see_space_post(v_post.id)
     or public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if (v_post.kind, p_kind) not in (('announcement', 'got_it'), ('file', 'received'),
                                   ('activity', 'on_my_way'), ('activity', 'in_my_calendar')) then
    raise exception 'that doesn''t go on this kind of post' using errcode = '22023';
  end if;

  if not coalesce(p_on, true) then
    delete from public.post_acks where post_id = p_post and profile_id = v_me and kind = p_kind;
    return;
  end if;
  if v_post.status <> 'live' or v_post.deleted_at is not null then
    raise exception 'this was cancelled' using errcode = 'P0001';
  end if;
  if v_post.kind = 'activity' then
    v_end := coalesce(v_post.ends_at, v_post.starts_at + interval '1 hour');
    if now() >= v_end
       or (p_kind = 'on_my_way' and now() < v_post.starts_at - interval '3 hours') then
      raise exception 'not at this time' using errcode = 'P0001';
    end if;
  end if;
  insert into public.post_acks (post_id, profile_id, kind) values (p_post, v_me, p_kind)
  on conflict do nothing;
  if v_me is distinct from v_post.author_id then
    insert into public.post_others (post_id) values (p_post) on conflict do nothing;
  end if;
end;
$$;

-- Who acknowledged [p_post]: faces and names, never a count. The author
-- only (an admin when the author is gone); nobody else gets any row.
create or replace function public.post_acks_for(p_post uuid)
returns table (profile_id uuid, name text, kind text, at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select a.profile_id, public.space_person_name(a.profile_id), a.kind, a.created_at
  from public.space_posts p
  join public.post_acks a on a.post_id = p.id
  where p.id = p_post and public.may_see_acks(p)
  order by a.created_at, a.profile_id;
$$;

-- ---------------------------------------------------------------------------
-- Reading: what the daybook shows above the list
-- ---------------------------------------------------------------------------

-- Pinned announcements (pinned now) and activities starting between
-- [p_from] and [p_to] (the phone's day), newest first. [reason] is
-- 'pinned' or 'activity'. Team posts as can_see_space_post.
create or replace function public.daybook_extras(p_space uuid, p_from timestamptz,
                                                 p_to timestamptz)
returns table (id uuid, reason text, post jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select (x.r).id, x.reason, public.space_post_json(x.r, false)
  from (
    select p as r, 'pinned'::text as reason, p.created_at as at
    from public.space_posts p
    where p.space_id = p_space and p.kind = 'announcement' and p.pinned_until > now()
      and p.status = 'live' and p.deleted_at is null
    union all
    select p, 'activity', p.starts_at
    from public.space_posts p
    where p.space_id = p_space and p.kind = 'activity'
      and p.starts_at >= p_from and p.starts_at < p_to
      and p.status = 'live' and p.deleted_at is null
  ) x
  where public.is_member(p_space) and public.can_see_space_post((x.r).id)
    and p_to > p_from and p_to - p_from <= interval '2 days'
  order by x.reason desc, x.at desc, (x.r).id desc
  limit 50;
$$;

-- ---------------------------------------------------------------------------
-- "Starts in 30 min" (service role, every 5 minutes)
-- ---------------------------------------------------------------------------

-- Activities starting in 25 to 35 minutes: one push to each of their
-- people and to whoever put them in their calendar, once per person and
-- start time, even when the Space is set to Off (A2: always). Only people
-- still in the Space who can see the post. No Activity row. Returns the
-- pushes queued.
create or replace function public.due_activity_reminders()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_rows integer;
begin
  with due as (
    select p.id, p.space_id, p.starts_at
    from public.space_posts p
    join public.spaces s on s.id = p.space_id and s.deleted_at is null
    where p.kind = 'activity' and p.status = 'live' and p.deleted_at is null
      and p.starts_at >= now() + interval '25 minutes'
      and p.starts_at < now() + interval '35 minutes'
  ),
  who as (
    select d.id, d.space_id, d.starts_at, pp.profile_id
    from due d join public.post_people pp on pp.post_id = d.id
    union
    select d.id, d.space_id, d.starts_at, a.profile_id
    from due d join public.post_acks a on a.post_id = d.id and a.kind = 'in_my_calendar'
  ),
  fresh as (
    insert into public.activity_reminders (post_id, profile_id, starts_at)
    select w.id, w.profile_id, w.starts_at from who w
    where public.can_see_space_post_as(w.id, w.profile_id)
    on conflict do nothing
    returning post_id, profile_id
  )
  insert into public.push_queue (profile_id, kind, data)
  select f.profile_id, 'activity_starting',
         jsonb_build_object('space_id', p.space_id, 'space_post_id', p.id)
  from fresh f
  join public.space_posts p on p.id = f.post_id
  where exists (select 1 from public.push_tokens t where t.profile_id = f.profile_id);
  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;

-- ---------------------------------------------------------------------------
-- Edit, delete and cancel for every kind
-- ---------------------------------------------------------------------------

-- A post the author may still change: live, not deleted; a work item only
-- while Open; an activity until it ends.
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
                    where w.id = p_post.id and w.status = 'open'))
    and (p_post.kind <> 'activity'
         or coalesce(p_post.ends_at, p_post.starts_at + interval '1 hour') > now());
$$;

-- Someone other than the author added something, so Delete has ended
-- (clarification 2): an update, sign-off or any event by another person,
-- any child work item (whoever made it), a file another person attached,
-- or a tick or acknowledgement by another person, even if taken back
-- (post_others). A purged person (null) counts as someone else.
create or replace function public.post_has_others(p_post public.space_posts)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.post_others o where o.post_id = p_post.id)
      or exists (select 1 from public.work_item_events e
                 where e.work_item_id = p_post.id
                   and e.actor_id is distinct from p_post.author_id)
      or exists (select 1 from public.space_posts c
                 where c.parent_id = p_post.id and c.deleted_at is null)
      or exists (select 1 from public.work_item_attachments a
                 where a.work_item_id = p_post.id
                   and a.added_by is distinct from p_post.author_id)
      or exists (select 1 from public.post_files f
                 where f.post_id = p_post.id
                   and f.added_by is distinct from p_post.author_id)
      or exists (select 1 from public.checklist_points c
                 where c.post_id = p_post.id and c.ticked_at is not null
                   and c.ticked_by is distinct from p_post.author_id)
      or exists (select 1 from public.post_acks a
                 where a.post_id = p_post.id and a.profile_id is distinct from p_post.author_id);
$$;

-- Edit [p_id] (the author only, while they may still post). [p_changes]
-- may hold, by kind:
-- - every kind: title, body, add_files, remove_files;
-- - place: work item, checklist, activity; due: work item, checklist;
-- - points (checklist, work item): {add: [{id?, text}], edit: [{id, text}],
--   remove: [id], order: [every point id]}; a ticked point can't be
--   removed or reworded, and can be moved;
-- - people (checklist, activity): {add: [id], remove: [id]};
-- - pinned_until (announcement): a time in the next 90 days, or null;
-- - starts_at, ends_at (activity): still in the future, ends after starts.
-- Each saved change is one post_edits row and tells whoever the post is
-- for: a work item's owner; a checklist's people; an activity's people and
-- whoever put it in their calendar. New people are told they were added.
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
  v_pinned timestamptz;
  v_starts timestamptz;
  v_ends timestamptz;
  v_added integer := 0;
  v_removed integer := 0;
  v_edit uuid;
  v_key text;
  v_points jsonb;
  v_people jsonb;
  v_item jsonb;
  v_point public.checklist_points;
  v_text text;
  v_p_added integer := 0;
  v_p_removed integer := 0;
  v_p_reworded integer := 0;
  v_p_moved boolean := false;
  v_sort integer;
  v_order uuid[];
  v_people_added integer := 0;
  v_people_removed integer := 0;
  v_new uuid[];
  v_person record;
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
    if v_key not in ('title', 'body', 'place', 'due', 'add_files', 'remove_files', 'points',
                     'people', 'pinned_until', 'starts_at', 'ends_at')
       or (v_key = 'place' and v_post.kind not in ('work_item', 'checklist', 'activity'))
       or (v_key = 'due' and v_post.kind not in ('work_item', 'checklist'))
       or (v_key = 'points' and v_post.kind not in ('work_item', 'checklist'))
       or (v_key = 'people' and v_post.kind not in ('checklist', 'activity'))
       or (v_key = 'pinned_until' and v_post.kind <> 'announcement')
       or (v_key in ('starts_at', 'ends_at') and v_post.kind <> 'activity') then
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
  begin
    if p_changes ? 'pinned_until' then
      v_pinned := nullif(p_changes ->> 'pinned_until', '')::timestamptz;
    end if;
    v_starts := case when p_changes ? 'starts_at'
                     then nullif(p_changes ->> 'starts_at', '')::timestamptz
                     else v_post.starts_at end;
    v_ends := case when p_changes ? 'ends_at'
                   then nullif(p_changes ->> 'ends_at', '')::timestamptz
                   else v_post.ends_at end;
  exception when others then
    raise exception 'a time' using errcode = '22023';
  end;
  if p_changes ? 'pinned_until' then
    if v_pinned is not null
       and (v_pinned <= now() or v_pinned > now() + interval '90 days') then
      raise exception 'pin it until a day in the next 90 days' using errcode = '22023';
    end if;
    if v_pinned is distinct from v_post.pinned_until then
      v_diff := v_diff || jsonb_build_object('pinned_until',
                  jsonb_build_object('from', v_post.pinned_until, 'to', v_pinned));
    end if;
  end if;
  if p_changes ? 'starts_at' or p_changes ? 'ends_at' then
    if v_starts is null
       or (v_starts is distinct from v_post.starts_at and v_starts <= now()) then
      raise exception 'an activity starts in the future' using errcode = '22023';
    end if;
    if v_ends is not null and (v_ends <= v_starts or v_ends > v_starts + interval '1 day') then
      raise exception 'it ends after it starts, within a day' using errcode = '22023';
    end if;
    if v_starts is distinct from v_post.starts_at then
      v_diff := v_diff || jsonb_build_object('starts_at',
                  jsonb_build_object('from', v_post.starts_at, 'to', v_starts));
    end if;
    if v_ends is distinct from v_post.ends_at then
      v_diff := v_diff || jsonb_build_object('ends_at',
                  jsonb_build_object('from', v_post.ends_at, 'to', v_ends));
    end if;
  end if;

  -- Points: locked first, so a tick running now lands before the tests.
  if p_changes ? 'points' then
    v_points := p_changes -> 'points';
    if jsonb_typeof(v_points) <> 'object' then
      raise exception 'points must be an object' using errcode = '22023';
    end if;
    perform 1 from public.checklist_points where post_id = p_id order by id for update;
    if v_points ? 'remove' then
      for v_item in select * from jsonb_array_elements(v_points -> 'remove') loop
        select * into v_point from public.checklist_points
        where id = (v_item #>> '{}')::uuid and post_id = p_id;
        if v_point.id is null then
          raise exception 'not a point of this post' using errcode = '22023';
        end if;
        if v_point.ticked_at is not null then
          raise exception 'a ticked point stays' using errcode = 'P0001';
        end if;
        delete from public.checklist_points where id = v_point.id;
        v_p_removed := v_p_removed + 1;
      end loop;
    end if;
    if v_points ? 'edit' then
      for v_item in select * from jsonb_array_elements(v_points -> 'edit') loop
        select * into v_point from public.checklist_points
        where id = (v_item ->> 'id')::uuid and post_id = p_id;
        if v_point.id is null then
          raise exception 'not a point of this post' using errcode = '22023';
        end if;
        v_text := public.point_text(v_item ->> 'text');
        if v_text is distinct from v_point.text then
          if v_point.ticked_at is not null then
            raise exception 'a ticked point stays as it is' using errcode = 'P0001';
          end if;
          update public.checklist_points set text = v_text where id = v_point.id;
          v_p_reworded := v_p_reworded + 1;
        end if;
      end loop;
    end if;
    if v_points ? 'add' then
      select coalesce(max(sort) + 1, 0) into v_sort from public.checklist_points where post_id = p_id;
      for v_item in select * from jsonb_array_elements(v_points -> 'add') loop
        insert into public.checklist_points (id, post_id, sort, text)
        values (coalesce(nullif(v_item ->> 'id', '')::uuid, gen_random_uuid()), p_id, v_sort,
                public.point_text(v_item ->> 'text'));
        v_sort := v_sort + 1;
        v_p_added := v_p_added + 1;
      end loop;
    end if;
    if v_points ? 'order' then
      select array_agg(x::uuid order by n) into v_order
      from jsonb_array_elements_text(v_points -> 'order') with ordinality t(x, n);
      if coalesce(cardinality(v_order), 0) <> (select count(*) from public.checklist_points where post_id = p_id)
         or exists (select 1 from public.checklist_points c
                    where c.post_id = p_id and not (c.id = any (v_order)))
         or cardinality(v_order) <> (select count(distinct x) from unnest(v_order) x) then
        raise exception 'order lists every point once' using errcode = '22023';
      end if;
      v_p_moved := v_order is distinct from (
        select array_agg(c.id order by c.sort, c.id)
        from public.checklist_points c where c.post_id = p_id);
      update public.checklist_points c set sort = o.n - 1
      from unnest(v_order) with ordinality o(id, n)
      where c.id = o.id and c.post_id = p_id;
    end if;
    if (select count(*) from public.checklist_points where post_id = p_id) > 50
       or (v_post.kind = 'checklist'
           and not exists (select 1 from public.checklist_points where post_id = p_id)) then
      raise exception 'a checklist has 1 to 50 points' using errcode = '22023';
    end if;
    if v_p_added + v_p_removed + v_p_reworded > 0 or v_p_moved then
      v_diff := v_diff || jsonb_build_object('points', jsonb_build_object(
                  'added', v_p_added, 'removed', v_p_removed, 'reworded', v_p_reworded,
                  'reordered', v_p_moved));
    end if;
  end if;

  if p_changes ? 'people' then
    v_people := p_changes -> 'people';
    if jsonb_typeof(v_people) <> 'object' then
      raise exception 'people must be an object' using errcode = '22023';
    end if;
    if v_people ? 'remove' then
      with gone as (
        delete from public.post_people pp
        where pp.post_id = p_id
          and pp.profile_id::text in (select jsonb_array_elements_text(v_people -> 'remove'))
        returning 1)
      select count(*) into v_people_removed from gone;
    end if;
    if v_people ? 'add' then
      select array_agg(x::uuid) into v_new from jsonb_array_elements_text(v_people -> 'add') x;
      v_people_added := public.add_post_people(v_post, v_new);
    end if;
    if v_post.kind = 'checklist' and not exists (select 1 from public.post_people where post_id = p_id) then
      raise exception 'choose who the checklist is for' using errcode = '22023';
    end if;
    if v_people_added + v_people_removed > 0 then
      v_diff := v_diff || jsonb_build_object('people', jsonb_build_object(
                  'added', v_people_added, 'removed', v_people_removed));
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
      pinned_until = case when p_changes ? 'pinned_until' then v_pinned else pinned_until end,
      starts_at = case when kind = 'activity' then v_starts else starts_at end,
      ends_at = case when kind = 'activity' then v_ends else ends_at end,
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
  -- A checklist's or an activity's people (and calendar adds), unless only
  -- people changed: those added were just told, those removed aren't.
  if v_post.kind in ('checklist', 'activity') and (v_diff - 'people') <> '{}'::jsonb then
    for v_person in
      select x.profile_id from (
        select pp.profile_id from public.post_people pp
        where pp.post_id = p_id and not (pp.profile_id = any (coalesce(v_new, '{}')))
        union
        select a.profile_id from public.post_acks a
        where a.post_id = p_id and a.kind = 'in_my_calendar') x
      where public.can_see_space_post_as(p_id, x.profile_id)
    loop
      perform public.add_notification(v_person.profile_id, 'item_edited', v_me, v_post.space_id,
                                      p_space_post => p_id,
                                      p_payload => jsonb_build_object('edit_id', v_edit));
    end loop;
  end if;
exception
  when invalid_text_representation then
    raise exception 'an id is not valid' using errcode = '22023';
end;
$$;

-- Cancel [p_id]: the author, or an admin when the author is gone. It stays
-- in the daybook with a CANCELLED stamp. A Checked item can't be cancelled.
-- Work items under it are cancelled with it, except those already Checked.
-- Each owner is told, and a checklist's or an activity's people (and
-- calendar adds).
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
  -- Lock the posts under it, then the work items (the order every path
  -- uses), so a sign-off, check or tick running now finishes before the
  -- Checked test below (and none lands after the cancel).
  perform 1 from public.space_posts c where c.parent_id = p_id order by c.id for update;
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
  if v_post.kind in ('checklist', 'activity') then
    for v_row in
      select x.profile_id from (
        select pp.profile_id from public.post_people pp where pp.post_id = p_id
        union
        select a.profile_id from public.post_acks a
        where a.post_id = p_id and a.kind = 'in_my_calendar') x
      where public.can_see_space_post_as(p_id, x.profile_id)
    loop
      perform public.add_notification(v_row.profile_id, 'item_cancelled', v_me, v_post.space_id,
                                      p_space_post => p_id);
    end loop;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Needs you: also a checklist for me with points still to tick
-- ---------------------------------------------------------------------------

-- A live checklist the caller is for and may still tick (not lowered to
-- Viewer), with a point still unticked.
create or replace function public.checklist_needs_me(p_post public.space_posts)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_post.kind = 'checklist' and p_post.status = 'live' and p_post.deleted_at is null
    and public.may_tick(p_post.space_id)
    and exists (select 1 from public.post_people pp
                where pp.post_id = p_post.id and pp.profile_id = auth.uid())
    and exists (select 1 from public.checklist_points c
                where c.post_id = p_post.id and c.ticked_at is null);
$$;

-- A new last column (space_post_id), so the function is made again.
drop function public.needs_you();

create function public.needs_you()
returns table (
  kind text,
  space_id uuid,
  work_item_id uuid,
  request_id uuid,
  created_at timestamptz,
  space_post_id uuid
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
         case when i.need = 'to_check' then i.done_at else i.created_at end, null::uuid
  from items i
  where i.need is not null
  union all
  select 'checklist_for_you', p.space_id, null::uuid, null::uuid, p.created_at, p.id
  from mine
  join public.post_people pp on pp.profile_id = auth.uid()
  join public.space_posts p on p.id = pp.post_id and p.space_id = mine.space_id
  where public.checklist_needs_me(p) and public.can_see_space_post(p.id)
  union all
  select 'join_request', r.space_id, null::uuid, r.id, r.created_at, null::uuid
  from mine
  join public.space_join_requests r
    on r.space_id = mine.space_id and r.status = 'pending'
  where public.is_space_admin(mine.space_id);
$$;

-- ---------------------------------------------------------------------------
-- Reading a post of any kind
-- ---------------------------------------------------------------------------

-- One post as the daybook shows it. [p_full] adds what opening it in place
-- needs. New in migration 19: the pin, the activity's time, its people,
-- the points (progress in the list, every point when opened), the file,
-- and the caller's own acknowledgements (others' only via post_acks_for).
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
    'pinned_until', case when p_post.pinned_until > now() then p_post.pinned_until end,
    'starts_at', p_post.starts_at,
    'ends_at', p_post.ends_at,
    'item', (
      select jsonb_build_object(
        'ref', w.ref, 'status', w.status,
        'owner_id', w.owner_id, 'owner_name', public.space_person_name(w.owner_id),
        'done_at', w.done_at, 'checked_at', w.checked_at,
        'checked_by_name', public.space_person_name(w.checked_by))
      from public.work_items w where w.id = p_post.id),
    'people', (
      select jsonb_agg(jsonb_build_object('id', pp.profile_id,
                                          'name', public.space_person_name(pp.profile_id))
                       order by pp.created_at, pp.profile_id)
      from public.post_people pp where pp.post_id = p_post.id),
    'points', (
      select jsonb_build_object('total', count(*),
                                'ticked', count(*) filter (where c.ticked_at is not null))
      from public.checklist_points c where c.post_id = p_post.id
      having count(*) > 0),
    'my_acks', (
      select jsonb_agg(a.kind order by a.kind)
      from public.post_acks a where a.post_id = p_post.id and a.profile_id = auth.uid()),
    'file', (
      select jsonb_build_object(
        'id', lf.id, 'name', lf.name, 'mime', lf.mime, 'bytes', lf.bytes,
        'rev_label', lf.rev_label, 'note', lf.note, 'path', lf.storage_path,
        'replaces', (select jsonb_build_object('name', o.name, 'rev_label', o.rev_label,
                                               'bytes', o.bytes)
                     from public.library_files o where o.id = lf.supersedes_id),
        'has_newer', exists (select 1 from public.library_files n
                             where n.supersedes_id = lf.id and n.deleted_at is null
                               and public.can_read_library_file(n.id)))
      from public.library_files lf
      where lf.id = p_post.library_file_id and public.can_read_library_file(lf.id)),
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
        when lf.supersedes_id is not null then jsonb_build_object(
          'kind', 'new_version', 'at', p_post.created_at)
      end
      -- Any kind can be cancelled; work items and new file versions have
      -- their own stamps.
      from (select 1) one
      left join public.work_items w on w.id = p_post.id
      left join public.library_files lf on lf.id = p_post.library_file_id
      left join lateral (
        select e.kind, e.created_at, e.reason, e.actor_id
        from public.work_item_events e
        where e.work_item_id = w.id and e.kind in ('done', 'checked', 'sent_back')
        order by e.created_at desc, e.id desc limit 1) last on true),
    -- The paper clip: this needs the caller.
    'needs_me', coalesce((
      select public.item_needs_me(w, p_post) is not null
      from public.work_items w where w.id = p_post.id), public.checklist_needs_me(p_post)),
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
    'point_list', (
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'text', c.text, 'ticked_at', c.ticked_at,
               'ticked_by_name', public.space_person_name(c.ticked_by),
               'ticked_by_me', c.ticked_by is not distinct from auth.uid() and c.ticked_at is not null)
             order by c.sort, c.id)
      from public.checklist_points c where c.post_id = p_post.id),
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

-- ---------------------------------------------------------------------------
-- Files: a file post keeps its Library file
-- ---------------------------------------------------------------------------

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
                 where f.library_file_id = p_file and p.deleted_at is null)
      or exists (select 1 from public.space_posts p
                 where p.library_file_id = p_file and p.deleted_at is null);
$$;

-- ---------------------------------------------------------------------------
-- Copies of live functions with one change each
-- ---------------------------------------------------------------------------

-- add_notification: a new last parameter, p_space_post (as in 20261013150000_market_pack.sql, with that change only). Callers name every argument after p_item.
drop function public.add_notification(uuid, text, uuid, uuid, uuid, uuid, uuid, uuid, jsonb);
CREATE FUNCTION public.add_notification(p_to uuid, p_kind text, p_actor uuid, p_space uuid DEFAULT NULL::uuid, p_item uuid DEFAULT NULL::uuid, p_post uuid DEFAULT NULL::uuid, p_reply uuid DEFAULT NULL::uuid, p_request uuid DEFAULT NULL::uuid, p_payload jsonb DEFAULT '{}'::jsonb, p_space_post uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if p_to is null or p_to is not distinct from p_actor
     or public.blocked_between(p_to, p_actor) then
    return;
  end if;
  -- Space news only for people still in the Space. A confirmed request
  -- is written just before the new member's row.
  if p_space is not null and p_kind <> 'join_confirmed'
     and not public.is_active_member(p_space, p_to) then
    return;
  end if;

  -- Asking again within a day after cancelling: the same row, now
  -- pointing at the new request and unread again. No new row, so no new
  -- push. A request after one that was answered is a new row (review 20).
  if p_kind = 'join_request' then
    update public.notifications n
    set request_id = p_request, read_at = null
    where n.profile_id = p_to and n.kind = 'join_request' and n.actor_id = p_actor
      and n.space_id = p_space and n.created_at > now() - interval '1 day'
      and exists (select 1 from public.space_join_requests r
                  where r.id = n.request_id and r.status = 'cancelled');
    if found then
      return;
    end if;
  end if;
  -- Follow, unfollow, follow: one row a week.
  if p_kind = 'follow' and exists (
    select 1 from public.notifications
    where profile_id = p_to and kind = 'follow' and actor_id = p_actor
      and created_at > now() - interval '7 days') then
    return;
  end if;

  if p_kind = 'post_useful' then
    -- No actor kept: who marked it is never stored on the author's row.
    insert into public.notifications (profile_id, kind, post_id, payload, day)
    values (p_to, p_kind, p_post, p_payload, public.local_day(p_to))
    on conflict (profile_id, post_id, day) where kind = 'post_useful'
    do update set created_at = excluded.created_at, read_at = null;
  else
    insert into public.notifications (profile_id, kind, actor_id, space_id, work_item_id,
                                      post_id, reply_id, request_id, payload, space_post_id)
    values (p_to, p_kind, p_actor, p_space, p_item, p_post, p_reply, p_request, p_payload,
            p_space_post);
  end if;
end;
$function$;

-- Push: the new kinds, item_edited and item_cancelled; the post's id in the data (as in 20261012190000_push.sql, with that change only).
CREATE OR REPLACE FUNCTION public.handle_notification_push()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_settings public.push_settings;
  v_wanted boolean;
begin
  begin
    if not exists (select 1 from public.push_tokens t where t.profile_id = new.profile_id) then
      return null;
    end if;
    select * into v_settings from public.push_settings s where s.profile_id = new.profile_id;
    v_wanted := case
      when new.kind in ('item_assigned', 'item_done', 'item_checked', 'item_sent_back',
                        'item_comment', 'item_edited', 'item_cancelled', 'announcement_new',
                        'checklist_for_you', 'activity_invited', 'join_request')
        then public.space_push_level(new.space_id, new.profile_id) in ('all', 'needs_you')
      -- Only for Spaces set to everything (review 33 A2).
      when new.kind = 'file_new_version'
        then public.space_push_level(new.space_id, new.profile_id) = 'all'
      when new.kind = 'join_confirmed' then true
      when new.kind = 'role_confirmed' then true
      when new.kind = 'follow' then coalesce(v_settings.followers, true)
      when new.kind = 'post_reply' then coalesce(v_settings.replies, true)
      else false
    end;
    if v_wanted then
      insert into public.push_queue (profile_id, kind, actor_id, notification_id, data)
      values (new.profile_id, new.kind, new.actor_id, new.id,
              jsonb_strip_nulls(jsonb_build_object(
                'space_id', new.space_id, 'work_item_id', new.work_item_id,
                'post_id', new.post_id, 'request_id', new.request_id,
                'space_post_id', new.space_post_id)));
    end if;
  exception when others then
    -- A push problem never blocks the step that caused it.
    raise warning 'push queue (notification %): %', new.id, sqlerrm;
  end;
  return null;
end;
$function$;

-- Activity: rows about a post that isn't a work item, with its title and kind, while you may see it (as in 20261015120000_daybook.sql, with that change only).
alter type public.activity_row add attribute space_post_id uuid, add attribute post_kind text;
CREATE OR REPLACE FUNCTION public.activity_rows()
 RETURNS SETOF activity_row
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    select r.*, s.name as space_name, m.pass, w.ref, coalesce(w.title, sp.title) as title,
           sp.kind as post_kind,
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
    left join public.space_posts sp on sp.id = r.space_post_id
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
      and (r.space_post_id is null or public.can_see_space_post(r.space_post_id))
  )
  select x.id, x.kind, x.group_kind, x.space_id, x.space_name, x.pass,
         x.work_item_id, x.ref, x.title, x.post_id, x.reply_id, x.context,
         x.request_id, x.request_status, x.project_id, x.project_name,
         x.actor_id, x.actor_name, x.payload, x.created_at, x.read_at,
         (row_number() over (partition by x.group_kind, x.space_id
                             order by x.created_at, x.id))::int,
         case when x.kind = 'post_useful' then
           array(select u.name from public.useful_names(x.post_id) u) end,
         x.space_post_id, x.post_kind
  from shown x;
$function$;

-- Download my data: acknowledgements, ticks and the posts you were for (as in 20261015120000_daybook.sql, with that change only).
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
    'push_settings', (select to_jsonb(ps) from public.push_settings ps where ps.profile_id = r.profile_id)
  )
  from public.data_requests r
  where r.id = p_request;
$function$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.can_see_space_post_as(uuid, uuid),
  public.may_see_acks(public.space_posts),
  public.may_be_post_person(uuid, uuid, text, uuid),
  public.may_tick(uuid),
  public.points_open(public.space_posts),
  public.point_text(text),
  public.add_post_people(public.space_posts, uuid[]),
  public.post_library_file(uuid, uuid, uuid),
  public.create_space_post(uuid, uuid, text, text, text, uuid, text, date, timestamptz,
                           timestamptz, timestamptz, uuid, uuid[], jsonb, uuid, jsonb, jsonb),
  public.tick_point(uuid, boolean),
  public.ack(uuid, text, boolean),
  public.post_acks_for(uuid),
  public.daybook_extras(uuid, timestamptz, timestamptz),
  public.due_activity_reminders(),
  public.checklist_needs_me(public.space_posts),
  public.needs_you(),
  public.add_notification(uuid, text, uuid, uuid, uuid, uuid, uuid, uuid, jsonb, uuid)
  from public, anon;
-- Internal: answers about anyone, writes without its own checks, or the
-- cron's only.
revoke execute on function
  public.can_see_space_post_as(uuid, uuid),
  public.may_see_acks(public.space_posts),
  public.may_be_post_person(uuid, uuid, text, uuid),
  public.may_tick(uuid),
  public.points_open(public.space_posts),
  public.point_text(text),
  public.add_post_people(public.space_posts, uuid[]),
  public.post_library_file(uuid, uuid, uuid),
  public.due_activity_reminders(),
  public.checklist_needs_me(public.space_posts),
  public.add_notification(uuid, text, uuid, uuid, uuid, uuid, uuid, uuid, jsonb, uuid)
  from authenticated;
grant execute on function
  public.create_space_post(uuid, uuid, text, text, text, uuid, text, date, timestamptz,
                           timestamptz, timestamptz, uuid, uuid[], jsonb, uuid, jsonb, jsonb),
  public.tick_point(uuid, boolean),
  public.ack(uuid, text, boolean),
  public.post_acks_for(uuid),
  public.daybook_extras(uuid, timestamptz, timestamptz),
  public.needs_you()
  to authenticated;
grant execute on function public.due_activity_reminders() to service_role;
