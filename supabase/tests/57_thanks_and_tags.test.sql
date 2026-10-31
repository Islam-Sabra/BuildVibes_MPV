-- Migration 20261118120000 (review 110 E): Thanks, and tags on work items.
-- Run with: supabase test db
--
-- Omar (a1) made the Space, a project in Kuwait: its admin, a Lead. Rakesh
-- (b2) and Tariq (c3) are Crew in the Team "Steel fixers"; Lina (d4) is Crew
-- outside it. Vera (e5) is a Viewer. Eve (f6) is not in the Space; she has
-- her own Space, with a Team and a work item. Omar also has a Space with no
-- project.

begin;
create extension if not exists pgtap with schema extensions;
select plan(113);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000057' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@th57.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('d4'), ('e5'), ('f6')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('a1', 'Omar', 'Haddad'), ('b2', 'Rakesh', 'Nair'), ('c3', 'Tariq', 'Aziz'),
             ('d4', 'Lina', 'Saad'), ('e5', 'Vera', 'Lane'), ('f6', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000057' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000057' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000057' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000057' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.sp2() returns uuid language sql as $$
  select current_setting('test.space2')::uuid;
$$;
create function pg_temp.sp3() returns uuid language sql as $$
  select current_setting('test.space3')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
create function pg_temp.team2() returns uuid language sql as $$
  select current_setting('test.team2')::uuid;
$$;
-- [p_post]'s card as [p_id] reads it in Work.
create function pg_temp.card(p_id text, p_post text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  select c.card into v from public.daybook_cards(
    (select space_id from public.space_posts where id = pg_temp.id(p_post)), null, 100) c
  where c.id = pg_temp.id(p_post);
  reset role;
  return v;
end;
$$;
-- The Thanks rows [p_id] reads through RLS in [p_space].
create function pg_temp.thanks_read(p_id text, p_space uuid) returns integer language plpgsql as $$
declare v integer;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  select count(*) into v from public.space_thanks where space_id = p_space;
  reset role;
  return v;
end;
$$;
-- The shown Thanks on [p_profile]'s profile, as [p_id] reads them.
create function pg_temp.on_profile(p_id text, p_profile text) returns integer language plpgsql as $$
declare v integer;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  select count(*) into v from public.profile_thanks(pg_temp.uid(p_profile));
  reset role;
  return v;
end;
$$;

-- Setup ----------------------------------------------------------------------------------------------

insert into public.projects (id, name, type_id, market_id)
values (pg_temp.id('c001'), 'Kuwait tower', (select id from public.project_types limit 1), 'kw');

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Thanks tower')::text, true);
select set_config('test.space3', public.create_space('No project yard')::text, true);
reset role;
update public.spaces set project_id = pg_temp.id('c001') where id = pg_temp.sp();
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1')
from (values ('b2', 'crew'), ('c3', 'crew'), ('d4', 'crew'), ('e5', 'viewer')) x(id, pass);
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp3(), pg_temp.uid('b2'), 'crew', pg_temp.uid('a1'));
select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'Steel fixers',
  array[pg_temp.uid('b2'), pg_temp.uid('c3')])::text, true);
reset role;

select pg_temp.as_user('f6');
set local role authenticated;
select set_config('test.space2', public.create_space('Other site')::text, true);
select set_config('test.team2', public.create_team(pg_temp.sp2(), 'Other team', '{}')::text, true);
select public.create_work_item(pg_temp.sp2(), 'Their own item', pg_temp.uid('f6'),
  p_id => pg_temp.id('a009'));
reset role;

-- Tariq's work items for Rakesh: one tagged Safety with two points, one
-- plain, one in the Team.
select pg_temp.as_user('c3');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Formwork check, level 3', pg_temp.uid('b2'),
  p_id => pg_temp.id('a001'), p_tag => 'safety',
  p_points => '[{"text": "Props at 1.2 m"}, {"text": "Ties tight"}]'::jsonb);
