-- Migration 20261121120000 (review 113). Run with: supabase test db
--
-- Omar (a1) made the Space "Tower 113", a project in Kuwait (weekend Friday
-- and Saturday, from the market pack): its admin, a Lead. Gus (a7) is a
-- Lead in the Team "Steel" with Rakesh (b2) and Lina (d4), both Crew.
-- Tariq (c3) is Crew outside it, alone in the Team "Solo". Vera (e5) is a
-- Viewer. Hana (a8) and Bilal (b9) are Crew; Rakesh blocks Bilal. Eve (f6)
-- is not in the Space: she made "Other site", where Rakesh is Crew too.
-- Gus also made "Daily site", which has a check-in every working day.
-- Rakesh and Gus turned lock-screen text on; nobody else did.

begin;
create extension if not exists pgtap with schema extensions;
select plan(284);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000060' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@r113.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('d4'), ('e5'), ('f6'), ('a7'), ('a8'), ('b9')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('a1', 'Omar', 'Haddad'), ('b2', 'Rakesh', 'Nair'), ('c3', 'Tariq', 'Aziz'),
             ('d4', 'Lina', 'Saad'), ('e5', 'Vera', 'Lane'), ('f6', 'Eve', 'Out'),
             ('a7', 'Gus', 'Lead'), ('a8', 'Hana', 'Hidden'), ('b9', 'Bilal', 'Block')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000060' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000060' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000060' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000060' || p)::uuid;
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
-- D: a Tuesday at least 30 days ahead (a working day in Kuwait).
create function pg_temp.d() returns date language sql as $$
  select x::date from generate_series(current_date + 30, current_date + 37, interval '1 day') x
  where extract(isodow from x) = 2 order by x limit 1;
$$;
-- [p_time] on D + [p_days], in Kuwait.
create function pg_temp.at(p_days integer, p_time text) returns timestamptz language sql as $$
  select ((pg_temp.d() + p_days) + p_time::time) at time zone 'Asia/Kuwait';
$$;
-- [p_post]'s card as [p_id] opens it.
create function pg_temp.card(p_id text, p_post text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  select c.card into v from public.daybook_card(pg_temp.id(p_post)) c;
  reset role;
  return v;
end;
$$;
-- [p_post]'s card as [p_id] reads it in Work (the list).
create function pg_temp.listed_card(p_id text, p_post text) returns jsonb language plpgsql as $$
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
-- [p_id] reacts [p_kind] to [p_post], as the app does.
create function pg_temp.react(p_id text, p_post text, p_kind text) returns text language plpgsql as $$
declare v text;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  v := public.react_to_post(pg_temp.id(p_post), p_kind);
  reset role;
  return v;
end;
$$;
-- Pushes of [p_kind] queued for [p_to] about [p_key] = [p_val].
create function pg_temp.pushes(p_kind text, p_to text, p_key text default null, p_val text default null)
returns integer language sql as $$
  select count(*)::int from public.push_queue
  where kind = p_kind and profile_id = pg_temp.uid(p_to)
    and (p_key is null or data ->> p_key = p_val);
$$;
create function pg_temp.push_data(p_kind text, p_to text, p_key text, p_val text)
returns jsonb language sql as $$
  select data from public.push_queue
  where kind = p_kind and profile_id = pg_temp.uid(p_to) and data ->> p_key = p_val
  order by id desc limit 1;
$$;
-- Who of everyone in the story reads [p_id] in [p_table] through RLS.
create function pg_temp.seers(p_table text, p_id uuid) returns text[] language plpgsql as $$
declare
  v text[] := '{}';
  v_who text;
  v_n integer;
begin
  foreach v_who in array array['a1', 'a7', 'b2', 'b9', 'c3', 'd4', 'e5', 'f6', 'a8'] loop
    perform pg_temp.as_user(v_who);
    set local role authenticated;
    execute format('select count(*) from public.%I where id = $1', p_table) into v_n using p_id;
    reset role;
    if v_n > 0 then
      v := v || v_who;
    end if;
  end loop;
  return v;
end;
$$;
-- Rows of [p_table] [p_id] reads through RLS.
create function pg_temp.reads(p_id text, p_sql text) returns integer language plpgsql as $$
declare v integer;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return v;
end;
$$;

-- Setup ----------------------------------------------------------------------------------------------

insert into public.projects (id, name, type_id, market_id)
values (pg_temp.id('ee01'), 'Kuwait tower 113', (select id from public.project_types limit 1), 'kw');

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Tower 113')::text, true);
reset role;
update public.spaces set project_id = pg_temp.id('ee01') where id = pg_temp.sp();
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1')
from (values ('b2', 'crew'), ('c3', 'crew'), ('d4', 'crew'), ('e5', 'viewer'), ('a7', 'lead'),
             ('a8', 'crew'), ('b9', 'crew')) x(id, pass);
select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'Steel',
  array[pg_temp.uid('b2'), pg_temp.uid('d4'), pg_temp.uid('a7')])::text, true);
select set_config('test.solo', public.create_team(pg_temp.sp(), 'Solo',
  array[pg_temp.uid('c3')])::text, true);
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select set_config('test.space2', public.create_space('Other site')::text, true);
select set_config('test.team2', public.create_team(pg_temp.sp2(), 'Other team', '{}')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp2(), pg_temp.uid('b2'), 'crew', pg_temp.uid('f6'));
select pg_temp.as_user('a7');
set local role authenticated;
select set_config('test.space3', public.create_space('Daily site')::text, true);
reset role;
update public.spaces set project_id = pg_temp.id('ee01') where id = pg_temp.sp3();
insert into public.push_tokens (token, profile_id, platform)
select repeat(x.c, 40), pg_temp.uid(x.id), 'android'
from (values ('a1', 'a'), ('b2', 'b'), ('c3', 'c'), ('d4', 'd'), ('e5', 'e'), ('f6', 'f'),
             ('a7', 'g'), ('a8', 'h'), ('b9', 'i')) x(id, c);
insert into public.push_settings (profile_id, message_text)
values (pg_temp.uid('b2'), true), (pg_temp.uid('a7'), true);
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('b2'), pg_temp.uid('b9'));

-- The tables ----------------------------------------------------------------------------------------

select has_table('public', 'post_reactions', 'post_reactions exists');
select has_table('public', 'need_you_calls', 'need_you_calls exists');
select has_table('public', 'library_folders', 'library_folders exists');
select has_column('public', 'library_files', 'folder_id', 'library_files.folder_id');
select ok((select bool_and(relrowsecurity) from pg_class
           where oid in ('public.post_reactions'::regclass, 'public.need_you_calls'::regclass,
                         'public.library_folders'::regclass, 'public.check_in_nudges'::regclass)),
  'row-level security on all four new tables');
select ok(not has_table_privilege('authenticated', 'public.post_reactions', 'insert')
          and not has_table_privilege('authenticated', 'public.post_reactions', 'update')
          and not has_table_privilege('authenticated', 'public.post_reactions', 'delete')
          and not has_table_privilege('authenticated', 'public.need_you_calls', 'insert')
          and not has_table_privilege('authenticated', 'public.need_you_calls', 'update')
          and not has_table_privilege('authenticated', 'public.need_you_calls', 'delete')
          and not has_table_privilege('authenticated', 'public.library_folders', 'insert')
          and not has_table_privilege('authenticated', 'public.library_folders', 'update')
          and not has_table_privilege('authenticated', 'public.library_folders', 'delete'),
  'nobody writes reactions, calls or folders directly');
select ok(not has_table_privilege('authenticated', 'public.check_in_nudges', 'select')
          and not has_table_privilege('anon', 'public.post_reactions', 'select')
          and not has_table_privilege('anon', 'public.need_you_calls', 'select')
          and not has_table_privilege('anon', 'public.library_folders', 'select'),
  'the nudge log is the server''s; nothing for anon');
select is((select count(*)::int from pg_proc
           where pronamespace = 'public'::regnamespace
             and proname in ('react_to_post', 'post_reactions_json', 'post_has_action', 'post_hold',
                             'check_in_nudge', 'send_need_you', 'answer_need_you',
                             'my_need_you_calls', 'can_read_library_folder', 'library_link_service',
                             'create_library_folder', 'update_library_folder',
                             'delete_library_folder', 'space_library_folders', 'add_library_file',
                             'archive_space_post', 'delete_space_post', 'refuse_archived_item',
                             'refuse_archived_reminder')
             and not (prosecdef and coalesce(proconfig, '{}') @> array['search_path=""'])),
  0, 'every new function is security definer with an empty search_path');
select ok(has_function_privilege('authenticated', 'public.react_to_post(uuid, text)', 'execute')
          and has_function_privilege('authenticated', 'public.send_need_you(uuid, uuid, uuid, text, text)', 'execute')
          and has_function_privilege('authenticated', 'public.answer_need_you(uuid, text)', 'execute')
          and has_function_privilege('authenticated', 'public.my_need_you_calls(uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.create_library_folder(uuid, uuid, text, text, uuid, uuid, text)', 'execute')
          and has_function_privilege('authenticated', 'public.update_library_folder(uuid, text, text, uuid, uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.delete_library_folder(uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.space_library_folders(uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.add_library_file(uuid, uuid, text, text, text, bigint, uuid, text, text, uuid, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.react_to_post(uuid, text)', 'execute')
          and not has_function_privilege('anon', 'public.send_need_you(uuid, uuid, uuid, text, text)', 'execute'),
  'the app''s calls, signed in only');
select ok(not has_function_privilege('authenticated', 'public.check_in_nudge(timestamptz)', 'execute')
          and has_function_privilege('service_role', 'public.check_in_nudge(timestamptz)', 'execute'),
  'the nudge is the cron job''s');

-- 1. Reactions (RX1) ---------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select public.create_space_post(pg_temp.id('a001'), pg_temp.sp(), 'announcement', 'Concrete pour Friday');
select public.post_check_in(pg_temp.id('a002'), pg_temp.sp(), 'Morning roll', null, null,
  29.3759, 47.9774, '07:00', 15);
