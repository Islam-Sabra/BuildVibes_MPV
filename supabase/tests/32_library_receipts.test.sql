-- Migration 32: who received a Library file, NEW VERSION for me, and
-- search shows only the version in use (review 67). Run with: supabase
-- test db
--
-- Omar (e1) made the Space and is its admin (Lead). Rakesh (e2) and Sara
-- (e3) are Crew, Vera (e4) a Viewer, Tariq (e6) Crew in the MEP Team. Eve
-- (e5) is not in the Space.
--
-- Omar posts the door schedule Rev C (f001, post a001), then Rev D (f002,
-- post a002) replacing it, and an MEP Team file (f003, post a003).

begin;
create extension if not exists pgtap with schema extensions;
select plan(41);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000032' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@libreceipts32.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e5'), ('e6')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e4', 'Vera', 'Lane'), ('e5', 'Eve', 'Out'), ('e6', 'Tariq', 'Aziz')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000032' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000032' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000032' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000032' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
-- Run as the database owner: a Library file, as the app registers it.
create function pg_temp.file(p_id text, p_name text, p_rev text, p_supersedes text,
                             p_team uuid) returns void language sql as $$
  insert into public.library_files (id, space_id, team_id, name, storage_path, mime, bytes,
                                    rev_label, supersedes_id, uploaded_by)
  values (pg_temp.item(p_id), pg_temp.sp(), p_team, p_name,
          pg_temp.sp() || '/library/' || pg_temp.item(p_id) || '/d.pdf', 'application/pdf', 1000,
          p_rev, case when p_supersedes is null then null else pg_temp.item(p_supersedes) end,
          pg_temp.uid('e1'));
$$;
create function pg_temp.files() returns uuid[] language sql as $$
  select coalesce(array_agg(o.file_id order by o.file_id), '{}') from public.library_overview(pg_temp.sp()) o;
$$;
create function pg_temp.new_for_me(p_file text) returns boolean language sql as $$
  select o.new_for_me from public.library_overview(pg_temp.sp()) o where o.file_id = pg_temp.item(p_file);
$$;
create function pg_temp.faces(p_file text) returns text[] language sql as $$
  select coalesce(array_agg(r ->> 'name' order by n), '{}')
  from public.library_overview(pg_temp.sp()) o,
       jsonb_array_elements(o.received) with ordinality x(r, n)
  where o.file_id = pg_temp.item(p_file);
$$;
create function pg_temp.receivers(p_file text) returns text[] language sql as $$
  select coalesce(array_agg(r.name order by r.at, r.profile_id), '{}')
  from public.library_file_receipts(pg_temp.item(p_file)) r;
$$;
create function pg_temp.search_files(p_q text) returns uuid[] language sql as $$
  select coalesce(array_agg(s.id order by s.id), '{}')
  from public.search_space(pg_temp.sp(), p_q) s where s.kind = 'file';
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Library site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e3', 'crew'), ('e4', 'viewer'), ('e6', 'crew')) x(id, pass);
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('e6')])::text, true);
reset role;
select pg_temp.file('f001', 'Door schedule', 'Rev C', null, null);
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_space_post(pg_temp.item('a001'), pg_temp.sp(), 'file', null,
                                p_library_file => pg_temp.item('f001'));
select pg_temp.as_user('e2');
select public.ack(pg_temp.item('a001'), 'received');
reset role;
select pg_temp.file('f002', 'Door schedule', 'Rev D', 'f001', null);
select pg_temp.file('f003', 'MEP riser', 'Rev A', null, pg_temp.team());
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_space_post(pg_temp.item('a002'), pg_temp.sp(), 'file', null,
                                p_library_file => pg_temp.item('f002'));
select public.create_space_post(pg_temp.item('a003'), pg_temp.sp(), 'file', null,
                                p_team => pg_temp.team(), p_library_file => pg_temp.item('f003'));
