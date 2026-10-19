-- Migration 23: a due time, "On site since" and the month drop-down.
-- Run with: supabase test db
--
-- Omar (e1) made the Space and is its admin (Lead). Rakesh (e2) is Crew,
-- Sara (e3) is Lead, Vera (e4) a Viewer, Tariq (e6) Crew in the MEP Team.
-- Eve (e5) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(122);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000023' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@extras23.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e5'), ('e6')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e4', 'Vera', 'Lane'), ('e5', 'Eve', 'Out'), ('e6', 'Tariq', 'Aziz')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000023' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000023' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000023' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000023' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
-- The month drop-down as the phone asks for it: 30 days either side, as UTC days.
create function pg_temp.month_rows(p_kind text) returns bigint language sql as $$
  select count(*) from public.daybook_month(pg_temp.sp(), current_date - 30, current_date + 30,
                                            now() - interval '30 days', now() + interval '30 days') m
  where m.kind = p_kind;
$$;
-- A daybook card as the signed-in person sees it (all pages at once).
create function pg_temp.card(p_id uuid) returns jsonb language sql as $$
  select d.card from public.daybook_cards(pg_temp.sp(), null, 100) d where d.id = p_id;
$$;
-- One line of a card's history.
create function pg_temp.line(p_item text, p_event uuid) returns jsonb language sql as $$
  select h from jsonb_array_elements(pg_temp.card(pg_temp.item(p_item)) -> 'history') h
  where h ->> 'id' = p_event::text;
$$;
-- The n-th event of a kind on a work item, oldest first.
create function pg_temp.ev(p_item text, p_kind text, p_n integer) returns uuid language sql as $$
  select e.id from public.work_item_events e
  where e.work_item_id = pg_temp.item(p_item) and e.kind = p_kind
  order by e.created_at, e.id offset p_n - 1 limit 1;
$$;
-- The done events of a work item, oldest first.
create function pg_temp.sign_off(p_item text, p_n integer) returns uuid language sql as $$
  select e.id from public.work_item_events e
  where e.work_item_id = pg_temp.item(p_item) and e.kind = 'done'
  order by e.created_at, e.id offset p_n - 1 limit 1;
$$;
-- Run as the database owner: the events just made move to a time of
-- their own (a test runs in one transaction, so now() never moves).
create function pg_temp.stamp(p_minutes_ago integer) returns void language sql as $$
  alter table public.work_item_events disable trigger work_item_events_append_only;
  update public.work_item_events set created_at = now() - make_interval(mins => p_minutes_ago)
  where created_at = now();
  alter table public.work_item_events enable trigger work_item_events_append_only;
$$;
create function pg_temp.due_days() returns date[] language sql as $$
  select coalesce(array_agg(m.day order by m.day), '{}')
  from public.daybook_month(pg_temp.sp(), current_date - 30, current_date + 30,
                            now() - interval '30 days', now() + interval '30 days') m
  where m.kind = 'due';
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Extras site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e3', 'lead'), ('e4', 'viewer'), ('e6', 'crew')) x(id, pass);
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('e6')])::text, true);

-- A due time ----------------------------------------------------------------------------------

select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Fix sleeves at grid C7', pg_temp.uid('e2'),
                    p_due => current_date, p_due_at => current_date + time '14:00',
                    p_id => pg_temp.item('a001'))$$,
  'a work item with a due date and time');
select is((select due_at from public.space_posts where id = pg_temp.item('a001')),
  (current_date + time '14:00')::timestamptz, 'the time is kept');
reset role;
select is((select (public.space_post_json(p, false) ->> 'due_at')::timestamptz
           from public.space_posts p where p.id = pg_temp.item('a001')),
  (current_date + time '14:00')::timestamptz, 'the post''s JSON carries the time');
set local role authenticated;
select throws_ok($$select public.create_work_item(pg_temp.sp(), 'A time with no day', pg_temp.uid('e2'),
                    p_due_at => now() + interval '1 hour', p_id => pg_temp.item('a090'))$$,
  '22023', null, 'a time needs its date');
