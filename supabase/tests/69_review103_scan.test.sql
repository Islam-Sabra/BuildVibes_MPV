-- Review 103: a scan is a PDF in the places that already take one. The
-- Library and the notebook keep it marked scanned, with its page count;
-- a work item's proof can be a scanned PDF (kind 'scan'). Each follows its
-- place's read rules. Run with: supabase test db
--
-- Omar (a1) made the Space; Bilal (b2) is Crew; Eve (e5) is outside.

begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000069' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@scan.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('e5')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000069' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000069' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0069-' || lpad(p, 12, '0'))::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.reads(p_id text, p_sql text) returns integer language plpgsql as $$
declare v integer;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return v;
end;
$$;

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Scan site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp(), pg_temp.uid('b2'), 'crew', pg_temp.uid('a1'));

-- The Library: a scanned PDF Omar added, and a photo.
insert into public.library_files (id, space_id, name, storage_path, mime, bytes, uploaded_by)
values (pg_temp.id('f1'), pg_temp.sp(), 'Delivery note.pdf',
        pg_temp.sp() || '/library/' || pg_temp.id('f1') || '/a.pdf', 'application/pdf', 400000,
        pg_temp.uid('a1')),
       (pg_temp.id('f2'), pg_temp.sp(), 'Gate.jpg',
        pg_temp.sp() || '/library/' || pg_temp.id('f2') || '/a.jpg', 'image/jpeg', 90000,
        pg_temp.uid('a1'));

select is((select scanned from public.library_files where id = pg_temp.id('f1')), false,
  'a file is not scanned unless marked');
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.mark_library_file_scanned(pg_temp.id('f1'), 3)$$,
  'its uploader marks it scanned, 3 pages');
select throws_ok($$select public.mark_library_file_scanned(pg_temp.id('f2'), 1)$$, '22023', null,
  'only a PDF is a scan');
select throws_ok($$select public.mark_library_file_scanned(pg_temp.id('f1'), 21)$$, '22023', null,
  'a scan is 1 to 20 pages');
reset role;
select is((select scanned::text || ' ' || page_count from public.library_files where id = pg_temp.id('f1')),
  'true 3', 'marked, with its pages');
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.mark_library_file_scanned(pg_temp.id('f1'), 2)$$, '42501', null,
  'nobody else marks it');
reset role;
select is(pg_temp.reads('b2', format($$select count(*)::int from public.library_files
                                       where id = %L and scanned$$, pg_temp.id('f1'))), 1,
  'a member reads it, scanned');
select is(pg_temp.reads('e5', format($$select count(*)::int from public.library_files
                                       where id = %L$$, pg_temp.id('f1'))), 0,
  'someone outside the Space reads nothing');
select ok(not has_function_privilege('anon', 'public.mark_library_file_scanned(uuid, integer, text)', 'execute'),
  'not for the signed out');

-- The notebook: Omar's note with a scanned PDF.
insert into public.notes (id, owner_id, kind, body) values (pg_temp.id('a2'), pg_temp.uid('a1'), 'text', 'Delivery');
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('notebook-files', pg_temp.uid('a1') || '/' || pg_temp.id('a2') || '/s.pdf', pg_temp.uid('a1'),
   '{"mimetype": "application/pdf"}');
-- set_note_files is the save's own step (not callable by the app): as Omar.
select pg_temp.as_user('a1');
select lives_ok(format($$select public.set_note_files(%L, %L::jsonb)$$, pg_temp.id('a2'),
  jsonb_build_array(jsonb_build_object('path', pg_temp.uid('a1') || '/' || pg_temp.id('a2') || '/s.pdf',
    'mime', 'application/pdf', 'name', 'Cube test.pdf', 'scanned', true, 'page_count', 2))),
  'a note keeps a scanned PDF');
select is((select scanned::text || ' ' || page_count from public.note_files where note_id = pg_temp.id('a2')),
  'true 2', 'marked, with its pages');
select is(pg_temp.reads('b2', format($$select count(*)::int from public.note_files where note_id = %L$$,
                                     pg_temp.id('a2'))), 0, 'nobody else reads a note''s files');

-- Sign as done with a scan: Bilal's work item, his signed inspection request.
select pg_temp.as_user('a1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Inspect the slab', pg_temp.uid('b2'), p_id => pg_temp.id('c1'));
reset role;
-- D1: as a phone uploads them, each with its type.
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('space-files', pg_temp.sp() || '/' || pg_temp.id('c1') || '/proof.pdf', pg_temp.uid('b2'),
   '{"mimetype": "application/pdf"}'),
  ('space-files', pg_temp.sp() || '/' || pg_temp.id('c1') || '/proof.txt', pg_temp.uid('b2'),
   '{"mimetype": "text/plain"}');
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok(format($$select public.sign_done(%L, null, %L::jsonb)$$, pg_temp.id('c1'),
  jsonb_build_array(jsonb_build_object('path', pg_temp.sp() || '/' || pg_temp.id('c1') || '/proof.txt'))),
  '22023', null, 'proof is a photo or a scanned PDF only');
select lives_ok(format($$select public.sign_done(%L, null, %L::jsonb)$$, pg_temp.id('c1'),
  jsonb_build_array(jsonb_build_object('path', pg_temp.sp() || '/' || pg_temp.id('c1') || '/proof.pdf',
                                       'page_count', 2))),
  'the owner signs it done with a scan');
reset role;
select is((select kind || ' ' || page_count from public.work_item_evidence where work_item_id = pg_temp.id('c1')),
  'scan 2', 'the proof is a scan of 2 pages');
-- D1: the author checks it: CHECKED stamps the scanned proof.
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok(format($$select public.check_item(%L)$$, pg_temp.id('c1')),
  'D1: its author checks the scanned proof');
reset role;
select is((select status from public.work_items where id = pg_temp.id('c1')), 'checked',
  'D1: CHECKED');
select is(pg_temp.reads('e5', format($$select count(*)::int from public.work_item_evidence
                                       where work_item_id = %L$$, pg_temp.id('c1'))), 0,
  'someone outside the Space reads no proof');
select is(pg_temp.reads('b2', format($$select count(*)::int from public.work_item_evidence
                                       where work_item_id = %L$$, pg_temp.id('c1'))), 1,
  'the Space reads it');

select * from finish();
rollback;
