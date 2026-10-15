-- Migration 14: push notifications. Run with: supabase test db
--
-- Omar (b1) runs the Space (admin, Lead). Rakesh (b2) is Crew, Sara (b3)
-- Lead and in the Team "Steel", Eve (b4) Crew. Bob (b5) is Crew with no
-- phone registered (until the chat checks). Nina (b6) asks to join. Vera
-- (b7) is a Viewer; Leo (b8) is Crew and leaves. Review 21's checks are
-- marked (r21).

begin;
create extension if not exists pgtap with schema extensions;
select plan(59);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000014b1', 'authenticated', 'authenticated', 'omar14@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000014b2', 'authenticated', 'authenticated', 'rakesh14@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000014b3', 'authenticated', 'authenticated', 'sara14@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000014b4', 'authenticated', 'authenticated', 'eve14@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000014b5', 'authenticated', 'authenticated', 'bob14@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000014b6', 'authenticated', 'authenticated', 'nina14@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000014b7', 'authenticated', 'authenticated', 'vera14@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000014b8', 'authenticated', 'authenticated', 'leo14@example.com', '{"home_market_id": "kw"}');

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000014' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000014' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000014' || p)::uuid;
$$;
-- A fake FCM token for [p_who].
create function pg_temp.token(p_who text) returns text language sql as $$
  select 'fcm-token-for-' || p_who || '-0123456789abcdef';
$$;
-- Queued pushes of [p_kind] for [p_who] (run as the test owner).
create function pg_temp.q(p_who text, p_kind text) returns bigint language sql as $$
  select count(*) from public.push_queue
  where profile_id = pg_temp.uid(p_who) and kind = p_kind;
$$;

select ok((select relrowsecurity from pg_class where oid = 'public.push_tokens'::regclass),
  'push_tokens has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.push_settings'::regclass),
  'push_settings has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.push_queue'::regclass),
  'push_queue has row-level security');

