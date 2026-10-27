-- Migration 44 (F107, review 92): a note as a page of blocks, its location
-- and its PDFs. Run with: supabase test db
--
-- Omar (e1) owns the notes and is in a Space with Rakesh (e2). Eve (e3) is
-- in no Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(72);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000044' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@notebook44.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000044' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000044' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000044' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000044' || p)::uuid;
$$;
-- A file in notebook-files, uploaded by [p_who] (as Storage records it).
create function pg_temp.upload(p_who text, p_note text, p_file text, p_mime text) returns text
language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('notebook-files', pg_temp.uid(p_who) || '/' || pg_temp.id(p_note) || '/' || p_file,
          pg_temp.uid(p_who)::text, jsonb_build_object('mimetype', p_mime, 'size', 1000))
  returning name;
$$;
create function pg_temp.path(p_who text, p_note text, p_file text) returns text language sql as $$
  select pg_temp.uid(p_who) || '/' || pg_temp.id(p_note) || '/' || p_file;
$$;
-- A block of [p_type] with a fresh id.
create function pg_temp.b(p_type text, p_text text default 'x') returns jsonb language sql as $$
  select jsonb_build_object('id', gen_random_uuid(), 'type', p_type, 'text', p_text);
$$;
-- save_note for a page, by name.
create function pg_temp.page(p_note text, p_blocks jsonb, p_files jsonb default null,
                             p_location jsonb default null, p_kind text default 'text')
returns uuid language sql as $$
  select public.save_note(p_id => pg_temp.id(p_note), p_kind => p_kind, p_body => 'words',
                          p_blocks => p_blocks, p_files => p_files, p_location => p_location);
$$;

-- Columns and grants ---------------------------------------------------------------------------

select has_column('public', 'notes', 'blocks', 'notes has blocks');
select has_column('public', 'notes', 'title', 'notes has a title');
select has_column('public', 'notes', 'location_text', 'notes has a typed location');
select has_column('public', 'notes', 'location_lat', 'and a latitude');
select has_column('public', 'notes', 'location_lng', 'and a longitude');
select has_column('public', 'notes', 'location_accuracy_m', 'and its accuracy');
select has_column('public', 'note_files', 'name', 'a file keeps its name');
select ok(not has_function_privilege('anon',
  'public.save_note(uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb, text, jsonb, jsonb, timestamptz, integer)',
  'execute'), 'signed out: no save_note');
select ok(not has_function_privilege('anon', 'public.note_for_space(uuid, boolean)', 'execute'),
  'signed out: no note_for_space');
select ok((select 'application/pdf' = any (allowed_mime_types) from storage.buckets
           where id = 'notebook-files'), 'notebook-files takes PDFs');
select is((select file_size_limit from storage.buckets where id = 'notebook-files'), 26214400::bigint,
  'up to the Library''s 25 MB');

-- The owner writes and reads a page, a location and a file ------------------------------------

select pg_temp.upload('e1', 'b001', 'drawing.pdf', 'application/pdf');
select pg_temp.upload('e1', 'b001', 'walk.m4a', 'audio/mp4');
select pg_temp.upload('e1', 'b001', 'p1.jpg', 'image/jpeg');
select pg_temp.as_user('e1');
set local role authenticated;
select ok(public.may_upload_note_file(pg_temp.path('e1', 'b002', 'A-501.pdf')),
  'Omar may upload a PDF into his own folder');
