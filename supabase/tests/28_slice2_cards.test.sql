-- Migration 28: ticks, un-ticks and acknowledgements on the card (history
-- lines and last activity), with the face rule; my_spaces' last activity;
-- 30 days of Activity with paging; event_id in the push data; post_history's
-- more flag; daybook_page gone. Run with: supabase test db
--
-- Omar (e1) made the Space and is its admin (Lead). Rakesh (e2) and Sara
-- (e3) are Crew, Vera (e4) a Viewer, Tariq (e6) Crew in the MEP Team, Lina
-- (e7) Crew who posts and then leaves. Eve (e5) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(112);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000028' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@slice2cards28.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e5'), ('e6'), ('e7')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e4', 'Vera', 'Lane'), ('e5', 'Eve', 'Out'), ('e6', 'Tariq', 'Aziz'),
             ('e7', 'Lina', 'Khalil')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000028' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000028' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000028' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000028' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
create function pg_temp.points(p_ids text[], p_texts text[]) returns jsonb language sql as $$
  select jsonb_agg(jsonb_build_object('id', pg_temp.item(i), 'text', t) order by n)
  from unnest(p_ids, p_texts) with ordinality u(i, t, n);
$$;
create function pg_temp.card(p_item text) returns jsonb language sql as $$
  select c.card from public.daybook_cards(pg_temp.sp(), null, 100) c where c.id = pg_temp.item(p_item);
$$;
-- The card's history lines of some kinds, newest first.
create function pg_temp.lines(p_item text, p_kinds text[]) returns jsonb language sql as $$
  select coalesce(jsonb_agg(h order by n), '[]')
  from jsonb_array_elements(pg_temp.card(p_item) -> 'history') with ordinality x(h, n)
  where h ->> 'kind' = any (p_kinds);
$$;
-- The same through post_history ("Show earlier").
create function pg_temp.history_kinds(p_item text, p_kinds text[]) returns bigint language sql as $$
  select count(*) from public.post_history(pg_temp.item(p_item)) h
  where h.event ->> 'kind' = any (p_kinds);
$$;
create function pg_temp.activity(p_item text) returns timestamptz language sql as $$
  select p.last_activity_at from public.space_posts p where p.id = pg_temp.item(p_item);
$$;
create function pg_temp.first_card() returns uuid language sql as $$
  select c.id from public.daybook_cards(pg_temp.sp(), null, 1) c;
$$;
-- Run as the database owner: a post's last activity goes back in time, so
-- the next mark can be seen moving it.
create function pg_temp.back(p_item text, p_minutes integer) returns void language sql as $$
  update public.space_posts set last_activity_at = now() - make_interval(mins => p_minutes)
  where id = pg_temp.item(p_item);
$$;
-- Run as the database owner: the ticks and acknowledgements just made move
-- to a time of their own (a test runs in one transaction).
create function pg_temp.stamp(p_minutes_ago integer) returns void language sql as $$
  alter table public.post_point_events disable trigger post_point_events_append_only;
  update public.post_point_events set created_at = now() - make_interval(mins => p_minutes_ago)
  where created_at = now();
  alter table public.post_point_events enable trigger post_point_events_append_only;
  update public.post_acks set created_at = now() - make_interval(mins => p_minutes_ago)
  where created_at = now();
$$;
create function pg_temp.my_space_activity() returns timestamptz language sql as $$
  select s.last_activity_at from public.my_spaces() s where s.space_id = pg_temp.sp();
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Slice 2 site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e3', 'crew'), ('e4', 'viewer'), ('e6', 'crew'), ('e7', 'crew')) x(id, pass);
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('e6')])::text, true);

-- Ticks and un-ticks --------------------------------------------------------------------------

select lives_ok($$select public.create_space_post(pg_temp.item('a001'), pg_temp.sp(), 'checklist',
                    'Before the pour', p_people => array[pg_temp.uid('e2')],
                    p_points => pg_temp.points(array['b001', 'b002', 'b003'],
                                               array['Rebar spacing', 'Cover blocks', 'Clean formwork']))$$,
  'Omar posts a checklist for Rakesh');