select throws_ok($$select public.create_work_item(pg_temp.sp(), 'A time on another day', pg_temp.uid('e2'),
                    p_due => current_date, p_due_at => now() + interval '3 days',
                    p_id => pg_temp.item('a091'))$$,
  '22023', null, 'the time falls on its date');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Late evening in UTC-11', pg_temp.uid('e2'),
                    p_due => current_date, p_due_at => current_date + interval '1 day 10 hours',
                    p_id => pg_temp.item('a002'))$$,
  'a date''s evening in the far west is the next day in UTC');
select ok(public.due_at_fits(current_date, (current_date::timestamp - interval '14 hours') at time zone 'UTC'),
  'the first moment of a date in UTC+14 fits');
select ok(not public.due_at_fits(current_date, (current_date::timestamp + interval '36 hours') at time zone 'UTC'),
  'the moment after its last in UTC-12 doesn''t');
select lives_ok($$select public.create_space_post(pg_temp.item('a003'), pg_temp.sp(), 'checklist',
                    'Before the pour', p_due => current_date + 2,
                    p_due_at => current_date + 2 + time '07:00',
                    p_people => array[pg_temp.uid('e3')],
                    p_points => jsonb_build_array(jsonb_build_object('text', 'Rebar spacing')))$$,
  'a checklist with a due time');
select throws_ok($$select public.create_space_post(pg_temp.item('a092'), pg_temp.sp(), 'announcement',
                    'Half day', p_due_at => now() + interval '1 hour')$$,
  '22023', null, 'a time goes only on a work item or checklist');
reset role;
select throws_ok($$update public.space_posts set due_at = now() + interval '9 days'
                   where id = pg_temp.item('a001')$$,
  '23514', null, 'the table refuses a time off its date, whoever writes it');
select throws_ok($$update public.space_posts set due_date = null where id = pg_temp.item('a001')$$,
  '23514', null, 'and a time with no date');

-- Editing the due date and time.
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.edit_space_post(pg_temp.item('a001'),
                    jsonb_build_object('due_at', current_date + time '16:30'))$$,
  'the author moves the time');
select is((select due_date from public.space_posts where id = pg_temp.item('a001')), current_date,
  'a time alone keeps the date');
select is((select due_at from public.space_posts where id = pg_temp.item('a001')),
  (current_date + time '16:30')::timestamptz, 'and changes the time');
reset role;
select is((select changes -> 'due' ->> 'to_at' from public.post_edits
           where post_id = pg_temp.item('a001') order by created_at desc, id desc limit 1)::timestamptz,
  (current_date + time '16:30')::timestamptz, 'the Edited line has the new time');
select is((select changes -> 'due' ->> 'from_at' from public.post_edits
           where post_id = pg_temp.item('a001') order by created_at desc, id desc limit 1)::timestamptz,
  (current_date + time '14:00')::timestamptz, 'and the old one');
select pg_temp.as_user('e1');
set local role authenticated;
select throws_ok($$select public.edit_space_post(pg_temp.item('a001'),
                    jsonb_build_object('due_at', now() + interval '5 days'))$$,
  '22023', null, 'a time off the date is refused');
select lives_ok($$select public.edit_space_post(pg_temp.item('a001'),
                    jsonb_build_object('due', current_date + 1))$$,
  'a new date alone');
select is((select due_at from public.space_posts where id = pg_temp.item('a001')), null,
  'has no time');
select is((select due_date from public.work_items where id = pg_temp.item('a001')), current_date + 1,
  'the work item keeps the same date');
select lives_ok($$select public.edit_space_post(pg_temp.item('a001'),
                    jsonb_build_object('due', current_date, 'due_at', current_date + time '09:00'))$$,
  'a date and time together');
select is((select due_at from public.space_posts where id = pg_temp.item('a001')),
  (current_date + time '09:00')::timestamptz, 'both change');
select lives_ok($$select public.edit_space_post(pg_temp.item('a002'), jsonb_build_object('due', null))$$,
  'clearing the date');
select is((select due_at from public.space_posts where id = pg_temp.item('a002')), null,
  'clears the time too');
