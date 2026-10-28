-- Migration 49 (review 102 N3): entries arranged by hand within their day.
-- notes.day_position, set only by arrange_day: the owner's entries of one
-- page and one day, in their new order. Run with: supabase test db
--
-- Omar (a1) owns the notebook; Rakesh (b2) is someone else, with an entry
-- of his own.

begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000049' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@daypos49.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000049' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000049' || p)::uuid;
$$;
-- The day positions of [p_ids], in that order.
create function pg_temp.pos(p_ids uuid[]) returns integer[] language sql as $$
  select array_agg(n.day_position order by i.o)
  from unnest(p_ids) with ordinality i(id, o) join public.notes n on n.id = i.id;
$$;

-- Setup: Omar's page with three entries today and one yesterday; a second
-- page with one today; Rakesh's entry.
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.create_notebook_page(pg_temp.id('e001'), 'Site log')$$, 'a page');
select lives_ok($$select public.create_notebook_page(pg_temp.id('e002'), 'Snags')$$, 'another');
select lives_ok($$
  select public.save_entry(p_id => pg_temp.id(x.id), p_kind => 'text', p_page => pg_temp.id(x.page),
                           p_title => x.id)
  from (values ('b001', 'e001'), ('b002', 'e001'), ('b003', 'e001'), ('b004', 'e001'),
               ('b005', 'e002')) x(id, page)
$$, 'five entries');
reset role;
-- Times as the page shows them: b003 newest today, b004 yesterday.
update public.notes set created_at = now() - interval '3 hours' where id = pg_temp.id('b001');
update public.notes set created_at = now() - interval '2 hours' where id = pg_temp.id('b002');
update public.notes set created_at = now() - interval '1 hour' where id = pg_temp.id('b003');
update public.notes set created_at = now() - interval '30 hours' where id = pg_temp.id('b004');
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok($$select public.create_notebook_page(pg_temp.id('e003'), 'Mine')$$, 'Rakesh''s page');
select lives_ok($$select public.save_entry(p_id => pg_temp.id('b006'), p_kind => 'text',
  p_page => pg_temp.id('e003'), p_title => 'His')$$, 'Rakesh''s entry');
reset role;

-- The column ---------------------------------------------------------------------------------------

select has_column('public', 'notes', 'day_position', 'notes.day_position');
select is(pg_temp.pos(array[pg_temp.id('b001'), pg_temp.id('b002'), pg_temp.id('b003')]),
  array[null, null, null]::integer[], 'none until arranged: the time order');

-- Arranging ----------------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.arrange_day(array[pg_temp.id('b001'), pg_temp.id('b003'), pg_temp.id('b002')])$$,
  'Omar arranges today');
select is(pg_temp.pos(array[pg_temp.id('b001'), pg_temp.id('b003'), pg_temp.id('b002')]),
  array[1, 2, 3], 'each takes its place, 1 at the top');
select lives_ok($$select public.arrange_day(array[pg_temp.id('b002'), pg_temp.id('b001'), pg_temp.id('b003')])$$,
  'again');
select is(pg_temp.pos(array[pg_temp.id('b002'), pg_temp.id('b001'), pg_temp.id('b003')]),
  array[1, 2, 3], 'the new order');
select is((select title from public.notes where id = pg_temp.id('b001')), 'b001',
  'nothing else of the entry changes');

-- Refused ------------------------------------------------------------------------------------------

select throws_ok($$select public.arrange_day(array[pg_temp.id('b001'), pg_temp.id('b004')])$$,
  '22023', 'entries of one day', 'not across days');
select throws_ok($$select public.arrange_day(array[pg_temp.id('b001'), pg_temp.id('b005')])$$,
  '22023', 'entries of one page', 'not across pages');
select throws_ok($$select public.arrange_day(array[pg_temp.id('b001'), pg_temp.id('b001')])$$,
  '22023', 'two or more entries, each once', 'each once');
select throws_ok($$select public.arrange_day(array[pg_temp.id('b001'), pg_temp.id('b006')])$$,
  '42501', 'not allowed', 'not with someone else''s entry');
reset role;

select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.arrange_day(array[pg_temp.id('b002'), pg_temp.id('b001')])$$,
  '42501', 'not allowed', 'someone else can''t move Omar''s entries');
reset role;
select is(pg_temp.pos(array[pg_temp.id('b002'), pg_temp.id('b001')]), array[1, 2],
  'Omar''s order is as he left it');

select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select public.arrange_day(array[pg_temp.id('b002'), pg_temp.id('b001')])$$,
  '42501', null, 'signed out: refused');
reset role;

select * from finish();
rollback;
