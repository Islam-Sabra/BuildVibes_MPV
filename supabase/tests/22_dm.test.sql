-- Migration 22: direct messages. Run with: supabase test db
--
-- Omar (e1) and Rakesh (e2) share a Space. Sara (e3) has no link to Omar;
-- Omar follows Vera (e4) one way; Omar and Tariq (e6) follow each other.
-- Eve (e5) is a third person. Lina (e7) asks to delete her account. Sam (e8)
-- messages a lot of new people (b1...b60). Phones: e1, e2, e3, e4, e6.

begin;
create extension if not exists pgtap with schema extensions;
select plan(117);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000022' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@dm22.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e5'), ('e6'), ('e7'), ('e8')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e4', 'Vera', 'Lane'), ('e5', 'Eve', 'Out'), ('e6', 'Tariq', 'Aziz'),
             ('e7', 'Lina', 'Saad'), ('e8', 'Sam', 'Spam')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000022' || n.id)::uuid;
insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0022-' || lpad(to_hex(g), 12, '0'))::uuid, 'authenticated', 'authenticated',
       'b' || g || '@dm22.example.com', '{"home_market_id": "kw"}'::jsonb
from generate_series(1, 60) g;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000022' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000022' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000022' || p)::uuid;
$$;
create function pg_temp.bulk(g integer) returns uuid language sql as $$
  select ('00000000-0000-0000-0022-' || lpad(to_hex(g), 12, '0'))::uuid;
$$;
-- Run as the database owner.
create function pg_temp.q(p_who text, p_kind text) returns bigint language sql as $$
  select count(*) from public.push_queue where profile_id = pg_temp.uid(p_who) and kind = p_kind;
$$;
create function pg_temp.state(p_thread text, p_who text) returns text language sql as $$
  select state from public.dm_members where thread_id = pg_temp.id(p_thread) and profile_id = pg_temp.uid(p_who);
$$;
create function pg_temp.upload(p_who text, p_message text, p_file text, p_mime text) returns text
language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('dm-files', pg_temp.uid(p_who) || '/' || pg_temp.id(p_message) || '/' || p_file,
          pg_temp.uid(p_who)::text, jsonb_build_object('mimetype', p_mime, 'size', 1000))
  returning name;
$$;
create function pg_temp.file(p_who text, p_message text, p_file text) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('path',
    pg_temp.uid(p_who) || '/' || pg_temp.id(p_message) || '/' || p_file, 'name', p_file));
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('DM site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (current_setting('test.space')::uuid, pg_temp.uid('e2'), 'crew', pg_temp.uid('e1'));
insert into public.follows (follower_id, followee_id)
values (pg_temp.uid('e1'), pg_temp.uid('e4')), (pg_temp.uid('e1'), pg_temp.uid('e6')),
       (pg_temp.uid('e6'), pg_temp.uid('e1'));
insert into public.push_tokens (token, profile_id, platform)
select 'fcm-token-for-' || x.id || '-0123456789abcdef', pg_temp.uid(x.id), 'android'
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e6')) x(id);

select ok((select bool_and(relrowsecurity) from pg_class
           where oid in ('public.dm_threads'::regclass, 'public.dm_members'::regclass,
                         'public.dm_messages'::regclass, 'public.dm_attachments'::regclass,
                         'public.app_settings'::regclass)),
  'every direct message table and app_settings has row-level security');
select is((select public from storage.buckets where id = 'dm-files'), false, 'dm-files is private');
select is((select value from public.app_settings where key = 'dm_unanswered_limit'),
  '{"limit": 50, "warn_at": 40, "days": 30}'::jsonb, 'the spam guard''s limits are seeded');

-- Starting a thread: open with a work link, a request without -----------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.r1', public.start_dm(pg_temp.id('a001'), pg_temp.uid('e2'), pg_temp.id('b001'),
                                              'Concrete at 7')::text, true);
select is(current_setting('test.r1')::jsonb ->> 'state', 'open',
  'someone you share a Space with gets an open thread');
