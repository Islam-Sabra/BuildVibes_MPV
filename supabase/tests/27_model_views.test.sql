-- Migration 27: model views from BuildVibes 360 in the Space Library
-- (docs/product/model-views.md; review 57, R1-R7).
-- Run with: supabase test db
--
-- Omar (e1) made the Tower site and is its admin. Rakesh (e2) is Crew and
-- publishes from Navisworks, Nadia (e3) is Crew in the MEP Team, Vera (e4)
-- a Viewer, Tariq (e6) Crew in the MEP Team, Sami (e7) Crew in the Civil
-- Team. Eve (e5) is not in the Tower site; she has her own Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(156);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000027' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@views27.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e5'), ('e6'), ('e7')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Nadia', 'Saleh'),
             ('e4', 'Vera', 'Lane'), ('e5', 'Eve', 'Out'), ('e6', 'Tariq', 'Aziz'),
             ('e7', 'Sami', 'Fares')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000027' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000027' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000027' || p_id)::uuid;
$$;
-- A Library file id (f...) or a work item id (c...).
create function pg_temp.f(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000027' || p)::uuid;
$$;
-- A saved viewpoint's Guid in the Navisworks file.
create function pg_temp.vp(p_n integer) returns uuid language sql as $$
  select ('aaaaaaaa-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.other() returns uuid language sql as $$
  select current_setting('test.other')::uuid;
$$;
create function pg_temp.mep() returns uuid language sql as $$
  select current_setting('test.mep')::uuid;
$$;
create function pg_temp.dir(p_file text, p_space uuid default null) returns text language sql as $$
  select coalesce(p_space, pg_temp.sp())::text || '/library/' || pg_temp.f(p_file)::text || '/';
$$;
-- A file as the Storage API would store it (type and size in metadata).
-- Run as the database owner.
create function pg_temp.upload(p_name text, p_owner text, p_mime text default 'image/jpeg')
returns void language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('space-files', p_name, pg_temp.uid(p_owner)::text,
          jsonb_build_object('mimetype', p_mime, 'size', 120000));
$$;
-- view.jpg and thumb.jpg, as the plugin uploads them.
create function pg_temp.upload_view(p_file text, p_owner text, p_space uuid default null)
returns void language sql as $$
  select pg_temp.upload(pg_temp.dir(p_file, p_space) || 'view.jpg', p_owner);
  select pg_temp.upload(pg_temp.dir(p_file, p_space) || 'thumb.jpg', p_owner);
$$;
-- publish_model_view as the plugin calls it; returns the version.
create function pg_temp.pub(
  p_file text, p_vp integer, p_team uuid default null,
  p_name text default 'Level 3 sleeves', p_camera text default '{"type": "perspective", "position": [1, 2, 3]}',
  p_comments text default '[{"author": "Islam", "body": "Check the sleeves at C7"}]',
  p_space uuid default null, p_note text default 'From the coordination model',
  p_width integer default 1920, p_folder text default 'BuildVibes 360',
  p_model_title text default 'Tower A', p_model_file text default 'TowerA.nwf',
  p_image text default null, p_thumb text default null,
  p_height integer default 1080, p_navisworks text default '2025', p_bytes bigint default 120000)
returns text language sql as $$
  select r.rev_label from public.publish_model_view(
    pg_temp.f(p_file), coalesce(p_space, pg_temp.sp()), p_team, p_name, p_note,
    coalesce(p_image, pg_temp.dir(p_file, p_space) || 'view.jpg'),
    coalesce(p_thumb, pg_temp.dir(p_file, p_space) || 'thumb.jpg'),
    p_bytes, p_camera, pg_temp.vp(p_vp), p_folder, p_model_title, p_model_file,
    p_comments, p_width, p_height, p_navisworks) r;
$$;
create function pg_temp.views_seen(p_file text) returns bigint language sql as $$
  select count(*) from public.model_views where library_file_id = pg_temp.f(p_file);
$$;
create function pg_temp.supersedes(p_file text) returns uuid language sql as $$
  select supersedes_id from public.library_files where id = pg_temp.f(p_file);
$$;
create function pg_temp.targets() returns text[] language sql as $$
  select array(select t.space_name || '/' || coalesce(t.team_name, '*')
               from public.my_publish_targets() t);
$$;
-- Run as the database owner: events made just now move back in time (a
-- test runs in one transaction, so now() never moves).
create function pg_temp.stamp(p_minutes_ago integer) returns void language sql as $$
  alter table public.work_item_events disable trigger work_item_events_append_only;
  update public.work_item_events set created_at = now() - make_interval(mins => p_minutes_ago)
  where created_at = now();
  alter table public.work_item_events enable trigger work_item_events_append_only;
  update public.work_item_evidence set created_at = now() - make_interval(mins => p_minutes_ago)
  where created_at = now();
  update public.space_posts set created_at = now() - make_interval(mins => p_minutes_ago)
  where created_at = now();
  update public.space_posts p set last_activity_at = greatest(
    p.created_at, p.cancelled_at,
    (select max(e.created_at) from public.work_item_events e where e.work_item_id = p.id),
    (select max(pe.created_at) from public.post_edits pe where pe.post_id = p.id))
  where p.space_id = pg_temp.sp();
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Tower site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e3', 'crew'), ('e4', 'viewer'), ('e6', 'crew'), ('e7', 'crew')) x(id, pass);
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.mep',
  public.create_team(pg_temp.sp(), 'MEP', array[pg_temp.uid('e3'), pg_temp.uid('e6')])::text, true);
select public.create_team(pg_temp.sp(), 'Civil', array[pg_temp.uid('e7')]);
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select set_config('test.other', public.create_space('Eve office')::text, true);
reset role;

-- Grants and the table ---------------------------------------------------------------------------

select ok(has_function_privilege('authenticated',
            'public.publish_model_view(uuid, uuid, uuid, text, text, text, text, bigint, text, uuid, text, text, text, text, integer, integer, text)',
            'execute')
          and has_function_privilege('authenticated', 'public.my_publish_targets()', 'execute')
          and has_function_privilege('authenticated', 'public.my_model_views(uuid[])', 'execute'),
  'a signed-in person may call the three plugin functions');
select ok(not has_function_privilege('anon',
            'public.publish_model_view(uuid, uuid, uuid, text, text, text, text, bigint, text, uuid, text, text, text, text, integer, integer, text)',
            'execute')
          and not has_function_privilege('anon', 'public.my_publish_targets()', 'execute')
          and not has_function_privilege('anon', 'public.my_model_views(uuid[])', 'execute'),
  'nobody signed out may call them');
select ok(not has_function_privilege('authenticated', 'public.is_valid_model_view_comments(jsonb)', 'execute')
          and not has_function_privilege('authenticated', 'public.refuse_claimed_thumb()', 'execute')
          and not has_function_privilege('authenticated', 'public.model_view_chain_key(uuid, uuid, uuid)', 'execute')
          and not has_function_privilege('authenticated', 'public.model_view_use_json(public.space_posts)', 'execute')
          and not has_function_privilege('anon', 'public.model_view_use_json(public.space_posts)', 'execute'),
  'the internal helpers are not callable from the app');
select ok(not has_function_privilege('authenticated', 'public.is_referenced_file(text)', 'execute')
          and has_function_privilege('authenticated', 'public.may_read_file(text, text)', 'execute'),
  'is_referenced_file and may_read_file keep their grants');
select ok(has_table_privilege('authenticated', 'public.model_views', 'select')
          and not has_table_privilege('authenticated', 'public.model_views', 'insert')
          and not has_table_privilege('authenticated', 'public.model_views', 'update')
          and not has_table_privilege('authenticated', 'public.model_views', 'delete')
          and not has_table_privilege('anon', 'public.model_views', 'select'),
  'model_views can be read, never written, from the app');
select ok((select relrowsecurity from pg_class where oid = 'public.model_views'::regclass),
  'model_views has row-level security');
select is(pg_get_function_result('public.my_publish_targets()'::regprocedure),
  'TABLE(space_id uuid, space_name text, team_id uuid, team_name text)',
  'publish targets carry no counts');
select is(pg_get_function_result('public.my_model_views(uuid[])'::regprocedure),
  'TABLE(library_file_id uuid, viewpoint_guid uuid, title text, rev_label text, space_id uuid, space_name text, team_id uuid, team_name text, created_at timestamp with time zone, is_current boolean, uses jsonb)',
  'my_model_views has the plugin''s row shape');

-- R6: both files upload before publishing, with may_upload unchanged ---------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select ok(public.may_upload(pg_temp.dir('f001') || 'view.jpg'), 'Rakesh may upload view.jpg to a new folder');
reset role;
select pg_temp.upload(pg_temp.dir('f001') || 'view.jpg', 'e2');
select pg_temp.as_user('e2');
set local role authenticated;
select ok(public.may_upload(pg_temp.dir('f001') || 'thumb.jpg'), 'and thumb.jpg beside it');
reset role;
select pg_temp.upload(pg_temp.dir('f001') || 'thumb.jpg', 'e2');
select pg_temp.as_user('e7');
set local role authenticated;
select ok(not public.may_upload(pg_temp.dir('f001') || 'extra.jpg'), 'nobody else may add a file to his folder');
reset role;
select pg_temp.as_user('e4');
set local role authenticated;
select ok(not public.may_upload(pg_temp.dir('f099') || 'view.jpg'), 'a Viewer may not upload to the Library');
reset role;

-- R7: publishing posts nothing and notifies nobody.
select set_config('test.counts', (select row(
  (select count(*) from public.notifications), (select count(*) from public.push_queue),
  (select count(*) from public.space_posts), (select count(*) from public.messages),
  (select count(*) from public.posts))::text), true);

select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.pub('f001', 1), 'V1', 'Crew publishes a viewpoint: V1');
select ok(not public.may_upload(pg_temp.dir('f001') || 'more.jpg'), 'after publishing, nothing more goes in that folder');
select ok(not public.may_upload(pg_temp.dir('f001') || 'thumb.jpg'), 'not even a second thumb');
reset role;
select is((select row(
  (select count(*) from public.notifications), (select count(*) from public.push_queue),
  (select count(*) from public.space_posts), (select count(*) from public.messages),
  (select count(*) from public.posts))::text),
  current_setting('test.counts'),
  'no notification, push, Work post, chat message or feed post is written (R7)');