select public.create_work_item(pg_temp.sp(), 'Sleeves at grid C7', pg_temp.uid('e2'), p_id => pg_temp.item('a002'));
reset role;
select pg_temp.back('a001', 60);
select pg_temp.back('a002', 30);
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.first_card(), pg_temp.item('a002'), 'before the tick, the work item is the newest card');
select lives_ok($$select public.tick_point(pg_temp.item('b001'), true)$$, 'Rakesh ticks a point');
select is(pg_temp.activity('a001'), now(), 'a tick raises the checklist''s last activity');
select is(pg_temp.first_card(), pg_temp.item('a001'), 'so the card moves to Now');
select is(pg_temp.lines('a001', array['ticked']) -> 0 ->> 'point', 'Rebar spacing',
  'the history has a tick line with the point''s text');
select is(pg_temp.lines('a001', array['ticked']) -> 0 ->> 'by_name', 'Rakesh Nair', 'and who ticked');
select is(pg_temp.lines('a001', array['ticked']) -> 0 ->> 'point_id', pg_temp.item('b001')::text,
  'and which point');
select is((pg_temp.lines('a001', array['ticked']) -> 0 ->> 'at')::timestamptz, now(), 'and when');
select lives_ok($$select public.tick_point(pg_temp.item('b001'), true)$$, 'ticking it again');
select is(jsonb_array_length(pg_temp.lines('a001', array['ticked'])), 1, 'adds no second line');
reset role;
select pg_temp.stamp(20);
select pg_temp.back('a001', 20);
select pg_temp.as_user('e2');
set local role authenticated;
select lives_ok($$select public.tick_point(pg_temp.item('b001'), false)$$, 'Rakesh unticks it');
select is(pg_temp.activity('a001'), now(), 'an un-tick raises the last activity too');
select is(pg_temp.lines('a001', array['ticked', 'unticked']) -> 0 ->> 'kind', 'unticked',
  'the un-tick is the newest line');
select is(jsonb_array_length(pg_temp.lines('a001', array['ticked', 'unticked'])), 2,
  'and the tick stays in the record');
select lives_ok($$select public.tick_point(pg_temp.item('b001'), false)$$, 'unticking an unticked point');
select is(jsonb_array_length(pg_temp.lines('a001', array['unticked'])), 1, 'adds no line');
reset role;
select pg_temp.stamp(15);
-- The point is reworded once unticked: the old lines keep the words they had.
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.edit_space_post(pg_temp.item('a001'), jsonb_build_object('points',
                    jsonb_build_object('edit', jsonb_build_array(
                      jsonb_build_object('id', pg_temp.item('b001'), 'text', 'Rebar spacing at 200')))))$$,
  'Omar rewords the unticked point');
select is(pg_temp.lines('a001', array['ticked']) -> 0 ->> 'point', 'Rebar spacing',
  'the tick line keeps the words that were ticked');
select pg_temp.as_user('e2');
select public.tick_point(pg_temp.item('b001'), true);
select is(pg_temp.lines('a001', array['ticked']) -> 0 ->> 'point', 'Rebar spacing at 200',
  'a new tick has the new words');
-- Removing an unticked point keeps its lines.
select public.tick_point(pg_temp.item('b003'), true);
select public.tick_point(pg_temp.item('b003'), false);
select pg_temp.as_user('e1');
select lives_ok($$select public.edit_space_post(pg_temp.item('a001'), jsonb_build_object('points',
                    jsonb_build_object('remove', jsonb_build_array(pg_temp.item('b003')))))$$,
  'Omar removes a point that was ticked and unticked');
select ok(exists (select 1 from jsonb_array_elements(pg_temp.lines('a001', array['ticked'])) h
                  where h ->> 'point' = 'Clean formwork' and h ->> 'point_id' is null),
  'its lines stay, without the point''s id');
select is(pg_temp.history_kinds('a001', array['ticked', 'unticked']),
  jsonb_array_length(pg_temp.lines('a001', array['ticked', 'unticked']))::bigint,
  'post_history has the same tick lines');
-- Every member who sees the post sees the ticks (they are on the points too).
select pg_temp.as_user('e4');
select is(jsonb_array_length(pg_temp.lines('a001', array['ticked', 'unticked'])), 5,
  'a Viewer sees every tick line');
select throws_ok($$select public.tick_point(pg_temp.item('b002'), true)$$, '42501', null,
  'but never ticks');