select is(current_setting('test.r1')::jsonb ->> 'warning', 'false', 'with no warning');
select set_config('test.r2', public.start_dm(pg_temp.id('a002'), pg_temp.uid('e3'), pg_temp.id('b002'),
                                              'Hello Sara')::text, true);
select is(current_setting('test.r2')::jsonb ->> 'state', 'request', 'someone new gets a message request');
select is(current_setting('test.r2')::jsonb ->> 'warning', 'false', 'with no warning the first time');
select is(public.start_dm(pg_temp.id('a003'), pg_temp.uid('e4'), pg_temp.id('b003'), 'Hi Vera') ->> 'state',
  'request', 'following someone one way is no link');
select is(public.start_dm(pg_temp.id('a006'), pg_temp.uid('e6'), pg_temp.id('b006'), 'Hi Tariq') ->> 'state',
  'open', 'following each other is a link');
select is(public.start_dm(pg_temp.id('a00f'), pg_temp.uid('e2'), pg_temp.id('b00f'), 'Again') ->> 'thread',
  pg_temp.id('a001')::text, 'a second start finds the same thread');
select throws_ok($$select public.start_dm(pg_temp.id('a009'), pg_temp.uid('e1'), pg_temp.id('b009'), 'Me')$$,
  '42501', null, 'nobody messages themselves');
select throws_ok($$select public.start_dm(pg_temp.id('a009'), pg_temp.uid('e2'), pg_temp.id('b009'))$$,
  '22023', null, 'a message has words or a file');

-- Only the two people -------------------------------------------------------------------------------

select pg_temp.as_user('e2');
select is((select count(*) from public.dm_messages where thread_id = pg_temp.id('a001')), 2::bigint,
  'Rakesh reads his thread with Omar');
select pg_temp.as_user('e5');
select is((select count(*) from public.dm_threads), 0::bigint, 'a third person reads no threads');
select is((select count(*) from public.dm_members), 0::bigint, 'no members');
select is((select count(*) from public.dm_messages), 0::bigint, 'no messages');
select is((select count(*) from public.dm_attachments), 0::bigint, 'no files');
select throws_ok($$insert into public.dm_threads (id, a_id, b_id) values (gen_random_uuid(), auth.uid(), null)$$,
  '42501', null, 'and writes no thread');
select throws_ok($$insert into public.dm_messages (id, thread_id, author_id, kind, body)
                   values (gen_random_uuid(), pg_temp.id('a001'), auth.uid(), 'text', 'x')$$,
  '42501', null, 'nor a message');
select throws_ok($$insert into public.dm_members (thread_id, profile_id, state)
                   values (pg_temp.id('a001'), auth.uid(), 'open')$$, '42501', null, 'nor a member');
select throws_ok($$insert into public.dm_attachments (message_id, storage_path, mime)
                   values (pg_temp.id('b001'), 'x/y/z.jpg', 'image/jpeg')$$, '42501', null, 'nor a file row');
select throws_ok($$select * from public.app_settings$$, '42501', null, 'nobody reads app_settings');
select throws_ok($$select public.send_dm(pg_temp.id('b0e5'), pg_temp.id('a001'), 'Butting in')$$,
  '42501', null, 'nor sends in someone else''s thread');
select is(public.dm_thread_page(pg_temp.id('a001')), null, 'nor opens it');
select pg_temp.as_user('e2');
select throws_ok($$update public.dm_messages set body = 'edited' where id = pg_temp.id('b001')$$,
  '42501', null, 'messages are never edited');

-- Pushes ---------------------------------------------------------------------------------------------

reset role;
-- F102 (migration 41): no quiet time any more; every message pushes.
select is(pg_temp.q('e2', 'dm_message'), 2::bigint, '(F102) an open thread pushes every message');
select is((select count(*) from public.push_queue where profile_id = pg_temp.uid('e2') and kind = 'dm_message'
             and message_text is not null),
  0::bigint, 'without the text unless the person chose it');
