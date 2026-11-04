-- Migration 66 (review 116): Poll («تصويت»).
--
-- 1. A new post kind, 'poll', written only by create_poll: Lead and Crew
--    (create_items, not a Viewer). Its title is the question (2–140); 2 to
--    6 options (1–60), one answer or more than one, an optional closing
--    time. For the whole Space or a Team, as any post. A new poll tells
--    everyone who can see it (poll_new, as announcement_new).
-- 2. vote_poll: anyone who can see the post, a Viewer too, while it is
--    open; the caller's choices become exactly the ones given (none takes
--    them back). One answer is one. Blocks don't matter: it is one Space.
-- 3. close_poll: its creator or a Space admin; final. The most chosen
--    option is decided; a tie waits for decide_poll (the creator or an
--    admin picks one of the tied); nobody voted closes with nothing
--    decided. The creator hears it closed (poll_closed), unless they
--    closed it themselves. close_due_polls closes those whose time has
--    passed (pg_cron every 5 minutes, scheduled by hand on live).
-- 4. edit_poll: its creator, until the first vote.
-- 5. The card (space_post_json): "poll", with each option's choices, who
--    made them (faces, never a percentage), the reader's own, and "Not
--    yet": who could answer and hasn't.

-- ---------------------------------------------------------------------------
-- 1. The kind and the tables
-- ---------------------------------------------------------------------------

alter table public.space_posts drop constraint space_posts_kind_check;
alter table public.space_posts add constraint space_posts_kind_check
  check (kind in ('note', 'work_item', 'checklist', 'announcement', 'activity', 'file', 'report',
                  'thanks', 'check_in', 'poll'));

create table public.polls (
  post_id uuid primary key references public.space_posts (id) on delete cascade,
  multi boolean not null default false,
  closes_at timestamptz,
  closed_at timestamptz,
  closed_by uuid references public.profiles (id) on delete set null,
  decided_option uuid
);

create table public.poll_options (
  id uuid primary key,
  post_id uuid not null references public.polls (post_id) on delete cascade,
  label text not null check (char_length(trim(label)) between 1 and 60),
  sort smallint not null default 0
);
create index poll_options_post_idx on public.poll_options (post_id);

alter table public.polls add constraint polls_decided_option_fkey
  foreign key (decided_option) references public.poll_options (id) on delete set null;

