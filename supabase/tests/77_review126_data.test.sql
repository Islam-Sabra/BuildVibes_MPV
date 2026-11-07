-- Migration 20261204120000 (review 126 P2 + P3, stage 1: data and server).
-- Run with: supabase test db
--
-- Omar (a1) has projects on his CV. Khalid (b2) is tagged on one as a
-- teammate. Tariq (c3) is a stranger. Lina (d4) and Omar block each other.
-- Eve (e5) is in a Space (for the phone step of Finish your profile). The
-- Space "Tower 126d" is Omar's; he posted a photo there, and so did Khalid.

begin;
create extension if not exists pgtap with schema extensions;
select plan(70);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-00000001260' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@r126d.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('1'), ('2'), ('3'), ('4'), ('5')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('1', 'Omar', 'Haddad'), ('2', 'Khalid', 'Mansour'), ('3', 'Tariq', 'Rahman'),
             ('4', 'Lina', 'Saad'), ('5', 'Eve', 'Space')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-00000001260' || n.id)::uuid;

create function pg_temp.uid(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000001260' || p)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000126d' || p)::uuid;
$$;
create function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-00000001260' || p || '", "role": "authenticated"}', true);
$$;
-- How many of Omar's CV entries [p_who] reads.
create function pg_temp.reads(p_who text, p_entry uuid) returns boolean language plpgsql as $$
declare v boolean;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  select exists (select 1 from public.cv_projects where id = p_entry) into v;
  reset role;
  return v;
end;
$$;
create function pg_temp.media_seen(p_who text, p_entry uuid) returns integer language plpgsql as $$
declare v integer;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  select count(*)::int into v from public.cv_project_media where cv_project_id = p_entry;
  reset role;
  return v;
end;
$$;
create function pg_temp.mates_seen(p_who text, p_entry uuid) returns integer language plpgsql as $$
declare v integer;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  select count(*)::int into v from public.cv_project_teammates where cv_project_id = p_entry;
  reset role;
  return v;
