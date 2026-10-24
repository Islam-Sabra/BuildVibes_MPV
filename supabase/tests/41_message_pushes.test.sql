-- Migration 41 (review 50 F102): every message pushes with its unread
-- count, and mute for a time. Run with: supabase test db
--
-- Omar (e1) runs the Space; Rakesh (e2) and Sara (e3) are Crew in it, so
-- their conversations with Omar are open. Vera (e4) is outside. Phones:
-- e1, e2, e3.

begin;
create extension if not exists pgtap with schema extensions;
select plan(46);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000041' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@f102.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e4', 'Vera', 'Lin')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000041' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000041' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000041' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000041' || p)::uuid;
$$;
-- Run as the database owner: pushes queued of a kind for someone.
create function pg_temp.q(p_who text, p_kind text) returns bigint language sql as $$
  select count(*) from public.push_queue where profile_id = pg_temp.uid(p_who) and kind = p_kind;
$$;
-- Their counts, oldest first.
create function pg_temp.counts(p_who text, p_kind text) returns text[] language sql as $$
  select coalesce(array_agg(data ->> 'count' order by id), '{}')
  from public.push_queue where profile_id = pg_temp.uid(p_who) and kind = p_kind;
$$;
create function pg_temp.everyone() returns uuid language sql as $$
  select id from public.threads
  where space_id = current_setting('test.space')::uuid and team_id is null;
$$;
create function pg_temp.say(p_who text, p_body text) returns void language sql as $$
  select pg_temp.as_user(p_who);
  set local role authenticated;
  select public.post_message(gen_random_uuid(), pg_temp.everyone(), p_body);
  reset role;
