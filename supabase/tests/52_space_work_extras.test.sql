-- Migration 52 (review 105B): a Space's Work extras. Places, Archive,
-- personal pins, Share to a chat thread, the Space's time zone, and
-- handover when someone leaves or is removed. Run with: supabase test db
--
-- Omar (f1) made the Space: its admin, a Lead. Rakesh (f2) and Tariq (f6)
-- are Crew, Tariq in the MEP Team. Vera (f4) is a Viewer. Eve (f5) is not
-- in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(71);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000052' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@extras52.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('f1'), ('f2'), ('f4'), ('f5'), ('f6')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('f1', 'Omar', 'Haddad'), ('f2', 'Rakesh', 'Nair'), ('f4', 'Vera', 'Lane'),
             ('f5', 'Eve', 'Out'), ('f6', 'Tariq', 'Aziz')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000052' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000052' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000052' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000052' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
create function pg_temp.everyone() returns uuid language sql as $$
  select t.id from public.threads t where t.space_id = pg_temp.sp() and t.team_id is null;
$$;
create function pg_temp.team_thread() returns uuid language sql as $$
  select t.id from public.threads t where t.space_id = pg_temp.sp() and t.team_id = pg_temp.team();
$$;
create function pg_temp.listed(p_id uuid) returns boolean language sql as $$
  select exists (select 1 from public.daybook_cards(pg_temp.sp(), null, 100) c where c.id = p_id);
$$;
create function pg_temp.owner(p_id uuid) returns uuid language sql as $$
  select w.owner_id from public.work_items w where w.id = p_id;
$$;