select is(public.save_note(
  p_id => pg_temp.id('b001'), p_kind => 'text',
  p_body => E'Before the pour, level 3\nCheck the sleeves',
  p_title => 'Before the pour, level 3',
  p_blocks => jsonb_build_array(
    jsonb_build_object('id', 'b0000000-0000-4000-8000-000000000001', 'type', 'todo',
                       'text', 'Check the sleeves', 'done', true),
    jsonb_build_object('id', 'b0000000-0000-4000-8000-000000000002', 'type', 'heading',
                       'text', 'Pump', 'level', 2),
    jsonb_build_object('id', 'b0000000-0000-4000-8000-000000000003', 'type', 'bullet',
                       'text', 'Al Bahar, 2 pm'),
    jsonb_build_object('id', 'b0000000-0000-4000-8000-000000000004', 'type', 'table',
                       'rows', '[["Bay", "m3"], ["C7", "18"]]'::jsonb),
    jsonb_build_object('id', 'b0000000-0000-4000-8000-000000000005', 'type', 'toggle',
                       'text', 'Mix', 'children', jsonb_build_array(
                         jsonb_build_object('id', 'b0000000-0000-4000-8000-000000000006',
                                            'type', 'quote', 'text', 'C35'))),
    jsonb_build_object('id', 'b0000000-0000-4000-8000-000000000007', 'type', 'divider'),
    jsonb_build_object('id', 'b0000000-0000-4000-8000-000000000008', 'type', 'voice',
                       'path', pg_temp.path('e1', 'b001', 'walk.m4a'), 'duration_ms', 8000)),
  p_files => jsonb_build_array(
    jsonb_build_object('path', pg_temp.path('e1', 'b001', 'drawing.pdf'), 'name', 'A-501 Rev D.pdf',
                       'bytes', 2400000),
    jsonb_build_object('path', pg_temp.path('e1', 'b001', 'walk.m4a'), 'duration_ms', 8000),
    jsonb_build_object('path', pg_temp.path('e1', 'b001', 'p1.jpg'))),
  p_location => '{"text": "Level 3, grid C7", "lat": 29.37594, "lng": 47.9774, "accuracy_m": 8}'::jsonb,
  p_due_at => date_trunc('day', now()) + interval '14 hours'),
  pg_temp.id('b001'), 'Omar saves a page with a location, a PDF, a voice block and a photo');
select is((select jsonb_array_length(blocks) from public.notes where id = pg_temp.id('b001')), 7,
  'he reads its seven blocks');
select is((select blocks -> 0 ->> 'text' from public.notes where id = pg_temp.id('b001')),
  'Check the sleeves', 'in their order');
select is((select title from public.notes where id = pg_temp.id('b001')), 'Before the pour, level 3',
  'and its title');
select is((select kind from public.notes where id = pg_temp.id('b001')), 'text', 'a page is a text note');
select is((select location_text || ' ' || location_lat || ' ' || location_lng || ' ' || location_accuracy_m
           from public.notes where id = pg_temp.id('b001')),
  'Level 3, grid C7 29.375940 47.977400 8.0', 'its location, typed and GPS');
select is((select kind || ' ' || name || ' ' || bytes from public.note_files
           where note_id = pg_temp.id('b001') and mime = 'application/pdf'),
  'file A-501 Rev D.pdf 2400000', 'its PDF, by name');
select is((select array_agg(kind order by sort) from public.note_files where note_id = pg_temp.id('b001')),
  array['file', 'voice', 'photo'], 'a file, a recording and a photo');
select isnt((select due_at from public.notes where id = pg_temp.id('b001')), null,
  'a page may have a date');
select ok((select array_agg(c.title) from public.my_calendar(current_date - 1, current_date + 7,
                          date_trunc('day', now()) - interval '1 day',
                          date_trunc('day', now()) + interval '8 days') c)
          @> array['Before the pour, level 3'], 'it shows in My calendar by its title');
select is(public.save_note(p_id => pg_temp.id('b001'), p_kind => 'text', p_body => 'words',
                           p_title => 'Before the pour, level 3',
                           p_blocks => '[]'::jsonb, p_files => '[]'::jsonb),
  pg_temp.id('b001'), 'he can empty it again (a title is enough)');
select is((select count(*)::int from public.note_files where note_id = pg_temp.id('b001')), 0,
  'its files go with the list');
select is((select location_text from public.notes where id = pg_temp.id('b001')), null,
  'and a save with no location has none');

-- Typed only, GPS only
select lives_ok($$select pg_temp.page('b003', jsonb_build_array(pg_temp.b('text', 'Lift 2')), null,
                                       '{"text": "Grid A4"}'::jsonb)$$, 'a typed location only');
select lives_ok($$select pg_temp.page('b004', jsonb_build_array(pg_temp.b('text', 'Lift 3')), null,
                                       '{"lat": -33.9, "lng": 151.2, "accuracy_m": 12.5}'::jsonb)$$,
  'a GPS position only');
select is((select location_text is null and location_lat = -33.9 from public.notes where id = pg_temp.id('b004')),
  true, 'kept as it came');

-- The phone's time
select lives_ok($$select public.save_note(p_id => pg_temp.id('b005'), p_kind => 'text', p_body => 'Sent offline',
                                          p_created_at => now() - interval '3 hours')$$,
  'a note sent later keeps the phone''s time');
select ok((select created_at < now() - interval '2 hours' from public.notes where id = pg_temp.id('b005')),
  'it is the phone''s');
select lives_ok($$select public.save_note(p_id => pg_temp.id('b006'), p_kind => 'text', p_body => 'Ahead',
                                          p_created_at => now() + interval '2 days')$$, 'a time ahead');
