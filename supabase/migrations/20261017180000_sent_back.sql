-- Migration 24: a send-back is its own daybook entry (review 47). Branch
-- sent-back-db. Not live.
--
-- - daybook_page returns 'sent_back' entries (who, reason, note, time, the
--   work item as the quote), on the same cursor as the other entries.
-- - The owner's paper clip and Sign as done go on the latest send-back while
--   the item waits to be signed again by that owner; on an item never
--   signed, given to someone else since, or whose owner left, they stay on
--   the work item slip. Never two on one item.
-- - The events index and the month's dots include send-backs.

drop index public.work_item_events_daybook_idx;
create index work_item_events_daybook_idx on public.work_item_events
  (space_id, created_at desc, id desc) where kind in ('done', 'comment', 'sent_back');

-- A post on the daybook: once an item is sent back, the owner's paper clip moves to the send-back (as in 20261017120000_daybook_extras.sql, with that change only).
CREATE OR REPLACE FUNCTION public.daybook_post_json(p_post space_posts)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select public.space_post_json(p_post, false)
    || case when w.id is null then '{}'::jsonb
            else jsonb_build_object('needs_me', coalesce(
                   public.item_needs_me(w, p_post) is distinct from 'to_check'
                   and public.item_needs_me(w, p_post) is not null
                   -- Sent back to me: my clip is on the latest send-back,
                   -- unless the item was given to someone since.
                   and not (public.item_needs_me(w, p_post) = 'open_owned'
                            and coalesce((select e.kind from public.work_item_events e
                                          where e.work_item_id = w.id
                                            and e.kind in ('sent_back', 'reassigned')
                                          order by e.created_at desc, e.id desc limit 1) = 'sent_back',
                                         false)),
                   false)) end
  from (select 1) one
  left join public.work_items w on w.id = p_post.id;
$function$;

-- A daybook entry: a send-back carries its reason and, while it is the latest, the owner's paper clip (as in 20261017120000_daybook_extras.sql, with those changes only).
CREATE OR REPLACE FUNCTION public.daybook_event_json(p_event work_item_events, p_post space_posts)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', p_event.id,
    'post_id', p_post.id,
    'space_id', p_post.space_id,
    'team_id', p_post.team_id,
    'ref', w.ref,
    'title', p_post.title,
    'post_status', p_post.status,
    'item_status', w.status,
    'actor_id', p_event.actor_id,
    'actor_name', public.space_person_name(p_event.actor_id),
    'note', p_event.note,
    'reason', p_event.reason,
    'at', p_event.created_at,
    'photos', (
      select jsonb_agg(jsonb_build_object('path', ev.storage_path, 'taken_at', ev.taken_at,
                                          'place', ev.place_text) order by ev.created_at, ev.id)
      from public.work_item_evidence ev where ev.event_id = p_event.id),
    'outcome', case when p_event.kind = 'done' then (
      select case
        when nx.kind = 'checked' then jsonb_build_object(
          'kind', 'checked', 'by_id', nx.actor_id,
          'by_name', public.space_person_name(nx.actor_id), 'at', nx.created_at)
        when nx.kind = 'sent_back' then jsonb_strip_nulls(jsonb_build_object(
          'kind', 'sent_back', 'reason', nx.reason, 'note', nx.note, 'by_id', nx.actor_id,
          'by_name', public.space_person_name(nx.actor_id), 'at', nx.created_at))
        when p_post.status = 'cancelled' then jsonb_build_object('kind', 'cancelled')
        else jsonb_build_object('kind', 'done')
      end
      from (select 1) one
      left join lateral (
        select x.kind, x.actor_id, x.reason, x.note, x.created_at
        from public.work_item_events x
        where x.work_item_id = p_event.work_item_id and x.kind in ('done', 'checked', 'sent_back')
          and (x.created_at, x.id) > (p_event.created_at, p_event.id)
        order by x.created_at, x.id
        limit 1) nx on true) end,
    'needs_me', case when p_event.kind = 'done' then
      w.status = 'done'
      and not exists (select 1 from public.work_item_events x
                      where x.work_item_id = p_event.work_item_id and x.kind = 'done'
                        and (x.created_at, x.id) > (p_event.created_at, p_event.id))
      and public.item_needs_me(w, p_post) is not distinct from 'to_check'
    -- The latest send-back, while the item waits to be signed again by the
    -- owner it was sent back to: their clip and Sign as done (never two on
    -- one item). A departed owner's clip stays on the slip, next to Give to
    -- someone else; a new owner's too.
    when p_event.kind = 'sent_back' then coalesce(
      w.status = 'open'
      and not exists (select 1 from public.work_item_events x
                      where x.work_item_id = p_event.work_item_id
                        and x.kind in ('done', 'sent_back', 'reassigned')
                        and (x.created_at, x.id) > (p_event.created_at, p_event.id))
      and public.item_needs_me(w, p_post) = 'open_owned', false) end
  ))
  from public.work_items w
  where w.id = p_post.id;
