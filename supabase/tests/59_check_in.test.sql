-- Migration 20261120120000 (review 109): Check-in. Run with: supabase test db
--
-- Omar (a1) made the Space, a project in Kuwait (Asia/Kuwait, weekend
-- Friday and Saturday from the market pack): its admin, a Lead. Gus (a7) is
-- a Lead in the Team "Steel fixers" and posts the check-ins. In that Team
-- too: Rakesh (b2), Tariq (c3), Sami (b3) and Noor (b4), all Crew, and Vera
-- (e5), a Viewer. Lina (d4) is Crew outside it, alone in the Team "Solo".
-- Hana (a8) is another Lead. Eve (f6) is not in the Space. Rakesh and
-- Gus turned lock-screen text on; nobody else did.
--
-- The clock: the public functions use now(); each has an internal twin
-- that takes the time (p_now), which only the database itself may call
-- (never authenticated). The tests call the twins as postgres, with the
-- caller set in request.jwt.claims, on D: a Tuesday at least 30 days ahead
-- (never a weekend in Kuwait), so the real day never gets in the way.

begin;
create extension if not exists pgtap with schema extensions;
select plan(239);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000059' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@ci59.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('b3'), ('b4'), ('d4'), ('e5'), ('f6'), ('a7'), ('a8')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('a1', 'Omar', 'Haddad'), ('b2', 'Rakesh', 'Nair'), ('c3', 'Tariq', 'Aziz'),
             ('b3', 'Sami', 'Fares'), ('b4', 'Noor', 'Ali'), ('d4', 'Lina', 'Saad'),
             ('e5', 'Vera', 'Lane'), ('f6', 'Eve', 'Out'), ('a7', 'Gus', 'Lead'),
             ('a8', 'Hana', 'Lead')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000059' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000059' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000059' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000059' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.sp2() returns uuid language sql as $$
  select current_setting('test.space2')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
create function pg_temp.solo() returns uuid language sql as $$
  select current_setting('test.solo')::uuid;
$$;
create function pg_temp.team2() returns uuid language sql as $$
  select current_setting('test.team2')::uuid;
$$;
-- D: a Tuesday at least 30 days ahead.
create function pg_temp.d() returns date language sql as $$
  select x::date from generate_series(current_date + 30, current_date + 37, interval '1 day') x
  where extract(isodow from x) = 2 order by x limit 1;
$$;
-- [p_time] on D + [p_days], in Kuwait.
create function pg_temp.at(p_days integer, p_time text) returns timestamptz language sql as $$
  select ((pg_temp.d() + p_days) + p_time::time) at time zone 'Asia/Kuwait';
$$;
-- Today in Kuwait.
create function pg_temp.today() returns date language sql as $$
  select (now() at time zone 'Asia/Kuwait')::date;
$$;
-- [p_id] marks [p_kind] on [p_post] at [p_at], [p_dlat] degrees north of the
-- site (null: the place isn't shared).
create function pg_temp.mark(p_id text, p_post text, p_kind text, p_at timestamptz,
                             p_dlat double precision default 0,
                             p_accuracy double precision default null,
                             p_mocked boolean default false) returns jsonb language plpgsql as $$
begin
  perform pg_temp.as_user(p_id);
  return public.check_in_mark_at(pg_temp.id(p_post), p_kind,
    case when p_dlat is not null then 29.3759 + p_dlat end,
    case when p_dlat is not null then 47.9774 end, p_accuracy, p_mocked, p_at);
end;
$$;
-- Marks on [p_post] that [p_id] reads through RLS; [p_others]: only other people's.
create function pg_temp.marks_read(p_id text, p_post text, p_others boolean default false)
returns integer language plpgsql as $$
declare v integer;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  select count(*) into v from public.check_in_marks
  where post_id = pg_temp.id(p_post) and (not p_others or user_id <> auth.uid());
  reset role;
  return v;
end;
$$;
-- [p_post]'s card as [p_id] reads it in Work.
create function pg_temp.card(p_id text, p_post text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  select c.card into v from public.daybook_cards(
    (select space_id from public.space_posts where id = pg_temp.id(p_post)), null, 100) c
  where c.id = pg_temp.id(p_post);
  reset role;
  return v;
end;
$$;
-- Library files [p_id] reads through RLS, of [p_file].
create function pg_temp.files_read(p_id text, p_file uuid) returns integer language plpgsql as $$
declare v integer;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  select count(*) into v from public.library_files where id = p_file;
  reset role;
  return v;
end;
$$;
-- Pushes queued for [p_post] of [p_kind].
create function pg_temp.pushes(p_post text, p_kind text) returns integer language sql as $$
  select count(*)::int from public.push_queue
  where kind = p_kind and data ->> 'post_id' = pg_temp.id(p_post)::text;
$$;

-- Setup ----------------------------------------------------------------------------------------------

insert into public.projects (id, name, type_id, market_id)
values (pg_temp.id('e001'), 'Kuwait tower', (select id from public.project_types limit 1), 'kw');

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Check-in tower')::text, true);
reset role;
update public.spaces set project_id = pg_temp.id('e001') where id = pg_temp.sp();
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1')
from (values ('b2', 'crew'), ('c3', 'crew'), ('b3', 'crew'), ('b4', 'crew'), ('d4', 'crew'),
             ('e5', 'viewer'), ('a7', 'lead'), ('a8', 'lead')) x(id, pass);
select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'Steel fixers',
  array[pg_temp.uid('b2'), pg_temp.uid('c3'), pg_temp.uid('b3'), pg_temp.uid('b4'),
        pg_temp.uid('e5'), pg_temp.uid('a7')])::text, true);
select set_config('test.solo', public.create_team(pg_temp.sp(), 'Solo',
  array[pg_temp.uid('d4')])::text, true);
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select set_config('test.space2', public.create_space('Other site')::text, true);
select set_config('test.team2', public.create_team(pg_temp.sp2(), 'Other team', '{}')::text, true);
reset role;
insert into public.push_tokens (token, profile_id, platform)
select repeat(x.c, 40), pg_temp.uid(x.id), 'android'
from (values ('a1', 'a'), ('b2', 'b'), ('c3', 'c'), ('b3', 'd'), ('b4', 'e'), ('d4', 'f'),
             ('e5', 'g'), ('a7', 'h'), ('a8', 'i')) x(id, c);
-- Lock-screen text (push_settings.message_text): on for Rakesh and Gus only.
insert into public.push_settings (profile_id, message_text)
values (pg_temp.uid('b2'), true), (pg_temp.uid('a7'), true);

-- The tables ----------------------------------------------------------------------------------------

select has_table('public', 'check_in_posts', 'check_in_posts exists');
select has_table('public', 'check_in_marks', 'check_in_marks exists');
select ok((select bool_and(relrowsecurity) from pg_class
           where oid in ('public.check_in_posts'::regclass, 'public.check_in_marks'::regclass,
                         'public.check_in_sends'::regclass, 'public.check_in_reports'::regclass)),
  'row-level security on all four');
select ok(not has_table_privilege('authenticated', 'public.check_in_marks', 'insert')
          and not has_table_privilege('authenticated', 'public.check_in_marks', 'update')
          and not has_table_privilege('authenticated', 'public.check_in_marks', 'delete')
          and not has_table_privilege('authenticated', 'public.check_in_posts', 'insert')
          and not has_table_privilege('authenticated', 'public.check_in_posts', 'update')
          and not has_table_privilege('authenticated', 'public.check_in_posts', 'delete'),
  'nobody writes the posts or the marks directly');
