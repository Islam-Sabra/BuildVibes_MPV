-- Migration 15: safety. Run with: supabase test db
--
-- Omar (c1) posts and writes in chat. Rakesh (c2) reports. Sara (c3) sees
-- everything else. All three are in one Space. Bob (c4) is outside it;
-- Omar blocks him.

begin;
create extension if not exists pgtap with schema extensions;
select plan(60);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000015c1', 'authenticated', 'authenticated', 'omar15@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000015c2', 'authenticated', 'authenticated', 'rakesh15@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000015c3', 'authenticated', 'authenticated', 'sara15@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000015c4', 'authenticated', 'authenticated', 'bob15@example.com', '{"home_market_id": "kw"}');
update public.profiles set first_name = 'Omar', last_name = 'Haddad' where id = '00000000-0000-0000-0000-0000000015c1';
update public.profiles set first_name = 'Sara', last_name = 'Ali' where id = '00000000-0000-0000-0000-0000000015c3';

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000015' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000015' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000015' || p)::uuid;
$$;

select ok((select relrowsecurity from pg_class where oid = 'public.reports'::regclass),
  'reports has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.content_removals'::regclass),
  'content_removals has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.removed_content'::regclass),
  'removed_content has row-level security');
select has_column('public', 'markets', 'moderation_email', 'the market pack has a moderation address');

-- Setting up: a Space, a post, a reply, a message --------------------------------------

select pg_temp.as_user('c1');
set local role authenticated;
select set_config('test.space', public.create_space('Site team', null, null)::text, true);
select public.create_post(pg_temp.id('a001'), 'Slab poured on level 3.', 'en');
select public.create_post(pg_temp.id('a002'), 'Second post.', 'en');
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (current_setting('test.space')::uuid, pg_temp.uid('c2'), 'crew', pg_temp.uid('c1')),
  (current_setting('test.space')::uuid, pg_temp.uid('c3'), 'lead', pg_temp.uid('c1'));
select set_config('test.thread', (select id from public.threads
  where space_id = current_setting('test.space')::uuid and team_id is null)::text, true);
select pg_temp.as_user('c3');
set local role authenticated;
select public.add_reply(pg_temp.id('d001'), pg_temp.id('a001'), null, 'Well done.');
select public.add_reply(pg_temp.id('d002'), pg_temp.id('a002'), null, 'Agreed.');
reset role;
select pg_temp.as_user('c1');
set local role authenticated;
select public.post_message(pg_temp.id('e001'), current_setting('test.thread')::uuid, 'Concrete at 7.');
reset role;

-- Reporting ------------------------------------------------------------------------------

select pg_temp.as_user('c2');
set local role authenticated;
select set_config('test.report', public.report('post', pg_temp.id('a001'), 'spam')::text, true);
select is((select count(*) from public.posts where id = pg_temp.id('a001')), 0::bigint,
  'a reported post is hidden for the reporter at once');
select is((select count(*) from public.post_cards where id = pg_temp.id('a001')), 0::bigint,
  'and its card');
select is((select count(*) from public.post_replies where post_id = pg_temp.id('a001')), 0::bigint,
  'and its replies');
select is(public.report('post', pg_temp.id('a001'), 'harassment'), current_setting('test.report')::uuid,
  'reporting it again is the same report');
select is((select count(*) from public.posts where id = pg_temp.id('a002')), 1::bigint,
  'the author''s other posts still show');
reset role;
select is((select count(*) from public.reports where target_id = pg_temp.id('a001')), 1::bigint,
  'one report per person and thing');
select pg_temp.as_user('c3');
set local role authenticated;
select is((select count(*) from public.post_cards where id = pg_temp.id('a001')), 1::bigint,
  'everyone else still sees it');
reset role;

select pg_temp.as_user('c2');
set local role authenticated;
select lives_ok(format($q$select public.report('reply', %L, 'harassment')$q$, pg_temp.id('d002')),
  'a reply can be reported');
select lives_ok(format($q$select public.report('message', %L, 'inappropriate_content')$q$, pg_temp.id('e001')),
  'a chat message can be reported');
select is((select count(*) from public.messages where id = pg_temp.id('e001')), 0::bigint,
  'a reported message is hidden for the reporter');
select ok((select coalesce(last_message_id <> pg_temp.id('e001'), true)
           from public.space_threads(current_setting('test.space')::uuid) where team_id is null),
  'and is not the last message in the thread list');
