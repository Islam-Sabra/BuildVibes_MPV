-- Migration 20261122120000 (review 111). Run with: supabase test db
--
-- Omar (a1) made the Space "Tower 111": its admin, a Lead, no company.
-- Delta Steel: Rakesh (b2, Crew, typed "Delta Steel Co.", joined first), Tariq
-- (c3, Crew, typed "DELTA.STEEL") and Gus (a7, Lead, typed "delta  steel",
-- joined last). Hana (a8, Crew) typed "Delta Steal": a similar spelling.
-- Gulf Mech: Lina (d4, Crew) works at the registered company; Vera (e5, a
-- Viewer) typed "gulf mech company". Bilal (b9, Crew) has no company.
-- Eve (f6) is outside: she made "Other site". Noor (c9, Crew) typed "Nile
-- Build" and Sami (ca, Crew) "Nile Build Co."; the Team "Nile Build" exists
-- with Noor in it. Zaki (cb) has only asked to join; he typed "شركة النيل".
-- Teams by hand: Rigging (Rakesh, Gus), Solo (Tariq).

begin;
create extension if not exists pgtap with schema extensions;
select plan(125);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000061' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@r111.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('d4'), ('e5'), ('f6'), ('a7'), ('a8'), ('b9'), ('c9'),
             ('ca'), ('cb')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l, company_name_text = n.c
from (values ('a1', 'Omar', 'Haddad', null), ('b2', 'Rakesh', 'Nair', 'Delta Steel Co.'),
             ('c3', 'Tariq', 'Aziz', 'DELTA.STEEL'), ('a7', 'Gus', 'Lead', 'delta  steel'),
             ('a8', 'Hana', 'Hidden', 'Delta Steal'), ('d4', 'Lina', 'Saad', null),
             ('e5', 'Vera', 'Lane', 'gulf mech company'), ('b9', 'Bilal', 'Block', null),
             ('f6', 'Eve', 'Out', 'Delta Steel'), ('c9', 'Noor', 'Ali', 'Nile Build'),
             ('ca', 'Sami', 'Adel', 'Nile Build Co.'), ('cb', 'Zaki', 'Nour', 'شركة النيل')
     ) n(id, f, l, c)
where p.id = ('00000000-0000-0000-0000-0000000061' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000061' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000061' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000061' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.sp2() returns uuid language sql as $$
  select current_setting('test.space2')::uuid;
$$;
create function pg_temp.rig() returns uuid language sql as $$
  select current_setting('test.rig')::uuid;
$$;
create function pg_temp.solo() returns uuid language sql as $$
  select current_setting('test.solo')::uuid;
$$;
create function pg_temp.nile() returns uuid language sql as $$
  select current_setting('test.nile')::uuid;
$$;
create function pg_temp.admin_of(p_team uuid) returns uuid language sql as $$
  select t.admin_id from public.teams t where t.id = p_team;
$$;
create function pg_temp.in_team(p_team uuid) returns uuid[] language sql as $$
  select coalesce(array_agg(tm.profile_id order by tm.profile_id), '{}')
  from public.team_members tm where tm.team_id = p_team;
$$;
create function pg_temp.team_named(p_name text) returns uuid language sql as $$
  select t.id from public.teams t where t.space_id = pg_temp.sp() and t.name = p_name;
$$;
-- The group for [p_key] in the preview [p_who] sees.
create function pg_temp.preview(p_who text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  v := public.company_team_preview(pg_temp.sp());
  reset role;
  return v;
end;
$$;
create function pg_temp.grp(p_key text) returns jsonb language sql as $$
  select g from jsonb_array_elements(pg_temp.preview('a1') -> 'groups') g
  where g ->> 'key' = p_key;
$$;
create function pg_temp.names(p_group jsonb) returns text[] language sql as $$
  select array_agg(x ->> 'name' order by x ->> 'name')
  from jsonb_array_elements(p_group -> 'people') x;
$$;

-- Setup ----------------------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Tower 111')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by, confirmed_at)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1'), now() - x.d * interval '1 day'
from (values ('b2', 'crew', 9), ('c3', 'crew', 8), ('a7', 'lead', 2), ('a8', 'crew', 7),
             ('d4', 'crew', 3), ('e5', 'viewer', 6), ('b9', 'crew', 5), ('c9', 'crew', 4),
             ('ca', 'crew', 1)) x(id, pass, d);
insert into public.companies (id, name, kind_id, market_id)
values (pg_temp.id('c001'), 'Gulf Mech', 'contractor', 'kw');
update public.profiles set company_id = pg_temp.id('c001'), company_name_text = null
where id = pg_temp.uid('d4');
select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.rig', public.create_team(pg_temp.sp(), 'Rigging',
  array[pg_temp.uid('b2'), pg_temp.uid('a7')])::text, true);
