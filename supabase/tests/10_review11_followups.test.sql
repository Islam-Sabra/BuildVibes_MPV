-- Migration 10: review 11 part A follow-ups. Run with: supabase test db
--
-- Omar (b1) is the admin of the Site team. Rakesh (b2) is Crew. Sara (b3)
-- is Lead; she also has her own Space that Omar isn't in.

begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000010b1', 'authenticated', 'authenticated', 'omar10@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000010b2', 'authenticated', 'authenticated', 'rakesh10@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000010b3', 'authenticated', 'authenticated', 'sara10@example.com', '{"home_market_id": "kw"}');
update public.profiles set first_name = 'Sara', last_name = 'Ali'
where id = '00000000-0000-0000-0000-0000000010b3';

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000010' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000010' || p_id)::uuid;
$$;
create function pg_temp.item(p_item text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000010' || p_item)::uuid;
$$;
create function pg_temp.space() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.path(p_item text, p_file text) returns text language sql as $$
  select pg_temp.space()::text || '/' || pg_temp.item(p_item)::text || '/' || p_file;
$$;
-- A file as the Storage API would store it (type and size in metadata).
create function pg_temp.upload(p_name text, p_owner text, p_bytes bigint,
  p_age interval default interval '0', p_mime text default 'image/jpeg')
returns void language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata, created_at)
  values ('space-files', p_name, pg_temp.uid(p_owner)::text,
          jsonb_build_object('mimetype', p_mime, 'size', p_bytes), now() - p_age);
$$;

select pg_temp.as_user('b1');
set local role authenticated;
select set_config('test.project',
  public.create_project('Kuwait City Tower', 'commercial', 'kw', 'kw-capital')::text, true);
select set_config('test.space',
  public.create_space('Site team', null, current_setting('test.project')::uuid)::text, true);
select pg_temp.as_user('b3');
select set_config('test.other', public.create_space('Sara''s office', null, null)::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.space(), pg_temp.uid(m.id), m.pass, pg_temp.uid('b1')
from (values ('b2', 'crew'), ('b3', 'lead')) as m(id, pass);

-- 1. Needs you, from my memberships ------------------------------------------------------

select pg_temp.as_user('b1');
set local role authenticated;
select public.create_work_item(pg_temp.space(), 'Seal the riser', pg_temp.uid('b2'),
  null, null, null, '[]', pg_temp.item('e001'));
-- Raised now; its loose photo (part 4) comes later.
select public.create_work_item(pg_temp.space(), 'Patch the slab edge', pg_temp.uid('b2'),
  null, null, null, '[]', pg_temp.item('e011'));
select pg_temp.as_user('b3');
-- In Sara's own Space, Omar is no member: nothing there may reach him.
select public.create_work_item(current_setting('test.other')::uuid, 'File the permit',
  pg_temp.uid('b3'), null, null, null, '[]', pg_temp.item('e002'));
select pg_temp.as_user('b2');
select is((select kind from public.needs_you() where work_item_id = pg_temp.item('e001')),
  'open_owned', 'the owner sees their open item');
select public.sign_done(pg_temp.item('e001'), 'Sealed both sides.', '[]');
select is((select count(*) from public.needs_you() where work_item_id = pg_temp.item('e001')),
  0::bigint, 'once signed, it leaves the owner''s Needs you');
select pg_temp.as_user('b1');
select is((select kind from public.needs_you() where work_item_id = pg_temp.item('e001')),
  'to_check', 'the creator is asked to check it');
select is((select count(*) from public.needs_you()
           where space_id = current_setting('test.other')::uuid),
  0::bigint, 'nothing from a Space I''m not in');
select is((select needs_you from public.my_spaces() where space_id = pg_temp.space()),
  1, 'My Spaces counts it once for the Site team');
select pg_temp.as_user('b3');
select is((select needs_you from public.my_spaces()
           where space_id = current_setting('test.other')::uuid),
  1, 'and Sara''s own Space counts her item');
select is((select needs_you from public.my_spaces() where space_id = pg_temp.space()),
  1, 'Sara may check, so the Site team counts it for her too');
reset role;

-- 2. Upload totals --------------------------------------------------------------------------

select pg_temp.upload(pg_temp.path('e010', 'a.jpg'), 'b2', 1000);
select pg_temp.upload(pg_temp.path('e010', 'b.jpg'), 'b2', 2000);
select pg_temp.upload(pg_temp.path('e011', 'old.jpg'), 'b2', 500, interval '8 days');
select pg_temp.upload(pg_temp.path('e001', 'omar.jpg'), 'b1', 9000);
select pg_temp.as_user('b2');
set local role authenticated;
select is((select row(files, bytes)::text from public.loose_uploads()),
  '(3,3500)', 'loose uploads: my three files, not Omar''s');
-- uploads_today() is internal (the upload rule calls it), so as the owner.
reset role;
select is((select row(files, bytes)::text from public.uploads_today()),
  '(2,3000)', 'uploads today: only the last 24 hours');
-- Evidence isn't loose.
select pg_temp.upload(pg_temp.path('e001', 'proof.jpg'), 'b2', 4000);
select pg_temp.as_user('b1');
set local role authenticated;
select public.check_item(pg_temp.item('e001'));
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select is((select files from public.loose_uploads()), 4::bigint,
  'a fresh photo that is not evidence counts as loose');
reset role;
-- After leaving, my files there still count.
update public.space_members set left_at = now()
where space_id = pg_temp.space() and profile_id = pg_temp.uid('b2');
select pg_temp.as_user('b2');
set local role authenticated;
select is((select files from public.loose_uploads()), 4::bigint,
  'files in a Space I left still count towards my cap');
reset role;
update public.space_members set left_at = null
where space_id = pg_temp.space() and profile_id = pg_temp.uid('b2');

-- 4. Cleanup claims -------------------------------------------------------------------------

select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select * from public.claim_orphan_files()$$, '42501', null,
  'a member can''t run the cleanup');