select is(pg_temp.q('e3', 'dm_request'), 1::bigint, 'a request pushes once');
select ok((select message_text is null and dm_thread_id = pg_temp.id('a002')
           from public.push_queue where profile_id = pg_temp.uid('e3') and kind = 'dm_request'),
  'never with the text');
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_dm(pg_temp.id('b010'), pg_temp.id('a002'), 'Are you there?');
reset role;
select is(pg_temp.q('e3', 'dm_request'), 1::bigint, 'one push per new person, not per message');
delete from public.push_queue where profile_id = pg_temp.uid('e6');
insert into public.push_settings (profile_id, message_text) values (pg_temp.uid('e6'), true)
on conflict (profile_id) do update set message_text = true;
select pg_temp.as_user('e6');
set local role authenticated;
select public.mute_dm(pg_temp.id('a006'), true);
select pg_temp.as_user('e1');
select public.send_dm(pg_temp.id('b016'), pg_temp.id('a006'), 'Muted?');
reset role;
select is(pg_temp.q('e6', 'dm_message'), 0::bigint, 'a muted thread sends no push');
select pg_temp.as_user('e6');
set local role authenticated;
select public.mute_dm(pg_temp.id('a006'), false);
select pg_temp.as_user('e1');
select public.send_dm(pg_temp.id('b017'), pg_temp.id('a006'), 'Gate at 7');
reset role;
select is((select message_text from public.push_queue where profile_id = pg_temp.uid('e6') and kind = 'dm_message'),
  'Gate at 7', 'with the text when the person chose it');

-- Message requests ---------------------------------------------------------------------------------------

select pg_temp.as_user('e3');
set local role authenticated;
select is(jsonb_array_length(public.my_dm_threads() -> 'threads'), 0, 'a request is not in Sara''s threads');
select ok((public.my_dm_threads() -> 'requests' ->> 'has')::boolean
          and not (public.my_dm_threads() -> 'requests' ? 'count'),
  'but in the Message requests row, with no count');
select is(jsonb_array_length(public.my_dm_requests()), 1, 'and in her requests');
reset role;
select pg_temp.upload('e1', 'b011', 'site.jpg', 'image/jpeg');
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_dm(pg_temp.id('b011'), pg_temp.id('a002'), null, null, pg_temp.file('e1', 'b011', 'site.jpg'));
select pg_temp.as_user('e3');
select is((select m ->> 'tap_to_show' from jsonb_array_elements(public.dm_thread_page(pg_temp.id('a002')) -> 'messages') m
           where m ->> 'id' = pg_temp.id('b011')::text), 'true',
  'a photo from someone new opens with one tap');
select is((select count(*) from storage.objects where bucket_id = 'dm-files'
           and name = pg_temp.uid('e1') || '/' || pg_temp.id('b011') || '/site.jpg'), 1::bigint,
  'and she may read the file');
select pg_temp.as_user('e5');
select is((select count(*) from storage.objects where bucket_id = 'dm-files'), 0::bigint,
  'a third person reads no direct message files');
select is((select count(*) from public.dm_attachments), 0::bigint, 'nor their rows');
select pg_temp.as_user('e3');
select lives_ok($$select public.send_dm(pg_temp.id('b012'), pg_temp.id('a002'), 'Yes, hello')$$,
  'Sara replies');
select is((public.dm_thread_page(pg_temp.id('a002')) ->> 'state'), 'open', 'replying opens the thread');
select ok(not exists (select 1 from jsonb_array_elements(public.dm_thread_page(pg_temp.id('a002')) -> 'messages') m
                      where m ? 'tap_to_show'), 'and files show as they are');
select is(jsonb_array_length(public.my_dm_threads() -> 'threads'), 1, 'it is in her threads now');

-- Decline, and a request again --------------------------------------------------------------------------

select pg_temp.as_user('e4');
select lives_ok($$select public.decline_dm(pg_temp.id('a003'))$$, 'Vera declines');
select ok(jsonb_array_length(public.my_dm_threads() -> 'threads') = 0
          and public.my_dm_threads() -> 'requests' is null
          and jsonb_array_length(public.my_dm_requests()) = 0,
  'it leaves her list quietly');
