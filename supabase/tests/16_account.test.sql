-- Migration 16: account. Run with: supabase test db
--
-- Omar (c1) runs a Space with Rakesh (c2) in it, posts, and asks to delete
-- his account. Sara (c3) follows him from outside the Space. Bob (c4) asks
-- for nothing.

begin;
create extension if not exists pgtap with schema extensions;
select plan(63);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000016c1', 'authenticated', 'authenticated', 'omar16@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000016c2', 'authenticated', 'authenticated', 'rakesh16@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000016c3', 'authenticated', 'authenticated', 'sara16@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000016c4', 'authenticated', 'authenticated', 'bob16@example.com', '{"home_market_id": "kw"}');
update public.profiles set first_name = 'Omar', last_name = 'Haddad' where id = '00000000-0000-0000-0000-0000000016c1';

-- [p_code_age]: seconds since the sign-in code was entered; null for none.
create function pg_temp.as_user(p_id text, p_code_age int default null) returns void language sql as $$
  select set_config('request.jwt.claims', jsonb_build_object(
    'sub', '00000000-0000-0000-0000-0000000016' || p_id,
    'role', 'authenticated',
    'amr', case when p_code_age is null then '[]'::jsonb
                else jsonb_build_array(jsonb_build_object(
                  'method', 'otp',
                  'timestamp', extract(epoch from now())::bigint - p_code_age)) end)::text, true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000016' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000016' || p)::uuid;
$$;

select ok((select relrowsecurity from pg_class where oid = 'public.data_requests'::regclass),
  'data_requests has row-level security');
select ok(not has_function_privilege('anon', 'public.request_account_deletion()', 'execute'),
  'anon can''t ask to delete an account');
select ok(not has_function_privilege('authenticated', 'public.purge_account(uuid)', 'execute'),
  'a signed-in person can''t purge an account');
select ok(not has_function_privilege('authenticated', 'public.accounts_due_for_purge()', 'execute'),
  'or list the accounts due');
select ok(not has_function_privilege('authenticated', 'public.export_my_data(uuid)', 'execute'),
  'or export anyone''s data');
select ok(not has_function_privilege('authenticated', 'public.mark_data_sent(uuid)', 'execute'),
  'or mark a request sent');
select ok(not has_function_privilege('authenticated', 'public.prune_reports()', 'execute'),
  'or prune reports');
select ok(not has_function_privilege('authenticated', 'public.is_hidden_account(uuid)', 'execute'),
  'or ask whether someone is hidden');

-- Setting up: a Space, a message, a post, a follow, a phone ------------------------------

select pg_temp.as_user('c1');
set local role authenticated;
select set_config('test.space', public.create_space('Site team', null, null)::text, true);
select public.create_post(pg_temp.id('a001'), 'Slab poured on level 3.', 'en');
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (current_setting('test.space')::uuid, pg_temp.uid('c2'), 'lead', pg_temp.uid('c1'));
select set_config('test.thread', (select id from public.threads
  where space_id = current_setting('test.space')::uuid and team_id is null)::text, true);
select set_config('test.code',
  (public.new_invite(current_setting('test.space')::uuid, pg_temp.uid('c1'))).code, true);
insert into public.follows (follower_id, followee_id) values (pg_temp.uid('c3'), pg_temp.uid('c1'));
insert into public.push_tokens (token, profile_id, platform)
values ('omar16-phone-token-0000000000', pg_temp.uid('c1'), 'android');
select pg_temp.as_user('c1');
set local role authenticated;
select public.post_message(pg_temp.id('e001'), current_setting('test.thread')::uuid, 'Concrete at 7.');
reset role;

-- Asking to delete -----------------------------------------------------------------------

select pg_temp.as_user('c1');
set local role authenticated;
select throws_ok($$select public.request_account_deletion()$$, '42501', null,
  'S13: no sign-in code in this session, no deletion');
reset role;
select pg_temp.as_user('c1', 900);
set local role authenticated;
select throws_ok($$select public.request_account_deletion()$$, '42501', null,
  'a code from 15 minutes ago is too old');
reset role;
select pg_temp.as_user('c1', 60);
set local role authenticated;
select ok(public.signed_in_recently(), 'a code from a minute ago is fresh');
select results_eq($$select space_name from public.account_deletion_blockers()$$,
  $$values ('Site team'::text)$$,
  'S12b: the only admin of a Space with others in it');
select throws_ok($$select public.request_account_deletion()$$, 'P0001', null,
  'and can''t delete until it''s transferred');