select ok(not has_table_privilege('authenticated', 'public.check_in_sends', 'select')
          and not has_table_privilege('authenticated', 'public.check_in_reports', 'select'),
  'the send log and the report jobs are the server''s');
select ok(not has_column_privilege('authenticated', 'public.check_in_posts', 'site_lat', 'select')
          and not has_column_privilege('authenticated', 'public.check_in_posts', 'site_lng', 'select'),
  'the site''s point is never read by the app');
select is((select count(*)::int from information_schema.columns
           where table_schema = 'public' and table_name like 'check_in%'
             and column_name ~ '(lat|lng|lon|latitude|longitude|geo|point|coord)'
             and not (table_name = 'check_in_posts' and column_name in ('site_lat', 'site_lng'))),
  0, 'no person coordinates in any check-in table');
select is((select array_agg(column_name::text order by column_name) from information_schema.columns
           where table_schema = 'public' and table_name = 'check_in_marks'),
  array['at', 'day', 'kind', 'on_time', 'place', 'post_id', 'tries', 'user_id'],
  'a mark keeps the time and the result only');
select is((select count(*)::int from pg_proc
           where pronamespace = 'public'::regnamespace
             and (proname like '%check_in%')
             and not (prosecdef and coalesce(proconfig, '{}') @> array['search_path=""'])),
  0, 'every check-in function is security definer with an empty search_path');
select ok(not has_function_privilege('authenticated',
            'public.check_in_mark_at(uuid, text, double precision, double precision, double precision, boolean, timestamptz)', 'execute')
          and not has_function_privilege('authenticated', 'public.check_in_rows(uuid, date, timestamptz)', 'execute')
          and not has_function_privilege('authenticated', 'public.check_in_notify(timestamptz)', 'execute')
          and not has_function_privilege('authenticated', 'public.check_in_daily_report(timestamptz)', 'execute')
          and not has_function_privilege('authenticated', 'public.claim_check_in_reports(integer)', 'execute')
          and not has_function_privilege('authenticated', 'public.check_in_report_rows(uuid, date)', 'execute')
          and not has_function_privilege('authenticated', 'public.finish_check_in_report(uuid, date, bigint, text)', 'execute'),
  'the clock''s twins, the cron jobs and the report''s calls are never the app''s');
select ok(has_function_privilege('authenticated',
            'public.post_check_in(uuid, uuid, text, text, uuid[], double precision, double precision, time, integer, time, integer, boolean, text)', 'execute')
          and has_function_privilege('authenticated', 'public.mark_check_in(uuid, text, double precision, double precision, double precision, boolean)', 'execute')
          and has_function_privilege('authenticated', 'public.stop_check_in(uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.check_in_list(uuid, date)', 'execute')
          and has_function_privilege('authenticated', 'public.check_in_days(uuid)', 'execute')
          and not has_function_privilege('anon', 'public.mark_check_in(uuid, text, double precision, double precision, double precision, boolean)', 'execute'),
  'the app''s five calls, signed in only');

-- Posting (CI1) -------------------------------------------------------------------------------------

-- C101: Gus, Steel fixers, every day, 7:00 · 15 min, out 14:00 · 15 min.
select pg_temp.as_user('a7');
set local role authenticated;
select is(public.post_check_in(pg_temp.id('c101'), pg_temp.sp(), 'Morning, Block B', null,
  array[pg_temp.team()], 29.3759, 47.9774, '07:00', 15, '14:00', 15, true),
  pg_temp.id('c101'), 'a Lead posts a check-in');
select is(public.post_check_in(pg_temp.id('c101'), pg_temp.sp(), 'Morning, Block B', null,
  array[pg_temp.team()], 29.3759, 47.9774, '07:00', 15, '14:00', 15, true),
  pg_temp.id('c101'), 'the same id again is the same check-in');
-- C102: the whole Space, once, 7:00 · 0 min, no check-out.
select is(public.post_check_in(pg_temp.id('c102'), pg_temp.sp(), 'Site induction', 'Gate 2',
  null, 29.3759, 47.9774, '07:00', 0),
  pg_temp.id('c102'), 'once, for the whole Space');
-- C104: Steel fixers, every day, for the pushes.
select lives_ok($$select public.post_check_in(pg_temp.id('c104'), pg_temp.sp(), 'Roll call',
  null, array[pg_temp.team()], 29.3759, 47.9774, '07:00', 15, '14:00', 15, true)$$,
  'a second one for the pushes');
-- C105: Solo (Lina only), every day, 8:00 · 10 min.
select lives_ok($$select public.post_check_in(pg_temp.id('c105'), pg_temp.sp(), 'Solo roll',
  null, array[pg_temp.solo()], 29.3759, 47.9774, '08:00', 10, null, null, true)$$,
  'and one for a Team of one');
select throws_ok($$select public.post_check_in(pg_temp.id('c1f1'), pg_temp.sp(), 'No place',
  null, null, null, null, '07:00', 15)$$, '22023', null, 'the site is needed');
select throws_ok($$select public.post_check_in(pg_temp.id('c1f1'), pg_temp.sp(), 'No time',
  null, null, 29.3759, 47.9774, null, 15)$$, '22023', null, 'the check-in time is needed');
select throws_ok($$select public.post_check_in(pg_temp.id('c1f1'), pg_temp.sp(), 'Odd allowance',
  null, null, 29.3759, 47.9774, '07:00', 5)$$, '22023', null, 'an allowance of 0, 10, 15 or 30');
select throws_ok($$select public.post_check_in(pg_temp.id('c1f1'), pg_temp.sp(), 'Odd out',
  null, null, 29.3759, 47.9774, '07:00', 15, '14:00', 20)$$, '22023', null,
  'the check-out allowance too');
select throws_ok($$select public.post_check_in(pg_temp.id('c1f1'), pg_temp.sp(), 'Out first',
  null, null, 29.3759, 47.9774, '07:00', 15, '07:10', 15)$$, '22023', null,
  'check-out opens after check-in''s allowance');
select throws_ok($$select public.post_check_in(pg_temp.id('c1f1'), pg_temp.sp(), '  ',
  null, null, 29.3759, 47.9774, '07:00', 15)$$, '22023', null, 'a title');
select throws_ok($$select public.post_check_in(pg_temp.id('c1f1'), pg_temp.sp(), 'Their team',
  null, array[pg_temp.team2()], 29.3759, 47.9774, '07:00', 15)$$, '22023', null,
  'only Teams of this Space');
select throws_ok($$select public.post_check_in(pg_temp.id('c1f1'), pg_temp.sp(), 'Odd zone',
  null, null, 29.3759, 47.9774, '07:00', 15, p_time_zone => 'Not/AZone')$$, '22023', 'a time zone',
  'Y1: a time zone that isn''t one is refused');
select throws_ok($$select public.post_check_in(pg_temp.id('c1f1'), pg_temp.sp(), 'Far away',
  null, null, 91, 47.9774, '07:00', 15)$$, '22023', null, 'a site on the earth');
reset role;

select pg_temp.as_user('a8');
set local role authenticated;
select throws_ok($$select public.post_check_in(pg_temp.id('c101'), pg_temp.sp(), 'Taken',
  null, null, 29.3759, 47.9774, '07:00', 15)$$, '42501', null, 'someone else''s id is refused');
-- C106: Hana's, the whole Space, once.
select lives_ok($$select public.post_check_in(pg_temp.id('c106'), pg_temp.sp(), 'Hana''s',
  null, null, 29.3759, 47.9774, '07:00', 15)$$, 'another Lead posts her own');