select lives_ok($$select public.edit_space_post(pg_temp.item('a001'),
                    jsonb_build_object('title', 'Fix sleeves at grid C7 before the pour',
                                       'due', current_date))$$,
  'an edit that sends the same date again');
select is((select due_at from public.space_posts where id = pg_temp.item('a001')),
  (current_date + time '09:00')::timestamptz, 'keeps the time');
select pg_temp.as_user('e2');
select throws_ok($$select public.edit_space_post(pg_temp.item('a001'),
                    jsonb_build_object('due_at', current_date + time '10:00'))$$,
  '42501', null, 'only the author edits the time');

-- Late ------------------------------------------------------------------------------------------

-- a001 falls due an hour ago.
reset role;
update public.space_posts set due_date = (now() - interval '1 hour')::date,
                              due_at = now() - interval '1 hour'
where id = pg_temp.item('a001');
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Due later today', pg_temp.uid('e2'),
                    p_due => (now() + interval '1 hour')::date, p_due_at => now() + interval '1 hour',
                    p_id => pg_temp.item('a004'))$$,
  'an item due in an hour');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Due yesterday', pg_temp.uid('e2'),
                    p_due => current_date - 1, p_id => pg_temp.item('a005'))$$,
  'a date-only item due yesterday');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Due today, no time', pg_temp.uid('e2'),
                    p_due => current_date, p_id => pg_temp.item('a006'))$$,
  'a date-only item due today');
create function pg_temp.late(p text) returns boolean language sql as $$
  select exists (select 1 from jsonb_array_elements(
                   public.week_report(pg_temp.sp(), current_date, now() - interval '7 days', now()) -> 'needs_decision') x
                 where x ->> 'post_id' = pg_temp.item(p)::text and x ->> 'state' = 'late');
$$;
create function pg_temp.coming(p text) returns boolean language sql as $$
  select exists (select 1 from jsonb_array_elements(
                   public.week_report(pg_temp.sp(), current_date, now() - interval '7 days', now()) -> 'coming_up') x
                 where x ->> 'post_id' = pg_temp.item(p)::text);
$$;
select ok(pg_temp.late('a001'), 'a timed item is late after its time');
select ok(not pg_temp.late('a004'), 'not before it');
select ok(pg_temp.coming('a004'), 'and is coming up until then');
select ok(not pg_temp.coming('a001'), 'a late item isn''t coming up');
select ok(pg_temp.late('a005'), 'a date-only item is late from the next day');
select ok(not pg_temp.late('a006'), 'not on its day');
select ok(exists (select 1 from jsonb_array_elements(
             public.week_report(pg_temp.sp(), current_date + 1, now() - interval '7 days', now()) -> 'coming_up') x
           where x ->> 'post_id' = pg_temp.item('a004')::text),
  'a timed item stays coming up for a reader already in the next day');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Level 4 ceilings', pg_temp.uid('e2'),
                    p_due => (now() + interval '2 hours')::date, p_due_at => now() + interval '2 hours',
                    p_id => pg_temp.item('a010'))$$,
  'a timed parent work item');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Hangers, bay 1', pg_temp.uid('e2'),
                    p_parent => pg_temp.item('a010'), p_id => pg_temp.item('a011'))$$,
  'with a work item under it');
select is((select (x ->> 'due_at')::timestamptz from jsonb_array_elements(
             public.week_report(pg_temp.sp(), current_date, now() - interval '7 days', now()) -> 'targets') x
           where x ->> 'post_id' = pg_temp.item('a010')::text),
  (select due_at from public.space_posts where id = pg_temp.item('a010')),
  'targets carry the time');
select is((select x ->> 'due_at' from jsonb_array_elements(
             public.week_report(pg_temp.sp(), current_date, now() - interval '7 days', now()) -> 'coming_up') x
           where x ->> 'post_id' = pg_temp.item('a004')::text)::timestamptz,
  (select due_at from public.space_posts where id = pg_temp.item('a004')),
  'coming up shows the time');