end;
$$;
create function pg_temp.timeline(p_who text, p_of text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  v := public.experience_timeline(pg_temp.uid(p_of));
  reset role;
  return v;
end;
$$;
create function pg_temp.completion(p_who text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  v := public.my_profile_completion();
  reset role;
  return v;
end;
$$;

-- Setup ----------------------------------------------------------------------------------------------

insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('4'), pg_temp.uid('1'));
insert into public.companies (id, name, kind_id, market_id)
values (pg_temp.id('c001'), 'Harbour Contracting', (select id from public.company_kinds limit 1), 'kw'),
       (pg_temp.id('c002'), 'Gulf MEP', (select id from public.company_kinds limit 1), 'kw'),
       (pg_temp.id('c003'), 'Third Co', (select id from public.company_kinds limit 1), 'kw');
insert into public.projects (id, name, type_id, market_id)
values (pg_temp.id('b001'), 'Harbour Tower', 'residential', 'kw'),
       (pg_temp.id('b002'), 'Old Mall', 'commercial', 'kw');
insert into public.cv_projects (id, profile_id, project_id, role_title, show_on_profile, end_month, start_month)
values (pg_temp.id('e001'), pg_temp.uid('1'), pg_temp.id('b001'), 'BIM Manager', true, null, '2025-01-01'),
       (pg_temp.id('e002'), pg_temp.uid('1'), pg_temp.id('b002'), 'Engineer', false, '2024-06-01', '2023-01-01');

-- Reference data (market pack, not code) -------------------------------------------------------------

select is((select array_agg(id order by sort) from public.project_kinds),
  array['building', 'infrastructure', 'interior', 'design_study', 'software', 'website', 'plugin_tool',
        'research', 'course', 'other'], 'ten kinds of project, in order');
select is((select array_agg(id order by sort) from public.project_kinds where physical),
  array['building', 'infrastructure', 'interior'], 'three of them are physical');
select is((select array_agg(id order by sort) from public.project_stages),
  array['design', 'tender', 'construction', 'handover'], 'four stages');
select ok((select count(*) from public.market_tools where market_id = 'kw') >= 5, 'a tool list for Kuwait');
select ok((select count(*) from public.market_tools where market_id = 'eg') >= 5, 'and for Egypt');

-- Projects for any kind of work -------------------------------------------------------------------

select is((select kind_id from public.projects where id = pg_temp.id('b001')), 'building',
  'an existing project is a building');
select pg_temp.as_user('1');
set local role authenticated;
select lives_ok($$select public.create_project('BuildVibes app', null, 'kw', p_kind_id => 'software')$$,
  'a software project needs no building type and no place');
select throws_ok($$select public.create_project('A tower', null, 'kw', p_kind_id => 'building')$$,
  '23514', null, 'a building still needs its type');
select lives_ok($$select public.create_project('A bridge', 'commercial', 'kw', p_kind_id => 'infrastructure',
                                               p_stage_id => 'construction')$$,
  'a stage is kept');
select throws_ok($$select public.create_project('A plugin', null, 'kw', p_kind_id => 'plugin_tool',
                                                p_stage_id => 'pouring')$$,
  '23503', null, 'only a known stage');
select lives_ok($$select public.create_project('A bridge study', null, 'kw', p_kind_id => 'infrastructure')$$,
  'only a building needs a building type; the place stays optional');
reset role;

-- A CV entry's new fields -------------------------------------------------------------------------

select is((select status from public.cv_projects where id = pg_temp.id('e001')), 'in_progress',
  'an entry with no end is in progress');
select is((select status from public.cv_projects where id = pg_temp.id('e002')), 'completed',
  'one with an end is completed');
select is((select visibility from public.cv_projects where id = pg_temp.id('e002')), 'hidden',
  'not shown on the profile: hidden');
select pg_temp.as_user('1');
set local role authenticated;
select throws_ok(format($$update public.cv_projects set what_i_did = repeat('x', 201) where id = %L$$,
                        pg_temp.id('e001')), '23514', null, 'what I did: 200 characters at most');
select lives_ok(format($$update public.cv_projects set what_i_did = 'Led the BIM model and clash checks',
                         link = 'https://example.com/tower' where id = %L$$, pg_temp.id('e001')),
  'what I did and one link');
select throws_ok(format($$update public.cv_projects set status = 'done' where id = %L$$, pg_temp.id('e001')),
  '23514', null, 'status: in progress or completed');
select throws_ok(format($$update public.cv_projects set link = 'javascript:alert(1)' where id = %L$$,
                        pg_temp.id('e001')), '23514', null, 'a link is a web address');
select throws_ok(format($$update public.cv_projects set with_company_ids = array[%L, %L, %L]::uuid[] where id = %L$$,
                        pg_temp.id('c001'), pg_temp.id('c002'), pg_temp.id('c003'), pg_temp.id('e001')),
  '23514', null, 'with: two companies at most (a joint venture)');
select lives_ok(format($$update public.cv_projects set with_company_ids = array[%L, %L]::uuid[] where id = %L$$,
                       pg_temp.id('c001'), pg_temp.id('c002'), pg_temp.id('e001')),
  'two registered companies');
select throws_ok(format($$update public.cv_projects set with_company_text = 'Typed Co' where id = %L$$,
                        pg_temp.id('e001')), '23514', null, 'registered or typed, not both');
select throws_ok(format($$update public.cv_projects set with_company_ids = array[%L]::uuid[] where id = %L$$,
                        gen_random_uuid(), pg_temp.id('e001')), '23503', null, 'only a registered company');
select throws_ok(format($$update public.cv_projects set tool_ids = array['no_such_tool'] where id = %L$$,
                        pg_temp.id('e001')), '23503', null, 'a tool from the market''s list');
select lives_ok(format($$update public.cv_projects set tool_ids = array[(select id from public.market_tools
                         where market_id = 'kw' order by sort limit 1)], tools_text = array['Dynamo scripts']
                         where id = %L$$, pg_temp.id('e001')),
  'a listed tool and one of my own');
select throws_ok(format($$update public.cv_projects set tools_text = array['a','b','c','d','e','f'] where id = %L$$,
                        pg_temp.id('e001')), '23514', null, 'five of my own tools at most');
reset role;

-- Featured: six at most ------------------------------------------------------------------------------

insert into public.projects (id, name, type_id, market_id)
select pg_temp.id('f00' || n), 'Featured ' || n, 'residential', 'kw' from generate_series(1, 7) n;
insert into public.cv_projects (id, profile_id, project_id, role_title)
select pg_temp.id('ef0' || n), pg_temp.uid('1'), pg_temp.id('f00' || n), 'Engineer' from generate_series(1, 7) n;
select pg_temp.as_user('1');
set local role authenticated;
select lives_ok($$update public.cv_projects set featured = true, featured_order = x.n
                  from (select id, row_number() over (order by id) n from public.cv_projects
                        where project_id::text like '%f00%' limit 6) x
                  where cv_projects.id = x.id$$, 'six featured');
select throws_ok(format($$update public.cv_projects set featured = true, featured_order = 7 where id = %L$$,
                        pg_temp.id('ef07')), 'P0001', null, 'not a seventh');
reset role;

-- Who sees it: everyone, team only, hidden --------------------------------------------------------

select ok(pg_temp.reads('3', pg_temp.id('e001')), 'everyone: a stranger reads it');
select ok(not pg_temp.reads('4', pg_temp.id('e001')), 'never across a block');
select ok(not pg_temp.reads('3', pg_temp.id('e002')), 'hidden: a stranger doesn''t');
select ok(pg_temp.reads('1', pg_temp.id('e002')), 'its owner does');
select pg_temp.as_user('1');
set local role authenticated;
update public.cv_projects set visibility = 'team_only' where id = pg_temp.id('e002');
insert into public.cv_project_teammates (cv_project_id, profile_id) values (pg_temp.id('e002'), pg_temp.uid('2'));
reset role;
select ok(pg_temp.reads('2', pg_temp.id('e002')), 'team only: a teammate tagged on it reads it');
select ok(not pg_temp.reads('3', pg_temp.id('e002')), 'a stranger doesn''t');
select is((select show_on_profile from public.cv_projects where id = pg_temp.id('e002')), false,
  'team only is not on the profile for everyone (today''s meaning)');
select pg_temp.as_user('1');
set local role authenticated;
update public.cv_projects set show_on_profile = true where id = pg_temp.id('e002');
reset role;
select is((select visibility from public.cv_projects where id = pg_temp.id('e002')), 'everyone',
  'the old switch still works: shown is everyone');

-- Teammates -------------------------------------------------------------------------------------------

select is((select count(*)::int from public.notifications where profile_id = pg_temp.uid('2')
           and kind = 'cv_teammate' and payload ->> 'cv_project_id' = pg_temp.id('e002')::text), 1,
  'a tagged teammate gets one notification');
select pg_temp.as_user('1');
set local role authenticated;
delete from public.cv_project_teammates where cv_project_id = pg_temp.id('e002');
insert into public.cv_project_teammates (cv_project_id, profile_id) values (pg_temp.id('e002'), pg_temp.uid('2'));
select throws_ok(format($$insert into public.cv_project_teammates (cv_project_id, profile_id) values (%L, %L)$$,
                        pg_temp.id('e002'), pg_temp.uid('1')), '23514', null, 'not myself');
select throws_ok(format($$insert into public.cv_project_teammates (cv_project_id, profile_id) values (%L, %L)$$,
                        pg_temp.id('e002'), pg_temp.uid('4')), '42501', null, 'not someone blocked');
reset role;
select is((select count(*)::int from public.notifications where profile_id = pg_temp.uid('2')
           and kind = 'cv_teammate' and payload ->> 'cv_project_id' = pg_temp.id('e002')::text), 1,
  'tagged again: still one notification');
select pg_temp.as_user('3');
set local role authenticated;
select throws_ok(format($$insert into public.cv_project_teammates (cv_project_id, profile_id) values (%L, %L)$$,
                        pg_temp.id('e001'), pg_temp.uid('3')), '42501', null, 'a stranger can''t tag on my entry');
reset role;
select is(pg_temp.mates_seen('3', pg_temp.id('e002')), 1, 'teammates show to whoever reads the entry');
select is(pg_temp.mates_seen('4', pg_temp.id('e002')), 0, 'not across a block');

-- Photos and videos ---------------------------------------------------------------------------------

select is((select public from storage.buckets where id = 'cv-media'), false, 'a private bucket (signed URLs)');
select pg_temp.as_user('1');
set local role authenticated;
select lives_ok(format($$insert into public.cv_project_media (cv_project_id, storage_path, mime, sort)
                         values (%L, %L, 'image/jpeg', 0)$$,
                       pg_temp.id('e001'), pg_temp.uid('1')::text || '/e001/cover.jpg'),
  'the owner adds a photo under their own folder');
select throws_ok(format($$insert into public.cv_project_media (cv_project_id, storage_path, mime, sort)
                          values (%L, %L, 'image/jpeg', 1)$$,
                        pg_temp.id('e001'), pg_temp.uid('3')::text || '/x.jpg'),
  '42501', null, 'not under someone else''s folder');
select throws_ok(format($$insert into public.cv_project_media (cv_project_id, storage_path, mime, sort)
                          values (%L, %L, 'application/pdf', 1)$$,
                        pg_temp.id('e001'), pg_temp.uid('1')::text || '/e001/x.pdf'),
  '23514', null, 'photos and videos only');
select lives_ok(format($$insert into public.cv_project_media (cv_project_id, storage_path, mime, sort)
                         select %L, %L || '/e001/' || n || '.jpg', 'image/jpeg', n from generate_series(1, 9) n$$,
                       pg_temp.id('e001'), pg_temp.uid('1')::text),
  'ten in all');
select throws_ok(format($$insert into public.cv_project_media (cv_project_id, storage_path, mime, sort)
                          values (%L, %L, 'image/jpeg', 10)$$,
                        pg_temp.id('e001'), pg_temp.uid('1')::text || '/e001/11.jpg'),
  'P0001', null, 'not an eleventh');
select lives_ok($$insert into storage.objects (bucket_id, name)
                  values ('cv-media', '00000000-0000-0000-0000-000000012601/e001/cover.jpg')$$,
  'storage: I upload into my own folder');
reset role;
select pg_temp.as_user('3');
set local role authenticated;
select throws_ok(format($$insert into public.cv_project_media (cv_project_id, storage_path, mime, sort)
                          values (%L, %L, 'image/jpeg', 0)$$,
                        pg_temp.id('e002'), pg_temp.uid('3')::text || '/x.jpg'),
  '42501', null, 'a stranger can''t add a photo to my entry');
select throws_ok($$insert into storage.objects (bucket_id, name)
                   values ('cv-media', '00000000-0000-0000-0000-000000012601/e001/z.jpg')$$,
  '42501', null, 'nor upload into my folder');
reset role;
select is(pg_temp.media_seen('3', pg_temp.id('e001')), 10, 'a stranger sees the photos of an entry for everyone');
select is(pg_temp.media_seen('4', pg_temp.id('e001')), 0, 'not across a block');
select pg_temp.as_user('1');
set local role authenticated;
update public.cv_projects set visibility = 'hidden' where id = pg_temp.id('e001');
reset role;
select is(pg_temp.media_seen('3', pg_temp.id('e001')), 0, 'nor of a hidden entry');

-- A Space photo: only my own, copied on choice (rule 8) --------------------------------------------

select pg_temp.as_user('1');
set local role authenticated;
select set_config('test.space', public.create_space('Tower 126d')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (current_setting('test.space')::uuid, pg_temp.uid('2'), 'crew', pg_temp.uid('1')),
       (current_setting('test.space')::uuid, pg_temp.uid('5'), 'crew', pg_temp.uid('1'));
insert into public.space_posts (id, space_id, kind, author_id, title, number, ref)
values (pg_temp.id('d001'), current_setting('test.space')::uuid, 'note', pg_temp.uid('1'), 'Pour', 9001, 'T-9001'),
       (pg_temp.id('d002'), current_setting('test.space')::uuid, 'note', pg_temp.uid('2'), 'Steel', 9002, 'T-9002');
insert into public.post_files (id, post_id, storage_path, added_by, mime)
values (pg_temp.id('f101'), pg_temp.id('d001'), 'space/x/omar.jpg', pg_temp.uid('1'), 'image/jpeg'),
       (pg_temp.id('f102'), pg_temp.id('d002'), 'space/x/khalid.jpg', pg_temp.uid('2'), 'image/jpeg');
select pg_temp.as_user('1');
set local role authenticated;
select lives_ok(format($$insert into public.cv_project_media (cv_project_id, storage_path, mime, sort, source_post_file_id)
                         values (%L, %L, 'image/jpeg', 0, %L)$$,
                       pg_temp.id('e002'), pg_temp.uid('1')::text || '/e002/from-space.jpg', pg_temp.id('f101')),
  'a photo I posted in a Space');
select throws_ok(format($$insert into public.cv_project_media (cv_project_id, storage_path, mime, sort, source_post_file_id)
                          values (%L, %L, 'image/jpeg', 1, %L)$$,
                        pg_temp.id('e002'), pg_temp.uid('1')::text || '/e002/not-mine.jpg', pg_temp.id('f102')),
  '42501', null, 'not someone else''s');
reset role;

-- Experience: roles by company, with promotions (P2) ---------------------------------------------------

insert into public.experience (profile_id, title, company_id, company_name_text, start_month, end_month, visibility)
values (pg_temp.uid('1'), 'Project manager', pg_temp.id('c001'), null, '2024-03-01', null, 'everyone'),
       (pg_temp.uid('1'), 'Site engineer', pg_temp.id('c001'), null, '2021-01-01', '2024-02-01', 'everyone'),
       (pg_temp.uid('1'), 'Trainee', null, 'Gulf MEP', '2019-01-01', '2020-12-01', 'everyone'),
       (pg_temp.uid('1'), 'Intern', null, 'Hidden Co', '2018-01-01', '2018-12-01', 'only_me');
select is(jsonb_array_length(pg_temp.timeline('3', '1')), 2, 'a stranger: two companies (the only-me role is not shown)');
select is(pg_temp.timeline('3', '1') -> 0 ->> 'company_name', 'Harbour Contracting', 'the newest company first');
select is((select array_agg(r ->> 'title' order by o) from jsonb_array_elements(pg_temp.timeline('3', '1') -> 0 -> 'roles')
           with ordinality x(r, o)), array['Project manager', 'Site engineer'], 'its roles, newest first');
select is(pg_temp.timeline('3', '1') -> 0 -> 'roles' -> 0 ->> 'promoted_on', '2024-03-01',
  'a promotion between two roles in a row, on the newer role''s start');
select is(pg_temp.timeline('3', '1') -> 0 -> 'roles' -> 1 ->> 'promoted_on', null, 'not on the first role there');
select is(pg_temp.timeline('3', '1') -> 1 -> 'roles' -> 0 ->> 'promoted_on', null, 'a new company is no promotion');
select is(jsonb_array_length(pg_temp.timeline('1', '1')), 3, 'its owner sees all three companies');

-- Finish your profile (from the server) --------------------------------------------------------------

select is(pg_temp.completion('3') -> 'steps', '["photo", "title", "current_work", "summary", "first_project"]'::jsonb,
  'out of any Space: five steps, no phone');
select is((pg_temp.completion('3') ->> 'done')::int, 0, 'none done yet');
select is(pg_temp.completion('5') -> 'steps',
  '["photo", "title", "current_work", "summary", "first_project", "phone"]'::jsonb,
  'in a Space: the phone is a step');
update public.profiles set phone = '+96555000001', headline = 'Foreman', about = 'Concrete works.'
where id = pg_temp.uid('5');
select is(pg_temp.completion('5') -> 'missing', '["photo", "current_work", "first_project"]'::jsonb,
  'phone, title and summary done; what is missing, in order');
select is((pg_temp.completion('1') -> 'missing') ? 'current_work', false, 'a current Experience entry is current work');
select ok(not has_function_privilege('anon', 'public.my_profile_completion()', 'execute'),
  'signed-in people only, each their own');

-- Row-level security on every new table --------------------------------------------------------------

select is((select array_agg(c.relname::text order by c.relname) from pg_class c
           join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
             and c.relname in ('project_kinds', 'project_stages', 'market_tools', 'cv_project_media',
                               'cv_project_teammates')), null, 'every new table has row-level security');

select * from finish();
rollback;
