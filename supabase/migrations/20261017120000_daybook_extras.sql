-- Migration 23: the Daybook's extras (review 44). Branch daybook-extras-db.
-- Not live.
--
-- - A due time: space_posts.due_at, optional, next to due_date, on work
--   items and checklists. The phone sends both (its own date and time), so
--   no time zone goes in SQL; the time must fall on that date somewhere on
--   Earth. A timed item is late after its time; a date-only item is late
--   from the next day, as before. Editing changes them together, in the
--   same "Edited: due moved" line.
-- - "On site since": spaces.site_start_date, optional, set only by a Space
--   admin with set_site_start_date. The daybook counts "day N" from it
--   (that day is day 1); without it, it shows only the date. Never counted
--   from the Space's creation date (rule 3).
-- - daybook_month: for the month drop-down, which days have posts the
--   caller can see and which have something due that isn't checked or
--   cancelled. Dots, never counts: post times come rounded to 15 minutes,
--   distinct, so the phone groups them by its own days (every time zone is
--   a whole number of 15 minutes from UTC).
-- - Undo of a check needs nothing here: the app holds the check for the
--   undo bar's 5 seconds, then sends it (review 44, answer 4).

-- ---------------------------------------------------------------------------
-- A due time
-- ---------------------------------------------------------------------------

-- A time fits a due date when it falls on that date in some time zone
-- (UTC-12 to UTC+14).
create function public.due_at_fits(p_day date, p_at timestamptz)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_day is not null
    and p_at >= (p_day::timestamp - interval '14 hours') at time zone 'UTC'
    and p_at < (p_day::timestamp + interval '36 hours') at time zone 'UTC';
$$;

alter table public.space_posts add column due_at timestamptz;
alter table public.space_posts add constraint space_posts_due_at_check
  check (due_at is null or public.due_at_fits(due_date, due_at));