select is((select row(f.source, f.name, f.mime, f.rev_label, f.note, f.supersedes_id, f.team_id,
                      f.uploaded_by = pg_temp.uid('e2'), f.storage_path = pg_temp.dir('f001') || 'view.jpg')::text
           from public.library_files f where f.id = pg_temp.f('f001')),
  row('model_view', 'Level 3 sleeves', 'image/jpeg', 'V1', 'From the coordination model', null::uuid, null::uuid,
      true, true)::text,
  'it is a Library file of source model_view: title, V1, note, view.jpg');
select is((select row(m.space_id = pg_temp.sp(), m.team_id, m.version, m.viewpoint_guid = pg_temp.vp(1),
                      m.thumb_path = pg_temp.dir('f001') || 'thumb.jpg', m.camera, m.comments,
                      m.viewpoint_folder, m.model_title, m.model_file, m.image_width, m.image_height,
                      m.navisworks)::text
           from public.model_views m where m.library_file_id = pg_temp.f('f001')),
  row(true, null::uuid, 1, true, true, '{"type": "perspective", "position": [1, 2, 3]}'::jsonb,
      '[{"author": "Islam", "body": "Check the sleeves at C7"}]'::jsonb,
      'BuildVibes 360', 'Tower A', 'TowerA.nwf', 1920, 1080, '2025')::text,
  'with its model view row: chain key, version, thumb, camera and comments as JSON');