select public.create_work_item(pg_temp.sp(), 'Sleeves at grid C7', pg_temp.uid('b2'),
  p_id => pg_temp.id('a002'));
select public.create_work_item(pg_temp.sp(), 'Rebar for the core wall', pg_temp.uid('b2'),
  p_id => pg_temp.id('a003'), p_team => pg_temp.team());
reset role;

-- 1. The market list ----------------------------------------------------------------------------------

select has_table('public', 'market_work_tags', 'market_work_tags exists');
select ok((select relrowsecurity from pg_class where oid = 'public.market_work_tags'::regclass),
  'with row-level security on');
select ok(not has_table_privilege('authenticated', 'public.market_work_tags', 'insert')
          and not has_table_privilege('authenticated', 'public.market_work_tags', 'update')
          and not has_table_privilege('authenticated', 'public.market_work_tags', 'delete'),
  'nobody writes it through the API');
select ok(not has_table_privilege('anon', 'public.market_work_tags', 'select'),
  'only signed-in people read it');
select is((select array_agg(id order by sort) from public.market_work_tags where market_id = 'kw'),
  array['safety', 'quality', 'design', 'material', 'admin'], 'Kuwait: the five tags, in order');
select is((select array_agg(id order by sort) from public.market_work_tags where market_id = 'eg'),
  array['safety', 'quality', 'design', 'material', 'admin'], 'Egypt: the same five');
select is((select array_agg(market_id order by market_id) from public.market_work_tags where danger),
  array['eg', 'kw'], 'only Safety is danger, in both');
select is((select name ->> 'ar' from public.market_work_tags where market_id = 'kw' and id = 'safety'),
  'سلامة', 'Safety in Arabic');
select is((select name ->> 'en' from public.market_work_tags where market_id = 'eg' and id = 'admin'),
  'Admin', 'Admin in English');
select pg_temp.as_user('f6');
set local role authenticated;
select is((select count(*) from public.market_work_tags)::integer, 10,
  'anyone signed in reads the list, even outside every Space');
select throws_ok($$insert into public.market_work_tags (market_id, id, name)
  values ('kw', 'roofing', '{"en": "Roofing", "ar": "أسقف"}')$$, '42501', null,
  'and can''t add to it');
reset role;

-- 2. Thanks: the table ---------------------------------------------------------------------------------

select has_table('public', 'space_thanks', 'space_thanks exists');
select ok((select relrowsecurity from pg_class where oid = 'public.space_thanks'::regclass),
  'with row-level security on');
select ok(not has_table_privilege('authenticated', 'public.space_thanks', 'insert')
          and not has_table_privilege('authenticated', 'public.space_thanks', 'update')
          and not has_table_privilege('authenticated', 'public.space_thanks', 'delete'),
  'nobody writes it directly');
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok(format($q$insert into public.space_thanks (post_id, space_id, to_kind, to_profile)
  values (%L, %L, 'person', %L)$q$, pg_temp.id('a002'), pg_temp.sp(), pg_temp.uid('f6')),
  '42501', null, 'an outsider can''t write a row');
reset role;

-- 3. create_thanks -------------------------------------------------------------------------------------

select pg_temp.as_user('c3');
set local role authenticated;
select lives_ok(format($q$select public.create_thanks(%L, %L, 'Thank you for staying late on the formwork',
  p_to_person => %L, p_for => %L)$q$, pg_temp.id('b001'), pg_temp.sp(), pg_temp.uid('b2'),
  pg_temp.id('a001')), 'Crew thanks a member, for a work item');
select is(public.create_thanks(pg_temp.id('b001'), pg_temp.sp(), 'Thank you for staying late on the formwork',
  p_to_person => pg_temp.uid('b2'), p_for => pg_temp.id('a001')), pg_temp.id('b001'),
  'the same id again is the same Thanks');
