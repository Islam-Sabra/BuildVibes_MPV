-- Migration 7: work items. Run with: supabase test db
--
-- Omar (o1) runs the Space (admin, Lead) and raises the items. Rakesh (r2)
-- is Crew and owns them. Sara (s3) is Lead with the check right. Nadia (n4)
-- is a Viewer. Eve (e5) is not a member.
-- Review 09 checks are marked "(r09)": each attack is refused and the
-- normal path still works.

begin;
create extension if not exists pgtap with schema extensions;
select plan(97);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000007a1', 'authenticated', 'authenticated', 'omar7@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000007a2', 'authenticated', 'authenticated', 'rakesh7@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000007a3', 'authenticated', 'authenticated', 'sara7@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000007a4', 'authenticated', 'authenticated', 'nadia7@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000007a5', 'authenticated', 'authenticated', 'eve7@example.com', '{"home_market_id": "kw"}');
update public.profiles set first_name = 'Sara', last_name = 'Ali'
where id = '00000000-0000-0000-0000-0000000007a3';

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000007' || p_id || '", "role": "authenticated"}', true);
$$;
-- <space>/<item>/<file> for item [p_item] (the last 4 hex digits).
create function pg_temp.path(p_item text, p_file text) returns text language sql as $$
  select current_setting('test.space') || '/00000000-0000-0000-0000-00000000' || p_item || '/' || p_file;
$$;
create function pg_temp.photo(p_item text, p_file text) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('path', pg_temp.path(p_item, p_file)));
$$;
create function pg_temp.item(p_item text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000000' || p_item)::uuid;
$$;

-- References -----------------------------------------------------------------------------

select is(public.latin_initials('Kuwait City Tower'), 'KCT', 'initials of a project name');
select is(public.latin_initials('Tower'), 'TO', 'one word: its first two letters');
select is(public.latin_initials('برج الكويت'), null, 'no Latin letters: no initials');

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.project',
  public.create_project('Kuwait City Tower', 'commercial', 'kw', 'kw-capital')::text, true);
select set_config('test.space',
  public.create_space('Site team', null, current_setting('test.project')::uuid)::text, true);
select set_config('test.space2', public.create_space('برج الكويت', null, null)::text, true);
reset role;

select is((select ref_prefix from public.spaces where id = current_setting('test.space')::uuid),
  'KCT', 'a Space linked to a project takes the project''s initials');
select is((select ref_prefix from public.spaces where id = current_setting('test.space2')::uuid),
  'BV', 'no Latin initials anywhere: BV');

insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (current_setting('test.space')::uuid, '00000000-0000-0000-0000-0000000007a2', 'crew', '00000000-0000-0000-0000-0000000007a1'),
  (current_setting('test.space')::uuid, '00000000-0000-0000-0000-0000000007a3', 'lead', '00000000-0000-0000-0000-0000000007a1'),
  (current_setting('test.space')::uuid, '00000000-0000-0000-0000-0000000007a4', 'viewer', '00000000-0000-0000-0000-0000000007a1');

-- Files already uploaded (each with its uploader).
insert into storage.objects (bucket_id, name, owner_id) values
  ('space-files', pg_temp.path('c001', 'raised.jpg'), '00000000-0000-0000-0000-0000000007a1'),
  ('space-files', pg_temp.path('c001', 'done.jpg'), '00000000-0000-0000-0000-0000000007a2'),
  ('space-files', pg_temp.path('c001', 'omars.jpg'), '00000000-0000-0000-0000-0000000007a1'),
  ('space-files', pg_temp.path('c004', 'raised4.jpg'), '00000000-0000-0000-0000-0000000007a1');

-- Raising items (W2) ---------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select is(
  public.create_work_item(current_setting('test.space')::uuid, 'Fix rebar at grid C7',
    '00000000-0000-0000-0000-0000000007a2', current_date + 2, null, 'Grid C7',
    pg_temp.photo('c001', 'raised.jpg'), pg_temp.item('c001')),
  pg_temp.item('c001'),
  'an admin raises an item for a Crew member, with an uploaded photo');
select is((select ref from public.work_items where id = pg_temp.item('c001')),
  'KCT-001', 'references run per Space with three digits');