reset role;
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok($$select public.post_check_in(pg_temp.id('c1f2'), pg_temp.sp(), 'Crew',
  null, null, 29.3759, 47.9774, '07:00', 15)$$, '42501', null, 'Crew can''t post one');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok($$select public.post_check_in(pg_temp.id('c1f2'), pg_temp.sp(), 'Viewer',
  null, null, 29.3759, 47.9774, '07:00', 15)$$, '42501', null, 'nor a Viewer');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.post_check_in(pg_temp.id('c1f2'), pg_temp.sp(), 'Outsider',
  null, null, 29.3759, 47.9774, '07:00', 15)$$, '42501', null, 'nor someone outside the Space');
reset role;

select is((select kind from public.space_posts where id = pg_temp.id('c101')), 'check_in',
  'a post of kind check_in');
select is((select team_id from public.space_posts where id = pg_temp.id('c101')), pg_temp.team(),
  'one Team: the post is that Team''s');
select is((select team_id from public.space_posts where id = pg_temp.id('c102')), null,
  'the whole Space: an Everyone post');
select is((select row(repeat, team_ids, in_time, in_allow_min, out_time, out_allow_min, site_lat, site_lng)::text
           from public.check_in_posts where post_id = pg_temp.id('c101')),
  row('daily', array[pg_temp.team()], time '07:00', 15, time '14:00', 15,
      29.3759::double precision, 47.9774::double precision)::text,
  'what was set is kept');
select is((select row(repeat, team_ids, out_time, out_allow_min)::text
           from public.check_in_posts where post_id = pg_temp.id('c102')),
  row('once', null::uuid[], null::time, null::integer)::text, 'once, with no check-out');
select is((select start_day from public.check_in_posts where post_id = pg_temp.id('c102')),
  pg_temp.today(), 'once, before its day closes: today');
select is((select start_day from public.check_in_posts where post_id = pg_temp.id('c101')),
  (select case when extract(dow from pg_temp.today()) not in (5, 6)
                    and now() < ((pg_temp.today() + time '13:45') at time zone 'Asia/Kuwait')
               then pg_temp.today()
               else (select x::date from generate_series(pg_temp.today() + 1, pg_temp.today() + 7,
                                                         interval '1 day') x
                     where extract(dow from x) not in (5, 6) order by x limit 1) end),
  'every day: today if it hasn''t closed and is a working day, else the next working day');
select is((select count(*)::int from public.work_items
           where id in (pg_temp.id('c101'), pg_temp.id('c102'))), 0,
  'a check-in is never a work item, so never proof on a profile');

-- Y1: a Space with no project keeps the creator's phone time zone.
select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.yard', public.create_space('No project yard')::text, true);
select throws_ok($$select public.post_check_in(pg_temp.id('c107'), current_setting('test.yard')::uuid,
  'Yard roll', null, null, 29.3759, 47.9774, '07:00', 15)$$, '22023', 'a time zone',
  'Y1: no project and no phone time zone: refused (never the home market, never UTC)');
select is(public.post_check_in(pg_temp.id('c107'), current_setting('test.yard')::uuid,
  'Yard roll', null, null, 29.3759, 47.9774, '07:00', 15, p_daily => true,
  p_time_zone => 'Africa/Cairo'), pg_temp.id('c107'), 'with the phone''s time zone');
reset role;
select is((select time_zone from public.check_in_posts where post_id = pg_temp.id('c107')),
  'Africa/Cairo', 'kept on the check-in');
select is(pg_temp.card('a1', 'c107') -> 'check_in' ->> 'tz', 'Africa/Cairo', 'the card says which zone');
select is((pg_temp.card('a1', 'c107') -> 'check_in' -> 'today' ->> 'in_opens_at')::timestamptz,
  ((pg_temp.card('a1', 'c107') -> 'check_in' -> 'today' ->> 'day')::date + time '06:45')
    at time zone 'Africa/Cairo',
  'and its times are in that zone');

-- Z1: Every day in a Space with no project, in a zone no market pack has:
-- the creator's home market's weekend (Omar is in Kuwait: Friday and
-- Saturday off), never every day.
select pg_temp.as_user('a1');
set local role authenticated;
select is(public.post_check_in(pg_temp.id('c108'), current_setting('test.yard')::uuid,
  'Yard roll, Paris phone', null, null, 29.3759, 47.9774, '07:00', 15, p_daily => true,
  p_time_zone => 'Europe/Paris'), pg_temp.id('c108'), 'Z1: a zone no market pack has');
reset role;
update public.check_in_posts set start_day = pg_temp.d() where post_id = pg_temp.id('c108');
select is(public.check_in_runs_on((select c from public.check_in_posts c where c.post_id = pg_temp.id('c108')),
  pg_temp.d() + 3), false, 'Z1: the creator''s home market''s weekend: not on Friday');
select is(public.check_in_runs_on((select c from public.check_in_posts c where c.post_id = pg_temp.id('c108')),
  pg_temp.d()), true, 'Z1: and on a working day it runs');

-- The days the tests run on.
update public.check_in_posts set start_day = pg_temp.d()
where post_id in (pg_temp.id('c101'), pg_temp.id('c102'), pg_temp.id('c104'), pg_temp.id('c105'));

-- The card (CI4) ------------------------------------------------------------------------------------

select is(pg_temp.card('b2', 'c101') -> 'check_in' ->> 'in_time', '07:00', 'the card: its time');
select is(pg_temp.card('b2', 'c101') -> 'check_in' ->> 'tz', 'Asia/Kuwait',
  'Y1: in the Space''s time zone');
select is((pg_temp.card('b2', 'c101') -> 'check_in' ->> 'in_allow')::int, 15, 'its allowance');
select is(pg_temp.card('b2', 'c101') -> 'check_in' ->> 'out_time', '14:00', 'its check-out');
select is((pg_temp.card('b2', 'c101') -> 'check_in' ->> 'out_allow')::int, 15, 'and allowance');
select is(pg_temp.card('b2', 'c102') -> 'check_in' -> 'out_time', 'null'::jsonb,
  'no check-out: null');
select is(pg_temp.card('b2', 'c101') -> 'check_in' -> 'daily', 'true'::jsonb, 'every day');
select is(pg_temp.card('b2', 'c101') -> 'check_in' -> 'teams',
  jsonb_build_array(jsonb_build_object('id', pg_temp.team(), 'name', 'Steel fixers')),
  'its Teams, with their names');
select is(pg_temp.card('b2', 'c102') -> 'check_in' -> 'teams', 'null'::jsonb,
  'the whole Space: null');
select is(pg_temp.card('b2', 'c101') -> 'check_in' -> 'site_set', 'true'::jsonb, 'the site is set');
select ok(pg_temp.card('b2', 'c101')::text not like '%29.3759%'
          and pg_temp.card('b2', 'c101')::text not like '%47.9774%'
          and pg_temp.card('a7', 'c101')::text not like '%29.3759%',
  'the card never carries the site''s point');
select is(pg_temp.card('b2', 'c101') -> 'check_in' -> 'asked', 'true'::jsonb, 'Rakesh is asked');
select is(pg_temp.card('b2', 'c101') -> 'check_in' -> 'sees_list', 'false'::jsonb,
  'and doesn''t see the list');
select is(pg_temp.card('a7', 'c101') -> 'check_in' -> 'asked', 'false'::jsonb,
  'the creator isn''t asked');
select is(pg_temp.card('a7', 'c101') -> 'check_in' -> 'sees_list', 'true'::jsonb,
  'the creator sees the list');
select is(pg_temp.card('a1', 'c101') -> 'check_in' -> 'sees_list', 'false'::jsonb,
  'the admin doesn''t, while the creator is in the Space');
select is(pg_temp.card('a7', 'c101') -> 'check_in' -> 'can_stop', 'true'::jsonb,
  'the creator may stop an every-day check-in');