select lives_ok(format($q$select public.create_thanks(%L, %L, null, p_to_team => %L)$q$,
  pg_temp.id('b002'), pg_temp.sp(), pg_temp.team()), 'a Team, with no words');
select lives_ok(format($q$select public.create_thanks(%L, %L, 'Core wall rebar, spot on',
  p_to_person => %L, p_for => %L)$q$, pg_temp.id('b003'), pg_temp.sp(), pg_temp.uid('b2'),
  pg_temp.id('a003')), 'for a Team''s work item');
select throws_ok(format($q$select public.create_thanks(%L, %L, 'Me', p_to_person => %L)$q$,
  pg_temp.id('b004'), pg_temp.sp(), pg_temp.uid('c3')), '22023', 'thank someone else',
  'not yourself');
select throws_ok(format($q$select public.create_thanks(%L, %L, 'Both', p_to_person => %L, p_to_team => %L)$q$,
  pg_temp.id('b004'), pg_temp.sp(), pg_temp.uid('b2'), pg_temp.team()), '22023',
  'thank a person or a team', 'not a person and a team');
select throws_ok(format($q$select public.create_thanks(%L, %L, 'Nobody')$q$,
  pg_temp.id('b004'), pg_temp.sp()), '22023', 'thank a person or a team', 'not nobody');
select throws_ok(format($q$select public.create_thanks(%L, %L, 'Out', p_to_person => %L)$q$,
  pg_temp.id('b004'), pg_temp.sp(), pg_temp.uid('f6')), '22023', 'only someone in this Space',
  'not someone outside the Space');
select throws_ok(format($q$select public.create_thanks(%L, %L, 'Theirs', p_to_team => %L)$q$,
  pg_temp.id('b004'), pg_temp.sp(), pg_temp.team2()), '22023', 'team not in this Space',
  'not a Team of another Space');
select throws_ok(format($q$select public.create_thanks(%L, %L, 'Theirs', p_to_person => %L, p_for => %L)$q$,
  pg_temp.id('b004'), pg_temp.sp(), pg_temp.uid('b2'), pg_temp.id('a009')), '22023',
  'only a work item of this Space', 'not For a work item of another Space');
select throws_ok(format($q$select public.create_thanks(%L, %L, 'A thanks', p_to_person => %L, p_for => %L)$q$,
  pg_temp.id('b004'), pg_temp.sp(), pg_temp.uid('b2'), pg_temp.id('b002')), '22023',
  'only a work item of this Space', 'For is a work item, not another post');
select throws_ok(format($q$select public.create_thanks(%L, %L, %L, p_to_person => %L)$q$,
  pg_temp.id('b004'), pg_temp.sp(), repeat('x', 5001), pg_temp.uid('b2')), '22023',
  'at most 5000 characters', 'words of up to 5000 characters');
reset role;
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok(format($q$select public.create_thanks(%L, %L, 'Mine now', p_to_person => %L)$q$,
  pg_temp.id('b001'), pg_temp.sp(), pg_temp.uid('b2')), '42501', 'not allowed',
  'another author''s id is not allowed');
select throws_ok(format($q$select public.create_thanks(%L, %L, 'Hidden', p_to_person => %L, p_for => %L)$q$,
  pg_temp.id('b004'), pg_temp.sp(), pg_temp.uid('b2'), pg_temp.id('a003')), '22023',
  'only a work item of this Space', 'not For a work item the author can''t see');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok(format($q$select public.create_thanks(%L, %L, 'Viewer', p_to_person => %L)$q$,
  pg_temp.id('b005'), pg_temp.sp(), pg_temp.uid('b2')), '42501', 'not allowed',
  'a Viewer reads only');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok(format($q$select public.create_thanks(%L, %L, 'Outsider', p_to_person => %L)$q$,
  pg_temp.id('b006'), pg_temp.sp(), pg_temp.uid('b2')), '42501', 'not allowed',
  'nor someone outside the Space');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok(format($q$select public.create_space_post(%L, %L, 'thanks', 'Thanks')$q$,
  pg_temp.id('b007'), pg_temp.sp()), '22023', 'choose a kind of post',
  'a Thanks is made only by create_thanks');
