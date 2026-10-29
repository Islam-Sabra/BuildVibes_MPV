-- Migration 9: Space chat and Library. Run with: supabase test db
--
-- Omar (a1) is the admin. Rakesh (a2) is Crew and in the MEP Team. Sara
-- (a3) is Lead but not in the Team. Nadia (a4) is a Viewer. Eve (a5) is
-- not a member.

begin;
create extension if not exists pgtap with schema extensions;
select plan(67);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000009a1', 'authenticated', 'authenticated', 'omar9@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000009a2', 'authenticated', 'authenticated', 'rakesh9@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000009a3', 'authenticated', 'authenticated', 'sara9@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000009a4', 'authenticated', 'authenticated', 'nadia9@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000009a5', 'authenticated', 'authenticated', 'eve9@example.com', '{"home_market_id": "kw"}');

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000009' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000009' || p_id)::uuid;
$$;
create function pg_temp.id(p_hex text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000' || p_hex)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.chat(p_msg text, p_file text) returns text language sql as $$
  select current_setting('test.space') || '/chat/' || pg_temp.id(p_msg)::text || '/' || p_file;
$$;
create function pg_temp.lib(p_file_id text, p_file text) returns text language sql as $$
  select current_setting('test.space') || '/library/' || pg_temp.id(p_file_id)::text || '/' || p_file;
$$;
create function pg_temp.everyone() returns uuid language sql as $$
  select t.id from public.threads t where t.space_id = pg_temp.sp() and t.team_id is null;
$$;
create function pg_temp.team_thread() returns uuid language sql as $$
  select t.id from public.threads t where t.team_id = current_setting('test.team')::uuid;
$$;

-- Setup -------------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Site team')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (pg_temp.sp(), pg_temp.uid('a2'), 'crew', pg_temp.uid('a1')),
  (pg_temp.sp(), pg_temp.uid('a3'), 'lead', pg_temp.uid('a1')),
  (pg_temp.sp(), pg_temp.uid('a4'), 'viewer', pg_temp.uid('a1'));
select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.team',
  public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('a2')])::text, true);
reset role;

select ok(pg_temp.everyone() is not null, 'a new Space gets its Everyone thread');
select ok(pg_temp.team_thread() is not null, 'a new Team gets its own thread');

-- Uploads already in storage, each with its uploader.
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('space-files', pg_temp.chat('c0000001', 'site.jpg'), pg_temp.uid('a2')::text, '{"size": 1000}'),
  ('space-files', pg_temp.chat('c0000002', 'level3.pdf'), pg_temp.uid('a2')::text, '{"size": 5000}'),
  ('space-files', pg_temp.chat('c0000003', 'mine.jpg'), pg_temp.uid('a4')::text, '{"size": 1000}'),
  ('space-files', pg_temp.chat('c0000004', 'omars.jpg'), pg_temp.uid('a1')::text, '{"size": 1000}'),
  ('space-files', pg_temp.lib('f0000001', 'revB.pdf'), pg_temp.uid('a2')::text, '{"size": 9000}'),
  ('space-files', pg_temp.lib('f0000002', 'revC.pdf'), pg_temp.uid('a2')::text, '{"size": 9000}'),
  ('space-files', pg_temp.lib('f0000003', 'nadia.pdf'), pg_temp.uid('a4')::text, '{"size": 9000}'),
  ('space-files', pg_temp.lib('f0000004', 'mep.pdf'), pg_temp.uid('a1')::text, '{"size": 9000}'),
  ('space-files', pg_temp.lib('f0000005', 'sara.pdf'), pg_temp.uid('a3')::text, '{"size": 9000}'),
  ('space-files', pg_temp.chat('c0000006', 'fake.pdf'), pg_temp.uid('a2')::text,
   '{"size": 1000, "mimetype": "image/jpeg"}'),
  ('space-files', pg_temp.lib('f0000006', 'everyone.pdf'), pg_temp.uid('a1')::text, '{"size": 9000}'),
  ('space-files', current_setting('test.space') || '/' || pg_temp.id('e0000003')::text || '/raised.jpg',
   pg_temp.uid('a1')::text, '{"size": 1000}'),
  ('space-files', current_setting('test.space') || '/' || pg_temp.id('e0000004')::text || '/d.jpg',
   pg_temp.uid('a1')::text, '{"size": 1000, "mimetype": "application/pdf"}'),
  ('space-files', current_setting('test.space') || '/' || pg_temp.id('e0000001')::text || '/raised.jpg',
   pg_temp.uid('a1')::text, '{"size": 1000}'),
  ('space-files', current_setting('test.space') || '/' || pg_temp.id('e0000002')::text || '/raised.jpg',
   pg_temp.uid('a1')::text, '{"size": 1000}');

