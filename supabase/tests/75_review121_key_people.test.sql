-- Migration 20261201120000 (review 121). Run with: supabase test db
--
-- Omar (a1) made the Space "Tower 121": its admin. Khalid (b2, Crew) shows
-- his number to his Spaces; Tariq (c3, Crew) set a number and shows it to
-- nobody; Gus (a7, Crew) shows his to his Spaces and the people he messages.
-- Lina (d4) is a Lead, Vera (e5) a Viewer, Hana (a8) and Bilal (b9) Crew.
-- Eve (f6) is outside: she made "Other site", and she has a direct message
-- with Khalid and with Gus. Ali (c9) is in two Teams: Gulf MEP (his company)
-- and Night shift. Sami (ca) and Bilal typed "Delta Steel" and are in Night
-- shift only.

begin;
create extension if not exists pgtap with schema extensions;
select plan(99);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000121' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@r121.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('d4'), ('e5'), ('f6'), ('a7'), ('a8'), ('b9'), ('c9'),
             ('ca')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l, company_name_text = n.c,
                             headline = n.h
from (values ('a1', 'Omar', 'Haddad', null, 'Project manager'),
             ('b2', 'Khalid', 'Al-Mansour', 'NBKCH', 'Safety'),
             ('c3', 'Tariq', 'Rahman', 'NBKCH', 'Safety'),
             ('d4', 'Lina', 'Saad', null, null), ('e5', 'Vera', 'Lane', null, null),
             ('f6', 'Eve', 'Out', null, null), ('a7', 'Gus', 'Store', null, null),
             ('a8', 'Hana', 'Nurse', null, null), ('b9', 'Bilal', 'Block', 'Delta Steel', null),
             ('c9', 'Ali', 'Saleh', 'Gulf MEP', 'Electrician'),
             ('ca', 'Sami', 'Adel', 'Delta Steel', null)
     ) n(id, f, l, c, h)
