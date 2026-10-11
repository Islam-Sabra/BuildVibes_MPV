-- Migration 2: people and companies.
-- Run with: supabase test db
--
-- Alice (a1), Bob (b2) and Carol (c3) sign up. Switching user:
--   reset role; select set_config('request.jwt.claims', '{"sub": …}', true);
--   set local role authenticated;

begin;
create extension if not exists pgtap with schema extensions;
select plan(42);

insert into auth.users (id, aud, role, email, phone, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', 'authenticated', 'authenticated',
   'alice@example.com', '96550000001', '{"locale": "ar", "home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000000b2', 'authenticated', 'authenticated',
   'bob@example.com', '201000000002', '{"locale": "xx", "home_market_id": "nowhere"}'),
  ('00000000-0000-0000-0000-0000000000c3', 'authenticated', 'authenticated',
   'carol@example.com', null, '{}');

-- Sign-up creates the rows ------------------------------------------------------------

select is((select count(*) from public.profiles), 3::bigint,
  'sign-up creates one profile per user');
select is(
  (select phone_e164 from public.profile_private
   where id = '00000000-0000-0000-0000-0000000000a1'),
  '+96550000001',
  'the private row keeps the sign-in phone in E.164');
select results_eq(
  $$select locale, home_market_id from public.profiles
    where id = '00000000-0000-0000-0000-0000000000a1'$$,
  $$values ('ar'::text, 'kw'::text)$$,
  'language and home market come from sign-up');
select results_eq(
  $$select locale, home_market_id from public.profiles
    where id = '00000000-0000-0000-0000-0000000000b2'$$,
  $$values ('en'::text, null::text)$$,
  'unknown language and market fall back safely');

-- Signed out sees no people -----------------------------------------------------------

set local role anon;
select throws_ok($$select * from public.profiles$$, '42501', null,
  'signed out: profiles are not readable');
select throws_ok($$select public.register_company('X Co', 'contractor', 'kw')$$,
  '42501', null, 'signed out: cannot register a company');

-- Alice -------------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000a1", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*) from public.profiles), 3::bigint,
  'signed in: other profiles are readable');
select is((select count(*) from public.profile_private), 1::bigint,
  'private details: only your own row is visible');
select lives_ok(
  $$update public.profiles set first_name = 'Alice', last_name = 'Saleh',
      trade_id = 'site_engineer', place_id = 'kw-salmiya'
    where id = '00000000-0000-0000-0000-0000000000a1'$$,
  'you can edit your own profile');
select lives_ok(
  $$update public.profiles set first_name = 'Hacked'
    where id = '00000000-0000-0000-0000-0000000000b2'$$,
  'editing someone else''s profile runs but changes nothing');
select throws_ok(
  $$update public.profiles set follower_count = 999
    where id = '00000000-0000-0000-0000-0000000000a1'$$,
  '42501', null, 'follower counts cannot be set from the app');
select throws_ok(
  $$update public.profile_private set phone_e164 = '+96599999999'
    where id = '00000000-0000-0000-0000-0000000000a1'$$,
  '42501', null, 'the private phone cannot be changed from the app');
select throws_ok(
  $$insert into public.profiles (id) values (gen_random_uuid())$$,
  '42501', null, 'profiles cannot be inserted from the app');
select throws_ok(
  $$update public.profiles set place_id = 'eg-cairo'
    where id = '00000000-0000-0000-0000-0000000000a1'$$,
  '23514', null, 'a place must be in your home market');

-- Companies: register, then the typed-name rule.
select lives_ok(
  $$select public.register_company('Al Noor Contracting', 'contractor', 'kw', 'kw-capital')$$,
  'you can register a company');
select throws_ok(
  $$insert into public.companies (name, kind_id, market_id)
    values ('Typed Co', 'contractor', 'kw')$$,
  '42501', null, 'a company is never inserted directly');
select throws_ok(
  $$update public.profiles
    set company_id = (select id from public.companies limit 1),
        company_name_text = 'Also typed'
    where id = '00000000-0000-0000-0000-0000000000a1'$$,
  '23514', null, 'a profile has a registered company or a typed name, not both');
select lives_ok(
  $$update public.companies set about = 'Builders since 1990'
    where name = 'Al Noor Contracting'$$,
  'a company admin can edit the company');
select throws_ok(
  $$update public.companies set verified = true where name = 'Al Noor Contracting'$$,
  '42501', null, 'admins cannot mark their company verified');

-- Alice follows Bob.
select lives_ok(
  $$insert into public.follows (follower_id, followee_id)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000b2')$$,
  'you can follow someone');
select throws_ok(
  $$insert into public.follows (follower_id, followee_id)
    values ('00000000-0000-0000-0000-0000000000b2',
            '00000000-0000-0000-0000-0000000000c3')$$,
  '42501', null, 'you cannot follow on someone else''s behalf');