select lives_ok(format($q$select public.report('profile', %L, 'scam_or_misleading', 'Asks for money.')$q$,
  pg_temp.uid('c1')), 'a person can be reported');
select is((select count(*) from public.profiles where id = pg_temp.uid('c1')), 1::bigint,
  'a reported person''s profile still shows');
select throws_ok(format($q$select public.report('post', %L, 'other')$q$, pg_temp.id('a002')),
  '22023', null, '"Something else" needs a few words');
select throws_ok(format($q$select public.report('post', %L, 'other', %L)$q$, pg_temp.id('a002'), repeat('x', 501)),
  '22023', null, 'at most 500 characters');
select throws_ok(format($q$select public.report('post', %L, 'boring')$q$, pg_temp.id('a002')),
  '22023', null, 'only the six reasons');
select throws_ok($$select count(*) from public.reports$$, '42501', null,
  'nobody reads reports in the app');
reset role;

select pg_temp.as_user('c3');
set local role authenticated;
select is((select count(*) from public.messages where id = pg_temp.id('e001')), 1::bigint,
  'others still see the reported message');
reset role;

select pg_temp.as_user('c1');
set local role authenticated;
select throws_ok(format($q$select public.report('post', %L, 'spam')$q$, pg_temp.id('a002')),
  '22023', null, 'you can''t report your own');
select throws_ok($$select count(*) from public.reports$$, '42501', null,
  'the reported person can''t read reports');
select public.block(pg_temp.uid('c4'), true);
reset role;
select pg_temp.as_user('c4');
set local role authenticated;
select throws_ok(format($q$select public.report('post', %L, 'spam')$q$, pg_temp.id('a002')),
  '42501', null, 'you can''t report what you can''t see (blocked)');
select throws_ok(format($q$select public.report('message', %L, 'spam')$q$, pg_temp.id('e001')),
  '42501', null, 'or a message in a Space you''re not in');
select throws_ok(format($q$select public.report('post', %L, 'spam')$q$, gen_random_uuid()),
  '42501', null, 'or something that isn''t there');
reset role;

-- 20 a day.
insert into public.reports (reporter_id, target_kind, target_id, reason)
select pg_temp.uid('c3'), 'profile', gen_random_uuid(), 'spam' from generate_series(1, 20);
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok(format($q$select public.report('post', %L, 'spam')$q$, pg_temp.id('a002')),
  'P0001', null, 'at most 20 reports a day');
reset role;

-- The alert: ids and reasons only, to the market's address --------------------------------

update public.markets set moderation_email = 'moderation@example.com' where id = 'kw';
set local role service_role;
select is((select format('%s %s %s', target_kind, reason, moderation_email)
           from public.report_alert(current_setting('test.report')::uuid)),
  'post spam moderation@example.com', 'the alert: kind, reason, and the market''s address');
reset role;
select pg_temp.as_user('c2');
set local role authenticated;
select throws_ok(format($q$select * from public.report_alert(%L)$q$, current_setting('test.report')),
  '42501', null, 'the app can''t read an alert');
reset role;

-- Deciding: the service role only --------------------------------------------------------

select pg_temp.as_user('c2');
set local role authenticated;
select throws_ok(format($q$select public.decide_report(%L, 'remove')$q$, current_setting('test.report')),
  '42501', null, 'the app can''t decide a report');
reset role;

set local role service_role;
select set_config('test.removal',
  public.decide_report(current_setting('test.report')::uuid, 'remove')::text, true);
reset role;
select ok(current_setting('test.removal') <> '', 'removing writes a removal');
select is((select status from public.reports where id = current_setting('test.report')::uuid),
  'removed', 'and decides the report');
select pg_temp.as_user('c3');
set local role authenticated;
select is((select count(*) from public.post_cards where id = pg_temp.id('a001')), 0::bigint,
  'a removed post is gone for everyone');
select is((select count(*) from public.content_removals), 0::bigint,
  'nobody else reads the removal');
select is((select count(*) from public.my_removal(current_setting('test.removal')::uuid)), 0::bigint,
  'or its notice');
select throws_ok(format($q$select public.appeal(%L, 'Mine')$q$, current_setting('test.removal')),
  '42501', null, 'only the author can appeal');
reset role;

select pg_temp.as_user('c1');
set local role authenticated;
select is((select excerpt || ' / ' || reason from public.my_removal(current_setting('test.removal')::uuid)),
  'Slab poured on level 3. / spam', 'the author''s R3 notice: what and why');
