-- Migration 19: checklists, announcements, scheduled activities and file
-- posts. Run with: supabase test db
--
-- Omar (e1) made the Space and is its admin (Lead). Rakesh (e2) and Lina
-- (e7) are Crew, Sara (e3) is Lead, Vera (e4) a Viewer, Tariq (e6) Crew in
-- the MEP Team. Eve (e5) is not in the Space. Omar also runs "Other site".
-- Phones: e1, e2, e3, e4, e6.

begin;
create extension if not exists pgtap with schema extensions;
select plan(139);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000019' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@kinds19.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e5'), ('e6'), ('e7')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e4', 'Vera', 'Lane'), ('e5', 'Eve', 'Out'), ('e6', 'Tariq', 'Aziz'),
             ('e7', 'Lina', 'Saad')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000019' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000019' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000019' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000019' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
-- Run as the database owner: notifications of a kind about a post, and
-- pushes queued.
create function pg_temp.n(p_who text, p_kind text, p_post text) returns bigint language sql as $$
  select count(*) from public.notifications
  where profile_id = pg_temp.uid(p_who) and kind = p_kind
    and coalesce(space_post_id, work_item_id) = pg_temp.item(p_post);
$$;
create function pg_temp.q(p_who text, p_kind text) returns bigint language sql as $$
  select count(*) from public.push_queue where profile_id = pg_temp.uid(p_who) and kind = p_kind;
$$;
create function pg_temp.points(p_ids text[], p_texts text[]) returns jsonb language sql as $$
  select jsonb_agg(jsonb_build_object('id', pg_temp.item(i), 'text', t) order by n)
  from unnest(p_ids, p_texts) with ordinality u(i, t, n);
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Kinds site')::text, true);
select set_config('test.space2', public.create_space('Other site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e3', 'lead'), ('e4', 'viewer'), ('e6', 'crew'), ('e7', 'crew')) x(id, pass);
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('e6')])::text, true);
reset role;
insert into public.push_tokens (token, profile_id, platform)
select 'fcm-token-for-' || x.id || '-0123456789abcdef', pg_temp.uid(x.id), 'android'
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e6')) x(id);
-- Library files: one for Everyone, one for the MEP Team, one in the other Space.
insert into public.library_files (id, space_id, team_id, name, storage_path, mime, bytes,
                                  rev_label, uploaded_by)
values
  (pg_temp.item('f001'), pg_temp.sp(), null, 'Door schedule',
   pg_temp.sp() || '/library/' || pg_temp.item('f001') || '/doors.pdf', 'application/pdf', 2400000,
   'Rev C', pg_temp.uid('e2')),
  (pg_temp.item('f002'), pg_temp.sp(), pg_temp.team(), 'MEP sleeves',
   pg_temp.sp() || '/library/' || pg_temp.item('f002') || '/sleeves.pdf', 'application/pdf', 900000,
   'Rev A', pg_temp.uid('e6')),
  (pg_temp.item('f003'), current_setting('test.space2')::uuid, null, 'Other site plan',
   current_setting('test.space2') || '/library/' || pg_temp.item('f003') || '/plan.pdf',
   'application/pdf', 500000, null, pg_temp.uid('e1'));

select ok((select relrowsecurity from pg_class where oid = 'public.post_people'::regclass),
  'post_people has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.checklist_points'::regclass),
  'checklist_points has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.post_acks'::regclass),
  'post_acks has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.activity_reminders'::regclass),
  'activity_reminders has row-level security');

-- Who posts each kind ---------------------------------------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select lives_ok($$select public.create_space_post(pg_temp.item('a101'), pg_temp.sp(), 'announcement',
                    'Friday is a half day', p_pinned_until => now() + interval '2 days')$$,
  'Crew posts an announcement, pinned for two days');
select lives_ok($$select public.create_space_post(pg_temp.item('a102'), pg_temp.sp(), 'checklist',
                    'Before the pour, slab L3', p_due => current_date + 1,
                    p_people => array[pg_temp.uid('e3'), pg_temp.uid('e7')],
                    p_points => pg_temp.points(array['b001', 'b002', 'b003'],
                                               array['Rebar spacing', 'Cover blocks', 'Clean formwork']))$$,
  'and a checklist for two people with three points');
select throws_ok($$select public.create_space_post(pg_temp.item('a190'), pg_temp.sp(), 'checklist',
                    'For a Viewer', p_people => array[pg_temp.uid('e4')],
                    p_points => pg_temp.points(array['b090'], array['x']))$$,
  '22023', null, 'a checklist is never for a Viewer');