where p.id = ('00000000-0000-0000-0000-0000000121' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000121' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000121' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000121' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.sp2() returns uuid language sql as $$
  select current_setting('test.space2')::uuid;
$$;
create function pg_temp.gulf() returns uuid language sql as $$
  select current_setting('test.gulf')::uuid;
$$;
create function pg_temp.night() returns uuid language sql as $$
  select current_setting('test.night')::uuid;
$$;
create function pg_temp.safety() returns uuid language sql as $$
  select current_setting('test.safety')::uuid;
$$;
-- What [p_who] reads from space_key_people for the Space.
create function pg_temp.people(p_who text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  v := public.space_key_people(pg_temp.sp());
  reset role;
  return v;
end;
$$;
-- The number [p_who] gets for [p_of], from [p_space].
create function pg_temp.phone(p_who text, p_of text, p_space uuid) returns text language plpgsql as $$
declare v text;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  v := public.person_phone(pg_temp.uid(p_of), p_space);
  reset role;
  return v;
end;
$$;
create function pg_temp.role_names() returns text[] language sql as $$
  select array_agg(r ->> 'name' order by o)
  from jsonb_array_elements(pg_temp.people('a1') -> 'roles') with ordinality x(r, o);
$$;
create function pg_temp.empty_lines(p_role text) returns integer language sql as $$
  select count(*)::int from public.notifications n
  where n.profile_id = pg_temp.uid('a1') and n.kind = 'key_role_empty'
    and n.space_id = pg_temp.sp() and n.payload ->> 'role' = p_role;
$$;
create function pg_temp.sees(p_who text, p_post uuid) returns boolean language plpgsql as $$
declare v boolean;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  v := public.can_see_space_post(p_post);
  reset role;
  return v;
end;
$$;
create function pg_temp.reads(p_who text, p_file uuid) returns boolean language plpgsql as $$
declare v boolean;
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  v := public.can_read_library_file(p_file);
  reset role;
  return v;
end;
$$;
-- D: a Tuesday at least 30 days ahead; [p_time] on D, in Kuwait.
create function pg_temp.at(p_time text) returns timestamptz language sql as $$
  select ((select x::date from generate_series(current_date + 30, current_date + 37,
                                               interval '1 day') x
           where extract(isodow from x) = 2 order by x limit 1) + p_time::time)
         at time zone 'Asia/Kuwait';
$$;

-- Setup ----------------------------------------------------------------------------------------------

insert into public.projects (id, name, type_id, market_id)
values (pg_temp.id('e001'), 'Tower 121', (select id from public.project_types limit 1), 'kw');
select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Tower 121')::text, true);
reset role;
update public.spaces set project_id = pg_temp.id('e001') where id = pg_temp.sp();
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1')
from (values ('b2', 'crew'), ('c3', 'crew'), ('d4', 'lead'), ('e5', 'viewer'), ('a7', 'crew'),
             ('a8', 'crew'), ('b9', 'crew'), ('c9', 'crew'), ('ca', 'crew')) x(id, pass);
select pg_temp.as_user('f6');
set local role authenticated;
select set_config('test.space2', public.create_space('Other site')::text, true);
reset role;
-- Eve's direct messages: with Khalid and with Gus, both open.
insert into public.dm_threads (id, a_id, b_id, started_by)
values (pg_temp.id('d001'), least(pg_temp.uid('b2'), pg_temp.uid('f6')),
        greatest(pg_temp.uid('b2'), pg_temp.uid('f6')), pg_temp.uid('f6')),
       (pg_temp.id('d002'), least(pg_temp.uid('a7'), pg_temp.uid('f6')),
        greatest(pg_temp.uid('a7'), pg_temp.uid('f6')), pg_temp.uid('f6'));
insert into public.dm_members (thread_id, profile_id, state)
values (pg_temp.id('d001'), pg_temp.uid('b2'), 'open'), (pg_temp.id('d001'), pg_temp.uid('f6'), 'open'),
       (pg_temp.id('d002'), pg_temp.uid('a7'), 'open'), (pg_temp.id('d002'), pg_temp.uid('f6'), 'open');

-- The tables: RLS on, nothing read or written directly ---------------------------------------------

select ok((select relrowsecurity from pg_class where oid = 'public.space_key_roles'::regclass),
  'space_key_roles has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.space_key_holders'::regclass),
  'space_key_holders has row-level security');
select ok(not has_table_privilege('authenticated', 'public.space_key_roles', 'select')
          and not has_table_privilege('authenticated', 'public.space_key_roles', 'insert')
          and not has_table_privilege('authenticated', 'public.space_key_holders', 'select')
          and not has_table_privilege('authenticated', 'public.space_key_holders', 'insert'),
  'members read and write only through the functions');
select ok(not has_table_privilege('authenticated', 'public.phone_reads', 'select'),
  'nobody reads who asked for numbers');
select is((select count(*)::int from pg_proc
           where oid in ('public.space_key_people(uuid)'::regprocedure,
                         'public.save_key_role(uuid, uuid, text, text, jsonb)'::regprocedure,
                         'public.delete_key_role(uuid)'::regprocedure,
                         'public.reorder_key_roles(uuid, uuid[])'::regprocedure,
                         'public.mark_key_people_seen(uuid)'::regprocedure,
                         'public.person_phone(uuid, uuid)'::regprocedure,
                         'public.my_phone()'::regprocedure,
                         'public.set_my_phone(text, text)'::regprocedure)
             and prosecdef and proconfig @> array['search_path=""']),
  8, 'every function is security definer with an empty search_path');
select ok(not has_function_privilege('anon', 'public.space_key_people(uuid)', 'execute')
          and not has_function_privilege('anon', 'public.person_phone(uuid, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.set_my_phone(text, text)', 'execute')
          and not has_function_privilege('authenticated', 'public.phone_shown_to(uuid, uuid, uuid)', 'execute'),
  'nothing for anon; the visibility rule is internal');

-- The market pack's role names ---------------------------------------------------------------------

select ok((select key_role_suggestions @> '[{"en": "Safety officer", "ar": "ضابط السلامة"}]'
                  and key_role_suggestions @> '[{"en": "Project engineer"}, {"en": "Site manager"},
                                                {"en": "Site nurse"}, {"en": "Storekeeper"}]'
           from public.markets where id = 'kw'), 'Kuwait has the five role names');
select ok((select jsonb_array_length(key_role_suggestions) >= 5
                  and key_role_suggestions @> '[{"en": "Safety officer", "ar": "ضابط السلامة"}]'
           from public.markets where id = 'eg'), 'and Egypt');
select ok(not exists (select 1 from public.markets m, jsonb_array_elements(m.key_role_suggestions) s
                      where s ->> 'ar' like '%مسؤول%'),
  '«مسؤول» is the Lead pass word, never a role name');
set local role anon;
select lives_ok($$select key_role_suggestions from public.markets$$, 'readable before signing in');
reset role;

-- The phone number: never selected directly -----------------------------------------------------------

select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok($$select phone from public.profiles$$, '42501', null,
  'no client selects phone');
