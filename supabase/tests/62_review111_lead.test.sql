-- Migration 20261122120000 (review 111): the lead's check V1–V9, V14.
-- Run with: supabase test db
--
-- Omar (a1) made "Tower 62": its admin. Bea (b2, Crew) is in Team Alpha.
-- Cal (c3, Crew) is in no Team. Acme Steel: Dee (d4, Viewer, joined first)
-- and Eli (e5, Crew) typed "Acme Steel"; the Team "Acme Steel" has them both.
-- Viper Works: Jon (b1, Viewer, joined first) and Kim (b3, Crew). Lone Corp:
-- Lia (b4, Viewer) only. Max (b5, Crew) typed "Acme Steal", a look-alike of
-- the existing Team. Fay (f6) is outside, never asked, typed "Acme Steel".
-- Gil (a7) asked to join and blocked Omar; Hal (a8) asked to join; Ida (a9)
-- asked to join and is deleting her account. All three typed "Acme Steel".

begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000062' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@r62.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('d4'), ('e5'), ('f6'), ('a7'), ('a8'), ('a9'),
             ('b1'), ('b3'), ('b4'), ('b5')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l, company_name_text = n.c
from (values ('a1', 'Omar', 'Haddad', null), ('b2', 'Bea', 'Alpha', null),
             ('c3', 'Cal', 'None', null), ('d4', 'Dee', 'View', 'Acme Steel'),
             ('e5', 'Eli', 'Crew', 'Acme Steel'), ('f6', 'Fay', 'Out', 'Acme Steel'),
             ('a7', 'Gil', 'Block', 'Acme Steel'), ('a8', 'Hal', 'Asks', 'Acme Steel'),
             ('a9', 'Ida', 'Gone', 'Acme Steel'), ('b1', 'Jon', 'View', 'Viper Works'),
             ('b3', 'Kim', 'Crew', 'Viper Works'), ('b4', 'Lia', 'View', 'Lone Corp'),
             ('b5', 'Max', 'Typo', 'Acme Steal')) n(id, f, l, c)
where p.id = ('00000000-0000-0000-0000-0000000062' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000062' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000062' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000062' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.alpha() returns uuid language sql as $$
  select current_setting('test.alpha')::uuid;
$$;
create function pg_temp.acme() returns uuid language sql as $$
  select current_setting('test.acme')::uuid;
$$;
create function pg_temp.admin_of(p_team uuid) returns uuid language sql as $$
  select t.admin_id from public.teams t where t.id = p_team;
$$;
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
create function pg_temp.grp(p_key text) returns jsonb language sql as $$
  select g from jsonb_array_elements(pg_temp.preview() -> 'groups') g
  where g ->> 'key' = p_key;
$$;

-- Setup ----------------------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Tower 62')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by, confirmed_at)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1'), now() - x.d * interval '1 day'
from (values ('b2', 'crew', 9), ('c3', 'crew', 8), ('d4', 'viewer', 7), ('e5', 'crew', 6),
             ('b1', 'viewer', 5), ('b3', 'crew', 4), ('b4', 'viewer', 3), ('b5', 'crew', 2)) x(id, pass, d);
insert into public.space_join_requests (space_id, profile_id, via)
select pg_temp.sp(), pg_temp.uid(x.id), 'code' from (values ('a7'), ('a8'), ('a9')) x(id);
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('a7'), pg_temp.uid('a1'));
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('a9');
select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.alpha', public.create_team(pg_temp.sp(), 'Alpha', array[pg_temp.uid('b2')])::text, true);
select set_config('test.acme', public.create_team(pg_temp.sp(), 'Acme Steel',
  array[pg_temp.uid('d4'), pg_temp.uid('e5')])::text, true);
reset role;

-- V1: a child work item keeps the Team post rule -----------------------------------------------------

select pg_temp.as_user('c3');
set local role authenticated;
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Everyone item', pg_temp.uid('b2'),
                    p_id => pg_temp.id('0001'))$$, 'Cal makes an Everyone work item');
select throws_ok($$select public.create_work_item(pg_temp.sp(), 'Sneak in', pg_temp.uid('b2'),
                    p_team => pg_temp.alpha(), p_parent => pg_temp.id('0001'))$$, '42501', null,
  'V1: a child under an Everyone item can''t go into a Team outside theirs');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Child', pg_temp.uid('b2'),
                    p_parent => pg_temp.id('0001'))$$, 'a child with no Team is fine');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Bea item', pg_temp.uid('c3'),
                    p_id => pg_temp.id('0002'))$$, 'Bea makes an Everyone work item');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Into Alpha', pg_temp.uid('c3'),
                    p_team => pg_temp.alpha(), p_parent => pg_temp.id('0002'))$$,
  'a child into the author''s own Team is fine');