select set_config('test.solo', public.create_team(pg_temp.sp(), 'Solo',
  array[pg_temp.uid('c3')])::text, true);
select set_config('test.nile', public.create_team(pg_temp.sp(), 'Nile Build',
  array[pg_temp.uid('c9')])::text, true);
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select set_config('test.space2', public.create_space('Other site')::text, true);
select set_config('test.other', public.create_team(pg_temp.sp2(), 'Other team', '{}')::text, true);
reset role;

-- Shape, grants, row-level security ------------------------------------------------------------------

select has_column('public', 'teams', 'admin_id', 'teams.admin_id exists');
select col_is_null('public', 'teams', 'admin_id', 'a Team may have no admin');
select is(pg_temp.admin_of(pg_temp.rig()), null, 'a Team starts with no admin');
select ok((select relrowsecurity from pg_class where oid = 'public.company_team_runs'::regclass),
  'company_team_runs has row-level security');
select ok(has_function_privilege('authenticated', 'public.set_team_admin(uuid, uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.company_team_preview(uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.create_company_teams(uuid, uuid, jsonb)', 'execute')
          and has_function_privilege('authenticated', 'public.company_team_for(uuid, uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.admin_name(public.teams)', 'execute'),
  'the app''s calls, signed in');
select ok(not has_function_privilege('anon', 'public.set_team_admin(uuid, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.company_team_preview(uuid)', 'execute')
          and not has_function_privilege('anon', 'public.create_company_teams(uuid, uuid, jsonb)', 'execute')
          and not has_function_privilege('anon', 'public.company_team_for(uuid, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.admin_name(public.teams)', 'execute'),
  'nothing for anon');
select ok(not has_function_privilege('authenticated', 'public.can_post_to_team(uuid, uuid)', 'execute')
          and not has_function_privilege('authenticated', 'public.is_team_admin(uuid)', 'execute')
          and not has_function_privilege('authenticated', 'public.is_any_team_admin(uuid)', 'execute')
          and not has_function_privilege('authenticated', 'public.company_key(text)', 'execute')
          and not has_function_privilege('authenticated', 'public.company_keys_similar(text, text)', 'execute')
          and not has_function_privilege('authenticated', 'public.person_company(uuid)', 'execute')
          and not has_function_privilege('authenticated', 'public.team_for_company(uuid, text, text)', 'execute'),
  'the helpers are not callable');
select ok(not exists (
    select 1 from pg_proc p
    where p.oid in ('public.set_team_admin(uuid, uuid)'::regprocedure,
                    'public.company_team_preview(uuid)'::regprocedure,
                    'public.create_company_teams(uuid, uuid, jsonb)'::regprocedure,
                    'public.company_team_for(uuid, uuid)'::regprocedure,
                    'public.admin_name(public.teams)'::regprocedure,
                    'public.can_post_to_team(uuid, uuid)'::regprocedure,
                    'public.set_team_members(uuid, uuid[])'::regprocedure)
      and not (p.prosecdef and p.proconfig @> array['search_path=""'])),
  'security definer with an empty search path');

select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select count(*) from public.company_team_runs$$, '42501', null,
  'a non-member can''t read company_team_runs');