select lives_ok($$select id, first_name, last_name, headline, phone_visibility from public.profiles$$,
  'every other column still reads');
select throws_ok($$update public.profiles set phone = '+96550001234' where id = auth.uid()$$, '42501', null,
  'nor writes it: set_my_phone checks it');
reset role;

select pg_temp.as_user('b2');
set local role authenticated;
select is((public.my_phone() ->> 'visibility'), 'nobody', 'Nobody by default');
select lives_ok($$select public.set_my_phone('+96550001234', 'spaces')$$, 'Khalid shows his to his Spaces');
select is(public.my_phone(), '{"phone": "+96550001234", "visibility": "spaces"}'::jsonb,
  'he reads his own number back');
select throws_ok($$select public.set_my_phone('50001234', 'spaces')$$, '22023', null,
  'E.164 only');
select throws_ok($$select public.set_my_phone('+9655000123', 'spaces')$$, '22023', null,
  'a Kuwait number has 8 digits (the market pack)');
select throws_ok($$select public.set_my_phone('+96520001234', 'spaces')$$, '22023', null,
  'and is a mobile number');
select throws_ok($$select public.set_my_phone('+99950001234', 'spaces')$$, '22023', null,
  'from a market the pack knows');
select throws_ok($$select public.set_my_phone('+96550001234', 'everyone')$$, '22023', null,
  'one of the three choices');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select lives_ok($$select public.set_my_phone('+96560001234')$$, 'Tariq sets a number only');
reset role;
select is((select phone_visibility from public.profiles where id = pg_temp.uid('c3')), 'nobody',
  'and it stays Nobody');
select pg_temp.as_user('a7');
set local role authenticated;
select lives_ok($$select public.set_my_phone('+96590001234', 'spaces_and_dms')$$, 'Gus: Spaces and DMs');
reset role;

-- person_phone ---------------------------------------------------------------------------------------

select is(pg_temp.phone('d4', 'b2', pg_temp.sp()), '+96550001234', 'a member of that Space gets it');
select is(pg_temp.phone('e5', 'b2', pg_temp.sp()), '+96550001234', 'a Viewer too');
select is(pg_temp.phone('d4', 'c3', pg_temp.sp()), null, 'Nobody: null');
select is(pg_temp.phone('f6', 'b2', pg_temp.sp()), null, 'a stranger naming the Space: null');
select is(pg_temp.phone('f6', 'b2', pg_temp.sp2()), null, 'a Space Khalid isn''t in: null');
select is(pg_temp.phone('f6', 'b2', null), null, 'Spaces only, from a direct message: null');
select is(pg_temp.phone('f6', 'a7', null), '+96590001234', 'Spaces and DMs, from a direct message');
update public.dm_members set state = 'request'
where thread_id = pg_temp.id('d002') and profile_id = pg_temp.uid('a7');
select is(pg_temp.phone('f6', 'a7', null), null, 'not while Gus hasn''t accepted it');
update public.dm_members set state = 'open'
where thread_id = pg_temp.id('d002') and profile_id = pg_temp.uid('a7');
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('b2'), pg_temp.uid('d4'));
select is(pg_temp.phone('d4', 'b2', pg_temp.sp()), null, 'blocked: null');
delete from public.blocks where blocker_id = pg_temp.uid('b2');
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('d4');
select is(pg_temp.phone('d4', 'b2', pg_temp.sp()), null, 'after leaving: null');
update public.space_members set left_at = null
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('d4');

select pg_temp.as_user('e5');
set local role authenticated;
select lives_ok($$select count(public.person_phone(pg_temp.uid('b2'), pg_temp.sp()))
                  from generate_series(1, 29)$$, '30 a day');
select throws_ok($$select public.person_phone(pg_temp.uid('b2'), pg_temp.sp())$$, '54000', null,
  'the 31st is refused');
reset role;
select ok(not exists (select 1 from public.phone_reads r
                      where r.caller_id = pg_temp.uid('e5') and r.created_at < now() - interval '1 day'),
  'counted over a day');

-- Key roles: the Space admin only --------------------------------------------------------------------

select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok($$select public.save_key_role(pg_temp.sp(), null, 'Safety officer', null, '[]')$$,
  '42501', null, 'a Lead doesn''t set key people');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.save_key_role(pg_temp.sp(), null, 'Safety officer', null, '[]')$$,
  '42501', null, 'nor does Crew');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.save_key_role(pg_temp.sp(), null, 'Safety officer', null, '[]')$$,
  '42501', null, 'nor anyone outside');
