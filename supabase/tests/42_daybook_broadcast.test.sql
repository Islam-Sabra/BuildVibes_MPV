-- Migration 42 (review 50, F47 reopened): the database keeps a Space's
-- daybook live. Run with: supabase test db
--
-- Omar (e1) runs the Space; Rakesh (e2) and Sara (e3) are Crew in it. Vera
-- (e5) is outside. Each action is its own transaction in the app; here
-- pg_temp.next() starts a fresh count (and forgets the posts already sent
-- in this test's one transaction).

begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000042' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@daybook42.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e5')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e5', 'Vera', 'Lin')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000042' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000042' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000042' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000042' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.topic() returns text language sql as $$
  select 'daybook:' || pg_temp.sp();
$$;
-- As the database owner: the broadcasts on the Space's topic since next().
create function pg_temp.casts() returns bigint language sql as $$
  select count(*) from realtime.messages where topic = pg_temp.topic() and event = 'changed';
$$;
create function pg_temp.cast_posts() returns text language sql as $$
  select string_agg(payload ->> 'post_id', ',' order by payload ->> 'post_id')
  from realtime.messages where topic = pg_temp.topic() and event = 'changed';
$$;
create function pg_temp.next() returns void language sql as $$
  delete from realtime.messages where topic = pg_temp.topic();
  select set_config('bv.daybook_sent', '', true);
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Live daybook')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x), 'crew', pg_temp.uid('e1')
from unnest(array['e2', 'e3']) x;
insert into public.library_files (id, space_id, name, storage_path, mime, bytes, uploaded_by)
values (pg_temp.id('f001'), pg_temp.sp(), 'Door schedule',
        pg_temp.sp() || '/library/' || pg_temp.id('f001') || '/doors.pdf', 'application/pdf',
        2400000, pg_temp.uid('e1'));
select pg_temp.next();

-- A post --------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select public.create_space_post(pg_temp.id('a001'), pg_temp.sp(), 'announcement',
                                'Friday is a half day');
reset role;
select is(pg_temp.casts(), 1::bigint, 'a new post: one broadcast on its Space''s topic');
select ok((select extension = 'broadcast' and private
           from realtime.messages where topic = pg_temp.topic()),
  'a private broadcast');
select is((select payload - 'id' from realtime.messages where topic = pg_temp.topic()),
  jsonb_build_object('space_id', pg_temp.sp(), 'post_id', pg_temp.id('a001')),
  'with only the Space''s and the post''s ids');
select ok((select position('Friday' in payload::text) = 0 from realtime.messages
           where topic = pg_temp.topic()), 'never any text');

select pg_temp.next();
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_space_post(pg_temp.id('a002'), pg_temp.sp(), 'checklist', 'Before the pour',
                                p_people => array[pg_temp.uid('e2')],
                                p_points => jsonb_build_array(
                                  jsonb_build_object('id', pg_temp.id('b001'), 'text', 'Rebar spacing'),
                                  jsonb_build_object('id', pg_temp.id('b002'), 'text', 'Cover blocks')));
reset role;
select is(pg_temp.casts(), 1::bigint,
  'a checklist with its people and points, in one action: one broadcast');
select is(pg_temp.cast_posts(), pg_temp.id('a002')::text, 'about that checklist');

-- A tick, Got it, Received ------------------------------------------------------------------

select pg_temp.next();
select pg_temp.as_user('e2');
set local role authenticated;
select public.tick_point(pg_temp.id('b001'), true);
reset role;
select is(pg_temp.casts(), 1::bigint, 'a tick: one broadcast');
select is(pg_temp.cast_posts(), pg_temp.id('a002')::text, 'about its checklist');

select pg_temp.next();
select pg_temp.as_user('e2');
set local role authenticated;
select public.tick_point(pg_temp.id('b001'), false);
reset role;
select is(pg_temp.casts(), 1::bigint, 'an untick too');

select pg_temp.next();
select pg_temp.as_user('e2');
set local role authenticated;
select public.ack(pg_temp.id('a001'), 'got_it');
reset role;
select is(pg_temp.casts(), 1::bigint, 'Got it: one broadcast');
select is(pg_temp.cast_posts(), pg_temp.id('a001')::text, 'about the announcement');

select pg_temp.next();
select pg_temp.as_user('e2');
set local role authenticated;
select public.ack(pg_temp.id('a001'), 'got_it', false);
reset role;
select is(pg_temp.casts(), 1::bigint, 'taking Got it back: one broadcast');

select pg_temp.next();
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_space_post(pg_temp.id('a004'), pg_temp.sp(), 'file', null, 'Door sets changed',
                                p_library_file => pg_temp.id('f001'));
reset role;
select is(pg_temp.casts(), 1::bigint, 'a file post: one broadcast');
select pg_temp.next();
select pg_temp.as_user('e2');
set local role authenticated;
select public.ack(pg_temp.id('a004'), 'received');
reset role;
select is(pg_temp.casts(), 1::bigint, 'Received: one broadcast');
select is(pg_temp.cast_posts(), pg_temp.id('a004')::text, 'about the file post');

