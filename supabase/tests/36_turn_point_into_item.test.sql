-- Migration 36: Turn into, in one step (review 76, slice 5).
-- Run with: supabase test db
--
-- Omar (e1) made the Space and is its admin (Lead) and the author of the
-- work items. Rakesh (e2) is Crew and owns them, Vera (e4) a Viewer. Eve
-- (e5) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000036' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@turn36.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e4'), ('e5')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e4', 'Vera', 'Lane'),
             ('e5', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000036' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000036' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000036' || p_id)::uuid;
$$;
-- Posts, points and blocks: ids by a short code.
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000036' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.version(p text) returns integer language sql as $$
  select blocks_version from public.space_posts where id = pg_temp.id(p);
$$;
create function pg_temp.blocks(p text) returns jsonb language sql as $$
  select blocks from public.space_posts where id = pg_temp.id(p);
$$;
create function pg_temp.points(p text) returns text language sql as $$
  select coalesce(string_agg(text, ', ' order by sort), '-')
  from public.checklist_points where post_id = pg_temp.id(p);
$$;

-- Setup -----------------------------------------------------------------------------------------
-- p001: a page with text, then a checklist of three points (b002), then a
-- table. p002: points and no page. p003: Done, so no longer editable.
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Turn into site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e4', 'viewer')) x(id, pass);

select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Sleeves at grid C7', pg_temp.uid('e2'),
  p_id => pg_temp.id('a001'),
  p_points => jsonb_build_array(
    jsonb_build_object('id', pg_temp.id('d001'), 'text', 'Sleeves sized as the drawing'),
    jsonb_build_object('id', pg_temp.id('d002'), 'text', 'Fire collars at C7'),
    jsonb_build_object('id', pg_temp.id('d003'), 'text', 'x')));
select public.save_blocks(pg_temp.id('a001'), jsonb_build_array(
  jsonb_build_object('id', pg_temp.id('e001'), 'type', 'text', 'text', 'Before the pour.'),
  jsonb_build_object('id', pg_temp.id('e002'), 'type', 'checklist_ref', 'point_ids',
    jsonb_build_array(pg_temp.id('d001'), pg_temp.id('d002'), pg_temp.id('d003'))),
  jsonb_build_object('id', pg_temp.id('e003'), 'type', 'table', 'rows',
    '[["Grid", "Size"], ["C7", "100 mm"]]'::jsonb)), 0);
select public.create_work_item(pg_temp.sp(), 'Fixes, level 1', pg_temp.uid('e2'),
  p_id => pg_temp.id('a002'),
  p_points => jsonb_build_array(
    jsonb_build_object('id', pg_temp.id('d021'), 'text', 'Lobby ceiling patch')));
select public.create_work_item(pg_temp.sp(), 'Paint room 3', pg_temp.uid('e2'),
  p_id => pg_temp.id('a003'),
  p_points => jsonb_build_array(
    jsonb_build_object('id', pg_temp.id('d031'), 'text', 'Second coat')));
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select public.sign_done(pg_temp.id('a003'), 'Done.');
-- Rakesh ticks t001.
select public.tick_point(pg_temp.id('d001'), true);
reset role;

-- Who may -------------------------------------------------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select throws_ok($$select public.turn_point_into_item(pg_temp.id('a001'), pg_temp.id('d002'),
                     pg_temp.id('c901'), pg_temp.uid('e2'), 1)$$,
  '42501', null, 'the owner is not the author: no');
reset role;
select pg_temp.as_user('e4');
set local role authenticated;
select throws_ok($$select public.turn_point_into_item(pg_temp.id('a001'), pg_temp.id('d002'),
                     pg_temp.id('c902'), pg_temp.uid('e2'), 1)$$,
  '42501', null, 'a Viewer: no');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok($$select public.turn_point_into_item(pg_temp.id('a001'), pg_temp.id('d002'),
                     pg_temp.id('c903'), pg_temp.uid('e2'), 1)$$,
  '42501', null, 'someone outside the Space: no');
reset role;
set local role anon;
select throws_ok($$select public.turn_point_into_item(pg_temp.id('a001'), pg_temp.id('d002'),
                     pg_temp.id('c904'), pg_temp.uid('e2'), 1)$$,
  '42501', null, 'anon may not run it');
reset role;
select is((select count(*)::int from public.space_posts where parent_id = pg_temp.id('a001')), 0,
  'nothing was made by the refusals');

