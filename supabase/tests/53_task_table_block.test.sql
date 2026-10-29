-- Migration 53 (review 105C-B): a work item's table of tasks, and the
-- removal sheet's list. Run with: supabase test db
--
-- Omar (f1) made the Space: its admin, a Lead. Rakesh (f2) and Tariq (f6)
-- are Crew. Vera (f4) is a Viewer. Eve (f5) is not in the Space. Tariq
-- wrote the work items for Rakesh.

begin;
create extension if not exists pgtap with schema extensions;
select plan(58);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000053' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@tasks53.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('f1'), ('f2'), ('f4'), ('f5'), ('f6')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('f1', 'Omar', 'Haddad'), ('f2', 'Rakesh', 'Nair'), ('f4', 'Vera', 'Lane'),
             ('f5', 'Eve', 'Out'), ('f6', 'Tariq', 'Aziz')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000053' || n.id)::uuid;

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
-- A table of tasks [b001] with [rows] as {"r": row's last four, "t": task,
-- "on": ticked}.
create function pg_temp.table_of(p_rows jsonb) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object(
    'id', pg_temp.id('b001'), 'type', 'task_table',
    'rows', (select jsonb_agg(jsonb_build_object(
                      'id', pg_temp.id(r ->> 'r'), 'text', r ->> 't',
                      'ticked', coalesce((r ->> 'on')::boolean, false)) order by n)
             from jsonb_array_elements(p_rows) with ordinality x(r, n))));
$$;
create function pg_temp.version(p uuid) returns integer language sql as $$
  select blocks_version from public.space_posts where id = p;
$$;
create function pg_temp.ticked(p uuid, p_row text) returns boolean language sql as $$
  select (r ->> 'ticked')::boolean
  from public.space_posts sp, jsonb_array_elements(sp.blocks) b, jsonb_array_elements(b -> 'rows') r
  where sp.id = p and r ->> 'id' = pg_temp.id(p_row)::text;
$$;

-- Setup: the Space, its people; Tariq's work items for Rakesh, and Omar's
-- announcement.
select pg_temp.as_user('f1');
set local role authenticated;
select set_config('test.space', public.create_space('Tasks site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('f1')
from (values ('f2', 'crew'), ('f4', 'viewer'), ('f6', 'crew')) x(id, pass);
select pg_temp.as_user('f6');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Snags, level 1 lobby', pg_temp.uid('f2'), p_id => pg_temp.id('a001'));
select public.create_work_item(pg_temp.sp(), 'Snags, level 2', pg_temp.uid('f2'), p_id => pg_temp.id('a002'));
reset role;
select pg_temp.as_user('f1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Test the fire pump', pg_temp.uid('f2'), p_id => pg_temp.id('a003'));
select public.create_space_post(pg_temp.id('a004'), pg_temp.sp(), 'announcement', 'Toolbox talk at 7');
reset role;

-- 1. The block ------------------------------------------------------------------------------------

select pg_temp.as_user('f6');
set local role authenticated;
select lives_ok($$select public.save_blocks(pg_temp.id('a001'), pg_temp.table_of(
  '[{"r": "c001", "t": "Cracked tile at the stair"}, {"r": "c002", "t": "Grout gap at the lift door"},
    {"r": "c003", "t": "Skirting loose, grid A3"}]'), 0)$$,
  'the author adds a table of tasks to a work item');
select is(jsonb_array_length((select blocks -> 0 -> 'rows' from public.space_posts where id = pg_temp.id('a001'))), 3,
  'with its three rows');
select throws_ok($$select public.save_blocks(pg_temp.id('a002'), pg_temp.table_of(
  '[{"r": "c001", "t": "Tile", "on": true}]'), 0)$$, '42501', null,
  'the author (Crew, not the owner) can''t save a row ticked');
select throws_ok($$select public.save_blocks(pg_temp.id('a002'), '[{"id": "00000000-0000-0000-0000-00000053b002",
  "type": "task_table", "rows": []}]'::jsonb, 0)$$, '22023', null, 'a table of tasks has a row at least');
select throws_ok($$select public.save_blocks(pg_temp.id('a002'), jsonb_build_array(jsonb_build_object(
  'id', pg_temp.id('b002'), 'type', 'task_table',
  'rows', (select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'text', 'Task', 'ticked', false))
           from generate_series(1, 21)))), 0)$$, '22023', null, 'and 20 at most');
select throws_ok($$select public.save_blocks(pg_temp.id('a002'), '[{"id": "00000000-0000-0000-0000-00000053b002",
  "type": "task_table", "rows": [{"id": "00000000-0000-0000-0000-00000053c001", "text": "Tile"}]}]'::jsonb, 0)$$,
  '22023', null, 'each row has its tick');