select throws_ok($$insert into public.company_team_runs (id, space_id, result)
                   values (gen_random_uuid(), pg_temp.sp(), '{}')$$, '42501', null,
  'a non-member can''t write company_team_runs');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select count(*) from public.company_team_runs$$, '42501', null,
  'nor can the Space admin: only the function uses it');
reset role;

-- The grouping key -----------------------------------------------------------------------------------

select is(public.company_key('Delta Steel Co.'), 'deltasteel', 'case, a space and Co. ignored');
select is(public.company_key('D.E.L.T.A   STEEL'), 'deltasteel', 'dots and spaces ignored');
select is(public.company_key('delta steel company'), 'deltasteel', 'a trailing Company ignored');
select is(public.company_key('الدلتا شركة'), 'الدلتا', 'a trailing شركة ignored');
select is(public.company_key('شركة الدلتا'), 'الدلتا', 'شركة first, as Arabic writes it, ignored');
select is(public.company_key('Costco'), 'costco', 'only a whole word Co goes');
select is(public.company_key('Company'), 'company', 'a name that is only the word stays');
select is(public.company_key('...'), null, 'nothing left is no company');
select is(public.company_key(null), null, 'null is no company');
select ok(public.company_keys_similar('deltasteel', 'deltasteal'), 'one letter apart is similar');
select ok(public.company_keys_similar('deltasteel', 'deltastee'), 'one contains the other');
select ok(public.company_keys_similar('alrayangroup', 'alrayyngrop'), 'two letters apart in a long name');
select ok(not public.company_keys_similar('deltasteel', 'deltasteel'), 'the same key is not a pair');
select ok(not public.company_keys_similar('abc', 'abd'), 'short names are too thin to compare');
select ok(not public.company_keys_similar('gulfmech', 'deltasteel'), 'different names are not similar');

-- Who may ask ----------------------------------------------------------------------------------------

update public.teams set admin_id = pg_temp.uid('b2') where id = pg_temp.rig();
select is(pg_temp.admin_of(pg_temp.rig()), pg_temp.uid('b2'), 'Rakesh is Rigging''s admin (a direct set for the setup)');

select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.company_team_preview(pg_temp.sp())$$, '42501', null, 'a non-member gets no preview');
select throws_ok($$select public.company_team_for(pg_temp.sp(), pg_temp.uid('b2'))$$, '42501', null,
  'a non-member gets no company match');
select throws_ok($$select public.create_company_teams(gen_random_uuid(), pg_temp.sp(),
    '[{"name": "X Y", "team_id": null, "people": [], "admin_id": null}]')$$, '42501', null,
  'a non-member can''t create company Teams');
select throws_ok($$select public.set_team_admin(pg_temp.rig(), pg_temp.uid('a7'))$$, '42501', null,
  'a non-member can''t change a Team admin');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok($$select public.company_team_preview(pg_temp.sp())$$, '42501', null, 'Crew gets no preview');
select throws_ok($$select public.create_company_teams(gen_random_uuid(), pg_temp.sp(),
    '[{"name": "X Y", "team_id": null, "people": [], "admin_id": null}]')$$, '42501', null,
  'Crew can''t create company Teams');
select throws_ok($$select public.set_team_admin(pg_temp.rig(), pg_temp.uid('a7'))$$, '42501', null,
  'Crew can''t change a Team admin');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.company_team_preview(pg_temp.sp())$$, '42501', null, 'a Team admin gets no preview');
select throws_ok($$select public.company_team_for(pg_temp.sp(), pg_temp.uid('c3'))$$, '42501', null,
  'a Team admin gets no company match');
select throws_ok($$select public.create_company_teams(gen_random_uuid(), pg_temp.sp(),
    '[{"name": "X Y", "team_id": null, "people": [], "admin_id": null}]')$$, '42501', null,
  'a Team admin can''t create company Teams');
select throws_ok($$select public.set_team_admin(pg_temp.solo(), pg_temp.uid('c3'))$$, '42501', null,
  'a Team admin can''t change another Team''s admin');
select throws_ok($$select public.set_team_admin(pg_temp.rig(), pg_temp.uid('a7'))$$, '42501', null,
  'a Team admin can''t pass on their own Team');
