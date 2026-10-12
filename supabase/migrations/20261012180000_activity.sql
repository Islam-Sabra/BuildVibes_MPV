-- Migration 13: Activity and the Home Spaces tab (week 7 part 2). Brief: docs/reviews/2026-10-12-16-home-activity.md §3.
--
-- - notifications: one row per thing that happened to a person. Written
--   only by triggers, never by the app; each person reads only their own.
--   Never to the actor, never across a block, and Space news only to
--   people still in the Space. A declined join request makes none.
-- - Useful on a post: one row per post per day (UTC), moved up by each
--   new mark, never one per mark and never a count. It keeps no actor:
--   the row's line names at most two people you follow (useful_names),
--   so nobody can list who marked their post.
-- - Repeats merge: asking to join the same Space again within a day
--   updates the admins' row; following again within 7 days adds none.
-- - space_visits: when you last opened each Space (mark_space_seen), so
--   Home can show what is new since.
-- - my_activity(): the last 7 days, with each row's group (a Space, Your
--   record, Your network, Your posts) and its place in the group (A = the
--   oldest). mark_activity_read() and unread_activity() (a yes/no, never
--   a number) serve the Activity tab and its dot.
-- - home_day() and today_in_spaces(): the H1b header and its rows. "Today"
--   starts at the phone's midnight, which the app passes, so no country's
--   time zone is typed here.
-- Push (push_tokens, push_queue) comes in part 3.
-- Review 19 fixes are in this file (it wasn't live yet).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in (
    'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
    'join_request', 'join_confirmed', 'role_confirmed', 'follow',
    'post_reply', 'post_useful')),
  -- A deleted account takes its notifications with it.
  actor_id uuid references public.profiles (id) on delete cascade,
  space_id uuid references public.spaces (id) on delete cascade,
  work_item_id uuid references public.work_items (id) on delete cascade,
  post_id uuid references public.posts (id) on delete cascade,
  reply_id uuid references public.post_replies (id) on delete cascade,
  request_id uuid references public.space_join_requests (id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  -- post_useful only: the day its row stands for.
  day date,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check ((kind = 'post_useful') = (day is not null))
);
create index notifications_profile_idx on public.notifications (profile_id, created_at desc);
create unique index notifications_useful_day_idx
  on public.notifications (profile_id, post_id, day) where kind = 'post_useful';

