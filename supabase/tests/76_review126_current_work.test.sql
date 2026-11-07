-- Migration 20261203120000 (review 126 P1). Run with: supabase test db
--
-- Your current company comes from Experience only: the entry with no end
-- month (the latest start if several). Omar (a1) made the Space "Tower 126":
-- its admin. Khalid (b2) and Ali (c9) work at GCG (typed), Tariq (c3) at
-- the registered "Harbour Contracting". Lina (d4) has two current entries;
-- the newer one counts. Fay (f6) shows her work to connections only, Sami
-- (ca) to herself only. Eve (e5) is outside the Space. Hana (a8) and Gus
-- (a7) have no Experience yet: Hana's basics company is back-filled, Gus
-- types his company in the basics.

begin;
create extension if not exists pgtap with schema extensions;
select plan(56);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000126' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@r126.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('d4'), ('e5'), ('f6'), ('a7'), ('a8'), ('b9'), ('c9'),
             ('ca')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l, headline = n.h, trade_id = n.t
from (values ('a1', 'Omar', 'Haddad', 'Project manager', null),
             ('b2', 'Khalid', 'Al-Mansour', 'Safety', null),
             ('c3', 'Tariq', 'Rahman', null, null), ('d4', 'Lina', 'Saad', null, null),
             ('e5', 'Eve', 'Out', null, null), ('f6', 'Fay', 'Near', null, null),
             ('a7', 'Gus', 'Store', 'Foreman', null), ('a8', 'Hana', 'Nurse', 'Project manager', null),
             ('b9', 'Bilal', 'Block', null, 'site_engineer'), ('c9', 'Ali', 'Saleh', null, null),
             ('ca', 'Sami', 'Adel', null, null)
     ) n(id, f, l, h, t)
