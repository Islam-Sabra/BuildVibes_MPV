-- Migration 28: slice 2 on the cards (review 56, "Server: migration 28"),
-- with the clean-up from review 54's "Later" list. Branch slice2-db. Not live.
--
-- - post_point_events: an append-only log of ticks and un-ticks, written by
--   tick_point (checklist_points keeps only the latest state). Current ticks
--   are back-filled as 'ticked' lines. Nobody reads it directly.
-- - post_acks gains an id, so an acknowledgement in force is a history line.
--   A taken-back acknowledgement leaves the history (no log: it is a toggle,
--   not a step of the work), and never lowers last_activity_at.
-- - post_history_rows (so daybook_cards' history and post_history) gains
--   'ticked' / 'unticked' (with the point's text as it was then) and
--   'got_it', 'received', 'on_my_way', 'in_my_calendar'. The face rule of
--   migration 19 holds on the lines: Received lines for everyone who sees
--   the post; the other three only the caller's own, unless the caller acts
--   for the author (acts_for_author: the author, or an admin when the author
--   is gone).
-- - last_activity_at rises on a tick, an un-tick and a Received: a card moves
--   for what everyone who sees it can see (review 60 S1). Got it, On my way
--   and In my calendar don't move it; nor does a take-back. Back-filled. The writers
--   (tick_point, ack) lock the post first, so the trigger never takes a lock
--   out of order.
-- - Clean-up (review 54): my_spaces().last_activity_at (the newest card the
--   caller can see, read without a visibility call per hidden row);
--   activity_rows() over 30 days (my_activity keeps its cursor and page of
--   100; unread_activity reads only the unread rows); event_id in the push
--   data; daybook_page and daybook_post_json dropped; post_history gains a
--   last column, more.
-- - Download my data gains tick_log (the person's ticks and un-ticks).

-- ---------------------------------------------------------------------------
-- Ticks and un-ticks: a log
-- ---------------------------------------------------------------------------

-- One line per tick or un-tick, in the order they happened. point_text is
-- the point's words at that moment (an unticked point can be reworded or
-- removed later; the line keeps what was ticked).
create table public.post_point_events (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.space_posts (id) on delete cascade,
  point_id uuid references public.checklist_points (id) on delete set null,
  actor_id uuid references public.profiles (id) on delete set null,
  kind text not null check (kind in ('ticked', 'unticked')),
  point_text text not null,
  created_at timestamptz not null default now()
);
create index post_point_events_post_idx
  on public.post_point_events (post_id, created_at desc, id desc);

-- Kept for the record, as work_item_events and post_edits are: no update or
-- delete, except the cascade of a removed post, and the set-null of a
-- removed point or a deleted account.
create function public.keep_post_point_events()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'service_role' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE' then
    if not exists (select 1 from public.space_posts p where p.id = old.post_id) then
      return old;
    end if;
  elsif (to_jsonb(new) - 'actor_id' - 'point_id') = (to_jsonb(old) - 'actor_id' - 'point_id')
        and (new.actor_id is not distinct from old.actor_id
             or (new.actor_id is null
                 and not exists (select 1 from public.profiles p where p.id = old.actor_id)))
        and (new.point_id is not distinct from old.point_id
             or (new.point_id is null
                 and not exists (select 1 from public.checklist_points c where c.id = old.point_id))) then
    return new;
  end if;
  raise exception 'ticks are kept for the record' using errcode = '42501';
end;
$$;

create trigger post_point_events_append_only
  before update or delete on public.post_point_events
  for each row execute function public.keep_post_point_events();
create trigger post_point_events_hidden_writer before insert on public.post_point_events
  for each row execute function public.refuse_hidden_writer();

alter table public.post_point_events enable row level security;
-- No policy: read only through post_history_rows (definer).
revoke all on public.post_point_events from public, anon, authenticated;
grant all on public.post_point_events to service_role;

-- ---------------------------------------------------------------------------
-- Acknowledgements: an id for the history line
-- ---------------------------------------------------------------------------

alter table public.post_acks add column id uuid not null default gen_random_uuid();
create unique index post_acks_id_key on public.post_acks (id);
create index post_acks_post_idx on public.post_acks (post_id, created_at desc, id desc);

-- ---------------------------------------------------------------------------
-- Last activity: ticks and acknowledgements
-- ---------------------------------------------------------------------------

-- A tick, an un-tick or a Received raises its post's last activity (never
-- lowers it): lines everyone who sees the post can see (review 60 S1). The
-- writers lock the post first.
create function public.post_activity_on_mark()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.space_posts set last_activity_at = new.created_at
  where id = new.post_id and last_activity_at < new.created_at;
  return null;
end;
$$;

create trigger post_point_events_activity
  after insert on public.post_point_events
  for each row execute function public.post_activity_on_mark();

create trigger post_acks_activity
  after insert on public.post_acks
  for each row when (new.kind = 'received')
  execute function public.post_activity_on_mark();

-- Back-fill: today's ticks are 'ticked' lines at their time (the trigger
-- raises their posts), and Received acknowledgements in force raise theirs.
insert into public.post_point_events (post_id, point_id, actor_id, kind, point_text, created_at)
select c.post_id, c.id, c.ticked_by, 'ticked', c.text, c.ticked_at
from public.checklist_points c
where c.ticked_at is not null;