select pg_temp.as_user('e1');
select is((public.dm_thread_page(pg_temp.id('a003')) ->> 'state'), 'open', 'Omar isn''t told');
select is((select count(*) from public.dm_members where thread_id = pg_temp.id('a003')
           and profile_id = pg_temp.uid('e4')), 0::bigint,
  'nor can he read her row (no decline, read time or mute shown)');
select public.send_dm(pg_temp.id('b013'), pg_temp.id('a003'), 'Sorry, one more thing');
reset role;
select is(pg_temp.state('a003', 'e4'), 'request', 'writing again makes it a request again');
select is(pg_temp.q('e4', 'dm_request'), 1::bigint, 'with no push within 30 days of the decline');
update public.dm_members set state = 'declined', declined_at = now() - interval '31 days'
where thread_id = pg_temp.id('a003') and profile_id = pg_temp.uid('e4');
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_dm(pg_temp.id('b014'), pg_temp.id('a003'), 'A month later');
reset role;
select is(pg_temp.q('e4', 'dm_request'), 2::bigint, 'after 30 days a request pushes again');
-- Becoming teammates opens it.
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (current_setting('test.space')::uuid, pg_temp.uid('e4'), 'viewer', pg_temp.uid('e1'));
select pg_temp.as_user('e4');
set local role authenticated;
select is(jsonb_array_length(public.my_dm_threads() -> 'threads'), 1,
  'a request becomes a thread once the two share a Space');
select is((public.dm_thread_page(pg_temp.id('a003')) -> 'shared_space' ->> 'name'), 'DM site',
  'which shows the Space they share');
select is(public.dm_thread_page(pg_temp.id('a002')), null, 'and nobody opens a thread that isn''t theirs');
reset role;
update public.space_members set left_at = now()
where space_id = current_setting('test.space')::uuid and profile_id = pg_temp.uid('e4');
select is(pg_temp.state('a003', 'e4'), 'open', 'and it stays open after the link ends (review 41)');
select pg_temp.as_user('e4');
set local role authenticated;
select is(jsonb_array_length(public.my_dm_threads() -> 'threads'), 1, 'still in her threads');
reset role;
select pg_temp.upload('e1', 'b015', 'site2.jpg', 'image/jpeg');
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_dm(pg_temp.id('b015'), pg_temp.id('a003'), null, null, pg_temp.file('e1', 'b015', 'site2.jpg'));
select pg_temp.as_user('e4');
select ok(not exists (select 1 from jsonb_array_elements(public.dm_thread_page(pg_temp.id('a003')) -> 'messages') m
                      where m ? 'tap_to_show'), 'and its photos show as they are');
select throws_ok($$select public.decline_dm(pg_temp.id('a003'))$$, 'P0001', null, 'and it can''t be declined');

-- Replies, delete, read --------------------------------------------------------------------------------

select pg_temp.as_user('e2');
select throws_ok($$select public.send_dm(pg_temp.id('b020'), pg_temp.id('a001'), 'Re', pg_temp.id('b002'))$$,
  '22023', null, 'a reply only to a message in the same thread');
select lives_ok($$select public.send_dm(pg_temp.id('b021'), pg_temp.id('a001'), 'Yes', pg_temp.id('b001'))$$,
  'a reply in the thread');
select throws_ok($$select public.delete_dm(pg_temp.id('b001'))$$, '42501', null,
  'nobody deletes someone else''s message');
select pg_temp.as_user('e1');
select ok((select (r ->> 'unread')::boolean from jsonb_array_elements(public.my_dm_threads() -> 'threads') r
           where r ->> 'thread' = pg_temp.id('a001')::text), 'a new message shows a dot');
select public.mark_dm_read(pg_temp.id('a001'));
select ok((select not (r ->> 'unread')::boolean from jsonb_array_elements(public.my_dm_threads() -> 'threads') r
           where r ->> 'thread' = pg_temp.id('a001')::text), 'and goes once read');
