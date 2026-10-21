-- Migration 34: the store reviewers' sign-in, made safe (review 73 B1, B2).
-- Run with: supabase test db
--
-- B1: the try counter, called by the review-sign-in function with the
-- service role. pgTAP runs in one transaction, so tries sent at the same
-- moment are checked on the local stack instead (10 concurrent psql calls:
-- 5 allowed, 5 refused); here the row lock's rules are checked in order.
--
-- B2: Rania (e1) and Tom (e2) are real members. Omar (demo) (e3) is a demo
-- teammate, the App Reviewer (e4) the reviewer account. All in Kuwait.

begin;
create extension if not exists pgtap with schema extensions;
select plan(61);

-- ---------------------------------------------------------------------------
-- B1: who reaches the counter
-- ---------------------------------------------------------------------------

select ok((select c.relrowsecurity from pg_class c where c.oid = 'public.review_sign_in_state'::regclass),
  'the counter table has row-level security on');
select is((select count(*)::int from pg_policies
           where schemaname = 'public' and tablename = 'review_sign_in_state'), 0,
  'and no policies, so only the service role reaches it');
select is((select count(*)::int from public.review_sign_in_state), 1, 'it has one row');
select ok(not has_table_privilege('anon', 'public.review_sign_in_state', 'select'),
  'anon can''t read the counter');
select ok(not has_table_privilege('authenticated', 'public.review_sign_in_state', 'select'),
  'a signed-in person can''t read the counter');
select ok(not has_table_privilege('authenticated', 'public.review_sign_in_state', 'update'),
  'or change it');
select ok(not has_function_privilege('anon', 'public.review_sign_in_try()', 'execute'),
  'anon can''t count a try');
select ok(not has_function_privilege('authenticated', 'public.review_sign_in_try()', 'execute'),
  'a signed-in person can''t count a try');
select ok(not has_function_privilege('anon', 'public.review_sign_in_ok()', 'execute'),
  'anon can''t clear the count');
select ok(not has_function_privilege('authenticated', 'public.review_sign_in_ok()', 'execute'),
  'a signed-in person can''t clear the count');
select ok(has_function_privilege('service_role', 'public.review_sign_in_try()', 'execute')
          and has_function_privilege('service_role', 'public.review_sign_in_ok()', 'execute'),
  'the service role can call both');

set local role authenticated;
select throws_ok($$select * from public.review_sign_in_state$$, '42501', null,
  'reading the counter as a signed-in person is refused');
select throws_ok($$select public.review_sign_in_try()$$, '42501', null,
  'and so is calling it');
reset role;
set local role anon;
select throws_ok($$select public.review_sign_in_ok()$$, '42501', null,
  'anon can''t call ok');
reset role;

-- ---------------------------------------------------------------------------
-- B1: the rules, try by try
-- ---------------------------------------------------------------------------

create function pg_temp.try() returns jsonb language sql as $$
  select public.review_sign_in_try();
$$;
-- [n] tries, with a right code (ok) after every fourth; how many were allowed.
create function pg_temp.tries_with_ok(n int) returns int language plpgsql as $$
declare
  v_allowed int := 0;
begin
  for i in 1..n loop
    if (public.review_sign_in_try() ->> 'allowed')::boolean then
      v_allowed := v_allowed + 1;
    end if;
    if i % 4 = 0 then
      perform public.review_sign_in_ok();
    end if;
  end loop;
  return v_allowed;
end;
$$;
create function pg_temp.fresh() returns void language sql as $$
  update public.review_sign_in_state
  set fails = 0, locked_until = null, day = (now() at time zone 'utc')::date, day_tries = 0;
$$;

set local role service_role;
select is(pg_temp.try(), '{"allowed": true, "retry_after": 0}'::jsonb, 'try 1 is compared');
select is(pg_temp.try() ->> 'allowed', 'true', 'try 2');
select is(pg_temp.try() ->> 'allowed', 'true', 'try 3');
select is(pg_temp.try() ->> 'allowed', 'true', 'try 4');
select is(pg_temp.try() ->> 'allowed', 'true', 'try 5 is compared, and locks it behind it');
select is(pg_temp.try(), '{"allowed": false, "retry_after": 900}'::jsonb,
  'try 6, without an ok in between, waits 15 minutes');
select is(pg_temp.try() ->> 'allowed', 'false', 'and so does try 7');
reset role;
select is((select day_tries from public.review_sign_in_state), 5,
  'refused tries aren''t counted for the day');
set local role service_role;
select lives_ok($$select public.review_sign_in_ok()$$, 'the service role can call ok');
reset role;