reset role;

select is((select kind || '|' || title || '|' || body from public.space_posts where id = pg_temp.id('b001')),
  'thanks||Thank you for staying late on the formwork', 'a thanks post: no title, the words as its body');
select is((select to_kind || '|' || to_profile::text || '|' || for_post::text || '|' || show_on_profile::text
           from public.space_thanks where post_id = pg_temp.id('b001')),
  'person|' || pg_temp.uid('b2') || '|' || pg_temp.id('a001') || '|false', 'its facts');
select is((select team_id from public.space_posts where id = pg_temp.id('b002')), null,
  'a Team''s Thanks is for the whole Space to see');
select is((select count(*) from public.notifications
           where space_post_id in (pg_temp.id('b001'), pg_temp.id('b002'), pg_temp.id('b003')))::integer, 0,
  'a Thanks tells nobody');
select ok(not exists (select 1 from public.work_item_events where work_item_id = pg_temp.id('b001')),
  'and has no sign-off');

-- Who reads its facts.
select is(pg_temp.thanks_read('e5', pg_temp.sp()), 3, 'a Viewer reads them all');
select is(pg_temp.thanks_read('d4', pg_temp.sp()), 3, 'Lina too: a Thanks is for the whole Space');
select is(pg_temp.thanks_read('f6', pg_temp.sp()), 0, 'someone outside the Space reads none');

-- 4. The card -----------------------------------------------------------------------------------------

select is(pg_temp.card('d4', 'b001') -> 'thanks' ->> 'to_kind', 'person', 'the card: to a person');
select is(pg_temp.card('d4', 'b001') -> 'thanks' ->> 'to_profile_id', pg_temp.uid('b2')::text, 'who');
select is(pg_temp.card('d4', 'b001') -> 'thanks' ->> 'to_profile_name', 'Rakesh Nair', 'and their name');
select is(pg_temp.card('d4', 'b001') -> 'thanks' -> 'for',
  jsonb_build_object('id', pg_temp.id('a001'), 'title', 'Formwork check, level 3',
                     'ref', (select ref from public.space_posts where id = pg_temp.id('a001'))),
  'For: the work item, its title and ref');
select is(pg_temp.card('d4', 'b001') ->> 'body', 'Thank you for staying late on the formwork', 'the words');
select is(pg_temp.card('d4', 'b001') -> 'thanks' ->> 'mine', 'false', 'not Lina''s');
select is(pg_temp.card('d4', 'b001') -> 'needs_me', 'null'::jsonb, 'it needs nobody');
select is(pg_temp.card('b2', 'b001') -> 'thanks' ->> 'mine', 'true', 'Rakesh''s: he sees Show on my profile');
select is(pg_temp.card('b2', 'b001') -> 'thanks' ->> 'show_on_profile', 'false', 'not shown yet');
select is(pg_temp.card('d4', 'b002') -> 'thanks' ->> 'to_kind', 'team', 'to a Team');
select is(pg_temp.card('d4', 'b002') -> 'thanks' ->> 'to_team_name', 'Steel fixers', 'the Team''s name');
select is(pg_temp.card('d4', 'b002') -> 'thanks' ->> 'mine', 'false', 'a Team''s Thanks is nobody''s own');
select is(pg_temp.card('d4', 'b003') -> 'thanks' -> 'for', null,
  'For a Team''s item: hidden from someone outside the Team');
select is(pg_temp.card('b2', 'b003') -> 'thanks' -> 'for' ->> 'title', 'Rebar for the core wall',
  'and shown to the Team');
select pg_temp.as_user('b2');
set local role authenticated;
select is((select card -> 'thanks' ->> 'to_profile_name' from public.daybook_card(pg_temp.id('b001'))),
  'Rakesh Nair', 'daybook_card carries it too');