-- Reading -------------------------------------------------------------------------------------

select pg_temp.as_user('e7');
set local role authenticated;
select is(pg_temp.views_seen('f001'), 1::bigint, 'a member reads the model view');
select ok(public.may_read_file(pg_temp.dir('f001') || 'thumb.jpg', pg_temp.uid('e2')::text)
          and public.may_read_file(pg_temp.dir('f001') || 'view.jpg', pg_temp.uid('e2')::text),
  'and may open its image and thumb');
reset role;
select pg_temp.as_user('e4');
set local role authenticated;
select is(pg_temp.views_seen('f001'), 1::bigint, 'a Viewer reads it too');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select is(pg_temp.views_seen('f001'), 0::bigint, 'a non-member can''t read the model view');
select is((select count(*) from public.library_files where id = pg_temp.f('f001')), 0::bigint,
  'or its Library file');
select ok(not public.may_read_file(pg_temp.dir('f001') || 'thumb.jpg', pg_temp.uid('e2')::text)
          and not public.may_read_file(pg_temp.dir('f001') || 'view.jpg', pg_temp.uid('e2')::text),
  'or open its image or thumb');
select is((select count(*) from public.my_model_views(array[pg_temp.vp(1)])), 0::bigint,
  'and my_model_views shows her nothing of it');
reset role;

-- No direct writes.
select pg_temp.as_user('e2');
set local role authenticated;
select throws_ok(
  format($$insert into public.model_views (library_file_id, thumb_path, camera, viewpoint_guid, space_id, version)
           values (%L, %L, '{}', %L, %L, 9)$$,
         pg_temp.f('f001'), pg_temp.dir('f001') || 'thumb.jpg', pg_temp.vp(1), pg_temp.sp()),
  '42501', null, 'nobody inserts a model view directly');
select throws_ok($$update public.model_views set camera = '{"moved": true}'$$,
  '42501', null, 'or changes one');
select throws_ok($$delete from public.model_views$$, '42501', null, 'or deletes one');
reset role;

-- Who may publish -------------------------------------------------------------------------------

select pg_temp.upload_view('f090', 'e5');
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok($$select pg_temp.pub('f090', 1)$$, '42501', 'not allowed',
  'a non-member can''t publish into the Space, even with her own upload there');
reset role;
select pg_temp.upload_view('f091', 'e4');
select pg_temp.as_user('e4');
set local role authenticated;
select throws_ok($$select pg_temp.pub('f091', 1)$$, '42501', 'not allowed',
  'a Viewer pass can''t publish');
reset role;
select pg_temp.upload_view('f092', 'e2', pg_temp.other());
select pg_temp.as_user('e2');
set local role authenticated;
select throws_ok($$select pg_temp.pub('f092', 1, p_space => pg_temp.other())$$, '42501', 'not allowed',
  'nobody publishes into a Space they are not in');
select throws_ok($$select pg_temp.pub('f090', 1)$$, '22023', 'file not uploaded',
  'nobody publishes someone else''s upload');
reset role;
select pg_temp.upload(pg_temp.dir('f093') || 'view.jpg', 'e2');
select pg_temp.upload_view('f094', 'e2');
select pg_temp.upload(pg_temp.dir('f095') || 'view.jpg', 'e2');
select pg_temp.upload(pg_temp.dir('f095') || 'thumb.jpg', 'e2', 'image/png');
select pg_temp.upload(pg_temp.dir('f096') || 'image.jpg', 'e2');
select pg_temp.upload(pg_temp.dir('f096') || 'thumb.jpg', 'e2');
select pg_temp.as_user('e2');
set local role authenticated;
select throws_ok($$select pg_temp.pub('f093', 1)$$, '22023', 'file not uploaded',
  'the thumb must be uploaded too');
select throws_ok($$select pg_temp.pub('f094', 1, p_thumb => pg_temp.dir('f001') || 'thumb.jpg')$$,
  '22023', 'file not uploaded', 'the thumb must be in the view''s own folder');
select throws_ok($$select pg_temp.pub('f096', 1, p_image => pg_temp.dir('f096') || 'image.jpg')$$,
  '22023', 'file not uploaded', 'the image must be view.jpg');
select throws_ok($$select pg_temp.pub('f094', 1, p_thumb => pg_temp.dir('f094') || 'view.jpg')$$,
  '22023', 'file not uploaded', 'the thumb must be thumb.jpg, not the image again');
select throws_ok($$select pg_temp.pub('f095', 1)$$, '22023', 'file type does not match the upload',
  'both files must be JPEG uploads');
select is(pg_temp.pub('f001', 1), 'V1',
  'a retry of the same publish by the same caller returns the same version (M1)');
select is((select count(*) from public.model_views where viewpoint_guid = pg_temp.vp(1)), 1::bigint,
  'and publishes nothing new');
select throws_ok($$select pg_temp.pub('f001', 2)$$, '22023', 'this id is taken',
  'the same id for another viewpoint is refused');
select throws_ok($$select pg_temp.pub('f001', 1, p_thumb => pg_temp.dir('f094') || 'thumb.jpg')$$,
  '22023', 'this id is taken', 'the same id with another thumb is refused');
reset role;
select pg_temp.as_user('e7');
set local role authenticated;
select throws_ok($$select pg_temp.pub('f001', 1)$$, '22023', 'this id is taken',
  'someone else retrying the id is refused');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;

