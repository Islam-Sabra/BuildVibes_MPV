-- Migration 59 (review 109): Check-in («تسجيل حضور», CI1–CI5).
--
-- 1. A new post kind, 'check_in', written only by post_check_in: Leads (or
--    the Space admin) only. For Teams or the whole Space (Viewers are never
--    asked, nor the creator); a check-in time with an allowance (0, 10, 15
--    or 30 min), an optional check-out with its own, Once or Every day (the
--    market pack's working days, never typed here), and the site: the point
--    the Lead set with Set place here. One Team makes it that Team's post,
--    as any Team post; several, or none, an Everyone post whose card tells
--    each reader whether they are asked.
-- 2. The times (part 2), in the Space's time zone (its project's market;
--    with no project, the market the creator was in when posting):
--    check-in opens at the time minus the allowance and is on time up to
--    the time plus the allowance; it stays open until check-out opens, or
--    to the end of the day. Check-out opens at its time minus its allowance
--    and stays open to the end of the day. Missed: no In by the time
--    check-in closed.
-- 3. mark_check_in: the person's own In or Out. The 100 m test is done here
--    (haversine); the point it was given is never stored, logged or sent
--    on: a mark keeps the time, on time or not, and the place result only
--    (on_site, away, not_shared). An 'away' mark is replaced while its
--    window is open; any other stays.
-- 4. Who sees the marks: their own person; the post's creator; the Space
--    admin only once the creator has left the Space (or is gone). Nobody
--    else, not other Leads and not the crew. check_in_list and
--    check_in_days are for them only.
-- 5. Pushes (check_in_notify, every minute): when check-in opens, one to
--    each asked person who hasn't checked in; when check-out opens, one to
--    each who checked in and hasn't checked out; once per day per window.
--    When check-in closes, one summary to the creator (or the admins once
--    the creator has left), only when someone was late, not at the site or
--    missed it. Sent even with the Space set to Off, as activity_starting:
--    the person was asked by name (A2 "always").
-- 6. The day's report (check_in_daily_report, every 15 minutes): once a
--    day has ended in the Space's time zone, a job for the check-in-report
--    function, which writes the day's .xlsx into the Library's "Check-in
--    reports" folder for the creator only (the admin once the creator has
--    left). "Only me" (library_files.only_profile_id) is a new per-file
--    visibility, used for these reports only and kept in
--    can_read_library_file, which every Library read goes through.
-- 7. Post later takes post_check_in (Hold Send, as for every kind).
-- 8. Never proof: a check-in is no work item, so it never reaches a profile.
--
-- The clock: mark_check_in and check_in_list read now(); their twins
-- check_in_mark_at and check_in_rows take the time, and so do
-- check_in_notify and check_in_daily_report, for the tests. The twins are
-- never the app's (no execute for authenticated).

-- ---------------------------------------------------------------------------
-- 1. The kind and the tables
-- ---------------------------------------------------------------------------

alter table public.space_posts drop constraint space_posts_kind_check;
alter table public.space_posts add constraint space_posts_kind_check
  check (kind in ('note', 'work_item', 'checklist', 'announcement', 'activity', 'file', 'report',
                  'thanks', 'check_in'));

create table public.check_in_posts (
  post_id uuid primary key references public.space_posts (id) on delete cascade,
  space_id uuid not null references public.spaces (id) on delete cascade,
  -- The site, not a person: where the Lead stood when setting the place.
  site_lat double precision not null check (site_lat between -90 and 90),
  site_lng double precision not null check (site_lng between -180 and 180),
  -- The asked Teams; null is the whole Space.
  team_ids uuid[] check (team_ids is null or cardinality(team_ids) between 1 and 50),
  in_time time not null,
  in_allow_min integer not null check (in_allow_min in (0, 10, 15, 30)),
  out_time time,
  out_allow_min integer check (out_allow_min in (0, 10, 15, 30)),
  repeat text not null check (repeat in ('once', 'daily')),
  -- Its first day (once: its only day), in the Space's time zone.
  start_day date not null,
  -- The market whose time zone and working days it keeps when the Space
  -- has no project: the creator's when posting.
  market_id text references public.markets (id),
  stopped_at timestamptz,
  created_at timestamptz not null default now(),
  check ((out_time is null) = (out_allow_min is null))
);
create index check_in_posts_space_idx on public.check_in_posts (space_id);
create index check_in_posts_running_idx on public.check_in_posts (start_day)
  where stopped_at is null;

