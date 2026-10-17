-- Migration 12: the feed. Run with: supabase test db
--
-- Omar (f1), Rakesh (f2) and Sami (f3) are in Kuwait. Eve (f4) has no
-- home market. Bob (f5) blocks Omar. Review 17's checks are at the end.

begin;
create extension if not exists pgtap with schema extensions;
select plan(72);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000012f1', 'authenticated', 'authenticated', 'omar12@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000012f2', 'authenticated', 'authenticated', 'rakesh12@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000012f3', 'authenticated', 'authenticated', 'sami12@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000012f4', 'authenticated', 'authenticated', 'eve12@example.com', '{}'),
  ('00000000-0000-0000-0000-0000000012f5', 'authenticated', 'authenticated', 'bob12@example.com', '{"home_market_id": "kw"}');
update public.profiles set first_name = 'Omar', last_name = 'Haddad' where id = '00000000-0000-0000-0000-0000000012f1';
update public.profiles set first_name = 'Rakesh', last_name = 'Nair' where id = '00000000-0000-0000-0000-0000000012f2';
update public.profiles set first_name = 'Sami', last_name = 'Al-Mansour' where id = '00000000-0000-0000-0000-0000000012f3';

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000012' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000012' || p_id)::uuid;
$$;
create function pg_temp.post(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000012' || p)::uuid;
$$;
create function pg_temp.photo(p_who text, p_post text, p_file text) returns text language sql as $$
  select pg_temp.uid(p_who)::text || '/' || pg_temp.post(p_post)::text || '/' || p_file;
$$;
create function pg_temp.upload(p_who text, p_post text, p_file text) returns void language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('post-media', pg_temp.photo(p_who, p_post, p_file), pg_temp.uid(p_who)::text,
          '{"mimetype": "image/jpeg", "size": 1000}');
$$;

-- Omar's project, on his CV and confirmed by Rakesh; another one only on
-- his CV, not confirmed.
select pg_temp.as_user('f1');
set local role authenticated;
select set_config('test.project',
  public.create_project('Kuwait City Tower', 'commercial', 'kw', 'kw-capital')::text, true);
select set_config('test.other',
  public.create_project('Gate 3 car park', 'commercial', 'kw', 'kw-capital')::text, true);
reset role;
insert into public.cv_projects (id, profile_id, project_id, role_title) values
  ('00000000-0000-0000-0000-0000000012c1', pg_temp.uid('f1'), current_setting('test.project')::uuid, 'Site engineer'),
  ('00000000-0000-0000-0000-0000000012c2', pg_temp.uid('f1'), current_setting('test.other')::uuid, 'Site engineer');
insert into public.cv_project_confirmations (cv_project_id, confirmed_by, source)
values ('00000000-0000-0000-0000-0000000012c1', pg_temp.uid('f2'), 'teammate');

-- Writing a post ---------------------------------------------------------------------------

select pg_temp.as_user('f1');
set local role authenticated;
select is(public.create_post(pg_temp.post('a001'), 'Slab poured on level 3.', 'en'),
  pg_temp.post('a001'), 'Omar posts text');
select is(public.create_post(pg_temp.post('a001'), 'Slab poured on level 3.', 'en'),
  pg_temp.post('a001'), 'a retry returns the same post');
select is((select count(*) from public.posts where author_id = pg_temp.uid('f1')), 1::bigint,
  'and posts it once');
select throws_ok($$select public.create_post(gen_random_uuid(), '   ', 'en')$$,
  '22023', null, 'no text and no photo is refused');
select throws_ok($$select public.create_post(gen_random_uuid(), 'Hi', 'fr')$$,
  '22023', null, 'the language is English or Arabic');
select throws_ok(format($q$select public.create_post(%L, null, 'en', null, %L)$q$,
  pg_temp.post('a002'), jsonb_build_array(jsonb_build_object('path', pg_temp.photo('f1', 'a002', 'x.jpg')))),
  '22023', 'photo not uploaded', 'a photo must be uploaded first');
reset role;
select pg_temp.upload('f1', 'a002', '1.jpg');
select pg_temp.upload('f1', 'a002', '2.jpg');
select pg_temp.upload('f2', 'a009', 'r.jpg');
select pg_temp.as_user('f1');
set local role authenticated;
select is(public.create_post(pg_temp.post('a002'), null, 'en', current_setting('test.project')::uuid,
  jsonb_build_array(
    jsonb_build_object('path', pg_temp.photo('f1', 'a002', '1.jpg'), 'width', 1600, 'height', 1200),
    jsonb_build_object('path', pg_temp.photo('f1', 'a002', '2.jpg')))),
  pg_temp.post('a002'), 'two photos and a confirmed project');
select is((select count(*) from public.post_media where post_id = pg_temp.post('a002')), 2::bigint,
  'both photos are on the post');
select throws_ok(format($q$select public.create_post(%L, 'x', 'en', null, %L)$q$,
  gen_random_uuid(), jsonb_build_array(jsonb_build_object('path', pg_temp.photo('f2', 'a009', 'r.jpg')))),
  '22023', 'photo not uploaded', 'someone else''s photo is refused');
select throws_ok(format($q$select public.create_post(gen_random_uuid(), 'x', 'en', null, %L)$q$,
  (select jsonb_agg(jsonb_build_object('path', 'p' || g)) from generate_series(1, 5) g)),
  '22023', 'at most 4 photos', 'five photos are refused');
select throws_ok(format($q$select public.create_post(gen_random_uuid(), 'x', 'en', %L)$q$,
  current_setting('test.other')), '42501', null,
  'a project without a confirmed role can''t be tagged');
reset role;
update public.cv_projects set show_on_profile = false where id = '00000000-0000-0000-0000-0000000012c1';
select pg_temp.as_user('f1');
set local role authenticated;
select throws_ok(format($q$select public.create_post(gen_random_uuid(), 'x', 'en', %L)$q$,
  current_setting('test.project')), '42501', null,
  'nor a project hidden from the profile');
select throws_ok($$insert into public.posts (id, author_id, body, lang) values (gen_random_uuid(), auth.uid(), 'x', 'en')$$,
  '42501', null, 'the app can''t write posts directly');
reset role;
update public.cv_projects set show_on_profile = true where id = '00000000-0000-0000-0000-0000000012c1';

-- Sami has posted 20 times today: the 21st waits.
insert into public.posts (id, author_id, body, lang, market_id)
select gen_random_uuid(), pg_temp.uid('f3'), 'post ' || g, 'en', 'kw' from generate_series(1, 20) g;
select pg_temp.as_user('f3');
set local role authenticated;
select throws_ok($$select public.create_post(gen_random_uuid(), 'One more', 'en')$$,
  'P0001', 'too many posts today', 'at most 20 posts a day');
reset role;
delete from public.posts where author_id = pg_temp.uid('f3');

-- Editing and deleting ---------------------------------------------------------------------

select pg_temp.as_user('f2');
set local role authenticated;
select throws_ok(format($q$select public.edit_post(%L, 'hacked', 'en')$q$, pg_temp.post('a001')),
  '42501', null, 'nobody edits someone else''s post');
select throws_ok(format($q$select public.delete_post(%L)$q$, pg_temp.post('a001')),
  '42501', null, 'nor deletes it');
select pg_temp.as_user('f1');
select lives_ok(format($q$select public.edit_post(%L, 'Slab poured on level 3, cured.', 'en')$q$,
  pg_temp.post('a001')), 'the author edits the text');
select ok((select edited_at is not null from public.posts where id = pg_temp.post('a001')),
  'and it shows as Edited');
select throws_ok(format($q$select public.edit_post(%L, '', 'en')$q$, pg_temp.post('a001')),
  '22023', null, 'a text post can''t be emptied');

-- Replies ----------------------------------------------------------------------------------

select pg_temp.as_user('f2');
select is(public.add_reply(pg_temp.post('b001'), pg_temp.post('a001'), null, 'Great work.'),
  pg_temp.post('b001'), 'Rakesh replies');
select pg_temp.as_user('f3');
select is(public.add_reply(pg_temp.post('b002'), pg_temp.post('a001'), pg_temp.post('b001'), 'Agreed.'),
  pg_temp.post('b002'), 'Sami replies to Rakesh''s reply');
select throws_ok(format($q$select public.add_reply(gen_random_uuid(), %L, %L, 'x')$q$,
  pg_temp.post('a002'), pg_temp.post('b001')),
  '22023', null, 'a reply answers a reply on the same post only');
select throws_ok(format($q$select public.delete_reply(%L)$q$, pg_temp.post('b001')),
  '42501', null, 'nobody deletes someone else''s reply');

-- Useful -----------------------------------------------------------------------------------

select pg_temp.as_user('f2');
select public.mark_useful('post', pg_temp.post('a001'), true);
select public.mark_useful('post', pg_temp.post('a001'), true);
reset role;
select is((select count(*) from public.useful_marks where target_id = pg_temp.post('a001')), 1::bigint,
  'Useful counts once per person');
select pg_temp.as_user('f2');
set local role authenticated;
select ok((select my_useful from public.post_cards where id = pg_temp.post('a001')),
  'the card knows Rakesh marked it');
select pg_temp.as_user('f1');
select throws_ok(format($q$select public.mark_useful('post', %L, true)$q$, pg_temp.post('a001')),
  '22023', null, 'not on your own post');
select is((select count(*) from public.useful_marks), 0::bigint,
  'and Omar can''t read anyone else''s marks');

-- The proof line: Sami follows Rakesh, Omar follows nobody.
reset role;
insert into public.follows (follower_id, followee_id) values (pg_temp.uid('f3'), pg_temp.uid('f2'));
select pg_temp.as_user('f3');
set local role authenticated;
select is((select array_agg(name) from public.useful_names(pg_temp.post('a001'))),
  array['Rakesh Nair'], 'Sami sees the name of a person he follows');
select pg_temp.as_user('f1');
select is((select count(*) from public.useful_names(pg_temp.post('a001'))), 0::bigint,
  'the author, following nobody, sees no names and no count');
select pg_temp.as_user('f2');
select public.mark_useful('post', pg_temp.post('a001'), false);
reset role;
select is((select count(*) from public.useful_marks where target_id = pg_temp.post('a001')), 0::bigint,
  'unmarking takes it off');

-- The feed ---------------------------------------------------------------------------------

-- Eve (no home market) posts; Omar has an old Kuwait post too.
select pg_temp.as_user('f4');
set local role authenticated;
select public.create_post(pg_temp.post('e001'), 'Hello from Cairo.', 'en');
reset role;
insert into public.posts (id, author_id, body, lang, market_id, created_at)
values (pg_temp.post('d001'), pg_temp.uid('f1'), 'Last month on site.', 'en', 'kw', now() - interval '40 days');
select pg_temp.as_user('f3');
set local role authenticated;
select is((select array_agg(section || ':' || right(post_id::text, 4) order by ord)
           from (select f.*, row_number() over () as ord from public.feed_page() f) x),
  array['home:a002', 'home:a001', 'beyond:e001', 'beyond:d001'],
  'home market from the last 30 days first, newest first; then the rest');
select is((select count(*) from public.feed_page(jsonb_build_object('section', 'beyond',
             'created_at', (select created_at from public.posts where id = pg_temp.post('e001')),
             'id', pg_temp.post('e001')))), 1::bigint,
  'the next page goes on after the cursor');

-- Mute: Rakesh mutes Omar.
select pg_temp.as_user('f2');
select public.mute(pg_temp.uid('f1'), true);
select is((select count(*) from public.feed_page() where post_id in (pg_temp.post('a001'), pg_temp.post('a002'))),
  0::bigint, 'a muted person''s posts leave the muter''s feed');
select is((select count(*) from public.posts_by(pg_temp.uid('f1'))), 3::bigint,
  'but stay on their profile');
select pg_temp.as_user('f3');
select is((select count(*) from public.feed_page() where post_id = pg_temp.post('a001')), 1::bigint,
  'and in everyone else''s feed');
select is((select count(*) from public.mutes), 0::bigint, 'nobody reads another person''s mutes');

-- Tagged posts on the project sheet; a merged project points on.
select is((select array_agg(post_id) from public.posts_tagged(current_setting('test.project')::uuid)),
  array[pg_temp.post('a002')], 'the project sheet shows the tagged post');
reset role;
update public.projects set status = 'merged', merged_into = current_setting('test.other')::uuid
where id = current_setting('test.project')::uuid;
select pg_temp.as_user('f3');
set local role authenticated;
select is((select project_id from public.post_cards where id = pg_temp.post('a002')),
  current_setting('test.other')::uuid, 'a merged project''s tag shows the project it went into');
reset role;
update public.projects set status = 'active', merged_into = null
where id = current_setting('test.project')::uuid;

-- Blocks -----------------------------------------------------------------------------------

insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('f5'), pg_temp.uid('f1'));
select pg_temp.as_user('f1');
set local role authenticated;
select public.add_reply(pg_temp.post('b003'), pg_temp.post('a001'), null, 'Thanks all.');
select pg_temp.as_user('f5');
select is((select count(*) from public.posts where author_id = pg_temp.uid('f1')), 0::bigint,
  'a blocked person can''t read the blocker''s posts');