reset role;
select is(pg_temp.card('d4', 'a002') -> 'thanks', null, 'a work item has no thanks facts');

-- 5. Show on my profile -------------------------------------------------------------------------------

select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok(format('select public.set_thanks_on_profile(%L, true)', pg_temp.id('b001')),
  '42501', 'not allowed', 'its author can''t choose');
reset role;
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok(format('select public.set_thanks_on_profile(%L, true)', pg_temp.id('b001')),
  '42501', 'not allowed', 'nor another member');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok(format('select public.set_thanks_on_profile(%L, true)', pg_temp.id('b002')),
  '42501', 'not allowed', 'a Team''s Thanks has no profile choice, even for its people');
select is(pg_temp.on_profile('f6', 'b2'), 0, 'nothing on the profile before he chooses');
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok(format('select public.set_thanks_on_profile(%L, true)', pg_temp.id('b001')),
  'the person thanked shows it');
reset role;
select ok((select show_on_profile and shown_at is not null from public.space_thanks
           where post_id = pg_temp.id('b001')), 'shown, with when');
select is(pg_temp.card('b2', 'b001') -> 'thanks' ->> 'show_on_profile', 'true', 'the card says so');

select is(pg_temp.on_profile('f6', 'b2'), 1, 'his profile shows only the one he chose, to anyone signed in');
select pg_temp.as_user('f6');
set local role authenticated;
select is((select from_name || '|' || words || '|' || project_name
           from public.profile_thanks(pg_temp.uid('b2'))),
  'Tariq Aziz|Thank you for staying late on the formwork|Kuwait tower',
  'who thanked, the words and the project');
select is((select from_id from public.profile_thanks(pg_temp.uid('b2'))), pg_temp.uid('c3'),
  'and who, to open their profile');
reset role;
select is((select proargnames[2:] from pg_proc where oid = 'public.profile_thanks(uuid)'::regprocedure),
  array['post_id', 'from_id', 'from_name', 'words', 'created_at', 'project_name'],
  'nothing else: no Space, no work item, no photos');
select ok(not has_function_privilege('anon', 'public.profile_thanks(uuid)', 'execute'),
  'not for anyone signed out');

insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('f6'), pg_temp.uid('c3'));
select is(pg_temp.on_profile('f6', 'b2'), 0, 'hidden from someone who blocked the thanker');
delete from public.blocks where blocker_id = pg_temp.uid('f6');

select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok(format('select public.set_thanks_on_profile(%L, false)', pg_temp.id('b001')),
  'he takes it off');
reset role;
select is(pg_temp.on_profile('f6', 'b2'), 0, 'and it is gone from the profile');
select ok((select not show_on_profile and shown_at is null from public.space_thanks
           where post_id = pg_temp.id('b001')), 'off, with no time');
select pg_temp.as_user('b2');
set local role authenticated;
select public.set_thanks_on_profile(pg_temp.id('b001'), true);
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select public.cancel_space_post(pg_temp.id('b001'));
reset role;
select is(pg_temp.on_profile('f6', 'b2'), 0, 'a cancelled Thanks leaves the profile');

-- 6. Tags -----------------------------------------------------------------------------------------------

select col_type_is('public', 'work_items', 'tag', 'text', 'a work item has one tag column');
select is((select tag from public.work_items where id = pg_temp.id('a001')), 'safety',
  'create_work_item takes the tag');
select is(pg_temp.card('d4', 'a001') -> 'tag',
  '{"id": "safety", "name": {"en": "Safety", "ar": "سلامة"}, "danger": true}'::jsonb,
  'the card: the tag, its name and danger');
