-- Migration 33: a new date when a work item is sent back (review 50 F62;
-- review 72). Not live.
--
-- A due date belongs to whoever must act next. When the author sends an
-- item back, they choose a new date or none (the app offers Today,
-- Tomorrow, Pick a date, No new date, nothing preselected). The old date
-- is not shown again.
--
-- - work_item_events.new_due (jsonb): on a send-back that chose, the new
--   due as {"date", "at"}; {"date": null} for "no new date". Null when the
--   send-back didn't choose (builds before this one), and the due stays.
-- - send_back(item, reason, note, due_set, due, due_at): with due_set the
--   item's due becomes due / due_at (both null for no date), in the same
--   transaction as the event. Only who may check (the author, or an admin
--   acting for an author who is gone: may_check) can send back, so only
--   they set it. Earlier calls (three arguments) work as before.
-- - post_history_rows: the event line carries new_due. After strip_nulls,
--   a missing key means unchanged, {} means no new date.
--
-- Numbered 33: it is written before the 3D model views (review 71), which
-- become 34.

alter table public.work_item_events add column new_due jsonb
  check (new_due is null or (jsonb_typeof(new_due) = 'object'
                             and (new_due - 'date' - 'at') = '{}'::jsonb));
alter table public.work_item_events add constraint work_item_events_new_due_kind_check
  check (new_due is null or kind = 'sent_back');

drop function public.send_back(uuid, text, text);
create function public.send_back(p_item uuid, p_reason text, p_note text default null,
                                 p_due_set boolean default false, p_due date default null,
                                 p_due_at timestamptz default null)
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
  v_new_due jsonb;
begin
  perform 1 from public.space_posts where id = p_item for no key update;
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
  if coalesce(p_due_set, false) then
    if p_due is null and p_due_at is not null then
      raise exception 'a due time needs its day' using errcode = '22023';
    end if;
    if p_due_at is not null and not public.due_at_fits(p_due, p_due_at) then
      raise exception 'a due time on its due day' using errcode = '22023';
    end if;
    v_new_due := jsonb_build_object('date', p_due, 'at', p_due_at);
    update public.space_posts set due_date = p_due, due_at = p_due_at where id = p_item;
    update public.work_items set due_date = p_due where id = p_item;
  elsif p_due is not null or p_due_at is not null then
    raise exception 'say that a new date was chosen' using errcode = '22023';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, reason, note, new_due)
  values (p_item, v_me, 'sent_back', v_reason, nullif(trim(p_note), ''), v_new_due);
  update public.work_items set status = 'open', done_at = null where id = p_item;
end;
$$;

-- As 20261019180000_slice2_cards.sql, with one more field on a line:
-- new_due (a send-back's new date).
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
           null::uuid as point_id, null::text as point, e.new_due
    from picked k join public.work_item_events e on e.id = k.id
    where k.src = 'event'
    union all
    select k.id, k.at, k.src, 'edited', pe.editor_id, null, null, null, null, pe.changes, null, null,
           null
    from picked k join public.post_edits pe on pe.id = k.id
    where k.src = 'edit'
    union all
    select k.id, k.at, k.src, 'cancelled', p_post.cancelled_by, p_post.cancel_note,
           null, null, null, null, null, null, null
    from picked k
    where k.src = 'cancel'
    union all
    select k.id, k.at, k.src, pp.kind, pp.actor_id, null, null, null, null, null,
           pp.point_id, pp.point_text, null
    from picked k join public.post_point_events pp on pp.id = k.id
    where k.src = 'point'
    union all
    select k.id, k.at, k.src, a.kind, a.profile_id, null, null, null, null, null, null, null, null
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
           'new_due', l.new_due,
           'photos', case when l.src = 'event' then (
                       select jsonb_agg(jsonb_build_object(
                                'path', ev.storage_path, 'taken_at', ev.taken_at,
                                'place', ev.place_text) order by ev.created_at, ev.id)
                       from public.work_item_evidence ev where ev.event_id = l.id) end))
  from lines l
  order by l.at desc, l.id desc;
$function$;

revoke execute on function public.send_back(uuid, text, text, boolean, date, timestamptz)
  from public, anon;
grant execute on function public.send_back(uuid, text, text, boolean, date, timestamptz)
  to authenticated;