select throws_ok($$select * from public.file_cleanup_claims$$, '42501', null,
  'a member can''t read the claims');
reset role;

set local role service_role;
select is((select array_agg(name order by name) from public.claim_orphan_files()),
  array[pg_temp.path('e011', 'old.jpg')],
  'only the loose file older than 7 days is claimed');
select is((select count(*) from public.claim_orphan_files()), 1::bigint,
  'claiming again is safe: the same file, one claim');
select is((select count(*) from public.file_cleanup_claims), 1::bigint, 'one claim row');
reset role;

-- A claimed file can't become evidence, a chat attachment or a Library file.
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok(
  format($$select public.sign_done(%L, null, %L)$$, pg_temp.item('e011'),
    jsonb_build_array(jsonb_build_object('path', pg_temp.path('e011', 'old.jpg')))),
  '22023', 'this file was cleaned up; upload it again',
  'a claimed photo is refused as evidence');
reset role;
select pg_temp.upload(pg_temp.space()::text || '/library/' || pg_temp.item('e020')::text || '/plan.pdf',
  'b2', 700, interval '9 days', 'application/pdf');
set local role service_role;
select is((select count(*) from public.claim_orphan_files()), 2::bigint,
  'the old Library upload is claimed too');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok(
  format($$select public.add_library_file(%L, %L, 'plan.pdf', %L, 'application/pdf')$$,
    pg_temp.item('e020'), pg_temp.space(),
    pg_temp.space()::text || '/library/' || pg_temp.item('e020')::text || '/plan.pdf'),
  '22023', 'this file was cleaned up; upload it again',
  'a claimed file is refused in the Library');
-- A new upload of the same photo is fine (the app uses a new name each try).
reset role;
select pg_temp.upload(pg_temp.path('e011', 'retry.jpg'), 'b2', 500);
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok(
  format($$select public.sign_done(%L, null, %L)$$, pg_temp.item('e011'),
    jsonb_build_array(jsonb_build_object('path', pg_temp.path('e011', 'retry.jpg')))),
  'the re-uploaded photo is accepted');
reset role;

-- The job deleted the files (Storage API); then it forgets the claims.
set local storage.allow_delete_query = 'true';
delete from storage.objects
where bucket_id = 'space-files' and name = pg_temp.path('e011', 'old.jpg');
set local role service_role;
select is(public.forget_cleanup_claims(), 1, 'the claim of a deleted file is forgotten');
select is((select storage_path from public.file_cleanup_claims),
  pg_temp.space()::text || '/library/' || pg_temp.item('e020')::text || '/plan.pdf',
  'a claim whose file is still there stays');
reset role;

-- 5. Shown work across a block ------------------------------------------------------------

select pg_temp.as_user('b3');
set local role authenticated;
select public.check_item(pg_temp.item('e011'));
select pg_temp.as_user('b2');
select public.set_shown_work(pg_temp.item('e011'), true);
select is((select checked_by_name from public.my_delivered_work()
           where work_item_id = pg_temp.item('e011')),
  'Sara Ali', 'Rakesh sees who checked it');
select pg_temp.as_user('b1');
select is((select checked_by_name from public.public_shown_work
           where work_item_id = pg_temp.item('e011')),
  'Sara Ali', 'so does anyone else');
reset role;

insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('b2'), pg_temp.uid('b3'));
select pg_temp.as_user('b2');
set local role authenticated;
select is((select row(checked_by_name is null, checked_at is not null)::text
           from public.my_delivered_work() where work_item_id = pg_temp.item('e011')),
  '(t,t)', 'after Rakesh blocks Sara: still Checked, without her name');
reset role;
delete from public.blocks;

insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('b3'), pg_temp.uid('b1'));
select pg_temp.as_user('b1');
set local role authenticated;
select is((select row(checked_by_name is null, checked_at is not null)::text
           from public.public_shown_work where work_item_id = pg_temp.item('e011')),
  '(t,t)', 'Sara blocked Omar: Omar sees Checked, without her name');
select pg_temp.as_user('b3');
select is((select checked_by_name from public.public_shown_work
           where work_item_id = pg_temp.item('e011')),
  'Sara Ali', 'Sara herself still sees her name');
reset role;

select * from finish();
rollback;