select throws_ok($$select public.rename_team(pg_temp.rig(), 'Mine')$$, '42501', null,
  'a Team admin can''t rename the Team');
select throws_ok($$select public.set_member_pass(pg_temp.sp(), pg_temp.uid('a7'), 'crew')$$, '42501', null,
  'a Team admin can''t change passes');
reset role;

-- The preview ----------------------------------------------------------------------------------------

select is(pg_temp.grp('deltasteel') ->> 'name', 'Delta Steel Co.',
  'the display name is a spelling people typed');
select is(pg_temp.names(pg_temp.grp('deltasteel')), array['Gus Lead', 'Rakesh Nair', 'Tariq Aziz'],
  'the grouping ignores case, dots, spaces and Co.');
select is(pg_temp.grp('deltasteel') ->> 'team_id', null, 'no Team of that name yet');
select is((pg_temp.grp('deltasteel') ->> 'admin_id')::uuid, pg_temp.uid('a7'),
  'the suggested admin is the Lead, though he joined last');
select is((select x ->> 'pass' from jsonb_array_elements(pg_temp.grp('deltasteel') -> 'people') x
           where x ->> 'id' = pg_temp.uid('a7')::text), 'lead', 'each person carries their pass');
select is(pg_temp.grp('gulfmech') ->> 'name', 'Gulf Mech', 'a registered company gives the name');
select is(pg_temp.names(pg_temp.grp('gulfmech')), array['Lina Saad', 'Vera Lane'],
  'a typed name matching a registered company joins it');
select is((pg_temp.grp('gulfmech') ->> 'admin_id')::uuid, pg_temp.uid('e5'),
  'no Lead there: the earliest member');
select is((pg_temp.grp('nilebuild') ->> 'team_id')::uuid, pg_temp.nile(),
  'an existing Team of that name is found');
select is(pg_temp.grp('nilebuild') ->> 'team_name', 'Nile Build', 'and its name given');
select is(pg_temp.names(pg_temp.grp('nilebuild')), array['Sami Adel'], 'only people not yet in it are listed');
select is((pg_temp.grp('nilebuild') ->> 'admin_id')::uuid, pg_temp.uid('c9'),
  'the suggestion may be someone already in that Team');
select is(pg_temp.preview('a1') -> 'similar',
  '[{"a": "deltasteal", "b": "deltasteel"}]'::jsonb, 'two spellings are offered, not merged');
select is((select array_agg(x ->> 'name' order by x ->> 'name')
           from jsonb_array_elements(pg_temp.preview('a1') -> 'no_company') x),
  array['Bilal Block', 'Omar Haddad'], 'people with no company stay apart');
select ok(not (pg_temp.preview('a1')::text like '%Eve Out%'), 'nobody from outside the Space');
select is((select count(*)::integer from public.companies where id <> pg_temp.id('c001')
           and name in ('Delta Steel Co.', 'Nile Build', 'Delta Steal')), 0, 'no company was created');

update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('a8');
select is(pg_temp.grp('deltasteal'), null, 'an account going away is left out');
select is(pg_temp.preview('a1') -> 'similar', '[]'::jsonb, 'and its pair with it');
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('a8');

insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('b9'), pg_temp.uid('a1'));
select ok(not (pg_temp.preview('a1')::text like '%Bilal%'), 'nobody the Space admin can''t see across a block');
delete from public.blocks where blocker_id = pg_temp.uid('b9');

-- TM4 ------------------------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select is((select array_agg(team_id::text || ' ' || team_name || ' ' || company)
           from public.company_team_for(pg_temp.sp(), pg_temp.uid('ca'))),
  array[pg_temp.nile()::text || ' Nile Build Nile Build Co.'], 'the Team of that person''s company');
select is((select count(*)::integer from public.company_team_for(pg_temp.sp(), pg_temp.uid('b2'))), 0,
  'no Team of that company, no row');
select is((select count(*)::integer from public.company_team_for(pg_temp.sp(), pg_temp.uid('b9'))), 0,
  'no company, no row');