$$;
create function pg_temp.dm(p_body text) returns void language sql as $$
  select pg_temp.as_user('e1');
  set local role authenticated;
  select public.send_dm(gen_random_uuid(), pg_temp.id('a001'), p_body);
  reset role;
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('F102 site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select current_setting('test.space')::uuid, pg_temp.uid(x.id), 'crew', pg_temp.uid('e1')
from (values ('e2'), ('e3')) x(id);
insert into public.push_tokens (token, profile_id, platform)
select 'fcm-token-for-' || x.id || '-0123456789abcdef', pg_temp.uid(x.id), 'android'
from (values ('e1'), ('e2'), ('e3')) x(id);

-- A direct message: 3 messages in 10 seconds, 3 pushes counting 1, 2, 3 -----------------------

select pg_temp.as_user('e1');
set local role authenticated;
select public.start_dm(pg_temp.id('a001'), pg_temp.uid('e2'), pg_temp.id('b001'), 'Pour at 7');
reset role;
select pg_temp.dm('Pump is late');
select pg_temp.dm('Stop the pour');
select is(pg_temp.q('e2', 'dm_message'), 3::bigint, 'a direct message: 3 messages queue 3 pushes');
select is(pg_temp.counts('e2', 'dm_message'), array['1', '2', '3'],
  'each with the unread count: 1, 2, 3');
select is(pg_temp.q('e2', 'dm_follow_up'), 0::bigint, 'and no follow-up is queued');
select ok((select bool_and(data ->> 'dm_thread_id' = pg_temp.id('a001')::text)
           from public.push_queue where profile_id = pg_temp.uid('e2') and kind = 'dm_message'),
  'all for the same conversation (one tag on the phone)');
select pg_temp.as_user('e2');
set local role authenticated;
select public.mark_dm_read(pg_temp.id('a001'));
reset role;
delete from public.push_queue where profile_id = pg_temp.uid('e2');
update public.dm_messages set created_at = created_at - interval '1 minute'
where thread_id = pg_temp.id('a001');
update public.dm_members set last_read_at = now() - interval '30 seconds'
where thread_id = pg_temp.id('a001') and profile_id = pg_temp.uid('e2');
select pg_temp.dm('Gate 3');
select is(pg_temp.counts('e2', 'dm_message'), array['1'], 'once read, the count starts again at 1');

-- Space chat: 3 messages, 3 pushes counting 1, 2, 3 -------------------------------------------

select pg_temp.say('e1', 'Crane at 6');
select pg_temp.say('e1', 'Bring helmets');
select pg_temp.say('e1', 'Gate 2 only');
select is(pg_temp.q('e2', 'chat_message'), 3::bigint, 'Space chat: 3 messages queue 3 pushes');
select is(pg_temp.counts('e2', 'chat_message'), array['1', '2', '3'],
  'each with the unread count: 1, 2, 3');
select is(pg_temp.counts('e3', 'chat_message'), array['1', '2', '3'], 'for each reader');
select is(pg_temp.q('e1', 'chat_message'), 0::bigint, 'never to the author');
select pg_temp.as_user('e3');
set local role authenticated;
select public.mark_thread_read(pg_temp.everyone());
reset role;
update public.messages set created_at = created_at - interval '1 minute'
where thread_id = pg_temp.everyone();
update public.thread_reads set last_read_at = now() - interval '30 seconds'
where thread_id = pg_temp.everyone() and profile_id = pg_temp.uid('e3');
delete from public.push_queue where kind = 'chat_message';
select pg_temp.say('e1', 'Lunch at 12');
select is(pg_temp.counts('e3', 'chat_message'), array['1'], 'once read, the count starts again at 1');
select is(pg_temp.counts('e2', 'chat_message'), array['4'], 'unread, it goes on: 4');

-- Mute a conversation for a time ----------------------------------------------------------------

delete from public.push_queue;
select pg_temp.as_user('e2');
set local role authenticated;
select public.mute_dm(pg_temp.id('a001'), true, now() + interval '8 hours');
select is((public.dm_thread_page(pg_temp.id('a001')) ->> 'muted')::boolean, true,
  'muted for 8 hours: the conversation shows muted');
select ok((public.dm_thread_page(pg_temp.id('a001')) ->> 'muted_until')::timestamptz
            = now() + interval '8 hours', 'with until when');
reset role;
select pg_temp.dm('Muted for now?');
select is(pg_temp.q('e2', 'dm_message'), 0::bigint, 'a muted conversation queues no push');
-- The 8 hours pass.
update public.dm_members set muted_until = now() - interval '1 second'
where thread_id = pg_temp.id('a001') and profile_id = pg_temp.uid('e2');
select pg_temp.dm('And now?');
select is(pg_temp.q('e2', 'dm_message'), 1::bigint, 'after its time it queues again');
select pg_temp.as_user('e2');
set local role authenticated;
select is((select (r ->> 'muted')::boolean from jsonb_array_elements(public.my_dm_threads() -> 'threads') r
           where r ->> 'thread' = pg_temp.id('a001')::text), false,
  'and the list shows it unmuted');
select public.mute_dm(pg_temp.id('a001'), true);
reset role;
delete from public.push_queue;
update public.dm_members set muted_until = null
where thread_id = pg_temp.id('a001') and profile_id = pg_temp.uid('e2') and muted_until is not null;
select pg_temp.dm('Always muted?');
select is(pg_temp.q('e2', 'dm_message'), 0::bigint, '"Always" never queues');
select is((select muted_until from public.dm_members
           where thread_id = pg_temp.id('a001') and profile_id = pg_temp.uid('e2')), null,
  '"Always" keeps no time');
select pg_temp.as_user('e2');
set local role authenticated;
select public.mute_dm(pg_temp.id('a001'), false);
select is((select muted::text || coalesce(muted_until::text, '-') from public.dm_members
           where thread_id = pg_temp.id('a001') and profile_id = auth.uid()), 'false-',
  'unmuting clears the time');
select throws_ok($$select public.mute_dm(pg_temp.id('a001'), true, now() - interval '1 minute')$$,
  '22023', null, 'a time that has passed is refused');

-- Mute a Space for a time --------------------------------------------------------------------

select public.set_space_notifications(current_setting('test.space')::uuid, 'off', now() + interval '7 days');
select is((select notify || ' ' || (notify_until = now() + interval '7 days')::text
           from public.my_spaces() where space_id = current_setting('test.space')::uuid),
  'off true', 'off for 1 week: my_spaces shows it, with its time');
reset role;
delete from public.push_queue;
select pg_temp.say('e1', 'Muted Space?');
select is(pg_temp.q('e2', 'chat_message'), 0::bigint, 'a muted Space queues no chat push');
select is(public.space_push_level(current_setting('test.space')::uuid, pg_temp.uid('e2')), 'off',
  'its level is off');
-- The week passes.
update public.space_members set notify_until = now() - interval '1 second'
where space_id = current_setting('test.space')::uuid and profile_id = pg_temp.uid('e2');
select is(public.space_push_level(current_setting('test.space')::uuid, pg_temp.uid('e2')), 'all',
  'after its time it is back to all by itself');
select pg_temp.say('e1', 'And now?');
select is(pg_temp.q('e2', 'chat_message'), 1::bigint, 'and chat pushes queue again');
select pg_temp.as_user('e2');
set local role authenticated;
select is((select notify || coalesce(notify_until::text, '-') from public.my_spaces()
           where space_id = current_setting('test.space')::uuid), 'all-',
  'my_spaces shows all, with no time');
select public.set_space_notifications(current_setting('test.space')::uuid, 'needs_you',
                                      now() + interval '8 hours');
reset role;
delete from public.push_queue;
select pg_temp.say('e1', 'Needs you only?');
select is(pg_temp.q('e2', 'chat_message'), 0::bigint, '"Needs you only" for 8 hours: no chat push');
select is(public.space_push_level(current_setting('test.space')::uuid, pg_temp.uid('e2')), 'needs_you',
  'but its level still lets work pushes through');
select pg_temp.as_user('e2');
set local role authenticated;
select public.set_space_notifications(current_setting('test.space')::uuid, 'off');
reset role;
update public.space_members set notify_until = null
where space_id = current_setting('test.space')::uuid and profile_id = pg_temp.uid('e2')
  and notify_until is not null;
select pg_temp.say('e1', 'Always off?');
select is(pg_temp.q('e2', 'chat_message'), 0::bigint, '"Always" never queues');
select is((select notify || coalesce(notify_until::text, '-') from public.space_members
           where space_id = current_setting('test.space')::uuid and profile_id = pg_temp.uid('e2')),
  'off-', '"Always" keeps no time');
select pg_temp.as_user('e2');
set local role authenticated;
select public.set_space_notifications(current_setting('test.space')::uuid, 'all');
select is((select notify || coalesce(notify_until::text, '-')
           from public.my_space_notify(current_setting('test.space')::uuid)),
  'all-', 'back to all clears the time');
select throws_ok($$select public.set_space_notifications(current_setting('test.space')::uuid, 'off',
                                                         now() - interval '1 minute')$$,
  '22023', null, 'a time that has passed is refused');

-- Nobody sets another person's ------------------------------------------------------------------

select pg_temp.as_user('e3');
select throws_ok($$select public.mute_dm(pg_temp.id('a001'), true)$$,
  '42501', null, 'nobody mutes a conversation they are not in');
select public.set_space_notifications(current_setting('test.space')::uuid, 'off');
reset role;
select is((select notify from public.space_members
           where space_id = current_setting('test.space')::uuid and profile_id = pg_temp.uid('e2')),
  'all', 'setting your own level leaves the others'' alone');
select pg_temp.as_user('e4');
set local role authenticated;
select throws_ok($$select public.set_space_notifications(current_setting('test.space')::uuid, 'off')$$,
  '42501', null, 'nor does someone outside the Space');
select is((select count(*) from public.my_space_notify(current_setting('test.space')::uuid)), 0::bigint,
  '(M1) and has no level there to read');

-- Review 89 M1: a level is the person's own ---------------------------------------------------

select pg_temp.as_user('e3');
select throws_ok($$select notify from public.space_members
                   where space_id = current_setting('test.space')::uuid and profile_id = pg_temp.uid('e2')$$,
  '42501', null, '(M1) a member can''t read another member''s level');
select throws_ok($$select notify_until from public.space_members
                   where space_id = current_setting('test.space')::uuid$$,
  '42501', null, '(M1) nor anyone''s until');
select is((select count(*) from public.space_members
           where space_id = current_setting('test.space')::uuid and pass is not null), 3::bigint,
  '(M1) every other column still reads');
select is((select notify || coalesce(notify_until::text, '-')
           from public.my_space_notify(current_setting('test.space')::uuid)),
  'off-', '(M1) my own level comes through my_space_notify');
select is((select notify from public.my_spaces() where space_id = current_setting('test.space')::uuid),
  'off', '(M1) and through my_spaces');
select pg_temp.as_user('e3');
select throws_ok($$update public.space_members set notify = 'off', notify_until = null
                   where space_id = current_setting('test.space')::uuid$$,
  '42501', null, 'nobody writes space_members directly');
select pg_temp.as_user('e1');
select throws_ok($$update public.dm_members set muted = true, muted_until = null
                   where thread_id = pg_temp.id('a001')$$,
  '42501', null, 'nor dm_members, not even your own row');
select lives_ok($$select public.mute_dm(p_thread => pg_temp.id('a001'), p_on => false)$$,
  'a build that sends no time still calls mute_dm');
reset role;
select ok(not has_function_privilege('anon', 'public.mute_dm(uuid, boolean, timestamptz)', 'execute')
          and not has_function_privilege('anon',
                'public.set_space_notifications(uuid, text, timestamptz)', 'execute'),
  'signed out: neither can be called');
select ok(not has_function_privilege('authenticated', 'public.space_notify_now(text, timestamptz)', 'execute')
          and not has_function_privilege('authenticated', 'public.dm_muted_now(boolean, timestamptz)', 'execute'),
  'the helpers are internal');

select * from finish();
rollback;