-- My calendar: the owner sees the time.
select pg_temp.as_user('e2');
select is((select c.starts_at from public.my_calendar(current_date - 1, current_date + 3,
                                                      now() - interval '1 day', now() + interval '3 days') c
           where c.post_id = pg_temp.item('a004')),
  (select due_at from public.space_posts where id = pg_temp.item('a004')),
  'My calendar has a work item''s due time');

select pg_temp.as_user('e3');
select is((select c.starts_at from public.my_calendar(current_date - 1, current_date + 3,
                                                      now() - interval '1 day', now() + interval '3 days') c
           where c.post_id = pg_temp.item('a003')),
  (current_date + 2 + time '07:00')::timestamptz,
  'and a checklist''s');

-- On site since ---------------------------------------------------------------------------------

select pg_temp.as_user('e1');
select lives_ok($$select public.set_site_start_date(pg_temp.sp(), date '2026-09-05')$$,
  'the Space admin sets "On site since"');
select pg_temp.as_user('e2');
select is((select site_start_date from public.spaces where id = pg_temp.sp()), date '2026-09-05',
  'members read it');
select pg_temp.as_user('e3');
select throws_ok($$select public.set_site_start_date(pg_temp.sp(), date '2026-09-01')$$,
  '42501', null, 'a Lead who isn''t admin can''t set it');
select pg_temp.as_user('e2');
select throws_ok($$select public.set_site_start_date(pg_temp.sp(), date '2026-09-01')$$,
  '42501', null, 'nor Crew');
select throws_ok($$update public.spaces set site_start_date = date '2026-09-01' where id = pg_temp.sp()$$,
  '42501', null, 'nor by writing the table');
select pg_temp.as_user('e5');
select throws_ok($$select public.set_site_start_date(pg_temp.sp(), date '2026-09-01')$$,
  '42501', null, 'nor someone outside the Space');
select is((select count(*) from public.spaces where id = pg_temp.sp()), 0::bigint,
  'who can''t read it either');
select pg_temp.as_user('e1');
select throws_ok($$select public.set_site_start_date(pg_temp.sp(), current_date + 400)$$,
  '22023', null, 'not more than a year ahead');
select throws_ok($$select public.set_site_start_date(pg_temp.sp(), date '1999-12-31')$$,
  '22023', null, 'nor before 2000');
select lives_ok($$select public.set_site_start_date(pg_temp.sp(), null)$$, 'the admin clears it');
select is((select site_start_date from public.spaces where id = pg_temp.sp()), null, 'cleared');

-- The daybook's entries (review 45) -------------------------------------------------------------

reset role;
insert into public.library_files (id, space_id, team_id, name, storage_path, mime, bytes,
                                  rev_label, uploaded_by)
select pg_temp.item('f00' || n), pg_temp.sp(), null, 'M-20' || n,
       pg_temp.sp() || '/library/' || pg_temp.item('f00' || n) || '/m.pdf', 'application/pdf', 1000,
       'Rev C', pg_temp.uid('e1')
from generate_series(1, 4) n;
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Sleeves at grid C7', pg_temp.uid('e2'),
                    p_id => pg_temp.item('b001'))$$,
  'Omar raises a work item for Rakesh');
select public.attach_library_file(pg_temp.item('b001'), pg_temp.item('f00' || n))
from generate_series(1, 4) n;
select is(jsonb_array_length(pg_temp.card(pg_temp.item('b001')) -> 'attachments'), 3,
  'the card carries its first three Library files');
select is(pg_temp.card(pg_temp.item('b001')) -> 'attachments' -> 0 ->> 'rev_label', 'Rev C',
  'each with its revision');
select is(pg_temp.card(pg_temp.item('b001')) ->> 'attachments_more', 'true',
  'and says there are more');
reset role;
select pg_temp.stamp(60);

select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.card(pg_temp.item('b001')) ->> 'needs_me', 'to_sign',
  'the owner''s card asks to sign while it is open');
select public.sign_done(pg_temp.item('b001'), 'All six fixed.');
reset role;
select pg_temp.stamp(50);
insert into public.work_item_evidence (event_id, work_item_id, storage_path, kind, taken_at, place_text)
values (pg_temp.sign_off('b001', 1), pg_temp.item('b001'),
        pg_temp.sp() || '/' || pg_temp.item('b001') || '/proof.jpg', 'photo', now() - interval '51 minutes',
        'Level 2, grid C7');