reset role;

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.safety', public.save_key_role(pg_temp.sp(), null, 'Safety officer',
  'Hazards, accidents, work permits',
  jsonb_build_array(jsonb_build_object('profile_id', pg_temp.uid('b2'), 'note', 'Day shift'),
                    jsonb_build_object('profile_id', pg_temp.uid('c3'), 'note', 'Night shift')))::text,
  true);
select ok(pg_temp.safety() is not null, 'the Space admin adds a role with two people');
select throws_ok(format($$select public.save_key_role(%L, null, 'Nurse', null, %L)$$, pg_temp.sp(),
    jsonb_build_array(jsonb_build_object('profile_id', pg_temp.uid('f6')))),
  '22023', null, 'a holder is a member of this Space');
select throws_ok(format($$select public.save_key_role(%L, null, 'Nurse', null, %L)$$, pg_temp.sp(),
    jsonb_build_array(jsonb_build_object('profile_id', pg_temp.uid('b2')),
                      jsonb_build_object('profile_id', pg_temp.uid('c3')),
                      jsonb_build_object('profile_id', pg_temp.uid('a8')))),
  '54000', null, 'up to 2 people');
select throws_ok(format($$select public.save_key_role(%L, null, 'Nurse', null, %L)$$, pg_temp.sp(),
    jsonb_build_array(jsonb_build_object('profile_id', pg_temp.uid('b2')),
                      jsonb_build_object('profile_id', pg_temp.uid('b2')))),
  '22023', null, 'one person once');
select throws_ok(format($$select public.save_key_role(%L, null, %L, null, '[]')$$, pg_temp.sp(),
    repeat('x', 41)), '22023', null, 'a name of 40 characters at most');
select throws_ok(format($$select public.save_key_role(%L, null, '  ', null, '[]')$$, pg_temp.sp()),
  '22023', null, 'and not empty');
select throws_ok(format($$select public.save_key_role(%L, null, 'Nurse', %L, '[]')$$, pg_temp.sp(),
    repeat('x', 121)), '22023', null, 'Call for: 120 at most');
select throws_ok(format($$select public.save_key_role(%L, null, 'Nurse', null, %L)$$, pg_temp.sp(),
    jsonb_build_array(jsonb_build_object('profile_id', pg_temp.uid('a8'), 'note', repeat('x', 25)))),
  '22023', null, 'a note of 24 at most');
select lives_ok(format($$select public.save_key_role(%L, null, 'Project engineer', 'Drawings', %L)$$,
    pg_temp.sp(), jsonb_build_array(jsonb_build_object('profile_id', pg_temp.uid('d4')))),
  'a second role');
select lives_ok(format($$select public.save_key_role(%L, null, 'Storekeeper', null, %L)$$,
    pg_temp.sp(), jsonb_build_array(jsonb_build_object('profile_id', pg_temp.uid('a8')))),
  'a third, with Hana alone');
select lives_ok(format($$select public.save_key_role(%L, null, 'Site nurse', null, '[]')$$, pg_temp.sp()),
  'a fourth, no one yet');
select lives_ok(format($$select public.save_key_role(%L, null, 'Site manager', null, '[]')$$, pg_temp.sp()),
  'a fifth');
select lives_ok(format($$select public.save_key_role(%L, null, 'Crane', null, '[]')$$, pg_temp.sp()),
  'a sixth');
select throws_ok(format($$select public.save_key_role(%L, null, 'Seventh', null, '[]')$$, pg_temp.sp()),
  '54000', null, 'up to 6 roles');
reset role;
select is(pg_temp.role_names(),
  array['Safety officer', 'Project engineer', 'Storekeeper', 'Site nurse', 'Site manager', 'Crane'],
  'in the order they were added');

-- Reading: every member, Viewers too, never the number --------------------------------------------------

select is(jsonb_array_length(pg_temp.people('e5') -> 'roles'), 6, 'a Viewer reads Who to call');
select is(pg_temp.people('e5') -> 'roles' -> 0 ->> 'call_for', 'Hazards, accidents, work permits',
  'with what to call them for');
select is((select array_agg(h ->> 'first_name' order by o)
           from jsonb_array_elements(pg_temp.people('e5') -> 'roles' -> 0 -> 'holders')
                with ordinality x(h, o)),
  array['Khalid', 'Tariq'], 'its people, in order');
