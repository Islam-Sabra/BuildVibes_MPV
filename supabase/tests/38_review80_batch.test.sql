-- Migration 38: review 80's batch (F75 version numbers, F94 a walk's
-- order, F86 Got it, F81 push tokens). Run with: supabase test db
--
-- Omar (e1) made the Space and is its admin (Lead). Rakesh (e2) and Sara
-- (e3) are Crew. Eve (e5) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000038' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@batch38.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e5')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e5', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000038' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000038' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000038' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000038' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
-- Run as the database owner: a Library file, as the app registers it.
create function pg_temp.file(p_id text, p_supersedes text) returns void language sql as $$
  insert into public.library_files (id, space_id, name, storage_path, mime, bytes,
                                    supersedes_id, uploaded_by)
  values (pg_temp.item(p_id), pg_temp.sp(), 'Door schedule',
          pg_temp.sp() || '/library/' || pg_temp.item(p_id) || '/d.pdf', 'application/pdf', 1000,
          case when p_supersedes is null then null else pg_temp.item(p_supersedes) end,
          pg_temp.uid('e1'));
$$;
create function pg_temp.no(p_id text) returns integer language sql as $$
  select version_no from public.library_files where id = pg_temp.item(p_id);
$$;
create function pg_temp.post_path(p_post text, p_file text) returns text language sql as $$
  select current_setting('test.space') || '/posts/' || pg_temp.item(p_post) || '/' || p_file;
$$;
create function pg_temp.upload(p_who text, p_path text) returns text language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('space-files', p_path, pg_temp.uid(p_who)::text,
          jsonb_build_object('mimetype', 'image/jpeg', 'size', 1000))
  returning name;
$$;
-- A post's card as [p_who] reads it.
create function pg_temp.card(p_who text, p_post text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_who);
  execute 'set local role authenticated';
  select d.card into v from public.daybook_card(pg_temp.item(p_post)) d;
  execute 'reset role';
  return v;
end;
$$;

-- Setup -----------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Batch site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e3', 'crew')) x(id, pass);

-- F75: version numbers ----------------------------------------------------------------------------

select pg_temp.file('f001', null);
select pg_temp.file('f002', 'f001');
select pg_temp.file('f003', 'f002');
select is(array[pg_temp.no('f001'), pg_temp.no('f002'), pg_temp.no('f003')], array[1, 2, 3],
  'versions are numbered V1, V2, V3 in the order they were added');
select is((select count(distinct chain_id)::integer from public.library_files
           where id in (pg_temp.item('f001'), pg_temp.item('f002'), pg_temp.item('f003'))), 1,
  'one chain');

update public.library_files set version_no = 9, chain_id = pg_temp.item('f003')
where id = pg_temp.item('f002');
select is(pg_temp.no('f002'), 2, 'a number never changes');
select is((select chain_id from public.library_files where id = pg_temp.item('f002')),
          pg_temp.item('f001'), 'nor its chain');

update public.library_files set deleted_at = now(), deleted_by = pg_temp.uid('e1')
where id = pg_temp.item('f002');
select pg_temp.file('f004', 'f003');
select is(array[pg_temp.no('f003'), pg_temp.no('f004')], array[3, 4],
  'a removed middle version renumbers nothing, and its number is not used again');

-- Two versions added at once, both replacing V1 of a new file.
select pg_temp.file('f101', null);
select pg_temp.file('f102', 'f101');
select pg_temp.file('f103', 'f101');
select is(array[pg_temp.no('f101'), pg_temp.no('f102'), pg_temp.no('f103')], array[1, 2, 3],
  'two versions added at once get 2 and 3');

select is(pg_temp.no('f201'), null, '(no file f201)');
select pg_temp.file('f201', null);
select is(pg_temp.no('f201'), 1, 'a new file is V1');

-- The post JSON: the number, the one it replaces, and the version in use.
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_space_post(pg_temp.item('a001'), pg_temp.sp(), 'file', 'Door schedule',
                                p_library_file => pg_temp.item('f101'));
select public.create_space_post(pg_temp.item('a002'), pg_temp.sp(), 'file', 'Door schedule',
                                p_library_file => pg_temp.item('f103'));
