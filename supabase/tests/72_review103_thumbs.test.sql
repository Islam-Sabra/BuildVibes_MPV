-- The lead's check of review 103, D10: a scan's page 1 thumbnail goes up
-- with it, beside it in its folder, and its row points to it: a Library
-- file's thumb_path, a proof's. It opens where its file opens, never
-- swept as a loose upload, and goes with its file. Run with: supabase test db
--
-- Omar (a1) made the Space; Bilal (b2) is Crew; Eve (e5) is outside.

begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000072' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@thumbs.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('e5')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000072' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000072' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0072-' || lpad(p, 12, '0'))::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.dir() returns text language sql as $$
  select pg_temp.sp() || '/library/' || pg_temp.id('f1') || '/';
$$;
create function pg_temp.opens(p_id text, p_name text) returns boolean language plpgsql as $$
declare v boolean;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  v := public.may_read_file(p_name, pg_temp.uid('a1')::text);
  reset role;
  return v;
end;
$$;

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Thumb site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp(), pg_temp.uid('b2'), 'crew', pg_temp.uid('a1'));

-- Omar's scan and its thumbnail, as his phone uploads them.
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('space-files', pg_temp.dir() || 'a.pdf', pg_temp.uid('a1'), '{"mimetype": "application/pdf"}'),
  ('space-files', pg_temp.dir() || 't.jpg', pg_temp.uid('a1'), '{"mimetype": "image/jpeg"}'),
  ('space-files', pg_temp.sp() || '/library/' || pg_temp.id('f9') || '/x.jpg', pg_temp.uid('a1'),
   '{"mimetype": "image/jpeg"}');
insert into public.library_files (id, space_id, name, storage_path, mime, bytes, uploaded_by)
values (pg_temp.id('f1'), pg_temp.sp(), 'Delivery note.pdf', pg_temp.dir() || 'a.pdf',
        'application/pdf', 400000, pg_temp.uid('a1'));

select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok(format($$select public.mark_library_file_scanned(%L, 3, %L)$$, pg_temp.id('f1'),
  pg_temp.sp() || '/library/' || pg_temp.id('f9') || '/x.jpg'), '22023', null,
  'a thumbnail in another file''s folder is refused');
select throws_ok(format($$select public.mark_library_file_scanned(%L, 3, %L)$$, pg_temp.id('f1'),
  pg_temp.dir() || 'never.jpg'), '22023', null, 'one never uploaded is refused');
select lives_ok(format($$select public.mark_library_file_scanned(%L, 3, %L)$$, pg_temp.id('f1'),
  pg_temp.dir() || 't.jpg'), 'its uploader marks it scanned, with its thumbnail beside it');
select lives_ok(format($$select public.mark_library_file_scanned(%L, 3)$$, pg_temp.id('f1')),
  'marked again on a retry, without one');
reset role;
select is((select thumb_path from public.library_files where id = pg_temp.id('f1')), pg_temp.dir() || 't.jpg',
  'the row points to its thumbnail, kept on a retry');
select ok(pg_temp.opens('b2', pg_temp.dir() || 't.jpg'), 'a member opens the thumbnail');
select ok(not pg_temp.opens('e5', pg_temp.dir() || 't.jpg'), 'someone outside the Space doesn''t');
select ok(public.is_referenced_file(pg_temp.dir() || 't.jpg'), 'never swept as a loose upload');

-- A scanned proof with its thumbnail.
select pg_temp.as_user('a1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Inspect the slab', pg_temp.uid('b2'), p_id => pg_temp.id('c1'));
reset role;
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('space-files', pg_temp.sp() || '/' || pg_temp.id('c1') || '/proof.pdf', pg_temp.uid('b2'),
   '{"mimetype": "application/pdf"}'),
  ('space-files', pg_temp.sp() || '/' || pg_temp.id('c1') || '/proof.jpg', pg_temp.uid('b2'),
   '{"mimetype": "image/jpeg"}');
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok(format($$select public.sign_done(%L, null, %L::jsonb)$$, pg_temp.id('c1'),
  jsonb_build_array(jsonb_build_object('path', pg_temp.sp() || '/' || pg_temp.id('c1') || '/proof.pdf',
    'page_count', 2, 'thumb_path', pg_temp.sp() || '/' || pg_temp.id('c1') || '/proof.jpg'))),
  'signed done with a scan and its thumbnail');
reset role;
select is((select thumb_path from public.work_item_evidence where work_item_id = pg_temp.id('c1')),
  pg_temp.sp() || '/' || pg_temp.id('c1') || '/proof.jpg', 'the proof points to its thumbnail');
select ok(public.is_referenced_file(pg_temp.sp() || '/' || pg_temp.id('c1') || '/proof.jpg'),
  'a proof''s thumbnail is never swept');
select pg_temp.as_user('a1');
select ok((select public.space_post_json(p, true)::text from public.space_posts p where p.id = pg_temp.id('c1'))
          like '%proof.jpg%', 'the card carries the proof''s thumbnail');

-- It goes with its file.
select public.library_gone(array[pg_temp.id('f1')]);
select is((select count(*)::int from public.private_file_purges where storage_path = pg_temp.dir() || 't.jpg'), 1,
  'a Library file gone for good: its thumbnail too');

select * from finish();
rollback;
