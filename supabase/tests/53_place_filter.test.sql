-- Migration 53 (review 105C part A): Search finds a Space's places. A
-- place whose name matches comes back as kind 'place', its id and its
-- name, for the Space's members only; Work then shows that place's posts
-- (the app filters by space_posts.place_id). Posts, points, messages and
-- files are found as before. A non-member finds nothing, and can't read
-- or write a place. Run with: supabase test db
--
-- Omar (c1) made the Space: its admin, a Lead. Rakesh (c2) is Crew. Eve
-- (c5) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000053' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@places53.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('c1'), ('c2'), ('c5')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000053' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000053' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000053' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.other() returns uuid language sql as $$
  select current_setting('test.other')::uuid;
$$;
-- The places search_space finds for [p_q], by name.
create function pg_temp.places(p_space uuid, p_q text) returns text[] language sql as $$
  select coalesce(array_agg(s.title order by s.title), '{}')
  from public.search_space(p_space, p_q) s where s.kind = 'place';
$$;

-- Setup: two Spaces of Omar's, places in each, a work item.
select pg_temp.as_user('c1');
set local role authenticated;
select set_config('test.space', public.create_space('Places site')::text, true);
select set_config('test.other', public.create_space('Other site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp(), pg_temp.uid('c2'), 'crew', pg_temp.uid('c1'));
select pg_temp.as_user('c1');
set local role authenticated;
insert into public.space_places (id, space_id, name, created_by) values
  (pg_temp.id('b001'), pg_temp.sp(), 'L3 · Grid B4', pg_temp.uid('c1')),
  (pg_temp.id('b002'), pg_temp.sp(), 'Gate 2', pg_temp.uid('c1')),
  (pg_temp.id('b003'), pg_temp.other(), 'L3 · Grid B4 east', pg_temp.uid('c1'));
select public.create_work_item(pg_temp.sp(), 'Grid B4 sleeves', pg_temp.uid('c2'),
                               p_id => pg_temp.id('a001'));
select public.set_post_place(pg_temp.id('a001'), pg_temp.id('b001'));
reset role;

-- A member finds places -----------------------------------------------------------------------------

select pg_temp.as_user('c1');
set local role authenticated;
select is(pg_temp.places(pg_temp.sp(), 'grid b4'), array['L3 · Grid B4'],
  'a Lead finds the place by part of its name, whatever its case');
select is(pg_temp.places(pg_temp.sp(), 'GATE'), array['Gate 2'], 'another place');
select is((select s.id from public.search_space(pg_temp.sp(), 'gate') s where s.kind = 'place'),
  pg_temp.id('b002'), 'with its id');
select is(pg_temp.places(pg_temp.sp(), 'g'), '{}'::text[], 'one letter finds nothing');
select is(pg_temp.places(pg_temp.sp(), 'east'), '{}'::text[], 'another Space''s place isn''t found');
select ok(exists (select 1 from public.search_space(pg_temp.sp(), 'grid b4') s
                  where s.kind = 'post' and s.post_id = pg_temp.id('a001')),
  'posts are found as before');
-- Many newer posts that match don't crowd the place out.
select public.create_work_item(pg_temp.sp(), 'Grid B4 item ' || n, pg_temp.uid('c2'))
from generate_series(1, 35) n;
select is(pg_temp.places(pg_temp.sp(), 'grid b4'), array['L3 · Grid B4'],
  'found before 35 newer posts with the same words');
reset role;
select pg_temp.as_user('c2');
set local role authenticated;
select is(pg_temp.places(pg_temp.sp(), 'grid'), array['L3 · Grid B4'], 'Crew finds it too');
reset role;

-- A non-member: nothing to read or write ---------------------------------------------------------------

select pg_temp.as_user('c5');
set local role authenticated;
select is((select count(*) from public.search_space(pg_temp.sp(), 'grid b4'))::integer, 0,
  'a non-member finds nothing, places neither');
select is((select count(*) from public.space_places where space_id = pg_temp.sp())::integer, 0,
  'a non-member can''t read the places');
select throws_ok($$insert into public.space_places (space_id, name, created_by)
  values (pg_temp.sp(), 'Roof', pg_temp.uid('c5'))$$, '42501', null,
  'a non-member can''t add one');
update public.space_places set name = 'Hacked' where id = pg_temp.id('b002');
delete from public.space_places where id = pg_temp.id('b002');
select throws_ok($$select public.set_post_place(pg_temp.id('a001'), pg_temp.id('b002'))$$,
  '42501', null, 'a non-member can''t set a post''s place');
reset role;
select is((select name from public.space_places where id = pg_temp.id('b002')), 'Gate 2',
  'a non-member can''t rename or delete one');
select is((select place_id from public.space_posts where id = pg_temp.id('a001')), pg_temp.id('b001'),
  'nor move a post');

-- The function -----------------------------------------------------------------------------------------

select is((select prosecdef from pg_proc where oid = 'public.search_space(uuid, text)'::regprocedure),
  true, 'search_space is security definer');
select ok((select proconfig from pg_proc where oid = 'public.search_space(uuid, text)'::regprocedure)
          @> array['search_path=""'], 'with an empty search_path');
select ok(not has_function_privilege('anon', 'public.search_space(uuid, text)', 'execute'),
  'anon can''t call it');

select * from finish();
rollback;
