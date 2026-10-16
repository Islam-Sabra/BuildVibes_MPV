-- Migration 21: the personal notebook and My calendar. Run with: supabase test db
--
-- Omar (d1) made the Space and is its admin (Lead). Rakesh (d2) is Crew and
-- in the MEP Team, Vera (d3) a Viewer, Eve (d4) is in no Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(101);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000021' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@notebook21.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('d1'), ('d2'), ('d3'), ('d4')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('d1', 'Omar', 'Haddad'), ('d2', 'Rakesh', 'Nair'), ('d3', 'Vera', 'Lane'),
             ('d4', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000021' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000021' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000021' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000021' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
-- A file in notebook-files, uploaded by [p_who] (as Storage records it).
create function pg_temp.upload(p_who text, p_note text, p_file text, p_mime text) returns text
language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('notebook-files', pg_temp.uid(p_who) || '/' || pg_temp.id(p_note) || '/' || p_file,
          pg_temp.uid(p_who)::text, jsonb_build_object('mimetype', p_mime, 'size', 1000))
  returning name;
$$;
-- Today in the test, as the phone would send it.
create function pg_temp.cal(p_days integer default 7)
returns setof record language sql as $$
  select kind, title, status, needs_me
  from public.my_calendar(current_date - 1, current_date + p_days,
                          date_trunc('day', now()) - interval '1 day',
                          date_trunc('day', now()) + make_interval(days => p_days + 1));
$$;
create function pg_temp.cal_titles() returns text[] language sql as $$
  select coalesce(array_agg(c.title order by c.title), '{}')
  from public.my_calendar(current_date - 1, current_date + 7,
                          date_trunc('day', now()) - interval '1 day',
                          date_trunc('day', now()) + interval '8 days') c;
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('d1');
set local role authenticated;
select set_config('test.space', public.create_space('Notebook site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('d1')
from (values ('d2', 'crew'), ('d3', 'viewer')) x(id, pass);
select pg_temp.as_user('d1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('d2')])::text, true);
reset role;

-- Tables and grants ---------------------------------------------------------------------------

select ok((select relrowsecurity from pg_class where oid = 'public.notes'::regclass),
  'notes has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.note_files'::regclass),
  'note_files has row-level security');
select ok(not has_table_privilege('anon', 'public.notes', 'select'), 'signed out: no notes');
select ok(not has_table_privilege('anon', 'public.note_files', 'select'), 'signed out: no note files');
select ok(not has_function_privilege('anon', 'public.save_note(uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb)', 'execute'),
  'signed out: no save_note');
select ok(not has_function_privilege('anon', 'public.my_calendar(date, date, timestamptz, timestamptz)', 'execute'),
  'signed out: no my_calendar');
select ok(not has_function_privilege('authenticated', 'public.set_note_files(uuid, jsonb)', 'execute'),
  'set_note_files is internal');
select ok(not has_function_privilege('authenticated', 'public.export_my_data(uuid)', 'execute'),
  'export_my_data stays service role only');
select ok(not has_function_privilege('authenticated', 'public.purge_account(uuid)', 'execute'),
  'purge_account stays service role only');
select is((select public from storage.buckets where id = 'notebook-files'), false,
  'notebook-files is a private bucket');

-- Writing notes -------------------------------------------------------------------------------

select pg_temp.as_user('d1');
set local role authenticated;
select is(public.save_note(pg_temp.id('a001'), 'text', 'Call Yousef at 1:30'), pg_temp.id('a001'),
  'Omar saves a note');
select is(public.save_note(pg_temp.id('a001'), 'text', 'Call Yousef at 1:30 to confirm'), pg_temp.id('a001'),
  'the same id again saves over it');
select is((select body from public.notes where id = pg_temp.id('a001')), 'Call Yousef at 1:30 to confirm',
  'with the new words');
select is((select count(*)::int from public.notes), 1, 'Omar reads his own note');
select throws_ok($$select public.save_note(pg_temp.id('a002'), 'text', '   ')$$, '22023', null,
  'a text note needs words or a photo');
select throws_ok($$select public.save_note(pg_temp.id('a002'), 'checklist', 'Before the walk')$$, '22023', null,
  'a checklist needs points');
select throws_ok($$select public.save_note(pg_temp.id('a002'), 'checklist', null,
                     (select jsonb_agg(jsonb_build_object('text', 'p' || g)) from generate_series(1, 51) g))$$,
  '22023', null, 'at most 50 points');
select throws_ok($$select public.save_note(pg_temp.id('a002'), 'checklist', null,
                     '[{"text": "ok", "extra": 1}]'::jsonb)$$, '22023', null, 'points have text and done only');
select is(public.save_note(pg_temp.id('a002'), 'checklist', 'Before the walk',
                           '[{"text": "Print A-501"}, {"text": "Charge the meter", "done": true}]'::jsonb),
  pg_temp.id('a002'), 'a checklist with two points');
select throws_ok($$select public.save_note(pg_temp.id('a003'), 'todo', null, null, now() + interval '1 day')$$,
  '22023', null, 'a to-do needs words');
select throws_ok($$select public.save_note(pg_temp.id('a003'), 'text', 'x', null, now())$$,
  '22023', null, 'only a to-do has a time');
select is(public.save_note(pg_temp.id('a003'), 'todo', 'Order 40 more sleeves', null,
                           date_trunc('day', now()) + interval '1 day 16 hours'),
  pg_temp.id('a003'), 'a to-do for tomorrow at 4 pm');
select lives_ok($$select public.set_note_done(pg_temp.id('a003'), true)$$, 'Omar ticks his to-do');
select isnt((select done_at from public.notes where id = pg_temp.id('a003')), null, 'it is done');
select throws_ok($$select public.set_note_done(pg_temp.id('a001'), true)$$, '22023', null,
  'only a to-do is ticked');
select throws_ok($$select public.save_note(pg_temp.id('a004'), 'voice')$$, '22023', null,
  'a voice note needs its recording');
reset role;
select pg_temp.upload('d1', 'a004', 'v1.m4a', 'audio/mp4');
select pg_temp.upload('d2', 'a004', 'v2.m4a', 'audio/mp4');
select pg_temp.upload('d1', 'a001', 'p1.jpg', 'image/jpeg');
select pg_temp.as_user('d1');
set local role authenticated;
select throws_ok($$select public.save_note(pg_temp.id('a004'), 'voice', null, null, null, null, null,
                     jsonb_build_array(jsonb_build_object('path', pg_temp.uid('d2') || '/' || pg_temp.id('a004') || '/v2.m4a')))$$,
  '42501', null, 'not someone else''s recording');
select throws_ok($$select public.save_note(pg_temp.id('a004'), 'voice', null, null, null, null, null,
                     jsonb_build_array(jsonb_build_object('path', pg_temp.uid('d1') || '/' || pg_temp.id('a001') || '/p1.jpg')))$$,
  '42501', null, 'nor a file from another note''s folder');
select is(public.save_note(pg_temp.id('a004'), 'voice', null, null, null, null, null,
                           jsonb_build_array(jsonb_build_object('path', pg_temp.uid('d1') || '/' || pg_temp.id('a004') || '/v1.m4a',
                                                                'duration_ms', 24000))),
  pg_temp.id('a004'), 'a voice note with its recording');
select is((select kind || ' ' || mime from public.note_files where note_id = pg_temp.id('a004')), 'voice audio/mp4',
  'the type comes from Storage');
select lives_ok($$select public.pin_note(pg_temp.id('a001'), true)$$, 'Omar pins a note');
select is((select pinned from public.notes where id = pg_temp.id('a001')), true, 'it is pinned');

-- Only the owner ------------------------------------------------------------------------------

select pg_temp.as_user('d2');
select is((select count(*)::int from public.notes), 0, 'Rakesh reads none of Omar''s notes');
select is((select count(*)::int from public.note_files), 0, 'nor their files');
select is((select count(*)::int from storage.objects where bucket_id = 'notebook-files'
           and name like pg_temp.uid('d1') || '/%'), 0, 'nor the files in Storage');
select throws_ok($$select public.save_note(pg_temp.id('a001'), 'text', 'mine now')$$, '42501', null,
  'Rakesh can''t save over Omar''s note');
select throws_ok($$select public.pin_note(pg_temp.id('a001'), false)$$, '42501', null, 'nor pin it');
select throws_ok($$select public.set_note_done(pg_temp.id('a003'), false)$$, '42501', null, 'nor untick it');
select lives_ok($$select public.delete_note(pg_temp.id('a001'))$$, 'deleting someone else''s note does nothing');
select throws_ok($$insert into public.notes (id, owner_id, kind, body) values (pg_temp.id('a009'), auth.uid(), 'text', 'x')$$,
  '42501', null, 'notes are written only through the functions');
select throws_ok($$update public.notes set body = 'x'$$, '42501', null, 'and changed only through them');
select ok(not public.may_upload_note_file(pg_temp.uid('d1') || '/' || pg_temp.id('a005') || '/x.jpg'),
  'Rakesh can''t upload into Omar''s folder');
select ok(public.may_upload_note_file(pg_temp.uid('d2') || '/' || pg_temp.id('a005') || '/x.jpg'),
  'he can upload into his own');
select ok(not public.may_upload_note_file(pg_temp.uid('d2') || '/' || pg_temp.id('a005') || '/x.exe'),
  'photos and voice notes only');
select ok(not public.may_upload_note_file(pg_temp.uid('d2') || '/' || pg_temp.id('a004') || '/x.jpg'),
  'not into the folder of a note that is someone else''s');
select ok(not public.may_delete_note_file(pg_temp.uid('d1') || '/' || pg_temp.id('a001') || '/p1.jpg',
                                          pg_temp.uid('d1')::text),
  'nor delete Omar''s unused file');
select pg_temp.as_user('d1');
select is((select count(*)::int from public.notes), 4, 'Omar still has his four notes');
select is((select count(*)::int from storage.objects where bucket_id = 'notebook-files'), 2,
  'and sees only his own files in Storage');
select ok(not public.may_delete_note_file(pg_temp.uid('d1') || '/' || pg_temp.id('a004') || '/v1.m4a',
                                          pg_temp.uid('d1')::text),
  'a file a note uses can''t be deleted');
select ok(public.may_delete_note_file(pg_temp.uid('d1') || '/' || pg_temp.id('a001') || '/p1.jpg',
                                      pg_temp.uid('d1')::text),
  'an unused one can');

-- Rakesh's own note: Omar, the Space admin, can't read it.
select pg_temp.as_user('d2');
select public.save_note(pg_temp.id('a006'), 'todo', 'Bring the snag list', null,
                        date_trunc('day', now()) + interval '1 day 8 hours');
select pg_temp.as_user('d1');
select is((select count(*)::int from public.notes where owner_id = pg_temp.uid('d2')), 0,
  'the Space admin reads none of Rakesh''s notes');
select ok(not (pg_temp.cal_titles() @> array['Bring the snag list']),
  'nor sees his to-do in My calendar');
select throws_ok($$select public.save_note(pg_temp.id('a008'), 'checklist', null,
                     jsonb_build_array(jsonb_build_object('text', 'a' || repeat(' ', 400))))$$,
  '22023', null, 'a point''s text, spaces included, is at most 300 characters');
select is(public.save_note(pg_temp.id('a008'), 'todo', 'Kind change', null, now() + interval '2 days'),
  pg_temp.id('a008'), 'a to-do');
select is(public.save_note(pg_temp.id('a008'), 'text', 'Kind change'), pg_temp.id('a008'),
  'turned into a text note');
select ok((select due_at is null and done_at is null from public.notes where id = pg_temp.id('a008')),
  'loses its time');
select throws_ok($$select public.save_note(pg_temp.id('a004'), 'text', 'no longer voice')$$, '22023', null,
  'a note with a recording stays a voice note');
select public.delete_note(pg_temp.id('a008'));
select is(public.save_note(pg_temp.id('a008'), 'text', 'A late edit from the outbox'), null,
  'a save after delete returns null');
select is((select count(*)::int from public.notes where id = pg_temp.id('a008')), 0,
  'and the note doesn''t come back');
select pg_temp.as_user('d2');
select throws_ok($$select public.save_note(pg_temp.id('a008'), 'text', 'mine')$$, '42501', null,
  'nobody else can take a deleted note''s id');
select throws_ok($$select count(*) from public.deleted_notes$$, '42501', null,
  'nobody reads the record of deleted notes');
select pg_temp.as_user('d1');

-- Put in a Space --------------------------------------------------------------------------------

select set_config('test.post', public.create_work_item(pg_temp.sp(), 'Order 40 more sleeves', pg_temp.uid('d2'),
                  current_date + 2, p_id => pg_temp.id('b001'))::text, true);
select lives_ok($$select public.mark_note_put(pg_temp.id('a003'), pg_temp.id('b001'))$$,
  'Omar links his to-do to the work item he posted from it');
select pg_temp.as_user('d2');
select throws_ok($$select public.mark_note_put(pg_temp.id('a003'), pg_temp.id('b001'))$$, '42501', null,
  'nobody else can');
select public.create_work_item(pg_temp.sp(), 'Rakesh''s own post', pg_temp.uid('d2'), p_id => pg_temp.id('b006'));
select throws_ok($$select public.mark_note_put(pg_temp.id('a003'), pg_temp.id('b006'))$$, '42501', null,
  'not even onto his own post');
select pg_temp.as_user('d1');
select throws_ok($$select public.mark_note_put(pg_temp.id('a001'), pg_temp.id('b006'))$$, '42501', null,
  'and Omar can''t link his note to a post he didn''t write');
select pg_temp.as_user('d2');
select is((select count(*)::int from public.notes where owner_id <> auth.uid()), 0, 'and the note stays private');

-- My calendar ---------------------------------------------------------------------------------

select pg_temp.as_user('d1');
select public.create_space_post(pg_temp.id('b002'), pg_temp.sp(), 'checklist', 'Before the pour',
  p_due => current_date + 1, p_people => array[pg_temp.uid('d2')],
  p_points => '[{"text": "Sleeves"}, {"text": "Spacers"}]'::jsonb, p_team => pg_temp.team());
select public.create_space_post(pg_temp.id('b003'), pg_temp.sp(), 'activity', 'Site walk',
  p_starts_at => date_trunc('day', now()) + interval '2 days 9 hours', p_people => array[pg_temp.uid('d3')],
  p_place => 'Gate office');
select public.create_space_post(pg_temp.id('b005'), pg_temp.sp(), 'activity', 'Team walk',
  p_team => pg_temp.team(), p_starts_at => date_trunc('day', now()) + interval '1 day 10 hours',
  p_people => array[pg_temp.uid('d2')]);
select public.create_work_item(pg_temp.sp(), 'Team sleeves', pg_temp.uid('d2'), current_date + 1,
  pg_temp.team(), p_id => pg_temp.id('b007'));
select is(pg_temp.cal_titles(), array['Order 40 more sleeves', 'Order 40 more sleeves', 'Team sleeves'],
  'Omar: the work items he wrote and his to-do');
select pg_temp.as_user('d2');
select is(pg_temp.cal_titles(),
  array['Before the pour', 'Bring the snag list', 'Order 40 more sleeves', 'Team sleeves', 'Team walk'],
  'Rakesh: the work items he owns, the Team checklist and activity he is for, and his to-do');
select is((select count(*)::int from pg_temp.cal() as c(kind text, title text, status text, needs_me boolean)
           where c.needs_me), 3, 'the checklist and both work items need him');
select is((select c.place from public.my_calendar(current_date - 1, current_date + 7,
             date_trunc('day', now()) - interval '1 day', date_trunc('day', now()) + interval '8 days') c
           where c.title = 'Bring the snag list'), null, 'a to-do has no place');
select public.ack(pg_temp.id('b003'), 'in_my_calendar');
select ok(pg_temp.cal_titles() @> array['Site walk'], 'an activity he put in his calendar appears');
select is((select c.place from public.my_calendar(current_date - 1, current_date + 7,
             date_trunc('day', now()) - interval '1 day', date_trunc('day', now()) + interval '8 days') c
           where c.title = 'Site walk'), 'Gate office', 'with its place');
select public.ack(pg_temp.id('b003'), 'in_my_calendar', false);
select ok(not (pg_temp.cal_titles() @> array['Site walk']), 'and goes when he takes it back');
select pg_temp.as_user('d3');
select is(pg_temp.cal_titles(), array['Site walk'], 'Vera (Viewer): the activity she is in');
select pg_temp.as_user('d4');
select is(pg_temp.cal_titles(), '{}'::text[], 'Eve, in no Space: nothing');
select throws_ok($$select * from public.my_calendar(current_date, current_date + 62, now(), now() + interval '63 days')$$,
  '22023', null, 'at most 62 days');
select throws_ok($$select * from public.my_calendar(current_date, current_date + 62, now(), now() + interval '1 day')$$,
  '22023', null, '63 days of days alone are refused');
select throws_ok($$select * from public.my_calendar(current_date, current_date, now(), now() + interval '62 days 2 hours')$$,
  '22023', null, 'and 62 days and 2 hours of time alone');
select is((select count(*)::int from public.my_calendar(current_date, current_date, now(), now() + interval '62 days 1 hour')),
  0, 'an hour of slack for a change of clock is allowed');
select throws_ok($$select * from public.my_calendar(current_date, current_date - 1, now(), now() - interval '1 day')$$,
  '22023', null, 'the end after the start');

select is((select count(*)::int from public.my_calendar(current_date, current_date + 61, now(), now() + interval '62 days')),
  0, '62 days, both ends included, are allowed');
-- A cancelled checklist leaves the calendar.
select pg_temp.as_user('d1');
select public.create_space_post(pg_temp.id('b004'), pg_temp.sp(), 'checklist', 'Cancelled list',
  p_due => current_date + 1, p_people => array[pg_temp.uid('d2')], p_points => '[{"text": "x"}]'::jsonb);
select public.cancel_space_post(pg_temp.id('b004'));
select pg_temp.as_user('d2');
select ok(not (pg_temp.cal_titles() @> array['Cancelled list']), 'a cancelled checklist isn''t shown');
select ok(pg_temp.cal_titles() @> array['Bring the snag list'], 'Rakesh sees his own to-do');
-- Taken out of the Team, Rakesh no longer sees its checklist.
select pg_temp.as_user('d1');
select public.set_team_members(pg_temp.team(), '{}');
select pg_temp.as_user('d2');
select is(pg_temp.cal_titles(), array['Bring the snag list', 'Order 40 more sleeves', 'Team sleeves'],
  'out of the Team, its checklist and activity go; the work item he owns stays');
-- After leaving the Space, nothing from it.
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('d2');
select pg_temp.as_user('d2');
set local role authenticated;
select is(pg_temp.cal_titles(), array['Bring the snag list'], 'after leaving the Space, only his own to-do');
reset role;

-- Limits and hidden accounts ------------------------------------------------------------------

insert into public.notes (id, owner_id, kind, body)
select gen_random_uuid(), pg_temp.uid('d4'), 'text', 'note ' || g from generate_series(1, 499) g;
select pg_temp.as_user('d4');
set local role authenticated;
select lives_ok($$select public.save_note(pg_temp.id('a00a'), 'text', 'the 500th')$$, 'the 500th note of the day');
select public.delete_note(pg_temp.id('a00a'));
select throws_ok($$select public.save_note(gen_random_uuid(), 'text', 'one more')$$, '54000', null,
  '500 new notes a day: deleting one doesn''t make room');
reset role;
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('d3');
select pg_temp.as_user('d3');
set local role authenticated;
select throws_ok($$select public.save_note(gen_random_uuid(), 'text', 'hidden')$$, '42501', null,
  'a hidden account writes nothing');
select ok(not public.may_upload_note_file(pg_temp.uid('d3') || '/' || pg_temp.id('a007') || '/x.jpg'),
  'and uploads nothing');
reset role;
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('d2');
select pg_temp.as_user('d2');
set local role authenticated;
select throws_ok($$select public.set_note_done(pg_temp.id('a006'), true)$$, '42501', null,
  'nor ticks a to-do');
select throws_ok($$select public.pin_note(pg_temp.id('a006'), true)$$, '42501', null, 'nor pins');
select throws_ok($$select public.delete_note(pg_temp.id('a006'))$$, '42501', null, 'nor deletes');
reset role;
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('d2');
select is((select count(*)::int from pg_policies
            where schemaname = 'storage' and tablename = 'objects'
              and policyname like 'notebook_files%'
              and not (roles = array['authenticated']::name[])), 0,
  'signed out: no rule lets anyone but a signed-in person near notebook files');
reset role;

-- Download my data and the purge (service role) -----------------------------------------------

insert into public.data_requests (id, profile_id) values (pg_temp.id('c001'), pg_temp.uid('d1'));
select is(jsonb_array_length(public.export_my_data(pg_temp.id('c001')) -> 'notes'), 4,
  'Omar''s download has his notes');
update public.profiles set deletion_scheduled_at = now() - interval '31 days' where id = pg_temp.uid('d1');
select ok(exists (select 1 from public.accounts_due_for_purge()
                  where profile_id = pg_temp.uid('d1') and bucket = 'notebook-files'),
  'the purge lists his notebook files');
select is(public.purge_account(pg_temp.uid('d1')), false, 'and waits while they remain');
-- Delete the voice note: its recording is released and the cleanup claims it.
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('d1');
select pg_temp.as_user('d1');
set local role authenticated;
select public.delete_note(pg_temp.id('a004'));
select ok(public.may_delete_note_file(pg_temp.uid('d1') || '/' || pg_temp.id('a004') || '/v1.m4a',
                                      pg_temp.uid('d1')::text),
  'a deleted note''s recording can be deleted');
reset role;
select pg_temp.upload('d2', 'a010', 'v.m4a', 'audio/mp4');
select pg_temp.as_user('d2');
set local role authenticated;
select public.save_note(pg_temp.id('a010'), 'voice', null, null, null, null, null,
  jsonb_build_array(jsonb_build_object('path', pg_temp.uid('d2') || '/' || pg_temp.id('a010') || '/v.m4a')));
reset role;
update storage.objects set created_at = now() - interval '8 days' where bucket_id = 'notebook-files';
select ok(exists (select 1 from public.orphan_note_files()
                  where name = pg_temp.uid('d1') || '/' || pg_temp.id('a004') || '/v1.m4a'),
  'the cleanup claims it');
select ok(not exists (select 1 from public.orphan_note_files()
                      where name = pg_temp.uid('d2') || '/' || pg_temp.id('a010') || '/v.m4a'),
  'but never a recording still on a note');
-- Real Supabase refuses direct deletes from Storage unless this is set.
set local storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id = 'notebook-files' and name like pg_temp.uid('d1') || '/%';
update public.profiles set deletion_scheduled_at = now() - interval '31 days' where id = pg_temp.uid('d1');
select is(public.purge_account(pg_temp.uid('d1')), true, 'with the files gone, the purge goes ahead');
select is((select count(*)::int from public.notes where owner_id = pg_temp.uid('d1')), 0,
  'and his notes go with him');

select * from finish();
rollback;