-- Setup: the Space, its people and Team; work items, one of them Checked.
select pg_temp.as_user('f1');
set local role authenticated;
select set_config('test.space', public.create_space('Extras site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('f1')
from (values ('f2', 'crew'), ('f4', 'viewer'), ('f6', 'crew')) x(id, pass);
select pg_temp.as_user('f1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('f6')])::text, true);
select public.create_work_item(pg_temp.sp(), 'Sleeves at grid C7', pg_temp.uid('f2'), p_id => pg_temp.item('a001'));
select public.create_work_item(pg_temp.sp(), 'Door closers', pg_temp.uid('f2'), p_id => pg_temp.item('a002'));
select public.create_work_item(pg_temp.sp(), 'Fire stopping', pg_temp.uid('f2'), p_id => pg_temp.item('a003'));
select public.create_work_item(pg_temp.sp(), 'Duct riser', pg_temp.uid('f6'), p_team => pg_temp.team(),
                               p_id => pg_temp.item('a004'));
reset role;
select pg_temp.as_user('f2');
set local role authenticated;
select public.sign_done(pg_temp.item('a001'), 'All six fixed.');
reset role;
select pg_temp.as_user('f1');
set local role authenticated;
select public.check_item(pg_temp.item('a001'));
reset role;

-- 1. Places --------------------------------------------------------------------------------------

select has_table('public', 'space_places', 'space_places');
select has_column('public', 'space_posts', 'place_id', 'a post''s place');
select pg_temp.as_user('f2');
set local role authenticated;
select lives_ok($$insert into public.space_places (space_id, name, created_by)
  values (pg_temp.sp(), 'Level 3 slab', auth.uid())$$, 'Crew who may post work add a place');
select throws_ok($$insert into public.space_places (space_id, name, created_by)
  values (pg_temp.sp(), '  level 3  SLAB ', auth.uid())$$, '23505', null,
  'the name is unique in the Space, whatever its case and spaces');
select is((select count(*) from public.space_places where space_id = pg_temp.sp())::integer, 1,
  'members read the places');
update public.space_places set name = 'Level 3' where space_id = pg_temp.sp();
select is((select name from public.space_places where space_id = pg_temp.sp()), 'Level 3 slab',
  'Crew can''t rename one');
reset role;
select pg_temp.as_user('f4');
set local role authenticated;
select throws_ok($$insert into public.space_places (space_id, name, created_by)
  values (pg_temp.sp(), 'Roof', auth.uid())$$, '42501', null, 'a Viewer can''t add one');
reset role;
select pg_temp.as_user('f5');
set local role authenticated;
select is((select count(*) from public.space_places where space_id = pg_temp.sp())::integer, 0,
  'someone outside the Space can''t read them');
select throws_ok($$insert into public.space_places (space_id, name, created_by)
  values (pg_temp.sp(), 'Roof', auth.uid())$$, '42501', null, 'nor add one');
reset role;
select pg_temp.as_user('f1');
set local role authenticated;
update public.space_places set name = 'Level 3, slab' where space_id = pg_temp.sp();
select is((select name from public.space_places where space_id = pg_temp.sp()), 'Level 3, slab',
  'a Lead renames one');
reset role;
-- A post's place is one of its own Space's.
insert into public.spaces (id, name, created_by) values (pg_temp.item('e001'), 'Other site', pg_temp.uid('f5'));
insert into public.space_places (id, space_id, name) values (pg_temp.item('d009'), pg_temp.item('e001'), 'Gate');
select throws_ok($$update public.space_posts set place_id = pg_temp.item('d009') where id = pg_temp.item('a002')$$,
  '22023', null, 'not another Space''s place');
update public.space_posts set place_id = (select id from public.space_places where space_id = pg_temp.sp())
where id = pg_temp.item('a002');
select isnt((select place_id from public.space_posts where id = pg_temp.item('a002')), null,
  'a place of its own Space');
select pg_temp.as_user('f1');
set local role authenticated;
delete from public.space_places where space_id = pg_temp.sp();
select is((select count(*) from public.space_places where space_id = pg_temp.sp())::integer, 0,
  'a Lead deletes one');
reset role;
select is((select place_id from public.space_posts where id = pg_temp.item('a002')), null,
  'its posts keep no place');

-- 2. Archive -------------------------------------------------------------------------------------

select has_column('public', 'space_posts', 'archived_at', 'space_posts.archived_at');
select pg_temp.as_user('f2');
set local role authenticated;
select throws_ok($$select public.archive_space_post(pg_temp.item('a001'))$$, '42501', null,
  'Crew can''t archive');
reset role;
select pg_temp.as_user('f1');
set local role authenticated;
select throws_ok($$select public.archive_space_post(pg_temp.item('a002'))$$, 'P0001', null,
  'not an open item');
select lives_ok($$select public.archive_space_post(pg_temp.item('a001'))$$, 'a Lead archives a Checked item');
select is((select archived_by from public.space_posts where id = pg_temp.item('a001')), pg_temp.uid('f1'),
  'who archived it is kept');
select is(pg_temp.listed(pg_temp.item('a001')), false, 'Work leaves it out');
select is(pg_temp.listed(pg_temp.item('a002')), true, 'the others stay');
select isnt((select count(*) from public.daybook_card(pg_temp.item('a001')))::integer, 0,
  'it still opens (Search)');
select ok(exists (select 1 from public.search_space(pg_temp.sp(), 'Sleeves') s
                  where s.id = pg_temp.item('a001')), 'Search still finds it');
select lives_ok($$select public.unarchive_space_post(pg_temp.item('a001'))$$, 'and brings it back');
select is(pg_temp.listed(pg_temp.item('a001')), true, 'back in Work');
reset role;
select pg_temp.as_user('f5');
set local role authenticated;
select throws_ok($$select public.archive_space_post(pg_temp.item('a001'))$$, '42501', null,
  'someone outside the Space can''t');
reset role;

-- 3. Personal pins -------------------------------------------------------------------------------

select has_table('public', 'space_post_pins', 'space_post_pins');
select pg_temp.as_user('f2');
set local role authenticated;
select lives_ok($$select public.pin_space_post(pg_temp.item('a002'))$$, 'Rakesh pins one for himself');
select lives_ok($$select public.pin_space_post(pg_temp.item('a002'))$$, 'twice is once');
select is((select count(*) from public.space_post_pins)::integer, 1, 'he reads his pin');
select is((select c.card ->> 'pinned_by_me' from public.daybook_cards(pg_temp.sp(), null, 100) c
           where c.id = pg_temp.item('a002')), 'true', 'its card says so');
select ok(exists (select 1 from public.daybook_extras(pg_temp.sp(), now() - interval '1 day', now() + interval '1 day') x
                  where x.id = pg_temp.item('a002') and x.reason = 'mine'), 'Work lists it with his pins');
select throws_ok($$insert into public.space_post_pins (user_id, post_id) values (auth.uid(), pg_temp.item('a003'))$$,
  '42501', null, 'only through pin_space_post');
reset role;
select pg_temp.as_user('f1');
set local role authenticated;
select is((select count(*) from public.space_post_pins)::integer, 0, 'Omar doesn''t see Rakesh''s pin');
select is((select c.card ->> 'pinned_by_me' from public.daybook_cards(pg_temp.sp(), null, 100) c
           where c.id = pg_temp.item('a002')), 'false', 'nor is it his');
select lives_ok($$select public.unpin_space_post(pg_temp.item('a002'))$$, 'his own unpin changes nothing');
reset role;
select is((select count(*) from public.space_post_pins)::integer, 1, 'Rakesh''s pin stays');
select pg_temp.as_user('f4');
set local role authenticated;
select throws_ok($$select public.pin_space_post(pg_temp.item('a004'))$$, '42501', null,
  'not a post he can''t see (a Team''s)');
reset role;
select pg_temp.as_user('f5');
set local role authenticated;
select throws_ok($$select public.pin_space_post(pg_temp.item('a002'))$$, '42501', null,
  'someone outside the Space can''t pin');
select is((select count(*) from public.space_post_pins)::integer, 0, 'nor read pins');
reset role;
select pg_temp.as_user('f2');
set local role authenticated;
select lives_ok($$select public.unpin_space_post(pg_temp.item('a002'))$$, 'Rakesh unpins it');
select is((select count(*) from public.space_post_pins)::integer, 0, 'gone');
reset role;

-- 4. Share to a chat thread ----------------------------------------------------------------------

select pg_temp.as_user('f2');
set local role authenticated;
select lives_ok($$select public.share_post_to_thread(pg_temp.item('cc01'), pg_temp.item('a002'), pg_temp.everyone())$$,
  'Rakesh shares a work item into the Everyone thread');
select is((select kind || ':' || post_id from public.messages where id = pg_temp.item('cc01')),
  'post:' || pg_temp.item('a002'), 'a message carrying the post''s card');
select lives_ok($$select public.share_post_to_thread(pg_temp.item('cc01'), pg_temp.item('a002'), pg_temp.everyone())$$,
  'a retry posts it once');
select is((select count(*) from public.messages where post_id = pg_temp.item('a002'))::integer, 1, 'once');
select throws_ok($$select public.share_post_to_thread(pg_temp.item('cc02'), pg_temp.item('a004'), pg_temp.everyone())$$,
  '42501', null, 'not a post he can''t see');
select throws_ok($$select public.share_post_to_thread(pg_temp.item('cc03'), pg_temp.item('a002'), pg_temp.team_thread())$$,
  '42501', null, 'not into a thread he can''t write in');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.share_post_to_thread(pg_temp.item('cc04'), pg_temp.item('a004'), pg_temp.everyone())$$,
  '22023', null, 'a Team''s post only into that Team''s thread');
select lives_ok($$select public.share_post_to_thread(pg_temp.item('cc05'), pg_temp.item('a004'), pg_temp.team_thread())$$,
  'into its Team''s thread');
reset role;
-- The other Space's thread.
insert into public.space_members (space_id, profile_id, pass, is_admin)
values (pg_temp.item('e001'), pg_temp.uid('f2'), 'lead', true);
select pg_temp.as_user('f2');
set local role authenticated;
select throws_ok($$select public.share_post_to_thread(pg_temp.item('cc06'), pg_temp.item('a002'),
                     (select t.id from public.threads t where t.space_id = pg_temp.item('e001') and t.team_id is null))$$,
  '22023', null, 'not into another Space''s thread: the work stays in its Space');
reset role;
select pg_temp.as_user('f5');
set local role authenticated;
select throws_ok($$select public.share_post_to_thread(pg_temp.item('cc07'), pg_temp.item('a002'), pg_temp.everyone())$$,
  '42501', null, 'someone outside the Space can''t share');
select is((select count(*) from public.messages where id = pg_temp.item('cc01'))::integer, 0,
  'nor read the message');
reset role;

-- 5. The Space's time zone -----------------------------------------------------------------------

select pg_temp.as_user('f2');
set local role authenticated;
select is(public.space_time_zone(pg_temp.sp()), 'Asia/Kuwait',
  'with no project: its maker''s market (Kuwait)');
reset role;
insert into public.projects (id, name, type_id, market_id)
values (pg_temp.item('b001'), 'Cairo tower', (select id from public.project_types limit 1), 'eg');
update public.spaces set project_id = pg_temp.item('b001') where id = pg_temp.sp();
select pg_temp.as_user('f2');
set local role authenticated;
select is(public.space_time_zone(pg_temp.sp()), 'Africa/Cairo', 'with a project: its market (Egypt)');
select is((select public.time_zone(s) from public.spaces s where s.id = pg_temp.sp()), 'Africa/Cairo',
  'read with the Space too');
reset role;
select pg_temp.as_user('f5');
set local role authenticated;
select is(public.space_time_zone(pg_temp.sp()), null, 'nothing for someone outside the Space');
reset role;

-- 6. Handover ------------------------------------------------------------------------------------

-- Rakesh owns a002 and a003 (open) and a001 (Checked).
select pg_temp.as_user('f1');
set local role authenticated;
select throws_ok($$select public.remove_member_with_handover(pg_temp.sp(), pg_temp.uid('f2'),
                     jsonb_build_array(jsonb_build_object('item', pg_temp.item('a002'), 'owner', pg_temp.uid('f1'))))$$,
  '22023', null, 'every open item needs a new owner');
select throws_ok($$select public.remove_member_with_handover(pg_temp.sp(), pg_temp.uid('f2'),
                     jsonb_build_array(
                       jsonb_build_object('item', pg_temp.item('a002'), 'owner', pg_temp.uid('f1')),
                       jsonb_build_object('item', pg_temp.item('a003'), 'owner', pg_temp.uid('f4'))))$$,
  '22023', null, 'not to a Viewer, who can''t own work');
select ok((select left_at is null from public.space_members
           where space_id = pg_temp.sp() and profile_id = pg_temp.uid('f2')), 'so nothing changed');
select is(pg_temp.owner(pg_temp.item('a002')), pg_temp.uid('f2'), 'his items are his still');
select lives_ok($$select public.remove_member_with_handover(pg_temp.sp(), pg_temp.uid('f2'),
                     jsonb_build_array(
                       jsonb_build_object('item', pg_temp.item('a002'), 'owner', pg_temp.uid('f1')),
                       jsonb_build_object('item', pg_temp.item('a003'), 'owner', pg_temp.uid('f6'))))$$,
  'removed, with his open work handed over');
select is(pg_temp.owner(pg_temp.item('a002')), pg_temp.uid('f1'), 'to Omar');
select is(pg_temp.owner(pg_temp.item('a003')), pg_temp.uid('f6'), 'and to Tariq');
select is(pg_temp.owner(pg_temp.item('a001')), pg_temp.uid('f2'), 'his Checked work stays his');
select is((select count(*) from public.work_item_events
           where work_item_id in (pg_temp.item('a002'), pg_temp.item('a003')) and kind = 'reassigned')::integer, 2,
  'each handover is in the item''s record');
select ok((select left_at is not null from public.space_members
           where space_id = pg_temp.sp() and profile_id = pg_temp.uid('f2')), 'and he is out');
reset role;
-- Tariq leaves, handing the Team's duct riser and fire stopping to Omar.
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.leave_space_with_handover(pg_temp.sp(), '[]'::jsonb)$$,
  '22023', null, 'leaving with open work needs its new owners');
select lives_ok($$select public.leave_space_with_handover(pg_temp.sp(),
                     jsonb_build_array(
                       jsonb_build_object('item', pg_temp.item('a003'), 'owner', pg_temp.uid('f1')),
                       jsonb_build_object('item', pg_temp.item('a004'), 'owner', pg_temp.uid('f1'))))$$,
  'Tariq leaves, his open work handed to Omar (an admin, in every Team)');
reset role;
select is(pg_temp.owner(pg_temp.item('a004')), pg_temp.uid('f1'), 'Omar owns the duct riser');
select pg_temp.as_user('f5');
set local role authenticated;
select throws_ok($$select public.remove_member_with_handover(pg_temp.sp(), pg_temp.uid('f1'), '[]'::jsonb)$$,
  '42501', null, 'someone outside the Space can''t remove anyone');
reset role;

select * from finish();
rollback;
