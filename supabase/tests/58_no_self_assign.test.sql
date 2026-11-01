-- Migration 20261119120000 (review 112): a work item is always for someone
-- else, and the notebook share's Space list in one call.
-- Run with: supabase test db
--
-- Omar (a1) made the Space "Tower": its admin, a Lead. Rakesh (b2) is Crew,
-- Vera (c3) a Viewer, Ian (d4) was Crew and left. Eve (e5) is in no Space of
-- Omar's. Omar also made "Yard" and "Depot"; in Depot Rakesh is a Viewer.

begin;
create extension if not exists pgtap with schema extensions;
select plan(39);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000058' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@ns58.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('d4'), ('e5')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('a1', 'Omar', 'Haddad'), ('b2', 'Rakesh', 'Nair'), ('c3', 'Vera', 'Lane'),
             ('d4', 'Ian', 'Left'), ('e5', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000058' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000058' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000058' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000058' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.yard() returns uuid language sql as $$
  select current_setting('test.yard')::uuid;
$$;
create function pg_temp.depot() returns uuid language sql as $$
  select current_setting('test.depot')::uuid;
$$;
-- The Spaces [p_id] may give work in, in the order the share lists them.
create function pg_temp.postable(p_id text) returns text[] language plpgsql as $$
declare v text[];
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  select coalesce(array_agg(name), '{}') into v from public.my_postable_spaces();
  reset role;
  return v;
end;
$$;

-- Setup ----------------------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Tower')::text, true);
select set_config('test.yard', public.create_space('Yard')::text, true);
select set_config('test.depot', public.create_space('Depot')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1')
from (values ('b2', 'crew'), ('c3', 'viewer'), ('d4', 'crew')) x(id, pass);
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.depot(), pg_temp.uid('b2'), 'viewer', pg_temp.uid('a1'));
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('d4');

-- An item Omar gave himself before this rule (written as the old rule let it).
select pg_temp.as_user('a1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Gate check', pg_temp.uid('b2'), p_id => pg_temp.id('a001'));
reset role;
set local session_replication_role = replica;
update public.work_items set owner_id = pg_temp.uid('a1') where id = pg_temp.id('a001');
set local session_replication_role = origin;

-- 1. A new work item ---------------------------------------------------------------------------------

select has_function('public', 'work_item_not_for_self', 'the rule is one function');
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.create_work_item(pg_temp.sp(), 'Sleeves at C7', pg_temp.uid('a1'),
                   p_id => pg_temp.id('a002'))$$,
  '22023', 'a work item is for someone else', 'a work item for yourself is refused');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Sleeves at C7', pg_temp.uid('b2'),
                   p_id => pg_temp.id('a002'))$$,
  'for someone else it goes');
reset role;
select is((select count(*) from public.space_posts where id = pg_temp.id('a002')), 1::bigint,
  'and only that one was made');
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.create_work_item(pg_temp.sp(), 'Tray L2', pg_temp.uid('b2'),
                   p_id => pg_temp.id('a003'))$$,
  '22023', 'a work item is for someone else', 'Crew can''t give one to themselves either');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Tray L2', pg_temp.uid('a1'),
                   p_id => pg_temp.id('a003'))$$,
  'but can give one to their Lead');
reset role;

-- 2. Give to and Send back ----------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.reassign_work_item(pg_temp.id('a002'), pg_temp.uid('a1'))$$,
  '22023', 'a work item is for someone else', 'Give to yourself is refused');
reset role;
select is((select owner_id from public.work_items where id = pg_temp.id('a002')), pg_temp.uid('b2'),
  'and it is still for Rakesh');

-- 3. Items already for their author ------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.sign_done(pg_temp.id('a001'), 'Checked the gate')$$,
  'an old item for its author can still be signed as done');
reset role;
select is((select status from public.work_items where id = pg_temp.id('a001')), 'done',
  'and it is Done');
select is((select owner_id from public.work_items where id = pg_temp.id('a001')), pg_temp.uid('a1'),
  'nothing rewrote it');
update public.work_items set title = 'Gate check, north' where id = pg_temp.id('a001');
select is((select title from public.work_items where id = pg_temp.id('a001')), 'Gate check, north',
  'and a change that leaves its owner is fine');