-- An edit, a cancel ---------------------------------------------------------------------------

select pg_temp.next();
select pg_temp.as_user('e1');
set local role authenticated;
select public.edit_space_post(pg_temp.id('a001'), '{"title": "Friday is a half day, gate 2"}');
reset role;
select is(pg_temp.casts(), 1::bigint, 'an edit (the post and its history line): one broadcast');
select ok((select position('gate 2' in payload::text) = 0 from realtime.messages
           where topic = pg_temp.topic()), 'never the new words');

select pg_temp.next();
select pg_temp.as_user('e1');
set local role authenticated;
select public.cancel_space_post(pg_temp.id('a001'), null);
reset role;
select is(pg_temp.casts(), 1::bigint, 'a cancel: one broadcast');

-- A work item's history ------------------------------------------------------------------------

select pg_temp.next();
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Pour slab L3', pg_temp.uid('e2'), p_id => pg_temp.id('a003'));
reset role;
select is(pg_temp.casts(), 1::bigint, 'a work item: one broadcast');
select pg_temp.next();
select pg_temp.as_user('e2');
set local role authenticated;
select public.add_comment(pg_temp.id('a003'), 'Pump booked for 7');
reset role;
select is(pg_temp.casts(), 1::bigint, 'a comment (a history line): one broadcast');
select is(pg_temp.cast_posts(), pg_temp.id('a003')::text, 'about the work item');
select ok((select position('Pump' in payload::text) = 0 from realtime.messages
           where topic = pg_temp.topic()), 'never the comment''s words');

-- Many rows in one statement --------------------------------------------------------------------

select pg_temp.next();
insert into public.post_point_events (post_id, point_id, actor_id, kind, point_text)
select pg_temp.id('a002'), pg_temp.id('b002'), pg_temp.uid('e2'), k, 'Cover blocks'
from unnest(array['ticked', 'unticked', 'ticked']) k;
select is(pg_temp.casts(), 1::bigint, 'three rows of one post in one statement: one broadcast');
select pg_temp.next();
update public.space_posts set last_activity_at = last_activity_at + interval '1 second'
where id in (pg_temp.id('a002'), pg_temp.id('a004'));
select is(pg_temp.cast_posts(),
  (select string_agg(x::text, ',' order by x::text) from unnest(array[pg_temp.id('a002'), pg_temp.id('a004')]) x),
  'two posts in one statement: one broadcast each');
select pg_temp.next();
update public.space_posts set last_activity_at = last_activity_at + interval '1 second'
where id = pg_temp.id('a002');
update public.space_posts set last_activity_at = last_activity_at + interval '1 second'
where id = pg_temp.id('a002');
select is(pg_temp.casts(), 1::bigint, 'one post twice in one transaction: once');
select pg_temp.next();
update public.space_posts set title = title where id = pg_temp.id('a002');
select is(pg_temp.casts(), 0::bigint, 'an update that changes nothing sends nothing');

-- Who receives -----------------------------------------------------------------------------------

select pg_temp.next();
select pg_temp.as_user('e2');
set local role authenticated;
select public.tick_point(pg_temp.id('b002'), true);
reset role;
select set_config('realtime.topic', pg_temp.topic(), true);
select pg_temp.as_user('e3');
set local role authenticated;
select is((select count(*) from realtime.messages where topic = pg_temp.topic()), 1::bigint,
  'another member receives Rakesh''s tick');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select is((select count(*) from realtime.messages where topic = pg_temp.topic()), 0::bigint,
  'a non-member who knows the Space id receives nothing');
reset role;
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select is((select count(*) from realtime.messages where topic = pg_temp.topic()), 0::bigint,
  'nor does anon');
reset role;

-- The app can't send -----------------------------------------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select throws_ok($$insert into realtime.messages (topic, extension, event, payload, private)
                   values (pg_temp.topic(), 'broadcast', 'changed',
                           jsonb_build_object('post_id', pg_temp.id('a002')), true)$$,
  '42501', null, 'a member can''t send on the daybook topic: only the database does');
select throws_ok($$select public.daybook_send(pg_temp.sp(), pg_temp.id('a002'))$$,
  '42501', null, 'nor call the database''s sender');
reset role;
select ok(not exists (select 1 from pg_policies
                      where schemaname = 'realtime' and tablename = 'messages'
                        and policyname = 'daybook_live_send'),
  'daybook_live_send is gone');
select ok(not exists (select 1 from pg_policies
                      where schemaname = 'realtime' and tablename = 'messages' and cmd = 'INSERT'),
  'no policy lets anyone insert a broadcast');
select ok(not has_function_privilege('authenticated', 'public.handle_post_row_broadcast()', 'execute')
          and not has_function_privilege('authenticated', 'public.handle_space_post_broadcast()', 'execute')
          and not has_function_privilege('anon', 'public.daybook_send(uuid, uuid)', 'execute'),
  'the triggers'' functions are the database''s own');

select * from finish();
rollback;