select pg_temp.as_user('e3');
select public.ack(pg_temp.item('a002'), 'received');
select pg_temp.as_user('e6');
select public.ack(pg_temp.item('a003'), 'received');
-- The setup's receipts move back half an hour (a test runs in one transaction).
reset role;
update public.post_acks set created_at = now() - interval '30 minutes' where created_at = now();
set local role authenticated;

-- The Library list ----------------------------------------------------------------------------

select pg_temp.as_user('e2');
select is(pg_temp.files(), array[pg_temp.item('f002')],
  'Rakesh sees only Rev D: Rev C is replaced, and the Team file is not his');
select is(pg_temp.new_for_me('f002'), true,
  'Rev D is new for Rakesh: it replaces Rev C and he has not received it');
select is(pg_temp.faces('f002'), array['Sara Ali'], 'the faces are who received Rev D');
select public.ack(pg_temp.item('a002'), 'received');
select is(pg_temp.new_for_me('f002'), false, 'once Rakesh marks Received, it is not new for him');
select is(pg_temp.faces('f002'), array['Rakesh Nair', 'Sara Ali'], 'newest receiver first');

select pg_temp.as_user('e3');
select is(pg_temp.new_for_me('f002'), false, 'Sara received it: not new for her');
select pg_temp.as_user('e1');
select is(pg_temp.new_for_me('f002'), false, 'never new for the one who posted it');
select is(pg_temp.files(), array[pg_temp.item('f002'), pg_temp.item('f003')],
  'the Space admin also sees the Team file');
select is(pg_temp.new_for_me('f003'), false, 'a first version is never NEW VERSION');
select pg_temp.as_user('e4');
select is(pg_temp.files(), array[pg_temp.item('f002')], 'a Viewer sees the file in use');
select is(pg_temp.new_for_me('f002'), true, 'and it is new for her');
select pg_temp.as_user('e6');
select is(pg_temp.faces('f003'), array['Tariq Aziz'], 'the Team sees who received its file');

-- Who received a file -------------------------------------------------------------------------

select pg_temp.as_user('e2');
select is(pg_temp.receivers('f002'), array['Sara Ali', 'Rakesh Nair'], 'receipts oldest first');
select is((select array_agg(r.mine order by r.at) from public.library_file_receipts(pg_temp.item('f002')) r),
  array[false, true], 'mine is marked');
select is(pg_temp.receivers('f001'), array['Rakesh Nair'], 'an older version keeps its own receipts');
select is(pg_temp.receivers('f003'), '{}'::text[], 'nothing from a Team file outside the Team');
select is(public.library_file_post(pg_temp.item('f002')), pg_temp.item('a002'),
  'the post to mark Received through');
select is(public.library_file_post(pg_temp.item('f003')), null, 'no Team post outside the Team');

-- A block either way leaves the person out.
select pg_temp.as_user('e3');
select public.block(pg_temp.uid('e2'), true);
select is(pg_temp.receivers('f002'), array['Sara Ali'], 'Sara blocked Rakesh: he is left out');
select is(pg_temp.faces('f002'), array['Sara Ali'], 'and from the faces');
select pg_temp.as_user('e2');
select is(pg_temp.receivers('f002'), array['Rakesh Nair'], 'and she is left out for him');
select pg_temp.as_user('e3');
select public.block(pg_temp.uid('e2'), false);

-- Outsiders and anon --------------------------------------------------------------------------

select pg_temp.as_user('e5');
select is(pg_temp.files(), '{}'::uuid[], 'Eve, not in the Space, gets no list');
select is(pg_temp.receivers('f002'), '{}'::text[], 'nor who received a file');
select is(public.library_file_post(pg_temp.item('f002')), null, 'nor the post');
select throws_ok($$select public.library_file_in_force(pg_temp.item('f001'))$$, '42501', null,
  'the in-use check is internal');
reset role;
set local role anon;
select throws_ok($$select * from public.library_overview(pg_temp.sp())$$, '42501', null,
  'anon cannot read the list');
select throws_ok($$select * from public.library_file_receipts(pg_temp.item('f002'))$$, '42501', null,
  'nor receipts');