update public.space_posts p
set last_activity_at = a.at
from (select a.post_id, max(a.created_at) as at
      from public.post_acks a
      where a.kind = 'received'
      group by a.post_id) a
where a.post_id = p.id and p.last_activity_at < a.at;

-- Tick a point (as 20261015180000_post_kinds.sql), now also writing the
-- tick or un-tick to post_point_events. Lock order unchanged: the post, then
-- the work item, then the point.
CREATE OR REPLACE FUNCTION public.tick_point(p_point uuid, p_on boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    insert into public.post_point_events (post_id, point_id, actor_id, kind, point_text)
    values (v_post.id, p_point, v_me, 'ticked', v_point.text);
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
    insert into public.post_point_events (post_id, point_id, actor_id, kind, point_text)
    values (v_post.id, p_point, v_me, 'unticked', v_point.text);
  end if;
end;
$function$;

-- ---------------------------------------------------------------------------
-- A card's history: ticks and acknowledgements
-- ---------------------------------------------------------------------------

-- As 20261018120000_daybook_cards.sql, with two more sources:
-- - post_point_events: 'ticked' / 'unticked', with point_id and point (the
--   point's text then);
-- - post_acks in force: 'got_it', 'received', 'on_my_way', 'in_my_calendar'.
--   Received lines for everyone the caller's visibility check let in; the
--   others only the caller's own, unless the caller acts for the author.
-- Internal: the callers check that the caller may see the post. Photos are
-- looked up only for work item events.
CREATE OR REPLACE FUNCTION public.post_history_rows(p_post public.space_posts, p_before timestamptz,
                                                    p_before_id uuid, p_limit integer)
 RETURNS TABLE (id uuid, at timestamptz, event jsonb)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with picked as (
    select x.id, x.at, x.src from (
      (select e.id, e.created_at as at, 'event'::text as src
       from public.work_item_events e
       where e.work_item_id = p_post.id
         and (e.created_at, e.id) < (coalesce(p_before, 'infinity'), public.cursor_id(p_before, p_before_id))
       order by e.created_at desc, e.id desc
       limit p_limit)
      union all
      (select pe.id, pe.created_at, 'edit'::text
       from public.post_edits pe
       where pe.post_id = p_post.id
         and (pe.created_at, pe.id) < (coalesce(p_before, 'infinity'), public.cursor_id(p_before, p_before_id))
       order by pe.created_at desc, pe.id desc
       limit p_limit)
      union all
      select p_post.id, p_post.cancelled_at, 'cancel'::text
      where p_post.cancelled_at is not null
        and (p_post.cancelled_at, p_post.id)
            < (coalesce(p_before, 'infinity'), public.cursor_id(p_before, p_before_id))
      union all
      (select pp.id, pp.created_at, 'point'::text
       from public.post_point_events pp
       where pp.post_id = p_post.id
         and (pp.created_at, pp.id) < (coalesce(p_before, 'infinity'), public.cursor_id(p_before, p_before_id))
       order by pp.created_at desc, pp.id desc
       limit p_limit)
      union all
      (select a.id, a.created_at, 'ack'::text
       from public.post_acks a
       where a.post_id = p_post.id
         and (a.kind = 'received'
              or a.profile_id = auth.uid()
              -- Evaluated once, and only when another person's ack is met.
              or (select public.acts_for_author(p_post)))
         and (a.created_at, a.id) < (coalesce(p_before, 'infinity'), public.cursor_id(p_before, p_before_id))
       order by a.created_at desc, a.id desc
       limit p_limit)
    ) x
    order by x.at desc, x.id desc
    limit p_limit
  ),
  lines as (
    select k.id, k.at, k.src, e.kind, e.actor_id as by_id, e.note, e.reason,
           e.from_owner_id, e.to_owner_id, null::jsonb as changes,
           null::uuid as point_id, null::text as point
    from picked k join public.work_item_events e on e.id = k.id
    where k.src = 'event'
    union all
    select k.id, k.at, k.src, 'edited', pe.editor_id, null, null, null, null, pe.changes, null, null
    from picked k join public.post_edits pe on pe.id = k.id
    where k.src = 'edit'
    union all
    select k.id, k.at, k.src, 'cancelled', p_post.cancelled_by, p_post.cancel_note,
           null, null, null, null, null, null
    from picked k
    where k.src = 'cancel'
    union all
    select k.id, k.at, k.src, pp.kind, pp.actor_id, null, null, null, null, null,
           pp.point_id, pp.point_text
    from picked k join public.post_point_events pp on pp.id = k.id
    where k.src = 'point'
    union all
    select k.id, k.at, k.src, a.kind, a.profile_id, null, null, null, null, null, null, null
    from picked k join public.post_acks a on a.id = k.id
    where k.src = 'ack'
  ),
  people as materialized (
    select u.pid, public.space_person_name(u.pid) as name
    from (select distinct x.pid
          from lines l, unnest(array[l.by_id, l.from_owner_id, l.to_owner_id]) x(pid)
          where x.pid is not null) u
  )
  select l.id, l.at, jsonb_strip_nulls(jsonb_build_object(
           'id', l.id, 'kind', l.kind,
           'by_id', l.by_id, 'by_name', (select n.name from people n where n.pid = l.by_id),
           'note', l.note, 'reason', l.reason, 'at', l.at,
           'from_id', l.from_owner_id,
           'from_name', (select n.name from people n where n.pid = l.from_owner_id),
           'to_id', l.to_owner_id,
           'to_name', (select n.name from people n where n.pid = l.to_owner_id),
           'changes', l.changes,
           'point_id', l.point_id,
           'point', l.point,
           'photos', case when l.src = 'event' then (
                       select jsonb_agg(jsonb_build_object(
                                'path', ev.storage_path, 'taken_at', ev.taken_at,
                                'place', ev.place_text) order by ev.created_at, ev.id)
                       from public.work_item_evidence ev where ev.event_id = l.id) end))
  from lines l
  order by l.at desc, l.id desc;
$function$;

-- Older history lines for "Show earlier" (as migration 26), with a last
-- column, more: there are lines before the last one returned. Every row
-- carries the same value; an empty page has no rows.
drop function public.post_history(uuid, timestamptz, uuid, integer);
create function public.post_history(p_post uuid, p_before timestamptz default null,
                                    p_before_id uuid default null, p_limit integer default 50)
returns table (id uuid, at timestamptz, event jsonb, more boolean)
language sql
stable
security definer
set search_path = ''
as $$
  with lim as (
    select least(greatest(coalesce(p_limit, 50), 1), 100) as n
  ),
  page as (
    select h.id, h.at, h.event, row_number() over (order by h.at desc, h.id desc) as rn
    from public.space_posts p
    cross join lim
    cross join lateral public.post_history_rows(p, p_before, p_before_id, lim.n + 1) h
    where p.id = p_post and public.can_see_space_post(p.id)
  )
  select pg.id, pg.at, pg.event, (select count(*) from page) > lim.n
  from page pg cross join lim
  where pg.rn <= lim.n
  order by pg.at desc, pg.id desc;
$$;

-- ---------------------------------------------------------------------------
-- Clean-up from review 54
-- ---------------------------------------------------------------------------

-- my_spaces as 20261012150000_review11_followups.sql, with last_activity_at
-- at the end: the newest last_activity_at among the Space's posts the caller
-- can see, null with none. It is the time on the caller's newest daybook
-- card, so Home → Spaces needs no daybook_cards call per Space.
--
-- The same answer as max(last_activity_at) where can_see_space_post, but
-- without calling it on each hidden row. For an active member of a live
-- Space (my_spaces' own rows), can_see_space_post is: not deleted, and
-- Everyone (team_id null), or the caller's own post, or a Space admin (not
-- a hidden account), or the caller in that Team, or the caller owning the
-- work item. So:
-- - an admin: the newest of all posts (space_posts_activity_idx);
-- - everyone else: the greatest of the newest Everyone post, the newest
--   post of the caller's Teams, of the caller's own Team posts, and of the
--   Team work items the caller owns. Each is one short index read.
create index space_posts_everyone_activity_idx on public.space_posts
  (space_id, last_activity_at desc) where deleted_at is null and team_id is null;
create index space_posts_team_activity_idx on public.space_posts
  (team_id, last_activity_at desc) where deleted_at is null and team_id is not null;
create index space_posts_author_team_activity_idx on public.space_posts
  (author_id, space_id, last_activity_at desc) where deleted_at is null and team_id is not null;

drop function public.my_spaces();
create function public.my_spaces()
returns table (space_id uuid, name text, kind text, access text, project_id uuid,
               project_name text, project_type_id text, pass text, is_admin boolean,
               pending_requests integer, joined_at timestamptz, needs_you integer,
               last_activity_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  -- needs_you() once for all Spaces, then counted per Space.
  with needs as (
    select n.space_id, count(*)::int as n
    from public.needs_you() n
    group by n.space_id
  )
  select s.id, s.name, s.kind, s.access, s.project_id, p.name, p.type_id,
         m.pass, m.is_admin,
         case when m.is_admin then (
           select count(*)::int from public.space_join_requests r
           where r.space_id = s.id and r.status = 'pending') else 0 end,
         m.confirmed_at,
         coalesce(needs.n, 0),
         case when m.is_admin and not hidden.yes then (
           select sp.last_activity_at from public.space_posts sp
           where sp.space_id = s.id and sp.deleted_at is null
           order by sp.last_activity_at desc, sp.id desc
           limit 1)
         else greatest(
           (select sp.last_activity_at from public.space_posts sp
            where sp.space_id = s.id and sp.deleted_at is null and sp.team_id is null
            order by sp.last_activity_at desc
            limit 1),
           (select max(t.at)
            from public.team_members tm
            cross join lateral (
              select sp.last_activity_at as at from public.space_posts sp
              where sp.team_id = tm.team_id and sp.space_id = s.id
                and sp.deleted_at is null and sp.team_id is not null
              order by sp.last_activity_at desc
              limit 1) t
            where tm.profile_id = auth.uid()),
           (select sp.last_activity_at from public.space_posts sp
            where sp.author_id = auth.uid() and sp.space_id = s.id
              and sp.deleted_at is null and sp.team_id is not null
            order by sp.last_activity_at desc
            limit 1),
           (select max(sp.last_activity_at)
            from public.work_items w
            join public.space_posts sp on sp.id = w.id
            where w.owner_id = auth.uid() and w.space_id = s.id
              and sp.deleted_at is null and sp.team_id is not null))
         end
  from public.space_members m
  join public.spaces s on s.id = m.space_id
  left join public.projects p on p.id = s.project_id
  left join needs on needs.space_id = s.id
  cross join (select public.is_hidden_account(auth.uid()) as yes) hidden
  where m.profile_id = auth.uid() and m.left_at is null and s.deleted_at is null
  order by m.confirmed_at desc;
$$;

-- The red dot: is there an unread row in Activity? The same rows as
-- activity_rows (30 days, the same drop-out rules), but only the unread
-- ones are looked at, newest first, and it stops at the first.
create index notifications_unread_idx on public.notifications (profile_id, created_at desc)
  where read_at is null;

CREATE OR REPLACE FUNCTION public.unread_activity()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.notifications r
    left join public.spaces s on s.id = r.space_id
    left join public.space_members m
      on m.space_id = r.space_id and m.profile_id = auth.uid() and m.left_at is null
    left join public.post_replies pr on pr.id = r.reply_id
    left join public.cv_projects cp on cp.id = (r.payload ->> 'cv_project_id')::uuid
    where r.profile_id = auth.uid()
      and r.read_at is null
      and r.created_at >= now() - interval '30 days'
      and not public.blocked_between(auth.uid(), r.actor_id)
      -- As activity_rows' shown rows.
      and (r.space_id is null or (s.deleted_at is null and m.profile_id is not null))
      and (r.kind <> 'join_request' or m.is_admin)
      and (r.post_id is null or public.can_see_post(r.post_id))
      and (r.reply_id is null or pr.deleted_at is null)
      and (r.reply_id is null or not public.reported_by_me('reply', r.reply_id))
      and (r.kind <> 'role_confirmed' or cp.id is not null)
      and (r.work_item_id is null or public.can_see_space_post(r.work_item_id))
      and (r.space_post_id is null or public.can_see_space_post(r.space_post_id)));
$function$;

-- Download my data: the person's ticks and un-ticks (tick_log). As
-- 20261017120000_daybook_extras.sql, with that key only.
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
    'tick_log', coalesce((select jsonb_agg(jsonb_build_object(
                           'post', p.title, 'kind', t.kind, 'point', t.point_text,
                           'created_at', t.created_at) order by t.created_at, t.id)
                         from public.post_point_events t join public.space_posts p on p.id = t.post_id
                         where t.actor_id = r.profile_id), '[]'),
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


-- Activity over 30 days (F32), as 20261015180000_post_kinds.sql with the
-- window changed. my_activity(cursor) pages it, 100 rows at a time, newest
-- first; unread_activity reads the same window.
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
      and n.created_at >= now() - interval '30 days'
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

-- The push data carries event_id, the id of the history line the push is
-- about, so a push opens the card at that line (slice 10): a work item
-- event's id (payload event_id), an edit's id (payload edit_id), or for a
-- cancel the post's id (a cancel's line has the post's id). As
-- 20261016120000_post_pages.sql, with that key added.
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
      -- A batch (walk, meeting notes) sends one push per owner itself.
      when new.kind = 'item_assigned' and current_setting('bv.batch', true) = 'on' then false
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
                'space_post_id', new.space_post_id,
                'event_id', coalesce(new.payload ->> 'event_id', new.payload ->> 'edit_id',
                                     case when new.kind = 'item_cancelled'
                                          then coalesce(new.work_item_id, new.space_post_id)::text end))));
    end if;
  exception when others then
    -- A push problem never blocks the step that caused it.
    raise warning 'push queue (notification %): %', new.id, sqlerrm;
  end;
  return null;
end;
$function$;

-- No build calls daybook_page since v13 (the app reads daybook_cards);
-- daybook_post_json was only its post builder. daybook_event_json stays: the
-- card's proof uses it.
drop function public.daybook_page(uuid, timestamptz, integer, uuid);
drop function public.daybook_post_json(public.space_posts);

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.keep_post_point_events(),
  public.post_activity_on_mark(),
  public.post_history(uuid, timestamptz, uuid, integer),
  public.my_spaces()
  from public, anon;
-- Internal: trigger functions.
revoke execute on function
  public.keep_post_point_events(),
  public.post_activity_on_mark()
  from authenticated;
grant execute on function
  public.post_history(uuid, timestamptz, uuid, integer),
  public.my_spaces()
  to authenticated;