-- Since migration 28 the daybook is cards only (daybook_page is gone): a
-- sign-off is a line of the card's history, and the latest is its proof.
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.line('b001', pg_temp.sign_off('b001', 1)) ->> 'kind', 'done',
  'a sign-off is a line of the card''s history');
select is(pg_temp.line('b001', pg_temp.sign_off('b001', 1)) ->> 'note', 'All six fixed.',
  'with the note');
select is(pg_temp.line('b001', pg_temp.sign_off('b001', 1)) -> 'photos' -> 0 ->> 'place',
  'Level 2, grid C7', 'and the photos');
select is(pg_temp.card(pg_temp.item('b001')) -> 'proof' -> 'outcome' ->> 'kind', 'done',
  'waiting for a check');
select is((pg_temp.line('b001', pg_temp.sign_off('b001', 1)) ->> 'at')::timestamptz,
  now() - interval '50 minutes', 'at its own time');
select is(pg_temp.card(pg_temp.item('b001')) ->> 'needs_me', 'to_check',
  'the author is asked to check');
select is(pg_temp.card(pg_temp.item('b001')) -> 'proof' ->> 'event_id', pg_temp.sign_off('b001', 1)::text,
  'the sign-off is the card''s proof');
select pg_temp.as_user('e2');
select is(pg_temp.card(pg_temp.item('b001')) ->> 'needs_me', null,
  'the owner has no clip while it waits');

select pg_temp.as_user('e1');
select public.send_back(pg_temp.item('b001'), 'photo_missing', 'One sleeve has no photo.');
reset role;
select pg_temp.stamp(40);
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.card(pg_temp.item('b001')) ->> 'needs_me', 'to_sign',
  'sent back, the owner is asked to sign again');
select public.sign_done(pg_temp.item('b001'), 'Photo added.');
reset role;
select pg_temp.stamp(30);
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.line('b001', pg_temp.ev('b001', 'sent_back', 1)) ->> 'kind', 'sent_back',
  'the send-back is a line of its own');
select is(pg_temp.line('b001', pg_temp.ev('b001', 'sent_back', 1)) ->> 'reason', 'photo_missing',
  'with the reason');
select is(pg_temp.line('b001', pg_temp.ev('b001', 'sent_back', 1)) ->> 'note',
  'One sleeve has no photo.', 'and the note');
select is(pg_temp.card(pg_temp.item('b001')) -> 'proof' -> 'outcome' ->> 'kind', 'done',
  'the second sign-off waits for a check');
select ok(pg_temp.card(pg_temp.item('b001')) ->> 'needs_me' = 'to_check'
          and pg_temp.card(pg_temp.item('b001')) -> 'proof' ->> 'event_id' = pg_temp.sign_off('b001', 2)::text,
  'the proof is the latest sign-off, with the author''s clip');
select public.check_item(pg_temp.item('b001'));
reset role;
select pg_temp.stamp(20);
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.card(pg_temp.item('b001')) -> 'proof' -> 'outcome' ->> 'kind', 'checked',
  'checked, the proof is stamped CHECKED');
select is(pg_temp.card(pg_temp.item('b001')) -> 'proof' -> 'outcome' ->> 'by_name', 'Omar Haddad',
  'by whom');
select is(pg_temp.card(pg_temp.item('b001')) ->> 'needs_me', null,
  'and has no clip');
select pg_temp.as_user('e2');
select lives_ok($$select public.add_comment(pg_temp.item('b001'), 'Cleaned the area too.')$$,
  'the owner adds an update');
reset role;
select pg_temp.stamp(10);
select pg_temp.as_user('e3');
set local role authenticated;
select is(pg_temp.line('b001', pg_temp.ev('b001', 'comment', 1)) ->> 'note',
  'Cleaned the area too.', 'an update is a line too');

-- Given to someone else.
select pg_temp.as_user('e1');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Gate 2 hinges', pg_temp.uid('e2'),
                    p_id => pg_temp.item('b003'))$$, 'another work item for Rakesh');