select throws_ok($$select public.library_file_post(pg_temp.item('f002'))$$, '42501', null,
  'nor the post');
reset role;

-- Search: only the version in use ---------------------------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.search_files('door'), array[pg_temp.item('f002')], 'search finds Rev D, not Rev C');
select is(pg_temp.search_files('riser'), '{}'::uuid[], 'nor a Team file outside the Team');
select pg_temp.as_user('e6');
select is(pg_temp.search_files('riser'), array[pg_temp.item('f003')], 'the Team finds its file');

-- A cancelled post is no way to mark Received; a deleted Rev D gives Rev C back.
select pg_temp.as_user('e1');
reset role;
update public.space_posts set status = 'cancelled', cancelled_at = now() where id = pg_temp.item('a002');
update public.library_files set deleted_at = now() where id = pg_temp.item('f002');
select pg_temp.as_user('e2');
set local role authenticated;
select is(public.library_file_post(pg_temp.item('f002')), null, 'no post once it is cancelled and the file deleted');
select is(pg_temp.files(), array[pg_temp.item('f001')], 'Rev D deleted: Rev C is in use again');
select is(pg_temp.search_files('door'), array[pg_temp.item('f001')], 'and search finds Rev C');

-- A deleted middle version is see-through: Rev E replaces Rev C through the deleted Rev D.
reset role;
select pg_temp.file('f004', 'Door schedule', 'Rev E', 'f002', null);
set local role authenticated;
select is(pg_temp.files(), array[pg_temp.item('f004')], 'Rev E in use; Rev C stays replaced');
select is(pg_temp.search_files('door'), array[pg_temp.item('f004')], 'and search finds only Rev E');

-- Faces: at most 4, newest first; someone who received it twice shows once.
reset role;
select pg_temp.file('f005', 'Site plan', 'Rev A', null, null);
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_space_post(pg_temp.item('a005'), pg_temp.sp(), 'file', null,
                                p_library_file => pg_temp.item('f005'));
select public.create_space_post(pg_temp.item('a006'), pg_temp.sp(), 'file', 'Site plan again',
                                p_library_file => pg_temp.item('f005'));
select public.ack(pg_temp.item('a005'), 'received');
reset role;
update public.post_acks set created_at = now() - interval '50 minutes' where created_at = now();
select pg_temp.as_user('e3');
set local role authenticated;
select public.ack(pg_temp.item('a005'), 'received');
reset role;
update public.post_acks set created_at = now() - interval '40 minutes' where created_at = now();
select pg_temp.as_user('e2');
set local role authenticated;
select public.ack(pg_temp.item('a005'), 'received');
reset role;
update public.post_acks set created_at = now() - interval '30 minutes' where created_at = now();
select pg_temp.as_user('e4');
set local role authenticated;
select public.ack(pg_temp.item('a005'), 'received');
reset role;
update public.post_acks set created_at = now() - interval '20 minutes' where created_at = now();
select pg_temp.as_user('e6');
set local role authenticated;
select public.ack(pg_temp.item('a005'), 'received');
select pg_temp.as_user('e3');
select public.ack(pg_temp.item('a006'), 'received');
select is(pg_temp.faces('f005'), array['Tariq Aziz', 'Vera Lane', 'Rakesh Nair', 'Sara Ali'],
  'four faces, newest first; Sara once, at her first Received');
select is(pg_temp.receivers('f005'),
  array['Omar Haddad', 'Sara Ali', 'Rakesh Nair', 'Vera Lane', 'Tariq Aziz'],
  'the file page lists everyone, oldest first, each once');
select is(public.library_file_post(pg_temp.item('f005')), pg_temp.item('a006'),
  'the newest live post is the one to mark Received through');

-- A former member reads nothing.
reset role;
update public.space_members set left_at = now() where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e4');
select pg_temp.as_user('e4');
set local role authenticated;
select is(pg_temp.files(), '{}'::uuid[], 'Vera left: no list');
select is(pg_temp.receivers('f005'), '{}'::text[], 'and no receipts');

select * from finish();
rollback;