select is(pg_temp.people('e5') -> 'roles' -> 0 -> 'holders' -> 0 ->> 'note', 'Day shift', 'with the note');
select is(pg_temp.people('e5') -> 'roles' -> 0 -> 'holders' -> 0 ->> 'company_name_text', 'NBKCH',
  'and title · company');
select is((pg_temp.people('e5') -> 'roles' -> 0 -> 'holders' -> 0 ->> 'can_call')::boolean, true,
  'Call for Khalid (Spaces)');
select is((pg_temp.people('e5') -> 'roles' -> 0 -> 'holders' -> 1 ->> 'can_call')::boolean, false,
  'not for Tariq (Nobody)');
select ok(pg_temp.people('e5')::text not like '%50001234%'
          and pg_temp.people('e5')::text not like '%60001234%',
  'never the number itself');
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok(format($$select public.space_key_people(%L)$$, pg_temp.sp()), '42501', null,
  'nobody outside the Space');
reset role;

-- Changing, ordering, deleting -----------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select is(public.save_key_role(pg_temp.sp(), pg_temp.safety(), 'Safety officer', 'Hazards',
  jsonb_build_array(jsonb_build_object('profile_id', pg_temp.uid('c3')),
                    jsonb_build_object('profile_id', pg_temp.uid('b2'), 'note', 'Day shift'))),
  pg_temp.safety(), 'a change keeps the role');
reset role;
select is((select array_agg(h ->> 'first_name' order by o)
           from jsonb_array_elements(pg_temp.people('a1') -> 'roles' -> 0 -> 'holders')
                with ordinality x(h, o)),
  array['Tariq', 'Khalid'], 'its people in the new order');
select is(pg_temp.people('a1') -> 'roles' -> 0 ->> 'call_for', 'Hazards', 'and the new line');
select set_config('test.reversed', (select array_agg(id order by position desc)
  from public.space_key_roles where space_id = pg_temp.sp())::text, true);
select set_config('test.short', (select array_agg(id)
  from public.space_key_roles where space_id = pg_temp.sp() and name <> 'Crane')::text, true);
select set_config('test.crane', (select id::text
  from public.space_key_roles where space_id = pg_temp.sp() and name = 'Crane'), true);
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok(format($$select public.reorder_key_roles(%L, %L)$$, pg_temp.sp(),
    current_setting('test.reversed')), 'reordered');
select throws_ok(format($$select public.reorder_key_roles(%L, %L)$$, pg_temp.sp(),
    current_setting('test.short')), '22023', null, 'every role, once');
reset role;
select is(pg_temp.role_names(),
  array['Crane', 'Site manager', 'Site nurse', 'Storekeeper', 'Project engineer', 'Safety officer'],
  'as the admin set it');
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok(format($$select public.reorder_key_roles(%L, %L)$$, pg_temp.sp(),
    current_setting('test.reversed')), '42501', null, 'a Lead doesn''t reorder');
select throws_ok(format($$select public.delete_key_role(%L)$$, pg_temp.safety()), '42501', null,
  'nor delete');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok(format($$select public.delete_key_role(%L)$$, current_setting('test.crane')),
  'the Space admin deletes a role');
reset role;
select is(cardinality(pg_temp.role_names()), 5, 'five left');

-- A holder leaves ------------------------------------------------------------------------------------

update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a8');
select is((select count(*)::int from public.space_key_holders where profile_id = pg_temp.uid('a8')), 0,
  'Hana left: she is off the role');
select is(pg_temp.empty_lines('Storekeeper'), 1, 'the Space admin hears "Storekeeper has no one now"');
select is((select actor_id from public.notifications
           where profile_id = pg_temp.uid('a1') and kind = 'key_role_empty'), null,
  'as one line, with no face');
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok(format($$select public.remove_member(%L, %L)$$, pg_temp.sp(), pg_temp.uid('c3')),
  'Tariq is removed');
reset role;
select is((select count(*)::int from public.space_key_holders where profile_id = pg_temp.uid('c3')), 0,
  'and is off the role');
select is(pg_temp.empty_lines('Safety officer'), 0, 'Khalid still holds it: no line');
delete from public.space_members where space_id = pg_temp.sp() and profile_id = pg_temp.uid('d4');
select is(pg_temp.empty_lines('Project engineer'), 1, 'a deleted membership empties it too');

-- KP2: seen once ---------------------------------------------------------------------------------------