select lives_ok($$select public.delete_dm(pg_temp.id('b001'))$$, 'Omar deletes his own message');
select is((select m ->> 'deleted' from jsonb_array_elements(public.dm_thread_page(pg_temp.id('a001')) -> 'messages') m
           where m ->> 'id' = pg_temp.id('b001')::text), 'true', 'it shows as deleted');
select is((select body from public.dm_messages where id = pg_temp.id('b001')), null, 'without its words');

-- Files ----------------------------------------------------------------------------------------------------

select ok(public.may_upload_dm_file(pg_temp.uid('e1') || '/' || pg_temp.id('b030') || '/plan.pdf'),
  'Omar uploads into his own folder');
select ok(not public.may_upload_dm_file(pg_temp.uid('e2') || '/' || pg_temp.id('b030') || '/plan.pdf'),
  'not into someone else''s');
select ok(not public.may_upload_dm_file(pg_temp.uid('e1') || '/' || pg_temp.id('b001') || '/late.jpg'),
  'nor for a message already sent');
select ok(not public.may_upload_dm_file(pg_temp.uid('e1') || '/' || pg_temp.id('b030') || '/x.exe'),
  'photos, PDFs and voice notes only');
reset role;
select pg_temp.upload('e2', 'b031', 'theirs.jpg', 'image/jpeg');
select pg_temp.upload('e1', 'b032', 'note.m4a', 'audio/mp4');
select pg_temp.as_user('e1');
set local role authenticated;
select throws_ok($$select public.send_dm(pg_temp.id('b031'), pg_temp.id('a001'), null, null,
                    pg_temp.file('e2', 'b031', 'theirs.jpg'))$$, '42501', null,
  'not someone else''s upload');
select throws_ok($$select public.send_dm(pg_temp.id('b032'), pg_temp.id('a001'), 'And words', null,
                    pg_temp.file('e1', 'b032', 'note.m4a'))$$, '22023', null, 'a voice note goes on its own');
select lives_ok($$select public.send_dm(pg_temp.id('b032'), pg_temp.id('a001'), null, null,
                   pg_temp.file('e1', 'b032', 'note.m4a'))$$, 'a voice note');
reset role;
select is((select kind || ' ' || a.name from public.dm_messages m
           join public.dm_attachments a on a.message_id = m.id where m.id = pg_temp.id('b032')),
  'voice note.m4a', 'kept with its name, never copied to a Library');
select pg_temp.as_user('e1');
set local role authenticated;
set local storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id = 'dm-files'
  and name = pg_temp.uid('e1') || '/' || pg_temp.id('b032') || '/note.m4a';
reset role;
select is((select count(*) from storage.objects where bucket_id = 'dm-files'
           and name = pg_temp.uid('e1') || '/' || pg_temp.id('b032') || '/note.m4a'), 1::bigint,
  'a sender can''t delete the file of a message that is live');
select pg_temp.upload('e1', 'b060', 'gone.jpg', 'image/jpeg');
select pg_temp.upload('e1', 'b061', 'told.jpg', 'image/jpeg');
select pg_temp.upload('e1', 'b062', 'draft.jpg', 'image/jpeg');
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_dm(pg_temp.id('b060'), pg_temp.id('a001'), null, null, pg_temp.file('e1', 'b060', 'gone.jpg'));
select public.send_dm(pg_temp.id('b061'), pg_temp.id('a001'), null, null, pg_temp.file('e1', 'b061', 'told.jpg'));
select is((select count(*) from storage.objects where bucket_id = 'dm-files'
           and name = pg_temp.uid('e1') || '/' || pg_temp.id('b062') || '/draft.jpg'), 1::bigint,
  'the sender reads an upload not sent yet');
select public.delete_dm(pg_temp.id('b060'));
select is((select count(*) from storage.objects where bucket_id = 'dm-files'
           and name = pg_temp.uid('e1') || '/' || pg_temp.id('b060') || '/gone.jpg'), 0::bigint,
  'once the message is deleted, nobody reads its file, its sender included (review 41)');