-- R4: limits on what the plugin sends ----------------------------------------------------------

select throws_ok($$select pg_temp.pub('f094', 1, p_camera => 'not json')$$, '22023', 'camera is not valid',
  'a camera that is not JSON is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_camera => '[1, 2, 3]')$$, '22023', 'camera is not valid',
  'a camera that is not an object is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_camera => '"camera"')$$, '22023', 'camera is not valid',
  'a JSON string as camera is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_camera => '{"a": "' || repeat('x', 4090) || '"}')$$,
  '22023', 'camera is not valid', 'a camera over 4 KB is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_camera => null)$$, '22023', 'camera is not valid',
  'a missing camera is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_comments => '[{"author": "A", "body": ')$$,
  '22023', 'comments are not valid', 'comments that are not JSON are refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_comments => '{"author": "A", "body": "B"}')$$,
  '22023', 'comments are not valid', 'comments that are not an array are refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_comments => (
    select jsonb_agg(jsonb_build_object('author', 'A', 'body', 'B')) from generate_series(1, 21))::text)$$,
  '22023', 'comments are not valid', 'more than 20 comments are refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_comments => '["just text"]')$$,
  '22023', 'comments are not valid', 'a comment must be an object');
select throws_ok($$select pg_temp.pub('f094', 1, p_comments => '[{"author": "A", "body": "B", "status": "open"}]')$$,
  '22023', 'comments are not valid', 'a comment has author and body, nothing else');
select throws_ok($$select pg_temp.pub('f094', 1, p_comments => '[{"author": "A"}]')$$,
  '22023', 'comments are not valid', 'a comment without a body is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_comments => '[{"author": "A", "body": 5}]')$$,
  '22023', 'comments are not valid', 'a comment body must be text');
select throws_ok($$select pg_temp.pub('f094', 1, p_comments =>
    jsonb_build_array(jsonb_build_object('author', 'A', 'body', repeat('b', 1001)))::text)$$,
  '22023', 'comments are not valid', 'a comment body over 1000 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_comments =>
    jsonb_build_array(jsonb_build_object('author', repeat('a', 121), 'body', 'B'))::text)$$,
  '22023', 'comments are not valid', 'a comment author over 120 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_name => '   ')$$, '22023', 'the title is not valid',
  'an empty title is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_name => repeat('t', 121))$$, '22023', 'the title is not valid',
  'a title over 120 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_note => 'Line one' || chr(10) || 'line two')$$,
  '22023', 'the note is not valid', 'the note is one line');
select throws_ok($$select pg_temp.pub('f094', 1, p_note => repeat('n', 301))$$, '22023', 'the note is not valid',
  'a note over 300 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_model_title => repeat('m', 201))$$,
  '22023', 'the model details are too long', 'a model title over 200 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_folder => repeat('m', 201))$$,
  '22023', 'the model details are too long', 'a viewpoint folder over 200 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_width => 0)$$, '22023', 'the image size is not valid',
  'an image width of 0 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_width => 10001)$$, '22023', 'the image size is not valid',
  'an image wider than 10000 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_model_file => repeat('m', 201))$$,
  '22023', 'the model details are too long', 'a model file name over 200 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_navisworks => repeat('2', 21))$$,
  '22023', 'the model details are too long', 'a Navisworks version over 20 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_height => 0)$$, '22023', 'the image size is not valid',
  'an image height of 0 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_height => 10001)$$, '22023', 'the image size is not valid',
  'an image taller than 10000 is refused');
select throws_ok($$select pg_temp.pub('f094', 1, p_bytes => -1)$$, '22023', 'the file size is not valid',
  'a negative file size is refused');
select is((select count(*) from public.library_files where id = pg_temp.f('f094')), 0::bigint,
  'nothing was written by the refused calls');
reset role;
select pg_temp.upload_view('f011', 'e2');
select pg_temp.upload_view('f013', 'e2');
select pg_temp.upload_view('f012', 'e2');
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.pub('f011', 11, p_camera => '{"a": "' || repeat('x', 4087) || '"}'), 'V1',
  'a camera of exactly 4 KB is accepted');
select is(pg_temp.pub('f012', 12, p_name => '  Riser 4  ', p_note => '   ', p_folder => '  ',
                      p_model_title => '  Tower A  ', p_model_file => '', p_comments => '[]'), 'V1',
  'a publish with empty extras is accepted');
select is(pg_temp.pub('f013', 13, p_comments => (
    select jsonb_agg(case n when 1 then jsonb_build_object('author', repeat('a', 120), 'body', repeat('b', 1000))
                            when 2 then jsonb_build_object('author', null, 'body', 'No author')
                            else jsonb_build_object('author', 'A', 'body', 'B') end order by n)
    from generate_series(1, 20) n)::text), 'V1',
  'the edges are accepted: 20 comments, a body of 1000, an author of 120, a null author');
select is((select row(jsonb_array_length(m.comments), length(m.comments -> 0 ->> 'author'),
                      length(m.comments -> 0 ->> 'body'), jsonb_typeof(m.comments -> 1 -> 'author'))::text
           from public.model_views m where m.library_file_id = pg_temp.f('f013')),
  row(20, 120, 1000, 'null')::text, 'and stored as sent');
select is((select row(f.name, f.note, m.viewpoint_folder, m.model_title, m.model_file, m.comments)::text
           from public.library_files f join public.model_views m on m.library_file_id = f.id
           where f.id = pg_temp.f('f012')),
  row('Riser 4', null::text, null::text, 'Tower A', null::text, '[]'::jsonb)::text,
  'text is trimmed and empty becomes null');
reset role;

-- Teams --------------------------------------------------------------------------------------------