select public.reassign_work_item(pg_temp.item('b003'), pg_temp.uid('e3'));
select is(pg_temp.card(pg_temp.item('b003')) -> 'given_to' ->> 'to_name', 'Sara Ali',
  'the card says who it was given to');
select is(pg_temp.card(pg_temp.item('b003')) -> 'given_to' ->> 'from_name', 'Rakesh Nair',
  'instead of whom');

-- A Team's sign-off stays in the Team.
select pg_temp.as_user('e6');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'MEP risers', pg_temp.uid('e6'),
                    p_team => pg_temp.team(), p_id => pg_temp.item('b002'))$$, 'a Team work item');
reset role;
select pg_temp.stamp(15);
select pg_temp.as_user('e6');
set local role authenticated;
select public.sign_done(pg_temp.item('b002'), 'Risers in.');
reset role;
select pg_temp.stamp(180);
select pg_temp.as_user('e6');
set local role authenticated;
select ok(pg_temp.line('b002', pg_temp.sign_off('b002', 1)) is not null,
  'the Team sees its sign-off');
select pg_temp.as_user('e2');
select ok(pg_temp.card(pg_temp.item('b002')) is null,
  'someone outside the Team never gets it');
select pg_temp.as_user('e5');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100)), 0::bigint,
  'nor does someone outside the Space get any card');

select pg_temp.as_user('e2');
select ok(exists (select 1 from public.daybook_month(pg_temp.sp(), current_date - 30, current_date + 30,
                                                     now() - interval '30 days', now() + interval '30 days') m
                  where m.kind = 'posts'
                    and m.at = date_bin('15 minutes', now() - interval '180 minutes',
                                        timestamptz '2000-01-01 00:00+00'))
          is false, 'nor a dot for it');
select pg_temp.as_user('e6');
select ok(exists (select 1 from public.daybook_month(pg_temp.sp(), current_date - 30, current_date + 30,
                                                     now() - interval '30 days', now() + interval '30 days') m
                  where m.kind = 'posts'
                    and m.at = date_bin('15 minutes', now() - interval '180 minutes',
                                        timestamptz '2000-01-01 00:00+00')),
  'which the Team gets');

-- Only the Library files the reader may read are on the slip, in the list
-- and in the count.
reset role;
insert into public.library_files (id, space_id, team_id, name, storage_path, mime, bytes, uploaded_by)
select pg_temp.item('f01' || n), pg_temp.sp(), pg_temp.team(), 'MEP-' || n,
       pg_temp.sp() || '/library/' || pg_temp.item('f01' || n) || '/m.pdf', 'application/pdf', 1000,
       pg_temp.uid('e6')
from generate_series(1, 3) n;
insert into public.work_item_attachments (work_item_id, library_file_id, added_by)
select pg_temp.item('b003'), pg_temp.item('f01' || n), pg_temp.uid('e1') from generate_series(1, 3) n
union all
select pg_temp.item('b003'), pg_temp.item('f004'), pg_temp.uid('e1');
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.card(pg_temp.item('b003')) -> 'attachments' -> 0 ->> 'name', 'M-204',
  'outside the Team, only the Everyone file is on the card');
select ok(jsonb_array_length(pg_temp.card(pg_temp.item('b003')) -> 'attachments') = 1
          and pg_temp.card(pg_temp.item('b003')) ->> 'attachments_more' is null,
  'and no "more"');
select pg_temp.as_user('e1');
select ok(jsonb_array_length(pg_temp.card(pg_temp.item('b003')) -> 'attachments') = 3
          and (pg_temp.card(pg_temp.item('b003')) ->> 'attachments_more')::boolean,
  'the admin gets three and "more"');

-- A Viewer, a cancelled item and a deleted item.
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Core B door sets', pg_temp.uid('e2'),
                    p_id => pg_temp.item('b004'))$$, 'a work item for Rakesh');
select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('b004'), 'Doors hung.');
select pg_temp.as_user('e4');
select ok(pg_temp.card(pg_temp.item('b004')) is not null
          and pg_temp.card(pg_temp.item('b004')) ->> 'needs_me' is null,
  'a Viewer never gets a clip');
