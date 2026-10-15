-- Migration 16: account. Run with: supabase test db
--
-- Omar (c1) runs a Space with Rakesh (c2) in it, posts, and asks to delete
-- his account. Sara (c3) follows him from outside the Space. Bob (c4) asks
-- for nothing. Review 26: Lina (c5) and Karim (c6) are the two admins of a
-- second Space with Nour (c7) in it. Its checks are marked (r26). Review 27
-- (r27): Huda (c8) confirms Rakesh in a second Space on the same project.

begin;
create extension if not exists pgtap with schema extensions;
select plan(110);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000016c1', 'authenticated', 'authenticated', 'omar16@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000016c2', 'authenticated', 'authenticated', 'rakesh16@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000016c3', 'authenticated', 'authenticated', 'sara16@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000016c4', 'authenticated', 'authenticated', 'bob16@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000016c5', 'authenticated', 'authenticated', 'lina16@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000016c6', 'authenticated', 'authenticated', 'karim16@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000016c7', 'authenticated', 'authenticated', 'nour16@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000016c8', 'authenticated', 'authenticated', 'huda16@example.com', '{"home_market_id": "kw"}');
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
-- (r26) One write by the signed-in person into [p_table]; [p_n] keeps ids apart.
create function pg_temp.write(p_table text, p_n text) returns void language plpgsql as $$
declare
  v_me uuid := auth.uid();
  v_space uuid := current_setting('test.space')::uuid;
begin
  case p_table
  when 'posts' then
    insert into public.posts (id, author_id, body, lang) values (pg_temp.id('b00' || p_n), v_me, 'Hi.', 'en');
  when 'post_replies' then
    insert into public.post_replies (id, post_id, author_id, body)
    values (pg_temp.id('d10' || p_n), pg_temp.id('a001'), v_me, 'Hi.');
  when 'messages' then
    insert into public.messages (id, thread_id, space_id, kind, body)
    values (pg_temp.id('e10' || p_n), current_setting('test.thread')::uuid, v_space, 'text', 'Hi.');
  when 'follows' then
    delete from public.follows where follower_id = v_me and followee_id = pg_temp.uid('c4');
    insert into public.follows (follower_id, followee_id) values (v_me, pg_temp.uid('c4'));
  when 'useful_marks' then
    delete from public.useful_marks where profile_id = v_me;
    insert into public.useful_marks (target_kind, target_id, profile_id) values ('post', pg_temp.id('a001'), v_me);
  when 'work_items' then
    -- (migration 18) its space_posts row is made in setup, so this checks the
    -- work_items guard itself.
    insert into public.work_items (id, space_id, number, ref, title)
    values (pg_temp.id('c09' || p_n), v_space, 90 + p_n::int, 'ZZ-09' || p_n, 'Hidden test');
  when 'space_posts' then
    insert into public.space_posts (id, space_id, kind, author_id, title)
    values (pg_temp.id('c19' || p_n), v_space, 'announcement', v_me, 'Hidden test');
  when 'post_edits' then
    insert into public.post_edits (post_id, editor_id, changes)
    values (current_setting('test.item')::uuid, v_me, '{"title": {"from": "a", "to": "b"}}');
  when 'work_item_events' then
    insert into public.work_item_events (work_item_id, actor_id, kind, note)
    values (current_setting('test.item')::uuid, v_me, 'comment', 'Hi.');
  when 'library_files' then
    insert into public.library_files (id, space_id, name, storage_path, mime)
    values (pg_temp.id('f10' || p_n), v_space, 'a.pdf', v_space || '/test' || p_n || '.pdf', 'application/pdf');
  when 'space_join_requests' then
    delete from public.space_join_requests where profile_id = v_me and space_id = current_setting('test.bob_space')::uuid;
    insert into public.space_join_requests (space_id, profile_id, via)
    values (current_setting('test.bob_space')::uuid, v_me, 'code');
  end case;
end;
$$;
create function pg_temp.tables() returns setof text language sql as $$
  values ('posts'), ('post_replies'), ('messages'), ('follows'), ('useful_marks'),
         ('work_items'), ('work_item_events'), ('library_files'), ('space_join_requests'),
         ('space_posts'), ('post_edits');
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
select ok(not has_function_privilege('authenticated', 'public.refuse_hidden_writer()', 'execute'),
  '(r26) the write guard isn''t callable');

-- Setting up: a Space, a message, a post, a follow, a phone ------------------------------

select pg_temp.as_user('c1');
set local role authenticated;
select set_config('test.project',
  public.create_project('Gulf Tower', 'commercial', 'kw', 'kw-capital')::text, true);
