-- Migration 29: private Realtime channels for the daybook (N1), unpin by an
-- admin acting for a gone author (N2), my_ack_at on the post JSON (and Got it
-- again after an edit), and the note kind (F58). Run with: supabase test db
--
-- Omar (e1) made the Space and is its admin (Lead). Rakesh (e2) and Sara
-- (e3) are Crew, Vera (e4) a Viewer, Lina (e6) Crew who posts and then
-- leaves, Hana (e7) Crew who leaves, Hadi (e8) Crew whose account waits for
-- deletion, Tariq (e9) Crew in the MEP Team. Eve (e5) is not in the Space;
-- she has a Space of her own.

begin;
create extension if not exists pgtap with schema extensions;
select plan(121);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000029' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@slice2live29.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e5'), ('e6'), ('e7'), ('e8'), ('e9')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e4', 'Vera', 'Lane'), ('e5', 'Eve', 'Out'), ('e6', 'Lina', 'Khalil'),
             ('e7', 'Hana', 'Saleh'), ('e8', 'Hadi', 'Fares'), ('e9', 'Tariq', 'Aziz')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000029' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000029' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000029' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000029' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.sp_eve() returns uuid language sql as $$
  select current_setting('test.space_eve')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
create function pg_temp.card(p_item text) returns jsonb language sql as $$
  select c.card from public.daybook_cards(pg_temp.sp(), null, 100) c where c.id = pg_temp.item(p_item);
$$;
create function pg_temp.activity(p_item text) returns timestamptz language sql as $$
  select p.last_activity_at from public.space_posts p where p.id = pg_temp.item(p_item);
$$;
create function pg_temp.first_card() returns uuid language sql as $$
  select c.id from public.daybook_cards(pg_temp.sp(), null, 1) c;
$$;
-- Run as the database owner: a post's last activity goes back in time.
create function pg_temp.back(p_item text, p_minutes integer) returns void language sql as $$
  update public.space_posts set last_activity_at = now() - make_interval(mins => p_minutes)
  where id = pg_temp.item(p_item);
$$;
-- Run as the database owner: every post of the Space goes back in time.
create function pg_temp.all_back(p_minutes integer) returns void language sql as $$
  update public.space_posts set last_activity_at = now() - make_interval(mins => p_minutes)
  where space_id = pg_temp.sp();
$$;
-- Run as the database owner: the acknowledgements just made move to a time
-- of their own (a test runs in one transaction).
create function pg_temp.stamp_acks(p_who text, p_minutes_ago integer) returns void language sql as $$
  update public.post_acks set created_at = now() - make_interval(mins => p_minutes_ago)
  where profile_id = pg_temp.uid(p_who) and created_at = now();
$$;
create function pg_temp.post_path(p_item text, p_file text) returns text language sql as $$
  select pg_temp.sp() || '/posts/' || pg_temp.item(p_item) || '/' || p_file;
$$;
-- A file as the Storage API would store it. Run as the database owner.
create function pg_temp.upload(p_name text, p_owner text, p_mime text) returns void language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('space-files', p_name, pg_temp.uid(p_owner)::text,
          jsonb_build_object('mimetype', p_mime, 'size', 120000));
$$;

-- Realtime, as Realtime Authorization asks: the channel's topic is set, then
-- the caller's role selects (may receive) or inserts (may send).
create function pg_temp.topic(p_space uuid) returns text language sql as $$
  select 'daybook:' || p_space;
$$;
create function pg_temp.on_topic(p_topic text) returns void language sql as $$
  select set_config('realtime.topic', p_topic, true);
$$;
create function pg_temp.send(p_topic text, p_extension text default 'broadcast') returns void
language sql as $$
  insert into realtime.messages (topic, extension, event, payload, private)
  values (p_topic, p_extension, 'changed', jsonb_build_object('post_id', gen_random_uuid()), true);
$$;
create function pg_temp.seen(p_topic text) returns bigint language sql as $$
  select count(*) from realtime.messages where topic = p_topic;
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Live site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e3', 'crew'), ('e4', 'viewer'), ('e6', 'crew'), ('e7', 'crew'),
             ('e8', 'crew'), ('e9', 'crew')) x(id, pass);
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('e9')])::text, true);
select pg_temp.as_user('e5');
select set_config('test.space_eve', public.create_space('Eve''s site')::text, true);
reset role;

