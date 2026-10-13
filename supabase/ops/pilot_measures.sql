-- Pilot measures (review 30 §5; MVP plan §5). For the founder only: these
-- numbers are never shown in the app (product rule 3).
--
-- Read-only. Run with the service role (Supabase dashboard → SQL editor, or
-- `supabase db query --linked -f supabase/ops/pilot_measures.sql`), one query
-- at a time. No names, no text: counts only. Days are each Space's own day,
-- in its project's market time zone (UTC when it has none).

-- 1. Active Spaces: a work item, a message or a file in the last 7 days.
select count(*) as active_spaces
from public.spaces s
where s.deleted_at is null
  and (exists (select 1 from public.work_items w
               where w.space_id = s.id and w.updated_at > now() - interval '7 days')
       or exists (select 1 from public.messages m
                  where m.space_id = s.id and m.created_at > now() - interval '7 days')
       or exists (select 1 from public.library_files f
                  where f.space_id = s.id and f.created_at > now() - interval '7 days'));

-- 2. Members per Space (active members, the admins among them).
select s.id as space_id,
       count(m.profile_id) filter (where m.left_at is null) as members,
       count(m.profile_id) filter (where m.left_at is null and m.is_admin) as admins
from public.spaces s
left join public.space_members m on m.space_id = s.id
where s.deleted_at is null
group by s.id
order by members desc;

-- 3. Work items opened and checked per day, the last 14 days.
with tz as (
  select s.id as space_id,
         coalesce((select mk.time_zone from public.projects p
                   join public.markets mk on mk.id = p.market_id
                   where p.id = s.project_id), 'UTC') as zone
  from public.spaces s
),
days as (
  select (w.created_at at time zone tz.zone)::date as day, 1 as opened, 0 as checked
  from public.work_items w join tz on tz.space_id = w.space_id
  where w.created_at > now() - interval '14 days'
  union all
  select (w.checked_at at time zone tz.zone)::date, 0, 1
  from public.work_items w join tz on tz.space_id = w.space_id
  where w.checked_at > now() - interval '14 days'
)
select day, sum(opened) as opened, sum(checked) as checked
from days
group by day
order by day;

-- 4. Storage used, per bucket (the free plan includes 1 GB).
select o.bucket_id,
       count(*) as files,
       pg_size_pretty(coalesce(sum((o.metadata ->> 'size')::bigint), 0)) as size
from storage.objects o
group by o.bucket_id
order by o.bucket_id;