reset role;
select pg_temp.as_user('a7');
set local role authenticated;
select public.create_space_post(pg_temp.id('a003'), pg_temp.sp(), 'announcement', 'Steel only',
  p_team => pg_temp.team());
reset role;

select is(pg_temp.react('b2', 'a001', 'like'), 'like', 'a member likes a post');
select is(pg_temp.card('a1', 'a001') -> 'reactions',
  jsonb_build_array(jsonb_build_object('kind', 'like', 'people',
    jsonb_build_array(jsonb_build_object('id', pg_temp.uid('b2'), 'name', 'Rakesh Nair')))),
  'the card: the kind with the faces of who reacted');
select is(pg_temp.card('a1', 'a001') -> 'my_reaction', 'null'::jsonb, 'the author has none of his own');
select is(pg_temp.card('b2', 'a001') ->> 'my_reaction', 'like', 'the reader''s own');
select is(pg_temp.listed_card('b2', 'a001') ->> 'my_reaction', 'like', 'in the Work list too');
select is(pg_temp.react('b2', 'a001', 'like'), null, 'the same again takes it back');
select is(pg_temp.card('a1', 'a001') -> 'reactions', '[]'::jsonb, 'none left');
select is(pg_temp.react('b2', 'a001', 'heart'), 'heart', 'a heart');
select is(pg_temp.react('b2', 'a001', 'bravo'), 'bravo', 'another kind replaces it');
select is((select count(*)::int from public.post_reactions
           where post_id = pg_temp.id('a001') and profile_id = pg_temp.uid('b2')),
  1, 'one per person per post');
select is(pg_temp.react('c3', 'a001', 'like'), 'like', 'Tariq likes it');
update public.post_reactions set created_at = created_at - interval '1 minute'
where profile_id = pg_temp.uid('c3');
select is(pg_temp.react('d4', 'a001', 'like'), 'like', 'and Lina');
select is(pg_temp.card('a1', 'a001') -> 'reactions',
  jsonb_build_array(
    jsonb_build_object('kind', 'like', 'people', jsonb_build_array(
      jsonb_build_object('id', pg_temp.uid('d4'), 'name', 'Lina Saad'),
      jsonb_build_object('id', pg_temp.uid('c3'), 'name', 'Tariq Aziz'))),
    jsonb_build_object('kind', 'bravo', 'people', jsonb_build_array(
      jsonb_build_object('id', pg_temp.uid('b2'), 'name', 'Rakesh Nair')))),
  'each kind with its people, newest first; Like, Heart, Bravo in that order');
select ok(not (pg_temp.card('a1', 'a001') ? 'reaction_count')
          and not exists (select 1 from jsonb_array_elements(pg_temp.card('a1', 'a001') -> 'reactions') e
                          where e ? 'count' or e ? 'total'),
  'never a number');
select is(pg_temp.react('e5', 'a001', 'heart'), 'heart', 'a Viewer reacts too');
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.react_to_post(pg_temp.id('a001'), 'like')$$, '42501', null,
  'someone outside the Space can''t');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok($$select public.react_to_post(pg_temp.id('a003'), 'like')$$, '42501', null,
  'nor someone who can''t see the post');
select throws_ok($$select public.react_to_post(pg_temp.id('a001'), 'love')$$, '22023',
  'like, heart or bravo', 'only the three');
select throws_ok($$select public.react_to_post(pg_temp.id('a001'), null)$$, '22023',
  'like, heart or bravo', 'a kind is needed');
select throws_ok($$select public.react_to_post(pg_temp.id('a002'), 'like')$$, '22023',
  'no reactions on a check-in', 'no reactions on a check-in');
reset role;
select is(pg_temp.card('b2', 'a002') -> 'reactions', '[]'::jsonb, 'a check-in card: no reactions');
select is(pg_temp.card('b2', 'a002') -> 'my_reaction', 'null'::jsonb, 'and none of mine');

-- Hidden and blocked people have no name.
select pg_temp.react('b9', 'a001', 'like');
select pg_temp.react('a8', 'a001', 'like');
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('a8');
select is((select p -> 'name' from jsonb_array_elements(pg_temp.card('b2', 'a001') -> 'reactions') e,
                  jsonb_array_elements(e -> 'people') p
           where p ->> 'id' = pg_temp.uid('b9')::text),
  'null'::jsonb, 'someone I blocked has no name');
select is((select p -> 'name' from jsonb_array_elements(pg_temp.card('a1', 'a001') -> 'reactions') e,
                  jsonb_array_elements(e -> 'people') p
           where p ->> 'id' = pg_temp.uid('a8')::text),
  'null'::jsonb, 'a hidden account has no name');
select is((select p ->> 'name' from jsonb_array_elements(pg_temp.card('a1', 'a001') -> 'reactions') e,
                  jsonb_array_elements(e -> 'people') p
           where p ->> 'id' = pg_temp.uid('b9')::text),
  'Bilal Block', 'others still see his name');
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('a8');

-- Who reads the reactions: whoever can see the post.
select pg_temp.react('b2', 'a003', 'heart');
select ok(pg_temp.reads('c3', $$select count(*)::int from public.post_reactions
                               where post_id = pg_temp.id('a001')$$) > 0,
  'a member reads the reactions of a post he sees');
select is(pg_temp.reads('c3', $$select count(*)::int from public.post_reactions
                               where post_id = pg_temp.id('a003')$$), 0,
  'not of a Team''s post he can''t see');
select is(pg_temp.reads('f6', $$select count(*)::int from public.post_reactions$$), 0,
  'someone outside the Space reads none');
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$insert into public.post_reactions (post_id, profile_id, kind)
                   values (pg_temp.id('a001'), pg_temp.uid('b2'), 'like')$$, '42501', null,
  'no reaction is written directly');
reset role;

-- The push: one, quiet, grouped, to the author.
select is(pg_temp.pushes('post_reaction', 'a1', 'post_id', pg_temp.id('a001')::text), 1,
  'many reactions within 10 minutes: one push to the author');
select is(pg_temp.push_data('post_reaction', 'a1', 'post_id', pg_temp.id('a001')::text),
  jsonb_build_object('post_id', pg_temp.id('a001'), 'space_id', pg_temp.sp(), 'kind', 'like'),
  'its ids and the kind; lock-screen text off: no title, no Space');
select is((select actor_id from public.push_queue where kind = 'post_reaction'
           and profile_id = pg_temp.uid('a1') order by id limit 1), pg_temp.uid('b2'),
  'from the first who reacted');
select pg_temp.react('a7', 'a003', 'like');
select is(pg_temp.pushes('post_reaction', 'a7', 'post_id', pg_temp.id('a003')::text), 1,
  'never for my own reaction to my own post (one push: Rakesh''s)');
select is(pg_temp.push_data('post_reaction', 'a7', 'post_id', pg_temp.id('a003')::text),
  jsonb_build_object('post_id', pg_temp.id('a003'), 'space_id', pg_temp.sp(), 'kind', 'heart',
                     'title', 'Steel only', 'space_name', 'Tower 113'),
  'lock-screen text on: the title and the Space');
update public.push_queue set created_at = created_at - interval '11 minutes'
where kind = 'post_reaction';
select pg_temp.react('c3', 'a001', 'like');
select is(pg_temp.pushes('post_reaction', 'a1', 'post_id', pg_temp.id('a001')::text), 1,
  'taking one back sends nothing');
select pg_temp.react('c3', 'a001', 'heart');
select is(pg_temp.pushes('post_reaction', 'a1', 'post_id', pg_temp.id('a001')::text), 2,
  'after 10 minutes, the next reaction sends one more');
select pg_temp.react('d4', 'a001', 'heart');
select is(pg_temp.pushes('post_reaction', 'a1', 'post_id', pg_temp.id('a001')::text), 2,
  'and then none again for 10 minutes');

-- 2. Share into the Space's Chat ----------------------------------------------------------------------

select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok($$select public.share_post_to_thread(pg_temp.id('fa01'), pg_temp.id('a001'),
                   (select t.id from public.threads t where t.space_id = pg_temp.sp() and t.team_id is null))$$,
  'into this Space''s Everyone chat');
select throws_ok($$select public.share_post_to_thread(pg_temp.id('fa02'), pg_temp.id('a001'),
                   (select t.id from public.threads t where t.space_id = pg_temp.sp2() and t.team_id is null))$$,
  '22023', null, 'never into another Space''s chat, even one I''m in');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok($$select public.share_post_to_thread(pg_temp.id('fa03'), pg_temp.id('a001'),
                   (select t.id from public.threads t where t.team_id = pg_temp.team()))$$,
  '42501', null, 'nor into a Team chat I''m not in');
reset role;

-- 3. Hold: Delete or Archive ------------------------------------------------------------------------

select pg_temp.as_user('a7');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Fresh item', pg_temp.uid('b2'), p_id => pg_temp.id('b001'));
select public.create_work_item(pg_temp.sp(), 'Updated item', pg_temp.uid('b2'), p_id => pg_temp.id('b002'));
select public.create_work_item(pg_temp.sp(), 'Checked item', pg_temp.uid('b2'), p_id => pg_temp.id('b003'));
select public.create_space_post(pg_temp.id('b004'), pg_temp.sp(), 'announcement', 'Gate 2 closed');
select public.create_work_item(pg_temp.sp(), 'Signed item', pg_temp.uid('b2'), p_id => pg_temp.id('b005'));
select public.create_work_item(pg_temp.sp(), 'Reminded item', pg_temp.uid('b2'), p_id => pg_temp.id('b006'));
select public.create_work_item(pg_temp.sp(), 'Nobody touched', pg_temp.uid('b2'), p_id => pg_temp.id('b007'));
reset role;
select pg_temp.react('c3', 'b001', 'bravo');
select pg_temp.as_user('b2');
select public.add_comment(pg_temp.id('b002'), 'On it');
select public.sign_done(pg_temp.id('b003'), 'Done.');
select public.sign_done(pg_temp.id('b005'), 'Done.');
select public.add_comment(pg_temp.id('b006'), 'Tomorrow');
select pg_temp.as_user('a7');
select public.check_item(pg_temp.id('b003'));
select public.set_work_reminder(pg_temp.id('b0a6'), pg_temp.id('b006'), array[pg_temp.uid('b2')],
  now() + interval '1 day');
