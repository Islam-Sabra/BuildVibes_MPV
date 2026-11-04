-- Review 103, OCR ("Extract text", before the pilot): a file's text, read
-- by Google Cloud Vision only when someone taps Extract text, is kept in
-- file_texts and read exactly as the file is read; it is searchable in
-- Space search and notebook search. At most 20 pages a file and 50 pages
-- a person a day. Run with: supabase test db
--
-- Omar (a1) made the Space; Bilal (b2) is Crew; Eve (e5) is outside.

begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000070' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@ocr.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('e5')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000070' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000070' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0070-' || lpad(p, 12, '0'))::uuid;
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
select set_config('test.space', public.create_space('Text site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp(), pg_temp.uid('b2'), 'crew', pg_temp.uid('a1'));
insert into public.library_files (id, space_id, name, storage_path, mime, bytes, uploaded_by, scanned, page_count)
values (pg_temp.id('f1'), pg_temp.sp(), 'Delivery note.pdf',
        pg_temp.sp() || '/library/' || pg_temp.id('f1') || '/a.pdf', 'application/pdf', 400000,
        pg_temp.uid('a1'), true, 2);
insert into public.notes (id, owner_id, kind, body) values (pg_temp.id('a2'), pg_temp.uid('a1'), 'text', 'Cubes');
insert into public.note_files (note_id, storage_path, kind, mime, name)
values (pg_temp.id('a2'), pg_temp.uid('a1') || '/' || pg_temp.id('a2') || '/c.pdf', 'file', 'application/pdf', 'Cube test.pdf');

-- Which file, for whom (the edge function asks as the caller).
select pg_temp.as_user('b2');
set local role authenticated;
select is((select path from public.file_for_text('library', pg_temp.id('f1')::text)),
  pg_temp.sp() || '/library/' || pg_temp.id('f1') || '/a.pdf', 'a member gets the Library file''s place');
select is((select bucket from public.file_for_text('library', pg_temp.id('f1')::text)), 'space-files',
  'in the Space''s files');
select throws_ok($$select * from public.file_for_text('note',
                   pg_temp.uid('a1') || '/' || pg_temp.id('a2') || '/c.pdf')$$, '42501', null,
  'nobody else''s note file');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok($$select * from public.file_for_text('library', pg_temp.id('f1')::text)$$, '42501', null,
  'someone outside the Space gets nothing');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select is((select bucket from public.file_for_text('note',
            pg_temp.uid('a1') || '/' || pg_temp.id('a2') || '/c.pdf')), 'notebook-files',
  'its owner gets the note file''s place');
select throws_ok($$select public.save_file_text('library', pg_temp.id('f1')::text, pg_temp.uid('a1'), 'en', 'x', 1)$$,
  '42501', null, 'the app never writes a text');
select throws_ok($$insert into public.file_texts (file_kind, file_ref, text, pages, created_by)
                   values ('library', 'x', 'x', 1, auth.uid())$$, '42501', null, 'nor directly');
reset role;

-- The edge function (service role) keeps what Vision read.
set local role service_role;
select lives_ok($$select public.save_file_text('library', pg_temp.id('f1')::text, pg_temp.uid('b2'),
                  'ar', 'إشعار تسليم حديد 16 مم Rebar delivery', 2)$$, 'the text is kept');
select throws_ok($$select public.save_file_text('library', pg_temp.id('f1')::text, pg_temp.uid('b2'), 'en', 'x', 21)$$,
  '22023', null, 'at most 20 pages a file');
-- The day's pages are ocr_usage's (D5, test 71): saving doesn't count.
select is(public.text_pages_left(pg_temp.uid('b2')), 50, 'saving a text reserves nothing');
select lives_ok($$select public.save_file_text('note', pg_temp.uid('a1') || '/' || pg_temp.id('a2') || '/c.pdf',
                  pg_temp.uid('a1'), 'en', 'Cube test 7 days 32.5 MPa', 1)$$, 'a note file''s text too');
reset role;
-- A day's limit: reserved before Vision is asked.
set local role service_role;
select public.reserve_text_pages(pg_temp.uid('b2'), 20);
select public.reserve_text_pages(pg_temp.uid('b2'), 20);
select is(public.reserve_text_pages(pg_temp.uid('b2'), 11), false, 'not past 50 pages a day');
reset role;

-- Who reads it: exactly as the file.
select is(pg_temp.reads('b2', format($$select count(*)::int from public.file_texts
                                       where file_kind = 'library' and file_ref = %L$$, pg_temp.id('f1'))), 1,
  'a member reads the Library file''s text');
select is(pg_temp.reads('e5', format($$select count(*)::int from public.file_texts
                                       where file_kind = 'library' and file_ref = %L$$, pg_temp.id('f1'))), 0,
  'someone outside the Space doesn''t');
select is(pg_temp.reads('b2', $$select count(*)::int from public.file_texts where file_kind = 'note'$$), 0,
  'nobody reads another''s note file text');
select is(pg_temp.reads('a1', $$select count(*)::int from public.file_texts where file_kind = 'note'$$), 1,
  'its owner does');

-- Searchable.
select pg_temp.as_user('b2');
set local role authenticated;
select is((select count(*)::int from public.search_space(pg_temp.sp(), 'rebar delivery') h where h.kind = 'file'),
  1, 'Space search finds the file by its text');
select is((select count(*)::int from public.search_space(pg_temp.sp(), 'حديد') h where h.kind = 'file'),
  1, 'Arabic too');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select is((select count(*)::int from public.search_notebook('32.5 mpa') h where h.note_id = pg_temp.id('a2')),
  1, 'notebook search finds the note by its file''s text');
reset role;

select * from finish();
rollback;