select pg_temp.as_user('e5');
select throws_ok($$select public.tick_point(pg_temp.item('b002'), true)$$, '42501', null,
  'nor does a non-member');
select is((select count(*) from public.post_history(pg_temp.item('a001'))), 0::bigint,
  'who reads no history');
select is((select count(*) from public.daybook_cards(pg_temp.sp())), 0::bigint, 'and no card');

-- A work item's points: a tick moves the work item's card.
select pg_temp.as_user('e1');
select public.edit_space_post(pg_temp.item('a002'), jsonb_build_object('points',
  jsonb_build_object('add', jsonb_build_array(jsonb_build_object('id', pg_temp.item('b010'), 'text', 'Six sleeves')))));
reset role;
select pg_temp.back('a002', 10);
select pg_temp.as_user('e2');
set local role authenticated;
select public.tick_point(pg_temp.item('b010'), true);
select ok(pg_temp.activity('a002') = now() and pg_temp.lines('a002', array['ticked']) -> 0 ->> 'point' = 'Six sleeves',
  'a tick on a work item''s point moves its card and is a line of its history');

-- The log is the database's own.
select throws_ok($$select count(*) from public.post_point_events$$, '42501', null,
  'the tick log can''t be read directly');
select throws_ok($$insert into public.post_point_events (post_id, kind, point_text)
                   values (pg_temp.item('a001'), 'ticked', 'x')$$, '42501', null,
  'nor written');
reset role;
select throws_ok($$update public.post_point_events set kind = 'unticked' where post_id = pg_temp.item('a001')$$,
  '42501', null, 'ticks are kept for the record, even for the owner');
select throws_ok($$delete from public.post_point_events where post_id = pg_temp.item('a001')$$,
  '42501', null, 'and can''t be deleted');

-- Got it: faces and lines only for the author ---------------------------------------------------

select pg_temp.as_user('e7');
set local role authenticated;
select lives_ok($$select public.create_space_post(pg_temp.item('a010'), pg_temp.sp(), 'announcement',
                    'Half day Friday')$$, 'Lina posts an announcement');
reset role;
select pg_temp.back('a010', 50);
select pg_temp.as_user('e3');
set local role authenticated;
select lives_ok($$select public.ack(pg_temp.item('a010'), 'got_it')$$, 'Sara: Got it');
select is(pg_temp.activity('a010'), now(), 'Got it raises the last activity');
reset role;
select pg_temp.stamp(40);
select pg_temp.as_user('e4');
set local role authenticated;
select public.ack(pg_temp.item('a010'), 'got_it');
reset role;
select pg_temp.stamp(35);
select pg_temp.as_user('e2');
set local role authenticated;
select public.ack(pg_temp.item('a010'), 'got_it');
select pg_temp.as_user('e3');
select ok(jsonb_array_length(pg_temp.lines('a010', array['got_it'])) = 1
          and pg_temp.lines('a010', array['got_it']) -> 0 ->> 'by_id' = pg_temp.uid('e3')::text,
  'Sara sees only her own Got it line');
select is(pg_temp.history_kinds('a010', array['got_it']), 1::bigint, 'in post_history too');
select is((select count(*) from public.post_acks_for(pg_temp.item('a010'))), 0::bigint,
  'and no faces');
select pg_temp.as_user('e4');
select ok(jsonb_array_length(pg_temp.lines('a010', array['got_it'])) = 1
          and pg_temp.lines('a010', array['got_it']) -> 0 ->> 'by_id' = pg_temp.uid('e4')::text,
  'a Viewer sees only her own');
select pg_temp.as_user('e6');
select is(jsonb_array_length(pg_temp.lines('a010', array['got_it'])), 0,
  'someone who didn''t acknowledge sees none');
select pg_temp.as_user('e1');
select is(jsonb_array_length(pg_temp.lines('a010', array['got_it'])), 0,
  'nor does an admin while the author is in the Space');
select pg_temp.as_user('e7');
select is(jsonb_array_length(pg_temp.lines('a010', array['got_it'])), 3,
  'the author sees every Got it line');
select is(pg_temp.lines('a010', array['got_it']) -> 2 ->> 'by_name', 'Sara Ali',
  'oldest last, with names');
select is((select count(*) from public.post_acks_for(pg_temp.item('a010'))), 3::bigint,
  'and the faces');