-- N1: the daybook's private channel -----------------------------------------------------------

select pg_temp.as_user('e2');
select pg_temp.on_topic(pg_temp.topic(pg_temp.sp()));
set local role authenticated;
select lives_ok($$select pg_temp.send(pg_temp.topic(pg_temp.sp()))$$,
  'a member may send on her Space''s daybook topic');
select is(pg_temp.seen(pg_temp.topic(pg_temp.sp())), 1::bigint, 'and receives on it');
select pg_temp.as_user('e4');
select is(pg_temp.seen(pg_temp.topic(pg_temp.sp())), 1::bigint, 'a Viewer receives too');
select lives_ok($$select pg_temp.send(pg_temp.topic(pg_temp.sp()))$$,
  'and may send (a Viewer acknowledges, and says so)');
select throws_ok($$select pg_temp.send(pg_temp.topic(pg_temp.sp()), 'presence')$$, '42501', null,
  'only broadcast: presence on the topic is refused');

select pg_temp.as_user('e5');
select is(pg_temp.seen(pg_temp.topic(pg_temp.sp())), 0::bigint,
  'a signed-in non-member who knows the Space id receives nothing');
select throws_ok($$select pg_temp.send(pg_temp.topic(pg_temp.sp()))$$, '42501', null,
  'and her send is refused');
reset role;
select pg_temp.on_topic(pg_temp.topic(pg_temp.sp_eve()));
select pg_temp.as_user('e5');
set local role authenticated;
select lives_ok($$select pg_temp.send(pg_temp.topic(pg_temp.sp_eve()))$$,
  'on her own Space''s topic she may send');
select is(pg_temp.seen(pg_temp.topic(pg_temp.sp_eve())), 1::bigint, 'and receive');
select is(pg_temp.seen(pg_temp.topic(pg_temp.sp())), 0::bigint,
  'but her own channel never shows another Space''s rows');
select throws_ok($$select pg_temp.send(pg_temp.topic(pg_temp.sp()))$$, '42501', null,
  'nor writes onto another Space''s topic');

-- Anything that isn't a daybook topic of a Space.
select pg_temp.as_user('e2');
reset role;
select pg_temp.on_topic('daybook:not-a-space');
set local role authenticated;
select throws_ok($$select pg_temp.send('daybook:not-a-space')$$, '42501', null,
  'a topic that isn''t a Space id is refused, without an error from the cast');
reset role;
select pg_temp.on_topic('chat:' || pg_temp.sp());
set local role authenticated;
select throws_ok($$select pg_temp.send('chat:' || pg_temp.sp())$$, '42501', null,
  'another topic of the Space has no policy, so it is refused');
select ok(not public.may_use_daybook_topic(null), 'no topic is no channel');

-- Signed out.
reset role;
select pg_temp.on_topic(pg_temp.topic(pg_temp.sp()));
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select is(pg_temp.seen(pg_temp.topic(pg_temp.sp())), 0::bigint, 'anon receives nothing');
select throws_ok($$select pg_temp.send(pg_temp.topic(pg_temp.sp()))$$, '42501', null,
  'and can''t send');
reset role;

-- A former member.
select pg_temp.as_user('e7');
set local role authenticated;
select is(pg_temp.seen(pg_temp.topic(pg_temp.sp())), 2::bigint, 'Hana, while in the Space, receives');
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e7');
set local role authenticated;
select is(pg_temp.seen(pg_temp.topic(pg_temp.sp())), 0::bigint, 'once she left, nothing');
select throws_ok($$select pg_temp.send(pg_temp.topic(pg_temp.sp()))$$, '42501', null,
  'and her send is refused');

-- Hidden and blocking: the channel follows the Space's read rule exactly.
reset role;
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('e8');
select pg_temp.as_user('e8');
set local role authenticated;
select is(pg_temp.seen(pg_temp.topic(pg_temp.sp())) > 0, public.is_member(pg_temp.sp()),
  'an account waiting for deletion receives exactly when it may read the Space');
select is(pg_temp.seen(pg_temp.topic(pg_temp.sp())) > 0,
          exists (select 1 from public.spaces s where s.id = pg_temp.sp()),
  'the same answer as the Space row''s own policy');