select pg_temp.upload_view('f020', 'e3');
select pg_temp.upload_view('f021', 'e1');
select pg_temp.upload_view('f022', 'e2');
select pg_temp.as_user('e2');
set local role authenticated;
select throws_ok($$select pg_temp.pub('f022', 1, pg_temp.mep())$$, '42501', 'not allowed for this Team',
  'only the Team''s members publish to a Team');
select throws_ok($$select pg_temp.pub('f022', 1, gen_random_uuid())$$, '42501', 'not allowed for this Team',
  'a Team must be in that Space');
reset role;
select pg_temp.as_user('e3');
set local role authenticated;
select is(pg_temp.pub('f020', 1, pg_temp.mep(), 'MEP sleeves'), 'V1',
  'the same viewpoint published to a Team starts its own chain at V1 (R3)');
select is(pg_temp.supersedes('f020'), null::uuid, 'and supersedes nothing in the whole-Space chain');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.pub('f021', 1, pg_temp.mep(), 'MEP sleeves'), 'V2',
  'an admin outside the Team may publish to it: V2');
select is(pg_temp.supersedes('f021'), pg_temp.f('f020'), 'superseding the Team''s V1');
reset role;
select pg_temp.as_user('e7');
set local role authenticated;
select is(pg_temp.views_seen('f020'), 0::bigint, 'a Team view is not readable outside the Team');
select ok(not public.may_read_file(pg_temp.dir('f020') || 'thumb.jpg', pg_temp.uid('e3')::text)
          and not public.may_read_file(pg_temp.dir('f020') || 'view.jpg', pg_temp.uid('e3')::text),
  'nor its image or thumb');
reset role;
select pg_temp.as_user('e6');
set local role authenticated;
select is(pg_temp.views_seen('f020'), 1::bigint, 'a Team member reads it');
select ok(public.may_read_file(pg_temp.dir('f020') || 'thumb.jpg', pg_temp.uid('e3')::text),
  'and opens its thumb');
reset role;

-- Publish targets ----------------------------------------------------------------------------

select pg_temp.as_user('e3');
set local role authenticated;
select is(pg_temp.targets(), array['Tower site/*', 'Tower site/MEP'],
  'targets: the whole Space, then the caller''s Teams');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.targets(), array['Tower site/*', 'Tower site/Civil', 'Tower site/MEP'],
  'an admin may publish to every Team, by name');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.targets(), array['Tower site/*'], 'Crew in no Team: the whole Space only');
reset role;
select pg_temp.as_user('e4');
set local role authenticated;
select is(pg_temp.targets(), array[]::text[], 'a Viewer has no targets');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select is(pg_temp.targets(), array['Eve office/*'], 'a non-member sees only her own Space');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.old', public.create_space('Old site')::text, true);
select is(pg_temp.targets(), array['Old site/*', 'Tower site/*', 'Tower site/Civil', 'Tower site/MEP'],
  'Spaces are ordered by name');
select public.delete_space(current_setting('test.old')::uuid);
select is(pg_temp.targets(), array['Tower site/*', 'Tower site/Civil', 'Tower site/MEP'],
  'a deleted Space is no longer a target');
reset role;
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('e7');
select pg_temp.as_user('e7');
set local role authenticated;
select is(pg_temp.targets(), array[]::text[], 'an account scheduled for deletion has no targets (L1)');
reset role;
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('e7');

-- Versions and supersede (R3) ---------------------------------------------------------------------

select pg_temp.upload_view('f002', 'e7');
select pg_temp.upload_view('f003', 'e2');
select pg_temp.upload_view('f004', 'e2');
select pg_temp.upload_view('f005', 'e2');
select pg_temp.upload_view('f006', 'e2');
select pg_temp.upload_view('f030', 'e5', pg_temp.other());
select pg_temp.as_user('e7');
set local role authenticated;
select is(pg_temp.pub('f002', 1), 'V2', 'the same viewpoint again in the whole Space: V2, whoever publishes');
select is(pg_temp.supersedes('f002'), pg_temp.f('f001'), 'superseding V1');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.pub('f003', 2), 'V1', 'another viewpoint starts at V1');
select is(pg_temp.supersedes('f003'), null::uuid, 'and supersedes nothing');
reset role;
select pg_temp.as_user('e7');
set local role authenticated;
select lives_ok($$select public.delete_library_file(pg_temp.f('f002'))$$, 'Sami removes his V2 from the Library');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.pub('f004', 1), 'V3', 'the next version counts the removed one: V3, never a second V2');
select is(pg_temp.supersedes('f004'), pg_temp.f('f001'), 'and supersedes the newest one not removed (V1)');
select lives_ok($$select public.delete_library_file(pg_temp.f('f004'))$$, 'Rakesh removes V3');
select lives_ok($$select public.delete_library_file(pg_temp.f('f001'))$$, 'and V1');
select is(pg_temp.pub('f005', 1), 'V4', 'with every version removed, the next is still V4');
select is(pg_temp.supersedes('f005'), null::uuid, 'superseding nothing');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select is(pg_temp.pub('f030', 1, p_space => pg_temp.other()), 'V1',
  'the same viewpoint in another Space is its own chain');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
-- The viewpoint of f003 (vp 2) is deleted in Navisworks and the view saved
-- again: Navisworks gives it a new Guid (vp 6).
select is(pg_temp.pub('f006', 6), 'V1', 'a viewpoint saved again in Navisworks (new Guid) starts at V1');
select is((select row(f.deleted_at is null, v.is_current)::text
           from public.library_files f, public.my_model_views(array[pg_temp.vp(2)]) v
           where f.id = pg_temp.f('f003') and v.library_file_id = f.id),
  row(true, true)::text,
  'a deleted viewpoint has no effect: its published view stays in the Library, current');