select is((select count(*) from public.post_replies where author_id = pg_temp.uid('f1')), 0::bigint,
  'nor their replies');
select is((select count(*) from public.post_media), 0::bigint, 'nor their photo rows');
select ok(not public.may_read_post_media(pg_temp.photo('f1', 'a002', '1.jpg'), pg_temp.uid('f1')::text),
  'nor their photos');
select is((select count(*) from public.feed_page() where post_id = pg_temp.post('a001')), 0::bigint,
  'their posts are out of the feed');
select throws_ok(format($q$select public.add_reply(gen_random_uuid(), %L, null, 'x')$q$, pg_temp.post('a001')),
  '42501', null, 'and can''t be replied to');
select pg_temp.as_user('f3');
select ok(public.may_read_post_media(pg_temp.photo('f1', 'a002', '1.jpg'), pg_temp.uid('f1')::text),
  'anyone else may read the photo of a post they see');

-- Deleting ---------------------------------------------------------------------------------

select pg_temp.as_user('f1');
select public.delete_post(pg_temp.post('a002'));
select pg_temp.as_user('f3');
select is((select count(*) from public.post_cards where id = pg_temp.post('a002')), 0::bigint,
  'a deleted post is gone for everyone');
select ok(not public.may_read_post_media(pg_temp.photo('f1', 'a002', '1.jpg'), pg_temp.uid('f1')::text),
  'and so are its photos');