where p.id = ('00000000-0000-0000-0000-0000000126' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000126' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000126' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000126' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
-- [p_who]'s view of [p_of]'s current work.
create function pg_temp.work(p_who text, p_of text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  v := public.current_work(pg_temp.uid(p_of));
  reset role;
  return v;
end;
$$;
-- The admin's Teams from companies: each group's name and its people.
create function pg_temp.preview() returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user('a1');
  set local role authenticated;
  v := public.company_team_preview(pg_temp.sp());
  reset role;
  return v;
end;
$$;
create function pg_temp.group_people(p_name text) returns uuid[] language sql as $$
  select array_agg((x ->> 'id')::uuid order by x ->> 'id')
  from jsonb_array_elements(pg_temp.preview() -> 'groups') g,
       jsonb_array_elements(g -> 'people') x
  where g ->> 'name' = p_name;
$$;
create function pg_temp.no_company() returns uuid[] language sql as $$
  select array_agg((x ->> 'id')::uuid order by x ->> 'id')
  from jsonb_array_elements(pg_temp.preview() -> 'no_company') x;
$$;
-- What [p_who] reads from space_member_work (a member's current work in
-- the Space), for [p_of].
create function pg_temp.in_space(p_who text, p_of text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  select w.work into v from public.space_member_work(pg_temp.sp()) w
  where w.profile_id = pg_temp.uid(p_of);
  reset role;
  return v;
end;
$$;
-- Who [p_who] finds by a company's name.
create function pg_temp.found(p_who text, p_query text) returns uuid[] language plpgsql as $$
declare v uuid[];
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  select array_agg(x order by x) into v from public.people_at_current_company(p_query, null) x;
  reset role;
  return coalesce(v, '{}');
end;
$$;
-- The key roles as the Space admin reads them.
create function pg_temp.people_roles() returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user('a1');
  set local role authenticated;
  v := public.space_key_people(pg_temp.sp()) -> 'roles';
  reset role;
  return v;
end;
$$;
-- The first key-role holder as a Space member reads it.
create function pg_temp.holder() returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user('a1');
  set local role authenticated;
  v := public.space_key_people(pg_temp.sp()) -> 'roles' -> 0 -> 'holders' -> 0;
  reset role;
  return v;
end;
$$;

-- Setup ----------------------------------------------------------------------------------------------

insert into public.companies (id, name, kind_id, market_id)
values (pg_temp.id('c001'), 'Harbour Contracting', (select id from public.company_kinds limit 1), 'kw');
insert into public.experience (profile_id, title, company_id, company_name_text, start_month, end_month,
                               visibility)
values (pg_temp.uid('b2'), 'Site engineer', null, 'GCG', '2025-03-01', null, 'everyone'),
       (pg_temp.uid('c9'), 'Electrician', null, 'GCG', '2024-01-01', null, 'everyone'),
       (pg_temp.uid('c3'), 'QS', pg_temp.id('c001'), null, '2023-06-01', null, 'everyone'),
       (pg_temp.uid('d4'), 'Engineer', null, 'Old Co', '2022-01-01', null, 'everyone'),
       (pg_temp.uid('d4'), 'BIM Manager', null, 'IMAR Group', '2026-05-01', null, 'everyone'),
       (pg_temp.uid('d4'), 'Trainee', null, 'Past Co', '2020-01-01', '2021-12-01', 'everyone'),
       (pg_temp.uid('f6'), 'Supervisor', null, 'Near Co', '2025-01-01', null, 'connections'),
       (pg_temp.uid('ca'), 'Driver', null, 'Quiet Co', '2025-01-01', null, 'only_me');

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Tower 126')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1')
from (values ('b2', 'crew'), ('c3', 'crew'), ('d4', 'lead'), ('f6', 'crew'), ('c9', 'crew'),
             ('ca', 'crew')) x(id, pass);
insert into public.space_key_roles (id, space_id, name)
values (pg_temp.id('a001'), pg_temp.sp(), 'Safety officer');
insert into public.space_key_holders (role_id, profile_id) values (pg_temp.id('a001'), pg_temp.uid('b2'));

-- One source ----------------------------------------------------------------------------------------

select hasnt_column('public', 'profiles', 'company_id', 'the basics company is gone');
select hasnt_column('public', 'profiles', 'company_name_text', 'and its typed name');
select ok(has_function_privilege('authenticated', 'public.current_work(uuid)', 'execute')
          and not has_function_privilege('anon', 'public.current_work(uuid)', 'execute')
          and has_table_privilege('authenticated', 'public.current_work', 'select')
          and not has_table_privilege('anon', 'public.current_work', 'select'),
  'current_work: signed-in people only');
select ok(not has_function_privilege('authenticated',
            'public.current_work_from_basics(uuid, uuid, text, date, text)', 'execute')
          and not has_function_privilege('anon',
            'public.current_work_from_basics(uuid, uuid, text, date, text)', 'execute'),
  'the back-fill rule is the server''s own');

-- A current entry drives everything -------------------------------------------------------------------

select is(pg_temp.work('a1', 'b2') ->> 'company_name', 'GCG', 'the Space row: the current company');
select is(pg_temp.work('a1', 'b2') ->> 'title', 'Site engineer', 'and the current title');
select is(pg_temp.work('a1', 'b2') ->> 'company_id', null, 'a typed name stays plain text (rule 4)');
select is(pg_temp.work('a1', 'c3') ->> 'company_name', 'Harbour Contracting', 'a registered company by its name');
select is((pg_temp.work('a1', 'c3') ->> 'company_id')::uuid, pg_temp.id('c001'), 'and its id');
select is(pg_temp.work('a1', 'd4') ->> 'company_name', 'IMAR Group', 'several current entries: the latest start');
select is(pg_temp.work('a1', 'a1'), null, 'no Experience: no current work');
select is(pg_temp.group_people('GCG'), (select array_agg(x order by x) from
            unnest(array[pg_temp.uid('b2'), pg_temp.uid('c9')]) x),
  'Teams from companies groups the people of GCG');
select is(pg_temp.group_people('Harbour Contracting'), array[pg_temp.uid('c3')],
  'and the registered company');
select ok(pg_temp.uid('d4') = any(pg_temp.group_people('IMAR Group')), 'by the newest current entry');
select is(pg_temp.found('e5', 'gcg'), (select array_agg(x order by x) from
            unnest(array[pg_temp.uid('b2'), pg_temp.uid('c9')]) x),
  'search finds the people of a company, from outside the Space too');
select is(pg_temp.found('e5', 'harbour'), array[pg_temp.uid('c3')], 'a registered company by its name');
select is(pg_temp.found('e5', 'old co'), '{}', 'not an older current entry');
select is(pg_temp.found('e5', 'past co'), '{}', 'not an ended one');
select pg_temp.as_user('e5');
set local role authenticated;
select is((select array_agg(x) from public.people_at_current_company(null, pg_temp.id('c001')) x),
  array[pg_temp.uid('c3')], 'Near you: the people at your registered company');
reset role;
select is(pg_temp.holder() -> 'current_work' ->> 'company_name', 'GCG', 'the key-role row');
-- The app's view: one row per person, what the reader may see.
select pg_temp.as_user('a1');
set local role authenticated;
select is((select array_agg(company_name order by company_name) from public.current_work
           where profile_id in (pg_temp.uid('b2'), pg_temp.uid('d4'), pg_temp.uid('f6'), pg_temp.uid('ca'))),
  array['GCG', 'IMAR Group'], 'the app''s view: the newest current entry, nothing hidden');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select is((select company_name from public.current_work where profile_id = pg_temp.uid('f6')), 'Near Co',
  'its owner reads their own');
reset role;

-- Ending it removes the company everywhere -----------------------------------------------------------

select pg_temp.as_user('b2');
set local role authenticated;
update public.experience set end_month = date_trunc('month', now())::date
where profile_id = pg_temp.uid('b2');
reset role;
select is(pg_temp.work('a1', 'b2'), null, 'an end month: no current work in the Space row');
select is(pg_temp.group_people('GCG'), array[pg_temp.uid('c9')], 'not in Teams from companies');
select ok(pg_temp.uid('b2') = any(pg_temp.no_company()), 'but with no company');
select is(pg_temp.found('e5', 'gcg'), array[pg_temp.uid('c9')], 'not found by the company');
select is(pg_temp.holder() ->> 'current_work', null, 'not on the key-role row');
select pg_temp.as_user('a1');
set local role authenticated;
select is((select count(*)::int from public.company_team_for(pg_temp.sp(), pg_temp.uid('b2'))), 0,
  'nor for a Team match');
reset role;

-- Never more than the profile allows -----------------------------------------------------------------

select is(pg_temp.work('e5', 'f6'), null, 'connections only: hidden from someone not connected');
select is(pg_temp.work('f6', 'f6') ->> 'company_name', 'Near Co', 'its owner sees it');
select is(pg_temp.work('a1', 'ca'), null, 'only me: hidden outside the Space, even from its admin');
select is(pg_temp.found('a1', 'quiet'), '{}', 'and from search');

-- Inside a Space, its members see a member's current work (lead's check) -------------------------

select is(pg_temp.in_space('a1', 'f6') ->> 'company_name', 'Near Co',
  'the Space admin sees a connections-only member''s company in the Space');
select is(pg_temp.in_space('c9', 'ca') ->> 'company_name', 'Quiet Co',
  'a member sees an only-me member''s company in the Space');
select is(pg_temp.group_people('Near Co'), array[pg_temp.uid('f6')],
  'Teams from companies uses it');
select ok(not (pg_temp.uid('ca') = any(pg_temp.no_company())), 'the only-me member too');
insert into public.space_key_holders (role_id, profile_id) values (pg_temp.id('a001'), pg_temp.uid('ca'));
select is((select h -> 'current_work' ->> 'company_name'
           from jsonb_array_elements(pg_temp.people_roles() -> 0 -> 'holders') h
           where h ->> 'id' = pg_temp.uid('ca')::text), 'Quiet Co', 'and the key-role row');
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok(format($$select * from public.space_member_work(%L)$$, pg_temp.sp()), '42501', null,
  'a non-member reads nothing of the Space');
select throws_ok(format($$select public.company_team_preview(%L)$$, pg_temp.sp()), '42501', null,
  'nor its Teams from companies');
reset role;
select is(pg_temp.work('e5', 'f6'), null, 'nor, outside the Space, the connections-only company');
select is(pg_temp.found('e5', 'near'), '{}', 'nor finds her by it');
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('c3'), pg_temp.uid('e5'));
select is(pg_temp.work('e5', 'c3'), null, 'nothing across a block');