select is(pg_temp.card('a1', 'c101') -> 'check_in' -> 'can_stop', 'false'::jsonb,
  'the admin may not while the creator is in the Space');
select is(pg_temp.card('b2', 'c101') -> 'check_in' -> 'can_stop', 'false'::jsonb, 'nor Crew');
select is(pg_temp.card('a8', 'c102') -> 'check_in' -> 'can_stop', 'false'::jsonb, 'nor another Lead');
select is(pg_temp.card('a7', 'c102') -> 'check_in' -> 'can_stop', 'false'::jsonb,
  'a once-only check-in has no Stop');
select is(pg_temp.card('e5', 'c102') -> 'check_in' -> 'asked', 'false'::jsonb,
  'a Viewer is never asked');
select is(pg_temp.card('d4', 'c102') -> 'check_in' -> 'asked', 'true'::jsonb,
  'the whole Space: Crew outside the Team is asked');
select is(pg_temp.card('d4', 'c101'), null, 'a Team''s check-in isn''t on the card list of others');
select is((select array_agg(k order by k) from jsonb_object_keys(pg_temp.card('b2', 'c101') -> 'check_in' -> 'today') k),
  array['day', 'day_ends_at', 'in_closes_at', 'in_opens_at', 'in_until', 'out_opens_at',
        'out_until', 'runs'],
  'today: the day and its times');
select is((pg_temp.card('b2', 'c101') -> 'check_in' -> 'today' ->> 'day')::date, pg_temp.d(),
  'before its first day: the next run day');
select is(pg_temp.card('b2', 'c101') -> 'check_in' -> 'today' -> 'runs', 'false'::jsonb,
  'which isn''t today');
select is((pg_temp.card('b2', 'c101') -> 'check_in' -> 'today' ->> 'in_opens_at')::timestamptz,
  pg_temp.at(0, '06:45'), 'check-in opens at the time minus the allowance, in the Space''s zone');
select is((pg_temp.card('b2', 'c101') -> 'check_in' -> 'today' ->> 'in_until')::timestamptz,
  pg_temp.at(0, '07:15'), 'on time up to the time plus the allowance');
select is((pg_temp.card('b2', 'c101') -> 'check_in' -> 'today' ->> 'in_closes_at')::timestamptz,
  pg_temp.at(0, '13:45'), 'open until check-out opens');
select is((pg_temp.card('b2', 'c102') -> 'check_in' -> 'today' ->> 'in_closes_at')::timestamptz,
  pg_temp.at(1, '00:00'), 'with no check-out, until the end of the day');
select is((pg_temp.card('b2', 'c101') -> 'check_in' -> 'today' ->> 'day_ends_at')::timestamptz,
  pg_temp.at(1, '00:00'), 'the day ends at midnight in the Space''s zone');
select ok(pg_temp.card('b2', 'c101') -> 'check_in' ? 'my_in'
          and pg_temp.card('b2', 'c101') -> 'check_in' -> 'my_in' = 'null'::jsonb
          and pg_temp.card('b2', 'c101') -> 'check_in' -> 'missed' = 'false'::jsonb,
  'no stamp yet, not missed');
select is(coalesce((pg_temp.card('b2', 'c101') ->> 'needs_me')::boolean, false), false,
  'a check-in needs nobody''s sign-off');

-- Who may mark ---------------------------------------------------------------------------------------

select throws_ok($$select pg_temp.mark('f6', 'c101', 'in', pg_temp.at(0, '07:00'))$$,
  '42501', 'not allowed', 'someone outside the Space can''t mark');
select throws_ok($$select pg_temp.mark('e5', 'c101', 'in', pg_temp.at(0, '07:00'))$$,
  '42501', 'not allowed', 'a Viewer in the Team can''t');
select throws_ok($$select pg_temp.mark('d4', 'c101', 'in', pg_temp.at(0, '07:00'))$$,
  '42501', 'not allowed', 'Crew outside the asked Team can''t');
select throws_ok($$select pg_temp.mark('a7', 'c101', 'in', pg_temp.at(0, '07:00'))$$,
  '42501', 'not allowed', 'the creator isn''t asked');
select throws_ok($$select pg_temp.mark('b2', 'c101', 'late', pg_temp.at(0, '07:00'))$$,
  '22023', null, 'in or out only');

-- The times (part 2), at the exact edges -------------------------------------------------------------

select throws_ok($$select pg_temp.mark('b2', 'c101', 'in', pg_temp.at(0, '06:44:59'))$$,
  '22023', 'not open yet', 'a second before it opens: not open yet');
select is(pg_temp.mark('b2', 'c101', 'in', pg_temp.at(0, '06:45'), 0.0005),
  jsonb_build_object('day', pg_temp.d(), 'kind', 'in', 'at', pg_temp.at(0, '06:45'),
                     'on_time', true, 'place', 'on_site'),
  'as it opens: on time, on site');
select is(pg_temp.mark('c3', 'c101', 'in', pg_temp.at(0, '07:15'), 0.00089) ->> 'on_time', 'true',
  'at the time plus the allowance: on time');
select is((select place from public.check_in_marks
           where post_id = pg_temp.id('c101') and user_id = pg_temp.uid('c3')), 'on_site',
  '99 m from the site: on site');
select is(pg_temp.mark('b3', 'c101', 'in', pg_temp.at(0, '07:15:01'), 0.00091),
  jsonb_build_object('day', pg_temp.d(), 'kind', 'in', 'at', pg_temp.at(0, '07:15:01'),
                     'on_time', false, 'place', 'away'),
  'a second later: late; 101 m: not at the site');
select throws_ok($$select pg_temp.mark('b2', 'c101', 'in', pg_temp.at(0, '07:20'))$$,
  '22023', 'already checked in', 'on site: not marked again');
select throws_ok($$select pg_temp.mark('c3', 'c101', 'in', pg_temp.at(0, '07:20'), null)$$,
  '22023', 'already checked in', 'not even without the place');
select is(pg_temp.mark('b3', 'c101', 'in', pg_temp.at(0, '07:30'), 0) ->> 'place', 'on_site',
  'not at the site: tried again while open, and replaced');
select is((select row(at, on_time, place)::text from public.check_in_marks
           where post_id = pg_temp.id('c101') and user_id = pg_temp.uid('b3') and kind = 'in'),
  row(pg_temp.at(0, '07:30'), false, 'on_site')::text, 'one mark, the new one');
select throws_ok($$select pg_temp.mark('b3', 'c101', 'in', pg_temp.at(0, '07:40'))$$,
  '22023', 'already checked in', 'and then it stays');
select throws_ok($$select pg_temp.mark('b4', 'c101', 'in', pg_temp.at(0, '13:45'))$$,
  '22023', 'closed', 'check-in closes when check-out opens');
select throws_ok($$select pg_temp.mark('b2', 'c101', 'in', pg_temp.at(3, '07:00'))$$,
  '22023', 'not a check-in day', 'every day is the market pack''s working days: not on Friday');
select throws_ok($$select pg_temp.mark('b2', 'c101', 'in', pg_temp.at(-7, '07:00'))$$,
  '22023', 'not open yet', 'not before its first day');

select throws_ok($$select pg_temp.mark('b2', 'c101', 'out', pg_temp.at(0, '13:44:59'))$$,
  '22023', 'not open yet', 'out before its window is refused');
select is(pg_temp.mark('b4', 'c101', 'out', pg_temp.at(0, '14:00'), 0) ->> 'on_time', 'true',
  'Y5: check-out without check-in is allowed');