select throws_ok($$select public.save_blocks(pg_temp.id('a002'), '[{"id": "00000000-0000-0000-0000-00000053b002",
  "type": "task_table", "rows": [{"id": "00000000-0000-0000-0000-00000053c001", "text": "Tile", "ticked": false},
  {"id": "00000000-0000-0000-0000-00000053c001", "text": "Grout", "ticked": false}]}]'::jsonb, 0)$$,
  '22023', null, 'and its own id');
select throws_ok($$select public.save_blocks(pg_temp.id('a002'), '[{"id": "00000000-0000-0000-0000-00000053b002",
  "type": "task_table", "rows": [{"id": "00000000-0000-0000-0000-00000053c001", "text": "Tile", "ticked": false,
  "owner": "00000000-0000-0000-0000-0000000053f2"}]}]'::jsonb, 0)$$,
  '22023', null, 'a row has no owner of its own: the item has one');
select throws_ok($$select public.save_blocks(pg_temp.id('a002'), pg_temp.table_of(
  jsonb_build_array(jsonb_build_object('r', 'c001', 't', repeat('x', 201)))), 0)$$,
  '22023', null, 'a task of up to 200 characters');
select throws_ok($$select public.save_blocks(pg_temp.id('a002'), jsonb_build_array(jsonb_build_object(
  'id', pg_temp.id('b003'), 'type', 'toggle', 'text', 'More',
  'children', pg_temp.table_of('[{"r": "c001", "t": "Tile"}]'))), 0)$$,
  '22023', null, 'a toggle doesn''t hold one');
reset role;
select pg_temp.as_user('f1');
set local role authenticated;
select throws_ok($$select public.save_blocks(pg_temp.id('a004'), pg_temp.table_of(
  '[{"r": "c001", "t": "Tile"}]'), 0)$$, '22023', null, 'only a work item has a table of tasks');
reset role;

-- 2. Ticks ---------------------------------------------------------------------------------------

select pg_temp.as_user('f2');
set local role authenticated;
select is(public.tick_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text, pg_temp.id('c001')::text, true), 2,
  'the owner ticks a row: the page''s next version');
select ok(pg_temp.ticked(pg_temp.id('a001'), 'c001'), 'the row is ticked');
select is(public.tick_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text, pg_temp.id('c001')::text, true), 2,
  'the same tick again changes nothing');
select is((select status from public.work_items where id = pg_temp.id('a001')), 'open',
  'a tick is not a signature: the item stays Open');
select throws_ok($$select public.tick_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text,
  pg_temp.id('c099')::text, true)$$, 'P0001', null, 'a row that isn''t there');
reset role;
select pg_temp.as_user('f1');
set local role authenticated;
select lives_ok($$select public.tick_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text,
  pg_temp.id('c002')::text, true)$$, 'a Lead ticks a row');
select lives_ok($$select public.tick_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text,
  pg_temp.id('c002')::text, false)$$, 'and takes the tick back');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.tick_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text,
  pg_temp.id('c002')::text, true)$$, '42501', null, 'Crew who don''t own the item can''t, its author neither');
reset role;
select pg_temp.as_user('f4');
set local role authenticated;
select throws_ok($$select public.tick_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text,
  pg_temp.id('c002')::text, true)$$, '42501', null, 'nor a Viewer');
reset role;
select pg_temp.as_user('f5');
set local role authenticated;
select throws_ok($$select public.tick_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text,
  pg_temp.id('c002')::text, true)$$, '42501', null, 'nor someone outside the Space');
select is((select count(*) from public.space_posts where id = pg_temp.id('a001'))::integer, 0,
  'who can''t read the work item and its table');
reset role;
select ok(not pg_temp.ticked(pg_temp.id('a001'), 'c002'), 'so the row stays unticked');