reset role;
select is((select count(*) from public.library_files f
           where f.id in (pg_temp.f('f001'), pg_temp.f('f002'), pg_temp.f('f004'))
             and f.deleted_at is not null), 3::bigint,
  'removed versions stay in the record');
select pg_temp.upload(pg_temp.dir('f097') || 'plan.pdf', 'e2', 'application/pdf');
select pg_temp.as_user('e2');
set local role authenticated;
select throws_ok(
  format($$select public.add_library_file(%L, %L, 'Shaft plan', %L, 'application/pdf', null, null, 'Rev B', null, %L)$$,
         pg_temp.f('f097'), pg_temp.sp(), pg_temp.dir('f097') || 'plan.pdf', pg_temp.f('f003')),
  '22023', 'a model view''s versions come only from BuildVibes 360',
  'an ordinary upload can''t continue a model view''s versions (L2)');
select lives_ok(
  format($$select public.add_library_file(%L, %L, 'Shaft plan', %L, 'application/pdf', null, null, 'Rev A')$$,
         pg_temp.f('f097'), pg_temp.sp(), pg_temp.dir('f097') || 'plan.pdf'),
  'the same upload without it is added');
select throws_ok($$select pg_temp.pub('f001', 1)$$, '22023', 'this id is taken',
  'a removed view''s id is not published again by a retry');
reset role;

-- R2: two publishes at once -------------------------------------------------------------------

select ok(exists (select 1 from pg_locks l
                  where l.locktype = 'advisory' and l.pid = pg_backend_pid() and l.granted
                    and l.objsubid = 1
                    and (l.classid::bigint << 32) + l.objid::bigint
                        = public.model_view_chain_key(pg_temp.sp(), null, pg_temp.vp(1))),
  'publishing holds the chain''s lock until the transaction ends, so a second publish waits');
select ok(public.model_view_chain_key(pg_temp.sp(), null, pg_temp.vp(1))
          <> public.model_view_chain_key(pg_temp.sp(), pg_temp.mep(), pg_temp.vp(1))
          and public.model_view_chain_key(pg_temp.sp(), null, pg_temp.vp(1))
          <> public.model_view_chain_key(pg_temp.other(), null, pg_temp.vp(1)),
  'each chain has its own lock');
insert into public.library_files (id, space_id, name, storage_path, mime, source, rev_label)
values (pg_temp.f('f040'), pg_temp.sp(), 'Race', pg_temp.dir('f040') || 'view.jpg', 'image/jpeg',
        'model_view', 'V1'),
       (pg_temp.f('f041'), pg_temp.sp(), 'Race', pg_temp.dir('f041') || 'view.jpg', 'image/jpeg',
        'model_view', 'V1');
select throws_ok(
  format($$insert into public.model_views (library_file_id, thumb_path, camera, viewpoint_guid, space_id, version)
           values (%L, %L, '{}', %L, %L, 4)$$,
         pg_temp.f('f040'), pg_temp.dir('f040') || 'thumb.jpg', pg_temp.vp(1), pg_temp.sp()),
  '23505', null, 'a second V4 of the same whole-Space chain is refused by the unique index');
select throws_ok(
  format($$insert into public.model_views (library_file_id, thumb_path, camera, viewpoint_guid, space_id, team_id, version)
           values (%L, %L, '{}', %L, %L, %L, 2)$$,
         pg_temp.f('f041'), pg_temp.dir('f041') || 'thumb.jpg', pg_temp.vp(1), pg_temp.sp(), pg_temp.mep()),
  '23505', null, 'and a second V2 of the Team chain');
select lives_ok(
  format($$insert into public.model_views (library_file_id, thumb_path, camera, viewpoint_guid, space_id, version)
           values (%L, %L, '{}', %L, %L, 1)$$,
         pg_temp.f('f041'), pg_temp.dir('f041') || 'thumb.jpg', pg_temp.vp(99), pg_temp.sp()),
  'the same version of another viewpoint is fine');
select throws_ok(
  format($$insert into public.model_views (library_file_id, thumb_path, camera, viewpoint_guid, space_id, version)
           values (%L, %L, '{}', %L, %L, 1)$$,
         pg_temp.f('f040'), pg_temp.dir('f041') || 'thumb.jpg', pg_temp.vp(98), pg_temp.sp()),
  '23514', null, 'a thumb must be in its own view''s folder');
delete from public.library_files where id in (pg_temp.f('f040'), pg_temp.f('f041'));

-- R5: Used in, with the site photo, across versions -------------------------------------------------

select pg_temp.upload_view('f050', 'e2');
select pg_temp.upload_view('f051', 'e2');
select pg_temp.as_user('e2');
set local role authenticated;
select set_config('test.loose', (select files::text from public.loose_uploads()), true);
select is(pg_temp.pub('f050', 7, p_name => 'Shaft 2'), 'V1', 'Rakesh publishes Shaft 2: V1');
select is((select files from public.loose_uploads()), current_setting('test.loose')::bigint - 2,
  'its view and thumb no longer count as loose uploads (R1)');
select is(pg_temp.pub('f051', 7, p_name => 'Shaft 2'), 'V2', 'and again: V2');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Fix shaft 2 sleeves', pg_temp.uid('e7'), p_id => pg_temp.f('c001'));
select public.create_work_item(pg_temp.sp(), 'Seal shaft 2', pg_temp.uid('e7'), p_id => pg_temp.f('c002'));
select public.create_work_item(pg_temp.sp(), 'MEP shaft 2 check', pg_temp.uid('e6'), null, pg_temp.mep(),
                               p_id => pg_temp.f('c003'));
select lives_ok($$select public.attach_library_file(pg_temp.f('c001'), pg_temp.f('f050'))$$,
  'Omar attaches V1 to a work item');