select is(pg_temp.mark('b2', 'c101', 'out', pg_temp.at(0, '14:15'), 0) ->> 'on_time', 'true',
  'out at its time plus the allowance: on time');
select is(pg_temp.mark('c3', 'c101', 'out', pg_temp.at(0, '14:15:01'), null),
  jsonb_build_object('day', pg_temp.d(), 'kind', 'out', 'at', pg_temp.at(0, '14:15:01'),
                     'on_time', false, 'place', 'not_shared'),
  'a second later: late; no place: not shared');
select throws_ok($$select pg_temp.mark('b2', 'c101', 'out', pg_temp.at(0, '15:00'))$$,
  '22023', 'already checked in', 'out once');

-- Once, with no check-out (C102)
select throws_ok($$select pg_temp.mark('d4', 'c102', 'in', pg_temp.at(0, '06:59:59'))$$,
  '22023', 'not open yet', 'allowance 0: opens at the time');
select is(pg_temp.mark('d4', 'c102', 'in', pg_temp.at(0, '07:00'), null),
  jsonb_build_object('day', pg_temp.d(), 'kind', 'in', 'at', pg_temp.at(0, '07:00'),
                     'on_time', true, 'place', 'not_shared'),
  'at the time: on time; the place not shared');
select throws_ok($$select pg_temp.mark('d4', 'c102', 'in', pg_temp.at(0, '07:01'), 0)$$,
  '22023', 'already checked in', 'not shared: not replaced');
select is(pg_temp.mark('a1', 'c102', 'in', pg_temp.at(0, '23:59:59'), 0) ->> 'on_time', 'false',
  'open to the end of the day, late');
select throws_ok($$select pg_temp.mark('b2', 'c102', 'in', pg_temp.at(1, '07:00'))$$,
  '22023', 'closed', 'once: the next day is closed');
select throws_ok($$select pg_temp.mark('b2', 'c102', 'out', pg_temp.at(0, '15:00'))$$,
  '22023', null, 'no check-out to mark');
select is((select count(*)::int from public.check_in_marks where user_id = pg_temp.uid('d4')), 1,
  'the refused tries left nothing');

-- Y4: a mocked reading, or one worse than 100 m, is not shared; 10 tries at most.
select is(pg_temp.mark('b2', 'c102', 'in', pg_temp.at(0, '08:00'), 0, null, true) ->> 'place',
  'not_shared', 'Y4: a mocked reading counts as not shared');
select is(pg_temp.mark('c3', 'c102', 'in', pg_temp.at(0, '08:00'), 0, 150) ->> 'place',
  'not_shared', 'accuracy worse than 100 m too');
select is(pg_temp.mark('b3', 'c102', 'in', pg_temp.at(0, '08:00'), 0, 50) ->> 'place',
  'on_site', 'a good reading is tested');
select is((select count(*)::int from (
             select pg_temp.mark('b4', 'c102', 'in', pg_temp.at(0, '08:00') + make_interval(mins => i), 0.002)
             from generate_series(0, 9) i) x), 10, 'ten tries, each not at the site');
select throws_ok($$select pg_temp.mark('b4', 'c102', 'in', pg_temp.at(0, '08:30'), 0)$$,
  '22023', 'too many tries', 'Y4: the eleventh is refused');
select is((select tries from public.check_in_marks where post_id = pg_temp.id('c102')
           and user_id = pg_temp.uid('b4')), 10::smallint, 'counted on the mark');

-- The public call, on the real clock (C103: open now, today)
select pg_temp.as_user('a7');
set local role authenticated;
select public.post_check_in(pg_temp.id('c103'), pg_temp.sp(), 'Now', null, null,
  29.3759, 47.9774, '12:00', 0);
reset role;
update public.check_in_posts
set start_day = pg_temp.today(), in_time = (now() at time zone 'Asia/Kuwait')::time, in_allow_min = 0
where post_id = pg_temp.id('c103');
select pg_temp.as_user('d4');
set local role authenticated;
select is(public.mark_check_in(pg_temp.id('c103'), 'in', 29.3760, 47.9774),
  jsonb_build_object('day', pg_temp.today(), 'kind', 'in', 'at', now(), 'on_time', true,
                     'place', 'on_site'),
  'mark_check_in: the day, kind, time, on time and place');
select is(pg_temp.card('d4', 'c103') -> 'check_in' -> 'my_in',
  jsonb_build_object('at', now(), 'on_time', true, 'place', 'on_site'), 'the card shows my In stamp');
select is(pg_temp.card('d4', 'c103') -> 'check_in' -> 'today' -> 'runs', 'true'::jsonb,
  'and that it runs today');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok($$select public.mark_check_in(pg_temp.id('c103'), 'in')$$, '42501', 'not allowed',
  'a Viewer is refused by the public call too');
reset role;

-- Who reads the marks (RLS) ------------------------------------------------------------------------

select is(pg_temp.marks_read('b2', 'c101'), 2, 'Rakesh reads his own In and Out');
select is(pg_temp.marks_read('b2', 'c101', true), 0, 'Crew can''t read another''s marks');
select is(pg_temp.marks_read('a7', 'c101'), 6, 'the creator reads them all');
select is(pg_temp.marks_read('a8', 'c101'), 0, 'another Lead reads none');
select is(pg_temp.marks_read('a1', 'c101'), 0, 'nor the admin, while the creator is in the Space');
select is(pg_temp.marks_read('f6', 'c101'), 0, 'nor someone outside');

-- The list (CI5) ------------------------------------------------------------------------------------

select pg_temp.as_user('a8');
set local role authenticated;
select throws_ok($$select * from public.check_in_list(pg_temp.id('c101'), pg_temp.d())$$,
  '42501', null, 'another Lead can''t read the list');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select * from public.check_in_list(pg_temp.id('c101'), pg_temp.d())$$,
  '42501', null, 'nor Crew');
select throws_ok($$select public.check_in_days(pg_temp.id('c101'))$$, '42501', null,
  'nor its days');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select * from public.check_in_list(pg_temp.id('c101'), pg_temp.d())$$,
  '42501', null, 'nor the admin while the creator is in the Space');
reset role;
select pg_temp.as_user('a7');
set local role authenticated;
select is((select array_agg(name order by n) from (
             select name, row_number() over () as n
             from public.check_in_list(pg_temp.id('c101'), pg_temp.d())) l),
  array['Noor Ali', 'Rakesh Nair', 'Sami Fares', 'Tariq Aziz'],
  'the creator: one line per asked person, A–Z (not the Viewer, not himself)');
select is((select team from public.check_in_list(pg_temp.id('c101'), pg_temp.d())
           where user_id = pg_temp.uid('b2')), 'Steel fixers', 'with the Team');
select is((select row(in_at, in_on_time, in_place, out_at, out_on_time, out_place, missed)::text
           from public.check_in_list(pg_temp.id('c101'), pg_temp.d())
           where user_id = pg_temp.uid('b2')),
  row(pg_temp.at(0, '06:45'), true, 'on_site', pg_temp.at(0, '14:15'), true, 'on_site', false)::text,
  'In and Out stamps');
select is((select missed from public.check_in_list(pg_temp.id('c101'), pg_temp.d())
           where user_id = pg_temp.uid('b4')), false, 'not missed before its day');
select ok(cardinality(public.check_in_days(pg_temp.id('c101'))) <= 60
          and coalesce((select bool_and(x <= pg_temp.today())
                        from unnest(public.check_in_days(pg_temp.id('c101'))) x), true),
  'its days: up to today, at most 60');
reset role;

select is((select missed from public.check_in_rows(pg_temp.id('c101'), pg_temp.d(), pg_temp.at(0, '13:44:59'))
           where user_id = pg_temp.uid('b4')), false, 'a second before check-in closes: not missed');