select throws_ok($$select public.create_space_post(pg_temp.item('a191'), pg_temp.sp(), 'checklist',
                    'For nobody', p_points => pg_temp.points(array['b091'], array['x']))$$,
  '22023', null, 'a checklist is for someone');
select throws_ok($$select public.create_space_post(pg_temp.item('a192'), pg_temp.sp(), 'checklist',
                    'No points', p_people => array[pg_temp.uid('e3')])$$,
  '22023', null, 'a checklist has points');
select throws_ok($$select public.create_space_post(pg_temp.item('a193'), pg_temp.sp(), 'checklist',
                    'Pinned?', p_pinned_until => now() + interval '1 day',
                    p_people => array[pg_temp.uid('e3')], p_points => pg_temp.points(array['b093'], array['x']))$$,
  '22023', null, 'a pin goes only on an announcement');
select lives_ok($$select public.create_space_post(pg_temp.item('a104'), pg_temp.sp(), 'file', null,
                    'Core B door sets changed', p_library_file => pg_temp.item('f001'))$$,
  'Crew shares a Library file');
select is((select title from public.space_posts where id = pg_temp.item('a104')), 'Door schedule',
  'a file post is called after its file');
select throws_ok($$select public.create_space_post(pg_temp.item('a194'), pg_temp.sp(), 'file', null,
                    p_library_file => pg_temp.item('f003'))$$,
  '42501', null, 'a file post can''t share another Space''s file');
select throws_ok($$select public.create_space_post(pg_temp.item('a195'), pg_temp.sp(), 'announcement',
                    'Into a Team I''m not in', p_team => pg_temp.team())$$,
  '42501', null, 'a Team post only from inside the Team');

select pg_temp.as_user('e3');
select lives_ok($$select public.create_space_post(pg_temp.item('a103'), pg_temp.sp(), 'activity',
                    'Toolbox talk', p_place => 'Gate 2',
                    p_starts_at => now() + interval '30 minutes', p_ends_at => now() + interval '90 minutes',
                    p_people => array[pg_temp.uid('e2'), pg_temp.uid('e4')])$$,
  'a Lead schedules an activity; a Viewer can attend');
select throws_ok($$select public.create_space_post(pg_temp.item('a196'), pg_temp.sp(), 'activity',
                    'Yesterday', p_starts_at => now() - interval '1 hour')$$,
  '22023', null, 'an activity starts in the future');
select throws_ok($$select public.create_space_post(pg_temp.item('a197'), pg_temp.sp(), 'activity',
                    'Backwards', p_starts_at => now() + interval '2 hours',
                    p_ends_at => now() + interval '1 hour')$$,
  '22023', null, 'and ends after it starts');
select throws_ok($$select public.create_space_post(pg_temp.item('a1c1'), pg_temp.sp(), 'activity',
                    'With a stranger', p_starts_at => now() + interval '5 hours',
                    p_people => array[pg_temp.uid('e5')])$$,
  '22023', null, 'its people are members of the Space');
select throws_ok($$select public.create_space_post(pg_temp.item('a101'), pg_temp.sp(), 'announcement',
                    'Someone else''s id')$$,
  '42501', null, 'someone else''s post id is refused');

select pg_temp.as_user('e1');
select throws_ok($$select public.create_space_post(pg_temp.item('a198'), pg_temp.sp(), 'file', null,
                    p_library_file => pg_temp.item('f002'))$$,
  '22023', null, 'a Team file can''t go on an Everyone post');

select pg_temp.as_user('e6');
select lives_ok($$select public.create_space_post(pg_temp.item('a105'), pg_temp.sp(), 'file', null,
                    p_team => pg_temp.team(), p_library_file => pg_temp.item('f002'))$$,
  'a Team file goes on that Team''s post');
select lives_ok($$select public.create_space_post(pg_temp.item('a106'), pg_temp.sp(), 'announcement',
                    'MEP: sleeves check at 10', p_team => pg_temp.team())$$,
  'a Team announcement');
select throws_ok($$select public.create_space_post(pg_temp.item('a1c2'), pg_temp.sp(), 'activity',
                    'MEP only', p_team => pg_temp.team(), p_starts_at => now() + interval '5 hours',
                    p_people => array[pg_temp.uid('e2')])$$,
  '22023', null, 'and of the Team, on a Team post');

select pg_temp.as_user('e4');
select throws_ok($$select public.create_space_post(pg_temp.item('a199'), pg_temp.sp(), 'announcement',
                    'Viewer here')$$, '42501', null, 'a Viewer can''t post');
select throws_ok($$select public.create_space_post(pg_temp.item('a19a'), pg_temp.sp(), 'file', null,
                    p_library_file => pg_temp.item('f001'))$$, '42501', null,
  'or share a file');