select pg_temp.as_user('e1');
select is(pg_temp.card(pg_temp.item('b004')) ->> 'needs_me', 'to_check',
  'the author does');
select lives_ok($$select public.cancel_space_post(pg_temp.item('b004'))$$, 'then cancels it');
select is(pg_temp.card(pg_temp.item('b004')) -> 'proof' -> 'outcome' ->> 'kind', 'cancelled',
  'its sign-off stays, as the record, marked cancelled');
select is(pg_temp.card(pg_temp.item('b004')) ->> 'needs_me', null,
  'with no clip');
reset role;
update public.space_posts set deleted_at = now() where id = pg_temp.item('b004');
select pg_temp.as_user('e1');
set local role authenticated;
select ok(pg_temp.card(pg_temp.item('b004')) is null
          and not exists (select 1 from public.post_history(pg_temp.item('b004'))),
  'a deleted item''s card and history go with it');
select ok(not has_function_privilege('authenticated',
                    'public.daybook_event_json(public.work_item_events, public.space_posts)', 'execute')
          and not has_function_privilege('anon', 'public.daybook_cards(uuid, timestamptz, integer, uuid)', 'execute'),
  'the entry builder is internal, and anon reads no daybook');

-- Paging: cards with the same last activity are neither skipped nor repeated.
reset role;
create function pg_temp.walk() returns bigint language plpgsql as $$
declare
  v_at timestamptz;
  v_id uuid;
  v_seen uuid[] := '{}';
  v_row record;
begin
  loop
    select d.last_activity_at, d.id into v_row from public.daybook_cards(pg_temp.sp(), v_at, 1, v_id) d;
    exit when v_row.id is null;
    v_seen := v_seen || v_row.id;
    v_at := v_row.last_activity_at;
    v_id := v_row.id;
  end loop;
  return (select count(distinct x) from unnest(v_seen) x);
end;
$$;
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.walk(),
  (select count(*) from public.daybook_cards(pg_temp.sp(), null, 100)),
  'one at a time, the cursor reaches every card once');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.last_activity_at = now()) > 1, true,
  'including several made at the same moment');

-- The month's dots count sign-offs and updates.
select ok(exists (select 1 from public.daybook_month(pg_temp.sp(), current_date - 30, current_date + 30,
                                                     now() - interval '30 days', now() + interval '30 days') m
                  where m.kind = 'posts'
                    and m.at = date_bin('15 minutes', now() - interval '10 minutes',
                                        timestamptz '2000-01-01 00:00+00')),
  'an update lights its quarter hour');

-- The month drop-down ---------------------------------------------------------------------------

-- A Team post by Tariq, and two of Omar's posts within the same quarter hour.
select pg_temp.as_user('e6');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'MEP only, due in a week', pg_temp.uid('e6'),
                    p_due => current_date + 7, p_team => pg_temp.team(), p_id => pg_temp.item('a007'))$$,
  'a Team work item');
reset role;
update public.space_posts set created_at = now() - interval '10 days' where id = pg_temp.item('a007');
update public.space_posts set created_at = date_bin('15 minutes', now() - interval '20 days',
                                                    timestamptz '2000-01-01 00:00+00') + interval '1 minute'
where id in (pg_temp.item('a005'), pg_temp.item('a006'));
-- Checked, cancelled and fully ticked posts light no due day: each gets a
-- day of its own.
update public.space_posts set due_date = current_date + 4, due_at = null where id = pg_temp.item('a004');
update public.work_items set status = 'checked', checked_at = now(), checked_by = pg_temp.uid('e1')
where id = pg_temp.item('a004');
update public.space_posts set due_date = current_date + 5 where id = pg_temp.item('a002');
update public.space_posts set due_date = (now() + interval '2 hours')::date + 20, due_at = null
where id = pg_temp.item('a010');
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.create_space_post(pg_temp.item('a008'), pg_temp.sp(), 'checklist',
                    'Ticked already', p_due => current_date + 3, p_people => array[pg_temp.uid('e3')],
                    p_points => jsonb_build_array(jsonb_build_object('text', 'Clean formwork')))$$,
  'a checklist due in three days');
