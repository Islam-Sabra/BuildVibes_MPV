-- Migration 13: Activity and the Home Spaces tab. Run with: supabase test db
--
-- Omar (a1) runs the Space (admin, Lead) and raises items. Rakesh (a2) is
-- Crew and owns them. Sara (a3) is Lead and checks. Eve (a4) asks to join
-- and is confirmed. Bob (a5) asks and is declined; Omar blocks him.

begin;
create extension if not exists pgtap with schema extensions;
select plan(51);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000013a1', 'authenticated', 'authenticated', 'omar13@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000013a2', 'authenticated', 'authenticated', 'rakesh13@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000013a3', 'authenticated', 'authenticated', 'sara13@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000013a4', 'authenticated', 'authenticated', 'eve13@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000013a5', 'authenticated', 'authenticated', 'bob13@example.com', '{"home_market_id": "kw"}');
update public.profiles set first_name = 'Omar', last_name = 'Haddad' where id = '00000000-0000-0000-0000-0000000013a1';
update public.profiles set first_name = 'Rakesh', last_name = 'Nair' where id = '00000000-0000-0000-0000-0000000013a2';
update public.profiles set first_name = 'Sara', last_name = 'Ali' where id = '00000000-0000-0000-0000-0000000013a3';

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000013' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000013' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000013' || p)::uuid;
$$;
-- How many [p_kind] rows [p_who] has (run as the test owner).
create function pg_temp.n(p_who text, p_kind text) returns bigint language sql as $$
  select count(*) from public.notifications
  where profile_id = pg_temp.uid(p_who) and kind = p_kind;
$$;

select ok((select relrowsecurity from pg_class where oid = 'public.notifications'::regclass),
  'notifications has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.space_visits'::regclass),
  'space_visits has row-level security');

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.project',
  public.create_project('Kuwait City Tower', 'commercial', 'kw', 'kw-capital')::text, true);
select set_config('test.space',
  public.create_space('Site team', null, current_setting('test.project')::uuid)::text, true);
select set_config('test.code',
  (select code from public.current_invite(current_setting('test.space')::uuid)), true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (current_setting('test.space')::uuid, pg_temp.uid('a2'), 'crew', pg_temp.uid('a1')),
  (current_setting('test.space')::uuid, pg_temp.uid('a3'), 'lead', pg_temp.uid('a1'));

-- Work items -----------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select public.create_work_item(current_setting('test.space')::uuid, 'Rebar on grid C7',
  pg_temp.uid('a2'), p_id => pg_temp.item('c001'));
select public.create_work_item(current_setting('test.space')::uuid, 'Order formwork',
  pg_temp.uid('a1'), p_id => pg_temp.item('c002'));
reset role;
select is(pg_temp.n('a2', 'item_assigned'), 1::bigint, 'an item raised for Rakesh reaches him');
select is((select count(*) from public.notifications where profile_id = pg_temp.uid('a1')), 0::bigint,
  'raising an item for yourself makes nothing');

select pg_temp.as_user('a2');
set local role authenticated;
select public.sign_done(pg_temp.item('c001'), 'Rebar fixed and tied.', '[]');
reset role;
select is(pg_temp.n('a1', 'item_done'), 1::bigint, 'signed as done: its creator hears');

select pg_temp.as_user('a3');
set local role authenticated;
select public.check_item(pg_temp.item('c001'));
reset role;
select is(pg_temp.n('a2', 'item_checked'), 1::bigint, 'checked: its owner hears');

select pg_temp.as_user('a1');
set local role authenticated;
select public.create_work_item(current_setting('test.space')::uuid, 'Upstand north wall',
  pg_temp.uid('a2'), p_id => pg_temp.item('c003'));
reset role;
select pg_temp.as_user('a2');
set local role authenticated;
select public.sign_done(pg_temp.item('c003'), 'Done.', '[]');
reset role;
select pg_temp.as_user('a3');
set local role authenticated;
select public.send_back(pg_temp.item('c003'), 'photo_missing', 'Add a photo.');
select public.add_comment(pg_temp.item('c003'), 'The north side too, please.');
reset role;
select is((select payload ->> 'reason' from public.notifications
           where profile_id = pg_temp.uid('a2') and kind = 'item_sent_back'),
  'photo_missing', 'sent back: its owner hears, with the reason');
select is(pg_temp.n('a2', 'item_comment'), 1::bigint, 'a comment reaches the owner');
select is(pg_temp.n('a1', 'item_comment'), 1::bigint, 'and the creator');

select pg_temp.as_user('a2');
set local role authenticated;
select public.add_comment(pg_temp.item('c003'), 'Photo coming.');
reset role;
select is(pg_temp.n('a2', 'item_comment'), 1::bigint, 'never to the one who commented');
select is(pg_temp.n('a1', 'item_comment'), 2::bigint, 'the creator hears the owner''s comment');

select pg_temp.as_user('a1');
set local role authenticated;
select public.reassign_work_item(pg_temp.item('c003'), pg_temp.uid('a3'));
reset role;
select is(pg_temp.n('a3', 'item_assigned'), 1::bigint, 'reassigned: the new owner hears');

-- Join requests --------------------------------------------------------------------------

select pg_temp.as_user('a4');
set local role authenticated;
select public.request_join(current_setting('test.code'));
select set_config('test.eve_request',
  (select request_id from public.my_join_requests() limit 1)::text, true);
reset role;
select is(pg_temp.n('a1', 'join_request'), 1::bigint, 'a request to join reaches the admin');
select is(pg_temp.n('a2', 'join_request'), 0::bigint, 'but not a member who isn''t admin');

select pg_temp.as_user('a1');
set local role authenticated;
select public.confirm_join(current_setting('test.eve_request')::uuid, 'crew');
reset role;
select is((select actor_id from public.notifications
           where profile_id = pg_temp.uid('a4') and kind = 'join_confirmed'),
  pg_temp.uid('a1'), 'confirmed: the new member hears, from the admin');

select pg_temp.as_user('a5');
set local role authenticated;
select public.request_join(current_setting('test.code'));
select set_config('test.bob_request',
  (select request_id from public.my_join_requests() limit 1)::text, true);
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select public.decline_join(current_setting('test.bob_request')::uuid);
reset role;
select is((select count(*) from public.notifications where profile_id = pg_temp.uid('a5')), 0::bigint,
  'declined: no notification');

-- Network --------------------------------------------------------------------------------

insert into public.follows (follower_id, followee_id) values (pg_temp.uid('a2'), pg_temp.uid('a1'));
select is(pg_temp.n('a1', 'follow'), 1::bigint, 'a new follower is told');
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('a1'), pg_temp.uid('a5'));
insert into public.follows (follower_id, followee_id) values (pg_temp.uid('a5'), pg_temp.uid('a1'));
select is(pg_temp.n('a1', 'follow'), 1::bigint, 'never across a block');