select pg_temp.as_user('e2');
select is((select count(*) from storage.objects where bucket_id = 'dm-files'
           and name = pg_temp.uid('e1') || '/' || pg_temp.id('b060') || '/gone.jpg'), 0::bigint,
  'nor the person it was sent to');
select public.report('dm_message', pg_temp.id('b061'), 'spam');
select is((select count(*) from storage.objects where bucket_id = 'dm-files'
           and name = pg_temp.uid('e1') || '/' || pg_temp.id('b061') || '/told.jpg'), 0::bigint,
  'a reported message''s file hides for the reporter');
select pg_temp.as_user('e1');
select is((select count(*) from storage.objects where bucket_id = 'dm-files'
           and name = pg_temp.uid('e1') || '/' || pg_temp.id('b061') || '/told.jpg'), 1::bigint,
  'not for its sender');
reset role;
insert into storage.objects (bucket_id, name, owner_id, metadata)
select 'dm-files', pg_temp.uid('e2') || '/' || gen_random_uuid() || '/f.jpg', pg_temp.uid('e2')::text,
       '{"mimetype": "image/jpeg", "size": 10}'
from generate_series(1, 300);
select pg_temp.as_user('e2');
set local role authenticated;
select ok(not public.may_upload_dm_file(pg_temp.uid('e2') || '/' || pg_temp.id('b070') || '/x.jpg'),
  '300 direct message files a day at most');
select ok(not public.may_upload(current_setting('test.space') || '/posts/' || pg_temp.id('b071') || '/x.jpg'),
  'shared with Space files');
reset role;

-- Blocks and hidden accounts ----------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select public.start_dm(pg_temp.id('a007'), pg_temp.uid('e7'), pg_temp.id('b040'), 'Hi Lina');
select pg_temp.as_user('e3');
select public.block(pg_temp.uid('e1'), true);
select throws_ok($$select public.send_dm(pg_temp.id('b041'), pg_temp.id('a002'), 'Hello?')$$, '42501', null,
  'a blocked pair can''t write');
select pg_temp.as_user('e1');
select throws_ok($$select public.send_dm(pg_temp.id('b042'), pg_temp.id('a002'), 'Hello?')$$, '42501', null,
  'either way');
select is((select count(*) from public.dm_threads where id = pg_temp.id('a002')), 0::bigint,
  'and the thread is hidden from both');
select throws_ok($$select public.start_dm(pg_temp.id('a00a'), pg_temp.uid('e3'), pg_temp.id('b043'), 'New?')$$,
  '42501', null, 'nor can a new one start');
reset role;
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('e7');
select pg_temp.as_user('e1');
set local role authenticated;
select throws_ok($$select public.send_dm(pg_temp.id('b044'), pg_temp.id('a007'), 'Still there?')$$, '42501', null,
  'someone deleting their account can''t be messaged');
select is((public.dm_thread_page(pg_temp.id('a007')) -> 'person' ->> 'former'), 'true',
  'and shows as Former member in the thread, which stays');
select pg_temp.as_user('e7');
select throws_ok($$select public.send_dm(pg_temp.id('b045'), pg_temp.id('a007'), 'Bye')$$, '42501', null,
  'nor writes');
reset role;
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('e7');

-- Reports --------------------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select public.send_dm(pg_temp.id('b050'), pg_temp.id('a001'), 'Rude words');
select pg_temp.as_user('e2');
select lives_ok($$select public.report('dm_message', pg_temp.id('b050'), 'harassment')$$,
  'the person it was sent to reports a message');
select is((select count(*) from public.dm_messages where id = pg_temp.id('b050')), 0::bigint,
  'it hides for them at once');
select pg_temp.as_user('e1');
select is((select count(*) from public.dm_messages where id = pg_temp.id('b050')), 1::bigint,
  'not for the person who sent it');
select throws_ok($$select public.report('dm_message', pg_temp.id('b050'), 'spam')$$, '22023', null,
  'nobody reports their own');