select pg_temp.as_user('d4');
select public.ack(pg_temp.id('b004'), 'got_it');

select is(pg_temp.card('a7', 'b001') ->> 'hold', 'delete', 'my post nobody acted on: Delete');
select is(pg_temp.listed_card('a7', 'b001') ->> 'hold', 'delete', 'in the Work list too');
select is(pg_temp.card('a7', 'b002') ->> 'hold', 'archive', 'an update: Archive');
select is(pg_temp.card('a7', 'b005') ->> 'hold', 'archive', 'a sign-off: Archive');
select is(pg_temp.card('a7', 'b004') ->> 'hold', 'archive', 'a Got it: Archive');
select is(pg_temp.card('a7', 'b003') -> 'hold', 'null'::jsonb, 'a Checked work item: nothing');
select is(pg_temp.card('b2', 'b001') -> 'hold', 'null'::jsonb, 'someone else''s post: nothing');
select is(pg_temp.card('a1', 'a002') ->> 'hold', 'delete', 'a check-in nobody marked: Delete');
insert into public.check_in_marks (post_id, user_id, day, kind, at, on_time, place)
values (pg_temp.id('a002'), pg_temp.uid('b2'), current_date, 'in', now(), true, 'on_site');
select is(pg_temp.card('a1', 'a002') ->> 'hold', 'archive', 'a check-in mark: Archive');
select is(pg_temp.card('a1', 'a001') ->> 'hold', 'delete', 'reactions don''t count');

select pg_temp.as_user('a7');
set local role authenticated;
select throws_ok($$select public.delete_space_post(pg_temp.id('b002'))$$, '22023',
  'someone has acted on it', 'Delete is refused once someone acted');
select throws_ok($$select public.delete_space_post(pg_temp.id('b003'))$$, '22023',
  'someone has acted on it', 'and on a Checked work item');
select lives_ok($$select public.delete_space_post(pg_temp.id('b001'))$$, 'reactions don''t stop Delete');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.delete_space_post(pg_temp.id('a002'))$$, '22023',
  'someone has acted on it', 'nor a check-in someone marked');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.delete_space_post(pg_temp.id('b004'))$$, '42501', null,
  'only the author deletes');
select throws_ok($$select public.archive_space_post(pg_temp.id('b004'))$$, '42501', null,
  'and only the author archives his post');
reset role;

-- Archiving an open work item stops it, and tells its owner once.
select pg_temp.as_user('a7');
set local role authenticated;
select lives_ok($$select public.archive_space_post(pg_temp.id('b002'))$$, 'the author archives his post');
select lives_ok($$select public.archive_space_post(pg_temp.id('b002'))$$, 'again: nothing more');
select lives_ok($$select public.archive_space_post(pg_temp.id('b005'))$$, 'and a signed one');
select lives_ok($$select public.archive_space_post(pg_temp.id('b006'))$$, 'and one with a reminder');
select lives_ok($$select public.archive_space_post(pg_temp.id('b004'))$$, 'and an announcement');
select throws_ok($$select public.archive_space_post(pg_temp.id('b007'))$$, 'P0001', null,
  'not one nobody acted on (that is Delete)');
reset role;
select is((select archived_by from public.space_posts where id = pg_temp.id('b002')), pg_temp.uid('a7'),
  'who archived it is kept');
select is(pg_temp.pushes('work_item_archived', 'b2', 'post_id', pg_temp.id('b002')::text), 1,
  'its owner gets one push');
select is(pg_temp.push_data('work_item_archived', 'b2', 'post_id', pg_temp.id('b002')::text),
  jsonb_build_object('post_id', pg_temp.id('b002'), 'space_id', pg_temp.sp(), 'title', 'Updated item'),
  'its ids, and its title under the lock-screen rule (on for Rakesh)');
select is((select count(*)::int from public.push_queue where kind = 'work_item_archived'
           and data ->> 'post_id' = pg_temp.id('b004')::text), 0, 'an announcement: no push');
select is(pg_temp.card('b2', 'b002') -> 'needs_me', 'null'::jsonb, 'it no longer needs its owner');
select is(pg_temp.card('a7', 'b002') -> 'hold', 'null'::jsonb, 'archived: nothing to hold');
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.sign_done(pg_temp.id('b002'), 'Done anyway')$$, '22023', null,
  'an archived work item can''t be signed');
reset role;
select pg_temp.as_user('a7');
set local role authenticated;
select throws_ok($$select public.check_item(pg_temp.id('b005'))$$, '22023', null,
  'nor checked');
select throws_ok($$select public.set_work_reminder(pg_temp.id('b0b2'), pg_temp.id('b002'),
                   array[pg_temp.uid('b2')], now() + interval '1 day')$$, '22023', null,
  'nor reminded');
reset role;
select is((select count(*)::int from public.work_item_reminders
           where post_id = pg_temp.id('b006') and sent_at is null), 0,
  'its waiting reminders are gone');
select is((select status from public.work_items where id = pg_temp.id('b005')), 'done',
  'it stays as it was, in the record');

-- 4. Check-in nudge ---------------------------------------------------------------------------------

-- Tower 113's check-ins: Omar's once (a002), then Gus's once (c001), the
-- most recent, at 06:40.
select pg_temp.as_user('a7');
set local role authenticated;
select public.post_check_in(pg_temp.id('c001'), pg_temp.sp(), 'Steel roll call', null,
  array[pg_temp.team()], 29.3759, 47.9774, '06:40', 15);
-- Daily site: Gus's every-day check-in runs on D.
select public.post_check_in(pg_temp.id('c002'), pg_temp.sp3(), 'Daily roll', null, null,
  29.3759, 47.9774, '07:00', 15, null, null, true);
reset role;
update public.space_posts set created_at = now() - interval '2 days' where id = pg_temp.id('a002');
update public.space_posts set created_at = now() - interval '1 day' where id = pg_temp.id('c001');

select is(public.check_in_nudge(pg_temp.at(0, '06:09')), 0, 'not before 30 minutes before');
select is(pg_temp.pushes('check_in_nudge', 'a7'), 0, 'nothing yet');
select is(public.check_in_nudge(pg_temp.at(0, '06:10')), 1, '30 minutes before its usual time: one');
select is(pg_temp.pushes('check_in_nudge', 'a7'), 1, 'to the creator of the last check-in');
select is((select data from public.push_queue where kind = 'check_in_nudge' order by id desc limit 1),
  jsonb_build_object('space_id', pg_temp.sp(), 'from_post_id', pg_temp.id('c001'),
                     'space_name', 'Tower 113'),
  'the Space and the check-in to fill from; the Space''s name under the lock-screen rule (on)');
select is(public.check_in_nudge(pg_temp.at(0, '06:20')), 0, 'once per Space per day');
select is((select count(*)::int from public.push_queue where kind = 'check_in_nudge'
           and data ->> 'space_id' = pg_temp.sp3()::text), 0,
  'a Space whose check-in runs today gets none');
select is((select count(*)::int from public.push_queue where kind = 'check_in_nudge'
           and data ->> 'space_id' = pg_temp.sp2()::text), 0,
  'a Space that never used check-in gets none');
select is(public.check_in_nudge(pg_temp.at(3, '06:15')), 0, 'Friday is the weekend: none');
select is(public.check_in_nudge(pg_temp.at(1, '06:15')), 1, 'the next working day: one again');
-- A day a check-in runs: c001 (once) moved to D+2.
update public.check_in_posts set start_day = pg_temp.d() + 2 where post_id = pg_temp.id('c001');
select is(public.check_in_nudge(pg_temp.at(2, '06:15')), 0, 'none on a day a check-in runs');
update public.check_in_posts set start_day = current_date where post_id = pg_temp.id('c001');
update public.space_members set pass = 'crew' where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a7');
select is(public.check_in_nudge(pg_temp.at(6, '06:15')), 0, 'its creator is no longer a Lead: none');
update public.space_members set pass = 'lead' where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a7');
delete from public.push_settings where profile_id = pg_temp.uid('a7');
select is(public.check_in_nudge(pg_temp.at(7, '06:15')), 1, 'a Lead again');
select is((select data from public.push_queue where kind = 'check_in_nudge' order by id desc limit 1),
  jsonb_build_object('space_id', pg_temp.sp(), 'from_post_id', pg_temp.id('c001')),
  'lock-screen text off: no Space name');
insert into public.push_settings (profile_id, message_text) values (pg_temp.uid('a7'), true);

-- 5. Need you now (NN1, NN2) ------------------------------------------------------------------------

select pg_temp.as_user('b2');
set local role authenticated;
select is(public.send_need_you(pg_temp.id('d001'), pg_temp.sp(), pg_temp.uid('c3'),
  'Concrete truck waiting', 'Gate 2'), pg_temp.id('d001'), 'Rakesh calls Tariq');
select is(public.send_need_you(pg_temp.id('d001'), pg_temp.sp(), pg_temp.uid('c3'),
  'Concrete truck waiting', 'Gate 2'), pg_temp.id('d001'), 'the same id again is the same call');
reset role;
select is((select count(*)::int from public.need_you_calls where id = pg_temp.id('d001')), 1, 'one call');
select is(pg_temp.pushes('need_you', 'c3'), 1, 'one push to Tariq');
select is(pg_temp.push_data('need_you', 'c3', 'call_id', pg_temp.id('d001')::text),
  jsonb_build_object('call_id', pg_temp.id('d001'), 'space_id', pg_temp.sp()),
  'lock-screen text off: only the ids, no name, no reason, no place');
select ok((select actor_id is null and message_text is null from public.push_queue
           where kind = 'need_you' and profile_id = pg_temp.uid('c3')),
  'and no one named anywhere in the queue');