select is(pg_temp.card('d4', 'a002') -> 'tag', null, 'no tag, no tag on the card');
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok(format($q$select public.create_work_item(%L, 'Roof sheets', %L, p_id => %L, p_tag => 'roofing')$q$,
  pg_temp.sp(), pg_temp.uid('b2'), pg_temp.id('a004')), '22023', 'a tag from the list',
  'only a tag from the list');
select throws_ok(format($q$select public.create_work_item(%L, 'Roof sheets', %L, p_id => %L, p_tag => 'safety,quality')$q$,
  pg_temp.sp(), pg_temp.uid('b2'), pg_temp.id('a004')), '22023', 'a tag from the list',
  'one tag at most');
reset role;

-- A tag only Egypt's list has: not in a Kuwait Space; any list will do
-- for a Space with no project.
insert into public.market_work_tags (market_id, id, name, sort)
values ('eg', 'permit', '{"en": "Permit", "ar": "تصريح"}', 6);
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok(format($q$select public.create_work_item(%L, 'Road permit', %L, p_id => %L, p_tag => 'permit')$q$,
  pg_temp.sp(), pg_temp.uid('b2'), pg_temp.id('a004')), '22023', 'a tag from the list',
  'not a tag of another market''s list');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok(format($q$select public.create_work_item(%L, 'Road permit', %L, p_id => %L, p_tag => 'permit')$q$,
  pg_temp.sp3(), pg_temp.uid('b2'), pg_temp.id('a005')), 'with no project, any list''s tag');
reset role;
select is(pg_temp.card('b2', 'a005') -> 'tag' -> 'name' ->> 'en', 'Permit', 'and its name');

-- The picker's list.
select pg_temp.as_user('d4');
set local role authenticated;
select is(array(select id from public.space_work_tags(pg_temp.sp())),
  array['safety', 'quality', 'design', 'material', 'admin'], 'the Space''s market''s list, in order');
select is((select danger from public.space_work_tags(pg_temp.sp()) where id = 'safety'), true,
  'Safety is danger');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select is((select count(*) from public.space_work_tags(pg_temp.sp3()))::integer, 5,
  'with no project: the reader''s home market''s list');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select is((select count(*) from public.space_work_tags(pg_temp.sp()))::integer, 0,
  'nothing for someone outside the Space');
reset role;

-- set_work_item_tag.
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok(format($q$select public.set_work_item_tag(%L, 'quality')$q$, pg_temp.id('a002')),
  'its owner tags it');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select lives_ok(format($q$select public.set_work_item_tag(%L, 'design')$q$, pg_temp.id('a002')),
  'its creator changes the tag');
select throws_ok(format($q$select public.set_work_item_tag(%L, 'roofing')$q$, pg_temp.id('a002')),
  '22023', 'a tag from the list', 'only a tag from the list');
reset role;
select is((select tag from public.work_items where id = pg_temp.id('a002')), 'design', 'one tag: the last');
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok(format($q$select public.set_work_item_tag(%L, null)$q$, pg_temp.id('a002')),
  'a Lead clears it');
reset role;
select is((select tag from public.work_items where id = pg_temp.id('a002')), null, 'no tag');
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok(format($q$select public.set_work_item_tag(%L, 'admin')$q$, pg_temp.id('a002')),
  '42501', 'not allowed', 'Crew who isn''t its creator or owner can''t');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok(format($q$select public.set_work_item_tag(%L, 'admin')$q$, pg_temp.id('a002')),
  '42501', 'not allowed', 'nor a Viewer');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok(format($q$select public.set_work_item_tag(%L, 'admin')$q$, pg_temp.id('a002')),
  '42501', 'not allowed', 'nor someone outside the Space');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok(format($q$select public.set_work_item_tag(%L, 'admin')$q$, pg_temp.id('b002')),
  '42501', 'not allowed', 'only a work item takes a tag');
reset role;

-- 7. A work item with points, end to end (the checklist inside it) -----------------------------------

select is(pg_temp.card('d4', 'a001') -> 'points', '{"total": 2, "ticked": 0}'::jsonb,
  'the work item has its two points');