select pg_temp.as_user('e3');
select public.block(pg_temp.uid('e2'), true);
select is(pg_temp.seen(pg_temp.topic(pg_temp.sp())), 2::bigint,
  'a block between members changes nothing (Space reading ignores it too)');
select pg_temp.as_user('e2');
select lives_ok($$select pg_temp.send(pg_temp.topic(pg_temp.sp()))$$,
  'and the blocked member still signals the Space');
select pg_temp.as_user('e3');
select public.block(pg_temp.uid('e2'), false);
reset role;
select ok(not has_function_privilege('anon', 'public.may_use_daybook_topic(text)', 'execute')
          and has_function_privilege('authenticated', 'public.may_use_daybook_topic(text)', 'execute'),
  'the topic test runs for signed-in people only');

-- N2: unpin by an admin acting for a gone author -----------------------------------------------

select pg_temp.as_user('e6');
set local role authenticated;
select lives_ok($$select public.create_space_post(pg_temp.item('a101'), pg_temp.sp(), 'announcement',
                    'Crane on site Thursday', 'Keep the north gate clear.',
                    p_pinned_until => now() + interval '7 days')$$,
  'Lina pins an announcement');
select pg_temp.as_user('e1');
select throws_ok($$select public.edit_space_post(pg_temp.item('a101'), '{"pinned_until": null}')$$,
  '42501', null, 'while Lina is in the Space, the admin can''t unpin it');
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e6');
select pg_temp.as_user('e2');
set local role authenticated;
select throws_ok($$select public.edit_space_post(pg_temp.item('a101'), '{"pinned_until": null}')$$,
  '42501', null, 'Lina left: an ordinary member still can''t unpin');
select pg_temp.as_user('e1');
select throws_ok($$select public.edit_space_post(pg_temp.item('a101'), '{"title": "Crane on Friday"}')$$,
  '42501', null, 'the acting admin can''t edit her words');
select throws_ok($$select public.edit_space_post(pg_temp.item('a101'),
                     '{"pinned_until": null, "body": "Gate open."}')$$,
  '42501', null, 'not even together with the unpin');
select throws_ok(format($$select public.edit_space_post(pg_temp.item('a101'), %L)$$,
                        jsonb_build_object('pinned_until', now() + interval '30 days')),
  '42501', null, 'nor pin it for longer');
select lives_ok($$select public.edit_space_post(pg_temp.item('a101'), '{"pinned_until": null}')$$,
  'the acting admin unpins it');
reset role;
select is((select pinned_until from public.space_posts where id = pg_temp.item('a101')), null,
  'it is no longer pinned');
select is((select author_id from public.space_posts where id = pg_temp.item('a101')), pg_temp.uid('e6'),
  'Lina is still its author');
select is((select title || ' / ' || body from public.space_posts where id = pg_temp.item('a101')),
  'Crane on site Thursday / Keep the north gate clear.', 'and its words are hers');
select is((select e.editor_id from public.post_edits e where e.post_id = pg_temp.item('a101')),
  pg_temp.uid('e1'), 'the unpin is on the record as the admin''s');
select pg_temp.as_user('e2');
set local role authenticated;
select ok(not exists (select 1 from public.daybook_extras(pg_temp.sp(), now() - interval '1 day',
                                                           now() + interval '1 day') x
                      where x.id = pg_temp.item('a101')),
  'it left the top of the daybook');
select is(pg_temp.card('a101') ->> 'status', 'live', 'and is an ordinary card on its day');

-- my_ack_at --------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
select lives_ok($$select public.create_space_post(pg_temp.item('a201'), pg_temp.sp(), 'announcement',
                    'Safety walk at 7', p_pinned_until => now() + interval '3 days')$$,
  'Omar pins an announcement');
select lives_ok($$select public.create_space_post(pg_temp.item('a202'), pg_temp.sp(), 'activity',
                    'Concrete pour', p_starts_at => now() + interval '1 hour')$$,
  'and schedules an activity');
select pg_temp.as_user('e2');
select public.ack(pg_temp.item('a201'), 'got_it');
reset role;
select pg_temp.stamp_acks('e2', 40);
select pg_temp.as_user('e3');
set local role authenticated;
select public.ack(pg_temp.item('a201'), 'got_it');
reset role;
select pg_temp.stamp_acks('e3', 20);

