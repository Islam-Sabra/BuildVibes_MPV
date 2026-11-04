-- Review 103, the lead's check of claude/r103 (D3, D5, D6, D7, D8): Extract
-- text keeps a day's pages in ocr_usage, reserved before Vision is asked
-- and given back when it fails, one person at a time; a text goes with its
-- file; file_for_text says the file's size; a file in someone's Only me
-- folder or another Team's folder is never read or found. A file over 20
-- pages is kept marked partial. Run with: supabase test db
--
-- Omar (a1) made the Space; Bilal (b2) is Crew in Team Steel; Dana (d4) is
-- Crew in no Team.

begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000071' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@ocrcheck.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('d4')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000071' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000071' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0071-' || lpad(p, 12, '0'))::uuid;
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
create function pg_temp.texts(p_ref text) returns integer language sql as $$
  select count(*)::int from public.file_texts where file_ref = p_ref;
$$;

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Check text site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp(), pg_temp.uid('b2'), 'crew', pg_temp.uid('a1')),
       (pg_temp.sp(), pg_temp.uid('d4'), 'crew', pg_temp.uid('a1'));
insert into public.teams (id, space_id, name, created_by)
values (pg_temp.id('7ea'), pg_temp.sp(), 'Steel', pg_temp.uid('a1'));
insert into public.team_members (team_id, profile_id) values (pg_temp.id('7ea'), pg_temp.uid('b2'));
insert into public.library_folders (id, space_id, name, kind, share, share_team, created_by)
values (pg_temp.id('f0a'), pg_temp.sp(), 'Mine', 'folder', 'only_me', null, pg_temp.uid('b2')),
       (pg_temp.id('f0b'), pg_temp.sp(), 'Steel', 'folder', 'team', pg_temp.id('7ea'), pg_temp.uid('a1'));
insert into public.library_files (id, space_id, name, storage_path, mime, bytes, uploaded_by, folder_id)
values (pg_temp.id('c1'), pg_temp.sp(), 'Open.pdf', pg_temp.sp() || '/library/c1/a.pdf', 'application/pdf',
        4000000, pg_temp.uid('a1'), null),
       (pg_temp.id('c2'), pg_temp.sp(), 'Mine.pdf', pg_temp.sp() || '/library/c2/a.pdf', 'application/pdf',
        100, pg_temp.uid('b2'), pg_temp.id('f0a')),
       (pg_temp.id('c3'), pg_temp.sp(), 'Steel only.pdf', pg_temp.sp() || '/library/c3/a.pdf',
        'application/pdf', 100, pg_temp.uid('a1'), pg_temp.id('f0b'));

-- D7: the size, before anything is downloaded.
select pg_temp.as_user('b2');
set local role authenticated;
select is((select bytes from public.file_for_text('library', pg_temp.id('c1')::text)), 4000000::bigint,
  'D7: file_for_text says the file''s size');
reset role;

-- D5: a day's pages, reserved one person at a time.
set local role service_role;
select public.reserve_text_pages(pg_temp.uid('b2'), 20);
select is(public.reserve_text_pages(pg_temp.uid('b2'), 20), true, 'D5: 40 pages reserved');
select is(public.reserve_text_pages(pg_temp.uid('b2'), 15), false, 'D5: 15 more would pass 50: refused');
select is(public.text_pages_left(pg_temp.uid('b2')), 10, 'D5: 10 left today');
select lives_ok($$select public.release_text_pages(pg_temp.uid('b2'), 20)$$, 'D5: Vision failed: given back');
select is(public.text_pages_left(pg_temp.uid('b2')), 30, 'D5: 30 again');
select is(public.reserve_text_pages(pg_temp.uid('b2'), 20), true, 'D5: reserved again');
-- The count is ocr_usage's, not file_texts'.
select lives_ok($$select public.save_file_text('library', pg_temp.id('c1')::text, pg_temp.uid('b2'),
                  'en', 'Open words', 20, true)$$, 'D3: a file over 20 pages kept, partial');
select is(public.text_pages_left(pg_temp.uid('b2')), 10, 'D5: saving doesn''t count it twice');
reset role;
select is((select partial from public.file_texts where file_ref = pg_temp.id('c1')::text), true,
  'D3: marked partial');
select is((select count(*)::int from information_schema.role_table_grants
           where table_name = 'ocr_usage' and grantee = 'authenticated'), 0,
  'D5: ocr_usage is the server''s');
select ok(not has_function_privilege('authenticated', 'public.reserve_text_pages(uuid, integer)', 'execute'),
  'D5: the app never reserves');