select ok((select created_at <= now() from public.notes where id = pg_temp.id('b006')), 'is never ahead');
select lives_ok($$select public.save_note(p_id => pg_temp.id('b007'), p_kind => 'text', p_body => 'Old',
                                          p_created_at => now() - interval '30 days')$$, 'a time a month back');
select ok((select created_at > now() - interval '1 minute' from public.notes where id = pg_temp.id('b007')),
  'is the server''s');
select lives_ok($$select public.save_note(pg_temp.id('b008'), 'text', 'An old note, the old way')$$,
  'an old-style note still saves');

-- The validator refuses a bad page -------------------------------------------------------------

select ok(not public.is_valid_note_blocks('{}'::jsonb), 'a page is a list');
select ok(not public.is_valid_note_blocks(
  (select jsonb_agg(pg_temp.b('text')) from generate_series(1, 201))), 'at most 200 blocks');
select ok(public.is_valid_note_blocks(
  (select jsonb_agg(pg_temp.b('text')) from generate_series(1, 200))), '200 are fine');
select ok(not public.is_valid_note_blocks(jsonb_build_array(pg_temp.b('text', repeat('a', 5001)))),
  'a block''s text is at most 5000 characters');
select ok(public.is_valid_note_blocks(jsonb_build_array(pg_temp.b('callout', repeat('a', 5000)))),
  '5000 are fine');
select ok(not public.is_valid_note_blocks(jsonb_build_array(pg_temp.b('poem'))), 'not a kind of block');
select ok(not public.is_valid_note_blocks('[{"id": "x", "type": "text", "text": "a"}]'::jsonb),
  'each block has its uuid');
select ok(not public.is_valid_note_blocks(
  '[{"id": "b0000000-0000-4000-8000-0000000000a1", "type": "text", "text": "a"},
    {"id": "b0000000-0000-4000-8000-0000000000a1", "type": "text", "text": "b"}]'::jsonb),
  'used once');
select ok(not public.is_valid_note_blocks(jsonb_build_array(pg_temp.b('text') || '{"colour": "red"}')),
  'nothing a block doesn''t have');
select ok(not public.is_valid_note_blocks(jsonb_build_array(pg_temp.b('heading') || '{"level": 3}')),
  'a heading is level 1 or 2');
select ok(not public.is_valid_note_blocks(jsonb_build_array(pg_temp.b('todo') || '{"done": "yes"}')),
  'a to-do is done or not');
select ok(not public.is_valid_note_blocks(jsonb_build_array(
  pg_temp.b('toggle') || jsonb_build_object('children', jsonb_build_array(pg_temp.b('toggle')
                                             || '{"children": []}')))), 'no toggle in a toggle');
select ok(not public.is_valid_note_blocks(jsonb_build_array(jsonb_build_object(
  'id', gen_random_uuid(), 'type', 'table',
  'rows', (select jsonb_agg('["a"]'::jsonb) from generate_series(1, 21))))), 'a table has up to 20 rows');
select ok(not public.is_valid_note_blocks(jsonb_build_array(jsonb_build_object(
  'id', gen_random_uuid(), 'type', 'table', 'rows', '[["a", "b"], ["c"]]'::jsonb))), 'all as wide');
select throws_ok($$select pg_temp.page('b010', jsonb_build_array(pg_temp.b('text', repeat('a', 5001))))$$,
  '22023', null, 'save_note refuses a bad page');
select throws_ok($$select pg_temp.page('b010', jsonb_build_array(pg_temp.b('text')), null, null, 'todo')$$,
  '22023', null, 'a page is a text note''s');

-- Files and voice blocks
reset role;
select pg_temp.upload('e1', 'b011', 'a.m4a', 'audio/mp4');
select pg_temp.upload('e1', 'b012', 'a.pdf', 'application/pdf');
select pg_temp.upload('e1', 'b013', 'x.exe', 'application/x-msdownload');
select pg_temp.upload('e1', 'b014', 'p' || g || '.pdf', 'application/pdf') from generate_series(1, 11) g;
select pg_temp.as_user('e1');
set local role authenticated;
select throws_ok($$select pg_temp.page('b011', jsonb_build_array(pg_temp.b('text')),
                     jsonb_build_array(jsonb_build_object('path', pg_temp.path('e1', 'b011', 'a.m4a'))))$$,
  '22023', null, 'a recording on a page is a voice block''s');