select pg_temp.as_user('c3');
set local role authenticated;
select is(public.send_need_you(pg_temp.id('d002'), pg_temp.sp(), pg_temp.uid('b2')),
  pg_temp.id('d002'), 'Tariq calls Rakesh, no reason');
reset role;
select is(pg_temp.push_data('need_you', 'b2', 'call_id', pg_temp.id('d002')::text),
  jsonb_build_object('call_id', pg_temp.id('d002'), 'space_id', pg_temp.sp(), 'from_name', 'Tariq Aziz',
                     'space_name', 'Tower 113'),
  'lock-screen text on: who and the Space (no reason or place given)');
select pg_temp.as_user('a1');
set local role authenticated;
select public.send_need_you(pg_temp.id('d003'), pg_temp.sp(), pg_temp.uid('b2'), 'Crane check', 'Block B');
reset role;
select is(pg_temp.push_data('need_you', 'b2', 'call_id', pg_temp.id('d003')::text),
  jsonb_build_object('call_id', pg_temp.id('d003'), 'space_id', pg_temp.sp(), 'from_name', 'Omar Haddad',
                     'reason', 'Crane check', 'place', 'Block B', 'space_name', 'Tower 113'),
  'and the reason and the place');
select is((select actor_id from public.push_queue where kind = 'need_you'
           and data ->> 'call_id' = pg_temp.id('d003')::text), pg_temp.uid('a1'), 'from Omar');

select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok($$select public.send_need_you(pg_temp.id('d0f1'), pg_temp.sp(), pg_temp.uid('b2'))$$,
  '42501', null, 'a Viewer can''t call');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.send_need_you(pg_temp.id('d0f2'), pg_temp.sp(), pg_temp.uid('e5'))$$,
  '42501', null, 'nor be called');
select throws_ok($$select public.send_need_you(pg_temp.id('d0f3'), pg_temp.sp(), pg_temp.uid('b9'))$$,
  '42501', null, 'not someone I blocked');
select throws_ok($$select public.send_need_you(pg_temp.id('d0f4'), pg_temp.sp(), pg_temp.uid('b2'))$$,
  '22023', null, 'not myself');
select throws_ok($$select public.send_need_you(pg_temp.id('d0f5'), pg_temp.sp2(), pg_temp.uid('c3'))$$,
  '42501', null, 'not through a Space the other isn''t in');
select throws_ok($$select public.send_need_you(pg_temp.id('d0f6'), pg_temp.sp(), pg_temp.uid('d4'),
                   repeat('x', 121))$$, '22023', null, 'a reason of up to 120 characters');
select throws_ok($$select public.send_need_you(pg_temp.id('d0f7'), pg_temp.sp(), pg_temp.uid('d4'),
                   null, repeat('x', 81))$$, '22023', null, 'a place of up to 80 characters');
reset role;
select pg_temp.as_user('b9');
set local role authenticated;
select throws_ok($$select public.send_need_you(pg_temp.id('d0f8'), pg_temp.sp(), pg_temp.uid('b2'))$$,
  '42501', null, 'nor someone who blocked me');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.send_need_you(pg_temp.id('d0f9'), pg_temp.sp(), pg_temp.uid('f6'))$$,
  '42501', null, 'not someone outside the Space');
select throws_ok($$select public.send_need_you(pg_temp.id('d0fa'), pg_temp.sp2(), pg_temp.uid('b2'))$$,
  '42501', null, 'not through a Space I''m not in');
reset role;
-- 3 an hour to the same person.
select pg_temp.as_user('b2');
set local role authenticated;
select public.send_need_you(pg_temp.id('d011'), pg_temp.sp(), pg_temp.uid('d4'));
select public.send_need_you(pg_temp.id('d012'), pg_temp.sp(), pg_temp.uid('d4'));
select lives_ok($$select public.send_need_you(pg_temp.id('d013'), pg_temp.sp(), pg_temp.uid('d4'))$$,
  'a third in the hour');
select throws_ok($$select public.send_need_you(pg_temp.id('d014'), pg_temp.sp(), pg_temp.uid('d4'))$$,
  '22023', 'at most 3 an hour', 'not a fourth');
reset role;
update public.need_you_calls set created_at = now() - interval '61 minutes'
where id in (pg_temp.id('d011'), pg_temp.id('d012'));
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok($$select public.send_need_you(pg_temp.id('d014'), pg_temp.sp(), pg_temp.uid('d4'))$$,
  'an hour later, again');
reset role;

-- The answer.
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.answer_need_you(pg_temp.id('d001'), 'coming')$$, '42501', null,
  'the caller doesn''t answer his own call');
reset role;
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok($$select public.answer_need_you(pg_temp.id('d001'), 'coming')$$, '42501', null,
  'nor anyone else');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok($$select public.answer_need_you(pg_temp.id('d001'), 'maybe')$$, '22023', null,
  'On my way or Can''t now');
select lives_ok($$select public.answer_need_you(pg_temp.id('d001'), 'coming')$$, 'Tariq: On my way');
select throws_ok($$select public.answer_need_you(pg_temp.id('d001'), 'cant')$$, '22023',
  'already answered', 'once');
reset role;
select is((select answer from public.need_you_calls where id = pg_temp.id('d001')), 'coming', 'kept');
select is(pg_temp.push_data('need_you_answer', 'b2', 'call_id', pg_temp.id('d001')::text),
  jsonb_build_object('call_id', pg_temp.id('d001'), 'answer', 'coming', 'space_id', pg_temp.sp(),
                     'name', 'Tariq Aziz'),
  'the caller sees the answer; the name under the lock-screen rule (on for Rakesh)');
select pg_temp.as_user('b2');
set local role authenticated;
select public.answer_need_you(pg_temp.id('d002'), 'cant');
reset role;
select is(pg_temp.push_data('need_you_answer', 'c3', 'call_id', pg_temp.id('d002')::text),
  jsonb_build_object('call_id', pg_temp.id('d002'), 'answer', 'cant', 'space_id', pg_temp.sp()),
  'text off: no name');

-- Who reads the calls.
select is(pg_temp.reads('c3', $$select count(*)::int from public.need_you_calls$$), 2,
  'Tariq reads the call he got and the one he made');
select is(pg_temp.reads('d4', $$select count(*)::int from public.need_you_calls
                               where id = pg_temp.id('d001')$$), 0, 'nobody else reads a call');
select is(pg_temp.reads('f6', $$select count(*)::int from public.need_you_calls$$), 0,
  'someone outside the Space reads none');
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$insert into public.need_you_calls (id, space_id, from_id, to_id)
                   values (pg_temp.id('d0fb'), pg_temp.sp(), pg_temp.uid('b2'), pg_temp.uid('c3'))$$,
  '42501', null, 'no call is written directly');
select throws_ok($$update public.need_you_calls set answer = 'coming' where id = pg_temp.id('d002')$$,
  '42501', null, 'nor answered directly');
reset role;

-- My calls in the last 24 hours.
update public.need_you_calls set created_at = now() - interval '25 hours' where id = pg_temp.id('d011');
select pg_temp.as_user('b2');
set local role authenticated;
select is((select array_agg(c.id order by c.id) from public.my_need_you_calls() c),
  array[pg_temp.id('d001'), pg_temp.id('d002'), pg_temp.id('d003'), pg_temp.id('d012'),
        pg_temp.id('d013'), pg_temp.id('d014')],
  'the calls I made or got in the last 24 hours');
select is((select row(c.from_name, c.to_name, c.reason, c.place, c.answer)::text
           from public.my_need_you_calls(pg_temp.sp()) c where c.id = pg_temp.id('d001')),
  row('Rakesh Nair', 'Tariq Aziz', 'Concrete truck waiting', 'Gate 2', 'coming')::text,
  'with names, the reason, the place and the answer');
select is((select count(*)::int from public.my_need_you_calls(pg_temp.sp2())), 0, 'by Space');
reset role;

-- 6. Library folders and Link folder (LB1, LB2) -----------------------------------------------------

select pg_temp.as_user('a7');
set local role authenticated;
select is(public.create_library_folder(pg_temp.id('f001'), pg_temp.sp(), 'My drafts', 'only_me'),
  pg_temp.id('f001'), 'a folder only I see');
select is(public.create_library_folder(pg_temp.id('f001'), pg_temp.sp(), 'My drafts', 'only_me'),
  pg_temp.id('f001'), 'the same id again is the same folder');
select public.create_library_folder(pg_temp.id('f002'), pg_temp.sp(), 'For Rakesh', 'person',
  pg_temp.uid('b2'));
select public.create_library_folder(pg_temp.id('f003'), pg_temp.sp(), 'Steel drawings', 'team',
  null, pg_temp.team());
select public.create_library_folder(pg_temp.id('f004'), pg_temp.sp(), 'Site photos', 'space');
select public.create_library_folder(pg_temp.id('f005'), pg_temp.sp(), 'Big drawings', 'space',
  p_url => 'https://onedrive.live.com/redir?resid=ABC123');
select public.create_library_folder(pg_temp.id('f006'), pg_temp.sp(), 'SharePoint', 'space',
  p_url => 'https://contoso.sharepoint.com/:f:/s/site/Eabc');
select public.create_library_folder(pg_temp.id('f007'), pg_temp.sp(), 'Drive', 'space',
  p_url => 'https://drive.google.com/drive/folders/1abc');