create table public.space_visits (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  space_id uuid not null references public.spaces (id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (profile_id, space_id)
);

-- Home: replies to your chat messages, and each Space's chat since a time.
create index messages_reply_to_idx on public.messages (reply_to) where reply_to is not null;
create index messages_space_idx on public.messages (space_id, created_at desc);
-- Home: today's work item events, without walking every item.
create index work_item_events_created_idx on public.work_item_events (created_at);

-- ---------------------------------------------------------------------------
-- Writing notifications (triggers only)
-- ---------------------------------------------------------------------------

-- True when [p_a] and [p_b] blocked each other, either way. Internal: it
-- answers about any two people, so the app can't call it.
create or replace function public.blocked_between(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks b
    where (b.blocker_id = p_a and b.blocked_id = p_b)
       or (b.blocker_id = p_b and b.blocked_id = p_a)
  );
$$;

create or replace function public.add_notification(
  p_to uuid,
  p_kind text,
  p_actor uuid,
  p_space uuid default null,
  p_item uuid default null,
  p_post uuid default null,
  p_reply uuid default null,
  p_request uuid default null,
  p_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
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

  -- Asking again (after cancelling) within a day: the same row, now
  -- pointing at the new request. No new row, so no new push.
  if p_kind = 'join_request' then
    update public.notifications
    set request_id = p_request
    where profile_id = p_to and kind = 'join_request' and actor_id = p_actor
      and space_id = p_space and created_at > now() - interval '1 day';
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
    values (p_to, p_kind, p_post, p_payload, (now() at time zone 'utc')::date)
    on conflict (profile_id, post_id, day) where kind = 'post_useful'
    do update set created_at = excluded.created_at, read_at = null;
  else
    insert into public.notifications (profile_id, kind, actor_id, space_id, work_item_id,
                                      post_id, reply_id, request_id, payload)
    values (p_to, p_kind, p_actor, p_space, p_item, p_post, p_reply, p_request, p_payload);
  end if;
end;
$$;

-- Work items: raised or reassigned to you, done (to its creator), checked
-- and sent back (to its owner), a comment (to its owner and creator).
create or replace function public.handle_work_item_event_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.work_items;
  v_payload jsonb;
begin
  select * into v_item from public.work_items where id = new.work_item_id;
  v_payload := jsonb_strip_nulls(jsonb_build_object('event_id', new.id, 'reason', new.reason));
  case new.kind
    when 'raised' then
      perform public.add_notification(v_item.owner_id, 'item_assigned', new.actor_id,
        v_item.space_id, v_item.id, p_payload => v_payload);
    when 'reassigned' then
      perform public.add_notification(new.to_owner_id, 'item_assigned', new.actor_id,
        v_item.space_id, v_item.id, p_payload => v_payload);
    when 'done' then
      perform public.add_notification(v_item.created_by, 'item_done', new.actor_id,
        v_item.space_id, v_item.id, p_payload => v_payload);
    when 'checked' then
      perform public.add_notification(v_item.owner_id, 'item_checked', new.actor_id,
        v_item.space_id, v_item.id, p_payload => v_payload);
    when 'sent_back' then
      perform public.add_notification(v_item.owner_id, 'item_sent_back', new.actor_id,
        v_item.space_id, v_item.id, p_payload => v_payload);
    when 'comment' then
      perform public.add_notification(v_item.owner_id, 'item_comment', new.actor_id,
        v_item.space_id, v_item.id, p_payload => v_payload);
      if v_item.created_by is distinct from v_item.owner_id then
        perform public.add_notification(v_item.created_by, 'item_comment', new.actor_id,
          v_item.space_id, v_item.id, p_payload => v_payload);
      end if;
    else
      null;
  end case;
  return null;
end;
$$;
create trigger work_item_events_notify
  after insert on public.work_item_events
  for each row execute function public.handle_work_item_event_notify();

-- A request to join reaches every admin; a confirmed one, the new member.
-- Declined: nothing (they see "Declined" on their request card).
create or replace function public.handle_join_request_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    perform public.add_notification(m.profile_id, 'join_request', new.profile_id,
      new.space_id, p_request => new.id)
    from public.space_members m
    where m.space_id = new.space_id and m.is_admin and m.left_at is null;
  elsif tg_op = 'UPDATE' and new.status = 'confirmed'
        and old.status is distinct from 'confirmed' then
    perform public.add_notification(new.profile_id, 'join_confirmed', new.decided_by,
      new.space_id, p_request => new.id);
  end if;
  return null;
end;
$$;
create trigger space_join_requests_notify
  after insert or update of status on public.space_join_requests
  for each row execute function public.handle_join_request_notify();

-- Proof on your record, from a Space or a teammate. The Space goes in the
-- payload: the row belongs to "Your record", not to the Space.
create or replace function public.handle_confirmation_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.add_notification(c.profile_id, 'role_confirmed', new.confirmed_by,
    p_payload => jsonb_strip_nulls(jsonb_build_object(
      'cv_project_id', new.cv_project_id, 'source', new.source, 'space_id', new.space_id)))
  from public.cv_projects c
  where c.id = new.cv_project_id;
  return null;
end;
$$;
create trigger cv_project_confirmations_notify
  after insert on public.cv_project_confirmations
  for each row execute function public.handle_confirmation_notify();

create or replace function public.handle_follow_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.add_notification(new.followee_id, 'follow', new.follower_id);
  return null;
end;
$$;
create trigger follows_notify
  after insert on public.follows
  for each row execute function public.handle_follow_notify();

-- A reply reaches the post's author, and the author of the reply it answers.
create or replace function public.handle_post_reply_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post_author uuid;
  v_reply_author uuid;
begin
  select author_id into v_post_author from public.posts where id = new.post_id;
  perform public.add_notification(v_post_author, 'post_reply', new.author_id,
    p_post => new.post_id, p_reply => new.id, p_payload => '{"to": "post"}');
  if new.reply_to is not null then
    select author_id into v_reply_author from public.post_replies where id = new.reply_to;
    if v_reply_author is distinct from v_post_author then
      perform public.add_notification(v_reply_author, 'post_reply', new.author_id,
        p_post => new.post_id, p_reply => new.id, p_payload => '{"to": "reply"}');
    end if;
  end if;
  return null;
end;
$$;
create trigger post_replies_notify
  after insert on public.post_replies
  for each row execute function public.handle_post_reply_notify();

create or replace function public.handle_useful_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.target_kind = 'post' then
    perform public.add_notification(p.author_id, 'post_useful', new.profile_id,
      p_post => p.id)
    from public.posts p
    where p.id = new.target_id;
  end if;
  return null;
end;
$$;
create trigger useful_marks_notify
  after insert on public.useful_marks
  for each row execute function public.handle_useful_notify();

-- ---------------------------------------------------------------------------
-- Activity (A1 v2)
-- ---------------------------------------------------------------------------

create type public.activity_row as (
  id uuid,
  kind text,
  -- 'space', 'record', 'network' or 'posts'.
  group_kind text,
  space_id uuid,
  space_name text,
  my_pass text,
  work_item_id uuid,
  work_item_ref text,
  work_item_title text,
  post_id uuid,
  reply_id uuid,
  -- The reply's text, or the post's: the row's one line of context.
  context text,
  request_id uuid,
  request_status text,
  project_id uuid,
  project_name text,
  actor_id uuid,
  actor_name text,
  payload jsonb,
  created_at timestamptz,
  read_at timestamptz,
  -- The row's place in its group, 1 = the oldest in the window (letter A).
  seq integer,
  -- post_useful: at most two people you follow who marked it. Never a count.
  useful_names text[]
);

-- The caller's last 7 days. Rows whose target is gone, or whose Space the
-- caller left, or whose actor is now blocked, drop out.
create or replace function public.activity_rows()
returns setof public.activity_row
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select n.*,
           case when n.kind in ('role_confirmed') then 'record'
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
      and (r.kind <> 'role_confirmed' or cp.id is not null)
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

-- Newest first, 100 at a time. Cursor: {"at": <created_at>, "id": <id>}
-- of the last row shown.
create or replace function public.my_activity(p_cursor jsonb default null)
returns setof public.activity_row
language sql
stable
security definer
set search_path = ''
as $$
  select a.*
  from public.activity_rows() a
  where p_cursor is null
     or (a.created_at, a.id) < ((p_cursor ->> 'at')::timestamptz, (p_cursor ->> 'id')::uuid)
  order by a.created_at desc, a.id desc
  limit 100;
$$;

-- Called when Activity opens.
create or replace function public.mark_activity_read()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.notifications set read_at = now()
  where profile_id = auth.uid() and read_at is null;
$$;

-- The dot on the Activity tab: yes or no, never a number.
create or replace function public.unread_activity()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.activity_rows() a where a.read_at is null);
$$;

-- ---------------------------------------------------------------------------
-- Home Spaces tab (H1b)
-- ---------------------------------------------------------------------------

-- Opening a Space marks it seen.
create or replace function public.mark_space_seen(p_space uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_member(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  insert into public.space_visits (profile_id, space_id, seen_at)
  values (auth.uid(), p_space, now())
  on conflict (profile_id, space_id) do update set seen_at = excluded.seen_at;
end;
$$;

-- The start of the caller's day, as the phone sends it: at most two days
-- back and never in the future; yesterday's time now when missing.
create or replace function public.day_start(p_day_start timestamptz)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select least(greatest(coalesce(p_day_start, now() - interval '1 day'),
                        now() - interval '2 days'),
               now());
$$;

-- One row per Space with something new today since the caller's last
-- visit, by someone else: its most important change (a work item event,
-- then a Library file, then the last chat message). Newest first.
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

-- The H1b header: what needs you, Spaces active today, and replies today
-- to your chat messages. Each is the caller's own count.
create or replace function public.home_day(p_day_start timestamptz)
returns table (needs_you integer, active_spaces integer, replies integer)
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select count(*)::int from public.needs_you()),
    (select count(*)::int from public.today_in_spaces(p_day_start)),
    -- Today's messages in your Spaces first (messages_space_idx), then
    -- those answering one of yours.
    (select count(*)::int
     from public.space_members sm
     join public.messages r
       on r.space_id = sm.space_id and r.created_at >= public.day_start(p_day_start)
     join public.messages mine on mine.id = r.reply_to and mine.author_id = auth.uid()
     where sm.profile_id = auth.uid() and sm.left_at is null
       and r.reply_to is not null
       and r.author_id is distinct from auth.uid()
       and r.deleted_at is null
       and public.can_use_thread(r.thread_id)
       and not public.blocked_between(auth.uid(), r.author_id));
$$;

-- ---------------------------------------------------------------------------
-- Row-level security and grants
-- ---------------------------------------------------------------------------

alter table public.notifications enable row level security;
alter table public.space_visits enable row level security;

create policy notifications_read_own on public.notifications
  for select to authenticated using (profile_id = auth.uid());
create policy space_visits_read_own on public.space_visits
  for select to authenticated using (profile_id = auth.uid());

revoke all on public.notifications, public.space_visits from anon, authenticated;
grant select on public.notifications, public.space_visits to authenticated;
grant all on public.notifications, public.space_visits to service_role;

revoke execute on function
  public.blocked_between(uuid, uuid),
  public.add_notification(uuid, text, uuid, uuid, uuid, uuid, uuid, uuid, jsonb),
  public.handle_work_item_event_notify(),
  public.handle_join_request_notify(),
  public.handle_confirmation_notify(),
  public.handle_follow_notify(),
  public.handle_post_reply_notify(),
  public.handle_useful_notify(),
  public.activity_rows(),
  public.my_activity(jsonb),
  public.mark_activity_read(),
  public.unread_activity(),
  public.mark_space_seen(uuid),
  public.day_start(timestamptz),
  public.today_in_spaces(timestamptz),
  public.home_day(timestamptz)
  from public, anon;
-- Internal: they answer about anyone, or write rows.
revoke execute on function
  public.blocked_between(uuid, uuid),
  public.add_notification(uuid, text, uuid, uuid, uuid, uuid, uuid, uuid, jsonb),
  public.handle_work_item_event_notify(),
  public.handle_join_request_notify(),
  public.handle_confirmation_notify(),
  public.handle_follow_notify(),
  public.handle_post_reply_notify(),
  public.handle_useful_notify(),
  public.activity_rows()
  from authenticated;

grant execute on function
  public.my_activity(jsonb),
  public.mark_activity_read(),
  public.unread_activity(),
  public.mark_space_seen(uuid),
  public.day_start(timestamptz),
  public.today_in_spaces(timestamptz),
  public.home_day(timestamptz)
  to authenticated;