select pg_temp.as_user('e5');
select throws_ok($$select public.report('dm_message', pg_temp.id('b050'), 'spam')$$, '42501', null,
  'nor a message they can''t read');
reset role;
select isnt(public.decide_report((select id from public.reports where target_kind = 'dm_message' and target_id = pg_temp.id('b050')), 'remove'),
  null, 'moderation removes it');
select is((select body from public.removed_content rc join public.content_removals c on c.id = rc.removal_id
           where c.target_kind = 'dm_message'), 'Rude words', 'keeping its words for an appeal');
select is((select deleted_at is not null from public.dm_messages where id = pg_temp.id('b050')), true,
  'and it is gone for both');
select isnt(public.decide_report((select id from public.reports where target_kind = 'dm_message'
                                    and target_id = pg_temp.id('b061')), 'remove'), null,
  'a reported photo is removed');
update storage.objects set created_at = now() - interval '8 days' where bucket_id = 'dm-files';
select ok(not exists (select 1 from public.orphan_dm_files()
                      where name = pg_temp.uid('e1') || '/' || pg_temp.id('b061') || '/told.jpg'),
  'its file stays while the removal can be appealed');
select ok(exists (select 1 from public.orphan_dm_files()
                  where name = pg_temp.uid('e1') || '/' || pg_temp.id('b060') || '/gone.jpg'),
  'a file of a message its sender deleted goes to the cleanup');

-- The spam guard -----------------------------------------------------------------------------------------

-- Sam starts threads with 40 new people who never reply (the minute limit
-- is reset between them, since time stands still in a test).
do $$
begin
  for g in 1..40 loop
    perform set_config('request.jwt.claims',
      '{"sub": "00000000-0000-0000-0000-0000000022e8", "role": "authenticated"}', true);
    perform public.start_dm(gen_random_uuid(), pg_temp.bulk(g), gen_random_uuid(), 'Buy now');
    update public.dm_messages set created_at = now() - interval '2 minutes'
    where author_id = pg_temp.uid('e8');
  end loop;
end;
$$;
select pg_temp.as_user('e8');
set local role authenticated;
select is(public.start_dm(gen_random_uuid(), pg_temp.bulk(41), gen_random_uuid(), 'Buy now') ->> 'warning',
  'true', 'the 41st new person who never replied brings a warning');
reset role;
do $$
begin
  for g in 42..50 loop
    perform set_config('request.jwt.claims',
      '{"sub": "00000000-0000-0000-0000-0000000022e8", "role": "authenticated"}', true);
    update public.dm_messages set created_at = now() - interval '2 minutes'
    where author_id = pg_temp.uid('e8');
    perform public.start_dm(gen_random_uuid(), pg_temp.bulk(g), gen_random_uuid(), 'Buy now');
  end loop;
  update public.dm_messages set created_at = now() - interval '2 minutes' where author_id = pg_temp.uid('e8');
end;
$$;
select pg_temp.as_user('e8');
set local role authenticated;
select ok((select r ->> 'state' = 'paused' and r -> 'thread' = 'null'::jsonb and r ->> 'until' is not null
           from public.start_dm(gen_random_uuid(), pg_temp.bulk(51), gen_random_uuid(), 'Buy now') r),
  'the 51st is refused, with the day it frees up');
reset role;
select is((select count(*) from public.dm_threads where started_by = pg_temp.uid('e8')), 50::bigint,
  'and nothing is made');
select pg_temp.as_user('e8');
set local role authenticated;
select lives_ok($$select public.send_dm(gen_random_uuid(),
                    (select id from public.dm_threads where b_id = pg_temp.bulk(1) or a_id = pg_temp.bulk(1)), 'Hello again')$$,
  'an existing thread still works');
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (current_setting('test.space')::uuid, pg_temp.uid('e8'), 'crew', pg_temp.uid('e1'));
update public.dm_messages set created_at = now() - interval '2 minutes' where author_id = pg_temp.uid('e8');
select pg_temp.as_user('e8');
set local role authenticated;
select is(public.start_dm(gen_random_uuid(), pg_temp.uid('e2'), gen_random_uuid(), 'Teammate?') ->> 'state',
  'open', 'while paused, a teammate is still messaged: the guard is for new people only');