reset role;
update public.checklist_points set ticked_at = now(), ticked_by = pg_temp.uid('e3')
where post_id = pg_temp.item('a008');
select pg_temp.as_user('e6');
set local role authenticated;
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'MEP item for Rakesh', pg_temp.uid('e2'),
                    p_due => current_date + 6, p_team => pg_temp.team(), p_id => pg_temp.item('a009'))$$,
  'a Team work item owned by someone outside the Team');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.cancel_space_post(pg_temp.item('a002'))$$, 'a work item cancelled');
select pg_temp.as_user('e2');
select ok(not ((current_date + 7) = any (pg_temp.due_days())),
  'a Team''s due item lights no day for someone outside the Team');
select ok(not exists (select 1 from public.daybook_month(pg_temp.sp(), current_date - 30, current_date + 30,
                                                         now() - interval '30 days', now() + interval '30 days') m
                      where m.kind = 'posts' and m.at = date_bin('15 minutes', now() - interval '10 days',
                                                                 timestamptz '2000-01-01 00:00+00')),
  'nor its post');
select ok((current_date + 6) = any (pg_temp.due_days()),
  'its owner outside the Team sees the day of the item they own');
select pg_temp.as_user('e4');
select ok((current_date - 1) = any (pg_temp.due_days())
          and not ((current_date + 6) = any (pg_temp.due_days()))
          and not ((current_date + 7) = any (pg_temp.due_days())),
  'a Viewer sees Everyone''s days, not a Team''s');
select pg_temp.as_user('e6');
select ok((current_date + 7) = any (pg_temp.due_days()), 'the Team sees its due day');
select pg_temp.as_user('e1');
select is(pg_temp.due_days(),
  (select array_agg(distinct d order by d)
   from unnest(array[current_date - 1, (now() - interval '1 hour')::date, current_date,
                     current_date + 2, current_date + 6, current_date + 7,
                     (now() + interval '2 hours')::date + 20]) d),
  'the admin sees each due day once: open, late and Team items and the open checklist');
select ok(not (array[current_date + 3, current_date + 4, current_date + 5] && pg_temp.due_days()),
  'never a checked or cancelled item, or a checklist with every point ticked');
select is((select count(*) from public.daybook_month(pg_temp.sp(), current_date - 30, current_date + 30,
                                                     now() - interval '30 days', now() + interval '30 days') m
           where m.kind = 'posts'
             and m.at = date_bin('15 minutes', now() - interval '20 days', timestamptz '2000-01-01 00:00+00')),
  1::bigint, 'two posts in the same quarter hour are one dot, never a count');
select ok((select bool_and(extract(epoch from m.at)::bigint % 900 = 0)
           from public.daybook_month(pg_temp.sp(), current_date - 30, current_date + 30,
                                     now() - interval '30 days', now() + interval '30 days') m
           where m.kind = 'posts'), 'post times are whole quarter hours');
select throws_ok($$select * from public.daybook_month(pg_temp.sp(), current_date - 70, current_date,
                                                      now() - interval '70 days', now())$$,
  '22023', null, 'at most 62 days');
select pg_temp.as_user('e5');
select is(pg_temp.month_rows('posts') + pg_temp.month_rows('due'), 0::bigint,
  'someone outside the Space reads nothing');
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e4');
select pg_temp.as_user('e4');
set local role authenticated;
select is(pg_temp.month_rows('posts') + pg_temp.month_rows('due'), 0::bigint,
  'nor someone who has left');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100)), 0::bigint,
  'who gets no daybook cards either');
reset role;
update public.spaces set deleted_at = now() where id = pg_temp.sp();
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.month_rows('posts') + pg_temp.month_rows('due'), 0::bigint,
  'a deleted Space shows nothing, even to its admin');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100)), 0::bigint,
  'no daybook cards');
select throws_ok($$select public.set_site_start_date(pg_temp.sp(), date '2026-09-05')$$,
  '42501', null, 'and its start date can''t be set');
reset role;

select * from finish();
rollback;