select is((select count(*)::integer from public.company_team_for(pg_temp.sp(), pg_temp.uid('cb'))), 0,
  'someone only asking to join: no Team of that company, no row');
reset role;
update public.profiles set company_name_text = 'Nile.Build' where id = pg_temp.uid('cb');
select pg_temp.as_user('a1');
set local role authenticated;
select is((select team_id from public.company_team_for(pg_temp.sp(), pg_temp.uid('cb'))), pg_temp.nile(),
  'someone asking to join: their company''s Team, spelled another way');

-- Create ---------------------------------------------------------------------------------------------

select is(public.create_company_teams(pg_temp.id('a001'), pg_temp.sp(), jsonb_build_array(
    jsonb_build_object('name', 'Delta Steel Co.', 'team_id', null,
      'people', jsonb_build_array(pg_temp.uid('b2'), pg_temp.uid('c3'), pg_temp.uid('a7')),
      'admin_id', pg_temp.uid('a7')),
    jsonb_build_object('name', 'Nile Build', 'team_id', pg_temp.nile(),
      'people', jsonb_build_array(pg_temp.uid('ca')), 'admin_id', pg_temp.uid('ca')))) -> 'team_ids' -> 1,
  to_jsonb(pg_temp.nile()::text), 'the ids come back in order');
reset role;
select set_config('test.delta', pg_temp.team_named('Delta Steel Co.')::text, true);
select is(cardinality(pg_temp.in_team(current_setting('test.delta')::uuid)), 3, 'each company a Team, its people inside');
select is(pg_temp.admin_of(current_setting('test.delta')::uuid), pg_temp.uid('a7'), 'with its Team admin');
select is(pg_temp.in_team(pg_temp.nile()), (select array_agg(x order by x) from unnest(array[pg_temp.uid('c9'), pg_temp.uid('ca')]) x),
  'an existing Team gets its new people');
select is(pg_temp.admin_of(pg_temp.nile()), pg_temp.uid('ca'), 'and the admin chosen in the sheet');
select is((select count(*)::integer from public.threads where team_id = current_setting('test.delta')::uuid), 1,
  'the new Team has its Chat');
select is((select count(*)::integer from public.companies where id <> pg_temp.id('c001')
           and name in ('Delta Steel Co.', 'Nile Build')), 0, 'creating Teams creates no company');
select is((select company_name_text from public.profiles where id = pg_temp.uid('b2')), 'Delta Steel Co.',
  'a typed name stays plain text');
select is((select company_id from public.profiles where id = pg_temp.uid('b2')), null,
  'and links to no company');

-- A retry.
select pg_temp.as_user('a1');
set local role authenticated;
select public.set_team_members(pg_temp.nile(), array[pg_temp.uid('c9')]);
select is(public.create_company_teams(pg_temp.id('a001'), pg_temp.sp(), '[]') -> 'team_ids' -> 1,
  to_jsonb(pg_temp.nile()::text), 'the same id returns the same result');
reset role;
select is(pg_temp.in_team(pg_temp.nile()), array[pg_temp.uid('c9')], 'and changes nothing');
select is((select count(*)::integer from public.teams where space_id = pg_temp.sp()), 4, 'no second Team');
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.create_company_teams(pg_temp.id('a001'), pg_temp.sp2(),
    '[{"name": "Stolen", "team_id": null, "people": [], "admin_id": null}]')$$, '42501', null,
  'a run''s id is not usable in another Space');
reset role;

-- All or nothing.
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok(format($$select public.create_company_teams(pg_temp.id('a002'), pg_temp.sp(),
    '[{"name": "Alpha", "team_id": null, "people": ["%s"], "admin_id": null},
      {"name": "Beta", "team_id": null, "people": ["%s"], "admin_id": null}]')$$,
    pg_temp.uid('b9'), pg_temp.uid('f6')), '22023', null, 'someone outside the Space stops it all');