-- 4. A walk and work items from a message -------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.create_walk(pg_temp.sp(), pg_temp.id('b100'), 'Walk, level 4',
                   jsonb_build_array(
                     jsonb_build_object('id', pg_temp.id('b101'), 'line', 'Debris', 'owner', pg_temp.uid('a1'),
                                        'photo', jsonb_build_object('path', 'x/1.jpg'))))$$,
  '22023', 'a work item is for someone else', 'a walk with a line for yourself is refused');
reset role;
select is((select count(*) from public.space_posts where id in (pg_temp.id('b100'), pg_temp.id('b101'))),
  0::bigint, 'and none of the walk was made');

select pg_temp.as_user('a1');
set local role authenticated;
select public.post_message(pg_temp.id('c201'),
  (select t.id from public.threads t where t.space_id = pg_temp.sp() and t.team_id is null),
  'Meeting 10:00');
select throws_ok($$select public.create_from_message(pg_temp.sp(), pg_temp.id('c201'), pg_temp.id('c300'),
                   'Meeting', jsonb_build_array(
                     jsonb_build_object('id', pg_temp.id('c301'), 'text', 'Sleeves', 'owner', pg_temp.uid('b2')),
                     jsonb_build_object('id', pg_temp.id('c302'), 'text', 'Trays', 'owner', pg_temp.uid('a1'))))$$,
  '22023', 'a work item is for someone else', 'work items from a message: a line for yourself is refused');
select lives_ok($$select public.create_from_message(pg_temp.sp(), pg_temp.id('c201'), pg_temp.id('c300'),
                   'Meeting', jsonb_build_array(
                     jsonb_build_object('id', pg_temp.id('c301'), 'text', 'Sleeves', 'owner', pg_temp.uid('b2'))))$$,
  'with every line for someone else it goes');
reset role;
select is((select owner_id from public.work_items where id = pg_temp.id('c300')), pg_temp.uid('a1'),
  'its parent, which holds the lines, is still its author''s');
select is((select owner_id from public.work_items where id = pg_temp.id('c301')), pg_temp.uid('b2'),
  'and its line is Rakesh''s');

-- 5. The notebook share -------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select public.save_entry(pg_temp.id('e100'), 'text', p_title => 'Pour check');
select throws_ok($$select public.share_note_to_space(pg_temp.id('e100'), pg_temp.id('e200'), pg_temp.sp(),
                   'work_item', p_owner => pg_temp.uid('a1'))$$,
  '22023', 'a work item is for someone else', 'a note put in as a work item for yourself is refused');
select lives_ok($$select public.share_note_to_space(pg_temp.id('e100'), pg_temp.id('e200'), pg_temp.sp(),
                   'work_item', p_owner => pg_temp.uid('b2'))$$,
  'for someone else it goes');
select lives_ok($$select public.share_note_to_space(pg_temp.id('e100'), pg_temp.id('e201'), pg_temp.sp(),
                   'note')$$,
  'and as a note it needs nobody');
reset role;

-- 6. Post later --------------------------------------------------------------------------------------

select has_function('public', 'scheduled_not_for_self', 'the rule when scheduling');
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok(format($q$select public.schedule_post(%L, 'create_work_item', %L::jsonb,
                   now() + interval '1 hour', 'Later for me')$q$,
                   pg_temp.id('d100'),
                   jsonb_build_object('p_space', pg_temp.sp(), 'p_title', 'Later for me',
                                      'p_owner', pg_temp.uid('a1'), 'p_id', pg_temp.id('d100'))),
  '22023', 'a work item is for someone else', 'a work item scheduled for yourself is refused');
select throws_ok(format($q$select public.schedule_post(%L, 'share_note_to_space', %L::jsonb,
                   now() + interval '1 hour', 'Pour check')$q$,
                   pg_temp.id('d101'),
                   jsonb_build_object('p_note', pg_temp.id('e100'), 'p_post', pg_temp.id('d101'),
                                      'p_space', pg_temp.sp(), 'p_kind', 'work_item',
                                      'p_owner', pg_temp.uid('a1'))),
  '22023', 'a work item is for someone else', 'so is a note scheduled as a work item for yourself');
