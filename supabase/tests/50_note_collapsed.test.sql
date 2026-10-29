-- Migration 50 (review 106 T2): an entry folded in its page. notes.collapsed,
-- set only by set_notes_collapsed: the owner's own entries. Run with:
-- supabase test db
--
-- Omar (a1) owns the notebook; Rakesh (b2) is someone else, with an entry
-- of his own.

begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000050' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@collapsed50.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000050' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000050' || p)::uuid;
$$;
create function pg_temp.folded(p text) returns boolean language sql as $$
  select collapsed from public.notes where id = pg_temp.id(p);
$$;

-- Setup: Omar's page with two entries; Rakesh's page with one.
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.create_notebook_page(pg_temp.id('e001'), 'Site log')$$, 'a page');
select lives_ok($$
  select public.save_entry(p_id => pg_temp.id(x.id), p_kind => 'text', p_page => pg_temp.id('e001'),
                           p_title => x.id)
  from (values ('b001'), ('b002')) x(id)
$$, 'two entries');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok($$select public.create_notebook_page(pg_temp.id('e002'), 'Mine')$$, 'Rakesh''s page');
select lives_ok($$select public.save_entry(p_id => pg_temp.id('b003'), p_kind => 'text',
  p_page => pg_temp.id('e002'), p_title => 'His')$$, 'Rakesh''s entry');
reset role;

-- The column ---------------------------------------------------------------------------------------

select col_not_null('public', 'notes', 'collapsed', 'notes.collapsed is not null');
select col_default_is('public', 'notes', 'collapsed', 'false', 'open by default');

-- The owner ----------------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.set_notes_collapsed(array[pg_temp.id('b001'), pg_temp.id('b002')], true)$$,
  'Omar folds his two entries (Collapse all)');
select is(pg_temp.folded('b001') and pg_temp.folded('b002'), true, 'both folded');
select lives_ok($$select public.set_notes_collapsed(array[pg_temp.id('b002')], false)$$, 'one opened again');
select is(pg_temp.folded('b002'), false, 'open');
select is((select title from public.notes where id = pg_temp.id('b001')), 'b001',
  'nothing else of the entry changes');
select throws_ok($$select public.set_notes_collapsed(array[pg_temp.id('b001'), pg_temp.id('b003')], true)$$,
  '42501', 'not allowed', 'not with someone else''s entry');
reset role;

-- Someone else -------------------------------------------------------------------------------------

select pg_temp.as_user('b2');
set local role authenticated;
select is((select count(*) from public.notes where id = pg_temp.id('b001'))::integer, 0,
  'someone else can''t read Omar''s entry, nor its fold');
select throws_ok($$select public.set_notes_collapsed(array[pg_temp.id('b002')], true)$$,
  '42501', 'not allowed', 'someone else can''t fold Omar''s entry');
reset role;

select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select public.set_notes_collapsed(array[pg_temp.id('b002')], true)$$,
  '42501', null, 'signed out: refused');
reset role;

select * from finish();
rollback;