select public.attach_library_file(pg_temp.f('c002'), pg_temp.f('f051'));
select public.attach_library_file(pg_temp.f('c003'), pg_temp.f('f051'));
select public.attach_library_file(pg_temp.f('c002'), pg_temp.f('f050'));
reset role;
select pg_temp.stamp(60);
select pg_temp.upload(pg_temp.sp()::text || '/' || pg_temp.f('c001')::text || '/first.jpg', 'e7');
select pg_temp.upload(pg_temp.sp()::text || '/' || pg_temp.f('c001')::text || '/second.jpg', 'e7');
select pg_temp.upload(pg_temp.sp()::text || '/' || pg_temp.f('c001')::text || '/again.jpg', 'e7');
select pg_temp.as_user('e7');
set local role authenticated;
select public.sign_done(pg_temp.f('c001'), 'Fixed.', jsonb_build_array(
  jsonb_build_object('path', pg_temp.sp()::text || '/' || pg_temp.f('c001')::text || '/first.jpg'),
  jsonb_build_object('path', pg_temp.sp()::text || '/' || pg_temp.f('c001')::text || '/second.jpg')));
reset role;
select pg_temp.stamp(30);
-- The second photo of that sign-off was added a moment after the first.
update public.work_item_evidence set created_at = created_at + interval '1 second'
where storage_path like '%/second.jpg';
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_back(pg_temp.f('c001'), 'not_finished', 'Two sleeves are loose.');
reset role;
select pg_temp.stamp(20);

select pg_temp.as_user('e2');
set local role authenticated;
select is(array(select v.rev_label from public.my_model_views(array[pg_temp.vp(7)]) v), array['V2', 'V1'],
  'my_model_views: every version of the viewpoint, newest first');
select is(array(select v.is_current from public.my_model_views(array[pg_temp.vp(7)]) v), array[true, false],
  'only the newest is current');
select is(array(select v.space_name || '/' || coalesce(v.team_name, '*') || '/' || v.title
                from public.my_model_views(array[pg_temp.vp(7)]) v),
  array['Tower site/*/Shaft 2', 'Tower site/*/Shaft 2'], 'with the Space and title');
select is((select array(select u ->> 'item_id' from jsonb_array_elements(v.uses) u order by u ->> 'item_id')
           from public.my_model_views(array[pg_temp.vp(7)]) v where v.rev_label = 'V1'),
  array[pg_temp.f('c001')::text, pg_temp.f('c002')::text],
  'uses cover every version: V1''s row lists the item that uses V2');
select is((select array(select u ->> 'item_id' from jsonb_array_elements(v.uses) u order by u ->> 'item_id')
           from public.my_model_views(array[pg_temp.vp(7)]) v where v.rev_label = 'V2'),
  array[pg_temp.f('c001')::text, pg_temp.f('c002')::text],
  'and V2''s row the item that uses V1; each item once, the Team item he can''t see left out');
select is((select u from public.my_model_views(array[pg_temp.vp(7)]) v, jsonb_array_elements(v.uses) u
           where v.rev_label = 'V2' and u ->> 'item_id' = pg_temp.f('c001')::text),
  jsonb_build_object('ref', (select ref from public.work_items where id = pg_temp.f('c001')),
                     'title', 'Fix shaft 2 sleeves', 'status', 'sent_back',
                     'item_id', pg_temp.f('c001'),
                     'at', (select last_activity_at from public.space_posts where id = pg_temp.f('c001')),
                     'proof_path', pg_temp.sp()::text || '/' || pg_temp.f('c001')::text || '/first.jpg'),
  'a use: ref, title, sent back, the item''s last activity and the sign-off''s first photo');
select is((select u ->> 'status' || '/' || coalesce(u ->> 'proof_path', 'none')
           from public.my_model_views(array[pg_temp.vp(7)]) v, jsonb_array_elements(v.uses) u
           where v.rev_label = 'V2' and u ->> 'item_id' = pg_temp.f('c002')::text),
  'open/none', 'an item never signed: open, no photo');
select is((select (v.uses -> 0 ->> 'item_id') from public.my_model_views(array[pg_temp.vp(7)]) v
           where v.rev_label = 'V2'),
  pg_temp.f('c001')::text, 'the most recent activity first');
reset role;

select pg_temp.as_user('e7');
set local role authenticated;
select public.sign_done(pg_temp.f('c001'), 'Tightened.', jsonb_build_array(
  jsonb_build_object('path', pg_temp.sp()::text || '/' || pg_temp.f('c001')::text || '/again.jpg')));
reset role;
select pg_temp.stamp(10);
select pg_temp.as_user('e2');
set local role authenticated;
select is((select u ->> 'status' || '/' || (u ->> 'proof_path')
           from public.my_model_views(array[pg_temp.vp(7)]) v, jsonb_array_elements(v.uses) u
           where v.rev_label = 'V2' and u ->> 'item_id' = pg_temp.f('c001')::text),
  'done/' || pg_temp.sp()::text || '/' || pg_temp.f('c001')::text || '/again.jpg',
  'signed again: done, with the latest sign-off''s photo');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select public.check_item(pg_temp.f('c001'));
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select is((select u ->> 'status' from public.my_model_views(array[pg_temp.vp(7)]) v, jsonb_array_elements(v.uses) u
           where v.rev_label = 'V2' and u ->> 'item_id' = pg_temp.f('c001')::text),
  'checked', 'checked');
select ok(public.may_read_file(pg_temp.sp()::text || '/' || pg_temp.f('c001')::text || '/again.jpg',
                               pg_temp.uid('e7')::text),
  'the publisher may open the site photo with his own session');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select public.cancel_space_post(pg_temp.f('c002'), 'Not needed.');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select is((select u ->> 'status' from public.my_model_views(array[pg_temp.vp(7)]) v, jsonb_array_elements(v.uses) u
           where v.rev_label = 'V2' and u ->> 'item_id' = pg_temp.f('c002')::text),
  'cancelled', 'a cancelled item shows as cancelled');
