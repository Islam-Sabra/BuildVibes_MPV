-- Migration 20261117120000 (review 108): reminders for someone else (RM1,
-- RM2) and Post later (PL1, PL2). Run with: supabase test db
--
-- Omar (a1) made the Space: its admin, a Lead. Tariq (c3, Crew) writes a
-- work item for Rakesh (b2, Crew, its owner). Lina (d4) is Crew who is
-- neither. Vera (e5) is a Viewer. Eve (f6) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(75);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000056' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@rm56.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('d4'), ('e5'), ('f6')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('a1', 'Omar', 'Haddad'), ('b2', 'Rakesh', 'Nair'), ('c3', 'Tariq', 'Aziz'),
             ('d4', 'Lina', 'Saad'), ('e5', 'Vera', 'Lane'), ('f6', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000056' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000056' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000056' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000056' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
-- Reminders on [p_post] that [p_id] reads through RLS.
create function pg_temp.reads(p_id text, p_post text) returns integer language plpgsql as $$
declare v integer;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  select count(*) into v from public.work_item_reminders where post_id = pg_temp.id(p_post);
  reset role;
  return v;
end;
$$;

-- Setup: the Space and its people; Tariq's work item for Rakesh, due
-- tomorrow at 10:00; phones for Rakesh and Lina.
select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Reminder tower')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1')
from (values ('b2', 'crew'), ('c3', 'crew'), ('d4', 'crew'), ('e5', 'viewer')) x(id, pass);
select pg_temp.as_user('c3');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Formwork check, level 3', pg_temp.uid('b2'),
  p_id => pg_temp.id('a001'), p_due => (now() + interval '1 day')::date,
  p_due_at => ((now() + interval '1 day')::date + time '10:00')::timestamptz);
select public.create_work_item(pg_temp.sp(), 'Sleeves at grid C7', pg_temp.uid('b2'),
  p_id => pg_temp.id('a002'));
reset role;
insert into public.push_tokens (token, profile_id, platform)
values (repeat('b', 40), pg_temp.uid('b2'), 'android'),
       (repeat('d', 40), pg_temp.uid('d4'), 'android');

-- RM: who may set a reminder for someone ------------------------------------------------------------

select has_table('public', 'work_item_reminders', 'work_item_reminders exists');
select ok((select relrowsecurity from pg_class where oid = 'public.work_item_reminders'::regclass),
  'with row-level security on');
select ok(not has_table_privilege('authenticated', 'public.work_item_reminders', 'insert')
          and not has_table_privilege('authenticated', 'public.work_item_reminders', 'update')
          and not has_table_privilege('authenticated', 'public.work_item_reminders', 'delete'),
  'nobody writes it directly');

select pg_temp.as_user('c3');
set local role authenticated;
select lives_ok($$select public.set_work_reminder(pg_temp.id('c001'), pg_temp.id('a001'),
  array[pg_temp.uid('b2')], now() + interval '12 hours', 'Check the formwork before the pour')$$,
  'the creator sets one for the owner');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok($$select public.set_work_reminder(pg_temp.id('c002'), pg_temp.id('a001'),
  array[pg_temp.uid('b2')], now() + interval '13 hours', null)$$, 'the owner sets one');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.set_work_reminder(pg_temp.id('c003'), pg_temp.id('a001'),
  array[pg_temp.uid('b2'), pg_temp.uid('d4')], now() + interval '14 hours', null)$$,
  'a Lead sets one, for two people');
select throws_ok($$select public.set_work_reminder(pg_temp.id('c004'), pg_temp.id('a001'),
  array[pg_temp.uid('f6')], now() + interval '1 hour', null)$$, '22023', null,
  'not for someone outside the Space');
select throws_ok($$select public.set_work_reminder(pg_temp.id('c004'), pg_temp.id('a001'),
  array[pg_temp.uid('b2')], now() - interval '1 hour', null)$$, '22023', null,
  'not in the past');
select throws_ok($$select public.set_work_reminder(pg_temp.id('c004'), pg_temp.id('a001'),
  array[pg_temp.uid('b2')], now() + interval '1 hour', repeat('x', 141))$$, '22023', null,
  'a note of up to 140 characters');
select throws_ok($$select public.set_work_reminder(pg_temp.id('c004'), pg_temp.id('a001'),
  '{}'::uuid[], now() + interval '1 hour', null)$$, '22023', null, 'someone to remind');