select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.card('a201') -> 'my_ack_at',
          jsonb_build_object('got_it', now() - interval '40 minutes'),
  'Rakesh''s card has the time he gave Got it');
select is(pg_temp.card('a201') -> 'my_acks', '["got_it"]'::jsonb, 'my_acks is unchanged');
select pg_temp.as_user('e3');
select is(pg_temp.card('a201') -> 'my_ack_at',
          jsonb_build_object('got_it', now() - interval '20 minutes'),
  'Sara sees only her own time, never Rakesh''s');
select pg_temp.as_user('e4');
select is(pg_temp.card('a201') -> 'my_ack_at', '{}'::jsonb, 'with none given, an empty object');
select is(pg_temp.card('a201') -> 'my_acks', null, 'and my_acks stays absent, as before');
select pg_temp.as_user('e1');
select is(pg_temp.card('a201') -> 'my_ack_at', '{}'::jsonb,
  'the author too sees only his own, not his crew''s times');
select pg_temp.as_user('e2');
select public.ack(pg_temp.item('a202'), 'in_my_calendar');
select public.ack(pg_temp.item('a202'), 'on_my_way');
select is((select array_agg(k order by k) from jsonb_object_keys(pg_temp.card('a202') -> 'my_ack_at') k),
  array['in_my_calendar', 'on_my_way'], 'one key per kind given');
select is((public.post_page(pg_temp.item('a201')) -> 'my_ack_at' ->> 'got_it')::timestamptz,
  now() - interval '40 minutes', 'the opened post carries it too');
select is((select (x.post -> 'my_ack_at' ->> 'got_it')::timestamptz
           from public.daybook_extras(pg_temp.sp(), now() - interval '1 day', now() + interval '1 day') x
           where x.id = pg_temp.item('a201')),
  now() - interval '40 minutes', 'and so does the pinned announcement above the list');

-- Got it again: no change without an edit; the new time after one (review 61 G1).
select pg_temp.as_user('e3');
select public.ack(pg_temp.item('a201'), 'got_it');
select is((pg_temp.card('a201') -> 'my_ack_at' ->> 'got_it')::timestamptz, now() - interval '20 minutes',
  'tapping Got it again, with no edit since, keeps the time');
select pg_temp.as_user('e1');
select public.edit_space_post(pg_temp.item('a201'), '{"body": "Hard hats and boots."}');
select pg_temp.as_user('e2');
select ok((pg_temp.card('a201') -> 'my_ack_at' ->> 'got_it')::timestamptz
          < (pg_temp.card('a201') ->> 'edited_at')::timestamptz,
  'after the edit, Rakesh''s Got it is older than the edit, so it opens again');
select public.ack(pg_temp.item('a201'), 'got_it');
select ok((pg_temp.card('a201') -> 'my_ack_at' ->> 'got_it')::timestamptz
          >= (pg_temp.card('a201') ->> 'edited_at')::timestamptz,
  'Got it again takes the new time');
select is((select count(*) from public.post_acks
           where post_id = pg_temp.item('a201') and profile_id = pg_temp.uid('e2')), 1::bigint,
  'still one acknowledgement');
select pg_temp.as_user('e3');
select is((pg_temp.card('a201') -> 'my_ack_at' ->> 'got_it')::timestamptz, now() - interval '20 minutes',
  'Sara''s time stays until she taps it again');
select pg_temp.as_user('e2');
select public.ack(pg_temp.item('a201'), 'got_it', false);
select is(pg_temp.card('a201') -> 'my_ack_at', '{}'::jsonb, 'taken back, it leaves my_ack_at');

-- The note kind -----------------------------------------------------------------------------------

reset role;
select pg_temp.all_back(60);
select pg_temp.upload(pg_temp.post_path('a301', 'wall.jpg'), 'e2', 'image/jpeg');
select pg_temp.upload(pg_temp.post_path('a301', 'letter.pdf'), 'e2', 'application/pdf');
select pg_temp.as_user('e2');
set local role authenticated;
select lives_ok(format($$select public.create_space_post(pg_temp.item('a301'), pg_temp.sp(), 'note',
                    'Water on level 2', 'The tank overflowed overnight; it is drying.',
                    p_files => %L)$$,
                    jsonb_build_array(jsonb_build_object('path', pg_temp.post_path('a301', 'wall.jpg')),
                                      jsonb_build_object('path', pg_temp.post_path('a301', 'letter.pdf')))),
  'Rakesh posts a note with a photo and a PDF');