select pg_temp.as_user('e5');
select ok(pg_temp.history_kinds('a010', array['got_it']) = 0
          and (select count(*) from public.post_acks_for(pg_temp.item('a010'))) = 0,
  'a non-member gets no line and no face');
-- Taken back: the line goes, the last activity stays.
select pg_temp.as_user('e2');
reset role;
select pg_temp.back('a010', 5);
select pg_temp.as_user('e2');
set local role authenticated;
select set_config('test.ack1', pg_temp.lines('a010', array['got_it']) -> 0 ->> 'id', true);
select lives_ok($$select public.ack(pg_temp.item('a010'), 'got_it', false)$$, 'Rakesh takes his back');
select is(jsonb_array_length(pg_temp.lines('a010', array['got_it'])), 0, 'his line is gone');
select is(pg_temp.activity('a010'), now() - interval '5 minutes', 'and a take-back moves nothing');
select public.ack(pg_temp.item('a010'), 'got_it');
select ok(jsonb_array_length(pg_temp.lines('a010', array['got_it'])) = 1
          and pg_temp.lines('a010', array['got_it']) -> 0 ->> 'id' <> current_setting('test.ack1'),
  'Got it again is a new line');
select is(pg_temp.activity('a010'), now(), 'and raises the last activity again');
reset role;
select pg_temp.stamp(30);
-- The author leaves: an admin acts for her.
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e7');
select pg_temp.as_user('e1');
set local role authenticated;
select is(jsonb_array_length(pg_temp.lines('a010', array['got_it'])), 3,
  'the author left: the admin sees every Got it line');
select is((select count(*) from public.post_acks_for(pg_temp.item('a010'))), 3::bigint,
  'and the faces');
select pg_temp.as_user('e3');
select is(jsonb_array_length(pg_temp.lines('a010', array['got_it'])), 1,
  'a member still sees only her own');

-- Received: everyone who sees the file post -----------------------------------------------------

reset role;
insert into public.library_files (id, space_id, team_id, name, storage_path, mime, bytes,
                                  rev_label, uploaded_by)
values (pg_temp.item('f001'), pg_temp.sp(), null, 'Door schedule',
        pg_temp.sp() || '/library/' || pg_temp.item('f001') || '/d.pdf', 'application/pdf', 1000,
        'Rev D', pg_temp.uid('e1'));
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.create_space_post(pg_temp.item('a020'), pg_temp.sp(), 'file', null,
                    p_library_file => pg_temp.item('f001'))$$, 'Omar shares a file');
reset role;
select pg_temp.back('a020', 45);
select pg_temp.as_user('e2');
set local role authenticated;
select public.ack(pg_temp.item('a020'), 'received');
select is(pg_temp.activity('a020'), now(), 'Received raises the last activity');
reset role;
select pg_temp.stamp(25);
select pg_temp.as_user('e3');
set local role authenticated;
select public.ack(pg_temp.item('a020'), 'received');
select pg_temp.as_user('e4');
select is(jsonb_array_length(pg_temp.lines('a020', array['received'])), 2,
  'a Viewer who didn''t acknowledge sees both Received lines');
select is((select count(*) from public.post_acks_for(pg_temp.item('a020'))), 2::bigint,
  'and both faces');
select is(pg_temp.lines('a020', array['received']) -> 0 ->> 'by_name', 'Sara Ali', 'newest first');
select pg_temp.as_user('e5');
select ok(pg_temp.history_kinds('a020', array['received']) = 0
          and (select count(*) from public.post_acks_for(pg_temp.item('a020'))) = 0,
  'a non-member gets neither');

-- On my way and In my calendar ------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.create_space_post(pg_temp.item('a030'), pg_temp.sp(), 'activity',
                    'Toolbox talk', p_starts_at => now() + interval '1 hour',
                    p_ends_at => now() + interval '2 hours')$$, 'Omar schedules an activity');