reset role;


-- Review 17 ---------------------------------------------------------------------------------

-- A1, changed by migration 25 (review 50 F2): two levels on screen. An
-- answer to b002 (which answers b001) is filed under b001.
select pg_temp.as_user('f2');
set local role authenticated;
select public.add_reply(pg_temp.post('b0f1'), pg_temp.post('a001'), pg_temp.post('b002'), 'x');
reset role;
select is((select reply_to from public.post_replies where id = pg_temp.post('b0f1')),
  pg_temp.post('b001'), 'an answer to a second-level reply is filed under its top comment');

-- B10: the author doesn't see a reply from someone they blocked.
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('f1'), pg_temp.uid('f3'));
select pg_temp.as_user('f1');
set local role authenticated;
select is((select count(*) from public.post_replies where id = pg_temp.post('b002')), 0::bigint,
  'the author doesn''t see a reply from someone they blocked');
reset role;
delete from public.blocks where blocker_id = pg_temp.uid('f1');

-- A6: the upload path and the photo type.
select pg_temp.as_user('f2');
set local role authenticated;
select ok(public.may_upload_post_media(pg_temp.photo('f2', 'a00a', 'site.jpg')),
  'a photo in your own post folder may go up');
select ok(not public.may_upload_post_media(pg_temp.photo('f1', 'a00a', 'site.jpg')),
  'never in someone else''s folder');
