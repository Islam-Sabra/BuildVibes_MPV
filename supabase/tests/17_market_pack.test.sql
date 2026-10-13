-- Migration 17: market pack audit. Run with: supabase test db
--
-- Omar (c1) is in Kuwait; Nadia (c2) has no market yet.

begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000018c1', 'authenticated', 'authenticated', 'omar18@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000018c2', 'authenticated', 'authenticated', 'nadia18@example.com', '{}'),
  ('00000000-0000-0000-0000-0000000018c3', 'authenticated', 'authenticated', 'sara18@example.com', '{"home_market_id": "kw"}');

create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000018' || p_id)::uuid;
$$;

-- The pack ---------------------------------------------------------------------------------

select is((select time_zone from public.markets where id = 'kw'), 'Asia/Kuwait', 'Kuwait''s time zone');
select is((select time_zone from public.markets where id = 'eg'), 'Africa/Cairo', 'Egypt''s time zone');
select is((select count(*) from public.markets where status = 'live' and time_zone is null), 0::bigint,
  'every live market has a time zone');
select is((select phone_rules -> 'mobile_prefixes' from public.markets where id = 'kw'),
  '["5", "6", "9", "41"]'::jsonb, 'Kuwait mobiles may start with 41 too');
select is((select count(*) from public.places where market_id = 'kw'), 25::bigint,
  'Kuwait has its 25 places');
select is((select parent_id from public.places where id = 'kw-khairan'), 'kw-ahmadi',
  'a new area sits in its governorate');
select is((select local_name ->> 'ar' from public.market_trades where market_id = 'kw' and trade_id = 'foreman'),
  'رئيس عمال (فورمن)', 'the foreman chip shows both names');
select is((select count(*) from public.places where market_id = 'kw' and needs_review)
          + (select count(*) from public.market_trades where market_id = 'kw' and needs_review)
          + (select cardinality(needs_review) from public.markets where id = 'kw'),
  0::bigint, 'nothing in Kuwait''s pack is flagged any more');
select ok((select cardinality(needs_review) from public.markets where id = 'eg') > 0
          and (select bool_and(needs_review) from public.places where market_id = 'eg'),
  'Egypt stays flagged');
select throws_ok($$update public.markets set time_zone = 'Asia/Atlantis' where id = 'eg'$$, '22023', null,
  'an unknown zone is refused');
select throws_ok($$update public.markets set time_zone = 'kuwait time' where id = 'eg'$$, '22023', null,
  'and so is anything that isn''t a zone name');

-- Today, in the person's time zone -----------------------------------------------------------

select is(public.local_day(pg_temp.uid('c1')), (now() at time zone 'Asia/Kuwait')::date,
  'Omar''s day is Kuwait''s');
select is(public.local_day(pg_temp.uid('c2')), (now() at time zone 'UTC')::date,
  'with no market, the day is UTC''s');
select ok(not has_function_privilege('authenticated', 'public.local_day(uuid)', 'execute'),
  'local_day is the server''s own');

-- One Useful row a day, by the author's day ----------------------------------------------------

select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000018c1", "role": "authenticated"}', true);
set local role authenticated;
select set_config('test.post', gen_random_uuid()::text, true);
select public.create_post(current_setting('test.post')::uuid, 'Slab poured.', 'en');
reset role;
select public.add_notification(pg_temp.uid('c1'), 'post_useful', pg_temp.uid('c3'),
  p_post => current_setting('test.post')::uuid);
select is((select day from public.notifications
           where profile_id = pg_temp.uid('c1') and kind = 'post_useful'),
  (now() at time zone 'Asia/Kuwait')::date, 'a Useful row is dated by the author''s day');
select public.add_notification(pg_temp.uid('c1'), 'post_useful', pg_temp.uid('c2'),
  p_post => current_setting('test.post')::uuid);
select is((select count(*) from public.notifications
           where profile_id = pg_temp.uid('c1') and kind = 'post_useful'),
  1::bigint, 'and a second mark the same day joins it');

select * from finish();
rollback;