reset role;
select pg_temp.back('a030', 40);
select pg_temp.as_user('e2');
set local role authenticated;
select lives_ok($$select public.ack(pg_temp.item('a030'), 'in_my_calendar')$$, 'Rakesh adds it to his calendar');
select is(pg_temp.activity('a030'), now() - interval '40 minutes', 'In my calendar moves nothing');
reset role;
select pg_temp.stamp(10);
select pg_temp.as_user('e2');
set local role authenticated;
select lives_ok($$select public.ack(pg_temp.item('a030'), 'on_my_way')$$, 'Rakesh is on his way');
select is(pg_temp.activity('a030'), now(), 'On my way raises the last activity');
select is(pg_temp.lines('a030', array['on_my_way', 'in_my_calendar']) -> 0 ->> 'kind', 'on_my_way',
  'Rakesh sees his own two lines, newest first');
select is(jsonb_array_length(pg_temp.lines('a030', array['on_my_way', 'in_my_calendar'])), 2,
  'both of them');
select pg_temp.as_user('e3');
select is(jsonb_array_length(pg_temp.lines('a030', array['on_my_way', 'in_my_calendar'])), 0,
  'another member sees none of them');
select pg_temp.as_user('e1');
select is(jsonb_array_length(pg_temp.lines('a030', array['on_my_way', 'in_my_calendar'])), 2,
  'the author sees them');

-- my_spaces: the last activity the caller can see -----------------------------------------------

select pg_temp.as_user('e2');
select is(pg_temp.my_space_activity(),
  (select max(c.last_activity_at) from public.daybook_cards(pg_temp.sp(), null, 100) c),
  'my_spaces carries the time of the newest card');
reset role;
update public.space_posts set last_activity_at = now() - interval '1 hour' where space_id = pg_temp.sp();
select pg_temp.as_user('e6');
set local role authenticated;
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'MEP risers', pg_temp.uid('e6'),
                    p_team => pg_temp.team(), p_id => pg_temp.item('a040'))$$, 'Tariq posts in the MEP Team');
select is(pg_temp.my_space_activity(), now(), 'the Team sees it as the Space''s last activity');
select pg_temp.as_user('e2');
select is(pg_temp.my_space_activity(), now() - interval '1 hour',
  'someone outside the Team sees the older time: no Team activity leaks');
select pg_temp.as_user('e1');
select is(pg_temp.my_space_activity(), now(), 'the admin sees the Team''s');
select pg_temp.as_user('e5');
select is((select count(*) from public.my_spaces() s where s.space_id = pg_temp.sp()), 0::bigint,
  'a non-member gets no row');
select set_config('test.empty', public.create_space('Empty site')::text, true);
select is((select s.last_activity_at from public.my_spaces() s
           where s.space_id = current_setting('test.empty')::uuid), null,
  'a Space with no posts has no last activity');

-- Activity: 30 days, paged ----------------------------------------------------------------------

reset role;
insert into public.notifications (profile_id, kind, actor_id, created_at)
select pg_temp.uid('e3'), 'follow', pg_temp.uid('e1'), now() - make_interval(hours => 5 * n)
from generate_series(1, 130) n;
insert into public.notifications (profile_id, kind, actor_id, created_at)
values (pg_temp.uid('e3'), 'follow', pg_temp.uid('e1'), now() - interval '31 days');
-- activity_rows is internal: read here as the owner, for Sara.
select pg_temp.as_user('e3');
select is((select count(*) from public.activity_rows() a where a.kind = 'follow'), 130::bigint,
  'Activity keeps 30 days (a row 27 days old is in, one 31 days old is out)');
select set_config('test.total', (select count(*) from public.activity_rows())::text, true);
set local role authenticated;
select is((select count(*) from public.my_activity()), 100::bigint, 'the first page has 100 rows');
select is((select count(*) from public.my_activity(
             (select jsonb_build_object('at', a.created_at, 'id', a.id)
              from public.my_activity() a order by a.created_at, a.id limit 1))),
  current_setting('test.total')::bigint - 100,
  'the next page, from the last row''s cursor, has the rest');
select ok(not exists (select 1 from public.my_activity() a
                      join public.my_activity((select jsonb_build_object('at', b.created_at, 'id', b.id)
                                               from public.my_activity() b order by b.created_at, b.id limit 1)) c
                        on c.id = a.id),
  'and no row is on both pages');