-- Who sees which thread -----------------------------------------------------------------------

select pg_temp.as_user('a5');
set local role authenticated;
select is((select count(*) from public.threads), 0::bigint, 'a non-member sees no threads');
select throws_ok(
  format($$select public.post_message(%L, %L, 'hello')$$, pg_temp.id('b0000001'), pg_temp.everyone()),
  '42501', null, 'a non-member cannot post');
select is((select count(*) from public.space_threads(pg_temp.sp())), 0::bigint,
  'a non-member gets no thread list');

reset role;
select pg_temp.as_user('a3');
set local role authenticated;
select is((select count(*) from public.threads), 1::bigint,
  'a member outside the Team sees only Everyone');
select throws_ok(
  format($$select public.post_message(%L, %L, 'hi')$$, pg_temp.id('b0000002'), pg_temp.team_thread()),
  '42501', null, 'a member outside the Team cannot post in its thread');

reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select is((select count(*) from public.threads), 2::bigint, 'an admin sees every thread');

-- Posting --------------------------------------------------------------------------------------

reset role;
select pg_temp.as_user('a2');
set local role authenticated;
select is(public.post_message(pg_temp.id('a0000001'), pg_temp.team_thread(), 'Sleeves fixed at C7'),
  pg_temp.id('a0000001'), 'a Team member posts in the Team thread');
select is(public.post_message(pg_temp.id('a0000001'), pg_temp.team_thread(), 'Sleeves fixed at C7'),
  pg_temp.id('a0000001'), 'a retry with the same id returns the same message');
select is((select count(*) from public.messages where id = pg_temp.id('a0000001')), 1::bigint,
  'and posts it only once');
select throws_ok(
  format($$select public.post_message(%L, %L, '   ')$$, pg_temp.id('a0000009'), pg_temp.everyone()),
  '22023', null, 'an empty message is refused');
select is(
  public.post_message(pg_temp.id('c0000001'), pg_temp.everyone(), null, null,
    jsonb_build_array(jsonb_build_object('path', pg_temp.chat('c0000001', 'site.jpg'),
                                         'mime', 'image/jpeg', 'bytes', 1000))),
  pg_temp.id('c0000001'), 'Crew posts a photo they uploaded');
select is((select kind from public.messages where id = pg_temp.id('c0000001')), 'photo',
  'a message with images is a photo message');
select throws_ok(
  format($$select public.post_message(%L, %L, null, null, %L::jsonb)$$,
    pg_temp.id('c0000004'), pg_temp.everyone(),
    jsonb_build_array(jsonb_build_object('path', pg_temp.chat('c0000004', 'omars.jpg'),
                                         'mime', 'image/jpeg'))::text),
  '22023', null, 'someone else''s upload cannot be attached');
select throws_ok(
  format($$select public.post_message(%L, %L, null, null, %L::jsonb)$$,
    pg_temp.id('c0000005'), pg_temp.everyone(),
    jsonb_build_array(jsonb_build_object('path', pg_temp.chat('c0000005', 'never.jpg'),
                                         'mime', 'image/jpeg'))::text),
  '22023', null, 'a file that was never uploaded is refused');
select throws_ok(
  format($$select public.post_message(%L, %L, 'reply', %L)$$,
    pg_temp.id('a0000002'), pg_temp.everyone(), pg_temp.id('a0000001')),
  '22023', null, 'a reply must be to a message in the same thread');
select is(
  public.post_message(pg_temp.id('c0000002'), pg_temp.team_thread(), 'Rev C', null,
    jsonb_build_array(jsonb_build_object('path', pg_temp.chat('c0000002', 'level3.pdf'),
                                         'mime', 'application/pdf', 'bytes', 5000,
                                         'name', 'Level 3 beam schedule Rev C.pdf'))),
  pg_temp.id('c0000002'), 'Crew shares a drawing in the Team thread');
