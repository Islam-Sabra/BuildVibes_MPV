-- Migration 17: translate. Run with: supabase test db
--
-- Omar (c1) writes a post. Sara (c2) translates it. Bob (c3) is a stranger.

begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000017c1', 'authenticated', 'authenticated', 'omar17@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000017c2', 'authenticated', 'authenticated', 'sara17@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000017c3', 'authenticated', 'authenticated', 'bob17@example.com', '{"home_market_id": "kw"}');

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000017' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000017' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000017' || p)::uuid;
$$;

select ok((select relrowsecurity from pg_class where oid = 'public.post_translations'::regclass),
  'post_translations has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.translation_uses'::regclass),
  'translation_uses has row-level security');
select ok(not has_function_privilege('authenticated', 'public.cached_translation(uuid, text)', 'execute'),
  'a signed-in person can''t read the cache directly');
select ok(not has_function_privilege('authenticated', 'public.save_translation(uuid, text, text)', 'execute'),
  'or write it');
select ok(not has_function_privilege('authenticated', 'public.claim_translation(uuid)', 'execute'),
  'or count translations');
select ok(not has_function_privilege('anon', 'public.cached_translation(uuid, text)', 'execute'),
  'and anon can''t either');

select pg_temp.as_user('c1');
set local role authenticated;
select public.create_post(pg_temp.id('a001'), 'First pour on the podium transfer slab is done.', 'en');
reset role;

-- The cache ----------------------------------------------------------------------------

select is(public.cached_translation(pg_temp.id('a001'), 'ar'), null, 'nothing cached yet');
select public.save_translation(pg_temp.id('a001'), 'ar', 'تم صب البلاطة.');
select is(public.cached_translation(pg_temp.id('a001'), 'ar'), 'تم صب البلاطة.', 'a saved translation is used');
select public.save_translation(pg_temp.id('a001'), 'ar', 'تم صب بلاطة المنصة.');
select is((select count(*) from public.post_translations where post_id = pg_temp.id('a001')), 1::bigint,
  'one row per post and language: saving again replaces it');

update public.posts set edited_at = now() + interval '1 minute' where id = pg_temp.id('a001');
select is(public.cached_translation(pg_temp.id('a001'), 'ar'), null,
  'after the post is edited, the old translation isn''t used');

select throws_ok($$select public.save_translation(pg_temp.id('a001'), 'fr', 'Bonjour')$$, '23514', null,
  'only en and ar');

update public.posts set deleted_at = now() where id = pg_temp.id('a001');
select is(public.cached_translation(pg_temp.id('a001'), 'ar'), null, 'a deleted post has no translation');
select public.save_translation(pg_temp.id('a001'), 'en', 'x');
select is((select count(*) from public.post_translations where post_id = pg_temp.id('a001') and lang = 'en'),
  0::bigint, 'and none is saved for it');
update public.posts set deleted_at = null where id = pg_temp.id('a001');

-- Nobody reads the tables --------------------------------------------------------------

select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok($$select count(*) from public.post_translations$$, '42501', null,
  'a signed-in person can''t read post_translations');
select throws_ok($$select count(*) from public.translation_uses$$, '42501', null,
  'or translation_uses');
select throws_ok($$insert into public.post_translations (post_id, lang, body) values (gen_random_uuid(), 'ar', 'x')$$,
  '42501', null, 'or write a translation');
reset role;

-- 100 a day ------------------------------------------------------------------------------

insert into public.translation_uses (profile_id, created_at)
select pg_temp.uid('c2'), now() - interval '1 hour' from generate_series(1, 99);
insert into public.translation_uses (profile_id, created_at)
select pg_temp.uid('c2'), now() - interval '3 days' from generate_series(1, 50);
select ok(public.claim_translation(pg_temp.uid('c2')), 'the 100th translation today is allowed');
select ok(not public.claim_translation(pg_temp.uid('c2')), 'the 101st is refused');
select is((select count(*) from public.translation_uses
           where profile_id = pg_temp.uid('c2') and created_at > now() - interval '1 day'),
  100::bigint, 'and a refused one isn''t counted');
select ok(public.claim_translation(pg_temp.uid('c3')), 'someone else still can');
select is(public.prune_translation_uses(), 50, 'old counts can be cleaned up');

-- Deleting the post or the person cleans up ---------------------------------------------

select public.save_translation(pg_temp.id('a001'), 'ar', 'تم صب بلاطة المنصة.');
delete from public.posts where id = pg_temp.id('a001');
select is((select count(*) from public.post_translations where post_id = pg_temp.id('a001')), 0::bigint,
  'a post''s translations go with it');
delete from auth.users where id = pg_temp.uid('c2');
select is((select count(*) from public.translation_uses where profile_id = pg_temp.uid('c2')), 0::bigint,
  'and a person''s counts go with them');

select * from finish();
rollback;