select set_config('test.space',
  public.create_space('Site team', null, current_setting('test.project')::uuid)::text, true);
select public.create_post(pg_temp.id('a001'), 'Slab poured on level 3.', 'en');
select public.report('profile', pg_temp.uid('c4'), 'spam');
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (current_setting('test.space')::uuid, pg_temp.uid('c2'), 'lead', pg_temp.uid('c1'));
-- Rakesh adds the project to his CV: the Space confirms it (by Omar).
select pg_temp.as_user('c2');
set local role authenticated;
insert into public.cv_projects (project_id, role_title)
values (current_setting('test.project')::uuid, 'Site engineer');
reset role;
-- (migration 18) every work item is a space_posts row with the same id.
insert into public.space_posts (id, space_id, kind, author_id, title) values
  (pg_temp.id('c080'), current_setting('test.space')::uuid, 'work_item', null, 'Rebar check level 3'),
  (pg_temp.id('c091'), current_setting('test.space')::uuid, 'work_item', null, 'Hidden test'),
  (pg_temp.id('c092'), current_setting('test.space')::uuid, 'work_item', null, 'Hidden test');
insert into public.work_items (id, space_id, number, ref, title)
values (pg_temp.id('c080'), current_setting('test.space')::uuid, 80, 'ZZ-080', 'Rebar check level 3');
select set_config('test.item', (select id from public.work_items where ref = 'ZZ-080')::text, true);
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
select pg_temp.as_user('c2');
set local role authenticated;
select public.post_message(pg_temp.id('e002'), current_setting('test.thread')::uuid, 'Pump booked.');
reset role;
select is((select count(*) from public.cv_project_confirmations k
           join public.cv_projects c on c.id = k.cv_project_id
           where c.profile_id = pg_temp.uid('c2') and k.confirmed_by = pg_temp.uid('c1')),
  1::bigint, '(r26) Rakesh''s project is confirmed by Omar');

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
select set_config('test.bob_space', public.create_space('Bob alone', null, null)::text, true);
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

-- (r26) M2: a hidden account can't write.
select pg_temp.as_user('c1');
select throws_ok(format('select pg_temp.write(%L, %L)', t, '1'), '42501', 'restore your account first',
  format('(r26) while hidden: no write to %s', t))
from pg_temp.tables() t;

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
select pg_temp.as_user('c1');
select lives_ok(format('select pg_temp.write(%L, %L)', t, '2'),
  format('(r26) after restoring: writing to %s works', t))
from pg_temp.tables() t;

-- After 30 days ------------------------------------------------------------------------------

select pg_temp.as_user('c1', 30);
set local role authenticated;
select public.request_account_deletion();
reset role;
select is((select count(*) from public.accounts_due_for_purge()), 0::bigint,
  'nothing is due before 30 days');
select ok(not public.purge_account(pg_temp.uid('c1')), 'and purge_account refuses it');
select ok(not public.purge_account(pg_temp.uid('c3')), 'or anyone who never asked');
-- (r26) L1: restored after the 30 days were nearly up: not purged.
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('c1');
select ok(not public.purge_account(pg_temp.uid('c1')), '(r26) a restored account isn''t purged');

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

select ok(not public.purge_account(pg_temp.uid('c1')),
  '(r26) M4: while their photos remain, the purge waits');
select is((select count(*) from public.profiles where id = pg_temp.uid('c1')), 1::bigint,
  '(r26) and the account stays');
-- The function deletes the photos through the Storage API.
set local storage.allow_delete_query = 'true';
delete from storage.objects where name like '00000000-0000-0000-0000-0000000016c1/%';
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
select is((select count(*) from public.cv_project_confirmations k
           join public.cv_projects c on c.id = k.cv_project_id
           where c.profile_id = pg_temp.uid('c2') and k.confirmed_by is null),
  1::bigint, '(r26) M3: Rakesh''s proof stays, confirmed by "Former member"');
select ok(not public.is_space_proof(current_setting('test.space')::uuid, pg_temp.uid('c2'), null),
  '(r27) R1: no new proof is ever made from a confirmer who is gone');

