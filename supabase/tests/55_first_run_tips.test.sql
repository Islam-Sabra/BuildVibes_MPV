-- Migration 20261116120000 (review 107 OB7): the first-run tips each
-- account has seen. profile_tips_seen is the owner's own: read through its
-- policy, written only by mark_tip_seen. Another user can neither read nor
-- write it. The lead's check of r107: Q1 invite_preview also gives the
-- Space's market (its project's), so the invite's market is the home
-- market; Q6 nine popular trades in each market pack. Run with:
-- supabase test db
--
-- Omar (a1) sees the tips; Rakesh (b2) is someone else.

begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000055' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@tips55.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000055' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000055' || p_id)::uuid;
$$;
-- The tips [p_id] has seen, read as the superuser.
create function pg_temp.seen(p_id text) returns text[] language sql as $$
  select coalesce(array_agg(t.tip order by t.tip), '{}')
  from public.profile_tips_seen t where t.profile_id = pg_temp.uid(p_id);
$$;

-- The table and its rules --------------------------------------------------------------------------

select has_table('public', 'profile_tips_seen', 'profile_tips_seen exists');
select ok((select relrowsecurity from pg_class where oid = 'public.profile_tips_seen'::regclass),
  'with row-level security on');
select ok(not has_table_privilege('authenticated', 'public.profile_tips_seen', 'insert')
          and not has_table_privilege('authenticated', 'public.profile_tips_seen', 'update')
          and not has_table_privilege('authenticated', 'public.profile_tips_seen', 'delete'),
  'nobody writes it directly');
select ok(not has_table_privilege('anon', 'public.profile_tips_seen', 'select'),
  'anon can''t read it');

-- Omar sees two tips -------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.mark_tip_seen('camera')$$, 'Omar marks the camera tip seen');
select lives_ok($$select public.mark_tip_seen('camera')$$, 'again: no error, no second row');
select lives_ok($$select public.mark_tip_seen('hold')$$, 'and the hold tip');
select is((select array_agg(tip order by tip) from public.profile_tips_seen),
  array['camera', 'hold'], 'he reads his own');
select throws_ok($$select public.mark_tip_seen('confetti')$$, '22023', null,
  'a tip that doesn''t exist is refused');
select throws_ok($$insert into public.profile_tips_seen (profile_id, tip)
  values (pg_temp.uid('a1'), 'sign_done')$$, '42501', null,
  'not even his own row is written directly');
reset role;
select is(pg_temp.seen('a1'), array['camera', 'hold'], 'two rows, the repeat kept once');

-- Rakesh can't read or write Omar's ----------------------------------------------------------------

select pg_temp.as_user('b2');
set local role authenticated;
select is((select count(*) from public.profile_tips_seen)::integer, 0,
  'another user reads none of Omar''s');
select throws_ok($$insert into public.profile_tips_seen (profile_id, tip)
  values (pg_temp.uid('a1'), 'sign_done')$$, '42501', null,
  'nor writes a row for him');
select throws_ok($$update public.profile_tips_seen set seen_at = now() - interval '1 year'
  where profile_id = pg_temp.uid('a1')$$, '42501', null, 'nor changes his rows');
select throws_ok($$delete from public.profile_tips_seen where profile_id = pg_temp.uid('a1')$$,
  '42501', null, 'nor deletes them');
select lives_ok($$select public.mark_tip_seen('sign_done')$$,
  'mark_tip_seen marks only the caller''s own');
reset role;
select is(pg_temp.seen('a1'), array['camera', 'hold'],
  'Omar''s are unchanged: nothing updated, deleted or added');
select is(pg_temp.seen('b2'), array['sign_done'], 'Rakesh has his own');

-- Signed out ---------------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select throws_ok($$select public.mark_tip_seen('camera')$$, '42501', null,
  'signed out: can''t mark a tip');
reset role;

-- Q1: the invite's market ------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Tower B')::text, true);
select set_config('test.code',
  (select code from public.current_invite(current_setting('test.space')::uuid)), true);
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select is((select space_name from public.invite_preview(current_setting('test.code'))), 'Tower B',
  'the code opens Tower B');
select is((select market_id from public.invite_preview(current_setting('test.code'))), null,
  'a Space with no project: no market');
reset role;
insert into public.projects (id, name, type_id, market_id)
values ('00000000-0000-0000-0000-000000550001', 'Tower B',
        (select id from public.project_types limit 1), 'eg');
update public.spaces set project_id = '00000000-0000-0000-0000-000000550001'
where id = current_setting('test.space')::uuid;
select pg_temp.as_user('b2');
set local role authenticated;
select is((select market_id from public.invite_preview(current_setting('test.code'))), 'eg',
  'with a project: its market');
reset role;

-- Q6: nine trades on OB5 ---------------------------------------------------------------------------

select is((select count(*) from public.market_trades
           where market_id = 'kw' and popular_sort is not null)::integer,
  9, 'Kuwait has nine popular trades');
select is((select count(*) from public.market_trades
           where market_id = 'eg' and popular_sort is not null)::integer,
  9, 'Egypt too');
select is((select array_agg(trade_id order by popular_sort) from public.market_trades
           where market_id = 'kw' and popular_sort > 7),
  array['carpenter', 'mason'], 'Carpenter and Mason after the seven');

-- The function -------------------------------------------------------------------------------------

select is((select prosecdef from pg_proc where oid = 'public.mark_tip_seen(text)'::regprocedure),
  true, 'mark_tip_seen is security definer');
select ok((select proconfig from pg_proc where oid = 'public.mark_tip_seen(text)'::regprocedure)
          @> array['search_path=""'], 'with an empty search_path');

select * from finish();
rollback;