select is(
  (select name || '/' || source || '/' || (team_id::text = current_setting('test.team'))::text
   from public.library_files where source_message_id = pg_temp.id('c0000002')),
  'Level 3 beam schedule Rev C.pdf/chat/true',
  'a document shared in chat goes to the Library, for that Team');
select ok(not public.may_upload(pg_temp.chat('c0000002', 'more.jpg')),
  'nothing more can be uploaded to a message already posted');
select ok(public.may_upload(pg_temp.chat('c0000099', 'new.jpg')),
  'a new message folder is open to its sender');
select is((select files from public.loose_uploads()), 3::bigint,
  'files used by messages are not counted as loose uploads (two Library files and one unsent)');

reset role;
select pg_temp.as_user('a3');
set local role authenticated;
select throws_ok(
  format($$select public.post_message(%L, %L, 'stolen id')$$, pg_temp.id('a0000001'), pg_temp.everyone()),
  '42501', null, 'nobody can post with someone else''s message id');
select is((select count(*) from public.messages where thread_id = pg_temp.team_thread()), 0::bigint,
  'a member outside the Team reads none of its messages');
select is((select count(*) from public.library_files), 0::bigint,
  'and none of its Library files');
select ok(not public.may_read_file(pg_temp.chat('c0000002', 'level3.pdf'), pg_temp.uid('a2')::text),
  'and cannot open its chat files');
select ok(public.may_read_file(pg_temp.chat('c0000001', 'site.jpg'), pg_temp.uid('a2')::text),
  'but can open photos posted to Everyone');

-- Viewers chat in text only.
reset role;
select pg_temp.as_user('a4');
set local role authenticated;
select lives_ok(
  format($$select public.post_message(%L, %L, 'Client will visit Friday')$$,
    pg_temp.id('a0000003'), pg_temp.everyone()),
  'a Viewer can chat');
select throws_ok(
  format($$select public.post_message(%L, %L, null, null, %L::jsonb)$$,
    pg_temp.id('c0000003'), pg_temp.everyone(),
    jsonb_build_array(jsonb_build_object('path', pg_temp.chat('c0000003', 'mine.jpg'),
                                         'mime', 'image/jpeg'))::text),
  '42501', null, 'a Viewer cannot post files');
select ok(not public.may_upload(pg_temp.chat('c0000098', 'x.jpg')),
  'a Viewer cannot upload chat files');

-- Outsider and files.
reset role;
select pg_temp.as_user('a5');
set local role authenticated;
select ok(not public.may_read_file(pg_temp.chat('c0000001', 'site.jpg'), pg_temp.uid('a2')::text),
  'a non-member cannot open chat photos');

-- Deleting ---------------------------------------------------------------------------------------

reset role;
select pg_temp.as_user('a3');
set local role authenticated;
select throws_ok(
  format($$select public.delete_message(%L)$$, pg_temp.id('c0000001')),
  '42501', null, 'a member cannot delete someone else''s message');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok(format($$select public.delete_message(%L)$$, pg_temp.id('c0000001')),
  'an admin can delete a message');
select is((select coalesce(body, '') || '/' || (deleted_at is not null)::text
           from public.messages where id = pg_temp.id('c0000001')),
  '/true', 'it stays as "Message deleted", with no text');
select is((select count(*) from public.message_attachments
           where message_id = pg_temp.id('c0000001')), 0::bigint,
  'and its files are hidden');
reset role;
select pg_temp.as_user('a3');
set local role authenticated;
select ok(not public.may_read_file(pg_temp.chat('c0000001', 'site.jpg'), pg_temp.uid('a2')::text),
  'a deleted message''s photo cannot be opened');

-- Library -----------------------------------------------------------------------------------------

reset role;
select pg_temp.as_user('a2');
set local role authenticated;
select lives_ok(
  format($$select public.add_library_file(%L, %L, 'Level 3 beam schedule', %L, 'application/pdf', 9000, null, 'Rev B')$$,
    pg_temp.id('f0000001'), pg_temp.sp(), pg_temp.lib('f0000001', 'revB.pdf')),
  'Crew adds a file to the Library');
select lives_ok(
  format($$select public.add_library_file(%L, %L, 'Level 3 beam schedule', %L, 'application/pdf', 9000, null, 'Rev C', 'Beams B3-12 to B3-15', %L)$$,
    pg_temp.id('f0000002'), pg_temp.sp(), pg_temp.lib('f0000002', 'revC.pdf'), pg_temp.id('f0000001')),
  'a new revision supersedes the old one, which is kept');
