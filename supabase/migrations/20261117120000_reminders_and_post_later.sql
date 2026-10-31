-- Migration 57 (review 108): reminders for someone else (RM1, RM2) and Post
-- later (PL1, PL2).
--
-- 1. work_item_reminders: a reminder the item's creator, its owner or a
--    Lead sets for one or more people who can see the item ("Someone"; a
--    "Me" reminder stays on the phone). Read by its setter, its people, the
--    item's creator and owner, and the Space's Leads; written only by
--    set_work_reminder and remove_work_reminder. At most 5 wait on an item,
--    and one person sets at most 20 a day. due_work_reminders() (cron,
--    every 5 minutes) pushes each once per person, unless the item is no
--    longer Open, the person has left, or its setter has left or may no
--    longer remind (not the creator, the owner or a Lead).
--    The push queue keeps ids only (migration 14's rule): the item's title
--    and the note go on the lock screen only for people who chose "Show
--    message text on lock screen".
-- 2. scheduled_posts: a post, announcement, checklist, work item, Feed post
--    or notebook share to send later. It keeps the create call (its name,
--    one of five, and its arguments). publish_due_posts() (cron, every 5
--    minutes) makes that same call as the author, so every rule is checked
--    again then; a refusal leaves it failed, says why, and pushes "Couldn't
--    post". A failed one can be tried again (Post now) or cancelled. Each
--    change locks the row and changes it only from the state it was read
--    in, so Post now or Cancel never races the cron into a second post or
--    a false "Couldn't post". One from My notebook through the writing
--    card marks its note "Went into a Space" once it goes. Owner-only;
--    written by schedule_post, update_scheduled_post, cancel_scheduled_post
--    and post_scheduled_now.
-- The two cron schedules are in supabase/ops/reminders_post_later_cron.sql
-- (a live step).

-- ---------------------------------------------------------------------------
-- Pushes
-- ---------------------------------------------------------------------------

alter table public.push_queue drop constraint push_queue_kind_check;
alter table public.push_queue add constraint push_queue_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'announcement_new', 'checklist_for_you', 'activity_invited', 'activity_starting',
  'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow', 'post_reply', 'chat_message',
  'dm_message', 'dm_request', 'dm_follow_up',
  'work_reminder', 'scheduled_failed'));

-- ---------------------------------------------------------------------------
-- 1. Reminders for someone else
-- ---------------------------------------------------------------------------

create table public.work_item_reminders (
  -- Chosen by the app, so a retry is the same reminder.
  id uuid primary key,
  post_id uuid not null references public.space_posts (id) on delete cascade,
  space_id uuid not null references public.spaces (id) on delete cascade,
  set_by uuid not null references public.profiles (id) on delete cascade,
  remind_at timestamptz not null,
  note text check (length(note) <= 140),
  recipients uuid[] not null check (cardinality(recipients) between 1 and 20),
  -- Sent, or passed over (the item no longer Open): never tried again.
  sent_at timestamptz,
  created_at timestamptz not null default now()
);
create index work_item_reminders_post_idx on public.work_item_reminders (post_id)
  where sent_at is null;
create index work_item_reminders_due_idx on public.work_item_reminders (remind_at)
  where sent_at is null;