-- Posts ----------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select public.create_post(pg_temp.item('b001'), 'Slab poured on level 3.', 'en');
reset role;
select pg_temp.as_user('a2');
set local role authenticated;
select public.add_reply(pg_temp.item('d001'), pg_temp.item('b001'), null, 'Nice work.');
reset role;
select is(pg_temp.n('a1', 'post_reply'), 1::bigint, 'a reply reaches the post''s author');
select pg_temp.as_user('a3');
set local role authenticated;
select public.add_reply(pg_temp.item('d002'), pg_temp.item('b001'), pg_temp.item('d001'), 'Agreed.');
reset role;
select is(pg_temp.n('a1', 'post_reply'), 2::bigint, 'a reply to a reply: the post''s author');
select is((select payload ->> 'to' from public.notifications
           where profile_id = pg_temp.uid('a2') and kind = 'post_reply'),
  'reply', 'and the author of the reply it answers');
select pg_temp.as_user('a1');
set local role authenticated;
select public.add_reply(pg_temp.item('d003'), pg_temp.item('b001'), pg_temp.item('d001'), 'Thanks.');
reset role;
select is(pg_temp.n('a2', 'post_reply'), 2::bigint, 'the author answering a reply: its writer hears');
select is(pg_temp.n('a1', 'post_reply'), 2::bigint, 'and the author is not told of their own reply');

select pg_temp.as_user('a2');
set local role authenticated;
select public.mark_useful('post', pg_temp.item('b001'), true);
reset role;
select pg_temp.as_user('a3');
set local role authenticated;
select public.mark_useful('post', pg_temp.item('b001'), true);
reset role;
select is(pg_temp.n('a1', 'post_useful'), 1::bigint, 'Useful: one row per post per day, not one per mark');
select is((select actor_id from public.notifications
           where profile_id = pg_temp.uid('a1') and kind = 'post_useful'),
  pg_temp.uid('a3'), 'showing the latest person');
select pg_temp.as_user('a1');
set local role authenticated;
select public.mark_useful('reply', pg_temp.item('d001'), true);
reset role;
select is(pg_temp.n('a2', 'post_useful'), 0::bigint, 'Useful on a reply makes no row');

-- Your record ----------------------------------------------------------------------------

insert into public.cv_projects (id, profile_id, project_id, role_title) values
  ('00000000-0000-0000-0000-0000000013c1', pg_temp.uid('a1'), current_setting('test.project')::uuid, 'Site engineer');
insert into public.cv_project_confirmations (cv_project_id, confirmed_by, source)
values ('00000000-0000-0000-0000-0000000013c1', pg_temp.uid('a2'), 'teammate');
select is(pg_temp.n('a1', 'role_confirmed'), 1::bigint, 'a confirmed role is told');

-- Only your own --------------------------------------------------------------------------