-- The author's save around the owner's ticks.
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.save_blocks(pg_temp.id('a001'), pg_temp.table_of(
  '[{"r": "c001", "t": "Cracked tile at the stair"}, {"r": "c002", "t": "Grout gap at the lift door"},
    {"r": "c003", "t": "Skirting loose, grid A3"}]'), pg_temp.version(pg_temp.id('a001')))$$,
  '42501', null, 'the author can''t untick a row by saving');
select throws_ok($$select public.save_blocks(pg_temp.id('a001'), pg_temp.table_of(
  '[{"r": "c002", "t": "Grout gap at the lift door"}, {"r": "c003", "t": "Skirting loose, grid A3"}]'),
  pg_temp.version(pg_temp.id('a001')))$$, '42501', null, 'nor take a ticked row out');
select throws_ok($$select public.save_blocks(pg_temp.id('a001'), pg_temp.table_of(
  '[{"r": "c001", "t": "Broken tile", "on": true}, {"r": "c002", "t": "Grout gap at the lift door"},
    {"r": "c003", "t": "Skirting loose, grid A3"}]'), pg_temp.version(pg_temp.id('a001')))$$,
  '42501', null, 'nor change a ticked row''s words');
select throws_ok($$select public.save_blocks(pg_temp.id('a001'), '[]'::jsonb, pg_temp.version(pg_temp.id('a001')))$$,
  '42501', null, 'nor take the table out while a row is ticked');
select lives_ok($$select public.save_blocks(pg_temp.id('a001'), pg_temp.table_of(
  '[{"r": "c001", "t": "Cracked tile at the stair", "on": true}, {"r": "c002", "t": "Grout gap, lift door"},
    {"r": "c004", "t": "Paint touch-up"}]'), pg_temp.version(pg_temp.id('a001')))$$,
  'he keeps the ticked row, and edits, adds and takes out the others');
select ok(pg_temp.ticked(pg_temp.id('a001'), 'c001'), 'the owner''s tick stays');
select throws_ok($$select public.save_blocks(pg_temp.id('a001'), pg_temp.table_of(
  '[{"r": "c001", "t": "Cracked tile at the stair", "on": true}]'), pg_temp.version(pg_temp.id('a001')) - 1)$$,
  '40001', null, 'a save from before a tick reads the page again first');
reset role;

-- 3. Add a row -----------------------------------------------------------------------------------

select pg_temp.as_user('f2');
set local role authenticated;
select lives_ok($$select public.add_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text, pg_temp.id('c005'),
  ' Seal the joint ', 'Grey')$$, 'the owner adds a row');
select is((select r from public.space_posts sp, jsonb_array_elements(sp.blocks -> 0 -> 'rows') r
           where sp.id = pg_temp.id('a001') and r ->> 'id' = pg_temp.id('c005')::text),
  jsonb_build_object('id', pg_temp.id('c005'), 'text', 'Seal the joint', 'note', 'Grey', 'ticked', false),
  'at the end, unticked, its words trimmed');
select is(public.add_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text, pg_temp.id('c005'), 'Seal the joint'),
  pg_temp.version(pg_temp.id('a001')), 'sent again, nothing more');
select is(jsonb_array_length((select blocks -> 0 -> 'rows' from public.space_posts where id = pg_temp.id('a001'))), 4,
  'one row added');
select throws_ok($$select public.add_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text, pg_temp.id('c006'), '  ')$$,
  '22023', null, 'a row has its task');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select lives_ok($$select public.add_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text, pg_temp.id('c007'),
  'Clean the lift sill')$$, 'the author adds one too');
reset role;
select pg_temp.as_user('f4');
set local role authenticated;
select throws_ok($$select public.add_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text, pg_temp.id('c008'),
  'Roof')$$, '42501', null, 'a Viewer can''t');
reset role;
select pg_temp.as_user('f5');
set local role authenticated;
select throws_ok($$select public.add_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text, pg_temp.id('c008'),
  'Roof')$$, '42501', null, 'nor someone outside the Space');
reset role;

-- 4. The cards' read -----------------------------------------------------------------------------

select pg_temp.as_user('f4');
set local role authenticated;
select is((select jsonb_array_length(t.blocks -> 0 -> 'rows') from public.space_task_tables(pg_temp.sp()) t
           where t.post_id = pg_temp.id('a001')), 5, 'members read the tables of tasks for the cards');
select is((select count(*) from public.space_task_tables(pg_temp.sp()))::integer, 1,
  'only the work items that have one');