reset role;
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok($$select public.set_work_reminder(pg_temp.id('c005'), pg_temp.id('a001'),
  array[pg_temp.uid('b2')], now() + interval '1 hour', null)$$, '42501', null,
  'Crew who isn''t its creator or owner can''t');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok($$select public.set_work_reminder(pg_temp.id('c005'), pg_temp.id('a001'),
  array[pg_temp.uid('b2')], now() + interval '1 hour', null)$$, '42501', null, 'nor a Viewer');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok($$select public.set_work_reminder(pg_temp.id('c005'), pg_temp.id('a001'),
  array[pg_temp.uid('b2')], now() + interval '1 hour', null)$$, '42501', null,
  'nor someone outside the Space');
reset role;

-- At most 5 waiting.
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.set_work_reminder(pg_temp.id('c006'), pg_temp.id('a001'),
  array[pg_temp.uid('b2')], now() + interval '15 hours', null)$$, 'a fourth');
select lives_ok($$select public.set_work_reminder(pg_temp.id('c007'), pg_temp.id('a001'),
  array[pg_temp.uid('b2')], now() + interval '16 hours', null)$$, 'a fifth');
select throws_ok($$select public.set_work_reminder(pg_temp.id('c008'), pg_temp.id('a001'),
  array[pg_temp.uid('b2')], now() + interval '17 hours', null)$$, '22023', null,
  'not a sixth while five wait');
reset role;

-- RM2: who reads them ---------------------------------------------------------------------------------

select is(pg_temp.reads('b2', 'a001'), 5, 'the owner, a recipient, reads all five');
select is(pg_temp.reads('c3', 'a001'), 5, 'the creator reads them');
select is(pg_temp.reads('a1', 'a001'), 5, 'a Lead reads them');
select is(pg_temp.reads('d4', 'a001'), 1, 'Lina only the one she is in');
select is(pg_temp.reads('e5', 'a001'), 0, 'a Viewer none');
select is(pg_temp.reads('f6', 'a001'), 0, 'someone outside none');
select pg_temp.as_user('b2');
set local role authenticated;
select is((select count(*) from public.post_work_reminders(pg_temp.id('a001')))::integer, 5,
  'the item''s Reminders line lists them');
select is((select recipients from public.post_work_reminders(pg_temp.id('a001')) where id = pg_temp.id('c003')),
  '[{"id": "00000000-0000-0000-0000-0000000056b2", "name": "Rakesh Nair"}, {"id": "00000000-0000-0000-0000-0000000056d4", "name": "Lina Saad"}]'::jsonb,
  'with each person''s name');
select is((select can_remove from public.post_work_reminders(pg_temp.id('a001')) where id = pg_temp.id('c002')),
  true, 'who set one may remove it');
select is((select can_remove from public.post_work_reminders(pg_temp.id('a001')) where id = pg_temp.id('c001')),
  false, 'not another''s, as the owner');
reset role;
select pg_temp.as_user('d4');
set local role authenticated;
select is((select count(*) from public.post_work_reminders(pg_temp.id('a001')))::integer, 1,
  'Lina''s line has only hers');
reset role;

-- Removing --------------------------------------------------------------------------------------------

select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok($$select public.remove_work_reminder(pg_temp.id('c003'))$$, '42501', null,
  'a recipient who isn''t its setter, the creator or a Lead can''t remove it');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok($$select public.remove_work_reminder(pg_temp.id('c002'))$$, 'its setter removes it');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select lives_ok($$select public.remove_work_reminder(pg_temp.id('c006'))$$, 'the creator removes a Lead''s');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.remove_work_reminder(pg_temp.id('c007'))$$, 'a Lead removes one');
reset role;
select is(pg_temp.reads('a1', 'a001'), 2, 'two wait');

-- Sending -----------------------------------------------------------------------------------------------

select ok(not has_function_privilege('authenticated', 'public.due_work_reminders()', 'execute'),
  'only the cron sends them');
update public.work_item_reminders set remind_at = now() - interval '1 minute'
where id in (pg_temp.id('c001'), pg_temp.id('c003'));
set local role service_role;
select is(public.due_work_reminders(), 3, 'three pushes: Rakesh once for each reminder, Lina once');
reset role;
select is((select count(*) from public.push_queue where kind = 'work_reminder'
           and profile_id = pg_temp.uid('b2'))::integer, 2, 'Rakesh: one per reminder');
select is((select count(*) from public.push_queue where kind = 'work_reminder'
           and profile_id = pg_temp.uid('d4'))::integer, 1, 'Lina: one');
select ok((select bool_and(data ? 'space_post_id' and data ? 'space_id' and not (data::text ilike '%Formwork%'))
           from public.push_queue where kind = 'work_reminder'), 'ids for the link, never the title in data');
select ok((select bool_and(message_text is null) from public.push_queue where kind = 'work_reminder'),
  'no words on the lock screen unless the person chose it');