-- A lock that has passed.
update public.review_sign_in_state set locked_until = now() - interval '1 second';
set local role service_role;
select is(pg_temp.try() ->> 'allowed', 'true', 'after 15 minutes a try is compared again');
reset role;

-- ok clears the count.
select pg_temp.fresh();
set local role service_role;
select pg_temp.try() from generate_series(1, 4);
select public.review_sign_in_ok();
reset role;
select is((select fails from public.review_sign_in_state), 0, 'a right code clears the fails');
select is((select day_tries from public.review_sign_in_state), 4, 'but not the day''s tries');
set local role service_role;
select is((select count(*)::int from generate_series(1, 4) g where (pg_temp.try() ->> 'allowed')::boolean), 4,
  'so four more tries are compared');
select is(pg_temp.try() ->> 'allowed', 'true', 'and the fifth since the ok');
select is(pg_temp.try() ->> 'allowed', 'false', 'then it locks');
reset role;

-- A right code during a lock: ok clears the lock too.
set local role service_role;
select public.review_sign_in_ok();
select is(pg_temp.try() ->> 'allowed', 'true', 'ok after the fifth try lifts the lock');
reset role;

-- The daily cap: 20 tries a day, even with an ok after every fourth.
select pg_temp.fresh();
set local role service_role;
select is(pg_temp.tries_with_ok(20), 20,
  '20 tries in a day are compared (an ok after every fourth)');
select is(pg_temp.try() ->> 'allowed', 'false', 'the 21st is refused');
reset role;
select ok((select locked_until is null from public.review_sign_in_state),
  'by the cap, not by the 5-try lock');
set local role service_role;
select ok((pg_temp.try() ->> 'retry_after')::int between 1 and 86400,
  'and it says to wait until the next UTC day');
select public.review_sign_in_ok();
select is(pg_temp.try() ->> 'allowed', 'false', 'a right code doesn''t lift the cap');
reset role;
update public.review_sign_in_state set day = day - 1;
set local role service_role;
select is(pg_temp.try() ->> 'allowed', 'true', 'the next day tries start again');
reset role;
select is((select day_tries from public.review_sign_in_state), 1, 'counted from one');
select pg_temp.fresh();

-- ---------------------------------------------------------------------------
-- B2: demo and reviewer accounts live apart from real people
-- ---------------------------------------------------------------------------

insert into auth.users (id, aud, role, email, raw_user_meta_data, raw_app_meta_data)
select ('00000000-0000-0000-0000-0000000034' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@review34.example.com', '{"home_market_id": "kw"}'::jsonb, x.app::jsonb
from (values ('e1', '{}'), ('e2', '{"demo": false}'), ('e3', '{"demo": true}'),
             ('e4', '{"review": true}')) x(id, app);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Rania', 'Saleh'), ('e2', 'Tom', 'Reed'), ('e3', 'Omar', '(demo)'),
             ('e4', 'App', 'Reviewer')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000034' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000034' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000034' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000034' || p)::uuid;
$$;
-- The test people a profile read finds, by their short id.
create function pg_temp.seen() returns text language sql as $$
  select coalesce(string_agg(right(p.id::text, 2), ',' order by p.id), '')
  from public.profiles p where p.id::text like '00000000-0000-0000-0000-0000000034%';
$$;
create function pg_temp.in_feed(p_post text) returns boolean language sql as $$
  select exists (select 1 from public.feed_page() f where f.post_id = pg_temp.id(p_post));
$$;

select ok(public.is_demo_account(pg_temp.uid('e3')) and public.is_demo_account(pg_temp.uid('e4')),
  'demo: true and review: true are demo accounts');
select ok(not public.is_demo_account(pg_temp.uid('e1')) and not public.is_demo_account(pg_temp.uid('e2')),
  'no flag, or demo: false, is a real person');
select ok(not has_function_privilege('authenticated', 'public.is_demo_account(uuid)', 'execute'),
  'nobody signed in can ask about anyone''s flags');

-- Posts: one by each.
select pg_temp.as_user('e2');
set local role authenticated;
select public.create_post(pg_temp.id('a002'), 'Slab poured on level 3.', 'en');
select pg_temp.as_user('e3');
select public.create_post(pg_temp.id('a003'), 'Sleeves fixed.', 'en');
select pg_temp.as_user('e4');
select public.create_post(pg_temp.id('a004'), 'Hello from the demo Space.', 'en');
reset role;

-- A real person.
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.seen(), 'e1,e2',
  'people search and suggestions: a real person finds real people only');