select public.create_library_folder(pg_temp.id('f008'), pg_temp.sp(), 'Dropbox', 'space',
  p_url => 'https://www.dropbox.com/sh/abc/def');
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f1'), pg_temp.sp(), 'Plain', 'space',
                   p_url => 'http://drive.google.com/drive/folders/1abc')$$, '22023',
  'a OneDrive, Google Drive or Dropbox link', 'https only');
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f1'), pg_temp.sp(), 'Other', 'space',
                   p_url => 'https://example.com/folder')$$, '22023',
  'a OneDrive, Google Drive or Dropbox link', 'only the three services');
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f1'), pg_temp.sp(), 'Trick', 'space',
                   p_url => 'https://drive.google.com.example.com/x')$$, '22023',
  'a OneDrive, Google Drive or Dropbox link', 'not a look-alike host');
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f1'), pg_temp.sp(), 'Trick', 'space',
                   p_url => 'https://drive.google.com@example.com/x')$$, '22023',
  'a OneDrive, Google Drive or Dropbox link', 'nor one hidden behind an @');
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f1'), pg_temp.sp(), '  ', 'space')$$,
  '22023', null, 'a name');
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f1'), pg_temp.sp(), repeat('x', 81), 'space')$$,
  '22023', null, 'of up to 80 characters');
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f1'), pg_temp.sp(), 'Friends', 'friends')$$,
  '22023', null, 'one of the four sharing choices');
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f1'), pg_temp.sp(), 'Eve', 'person',
                   pg_temp.uid('f6'))$$, '22023', null, 'a person in this Space');
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f1'), pg_temp.sp(), 'Theirs', 'team',
                   null, pg_temp.team2())$$, '22023', null, 'a Team of this Space');
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f1'), pg_temp.sp(), 'Nobody', 'person')$$,
  '22023', null, 'a person is needed');
reset role;
select is((select array_agg(service order by id) from public.library_folders
           where id in (pg_temp.id('f005'), pg_temp.id('f006'), pg_temp.id('f007'), pg_temp.id('f008'))),
  array['onedrive', 'onedrive', 'google_drive', 'dropbox'], 'the service found from the link');
select is((select kind from public.library_folders where id = pg_temp.id('f005')), 'link', 'a link folder');
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f2'), pg_temp.sp(), 'Mine', 'space')$$,
  '42501', null, 'a Viewer adds no folder');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f2'), pg_temp.sp(), 'Mine', 'space')$$,
  '42501', null, 'nor someone outside the Space');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok($$select public.create_library_folder(pg_temp.id('f0f2'), pg_temp.sp(), 'Not mine', 'team',
                   null, pg_temp.team())$$, '42501', null, 'nor for a Team I''m not in');
select throws_ok($$insert into public.library_folders (id, space_id, name, kind, share, created_by)
                   values (pg_temp.id('f0f3'), pg_temp.sp(), 'Direct', 'folder', 'space', pg_temp.uid('c3'))$$,
  '42501', null, 'no folder is written directly');
reset role;

-- Who sees each folder.
select is(pg_temp.seers('library_folders', pg_temp.id('f001')), array['a7'], 'only me: its creator');
select is(pg_temp.seers('library_folders', pg_temp.id('f002')), array['a7', 'b2'],
  'a person: the creator and that person');
select is(pg_temp.seers('library_folders', pg_temp.id('f003')), array['a1', 'a7', 'b2', 'd4'],
  'a Team: the creator, its members and the Space admin');
select is(pg_temp.seers('library_folders', pg_temp.id('f004')),
  array['a1', 'a7', 'b2', 'b9', 'c3', 'd4', 'e5', 'a8'], 'the whole Space: every member');

-- Files inherit their folder's sharing.
insert into public.library_files (id, space_id, name, storage_path, mime, uploaded_by, folder_id)
select pg_temp.id(x.f), pg_temp.sp(), x.f || '.pdf',
       pg_temp.sp()::text || '/library/' || pg_temp.id(x.f)::text || '/' || x.f || '.pdf',
       'application/pdf', pg_temp.uid('a7'), case when x.d is not null then pg_temp.id(x.d) end
from (values ('f101', 'f001'), ('f102', 'f002'), ('f103', 'f003'), ('f104', 'f004'),
             ('f105', null)) x(f, d);
select is(pg_temp.seers('library_files', pg_temp.id('f101')), array['a7'], 'a file in an only-me folder');
select is(pg_temp.seers('library_files', pg_temp.id('f102')), array['a7', 'b2'], 'in a person''s folder');
select is(pg_temp.seers('library_files', pg_temp.id('f103')), array['a1', 'a7', 'b2', 'd4'],
  'in a Team''s folder');
select is(pg_temp.seers('library_files', pg_temp.id('f104')),
  array['a1', 'a7', 'b2', 'b9', 'c3', 'd4', 'e5', 'a8'], 'in a whole-Space folder');
select is(pg_temp.seers('library_files', pg_temp.id('f105')),
  array['a1', 'a7', 'b2', 'b9', 'c3', 'd4', 'e5', 'a8'], 'today''s files stay in the Space''s Library');

-- add_library_file into a folder.
insert into storage.objects (bucket_id, name, owner_id, metadata)
select 'space-files', pg_temp.sp()::text || '/library/' || pg_temp.id(x.f)::text || '/plan.pdf',
       pg_temp.uid(x.who)::text, '{"size": 1000, "mimetype": "application/pdf"}'
from (values ('f201', 'a7'), ('f202', 'c3'), ('f203', 'a7')) x(f, who);
select pg_temp.as_user('a7');
set local role authenticated;
select lives_ok($$select public.add_library_file(pg_temp.id('f201'), pg_temp.sp(), 'Plan',
                   pg_temp.sp()::text || '/library/' || pg_temp.id('f201')::text || '/plan.pdf',
                   'application/pdf', 1000, p_folder => pg_temp.id('f001'))$$,
  'a file into my folder');
select throws_ok($$select public.add_library_file(pg_temp.id('f203'), pg_temp.sp(), 'Plan',
                   pg_temp.sp()::text || '/library/' || pg_temp.id('f203')::text || '/plan.pdf',
                   'application/pdf', 1000, p_folder => pg_temp.id('f005'))$$,
  '22023', null, 'never into a link folder');
reset role;
select is((select folder_id from public.library_files where id = pg_temp.id('f201')), pg_temp.id('f001'),
  'it is in the folder');
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok($$select public.add_library_file(pg_temp.id('f202'), pg_temp.sp(), 'Plan',
                   pg_temp.sp()::text || '/library/' || pg_temp.id('f202')::text || '/plan.pdf',
                   'application/pdf', 1000, p_folder => pg_temp.id('f001'))$$,
  '42501', null, 'not into a folder I can''t see');
reset role;

-- The list.
select pg_temp.as_user('b2');
set local role authenticated;
select is((select array_agg(f.id order by f.id) from public.space_library_folders(pg_temp.sp()) f),
  array[pg_temp.id('f002'), pg_temp.id('f003'), pg_temp.id('f004'), pg_temp.id('f005'),
        pg_temp.id('f006'), pg_temp.id('f007'), pg_temp.id('f008')],
  'the folders I can see');
select is((select row(f.name, f.kind, f.share, f.share_person_name, f.share_team_name, f.file_count, f.mine)::text
           from public.space_library_folders(pg_temp.sp()) f where f.id = pg_temp.id('f002')),
  row('For Rakesh', 'folder', 'person', 'Rakesh Nair', null::text, 1, false)::text,
  'a person''s folder, with its name and how many files');
select is((select row(f.share, f.share_team_name, f.file_count)::text
           from public.space_library_folders(pg_temp.sp()) f where f.id = pg_temp.id('f003')),
  row('team', 'Steel', 1)::text, 'a Team''s folder');
select is((select row(f.kind, f.url, f.service)::text
           from public.space_library_folders(pg_temp.sp()) f where f.id = pg_temp.id('f005')),
  row('link', 'https://onedrive.live.com/redir?resid=ABC123', 'onedrive')::text,
  'a link folder, with its link and service');
reset role;
select pg_temp.as_user('a7');
set local role authenticated;
select is((select f.mine from public.space_library_folders(pg_temp.sp()) f where f.id = pg_temp.id('f002')),
  true, 'mine');
select is((select f.file_count from public.space_library_folders(pg_temp.sp()) f where f.id = pg_temp.id('f001')),
  2, 'two files in my folder');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select is((select count(*)::int from public.space_library_folders(pg_temp.sp())), 0,
  'someone outside the Space sees none');
reset role;

-- Change and delete.
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.update_library_folder(pg_temp.id('f002'), 'Mine now', 'space')$$,
  '42501', null, 'only its creator or the Space admin changes it');
select throws_ok($$select public.delete_library_folder(pg_temp.id('f008'))$$,
  '42501', null, 'or deletes it');
reset role;
select pg_temp.as_user('a7');
set local role authenticated;
select lives_ok($$select public.update_library_folder(pg_temp.id('f002'), 'For everyone', 'space')$$,
  'the creator shares it with the whole Space');
reset role;
select ok('c3' = any (pg_temp.seers('library_files', pg_temp.id('f102'))), 'its file follows');
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.update_library_folder(pg_temp.id('f003'), 'Steel drawings rev', 'team',
                   null, pg_temp.team())$$, 'the Space admin renames it');
select throws_ok($$select public.update_library_folder(pg_temp.id('f003'), 'Steel', 'team',
                   null, pg_temp.team2())$$, '22023', null, 'the same checks');
reset role;
select pg_temp.as_user('a7');
set local role authenticated;
select throws_ok($$select public.delete_library_folder(pg_temp.id('f004'))$$, '22023',
  'empty it first', 'a folder with files: empty it first');
select lives_ok($$select public.delete_library_folder(pg_temp.id('f008'))$$, 'an empty one goes');
reset role;
select is((select count(*)::int from public.library_folders where id = pg_temp.id('f008')), 0, 'gone');

-- When a folder's creator leaves or is removed (the lead, 2 Nov): "only me"
-- folders go with their files, never opened to the admin; a person's
-- folder passes to the Space admin.
select pg_temp.as_user('d4');
set local role authenticated;
select public.create_library_folder(pg_temp.id('f009'), pg_temp.sp(), 'Lina private', 'only_me');
select public.create_library_folder(pg_temp.id('f00a'), pg_temp.sp(), 'For Rakesh from Lina', 'person',
  pg_temp.uid('b2'));
reset role;
select pg_temp.as_user('b9');
set local role authenticated;
select public.create_library_folder(pg_temp.id('f00b'), pg_temp.sp(), 'Bilal private', 'only_me');
reset role;
insert into storage.objects (bucket_id, name, owner_id, metadata, created_at)
select 'space-files', pg_temp.sp()::text || '/library/' || pg_temp.id(x.f)::text || '/x.pdf',
       pg_temp.uid(x.who)::text, '{"size": 1000, "mimetype": "application/pdf"}', now() - interval '8 days'