select is((select missed from public.check_in_rows(pg_temp.id('c101'), pg_temp.d(), pg_temp.at(0, '13:45'))
           where user_id = pg_temp.uid('b4')), true, 'as it closes with no In: missed');
select is((select count(*)::int from public.check_in_rows(pg_temp.id('c101'), pg_temp.d(), pg_temp.at(0, '13:45'))
           where missed), 1, 'only the one who never checked in');
select is((select row(missed, in_at, out_at, out_on_time)::text
           from public.check_in_rows(pg_temp.id('c101'), pg_temp.d(), pg_temp.at(1, '00:00'))
           where user_id = pg_temp.uid('b4')),
  row(true, null::timestamptz, pg_temp.at(0, '14:00'), true)::text,
  'Y5: In missed, with the Out stamp');
-- Y5 on Noor's own card (the card's clock twin, check_in_card, at D's times).
create function pg_temp.my_card(p_id text, p_post text, p_at timestamptz) returns jsonb language plpgsql as $$
begin
  perform pg_temp.as_user(p_id);
  return (select public.check_in_card(p, p_at) from public.space_posts p where p.id = pg_temp.id(p_post));
end;
$$;
select is(pg_temp.my_card('b4', 'c101', pg_temp.at(0, '14:30')) -> 'my_in', 'null'::jsonb,
  'Y5 card: no In stamp');
select is(pg_temp.my_card('b4', 'c101', pg_temp.at(0, '14:30')) -> 'my_out',
  jsonb_build_object('at', pg_temp.at(0, '14:00'), 'on_time', true, 'place', 'on_site'),
  'Y5 card: the Out stamp');
select is(pg_temp.my_card('b4', 'c101', pg_temp.at(0, '14:30')) -> 'missed', 'true'::jsonb,
  'Y5 card: In missed, once check-in has closed');
select is(pg_temp.my_card('b4', 'c104', pg_temp.at(0, '13:00')) -> 'missed', 'false'::jsonb,
  'before check-in closes: not missed');
select is(pg_temp.my_card('b4', 'c104', pg_temp.at(0, '13:00')) -> 'my_out', 'null'::jsonb,
  'and no Out stamp');
select is(pg_temp.my_card('b4', 'c104', pg_temp.at(0, '13:45')) -> 'missed', 'true'::jsonb,
  'as it closes with no In: missed');
-- Y2: an earlier day lists those asked that day.
update public.space_members set confirmed_at = pg_temp.at(1, '01:00')
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('c3');
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('b4');
select is((select array_agg(name order by name)
           from public.check_in_rows(pg_temp.id('c104'), pg_temp.d(), pg_temp.at(1, '00:00'))),
  array['Rakesh Nair', 'Sami Fares'],
  'Y2: not who joined after the day ended, nor who left before it began');
select is((select array_agg(name order by name)
           from public.check_in_rows(pg_temp.id('c101'), pg_temp.d(), pg_temp.at(1, '00:00'))),
  array['Noor Ali', 'Rakesh Nair', 'Sami Fares', 'Tariq Aziz'],
  'but anyone who marked that day stays on it');
update public.space_members set confirmed_at = now(), left_at = null
where space_id = pg_temp.sp() and profile_id in (pg_temp.uid('c3'), pg_temp.uid('b4'));
select is((select in_on_time from public.check_in_rows(pg_temp.id('c101'), pg_temp.d(), pg_temp.at(1, '00:00'))
           where user_id = pg_temp.uid('b3')), false, 'Sami was late');
select is((select row(in_at, in_place, out_at)::text from public.check_in_rows(pg_temp.id('c101'), pg_temp.d(), pg_temp.at(1, '00:00'))
           where user_id = pg_temp.uid('b3')),
  row(pg_temp.at(0, '07:30'), 'on_site', null::timestamptz)::text,
  'a missing Out is no Out stamp');

-- The creator leaves: the admin sees the list.
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a7');
select is(pg_temp.marks_read('a1', 'c101'), 6, 'the creator left: the admin reads the marks');
select pg_temp.as_user('a1');
set local role authenticated;
select is((select count(*)::int from public.check_in_list(pg_temp.id('c101'), pg_temp.d())), 4,
  'and the list');
select lives_ok($$select public.check_in_days(pg_temp.id('c101'))$$, 'and its days');
reset role;
select is(pg_temp.card('a1', 'c101') -> 'check_in' -> 'sees_list', 'true'::jsonb,
  'the admin''s card says so');
select is(pg_temp.marks_read('a8', 'c101'), 0, 'another Lead still reads none');
update public.space_members set left_at = null
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a7');

-- Pushes: check_in_notify (C104, C105) -----------------------------------------------------------

select is(public.check_in_notify(pg_temp.at(0, '06:44')) >= 0, true, 'it runs');
select is(pg_temp.pushes('c104', 'check_in_open'), 0, 'nothing before check-in opens');
select ok(public.check_in_notify(pg_temp.at(0, '06:45')) >= 4, 'as it opens');
select is(pg_temp.pushes('c104', 'check_in_open'), 4,
  'one to each asked person with a phone (not the Viewer, not the creator)');
select is((select array_agg(profile_id order by profile_id) from public.push_queue
           where kind = 'check_in_open' and data ->> 'post_id' = pg_temp.id('c104')::text),
  array[pg_temp.uid('b2'), pg_temp.uid('b3'), pg_temp.uid('b4'), pg_temp.uid('c3')]::uuid[],
  'Rakesh, Sami, Noor and Tariq');
select is((select data - 'tz' from public.push_queue
           where kind = 'check_in_open' and data ->> 'post_id' = pg_temp.id('c104')::text
             and profile_id = pg_temp.uid('b2')),
  jsonb_build_object('post_id', pg_temp.id('c104'), 'space_id', pg_temp.sp(), 'mark', 'in',
                     'title', 'Roll call', 'space_name', 'Check-in tower',
                     'until', pg_temp.at(0, '07:15')),
  'what it carries: the post, the Space, In, its title and Space, and the on-time limit');
select is((select data - 'tz' from public.push_queue
           where kind = 'check_in_open' and data ->> 'post_id' = pg_temp.id('c104')::text
             and profile_id = pg_temp.uid('b3')),
  jsonb_build_object('post_id', pg_temp.id('c104'), 'space_id', pg_temp.sp(), 'mark', 'in',
                     'until', pg_temp.at(0, '07:15')),
  'lock-screen text off: no title and no Space, only what the actions need');
select is(public.check_in_notify(pg_temp.at(0, '06:45')), 0, 'a second run in the same minute sends nothing');
select is((select count(*)::int from public.push_queue where kind = 'check_in_open'
           and data ->> 'post_id' = pg_temp.id('c104')::text), 4, 'still four');
select is(public.check_in_notify(pg_temp.at(0, '07:30')) >= 0, true, 'later while open');
select is(pg_temp.pushes('c104', 'check_in_open'), 4, 'once per day per window');

select pg_temp.mark('b2', 'c104', 'in', pg_temp.at(0, '07:00'), 0);
select pg_temp.mark('c3', 'c104', 'in', pg_temp.at(0, '07:20'), 0.002);
select ok(public.check_in_notify(pg_temp.at(0, '13:45')) >= 1, 'as check-in closes and check-out opens');
select is((select count(*)::int from public.push_queue where kind = 'check_in_open'
           and data ->> 'post_id' = pg_temp.id('c104')::text and data ->> 'mark' = 'out'), 4,
  'check-out opens: to everyone asked (Y5: check-out without check-in is allowed)');