-- Late: after its time, or, with no time, from the day after its date (the
-- phone's today).
create function public.is_late(p_post public.space_posts, p_today date)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case when p_post.due_at is not null then p_post.due_at < now()
              else p_post.due_date < p_today end;
$$;

-- ---------------------------------------------------------------------------
-- On site since
-- ---------------------------------------------------------------------------

alter table public.spaces add column site_start_date date;

create function public.set_site_start_date(p_space uuid, p_day date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_space_admin(p_space)
     or not exists (select 1 from public.spaces s where s.id = p_space and s.deleted_at is null) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  -- A real site day: not before 2000, at most a year ahead (a Space set up
  -- before work starts).
  if p_day is not null
     and (p_day < date '2000-01-01' or p_day > (now() + interval '366 days')::date) then
    raise exception 'choose the day work started on site' using errcode = '22023';
  end if;
  update public.spaces set site_start_date = p_day where id = p_space;
end;
$$;

-- Raising a work item: also an optional due time (as in 20261016120000_post_pages.sql, with that change only).
drop function public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid, uuid, jsonb, jsonb, uuid, jsonb, jsonb);
CREATE FUNCTION public.create_work_item(p_space uuid, p_title text, p_owner uuid, p_due date DEFAULT NULL::date, p_team uuid DEFAULT NULL::uuid, p_place text DEFAULT NULL::text, p_evidence jsonb DEFAULT '[]'::jsonb, p_id uuid DEFAULT NULL::uuid, p_body text DEFAULT NULL::text, p_parent uuid DEFAULT NULL::uuid, p_source_message uuid DEFAULT NULL::uuid, p_quote jsonb DEFAULT NULL::jsonb, p_files jsonb DEFAULT '[]'::jsonb, p_template uuid DEFAULT NULL::uuid, p_blocks jsonb DEFAULT NULL::jsonb, p_points jsonb DEFAULT NULL::jsonb, p_due_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_template public.post_templates;
  v_point jsonb;
  v_sort integer := 0;
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
    -- Only under your own work item, or one you act for (review 34 D1).
    if v_parent.id is null or v_parent.space_id <> p_space or v_parent.kind <> 'work_item'
       or not public.can_see_space_post(v_parent.id)
       or not public.acts_for_author(v_parent) then
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

  -- From a work item template (migration 20): one the caller may read in
  -- this Space, for the same Team.
  if p_template is not null then
    select * into v_template from public.post_templates t where t.id = p_template;
    if v_template.id is null or not public.can_read_template(v_template)
       or (v_template.space_id is not null and v_template.space_id <> p_space) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if v_template.kind <> 'work_item'
       or (v_template.team_id is not null and v_template.team_id is distinct from v_team) then
      raise exception 'this template is for another kind of post or Team' using errcode = '22023';
    end if;
  end if;
  if p_points is not null and (jsonb_typeof(p_points) <> 'array'
                               or jsonb_array_length(p_points) > 50) then
    raise exception 'at most 50 points' using errcode = '22023';
  end if;
  if p_due_at is not null and not public.due_at_fits(p_due, p_due_at) then
    raise exception 'a due time on its due day' using errcode = '22023';
  end if;

  insert into public.space_posts (id, space_id, team_id, kind, author_id, title, body,
                                  place_text, due_date, due_at, parent_id, source_message_id,
                                  quote, template_id)
  values (v_id, p_space, v_team, 'work_item', v_me, trim(p_title), nullif(trim(p_body), ''),
          nullif(trim(p_place), ''), p_due, p_due_at, p_parent, p_source_message, p_quote,
          p_template)
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
  -- Its points and page (migration 20).
  for v_point in select * from jsonb_array_elements(coalesce(p_points, '[]'::jsonb)) loop
    if jsonb_typeof(v_point) <> 'object' then
      raise exception 'a point must be an object' using errcode = '22023';
    end if;
    insert into public.checklist_points (id, post_id, sort, text)
    values (coalesce(nullif(v_point ->> 'id', '')::uuid, gen_random_uuid()), v_id, v_sort,
            public.point_text(v_point ->> 'text'));
    v_sort := v_sort + 1;
  end loop;
  if p_blocks is not null then
    perform public.validate_blocks(v_post, p_blocks);
    update public.space_posts set blocks = p_blocks where id = v_id;
  end if;
  return v_id;
end;
$function$;

-- Posting a checklist: also an optional due time (as in 20261016120000_post_pages.sql, with that change only).
drop function public.create_space_post(uuid, uuid, text, text, text, uuid, text, date, timestamptz, timestamptz, timestamptz, uuid, uuid[], jsonb, uuid, jsonb, jsonb, uuid, jsonb);
CREATE FUNCTION public.create_space_post(p_id uuid, p_space uuid, p_kind text, p_title text DEFAULT NULL::text, p_body text DEFAULT NULL::text, p_team uuid DEFAULT NULL::uuid, p_place text DEFAULT NULL::text, p_due date DEFAULT NULL::date, p_pinned_until timestamp with time zone DEFAULT NULL::timestamp with time zone, p_starts_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_ends_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_library_file uuid DEFAULT NULL::uuid, p_people uuid[] DEFAULT '{}'::uuid[], p_points jsonb DEFAULT '[]'::jsonb, p_source_message uuid DEFAULT NULL::uuid, p_quote jsonb DEFAULT NULL::jsonb, p_files jsonb DEFAULT '[]'::jsonb, p_template uuid DEFAULT NULL::uuid, p_blocks jsonb DEFAULT NULL::jsonb, p_due_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_template public.post_templates;
begin
  -- The same id again (a retry): the same post, if it is the caller's.
  select * into v_post from public.space_posts where id = v_id;
  if v_post.id is not null then
    if v_post.author_id = v_me and v_post.space_id = p_space and v_post.kind = p_kind then
      return v_post.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if p_kind is null or p_kind not in ('checklist', 'announcement', 'activity', 'file', 'report') then
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
     or ((p_due is not null or p_due_at is not null) and p_kind <> 'checklist')
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
  if p_due_at is not null and not public.due_at_fits(p_due, p_due_at) then
    raise exception 'a due time on its due day' using errcode = '22023';
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

  -- From a template (migration 20): a built-in or one of this Space the
  -- caller may read, of the same kind and audience.
  if p_template is not null then
    select * into v_template from public.post_templates t where t.id = p_template;
    if v_template.id is null or not public.can_read_template(v_template)
       or (v_template.space_id is not null and v_template.space_id <> p_space) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if v_template.kind <> p_kind
       or (v_template.team_id is not null and v_template.team_id is distinct from v_team) then
      raise exception 'this template is for another kind of post or Team' using errcode = '22023';
    end if;
  end if;

  insert into public.space_posts (id, space_id, team_id, kind, author_id, title, body,
                                  place_text, due_date, due_at, source_message_id, quote,
                                  pinned_until, starts_at, ends_at, library_file_id,
                                  template_id)
  values (v_id, p_space, v_team, p_kind, v_me, v_title, nullif(trim(p_body), ''),
          nullif(trim(p_place), ''), p_due, p_due_at, p_source_message, p_quote,
          p_pinned_until, p_starts_at, p_ends_at, p_library_file, p_template)
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
  -- The page, once its files and points are there (migration 20).
  if p_blocks is not null then
    perform public.validate_blocks(v_post, p_blocks);
    update public.space_posts set blocks = p_blocks where id = v_id;
  end if;

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
$function$;

-- Editing: the due time too, in the same Edited line (as in 20261016120000_post_pages.sql, with that change only).
CREATE OR REPLACE FUNCTION public.edit_space_post(p_id uuid, p_changes jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_owner uuid;
  v_diff jsonb := '{}'::jsonb;
  v_title text;
  v_body text;
  v_place text;
  v_due date;
  v_due_at timestamptz;
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
    if v_key not in ('title', 'body', 'place', 'due', 'due_at', 'add_files', 'remove_files', 'points',
                     'people', 'pinned_until', 'starts_at', 'ends_at')
       or (v_key = 'place' and v_post.kind not in ('work_item', 'checklist', 'activity'))
       or (v_key in ('due', 'due_at') and v_post.kind not in ('work_item', 'checklist'))
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
  -- The due date and time change together: a new date alone has no time
  -- (the same date again keeps it); a time alone keeps the date
  -- (migration 23).
  if p_changes ? 'due' or p_changes ? 'due_at' then
    begin
      v_due := case when p_changes ? 'due' then nullif(p_changes ->> 'due', '')::date
                    else v_post.due_date end;
      v_due_at := case when p_changes ? 'due_at' then nullif(p_changes ->> 'due_at', '')::timestamptz
                       when v_due is distinct from v_post.due_date then null
                       else v_post.due_at end;
    exception when others then
      raise exception 'a due date' using errcode = '22023';
    end;
    if v_due_at is not null and not public.due_at_fits(v_due, v_due_at) then
      raise exception 'a due time on its due day' using errcode = '22023';
    end if;
    if v_due is distinct from v_post.due_date or v_due_at is distinct from v_post.due_at then
      v_diff := v_diff || jsonb_build_object('due',
                  jsonb_build_object('from', v_post.due_date, 'to', v_due)
                  || jsonb_strip_nulls(jsonb_build_object('from_at', v_post.due_at, 'to_at', v_due_at)));
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
        if exists (select 1 from jsonb_path_query(v_post.blocks,
                     'strict $.** ? (@.type == "checklist_ref").point_ids[*]') r
                   where r #>> '{}' = v_point.id::text) then
          raise exception 'the page shows this point; take it off the page first'
            using errcode = 'P0001';
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
    -- A file the page shows stays until the page no longer shows it.
    if exists (
         select 1 from public.post_files f
         where f.post_id = p_id
           and f.id::text in (select jsonb_array_elements_text(p_changes -> 'remove_files'))
           and (f.storage_path in (
                  select r #>> '{}' from jsonb_path_query(v_post.blocks,
                    'strict $.** ? (@.type == "photo").path') r)
                or f.library_file_id::text in (
                  select r #>> '{}' from jsonb_path_query(v_post.blocks,
                    'strict $.** ? (@.type == "file").library_file_id') r))) then
      raise exception 'the page shows this file; take it off the page first' using errcode = 'P0001';
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
      due_date = case when p_changes ? 'due' or p_changes ? 'due_at' then v_due else due_date end,
      due_at = case when p_changes ? 'due' or p_changes ? 'due_at' then v_due_at else due_at end,
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
        due_date = case when p_changes ? 'due' or p_changes ? 'due_at' then v_due else due_date end
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
$function$;

-- A post's JSON: its due time (as in 20261016120000_post_pages.sql, with that change only).
CREATE OR REPLACE FUNCTION public.space_post_json(p_post space_posts, p_full boolean)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    'due_at', p_post.due_at,
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
    'has_page', jsonb_array_length(p_post.blocks) > 0,
    'template_id', p_post.template_id,
    'cover_path', (
      select f.storage_path from public.post_files f
      where f.post_id = p_post.id and f.storage_path is not null and f.mime like 'image/%'
      order by f.sort, f.created_at limit 1),
    'children', (
      select jsonb_build_object(
        'total', count(*),
        'checked', count(*) filter (where w.status = 'checked'),
        -- The first 10, for a walk's slip (R1b).
        'rows', (select jsonb_agg(r.row order by r.created_at, r.id) from (
                   select c2.id, c2.created_at, jsonb_strip_nulls(jsonb_build_object(
                            'id', c2.id, 'title', c2.title, 'item_status', w2.status,
                            'owner_id', w2.owner_id,
                            'owner_name', public.space_person_name(w2.owner_id),
                            'cover_path', (select f.storage_path from public.post_files f
                                           where f.post_id = c2.id and f.storage_path is not null
                                             and f.mime like 'image/%'
                                           order by f.sort, f.created_at limit 1))) as row
                   from public.space_posts c2
                   join public.work_items w2 on w2.id = c2.id
                   where c2.parent_id = p_post.id and c2.deleted_at is null and c2.status = 'live'
                     and public.can_see_space_post(c2.id)
                   order by c2.created_at, c2.id
                   limit 10) r))
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
    'blocks', p_post.blocks,
    'blocks_version', p_post.blocks_version,
    -- A report's work items, as this reader may see them (migration 20).
    'refs', (
      select jsonb_object_agg(c.id, jsonb_strip_nulls(jsonb_build_object(
               'title', c.title, 'ref', w.ref, 'item_status', w.status,
               'owner_name', public.space_person_name(w.owner_id),
               'checked_at', w.checked_at,
               'checker_name', public.space_person_name(w.checked_by),
               'done_photo_path', public.done_photo_path(w.id))))
      from public.space_posts c
      join public.work_items w on w.id = c.id
      where c.id::text in (select r #>> '{}' from jsonb_path_query(p_post.blocks,
                             'strict $.** ? (@.type == "item_ref").post_id') r)
        and c.space_id = p_post.space_id and c.deleted_at is null
        and public.can_see_space_post(c.id)),
    'under', (
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'title', c.title, 'status', c.status, 'ref', w.ref,
               'item_status', w.status, 'owner_id', w.owner_id,
               'owner_name', public.space_person_name(w.owner_id),
               'cover_path', (select f.storage_path from public.post_files f
                              where f.post_id = c.id and f.storage_path is not null
                                and f.mime like 'image/%'
                              order by f.sort, f.created_at limit 1))
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
$function$;

-- The week report: a timed item is late after its time, and coming up until then (as in 20261016120000_post_pages.sql, with that change only).
CREATE OR REPLACE FUNCTION public.week_report(p_space uuid, p_today date, p_from timestamp with time zone, p_to timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not public.is_member(p_space) then
    return null;
  end if;
  if p_today is null or p_from is null or p_to is null or p_to <= p_from
     or p_to - p_from > interval '7 days 1 hour' then
    raise exception 'choose a week' using errcode = '22023';
  end if;
  return jsonb_build_object(
    'needs_decision', coalesce((
      select jsonb_agg(x.row order by x.at desc, x.id) from (
        select p.id, coalesce(w.done_at, last.created_at, p.created_at) as at,
               jsonb_strip_nulls(jsonb_build_object(
                 'post_id', p.id, 'title', p.title, 'ref', w.ref,
                 'state', case when w.status = 'done' then 'done'
                               when last.kind = 'sent_back' then 'sent_back'
                               else 'late' end,
                 'owner_name', public.space_person_name(w.owner_id),
                 'reason', case when w.status = 'open' and last.kind = 'sent_back' then last.reason end,
                 'due_date', p.due_date, 'due_at', p.due_at, 'done_at', w.done_at,
                 'needs_me', public.item_needs_me(w, p) is not null)) as row
        from public.work_items w
        join public.space_posts p on p.id = w.id
        left join lateral (
          select e.kind, e.reason, e.created_at from public.work_item_events e
          where e.work_item_id = w.id and e.kind in ('done', 'checked', 'sent_back')
          order by e.created_at desc, e.id desc limit 1) last on true
        where p.space_id = p_space and p.deleted_at is null and p.status = 'live'
          and (w.status = 'done'
               or (w.status = 'open' and (last.kind = 'sent_back' or public.is_late(p, p_today))))
          and not public.is_target(p.id)
          and public.can_see_space_post(p.id)
        order by 2 desc, p.id
        limit 30) x), '[]'::jsonb),
    'checked', coalesce((
      select jsonb_agg(x.row order by x.at desc, x.id) from (
        select p.id, w.checked_at as at, jsonb_strip_nulls(jsonb_build_object(
                 'post_id', p.id, 'title', p.title, 'ref', w.ref,
                 'done_photo_path', public.done_photo_path(w.id),
                 'checker_name', public.space_person_name(w.checked_by),
                 'checked_at', w.checked_at)) as row
        from public.work_items w
        join public.space_posts p on p.id = w.id
        where p.space_id = p_space and p.deleted_at is null and w.status = 'checked'
          and w.checked_at >= p_from and w.checked_at < p_to
          and public.can_see_space_post(p.id)
        order by w.checked_at desc, p.id
        limit 30) x), '[]'::jsonb),
    'targets', coalesce((
      select jsonb_agg(x.row order by x.at desc, x.id) from (
        select p.id, p.created_at as at, jsonb_strip_nulls(jsonb_build_object(
                 'post_id', p.id, 'title', p.title, 'ref', w.ref, 'due_date', p.due_date,
                 'due_at', p.due_at, 'children', ch.progress)) as row
        from public.work_items w
        join public.space_posts p on p.id = w.id
        join lateral (
          select jsonb_build_object('total', count(*),
                                    'checked', count(*) filter (where cw.status = 'checked')) as progress
          from public.space_posts c
          join public.work_items cw on cw.id = c.id
          where c.parent_id = p.id and c.deleted_at is null and c.status = 'live'
            and public.can_see_space_post(c.id)
          having count(*) > 0
             and count(*) filter (where cw.status = 'checked') < count(*)) ch on true
        where p.space_id = p_space and p.deleted_at is null and p.status = 'live'
          and p.parent_id is null and w.status <> 'checked'
          and public.can_see_space_post(p.id)
        order by p.created_at desc, p.id
        limit 30) x), '[]'::jsonb),
    'coming_up', coalesce((
      select jsonb_agg(x.row order by x.at, x.id) from (
        select p.id, p.starts_at as at, jsonb_strip_nulls(jsonb_build_object(
                 'post_id', p.id, 'kind', 'activity', 'title', p.title,
                 'starts_at', p.starts_at, 'ends_at', p.ends_at, 'place', p.place_text)) as row
        from public.space_posts p
        where p.space_id = p_space and p.kind = 'activity' and p.deleted_at is null
          and p.status = 'live' and p.starts_at >= now() and p.starts_at < now() + interval '7 days'
          and public.can_see_space_post(p.id)
        union all
        select p.id, coalesce(p.due_at, p.due_date::timestamptz), jsonb_strip_nulls(jsonb_build_object(
                 'post_id', p.id, 'kind', 'work_item', 'title', p.title, 'ref', w.ref,
                 'due_date', p.due_date, 'due_at', p.due_at, 'owner_name', public.space_person_name(w.owner_id)))
        from public.work_items w
        join public.space_posts p on p.id = w.id
        where p.space_id = p_space and p.deleted_at is null and p.status = 'live'
          and w.status in ('open', 'done')
          and case when p.due_at is not null
                   then p.due_at >= now() and p.due_at < now() + interval '7 days'
                   else p.due_date >= p_today and p.due_date < p_today + 7 end
          and public.can_see_space_post(p.id)
        order by 2, 1
        limit 30) x), '[]'::jsonb));
end;
$function$;

-- My calendar: a work item's or checklist's due time in starts_at, as a to-do's (as in 20261015230000_notebook.sql, with that change only).
CREATE OR REPLACE FUNCTION public.my_calendar(p_from_day date, p_to_day date, p_from timestamp with time zone, p_to timestamp with time zone)
 RETURNS TABLE(kind text, space_id uuid, space_name text, team_id uuid, post_id uuid, note_id uuid, title text, place text, day date, starts_at timestamp with time zone, ends_at timestamp with time zone, status text, needs_me boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
         p.place_text, p.due_date, p.due_at, null::timestamptz, w.status,
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
         p.place_text, p.due_date, p.due_at, null, p.status, public.checklist_needs_me(p)
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
$function$;

-- Download my data: a post's due time (as in 20261016180000_dm.sql, with that change only).
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
                              'place', p.place_text, 'due_date', p.due_date, 'due_at', p.due_at,
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
-- The month drop-down
-- ---------------------------------------------------------------------------

-- 'posts' rows: a time (15 minutes) with a post the caller can see, as the
-- daybook page lists them. 'due' rows: a day with a live work item that
-- isn't checked, or a live checklist with a point not ticked, the caller
-- can see. Days and times
-- come from the phone, as in my_calendar.
create function public.daybook_month(p_space uuid, p_from_day date, p_to_day date,
                                     p_from timestamptz, p_to timestamptz)
returns table (kind text, at timestamptz, day date)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_from_day is null or p_to_day is null or p_to_day < p_from_day
     or p_to_day - p_from_day > 61
     or p_from is null or p_to is null or p_to <= p_from
     -- An hour of slack for a change of clock in the phone's time zone.
     or p_to - p_from > interval '62 days 1 hour' then
    raise exception 'choose up to 62 days' using errcode = '22023';
  end if;
  if not public.is_member(p_space) then
    return;
  end if;
  return query
  select distinct 'posts'::text,
         date_bin('15 minutes', p.created_at, timestamptz '2000-01-01 00:00+00'), null::date
  from public.space_posts p
  where p.space_id = p_space and p.deleted_at is null
    and p.created_at >= p_from and p.created_at < p_to
    and public.can_see_space_post(p.id)
  union
  select 'due'::text, null::timestamptz, p.due_date
  from public.space_posts p
  left join public.work_items w on w.id = p.id
  where p.space_id = p_space and p.deleted_at is null and p.status = 'live'
    and ((p.kind = 'checklist'
          and exists (select 1 from public.checklist_points c
                      where c.post_id = p.id and c.ticked_at is null))
         or (p.kind = 'work_item' and w.status in ('open', 'done')))
    and p.due_date between p_from_day and p_to_day
    and public.can_see_space_post(p.id)
  order by 1, 2, 3;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.due_at_fits(date, timestamptz),
  public.is_late(public.space_posts, date),
  public.set_site_start_date(uuid, date),
  public.daybook_month(uuid, date, date, timestamptz, timestamptz),
  public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid, uuid, jsonb,
                          jsonb, uuid, jsonb, jsonb, timestamptz),
  public.create_space_post(uuid, uuid, text, text, text, uuid, text, date, timestamptz,
                           timestamptz, timestamptz, uuid, uuid[], jsonb, uuid, jsonb, jsonb,
                           uuid, jsonb, timestamptz)
  from public, anon;
-- Internal helpers.
revoke execute on function
  public.is_late(public.space_posts, date)
  from authenticated;
grant execute on function
  public.due_at_fits(date, timestamptz),
  public.set_site_start_date(uuid, date),
  public.daybook_month(uuid, date, date, timestamptz, timestamptz),
  public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid, uuid, jsonb,
                          jsonb, uuid, jsonb, jsonb, timestamptz),
  public.create_space_post(uuid, uuid, text, text, text, uuid, text, date, timestamptz,
                           timestamptz, timestamptz, uuid, uuid[], jsonb, uuid, jsonb, jsonb,
                           uuid, jsonb, timestamptz)
  to authenticated;
