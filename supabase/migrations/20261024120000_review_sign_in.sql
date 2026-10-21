-- Migration 34: the store reviewers' sign-in, made safe (review 73 B1, B2).
-- Not live.
--
-- Numbered 34, the next free number after migration 33 (the send-back
-- date). Review 71's 3D model views take the number after this one.
--
-- B1. The try counter lives in Postgres, changed atomically. Before, the
-- review-sign-in Edge Function read, changed and wrote back a counter in
-- the reviewer account's app_metadata, so tries sent at the same moment all
-- read "0 fails" and the lock never closed.
-- - review_sign_in_state: one row, RLS on, no policies and no grants, so
--   it is reached only through the two functions below.
-- - review_sign_in_try(): called BEFORE the code is compared. It locks the
--   row (for update), so tries sent together queue one behind the other.
--   It refuses while locked and after 20 tries in a UTC day; otherwise it
--   counts the try and allows the comparison. The function can't know
--   whether the code will be right, so every try counts as a fail until
--   review_sign_in_ok() clears it: five tries without an ok lock it for 15
--   minutes. Answer: {"allowed": bool, "retry_after": seconds (0 when
--   allowed)}.
-- - review_sign_in_ok(): called after a right code; clears the fails and
--   the lock. The daily count stays, so an attacker can't use the
--   reviewer's own sign-ins to reset the cap.
-- Both are for the service role only.
--
-- B2. The reviewer ("App Reviewer", app_metadata.review = true) and the two
-- demo teammates (app_metadata.demo = true) live apart from real people.
-- The seed and step 1 of docs/store/review-sign-in.md set the flags.
-- - is_demo_account(id): reads auth.users.raw_app_meta_data. Internal.
-- - demo_apart(other): true when exactly one of the signed-in person and
--   [other] is a demo account. Demo accounts still see, follow and message
--   each other; real people still see, follow and message each other.
-- Where it applies (each re-created from its latest definition, with only
-- the demo line added):
-- - profiles_read: people search and suggestions read profiles directly
--   (there is no search_people function), so a real person can't find a
--   demo account, and the reviewer isn't offered real people to follow;
-- - follows_insert_own: no follow across the line, either way;
-- - start_dm: no new DM across the line, either way;
-- - feed_page (Home), posts_tagged (a project's posts) and posts_read: a
--   demo account's posts aren't shown to real people. Both ways, so the
--   reviewer never opens a real person's profile it can't read, or replies
--   to a real person.

-- ---------------------------------------------------------------------------
-- B1: the try counter
-- ---------------------------------------------------------------------------

create table public.review_sign_in_state (
  id boolean primary key default true check (id),
  -- Tries since the last right code or the last lock.
  fails integer not null default 0 check (fails >= 0),
  locked_until timestamptz,
  -- The UTC day [day_tries] counts.
  day date not null default (now() at time zone 'utc')::date,
  day_tries integer not null default 0 check (day_tries >= 0)
);
insert into public.review_sign_in_state default values;

alter table public.review_sign_in_state enable row level security;
revoke all on public.review_sign_in_state from public, anon, authenticated, service_role;

create function public.review_sign_in_try()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v public.review_sign_in_state;
  v_now timestamptz := now();
  v_today date := (now() at time zone 'utc')::date;
begin
  -- The row lock: tries sent at the same moment wait here, one by one, and
  -- each reads what the one before it wrote.
  select * into v from public.review_sign_in_state s where s.id for update;
  if v.day is distinct from v_today then
    v.day := v_today;
    v.day_tries := 0;
  end if;
  if v.locked_until is not null and v.locked_until > v_now then
    update public.review_sign_in_state s
    set day = v.day, day_tries = v.day_tries where s.id;
    return jsonb_build_object('allowed', false, 'retry_after',
      ceil(extract(epoch from v.locked_until - v_now))::integer);
  end if;
  if v.day_tries >= 20 then
    update public.review_sign_in_state s
    set day = v.day, day_tries = v.day_tries where s.id;
    return jsonb_build_object('allowed', false, 'retry_after',
      ceil(extract(epoch from ((v_today + 1)::timestamp at time zone 'utc') - v_now))::integer);
  end if;
  -- Counted before the code is compared: a fail until ok() says otherwise.
  v.fails := v.fails + 1;
  v.day_tries := v.day_tries + 1;
  if v.fails >= 5 then
    v.fails := 0;
    v.locked_until := v_now + interval '15 minutes';
  else
    v.locked_until := null;
  end if;
  update public.review_sign_in_state s
  set fails = v.fails, locked_until = v.locked_until, day = v.day, day_tries = v.day_tries
  where s.id;
  return jsonb_build_object('allowed', true, 'retry_after', 0);
end;
$$;

create function public.review_sign_in_ok()
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.review_sign_in_state s set fails = 0, locked_until = null where s.id;
$$;

revoke execute on function public.review_sign_in_try(), public.review_sign_in_ok()
  from public, anon, authenticated;
grant execute on function public.review_sign_in_try(), public.review_sign_in_ok()
  to service_role;

-- ---------------------------------------------------------------------------
-- B2: demo and reviewer accounts live apart
-- ---------------------------------------------------------------------------

-- True when [p_id] is the store reviewer or a demo teammate.
create function public.is_demo_account(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select coalesce(u.raw_app_meta_data ->> 'demo', '') = 'true'
        or coalesce(u.raw_app_meta_data ->> 'review', '') = 'true'
    from auth.users u where u.id = p_id), false);