select is(pg_temp.card('a301') ->> 'kind', 'note', 'it is a note');
select is((select count(*) from public.post_files where post_id = pg_temp.item('a301')), 2::bigint,
  'with its two files');
select is(pg_temp.card('a301') ->> 'cover_path', pg_temp.post_path('a301', 'wall.jpg'),
  'the photo is its cover');
select is(pg_temp.first_card(), pg_temp.item('a301'), 'its card is at Now');
select is(pg_temp.activity('a301'), now(), 'its last activity is when it was made');
select is(pg_temp.card('a301') -> 'needs_me', 'null'::jsonb, 'a note never needs you');
select is(pg_temp.card('a301') -> 'my_ack_at', '{}'::jsonb, 'and has no acknowledgements');
select is(public.create_space_post(pg_temp.item('a301'), pg_temp.sp(), 'note', 'Water on level 2'),
  pg_temp.item('a301'), 'a retry with the same id is the same note');
select lives_ok($$select public.create_space_post(pg_temp.item('a302'), pg_temp.sp(), 'note',
                    'Gate code changed')$$, 'a note with a title only');
reset role;
select ok(not exists (select 1 from public.notifications n
                      where n.space_post_id in (pg_temp.item('a301'), pg_temp.item('a302'))),
  'a note tells nobody');
set local role authenticated;

-- What a note doesn't take.
select throws_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'For Sara',
                     p_people => array[pg_temp.uid('e3')])$$, '22023', null, 'no people');
select throws_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'Points',
                     p_points => '[{"text": "One"}]')$$, '22023', null, 'no points');
select throws_ok(format($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'Pin',
                     p_pinned_until => %L)$$, now() + interval '1 day'), '22023', null, 'no pin');
select throws_ok(format($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'At',
                     p_starts_at => %L)$$, now() + interval '1 day'), '22023', null, 'no times');
select throws_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'File',
                     p_library_file => gen_random_uuid())$$, '22023', null, 'no Library file');
select throws_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'Where',
                     p_place => 'Level 2')$$, '22023', null, 'no place');
select throws_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'When',
                     p_due => current_date)$$, '22023', null, 'no due date');
select throws_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', '  ')$$,
  '22023', null, 'a title, as every post');
select throws_ok($$select public.ack(pg_temp.item('a301'), 'got_it')$$, '22023', null,
  'no Got it on a note');
select throws_ok($$select public.ack(pg_temp.item('a301'), 'received')$$, '22023', null,
  'nor any other acknowledgement');
select pg_temp.as_user('e4');
select throws_ok($$select public.create_space_post(gen_random_uuid(), pg_temp.sp(), 'note', 'Viewer')$$,
  '42501', null, 'a Viewer can''t post a note');
select throws_ok($$select public.ack(pg_temp.item('a302'), 'got_it')$$, '22023', null,
  'and can''t acknowledge one either');
select is(pg_temp.card('a301') ->> 'title', 'Water on level 2', 'but reads it');

-- Edit, as an announcement.
reset role;
select pg_temp.all_back(60);
select pg_temp.back('a301', 30);
select pg_temp.as_user('e2');
set local role authenticated;
select lives_ok($$select public.edit_space_post(pg_temp.item('a301'),
                    '{"title": "Water on level 2 (dry now)", "body": "Dried by noon."}')$$,
  'Rakesh edits his note');
select is(pg_temp.activity('a301'), now(), 'the edit raises its last activity');
select is(pg_temp.first_card(), pg_temp.item('a301'), 'so the card moves to Now');
select is((select h ->> 'kind' from jsonb_array_elements(pg_temp.card('a301') -> 'history') h limit 1),
  'edited', 'the edit is a line in its history');
select is((select count(*) from public.post_history(pg_temp.item('a301')) h
           where h.event ->> 'kind' = 'edited'), 1::bigint, 'and in post_history');