create table public.check_in_marks (
  post_id uuid not null references public.check_in_posts (post_id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  kind text not null check (kind in ('in', 'out')),
  at timestamptz not null,
  on_time boolean not null,
  place text not null check (place in ('on_site', 'away', 'not_shared')),
  primary key (post_id, user_id, day, kind)
);
create index check_in_marks_day_idx on public.check_in_marks (post_id, day);
create index check_in_marks_user_idx on public.check_in_marks (user_id);

-- What check_in_notify has sent: once per day per window.
create table public.check_in_sends (
  post_id uuid not null references public.check_in_posts (post_id) on delete cascade,
  day date not null,
  what text not null check (what in ('in', 'out', 'summary')),
  sent_at timestamptz not null default now(),
  primary key (post_id, day, what)
);

-- The day's report, a job for the check-in-report function.
create table public.check_in_reports (
  post_id uuid not null references public.check_in_posts (post_id) on delete cascade,
  day date not null,
  space_id uuid not null references public.spaces (id) on delete cascade,
  -- Who may open it: the creator, or an admin once the creator has left.
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  file_id uuid not null default gen_random_uuid() unique,
  file_name text not null check (length(trim(file_name)) between 1 and 120),
  storage_path text not null unique,
  state text not null default 'waiting' check (state in ('waiting', 'claimed', 'done', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  claimed_at timestamptz,
  done_at timestamptz,
  library_file_id uuid references public.library_files (id) on delete set null,
  error text check (length(error) <= 500),
  created_at timestamptz not null default now(),
  primary key (post_id, day)
);
create index check_in_reports_waiting_idx on public.check_in_reports (created_at)
  where state in ('waiting', 'claimed');

alter table public.check_in_posts enable row level security;
alter table public.check_in_marks enable row level security;
alter table public.check_in_sends enable row level security;
alter table public.check_in_reports enable row level security;

-- ---------------------------------------------------------------------------
-- 2. Library: "only me", and the Check-in reports folder
-- ---------------------------------------------------------------------------

alter table public.library_files
  -- Only this person opens the file (and an admin once they have left the
  -- Space). Check-in reports only.
  add column only_profile_id uuid references public.profiles (id) on delete cascade,
  -- A folder the server keeps; the app names it ("Check-in reports").
  add column folder text check (folder in ('check_in_reports'));

alter table public.library_files drop constraint library_files_source_check;
alter table public.library_files add constraint library_files_source_check
  check (source in ('upload', 'chat', 'model_view', 'check_in_report'));
alter table public.library_files add constraint library_files_only_me_check
  check (only_profile_id is null or source = 'check_in_report');
alter table public.library_files add constraint library_files_check_in_folder_check
  check ((folder is not distinct from 'check_in_reports') = (source = 'check_in_report'));

-- The spreadsheet's type, for the bucket.
update storage.buckets
set allowed_mime_types = array_append(allowed_mime_types,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
where id = 'space-files'
  and not ('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
           = any (allowed_mime_types));

-- can_read_library_file (migration 9), as it was, and only me: a check-in
-- report opens for its person, or for an admin once that person is no
-- longer in the Space. Every Library read goes through here (the table's
-- RLS, the stored file's, the cards, the list and search).
create or replace function public.can_read_library_file(p_file uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select f.deleted_at is null
       and public.is_member(f.space_id)
       and (f.team_id is null
            or public.is_space_admin(f.space_id)
            or exists (select 1 from public.team_members m
                       where m.team_id = f.team_id and m.profile_id = auth.uid()))
       and (f.source <> 'check_in_report'
            or coalesce(f.only_profile_id = auth.uid(), false)
            or ((f.only_profile_id is null
                 or not public.is_active_member(f.space_id, f.only_profile_id)
                 or public.is_hidden_account(f.only_profile_id))
                and public.is_space_admin(f.space_id)))
    from public.library_files f where f.id = p_file
  ), false);
$$;

-- ---------------------------------------------------------------------------
-- 3. The times
-- ---------------------------------------------------------------------------

-- The market a check-in keeps: its Space's project's, else the one kept
-- when it was posted.
create or replace function public.check_in_market(p_c public.check_in_posts)
returns public.markets
language sql
stable
security definer
set search_path = ''
as $$
  select m.* from public.markets m
  where m.id = coalesce((select pr.market_id from public.spaces s
                         join public.projects pr on pr.id = s.project_id
                         where s.id = p_c.space_id), p_c.market_id);
$$;

create or replace function public.check_in_zone(p_c public.check_in_posts)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((public.check_in_market(p_c)).time_zone, 'UTC');
$$;

-- [p_day] is one of its days by its schedule: on or after its first day;
-- once, that day only; every day, the market pack's working days.
create or replace function public.check_in_runs_on(p_c public.check_in_posts, p_day date)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_day >= p_c.start_day
     and case p_c.repeat
           when 'once' then p_day = p_c.start_day
           else not (extract(dow from p_day)::smallint
                     = any (coalesce((public.check_in_market(p_c)).weekend, '{}'::smallint[])))
         end;
$$;

-- It ran on [p_day]: one of its days, and not after the day it was stopped.
create or replace function public.check_in_ran_on(p_c public.check_in_posts, p_day date)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.check_in_runs_on(p_c, p_day)
     and (p_c.stopped_at is null
          or p_day <= (p_c.stopped_at at time zone public.check_in_zone(p_c))::date);
$$;

-- [p_day]'s times (part 2), in the Space's time zone.
create or replace function public.check_in_times(
  p_c public.check_in_posts, p_day date,
  out in_opens_at timestamptz, out in_until timestamptz, out in_closes_at timestamptz,
  out out_opens_at timestamptz, out out_until timestamptz, out day_ends_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_zone text := public.check_in_zone(p_c);
  v_in timestamptz := (p_day + p_c.in_time) at time zone v_zone;
  v_out timestamptz := (p_day + p_c.out_time) at time zone v_zone;
begin
  in_opens_at := v_in - make_interval(mins => p_c.in_allow_min);
  in_until := v_in + make_interval(mins => p_c.in_allow_min);
  day_ends_at := (p_day + 1)::timestamp at time zone v_zone;
  if p_c.out_time is not null then
    out_opens_at := v_out - make_interval(mins => p_c.out_allow_min);
    out_until := v_out + make_interval(mins => p_c.out_allow_min);
  end if;
  in_closes_at := coalesce(out_opens_at, day_ends_at);
end;
$$;

-- Metres between two points on the earth (haversine).
create or replace function public.check_in_distance_m(
  p_lat1 double precision, p_lng1 double precision,
  p_lat2 double precision, p_lng2 double precision)
returns double precision
language sql
immutable
security definer
set search_path = ''
as $$
  select 2 * 6371000 * asin(least(1, sqrt(
    power(sin(radians(p_lat2 - p_lat1) / 2), 2)
    + cos(radians(p_lat1)) * cos(radians(p_lat2)) * power(sin(radians(p_lng2 - p_lng1) / 2), 2))));
$$;

-- ---------------------------------------------------------------------------
-- 4. Who
-- ---------------------------------------------------------------------------

-- [p_profile] is asked: an active member who isn't a Viewer, not its
-- creator, not a hidden account, in one of its Teams (any, for the whole
-- Space).
create or replace function public.check_in_asked(p_c public.check_in_posts, p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_profile is not null
     and exists (select 1 from public.space_members m
                 join public.spaces s on s.id = m.space_id and s.deleted_at is null
                 join public.space_posts p on p.id = p_c.post_id
                 where m.space_id = p_c.space_id and m.profile_id = p_profile
                   and m.left_at is null and m.pass <> 'viewer'
                   and p.author_id is distinct from p_profile)
     and not public.is_hidden_account(p_profile)
     and (p_c.team_ids is null
          or exists (select 1 from public.team_members tm
                     join public.teams t on t.id = tm.team_id and t.space_id = p_c.space_id
                     where tm.profile_id = p_profile and tm.team_id = any (p_c.team_ids)));
$$;

-- The caller sees [p_post]'s list and marks: its creator while in the
-- Space; a Space admin once the creator has left (or is gone).
create or replace function public.check_in_sees_list(p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select auth.uid() is not null and p.deleted_at is null and (
      (p.author_id = auth.uid() and public.is_member(p.space_id)
       and not public.is_hidden_account(auth.uid()))
      or (public.is_space_admin(p.space_id)
          and (p.author_id is null
               or not public.is_active_member(p.space_id, p.author_id)
               or public.is_hidden_account(p.author_id))))
    from public.space_posts p
    join public.check_in_posts c on c.post_id = p.id
    where p.id = p_post), false);
$$;

create policy check_in_posts_read on public.check_in_posts
  for select to authenticated
  using (public.can_see_space_post(post_id));

create policy check_in_marks_read on public.check_in_marks
  for select to authenticated
  using (user_id = auth.uid() or public.check_in_sees_list(post_id));

revoke all on public.check_in_posts, public.check_in_marks, public.check_in_sends,
  public.check_in_reports from public, anon, authenticated;
-- Never the site's point: the card says only that it is set.
grant select (post_id, space_id, team_ids, in_time, in_allow_min, out_time, out_allow_min,
              repeat, start_day, stopped_at, created_at)
  on public.check_in_posts to authenticated;
grant select on public.check_in_marks to authenticated;
grant all on public.check_in_posts, public.check_in_marks, public.check_in_sends,
  public.check_in_reports to service_role;

-- ---------------------------------------------------------------------------
-- 5. Posting, marking, stopping
-- ---------------------------------------------------------------------------

-- CI1: [p_title] (and [p_body]) for [p_teams] (null: the whole Space), at
-- the site [p_site_lat], [p_site_lng]; check-in at [p_in_time] with
-- [p_in_allow] minutes; check-out at [p_out_time] with [p_out_allow]
-- (15 when not given); [p_daily]: every working day, else once. The same
-- [p_id] again is the same check-in. Its first day is today if check-in
-- hasn't closed yet today (and today is one of its days), else its next day.
create or replace function public.post_check_in(
  p_id uuid,
  p_space uuid,
  p_title text,
  p_body text default null,
  p_teams uuid[] default null,
  p_site_lat double precision default null,
  p_site_lng double precision default null,
  p_in_time time default null,
  p_in_allow integer default 15,
  p_out_time time default null,
  p_out_allow integer default null,
  p_daily boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_title text := trim(coalesce(p_title, ''));
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_teams uuid[];
  v_in_allow integer := coalesce(p_in_allow, 15);
  v_out_allow integer;
  v_c public.check_in_posts;
  v_today date;
  v_day date;
  v_in_min numeric;
  v_out_min numeric;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_id is null then
    raise exception 'its id is the app''s' using errcode = '22023';
  end if;
  -- The same id again (a retry): the same post, if it is the caller's.
  select * into v_post from public.space_posts where id = p_id;
  if v_post.id is not null then
    if v_post.author_id = v_me and v_post.space_id = p_space and v_post.kind = 'check_in' then
      return v_post.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;

  -- Leads only, or the Space admin.
  if not public.is_member(p_space) or public.is_hidden_account(v_me)
     or not (public.member_pass(p_space) = 'lead' or public.is_space_admin(p_space)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if length(v_title) not between 1 and 200 then
    raise exception 'a title of up to 200 characters' using errcode = '22023';
  end if;
  if length(v_body) > 5000 then
    raise exception 'at most 5000 characters' using errcode = '22023';
  end if;
  if p_site_lat is null or p_site_lng is null
     or p_site_lat not between -90 and 90 or p_site_lng not between -180 and 180 then
    raise exception 'set the place first' using errcode = '22023';
  end if;
  if p_in_time is null then
    raise exception 'a check-in time' using errcode = '22023';
  end if;
  if v_in_allow not in (0, 10, 15, 30) then
    raise exception 'an allowance of 0, 10, 15 or 30 minutes' using errcode = '22023';
  end if;
  if p_out_time is not null then
    v_out_allow := coalesce(p_out_allow, 15);
    if v_out_allow not in (0, 10, 15, 30) then
      raise exception 'an allowance of 0, 10, 15 or 30 minutes' using errcode = '22023';
    end if;
  end if;
  -- Its windows stay inside the day, and check-out opens after check-in's
  -- on-time limit.
  v_in_min := extract(epoch from p_in_time) / 60;
  if v_in_min - v_in_allow < 0 or v_in_min + v_in_allow >= 24 * 60 then
    raise exception 'the check-in time and its allowance fit in the day' using errcode = '22023';
  end if;
  if p_out_time is not null then
    v_out_min := extract(epoch from p_out_time) / 60;
    if v_out_min - v_out_allow <= v_in_min + v_in_allow then
      raise exception 'check-out opens after check-in''s allowance' using errcode = '22023';
    end if;
    if v_out_min + v_out_allow >= 24 * 60 then
      raise exception 'the check-out time and its allowance fit in the day' using errcode = '22023';
    end if;
  end if;

  v_teams := (select array_agg(distinct t) from unnest(p_teams) t where t is not null);
  if v_teams is not null and exists (
       select 1 from unnest(v_teams) t
       where not exists (select 1 from public.teams tm where tm.id = t and tm.space_id = p_space)) then
    raise exception 'team not in this Space' using errcode = '22023';
  end if;

  insert into public.space_posts (id, space_id, team_id, kind, author_id, title, body)
  values (p_id, p_space, case when cardinality(v_teams) = 1 then v_teams[1] end, 'check_in', v_me,
          v_title, v_body)
  returning * into v_post;

  v_c.post_id := p_id;
  v_c.space_id := p_space;
  v_c.site_lat := p_site_lat;
  v_c.site_lng := p_site_lng;
  v_c.team_ids := v_teams;
  v_c.in_time := p_in_time;
  v_c.in_allow_min := v_in_allow;
  v_c.out_time := p_out_time;
  v_c.out_allow_min := v_out_allow;
  v_c.repeat := case when coalesce(p_daily, false) then 'daily' else 'once' end;
  -- With no project, the creator's market keeps its zone and working days.
  v_c.market_id := coalesce(
    (select pr.market_id from public.spaces s join public.projects pr on pr.id = s.project_id
     where s.id = p_space),
    (select p.home_market_id from public.profiles p where p.id = v_me));
  v_today := (now() at time zone public.check_in_zone(v_c))::date;
  v_c.start_day := v_today;
  if not public.check_in_runs_on(v_c, v_today)
     or now() >= (public.check_in_times(v_c, v_today)).in_closes_at then
    v_day := v_today + 1;
    if v_c.repeat = 'daily' then
      for i in 1..14 loop
        v_c.start_day := v_day;
        exit when public.check_in_runs_on(v_c, v_day);
        v_day := v_day + 1;
      end loop;
    end if;
    v_c.start_day := v_day;
  end if;
  v_c.created_at := now();
  insert into public.check_in_posts select v_c.*;
  return p_id;
exception
  when invalid_text_representation then
    raise exception 'an id is not valid' using errcode = '22023';
end;
$$;

-- The caller's In or Out on [p_post] at [p_now]; [p_lat], [p_lng] (both or
-- neither) where the phone is, used for the 100 m test and never kept.
create or replace function public.check_in_mark_at(
  p_post uuid, p_kind text, p_lat double precision, p_lng double precision, p_now timestamptz)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_c public.check_in_posts;
  v_day date;
  v_t record;
  v_on_time boolean;
  v_place text;
  v_old public.check_in_marks;
begin
  select * into v_post from public.space_posts where id = p_post;
  -- For share: Stop running now finishes first.
  select * into v_c from public.check_in_posts where post_id = p_post for share;
  if v_me is null or v_post.id is null or v_c.post_id is null or v_post.deleted_at is not null
     or not public.can_see_space_post(p_post) or not public.check_in_asked(v_c, v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_kind is null or p_kind not in ('in', 'out') then
    raise exception 'in or out' using errcode = '22023';
  end if;
  if v_c.stopped_at is not null or v_post.status <> 'live' then
    raise exception 'stopped' using errcode = '22023';
  end if;
  v_day := (p_now at time zone public.check_in_zone(v_c))::date;
  if v_day < v_c.start_day then
    raise exception 'not open yet' using errcode = '22023';
  end if;
  if v_c.repeat = 'once' and v_day > v_c.start_day then
    raise exception 'closed' using errcode = '22023';
  end if;
  if not public.check_in_runs_on(v_c, v_day) then
    raise exception 'not a check-in day' using errcode = '22023';
  end if;
  v_t := public.check_in_times(v_c, v_day);
  if p_kind = 'in' then
    if p_now < v_t.in_opens_at then
      raise exception 'not open yet' using errcode = '22023';
    end if;
    if p_now >= v_t.in_closes_at then
      raise exception 'closed' using errcode = '22023';
    end if;
    v_on_time := p_now <= v_t.in_until;
  else
    if v_c.out_time is null then
      raise exception 'no check-out' using errcode = '22023';
    end if;
    if p_now < v_t.out_opens_at then
      raise exception 'not open yet' using errcode = '22023';
    end if;
    if p_now >= v_t.day_ends_at then
      raise exception 'closed' using errcode = '22023';
    end if;
    if not exists (select 1 from public.check_in_marks k
                   where k.post_id = p_post and k.user_id = v_me and k.day = v_day
                     and k.kind = 'in') then
      raise exception 'check in first' using errcode = '22023';
    end if;
    v_on_time := p_now <= v_t.out_until;
  end if;

  select * into v_old from public.check_in_marks k
  where k.post_id = p_post and k.user_id = v_me and k.day = v_day and k.kind = p_kind
  for update;
  if v_old.post_id is not null and v_old.place <> 'away' then
    raise exception 'already checked in' using errcode = '22023';
  end if;

  v_place := case
    when p_lat is null or p_lng is null
         or p_lat not between -90 and 90 or p_lng not between -180 and 180 then 'not_shared'
    when public.check_in_distance_m(v_c.site_lat, v_c.site_lng, p_lat, p_lng) <= 100 then 'on_site'
    else 'away'
  end;

  insert into public.check_in_marks as k (post_id, user_id, day, kind, at, on_time, place)
  values (p_post, v_me, v_day, p_kind, p_now, v_on_time, v_place)
  on conflict (post_id, user_id, day, kind) do update
    set at = excluded.at, on_time = excluded.on_time, place = excluded.place
    where k.place = 'away';
  if not found then
    raise exception 'already checked in' using errcode = '22023';
  end if;
  return jsonb_build_object('day', v_day, 'kind', p_kind, 'at', p_now, 'on_time', v_on_time,
                            'place', v_place);
end;
$$;

-- CI2–CI4: the caller's In or Out, now.
create or replace function public.mark_check_in(
  p_post uuid, p_kind text, p_lat double precision default null, p_lng double precision default null)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select public.check_in_mark_at(p_post, p_kind, p_lat, p_lng, now());
$$;

-- Stop (⋯): its creator; a Space admin once the creator has left the
-- Space (the lead, 1 Nov: otherwise it runs forever). The same people who
-- see the list (check_in_sees_list). Its earlier days stay.
create or replace function public.stop_check_in(p_post uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.check_in_sees_list(p_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.check_in_posts set stopped_at = now()
  where post_id = p_post and stopped_at is null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. The list (CI5)
-- ---------------------------------------------------------------------------

-- [p_post]'s lines for [p_day] at [p_now]: everyone asked, and anyone who
-- marked that day (so a day's list keeps who has since left), A–Z.
-- Missed: it ran that day, check-in has closed, and no In.
create or replace function public.check_in_rows(p_post uuid, p_day date, p_now timestamptz)
returns table (user_id uuid, name text, team text, in_at timestamptz, in_on_time boolean,
               in_place text, out_at timestamptz, out_on_time boolean, out_place text,
               missed boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select pe.uid,
         public.space_person_name(pe.uid),
         (select string_agg(t.name, ', ' order by t.name)
          from public.team_members tm
          join public.teams t on t.id = tm.team_id
          where tm.profile_id = pe.uid and t.space_id = c.space_id
            and (c.team_ids is null or t.id = any (c.team_ids))),
         i.at, i.on_time, i.place, o.at, o.on_time, o.place,
         i.post_id is null and public.check_in_ran_on(c, p_day)
           and p_now >= (public.check_in_times(c, p_day)).in_closes_at
  from public.check_in_posts c
  cross join lateral (
    select m.profile_id as uid from public.space_members m
    where m.space_id = c.space_id and public.check_in_asked(c, m.profile_id)
    union
    select k.user_id from public.check_in_marks k where k.post_id = c.post_id and k.day = p_day
  ) pe
  left join public.check_in_marks i
    on i.post_id = c.post_id and i.user_id = pe.uid and i.day = p_day and i.kind = 'in'
  left join public.check_in_marks o
    on o.post_id = c.post_id and o.user_id = pe.uid and o.day = p_day and o.kind = 'out'
  where c.post_id = p_post
  order by lower(coalesce(public.space_person_name(pe.uid), '')), pe.uid;
$$;

-- CI5: the day's list, for its creator (or the admin once the creator left).
create or replace function public.check_in_list(p_post uuid, p_day date)
returns table (user_id uuid, name text, team text, in_at timestamptz, in_on_time boolean,
               in_place text, out_at timestamptz, out_on_time boolean, out_place text,
               missed boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.check_in_sees_list(p_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_day is null then
    raise exception 'a day' using errcode = '22023';
  end if;
  return query select * from public.check_in_rows(p_post, p_day, now());
end;
$$;

-- CI5's day picker: the days it ran, newest first, up to today, at most 60.
create or replace function public.check_in_days(p_post uuid)
returns date[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_c public.check_in_posts;
  v_last date;
begin
  if not public.check_in_sees_list(p_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_c from public.check_in_posts where post_id = p_post;
  v_last := (now() at time zone public.check_in_zone(v_c))::date;
  if v_c.stopped_at is not null then
    v_last := least(v_last, (v_c.stopped_at at time zone public.check_in_zone(v_c))::date);
  end if;
  return array(
    select x.d from (
      select g::date as d
      from generate_series(v_last::timestamp, greatest(v_c.start_day, v_last - 400)::timestamp,
                           interval '-1 day') g) x
    where public.check_in_runs_on(v_c, x.d)
    order by x.d desc
    limit 60);
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. The card
-- ---------------------------------------------------------------------------

-- [p_post]'s "check_in" for the reader at [p_now]. "today" is today in the
-- Space's time zone when it runs today; else its next day (a once whose
-- day has passed: that day; stopped: today); "runs" is whether it runs
-- today. my_in, my_out and missed are the reader's, for that day.
create or replace function public.check_in_card(p_post public.space_posts, p_now timestamptz)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_c public.check_in_posts;
  v_stopped boolean;
  v_today date;
  v_day date;
  v_runs boolean;
  v_t record;
  v_asked boolean;
  v_in public.check_in_marks;
  v_out public.check_in_marks;
begin
  select * into v_c from public.check_in_posts where post_id = p_post.id;
  if v_c.post_id is null then
    return null;
  end if;
  v_stopped := v_c.stopped_at is not null or p_post.status <> 'live';
  v_today := (p_now at time zone public.check_in_zone(v_c))::date;
  v_runs := not v_stopped and public.check_in_runs_on(v_c, v_today);
  v_day := v_today;
  if not v_runs and not v_stopped then
    if v_c.repeat = 'once' and v_today > v_c.start_day then
      v_day := v_c.start_day;
    else
      v_day := (select g::date from generate_series(greatest(v_today + 1, v_c.start_day)::timestamp,
                                                    (greatest(v_today + 1, v_c.start_day) + 14)::timestamp,
                                                    interval '1 day') g
                where public.check_in_runs_on(v_c, g::date)
                order by g limit 1);
      v_day := coalesce(v_day, v_today);
    end if;
  end if;
  v_t := public.check_in_times(v_c, v_day);
  v_asked := public.check_in_asked(v_c, auth.uid());
  select * into v_in from public.check_in_marks k
  where k.post_id = v_c.post_id and k.user_id = auth.uid() and k.day = v_day and k.kind = 'in';
  select * into v_out from public.check_in_marks k
  where k.post_id = v_c.post_id and k.user_id = auth.uid() and k.day = v_day and k.kind = 'out';
  return jsonb_build_object(
    'in_time', to_char(v_c.in_time, 'HH24:MI'),
    'in_allow', v_c.in_allow_min,
    'out_time', to_char(v_c.out_time, 'HH24:MI'),
    'out_allow', v_c.out_allow_min,
    'daily', v_c.repeat = 'daily',
    'teams', (select jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name) order by t.name, t.id)
              from public.teams t where t.id = any (v_c.team_ids)),
    'stopped', v_stopped,
    'site_set', true,
    'sees_list', public.check_in_sees_list(v_c.post_id),
    -- Stop in ⋯: an every-day check-in not yet stopped, for whoever may
    -- stop it (stop_check_in).
    'can_stop', v_c.repeat = 'daily' and not v_stopped and public.check_in_sees_list(v_c.post_id),
    'asked', v_asked,
    'today', jsonb_build_object(
      'day', v_day,
      'runs', v_runs,
      'in_opens_at', v_t.in_opens_at,
      'in_until', v_t.in_until,
      'in_closes_at', v_t.in_closes_at,
      'out_opens_at', v_t.out_opens_at,
      'out_until', v_t.out_until,
      'day_ends_at', v_t.day_ends_at),
    'my_in', case when v_in.post_id is not null then jsonb_build_object(
      'at', v_in.at, 'on_time', v_in.on_time, 'place', v_in.place) end,
    'my_out', case when v_out.post_id is not null then jsonb_build_object(
      'at', v_out.at, 'on_time', v_out.on_time, 'place', v_out.place) end,
    'missed', v_asked and v_in.post_id is null and public.check_in_ran_on(v_c, v_day)
              and p_now >= v_t.in_closes_at);
end;
$$;

-- ---------------------------------------------------------------------------
-- space_post_json (migration 58), as it was, and a check-in's "check_in"
-- (every card reader uses it: daybook_cards, daybook_card, the opened post).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.space_post_json(p_post space_posts, p_full boolean)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  -- Migration 46: every post's own number, as its ref (NST-031).
  select jsonb_strip_nulls(jsonb_build_object('ref', p_post.ref,
    'archived_at', p_post.archived_at, 'place_id', p_post.place_id) || jsonb_build_object(
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
        'version_no', lf.version_no,
        'replaces', (select jsonb_build_object('name', o.name, 'rev_label', o.rev_label,
                                               'bytes', o.bytes, 'version_no', o.version_no)
                     from public.library_files o where o.id = lf.supersedes_id),
        -- The version in use now, when this one isn't (F76): its number, when
        -- it came, and the newest post carrying it the reader can see.
        'newer', (select jsonb_build_object(
                           'version_no', n.version_no, 'at', n.created_at,
                           'post_id', (select sp.id from public.space_posts sp
                                       where sp.library_file_id = n.id and sp.deleted_at is null
                                         and sp.status = 'live'
                                         and public.can_see_space_post(sp.id)
                                       order by sp.created_at desc limit 1))
                  from public.library_files n
                  where n.chain_id = lf.chain_id and n.version_no > lf.version_no
                    and n.deleted_at is null and public.can_read_library_file(n.id)
                  order by n.version_no desc limit 1),
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
    -- Review 110 F (HV1): the short card's quiet line, "1 table".
    'table_count', (select count(*) from jsonb_array_elements(p_post.blocks) b
                    where b ->> 'type' = 'table'),
    'template_id', p_post.template_id,
    'cover_path', (
      select f.storage_path from public.post_files f
      where f.post_id = p_post.id and f.storage_path is not null and f.mime like 'image/%'
      order by f.sort, f.created_at limit 1),
    'children', (
      select jsonb_build_object(
        'total', count(*),
        'checked', count(*) filter (where w.status = 'checked'),
        -- A target (a walk, meeting notes): its work items fold into its
        -- card (migration 37).
        'target', public.is_target(p_post.id),
        -- Up to 30 (a walk's most), each with what it needs of the reader.
        'rows', (select jsonb_agg(r.row order by r.created_at, r.id) from (
                   select c2.id, c2.created_at, jsonb_strip_nulls(jsonb_build_object(
                            'id', c2.id, 'title', c2.title, 'item_status', w2.status,
                            'ref', w2.ref,
                            'needs_me', public.card_needs_me(c2),
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
                   limit 30) r))
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
  ) || jsonb_build_object(
    -- Migration 58: a work item's tag, with its name and danger.
    'tag', (
      select public.work_tag_json(p_post.space_id, w.tag)
      from public.work_items w where w.id = p_post.id and w.tag is not null),
    -- A Thanks: to whom, for what (only a work item the reader can see),
    -- whether it is on its person's profile, and whether the reader is
    -- that person (only they see Show on my profile).
    'thanks', (
      select jsonb_build_object(
        'to_kind', th.to_kind,
        'to_profile_id', th.to_profile,
        'to_profile_name', public.space_person_name(th.to_profile),
        'to_team_id', th.to_team,
        'to_team_name', (select t.name from public.teams t where t.id = th.to_team),
        'for', (select jsonb_build_object('id', f.id, 'title', f.title, 'ref', f.ref)
                from public.space_posts f
                where f.id = th.for_post and public.can_see_space_post(f.id)),
        'show_on_profile', th.show_on_profile,
        'mine', th.to_profile is not null and th.to_profile = auth.uid())
      from public.space_thanks th where th.post_id = p_post.id)
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
    -- A report's work items and notes, as this reader may see them
    -- (migration 20; notes and kind in migration 30).
    'refs', (
      select jsonb_object_agg(c.id, jsonb_strip_nulls(jsonb_build_object(
               'kind', c.kind, 'status', c.status,
               'author_name', case when c.kind = 'note' then public.space_person_name(c.author_id) end,
               'created_at', case when c.kind = 'note' then c.created_at end,
               'photo_path', case when c.kind = 'note' then public.post_cover_path(c.id) end,
               'title', c.title, 'ref', w.ref, 'item_status', w.status,
               'owner_name', public.space_person_name(w.owner_id),
               'checked_at', w.checked_at,
               'checker_name', public.space_person_name(w.checked_by),
               'done_photo_path', public.done_photo_path(w.id))))
      from public.space_posts c
      left join public.work_items w on w.id = c.id
      where c.id::text in (select r #>> '{}' from jsonb_path_query(p_post.blocks,
                             'strict $.** ? (@.type == "item_ref").post_id') r)
        and c.space_id = p_post.space_id and c.deleted_at is null
        and c.kind in ('work_item', 'note')
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
  )) end
  -- Migration 59: a check-in's times, the reader's stamps and whether they
  -- see the list; outside jsonb_strip_nulls, since its nulls say something
  -- ("out_time": null is no check-out).
  || case when p_post.kind = 'check_in'
          then jsonb_build_object('check_in', public.check_in_card(p_post, now()))
          else '{}'::jsonb end;
$function$;

-- ---------------------------------------------------------------------------
-- 8. Pushes (every minute)
-- ---------------------------------------------------------------------------

-- Who gets [p_c]'s summary: its creator while in the Space, else every
-- active admin.
create or replace function public.check_in_owners(p_c public.check_in_posts)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.author_id from public.space_posts p
  where p.id = p_c.post_id and p.author_id is not null
    and public.is_active_member(p_c.space_id, p.author_id)
    and not public.is_hidden_account(p.author_id)
  union all
  select m.profile_id from public.space_members m
  where m.space_id = p_c.space_id and m.is_admin and m.left_at is null
    and not public.is_hidden_account(m.profile_id)
    and not exists (select 1 from public.space_posts p
                    where p.id = p_c.post_id and p.author_id is not null
                      and public.is_active_member(p_c.space_id, p.author_id)
                      and not public.is_hidden_account(p.author_id));
$$;

-- The lock-screen rule (migration 14, push_settings.message_text, off
-- unless the person turned it on): only then does a check-in push carry
-- its title, its Space and the summary's counts. Off, the push says only
-- "Time to check in" or "Check-in summary ready"; the ids stay, so its
-- actions still work.
create or replace function public.check_in_shows_text(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select ps.message_text from public.push_settings ps
                   where ps.profile_id = p_profile), false);
$$;

-- At [p_now]: the opening pushes of each window that is open, once per day
-- and window, and each summary of a check-in that closed (today or
-- yesterday, within a day), once, only when someone was late, not at the
-- site, or missed it. Returns the pushes queued.
create or replace function public.check_in_notify(p_now timestamptz default now())
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_c public.check_in_posts;
  v_post public.space_posts;
  v_space_name text;
  v_zone text;
  v_today date;
  v_day date;
  v_t record;
  v_new boolean;
  v_late integer;
  v_away integer;
  v_missed integer;
  v_rows integer;
  v_queued integer := 0;
begin
  for v_c in
    select c.* from public.check_in_posts c
    join public.space_posts p on p.id = c.post_id and p.status = 'live' and p.deleted_at is null
    join public.spaces s on s.id = c.space_id and s.deleted_at is null
    where c.stopped_at is null
      and (c.repeat = 'daily' or c.start_day >= (p_now - interval '3 days')::date)
      and c.start_day <= (p_now + interval '1 day')::date
    order by c.post_id
  loop
    select * into v_post from public.space_posts where id = v_c.post_id;
    select s.name into v_space_name from public.spaces s where s.id = v_c.space_id;
    v_zone := public.check_in_zone(v_c);
    v_today := (p_now at time zone v_zone)::date;

    if public.check_in_runs_on(v_c, v_today) then
      v_t := public.check_in_times(v_c, v_today);
      -- Check-in opens: each asked person who hasn't checked in.
      if p_now >= v_t.in_opens_at and p_now < v_t.in_closes_at then
        v_new := null;
        insert into public.check_in_sends (post_id, day, what) values (v_c.post_id, v_today, 'in')
        on conflict do nothing
        returning true into v_new;
        if v_new then
          insert into public.push_queue (profile_id, kind, data)
          select m.profile_id, 'check_in_open',
                 jsonb_build_object('post_id', v_c.post_id, 'space_id', v_c.space_id, 'mark', 'in',
                                    'until', v_t.in_until, 'tz', v_zone)
                 || case when public.check_in_shows_text(m.profile_id)
                         then jsonb_build_object('title', v_post.title, 'space_name', v_space_name)
                         else '{}'::jsonb end
          from public.space_members m
          where m.space_id = v_c.space_id and public.check_in_asked(v_c, m.profile_id)
            and not exists (select 1 from public.check_in_marks k
                            where k.post_id = v_c.post_id and k.user_id = m.profile_id
                              and k.day = v_today and k.kind = 'in')
            and exists (select 1 from public.push_tokens t where t.profile_id = m.profile_id);
          get diagnostics v_rows = row_count;
          v_queued := v_queued + v_rows;
        end if;
      end if;
      -- Check-out opens: each asked person who checked in and hasn't out.
      if v_c.out_time is not null and p_now >= v_t.out_opens_at and p_now < v_t.day_ends_at then
        v_new := null;
        insert into public.check_in_sends (post_id, day, what) values (v_c.post_id, v_today, 'out')
        on conflict do nothing
        returning true into v_new;
        if v_new then
          insert into public.push_queue (profile_id, kind, data)
          select m.profile_id, 'check_in_open',
                 jsonb_build_object('post_id', v_c.post_id, 'space_id', v_c.space_id, 'mark', 'out',
                                    'until', v_t.out_until, 'tz', v_zone)
                 || case when public.check_in_shows_text(m.profile_id)
                         then jsonb_build_object('title', v_post.title, 'space_name', v_space_name)
                         else '{}'::jsonb end
          from public.space_members m
          where m.space_id = v_c.space_id and public.check_in_asked(v_c, m.profile_id)
            and exists (select 1 from public.check_in_marks k
                        where k.post_id = v_c.post_id and k.user_id = m.profile_id
                          and k.day = v_today and k.kind = 'in')
            and not exists (select 1 from public.check_in_marks k
                            where k.post_id = v_c.post_id and k.user_id = m.profile_id
                              and k.day = v_today and k.kind = 'out')
            and exists (select 1 from public.push_tokens t where t.profile_id = m.profile_id);
          get diagnostics v_rows = row_count;
          v_queued := v_queued + v_rows;
        end if;
      end if;
    end if;

    -- The summary, once check-in has closed (yesterday's too: with no
    -- check-out it closes at midnight).
    foreach v_day in array array[v_today - 1, v_today] loop
      continue when not public.check_in_runs_on(v_c, v_day);
      v_t := public.check_in_times(v_c, v_day);
      continue when p_now < v_t.in_closes_at or p_now >= v_t.in_closes_at + interval '1 day';
      v_new := null;
      insert into public.check_in_sends (post_id, day, what) values (v_c.post_id, v_day, 'summary')
      on conflict do nothing
      returning true into v_new;
      continue when v_new is null;
      select count(*) filter (where r.in_on_time is false),
             count(*) filter (where r.in_place = 'away'),
             count(*) filter (where r.missed)
      into v_late, v_away, v_missed
      from public.check_in_rows(v_c.post_id, v_day, p_now) r;
      continue when v_late + v_away + v_missed = 0;
      insert into public.push_queue (profile_id, kind, data)
      select o.id, 'check_in_summary',
             jsonb_build_object('post_id', v_c.post_id, 'space_id', v_c.space_id)
             || case when public.check_in_shows_text(o.id)
                     then jsonb_build_object('title', v_post.title, 'late', v_late, 'away', v_away,
                                             'missed', v_missed)
                     else '{}'::jsonb end
      from public.check_in_owners(v_c) o(id)
      where exists (select 1 from public.push_tokens t where t.profile_id = o.id);
      get diagnostics v_rows = row_count;
      v_queued := v_queued + v_rows;
    end loop;
  end loop;
  return v_queued;
end;
$$;

alter table public.push_queue drop constraint push_queue_kind_check;
alter table public.push_queue add constraint push_queue_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'announcement_new', 'checklist_for_you', 'activity_invited', 'activity_starting',
  'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow', 'post_reply', 'chat_message',
  'dm_message', 'dm_request', 'dm_follow_up',
  'work_reminder', 'scheduled_failed',
  'check_in_open', 'check_in_summary'));

-- ---------------------------------------------------------------------------
-- 9. The day's report (every 15 minutes; the check-in-report function)
-- ---------------------------------------------------------------------------

-- At [p_now]: a job for each check-in whose day has ended in its Space's
-- time zone (yesterday there), once. For its creator while in the Space,
-- else the admin who joined first. Returns the jobs waiting, so cron calls
-- the function only when there is work.
create or replace function public.check_in_daily_report(p_now timestamptz default now())
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_c public.check_in_posts;
  v_post public.space_posts;
  v_day date;
  v_to uuid;
  v_file uuid;
begin
  for v_c in
    select c.* from public.check_in_posts c
    join public.space_posts p on p.id = c.post_id and p.status = 'live' and p.deleted_at is null
    join public.spaces s on s.id = c.space_id and s.deleted_at is null
    where (c.stopped_at is null or c.stopped_at >= p_now - interval '3 days')
      and (c.repeat = 'daily' or c.start_day >= (p_now - interval '3 days')::date)
      and c.start_day <= p_now::date
    order by c.post_id
  loop
    v_day := (p_now at time zone public.check_in_zone(v_c))::date - 1;
    continue when not public.check_in_ran_on(v_c, v_day)
               or p_now < (public.check_in_times(v_c, v_day)).day_ends_at;
    continue when exists (select 1 from public.check_in_reports r
                          where r.post_id = v_c.post_id and r.day = v_day);
    select * into v_post from public.space_posts where id = v_c.post_id;
    v_to := (select o.id from public.check_in_owners(v_c) o(id)
             left join public.space_members m on m.space_id = v_c.space_id and m.profile_id = o.id
             order by (o.id is not distinct from v_post.author_id) desc, m.confirmed_at, o.id
             limit 1);
    continue when v_to is null;
    v_file := gen_random_uuid();
    insert into public.check_in_reports (post_id, day, space_id, recipient_id, file_id, file_name,
                                         storage_path)
    values (v_c.post_id, v_day, v_c.space_id, v_to, v_file,
            left(regexp_replace(trim(v_post.title), '[\\/:*?"<>|]+', ' ', 'g'), 100)
              || ' ' || to_char(v_day, 'YYYY-MM-DD') || '.xlsx',
            v_c.space_id::text || '/library/' || v_file::text || '/check-in-'
              || to_char(v_day, 'YYYY-MM-DD') || '.xlsx')
    on conflict do nothing;
  end loop;
  return (select count(*)::int from public.check_in_reports r
          where r.attempts < 5
            and (r.state = 'waiting'
                 or (r.state = 'claimed' and r.claimed_at < p_now - interval '10 minutes')));
end;
$$;

-- The function takes up to [p_limit] jobs (a claim lasts 10 minutes).
create or replace function public.claim_check_in_reports(p_limit integer default 20)
returns table (post_id uuid, day date, space_id uuid, recipient_id uuid, file_id uuid,
               file_name text, storage_path text, title text, locale text, time_zone text)
language sql
volatile
security definer
set search_path = ''
as $$
  with due as (
    select r.post_id, r.day from public.check_in_reports r
    where r.attempts < 5
      and (r.state = 'waiting'
           or (r.state = 'claimed' and r.claimed_at < now() - interval '10 minutes'))
    order by r.created_at
    limit least(greatest(coalesce(p_limit, 20), 1), 100)
    for update skip locked
  ),
  claimed as (
    update public.check_in_reports r
    set state = 'claimed', claimed_at = now(), attempts = r.attempts + 1
    from due where r.post_id = due.post_id and r.day = due.day
    returning r.*
  )
  select c.post_id, c.day, c.space_id, c.recipient_id, c.file_id, c.file_name, c.storage_path,
         p.title, coalesce(pr.locale, 'en'),
         (select public.check_in_zone(ci) from public.check_in_posts ci where ci.post_id = c.post_id)
  from claimed c
  join public.space_posts p on p.id = c.post_id
  left join public.profiles pr on pr.id = c.recipient_id;
$$;

-- The report's lines for [p_day], as the spreadsheet shows them: the
-- name, the Team, In and Out in the Space's time zone, late, and the
-- place result of the In ('missed' with no In).
create or replace function public.check_in_report_rows(p_post uuid, p_day date)
returns table (name text, team text, in_time text, out_time text, in_late boolean,
               out_late boolean, place text)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(nullif(trim(coalesce(pr.first_name, '') || ' ' || coalesce(pr.last_name, '')), ''), '—'),
         r.team,
         to_char(r.in_at at time zone z.zone, 'HH24:MI'),
         to_char(r.out_at at time zone z.zone, 'HH24:MI'),
         coalesce(not r.in_on_time, false),
         coalesce(not r.out_on_time, false),
         case when r.missed then 'missed' else r.in_place end
  from public.check_in_rows(p_post, p_day, 'infinity'::timestamptz) r
  left join public.profiles pr on pr.id = r.user_id
  cross join (select public.check_in_zone(c) as zone from public.check_in_posts c
              where c.post_id = p_post) z
  order by lower(coalesce(nullif(trim(coalesce(pr.first_name, '') || ' ' || coalesce(pr.last_name, '')), ''), '')),
           r.user_id;
$$;

-- The function stored the file ([p_bytes]): it goes into the Library,
-- only for its person. With [p_error], it waits for another try (five in
-- all).
create or replace function public.finish_check_in_report(
  p_post uuid, p_day date, p_bytes bigint, p_error text default null)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_job public.check_in_reports;
begin
  select * into v_job from public.check_in_reports r
  where r.post_id = p_post and r.day = p_day for update;
  if v_job.post_id is null or v_job.state = 'done' then
    return;
  end if;
  if p_error is not null then
    update public.check_in_reports r
    set state = case when r.attempts >= 5 then 'failed' else 'waiting' end,
        error = left(p_error, 500)
    where r.post_id = p_post and r.day = p_day;
    return;
  end if;
  insert into public.library_files (id, space_id, team_id, name, storage_path, mime, bytes, source,
                                    folder, only_profile_id)
  values (v_job.file_id, v_job.space_id, null, v_job.file_name, v_job.storage_path,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', p_bytes,
          'check_in_report', 'check_in_reports', v_job.recipient_id)
  on conflict (id) do nothing;
  update public.check_in_reports r
  set state = 'done', done_at = now(), error = null, library_file_id = v_job.file_id
  where r.post_id = p_post and r.day = p_day;
end;
$$;

-- ---------------------------------------------------------------------------
-- 10. Post later takes post_check_in
-- ---------------------------------------------------------------------------

alter table public.scheduled_posts drop constraint scheduled_posts_fn_check;
alter table public.scheduled_posts add constraint scheduled_posts_fn_check
  check (fn in ('create_space_post', 'create_work_item', 'create_post',
                'share_note_to_feed', 'share_note_to_space', 'create_thanks', 'post_check_in'));

-- scheduled_call_sql (migration 58), as it was, and post_check_in.
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
      when 'create_work_item' then 'public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid, uuid, jsonb, jsonb, uuid, jsonb, jsonb, timestamptz, text)'
      when 'create_post' then 'public.create_post(uuid, text, text, uuid, jsonb)'
      when 'share_note_to_feed' then 'public.share_note_to_feed(uuid, uuid, text, text[], uuid, boolean, jsonb)'
      when 'share_note_to_space' then 'public.share_note_to_space(uuid, uuid, uuid, text, text[], uuid, uuid, boolean, jsonb, uuid[])'
      when 'create_thanks' then 'public.create_thanks(uuid, uuid, text, uuid, uuid, uuid, jsonb)'
      when 'post_check_in' then 'public.post_check_in(uuid, uuid, text, text, uuid[], double precision, double precision, time, integer, time, integer, boolean)'
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

-- schedule_post (migration 58), as it was, and post_check_in.
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
                                  'share_note_to_feed', 'share_note_to_space', 'create_thanks',
                                  'post_check_in')
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

-- ---------------------------------------------------------------------------
-- 11. My data and account deletion
-- ---------------------------------------------------------------------------

-- export_my_data (migration 48), as it was, and the person's own marks.
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
    'notebook_pages', coalesce((select jsonb_agg(jsonb_build_object(
                                 'id', np.id, 'title', np.title, 'named', np.named,
                                 'icon', np.icon,
                                 'parent_id', np.parent_id, 'pinned', np.pinned,
                                 'deleted_at', np.deleted_at,
                                 'created_at', np.created_at))
                               from public.notebook_pages np where np.owner_id = r.profile_id), '[]'),
    'notes', coalesce((select jsonb_agg(jsonb_build_object(
                        'kind', n.kind, 'title', n.title, 'body', n.body, 'points', n.points,
                        'blocks', n.blocks, 'location_text', n.location_text,
                        'location_lat', n.location_lat, 'location_lng', n.location_lng,
                        'due_at', n.due_at, 'done_at', n.done_at, 'pinned', n.pinned,
                        'remind_at', n.remind_at,
                        'page_id', n.page_id,
                        'deleted_at', n.deleted_at,
                        'archived_at', n.archived_at,
                        'created_at', n.created_at,
                        'files', (select jsonb_agg(f.storage_path order by f.sort)
                                  from public.note_files f where f.note_id = n.id)))
                      from public.notes n where n.owner_id = r.profile_id), '[]'),
    'note_shares', coalesce((select jsonb_agg(jsonb_build_object(
                              'note_id', ns.note_id, 'target', ns.target,
                              'target_name', ns.target_name,
                              'space_post_id', ns.space_post_id,
                              'feed_post_id', ns.feed_post_id,
                              'dm_thread_id', ns.dm_thread_id,
                              'created_at', ns.created_at))
                            from public.note_shares ns where ns.owner_id = r.profile_id), '[]'),
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
  ) || jsonb_build_object(
    -- Migration 59: the person's own check-in marks, never anyone else's
    -- (and never a point: none is kept).
    'check_in_marks', coalesce((select jsonb_agg(jsonb_build_object(
                                  'check_in', p.title, 'space', s.name, 'day', k.day,
                                  'kind', k.kind, 'at', k.at, 'on_time', k.on_time,
                                  'place', k.place) order by k.day, k.at)
                                from public.check_in_marks k
                                join public.space_posts p on p.id = k.post_id
                                join public.spaces s on s.id = p.space_id
                                where k.user_id = r.profile_id), '[]'))
  from public.data_requests r
  where r.id = p_request;
$function$;

-- accounts_due_for_purge (migration 22), as it was, and each account's
-- "only me" check-in reports in space-files: they go with the account (the
-- account-purge function removes every listed file, then purge_account).
create or replace function public.accounts_due_for_purge()
returns table (profile_id uuid, bucket text, name text)
language sql
stable
security definer
set search_path = ''
as $$
  with due as (
    select p.id from public.profiles p
    where p.deletion_scheduled_at < now() - interval '30 days'
  ),
  files as (
    select d.id, o.bucket_id, o.name
    from due d
    join storage.objects o
      on o.bucket_id in ('avatars', 'post-media', 'notebook-files', 'dm-files')
     and o.name collate "C" >= d.id::text || '/'
     and o.name collate "C" < d.id::text || '0'
    union all
    select d.id, o.bucket_id, o.name
    from due d
    join public.library_files f on f.only_profile_id = d.id and f.source = 'check_in_report'
    join storage.objects o on o.bucket_id = 'space-files' and o.name = f.storage_path
  )
  select d.id, f.bucket_id, f.name
  from due d
  left join files f on f.id = d.id
  order by d.id;
$$;

-- purge_account (migration 22), as it was, and it waits while an "only
-- me" check-in report of theirs is still stored; their report rows then go
-- with the account (library_files.only_profile_id cascades).
create or replace function public.purge_account(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1 from public.profiles
  where id = p_id and deletion_scheduled_at < now() - interval '30 days'
  for update;
  if not found then
    return false;
  end if;
  if exists (select 1 from storage.objects o
             where o.bucket_id in ('avatars', 'post-media', 'notebook-files', 'dm-files')
               and o.name collate "C" >= p_id::text || '/'
               and o.name collate "C" < p_id::text || '0')
     or exists (select 1 from public.library_files f
                join storage.objects o on o.bucket_id = 'space-files' and o.name = f.storage_path
                where f.only_profile_id = p_id and f.source = 'check_in_report') then
    return false;
  end if;
  -- Their files went first (their folder): their file rows go too, and a
  -- message of theirs with no words left shows as "Message deleted"; their
  -- words stay for the other person (review 42 R1).
  update public.dm_messages set deleted_at = now()
  where author_id = p_id and deleted_at is null and body is null;
  delete from public.dm_attachments a using public.dm_messages m
  where a.message_id = m.id and m.author_id = p_id;
  delete from auth.users where id = p_id;
  -- A thread whose two people are both gone goes too.
  delete from public.dm_threads where a_id is null and b_id is null;
  return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function public.check_in_market(public.check_in_posts) from public, anon, authenticated;
revoke all on function public.check_in_zone(public.check_in_posts) from public, anon, authenticated;
revoke all on function public.check_in_runs_on(public.check_in_posts, date) from public, anon, authenticated;
revoke all on function public.check_in_ran_on(public.check_in_posts, date) from public, anon, authenticated;
revoke all on function public.check_in_times(public.check_in_posts, date) from public, anon, authenticated;
revoke all on function public.check_in_distance_m(double precision, double precision, double precision, double precision)
  from public, anon, authenticated;
revoke all on function public.check_in_asked(public.check_in_posts, uuid) from public, anon, authenticated;
-- Used by the marks' RLS: callable, and it says only whether the caller
-- sees the list.
revoke all on function public.check_in_sees_list(uuid) from public, anon;
revoke all on function public.post_check_in(uuid, uuid, text, text, uuid[], double precision,
                                            double precision, time, integer, time, integer, boolean)
  from public, anon;
revoke all on function public.check_in_mark_at(uuid, text, double precision, double precision, timestamptz)
  from public, anon, authenticated;
revoke all on function public.mark_check_in(uuid, text, double precision, double precision) from public, anon;
revoke all on function public.stop_check_in(uuid) from public, anon;
revoke all on function public.check_in_rows(uuid, date, timestamptz) from public, anon, authenticated;
revoke all on function public.check_in_list(uuid, date) from public, anon;
revoke all on function public.check_in_days(uuid) from public, anon;
revoke all on function public.check_in_card(public.space_posts, timestamptz) from public, anon, authenticated;
revoke all on function public.space_post_json(public.space_posts, boolean) from public, anon, authenticated;
revoke all on function public.check_in_owners(public.check_in_posts) from public, anon, authenticated;
revoke all on function public.check_in_shows_text(uuid) from public, anon, authenticated;
revoke all on function public.export_my_data(uuid) from public, anon, authenticated;
revoke all on function public.accounts_due_for_purge() from public, anon, authenticated;
revoke all on function public.purge_account(uuid) from public, anon, authenticated;
revoke all on function public.check_in_notify(timestamptz) from public, anon, authenticated;
revoke all on function public.check_in_daily_report(timestamptz) from public, anon, authenticated;
revoke all on function public.claim_check_in_reports(integer) from public, anon, authenticated;
revoke all on function public.check_in_report_rows(uuid, date) from public, anon, authenticated;
revoke all on function public.finish_check_in_report(uuid, date, bigint, text) from public, anon, authenticated;
revoke all on function public.scheduled_call_sql(text, jsonb) from public, anon, authenticated;
revoke all on function public.schedule_post(uuid, text, jsonb, timestamptz, text, uuid) from public, anon;

grant execute on function public.check_in_sees_list(uuid) to authenticated;
grant execute on function public.post_check_in(uuid, uuid, text, text, uuid[], double precision,
                                               double precision, time, integer, time, integer, boolean)
  to authenticated;
grant execute on function public.mark_check_in(uuid, text, double precision, double precision) to authenticated;
grant execute on function public.stop_check_in(uuid) to authenticated;
grant execute on function public.check_in_list(uuid, date) to authenticated;
grant execute on function public.check_in_days(uuid) to authenticated;
grant execute on function public.schedule_post(uuid, text, jsonb, timestamptz, text, uuid) to authenticated;
grant execute on function public.check_in_notify(timestamptz) to service_role;
grant execute on function public.check_in_daily_report(timestamptz) to service_role;
grant execute on function public.claim_check_in_reports(integer) to service_role;
grant execute on function public.check_in_report_rows(uuid, date) to service_role;
grant execute on function public.finish_check_in_report(uuid, date, bigint, text) to service_role;
grant execute on function public.accounts_due_for_purge() to service_role;
grant execute on function public.purge_account(uuid) to service_role;
