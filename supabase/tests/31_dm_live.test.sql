-- Migration 31: a direct message thread's private live channel (review 64).
-- Run with: supabase test db
--
-- Omar (e1) writes to Rakesh (e2); Sara (e3) is neither. Then Rakesh
-- blocks Omar.

begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000031' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@dmlive31.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000031' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000031' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000031' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000031' || p)::uuid;
$$;
create function pg_temp.topic() returns text language sql as $$
  select 'dm:' || pg_temp.id('a001');
$$;
create function pg_temp.on_topic(p_topic text) returns void language sql as $$
  select set_config('realtime.topic', p_topic, true);
$$;
create function pg_temp.seen(p_topic text) returns bigint language sql as $$
  select count(*) from realtime.messages where topic = p_topic;
$$;

-- Setup: Omar starts the thread; Realtime writes one row on its topic.
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.start_dm(pg_temp.id('a001'), pg_temp.uid('e2'), pg_temp.id('b001'),
                    'At the gate at 7?')$$, 'Omar writes to Rakesh');
reset role;
insert into realtime.messages (topic, extension, event, payload, private)
values (pg_temp.topic(), 'broadcast', 'x', '{}', true);
select pg_temp.on_topic(pg_temp.topic());

select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.seen(pg_temp.topic()), 1::bigint, 'Omar may join his thread''s channel');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.seen(pg_temp.topic()), 1::bigint, 'so may Rakesh, even before he answers');
select throws_ok($$insert into realtime.messages (topic, extension, event, payload, private)
                   values (pg_temp.topic(), 'broadcast', 'x', '{}', true)$$, '42501', null,
  'receive only: nobody sends on a thread''s channel');
reset role;
select pg_temp.as_user('e3');
set local role authenticated;
select is(pg_temp.seen(pg_temp.topic()), 0::bigint,
  'someone else who knows the thread id gets nothing');
reset role;

-- Signed out.
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select is(pg_temp.seen(pg_temp.topic()), 0::bigint, 'nor does anon');
reset role;

-- A block either way closes the channel, as it closes the thread.
select pg_temp.as_user('e2');
set local role authenticated;
select public.block(pg_temp.uid('e1'), true);
select is(pg_temp.seen(pg_temp.topic()), 0::bigint, 'once Rakesh blocks Omar, Rakesh gets nothing');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.seen(pg_temp.topic()), 0::bigint, 'nor does Omar');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select public.block(pg_temp.uid('e1'), false);
select is(pg_temp.seen(pg_temp.topic()), 1::bigint, 'unblocked, it opens again');

select ok(not public.may_use_dm_topic('dm:not-a-thread')
          and not public.may_use_dm_topic(null)
          and not public.may_use_dm_topic('dm:' || gen_random_uuid()),
  'a topic that isn''t a thread is refused, without an error from the cast');
-- The other topics keep their own rules.
select ok(not public.may_use_dm_topic('daybook:' || pg_temp.id('a001')),
  'a daybook topic is not a thread''s');
reset role;
select ok(not has_function_privilege('anon', 'public.may_use_dm_topic(text)', 'execute')
          and has_function_privilege('authenticated', 'public.may_use_dm_topic(text)', 'execute'),
  'the topic test runs for signed-in people only');

select * from finish();
rollback;