-- The back-fill keeps the basics company --------------------------------------------------------------

select ok(public.current_work_from_basics(pg_temp.uid('a8'), null, 'GCG', '2026-10-01') is not null,
  'a basics company with no current entry: one is made');
select is(pg_temp.work('a1', 'a8') ->> 'company_name', 'GCG', 'it keeps GCG');
select is(pg_temp.work('a1', 'a8') ->> 'title', 'Project manager', 'titled with the headline');
select is((select start_month from public.experience where profile_id = pg_temp.uid('a8')), '2026-10-01'::date,
  'from the month given (the profile''s creation month)');
select ok(public.current_work_from_basics(pg_temp.uid('b9'), pg_temp.id('c001'), null, '2026-10-01') is not null
          and pg_temp.work('a1', 'b9') ->> 'title' = 'Site engineer',
  'no headline: the role (trade) in the profile''s language');
select is(public.current_work_from_basics(pg_temp.uid('e5'), null, 'Nameless', '2026-10-01'), null,
  'no headline and no role: nothing to title it, nothing made');

-- The basics write the current Experience entry ----------------------------------------------------

select pg_temp.as_user('a7');
set local role authenticated;
select lives_ok($$select public.set_current_company(null, 'Al Noor')$$, 'typing a company in the basics');
select is((select count(*)::int from public.experience where profile_id = pg_temp.uid('a7')), 1,
  'makes one current entry');
select lives_ok(format($$select public.set_current_company(%L, null)$$, pg_temp.id('c001')),
  'picking a registered company');
reset role;
select is((select company_id from public.experience where profile_id = pg_temp.uid('a7')), pg_temp.id('c001'),
  'changes the same entry, linked');
select pg_temp.as_user('a7');
set local role authenticated;
select lives_ok(format($$select public.set_current_company(%L, null, 'Store manager')$$, pg_temp.id('c001')),
  'editing the headline in the basics');
reset role;
select is((select title from public.experience where profile_id = pg_temp.uid('a7')), 'Store manager',
  'renames the current entry');
select pg_temp.as_user('e5');
set local role authenticated;
select lives_ok($$select public.set_current_company(null, null, 'Nurse')$$,
  'a headline with no company and no current entry');
reset role;
select is((select count(*)::int from public.experience where profile_id = pg_temp.uid('e5')), 0,
  'makes no entry: the headline stays as it is');

select * from finish();
rollback;