reset role;
update public.space_members set custom = '{"add_files": false}'
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e7');
select pg_temp.as_user('e7');
set local role authenticated;
select throws_ok($$select public.create_space_post(pg_temp.item('a19c'), pg_temp.sp(), 'file', null,
                    p_library_file => pg_temp.item('f001'))$$, '42501', null,
  'Crew without the files right can''t share a file');
select lives_ok($$select public.create_space_post(pg_temp.item('a1a0'), pg_temp.sp(), 'announcement',
                    'Lina is on leave Sunday')$$, 'but still posts');
reset role;
update public.space_members set custom = '{}'
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e7');
set local role authenticated;
select pg_temp.as_user('e5');
select throws_ok($$select public.create_space_post(pg_temp.item('a19b'), pg_temp.sp(), 'announcement',
                    'Stranger')$$, '42501', null, 'nor can a non-member');

select pg_temp.as_user('e2');
select is(public.create_space_post(pg_temp.item('a101'), pg_temp.sp(), 'announcement',
            'Friday is a half day'), pg_temp.item('a101'),
  'sending the same post again makes no second one');

-- Who is told -------------------------------------------------------------------------------------

reset role;
select is((select count(*) from public.notifications
           where kind = 'announcement_new' and space_post_id = pg_temp.item('a101')), 5::bigint,
  'an announcement reaches everyone in the Space');
select is(pg_temp.n('e2', 'announcement_new', 'a101'), 0::bigint, 'but its author');
select is((select string_agg(p.first_name, ',' order by p.first_name) from public.notifications n
           join public.profiles p on p.id = n.profile_id
           where n.kind = 'announcement_new' and n.space_post_id = pg_temp.item('a106')),
  'Omar', 'a Team announcement reaches the Team and the admins only');
select is(pg_temp.n('e3', 'checklist_for_you', 'a102') + pg_temp.n('e7', 'checklist_for_you', 'a102'),
  2::bigint, 'a checklist''s people are told');
select is(pg_temp.n('e2', 'activity_invited', 'a103') + pg_temp.n('e4', 'activity_invited', 'a103'),
  2::bigint, 'and an activity''s');
select is(pg_temp.q('e3', 'checklist_for_you'), 1::bigint, 'with a push');
select ok((select data ->> 'space_post_id' = pg_temp.item('a103')::text
                  and data::text not like '%Toolbox%'
           from public.push_queue where profile_id = pg_temp.uid('e4') and kind = 'activity_invited'),
  'the push carries the post''s id, never its title');

-- Pushes for edits and cancels of a work item (deferred from migration 18).
select pg_temp.as_user('e3');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Close the gate', pg_temp.uid('e2'), p_id => pg_temp.item('a110'));
select public.edit_space_post(pg_temp.item('a110'), '{"title": "Close the north gate"}');
select public.cancel_space_post(pg_temp.item('a110'));
reset role;
select is(pg_temp.q('e2', 'item_edited'), 1::bigint, 'an edit to your work item now pushes');
select is(pg_temp.q('e2', 'item_cancelled'), 1::bigint, 'and so does a cancel');

-- Ticking points ----------------------------------------------------------------------------------

select pg_temp.as_user('e7');
set local role authenticated;
select lives_ok($$select public.tick_point(pg_temp.item('b001'), true)$$, 'one of its people ticks a point');
select pg_temp.as_user('e6');
select lives_ok($$select public.tick_point(pg_temp.item('b002'), true)$$, 'so does any Crew member');
select throws_ok($$select public.tick_point(pg_temp.item('b001'), false)$$, '42501', null,
  'but only whoever ticked it, or the author, unticks it');
select lives_ok($$select public.tick_point(pg_temp.item('b002'), false)$$, 'whoever ticked it unticks it');
select is((select ticked_at from public.checklist_points where id = pg_temp.item('b002')), null,
  'and the tick is gone');
select public.tick_point(pg_temp.item('b002'), true);
select pg_temp.as_user('e4');
select throws_ok($$select public.tick_point(pg_temp.item('b003'), true)$$, '42501', null,
  'a Viewer never ticks');
select pg_temp.as_user('e5');
select throws_ok($$select public.tick_point(pg_temp.item('b003'), true)$$, '42501', null,
  'nor a non-member');
select pg_temp.as_user('e2');
select lives_ok($$select public.tick_point(pg_temp.item('b001'), false)$$, 'the author unticks it');
select is((select d.card -> 'points' from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.id = pg_temp.item('a102')), '{"total": 3, "ticked": 1}'::jsonb,
  'the slip shows 1 of 3 ticked');