select is(
  public.create_work_item(current_setting('test.space')::uuid, 'Fix rebar at grid C7',
    '00000000-0000-0000-0000-0000000007a2', null, null, null, '[]', pg_temp.item('c001')),
  pg_temp.item('c001'),
  'a retry with the same id returns the same item');
select is((select count(*) from public.work_items where space_id = current_setting('test.space')::uuid),
  1::bigint, 'the retry made no second item');
select is((select count(*) from public.work_item_events
           where work_item_id = pg_temp.item('c001') and kind = 'raised'),
  1::bigint, 'raising writes one "raised" event');
select is((select count(*) from public.work_item_evidence where work_item_id = pg_temp.item('c001')),
  1::bigint, 'the photo is kept as evidence');
select set_config('test.item2',
  public.create_work_item(current_setting('test.space')::uuid, 'Close the shaft opening',
    '00000000-0000-0000-0000-0000000007a2')::text, true);
select is((select ref from public.work_items where id = current_setting('test.item2')::uuid),
  'KCT-002', 'the next item is KCT-002');
select throws_ok(
  $$select public.create_work_item(current_setting('test.space')::uuid, 'Look only',
      '00000000-0000-0000-0000-0000000007a4')$$,
  '22023', null, 'a Viewer cannot own an item');
select throws_ok(
  $$select public.create_work_item(current_setting('test.space')::uuid, 'Outsider',
      '00000000-0000-0000-0000-0000000007a5')$$,
  '22023', null, 'someone outside the Space cannot own an item');
select throws_ok(
  $$select public.create_work_item(current_setting('test.space')::uuid, 'Bad photo',
      '00000000-0000-0000-0000-0000000007a2', null, null, null,
      '[{"path": "somewhere-else/x.jpg"}]')$$,
  '22023', null, 'a photo outside the item''s folder is refused');
select throws_ok(
  $$select public.create_work_item(current_setting('test.space')::uuid, 'Made-up photo',
      '00000000-0000-0000-0000-0000000007a2', null, null, null,
      pg_temp.photo('c009', 'never-uploaded.jpg'), pg_temp.item('c009'))$$,
  '22023', null, '(r09) a made-up photo path is refused when raising');
select throws_ok(
  $$select public.create_work_item(current_setting('test.space')::uuid, 'X',
      '00000000-0000-0000-0000-0000000007a2')$$,
  '23514', null, 'a title needs at least two letters');
select pg_temp.as_user('a2');
select throws_ok(
  $$select public.create_work_item(current_setting('test.space')::uuid, 'Crew item',
      '00000000-0000-0000-0000-0000000007a2')$$,
  '42501', null, 'Crew cannot raise items by default');
select pg_temp.as_user('a5');
select throws_ok(
  $$select public.create_work_item(current_setting('test.space')::uuid, 'Eve item',
      '00000000-0000-0000-0000-0000000007a2')$$,
  '42501', null, 'a non-member cannot raise items');

-- Uploads (r09, finding 3) -----------------------------------------------------------------

select pg_temp.as_user('a4');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('space-files', pg_temp.path('c001', 'viewer.jpg'))$$,
  '42501', null, '(r09) a Viewer cannot upload');
select pg_temp.as_user('a1');
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('space-files', current_setting('test.space') || '/loose.jpg')$$,
  '42501', null, '(r09) nobody uploads outside an item folder');
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values ('space-files', pg_temp.path('c00a', 'new.jpg'), '00000000-0000-0000-0000-0000000007a1')$$,
  '(r09) someone who can raise items uploads for an item not made yet');
select pg_temp.as_user('a2');
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values ('space-files', pg_temp.path('c001', 'leftover.jpg'), '00000000-0000-0000-0000-0000000007a2')$$,
  '(r09) the owner uploads into their item''s folder');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('space-files', pg_temp.path('c00b', 'crew.jpg'))$$,
  '42501', null, '(r09) Crew cannot upload for an item that doesn''t exist');
select pg_temp.as_user('a5');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('space-files', pg_temp.path('c001', 'eve.jpg'))$$,
  '42501', null, 'a non-member cannot upload into a Space');

