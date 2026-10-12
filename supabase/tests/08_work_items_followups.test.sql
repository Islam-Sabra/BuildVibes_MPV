-- Migration 8: work items follow-ups (review 10 part A). Run with: supabase test db
--
-- Omar (o1) is the admin. Rakesh (r2) is Crew. Sara (s3) is Lead (she may
-- raise and check). Nadia (n4) is a Viewer. Eve (e5) is Crew too.

begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000008a1', 'authenticated', 'authenticated', 'omar8@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000008a2', 'authenticated', 'authenticated', 'rakesh8@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000008a3', 'authenticated', 'authenticated', 'sara8@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000008a4', 'authenticated', 'authenticated', 'nadia8@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000008a5', 'authenticated', 'authenticated', 'eve8@example.com', '{"home_market_id": "kw"}');
update public.profiles set first_name = 'Sara', last_name = 'Ali'
where id = '00000000-0000-0000-0000-0000000008a3';

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000008' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000008' || p_id)::uuid;
$$;
create function pg_temp.item(p_item text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000000' || p_item)::uuid;
$$;
create function pg_temp.path(p_item text, p_file text) returns text language sql as $$
  select current_setting('test.space') || '/' || pg_temp.item(p_item)::text || '/' || p_file;
$$;
create function pg_temp.member(p_id text, p_pass text, p_left boolean default false)
returns void language sql as $$
  update public.space_members set pass = p_pass, left_at = case when p_left then now() end
  where space_id = current_setting('test.space')::uuid and profile_id = pg_temp.uid(p_id);
$$;

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.project',
  public.create_project('Kuwait City Tower', 'commercial', 'kw', 'kw-capital')::text, true);
select set_config('test.space',
  public.create_space('Site team', null, current_setting('test.project')::uuid)::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select current_setting('test.space')::uuid, pg_temp.uid(m.id), m.pass, pg_temp.uid('a1')
from (values ('a2', 'crew'), ('a3', 'lead'), ('a4', 'viewer'), ('a5', 'crew')) as m(id, pass);

-- 1, 2. Stuck items -------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select public.create_work_item(current_setting('test.space')::uuid, 'Seal the riser',
  pg_temp.uid('a2'), null, null, null, '[]', pg_temp.item('d001'));
reset role;
select pg_temp.member('a2', 'viewer');
select pg_temp.as_user('a2');
set local role authenticated;
select is((select count(*) from public.needs_you() where work_item_id = pg_temp.item('d001')),
  0::bigint, 'an owner changed to Viewer no longer has the item in Needs you');
select pg_temp.as_user('a1');
select is((select kind from public.needs_you() where work_item_id = pg_temp.item('d001')),
  'owner_left', 'its creator sees "Owner left · reassign"');
reset role;
select pg_temp.member('a2', 'crew');

-- Sara raises an item for Rakesh; then both leave.
select pg_temp.as_user('a3');
set local role authenticated;
select public.create_work_item(current_setting('test.space')::uuid, 'Patch the slab edge',
  pg_temp.uid('a2'), null, null, null, '[]', pg_temp.item('d002'));
reset role;
select pg_temp.member('a2', 'crew', true);
select pg_temp.as_user('a1');
set local role authenticated;
select is((select count(*) from public.needs_you() where work_item_id = pg_temp.item('d002')),
  0::bigint, 'while the creator is still here, only the creator is told');
select pg_temp.as_user('a3');
select is((select kind from public.needs_you() where work_item_id = pg_temp.item('d002')),
  'owner_left', 'the creator is told');
reset role;
select pg_temp.member('a3', 'lead', true);
select pg_temp.as_user('a1');
set local role authenticated;
select is((select kind from public.needs_you() where work_item_id = pg_temp.item('d002')),
  'owner_left', 'creator gone too: a member who may check is told');
select pg_temp.as_user('a4');
select is((select count(*) from public.needs_you() where work_item_id = pg_temp.item('d002')),
  0::bigint, 'a Viewer is not told');
select pg_temp.as_user('a5');
select is((select count(*) from public.needs_you() where work_item_id = pg_temp.item('d002')),
  0::bigint, 'Crew without the check right is not told');
reset role;
select pg_temp.member('a2', 'crew');
select pg_temp.member('a3', 'lead');

-- 4. Reassign history ------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.reassign_work_item(pg_temp.item('d001'), pg_temp.uid('a5'))$$,
  'Omar reassigns d001 from Rakesh to Eve');
select results_eq(
  $$select from_owner_id, to_owner_id from public.work_item_events
    where work_item_id = pg_temp.item('d001') and kind = 'reassigned'$$,
  $$values (pg_temp.uid('a2'), pg_temp.uid('a5'))$$,
  'the record keeps the previous and the new owner');

-- 3. Photos before the item exists ----------------------------------------------------------

select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values ('space-files', pg_temp.path('d010', 'a.jpg'), pg_temp.uid('a1')::text)$$,
  'Omar uploads a photo for an item he is about to raise');
select pg_temp.as_user('a2');
select is((select count(*) from storage.objects where name = pg_temp.path('d010', 'a.jpg')),
  0::bigint, 'another member cannot see it before the item exists');
select pg_temp.as_user('a1');
select is((select count(*) from storage.objects where name = pg_temp.path('d010', 'a.jpg')),
  1::bigint, 'the uploader can');
select public.create_work_item(current_setting('test.space')::uuid, 'Fix the door frame',
  pg_temp.uid('a2'), null, null, null,
  jsonb_build_array(jsonb_build_object('path', pg_temp.path('d010', 'a.jpg'))), pg_temp.item('d010'));