$$;

-- True when exactly one of the signed-in person and [p_other] is a demo
-- account. Signed out counts as a real person.
create function public.demo_apart(p_other uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_demo_account(auth.uid()) <> public.is_demo_account(p_other);
$$;

revoke execute on function public.is_demo_account(uuid) from public, anon, authenticated;
revoke execute on function public.demo_apart(uuid) from public, anon;
grant execute on function public.demo_apart(uuid) to authenticated;

-- People search and suggestions read profiles: demo accounts and real
-- people don't find each other (added: "and not demo_apart").
alter policy profiles_read on public.profiles
  using (id = auth.uid() or (not public.is_blocked_with(id) and not public.demo_apart(id)));

-- Follow: not across the line (added: "and not demo_apart").
alter policy follows_insert_own on public.follows
  with check (follower_id = auth.uid() and not public.is_blocked_with(followee_id)
              and not public.demo_apart(followee_id));

-- Posts read directly: a demo account's posts stay among demo accounts
-- (added: "and not demo_apart").
alter policy posts_read on public.posts
  using (deleted_at is null
         and (author_id = auth.uid()
              or (not public.is_blocked_with(author_id) and not public.demo_apart(author_id)))
         and not public.reported_by_me('post', id));

-- start_dm, from its latest definition (migration 22, DM): one line added,
-- "or public.demo_apart(p_to)".
create or replace function public.start_dm(p_thread uuid, p_to uuid, p_message uuid,
                                           p_body text default null,
                                           p_attachments jsonb default '[]'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_me uuid := auth.uid();
  v_a uuid := least(auth.uid(), p_to);
  v_b uuid := greatest(auth.uid(), p_to);
  v_thread public.dm_threads;
  v_link boolean;
  v_warning boolean := false;
  v_n bigint;
  v_set record;
  v_until timestamptz;
  v_state text;
begin
  if v_me is null or public.is_hidden_account(v_me) or p_to is null or p_to = v_me
     or not exists (select 1 from public.profiles p where p.id = p_to)
     or public.is_hidden_account(p_to) or public.dm_blocked(v_me, p_to)
     -- Migration 34 (review 73 B2): no DM between a demo account and a real person.
     or public.demo_apart(p_to) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  -- Both people starting at once make one thread.
  perform pg_advisory_xact_lock(hashtextextended('dm_pair:' || v_a::text || v_b::text, 0));
  select * into v_thread from public.dm_threads where a_id = v_a and b_id = v_b;
  if v_thread.id is not null then
    perform public.dm_post(p_message, v_thread.id, p_body, null, p_attachments);
    select state into v_state from public.dm_members where thread_id = v_thread.id and profile_id = p_to;
    return jsonb_build_object('thread', v_thread.id, 'state', v_state, 'warning', false);
  end if;
  if p_thread is null or exists (select 1 from public.dm_threads t where t.id = p_thread) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  v_link := public.dm_work_link(v_me, p_to);
  if not v_link then
    -- One new person at a time per sender, so two at once can't both pass.
    perform pg_advisory_xact_lock(hashtextextended('dm_start:' || v_me::text, 0));
    select * into v_set from public.dm_settings();
    v_n := public.dm_unanswered_count(v_me, v_set.days);
    if v_n >= v_set.lim then
      select t.created_at + make_interval(days => v_set.days) into v_until
      from public.dm_threads t
      join public.dm_members r on r.thread_id = t.id and r.profile_id is distinct from v_me
      where t.started_by = v_me and t.created_at > now() - make_interval(days => v_set.days)
        and r.state in ('request', 'declined')
        and not exists (select 1 from public.dm_messages m
                        where m.thread_id = t.id and m.author_id = r.profile_id)
      order by t.created_at, t.id
      offset (v_n - v_set.lim) limit 1;
      return jsonb_build_object('thread', null, 'state', 'paused', 'warning', true, 'until', v_until);
    end if;
    v_warning := v_n >= v_set.warn_at;
  end if;

  insert into public.dm_threads (id, a_id, b_id, started_by) values (p_thread, v_a, v_b, v_me);
  insert into public.dm_members (thread_id, profile_id, state)
  values (p_thread, v_me, 'open'),
         (p_thread, p_to, case when v_link then 'open' else 'request' end);
  perform public.dm_post(p_message, p_thread, p_body, null, p_attachments);
  return jsonb_build_object('thread', p_thread, 'state', case when v_link then 'open' else 'request' end,
                            'warning', v_warning);
end;
$function$;

-- feed_page (Home), from its latest definition (migration 15, safety): in
-- both sections, "and not public.demo_apart(p.author_id)" added to the
-- author line.
create or replace function public.feed_page(p_cursor jsonb default null)
returns table (section text, post_id uuid, created_at timestamptz, since timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_me uuid := auth.uid();
  v_market text := (select home_market_id from public.profiles where id = v_me);
  v_since timestamptz := coalesce((p_cursor ->> 'since')::timestamptz,
                                  now() - interval '30 days');
  v_section text := coalesce(p_cursor ->> 'section', 'home');
  v_at timestamptz := (p_cursor ->> 'created_at')::timestamptz;
  v_id uuid := (p_cursor ->> 'id')::uuid;
  v_left int := 20;
  v_n int;
begin
  if v_me is null then
    return;
  end if;
  if v_section = 'home' and v_market is not null then
    return query
      select 'home'::text, p.id, p.created_at, v_since
      from public.posts p
      where p.deleted_at is null
        and p.market_id = v_market and p.created_at > v_since
        and (v_at is null or (p.created_at, p.id) < (v_at, v_id))
        and (p.author_id = v_me
             or (not public.is_blocked_with(p.author_id) and not public.demo_apart(p.author_id)))
        and not public.reported_by_me('post', p.id)
        and not exists (select 1 from public.mutes mu
                        where mu.muter_id = v_me and mu.muted_id = p.author_id)
      order by p.created_at desc, p.id desc
      limit v_left;
    get diagnostics v_n = row_count;
    v_left := v_left - v_n;
    if v_left = 0 then
      return;
    end if;
  end if;
  if v_section = 'home' then
    -- The home section ended (or there is none): the rest from the top.
    v_at := null;
    v_id := null;
  end if;
  return query
    select 'beyond'::text, p.id, p.created_at, v_since
    from public.posts p
    where p.deleted_at is null
      and not coalesce(p.market_id = v_market and p.created_at > v_since, false)
      and (v_at is null or (p.created_at, p.id) < (v_at, v_id))
      and (p.author_id = v_me
           or (not public.is_blocked_with(p.author_id) and not public.demo_apart(p.author_id)))
      and not public.reported_by_me('post', p.id)
      and not exists (select 1 from public.mutes mu
                      where mu.muter_id = v_me and mu.muted_id = p.author_id)
    order by p.created_at desc, p.id desc
    limit v_left;
end;
$function$;

-- posts_tagged (a project's posts), from its latest definition (migration
-- 15, safety): "and not public.demo_apart(p.author_id)" added.
create or replace function public.posts_tagged(p_project uuid, p_cursor jsonb default null)
returns table (post_id uuid, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $function$
  -- The project and every project merged into it (to 5 steps), so the
  -- project index finds the posts.
  with recursive merged (id, depth) as (
    select p_project, 0
    union
    select pr.id, m.depth + 1 from public.projects pr
    join merged m on pr.merged_into = m.id
    where m.depth < 5
  )
  select p.id, p.created_at
  from public.posts p
  where p.project_id in (select id from merged)
    and public.shown_project(p_project) = p_project
    and p.deleted_at is null
    and (p.author_id = auth.uid()
         or (not public.is_blocked_with(p.author_id) and not public.demo_apart(p.author_id)))
    and not public.reported_by_me('post', p.id)
    and (p_cursor is null
         or (p.created_at, p.id) < ((p_cursor ->> 'created_at')::timestamptz,
                                    (p_cursor ->> 'id')::uuid))
  order by p.created_at desc, p.id desc
  limit 20;
$function$;