set local role service_role;
select is(public.due_work_reminders(), 0, 'sent once');
reset role;
select ok((select bool_and(sent_at is not null) from public.work_item_reminders
           where id in (pg_temp.id('c001'), pg_temp.id('c003'))), 'marked as sent');

-- Not sent when the item is Done, or the person has left.
select pg_temp.as_user('a1');
set local role authenticated;
select public.set_work_reminder(pg_temp.id('c010'), pg_temp.id('a002'),
  array[pg_temp.uid('b2')], now() + interval '1 hour', null);
select public.set_work_reminder(pg_temp.id('c011'), pg_temp.id('a001'),
  array[pg_temp.uid('d4')], now() + interval '1 hour', null);
reset role;
update public.work_items set status = 'done', done_at = now() where id = pg_temp.id('a002');
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('d4');
update public.work_item_reminders set remind_at = now() - interval '1 minute'
where id in (pg_temp.id('c010'), pg_temp.id('c011'));
set local role service_role;
select is(public.due_work_reminders(), 0, 'not for a Done item, nor someone who left');
reset role;
select ok((select bool_and(sent_at is not null) from public.work_item_reminders
           where id in (pg_temp.id('c010'), pg_temp.id('c011'))), 'and not tried again');
update public.space_members set left_at = null
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('d4');

-- PL: Post later ----------------------------------------------------------------------------------------

select has_table('public', 'scheduled_posts', 'scheduled_posts exists');
select ok(not has_table_privilege('authenticated', 'public.scheduled_posts', 'insert')
          and not has_table_privilege('authenticated', 'public.scheduled_posts', 'update')
          and not has_table_privilege('authenticated', 'public.scheduled_posts', 'delete'),
  'nobody writes it directly');

select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok(format($q$select public.schedule_post(%L, 'create_space_post',
  jsonb_build_object('p_id', %L, 'p_space', %L, 'p_kind', 'announcement',
                     'p_title', 'Morning brief: pour at level 3 starts 10:00'),
  now() + interval '1 day', 'Morning brief: pour at level 3 starts 10:00')$q$,
  pg_temp.id('d001'), pg_temp.id('d001'), pg_temp.sp()), 'a Lead schedules an announcement');
select lives_ok(format($q$select public.schedule_post(%L, 'create_space_post',
  jsonb_build_object('p_id', %L, 'p_space', %L, 'p_kind', 'announcement', 'p_title', 'Toolbox talk'),
  now() + interval '1 day', 'Toolbox talk')$q$,
  pg_temp.id('d002'), pg_temp.id('d002'), pg_temp.sp()), 'and another');
select throws_ok(format($q$select public.schedule_post(%L, 'delete_space', '{}'::jsonb,
  now() + interval '1 day', 'x')$q$, pg_temp.id('d003')), '22023', null,
  'only the create calls can be scheduled');
select throws_ok(format($q$select public.schedule_post(%L, 'create_post',
  jsonb_build_object('p_id', %L, 'p_body', 'x', 'p_lang', 'en'), now() - interval '1 hour', 'x')$q$,
  pg_temp.id('d003'), pg_temp.id('d003')), '22023', null, 'not in the past');
select throws_ok(format($q$select public.schedule_post(%L, 'create_post',
  jsonb_build_object('p_id', %L, 'p_body', 'x', 'p_lang', 'en'), now() + interval '1 hour', 'x')$q$,
  pg_temp.id('d003'), pg_temp.id('d999')), '22023', null, 'its id is the post''s');
select throws_ok(format($q$select public.schedule_post(%L, 'create_post',
  jsonb_build_object('p_id', %L, 'p_body', 'x', 'p_lang', 'en', 'p_drop', 'y'), now() + interval '1 hour', 'x')$q$,
  pg_temp.id('d003'), pg_temp.id('d003')), '22023', null, 'only the call''s own arguments');
select is((select count(*) from public.scheduled_posts)::integer, 2, 'Omar reads his two');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select is((select count(*) from public.scheduled_posts)::integer, 0, 'nobody else reads them');
select throws_ok(format($q$select public.cancel_scheduled_post(%L)$q$, pg_temp.id('d002')),
  '42501', null, 'nor cancels them');
reset role;
select pg_temp.as_user('f6');
set local role authenticated;
select throws_ok(format($q$select public.schedule_post(%L, 'create_space_post',
  jsonb_build_object('p_id', %L, 'p_space', %L, 'p_kind', 'announcement', 'p_title', 'x'),
  now() + interval '1 day', 'x')$q$, pg_temp.id('d004'), pg_temp.id('d004'), pg_temp.sp()),
  '42501', null, 'someone outside the Space can''t schedule into it');