select pg_temp.as_user('a2');
select is((select count(*) from storage.objects where name = pg_temp.path('d010', 'a.jpg')),
  1::bigint, 'once the item exists, members can');

-- Sara starts d011 first; Omar can't take that id.
select pg_temp.as_user('a3');
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values ('space-files', pg_temp.path('d011', 's.jpg'), pg_temp.uid('a3')::text)$$,
  'Sara uploads for a new item d011');
select pg_temp.as_user('a1');
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values ('space-files', pg_temp.path('d011', 'o.jpg'), pg_temp.uid('a1')::text)$$,
  '42501', null, 'nobody else uploads into a folder someone already started');
select throws_ok(
  $$select public.create_work_item(current_setting('test.space')::uuid, 'Taken id',
      pg_temp.uid('a2'), null, null, null, '[]', pg_temp.item('d011'))$$,
  '42501', null, 'nobody else raises an item with that id');
select pg_temp.as_user('a3');
select lives_ok(
  $$select public.create_work_item(current_setting('test.space')::uuid, 'Sara''s item',
      pg_temp.uid('a2'), null, null, null,
      jsonb_build_array(jsonb_build_object('path', pg_temp.path('d011', 's.jpg'))), pg_temp.item('d011'))$$,
  'the person who started it raises it');

-- 5. A cap on loose files --------------------------------------------------------------------

reset role;
insert into storage.objects (bucket_id, name, owner_id, metadata, created_at) values
  ('space-files', pg_temp.path('d020', 'big.jpg'), pg_temp.uid('a1')::text,
   '{"size": 209715200}', now() - interval '8 days');
select pg_temp.as_user('a1');
set local role authenticated;
select is((select bytes from public.loose_uploads()), 209715200::bigint,
  'loose uploads are counted');
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values ('space-files', pg_temp.path('d021', 'more.jpg'), pg_temp.uid('a1')::text)$$,
  '42501', null, 'over about 200 MB of loose photos, no more uploads');
select throws_ok($$select * from public.orphan_space_files()$$,
  '42501', null, 'the app cannot list orphan files');
reset role;
set local role service_role;
select is((select count(*) from public.orphan_space_files()
           where name = pg_temp.path('d020', 'big.jpg')),
  1::bigint, 'the cleanup job finds a loose file older than 7 days');
select is((select count(*) from public.orphan_space_files()
           where name = pg_temp.path('d010', 'a.jpg')),
  0::bigint, 'but never a photo that is evidence');
reset role;

-- 6. The record stays append-only ------------------------------------------------------------

-- A future trigger that writes events is refused.
create function public.test_touch_events() returns trigger language plpgsql as $$
begin
  update public.work_item_events set note = 'touched' where work_item_id = new.id;
  return new;
end;
$$;
create trigger test_touch after update on public.work_items
  for each row execute function public.test_touch_events();
select throws_ok(
  $$update public.work_items set place_text = 'Gate 2' where id = pg_temp.item('d001')$$,
  '42501', null, 'another trigger cannot change the record');
drop trigger test_touch on public.work_items;
drop function public.test_touch_events();

select throws_ok(
  $$update public.work_item_events set actor_id = null where actor_id = pg_temp.uid('a1')$$,
  '42501', null, 'a living person cannot be cleared from the record');
select pg_temp.as_user('a4');
set local role authenticated;
select public.add_comment(pg_temp.item('d001'), 'On site tomorrow?');
reset role;
select lives_ok($$delete from auth.users where id = pg_temp.uid('a4')$$,
  'deleting an account clears it from the record');
select is((select count(*) from public.work_item_events
           where work_item_id = pg_temp.item('d001') and kind = 'comment' and actor_id is null),
  1::bigint, 'the comment stays, without the name');
select lives_ok($$delete from public.work_items where id = pg_temp.item('d002')$$,
  'deleting a work item takes its record with it');
select is((select count(*) from public.work_item_events where work_item_id = pg_temp.item('d002')),
  0::bigint, 'its events went with it');

-- RE2 · Work you delivered -------------------------------------------------------------------

-- Rakesh signs d010 with a photo; Sara checks it.
reset role;
insert into storage.objects (bucket_id, name, owner_id)
values ('space-files', pg_temp.path('d010', 'done.jpg'), pg_temp.uid('a2')::text);
select pg_temp.as_user('a2');
set local role authenticated;
select public.sign_done(pg_temp.item('d010'), 'Frame fixed.',
  jsonb_build_array(jsonb_build_object('path', pg_temp.path('d010', 'done.jpg'))));
select pg_temp.as_user('a3');
select public.check_item(pg_temp.item('d010'));
select pg_temp.as_user('a2');
select results_eq(
  $$select title, project_name, checked_by_name, shown, photo_path from public.my_delivered_work()$$,
  $$values ('Fix the door frame'::text, 'Kuwait City Tower'::text, 'Sara Ali'::text, false,
            pg_temp.path('d010', 'done.jpg'))$$,
  'the owner sees their checked work, hidden until they show it');
select pg_temp.as_user('a1');
select is((select count(*) from public.my_delivered_work()), 0::bigint,
  'nobody sees someone else''s list');
reset role;
select pg_temp.member('a2', 'crew', true);
select pg_temp.as_user('a2');
set local role authenticated;
select is((select count(*) from public.my_delivered_work()), 1::bigint,
  'after leaving the Space, the work is still yours to show or hide');
select is((select count(*) from storage.objects where name = pg_temp.path('d010', 'done.jpg')),
  1::bigint, 'and your own photo is still yours to see');
select lives_ok($$select public.set_shown_work(pg_temp.item('d010'), true)$$,
  'you can show it after leaving');

select * from finish();
rollback;