select throws_ok(format($$select public.edit_space_post(pg_temp.item('a301'), %L)$$,
                        jsonb_build_object('pinned_until', now() + interval '1 day')),
  '22023', null, 'a note can''t be pinned by an edit');
select throws_ok($$select public.edit_space_post(pg_temp.item('a301'), '{"place": "Level 2"}')$$,
  '22023', null, 'nor given a place');
select throws_ok(format($$select public.edit_space_post(pg_temp.item('a301'), %L)$$,
                        jsonb_build_object('people', jsonb_build_object('add', array[pg_temp.uid('e3')]))),
  '22023', null, 'nor people');
select throws_ok($$select public.edit_space_post(pg_temp.item('a301'), '{"points": {"add": [{"text": "x"}]}}')$$,
  '22023', null, 'nor points');
select pg_temp.as_user('e3');
select throws_ok($$select public.edit_space_post(pg_temp.item('a301'), '{"title": "Mine now"}')$$,
  '42501', null, 'another member can''t edit it');
select ok(exists (select 1 from public.search_space(pg_temp.sp(), 'dried') s
                  where pg_temp.item('a301') in (s.id, s.post_id) and s.post_kind = 'note'),
  'Space search finds it');

-- Who sees a note.
select pg_temp.as_user('e9');
select lives_ok($$select public.create_space_post(pg_temp.item('a303'), pg_temp.sp(), 'note',
                    'Panel B is live', p_team => pg_temp.team())$$, 'Tariq posts a note to the MEP Team');
select pg_temp.as_user('e3');
select is(pg_temp.card('a303'), null, 'Sara, outside the Team, doesn''t see it');
select pg_temp.as_user('e1');
select is(pg_temp.card('a303') ->> 'kind', 'note', 'the Space admin does');
select pg_temp.as_user('e5');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100)), 0::bigint,
  'a non-member reads no cards');
select is((select count(*) from public.space_posts where id = pg_temp.item('a301')), 0::bigint,
  'nor the note''s row');
select is((select count(*) from public.post_history(pg_temp.item('a301'))), 0::bigint,
  'nor its history');
select is(public.post_page(pg_temp.item('a301')), null, 'nor the opened note');
select is((select count(*) from public.post_files where post_id = pg_temp.item('a301')), 0::bigint,
  'nor its files');
select pg_temp.as_user('e7');
select is((select count(*) from public.space_posts where id = pg_temp.item('a301')), 0::bigint,
  'a former member doesn''t read it either');

-- Cancel and delete, as an announcement.
select pg_temp.as_user('e3');
select throws_ok($$select public.cancel_space_post(pg_temp.item('a301'))$$, '42501', null,
  'another member can''t cancel it');
select throws_ok($$select public.delete_space_post(pg_temp.item('a302'))$$, '42501', null,
  'nor delete it');
select pg_temp.as_user('e2');
select lives_ok($$select public.cancel_space_post(pg_temp.item('a301'), 'Posted twice')$$,
  'Rakesh cancels his note');
select is(pg_temp.card('a301') -> 'stamp' ->> 'kind', 'cancelled', 'it stays with a CANCELLED stamp');
select throws_ok($$select public.edit_space_post(pg_temp.item('a301'), '{"title": "Again"}')$$,
  'P0001', null, 'and can no longer be edited');
select lives_ok($$select public.delete_space_post(pg_temp.item('a302'))$$,
  'his other note, with nothing added by anyone, can be deleted');
select is(pg_temp.card('a302'), null, 'and leaves the daybook');

-- A note whose author left: the admin cancels it but never edits it.
reset role;
update public.space_members set left_at = null
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e6');
select pg_temp.as_user('e6');
set local role authenticated;
select public.create_space_post(pg_temp.item('a304'), pg_temp.sp(), 'note', 'Keys with the guard');
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e6');
select pg_temp.as_user('e1');
set local role authenticated;
select throws_ok($$select public.edit_space_post(pg_temp.item('a304'), '{"pinned_until": null}')$$,
  '42501', null, 'the unpin path is for announcements only');
select throws_ok($$select public.edit_space_post(pg_temp.item('a304'), '{"title": "Keys at the office"}')$$,
  '42501', null, 'the acting admin can''t edit a gone author''s note');
select lives_ok($$select public.cancel_space_post(pg_temp.item('a304'))$$, 'but can cancel it');