reset role;

select pg_temp.as_user('e6');
set local role authenticated;
select is((select count(*) from public.my_model_views(array[pg_temp.vp(7)])), 0::bigint,
  'my_model_views lists only the caller''s own published views');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select is((select count(*) from public.my_model_views(array[pg_temp.vp(7)])), 0::bigint,
  'an admin sees only his own too');
select is(array(select v.rev_label || '/' || v.team_name from public.my_model_views(array[pg_temp.vp(1)]) v),
  array['V2/MEP'], 'Omar''s Team view, by Team');
reset role;
select pg_temp.as_user('e3');
set local role authenticated;
select is(array(select v.rev_label || '/' || v.team_name || '/' || v.is_current
                from public.my_model_views(array[pg_temp.vp(1)]) v),
  array['V1/MEP/false'], 'Nadia''s Team V1, no longer current');
select is((select uses from public.my_model_views(array[pg_temp.vp(1)])), '[]'::jsonb,
  'no item uses it: uses is []');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select public.set_team_members(pg_temp.mep(), array[pg_temp.uid('e6')]);
reset role;
select pg_temp.as_user('e3');
set local role authenticated;
select is((select count(*) from public.my_model_views(array[pg_temp.vp(1)])), 0::bigint,
  'out of the Team, Nadia no longer sees her Team view');
select is(pg_temp.targets(), array['Tower site/*'], 'or may publish to the Team');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select is(array(select v.rev_label from public.my_model_views(array[pg_temp.vp(1)]) v), array['V4'],
  'removed versions are not listed as published');
select is((select count(*) from public.my_model_views(array[pg_temp.vp(1), pg_temp.vp(2), pg_temp.vp(7)])),
  4::bigint, 'several viewpoints at once');
select is((select count(*) from public.my_model_views('{}')), 0::bigint, 'no viewpoints, no rows');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select is(array(select v.space_name || '/' || v.rev_label from public.my_model_views(array[pg_temp.vp(1), pg_temp.vp(7)]) v),
  array['Eve office/V1'], 'Eve sees only her own view, never the Tower site''s');
reset role;
select pg_temp.as_user('e2');
set local role authenticated;
select public.leave_space(pg_temp.sp());
select is((select count(*) from public.my_model_views(array[pg_temp.vp(1), pg_temp.vp(7)])), 0::bigint,
  'after leaving the Space, the publisher sees none of its views');
select throws_ok($$select pg_temp.pub('f094', 8)$$, '42501', 'not allowed', 'and can''t publish there');
select is(pg_temp.targets(), array[]::text[], 'a member who left has no targets there');
reset role;

-- R1: the cleanup never takes a published view ---------------------------------------------------

update storage.objects set created_at = now() - interval '8 days'
where bucket_id = 'space-files' and name like pg_temp.sp()::text || '/library/%';
select ok(not exists (select 1 from public.orphan_space_files() o
                      where o.name in (pg_temp.dir('f050') || 'view.jpg', pg_temp.dir('f050') || 'thumb.jpg',
                                       pg_temp.dir('f001') || 'view.jpg', pg_temp.dir('f001') || 'thumb.jpg')),
  'orphan_space_files lists neither view.jpg nor thumb.jpg of a published view, removed ones too');
select ok(exists (select 1 from public.orphan_space_files() o where o.name = pg_temp.dir('f094') || 'thumb.jpg'),
  'while a thumb that was never published is still cleaned up');
select ok(public.is_referenced_file(pg_temp.dir('f002') || 'thumb.jpg'),
  'a removed version''s thumb stays referenced, like its image');
select pg_temp.as_user('e7');
set local role authenticated;
select ok(not public.may_delete_file(pg_temp.dir('f002') || 'thumb.jpg', pg_temp.uid('e7')::text),
  'so its uploader can''t delete it from storage');
reset role;
select pg_temp.upload_view('f060', 'e3');
insert into public.file_cleanup_claims (storage_path) values (pg_temp.dir('f060') || 'thumb.jpg');
select pg_temp.as_user('e3');
set local role authenticated;
select throws_ok($$select pg_temp.pub('f060', 9)$$, '22023', 'this file was cleaned up; upload it again',
  'a thumb the cleanup has claimed can''t be published');
reset role;

-- Removed and hidden views: their files are closed to other members.
select pg_temp.as_user('e6');
set local role authenticated;
select ok(not public.may_read_file(pg_temp.dir('f002') || 'thumb.jpg', pg_temp.uid('e7')::text)
          and not public.may_read_file(pg_temp.dir('f002') || 'view.jpg', pg_temp.uid('e7')::text),
  'another member can''t open a removed model view''s thumb or image');
select ok(public.may_read_file(pg_temp.dir('f003') || 'thumb.jpg', pg_temp.uid('e2')::text),
  'while a live one''s thumb opens');
reset role;
-- As a moderator's removal does: deleted_at, no deleted_by.
update public.library_files set deleted_at = now() where id = pg_temp.f('f003');
select pg_temp.as_user('e6');
set local role authenticated;
select ok(not public.may_read_file(pg_temp.dir('f003') || 'thumb.jpg', pg_temp.uid('e2')::text)
          and not public.may_read_file(pg_temp.dir('f003') || 'view.jpg', pg_temp.uid('e2')::text),
  'or a model view hidden by moderation');
select is(pg_temp.views_seen('f003'), 0::bigint, 'and its model view row is not readable');
reset role;

select * from finish();
rollback;