select throws_ok(format($$select public.create_company_teams(pg_temp.id('a002'), pg_temp.sp(),
    '[{"name": "Alpha", "team_id": null, "people": ["%s"], "admin_id": null},
      {"name": "Beta", "team_id": null, "people": ["%s"], "admin_id": "%s"}]')$$,
    pg_temp.uid('b9'), pg_temp.uid('a8'), pg_temp.uid('b9')), '22023', null,
  'an admin outside the group stops it all');
select throws_ok(format($$select public.create_company_teams(pg_temp.id('a002'), pg_temp.sp(),
    '[{"name": "Alpha", "team_id": null, "people": ["%s"], "admin_id": null},
      {"name": "Beta", "team_id": "%s", "people": ["%s"], "admin_id": null}]')$$,
    pg_temp.uid('b9'), current_setting('test.other'), pg_temp.uid('a8')), '22023', null,
  'another Space''s Team stops it all');
select throws_ok($$select public.create_company_teams(pg_temp.id('a002'), pg_temp.sp(), '{}')$$, '22023', null,
  'the groups are a list');
select throws_ok($$select public.create_company_teams(pg_temp.id('a002'), pg_temp.sp(),
    '[{"name": "  ", "team_id": null, "people": [], "admin_id": null}]')$$, '22023', null,
  'a Team has a name');
reset role;
select is(pg_temp.team_named('Alpha'), null, 'nothing was created');
select pg_temp.as_user('a1');
set local role authenticated;
select ok(jsonb_array_length(public.create_company_teams(pg_temp.id('a002'), pg_temp.sp(), jsonb_build_array(
    jsonb_build_object('name', 'Alpha', 'team_id', null,
      'people', jsonb_build_array(pg_temp.uid('b9')), 'admin_id', null))) -> 'team_ids') = 1,
  'the same id works after a failure');
-- A name typed the long way: a Team takes 40 characters.
select lives_ok(format($$select public.create_company_teams(pg_temp.id('a003'), pg_temp.sp(),
    '[{"name": "%s", "team_id": null, "people": ["%s"], "admin_id": null}]')$$,
    repeat('Long', 15), pg_temp.uid('a8')), 'a long company name fits');
-- No team_id, but a Team of that name was made since the preview.
select lives_ok(format($$select public.create_company_teams(pg_temp.id('a004'), pg_temp.sp(),
    '[{"name": "alpha co.", "team_id": null, "people": ["%s"], "admin_id": "%s"}]')$$,
    pg_temp.uid('e5'), pg_temp.uid('e5')), 'the same name again');
reset role;
select is(cardinality(pg_temp.in_team(pg_temp.team_named('Alpha'))), 2, 'goes into the Team that has it');
select is(length((select t.name from public.teams t where t.name like 'LongLong%')), 40, 'cut to fit');

-- set_team_admin -------------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.set_team_admin(pg_temp.solo(), pg_temp.uid('b2'))$$, '22023', null,
  'a Team admin is a member of that Team');
select lives_ok($$select public.set_team_admin(pg_temp.solo(), pg_temp.uid('c3'))$$, 'the Space admin sets it');
select lives_ok($$select public.set_team_admin(pg_temp.solo(), null)$$, 'and clears it');
select public.set_team_admin(pg_temp.solo(), pg_temp.uid('c3'));
reset role;
select is(pg_temp.admin_of(pg_temp.solo()), pg_temp.uid('c3'), 'Tariq is Solo''s admin');

-- What the app reads.
select pg_temp.as_user('b9');
set local role authenticated;
select is((select public.admin_name(t) from public.teams t where t.id = pg_temp.solo()), 'Tariq Aziz',
  'a member reads the admin''s name beside the Team');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select is((select public.admin_name(row(pg_temp.solo(), pg_temp.sp(), 'x', null, now(), now(),
                                        pg_temp.uid('a1'))::public.teams)), null,
  'a non-member gets no name, whatever row they pass');
reset role;

-- A Team admin adds and removes in their own Team only ----------------------------------------------

select pg_temp.as_user('c3');
set local role authenticated;
select lives_ok($$select public.set_team_members(pg_temp.solo(), array[pg_temp.uid('c3'), pg_temp.uid('d4')])$$,
  'a Team admin adds to their own Team');