select pg_temp.as_user('b1');
set local role authenticated;
select set_config('test.space', public.create_space('Site team', null, null)::text, true);
select set_config('test.code',
  (select code from public.current_invite(current_setting('test.space')::uuid)), true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (current_setting('test.space')::uuid, pg_temp.uid('b2'), 'crew', pg_temp.uid('b1')),
  (current_setting('test.space')::uuid, pg_temp.uid('b3'), 'lead', pg_temp.uid('b1')),
  (current_setting('test.space')::uuid, pg_temp.uid('b4'), 'crew', pg_temp.uid('b1')),
  (current_setting('test.space')::uuid, pg_temp.uid('b5'), 'crew', pg_temp.uid('b1')),
  (current_setting('test.space')::uuid, pg_temp.uid('b7'), 'viewer', pg_temp.uid('b1')),
  (current_setting('test.space')::uuid, pg_temp.uid('b8'), 'crew', pg_temp.uid('b1'));

-- Phones -------------------------------------------------------------------------------

select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok(format($q$select public.register_push_token(%L, 'android', 'ar')$q$, pg_temp.token('b2')),
  'Rakesh registers his phone');
select is((select locale from public.push_tokens), 'ar', 'and sees only his own phone, in Arabic');
select throws_ok($$select public.register_push_token('short', 'android')$$,
  '22023', null, 'a token must look like one');
select throws_ok(format($q$insert into public.push_tokens (token, profile_id, platform) values (%L, %L, 'android')$q$,
  pg_temp.token('x1'), pg_temp.uid('b2')), '42501', null, 'the app can''t write the table');
select throws_ok($$select count(*) from public.push_queue$$, '42501', null,
  'nobody reads the queue but the service role');
reset role;
do $$ begin
  for w in 1..4 loop
    if w <> 2 then
      perform set_config('request.jwt.claims',
        '{"sub": "00000000-0000-0000-0000-0000000014b' || w || '", "role": "authenticated"}', true);
      perform public.register_push_token('fcm-token-for-b' || w || '-0123456789abcdef', 'android', 'en');
    end if;
  end loop;
end $$;
select pg_temp.as_user('b3');
set local role authenticated;
select is((select count(*) from public.push_tokens where profile_id <> pg_temp.uid('b3')), 0::bigint,
  'nobody reads another person''s phones');
select public.register_push_token(pg_temp.token('b2'), 'android', 'en');
reset role;
select is((select profile_id from public.push_tokens where token = pg_temp.token('b2')),
  pg_temp.uid('b3'), 'a phone signed in on another account moves to it');
select pg_temp.as_user('b2');
set local role authenticated;
select public.register_push_token(pg_temp.token('b2'), 'android', 'ar');
select is((select format('%s %s %s', followers, replies, message_text) from public.my_push_settings()),
  't t f', 'S3 defaults: followers and replies on, message text off');
select throws_ok($$select public.set_push_settings(true, null, false)$$, '22023', null,
  'each switch is on or off');
select throws_ok($$select public.prune_push_queue()$$, '42501', null, 'the cleanup is the service role''s');
reset role;

-- Work items follow the Space's level ----------------------------------------------------

select pg_temp.as_user('b1');
set local role authenticated;
select public.create_work_item(current_setting('test.space')::uuid, 'Rebar on grid C7',
  pg_temp.uid('b2'), p_id => pg_temp.id('c001'));
reset role;
select is(pg_temp.q('b2', 'item_assigned'), 1::bigint, 'a work item for Rakesh queues a push');
select ok((select data ? 'work_item_id' and data ? 'space_id' and data::text not like '%Rebar%'
           from public.push_queue where profile_id = pg_temp.uid('b2') and kind = 'item_assigned'),
  'with the ids for the link, never the title');
select is((select count(*) from public.messages
           where space_id = current_setting('test.space')::uuid and kind = 'work_item'), 0::bigint,
  '(m18) a new work item posts no card in chat');
select is((select count(*) from public.push_queue where kind = 'chat_message'), 0::bigint,
  'so it sends no chat push');

select pg_temp.as_user('b2');
set local role authenticated;
select public.set_space_notifications(current_setting('test.space')::uuid, 'needs_you');
reset role;
select pg_temp.as_user('b1');
set local role authenticated;
select public.add_comment(pg_temp.id('c001'), 'Use 16 mm bars.');
reset role;
select is(pg_temp.q('b2', 'item_comment'), 1::bigint, '"Needs you only" still sends work item pushes');

select pg_temp.as_user('b2');
set local role authenticated;
select public.set_space_notifications(current_setting('test.space')::uuid, 'off');
reset role;
select pg_temp.as_user('b1');
set local role authenticated;
select public.create_work_item(current_setting('test.space')::uuid, 'Order formwork',
  pg_temp.uid('b2'), p_id => pg_temp.id('c002'));
select public.create_work_item(current_setting('test.space')::uuid, 'Clear Gate 3',
  pg_temp.uid('b5'), p_id => pg_temp.id('c003'));
reset role;
select is(pg_temp.q('b2', 'item_assigned'), 1::bigint, '"Off": no push from that Space');
select is((select count(*) from public.notifications
           where profile_id = pg_temp.uid('b2') and kind = 'item_assigned'), 2::bigint,
  'but Activity still has it');
select is((select count(*) from public.push_queue where profile_id = pg_temp.uid('b5')), 0::bigint,
  'no phone registered: nothing queued');

-- Requests to join ------------------------------------------------------------------------

select pg_temp.as_user('b6');
set local role authenticated;
do $$
declare
  v uuid;
begin
  for i in 1..3 loop
    v := (public.request_join(current_setting('test.code')) ->> 'request_id')::uuid;
    perform public.cancel_join_request(v);
  end loop;
end $$;
reset role;
select is(pg_temp.q('b1', 'join_request'), 1::bigint,
  'asking and cancelling again and again: one push to the admin');

-- People and posts -----------------------------------------------------------------------

insert into public.follows (follower_id, followee_id) values (pg_temp.uid('b3'), pg_temp.uid('b1'));
select is(pg_temp.q('b1', 'follow'), 1::bigint, 'a new follower: a push');
select pg_temp.as_user('b1');
set local role authenticated;
select public.set_push_settings(false, true, false);
reset role;
insert into public.follows (follower_id, followee_id) values (pg_temp.uid('b4'), pg_temp.uid('b1'));
select is(pg_temp.q('b1', 'follow'), 1::bigint, 'New followers off: no push');

select pg_temp.as_user('b1');
set local role authenticated;
select public.create_post(pg_temp.id('a001'), 'Slab poured on level 3.', 'en');
reset role;
select pg_temp.as_user('b3');
set local role authenticated;
select public.add_reply(pg_temp.id('d001'), pg_temp.id('a001'), null, 'Well done.');
select public.mark_useful('post', pg_temp.id('a001'), true);
reset role;
select is(pg_temp.q('b1', 'post_reply'), 1::bigint, 'a reply to your post: a push');
select is((select count(*) from public.push_queue q
           join public.notifications n on n.id = q.notification_id
           where n.kind = 'post_useful'), 0::bigint, 'Useful: never a push');
select pg_temp.as_user('b1');
set local role authenticated;
select public.set_push_settings(false, false, false);
reset role;
select pg_temp.as_user('b4');
set local role authenticated;
select public.add_reply(pg_temp.id('d002'), pg_temp.id('a001'), null, 'Nice.');
reset role;
select is(pg_temp.q('b1', 'post_reply'), 1::bigint, 'Replies off: no push');

select pg_temp.as_user('b2');
set local role authenticated;
select set_config('test.project',
  public.create_project('Gate 3 car park', 'commercial', 'kw', 'kw-capital')::text, true);
reset role;
insert into public.cv_projects (id, profile_id, project_id, role_title)
values ('00000000-0000-0000-0000-0000000014c1', pg_temp.uid('b2'),
        current_setting('test.project')::uuid, 'Foreman');
insert into public.cv_project_confirmations (cv_project_id, confirmed_by, source)
values ('00000000-0000-0000-0000-0000000014c1', pg_temp.uid('b3'), 'teammate');
select is(pg_temp.q('b2', 'role_confirmed'), 1::bigint,
  'a confirmed role: always a push, whatever the Space levels');

-- Chat ----------------------------------------------------------------------------------

select pg_temp.as_user('b3');
set local role authenticated;
select public.set_push_settings(true, true, true);
reset role;
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('b4'), pg_temp.uid('b1'));
-- Bob, Vera and Leo register phones. Bob sets "Needs you"; Leo leaves.
do $$ begin
  for w in 5..8 loop
    if w <> 6 then
      perform set_config('request.jwt.claims',
        '{"sub": "00000000-0000-0000-0000-0000000014b' || w || '", "role": "authenticated"}', true);
      perform public.register_push_token('fcm-token-for-b' || w || '-0123456789abcdef', 'android', 'en');
    end if;
  end loop;