select is((select count(*)::int from public.profiles
           where home_market_id = 'kw' and id in (pg_temp.uid('e3'), pg_temp.uid('e4'))), 0,
  'not even by country (suggestions)');
select throws_ok(format($$insert into public.follows (follower_id, followee_id) values (%L, %L)$$,
                        pg_temp.uid('e1'), pg_temp.uid('e3')), '42501', null,
  'a real person can''t follow a demo teammate');
select throws_ok(format($$insert into public.follows (follower_id, followee_id) values (%L, %L)$$,
                        pg_temp.uid('e1'), pg_temp.uid('e4')), '42501', null,
  'or the reviewer');
select lives_ok(format($$insert into public.follows (follower_id, followee_id) values (%L, %L)$$,
                       pg_temp.uid('e1'), pg_temp.uid('e2')),
  'but follows real people as before');
select throws_ok(format($$select public.start_dm(%L, %L, %L, 'Hi')$$,
                        pg_temp.id('b001'), pg_temp.uid('e3'), pg_temp.id('c001')), '42501', null,
  'a real person can''t start a DM with a demo teammate');
select throws_ok(format($$select public.start_dm(%L, %L, %L, 'Hi')$$,
                        pg_temp.id('b002'), pg_temp.uid('e4'), pg_temp.id('c002')), '42501', null,
  'or with the reviewer');
select lives_ok(format($$select public.start_dm(%L, %L, %L, 'Hi Tom')$$,
                       pg_temp.id('b003'), pg_temp.uid('e2'), pg_temp.id('c003')),
  'but DMs real people as before');
select ok(pg_temp.in_feed('a002'), 'Home shows a real person''s post');
select ok(not pg_temp.in_feed('a003') and not pg_temp.in_feed('a004'),
  'and no demo or reviewer posts');
select is((select count(*)::int from public.posts where id in (pg_temp.id('a003'), pg_temp.id('a004'))), 0,
  'nor can they be read directly');
reset role;

-- The reviewer.
select pg_temp.as_user('e4');
set local role authenticated;
select is(pg_temp.seen(), 'e3,e4', 'the reviewer finds demo accounts only');
select throws_ok(format($$insert into public.follows (follower_id, followee_id) values (%L, %L)$$,
                        pg_temp.uid('e4'), pg_temp.uid('e1')), '42501', null,
  'the reviewer can''t follow a real person');
select throws_ok(format($$select public.start_dm(%L, %L, %L, 'Hi')$$,
                        pg_temp.id('b004'), pg_temp.uid('e1'), pg_temp.id('c004')), '42501', null,
  'or start a DM with one');
select lives_ok(format($$insert into public.follows (follower_id, followee_id) values (%L, %L)$$,
                       pg_temp.uid('e4'), pg_temp.uid('e3')),
  'demo accounts follow each other');
select is(public.start_dm(pg_temp.id('b005'), pg_temp.uid('e3'), pg_temp.id('c005'),
                          'The door schedule is in.') ->> 'state', 'request',
  'and DM each other');
select ok(pg_temp.in_feed('a003') and pg_temp.in_feed('a004'),
  'the reviewer''s Home shows demo posts');
select ok(not pg_temp.in_feed('a002'), 'and not real people''s');
reset role;

-- The demo teammate answers the reviewer.
select pg_temp.as_user('e3');
set local role authenticated;
select is(pg_temp.seen(), 'e3,e4', 'a demo teammate finds demo accounts only');
select lives_ok(format($$select public.start_dm(%L, %L, %L, 'Got it.')$$,
                       pg_temp.id('b006'), pg_temp.uid('e4'), pg_temp.id('c006')),
  'and writes back in the same thread');
reset role;

-- A project's posts.
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.project',
  public.create_project('Review tower', 'commercial', 'kw', 'kw-capital')::text, true);
reset role;
insert into public.posts (id, author_id, body, lang, project_id, market_id) values
  (pg_temp.id('a013'), pg_temp.uid('e3'), 'Tagged by the demo.', 'en',
   current_setting('test.project')::uuid, 'kw'),
  (pg_temp.id('a012'), pg_temp.uid('e2'), 'Tagged by Tom.', 'en',
   current_setting('test.project')::uuid, 'kw');
select pg_temp.as_user('e1');
set local role authenticated;
select is((select string_agg(right(t.post_id::text, 4), ',' order by t.post_id)
           from public.posts_tagged(current_setting('test.project')::uuid) t), 'a012',
  'a project''s posts leave out demo accounts'' posts');
reset role;

select * from finish();
rollback;
