-- Migration 29: slice 2 live (review 62, "The next migration (29)"). Branch
-- slice2-live-db. Not live.
--
-- - N1, private Realtime channels: policies on realtime.messages let a user
--   receive (select) and send (insert) a broadcast on the topic
--   'daybook:<space id>' only while they may read that Space (is_member, as
--   daybook_cards). A non-member, someone who left and anon get nothing and
--   can't send. One topic per Space: the message is only a post id, and
--   everyone re-reads under the post's own rules, so a Team needs no topic
--   of its own. Review 63 R1: a chat thread's channel, 'thread:<thread
--   id>', may be joined (receive only) by whoever can_use_thread, so chat
--   stays live once public channels are off.
-- - N2: an admin acting for an author who is gone (acts_for_author) may
--   unpin that author's announcement through edit_space_post with exactly
--   {"pinned_until": null}. Every other edit stays the author's.
-- - my_ack_at in the post JSON (so daybook_cards, post_page and
--   daybook_extras): when the caller gave each of their acknowledgements,
--   {"got_it": "<time>"} or {}; my_acks is unchanged. Got it given again
--   after an edit takes the new time (review 61 G1); Received keeps its
--   first time (review 63 R2); otherwise a second tap still changes nothing.
-- - The note kind (review 50 F58): create_space_post takes p_kind 'note', a
--   title with words, photos or files, and nothing else: no people, points,
--   pin, times, place, due date or Library file, and no acknowledgement
--   (ack refuses). It reads, edits, cancels and deletes as an announcement,
--   tells nobody, never needs you, and moves its card on create and edit.

-- ---------------------------------------------------------------------------
-- The note kind
-- ---------------------------------------------------------------------------

alter table public.space_posts drop constraint space_posts_kind_check;
alter table public.space_posts add constraint space_posts_kind_check
  check (kind in ('note', 'work_item', 'checklist', 'announcement', 'activity', 'file', 'report'));

-- ---------------------------------------------------------------------------
-- N1: private Realtime channels
-- ---------------------------------------------------------------------------