select is((select p ->> 'ticked_by_name' from jsonb_array_elements(
             public.post_page(pg_temp.item('a102')) -> 'point_list') p
           where p ->> 'id' = pg_temp.item('b002')::text), 'Tariq Aziz',
  'opened, each tick says who');
select throws_ok($$select public.delete_space_post(pg_temp.item('a102'))$$, 'P0001', null,
  'a tick by someone else ends Delete, even once undone');

-- Editing points and people.
select throws_ok($$select public.edit_space_post(pg_temp.item('a102'),
                    jsonb_build_object('points', jsonb_build_object('remove', jsonb_build_array(pg_temp.item('b002')))))$$,
  'P0001', null, 'a ticked point can''t be removed');
select throws_ok($$select public.edit_space_post(pg_temp.item('a102'),
                    jsonb_build_object('points', jsonb_build_object('edit',
                      jsonb_build_array(jsonb_build_object('id', pg_temp.item('b002'), 'text', 'Other words')))))$$,
  'P0001', null, 'or reworded');
select lives_ok($$select public.edit_space_post(pg_temp.item('a102'),
                    jsonb_build_object('points', jsonb_build_object('order',
                      jsonb_build_array(pg_temp.item('b003'), pg_temp.item('b002'), pg_temp.item('b001')))))$$,
  'but it can be moved');
select lives_ok($$select public.edit_space_post(pg_temp.item('a102'),
                    jsonb_build_object('points', jsonb_build_object(
                      'add', jsonb_build_array(jsonb_build_object('id', pg_temp.item('b005'), 'text', 'Photo of the cover')),
                      'edit', jsonb_build_array(jsonb_build_object('id', pg_temp.item('b003'), 'text', 'Clean the formwork')),
                      'remove', jsonb_build_array(pg_temp.item('b001')))))$$,
  'the author adds, rewords and removes unticked points');
select ok(exists (select 1 from public.post_edits where post_id = pg_temp.item('a102')
                  and changes -> 'points' = '{"added": 1, "removed": 1, "reworded": 1, "reordered": false}'::jsonb)
      and exists (select 1 from public.post_edits where post_id = pg_temp.item('a102')
                  and (changes -> 'points' ->> 'reordered')::boolean),
  'each change is in the record');
select is((select string_agg(text, ' | ' order by sort) from public.checklist_points
           where post_id = pg_temp.item('a102')),
  'Clean the formwork | Cover blocks | Photo of the cover', 'in the new order');
select lives_ok($$select public.edit_space_post(pg_temp.item('a102'),
                    jsonb_build_object('people', jsonb_build_object(
                      'add', jsonb_build_array(pg_temp.uid('e6')), 'remove', jsonb_build_array(pg_temp.uid('e7')))))$$,
  'and changes who it is for');
select throws_ok($$select public.edit_space_post(pg_temp.item('a102'),
                    jsonb_build_object('people', jsonb_build_object('add', jsonb_build_array(pg_temp.uid('e4')))))$$,
  '22023', null, 'never a Viewer');
select throws_ok($$select public.edit_space_post(pg_temp.item('a102'),
                    jsonb_build_object('people', jsonb_build_object('remove',
                      jsonb_build_array(pg_temp.uid('e3'), pg_temp.uid('e6')))))$$,
  '22023', null, 'and never nobody');
select throws_ok($$select public.edit_space_post(pg_temp.item('a101'), '{"due": "2026-12-01"}')$$,
  '22023', null, 'a key that doesn''t fit the kind is refused');
reset role;
select is(pg_temp.n('e6', 'checklist_for_you', 'a102'), 1::bigint, 'someone added is told');
select is(pg_temp.n('e3', 'item_edited', 'a102'), 2::bigint,
  'its people hear of each edit to the points, not of the people changing');

-- Needs you.
select pg_temp.as_user('e3');
set local role authenticated;
select is((select count(*) from public.needs_you() where kind = 'checklist_for_you'
           and space_post_id = pg_temp.item('a102')), 1::bigint,
  'a checklist with points to tick is in its people''s Needs you');
select is((select d.card ->> 'needs_me' from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.id = pg_temp.item('a102')), 'to_tick', 'with the paper clip');
select pg_temp.as_user('e2');
select is((select count(*) from public.needs_you() where kind = 'checklist_for_you'), 0::bigint,
  'not in its author''s');
select pg_temp.as_user('e3');
select public.create_space_post(pg_temp.item('a115'), pg_temp.sp(), 'checklist', 'One point',
  p_people => array[pg_temp.uid('e7')], p_points => pg_temp.points(array['b007'], array['Only']));