-- Reading (rule 8) ------------------------------------------------------------------------

select is((select count(*) from public.work_items), 0::bigint, 'a non-member reads no work items');
select is((select count(*) from public.work_item_events), 0::bigint, 'a non-member reads no events');
select is((select count(*) from public.work_item_evidence), 0::bigint, 'a non-member reads no evidence');
select pg_temp.as_user('a4');
select is((select count(*) from public.work_items), 2::bigint, 'a Viewer in the Space reads its items');
select throws_ok(
  $$insert into public.work_items (space_id, number, ref, title)
    values (current_setting('test.space')::uuid, 99, 'KCT-099', 'Sneaky')$$,
  '42501', null, 'the app cannot write work items directly');
select throws_ok($$update public.work_items set status = 'checked'$$,
  '42501', null, 'the app cannot change a status directly');

-- Sign as done (W4, rule 4) ----------------------------------------------------------------

select pg_temp.as_user('a1');
select throws_ok($$select public.sign_done(pg_temp.item('c001'), 'done', '[]')$$,
  '42501', null, 'only the owner signs as done');
select pg_temp.as_user('a2');
select throws_ok($$select public.sign_done(pg_temp.item('c001'), '  ', '[]')$$,
  '22023', null, 'signing needs a photo or a note');
select throws_ok(
  $$select public.sign_done(pg_temp.item('c001'), null, pg_temp.photo('c001', 'never-uploaded.jpg'))$$,
  '22023', null, '(r09) a made-up photo path does not count as a photo');
select throws_ok(
  $$select public.sign_done(pg_temp.item('c001'), null, pg_temp.photo('c001', 'omars.jpg'))$$,
  '22023', null, '(r09) someone else''s upload does not count as your photo');
select lives_ok($$select public.sign_done(pg_temp.item('c001'), 'Rebar fixed and tied.', '[]')$$,
  'the owner signs as done with a note');
select is((select status from public.work_items where id = pg_temp.item('c001')), 'done', 'the item is Done');
select throws_ok($$select public.sign_done(pg_temp.item('c001'), 'again', '[]')$$,
  'P0001', null, 'a Done item cannot be signed again');

-- Check and send back (rules 5, 6) ---------------------------------------------------------

select throws_ok($$select public.check_item(pg_temp.item('c001'))$$,
  '42501', null, 'the owner cannot check their own item');
select pg_temp.as_user('a4');
select throws_ok($$select public.check_item(pg_temp.item('c001'))$$, '42501', null, 'a Viewer cannot check');
select pg_temp.as_user('a1');
select throws_ok($$select public.send_back(pg_temp.item('c001'), null, null)$$,
  '22023', null, 'sending back needs a reason');
select throws_ok($$select public.send_back(pg_temp.item('c001'), 'other', ' ')$$,
  '22023', null, '"Other" needs a note');
select lives_ok($$select public.send_back(pg_temp.item('c001'), 'photo_missing', 'Add a photo of the ties.')$$,
  'the creator sends it back with a reason');
select is((select status from public.work_items where id = pg_temp.item('c001')), 'open', 'sent back: Open again');
select is((select reason from public.work_item_events
           where work_item_id = pg_temp.item('c001') and kind = 'sent_back'),
  'photo_missing', 'the reason is in the record');
select throws_ok($$select public.check_item(pg_temp.item('c001'))$$,
  'P0001', null, 'an Open item cannot be checked');
select pg_temp.as_user('a2');
select lives_ok($$select public.sign_done(pg_temp.item('c001'), null, pg_temp.photo('c001', 'done.jpg'))$$,
  'the owner signs again with their uploaded photo');
select pg_temp.as_user('a3');
select lives_ok($$select public.check_item(pg_temp.item('c001'))$$,
  'a member with the check right checks and closes it');
select is((select status || ' by ' || checked_by::text from public.work_items where id = pg_temp.item('c001')),
  'checked by 00000000-0000-0000-0000-0000000007a3', 'Checked, by Sara');
select throws_ok($$select public.send_back(pg_temp.item('c001'), 'not_finished', null)$$,
  'P0001', null, 'a Checked item cannot be sent back');