from (values ('f106', 'd4'), ('f107', 'd4'), ('f108', 'b9')) x(f, who);
insert into public.library_files (id, space_id, name, storage_path, mime, uploaded_by, folder_id)
select pg_temp.id(x.f), pg_temp.sp(), 'x.pdf',
       pg_temp.sp()::text || '/library/' || pg_temp.id(x.f)::text || '/x.pdf',
       'application/pdf', pg_temp.uid(x.who), pg_temp.id(x.d)
from (values ('f106', 'd4', 'f009'), ('f107', 'd4', 'f00a'), ('f108', 'b9', 'f00b')) x(f, who, d);
select is(pg_temp.seers('library_folders', pg_temp.id('f009')), array['d4'],
  'the admin never reads an only-me folder');
select is(pg_temp.seers('library_files', pg_temp.id('f106')), array['d4'], 'nor its file');

select pg_temp.as_user('d4');
set local role authenticated;
select public.leave_space(pg_temp.sp());
reset role;
select is((select count(*)::int from public.library_folders where id = pg_temp.id('f009')), 0,
  'its creator leaves: the only-me folder is deleted');
select is((select count(*)::int from public.library_files where id = pg_temp.id('f106')), 0,
  'with its files');
select ok(not public.is_referenced_file(pg_temp.sp()::text || '/library/' || pg_temp.id('f106')::text || '/x.pdf'),
  'its stored file is referenced by nothing now');
select ok(exists (select 1 from public.claim_orphan_files(interval '1 day') c
                  where c.name = pg_temp.sp()::text || '/library/' || pg_temp.id('f106')::text || '/x.pdf'),
  'so the cleanup job claims it for deletion from storage');
select is(pg_temp.seers('library_folders', pg_temp.id('f00a')), array['a1', 'b2'],
  'a person''s folder passes to the Space admin (and stays with that person)');
select is(pg_temp.seers('library_files', pg_temp.id('f107')), array['a1', 'b2'], 'with its file');

select pg_temp.as_user('a1');
set local role authenticated;
select public.remove_member(pg_temp.sp(), pg_temp.uid('b9'));
reset role;
select is((select count(*)::int from public.library_folders where id = pg_temp.id('f00b')), 0,
  'removed from the Space: the only-me folder is deleted');
select is((select count(*)::int from public.library_files where id = pg_temp.id('f108')), 0,
  'with its files');
select is((select count(*)::int from public.library_folders where id = pg_temp.id('f001')), 1,
  'others'' only-me folders stay');

-- The nightly space-files sweep (the lead, 2 Nov) -----------------------------------------------------

create function pg_temp.path(p text) returns text language sql as $$
  select pg_temp.sp()::text || '/library/' || pg_temp.id(p)::text || '/x.jpg';
$$;
-- A stored object of [p_who], [p_age] old.
create function pg_temp.obj(p text, p_who text, p_age interval) returns void language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata, created_at)
  values ('space-files', pg_temp.path(p), pg_temp.uid(p_who)::text,
          '{"size": 1000, "mimetype": "image/jpeg"}', now() - p_age);
$$;
create function pg_temp.orphan(p text) returns boolean language sql as $$
  select exists (select 1 from public.orphan_space_files() o where o.name = pg_temp.path(p));
$$;
-- [p_id] reads the stored object [p] through the bucket's read policy.
create function pg_temp.opens(p_id text, p text) returns boolean language plpgsql as $$
declare v integer;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  select count(*) into v from storage.objects
  where bucket_id = 'space-files' and name = pg_temp.path(p);
  reset role;
  return v > 0;
end;
$$;

-- 1. One check per reference: the old file is an orphan until a row uses it.
select pg_temp.obj(x.f, 'a1', interval '8 days')
from (values ('f300'), ('f301'), ('f302'), ('f303'), ('f304'), ('f305'), ('f306'), ('f307'),
             ('f308'), ('f309'), ('f30a'), ('f30b'), ('f30c')) x(f);
select ok(pg_temp.orphan('f300'), 'a file nothing uses is an orphan');
insert into public.library_files (id, space_id, name, storage_path, mime, uploaded_by)
values (pg_temp.id('f301'), pg_temp.sp(), 'x.jpg', pg_temp.path('f301'), 'image/jpeg', pg_temp.uid('a1'));
select ok(not pg_temp.orphan('f301'), 'a Library file protects it');
insert into public.post_files (post_id, storage_path, mime, sort, added_by)
values (pg_temp.id('a001'), pg_temp.path('f302'), 'image/jpeg', 50, pg_temp.uid('a1')),
       (pg_temp.id('a001'), pg_temp.path('f303'), 'audio/mp4', 51, pg_temp.uid('a1'));
select ok(not pg_temp.orphan('f302'), 'a post photo');
select ok(not pg_temp.orphan('f303'), 'a post voice note');
insert into public.message_attachments (message_id, storage_path, mime, duration_ms)
values (pg_temp.id('fa01'), pg_temp.path('f304'), 'image/jpeg', null),
       (pg_temp.id('fa01'), pg_temp.path('f305'), 'audio/mp4', 4000);
select ok(not pg_temp.orphan('f304'), 'a message attachment');
select ok(not pg_temp.orphan('f305'), 'a chat voice note');
insert into public.work_item_evidence (event_id, work_item_id, storage_path, kind)
select e.id, e.work_item_id, pg_temp.path('f306'), 'photo'
from public.work_item_events e where e.work_item_id = pg_temp.id('b003') limit 1;
select ok(not pg_temp.orphan('f306'), 'work item evidence');
insert into public.notes (id, owner_id, kind) values (pg_temp.id('fe01'), pg_temp.uid('a1'), 'text');
insert into public.note_files (note_id, storage_path, kind, mime)
values (pg_temp.id('fe01'), pg_temp.path('f307'), 'photo', 'image/jpeg');
select ok(not pg_temp.orphan('f307'), 'a notebook file');
insert into public.check_in_reports (post_id, day, space_id, recipient_id, file_name, storage_path)
values (pg_temp.id('a002'), current_date, pg_temp.sp(), pg_temp.uid('a1'), 'r.xlsx', pg_temp.path('f308'));
select ok(not pg_temp.orphan('f308'), 'a check-in report');
-- Post later: a waiting (or failed, which can be tried again) post holds its files.
insert into public.scheduled_posts (id, author_id, fn, params, title, publish_at)
values (pg_temp.id('fe02'), pg_temp.uid('a1'), 'create_space_post',
        jsonb_build_object('p_id', pg_temp.id('fe02'),
                           'p_files', jsonb_build_array(jsonb_build_object('path', pg_temp.path('f309')))),
        'Later', now() + interval '6 months'),
       (pg_temp.id('fe03'), pg_temp.uid('a1'), 'create_work_item',
        jsonb_build_object('p_id', pg_temp.id('fe03'),
                           'p_evidence', jsonb_build_array(jsonb_build_object('path', pg_temp.path('f30a')))),
        'Later', now() + interval '6 months');
select ok(not pg_temp.orphan('f309'), 'a waiting Post later protects its files');
select ok(not pg_temp.orphan('f30a'), 'in its evidence too');
update public.scheduled_posts set state = 'failed', error = 'other' where id = pg_temp.id('fe02');
select ok(not pg_temp.orphan('f309'), 'a failed one can be tried again: still protected');
update public.scheduled_posts set state = 'posted', error = null, posted_at = now()
where id = pg_temp.id('fe02');
select ok(pg_temp.orphan('f309'), 'once posted it no longer protects');
update public.scheduled_posts set state = 'cancelled' where id = pg_temp.id('fe03');
select ok(pg_temp.orphan('f30a'), 'nor once cancelled');

-- 2. Seven days, at the edge, whatever the job asks for.
select pg_temp.obj('f30d', 'a1', interval '7 days' - interval '1 minute');
select pg_temp.obj('f30e', 'a1', interval '7 days' + interval '1 minute');
select ok(not exists (select 1 from public.claim_orphan_files(interval '1 day') c
                      where c.name = pg_temp.path('f30d')),
  'a minute under 7 days stays, even asked for 1 day');
select ok(exists (select 1 from public.claim_orphan_files(interval '1 day') c
                  where c.name = pg_temp.path('f30e')), 'a minute over 7 days goes');

-- 3 and 4. A private folder: Tariq's, with a plain file, one a chat
-- still uses, and one a post carries.
select pg_temp.as_user('c3');
set local role authenticated;
select public.create_library_folder(pg_temp.id('f00c'), pg_temp.sp(), 'Tariq private', 'only_me');
reset role;
select pg_temp.obj(x.f, 'c3', interval '0') from (values ('f109'), ('f10a'), ('f10b')) x(f);
insert into public.library_files (id, space_id, name, storage_path, mime, uploaded_by, folder_id)
select pg_temp.id(x.f), pg_temp.sp(), 'x.jpg', pg_temp.path(x.f), 'image/jpeg', pg_temp.uid('c3'),
       pg_temp.id('f00c')
from (values ('f109'), ('f10a'), ('f10b')) x(f);
insert into public.message_attachments (message_id, storage_path, mime)
values (pg_temp.id('fa01'), pg_temp.path('f10a'), 'image/jpeg');
update public.space_posts set kind = 'file', library_file_id = pg_temp.id('f10b') where id = pg_temp.id('a003');
insert into public.post_files (post_id, library_file_id, sort, added_by)
values (pg_temp.id('a003'), pg_temp.id('f10b'), 52, pg_temp.uid('c3'));
select ok(pg_temp.opens('c3', 'f109'), 'the uploader opens his private file while in the Space');
select pg_temp.as_user('c3');
set local role authenticated;
select public.leave_space(pg_temp.sp());
reset role;
select ok(not pg_temp.opens('c3', 'f109'), 'after leaving he can''t open it by its path');
select ok(not pg_temp.opens('c3', 'f10b'), 'nor the one a post carried');
select ok(not pg_temp.opens('a1', 'f109'), 'nor can the admin');
-- An orphan upload of someone who left, which never was in a folder.
select pg_temp.obj('f10e', 'c3', interval '0');
select ok(not pg_temp.opens('c3', 'f10e'), 'nor any orphan of his, once he has left');
select is((select array_agg(storage_path order by storage_path) from public.private_file_purges),
  (select array_agg(p order by p) from unnest(array[replace(pg_temp.path('f106'), '.jpg', '.pdf'), replace(pg_temp.path('f108'), '.jpg', '.pdf'), pg_temp.path('f109'),
                                                    pg_temp.path('f10a'), pg_temp.path('f10b')]) p),
  'the folder''s paths wait in the queue at once');