select ok(not public.may_upload_post_media(pg_temp.uid('f2')::text || '/notauuid/site.jpg'),
  'the post folder must be an id');
select ok(not public.may_upload_post_media(pg_temp.photo('f2', 'a00a', 'evil.exe')),
  'only photo file names');
select ok(not public.may_upload_post_media(pg_temp.photo('f2', 'a00a', '.jpg')),
  'and not an empty name');
reset role;
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('post-media', pg_temp.photo('f2', 'a00b', 'v.jpg'), pg_temp.uid('f2')::text, '{"mimetype": "image/svg+xml", "size": 10}'),
  ('post-media', pg_temp.photo('f2', 'a00c', 'w.jpg'), pg_temp.uid('f2')::text, '{"size": 10}');
select pg_temp.as_user('f2');
set local role authenticated;
select throws_ok(format($q$select public.create_post(%L, null, 'en', null, %L)$q$,
  pg_temp.post('a00b'), jsonb_build_array(jsonb_build_object('path', pg_temp.photo('f2', 'a00b', 'v.jpg')))),
  '22023', 'photo not uploaded', 'an SVG is not a photo');
select throws_ok(format($q$select public.create_post(%L, null, 'en', null, %L)$q$,
  pg_temp.post('a00c'), jsonb_build_array(jsonb_build_object('path', pg_temp.photo('f2', 'a00c', 'w.jpg')))),
  '22023', 'photo not uploaded', 'nor a file with no type');