create table public.poll_votes (
  option_id uuid not null references public.poll_options (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (option_id, profile_id)
);
create index poll_votes_profile_idx on public.poll_votes (profile_id);

alter table public.polls enable row level security;
alter table public.poll_options enable row level security;
alter table public.poll_votes enable row level security;
create policy polls_read on public.polls
  for select to authenticated using (public.can_see_space_post(post_id));
create policy poll_options_read on public.poll_options
  for select to authenticated using (public.can_see_space_post(post_id));
create policy poll_votes_read on public.poll_votes
  for select to authenticated
  using (exists (select 1 from public.poll_options o
                 where o.id = option_id and public.can_see_space_post(o.post_id)));
revoke all on public.polls, public.poll_options, public.poll_votes from public, anon, authenticated;
grant select on public.polls, public.poll_options, public.poll_votes to authenticated;
grant all on public.polls, public.poll_options, public.poll_votes to service_role;

-- ---------------------------------------------------------------------------
-- 2. Helpers
-- ---------------------------------------------------------------------------

-- Open: not closed, and its closing time (if any) not passed.
create or replace function public.poll_is_open(p public.polls)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p.closed_at is null and (p.closes_at is null or p.closes_at > now());
$$;

-- The app's options: 2 to 6 of {"id", "label"}, ids its own and distinct,
-- each label 1 to 60 characters.
create or replace function public.poll_options_ok(p_options jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(p_options) = 'array'
     and jsonb_array_length(p_options) between 2 and 6
     and not exists (
       select 1 from jsonb_array_elements(p_options) o
       where jsonb_typeof(o -> 'id') <> 'string'
          or (o ->> 'id') !~ '^[0-9a-fA-F-]{36}$'
          or char_length(trim(coalesce(o ->> 'label', ''))) not between 1 and 60)
     and (select count(distinct o ->> 'id') from jsonb_array_elements(p_options) o)
         = jsonb_array_length(p_options);
$$;

-- Each option's choices.
create or replace function public.poll_counts(p_post uuid)
returns table (option_id uuid, n bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select o.id, count(v.profile_id)
  from public.poll_options o
  left join public.poll_votes v on v.option_id = o.id
  where o.post_id = p_post
  group by o.id;
$$;

-- The options with the most choices, when someone chose any.
create or replace function public.poll_leaders(p_post uuid)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  with c as (select * from public.poll_counts(p_post))
  select c.option_id from c
  where c.n > 0 and c.n = (select max(n) from c);
$$;

create or replace function public.poll_person_name(p_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select nullif(trim(concat_ws(' ', p.first_name, p.last_name)), '')
  from public.profiles p where p.id = p_id;
$$;

-- ---------------------------------------------------------------------------
-- 3. Making, editing and voting
-- ---------------------------------------------------------------------------

create or replace function public.create_poll(
  p_id uuid,
  p_space uuid,
  p_question text,
  p_options jsonb,
  p_multi boolean default false,
  p_closes_at timestamptz default null,
  p_team uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_question text := trim(coalesce(p_question, ''));
  v_member record;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_id is null then
    raise exception 'its id is the app''s' using errcode = '22023';
  end if;
  -- The same id again (a retry): the same poll, if it is the caller's.
  select * into v_post from public.space_posts where id = p_id;
  if v_post.id is not null then
    if v_post.author_id = v_me and v_post.space_id = p_space and v_post.kind = 'poll' then
      return v_post.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  -- Lead and Crew; a Viewer votes but doesn't make one.
  if not public.is_member(p_space) or public.is_hidden_account(v_me)
     or not public.can(p_space, 'create_items')
     or public.member_pass(p_space) = 'viewer' then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_team is not null and not public.can_post_to_team(p_space, p_team) then
    raise exception 'not allowed for this Team' using errcode = '42501';
  end if;
  if char_length(v_question) not between 2 and 140 then
    raise exception 'a question of 2 to 140 characters' using errcode = '22023';
  end if;
  if not public.poll_options_ok(p_options) then
    raise exception '2 to 6 options of 1 to 60 characters' using errcode = '22023';
  end if;
  if p_closes_at is not null and p_closes_at <= now() then
    raise exception 'it closes in the future' using errcode = '22023';
  end if;
  if exists (select 1 from public.poll_options o
             where o.id in (select (x ->> 'id')::uuid from jsonb_array_elements(p_options) x)) then
    raise exception 'this id is taken' using errcode = '22023';
  end if;

  insert into public.space_posts (id, space_id, team_id, kind, author_id, title)
  values (p_id, p_space, p_team, 'poll', v_me, v_question);
  insert into public.polls (post_id, multi, closes_at)
  values (p_id, coalesce(p_multi, false), p_closes_at);
  insert into public.poll_options (id, post_id, label, sort)
  select (x ->> 'id')::uuid, p_id, trim(x ->> 'label'), i - 1
  from jsonb_array_elements(p_options) with ordinality as u(x, i);

  -- As an announcement: everyone who can see it.
  for v_member in
    select m.profile_id from public.space_members m
    where m.space_id = p_space and m.left_at is null and m.profile_id <> v_me
      and public.can_see_space_post_as(p_id, m.profile_id)
  loop
    perform public.add_notification(v_member.profile_id, 'poll_new', v_me, p_space,
                                    p_space_post => p_id);
  end loop;
  return p_id;
end;
$$;

create or replace function public.edit_poll(
  p_post uuid,
  p_question text,
  p_options jsonb,
  p_multi boolean,
  p_closes_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_poll public.polls;
  v_question text := trim(coalesce(p_question, ''));
begin
  select * into v_post from public.space_posts where id = p_post;
  if v_me is null or v_post.id is null or v_post.kind <> 'poll' or v_post.deleted_at is not null
     or v_post.author_id <> v_me or not public.is_member(v_post.space_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_poll from public.polls where post_id = p_post;
  if not public.poll_is_open(v_poll) then
    raise exception 'the poll is closed' using errcode = '22023';
  end if;
  if exists (select 1 from public.poll_votes v join public.poll_options o on o.id = v.option_id
             where o.post_id = p_post) then
    raise exception 'not after the first vote' using errcode = '22023';
  end if;
  if char_length(v_question) not between 2 and 140 then
    raise exception 'a question of 2 to 140 characters' using errcode = '22023';
  end if;
  if not public.poll_options_ok(p_options) then
    raise exception '2 to 6 options of 1 to 60 characters' using errcode = '22023';
  end if;
  if p_closes_at is not null and p_closes_at <= now() then
    raise exception 'it closes in the future' using errcode = '22023';
  end if;
  if exists (select 1 from public.poll_options o
             where o.post_id <> p_post
               and o.id in (select (x ->> 'id')::uuid from jsonb_array_elements(p_options) x)) then
    raise exception 'this id is taken' using errcode = '22023';
  end if;

  update public.space_posts set title = v_question where id = p_post;
  update public.polls set multi = coalesce(p_multi, false), closes_at = p_closes_at
  where post_id = p_post;
  delete from public.poll_options o
  where o.post_id = p_post
    and o.id not in (select (x ->> 'id')::uuid from jsonb_array_elements(p_options) x);
  insert into public.poll_options (id, post_id, label, sort)
  select (x ->> 'id')::uuid, p_post, trim(x ->> 'label'), i - 1
  from jsonb_array_elements(p_options) with ordinality as u(x, i)
  on conflict (id) do update set label = excluded.label, sort = excluded.sort;
end;
$$;

create or replace function public.vote_poll(p_post uuid, p_options uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_poll public.polls;
  v_options uuid[] := coalesce((select array_agg(distinct o) from unnest(p_options) o), '{}');
begin
  select * into v_post from public.space_posts where id = p_post;
  if v_me is null or v_post.id is null or v_post.kind <> 'poll' or v_post.deleted_at is not null
     or not public.can_see_space_post(p_post) or public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_poll from public.polls where post_id = p_post;
  if not public.poll_is_open(v_poll) then
    raise exception 'the poll is closed' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(v_options) o
             where not exists (select 1 from public.poll_options po
                               where po.id = o and po.post_id = p_post)) then
    raise exception 'not an option of this poll' using errcode = '22023';
  end if;
  if not v_poll.multi and cardinality(v_options) > 1 then
    raise exception 'one answer' using errcode = '22023';
  end if;

  delete from public.poll_votes v
  using public.poll_options o
  where v.option_id = o.id and o.post_id = p_post and v.profile_id = v_me
    and not (v.option_id = any (v_options));
  insert into public.poll_votes (option_id, profile_id)
  select o, v_me from unnest(v_options) o
  on conflict do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Closing and deciding
-- ---------------------------------------------------------------------------

-- Closes [p_post] (by [p_by]; null is its closing time): the most chosen
-- option decided when there is one; its creator hears it, unless they
-- closed it themselves. Not the app's.
create or replace function public.poll_close(p_post uuid, p_by uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post public.space_posts;
  v_leaders uuid[];
begin
  select * into v_post from public.space_posts where id = p_post;
  v_leaders := array(select public.poll_leaders(p_post));
  update public.polls
  set closed_at = now(), closed_by = p_by,
      decided_option = case when cardinality(v_leaders) = 1 then v_leaders[1] end
  where post_id = p_post and closed_at is null;
  if not found then
    return false;
  end if;
  if p_by is distinct from v_post.author_id then
    perform public.add_notification(v_post.author_id, 'poll_closed', p_by, v_post.space_id,
                                    p_space_post => p_post);
  end if;
  return true;
end;
$$;

create or replace function public.close_poll(p_post uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
begin
  select * into v_post from public.space_posts where id = p_post;
  if v_me is null or v_post.id is null or v_post.kind <> 'poll' or v_post.deleted_at is not null
     or not public.is_member(v_post.space_id)
     or (v_post.author_id <> v_me and not public.is_space_admin(v_post.space_id)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.poll_close(p_post, v_me) then
    raise exception 'the poll is closed' using errcode = '22023';
  end if;
end;
$$;

create or replace function public.decide_poll(p_post uuid, p_option uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_poll public.polls;
  v_leaders uuid[];
begin
  select * into v_post from public.space_posts where id = p_post;
  if v_me is null or v_post.id is null or v_post.kind <> 'poll' or v_post.deleted_at is not null
     or not public.is_member(v_post.space_id)
     or (v_post.author_id <> v_me and not public.is_space_admin(v_post.space_id)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_poll from public.polls where post_id = p_post;
  v_leaders := array(select public.poll_leaders(p_post));
  if v_poll.closed_at is null or v_poll.decided_option is not null
     or cardinality(v_leaders) < 2 or not (p_option = any (v_leaders)) then
    raise exception 'only one of the tied options of a closed poll' using errcode = '22023';
  end if;
  update public.polls set decided_option = p_option where post_id = p_post;
end;
$$;

-- pg_cron, every 5 minutes (scheduled by hand on live): the polls whose
-- time has passed. How many it closed.
create or replace function public.close_due_polls()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post uuid;
  v_n integer := 0;
begin
  for v_post in
    select p.post_id from public.polls p
    where p.closed_at is null and p.closes_at is not null and p.closes_at <= now()
  loop
    if public.poll_close(v_post, null) then
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. The card
-- ---------------------------------------------------------------------------

-- [p_post]'s "poll" as the reader sees it: each option's choices and who
-- made them (newest first), the reader's own, the state, and Not yet: who
-- could answer and hasn't (two first names and how many more).
create or replace function public.poll_card(p_post public.space_posts)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with poll as (select * from public.polls where post_id = p_post.id),
  leaders as (select public.poll_leaders(p_post.id) as id),
  voters as (
    select v.profile_id from public.poll_votes v
    join public.poll_options o on o.id = v.option_id
    where o.post_id = p_post.id),
  waiting as (
    select pr.first_name, pr.last_name, pr.id
    from public.space_members m
    join public.profiles pr on pr.id = m.profile_id
    where m.space_id = p_post.space_id and m.left_at is null
      and not public.is_hidden_account(m.profile_id)
      and public.can_see_space_post_as(p_post.id, m.profile_id)
      and m.profile_id not in (select profile_id from voters))
  select jsonb_build_object(
    'multi', poll.multi,
    'closes_at', poll.closes_at,
    'closed_at', poll.closed_at,
    'closed_by_name', public.poll_person_name(poll.closed_by),
    'decided_option', poll.decided_option,
    'tied', poll.closed_at is not null and poll.decided_option is null
            and (select count(*) from leaders) > 1,
    'voted', exists (select 1 from voters),
    'options', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id,
        'label', o.label,
        'sort', o.sort,
        'count', (select count(*) from public.poll_votes v where v.option_id = o.id),
        'mine', exists (select 1 from public.poll_votes v
                        where v.option_id = o.id and v.profile_id = auth.uid()),
        'voters', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', v.profile_id,
            'name', public.poll_person_name(v.profile_id),
            'avatar', pr.photo_path) order by v.created_at desc, v.profile_id)
          from public.poll_votes v
          join public.profiles pr on pr.id = v.profile_id
          where v.option_id = o.id), '[]'::jsonb)) order by o.sort, o.id)
      from public.poll_options o where o.post_id = p_post.id), '[]'::jsonb),
    'not_yet', jsonb_build_object(
      'names', coalesce((
        select jsonb_agg(w.first_name order by w.first_name, w.id)
        from (select * from waiting order by first_name, id limit 2) w), '[]'::jsonb),
      'more', greatest((select count(*) from waiting) - 2, 0)))
  from poll;
$$;

-- space_post_json: a poll's "poll", beside a check-in's "check_in".
create function pg_temp.r116_patch(p_fn regprocedure, p_old text, p_new text)
returns void language plpgsql as $$
declare
  -- Live has CRLF in some function bodies.
  v_def text := replace(pg_get_functiondef(p_fn), chr(13), '');
begin
  if position(p_old in v_def) = 0
     or position(p_old in substr(v_def, position(p_old in v_def) + 1)) > 0 then
    raise exception 'review 116: % is not as expected', p_fn;
  end if;
  execute replace(v_def, p_old, p_new);
end;
$$;

select pg_temp.r116_patch(
  'public.space_post_json(public.space_posts, boolean)',
  $old$  || case when p_post.kind = 'check_in'
          then jsonb_build_object('check_in', public.check_in_card(p_post, now()))
          else '{}'::jsonb end$old$,
  $new$  || case when p_post.kind = 'check_in'
          then jsonb_build_object('check_in', public.check_in_card(p_post, now()))
          else '{}'::jsonb end
  -- Migration 66 (review 116): a poll's options, choices and state.
  || case when p_post.kind = 'poll'
          then jsonb_build_object('poll', public.poll_card(p_post))
          else '{}'::jsonb end$new$);

-- ---------------------------------------------------------------------------
-- 6. Notifications
-- ---------------------------------------------------------------------------

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'announcement_new', 'checklist_for_you', 'activity_invited', 'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow',
  'post_reply', 'post_useful', 'content_removed', 'appeal_decided',
  'poll_new', 'poll_closed'));

alter table public.push_queue drop constraint push_queue_kind_check;
alter table public.push_queue add constraint push_queue_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'announcement_new', 'checklist_for_you', 'activity_invited', 'activity_starting',
  'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow', 'post_reply', 'chat_message',
  'dm_message', 'dm_request', 'dm_follow_up',
  'work_reminder', 'scheduled_failed',
  'check_in_open', 'check_in_summary',
  'post_reaction', 'work_item_archived', 'check_in_nudge', 'need_you', 'need_you_answer',
  'scheduled_expiring',
  'need_you_test',
  'poll_new', 'poll_closed'));