select lives_ok(format($q$select public.schedule_post(%L, 'create_post',
  jsonb_build_object('p_id', %L, 'p_body', 'Level 3 slab done', 'p_lang', 'en'),
  now() + interval '2 days', 'Level 3 slab done')$q$, pg_temp.id('d005'), pg_temp.id('d005')),
  'a Feed post, for anyone');
reset role;

-- Edit (its time), cancel, post now.
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok(format($q$select public.update_scheduled_post(%L, now() + interval '3 days')$q$,
  pg_temp.id('d002')), 'its time changes');
select lives_ok(format($q$select public.cancel_scheduled_post(%L)$q$, pg_temp.id('d002')), 'and it is cancelled');
select is((select state from public.scheduled_posts where id = pg_temp.id('d002')), 'cancelled', 'cancelled');
select throws_ok(format($q$select public.update_scheduled_post(%L, now() + interval '1 day')$q$,
  pg_temp.id('d002')), '22023', null, 'a cancelled one doesn''t change');
select lives_ok(format($q$select public.post_scheduled_now(%L)$q$, pg_temp.id('d001')), 'Post now');
select is((select author_id from public.space_posts where id = pg_temp.id('d001')), pg_temp.uid('a1'),
  'the announcement is in the Space, as Omar''s');
select is((select state from public.scheduled_posts where id = pg_temp.id('d001')), 'posted', 'posted');
reset role;

-- At the time: published as the author, the rules checked again.
select pg_temp.as_user('d4');
set local role authenticated;
select lives_ok(format($q$select public.schedule_post(%L, 'create_work_item',
  jsonb_build_object('p_id', %L, 'p_space', %L, 'p_title', 'Seal the riser', 'p_owner', %L),
  now() + interval '1 day', 'Seal the riser')$q$,
  pg_temp.id('d006'), pg_temp.id('d006'), pg_temp.sp(), pg_temp.uid('b2')),
  'Lina schedules a work item for Rakesh');
select lives_ok(format($q$select public.schedule_post(%L, 'create_space_post',
  jsonb_build_object('p_id', %L, 'p_space', %L, 'p_kind', 'checklist', 'p_title', 'Handover list',
                     'p_people', jsonb_build_array(%L),
                     'p_points', '[{"text": "Doors"}, {"text": "Keys"}]'::jsonb),
  now() + interval '1 day', 'Handover list')$q$,
  pg_temp.id('d007'), pg_temp.id('d007'), pg_temp.sp(), pg_temp.uid('b2')),
  'and a checklist, with its people');
reset role;
update public.scheduled_posts set publish_at = now() - interval '1 minute'
where id in (pg_temp.id('d005'), pg_temp.id('d006'), pg_temp.id('d007'));
select ok(not has_function_privilege('authenticated', 'public.publish_due_posts()', 'execute'),
  'only the cron publishes them');
set local role service_role;
select is(public.publish_due_posts(), 3, 'three published');
reset role;
select is((select author_id from public.space_posts where id = pg_temp.id('d006')), pg_temp.uid('d4'),
  'the work item, as Lina''s');
select is((select owner_id from public.work_items where id = pg_temp.id('d006')), pg_temp.uid('b2'),
  'given to Rakesh at that time');
select ok((select created_at > now() - interval '1 minute' from public.space_posts where id = pg_temp.id('d007')),
  'its time is the publishing time');
select is((select author_id from public.posts where id = pg_temp.id('d005')), pg_temp.uid('f6'),
  'the Feed post, as Eve''s');

-- Lina leaves; her next one isn't published, and she is told.
select pg_temp.as_user('d4');
set local role authenticated;
select public.schedule_post(pg_temp.id('d008'), 'create_space_post',
  jsonb_build_object('p_id', pg_temp.id('d008'), 'p_space', pg_temp.sp(), 'p_kind', 'announcement',
                     'p_title', 'Night shift'),
  now() + interval '1 day', 'Night shift');
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('d4');
update public.scheduled_posts set publish_at = now() - interval '1 minute' where id = pg_temp.id('d008');
select set_config('test.claims', coalesce(current_setting('request.jwt.claims', true), ''), true);
set local role service_role;
select is(public.publish_due_posts(), 0, 'not published once she has left');
reset role;
select is((select state || ' ' || error from public.scheduled_posts where id = pg_temp.id('d008')),
  'failed not_allowed', 'failed, with why');
select is((select count(*) from public.space_posts where id = pg_temp.id('d008'))::integer, 0, 'no post');
select is((select count(*) from public.push_queue where kind = 'scheduled_failed'
           and profile_id = pg_temp.uid('d4'))::integer, 1, 'Lina is told: "Couldn''t post"');
select is(coalesce(current_setting('request.jwt.claims', true), ''), current_setting('test.claims'),
  'the cron''s own session is as it was');

select * from finish();
rollback;