reset role;

-- A2c: at most 100 MB a day.
insert into storage.objects (bucket_id, name, owner_id, metadata)
select 'post-media', pg_temp.uid('f4')::text || '/' || gen_random_uuid() || '/big.jpg',
       pg_temp.uid('f4')::text, '{"mimetype": "image/jpeg", "size": 10485760}'
from generate_series(1, 10);
select pg_temp.as_user('f4');
set local role authenticated;
select ok(not public.may_upload_post_media(pg_temp.photo('f4', 'a00d', 'one-more.jpg')),
  'after 100 MB today, no more photos');
reset role;

-- A2a: remove your own photo that no post uses.
select pg_temp.upload('f2', 'a00e', 'spare.jpg');
select pg_temp.as_user('f2');
set local role authenticated;
select ok(public.may_delete_post_media(pg_temp.photo('f2', 'a00e', 'spare.jpg'), pg_temp.uid('f2')::text),
  'the author may remove a photo no post uses');
select pg_temp.as_user('f3');
select ok(not public.may_delete_post_media(pg_temp.photo('f2', 'a00e', 'spare.jpg'), pg_temp.uid('f2')::text),
  'nobody else may');
select pg_temp.as_user('f1');
select ok(not public.may_delete_post_media(pg_temp.photo('f1', 'a002', '1.jpg'), pg_temp.uid('f1')::text),
  'nor a photo a post uses, even a deleted post''s');
reset role;

-- A2b: the cleanup. An old unused photo, a fresh one, and the photos of
-- posts deleted 31 and 5 days ago.
insert into storage.objects (bucket_id, name, owner_id, metadata, created_at) values
  ('post-media', pg_temp.photo('f2', 'a0f1', 'old.jpg'), pg_temp.uid('f2')::text, '{"mimetype": "image/jpeg"}', now() - interval '2 days'),
  ('post-media', pg_temp.photo('f2', 'a0f2', 'new.jpg'), pg_temp.uid('f2')::text, '{"mimetype": "image/jpeg"}', now() - interval '2 hours'),
  ('post-media', pg_temp.photo('f2', 'a0f3', 'gone.jpg'), pg_temp.uid('f2')::text, '{"mimetype": "image/jpeg"}', now() - interval '40 days'),
  ('post-media', pg_temp.photo('f2', 'a0f4', 'recent.jpg'), pg_temp.uid('f2')::text, '{"mimetype": "image/jpeg"}', now() - interval '40 days');
insert into public.posts (id, author_id, lang, created_at, deleted_at) values
  (pg_temp.post('a0f3'), pg_temp.uid('f2'), 'en', now() - interval '40 days', now() - interval '31 days'),
  (pg_temp.post('a0f4'), pg_temp.uid('f2'), 'en', now() - interval '40 days', now() - interval '5 days');
insert into public.post_media (post_id, storage_path, sort) values
  (pg_temp.post('a0f3'), pg_temp.photo('f2', 'a0f3', 'gone.jpg'), 0),
  (pg_temp.post('a0f4'), pg_temp.photo('f2', 'a0f4', 'recent.jpg'), 0);
