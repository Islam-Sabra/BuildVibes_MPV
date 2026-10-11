-- Migration 5: email sign-in, private mobile number, invite exception.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

-- Space invites arrive with the Spaces migration; for this test one code is
-- valid (rolled back at the end).
create or replace function public.is_valid_invite_code(p_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_code = 'SPACE-OK';
$$;

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000005a1', 'authenticated', 'authenticated',
   'dana@example.com', '{"locale": "ar"}'),
  ('00000000-0000-0000-0000-0000000005a2', 'authenticated', 'authenticated',
   'mona@example.com', '{"invite_code": "SPACE-OK", "home_market_id": "eg"}'),
  ('00000000-0000-0000-0000-0000000005a3', 'authenticated', 'authenticated',
   'adel@example.com', '{"invite_code": "MADE-UP", "home_market_id": "eg"}');

-- Sign-up ----------------------------------------------------------------------------

select is(
  public.hook_before_user_created('{"user": {"email": "new@example.com", "phone": ""}}'),
  '{}'::jsonb,
  'email sign-up is open to anyone');
select is(
  (select home_market_id from public.profiles
   where id = '00000000-0000-0000-0000-0000000005a2'),
  'eg',
  'with a valid invite, a market that is coming soon is taken from sign-up');
select is(
  (select home_market_id from public.profiles
   where id = '00000000-0000-0000-0000-0000000005a3'),
  null,
  'a made-up invite code does not open a market that is coming soon');

-- Home market -------------------------------------------------------------------------

select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000005a1", "role": "authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$update public.profiles set home_market_id = 'eg'
    where id = '00000000-0000-0000-0000-0000000005a1'$$,
  '23514', null, 'without an invite you cannot choose a market that is coming soon');
select lives_ok(
  $$update public.profiles set home_market_id = 'kw'
    where id = '00000000-0000-0000-0000-0000000005a1'$$,
  'without an invite you can choose a live market');

-- Private mobile number ---------------------------------------------------------------

select lives_ok(
  $$update public.profile_private set mobile_e164 = '+96550000009'
    where id = '00000000-0000-0000-0000-0000000005a1'$$,
  'you can save your own mobile number');
select throws_ok(
  $$update public.profile_private set mobile_e164 = '50000009'
    where id = '00000000-0000-0000-0000-0000000005a1'$$,
  '23514', null, 'the mobile number must be in international form');
select throws_ok(
  $$update public.profile_private set phone_e164 = '+96550000009'
    where id = '00000000-0000-0000-0000-0000000005a1'$$,
  '42501', null, 'the sign-in phone still cannot be edited');

-- Someone else: the invited member.
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000005a2", "role": "authenticated"}', true);

select is(
  (select count(*) from public.profile_private
   where id = '00000000-0000-0000-0000-0000000005a1'),
  0::bigint,
  'nobody else can read your mobile number');
select is_empty(
  $$update public.profile_private set mobile_e164 = '+96550000001'
    where id = '00000000-0000-0000-0000-0000000005a1' returning id$$,
  'nobody else can change your mobile number');
select lives_ok(
  $$update public.profiles set home_market_id = 'kw'
    where id = '00000000-0000-0000-0000-0000000005a2'$$,
  'an invited member can still move to a live market');
select lives_ok(
  $$update public.profiles set home_market_id = 'eg'
    where id = '00000000-0000-0000-0000-0000000005a2'$$,
  'an invited member can choose a market that is coming soon');

reset role;
select * from finish();
rollback;