-- Whether the caller may use a daybook topic, 'daybook:<space id>': the
-- same test as reading the Space (is_member; a hidden account and a block
-- change nothing there, so they change nothing here). Any other topic is
-- refused, and a topic that isn't a Space id never reaches the cast.
create function public.may_use_daybook_topic(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_topic ~* '^daybook:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.is_member(substr(p_topic, 9)::uuid)
    else false
  end;
$$;

-- Whether the caller may join a chat thread's channel, 'thread:<thread id>'
-- (review 63 R1): the chat's live updates are Postgres changes on messages,
-- and with public channels off they need a private channel too. The same
-- test as reading the thread (can_use_thread: a Team's thread stays in that
-- Team). Receive only: the chat sends nothing on it.
create function public.may_use_thread_topic(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_topic ~* '^thread:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.can_use_thread(substr(p_topic, 8)::uuid)
    else false
  end;
$$;

-- Realtime Authorization reads these policies as the signed-in person when
-- they join a private channel (select: may receive) and when they send on
-- it (insert: may send), with realtime.topic() set to the channel's topic.
-- A row is seen or written only on that topic, so joining one Space's
-- channel never shows another's rows. Nothing for anon.
create policy daybook_live_receive on realtime.messages
  for select to authenticated
  using (realtime.messages.extension = 'broadcast'
         and realtime.messages.topic = (select realtime.topic())
         and ((select public.may_use_daybook_topic((select realtime.topic())))
              or (select public.may_use_thread_topic((select realtime.topic())))));
create policy daybook_live_send on realtime.messages
  for insert to authenticated
  with check (realtime.messages.extension = 'broadcast'
              and realtime.messages.topic = (select realtime.topic())
              and (select public.may_use_daybook_topic((select realtime.topic()))));

-- ---------------------------------------------------------------------------
-- Functions
-- ---------------------------------------------------------------------------

-- As 20261017120000_daybook_extras.sql, with 'note' in the kinds (F58).
CREATE OR REPLACE FUNCTION public.create_space_post(p_id uuid, p_space uuid, p_kind text, p_title text DEFAULT NULL::text, p_body text DEFAULT NULL::text, p_team uuid DEFAULT NULL::uuid, p_place text DEFAULT NULL::text, p_due date DEFAULT NULL::date, p_pinned_until timestamp with time zone DEFAULT NULL::timestamp with time zone, p_starts_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_ends_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_library_file uuid DEFAULT NULL::uuid, p_people uuid[] DEFAULT '{}'::uuid[], p_points jsonb DEFAULT '[]'::jsonb, p_source_message uuid DEFAULT NULL::uuid, p_quote jsonb DEFAULT NULL::jsonb, p_files jsonb DEFAULT '[]'::jsonb, p_template uuid DEFAULT NULL::uuid, p_blocks jsonb DEFAULT NULL::jsonb, p_due_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
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

  -- A note (migration 29): the plain post. Every "what each kind takes"
  -- test below already refuses it people, points, a pin, times, a place, a
  -- due date and a Library file, and it tells nobody.
  if p_kind is null or p_kind not in ('note', 'checklist', 'announcement', 'activity', 'file', 'report') then
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


-- As 20261017120000_daybook_extras.sql, with the N2 path: an admin acting for
-- a gone author may unpin (review 62).
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
  -- not switched off); files need the files right too. Migration 29 (review
  -- 62 N2): a Space admin acting for an author who is gone (acts_for_author)
  -- may unpin an announcement, and only that: the change is exactly
  -- {"pinned_until": null}.
  -- The words stay the author's, and so does the post.
  if v_post.id is null
     or (not (v_post.author_id is not distinct from v_me
              and public.is_member(v_post.space_id) and not public.is_hidden_account(v_me)
              and public.can(v_post.space_id, 'create_items')
              and not ((p_changes ? 'add_files' or p_changes ? 'remove_files')
                       and not public.can(v_post.space_id, 'add_files')))
         and not (v_post.author_id is distinct from v_me and v_post.kind = 'announcement'
                  and jsonb_typeof(p_changes) = 'object'
                  and (select array_agg(k) from jsonb_object_keys(p_changes) k) = array['pinned_until']
                  and nullif(p_changes ->> 'pinned_until', '') is null
                  and public.acts_for_author(v_post))) then
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


-- As 20261015180000_post_kinds.sql, with an acknowledgement given again after
-- an edit taking the new time (review 61 G1). A note is refused, as every
-- kind not listed.
CREATE OR REPLACE FUNCTION public.ack(p_post uuid, p_kind text, p_on boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  -- A note takes no acknowledgement (migration 29): it isn't in this list.
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
  -- Got it given again after an edit (migration 29, review 61 G1): it takes
  -- the new time, so my_ack_at is later than the edit. Only Got it (review
  -- 63 R2): Received keeps its first time, the record of receipt. Otherwise
  -- a second tap changes nothing.
  insert into public.post_acks as a (post_id, profile_id, kind) values (p_post, v_me, p_kind)
  on conflict (post_id, profile_id, kind) do update set created_at = now()
  where a.kind = 'got_it' and a.created_at < v_post.edited_at;
  if v_me is distinct from v_post.author_id then
    insert into public.post_others (post_id) values (p_post) on conflict do nothing;
  end if;
end;
$function$;


-- As 20261017120000_daybook_extras.sql, with my_ack_at next to my_acks.
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
    -- When the caller gave each of them, {"got_it": "<time>"} or {}
    -- (migration 29): only the caller's own.
    'my_ack_at', coalesce((
      select jsonb_object_agg(a.kind, a.created_at order by a.kind)
      from public.post_acks a where a.post_id = p_post.id and a.profile_id = auth.uid()),
      '{}'::jsonb),
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
    -- A work item's first three Library files, for the slip's chips, and
    -- whether there are more (review 45 M3). The full page lists them all.
    'attachments', (
      select jsonb_agg(jsonb_build_object('library_file_id', a.id, 'name', a.name,
                                          'rev_label', a.rev_label) order by a.created_at, a.id)
      from (select lf.id, lf.name, lf.rev_label, wa.created_at
            from public.work_item_attachments wa
            join public.library_files lf on lf.id = wa.library_file_id
            where wa.work_item_id = p_post.id and public.can_read_library_file(lf.id)
            order by wa.created_at, lf.id limit 3) a),
    'attachments_more', (
      select true
      from public.work_item_attachments wa
      where wa.work_item_id = p_post.id and public.can_read_library_file(wa.library_file_id)
      having count(*) > 3),
    -- The last time it was given to someone else.
    'given_to', (
      select jsonb_build_object('from_id', e.from_owner_id,
                                'from_name', public.space_person_name(e.from_owner_id),
                                'to_id', e.to_owner_id,
                                'to_name', public.space_person_name(e.to_owner_id),
                                'at', e.created_at)
      from public.work_item_events e
      where e.work_item_id = p_post.id and e.kind = 'reassigned'
      order by e.created_at desc, e.id desc limit 1),
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
                                          'rev_label', lf.rev_label,
                                          'mime', lf.mime, 'bytes', lf.bytes)
                       order by a.created_at, lf.id)
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


-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

-- Realtime evaluates the policies as authenticated, so it may run the test.
revoke execute on function public.may_use_daybook_topic(text) from public, anon;
grant execute on function public.may_use_daybook_topic(text) to authenticated;
revoke execute on function public.may_use_thread_topic(text) from public, anon;
grant execute on function public.may_use_thread_topic(text) to authenticated;