select throws_ok(
  format($$select public.add_library_file(%L, %L, 'Again', %L, 'application/pdf')$$,
    pg_temp.id('f0000002'), pg_temp.sp(), pg_temp.lib('f0000002', 'revC.pdf')),
  '22023', null, 'a file id cannot be used twice');
reset role;
select pg_temp.as_user('a4');
set local role authenticated;
select throws_ok(
  format($$select public.add_library_file(%L, %L, 'Mine', %L, 'application/pdf')$$,
    pg_temp.id('f0000003'), pg_temp.sp(), pg_temp.lib('f0000003', 'nadia.pdf')),
  '42501', null, 'a Viewer cannot add Library files');
select is((select count(*) from public.library_files), 2::bigint,
  'a Viewer reads the Everyone files (not the Team''s)');
reset role;
select pg_temp.as_user('a3');
set local role authenticated;
select throws_ok(
  format($$select public.add_library_file(%L, %L, 'MEP only', %L, 'application/pdf', null, %L)$$,
    pg_temp.id('f0000005'), pg_temp.sp(), pg_temp.lib('f0000005', 'sara.pdf'), current_setting('test.team')),
  '42501', null, 'someone outside a Team cannot add files to it');

-- Work item cards and attachments -----------------------------------------------------------------

reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok(
  format($$select public.add_library_file(%L, %L, 'MEP layout', %L, 'application/pdf', null, %L)$$,
    pg_temp.id('f0000004'), pg_temp.sp(), pg_temp.lib('f0000004', 'mep.pdf'), current_setting('test.team')),
  'an admin adds a Team file');
select lives_ok(
  format($$select public.create_work_item(%L, 'Sleeves at grid C7', %L, null, %L, 'Grid C7', %L::jsonb, %L)$$,
    pg_temp.sp(), pg_temp.uid('a2'), current_setting('test.team'),
    jsonb_build_array(jsonb_build_object('path',
      current_setting('test.space') || '/' || pg_temp.id('e0000001')::text || '/raised.jpg'))::text,
    pg_temp.id('e0000001')),
  'an admin raises a Team work item');
select is((select count(*) from public.messages
           where kind = 'work_item' or work_item_id = pg_temp.id('e0000001')), 0::bigint,
  'raising it no longer posts a card in chat');
select lives_ok(
  format($$select public.create_work_item(%L, 'Gate 3 access', %L, null, null, 'Gate 3', %L::jsonb, %L)$$,
    pg_temp.sp(), pg_temp.uid('a2'),
    jsonb_build_array(jsonb_build_object('path',
      current_setting('test.space') || '/' || pg_temp.id('e0000002')::text || '/raised.jpg'))::text,
    pg_temp.id('e0000002')),
  'and an item for the whole Space');
select is((select count(*) from public.messages
           where kind = 'work_item' or work_item_id = pg_temp.id('e0000002')), 0::bigint,
  'nor does an item without a Team');
-- Cards posted before migration 18 stay in chat; put one in directly.
reset role;
insert into public.messages (id, thread_id, space_id, author_id, kind, work_item_id, work_item_event_id)
select pg_temp.id('d0000001'), pg_temp.everyone(), pg_temp.sp(), pg_temp.uid('a1'), 'work_item',
       e.work_item_id, e.id
from public.work_item_events e
where e.work_item_id = pg_temp.id('e0000002') and e.kind = 'raised';
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok(
  format($$select public.delete_message(%L)$$,
    pg_temp.id('d0000001')),
  '42501', null, 'old work item cards cannot be deleted, even by an admin who posted them');
select lives_ok(
  format($$select public.attach_library_file(%L, %L)$$, pg_temp.id('e0000001'), pg_temp.id('f0000004')),
  'a Team file can go on that Team''s item');
select throws_ok(
  format($$select public.attach_library_file(%L, %L)$$, pg_temp.id('e0000002'), pg_temp.id('f0000004')),
  '22023', null, 'a Team file cannot go on an item for the whole Space');
select throws_ok(
  format($$select public.delete_library_file(%L)$$, pg_temp.id('f0000004')),
  'P0001', null, 'a file a work item uses stays in the record');
select throws_ok(
  format($$select public.delete_team(%L)$$, current_setting('test.team')),
  'P0001', null, 'a Team with chat or files cannot be deleted');