select ok((select can_appeal from public.my_removal(current_setting('test.removal')::uuid)),
  'with an appeal still open to them');
select is((select count(*) from public.posts where id = pg_temp.id('a001')), 0::bigint,
  'but the post itself is gone for its author too');
select is((select group_kind || ' ' || (payload ->> 'target_kind')
           from public.my_activity() where kind = 'content_removed'),
  'record post', 'the author hears in Activity, under Your record');
select throws_ok(format($q$select public.appeal(%L, '  ')$q$, current_setting('test.removal')),
  '22023', null, 'an appeal says why');
select lives_ok(format($q$select public.appeal(%L, 'It was a site update, not spam.')$q$,
  current_setting('test.removal')), 'the author appeals');
select throws_ok(format($q$select public.appeal(%L, 'Again')$q$, current_setting('test.removal')),
  'P0001', null, 'once');
reset role;

set local role service_role;
select public.decide_appeal(current_setting('test.removal')::uuid, 'reverse');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select is((select body from public.post_cards where id = pg_temp.id('a001')),
  'Slab poured on level 3.', 'reversed: the post is back as it was');
reset role;
select pg_temp.as_user('c1');
set local role authenticated;
select is((select payload ->> 'result' from public.my_activity() where kind = 'appeal_decided'),
  'reversed', 'and the author hears');
reset role;
set local role service_role;
select throws_ok(format($q$select public.decide_appeal(%L, 'uphold')$q$, current_setting('test.removal')),
  'P0001', null, 'an appeal is decided once');
reset role;

-- The 14 days, and a removed reply.
set local role service_role;
select set_config('test.removal2', public.decide_report(
  (select id from public.reports where target_id = pg_temp.id('d002')), 'remove')::text, true);
reset role;
select pg_temp.as_user('c1');
set local role authenticated;
select is((select count(*) from public.post_replies where id = pg_temp.id('d002')), 0::bigint,
  'a removed reply is gone for everyone');
reset role;
update public.content_removals set removed_at = now() - interval '15 days'
where id = current_setting('test.removal2')::uuid;
select pg_temp.as_user('c3');
set local role authenticated;
select ok(not (select can_appeal from public.my_removal(current_setting('test.removal2')::uuid)),
  'after 14 days R3 offers no appeal');
select throws_ok(format($q$select public.appeal(%L, 'Late')$q$, current_setting('test.removal2')),
  'P0001', null, 'and an appeal is refused');
reset role;

-- A message, dismissed; a person can't be removed.
set local role service_role;
select is(public.decide_report((select id from public.reports where target_id = pg_temp.id('e001')), 'dismiss'),
  null, 'dismissing removes nothing');
select throws_ok(format($q$select public.decide_report(%L, 'remove')$q$,
  (select id from public.reports where target_kind = 'profile' and target_id = pg_temp.uid('c1'))),
  '22023', null, 'a person is not removed');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select is((select count(*) from public.messages where id = pg_temp.id('e001')), 1::bigint,
  'the dismissed message still shows');
reset role;

-- Blocking ------------------------------------------------------------------------------

insert into public.follows (follower_id, followee_id) values (pg_temp.uid('c3'), pg_temp.uid('c1'));
select pg_temp.as_user('c1');
set local role authenticated;
select is((select count(*) from public.my_activity() where actor_id = pg_temp.uid('c3') and kind = 'follow'),
  1::bigint, 'before: Sara''s follow is in Omar''s Activity');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok(format($q$select public.block(%L, true)$q$, pg_temp.uid('c3')),
  '22023', null, 'you can''t block yourself');
select public.block(pg_temp.uid('c1'), true);
select is((select count(*) from public.my_blocks()), 1::bigint, 'S7 lists who you blocked');
select is((select count(*) from public.post_cards where author_id = pg_temp.uid('c1')), 0::bigint,
  'blocked: their posts are gone for you');
reset role;
select pg_temp.as_user('c1');
set local role authenticated;
select is((select count(*) from public.post_cards where author_id = pg_temp.uid('c3')), 0::bigint,
  'and yours for them');
select is((select count(*) from public.my_activity() where actor_id = pg_temp.uid('c3')), 0::bigint,
  'and what you did leaves their Activity');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select public.block(pg_temp.uid('c1'), false);
select is((select count(*) from public.post_cards where author_id = pg_temp.uid('c1')), 2::bigint,
  'unblocked (Undo): their posts are back');
reset role;

select * from finish();
rollback;