select lives_ok(format($q$select public.schedule_post(%L, 'create_work_item', %L::jsonb,
                   now() + interval '1 hour', 'Later for Rakesh')$q$,
                   pg_temp.id('d102'),
                   jsonb_build_object('p_space', pg_temp.sp(), 'p_title', 'Later for Rakesh',
                                      'p_owner', pg_temp.uid('b2'), 'p_id', pg_temp.id('d102'))),
  'for someone else it is scheduled');
reset role;
-- One that slipped in before the rule: when it goes out, it is refused, not made.
set local session_replication_role = replica;
insert into public.scheduled_posts (id, author_id, fn, params, space_id, title, publish_at)
values (pg_temp.id('d103'), pg_temp.uid('a1'), 'create_work_item',
        jsonb_build_object('p_space', pg_temp.sp(), 'p_title', 'Old later', 'p_owner', pg_temp.uid('a1'),
                           'p_id', pg_temp.id('d103')),
        pg_temp.sp(), 'Old later', now() + interval '1 hour');
set local session_replication_role = origin;
select is(public.publish_scheduled((select s from public.scheduled_posts s where s.id = pg_temp.id('d103'))),
  false, 'an old one for yourself does not go out');
select is((select state || ':' || error from public.scheduled_posts where id = pg_temp.id('d103')),
  'failed:not_valid', 'it says why');
select is((select count(*) from public.space_posts where id = pg_temp.id('d103')), 0::bigint,
  'and nothing was made');

-- 7. my_postable_spaces --------------------------------------------------------------------------------

select ok(not has_function_privilege('anon', 'public.my_postable_spaces()', 'execute'),
  'only signed-in people call my_postable_spaces');
-- Omar posted in Yard after Tower: Yard comes first; Depot (no post) last.
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.yard(), pg_temp.uid('e5'), 'crew', pg_temp.uid('a1'));
select pg_temp.as_user('a1');
set local role authenticated;
select public.create_work_item(pg_temp.yard(), 'Fence line', pg_temp.uid('e5'), p_id => pg_temp.id('f001'));
reset role;
update public.space_posts set created_at = now() + interval '1 minute' where id = pg_temp.id('f001');
select is(pg_temp.postable('a1'), array['Yard', 'Tower', 'Depot'],
  'my Spaces, the one I posted in last first, then the rest');
select is(pg_temp.postable('b2'), array['Tower'],
  'Crew: the Space where they may give work; not Depot, where they are a Viewer');
select is(pg_temp.postable('c3'), '{}'::text[], 'a Viewer: none');
select is(pg_temp.postable('d4'), '{}'::text[], 'someone who left: none');
select is(pg_temp.postable('e5'), array['Yard'], 'someone else: only their own Space, never Omar''s others');
select pg_temp.as_user('a1');
set local role authenticated;
select is((select pass || ':' || is_admin from public.my_postable_spaces() where space_id = pg_temp.sp()),
  'lead:true', 'with my pass and whether I am its admin');
reset role;

-- 8. A handover is not "for yourself" -------------------------------------------------------------------

-- Review 105B L1: a removed member's open work goes to the admin first.
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp(), pg_temp.uid('e5'), 'crew', pg_temp.uid('a1'));
select pg_temp.as_user('a1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Rails at L5', pg_temp.uid('e5'), p_id => pg_temp.id('f002'));
select lives_ok(format($q$select public.remove_member_with_handover(%L, %L,
                   jsonb_build_array(jsonb_build_object('item', %L, 'owner', %L)))$q$,
                   pg_temp.sp(), pg_temp.uid('e5'), pg_temp.id('f002'), pg_temp.uid('a1')),
  'removing Eve, the admin may take her open work');
reset role;
select is((select owner_id from public.work_items where id = pg_temp.id('f002')), pg_temp.uid('a1'),
  'and it is his now');
select set_config('request.jwt.claims', '', true);
select is((select count(*) from public.my_postable_spaces()), 0::bigint,
  'with no one signed in: nothing');
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('b2');
select is(pg_temp.postable('b2'), '{}'::text[], 'a hidden account: none');

select * from finish();
rollback;