-- Review fixes ------------------------------------------------------------------------------

select lives_ok(
  format($$select public.attach_library_file(%L, %L)$$, pg_temp.id('e0000001'),
    (select id from public.library_files where source_message_id = pg_temp.id('c0000002'))),
  'the drawing shared in the Team chat goes on the Team item');
select lives_ok(format($$select public.delete_message(%L)$$, pg_temp.id('c0000002')),
  'the admin deletes the chat message that shared it');
select ok(public.may_read_file(pg_temp.chat('c0000002', 'level3.pdf'), pg_temp.uid('a2')::text),
  'the drawing stays readable through the Library because the item uses it');
select throws_ok(
  format($$select public.add_library_file(%L, %L, 'Everyone rev', %L, 'application/pdf', null, null, 'Rev D', null, %L)$$,
    pg_temp.id('f0000006'), pg_temp.sp(), pg_temp.lib('f0000006', 'everyone.pdf'), pg_temp.id('f0000004')),
  '22023', null, 'a file cannot supersede a file of another Team');
select ok(not public.may_upload(current_setting('test.space') || '/' || pg_temp.id('e0000009')::text || '/drawing.pdf'),
  'work item folders take photos only');
select lives_ok(
  format($$select public.create_work_item(%L, 'Clear gate 2', %L, null, %L, 'Gate 2', %L::jsonb, %L)$$,
    pg_temp.sp(), pg_temp.uid('a3'), current_setting('test.team'),
    jsonb_build_array(jsonb_build_object('path',
      current_setting('test.space') || '/' || pg_temp.id('e0000003')::text || '/raised.jpg'))::text,
    pg_temp.id('e0000003')),
  'an item for the MEP Team owned by someone outside it');
select is((select count(*) from public.messages where work_item_id = pg_temp.id('e0000003')), 0::bigint,
  'it posts no chat card either');
reset role;
select pg_temp.as_user('a3');
set local role authenticated;
select is((select count(*) from public.work_items where id = pg_temp.id('e0000003')), 1::bigint,
  'its owner outside the Team still sees the item');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok(
  format($$select public.create_work_item(%L, 'Disguised PDF', %L, null, null, null, %L::jsonb, %L)$$,
    pg_temp.sp(), pg_temp.uid('a2'),
    jsonb_build_array(jsonb_build_object('path',
      current_setting('test.space') || '/' || pg_temp.id('e0000004')::text || '/d.jpg'))::text,
    pg_temp.id('e0000004')),
  '22023', null, 'a PDF named .jpg is not accepted as a photo');
reset role;
select pg_temp.as_user('a2');
set local role authenticated;
select throws_ok(
  format($$select public.post_message(%L, %L, null, null, %L::jsonb)$$,
    pg_temp.id('c0000006'), pg_temp.everyone(),
    jsonb_build_array(jsonb_build_object('path', pg_temp.chat('c0000006', 'fake.pdf'),
                                         'mime', 'application/pdf'))::text),
  '22023', null, 'a photo labelled as a PDF is refused');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;

-- Unread --------------------------------------------------------------------------------------------

select ok((select unread from public.space_threads(pg_temp.sp()) where team_id is not null) >= 1,
  'the admin has unread messages in the Team thread');
select lives_ok(format($$select public.mark_thread_read(%L)$$, pg_temp.team_thread()),
  'marking the thread read');
select is((select unread from public.space_threads(pg_temp.sp()) where team_id is not null), 0,
  'leaves nothing unread');

-- Leaving -------------------------------------------------------------------------------------------

-- His open work goes to the admin first (migration 52, review 105B L1).
select lives_ok(format($$select public.remove_member_with_handover(%L, %L,
    (select coalesce(jsonb_agg(jsonb_build_object('item', w.id, 'owner', %L)), '[]'::jsonb)
     from public.work_items w join public.space_posts p on p.id = w.id
     where w.space_id = %L and w.owner_id = %L and w.status = 'open'
       and p.status = 'live' and p.deleted_at is null))$$,
    pg_temp.sp(), pg_temp.uid('a2'), pg_temp.uid('a1'), pg_temp.sp(), pg_temp.uid('a2')),
  'the admin removes Rakesh');
reset role;
select pg_temp.as_user('a2');
set local role authenticated;
select is((select count(*) from public.threads), 0::bigint,
  'a removed member sees no threads');

select * from finish();
rollback;