reset role;
select pg_temp.as_user('f5');
set local role authenticated;
select is((select count(*) from public.space_task_tables(pg_temp.sp()))::integer, 0,
  'someone outside the Space reads none');
reset role;

-- 5. Signed: the rows stop -----------------------------------------------------------------------

select pg_temp.as_user('f2');
set local role authenticated;
select lives_ok($$select public.sign_done(pg_temp.id('a001'), 'All fixed.')$$,
  'Sign as done once for the whole item, with rows still unticked');
select throws_ok($$select public.tick_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text,
  pg_temp.id('c002')::text, true)$$, 'P0001', null, 'once Done, a row can''t be ticked');
select throws_ok($$select public.add_task_row(pg_temp.id('a001'), pg_temp.id('b001')::text, pg_temp.id('c009'),
  'More')$$, 'P0001', null, 'nor added');
reset role;

-- 6. Templates leave it out ----------------------------------------------------------------------

select pg_temp.as_user('f1');
set local role authenticated;
select lives_ok($$select public.save_template(pg_temp.id('e001'), pg_temp.sp(), pg_temp.id('a001'), 'Snags')$$,
  'a work item with a table of tasks can still be a template');
select is((select blocks from public.post_templates where id = pg_temp.id('e001')), '[]'::jsonb,
  'without its table (a template holds words)');
reset role;

-- 7. The removal sheet's list --------------------------------------------------------------------

select pg_temp.as_user('f1');
set local role authenticated;
select is(jsonb_array_length(public.open_work_to_hand_over(pg_temp.sp(), pg_temp.uid('f2'))), 2,
  'the admin reads the open work items Rakesh owns (not the Done one)');
select is(public.open_work_to_hand_over(pg_temp.sp(), pg_temp.uid('f2')) -> 0 ->> 'ref' is not null, true,
  'each with its reference');
select is((select x ->> 'maker_name' from jsonb_array_elements(public.open_work_to_hand_over(pg_temp.sp(),
           pg_temp.uid('f2'))) x where x ->> 'id' = pg_temp.id('a002')::text), 'Tariq Aziz',
  'and its maker');
select is((select (x ->> 'maker_may_own')::boolean from jsonb_array_elements(public.open_work_to_hand_over(
           pg_temp.sp(), pg_temp.uid('f2'))) x where x ->> 'id' = pg_temp.id('a002')::text), true,
  'who may take it back (Crew)');
select is(jsonb_array_length(public.open_work_to_hand_over(pg_temp.sp(), pg_temp.uid('f4'))), 0,
  'none for someone with no open work');
reset role;
select pg_temp.as_user('f2');
set local role authenticated;
select is(jsonb_array_length(public.open_work_to_hand_over(pg_temp.sp(), pg_temp.uid('f2'))), 2,
  'Rakesh reads his own, to leave');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.open_work_to_hand_over(pg_temp.sp(), pg_temp.uid('f2'))$$, '42501', null,
  'other Crew can''t read someone else''s');
reset role;
select pg_temp.as_user('f5');
set local role authenticated;
select throws_ok($$select public.open_work_to_hand_over(pg_temp.sp(), pg_temp.uid('f2'))$$, '42501', null,
  'nor someone outside the Space');
reset role;

-- The sheet's answer goes through migration 52's handover.
select pg_temp.as_user('f1');
set local role authenticated;
select lives_ok($$select public.remove_member_with_handover(pg_temp.sp(), pg_temp.uid('f2'),
  jsonb_build_array(jsonb_build_object('item', pg_temp.id('a002'), 'owner', pg_temp.uid('f6')),
                    jsonb_build_object('item', pg_temp.id('a003'), 'owner', pg_temp.uid('f1'))))$$,
  'Give and remove: each open item to its new owner, then removed');
select is(jsonb_array_length(public.open_work_to_hand_over(pg_temp.sp(), pg_temp.uid('f6'))), 1,
  'Tariq owns his item now');
reset role;

-- 8. Grants --------------------------------------------------------------------------------------

select ok(not has_function_privilege('authenticated', 'public.may_tick_task(public.space_posts)', 'execute'),
  'may_tick_task is internal');
select ok(not has_function_privilege('anon', 'public.tick_task_row(uuid, text, text, boolean)', 'execute'),
  'a signed-out caller can''t tick');

select * from finish();
rollback;