select is(public.my_account_deletion(), null, 'nothing scheduled yet');
reset role;

-- A Space with only you in it is no blocker.
select pg_temp.as_user('c4');
set local role authenticated;
select public.create_space('Bob alone', null, null);
select is((select count(*) from public.account_deletion_blockers()), 0::bigint,
  'a Space with only you in it doesn''t block');
reset role;

select pg_temp.as_user('c1', 60);
set local role authenticated;
select public.transfer_ownership(current_setting('test.space')::uuid, pg_temp.uid('c2'));
select is((select count(*) from public.account_deletion_blockers()), 0::bigint,
  'after S15d, nothing blocks');
select ok(public.request_account_deletion() between now() + interval '30 days' - interval '1 minute'
                                                and now() + interval '30 days',
  'S14: gone for good in 30 days');
select ok(public.my_account_deletion() is not null, 'S14 shows the date');
select is((select count(*) from public.profiles where id = pg_temp.uid('c1')), 1::bigint,
  'you still see your own profile');
reset role;
select is((select count(*) from public.push_tokens where profile_id = pg_temp.uid('c1')), 0::bigint,
  'every phone stops getting pushes');

-- Hidden from everyone else ----------------------------------------------------------------

select pg_temp.as_user('c3');
set local role authenticated;
select is((select count(*) from public.profiles where id = pg_temp.uid('c1')), 0::bigint,
  'the profile is hidden');
select is((select count(*) from public.posts where id = pg_temp.id('a001')), 0::bigint,
  'and the posts');
select is((select count(*) from public.post_cards where id = pg_temp.id('a001')), 0::bigint,
  'and the post cards');
select is((select count(*) from public.feed_page(null) where post_id = pg_temp.id('a001')), 0::bigint,
  'and feed pages');
select is((select count(*) from public.follows where followee_id = pg_temp.uid('c1')), 0::bigint,
  'and the follow');
select is((select count(*) from public.posts_by(pg_temp.uid('c1'), null)), 0::bigint,
  'and the profile''s post list');
select is((select invited_by_name from public.invite_preview(current_setting('test.code'))), null,
  'an invite they shared names no one');
select is((select space_name from public.invite_preview(current_setting('test.code'))), 'Site team',
  'but still opens the Space');
reset role;
select ok(public.blocked_between(pg_temp.uid('c3'), pg_temp.uid('c1')),
  'no Activity or pushes to or from them');
select ok(public.blocked_between(pg_temp.uid('c1'), null),
  'even without a second person');

select pg_temp.as_user('c2');
set local role authenticated;
select is((select count(*) from public.messages where id = pg_temp.id('e001')), 1::bigint,
  'in the Space, their messages stay');
select is((select count(*) from public.space_members
           where space_id = current_setting('test.space')::uuid and profile_id = pg_temp.uid('c1')),
  1::bigint, 'and their membership, for the record');
select is((select count(*) from public.profiles where id = pg_temp.uid('c1')), 0::bigint,
  'but the name can''t be read ("Former member")');
reset role;

-- Restoring --------------------------------------------------------------------------------

select pg_temp.as_user('c1');
set local role authenticated;
select lives_ok($$select public.restore_account()$$, 'S14: Restore my account');
select is(public.my_account_deletion(), null, 'nothing scheduled any more');
select throws_ok($$select public.restore_account()$$, 'P0001', null,
  'restoring twice: nothing to restore');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select is((select count(*) from public.profiles where id = pg_temp.uid('c1')), 1::bigint,
  'the profile is back');
select is((select count(*) from public.posts where id = pg_temp.id('a001')), 1::bigint,
  'and the posts');
select is((select count(*) from public.follows where followee_id = pg_temp.uid('c1')), 1::bigint,
  'and the follow');
reset role;

-- After 30 days ------------------------------------------------------------------------------

select pg_temp.as_user('c1', 30);
set local role authenticated;
select public.request_account_deletion();
reset role;
select is((select count(*) from public.accounts_due_for_purge()), 0::bigint,
  'nothing is due before 30 days');
select ok(not public.purge_account(pg_temp.uid('c1')), 'and purge_account refuses it');
select ok(not public.purge_account(pg_temp.uid('c3')), 'or anyone who never asked');

