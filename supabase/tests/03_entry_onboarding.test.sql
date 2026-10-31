-- Migration 3: sign-up gate and onboarding reference data.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

-- The sign-up gate ----------------------------------------------------------------

select is(
  public.hook_before_user_created('{"user": {"phone": "96550000001"}}'),
  '{}'::jsonb,
  'a Kuwait number (live market) can sign up');
select is(
  public.hook_before_user_created('{"user": {"phone": "+96550000001"}}'),
  '{}'::jsonb,
  'the leading "+" does not matter');
select is(
  public.hook_before_user_created('{"user": {"phone": "201000000001"}}') -> 'error' ->> 'http_code',
  '403',
  'an Egypt number (market coming soon) cannot sign up without an invite');
select is(
  public.hook_before_user_created('{"user": {"phone": "919800000001"}}') -> 'error' ->> 'message',
  'signup_not_open_for_country',
  'a number from a country with no market cannot sign up without an invite');
select is(
  public.hook_before_user_created(
    '{"user": {"phone": "919800000001", "user_metadata": {"invite_code": "FAKE01"}}}'
  ) -> 'error' ->> 'http_code',
  '403',
  'a made-up invite code does not open sign-up');
select is(
  public.hook_before_user_created('{"user": {"email": "a@example.com", "phone": ""}}'),
  '{}'::jsonb,
  'an email sign-up is allowed (a live home market is chosen in onboarding)');
select ok(
  has_function_privilege('supabase_auth_admin', 'public.hook_before_user_created(jsonb)', 'execute'),
  'Supabase Auth can run the hook');
select ok(
  not has_function_privilege('authenticated', 'public.hook_before_user_created(jsonb)', 'execute')
  and not has_function_privilege('anon', 'public.hook_before_user_created(jsonb)', 'execute'),
  'the app cannot call the hook');

-- Sign-up only takes a live home market --------------------------------------------

insert into auth.users (id, aud, role, phone, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d4', 'authenticated', 'authenticated',
   '96550000002', '{"home_market_id": "eg"}');
select is(
  (select home_market_id from public.profiles
   where id = '00000000-0000-0000-0000-0000000000d4'),
  null,
  'a market that is not live is not taken from sign-up');

-- Home market must be live ------------------------------------------------------------

select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000d4", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$update public.profiles set home_market_id = 'kw'
    where id = '00000000-0000-0000-0000-0000000000d4'$$,
  'you can choose a live market');
select throws_ok(
  $$update public.profiles set home_market_id = 'eg'
    where id = '00000000-0000-0000-0000-0000000000d4'$$,
  '23514', null, 'you cannot choose a market that is coming soon');
select lives_ok(
  $$update public.profiles set first_name = 'Dana', last_name = 'Ali',
      trade_id = 'other', headline = 'Formwork supervisor'
    where id = '00000000-0000-0000-0000-0000000000d4'$$,
  'a role not in the list is saved as "other" with your own words');

-- Role picker data ------------------------------------------------------------------------

select results_eq(
  'select id from public.role_families order by sort',
  array['trades', 'engineering', 'management'],
  'three role groups, in the E9b order');
select is(
  (select count(*) from public.trades where description is null),
  0::bigint,
  'every trade has a short description');
select is(
  (select count(*) from public.market_trades
   where market_id = 'kw' and popular_sort is not null),
  -- Seven from the E9b design, and Carpenter and Mason for OB5's nine
  -- tiles (review 107, the lead's check Q6).
  9::bigint,
  'nine popular trades in Kuwait');
select is(
  (select count(*) from public.market_trades
   where market_id = 'eg' and popular_sort is not null and not needs_review),
  0::bigint,
  'Egypt''s popular list is marked for local review');

select * from finish();
rollback;