select lives_ok($$select public.set_team_members(pg_temp.solo(), array[pg_temp.uid('c3')])$$,
  'and removes from it');
select throws_ok($$select public.set_team_members(pg_temp.rig(), array[pg_temp.uid('c3')])$$, '42501', null,
  'not in another Team');
select throws_ok($$select public.set_team_members(pg_temp.solo(), array[pg_temp.uid('c3'), pg_temp.uid('f6')])$$,
  '22023', null, 'only people in the Space');
select throws_ok($$select public.set_team_members(pg_temp.solo(), array[pg_temp.uid('d4')])$$, 'BV002', null,
  'a Team admin can''t take themselves out: only the Space admin changes the Team admin');
reset role;
select is(pg_temp.admin_of(pg_temp.solo()), pg_temp.uid('c3'), 'and stays the admin');
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok($$select public.set_team_members(pg_temp.solo(), array[pg_temp.uid('d4')])$$, '42501', null,
  'a member of no Team changes nothing');
reset role;

-- Who can post where ---------------------------------------------------------------------------------

select pg_temp.as_user('c3');
set local role authenticated;
select lives_ok($$select public.create_space_post(pg_temp.id('b001'), pg_temp.sp(), 'note', 'To Rigging',
                    p_team => pg_temp.rig())$$, 'a Team admin posts to another Team');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Coordinate', pg_temp.uid('b2'),
                    p_team => pg_temp.rig(), p_id => pg_temp.id('b002'))$$,
  'a work item too');
select throws_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp2(), 'note', 'Elsewhere',
                    p_team => current_setting('test.other')::uuid)$$, '42501', null,
  'not into a Team of a Space they are not in');
reset role;
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'To Rigging',
                    p_team => pg_temp.rig())$$, '42501', null, 'a member can''t post to a Team outside theirs');
select throws_ok($$select public.create_work_item(pg_temp.sp(), 'Sneak in', pg_temp.uid('b2'),
                    p_team => pg_temp.rig())$$, '42501', null, 'nor a work item');
select throws_ok($$select public.create_walk(pg_temp.sp(), null, 'Walk', '[{"title": "Go"}]', null,
                    pg_temp.rig())$$, '42501', null, 'nor a walk');
select lives_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'Everyone')$$,
  'Everyone is open');
reset role;
select pg_temp.as_user('b9');
set local role authenticated;
select lives_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'Mine',
                    p_team => pg_temp.team_named('Alpha'))$$, 'a member posts to their own Team');
reset role;

-- A Team's file from its admin ----------------------------------------------------------------------

insert into storage.objects (bucket_id, name, owner_id, metadata)
values ('space-files', pg_temp.sp()::text || '/library/' || pg_temp.id('f001')::text || '/plan.pdf',
        pg_temp.uid('c3')::text, '{"size": 1000, "mimetype": "application/pdf"}'),
       ('space-files', pg_temp.sp()::text || '/library/' || pg_temp.id('f002')::text || '/plan.pdf',
        pg_temp.uid('d4')::text, '{"size": 1000, "mimetype": "application/pdf"}');
select pg_temp.as_user('c3');
set local role authenticated;
select lives_ok($$select public.add_library_file(pg_temp.id('f001'), pg_temp.sp(), 'Plan',
                    pg_temp.sp()::text || '/library/' || pg_temp.id('f001')::text || '/plan.pdf',
                    'application/pdf', 1000, pg_temp.rig())$$, 'a Team admin adds a file to another Team');
select lives_ok($$select public.create_space_post(pg_temp.id('b003'), pg_temp.sp(), 'file', null,
                    p_team => pg_temp.rig(), p_library_file => pg_temp.id('f001'))$$,
  'and posts it there');
reset role;
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok($$select public.add_library_file(pg_temp.id('f002'), pg_temp.sp(), 'Plan',
                    pg_temp.sp()::text || '/library/' || pg_temp.id('f002')::text || '/plan.pdf',
                    'application/pdf', 1000, pg_temp.rig())$$, '42501', null, 'a member can''t');