reset role;

-- V2: company_team_for only for someone asking to join, or a member ---------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select * from public.company_team_for(pg_temp.sp(), pg_temp.uid('f6'))$$, '42501', null,
  'V2: not for someone who never asked to join');
select throws_ok($$select * from public.company_team_for(pg_temp.sp(), pg_temp.uid('a7'))$$, '42501', null,
  'V2: not across a block');
select throws_ok($$select * from public.company_team_for(pg_temp.sp(), pg_temp.uid('a9'))$$, '42501', null,
  'V2: not for an account going away');
select is((select team_id from public.company_team_for(pg_temp.sp(), pg_temp.uid('a8'))), pg_temp.acme(),
  'someone asking to join: their company''s Team');
select is((select team_id from public.company_team_for(pg_temp.sp(), pg_temp.uid('e5'))), pg_temp.acme(),
  'a member: their company''s Team');

-- V3: a Viewer is never a Team admin -----------------------------------------------------------------

select throws_ok($$select public.set_team_admin(pg_temp.acme(), pg_temp.uid('d4'))$$, '22023', null,
  'V3: a Viewer can''t be made Team admin');
reset role;
select is((pg_temp.grp('viperworks') ->> 'admin_id')::uuid, pg_temp.uid('b3'),
  'V3: the suggestion skips a Viewer who joined first');
select is(pg_temp.grp('lonecorp') ->> 'admin_id', null, 'V3: only Viewers: no admin suggested');
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.create_company_teams(gen_random_uuid(), pg_temp.sp(), jsonb_build_array(
    jsonb_build_object('name', 'Viper Works', 'team_id', null,
      'people', jsonb_build_array(pg_temp.uid('b1'), pg_temp.uid('b3')), 'admin_id', pg_temp.uid('b1'))))$$,
  '22023', null, 'V3: Create refuses a Viewer as admin');
select lives_ok($$select public.set_team_admin(pg_temp.acme(), pg_temp.uid('e5'))$$, 'Eli (Crew) is Team admin');
select lives_ok($$select public.set_member_pass(pg_temp.sp(), pg_temp.uid('e5'), 'viewer')$$, 'Eli becomes a Viewer');
reset role;
select is(pg_temp.admin_of(pg_temp.acme()), null, 'V3: becoming a Viewer ends being Team admin');
update public.space_members set pass = 'crew' where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e5');

-- V4: a look-alike of an existing Team's name --------------------------------------------------------

select is(pg_temp.preview() -> 'similar_teams',
  jsonb_build_array(jsonb_build_object('key', 'acmesteal', 'team_id', pg_temp.acme(), 'team_name', 'Acme Steel')),
  'V4: "Acme Steal" looks like the existing Team "Acme Steel"');

-- V6: the suggested admin's name comes with the group -----------------------------------------------

select is(pg_temp.grp('viperworks') ->> 'admin_name', 'Kim Crew', 'V6: the row names who Create will set');

-- V7: a Team file opens for its uploader, a member of the Space ----------------------------------

insert into public.library_files (id, space_id, team_id, name, storage_path, mime, uploaded_by)
values (pg_temp.id('f001'), pg_temp.sp(), pg_temp.alpha(), 'plan.pdf',
        pg_temp.sp()::text || '/library/' || pg_temp.id('f001')::text || '/plan.pdf', 'application/pdf',
        pg_temp.uid('c3'));
select pg_temp.as_user('c3');
set local role authenticated;
select ok(public.can_read_library_file(pg_temp.id('f001')), 'V7: Cal opens the Team file he uploaded');
reset role;
select pg_temp.as_user('b3');
set local role authenticated;
select ok(not public.can_read_library_file(pg_temp.id('f001')), 'someone else outside the Team doesn''t');
reset role;

-- V14: a Team admin outside a Team posts to it, and no more ------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select public.set_team_admin(pg_temp.acme(), pg_temp.uid('e5'));
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select ok(not public.can_use_thread((select t.id from public.threads t where t.team_id = pg_temp.alpha())),
  'V14: a Team admin outside Alpha doesn''t read Alpha''s chat');
select lives_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'To Alpha',
                    p_team => pg_temp.alpha())$$, 'but posts to Alpha');
reset role;

select * from finish();
rollback;