update public.profiles set deletion_scheduled_at = now() - interval '31 days'
where id = pg_temp.uid('c1');
insert into storage.objects (bucket_id, name) values
  ('avatars', '00000000-0000-0000-0000-0000000016c1/me.jpg'),
  ('post-media', '00000000-0000-0000-0000-0000000016c1/' || pg_temp.id('a001') || '/1.jpg'),
  ('avatars', '00000000-0000-0000-0000-0000000016c10/not-his.jpg');
select results_eq(
  $$select bucket, name from public.accounts_due_for_purge() order by bucket$$,
  $$values ('avatars'::text, '00000000-0000-0000-0000-0000000016c1/me.jpg'::text),
           ('post-media', '00000000-0000-0000-0000-0000000016c1/' || pg_temp.id('a001') || '/1.jpg')$$,
  'due: their avatar and post photos, nobody else''s');

select pg_temp.as_user('c1');
set local role authenticated;
select throws_ok($$select public.restore_account()$$, 'P0001', null,
  'after 30 days, it can''t be restored');
reset role;

select ok(public.purge_account(pg_temp.uid('c1')), 'purge_account deletes the user');
select is((select count(*) from public.profiles where id = pg_temp.uid('c1')), 0::bigint,
  'the profile is gone');
select is((select count(*) from public.posts where author_id = pg_temp.uid('c1')), 0::bigint,
  'and the posts');
select is((select author_id from public.messages where id = pg_temp.id('e001')), null,
  'the Space keeps the message, by "Former member"');
select is((select count(*) from public.space_members
           where space_id = current_setting('test.space')::uuid and is_admin and left_at is null),
  1::bigint, 'and still has its admin');

-- Download my data -----------------------------------------------------------------------------

select pg_temp.as_user('c3');
set local role authenticated;
select set_config('test.req', public.request_my_data()::text, true);
select is(public.request_my_data(), current_setting('test.req')::uuid,
  'S10: asking again while one is open gives the same request');
select is((select status from public.data_requests where id = current_setting('test.req')::uuid), 'open',
  'S11: you see your request');
select throws_ok($$insert into public.data_requests (profile_id) values (auth.uid())$$, '42501', null,
  'requests are made only through request_my_data');
reset role;
select pg_temp.as_user('c4');
set local role authenticated;
select is((select count(*) from public.data_requests), 0::bigint,
  'nobody else sees it');
reset role;
set local role anon;
select throws_ok($$select count(*) from public.data_requests$$, '42501', null,
  'and anon can''t read requests');
reset role;

select is(public.export_my_data(current_setting('test.req')::uuid) -> 'profile' ->> 'id',
  pg_temp.uid('c3')::text, 'the export holds the person''s profile');
select is(jsonb_array_length(public.export_my_data(current_setting('test.req')::uuid) -> 'following'), 0,
  'and who they follow (Omar is gone)');
select ok(not (public.export_my_data(current_setting('test.req')::uuid) -> 'profile' ? 'follower_count'),
  'but no counts');
select public.mark_data_sent(current_setting('test.req')::uuid);
select is((select status from public.data_requests where id = current_setting('test.req')::uuid), 'sent',
  'mark_data_sent marks it sent');
select pg_temp.as_user('c3');
set local role authenticated;
select isnt(public.request_my_data(), current_setting('test.req')::uuid,
  'after it''s sent, a new request can be made');
reset role;

-- The market pack, and old reports ----------------------------------------------------------------

select throws_ok($$update public.markets set support_email = 'not an address' where id = 'kw'$$,
  '23514', null, 'support_email must look like an address');
select lives_ok($$update public.markets set support_email = 'help@example.com' where id = 'kw'$$,
  'a real address is taken');

insert into public.reports (id, reporter_id, target_kind, target_id, reason, status, created_at, decided_at) values
  (pg_temp.id('f001'), pg_temp.uid('c3'), 'profile', pg_temp.uid('c2'), 'spam', 'dismissed',
   now() - interval '14 months', now() - interval '13 months'),
  (pg_temp.id('f002'), pg_temp.uid('c3'), 'profile', pg_temp.uid('c4'), 'spam', 'dismissed',
   now() - interval '2 months', now() - interval '1 month'),
  (pg_temp.id('f003'), pg_temp.uid('c4'), 'profile', pg_temp.uid('c2'), 'fake', 'open',
   now() - interval '14 months', null);
select is(public.prune_reports(), 1, 'reports decided over 12 months ago are deleted');
select is((select count(*) from public.reports where id in (pg_temp.id('f002'), pg_temp.id('f003'))),
  2::bigint, 'recent decisions and open reports stay');

select * from finish();
rollback;