reset role;
select is(pg_temp.card('e2', 'a002') -> 'file' ->> 'version_no', '3', 'the card says V3');
select is(pg_temp.card('e2', 'a002') -> 'file' -> 'replaces' ->> 'version_no', '1',
  'and the version it replaces');
select is(pg_temp.card('e2', 'a001') -> 'file' -> 'newer' ->> 'version_no', '3',
  'the older post says which version replaced it');
select is(pg_temp.card('e2', 'a001') -> 'file' -> 'newer' ->> 'post_id', pg_temp.item('a002')::text,
  'with the post that carries it');
select is(pg_temp.card('e2', 'a002') -> 'file' -> 'newer', null, 'the version in use has no newer');

-- F94: a walk keeps its photos' order -------------------------------------------------------------

select pg_temp.upload('e1', pg_temp.post_path('b00' || n, n || '.jpg')) from generate_series(1, 5) n;
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_walk(
  pg_temp.sp(), pg_temp.item('b000'), 'Walk, level 2',
  (select jsonb_agg(jsonb_build_object(
            'id', pg_temp.item('b00' || n), 'line', 'Line ' || n, 'owner', pg_temp.uid('e2'),
            'photo', jsonb_build_object('path', pg_temp.post_path('b00' || n, n || '.jpg')))
          order by o)
   -- Photos taken 5 to 1: ids that sort the other way round, as random
   -- ones may.
   from unnest(array[5, 4, 3, 2, 1]) with ordinality v(n, o)));
reset role;
select is((select array_agg(r ->> 'title' order by o)
           from jsonb_array_elements(pg_temp.card('e2', 'b000') -> 'children' -> 'rows')
                with ordinality x(r, o)),
          array['Line 5', 'Line 4', 'Line 3', 'Line 2', 'Line 1'],
  'a 5-photo walk comes back in its photos'' order');

-- F86: the author never gives Got it --------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select public.create_space_post(pg_temp.item('c001'), pg_temp.sp(), 'announcement',
                                'Gate 2 closed');
select throws_ok($$ select public.ack(pg_temp.item('c001'), 'got_it') $$, '42501', null,
  'the author is refused Got it on their own announcement');
select lives_ok($$ select public.ack(pg_temp.item('c001'), 'got_it', false) $$,
  'taking nothing back is still fine');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select lives_ok($$ select public.ack(pg_temp.item('c001'), 'got_it') $$,
  'Rakesh gives Got it');
reset role;

-- F81: one token per install; FCM's answers kept ---------------------------------------------------

select pg_temp.as_user('e3');
set local role authenticated;
select public.register_push_token(repeat('a', 30), 'android', 'en',
                                  '00000000-0000-4000-8000-000000003801');
select public.register_push_token(repeat('t', 30), 'android', 'en',
                                  '00000000-0000-4000-8000-000000003802');
-- The phone's token changed: same install, new token.
select public.register_push_token(repeat('b', 30), 'android', 'ar',
                                  '00000000-0000-4000-8000-000000003801');
reset role;
select is((select array_agg(token order by token) from public.push_tokens
           where profile_id = pg_temp.uid('e3')),
          array[repeat('b', 30), repeat('t', 30)],
  'a new token replaces only the same install''s old one; the tablet keeps its own');
select pg_temp.as_user('e3');
set local role authenticated;
select lives_ok($$ select public.register_push_token(repeat('c', 30), 'ios') $$,
  'an older app with no install id still registers');
reset role;
select ok(not has_function_privilege('authenticated', 'public.finish_push(bigint, text, jsonb)',
                                     'execute'),
  'only the push function finishes a push');

insert into public.push_queue (profile_id, kind, data)
values (pg_temp.uid('e3'), 'follow', '{}') returning id \gset q_
select public.finish_push(:q_id, null,
  '[{"platform": "android", "token": "bbbbbb", "status": 200, "outcome": "sent"}]');
select is((select answers -> 0 ->> 'outcome' from public.push_queue where id = :q_id), 'sent',
  'FCM''s answer for each phone is kept on the row');
select throws_ok(format('select public.finish_push(%s, null, %L::jsonb)', :q_id,
                        '{"not": "a list"}'), '23514', null,
  'answers are a list');

select * from finish();
rollback;