select is((select data ->> 'until' from public.push_queue where kind = 'check_in_open'
           and data ->> 'post_id' = pg_temp.id('c104')::text and data ->> 'mark' = 'out' limit 1)::timestamptz,
  pg_temp.at(0, '14:15'), 'by its on-time limit');
select is(pg_temp.pushes('c104', 'check_in_summary'), 1, 'one summary as check-in closes');
select is((select row(profile_id, data)::text from public.push_queue
           where kind = 'check_in_summary' and data ->> 'post_id' = pg_temp.id('c104')::text),
  row(pg_temp.uid('a7'), jsonb_build_object('post_id', pg_temp.id('c104'), 'space_id', pg_temp.sp(),
                                            'title', 'Roll call', 'late', 1, 'away', 1, 'missed', 2))::text,
  'to the creator: 1 late, 1 not at site, 2 missed');
select is(public.check_in_notify(pg_temp.at(0, '13:46')) >= 0, true, 'a minute later');
select is(pg_temp.pushes('c104', 'check_in_summary'), 1, 'still one summary');

-- C105: Lina checks in on time, on site: nothing to see, no summary.
select is(public.check_in_notify(pg_temp.at(0, '07:50')) >= 0, true, 'Solo is open (its push went at the last run)');
select is(pg_temp.pushes('c105', 'check_in_open'), 1, 'one push, to Lina');
select pg_temp.mark('d4', 'c105', 'in', pg_temp.at(0, '07:55'), 0);
select is(public.check_in_notify(pg_temp.at(1, '00:00')) >= 0, true, 'at the end of the day');
select is(pg_temp.pushes('c105', 'check_in_summary'), 0,
  'everyone on time and on site: no summary');
-- The next day Lina misses it, and Gus has left: the first-joined admin gets
-- the summary (Hana is made an admin who joined earlier than Omar).
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a7');
update public.space_members set is_admin = true, confirmed_at = now() - interval '1 day'
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a8');
select is(public.check_in_notify(pg_temp.at(2, '00:00')) >= 1, true, 'the next day ends');
select is((select array_agg(profile_id) from public.push_queue
           where kind = 'check_in_summary' and data ->> 'post_id' = pg_temp.id('c105')::text),
  array[pg_temp.uid('a8')], 'Y6: the creator left: one summary, to the first-joined admin');
select is((select data from public.push_queue
           where kind = 'check_in_summary' and data ->> 'post_id' = pg_temp.id('c105')::text),
  jsonb_build_object('post_id', pg_temp.id('c105'), 'space_id', pg_temp.sp()),
  'lock-screen text off: the summary says only that it is ready');
update public.space_members set is_admin = false, confirmed_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a8');
update public.space_members set left_at = null
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a7');

-- The day's report into the Library (only me) -----------------------------------------------------

select ok(public.check_in_daily_report(pg_temp.at(0, '23:59')) >= 0, 'before the day ends');
select is((select count(*)::int from public.check_in_reports where day = pg_temp.d()), 0,
  'no report before the day ends');
select ok(public.check_in_daily_report(pg_temp.at(1, '00:05')) >= 4, 'after the day ends: waiting reports');
select is((select recipient_id from public.check_in_reports
           where post_id = pg_temp.id('c101') and day = pg_temp.d()), pg_temp.uid('a7'),
  'one for the day, for the creator');
select is((select count(*)::int from public.check_in_reports where day = pg_temp.d() + 1), 0,
  'not the day still running');
select lives_ok($$select public.check_in_daily_report(pg_temp.at(1, '00:20'))$$, 'run again');
select is((select count(*)::int from public.check_in_reports
           where post_id = pg_temp.id('c101') and day = pg_temp.d()), 1, 'still one for the day');

set local role service_role;
select ok((select count(*)::int from public.claim_check_in_reports(50)
           where post_id = pg_temp.id('c101') and day = pg_temp.d()) = 1,
  'the function claims it');
select is((select count(*)::int from public.claim_check_in_reports(50)
           where post_id = pg_temp.id('c101')), 0, 'once');
select is((select array_agg(name order by name) from public.check_in_report_rows(pg_temp.id('c101'), pg_temp.d())),
  array['Noor Ali', 'Rakesh Nair', 'Sami Fares', 'Tariq Aziz'], 'its lines');
select is((select row(team, in_time, out_time, in_late, out_late, place)::text
           from public.check_in_report_rows(pg_temp.id('c101'), pg_temp.d()) where name = 'Sami Fares'),
  row('Steel fixers', '07:30', null::text, true, false, 'on_site')::text,
  'times in the Space''s zone, late and the place');
select is((select place from public.check_in_report_rows(pg_temp.id('c101'), pg_temp.d())
           where name = 'Noor Ali'), 'missed', 'missed');
select is((select out_time from public.check_in_report_rows(pg_temp.id('c101'), pg_temp.d())
           where name = 'Noor Ali'), '14:00', 'Y5: with her Out');
reset role;
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('a7'), pg_temp.uid('b3'));
set local role service_role;
select is((select array_agg(name order by name collate "C") from public.check_in_report_rows(pg_temp.id('c101'), pg_temp.d())),
  array['Noor Ali', 'Rakesh Nair', 'Tariq Aziz', '—'],
  'Y3: named as the list names them for its reader: someone he blocked has no name');
reset role;
delete from public.blocks where blocker_id = pg_temp.uid('a7') and blocked_id = pg_temp.uid('b3');
set local role service_role;
select lives_ok($$select public.finish_check_in_report(pg_temp.id('c101'), pg_temp.d(), 4096, null)$$,
  'stored');
reset role;
select set_config('test.file', (select library_file_id::text from public.check_in_reports
                                where post_id = pg_temp.id('c101') and day = pg_temp.d()), true);