end $$;
select pg_temp.as_user('b5');
set local role authenticated;
select public.set_space_notifications(current_setting('test.space')::uuid, 'needs_you');
reset role;
select pg_temp.as_user('b8');
set local role authenticated;
select public.leave_space(current_setting('test.space')::uuid);
reset role;
select pg_temp.as_user('b1');
set local role authenticated;
select public.post_message(pg_temp.id('e001'),
  (select id from public.threads where space_id = current_setting('test.space')::uuid and team_id is null),
  'Concrete arrives at 7.');
reset role;
select is(pg_temp.q('b7', 'chat_message'), 1::bigint, '(r21) a Viewer hears the Everyone thread');
select is(pg_temp.q('b5', 'chat_message'), 0::bigint, '(r21) "Needs you": no chat pushes');
select is(pg_temp.q('b8', 'chat_message'), 0::bigint, '(r21) after leaving: nothing');
select is(pg_temp.q('b3', 'chat_message'), 1::bigint, 'a chat message: a push to a reader set to "all"');
select is((select message_text from public.push_queue
           where profile_id = pg_temp.uid('b3') and kind = 'chat_message'),
  'Concrete arrives at 7.', 'with its text, since Sara turned lock-screen text on');
select is(pg_temp.q('b1', 'chat_message'), 0::bigint, 'never to the author');
select is(pg_temp.q('b2', 'chat_message'), 0::bigint, 'not to a Space set to "off"');
select is(pg_temp.q('b4', 'chat_message'), 0::bigint, 'never across a block');
select pg_temp.as_user('b1');
set local role authenticated;
select public.delete_message(pg_temp.id('e001'));
reset role;
select is((select count(*) from public.push_queue
           where kind = 'chat_message' and message_text is not null
             and data ->> 'message_id' = pg_temp.id('e001')::text), 0::bigint,
  '(r21) deleting the message clears its text from the queue');

select pg_temp.as_user('b1');
set local role authenticated;
select public.post_message(gen_random_uuid(),
  (select id from public.threads where space_id = current_setting('test.space')::uuid and team_id is null),
  'And the pump at 8.');
reset role;
select is(pg_temp.q('b3', 'chat_message'), 1::bigint, 'one push per thread every 5 minutes');

delete from public.blocks where blocker_id = pg_temp.uid('b4');
select pg_temp.as_user('b1');
set local role authenticated;
select public.post_message(gen_random_uuid(),
  (select id from public.threads where space_id = current_setting('test.space')::uuid and team_id is null),
  'Gate 3 is open again.');
reset role;
select is(pg_temp.q('b4', 'chat_message'), 1::bigint, 'unblocked: Eve hears the next one');
select is((select message_text from public.push_queue
           where profile_id = pg_temp.uid('b4') and kind = 'chat_message'), null,
  'without its text: lock-screen text is off by default');
select pg_temp.as_user('b1');
set local role authenticated;
select set_config('test.team',
  public.create_team(current_setting('test.space')::uuid, 'Steel', array[pg_temp.uid('b3')])::text, true);
select public.post_message(gen_random_uuid(),
  (select id from public.threads where team_id = current_setting('test.team')::uuid),
  'Steel delivery moved to Sunday.');