-- unread_activity reads only unread rows, with activity_rows' rules.
select ok(public.unread_activity(), 'unread rows light the dot');
select public.mark_activity_read();
select ok(not public.unread_activity(), 'once read, no dot');
reset role;
-- Unread, but about a Team post Sara can't see, and one older than 30 days.
insert into public.notifications (profile_id, kind, actor_id, space_id, space_post_id, created_at)
values (pg_temp.uid('e3'), 'announcement_new', pg_temp.uid('e6'), pg_temp.sp(), pg_temp.item('a040'), now()),
       (pg_temp.uid('e3'), 'follow', pg_temp.uid('e1'), null, null, now() - interval '31 days');
select pg_temp.as_user('e3');
select is(public.unread_activity(), exists (select 1 from public.activity_rows() a where a.read_at is null),
  'rows Activity would drop light no dot (same answer as the whole window)');
set local role authenticated;
select ok(not public.unread_activity(), 'so there is none');

-- The event id in the push data -----------------------------------------------------------------

reset role;
insert into public.push_tokens (token, profile_id, platform, locale)
values ('fcm-token-for-e2-28-0123456789abcdef', pg_temp.uid('e2'), 'android', 'en');
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Door closers', pg_temp.uid('e2'), p_id => pg_temp.item('a050'));
reset role;
select is((select q.data ->> 'event_id' from public.push_queue q
           where q.profile_id = pg_temp.uid('e2') and q.kind = 'item_assigned'
             and q.data ->> 'work_item_id' = pg_temp.item('a050')::text),
  (select e.id::text from public.work_item_events e
   where e.work_item_id = pg_temp.item('a050') and e.kind = 'raised'),
  'a work item push carries the event''s id');
select pg_temp.as_user('e1');
set local role authenticated;
select public.edit_space_post(pg_temp.item('a050'), jsonb_build_object('title', 'Door closers, level 2'));
reset role;
select is((select q.data ->> 'event_id' from public.push_queue q
           where q.profile_id = pg_temp.uid('e2') and q.kind = 'item_edited'
             and q.data ->> 'work_item_id' = pg_temp.item('a050')::text),
  (select pe.id::text from public.post_edits pe where pe.post_id = pg_temp.item('a050')),
  'an edit''s push carries the edit line''s id');
select pg_temp.as_user('e1');
set local role authenticated;
select public.cancel_space_post(pg_temp.item('a050'));
reset role;
select is((select q.data ->> 'event_id' from public.push_queue q
           where q.profile_id = pg_temp.uid('e2') and q.kind = 'item_cancelled'
             and q.data ->> 'work_item_id' = pg_temp.item('a050')::text),
  pg_temp.item('a050')::text, 'a cancel''s push carries the cancel line''s id (the post''s)');
select ok((select bool_and((q.data ->> 'event_id') is not null) from public.push_queue q
           where q.profile_id = pg_temp.uid('e2')
             and q.data ->> 'work_item_id' = pg_temp.item('a050')::text)
          and (select count(*) from public.push_queue q where q.profile_id = pg_temp.uid('e2')) = 3,
  'every one of them, and nothing else was queued');

-- post_history's more flag ----------------------------------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select ok((select bool_and(h.more) and count(*) = 2
           from public.post_history(pg_temp.item('a001'), p_limit => 2) h),
  'a page with lines left says more');
select ok((select not bool_or(h.more) from public.post_history(pg_temp.item('a001'), p_limit => 100) h),
  'the last page says no more');
select ok((select not bool_or(h.more) and count(*) = 1
           from public.post_history(pg_temp.item('a001'),
                  (select h2.at from public.post_history(pg_temp.item('a001')) h2 order by h2.at, h2.id limit 1 offset 1),
                  (select h2.id from public.post_history(pg_temp.item('a001')) h2 order by h2.at, h2.id limit 1 offset 1)) h),
  'from a cursor, the oldest line alone, with no more');

-- A Team's ticks and acknowledgements stay in the Team ------------------------------------------

select pg_temp.as_user('e6');
set local role authenticated;
select lives_ok($$select public.create_space_post(pg_temp.item('a060'), pg_temp.sp(), 'checklist',
                    'MEP checks', p_team => pg_temp.team(), p_people => array[pg_temp.uid('e6')],
                    p_points => pg_temp.points(array['b020'], array['Riser sleeves']))$$,
  'Tariq posts a Team checklist');
select public.create_space_post(pg_temp.item('a061'), pg_temp.sp(), 'announcement', 'MEP only',
                                p_team => pg_temp.team());
