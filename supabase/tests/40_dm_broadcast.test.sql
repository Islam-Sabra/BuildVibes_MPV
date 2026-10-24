-- Migration 40: a direct message's live update as a database broadcast
-- (review 50 F100). Run with: supabase test db
--
-- Omar (e1) writes to Rakesh (e2). Sara (e3) is neither; Mona (e4) shares
-- a Space with both but isn't in their thread.

begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000040' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@dmcast40.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e4', 'Mona', 'Saleh')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000040' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000040' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000040' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000040' || p)::uuid;
$$;
create function pg_temp.topic() returns text language sql as $$
  select 'dm:' || pg_temp.id('a001');
$$;
create function pg_temp.on_topic() returns void language sql as $$
  select set_config('realtime.topic', pg_temp.topic(), true);
$$;
-- The thread's broadcasts the current role may receive.
create function pg_temp.seen() returns bigint language sql as $$
  select count(*) from realtime.messages where topic = pg_temp.topic() and event = 'dm';
$$;
-- The payload of the broadcast about a message, without realtime.send's
-- own id (read as the test's owner, past row-level security).
create function pg_temp.sent(p_message text, p_op text) returns jsonb language sql as $$
  select payload - 'id' from realtime.messages
  where topic = pg_temp.topic() and event = 'dm'
    and payload ->> 'message_id' = pg_temp.id(p_message)::text and payload ->> 'op' = p_op;
$$;
create function pg_temp.casts(p_message text) returns bigint language sql as $$
  select count(*) from realtime.messages
  where topic = pg_temp.topic() and payload ->> 'message_id' = pg_temp.id(p_message)::text;
$$;

-- Setup: Mona shares a Space with both.
select pg_temp.as_user('e4');
set local role authenticated;
select set_config('test.space', public.create_space('Broadcast site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select current_setting('test.space')::uuid, pg_temp.uid(x), 'crew', pg_temp.uid('e4')
from unnest(array['e1', 'e2']) x;

-- A new message ----------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.start_dm(pg_temp.id('a001'), pg_temp.uid('e2'), pg_temp.id('b001'),
                    'At the gate at 7?')$$, 'Omar writes to Rakesh');
reset role;

select is((select count(*) from realtime.messages where topic = pg_temp.topic()), 1::bigint,
  'one broadcast on the thread''s topic');
select ok((select extension = 'broadcast' and private and event = 'dm'
           from realtime.messages where topic = pg_temp.topic()),
  'a private broadcast, event dm');
select is(pg_temp.sent('b001', 'insert'),
  jsonb_build_object('thread_id', pg_temp.id('a001'), 'message_id', pg_temp.id('b001'),
                     'author_id', pg_temp.uid('e1'), 'op', 'insert'),
  'it carries only the ids and what happened');
select ok((select position('gate' in payload::text) = 0 and not payload ? 'body'
           from realtime.messages where topic = pg_temp.topic()),
  'never the words');

-- Who receives it ----------------------------------------------------------------------------

select pg_temp.on_topic();
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.seen(), 1::bigint, 'Omar receives it');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.seen(), 1::bigint, 'so does Rakesh, before he answers');
reset role;
select pg_temp.as_user('e3');
set local role authenticated;
select is(pg_temp.seen(), 0::bigint, 'someone who knows the thread id gets nothing');
reset role;
select pg_temp.as_user('e4');
set local role authenticated;
select is(pg_temp.seen(), 0::bigint, 'nor does a member of a Space both are in');
reset role;
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select is(pg_temp.seen(), 0::bigint, 'nor does anon');
reset role;

-- Nobody sends on a thread's topic from the app ---------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select throws_ok($$insert into realtime.messages (topic, extension, event, payload, private)
                   values (pg_temp.topic(), 'broadcast', 'dm', '{"op": "insert"}', true)$$,
  '42501', null, 'Omar can''t send on his thread''s topic');
select lives_ok($$select realtime.send('{"op": "insert"}', 'dm', pg_temp.topic(), true)$$,
  'realtime.send as Omar runs');
reset role;
select is((select count(*) from realtime.messages where topic = pg_temp.topic()), 1::bigint,
  '... but writes nothing: only the trigger sends');
select pg_temp.on_topic();

-- An answer, then a delete -------------------------------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select lives_ok($$select public.send_dm(pg_temp.id('b002'), pg_temp.id('a001'), 'Yes')$$,
  'Rakesh answers');
select lives_ok($$select public.delete_dm(pg_temp.id('b002'))$$, 'and deletes his answer');
reset role;
select is(pg_temp.sent('b002', 'insert') ->> 'author_id', pg_temp.uid('e2')::text,
  'the answer is broadcast with its author');
select is(pg_temp.sent('b002', 'delete'),
  jsonb_build_object('thread_id', pg_temp.id('a001'), 'message_id', pg_temp.id('b002'),
                     'author_id', pg_temp.uid('e2'), 'op', 'delete'),
  'the delete is broadcast too, with ids only');
update public.dm_messages set deleted_at = now() where id = pg_temp.id('b002');
update public.dm_messages set body = 'At the gate at 7:30?' where id = pg_temp.id('b001');
select is(pg_temp.casts('b002') + pg_temp.casts('b001'), 3::bigint,
  'a deleted message deleted again, or another change, sends nothing more');

-- A block closes it, either way ---------------------------------------------------------------

select pg_temp.on_topic();
select pg_temp.as_user('e2');
set local role authenticated;
select public.block(pg_temp.uid('e1'), true);
select is(pg_temp.seen(), 0::bigint, 'once Rakesh blocks Omar, Rakesh receives nothing');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.seen(), 0::bigint, 'nor does Omar');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select public.block(pg_temp.uid('e1'), false);
select is(pg_temp.seen(), 3::bigint, 'unblocked, Rakesh receives again');
reset role;

-- A Realtime problem never blocks a message ----------------------------------------------------

create function public.test40_refuse() returns trigger language plpgsql as $$
begin
  raise exception 'realtime is down';
end;
$$;
create trigger test40_refuse before insert on realtime.messages
  for each row execute function public.test40_refuse();
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.send_dm(pg_temp.id('b003'), pg_temp.id('a001'), 'Still there?')$$,
  'with realtime.messages refusing every row, Omar still sends');
reset role;
select ok(exists (select 1 from public.dm_messages where id = pg_temp.id('b003')),
  'the message is kept');
select is(pg_temp.casts('b003'), 0::bigint, '... with no broadcast');
drop trigger test40_refuse on realtime.messages;
drop function public.test40_refuse();

select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.delete_dm(pg_temp.id('b003'))$$, 'Realtime back, Omar deletes it');
reset role;
select is(pg_temp.sent('b003', 'delete') ->> 'op', 'delete', 'and the delete is broadcast');

select ok(not has_function_privilege('authenticated', 'public.handle_dm_broadcast()', 'execute')
          and not has_function_privilege('anon', 'public.handle_dm_broadcast()', 'execute'),
  'the trigger function isn''t callable from the app');

select * from finish();
rollback;