-- Review 63 R1: a chat thread's private channel --------------------------------------------------

reset role;
select set_config('test.thread', (select id from public.threads
  where space_id = pg_temp.sp() and team_id is null)::text, true);
select set_config('test.team_thread', (select id from public.threads
  where team_id = pg_temp.team())::text, true);
-- One row on each topic, as the database owner (Realtime writes them).
insert into realtime.messages (topic, extension, event, payload, private)
values ('thread:' || current_setting('test.thread'), 'broadcast', 'x', '{}', true),
       ('thread:' || current_setting('test.team_thread'), 'broadcast', 'x', '{}', true);
create function pg_temp.thread_seen(p_who text, p_setting text) returns bigint language plpgsql as $$
begin
  perform pg_temp.on_topic('thread:' || current_setting(p_setting));
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  return pg_temp.seen('thread:' || current_setting(p_setting));
end;
$$;

select is(pg_temp.thread_seen('e2', 'test.thread'), 1::bigint,
  'a member may join the Space''s Everyone thread channel');
reset role;
select is(pg_temp.thread_seen('e2', 'test.team_thread'), 0::bigint,
  'but not a Team thread she isn''t in');
reset role;
select is(pg_temp.thread_seen('e9', 'test.team_thread'), 1::bigint, 'the Team''s member may');
reset role;
select is(pg_temp.thread_seen('e1', 'test.team_thread'), 1::bigint,
  'and so may the Space admin, as can_use_thread');
reset role;
select is(pg_temp.thread_seen('e5', 'test.thread'), 0::bigint,
  'a signed-in non-member who knows the thread id gets nothing');
reset role;
select is(pg_temp.thread_seen('e7', 'test.thread'), 0::bigint, 'nor does someone who left');
reset role;
select pg_temp.on_topic('thread:' || current_setting('test.thread'));
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select is(pg_temp.seen('thread:' || current_setting('test.thread')), 0::bigint, 'nor anon');
reset role;
select pg_temp.on_topic('thread:' || current_setting('test.thread'));
select pg_temp.as_user('e2');
set local role authenticated;
select throws_ok($$select pg_temp.send('thread:' || current_setting('test.thread'))$$, '42501', null,
  'receive only: nobody sends on a thread''s channel');
select ok(not public.may_use_thread_topic('thread:not-a-thread')
          and not public.may_use_thread_topic(null)
          and not public.may_use_thread_topic('thread:' || gen_random_uuid()),
  'a topic that isn''t a thread is refused, without an error from the cast');
reset role;
select ok(not has_function_privilege('anon', 'public.may_use_thread_topic(text)', 'execute')
          and has_function_privilege('authenticated', 'public.may_use_thread_topic(text)', 'execute'),
  'the thread topic test runs for signed-in people only');

-- Review 63 R2: Received keeps its first time -------------------------------------------------

insert into public.library_files (id, space_id, team_id, name, storage_path, mime, bytes,
                                  rev_label, uploaded_by)
values (pg_temp.item('f501'), pg_temp.sp(), null, 'Door schedule',
        pg_temp.sp() || '/library/' || pg_temp.item('f501') || '/d.pdf', 'application/pdf', 1000,
        'Rev D', pg_temp.uid('e1'));
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.create_space_post(pg_temp.item('a501'), pg_temp.sp(), 'file', null,
                    p_library_file => pg_temp.item('f501'))$$, 'Omar shares a document for receipt');
select pg_temp.as_user('e3');
select public.ack(pg_temp.item('a501'), 'received');
reset role;
select pg_temp.stamp_acks('e3', 30);
update public.space_posts set created_at = now() - interval '40 minutes' where id = pg_temp.item('a501');
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.edit_space_post(pg_temp.item('a501'), '{"title": "Door schedule, Rev D"}')$$,
  'Omar fixes its title after Sara received it');
select pg_temp.as_user('e3');
select public.ack(pg_temp.item('a501'), 'received');
reset role;
select is((select created_at < now() - interval '20 minutes' from public.post_acks
           where post_id = pg_temp.item('a501') and profile_id = pg_temp.uid('e3') and kind = 'received'),
  true, 'Received again after the edit keeps the first time');

select * from finish();
rollback;