select pg_temp.as_user('d4');
set local role authenticated;
select lives_ok(format('select public.tick_point(%L, true)',
  (select id from public.checklist_points where post_id = pg_temp.id('a001') and sort = 0)),
  'Crew ticks one');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok(format('select public.tick_point(%L, true)',
  (select id from public.checklist_points where post_id = pg_temp.id('a001') and sort = 1)),
  'the owner ticks the other');
reset role;
select is(pg_temp.card('d4', 'a001') -> 'points', '{"total": 2, "ticked": 2}'::jsonb, 'both ticked');
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok(format($q$select public.sign_done(%L, 'Props and ties checked')$q$, pg_temp.id('a001')),
  'the owner signs it as done');
select throws_ok(format($q$select public.set_work_item_tag(%L, 'quality')$q$, pg_temp.id('a001')),
  '22023', 'only an open work item', 'the tag stays once it is done');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select lives_ok(format('select public.check_item(%L)', pg_temp.id('a001')), 'its creator checks it');
reset role;
select is((select status from public.work_items where id = pg_temp.id('a001')), 'checked', 'Checked');
select is(pg_temp.card('d4', 'a001') -> 'tag' ->> 'id', 'safety', 'and it keeps its tag');

-- 8. Post later of a tagged work item ---------------------------------------------------------------

select is((select count(*) from pg_proc where proname = 'create_work_item'
           and pronamespace = 'public'::regnamespace)::integer, 1, 'one create_work_item');
select isnt(public.scheduled_call_sql('create_work_item',
  jsonb_build_object('p_id', pg_temp.id('a006'), 'p_tag', 'safety')), null,
  'scheduled_call_sql knows its new signature');
select pg_temp.as_user('c3');
set local role authenticated;
select lives_ok(format($q$select public.schedule_post(%L, 'create_work_item',
  jsonb_build_object('p_id', %L, 'p_space', %L, 'p_title', 'Edge protection, level 4',
                     'p_owner', %L, 'p_tag', 'safety'),
  now() + interval '1 hour', 'Edge protection, level 4')$q$,
  pg_temp.id('a006'), pg_temp.id('a006'), pg_temp.sp(), pg_temp.uid('b2')),
  'Crew schedules a tagged work item');
reset role;
select is(public.publish_scheduled(s), true, 'it goes out at its time')
from public.scheduled_posts s where s.id = pg_temp.id('a006');
select is((select tag from public.work_items where id = pg_temp.id('a006')), 'safety', 'with its tag');

-- 9. The functions ----------------------------------------------------------------------------------

select ok((select bool_and(prosecdef and proconfig @> array['search_path=""']) from pg_proc
           where oid in ('public.create_thanks(uuid, uuid, text, uuid, uuid, uuid, jsonb)'::regprocedure,
                         'public.set_thanks_on_profile(uuid, boolean)'::regprocedure,
                         'public.profile_thanks(uuid)'::regprocedure,
                         'public.space_work_tags(uuid)'::regprocedure,
                         'public.set_work_item_tag(uuid, text)'::regprocedure)),
  'security definer, with an empty search_path');
select ok(not has_function_privilege('anon', 'public.create_thanks(uuid, uuid, text, uuid, uuid, uuid, jsonb)', 'execute')
          and not has_function_privilege('anon', 'public.set_work_item_tag(uuid, text)', 'execute')
          and not has_function_privilege('authenticated', 'public.work_tag_json(uuid, text)', 'execute')
          and not has_function_privilege('authenticated', 'public.is_work_tag(uuid, text)', 'execute'),
  'anon calls none; the helpers are not the app''s');

-- delete_team keeps a thanked Team.
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok(format('select public.delete_team(%L)', pg_temp.team()), 'P0001', null,
  'a thanked Team stays in the record');
reset role;

select * from finish();
rollback;