select pg_temp.as_user('e7');
select is((select count(*) from public.needs_you() where space_post_id = pg_temp.item('a115')),
  1::bigint, 'a checklist waits in Needs you');
select public.tick_point(pg_temp.item('b007'), true);
select is((select count(*) from public.needs_you() where space_post_id = pg_temp.item('a115')),
  0::bigint, 'until every point is ticked');
reset role;
update public.space_members set pass = 'viewer'
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e3');
select pg_temp.as_user('e3');
set local role authenticated;
select is((select count(*) from public.needs_you() where space_post_id = pg_temp.item('a102')),
  0::bigint, 'someone lowered to Viewer no longer has it in Needs you');
select is((select d.card ->> 'needs_me' from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.id = pg_temp.item('a102')), null, 'nor the paper clip');
reset role;
update public.space_members set pass = 'lead'
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e3');
select pg_temp.as_user('e3');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Fix the ties', pg_temp.uid('e7'), p_id => pg_temp.item('a116'));
select lives_ok($$select public.edit_space_post(pg_temp.item('a116'), jsonb_build_object('points',
                    jsonb_build_object('add', jsonb_build_array(
                      jsonb_build_object('id', pg_temp.item('b008'), 'text', 'Ties at 200')))))$$,
  'the author adds a point to a work item');
select pg_temp.as_user('e7');
select lives_ok($$select public.tick_point(pg_temp.item('b008'), true)$$, 'its owner ticks it while Open');
select public.tick_point(pg_temp.item('b008'), false);
select public.sign_done(pg_temp.item('a116'), 'Done.');
select throws_ok($$select public.tick_point(pg_temp.item('b008'), true)$$, 'P0001', null,
  'a work item''s points lock once it is Done');
select pg_temp.as_user('e2');

-- Acknowledging ------------------------------------------------------------------------------------

select pg_temp.as_user('e3');
select lives_ok($$select public.ack(pg_temp.item('a101'), 'got_it')$$, 'Got it on an announcement');
select lives_ok($$select public.ack(pg_temp.item('a101'), 'got_it')$$, 'twice is still once');
select throws_ok($$select public.ack(pg_temp.item('a101'), 'received')$$, '22023', null,
  'each kind takes its own acknowledgement');
select is((select count(*) from public.post_acks), 1::bigint, 'everyone reads only their own');
select is((select d.card -> 'my_acks' from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.id = pg_temp.item('a101')), '["got_it"]'::jsonb, 'and sees it on the slip');
select pg_temp.as_user('e4');
select lives_ok($$select public.ack(pg_temp.item('a101'), 'got_it')$$, 'a Viewer acknowledges too');
select is((select count(*) from public.post_acks_for(pg_temp.item('a101'))), 0::bigint,
  'but only the author sees who');
select pg_temp.as_user('e1');
select is((select count(*) from public.post_acks_for(pg_temp.item('a101'))), 0::bigint,
  'not an admin while the author is in the Space');
select pg_temp.as_user('e2');
select is((select string_agg(name, ', ' order by name) from public.post_acks_for(pg_temp.item('a101'))),
  'Sara Ali, Vera Lane', 'the author sees each face and name');
select ok(not (public.post_page(pg_temp.item('a101'))::text ~ '"(acks|ack_count|count)"'),
  'and no number anywhere');
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e2');
select pg_temp.as_user('e1');
set local role authenticated;
select is((select count(*) from public.post_acks_for(pg_temp.item('a101'))), 2::bigint,
  'an admin sees who once the author has left');
select pg_temp.as_user('e3');
select is((select count(*) from public.post_acks_for(pg_temp.item('a101'))), 0::bigint,
  'a Lead who isn''t an admin still doesn''t');
reset role;
update public.space_members set left_at = null
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e2');
select pg_temp.as_user('e2');
set local role authenticated;
select is((select count(*) from public.space_posts where id = pg_temp.item('a101')
           and to_jsonb(space_posts) ? 'others_added_at'), 0::bigint,
  'nothing on the post says that someone acknowledged it');
select throws_ok($$select count(*) from public.post_others$$, '42501', null,
  'and nobody reads the record that ends Delete');
select throws_ok($$select public.delete_space_post(pg_temp.item('a101'))$$, 'P0001', null,
  'an acknowledgement by someone else ends Delete');
select throws_ok($$select public.ack(pg_temp.item('a106'), 'got_it')$$, '42501', null,
  'nobody outside a Team acknowledges its post');
select pg_temp.as_user('e3');
select lives_ok($$select public.ack(pg_temp.item('a101'), 'got_it', false)$$, 'Got it can be taken back');
select pg_temp.as_user('e2');
select throws_ok($$select public.delete_space_post(pg_temp.item('a101'))$$, 'P0001', null,
  'and Delete stays ended');