reset role;
select is((select count(*) from public.push_queue
           where profile_id = pg_temp.uid('b3') and kind = 'chat_message'), 2::bigint,
  'a Team thread: its member hears');
select is(pg_temp.q('b4', 'chat_message'), 1::bigint, 'nobody outside the Team does');
select pg_temp.as_user('b3');
set local role authenticated;
select public.post_message(gen_random_uuid(),
  (select id from public.threads where team_id = current_setting('test.team')::uuid),
  'Noted.');
reset role;
select is(pg_temp.q('b1', 'chat_message'), 1::bigint, '(r21) an admin outside the Team hears its thread');

-- Sending (r21) ------------------------------------------------------------------------

select set_config('test.row', (select min(id) from public.push_queue
  where profile_id = pg_temp.uid('b3') and kind = 'chat_message' and sent_at is null)::text, true);
set local role service_role;
select is((select count(*) from public.claim_push(current_setting('test.row')::bigint)), 1::bigint,
  '(r21) the function claims a row');
select is((select count(*) from public.claim_push(current_setting('test.row')::bigint)), 0::bigint,
  '(r21) a repeated call gets nothing: it sends once');
select public.release_push(current_setting('test.row')::bigint, interval '30 seconds', '429');
select is((select count(*) from public.claim_push(current_setting('test.row')::bigint)), 0::bigint,
  '(r21) FCM said wait: not before then');
update public.push_queue set not_before = null, created_at = now() - interval '5 minutes'
where id = current_setting('test.row')::bigint;
select ok(current_setting('test.row')::bigint in (select id from public.retry_push_queue()),
  '(r21) unsent after a minute: in the retry list');
select is((select count(*) from public.claim_push(current_setting('test.row')::bigint)), 1::bigint,
  '(r21) and it can be claimed again');
select public.finish_push(current_setting('test.row')::bigint);
select is((select message_text from public.push_queue where id = current_setting('test.row')::bigint),
  null, '(r21) once sent, its text is gone');
select ok(current_setting('test.row')::bigint not in (select id from public.retry_push_queue()),
  '(r21) and it leaves the retry list');
-- (r22) The 5th failed attempt: finished, and its text gone at once.
select set_config('test.row5', (select min(id) from public.push_queue
  where profile_id = pg_temp.uid('b3') and kind = 'chat_message' and sent_at is null)::text, true);
update public.push_queue set message_text = 'Kept until sent.', attempts = 4
where id = current_setting('test.row5')::bigint;
select public.claim_push(current_setting('test.row5')::bigint);
select public.release_push(current_setting('test.row5')::bigint, interval '30 seconds', '503');
select ok((select sent_at is not null and message_text is null and not_before is null
           from public.push_queue where id = current_setting('test.row5')::bigint),
  '(r22) after the 5th attempt: finished, its text gone');
select ok(current_setting('test.row5')::bigint not in (select id from public.retry_push_queue()),
  '(r22) and never tried again');
update public.push_queue set created_at = now() - interval '2 days'
where id = current_setting('test.row')::bigint;
update public.push_tokens set updated_at = now() - interval '61 days'
where token = pg_temp.token('b7');
select ok(public.prune_push_queue() >= 2, '(r21) the nightly cleanup runs');
select is((select count(*) from public.push_queue where id = current_setting('test.row')::bigint),
  0::bigint, '(r21) rows over a day old go');
select is((select count(*) from public.push_tokens where token = pg_temp.token('b7')), 0::bigint,
  '(r21) and phones not seen for 60 days');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok(format($q$select * from public.claim_push(%s)$q$, current_setting('test.row')),
  '42501', null, '(r21) the app can not claim a push');
reset role;

-- Phones per person (r21) ---------------------------------------------------------------

select pg_temp.as_user('b7');
set local role authenticated;
do $$ begin
  for i in 1..12 loop
    perform public.register_push_token('fcm-token-vera-phone-' || lpad(i::text, 2, '0') || '-abcdef', 'android', 'en');
  end loop;
end $$;
select is((select count(*) from public.push_tokens), 10::bigint, '(r21) at most 10 phones per person');
select ok(exists (select 1 from public.push_tokens where token like 'fcm-token-vera-phone-12-%')
          and not exists (select 1 from public.push_tokens where token like 'fcm-token-vera-phone-01-%'),
  '(r21) the newest are kept');
reset role;

-- Signing out --------------------------------------------------------------------------

select pg_temp.as_user('b2');
set local role authenticated;
select public.unregister_push_token(pg_temp.token('b2'));
select is((select count(*) from public.push_tokens), 0::bigint, 'signing out removes the phone');
reset role;

select * from finish();
rollback;