-- What is refused -------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select throws_ok($$select public.turn_point_into_item(pg_temp.id('a001'), pg_temp.id('d001'),
                     pg_temp.id('c905'), pg_temp.uid('e2'), 1)$$,
  'P0001', 'a ticked point stays as it is', 'a ticked point is a record');
select throws_ok($$select public.turn_point_into_item(pg_temp.id('a001'), pg_temp.id('d003'),
                     pg_temp.id('c906'), pg_temp.uid('e2'), 1)$$,
  '22023', null, 'one character is too short for a work item''s title');
select throws_ok($$select public.turn_point_into_item(pg_temp.id('a001'), pg_temp.id('d021'),
                     pg_temp.id('c907'), pg_temp.uid('e2'), 1)$$,
  '22023', 'not a point of this post', 'another post''s point');
select throws_ok($$select public.turn_point_into_item(pg_temp.id('a001'), pg_temp.id('d002'),
                     pg_temp.id('c908'), pg_temp.uid('e2'), 0)$$,
  '40001', null, 'a stale page version: reload');
select throws_ok($$select public.turn_point_into_item(pg_temp.id('a001'), pg_temp.id('d002'),
                     pg_temp.id('c909'), pg_temp.uid('e4'), 1)$$,
  '22023', null, 'a Viewer can''t own it');
select throws_ok($$select public.turn_point_into_item(pg_temp.id('a003'), pg_temp.id('d031'),
                     pg_temp.id('c910'), pg_temp.uid('e2'), 0)$$,
  'P0001', 'this can no longer be edited', 'a work item signed as done can''t be changed');
reset role;
select is((select count(*)::int from public.space_posts
           where parent_id in (pg_temp.id('a001'), pg_temp.id('a003'))), 0,
  'still nothing made');
select is(pg_temp.points('a001'), 'Sleeves sized as the drawing, Fire collars at C7, x',
  'and every point is still there');

-- Turned ----------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select is(public.turn_point_into_item(pg_temp.id('a001'), pg_temp.id('d002'),
            pg_temp.id('c001'), pg_temp.uid('e2'), 1), 2,
  'turned: the page''s new version');
reset role;
select is((select title from public.space_posts where id = pg_temp.id('c001')), 'Fire collars at C7',
  'the work item takes the point''s words');
select is((select parent_id from public.space_posts where id = pg_temp.id('c001')), pg_temp.id('a001'),
  'under this one');
select is((select owner_id from public.work_items where id = pg_temp.id('c001')), pg_temp.uid('e2'),
  'owned by Rakesh');
select is(pg_temp.points('a001'), 'Sleeves sized as the drawing, x', 'the point is gone');
select is((select jsonb_agg(b ->> 'type') from jsonb_array_elements(pg_temp.blocks('a001')) b),
  '["text", "checklist_ref", "child_item", "table"]'::jsonb,
  'the work item takes the point''s place on the page, after its checklist');
select is((select b -> 'point_ids' from jsonb_array_elements(pg_temp.blocks('a001')) b
           where b ->> 'type' = 'checklist_ref'),
  jsonb_build_array(pg_temp.id('d001')::text, pg_temp.id('d003')::text),
  'the checklist keeps its other points');
select is((select count(*)::int from public.notifications
           where profile_id = pg_temp.uid('e2') and work_item_id = pg_temp.id('c001')), 1,
  'Rakesh is told of his new work item');

-- A retry after a lost answer: the same item, nothing more.
select pg_temp.as_user('e1');
set local role authenticated;
select is(public.turn_point_into_item(pg_temp.id('a001'), pg_temp.id('d002'),
            pg_temp.id('c001'), pg_temp.uid('e2'), 1), 2,
  'a retry gives the same version');
reset role;
select is((select count(*)::int from public.space_posts where parent_id = pg_temp.id('a001')), 1,
  'and makes nothing more');

-- A post with points and no page keeps no page.
select pg_temp.as_user('e1');
set local role authenticated;
select is(public.turn_point_into_item(pg_temp.id('a002'), pg_temp.id('d021'),
            pg_temp.id('c021'), pg_temp.uid('e2'), 0), 0,
  'no page: no page is made');
reset role;
select is(pg_temp.points('a002'), '-', 'its point is gone');

select * from finish();
rollback;
