-- Migration 20261123120000 (review 114): send_test_alert. Run with: supabase test db
--
-- Omar (a1) made the Space "Tower 114"; Rakesh (b2) is Crew there. Tariq
-- (c3) is in no Space at all. Lina (d4) has no phone registered. Eve (e5)
-- asked to delete her account. Everyone but Lina has a push token.

begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000063' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@r114.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('d4'), ('e5')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('a1', 'Omar', 'Haddad'), ('b2', 'Rakesh', 'Nair'), ('c3', 'Tariq', 'Aziz'),
             ('d4', 'Lina', 'Saad'), ('e5', 'Eve', 'Gone')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000063' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000063' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000063' || p_id)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
-- [p_id]'s test alerts in the queue.
create function pg_temp.tests(p_id text) returns integer language sql as $$
  select count(*)::int from public.push_queue
  where kind = 'need_you_test' and profile_id = pg_temp.uid(p_id);
$$;
-- Every row in the queue for anyone but [p_id].
create function pg_temp.others(p_id text) returns integer language sql as $$
  select count(*)::int from public.push_queue where profile_id <> pg_temp.uid(p_id);
$$;
-- [p_id] calls send_test_alert, signed in.
create function pg_temp.send(p_id text) returns void language plpgsql as $$
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  perform public.send_test_alert();
  reset role;
end;
$$;

-- Setup ----------------------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Tower 114')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp(), pg_temp.uid('b2'), 'crew', pg_temp.uid('a1'));
insert into public.push_tokens (token, profile_id, platform)
select repeat(x.c, 40), pg_temp.uid(x.id), 'android'
from (values ('a1', 'p'), ('b2', 'q'), ('c3', 'r'), ('e5', 's')) x(id, c);
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('e5');
select set_config('test.before', pg_temp.others('b2')::text, true);

-- The function ---------------------------------------------------------------------------------------

select has_function('public', 'send_test_alert', '{}'::name[], 'send_test_alert() exists, with no arguments');
select function_returns('public', 'send_test_alert', '{}'::name[], 'void', 'and returns nothing');
select ok((select p.prosecdef and p.proconfig @> array['search_path=""']
           from pg_proc p where p.oid = 'public.send_test_alert()'::regprocedure),
  'security definer, with an empty search_path');
select ok(has_function_privilege('authenticated', 'public.send_test_alert()', 'execute'),
  'a signed-in person may call it');
select ok(not has_function_privilege('anon', 'public.send_test_alert()', 'execute'),
  'anon can''t');
select ok(not exists (select 1 from pg_proc p, aclexplode(p.proacl) a
                      where p.oid = 'public.send_test_alert()'::regprocedure and a.grantee = 0),
  'nor PUBLIC');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'send_test_alert'), 1,
  'one send_test_alert only: no form that takes a person');

-- Only self ------------------------------------------------------------------------------------------

select lives_ok($$select pg_temp.send('b2')$$, 'Rakesh sends himself a test');
select is(pg_temp.tests('b2'), 1, 'one test alert, to Rakesh');
select is(pg_temp.others('b2'), current_setting('test.before')::int,
  'nothing queued for anyone else, not even his Space''s admin');
select is((select data from public.push_queue where kind = 'need_you_test' and profile_id = pg_temp.uid('b2')),
  '{}'::jsonb, 'its data names nobody and no Space');
select ok((select actor_id is null and message_text is null and thread_id is null
           and notification_id is null
           from public.push_queue where kind = 'need_you_test' and profile_id = pg_temp.uid('b2')),
  'and no actor, no text, no thread, no notification');
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.send_test_alert(pg_temp.uid('a1'))$$, '42883', null,
  'no one else can be named: the call takes no person');
reset role;

-- At most 3 an hour ----------------------------------------------------------------------------------

select lives_ok($$select pg_temp.send('b2')$$, 'the second in the hour');
select lives_ok($$select pg_temp.send('b2')$$, 'the third');
select throws_ok($$select pg_temp.send('b2')$$, '22023', 'at most 3 an hour', 'the fourth is refused');
select is(pg_temp.tests('b2'), 3, 'still three');
update public.push_queue set created_at = now() - interval '61 minutes'
where kind = 'need_you_test' and profile_id = pg_temp.uid('b2')
  and id = (select min(id) from public.push_queue
            where kind = 'need_you_test' and profile_id = pg_temp.uid('b2'));
select lives_ok($$select pg_temp.send('b2')$$, 'an hour after the first, one more');
select throws_ok($$select pg_temp.send('b2')$$, '22023', 'at most 3 an hour', 'and then no more');
select is(pg_temp.tests('b2'), 4, 'four in all, three in the last hour');

-- Outside any Space ----------------------------------------------------------------------------------

select set_config('test.before', pg_temp.others('c3')::text, true);
select lives_ok($$select pg_temp.send('c3')$$, 'Tariq, in no Space, tests his own phone');
select is(pg_temp.tests('c3'), 1, 'one test alert, to Tariq');
select is(pg_temp.others('c3'), current_setting('test.before')::int, 'and nothing for anyone else');
select is(pg_temp.tests('a1'), 0, 'nothing ever reached Omar');

-- No phone, signed out, going away ------------------------------------------------------------------

select lives_ok($$select pg_temp.send('d4'); select pg_temp.send('d4');
                  select pg_temp.send('d4'); select pg_temp.send('d4')$$,
  'Lina has no phone registered: each call returns');
select is(pg_temp.tests('d4'), 0, 'and queues nothing');
select set_config('request.jwt.claims', '', true);
set local role authenticated;
select throws_ok($$select public.send_test_alert()$$, '42501', null, 'signed out: refused');
reset role;
set local role anon;
select throws_ok($$select public.send_test_alert()$$, '42501', null, 'anon: refused');
reset role;
select throws_ok($$select pg_temp.send('e5')$$, '42501', null, 'an account going away: refused');
select is(pg_temp.tests('e5'), 0, 'and nothing queued for Eve');

-- The queue's kinds ----------------------------------------------------------------------------------

select throws_ok($$insert into public.push_queue (profile_id, kind) values (pg_temp.uid('a1'), 'need_you_tests')$$,
  '23514', null, 'the kind check still refuses a kind it doesn''t know');

select * from finish();
rollback;