$function$;

-- The daybook: send-backs are entries too (as in 20261017120000_daybook_extras.sql, with that change only).
CREATE OR REPLACE FUNCTION public.daybook_page(p_space uuid, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 30, p_before_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(id uuid, created_at timestamp with time zone, kind text, entry jsonb)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  -- Each kind newest first from its own index, stopping at a page, then
  -- merged into one page.
  with posts as (
    select p.id, p.created_at, 'post'::text as kind, p.id as post_id, null::uuid as event_id
    from public.space_posts p
    where p.space_id = p_space and p.deleted_at is null
      and public.is_member(p_space)
      and (p_before is null
           or (p_before_id is null and p.created_at < p_before)
           or (p.created_at, p.id) < (p_before, p_before_id))
      and public.can_see_space_post(p.id)
    order by p.created_at desc, p.id desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100)
  ),
  events as (
    select e.id, e.created_at,
           case e.kind when 'done' then 'sign_off' when 'sent_back' then 'sent_back'
                       else 'update' end as kind,
           e.work_item_id as post_id, e.id as event_id
    from public.work_item_events e
    join public.space_posts p on p.id = e.work_item_id and p.deleted_at is null
    where e.space_id = p_space and e.kind in ('done', 'comment', 'sent_back')
      and public.is_member(p_space)
      and (p_before is null
           or (p_before_id is null and e.created_at < p_before)
           or (e.created_at, e.id) < (p_before, p_before_id))
      and public.can_see_space_post(p.id)
    order by e.created_at desc, e.id desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100)
  ),
  page as (
    select x.* from (select * from posts union all select * from events) x
    order by x.created_at desc, x.id desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100)
  )
  select pg.id, pg.created_at, pg.kind,
         case when pg.kind = 'post' then public.daybook_post_json(p)
              else public.daybook_event_json(e, p) end
  from page pg
  join public.space_posts p on p.id = pg.post_id
  left join public.work_item_events e on e.id = pg.event_id
  order by pg.created_at desc, pg.id desc;
$function$;

-- The month's dots: send-backs too (as in 20261017120000_daybook_extras.sql, with that change only).
CREATE OR REPLACE FUNCTION public.daybook_month(p_space uuid, p_from_day date, p_to_day date, p_from timestamp with time zone, p_to timestamp with time zone)
 RETURNS TABLE(kind text, at timestamp with time zone, day date)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  -- Posts and their sign-offs and updates in the window; each post's
  -- visibility is checked once.
  with seen as (
    select p.id as post_id, p.created_at as at
    from public.space_posts p
    where p.space_id = p_space and p.deleted_at is null
      and p.created_at >= p_from and p.created_at < p_to
    union all
    -- Sign-offs, send-backs and updates are entries too (reviews 45 and 47).
    select e.work_item_id, e.created_at
    from public.work_item_events e
    where e.space_id = p_space and e.kind in ('done', 'comment', 'sent_back')
      and e.created_at >= p_from and e.created_at < p_to
  ),
  visible as (
    select v.post_id
    from (select distinct seen.post_id from seen) v
    join public.space_posts p on p.id = v.post_id and p.deleted_at is null
    where public.can_see_space_post(v.post_id)
  )
  select distinct 'posts'::text,
         date_bin('15 minutes', seen.at, timestamptz '2000-01-01 00:00+00'), null::date
  from seen
  join visible on visible.post_id = seen.post_id
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
$function$;