select throws_ok($$select pg_temp.page('b011', jsonb_build_array(jsonb_build_object(
                     'id', gen_random_uuid(), 'type', 'voice', 'path', pg_temp.path('e1', 'b011', 'gone.m4a'))),
                     '[]'::jsonb)$$,
  '22023', null, 'a voice block is one of the note''s recordings');
select throws_ok($$select public.save_note(pg_temp.id('b012'), 'todo', 'Read it', null, null, null, null,
                     jsonb_build_array(jsonb_build_object('path', pg_temp.path('e1', 'b012', 'a.pdf'))))$$,
  '22023', null, 'a PDF goes on a note, not a to-do');
select throws_ok($$select pg_temp.page('b013', '[]'::jsonb,
                     jsonb_build_array(jsonb_build_object('path', pg_temp.path('e1', 'b013', 'x.exe'))))$$,
  '22023', null, 'photos, PDFs and voice notes only');
select throws_ok($$select pg_temp.page('b014', '[]'::jsonb,
                     (select jsonb_agg(jsonb_build_object('path', pg_temp.path('e1', 'b014', 'p' || g || '.pdf')))
                      from generate_series(1, 11) g))$$,
  '22023', null, 'at most 10 PDFs on a note');

-- Locations
select throws_ok($$select pg_temp.page('b015', '[]'::jsonb, null, '{"lat": 29.3}'::jsonb)$$,
  '22023', null, 'a position is both numbers');
select throws_ok($$select pg_temp.page('b015', '[]'::jsonb, null, '{"lat": 91, "lng": 47}'::jsonb)$$,
  '22023', null, 'in range');
select throws_ok($$select pg_temp.page('b015', '[]'::jsonb, null,
                     jsonb_build_object('text', repeat('a', 121)))$$,
  '22023', null, 'a typed location is up to 120 characters');
select throws_ok($$select pg_temp.page('b015', '[]'::jsonb, null,
                     '{"lat": 29.3, "lng": 47.9, "accuracy_m": 0}'::jsonb)$$,
  '22023', null, 'its accuracy is more than nothing');

-- Put in a Space: the typed location, not the GPS unless asked ---------------------------------

select is(public.save_note(p_id => pg_temp.id('b020'), p_kind => 'text', p_body => 'Pump booking',
                           p_title => 'Pump booking',
                           p_blocks => jsonb_build_array(pg_temp.b('text', 'Al Bahar, 2 pm slot.')),
                           p_location => '{"text": "Level 3, grid C7", "lat": 29.37594, "lng": 47.9774, "accuracy_m": 8}'::jsonb),
  pg_temp.id('b020'), 'a note with both');
select is(public.note_for_space(pg_temp.id('b020')) ->> 'location_text', 'Level 3, grid C7',
  'Put in a Space carries the typed location');
select ok(not (public.note_for_space(pg_temp.id('b020')) ?| array['location_lat', 'location_lng',
                                                                    'location_accuracy_m']),
  'but not the GPS');
select is(public.note_for_space(pg_temp.id('b020'), true) ->> 'location_lat', '29.375940',
  'unless "Include my GPS position" is ticked');
select is(public.note_for_space(pg_temp.id('b020')) ->> 'title', 'Pump booking', 'with its words');

-- Another person reads none of it ---------------------------------------------------------------

select pg_temp.as_user('e2');
select is((select count(*)::int from public.notes where owner_id = pg_temp.uid('e1')), 0,
  'Rakesh reads none of Omar''s pages');
select is((select count(*)::int from public.note_files f where f.note_id = pg_temp.id('b020')
           or f.note_id = pg_temp.id('b001')), 0, 'nor their files');
select throws_ok($$select public.note_for_space(pg_temp.id('b020'), true)$$, '42501', null,
  'nor what Put in a Space would carry');

-- Someone in no Space can't read or write any of it ---------------------------------------------

select pg_temp.as_user('e3');
select is((select count(*)::int from public.notes n where n.blocks is not null or n.location_text is not null),
  0, 'Eve reads no page and no location');
select is((select count(*)::int from storage.objects where bucket_id = 'notebook-files'
           and name like pg_temp.uid('e1') || '/%'), 0, 'nor a PDF in Storage');
select throws_ok($$select pg_temp.page('b020', jsonb_build_array(pg_temp.b('text', 'mine')))$$,
  '42501', null, 'nor saves over Omar''s page');
select ok(not public.may_upload_note_file(pg_temp.path('e1', 'b030', 'x.pdf')),
  'nor uploads a PDF into his folder');

reset role;
select * from finish();
rollback;