select ok((select deleted_at is not null and private_gone_at is not null and folder_id is null
           from public.library_files where id = pg_temp.id('f10b')),
  'a file a post carries: its row stays, gone');
select ok(not public.is_referenced_file(pg_temp.path('f10b')), 'and it references its object no more');
select is((select count(*)::int from public.post_files where library_file_id = pg_temp.id('f10b')), 0,
  'the post''s link to it goes');
select ok(public.is_referenced_file(pg_temp.path('f10a')), 'a chat still uses the other');

select ok(not has_table_privilege('authenticated', 'public.private_file_purges', 'select')
          and not has_table_privilege('authenticated', 'public.private_file_purges', 'insert')
          and (select relrowsecurity from pg_class where oid = 'public.private_file_purges'::regclass),
  'the queue is the service role''s, with row-level security');
select ok(not has_function_privilege('authenticated', 'public.claim_private_file_purges(integer)', 'execute')
          and has_function_privilege('service_role', 'public.claim_private_file_purges(integer)', 'execute'),
  'and so is its claim');

set local role service_role;
select is((select array_agg(c.name order by c.name) from public.claim_private_file_purges() c),
  (select array_agg(p order by p) from unnest(array[replace(pg_temp.path('f106'), '.jpg', '.pdf'), replace(pg_temp.path('f108'), '.jpg', '.pdf'),
                                                    pg_temp.path('f109'), pg_temp.path('f10b')]) p),
  'the job gets them with no grace period; the one still referenced is never given');
reset role;
select is((select count(*)::int from public.private_file_purges where storage_path = pg_temp.path('f10a')), 0,
  'a referenced path leaves the queue (the sweep has it, if it is ever free)');
select is((select count(*)::int from public.file_cleanup_claims where storage_path = pg_temp.path('f10a')), 0,
  'and is never claimed');
select public.forget_cleanup_claims();
select is((select count(*)::int from public.private_file_purges where storage_path = pg_temp.path('f109')), 1,
  'a delete that failed stays in the queue');
select ok(exists (select 1 from public.claim_private_file_purges() c where c.name = pg_temp.path('f109')),
  'and comes again next run');
set local storage.allow_delete_query = 'true';
delete from storage.objects where name in (pg_temp.path('f109'), pg_temp.path('f10b'));
select public.forget_cleanup_claims();
select is((select count(*)::int from public.private_file_purges
           where storage_path in (pg_temp.path('f109'), pg_temp.path('f10b'))), 0,
  'once the object is gone, so is its line');

-- 5. The delete paths: the member's row goes.
select pg_temp.as_user('a8');
set local role authenticated;
select public.create_library_folder(pg_temp.id('f00d'), pg_temp.sp(), 'Hana private', 'only_me');
reset role;
select pg_temp.obj('f10c', 'a8', interval '0');
insert into public.library_files (id, space_id, name, storage_path, mime, uploaded_by, folder_id)
values (pg_temp.id('f10c'), pg_temp.sp(), 'x.jpg', pg_temp.path('f10c'), 'image/jpeg', pg_temp.uid('a8'),
        pg_temp.id('f00d'));
delete from public.space_members where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a8');
select is((select count(*)::int from public.library_folders where id = pg_temp.id('f00d')), 0,
  'the member''s row deleted: the only-me folder goes');
select is((select count(*)::int from public.private_file_purges where storage_path = pg_temp.path('f10c')), 1,
  'and its path waits in the queue');

-- 5. Account purge: Eve's private file, attached to her post.
select pg_temp.as_user('f6');
set local role authenticated;
select public.create_library_folder(pg_temp.id('f00e'), pg_temp.sp2(), 'Eve private', 'only_me');
select public.create_space_post(pg_temp.id('a004'), pg_temp.sp2(), 'announcement', 'Eve''s post');
reset role;
select pg_temp.obj('f10d', 'f6', interval '0');
insert into public.library_files (id, space_id, name, storage_path, mime, uploaded_by, folder_id)
values (pg_temp.id('f10d'), pg_temp.sp2(), 'x.jpg', pg_temp.path('f10d'), 'image/jpeg', pg_temp.uid('f6'),
        pg_temp.id('f00e'));
update public.space_posts set kind = 'file', library_file_id = pg_temp.id('f10d') where id = pg_temp.id('a004');
insert into public.post_files (post_id, library_file_id, sort, added_by)
values (pg_temp.id('a004'), pg_temp.id('f10d'), 0, pg_temp.uid('f6'));
update public.profiles set deletion_scheduled_at = now() - interval '31 days' where id = pg_temp.uid('f6');
select ok(public.purge_account(pg_temp.uid('f6')), 'the account is purged');
select is((select count(*)::int from public.library_folders where id = pg_temp.id('f00e')), 0,
  'its only-me folder goes');
select ok((select private_gone_at is not null from public.library_files where id = pg_temp.id('f10d')),
  'the row its post needs stays, gone');
select ok(exists (select 1 from public.claim_private_file_purges() c where c.name = pg_temp.path('f10d')),
  'and its object is claimed, so it actually goes');

-- A failed Post later nobody retries or cancels (the lead, 2 Nov) -------------------------------------

create function pg_temp.sched(p text, p_who text, p_file text) returns void language sql as $$
  insert into public.scheduled_posts (id, author_id, fn, params, title, publish_at, state, error)
  values (pg_temp.id(p), pg_temp.uid(p_who), 'create_space_post',
          jsonb_build_object('p_id', pg_temp.id(p),
                             'p_files', jsonb_build_array(jsonb_build_object('path', pg_temp.path(p_file)))),
          'Pour notice', now() - interval '40 days', 'failed', 'other');
$$;
create function pg_temp.sched_pushes(p text) returns integer language sql as $$
  select count(*)::int from public.push_queue
  where kind = 'scheduled_expiring' and data ->> 'scheduled_id' = pg_temp.id(p)::text;
$$;
create function pg_temp.sched_state(p text) returns text language sql as $$
  select state from public.scheduled_posts where id = pg_temp.id(p);
$$;

select ok(not has_function_privilege('authenticated', 'public.expire_failed_posts(timestamptz)', 'execute')
          and has_function_privilege('service_role', 'public.expire_failed_posts(timestamptz)', 'execute'),
  'the expiry is the cron job''s');
select pg_temp.obj('f401', 'a1', interval '8 days');
select pg_temp.sched('fe10', 'a1', 'f401');
select ok((select failed_at is not null from public.scheduled_posts where id = pg_temp.id('fe10')) is false,
  'inserted failed by hand: the state never changed');
update public.scheduled_posts set state = 'failed' where id = pg_temp.id('fe10');
select ok((select failed_at is not null from public.scheduled_posts where id = pg_temp.id('fe10')),
  'failing starts the 30 days');

update public.scheduled_posts set failed_at = now() - interval '29 days' + interval '1 minute'
where id = pg_temp.id('fe10');
select public.expire_failed_posts();
select is(pg_temp.sched_pushes('fe10'), 0, 'no push before the day before');
update public.scheduled_posts set failed_at = now() - interval '29 days' where id = pg_temp.id('fe10');
select public.expire_failed_posts();
select is(pg_temp.sched_pushes('fe10'), 1, 'one push the day before');
select public.expire_failed_posts();
select is(pg_temp.sched_pushes('fe10'), 1, 'once');
select is((select data from public.push_queue where kind = 'scheduled_expiring'
           and data ->> 'scheduled_id' = pg_temp.id('fe10')::text),
  jsonb_build_object('scheduled_id', pg_temp.id('fe10')), 'lock-screen text off: no title');
select is(pg_temp.sched_state('fe10'), 'failed', 'still failed after the push');
select ok(not pg_temp.orphan('f401'), 'and its files are still held');
-- Not before day 30.
update public.scheduled_posts set failed_at = now() - interval '30 days' + interval '1 minute',
                                  expiry_warned_at = now() - interval '2 days'
where id = pg_temp.id('fe10');
select public.expire_failed_posts();
select is(pg_temp.sched_state('fe10'), 'failed', 'a minute before day 30 it stays');
-- Never cancelled without a full day's warning, even if the job was down.
update public.scheduled_posts set failed_at = now() - interval '40 days', expiry_warned_at = now()
where id = pg_temp.id('fe10');
select public.expire_failed_posts();
select is(pg_temp.sched_state('fe10'), 'failed', 'warned just now: a day''s notice first');
update public.scheduled_posts set failed_at = now() - interval '30 days',
                                  expiry_warned_at = now() - interval '1 day'
where id = pg_temp.id('fe10');
select public.expire_failed_posts();
select is(pg_temp.sched_state('fe10'), 'cancelled', 'day 30: cancelled');
select is(pg_temp.sched_pushes('fe10'), 1, 'no second push');
select ok(pg_temp.orphan('f401'), 'and its files are freed');

-- Lock-screen text on (Rakesh).
select pg_temp.obj('f402', 'b2', interval '8 days');
select pg_temp.sched('fe11', 'b2', 'f402');
update public.scheduled_posts set state = 'failed' where id = pg_temp.id('fe11');
update public.scheduled_posts set failed_at = now() - interval '29 days' where id = pg_temp.id('fe11');
select public.expire_failed_posts();
select is((select data ->> 'title' from public.push_queue where kind = 'scheduled_expiring'
           and data ->> 'scheduled_id' = pg_temp.id('fe11')::text), 'Pour notice',
  'lock-screen text on: its title');

