-- Migration 4: profiles and project records.
-- Run with: supabase test db
--
-- Alice (a1) creates and lists projects; Bob (b2) looks; Carol (c3) is
-- blocked by Alice.

begin;
create extension if not exists pgtap with schema extensions;
select plan(32);

insert into auth.users (id, aud, role, phone, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', 'authenticated', 'authenticated', '96550000011', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000000b2', 'authenticated', 'authenticated', '96550000012', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000000c3', 'authenticated', 'authenticated', '96550000013', '{"home_market_id": "kw"}');

-- Signed out --------------------------------------------------------------------------

set local role anon;
select throws_ok($$select * from public.projects$$, '42501', null,
  'signed out: projects are not readable');
select throws_ok(
  $$select public.create_project('X Tower', 'residential', 'kw')$$,
  '42501', null, 'signed out: cannot create a project');

-- Alice --------------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000a1", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$select public.create_project('Al Kout Mall', 'commercial', 'kw', 'kw-fahaheel',
      null, '2019-01-01', '2021-06-01', false)$$,
  'you can create a project record');
select lives_ok(
  $$select public.create_project('Al Kout Mall Car Park', 'infrastructure', 'kw', 'kw-fahaheel')$$,
  'a second record on the same site');
select throws_ok(
  $$insert into public.projects (name, type_id, market_id) values ('Typed', 'retail', 'kw')$$,
  '42501', null, 'projects are never inserted directly');
select throws_ok(
  $$update public.projects set name = 'Renamed' where name = 'Al Kout Mall'$$,
  '42501', null, 'nobody can edit a project: there is no owner');
select throws_ok(
  $$delete from public.projects where name = 'Al Kout Mall'$$,
  '42501', null, 'nobody can delete a project');
select throws_ok(
  $$select public.create_project('Bad place', 'commercial', 'kw', 'eg-cairo')$$,
  '23514', null, 'a project''s place must be in its market');
select throws_ok(
  $$select public.create_project('Backwards', 'commercial', 'kw', null, null,
      '2024-01-01', '2023-01-01', false)$$,
  '23514', null, 'a project cannot end before it starts');

-- "Is it already here?"
select is(
  (select reason from public.find_similar_projects('al kout mall phase 2', null)
   where name = 'Al Kout Mall'),
  'same_name',
  'a similar name is found, whatever the case');
select is(
  (select count(*) from public.find_similar_projects('Gulf Bank HQ', 'kw-fahaheel')
   where reason = 'same_site'),
  2::bigint,
  'records on the same site are offered too');
select is(
  (select count(*) from public.find_similar_projects('Nothing like it', 'kw-capital')),
  0::bigint,
  'nothing unrelated is offered');

-- On the CV.
select lives_ok(
  $$insert into public.cv_projects (project_id, role_title, start_month, end_month)
    select id, 'BIM Manager', '2019-03-01', null from public.projects
    where name = 'Al Kout Mall'$$,
  'you can add a project to your CV');
select lives_ok(
  $$insert into public.cv_projects (project_id, role_title, show_on_profile)
    select id, 'Coordinator', false from public.projects
    where name = 'Al Kout Mall Car Park'$$,
  'a CV project can be kept off the profile');
select throws_ok(
  $$insert into public.cv_projects (profile_id, project_id, role_title)
    select '00000000-0000-0000-0000-0000000000b2', id, 'Fake'
    from public.projects where name = 'Al Kout Mall'$$,
  '42501', null, 'you cannot add a project to someone else''s CV');

-- Suggest an edit.
select lives_ok(
  $$insert into public.project_edit_suggestions (project_id, field, correct_value)
    select id, 'dates', 'Ended: expected Mar 2027' from public.projects
    where name = 'Al Kout Mall'$$,
  'anyone can suggest an edit');
select throws_ok(
  $$insert into public.project_edit_suggestions (project_id, field, correct_value, status)
    select id, 'name', 'X', 'accepted' from public.projects where name = 'Al Kout Mall'$$,
  '42501', null, 'a suggestion cannot accept itself');
select throws_ok(
  $$update public.project_edit_suggestions set status = 'accepted'$$,
  '42501', null, 'suggestions are reviewed only in the back office');

-- Open to: only connections.
select lives_ok(
  $$insert into public.profile_open_to (profile_id, options, note, visibility)
    values ('00000000-0000-0000-0000-0000000000a1', '{consulting}', 'From next month', 'connections')$$,
  'you can say what you are open to');
select throws_ok(
  $$insert into public.profile_open_to (profile_id, options)
    values ('00000000-0000-0000-0000-0000000000a1', '{jobs}')$$,
  '23514', null, 'only the listed "open to" options');

-- Alice blocks Carol.
insert into public.blocks (blocker_id, blocked_id)
  values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c3');

-- Storage: only your own folder.
select lives_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('avatars', '00000000-0000-0000-0000-0000000000a1/photo.jpg')$$,
  'you can upload a photo to your own folder');
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('avatars', '00000000-0000-0000-0000-0000000000b2/photo.jpg')$$,
  '42501', null, 'you cannot upload into someone else''s folder');

-- Bob ------------------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000b2", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*) from public.projects), 2::bigint,
  'signed in: project records are readable');
select is(
  (select count(*) from public.cv_projects
   where profile_id = '00000000-0000-0000-0000-0000000000a1'),
  1::bigint,
  'others see only the CV projects that are shown');
select is((select count(*) from public.project_edit_suggestions), 0::bigint,
  'you cannot read other people''s suggestions');
select is((select count(*) from public.profile_open_to), 0::bigint,
  '"open to" for connections is hidden from someone not connected');
select lives_ok(
  $$update public.cv_projects set role_title = 'Hacked'$$,
  'editing someone else''s CV runs but changes nothing');

insert into public.follows (follower_id, followee_id) values
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a1');
reset role;
insert into public.follows (follower_id, followee_id) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b2');
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000b2", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.profile_open_to), 1::bigint,
  'connected (follow both ways): "open to" shows');

-- Carol (blocked by Alice) ------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000c3", "role": "authenticated"}', true);
set local role authenticated;

select is(
  (select count(*) from public.cv_projects
   where profile_id = '00000000-0000-0000-0000-0000000000a1'),
  0::bigint,
  'a blocked user cannot see the blocker''s CV projects');

reset role;
select is(
  (select role_title from public.cv_projects
   where role_title in ('BIM Manager', 'Hacked')),
  'BIM Manager',
  'Alice''s CV was not changed by Bob');
select is(
  (select status from public.project_edit_suggestions limit 1),
  'pending',
  'a new suggestion waits for review');
select ok(
  (select public from storage.buckets where id = 'avatars'),
  'the avatars bucket exists');

select * from finish();
rollback;
