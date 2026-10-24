-- Migration 43 (review 89, F103): Space chat kept live by the database.
-- Run with: supabase test db
--
-- Omar (e1) runs the Space; Rakesh (e2) and Sara (e3) are Crew in it, and
-- only Rakesh is in the Steel Team. Vera (e5) is outside.

begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000043' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@chat43.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e5')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000043' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000043' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000043' || p)::uuid;
$$;
create function pg_temp.everyone() returns text language sql as $$
  select 'thread:' || current_setting('test.everyone');
$$;
create function pg_temp.steel() returns text language sql as $$
  select 'thread:' || current_setting('test.steel');
$$;
-- As the database owner: the chat broadcasts on a topic.
create function pg_temp.casts(p_topic text) returns bigint language sql as $$
  select count(*) from realtime.messages where topic = p_topic and event = 'chat';
$$;
create function pg_temp.sent(p_topic text, p_op text) returns jsonb language sql as $$
  select payload - 'id' from realtime.messages
  where topic = p_topic and event = 'chat' and payload ->> 'op' = p_op;
$$;
-- What the current role may receive on a topic, as Realtime asks it.
create function pg_temp.seen(p_topic text) returns bigint language plpgsql as $$
begin
  perform set_config('realtime.topic', p_topic, true);
  return (select count(*) from realtime.messages where topic = p_topic and event = 'chat');
end;
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Chat site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select current_setting('test.space')::uuid, pg_temp.uid(x), 'crew', pg_temp.uid('e1')
from unnest(array['e2', 'e3']) x;
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.team',
  public.create_team(current_setting('test.space')::uuid, 'Steel', array[pg_temp.uid('e2')])::text, true);
reset role;
select set_config('test.everyone', (select id from public.threads
  where space_id = current_setting('test.space')::uuid and team_id is null)::text, true);
select set_config('test.steel', (select id from public.threads
  where team_id = current_setting('test.team')::uuid)::text, true);

-- A new message ---------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select public.post_message(pg_temp.id('b001'), current_setting('test.everyone')::uuid, 'Crane at 6');
reset role;
select is(pg_temp.casts(pg_temp.everyone()), 1::bigint, 'a message: one broadcast on its thread''s topic');
select ok((select extension = 'broadcast' and private from realtime.messages
           where topic = pg_temp.everyone() and event = 'chat'), 'a private broadcast, event chat');
select is(pg_temp.sent(pg_temp.everyone(), 'insert'),
  jsonb_build_object('thread_id', current_setting('test.everyone')::uuid, 'message_id', pg_temp.id('b001'),
                     'author_id', pg_temp.uid('e1'), 'op', 'insert'),
  'it carries only the ids and what happened');
select ok((select position('Crane' in payload::text) = 0 from realtime.messages
           where topic = pg_temp.everyone() and event = 'chat'), 'never the words');

-- Who receives ------------------------------------------------------------------------------------

select pg_temp.as_user('e3');
set local role authenticated;
select is(pg_temp.seen(pg_temp.everyone()), 1::bigint, 'a member of the thread receives it');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select is(pg_temp.seen(pg_temp.everyone()), 0::bigint, 'an outsider who knows the thread id gets nothing');
reset role;
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select is(pg_temp.seen(pg_temp.everyone()), 0::bigint, 'nor does anon');
reset role;

select pg_temp.as_user('e2');
set local role authenticated;
select public.post_message(pg_temp.id('b002'), current_setting('test.steel')::uuid, 'Rebar at gate 2');
select is(pg_temp.seen(pg_temp.steel()), 1::bigint, 'a Team''s thread: its member receives');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.seen(pg_temp.steel()), 1::bigint, 'and so does the Space admin');
reset role;
select pg_temp.as_user('e3');
set local role authenticated;
select is(pg_temp.seen(pg_temp.steel()), 0::bigint,
  'a Space member outside the Team receives nothing');
reset role;

-- The app can't send ----------------------------------------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select set_config('realtime.topic', pg_temp.everyone(), true);
select throws_ok($$insert into realtime.messages (topic, extension, event, payload, private)
                   values (pg_temp.everyone(), 'broadcast', 'chat', '{}', true)$$,
  '42501', null, 'a member can''t send on a thread''s topic: only the database does');
reset role;
select ok(not has_function_privilege('authenticated', 'public.handle_chat_broadcast()', 'execute')
          and not has_function_privilege('anon', 'public.handle_chat_broadcast()', 'execute'),
  'nor call the trigger''s function');

-- A delete ------------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select public.delete_message(pg_temp.id('b001'));
reset role;
select is(pg_temp.casts(pg_temp.everyone()), 2::bigint, 'deleting a message sends one more');
select is(pg_temp.sent(pg_temp.everyone(), 'delete'),
  jsonb_build_object('thread_id', current_setting('test.everyone')::uuid, 'message_id', pg_temp.id('b001'),
                     'author_id', pg_temp.uid('e1'), 'op', 'delete'),
  'with op delete');
update public.messages set deleted_at = deleted_at where id = pg_temp.id('b001');
select is(pg_temp.casts(pg_temp.everyone()), 2::bigint, 'an update that deletes nothing new sends nothing');
select is(pg_temp.casts(pg_temp.steel()), 1::bigint, 'and each thread has only its own');

select * from finish();
rollback;