-- (r27) R1: Huda confirms Rakesh for the same project in a second Space; she
-- is purged after Omar.
select pg_temp.as_user('c8');
set local role authenticated;
select set_config('test.space3',
  public.create_space('Second site', null, current_setting('test.project')::uuid)::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (current_setting('test.space3')::uuid, pg_temp.uid('c2'), 'crew', pg_temp.uid('c8'));
select public.add_space_confirmations(current_setting('test.space3')::uuid);
update public.profiles set deletion_scheduled_at = now() - interval '31 days'
where id = pg_temp.uid('c8');
select ok(public.purge_account(pg_temp.uid('c8')),
  '(r27) R1: a second confirmer''s purge succeeds');
select is((select count(*) from public.cv_project_confirmations k
           join public.cv_projects c on c.id = k.cv_project_id
           where c.profile_id = pg_temp.uid('c2') and k.confirmed_by is null),
  2::bigint, '(r27) and Rakesh keeps both confirmations');
select public.add_space_confirmations(current_setting('test.space')::uuid);
select public.add_space_confirmations(current_setting('test.space3')::uuid);
select is((select count(*) from public.cv_project_confirmations k
           join public.cv_projects c on c.id = k.cv_project_id
           where c.profile_id = pg_temp.uid('c2')),
  2::bigint, '(r27) confirming again adds no duplicates');
select is((select count(*) from public.reports where target_id = pg_temp.uid('c4') and reporter_id is null),
  1::bigint, '(r26) L2: Omar''s report stays');

-- (r26) M1: two admins, one hidden -----------------------------------------------------------

select pg_temp.as_user('c5');
set local role authenticated;
select set_config('test.space2', public.create_space('Two admins', null, null)::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, is_admin, confirmed_by) values
  (current_setting('test.space2')::uuid, pg_temp.uid('c6'), 'lead', true, pg_temp.uid('c5')),
  (current_setting('test.space2')::uuid, pg_temp.uid('c7'), 'crew', false, pg_temp.uid('c5'));
select pg_temp.as_user('c5', 60);
set local role authenticated;
select lives_ok($$select public.request_account_deletion()$$,
  '(r26) Lina may go: Karim is still an admin');
select ok(not public.is_space_admin(current_setting('test.space2')::uuid),
  '(r26) and, hidden, she has no admin rights');
reset role;
select pg_temp.as_user('c6', 60);
set local role authenticated;
select results_eq($$select space_name from public.account_deletion_blockers()$$,
  $$values ('Two admins'::text)$$, '(r26) now Karim is the only admin who counts');
select throws_ok($$select public.request_account_deletion()$$, 'P0001', null,
  '(r26) so he can''t go after her');
select throws_ok(format('select public.leave_space(%L)', current_setting('test.space2')), 'P0001', null,
  '(r26) or leave the Space');
select throws_ok(format('select public.transfer_ownership(%L, %L)', current_setting('test.space2'), pg_temp.uid('c5')),
  'P0001', null, '(r26) or hand it to Lina');
select throws_ok(format('select public.set_member_admin(%L, %L, true)', current_setting('test.space2'), pg_temp.uid('c5')),
  'P0001', null, '(r26) or make her admin');
reset role;
-- Karim's account goes another way (deleted by support): the next admin is
-- Nour, not hidden Lina.
delete from public.space_members
where space_id = current_setting('test.space2')::uuid and profile_id = pg_temp.uid('c6');
select ok((select is_admin from public.space_members
           where space_id = current_setting('test.space2')::uuid and profile_id = pg_temp.uid('c7')),
  '(r26) the handover passes over a hidden admin');

-- (r27) R2: Lina, hidden, is left as the only admin, with Nour in the Space.
update public.space_members set is_admin = false
where space_id = current_setting('test.space2')::uuid and profile_id = pg_temp.uid('c7');
select pg_temp.as_user('c5');
set local role authenticated;
select throws_ok(format('select public.leave_space(%L)', current_setting('test.space2')), 'P0001', null,
  '(r27) R2: a hidden sole admin can''t leave');
reset role;
select is((select count(*) from public.space_members
           where space_id = current_setting('test.space2')::uuid and is_admin and left_at is null),
  1::bigint, '(r27) and the Space keeps its admin');

-- Download my data -----------------------------------------------------------------------------

select pg_temp.as_user('c3');
set local role authenticated;
select public.block(pg_temp.uid('c4'), true);
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
select is(jsonb_array_length(public.export_my_data(current_setting('test.req')::uuid) -> 'blocked'), 1,
  '(r26) L4: and who they blocked');
select ok(public.export_my_data(current_setting('test.req')::uuid)
          ?& array['work_item_notes', 'library_files', 'muted', 'useful_marks', 'reports_made', 'join_requests'],
  '(r26) and their notes, files, mutes, Useful marks, reports and join requests');
select pg_temp.as_user('c2');
set local role authenticated;
select set_config('test.req2', public.request_my_data()::text, true);
reset role;
select ok(public.export_my_data(current_setting('test.req2')::uuid)::text like '%Pump booked.%',
  '(r26) Rakesh''s export holds his message');
select ok(public.export_my_data(current_setting('test.req2')::uuid)::text not like '%Concrete at 7.%',
  '(r26) and nothing written by others');
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