select pg_temp.as_user('a2');
set local role authenticated;
select is((select count(*) from public.notifications where profile_id <> pg_temp.uid('a2')), 0::bigint,
  'nobody reads another person''s notifications');
select is((select count(*) from public.my_activity() a
           join public.notifications n on n.id = a.id where n.profile_id <> pg_temp.uid('a2')), 0::bigint,
  'and my_activity is only your own');
select throws_ok(format($q$insert into public.notifications (profile_id, kind, actor_id) values (%L, 'follow', %L)$q$,
  pg_temp.uid('a2'), pg_temp.uid('a1')), '42501', null, 'the app can''t write a notification');
select throws_ok($$update public.notifications set read_at = now()$$, '42501', null,
  'or change one');
select throws_ok(format($q$select public.add_notification(%L, 'follow', %L)$q$,
  pg_temp.uid('a2'), pg_temp.uid('a1')), '42501', null, 'or call the writer');
select throws_ok(format($q$select public.blocked_between(%L, %L)$q$,
  pg_temp.uid('a1'), pg_temp.uid('a5')), '42501', null, 'nobody asks who blocked whom');
reset role;

-- Activity -------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select is((select distinct group_kind || ' ' || space_name || ' ' || my_pass from public.my_activity()
           where kind = 'item_done'),
  'space Site team lead', 'a work item row: in its Space''s group, with your pass');
select is((select group_kind || ' ' || project_name from public.my_activity() where kind = 'role_confirmed'),
  'record Kuwait City Tower', 'a confirmed role: Your record, with the project');
select is((select group_kind || ' ' || actor_name from public.my_activity() where kind = 'follow'),
  'network Rakesh Nair', 'a follower: Your network');
select is((select array_agg(distinct group_kind) from public.my_activity() where post_id is not null),
  array['posts'], 'replies and Useful: Your posts');
select is((select array_agg(seq order by seq) from public.my_activity() where group_kind = 'space'),
  (select array_agg(g) from generate_series(1,
    (select count(*)::int from public.my_activity() where group_kind = 'space')) g),
  'each group''s rows run 1, 2, 3… (A, B, C…)');
select ok(public.unread_activity(), 'unread: the dot shows');
select public.mark_activity_read();
select ok(not public.unread_activity(), 'opening Activity clears it');
reset role;

-- Home -----------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select public.post_message(gen_random_uuid(),
  (select id from public.threads where space_id = current_setting('test.space')::uuid and team_id is null),
  'Morning all.');
reset role;
select pg_temp.as_user('a2');
set local role authenticated;
select public.post_message('00000000-0000-0000-0000-0000000013e1',
  (select id from public.threads where space_id = current_setting('test.space')::uuid and team_id is null),
  'Concrete arrives at 7.');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select public.post_message(gen_random_uuid(),
  (select id from public.threads where space_id = current_setting('test.space')::uuid and team_id is null),
  'Thanks.', '00000000-0000-0000-0000-0000000013e1');
reset role;

select pg_temp.as_user('a2');
set local role authenticated;
select is((select needs_you from public.home_day(now() - interval '1 hour')),
  (select count(*)::int from public.needs_you()), 'the header counts what needs you');
select is((select active_spaces from public.home_day(now() - interval '1 hour')), 1,
  'and Spaces with something new today');
select is((select replies from public.home_day(now() - interval '1 hour')), 1,
  'and replies to your chat messages today');
select is((select change from public.today_in_spaces(now() - interval '1 hour')), 'work_item',
  'a work item event comes before a chat message');
select public.mark_space_seen(current_setting('test.space')::uuid);
select is((select active_spaces from public.home_day(now() - interval '1 hour')), 0,
  'opening the Space marks it seen');
reset role;
select pg_temp.as_user('a5');
set local role authenticated;
select throws_ok(format($q$select public.mark_space_seen(%L)$q$, current_setting('test.space')),
  '42501', null, 'only a member marks a Space seen');
select is((select count(*) from public.space_visits), 0::bigint, 'and nobody reads another''s visits');
reset role;
select is(public.day_start(now() - interval '10 days'), now() - interval '2 days',
  'the day starts at most two days back');

-- Rows drop out --------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select public.delete_post(pg_temp.item('b001'));
select is((select count(*) from public.my_activity() where post_id is not null), 0::bigint,
  'a deleted post takes its rows away');
reset role;
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('a1'), pg_temp.uid('a2'));
select pg_temp.as_user('a1');
set local role authenticated;
select is((select count(*) from public.my_activity() where actor_id = pg_temp.uid('a2')), 0::bigint,
  'blocking someone hides what they did');
reset role;
select pg_temp.as_user('a4');
set local role authenticated;
select public.leave_space(current_setting('test.space')::uuid);
select is((select count(*) from public.my_activity() where kind = 'join_confirmed'), 0::bigint,
  'a Space you left leaves your Activity');
reset role;

select * from finish();
rollback;