select pg_temp.as_user('a1');
select set_config('test.self',
  public.create_work_item(current_setting('test.space')::uuid, 'Sign the permit',
    '00000000-0000-0000-0000-0000000007a1')::text, true);
select lives_ok($$select public.sign_done(current_setting('test.self')::uuid, 'Signed.', '[]')$$,
  'an admin signs their own item as done');
select throws_ok($$select public.check_item(current_setting('test.self')::uuid)$$,
  '42501', null, 'nobody checks an item they own, even its creator and an admin');
select pg_temp.as_user('a3');
select lives_ok($$select public.check_item(current_setting('test.self')::uuid)$$, 'someone else checks it');

-- Evidence can't be swapped (r09, finding 1) -----------------------------------------------

-- Rakesh tries to rename his Done photo: no update rule lets it through.
-- Deletes go through the Storage API, which applies may_delete_file().
select pg_temp.as_user('a2');
update storage.objects set name = name || '.swapped'
where bucket_id = 'space-files' and name = pg_temp.path('c001', 'done.jpg');
reset role;
select ok(not exists (select 1 from storage.objects where name = pg_temp.path('c001', 'done.jpg.swapped')),
  '(r09) a photo cannot be replaced or renamed after the fact');
select pg_temp.as_user('a2');
set local role authenticated;
select ok(not public.may_delete_file(pg_temp.path('c001', 'done.jpg'), '00000000-0000-0000-0000-0000000007a2'),
  '(r09) a photo that is evidence cannot be deleted, even by its uploader');
select ok(public.may_delete_file(pg_temp.path('c001', 'leftover.jpg'), '00000000-0000-0000-0000-0000000007a2'),
  '(r09) your own unused upload can be deleted');
select ok(not public.may_delete_file(pg_temp.path('c001', 'omars.jpg'), '00000000-0000-0000-0000-0000000007a1'),
  '(r09) someone else''s upload cannot be deleted');

-- Discussion and the record (rule 1) -------------------------------------------------------

select pg_temp.as_user('a4');
select lives_ok($$select public.add_comment(current_setting('test.item2')::uuid, 'Is the cover on site?')$$,
  'a Viewer comments');
select throws_ok($$select public.add_comment(current_setting('test.item2')::uuid, ' ')$$,
  '22023', null, 'an empty comment is refused');
select pg_temp.as_user('a5');
select throws_ok($$select public.add_comment(current_setting('test.item2')::uuid, 'hi')$$,
  '42501', null, 'a non-member cannot comment');
select pg_temp.as_user('a1');
select throws_ok($$update public.work_item_events set note = 'changed'$$,
  '42501', null, 'the app cannot change events');
select throws_ok($$delete from public.work_item_events$$, '42501', null, 'the app cannot delete events');
reset role;
select throws_ok($$update public.work_item_events set note = 'changed'$$,
  '42501', null, 'not even the database owner changes an event');
select throws_ok($$delete from public.work_item_events$$,
  '42501', null, 'not even the database owner deletes an event');
set local role service_role;
select lives_ok($$update public.work_item_events set note = 'Is the cover on site? (edited by support)'
                  where kind = 'comment'$$,
  '(r09) the service role can correct the record for support');
reset role;

-- Needs you (rule 9) ------------------------------------------------------------------------

select pg_temp.as_user('a2');
set local role authenticated;
select is((select count(*) from public.needs_you()
           where kind = 'open_owned' and work_item_id = current_setting('test.item2')::uuid),
  1::bigint, 'an Open item I own needs me');
select public.sign_done(current_setting('test.item2')::uuid, 'Cover fixed.', '[]');
select pg_temp.as_user('a1');
select is((select count(*) from public.needs_you()
           where kind = 'to_check' and work_item_id = current_setting('test.item2')::uuid),
  1::bigint, 'a Done item I raised needs me to check it');
select is((select needs_you from public.my_spaces() where space_id = current_setting('test.space')::uuid),
  1, 'My Spaces counts it');
select pg_temp.as_user('a2');
select is((select count(*) from public.needs_you() where kind = 'to_check'),
  0::bigint, 'the owner is never asked to check');