select is((select row(folder, only_profile_id, source, mime, space_id)::text from public.library_files
           where id = current_setting('test.file')::uuid),
  row('check_in_reports', pg_temp.uid('a7'), 'check_in_report',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', pg_temp.sp())::text,
  'a spreadsheet in Check-in reports, only for the creator');
select is((select state from public.check_in_reports
           where post_id = pg_temp.id('c101') and day = pg_temp.d()), 'done', 'done');
select is(pg_temp.files_read('a7', current_setting('test.file')::uuid), 1, 'the creator opens it');
select is(pg_temp.files_read('b2', current_setting('test.file')::uuid), 0,
  'the only-me file is invisible to other members');
select is(pg_temp.files_read('a1', current_setting('test.file')::uuid), 0,
  'to the admin too, while the creator is in the Space');
select is(pg_temp.files_read('a8', current_setting('test.file')::uuid), 0, 'and to another Lead');
select pg_temp.as_user('b2');
select is(public.may_read_file((select storage_path from public.library_files
                                where id = current_setting('test.file')::uuid), null), false,
  'nor its stored file');
select pg_temp.as_user('a1');
set local role authenticated;
select is((select count(*)::int from public.library_overview(pg_temp.sp())
           where file_id = current_setting('test.file')::uuid), 0, 'nor in the Library list');
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a7');
select is(pg_temp.files_read('a1', current_setting('test.file')::uuid), 1,
  'the creator left: the admin opens it');
select is(pg_temp.files_read('b2', current_setting('test.file')::uuid), 0, 'still nobody else');
update public.space_members set left_at = null
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a7');
select throws_ok($$insert into public.library_files (id, space_id, name, storage_path, mime, only_profile_id)
  values (pg_temp.id('f001'), pg_temp.sp(), 'Mine', pg_temp.sp()::text || '/library/x/y.pdf',
          'application/pdf', pg_temp.uid('b2'))$$, '23514', null,
  'only me is for check-in reports only');
select throws_ok($$insert into public.library_files (id, space_id, name, storage_path, mime, supersedes_id)
  values (pg_temp.id('f002'), pg_temp.sp(), 'Newer', pg_temp.sp()::text || '/library/' || pg_temp.id('f002') || '/y.pdf',
          'application/pdf', current_setting('test.file')::uuid)$$, '22023', null,
  'Y7: a check-in report has no newer versions');
-- Y9: a job still claimed after its fifth try fails.
update public.check_in_reports set state = 'claimed', attempts = 5, claimed_at = now() - interval '1 hour'
where post_id = pg_temp.id('c102') and day = pg_temp.d();
set local role service_role;
select is((select count(*)::int from public.claim_check_in_reports(50)
           where post_id = pg_temp.id('c102')), 0, 'Y9: not claimed a sixth time');
reset role;
select is((select state from public.check_in_reports
           where post_id = pg_temp.id('c102') and day = pg_temp.d()), 'failed', 'Y9: failed');

-- Post later ----------------------------------------------------------------------------------------

select pg_temp.as_user('a7');
set local role authenticated;
select lives_ok($$select public.schedule_post(pg_temp.id('c201'), 'post_check_in',
  jsonb_build_object('p_id', pg_temp.id('c201'), 'p_space', pg_temp.sp(), 'p_title', 'Later roll',
                     'p_teams', jsonb_build_array(pg_temp.team()), 'p_site_lat', 29.3759,
                     'p_site_lng', 47.9774, 'p_in_time', '07:00', 'p_in_allow', 15,
                     'p_out_time', '14:00', 'p_out_allow', 15, 'p_daily', true),
  now() + interval '1 hour', 'Later roll')$$, 'Hold Send = Post later takes a check-in');
reset role;
update public.scheduled_posts set publish_at = now() - interval '1 minute' where id = pg_temp.id('c201');
select ok(public.publish_due_posts() >= 1, 'it goes at its time');
select is((select row(kind, author_id)::text from public.space_posts where id = pg_temp.id('c201')),
  row('check_in', pg_temp.uid('a7'))::text, 'as a check-in by its author');
select is((select team_ids from public.check_in_posts where post_id = pg_temp.id('c201')),
  array[pg_temp.team()], 'with its Teams');

-- Stop ----------------------------------------------------------------------------------------------

select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.stop_check_in(pg_temp.id('c101'))$$, '42501', null,
  'Crew can''t stop it');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.stop_check_in(pg_temp.id('c101'))$$, '42501', null,
  'nor the admin');
reset role;
select pg_temp.as_user('a8');
set local role authenticated;
select throws_ok($$select public.stop_check_in(pg_temp.id('c101'))$$, '42501', null,
  'nor another Lead');
reset role;
select pg_temp.as_user('a7');
set local role authenticated;
select lives_ok($$select public.stop_check_in(pg_temp.id('c101'))$$, 'the creator stops it');
select lives_ok($$select public.stop_check_in(pg_temp.id('c101'))$$, 'again is no harm');
reset role;
select isnt((select stopped_at from public.check_in_posts where post_id = pg_temp.id('c101')), null,
  'stopped');
select is(pg_temp.card('a7', 'c101') -> 'check_in' -> 'can_stop', 'false'::jsonb,
  'a stopped check-in offers no Stop');
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a7');
select is(pg_temp.card('a1', 'c104') -> 'check_in' -> 'can_stop', 'true'::jsonb,
  'the creator left: the admin may stop it');
select pg_temp.as_user('a8');
set local role authenticated;
select throws_ok($$select public.stop_check_in(pg_temp.id('c104'))$$, '42501', null,
  'another Lead never can');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.stop_check_in(pg_temp.id('c104'))$$,
  'the admin stops it once the creator has left');
reset role;
select isnt((select stopped_at from public.check_in_posts where post_id = pg_temp.id('c104')), null,
  'stopped by the admin');
update public.space_members set left_at = null
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a7');
select throws_ok($$select pg_temp.mark('b4', 'c101', 'in', pg_temp.at(7, '07:00'))$$,
  '22023', 'stopped', 'nobody marks a stopped check-in');
select is(pg_temp.card('b2', 'c101') -> 'check_in' -> 'stopped', 'true'::jsonb, 'its card says so');
select is(pg_temp.card('b2', 'c101') -> 'check_in' -> 'today' -> 'runs', 'false'::jsonb,
  'and it doesn''t run');
select is((select count(*)::int from public.check_in_marks where post_id = pg_temp.id('c101')), 6,
  'its earlier days stay');
select is(public.check_in_notify(pg_temp.at(7, '06:50')) >= 0, true, 'a week later');
select is((select count(*)::int from public.push_queue where kind = 'check_in_open'
           and data ->> 'post_id' = pg_temp.id('c101')::text
           and (data ->> 'until')::timestamptz > pg_temp.at(6, '00:00')), 0,
  'a stopped check-in sends nothing');

select is((select count(*)::int from public.push_queue
           where data::text like '%29.376%' or data::text like '%47.977%'), 0,
  'no point in any push');

-- My data: my own marks, nobody else's -------------------------------------------------------------

insert into public.data_requests (id, profile_id) values (pg_temp.id('f101'), pg_temp.uid('d4'));
select is(jsonb_array_length(public.export_my_data(pg_temp.id('f101')) -> 'check_in_marks'),
  (select count(*)::int from public.check_in_marks where user_id = pg_temp.uid('d4')),
  'export_my_data has every one of Lina''s marks');
select ok((select count(*) from public.check_in_marks where user_id = pg_temp.uid('d4')) >= 3,
  'and she has several');
select is((select array_agg(k order by k) from jsonb_object_keys(
             public.export_my_data(pg_temp.id('f101')) -> 'check_in_marks' -> 0) k),
  array['at', 'check_in', 'day', 'kind', 'on_time', 'place', 'space'],
  'each: the check-in, its Space, the day, in or out, the time, on time and the place result');
select ok((public.export_my_data(pg_temp.id('f101')) -> 'check_in_marks')::text
            not like '%' || pg_temp.uid('b2')::text || '%'
          and not exists (
            select 1 from jsonb_array_elements(public.export_my_data(pg_temp.id('f101')) -> 'check_in_marks') e
            where (e ->> 'at')::timestamptz = pg_temp.at(0, '06:45')),
  'nobody else''s (not Rakesh''s 06:45)');

-- Account deletion: the only-me reports and their stored files go -----------------------------

insert into storage.objects (bucket_id, name)
select 'space-files', storage_path from public.library_files where id = current_setting('test.file')::uuid;
update public.profiles set deletion_scheduled_at = now() - interval '31 days' where id = pg_temp.uid('a7');
select ok(exists (select 1 from public.accounts_due_for_purge()
                  where profile_id = pg_temp.uid('a7') and bucket = 'space-files'
                    and name = (select storage_path from public.library_files
                                where id = current_setting('test.file')::uuid)),
  'due: the creator''s check-in report file');
select is((select count(*)::int from public.accounts_due_for_purge()
           where bucket = 'space-files'), 1, 'and no other Space file');
select ok(not public.purge_account(pg_temp.uid('a7')), 'not purged while the file is still stored');
set local storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id = 'space-files'
  and name = (select storage_path from public.library_files where id = current_setting('test.file')::uuid);
select ok(public.purge_account(pg_temp.uid('a7')), 'once the file is gone, purged');
select is((select count(*)::int from public.library_files where id = current_setting('test.file')::uuid), 0,
  'and the report''s Library row with it');

select * from finish();
rollback;