reset role;
update public.space_posts set last_activity_at = now() - interval '2 hours' where space_id = pg_temp.sp();
select pg_temp.as_user('e6');
set local role authenticated;
select public.tick_point(pg_temp.item('b020'), true);
select pg_temp.as_user('e1');
select public.ack(pg_temp.item('a061'), 'got_it');
select pg_temp.as_user('e6');
select ok(pg_temp.lines('a060', array['ticked']) -> 0 ->> 'point' = 'Riser sleeves'
          and jsonb_array_length(pg_temp.lines('a061', array['got_it'])) = 1,
  'the Team sees its tick, and its author the Got it');
select is(pg_temp.my_space_activity(), now(), 'and the Team''s newer time');
select pg_temp.as_user('e2');
select ok(pg_temp.card('a060') is null and pg_temp.card('a061') is null,
  'someone outside the Team gets neither card');
select is((select count(*) from public.post_history(pg_temp.item('a060')))
          + (select count(*) from public.post_history(pg_temp.item('a061'))), 0::bigint,
  'nor any of their lines');
select ok(not exists (select 1 from public.daybook_cards(pg_temp.sp(), null, 100) c,
                        jsonb_array_elements(c.card -> 'history') h
                      where h ->> 'point' = 'Riser sleeves'
                         or (h ->> 'kind' = 'got_it' and h ->> 'by_id' = pg_temp.uid('e1')::text)),
  'on no card at all');
select is(pg_temp.my_space_activity(), now() - interval '2 hours',
  'and my_spaces keeps the older time: a Team tick or Got it doesn''t leak');

-- my_spaces gives what can_see_space_post would, for everyone: an owner
-- outside the Team, and an author who left the Team.
select pg_temp.as_user('e6');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'MEP item for Rakesh', pg_temp.uid('e2'),
                               p_team => pg_temp.team(), p_id => pg_temp.item('a090'));
select public.create_work_item(pg_temp.sp(), 'MEP item of Tariq''s', pg_temp.uid('e6'),
                               p_team => pg_temp.team(), p_id => pg_temp.item('a091'));
reset role;
update public.space_posts set last_activity_at = now() + interval '1 minute' where id = pg_temp.item('a090');
update public.space_posts set last_activity_at = now() + interval '2 minutes' where id = pg_temp.item('a091');
delete from public.team_members where team_id = pg_temp.team() and profile_id = pg_temp.uid('e6');
create function pg_temp.spaces_match() returns boolean language plpgsql as $$
declare
  v_who text;
  v_ok boolean := true;
begin
  foreach v_who in array array['e1', 'e2', 'e3', 'e4', 'e6', 'e7'] loop
    perform pg_temp.as_user(v_who);
    v_ok := v_ok and (pg_temp.my_space_activity() is not distinct from
      (select max(p.last_activity_at) from public.space_posts p
       where p.space_id = pg_temp.sp() and p.deleted_at is null and public.can_see_space_post(p.id)));
  end loop;
  return v_ok;
end;
$$;
select ok(pg_temp.spaces_match(), 'my_spaces matches can_see_space_post for every member, and none for who left');
select pg_temp.as_user('e2');
select is(pg_temp.my_space_activity(), now() + interval '1 minute', 'the owner of a Team item outside the Team sees it');
select pg_temp.as_user('e6');
select is(pg_temp.my_space_activity(), now() + interval '2 minutes', 'an author who left the Team sees their own post');
select pg_temp.as_user('e3');
select is(pg_temp.my_space_activity(), now() - interval '2 hours', 'the rest of the Space still sees neither');
reset role;
insert into public.team_members (team_id, profile_id) values (pg_temp.team(), pg_temp.uid('e6'));

-- More, when the only older lines are hidden ----------------------------------------------------

reset role;
insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000029' || lpad(n::text, 2, '0'))::uuid, 'authenticated', 'authenticated',
       'x' || n || '@slice2cards28.example.com', '{"home_market_id": "kw"}'::jsonb