-- A pass changed to Viewer can't sign (r09, finding 9) -------------------------------------

select pg_temp.as_user('a1');
select set_config('test.item3',
  public.create_work_item(current_setting('test.space')::uuid, 'Seal the riser',
    '00000000-0000-0000-0000-0000000007a2')::text, true);
reset role;
update public.space_members set pass = 'viewer'
where space_id = current_setting('test.space')::uuid and profile_id = '00000000-0000-0000-0000-0000000007a2';
select pg_temp.as_user('a2');
set local role authenticated;
select throws_ok($$select public.sign_done(current_setting('test.item3')::uuid, 'done', '[]')$$,
  '42501', null, '(r09) an owner whose pass became Viewer cannot sign');
reset role;
update public.space_members set pass = 'crew'
where space_id = current_setting('test.space')::uuid and profile_id = '00000000-0000-0000-0000-0000000007a2';

-- Reassign (r09, finding 4) ----------------------------------------------------------------

-- Rakesh leaves; his Open item goes into the creator's Needs you.
update public.space_members set left_at = now()
where space_id = current_setting('test.space')::uuid and profile_id = '00000000-0000-0000-0000-0000000007a2';
select pg_temp.as_user('a1');
set local role authenticated;
select is((select count(*) from public.needs_you()
           where kind = 'owner_left' and work_item_id = current_setting('test.item3')::uuid),
  1::bigint, '(r09) an Open item whose owner left needs its creator: "Owner left · reassign"');
select pg_temp.as_user('a4');
select throws_ok($$select public.reassign_work_item(current_setting('test.item3')::uuid,
                    '00000000-0000-0000-0000-0000000007a3')$$,
  '42501', null, '(r09) a Viewer cannot reassign');
select pg_temp.as_user('a1');
select throws_ok($$select public.reassign_work_item(current_setting('test.item3')::uuid,
                    '00000000-0000-0000-0000-0000000007a4')$$,
  '22023', null, '(r09) a Viewer cannot be the new owner');
select lives_ok($$select public.reassign_work_item(current_setting('test.item3')::uuid,
                   '00000000-0000-0000-0000-0000000007a3')$$,
  '(r09) the creator reassigns it to Sara');
select is((select owner_id from public.work_items where id = current_setting('test.item3')::uuid),
  '00000000-0000-0000-0000-0000000007a3'::uuid, '(r09) Sara owns it now');
select is((select count(*) from public.work_item_events
           where work_item_id = current_setting('test.item3')::uuid and kind = 'reassigned'),
  1::bigint, '(r09) the reassignment is in the record');
select is((select count(*) from public.needs_you() where kind = 'owner_left'),
  0::bigint, '(r09) no longer "Owner left"');
select throws_ok($$select public.reassign_work_item(current_setting('test.self')::uuid,
                    '00000000-0000-0000-0000-0000000007a3')$$,
  'P0001', null, '(r09) only an Open item can be reassigned');
reset role;
update public.space_members set left_at = null
where space_id = current_setting('test.space')::uuid and profile_id = '00000000-0000-0000-0000-0000000007a2';

-- Shown work (rule 10) ------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.set_shown_work(pg_temp.item('c001'), true)$$,
  '42501', null, 'only the owner shows an item');
-- Item 4: raised with Omar's photo; Rakesh signs with a note only.
select public.create_work_item(current_setting('test.space')::uuid, 'Patch the slab edge',
  '00000000-0000-0000-0000-0000000007a2', null, null, 'Level 4',
  pg_temp.photo('c004', 'raised4.jpg'), pg_temp.item('c004'));
select pg_temp.as_user('a2');
select public.sign_done(pg_temp.item('c004'), 'Patched.', '[]');
select pg_temp.as_user('a3');
select public.check_item(pg_temp.item('c004'));
select pg_temp.as_user('a2');
select throws_ok($$select public.set_shown_work(current_setting('test.item2')::uuid, true)$$,
  'P0001', null, 'only Checked work can be shown');
select pg_temp.as_user('a5');
select is((select count(*) from public.public_shown_work), 0::bigint, 'nothing is shown by default');
select pg_temp.as_user('a2');
select lives_ok($$select public.set_shown_work(pg_temp.item('c001'), true)$$, 'the owner shows a Checked item');
select public.set_shown_work(pg_temp.item('c004'), true);