-- Activities: On my way near the time, In my calendar until the end.
select lives_ok($$select public.ack(pg_temp.item('a103'), 'on_my_way')$$, 'On my way, 30 minutes before');
select pg_temp.as_user('e1');
select lives_ok($$select public.ack(pg_temp.item('a103'), 'in_my_calendar')$$,
  'anyone who reads it puts it in their calendar');
select pg_temp.as_user('e3');
select public.create_space_post(pg_temp.item('a107'), pg_temp.sp(), 'activity', 'Site walk',
  p_starts_at => now() + interval '1 day', p_people => array[pg_temp.uid('e7')]);
select pg_temp.as_user('e2');
select throws_ok($$select public.ack(pg_temp.item('a107'), 'on_my_way')$$, 'P0001', null,
  'On my way not a day ahead');
select lives_ok($$select public.ack(pg_temp.item('a107'), 'in_my_calendar')$$, 'In my calendar, yes');
select pg_temp.as_user('e3');
select public.cancel_space_post(pg_temp.item('a107'));
select pg_temp.as_user('e2');
select throws_ok($$select public.ack(pg_temp.item('a107'), 'in_my_calendar')$$, 'P0001', null,
  'nothing on a cancelled post');
reset role;
select is(pg_temp.n('e7', 'item_cancelled', 'a107') + pg_temp.n('e2', 'item_cancelled', 'a107'),
  2::bigint, 'its people and calendar adds are told it was cancelled');
select pg_temp.as_user('e3');
set local role authenticated;
select public.create_space_post(pg_temp.item('a108'), pg_temp.sp(), 'checklist', 'Cancelled list',
  p_people => array[pg_temp.uid('e2')], p_points => pg_temp.points(array['b004'], array['One']));
select public.cancel_space_post(pg_temp.item('a108'));
select pg_temp.as_user('e2');
select throws_ok($$select public.tick_point(pg_temp.item('b004'), true)$$, 'P0001', null,
  'no tick on a cancelled checklist');
select pg_temp.as_user('e3');
select public.create_space_post(pg_temp.item('a113'), pg_temp.sp(), 'checklist', 'Own ticks',
  p_people => array[pg_temp.uid('e2')], p_points => pg_temp.points(array['b006'], array['Mine']));
select public.tick_point(pg_temp.item('b006'), true);
select public.create_space_post(pg_temp.item('a114'), pg_temp.sp(), 'announcement', 'Own note');
-- The author never gives Got it on their own announcement (migration 38, F86).
select throws_ok($$select public.ack(pg_temp.item('a114'), 'got_it')$$, '42501', null,
  'the author gives no Got it on their own announcement');
select lives_ok($$select public.delete_space_post(pg_temp.item('a113'))$$,
  'the author''s own tick doesn''t end Delete');
select lives_ok($$select public.delete_space_post(pg_temp.item('a114'))$$,
  'nor their own announcement');

-- A new version of a file ------------------------------------------------------------------------

select pg_temp.as_user('e3');
select public.ack(pg_temp.item('a104'), 'received');
select pg_temp.as_user('e4');
select public.ack(pg_temp.item('a104'), 'received');
reset role;
update public.space_members set notify = 'needs_you'
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e4');
insert into public.library_files (id, space_id, name, storage_path, mime, bytes, rev_label,
                                  supersedes_id, uploaded_by)
values (pg_temp.item('f004'), pg_temp.sp(), 'Door schedule',
        pg_temp.sp() || '/library/' || pg_temp.item('f004') || '/doors-d.pdf', 'application/pdf',
        2500000, 'Rev D', pg_temp.item('f001'), pg_temp.uid('e2'));
select pg_temp.as_user('e2');
set local role authenticated;
select lives_ok($$select public.create_space_post(pg_temp.item('a109'), pg_temp.sp(), 'file', null,
                    p_library_file => pg_temp.item('f004'))$$, 'the new version is shared');
select is((select d.card -> 'stamp' ->> 'kind' from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.id = pg_temp.item('a109')), 'new_version', 'with a NEW VERSION stamp');
select is((select d.card -> 'file' -> 'replaces' ->> 'rev_label' from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.id = pg_temp.item('a109')), 'Rev C', 'saying what it replaces');
select throws_ok($$select public.delete_library_file(pg_temp.item('f001'))$$, 'P0001', null,
  'a file a post shares stays in the Library');
reset role;
select is(pg_temp.n('e3', 'file_new_version', 'a109') + pg_temp.n('e4', 'file_new_version', 'a109'),
  2::bigint, 'whoever received the old version is told');