reset role;
update public.app_settings set value = '{"limit": 60, "warn_at": 55, "days": 30}' where key = 'dm_unanswered_limit';
update public.dm_messages set created_at = now() - interval '2 minutes' where author_id = pg_temp.uid('e8');
select pg_temp.as_user('e8');
set local role authenticated;
select is(public.start_dm(gen_random_uuid(), pg_temp.bulk(52), gen_random_uuid(), 'Buy now') ->> 'state',
  'request', 'changing app_settings changes the limit, with no migration');


-- 30 a minute -------------------------------------------------------------------------------------------

reset role;
do $$
begin
  perform set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000022e6", "role": "authenticated"}', true);
  for g in 1..30 loop
    perform public.send_dm(gen_random_uuid(), pg_temp.id('a006'), 'Quick ' || g);
  end loop;
end;
$$;
select pg_temp.as_user('e6');
set local role authenticated;
select throws_ok($$select public.send_dm(gen_random_uuid(), pg_temp.id('a006'), 'One more')$$, 'P0001', null,
  'at most 30 messages a minute');

-- The account: export and purge --------------------------------------------------------------------------

reset role;
insert into public.data_requests (id, profile_id) values (pg_temp.id('c001'), pg_temp.uid('e1'));
select ok(jsonb_array_length(public.export_my_data(pg_temp.id('c001')) -> 'dm_messages') > 0,
  'Download my data has the messages Omar sent');
select ok(not exists (select 1 from jsonb_array_elements(public.export_my_data(pg_temp.id('c001')) -> 'dm_messages') d
                      where d ->> 'body' = 'Yes'), 'never the ones he received');
update public.profiles set deletion_scheduled_at = now() - interval '31 days' where id = pg_temp.uid('e1');
select ok(exists (select 1 from public.accounts_due_for_purge()
                  where profile_id = pg_temp.uid('e1') and bucket = 'dm-files'),
  'the purge lists his direct message files');
select is(public.purge_account(pg_temp.uid('e1')), false, 'and waits while they remain');
select set_config('test.mine', (select count(*) from public.dm_messages
                                 where thread_id = pg_temp.id('a001') and author_id = pg_temp.uid('e1'))::text, true);
set local storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id = 'dm-files' and name like pg_temp.uid('e1') || '/%';
select is(public.purge_account(pg_temp.uid('e1')), true, 'with them gone, it goes ahead');
select is((select count(*) from public.dm_messages where thread_id = pg_temp.id('a001') and author_id is null),
  current_setting('test.mine')::bigint, 'his messages stay for Rakesh, with no author');
select pg_temp.as_user('e2');
set local role authenticated;
select is((public.dm_thread_page(pg_temp.id('a001')) -> 'person' ->> 'former'), 'true',
  'as Former member');
select ok(not exists (select 1 from jsonb_array_elements(public.dm_thread_page(pg_temp.id('a001')) -> 'messages') m
                      where not (m ->> 'from_me')::boolean and m ? 'files'),
  'with none of his files left listed (review 42 R1)');
select is((select m ->> 'deleted' from jsonb_array_elements(public.dm_thread_page(pg_temp.id('a001')) -> 'messages') m
           where m ->> 'id' = pg_temp.id('b032')::text), 'true',
  'and his voice note shows as deleted');
select throws_ok($$select public.send_dm(gen_random_uuid(), pg_temp.id('a001'), 'Hello?')$$, '42501', null,
  'and nobody writes to a purged account');
select pg_temp.as_user('e5');
select throws_ok($$select public.send_dm(gen_random_uuid(), pg_temp.id('a001'), 'Me too')$$, '42501', null,
  'nor does a stranger get into the thread');

select * from finish();
rollback;