select pg_temp.as_user('a5');
select results_eq(
  $$select title, place_text, checked_by_name, project_name from public.public_shown_work
    where work_item_id = pg_temp.item('c001')$$,
  $$values ('Fix rebar at grid C7'::text, 'Grid C7'::text, 'Sara Ali'::text, 'Kuwait City Tower'::text)$$,
  'anyone signed in sees the title, place, checker and project');
select is((select photo_path from public.public_shown_work where work_item_id = pg_temp.item('c001')),
  pg_temp.path('c001', 'done.jpg'), 'one photo: the owner''s Done photo');
select is((select photo_path from public.public_shown_work where work_item_id = pg_temp.item('c004')),
  null, '(r09) no Done photo: no public photo, never the photo from when it was raised');
select is(
  (select array_agg(column_name::text collate "C" order by ordinal_position)
   from information_schema.columns
   where table_schema = 'public' and table_name = 'public_shown_work'),
  array['work_item_id', 'profile_id', 'title', 'place_text', 'photo_path',
        'checked_by_name', 'checked_at', 'project_name']::text[],
  'the public view has only these fields (no Space name, discussion or files)');

-- Photos readable by non-members: only the shown one.
reset role;
select set_config('test.files', (select count(*) from storage.objects
  where bucket_id = 'space-files' and name like current_setting('test.space') || '/%')::text, true);
select pg_temp.as_user('a5');
set local role authenticated;
select is((select count(*) from storage.objects where bucket_id = 'space-files'), 1::bigint,
  'a non-member reads only the shown photo');
select is((select name from storage.objects where bucket_id = 'space-files'),
  pg_temp.path('c001', 'done.jpg'), '(r09) and the raised photo of item 4 stays private');
select pg_temp.as_user('a4');
select is((select count(*) from storage.objects where bucket_id = 'space-files')::text,
  current_setting('test.files'), 'members read every file in their Space');

-- Blocks (r09, finding 6) --------------------------------------------------------------------

reset role;
insert into public.blocks (blocker_id, blocked_id)
values ('00000000-0000-0000-0000-0000000007a5', '00000000-0000-0000-0000-0000000007a2');
select pg_temp.as_user('a5');
set local role authenticated;
select is((select count(*) from public.public_shown_work), 0::bigint,
  '(r09) someone who blocked the owner sees none of their shown work');
select is((select count(*) from storage.objects where bucket_id = 'space-files'), 0::bigint,
  '(r09) nor its photo');
reset role;
delete from public.blocks where blocker_id = '00000000-0000-0000-0000-0000000007a5';
select pg_temp.as_user('a3');
set local role authenticated;
select is((select count(*) from public.public_shown_work), 2::bigint,
  '(r09) someone who didn''t block still sees it');

-- Deleted Space and deleted owner (r09, findings 7, 10) ------------------------------------

reset role;
update public.spaces set deleted_at = now() where id = current_setting('test.space')::uuid;
select pg_temp.as_user('a5');
set local role authenticated;
select is((select count(*) from storage.objects where bucket_id = 'space-files'), 0::bigint,
  '(r09) photos of a deleted Space can no longer be read');
select is((select count(*) from public.public_shown_work), 0::bigint,
  'nor is its work shown');
reset role;
update public.spaces set deleted_at = null where id = current_setting('test.space')::uuid;
update public.work_items set owner_id = null where id = pg_temp.item('c001');
select pg_temp.as_user('a5');
set local role authenticated;
select is((select count(*) from public.public_shown_work where work_item_id = pg_temp.item('c001')),
  0::bigint, '(r09) work of a deleted account is not shown');

-- Hard deletes (r09, finding 11) -------------------------------------------------------------

reset role;
select lives_ok($$delete from public.work_items where id = current_setting('test.item2')::uuid$$,
  '(r09) a hard delete cascades through the record');
select is((select count(*) from public.work_item_events
           where work_item_id = current_setting('test.item2')::uuid),
  0::bigint, '(r09) its events went with it');

select * from finish();
rollback;