select is(pg_temp.q('e3', 'file_new_version'), 1::bigint, 'with a push at "everything"');
select is(pg_temp.q('e4', 'file_new_version'), 0::bigint, 'and none at "needs you"');
select pg_temp.as_user('e6');
set local role authenticated;
select is((select string_agg(name, ', ' order by name) from public.post_acks_for(pg_temp.item('a104'))),
  'Sara Ali, Vera Lane', 'anyone who can see a file post sees who received it (review 36 R1)');
select is((select count(*) from public.post_acks_for(pg_temp.item('a101'))), 0::bigint,
  'but not who got an announcement');
select pg_temp.as_user('e1');
select public.ack(pg_temp.item('a105'), 'received');
select pg_temp.as_user('e2');
select is((select count(*) from public.post_acks_for(pg_temp.item('a105'))), 0::bigint,
  'nobody outside a Team sees who received its file');
reset role;

-- Pinned, and the activity on its day ---------------------------------------------------------------

select pg_temp.as_user('e3');
set local role authenticated;
select is((select string_agg(reason, ',' order by reason) from public.daybook_extras(
             pg_temp.sp(), now() - interval '1 hour', now() + interval '23 hours')),
  'activity,pinned', 'above the list: the pinned announcement and today''s activity');
select pg_temp.as_user('e2');
select throws_ok($$select public.edit_space_post(pg_temp.item('a101'),
                    jsonb_build_object('pinned_until', now() + interval '100 days'))$$,
  '22023', null, 'pinned for 90 days at most');
select lives_ok($$select public.edit_space_post(pg_temp.item('a101'), '{"pinned_until": null}')$$,
  'the author unpins it');
select is((select count(*) from public.daybook_extras(pg_temp.sp(), now(), now() + interval '1 day')
           where reason = 'pinned'), 0::bigint, 'and it leaves the top');

-- Moving an activity tells its people and calendar adds.
select pg_temp.as_user('e3');
select lives_ok($$select public.edit_space_post(pg_temp.item('a103'), jsonb_build_object(
                    'starts_at', now() + interval '2 hours', 'ends_at', now() + interval '3 hours'))$$,
  'the author moves the activity');
reset role;
select is(pg_temp.n('e1', 'item_edited', 'a103') + pg_temp.n('e2', 'item_edited', 'a103')
          + pg_temp.n('e4', 'item_edited', 'a103'), 3::bigint,
  'its people and whoever put it in their calendar are told');
insert into public.team_members (team_id, profile_id, added_by)
values (pg_temp.team(), pg_temp.uid('e2'), pg_temp.uid('e1'));
select pg_temp.as_user('e6');
set local role authenticated;
select public.create_space_post(pg_temp.item('a120'), pg_temp.sp(), 'activity', 'MEP sleeves walk',
  p_team => pg_temp.team(), p_starts_at => now() + interval '5 hours', p_people => array[pg_temp.uid('e2')]);
reset role;
delete from public.team_members where team_id = pg_temp.team() and profile_id = pg_temp.uid('e2');
select pg_temp.as_user('e6');
set local role authenticated;
select public.edit_space_post(pg_temp.item('a120'), '{"title": "MEP sleeves walk, level 2"}');
select public.cancel_space_post(pg_temp.item('a120'));
reset role;
select is(pg_temp.n('e2', 'item_edited', 'a120') + pg_temp.n('e2', 'item_cancelled', 'a120'),
  0::bigint, 'nobody who left the Team hears of its post');

-- "Starts in 30 min" -------------------------------------------------------------------------------

select ok(not has_function_privilege('authenticated', 'public.due_activity_reminders()', 'execute'),
  'only the cron runs the reminders');
select pg_temp.as_user('e3');
set local role authenticated;
select public.create_space_post(pg_temp.item('a111'), pg_temp.sp(), 'activity', 'Pour briefing',
  p_starts_at => now() + interval '30 minutes', p_people => array[pg_temp.uid('e2'), pg_temp.uid('e4')]);
select pg_temp.as_user('e1');
select public.ack(pg_temp.item('a111'), 'in_my_calendar');
select pg_temp.as_user('e6');
select public.create_space_post(pg_temp.item('a112'), pg_temp.sp(), 'activity', 'MEP walk',
  p_team => pg_temp.team(), p_starts_at => now() + interval '28 minutes',
  p_people => array[pg_temp.uid('e6')]);
select public.create_space_post(pg_temp.item('a117'), pg_temp.sp(), 'checklist', 'MEP list',
  p_team => pg_temp.team(), p_people => array[pg_temp.uid('e6')],
  p_points => pg_temp.points(array['b009'], array['Sleeve C7']));