from generate_series(1, 55) n;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), ('00000000-0000-0000-0000-0000000029' || lpad(n::text, 2, '0'))::uuid, 'crew', pg_temp.uid('e1')
from generate_series(1, 55) n;
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_space_post(pg_temp.item('a070'), pg_temp.sp(), 'announcement', 'Crane day');
reset role;
insert into public.post_acks (post_id, profile_id, kind, created_at)
select pg_temp.item('a070'), ('00000000-0000-0000-0000-0000000029' || lpad(n::text, 2, '0'))::uuid, 'got_it',
       now() - make_interval(mins => 60 + n)
from generate_series(1, 55) n;
select pg_temp.as_user('e3');
set local role authenticated;
select public.ack(pg_temp.item('a070'), 'got_it');
select ok(jsonb_array_length(pg_temp.lines('a070', array['got_it'])) = 1
          and not (pg_temp.card('a070') ->> 'history_more')::boolean,
  'with 55 older lines hidden from her, the card says no more');
select ok((select count(*) = 1 and not bool_or(h.more)
           from public.post_history(pg_temp.item('a070'), p_limit => 1) h),
  'and post_history says no more');
select pg_temp.as_user('e1');
select ok(jsonb_array_length(pg_temp.card('a070') -> 'history') = 50
          and (pg_temp.card('a070') ->> 'history_more')::boolean,
  'the author gets 50 lines, and more');

-- The tick log through an account deletion and a hard delete -------------------------------------

reset role;
insert into auth.users (id, aud, role, email, raw_user_meta_data)
values (pg_temp.uid('e8'), 'authenticated', 'authenticated', 'e8@slice2cards28.example.com',
        '{"home_market_id": "kw"}'::jsonb);
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp(), pg_temp.uid('e8'), 'crew', pg_temp.uid('e1'));
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_space_post(pg_temp.item('a080'), pg_temp.sp(), 'checklist', 'Shutters',
  p_people => array[pg_temp.uid('e8')], p_points => pg_temp.points(array['b030'], array['Shutter oil']));
select pg_temp.as_user('e8');
select public.tick_point(pg_temp.item('b030'), true);
reset role;
delete from auth.users where id = pg_temp.uid('e8');
select ok((select count(*) = 1 and count(actor_id) = 0 from public.post_point_events
           where post_id = pg_temp.item('a080')),
  'a deleted account''s tick line stays, without the actor');
select pg_temp.as_user('e1');
set local role authenticated;
select ok(pg_temp.lines('a080', array['ticked']) -> 0 ->> 'point' = 'Shutter oil'
          and pg_temp.lines('a080', array['ticked']) -> 0 ->> 'by_name' is null,
  'shown with no name ("Former member")');
reset role;
delete from public.space_posts where id = pg_temp.item('a080');
select is((select count(*) from public.post_point_events where post_id = pg_temp.item('a080')), 0::bigint,
  'a post deleted for good takes its tick lines with it');

-- Download my data ------------------------------------------------------------------------------

insert into public.data_requests (id, profile_id)
values (pg_temp.item('d001'), pg_temp.uid('e2'));
select ok((select count(*) >= 5
                  and bool_and(t ->> 'post' = 'Before the pour' or t ->> 'post' = 'Sleeves at grid C7')
           from jsonb_array_elements(public.export_my_data(pg_temp.item('d001')) -> 'tick_log') t),
  'the export lists the person''s ticks and un-ticks (tick_log)');

-- Gone, and grants ------------------------------------------------------------------------------

select ok(to_regprocedure('public.daybook_page(uuid, timestamptz, integer, uuid)') is null
          and to_regprocedure('public.daybook_post_json(public.space_posts)') is null,
  'daybook_page and its post builder are gone');
select ok(not has_function_privilege('authenticated', 'public.post_activity_on_mark()', 'execute')
          and not has_function_privilege('authenticated', 'public.keep_post_point_events()', 'execute')
          and not has_function_privilege('authenticated',
                    'public.post_history_rows(public.space_posts, timestamptz, uuid, integer)', 'execute'),
  'the helpers are internal');
select ok(has_function_privilege('authenticated', 'public.post_history(uuid, timestamptz, uuid, integer)', 'execute')
          and has_function_privilege('authenticated', 'public.my_spaces()', 'execute')
          and not has_function_privilege('anon', 'public.post_history(uuid, timestamptz, uuid, integer)', 'execute')
          and not has_function_privilege('anon', 'public.my_spaces()', 'execute'),
  'post_history and my_spaces are for signed-in people only');

select * from finish();
rollback;