-- D8: Only me and another Team's folders.
set local role service_role;
select public.save_file_text('library', pg_temp.id('c2')::text, pg_temp.uid('b2'), 'en', 'Secret mine words', 1, false);
select public.save_file_text('library', pg_temp.id('c3')::text, pg_temp.uid('a1'), 'en', 'Steel team words', 1, false);
reset role;
select is(pg_temp.reads('a1', format($$select count(*)::int from public.file_texts where file_ref = %L$$,
                                     pg_temp.id('c2'))), 0,
  'D8: no text from someone''s Only me folder, even for the admin');
select is(pg_temp.reads('d4', format($$select count(*)::int from public.file_texts where file_ref = %L$$,
                                     pg_temp.id('c3'))), 0,
  'D8: no text from another Team''s folder');
select is(pg_temp.reads('b2', format($$select count(*)::int from public.file_texts where file_ref = %L$$,
                                     pg_temp.id('c3'))), 1, 'the Team reads it');
select pg_temp.as_user('d4');
set local role authenticated;
select is((select count(*)::int from public.search_space(pg_temp.sp(), 'secret mine') h), 0,
  'D8: no search hit from an Only me folder');
select is((select count(*)::int from public.search_space(pg_temp.sp(), 'steel team words') h), 0,
  'D8: nor from another Team''s folder');
select throws_ok($$select * from public.file_for_text('library', pg_temp.id('c3')::text)$$, '42501', null,
  'D8: nor read');
reset role;

-- D6: a text goes with its file.
update public.library_files set deleted_at = now() where id = pg_temp.id('c1');
select is(pg_temp.texts(pg_temp.id('c1')::text), 0, 'D6: a Library file deleted, its text goes');
delete from public.library_files where id = pg_temp.id('c2');
select is(pg_temp.texts(pg_temp.id('c2')::text), 0, 'D6: purged, too');

insert into public.notes (id, owner_id, kind, body)
values (pg_temp.id('a2'), pg_temp.uid('d4'), 'text', 'One'), (pg_temp.id('a3'), pg_temp.uid('d4'), 'text', 'Two');
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('notebook-files', pg_temp.uid('d4') || '/' || pg_temp.id('a2') || '/x.pdf', pg_temp.uid('d4'),
   '{"mimetype": "application/pdf"}'),
  ('notebook-files', pg_temp.uid('d4') || '/' || pg_temp.id('a2') || '/y.pdf', pg_temp.uid('d4'),
   '{"mimetype": "application/pdf"}'),
  ('notebook-files', pg_temp.uid('d4') || '/' || pg_temp.id('a3') || '/z.pdf', pg_temp.uid('d4'),
   '{"mimetype": "application/pdf"}');
create function pg_temp.files(p_note text, variadic p_names text[]) returns void language plpgsql as $$
begin
  perform pg_temp.as_user('d4');
  perform public.set_note_files(pg_temp.id(p_note), (
    select jsonb_agg(jsonb_build_object('path', pg_temp.uid('d4') || '/' || pg_temp.id(p_note) || '/' || n,
                                        'mime', 'application/pdf', 'name', n))
    from unnest(p_names) n));
end;
$$;
select pg_temp.files('a2', 'x.pdf', 'y.pdf');
select pg_temp.files('a3', 'z.pdf');
set local role service_role;
select public.save_file_text('note', pg_temp.uid('d4') || '/' || pg_temp.id('a2') || '/x.pdf', pg_temp.uid('d4'), 'en', 'x', 1, false);
select public.save_file_text('note', pg_temp.uid('d4') || '/' || pg_temp.id('a2') || '/y.pdf', pg_temp.uid('d4'), 'en', 'y', 1, false);
select public.save_file_text('note', pg_temp.uid('d4') || '/' || pg_temp.id('a3') || '/z.pdf', pg_temp.uid('d4'), 'en', 'z', 1, false);
reset role;
select pg_temp.files('a2', 'y.pdf');
select is(pg_temp.texts(pg_temp.uid('d4') || '/' || pg_temp.id('a2') || '/x.pdf'), 0,
  'D6: a file taken off a note, its text goes');
select is(pg_temp.texts(pg_temp.uid('d4') || '/' || pg_temp.id('a2') || '/y.pdf'), 1,
  'the note''s other file keeps its text');
delete from public.notes where id = pg_temp.id('a2');
select is(pg_temp.texts(pg_temp.uid('d4') || '/' || pg_temp.id('a2') || '/y.pdf'), 0,
  'D6: a note deleted, its texts go');
delete from auth.users where id = pg_temp.uid('d4');
select is(pg_temp.texts(pg_temp.uid('d4') || '/' || pg_temp.id('a3') || '/z.pdf'), 0,
  'D6: an account deleted, its notes'' texts go');

select * from finish();
rollback;