select pg_temp.as_user('e2');
select is((select count(*) from public.post_people where post_id = pg_temp.item('a112')), 0::bigint,
  'a member outside the Team reads no people of a Team post');
select is((select count(*) from public.checklist_points where post_id = pg_temp.item('a117')), 0::bigint,
  'nor its points');
select pg_temp.as_user('e3');
select public.create_space_post(pg_temp.item('a118'), pg_temp.sp(), 'activity', 'Called off',
  p_starts_at => now() + interval '30 minutes', p_people => array[pg_temp.uid('e2')]);
select public.cancel_space_post(pg_temp.item('a118'));
select public.create_space_post(pg_temp.item('a119'), pg_temp.sp(), 'activity', 'Lina''s walk',
  p_starts_at => now() + interval '30 minutes', p_people => array[pg_temp.uid('e7')]);
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e7');
reset role;
update public.space_members set notify = 'off'
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e4');
set local role service_role;
select is(public.due_activity_reminders(), 4, 'one push each to its people and calendar adds');
select is(public.due_activity_reminders(), 0, 'the next run sends nothing again');
reset role;
select is((select count(*) from public.activity_reminders
           where post_id in (pg_temp.item('a118'), pg_temp.item('a119'))), 0::bigint,
  'nothing for a cancelled activity or someone who left');
select is(pg_temp.q('e4', 'activity_starting'), 1::bigint, 'even with the Space set to Off');
select is((select count(*) from public.push_queue where kind = 'activity_starting'
           and data ->> 'space_post_id' = pg_temp.item('a103')::text), 0::bigint,
  'nothing for an activity two hours away');
select ok((select bool_and(data ? 'space_post_id' and data::text not like '%Pour%')
           from public.push_queue where kind = 'activity_starting'), 'ids only, no title');
update public.space_posts set starts_at = now() + interval '26 minutes' where id = pg_temp.item('a111');
set local role service_role;
select is(public.due_activity_reminders(), 3, 'a moved activity is reminded again');
reset role;
update public.space_posts set starts_at = now() - interval '2 hours', ends_at = now() - interval '1 hour'
where id = pg_temp.item('a103');
select pg_temp.as_user('e6');
set local role authenticated;
select throws_ok($$select public.ack(pg_temp.item('a103'), 'in_my_calendar')$$, 'P0001', null,
  'In my calendar not after it ended');
reset role;

-- A hidden account can't acknowledge --------------------------------------------------------------

update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('e3');
select pg_temp.as_user('e3');
set local role authenticated;
select throws_ok($$select public.ack(pg_temp.item('a111'), 'in_my_calendar')$$, '42501', null,
  'an account waiting to be deleted can''t acknowledge');
reset role;
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('e3');

-- Nobody reads or writes the tables directly ---------------------------------------------------------

select pg_temp.as_user('e5');
set local role authenticated;
select is((select count(*) from public.post_people), 0::bigint, 'a non-member reads no post people');
select is((select count(*) from public.checklist_points), 0::bigint, 'no points');
select is((select count(*) from public.post_acks), 0::bigint, 'no acknowledgements');
select throws_ok($$insert into public.post_people (post_id, profile_id)
                   values (pg_temp.item('a102'), auth.uid())$$,
  '42501', null, 'a non-member can''t write post_people');
select throws_ok($$insert into public.checklist_points (post_id, sort, text)
                   values (pg_temp.item('a102'), 9, 'x')$$,
  '42501', null, 'or checklist_points');
select throws_ok($$insert into public.post_acks (post_id, profile_id, kind)
                   values (pg_temp.item('a101'), auth.uid(), 'got_it')$$,
  '42501', null, 'or post_acks');
select throws_ok($$insert into public.activity_reminders (post_id, profile_id, starts_at)
                   values (pg_temp.item('a111'), auth.uid(), now())$$,
  '42501', null, 'or the reminders sent');
select pg_temp.as_user('e2');
select throws_ok($$update public.checklist_points set ticked_at = now() where id = pg_temp.item('b003')$$,
  '42501', null, 'members tick only through the functions');
select throws_ok($$delete from public.post_people where post_id = pg_temp.item('a102')$$,
  '42501', null, 'and change people only through them');
select throws_ok($$insert into public.post_acks (post_id, profile_id, kind)
                   values (pg_temp.item('a101'), auth.uid(), 'got_it')$$,
  '42501', null, 'and acknowledge only through them');
select throws_ok($$select count(*) from public.activity_reminders$$, '42501', null,
  'nobody but the service role reads the reminders sent');

select * from finish();
rollback;
