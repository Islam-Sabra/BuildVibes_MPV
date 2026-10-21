-- The pilot's four targets, for one Space (docs/product/pilot-targets.md).
-- For the founder only; the measures for every Space are in
-- pilot_measures.sql. Never shown in the app (rule 3). People are grouped
-- by pass, never named.
--
-- READ ONLY. Run the whole file in the Supabase SQL editor (service role).
-- The transaction is read only and ends in rollback.
--
-- Set the three values on the first lines:
--   pilot.space   the pilot Space's id (select id, name from public.spaces;)
--   pilot.start   the pilot's first day
--   pilot.roster  how many people the site team planned to have in the Space
-- The day, time zone and weekend are the market pack's: the Space's
-- project's market, else its creator's home market (UTC, no weekend, when
-- neither has one).

begin transaction read only;
select set_config('pilot.space', '00000000-0000-0000-0000-000000000000', true),
       set_config('pilot.start', '2027-02-01', true),
       set_config('pilot.roster', '20', true),
       set_config('pilot.tz', 'UTC', true),
       set_config('pilot.weekend', '{}', true);
select set_config('pilot.tz', coalesce(k.time_zone, 'UTC'), true),
       set_config('pilot.weekend', coalesce(k.weekend, '{}')::text, true)
from public.spaces s
left join public.projects pr on pr.id = s.project_id
left join public.profiles pf on pf.id = s.created_by
left join public.markets k on k.id = coalesce(pr.market_id, pf.home_market_id)
where s.id = current_setting('pilot.space')::uuid;

-- 1. Joining: who is in, by pass, and by the end of week 1 ------------------------------------
select m.pass,
       count(*) filter (where m.left_at is null) as in_space_now,
       count(*) filter (where (m.confirmed_at at time zone current_setting('pilot.tz'))::date < current_setting('pilot.start')::date + 7
                          and (m.left_at is null or (m.left_at at time zone current_setting('pilot.tz'))::date >= current_setting('pilot.start')::date + 7))
         as in_by_end_of_week_1,
       count(*) filter (where m.left_at is not null) as left
from public.space_members m
where m.space_id = current_setting('pilot.space')::uuid
group by rollup (m.pass)
order by m.pass nulls last;

select round(100.0 * count(*) / nullif(current_setting('pilot.roster')::int, 0)) as pct_of_roster_in_week_1,
       '>= 80' as target
from public.space_members m
where m.space_id = current_setting('pilot.space')::uuid
  and (m.confirmed_at at time zone current_setting('pilot.tz'))::date < current_setting('pilot.start')::date + 7
  and (m.left_at is null or (m.left_at at time zone current_setting('pilot.tz'))::date >= current_setting('pilot.start')::date + 7);

select r.status, count(*) as join_requests
from public.space_join_requests r
where r.space_id = current_setting('pilot.space')::uuid
group by r.status order by r.status;

-- 2. Every working day: work raised, signed as done, checked, sent back ------------------------
with days as (
  select d::date as day
  from generate_series(current_setting('pilot.start')::date,
                       least(current_setting('pilot.start')::date + 27,
                             (now() at time zone current_setting('pilot.tz'))::date),
                       interval '1 day') d
), ev as (
  select (e.created_at at time zone current_setting('pilot.tz'))::date as day, e.kind
  from public.work_item_events e
  join public.work_items w on w.id = e.work_item_id
  where w.space_id = current_setting('pilot.space')::uuid
    and e.kind in ('raised', 'done', 'checked', 'sent_back')
)
select d.day,
       1 + (d.day - current_setting('pilot.start')::date) / 7 as week,
       extract(dow from d.day)::int = any (current_setting('pilot.weekend')::smallint[]) as weekend,
       count(*) filter (where ev.kind = 'raised') as raised,
       count(*) filter (where ev.kind = 'done') as signed_done,
       count(*) filter (where ev.kind = 'checked') as checked,
       count(*) filter (where ev.kind = 'sent_back') as sent_back
from days d
left join ev on ev.day = d.day
group by d.day order by d.day;

-- Working days in weeks 2 to 4 with at least one item raised and one signed or checked (target >= 80%).
with days as (
  select d::date as day
  from generate_series(current_setting('pilot.start')::date + 7,
                       least(current_setting('pilot.start')::date + 27,
                             (now() at time zone current_setting('pilot.tz'))::date),
                       interval '1 day') d
), ev as (
  select (e.created_at at time zone current_setting('pilot.tz'))::date as day, e.kind
  from public.work_item_events e
  join public.work_items w on w.id = e.work_item_id
  where w.space_id = current_setting('pilot.space')::uuid
), per_day as (
  select d.day,
         bool_or(ev.kind = 'raised') as raised,
         bool_or(ev.kind in ('done', 'checked')) as closed
  from days d left join ev on ev.day = d.day
  where not extract(dow from d.day)::int = any (current_setting('pilot.weekend')::smallint[])
  group by d.day
)
select count(*) as working_days,
       count(*) filter (where raised and closed) as active_days,
       round(100.0 * count(*) filter (where raised and closed) / nullif(count(*), 0)) as pct,
       '>= 80' as target
from per_day;

-- Week 4 against week 1: items signed as done (target: week 4 at least half of week 1).
select 1 + ((e.created_at at time zone current_setting('pilot.tz'))::date
            - current_setting('pilot.start')::date) / 7 as week,
       count(*) as signed_done
from public.work_item_events e
join public.work_items w on w.id = e.work_item_id
where w.space_id = current_setting('pilot.space')::uuid and e.kind = 'done'
  and (e.created_at at time zone current_setting('pilot.tz'))::date >= current_setting('pilot.start')::date
group by 1 order by 1;

-- 3. The crew sign off themselves: different Crew members who signed as done with a photo -------
-- (target: 3 or more by the end of week 2; the founder also watches one do it unaided).
select m.pass,
       count(distinct e.actor_id) as people_signed_with_photo,
       count(distinct e.actor_id) filter (where (e.created_at at time zone current_setting('pilot.tz'))::date
                                                < current_setting('pilot.start')::date + 14)
         as by_end_of_week_2
from public.work_item_events e
join public.work_items w on w.id = e.work_item_id
join public.space_members m on m.space_id = w.space_id and m.profile_id = e.actor_id
where w.space_id = current_setting('pilot.space')::uuid and e.kind = 'done'
  and exists (select 1 from public.work_item_evidence x where x.event_id = e.id)
group by m.pass order by m.pass;

-- Time from signed as done to checked, in hours (a sign that Leads keep up; no target).
select percentile_cont(0.5) within group (order by extract(epoch from w.checked_at - w.done_at) / 3600)
         as median_hours_done_to_checked
from public.work_items w
where w.space_id = current_setting('pilot.space')::uuid
  and w.checked_at is not null and w.done_at is not null;

-- 4. Proof on profiles: different members showing at least one checked item (target: 3 or more by the end of week 4).
select count(distinct w.owner_id) as members_showing_proof,
       count(*) as items_shown
from public.work_items w
where w.space_id = current_setting('pilot.space')::uuid and w.shown;

rollback;