reset role;
select pg_temp.as_user('b9');
set local role authenticated;
select ok(not public.can_read_library_file(pg_temp.id('f001')), 'a Team file stays with that Team');
reset role;

select pg_temp.as_user('c3');
set local role authenticated;
select ok((select count(*) from public.my_publish_targets() t where t.team_id = pg_temp.rig()) = 1,
  'a Team admin can publish to any Team');
reset role;
select pg_temp.as_user('d4');
set local role authenticated;
select ok((select count(*) from public.my_publish_targets() t where t.team_id = pg_temp.rig()) = 0,
  'a member only to their own');
reset role;

-- Leaving clears the admin ---------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select public.set_team_members(pg_temp.solo(), array[pg_temp.uid('d4')]);
reset role;
select is(pg_temp.admin_of(pg_temp.solo()), null, 'the Space admin takes the admin out: it clears');
select pg_temp.as_user('a1');
set local role authenticated;
select public.set_team_members(pg_temp.solo(), array[pg_temp.uid('c3'), pg_temp.uid('d4')]);
select public.set_team_admin(pg_temp.solo(), pg_temp.uid('c3'));
select public.set_member_teams(pg_temp.sp(), pg_temp.uid('c3'), '{}');
reset role;
select is(pg_temp.admin_of(pg_temp.solo()), null, 'moved out by set_member_teams: it clears');

select pg_temp.as_user('a1');
set local role authenticated;
select public.set_team_admin(pg_temp.solo(), pg_temp.uid('d4'));
select public.remove_member(pg_temp.sp(), pg_temp.uid('d4'));
reset role;
select is(pg_temp.admin_of(pg_temp.solo()), null, 'removed from the Space: it clears');

select pg_temp.as_user('a1');
set local role authenticated;
select public.set_team_members(pg_temp.solo(), array[pg_temp.uid('b9')]);
select public.set_team_admin(pg_temp.solo(), pg_temp.uid('b9'));
reset role;
select pg_temp.as_user('b9');
set local role authenticated;
select public.leave_space(pg_temp.sp());
reset role;
select is(pg_temp.admin_of(pg_temp.solo()), null, 'left the Space: it clears');

-- No longer an admin, no longer in the Team: the right has gone with it.
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'To Rigging',
                    p_team => pg_temp.rig())$$, '42501', null, 'a former Team admin can''t post to another Team');
reset role;

-- An account going away acts as nothing.
select pg_temp.as_user('a1');
set local role authenticated;
select public.set_team_members(pg_temp.solo(), array[pg_temp.uid('c3')]);
select public.set_team_admin(pg_temp.solo(), pg_temp.uid('c3'));
reset role;
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('c3');
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok($$select public.set_team_members(pg_temp.solo(), array[pg_temp.uid('c3')])$$, '42501', null,
  'a Team admin whose account is going away changes nothing');
reset role;
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('c3');

-- The record of being a Team admin is mine.
select pg_temp.as_user('a1');
set local role authenticated;
select public.set_team_members(pg_temp.solo(), array[pg_temp.uid('e5')]);
select public.set_team_admin(pg_temp.solo(), pg_temp.uid('e5'));
reset role;
insert into public.data_requests (id, profile_id) values (pg_temp.id('d001'), pg_temp.uid('e5'));
select is(public.export_my_data(pg_temp.id('d001')) -> 'team_admin_of' -> 0 ->> 'team', 'Solo',
  'my data lists the Teams I am admin of');

delete from auth.users where id = pg_temp.uid('e5');
select is(pg_temp.admin_of(pg_temp.solo()), null, 'a deleted account clears it');

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.gone', public.create_team(pg_temp.sp(), 'Gone', array[pg_temp.uid('a7')])::text, true);
select public.set_team_admin(current_setting('test.gone')::uuid, pg_temp.uid('a7'));
select lives_ok($$select public.delete_team(current_setting('test.gone')::uuid)$$, 'a Team with an admin can be deleted');
reset role;
select * from finish();
rollback;
