-- Migration 1: market pack and reference data.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

-- Seed ------------------------------------------------------------------------

select results_eq(
  'select id from public.markets order by sort',
  array['kw', 'eg'],
  'Kuwait and Egypt packs are seeded'
);
-- Kuwait's pack was confirmed by the founder (review 29, migration 17); a
-- market nobody has confirmed yet keeps its flags.
select is(
  (select count(*) from public.markets where cardinality(needs_review) = 0 and id <> 'kw'),
  0::bigint,
  'every market not yet confirmed lists the fields a local must confirm'
);
select is(
  (select count(*) from public.places where not needs_review and market_id <> 'kw'),
  0::bigint,
  'every place not yet confirmed is marked for local review'
);
select ok(
  (select count(*) from public.trades) >= 14,
  'the role picker trades are seeded'
);
select is(
  (select count(*) from public.market_trades),
  (select count(*) * 2 from public.trades),
  'every trade is offered in both markets'
);
select throws_ok(
  $$insert into public.role_families (id, name) values ('x', '{"en": "Only English"}')$$,
  '23514',
  null,
  'a label needs both English and Arabic'
);
select throws_ok(
  $$insert into public.places (id, market_id, parent_id, level, name)
    values ('kw-bad', 'kw', null, 'area', '{"en": "A", "ar": "أ"}')$$,
  '23514',
  null,
  'an area must sit under a city'
);

-- RLS is on for every reference table ------------------------------------------

select is(
  (select count(*) from pg_class
   where relnamespace = 'public'::regnamespace
     and relname in ('markets', 'places', 'role_families', 'trades',
                     'market_trades', 'company_kinds', 'project_types')
     and relrowsecurity),
  7::bigint,
  'row-level security is on for all 7 reference tables'
);

-- A hidden market for the visibility test.
insert into public.markets (id, status, name, default_locale, dial_code,
  code_channel, currency, currency_decimals, week_start)
values ('zz', 'hidden', '{"en": "Test", "ar": "تجربة"}', 'en', '+999',
  'sms', 'XXX', 2, 0);

-- Signed out --------------------------------------------------------------------

set local role anon;

select is(
  (select count(*) from public.markets where id in ('kw', 'eg')),
  2::bigint,
  'signed out: markets are readable'
);
select ok(
  (select count(*) from public.places) > 0,
  'signed out: places are readable'
);
select is(
  (select count(*) from public.markets where id = 'zz'),
  0::bigint,
  'signed out: a hidden market is not shown'
);
select throws_ok(
  $$insert into public.markets (id, name, default_locale, dial_code,
      code_channel, currency, currency_decimals, week_start)
    values ('qq', '{"en": "Q", "ar": "ق"}', 'en', '+1', 'sms', 'QQQ', 2, 0)$$,
  '42501',
  null,
  'signed out: cannot add a market'
);
select throws_ok(
  $$update public.markets set dial_code = '+1' where id = 'kw'$$,
  '42501',
  null,
  'signed out: cannot change a market'
);
select throws_ok(
  $$delete from public.trades where id = 'electrician'$$,
  '42501',
  null,
  'signed out: cannot delete a trade'
);

-- Signed in -------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000a1", "role": "authenticated"}', true);
set local role authenticated;

select ok(
  (select count(*) from public.trades) >= 14,
  'signed in: trades are readable'
);
select throws_ok(
  $$insert into public.trades (id, family_id, name)
    values ('hacker', 'other', '{"en": "H", "ar": "ه"}')$$,
  '42501',
  null,
  'signed in: cannot add a trade'
);
select throws_ok(
  $$update public.places set name = '{"en": "X", "ar": "س"}' where id = 'kw-capital'$$,
  '42501',
  null,
  'signed in: cannot rename a place'
);
select throws_ok(
  $$delete from public.company_kinds$$,
  '42501',
  null,
  'signed in: cannot delete company kinds'
);
select throws_ok(
  $$update public.market_trades set visible = false$$,
  '42501',
  null,
  'signed in: cannot hide trades'
);

select * from finish();
rollback;