select pg_temp.as_user('f2');
set local role authenticated;
select throws_ok($$select * from public.orphan_post_media()$$, '42501', null,
  'members can''t run the cleanup');
reset role;
set local role service_role;
select is((select array_agg(right(name, 8) order by name) from public.orphan_post_media(interval '0 seconds')
           where name like '%' || pg_temp.uid('f2')::text || '%'),
  array['/old.jpg', 'gone.jpg'],
  'it claims unused photos over a day old and those of posts deleted over 30 days ago');
select is((select count(*) from public.file_cleanup_claims where storage_path like '%new.jpg' or storage_path like '%recent.jpg'),
  0::bigint, 'never a fresh upload, nor a photo inside the appeal window');
reset role;

-- B7: no home market, no home section.
select pg_temp.as_user('f4');
set local role authenticated;
select is((select count(*) from public.feed_page() where section = 'home'), 0::bigint,
  'someone with no home market gets no home section');

-- B8: the 30-day window rides in the cursor.
select pg_temp.as_user('f3');
select is((select distinct since from public.feed_page(jsonb_build_object(
             'section', 'home', 'since', '2026-09-01T00:00:00Z'))),
  '2026-09-01T00:00:00Z'::timestamptz, 'the window comes back from the cursor unchanged');
select ok((select bool_and(since is not null) from public.feed_page()),
  'and the first page says where it starts');
reset role;

-- B9: a two-step merge (A into B into C) keeps the tag.
select pg_temp.as_user('f1');
set local role authenticated;
select set_config('test.c', public.create_project('Tower C', 'commercial', 'kw', 'kw-capital')::text, true);
select public.create_post(pg_temp.post('a0c1'), 'Tagged before the merges.', 'en',
  current_setting('test.project')::uuid);
reset role;
update public.projects set status = 'merged', merged_into = current_setting('test.c')::uuid
where id = current_setting('test.other')::uuid;
update public.projects set status = 'merged', merged_into = current_setting('test.other')::uuid
where id = current_setting('test.project')::uuid;
select pg_temp.as_user('f3');
set local role authenticated;
select is((select project_id from public.post_cards where id = pg_temp.post('a0c1')),
  current_setting('test.c')::uuid, 'the tag follows the merges to the end');
select is((select count(*) from public.posts_tagged(current_setting('test.c')::uuid)
           where post_id = pg_temp.post('a0c1')), 1::bigint,
  'and the post shows on the last project''s sheet');
select is((select count(*) from public.posts_tagged(current_setting('test.project')::uuid)), 0::bigint,
  'not on a merged project''s');
reset role;

-- Review 18: a claimed post photo keeps its claim while it exists.
select pg_temp.upload('f2', 'a0f5', 'claimed.jpg');
update storage.objects set created_at = now() - interval '3 days'
where name = pg_temp.photo('f2', 'a0f5', 'claimed.jpg');
set local role service_role;
select public.orphan_post_media(interval '0 seconds');
select public.forget_cleanup_claims();
select is((select count(*) from public.file_cleanup_claims
           where storage_path = pg_temp.photo('f2', 'a0f5', 'claimed.jpg')), 1::bigint,
  'the claim of a post photo that still exists stays');
reset role;
select pg_temp.as_user('f2');
set local role authenticated;
select throws_ok(format($q$select public.create_post(%L, null, 'en', null, %L)$q$,
  pg_temp.post('a0f5'), jsonb_build_array(jsonb_build_object('path', pg_temp.photo('f2', 'a0f5', 'claimed.jpg')))),
  '22023', 'this file was cleaned up; upload it again',
  'and the claimed photo can''t go on a post');
reset role;
set local storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id = 'post-media'
  and name = pg_temp.photo('f2', 'a0f5', 'claimed.jpg');
set local role service_role;
select public.forget_cleanup_claims();
select is((select count(*) from public.file_cleanup_claims
           where storage_path = pg_temp.photo('f2', 'a0f5', 'claimed.jpg')), 0::bigint,
  'once the photo is deleted, its claim goes');
reset role;

select * from finish();
rollback;