reset role;
select results_eq(
  $$select first_name from public.profiles
    where id = '00000000-0000-0000-0000-0000000000b2'$$,
  $$values (''::text)$$,
  'Bob''s profile was not changed by Alice');
select results_eq(
  $$select follower_count from public.profiles
    where id = '00000000-0000-0000-0000-0000000000b2'$$,
  $$values (1)$$,
  'following updates the follower count');
select results_eq(
  $$select verified from public.companies where name = 'Al Noor Contracting'$$,
  $$values (false)$$,
  'a new company is not verified');

-- Carol: not an admin of Alice's company ------------------------------------------------

select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000c3", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$update public.companies set about = 'Hacked' where name = 'Al Noor Contracting'$$,
  'a non-admin''s company edit runs but changes nothing');
select throws_ok(
  $$select public.add_company_admin(
      (select id from public.companies where name = 'Al Noor Contracting'),
      '00000000-0000-0000-0000-0000000000c3')$$,
  '42501', null, 'a non-admin cannot make themselves admin');

-- Experience with each visibility.
select lives_ok(
  $$insert into public.experience (profile_id, title, company_name_text, start_month, visibility)
    values
      ('00000000-0000-0000-0000-0000000000c3', 'Foreman', 'Typed Co', '2020-01-01', 'everyone'),
      ('00000000-0000-0000-0000-0000000000c3', 'Steel fixer', null, '2018-01-01', 'connections'),
      ('00000000-0000-0000-0000-0000000000c3', 'Helper', null, '2016-01-01', 'only_me')$$,
  'you can add your own experience');
select throws_ok(
  $$insert into public.experience (profile_id, title, start_month)
    values ('00000000-0000-0000-0000-0000000000a1', 'Fake', '2020-01-01')$$,
  '42501', null, 'you cannot add experience to someone else');
select lives_ok(
  $$insert into public.follows (follower_id, followee_id)
    values ('00000000-0000-0000-0000-0000000000c3',
            '00000000-0000-0000-0000-0000000000a1')$$,
  'Carol follows Alice');

reset role;
select results_eq(
  $$select about from public.companies where name = 'Al Noor Contracting'$$,
  $$values ('Builders since 1990'::text)$$,
  'the company was not changed by a non-admin');

-- Alice sees Carol's experience by visibility -------------------------------------------

select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000a1", "role": "authenticated"}', true);
set local role authenticated;

select is(
  (select count(*) from public.experience
   where profile_id = '00000000-0000-0000-0000-0000000000c3'),
  1::bigint,
  'not connected: only "everyone" experience is visible');
insert into public.follows (follower_id, followee_id)
  values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c3');
select is(
  (select count(*) from public.experience
   where profile_id = '00000000-0000-0000-0000-0000000000c3'),
  2::bigint,
  'connected (follow both ways): "connections" experience shows; "only me" never');

-- Bob blocks Alice ------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000b2", "role": "authenticated"}', true);
set local role authenticated;

insert into public.blocks (blocker_id, blocked_id)
  values ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a1');
select is(
  (select count(*) from public.profiles
   where id = '00000000-0000-0000-0000-0000000000a1'),
  0::bigint,
  'the blocker no longer sees the blocked profile');
select is((select count(*) from public.blocks), 1::bigint,
  'the blocker sees their block');

reset role;
select results_eq(
  $$select follower_count from public.profiles
    where id = '00000000-0000-0000-0000-0000000000b2'$$,
  $$values (0)$$,
  'blocking removes follows both ways and updates counts');

select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000a1", "role": "authenticated"}', true);
set local role authenticated;

select is(
  (select count(*) from public.profiles
   where id = '00000000-0000-0000-0000-0000000000b2'),
  0::bigint,
  'a blocked user cannot read the blocker''s profile');
select is((select count(*) from public.blocks), 0::bigint,
  'the blocked user cannot see the block');
select throws_ok(
  $$insert into public.follows (follower_id, followee_id)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000b2')$$,
  '42501', null, 'a blocked user cannot follow the blocker');

-- Company admins: the last admin stays.
select lives_ok(
  $$select public.add_company_admin(
      (select id from public.companies where name = 'Al Noor Contracting'),
      '00000000-0000-0000-0000-0000000000c3')$$,
  'an admin can add another admin');
select lives_ok(
  $$select public.remove_company_admin(
      (select id from public.companies where name = 'Al Noor Contracting'),
      '00000000-0000-0000-0000-0000000000a1')$$,
  'an admin can step down while another admin remains');

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000c3", "role": "authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$select public.remove_company_admin(
      (select id from public.companies where name = 'Al Noor Contracting'),
      '00000000-0000-0000-0000-0000000000c3')$$,
  'P0001', null, 'the last admin cannot be removed');

-- Signed out can still read companies.
reset role;
set local role anon;
select is((select count(*) from public.companies), 1::bigint,
  'signed out: companies are readable');

select * from finish();
rollback;