-- A retry that fails again starts the 30 days over.
update public.scheduled_posts set state = 'failed', error = 'other' where id = pg_temp.id('fe11');
select ok((select failed_at > now() - interval '1 minute' and expiry_warned_at is null
           from public.scheduled_posts where id = pg_temp.id('fe11')), 'a failed retry starts over');
-- A cancel stops both.
select pg_temp.obj('f403', 'a1', interval '8 days');
select pg_temp.sched('fe12', 'a1', 'f403');
update public.scheduled_posts set state = 'failed' where id = pg_temp.id('fe12');
update public.scheduled_posts set state = 'cancelled' where id = pg_temp.id('fe12');
select public.expire_failed_posts();
select is(pg_temp.sched_pushes('fe12'), 0, 'cancelled by hand: no push');
-- A retry that posts stops both.
select pg_temp.obj('f404', 'a1', interval '8 days');
select pg_temp.sched('fe13', 'a1', 'f404');
update public.scheduled_posts set state = 'failed' where id = pg_temp.id('fe13');
update public.scheduled_posts set failed_at = now() - interval '31 days',
                                  expiry_warned_at = now() - interval '2 days'
where id = pg_temp.id('fe13');
update public.scheduled_posts set state = 'posted', error = null, posted_at = now()
where id = pg_temp.id('fe13');
select public.expire_failed_posts();
select is(pg_temp.sched_state('fe13'), 'posted', 'a retry that posted stays posted');

-- Soft-deleted Library files go 30 days after deletion (the lead, 2 Nov) ------------------------------

create function pg_temp.file_row(p text, p_deleted interval, p_supersedes text default null)
returns void language sql as $$
  insert into public.library_files (id, space_id, name, storage_path, mime, uploaded_by, deleted_at, supersedes_id)
  values (pg_temp.id(p), pg_temp.sp(), 'x.jpg', pg_temp.path(p), 'image/jpeg', pg_temp.uid('a1'),
          now() - p_deleted, case when p_supersedes is not null then pg_temp.id(p_supersedes) end);
$$;
create function pg_temp.queued(p text) returns integer language sql as $$
  select count(*)::int from public.private_file_purges where storage_path = pg_temp.path(p);
$$;
create function pg_temp.file_rows(p text) returns integer language sql as $$
  select count(*)::int from public.library_files where id = pg_temp.id(p);
$$;

select ok(not has_function_privilege('authenticated', 'public.purge_deleted_library_files(timestamptz, integer)', 'execute')
          and has_function_privilege('service_role', 'public.purge_deleted_library_files(timestamptz, integer)', 'execute'),
  'the Library purge is the job''s');
select pg_temp.obj(x.f, 'a1', interval '0')
from (values ('f411'), ('f412'), ('f413'), ('f414'), ('f415'), ('f416'), ('f417')) x(f);
select pg_temp.file_row('f411', interval '30 days' - interval '1 minute');
select pg_temp.file_row('f412', interval '31 days');
-- f413, in use, with a deleted newer version f414.
select pg_temp.file_row('f413', interval '0');
update public.library_files set deleted_at = null where id = pg_temp.id('f413');
select pg_temp.file_row('f414', interval '31 days', 'f413');
-- f415 deleted long ago, but a superseded revision of the live f416.
select pg_temp.file_row('f415', interval '31 days');
select pg_temp.file_row('f416', interval '0', 'f415');
update public.library_files set deleted_at = null where id = pg_temp.id('f416');
-- f417 on a post.
select pg_temp.file_row('f417', interval '31 days');
select pg_temp.as_user('a1');
set local role authenticated;
select public.create_space_post(pg_temp.id('a005'), pg_temp.sp(), 'announcement', 'A file post');
reset role;
update public.space_posts set kind = 'file', library_file_id = pg_temp.id('f417') where id = pg_temp.id('a005');

select is(public.purge_deleted_library_files(), 3, 'three purged');
select is(pg_temp.file_rows('f411'), 1, 'not before day 30');
select is(pg_temp.queued('f411'), 0, 'nor its object');
select is(pg_temp.file_rows('f412'), 0, 'day 30: the row goes');
select is(pg_temp.queued('f412'), 1, 'and its object waits for the job, with no grace period');
select is(pg_temp.file_rows('f414'), 0, 'a deleted newer version goes');
select is((select deleted_at from public.library_files where id = pg_temp.id('f413')), null,
  'the revision it superseded is untouched');
select ok(public.is_referenced_file(pg_temp.path('f413')), 'and keeps its object');
select is(pg_temp.file_rows('f415'), 1, 'a superseded revision stays as it is, deleted or not');
select is(pg_temp.queued('f415'), 0, 'with its object');
select ok((select private_gone_at is not null from public.library_files where id = pg_temp.id('f417')),
  'a row a post points at stays, gone');
select is(pg_temp.queued('f417'), 1, 'but its object goes');
select is((select count(*)::int from public.space_posts where id = pg_temp.id('a005') and deleted_at is null), 1,
  'the post stays');
set local role service_role;
select is((select array_agg(c.name order by c.name) from public.claim_private_file_purges() c
           where c.name in (pg_temp.path('f412'), pg_temp.path('f417'))),
  (select array_agg(p order by p) from unnest(array[pg_temp.path('f412'), pg_temp.path('f417')]) p),
  'the job gets both objects');
reset role;
select is(public.purge_deleted_library_files(), 0, 'a second run has nothing to do');

-- Post a check-in at the same place as an earlier one (the lead, 2 Nov) -------------------------------

update public.check_in_posts set site_lat = 29.5, site_lng = 48.1 where post_id = pg_temp.id('c001');
select pg_temp.as_user('a1');
set local role authenticated;
select is(public.post_check_in(pg_temp.id('c010'), pg_temp.sp(), 'Same place', null, null, null, null,
  '07:00', 15, p_same_place_as => pg_temp.id('c001')), pg_temp.id('c010'),
  'the Space admin posts one at the place of Gus''s check-in, with no point of her own');
reset role;
select is((select array[n.site_lat, n.site_lng] from public.check_in_posts n
           where n.post_id = pg_temp.id('c010')), array[29.5, 48.1]::double precision[],
  'the server copied the site');
select pg_temp.as_user('a7');
set local role authenticated;
select is(public.post_check_in(pg_temp.id('c011'), pg_temp.sp(), 'Mine again', null, null, null, null,
  '07:00', 15, p_same_place_as => pg_temp.id('c001')), pg_temp.id('c011'), 'its creator too');
select throws_ok($$select public.post_check_in(pg_temp.id('c0f1'), pg_temp.sp(), 'Other Space', null, null,
                   null, null, '07:00', 15, p_same_place_as => pg_temp.id('c002'))$$,
  '42501', 'not allowed', 'not a check-in of another Space, even my own');
select throws_ok($$select public.post_check_in(pg_temp.id('c0f1'), pg_temp.sp(), 'Unknown', null, null,
                   null, null, '07:00', 15, p_same_place_as => pg_temp.id('c0ff'))$$,
  '42501', 'not allowed', 'an unknown id says the same');
select throws_ok($$select public.post_check_in(pg_temp.id('c0f1'), pg_temp.sp(), 'Not one', null, null,
                   null, null, '07:00', 15, p_same_place_as => pg_temp.id('a001'))$$,
  '22023', 'not a check-in', 'not a post that isn''t a check-in');
select throws_ok($$select public.post_check_in(pg_temp.id('c0f1'), pg_temp.sp(), 'Both', null, null,
                   29.3, 47.9, '07:00', 15, p_same_place_as => pg_temp.id('c001'))$$,
  '22023', 'a place or the same place, not both', 'never both a point and an earlier check-in');
select throws_ok($$select public.post_check_in(pg_temp.id('c0f1'), pg_temp.sp(), 'Half', null, null,
                   29.3, null, '07:00', 15, p_same_place_as => pg_temp.id('c001'))$$,
  '22023', 'a place or the same place, not both', 'nor half a point');
select throws_ok($$select public.post_check_in(pg_temp.id('c0f1'), pg_temp.sp(), 'Neither', null, null,
                   null, null, '07:00', 15)$$, '22023', 'set the place first', 'neither: the place is needed');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.post_check_in(pg_temp.id('c0f1'), pg_temp.sp(), 'Crew', null, null,
                   null, null, '07:00', 15, p_same_place_as => pg_temp.id('c001'))$$,
  '42501', 'not allowed', 'Crew can''t');
select throws_ok($$select site_lat from public.check_in_posts where post_id = pg_temp.id('c010')$$,
  '42501', null, 'the point stays unreadable by the app');
reset role;
select ok(pg_temp.card('a7', 'c010')::text !~ '29\.5|48\.1|site_lat|site_lng|same_place',
  'the card has no point');
select is(pg_temp.card('a7', 'c010') -> 'check_in' -> 'site_set', 'true'::jsonb, 'only that it is set');

-- Post later takes it.
select ok(public.scheduled_call_sql('post_check_in',
            jsonb_build_object('p_id', pg_temp.id('c012'), 'p_same_place_as', pg_temp.id('c001')))
          like '%p_same_place_as%', 'Post later''s call carries it');
select pg_temp.as_user('a7');
set local role authenticated;
select lives_ok($$select public.schedule_post(pg_temp.id('c012'), 'post_check_in',
                   jsonb_build_object('p_id', pg_temp.id('c012'), 'p_space', pg_temp.sp(), 'p_title', 'Later here',
                                      'p_in_time', '07:00', 'p_in_allow', 15,
                                      'p_same_place_as', pg_temp.id('c001')),
                   now() + interval '1 day', 'Later here')$$, 'Post later accepts it');
reset role;
select is(public.scheduled_call_sql('post_check_in', '{"p_id": "x", "p_unknown": 1}'::jsonb), null,
  'and still refuses what it doesn''t know');

select * from finish();
rollback;