-- Once per person per reminder.
create table public.work_item_reminder_sends (
  reminder_id uuid not null references public.work_item_reminders (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  sent_at timestamptz not null default now(),
  primary key (reminder_id, profile_id)
);

alter table public.work_item_reminders enable row level security;
alter table public.work_item_reminder_sends enable row level security;

-- The caller may read [p_row]: a member who set it, is reminded by it,
-- made or owns the item, or is a Lead of its Space.
create or replace function public.can_read_work_reminder(p_row public.work_item_reminders)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and public.is_member(p_row.space_id)
    and (p_row.set_by = auth.uid()
         or auth.uid() = any (p_row.recipients)
         or public.member_pass(p_row.space_id) = 'lead'
         or exists (select 1 from public.space_posts p
                    left join public.work_items w on w.id = p.id
                    where p.id = p_row.post_id
                      and (p.author_id = auth.uid() or w.owner_id = auth.uid())));
$$;

-- The same rule in place (review 108 V9: the function is not the app's to
-- call; post_work_reminders uses it as the definer).
create policy work_item_reminders_read on public.work_item_reminders
  for select to authenticated
  using (auth.uid() is not null and public.is_member(space_id)
         and (set_by = auth.uid()
              or auth.uid() = any (recipients)
              or public.member_pass(space_id) = 'lead'
              or exists (select 1 from public.space_posts p
                         left join public.work_items w on w.id = p.id
                         where p.id = work_item_reminders.post_id
                           and (p.author_id = auth.uid() or w.owner_id = auth.uid()))));

revoke all on public.work_item_reminders from public, anon, authenticated;
revoke all on public.work_item_reminder_sends from public, anon, authenticated;
grant select on public.work_item_reminders to authenticated;
grant all on public.work_item_reminders to service_role;
grant all on public.work_item_reminder_sends to service_role;

-- RM1: [p_recipients] are reminded about the work item [p_post] at
-- [p_at], with an optional [p_note]. The item's creator, its owner or a
-- Lead; an Open, live item; people who are members and can see it; at
-- most 5 waiting on the item (counted with the item locked), and at most
-- 20 set by one person in a day. The same [p_id] again is the same
-- reminder.
create or replace function public.set_work_reminder(
  p_id uuid,
  p_post uuid,
  p_recipients uuid[],
  p_at timestamptz,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_owner uuid;
  v_status text;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_people uuid[];
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if exists (select 1 from public.work_item_reminders where id = p_id) then
    return p_id;
  end if;
  -- Locked, so two at once can't both be the fifth.
  select * into v_post from public.space_posts where id = p_post for update;
  if v_post.id is null or v_post.kind <> 'work_item' or v_post.status <> 'live'
     or v_post.deleted_at is not null or not public.is_member(v_post.space_id)
     or not public.can_see_space_post(p_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select w.owner_id, w.status into v_owner, v_status from public.work_items w where w.id = p_post;
  if not (v_post.author_id = v_me or v_owner = v_me
          or public.member_pass(v_post.space_id) = 'lead') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_status is distinct from 'open' then
    raise exception 'only an open work item' using errcode = '22023';
  end if;
  v_people := array(select distinct r from unnest(coalesce(p_recipients, '{}')) r where r is not null);
  if cardinality(v_people) not between 1 and 20 then
    raise exception 'one to 20 people' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(v_people) r
             where not exists (select 1 from public.space_members m
                               where m.space_id = v_post.space_id and m.profile_id = r
                                 and m.left_at is null)
                or not public.can_see_space_post_as(p_post, r)) then
    raise exception 'only people in the Space who can see it' using errcode = '22023';
  end if;
  if p_at is null or p_at <= now() or p_at > now() + interval '1 year' then
    raise exception 'a time to come' using errcode = '22023';
  end if;
  if length(v_note) > 140 then
    raise exception 'a note of up to 140 characters' using errcode = '22023';
  end if;
  if (select count(*) from public.work_item_reminders
      where set_by = v_me and created_at > now() - interval '1 day') >= 20 then
    raise exception 'the most reminders for today' using errcode = '54000';
  end if;
  if (select count(*) from public.work_item_reminders
      where post_id = p_post and sent_at is null) >= 5 then
    raise exception 'at most 5 reminders wait on an item' using errcode = '22023';
  end if;
  insert into public.work_item_reminders (id, post_id, space_id, set_by, remind_at, note, recipients)
  values (p_id, p_post, v_post.space_id, v_me, p_at, v_note, v_people);
  return p_id;
end;
$$;

-- RM2: its setter, the item's creator or a Lead takes it off.
create or replace function public.remove_work_reminder(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.work_item_reminders;
begin
  select * into v_row from public.work_item_reminders where id = p_id;
  if v_row.id is null or not public.is_member(v_row.space_id)
     or not (v_row.set_by = auth.uid()
             or public.member_pass(v_row.space_id) = 'lead'
             or exists (select 1 from public.space_posts p
                        where p.id = v_row.post_id and p.author_id = auth.uid())) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from public.work_item_reminders where id = p_id;
end;
$$;

-- RM2: the opened item's "Reminders" line: the ones still waiting that the
-- caller may read, with each person's name, and whether the caller may
-- take it off.
create or replace function public.post_work_reminders(p_post uuid)
returns table (id uuid, set_by uuid, set_by_name text, remind_at timestamptz, note text,
               recipients jsonb, can_remove boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.set_by, public.space_person_name(r.set_by), r.remind_at, r.note,
         (select jsonb_agg(jsonb_build_object('id', x.p, 'name', public.space_person_name(x.p))
                           order by x.n)
          from unnest(r.recipients) with ordinality x(p, n)),
         r.set_by = auth.uid()
           or public.member_pass(r.space_id) = 'lead'
           or exists (select 1 from public.space_posts p
                      where p.id = r.post_id and p.author_id = auth.uid())
  from public.work_item_reminders r
  where r.post_id = p_post and r.sent_at is null
    and public.can_read_work_reminder(r)
  order by r.remind_at, r.id;
$$;

-- Cron, every 5 minutes: the reminders due. One push per person, only
-- while the item is Open and live, the person is still in the Space and
-- can see it, and its setter is still in the Space and still its creator,
-- its owner or a Lead; each reminder is then marked, sent or not. Ids for the
-- link, the item's due time and the Space's time zone; the title and the
-- note only for whoever turned lock-screen text on. Returns the pushes
-- queued.
create or replace function public.due_work_reminders()
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
    select r.id from public.work_item_reminders r
    where r.sent_at is null and r.remind_at <= now()
    for update skip locked
  ),
  marked as (
    update public.work_item_reminders r set sent_at = now()
    from due where r.id = due.id
    returning r.id, r.post_id, r.space_id, r.set_by, r.recipients
  ),
  ready as (
    select m.id, x.profile_id, m.post_id
    from marked m
    cross join lateral unnest(m.recipients) x(profile_id)
    join public.space_posts p on p.id = m.post_id and p.status = 'live' and p.deleted_at is null
    join public.work_items w on w.id = m.post_id and w.status = 'open'
    join public.spaces s on s.id = m.space_id and s.deleted_at is null
    join public.space_members setter on setter.space_id = m.space_id
      and setter.profile_id = m.set_by and setter.left_at is null
      and (setter.pass = 'lead' or p.author_id = m.set_by or w.owner_id = m.set_by)
    where exists (select 1 from public.space_members sm
                  where sm.space_id = m.space_id and sm.profile_id = x.profile_id
                    and sm.left_at is null)
      and public.can_see_space_post_as(m.post_id, x.profile_id)
  ),
  fresh as (
    insert into public.work_item_reminder_sends (reminder_id, profile_id)
    select id, profile_id from ready
    on conflict do nothing
    returning reminder_id, profile_id
  )
  insert into public.push_queue (profile_id, kind, actor_id, data, message_text)
  select f.profile_id, 'work_reminder', r.set_by,
         jsonb_strip_nulls(jsonb_build_object(
           'space_id', r.space_id, 'space_post_id', r.post_id, 'due_at', p.due_at,
           'tz', (select mk.time_zone from public.spaces s
                  join public.projects pr on pr.id = s.project_id
                  join public.markets mk on mk.id = pr.market_id
                  where s.id = r.space_id))),
         case when coalesce(ps.message_text, false)
              then left(p.title || coalesce(' · ' || r.note, ''), 200) end
  from fresh f
  join public.work_item_reminders r on r.id = f.reminder_id
  join public.space_posts p on p.id = r.post_id
  left join public.push_settings ps on ps.profile_id = f.profile_id
  where exists (select 1 from public.push_tokens t where t.profile_id = f.profile_id);
  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Post later
-- ---------------------------------------------------------------------------

create table public.scheduled_posts (
  -- The id of the post it makes, so the app's own retries are one.
  id uuid primary key,
  author_id uuid not null references public.profiles (id) on delete cascade,
  -- The create call, and its arguments by name.
  fn text not null check (fn in ('create_space_post', 'create_work_item', 'create_post',
                                 'share_note_to_feed', 'share_note_to_space')),
  params jsonb not null check (jsonb_typeof(params) = 'object'
                               and octet_length(params::text) <= 200000),
  -- The Space it goes to; none for the Feed.
  space_id uuid references public.spaces (id) on delete cascade,
  -- What Scheduled shows.
  title text not null check (length(trim(title)) between 1 and 200),
  publish_at timestamptz not null,
  state text not null default 'waiting'
    check (state in ('waiting', 'posted', 'failed', 'cancelled')),
  -- Why it failed: not_allowed, not_valid or other.
  error text check (error in ('not_allowed', 'not_valid', 'other')),
  posted_at timestamptz,
  -- My notebook's note it was put in from (review 108 V8): marked once it
  -- goes.
  note_id uuid references public.notes (id) on delete set null,
  created_at timestamptz not null default now()
);
create index scheduled_posts_due_idx on public.scheduled_posts (publish_at)
  where state = 'waiting';
create index scheduled_posts_author_idx on public.scheduled_posts (author_id, publish_at);

alter table public.scheduled_posts enable row level security;

create policy scheduled_posts_own on public.scheduled_posts
  for select to authenticated
  using (author_id = auth.uid());

revoke all on public.scheduled_posts from public, anon, authenticated;
grant select on public.scheduled_posts to authenticated;
grant all on public.scheduled_posts to service_role;

-- The SQL for [p_fn]'s call with [p_params] (passed as $1): each argument
-- by name, cast to its own type from the catalogue. Null when an argument
-- isn't the function's. Each name is one exact function (review 108 V9):
-- an overload made later never takes its place. A migration that changes
-- one of these signatures changes it here too.
create or replace function public.scheduled_call_sql(p_fn text, p_params jsonb)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  with fn as (
    select to_regprocedure(case p_fn
      when 'create_space_post' then 'public.create_space_post(uuid, uuid, text, text, text, uuid, text, date, timestamptz, timestamptz, timestamptz, uuid, uuid[], jsonb, uuid, jsonb, jsonb, uuid, jsonb, timestamptz)'
      when 'create_work_item' then 'public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid, uuid, jsonb, jsonb, uuid, jsonb, jsonb, timestamptz)'
      when 'create_post' then 'public.create_post(uuid, text, text, uuid, jsonb)'
      when 'share_note_to_feed' then 'public.share_note_to_feed(uuid, uuid, text, text[], uuid, boolean, jsonb)'
      when 'share_note_to_space' then 'public.share_note_to_space(uuid, uuid, uuid, text, text[], uuid, uuid, boolean, jsonb, uuid[])'
    end) as oid
  ),
  args as (
    select a.name, format_type(a.typ, null) as typ
    from fn
    join pg_proc p on p.oid = fn.oid
    cross join lateral unnest(p.proargnames[1:p.pronargs], p.proargtypes::oid[]) a(name, typ)
  )
  select case
    when (select oid from fn) is null then null
    when exists (select 1 from jsonb_object_keys(p_params) k
                 where k not in (select name from args)) then null
    else format('select public.%I(%s)', p_fn, coalesce((
      select string_agg(format('%I => %s', a.name, case
        when a.typ like '%[]' then format(
          '(case when jsonb_typeof($1 -> %L) = ''array'' then array(select jsonb_array_elements_text($1 -> %L))::%s end)',
          a.name, a.name, a.typ)
        when a.typ in ('jsonb', 'json') then format('nullif($1 -> %L, ''null''::jsonb)', a.name)
        else format('($1 ->> %L)::%s', a.name, a.typ)
      end), ', ')
      from args a where p_params ? a.name), ''))
  end;
$$;

revoke all on function public.scheduled_call_sql(text, jsonb) from public, anon, authenticated;

-- Publishes [p_row] now, as its author: the create call, with every rule
-- checked as it is at this moment. Posted, or failed with why (and the
-- author told). Each in its own step, so one refusal never stops others.
-- The session is the author's only for the call (auth.uid() reads
-- request.jwt.claim.sub first): both settings are as they were after.
-- The row changes only from the state [p_row] was read in (waiting, or
-- failed for a retry), so a copy read before the cron posted it changes
-- nothing (review 108 V1); the author is told only when the cron's try
-- fails. A note it came from is marked as it goes (V8).
create or replace function public.publish_scheduled(p_row public.scheduled_posts)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claims text := coalesce(current_setting('request.jwt.claims', true), '');
  v_sub text := coalesce(current_setting('request.jwt.claim.sub', true), '');
  v_reason text;
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_row.author_id, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_row.author_id::text, true);
  begin
    execute public.scheduled_call_sql(p_row.fn, p_row.params) using p_row.params;
    if p_row.note_id is not null then
      begin
        perform public.mark_note_put(p_row.note_id, p_row.id);
      exception when others then
        -- Only the note's line is missed; the post went.
        null;
      end;
    end if;
  exception when others then
    v_reason := case sqlstate when '42501' then 'not_allowed' when '22023' then 'not_valid'
                              else 'other' end;
  end;
  perform set_config('request.jwt.claims', v_claims, true);
  perform set_config('request.jwt.claim.sub', v_sub, true);
  if v_reason is null then
    update public.scheduled_posts set state = 'posted', posted_at = now(), error = null
    where id = p_row.id and state = p_row.state;
    return found;
  end if;
  update public.scheduled_posts set state = 'failed', error = v_reason
  where id = p_row.id and state = p_row.state and state in ('waiting', 'failed');
  if found and p_row.state = 'waiting' then
    insert into public.push_queue (profile_id, kind, data)
    select p_row.author_id, 'scheduled_failed',
           jsonb_build_object('scheduled_id', p_row.id, 'reason', v_reason)
    where exists (select 1 from public.push_tokens t where t.profile_id = p_row.author_id);
  end if;
  return false;
end;
$$;

revoke all on function public.publish_scheduled(public.scheduled_posts) from public, anon, authenticated;

-- PL1: [p_fn] with [p_params] goes out at [p_at] as the caller's. Its id
-- is the post's own (p_id, or p_post for a notebook share). Into a Space
-- only for its members; a time to come, within a year; [p_title] is what
-- Scheduled shows; [p_note] is the caller's note it was put in from. The
-- same id again changes nothing; an id another author has is not allowed.
create or replace function public.schedule_post(
  p_id uuid,
  p_fn text,
  p_params jsonb,
  p_at timestamptz,
  p_title text,
  p_note uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_space uuid;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if exists (select 1 from public.scheduled_posts where id = p_id and author_id = v_me) then
    return p_id;
  end if;
  if exists (select 1 from public.scheduled_posts where id = p_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_note is not null and not exists (select 1 from public.notes n
                                        where n.id = p_note and n.owner_id = v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_fn is null or p_fn not in ('create_space_post', 'create_work_item', 'create_post',
                                  'share_note_to_feed', 'share_note_to_space')
     or p_params is null or jsonb_typeof(p_params) <> 'object'
     or public.scheduled_call_sql(p_fn, p_params) is null then
    raise exception 'only a post can be scheduled' using errcode = '22023';
  end if;
  if coalesce(p_params ->> case when p_fn like 'share_note_%' then 'p_post' else 'p_id' end, '')
     <> p_id::text then
    raise exception 'its id is the post''s' using errcode = '22023';
  end if;
  if p_at is null or p_at <= now() or p_at > now() + interval '1 year' then
    raise exception 'a time to come' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_title, ''))) not between 1 and 200 then
    raise exception 'what it says' using errcode = '22023';
  end if;
  v_space := nullif(p_params ->> 'p_space', '')::uuid;
  if v_space is not null and not public.is_member(v_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if (select count(*) from public.scheduled_posts
      where author_id = v_me and state = 'waiting') >= 100 then
    raise exception 'at most 100 waiting' using errcode = '22023';
  end if;
  insert into public.scheduled_posts (id, author_id, fn, params, space_id, title, publish_at, note_id)
  values (p_id, v_me, p_fn, p_params, v_space, trim(p_title), p_at, p_note);
  return p_id;
end;
$$;

-- The caller's own row in one of [p_states], locked until the change is
-- made (review 108 V1): the cron skips a locked row, and a row the cron
-- already took is read again here once it is done, in its new state.
create or replace function public.my_scheduled(p_id uuid, p_states text[])
returns public.scheduled_posts
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_row public.scheduled_posts;
begin
  select * into v_row from public.scheduled_posts where id = p_id for update;
  if v_row.id is null or v_row.author_id is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not v_row.state = any (p_states) then
    raise exception 'it is no longer waiting' using errcode = '22023';
  end if;
  return v_row;
end;
$$;

revoke all on function public.my_scheduled(uuid, text[]) from public, anon, authenticated;

-- PL2 Edit: another time.
create or replace function public.update_scheduled_post(p_id uuid, p_at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.my_scheduled(p_id, array['waiting']);
  if p_at is null or p_at <= now() or p_at > now() + interval '1 year' then
    raise exception 'a time to come' using errcode = '22023';
  end if;
  update public.scheduled_posts set publish_at = p_at where id = p_id and state = 'waiting';
end;
$$;

-- PL2 Cancel: a waiting one, or a failed one cleared (review 108 V2).
create or replace function public.cancel_scheduled_post(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.scheduled_posts := public.my_scheduled(p_id, array['waiting', 'failed']);
begin
  update public.scheduled_posts set state = 'cancelled'
  where id = p_id and state = v_row.state;
end;
$$;

-- PL2 Post now: published at once, as at its time; a failed one is tried
-- again (review 108 V2). True when posted.
create or replace function public.post_scheduled_now(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public.publish_scheduled(public.my_scheduled(p_id, array['waiting', 'failed']));
end;
$$;

-- Cron, every 5 minutes: the posts due, each as its author
-- (publish_scheduled). Returns how many were posted.
create or replace function public.publish_due_posts()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_row public.scheduled_posts;
  v_posted integer := 0;
begin
  for v_row in
    select * from public.scheduled_posts
    where state = 'waiting' and publish_at <= now()
    order by publish_at, id
    limit 200
    for update skip locked
  loop
    if public.publish_scheduled(v_row) then
      v_posted := v_posted + 1;
    end if;
  end loop;
  return v_posted;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function public.can_read_work_reminder(public.work_item_reminders) from public, anon, authenticated;
revoke all on function public.set_work_reminder(uuid, uuid, uuid[], timestamptz, text) from public, anon;
revoke all on function public.remove_work_reminder(uuid) from public, anon;
revoke all on function public.post_work_reminders(uuid) from public, anon;
revoke all on function public.due_work_reminders() from public, anon, authenticated;
revoke all on function public.schedule_post(uuid, text, jsonb, timestamptz, text, uuid) from public, anon;
revoke all on function public.update_scheduled_post(uuid, timestamptz) from public, anon;
revoke all on function public.cancel_scheduled_post(uuid) from public, anon;
revoke all on function public.post_scheduled_now(uuid) from public, anon;
revoke all on function public.publish_due_posts() from public, anon, authenticated;

grant execute on function public.set_work_reminder(uuid, uuid, uuid[], timestamptz, text) to authenticated;
grant execute on function public.remove_work_reminder(uuid) to authenticated;
grant execute on function public.post_work_reminders(uuid) to authenticated;
grant execute on function public.schedule_post(uuid, text, jsonb, timestamptz, text, uuid) to authenticated;
grant execute on function public.update_scheduled_post(uuid, timestamptz) to authenticated;
grant execute on function public.cancel_scheduled_post(uuid) to authenticated;
grant execute on function public.post_scheduled_now(uuid) to authenticated;
grant execute on function public.due_work_reminders() to service_role;
grant execute on function public.publish_due_posts() to service_role;