select is((pg_temp.people('b9') ->> 'seen')::boolean, false, 'a new member hasn''t seen Who to call');
select pg_temp.as_user('b9');
set local role authenticated;
select lives_ok(format($$select public.mark_key_people_seen(%L)$$, pg_temp.sp()), 'Got it');
reset role;
select is((pg_temp.people('b9') ->> 'seen')::boolean, true, 'then it doesn''t show again');
select is((pg_temp.people('a1') ->> 'seen')::boolean, true, 'whoever made the Space never sees it');

-- One person in several Teams ------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.gulf', public.create_team(pg_temp.sp(), 'Gulf MEP',
  array[pg_temp.uid('c9'), pg_temp.uid('b2')])::text, true);
select set_config('test.night', public.create_team(pg_temp.sp(), 'Night shift',
  array[pg_temp.uid('c9'), pg_temp.uid('b9'), pg_temp.uid('ca')])::text, true);
select lives_ok($$select public.set_team_admin(pg_temp.gulf(), pg_temp.uid('c9'))$$,
  'Ali is the admin of one Team');
select lives_ok($$select public.set_team_admin(pg_temp.night(), pg_temp.uid('c9'))$$,
  'and of another');
select lives_ok($$select public.create_space_post(pg_temp.id('b001'), pg_temp.sp(), 'note', 'To Gulf MEP',
                    p_team => pg_temp.gulf())$$, 'a post to Gulf MEP');
select lives_ok($$select public.create_space_post(pg_temp.id('b002'), pg_temp.sp(), 'note', 'To Night shift',
                    p_team => pg_temp.night())$$, 'and one to Night shift');
reset role;
select is((select array_agg(t.name order by t.name) from public.team_members tm
           join public.teams t on t.id = tm.team_id where tm.profile_id = pg_temp.uid('c9')),
  array['Gulf MEP', 'Night shift'], 'Ali is in both Teams');
select ok(pg_temp.sees('c9', pg_temp.id('b001')) and pg_temp.sees('c9', pg_temp.id('b002')),
  'he sees both Teams'' posts');
insert into public.library_files (id, space_id, team_id, name, storage_path, mime, uploaded_by)
select pg_temp.id(x.f), pg_temp.sp(), x.t, x.n,
       pg_temp.sp()::text || '/library/' || pg_temp.id(x.f)::text || '/' || x.n, 'application/pdf',
       pg_temp.uid('a1')
from (values ('f001', pg_temp.gulf(), 'gulf.pdf'), ('f002', pg_temp.night(), 'night.pdf')) x(f, t, n);
select ok(pg_temp.reads('c9', pg_temp.id('f001')) and pg_temp.reads('c9', pg_temp.id('f002')),
  'and both Teams'' files');

-- A check-in for both Teams: one push.
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.post_check_in(pg_temp.id('c101'), pg_temp.sp(), 'Roll call', null,
  array[pg_temp.gulf(), pg_temp.night()], 29.3759, 47.9774, '07:00', 15, null, null, true)$$,
  'a check-in for both Teams');
reset role;
insert into public.push_tokens (token, profile_id, platform)
values (repeat('a', 40), pg_temp.uid('c9'), 'android');
select ok(public.check_in_notify(pg_temp.at('06:45')) >= 1, 'it opens');
select is((select count(*)::int from public.push_queue
           where profile_id = pg_temp.uid('c9') and kind = 'check_in_open'
             and data ->> 'post_id' = pg_temp.id('c101')::text),
  1, 'Ali, in both Teams, gets one push');

-- TM1: a shift Team doesn't hide a company.
select pg_temp.as_user('a1');
set local role authenticated;
select is((select array_agg(p ->> 'name' order by p ->> 'name')
           from jsonb_array_elements(public.company_team_preview(pg_temp.sp()) -> 'groups') g,
                jsonb_array_elements(g -> 'people') p
           where g ->> 'name' = 'Delta Steel' and g ->> 'team_id' is null),
  array['Bilal Block', 'Sami Adel'], 'Delta Steel is still offered, though both are in Night shift');

-- Out of one Team, still in the other.
select lives_ok($$select public.set_team_members(pg_temp.night(), array[pg_temp.uid('b9'), pg_temp.uid('ca')])$$,
  'Ali leaves Night shift');
reset role;
select ok(pg_temp.sees('c9', pg_temp.id('b001')) and not pg_temp.sees('c9', pg_temp.id('b002')),
  'Gulf MEP''s post still, Night shift''s not');
select ok(exists (select 1 from public.team_members
                  where team_id = pg_temp.gulf() and profile_id = pg_temp.uid('c9')),
  'and he is still in Gulf MEP');

select * from finish();
rollback;