-- A new poll pushes as an announcement does (the Space's level); its
-- creator always hears it closed.
select pg_temp.r116_patch(
  'public.handle_notification_push()',
  $old$'item_comment', 'item_edited', 'item_cancelled', 'announcement_new',$old$,
  $new$'item_comment', 'item_edited', 'item_cancelled', 'announcement_new', 'poll_new',$new$);
select pg_temp.r116_patch(
  'public.handle_notification_push()',
  $old$      when new.kind = 'join_confirmed' then true$old$,
  $new$      when new.kind = 'join_confirmed' then true
      when new.kind = 'poll_closed' then true$new$);

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function
  public.poll_is_open(public.polls),
  public.poll_options_ok(jsonb),
  public.poll_counts(uuid),
  public.poll_leaders(uuid),
  public.poll_person_name(uuid),
  public.poll_close(uuid, uuid),
  public.close_due_polls(),
  public.poll_card(public.space_posts),
  public.create_poll(uuid, uuid, text, jsonb, boolean, timestamptz, uuid),
  public.edit_poll(uuid, text, jsonb, boolean, timestamptz),
  public.vote_poll(uuid, uuid[]),
  public.close_poll(uuid),
  public.decide_poll(uuid, uuid)
  from public, anon, authenticated;
grant execute on function
  public.create_poll(uuid, uuid, text, jsonb, boolean, timestamptz, uuid),
  public.edit_poll(uuid, text, jsonb, boolean, timestamptz),
  public.vote_poll(uuid, uuid[]),
  public.close_poll(uuid),
  public.decide_poll(uuid, uuid)
  to authenticated;
grant execute on function public.close_due_polls() to service_role;
