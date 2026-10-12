-- Migration 7: work items. Run with: supabase test db
--
-- Omar (o1) runs the Space (admin, Lead) and raises the items. Rakesh (r2)
-- is Crew and owns them. Sara (s3) is Lead with the check right. Nadia (n4)
-- is a Viewer. Eve (e5) is not a member.

begin;
create extension if not exists pgtap with schema extensions;
select plan(65);

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

-- References -----------------------------------------------------------------------------

select is(public.latin_initials('Kuwait City Tower'), 'KCT', 'initials of a project name');
select is(public.latin_initials('Tower'), 'TO', 'one word: its first two letters');
select is(public.latin_initials('برج الكويت'), null, 'no Latin letters: no initials');

-- Omar makes two Spaces.
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

-- Members: Rakesh Crew, Sara Lead with the check right, Nadia Viewer.
insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (current_setting('test.space')::uuid, '00000000-0000-0000-0000-0000000007a2', 'crew', '00000000-0000-0000-0000-0000000007a1'),
  (current_setting('test.space')::uuid, '00000000-0000-0000-0000-0000000007a3', 'lead', '00000000-0000-0000-0000-0000000007a1'),
  (current_setting('test.space')::uuid, '00000000-0000-0000-0000-0000000007a4', 'viewer', '00000000-0000-0000-0000-0000000007a1');

-- Raising items (W2) ---------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.item', '00000000-0000-0000-0000-00000000c001', true);
select is(
  public.create_work_item(current_setting('test.space')::uuid, 'Fix rebar at grid C7',
    '00000000-0000-0000-0000-0000000007a2', current_date + 2, null, 'Grid C7',
    jsonb_build_array(jsonb_build_object(
      'path', current_setting('test.space') || '/00000000-0000-0000-0000-00000000c001/raised.jpg',
      'taken_at', now(), 'place', 'Grid C7')),
    current_setting('test.item')::uuid),
  current_setting('test.item')::uuid,
  'an admin raises an item for a Crew member');
select is((select ref from public.work_items where id = current_setting('test.item')::uuid),
  'KCT-001', 'references run per Space with three digits');
select is(
  public.create_work_item(current_setting('test.space')::uuid, 'Fix rebar at grid C7',
    '00000000-0000-0000-0000-0000000007a2', null, null, null, '[]', current_setting('test.item')::uuid),
  current_setting('test.item')::uuid,
  'a retry with the same id returns the same item');
select is((select count(*) from public.work_items where space_id = current_setting('test.space')::uuid),
  1::bigint, 'the retry made no second item');
select is((select count(*) from public.work_item_events
           where work_item_id = current_setting('test.item')::uuid and kind = 'raised'),
  1::bigint, 'raising writes one "raised" event');
select is((select count(*) from public.work_item_evidence
           where work_item_id = current_setting('test.item')::uuid),
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
  $$select public.create_work_item(current_setting('test.space')::uuid, 'X',
      '00000000-0000-0000-0000-0000000007a2')$$,
  '23514', null, 'a title needs at least two letters');

-- Crew can't raise items unless the admin opened it.
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

-- Reading (rule 8) ------------------------------------------------------------------------

select is((select count(*) from public.work_items), 0::bigint,
  'a non-member reads no work items');
select is((select count(*) from public.work_item_events), 0::bigint,
  'a non-member reads no events');
select is((select count(*) from public.work_item_evidence), 0::bigint,
  'a non-member reads no evidence');
select pg_temp.as_user('a4');
select is((select count(*) from public.work_items), 2::bigint,
  'a Viewer in the Space reads its items');
select throws_ok(
  $$insert into public.work_items (space_id, number, ref, title)
    values (current_setting('test.space')::uuid, 99, 'KCT-099', 'Sneaky')$$,
  '42501', null, 'the app cannot write work items directly');
select throws_ok(
  $$update public.work_items set status = 'checked'$$,
  '42501', null, 'the app cannot change a status directly');

-- Sign as done (W4, rule 4) ----------------------------------------------------------------

select pg_temp.as_user('a1');
select throws_ok(
  $$select public.sign_done(current_setting('test.item')::uuid, 'done', '[]')$$,
  '42501', null, 'only the owner signs as done');
select pg_temp.as_user('a2');
select throws_ok(
  $$select public.sign_done(current_setting('test.item')::uuid, '  ', '[]')$$,
  '22023', null, 'signing needs a photo or a note');
select lives_ok(
  $$select public.sign_done(current_setting('test.item')::uuid, 'Rebar fixed and tied.', '[]')$$,
  'the owner signs as done with a note');
select is((select status from public.work_items where id = current_setting('test.item')::uuid),
  'done', 'the item is Done');
select throws_ok(
  $$select public.sign_done(current_setting('test.item')::uuid, 'again', '[]')$$,
  'P0001', null, 'a Done item cannot be signed again');

-- Check and send back (rules 5, 6) ---------------------------------------------------------

select throws_ok(
  $$select public.check_item(current_setting('test.item')::uuid)$$,
  '42501', null, 'the owner cannot check their own item');
select pg_temp.as_user('a4');
select throws_ok(
  $$select public.check_item(current_setting('test.item')::uuid)$$,
  '42501', null, 'a Viewer cannot check');
select pg_temp.as_user('a1');
select throws_ok(
  $$select public.send_back(current_setting('test.item')::uuid, null, null)$$,
  '22023', null, 'sending back needs a reason');
select throws_ok(
  $$select public.send_back(current_setting('test.item')::uuid, 'other', ' ')$$,
  '22023', null, '"Other" needs a note');
select lives_ok(
  $$select public.send_back(current_setting('test.item')::uuid, 'photo_missing', 'Add a photo of the ties.')$$,
  'the creator sends it back with a reason');
select is((select status from public.work_items where id = current_setting('test.item')::uuid),
  'open', 'sent back: Open again');
select is((select reason from public.work_item_events
           where work_item_id = current_setting('test.item')::uuid and kind = 'sent_back'),
  'photo_missing', 'the reason is in the record');
select throws_ok(
  $$select public.check_item(current_setting('test.item')::uuid)$$,
  'P0001', null, 'an Open item cannot be checked');

select pg_temp.as_user('a2');
select lives_ok(
  $$select public.sign_done(current_setting('test.item')::uuid, null,
      jsonb_build_array(jsonb_build_object(
        'path', current_setting('test.space') || '/00000000-0000-0000-0000-00000000c001/done.jpg')))$$,
  'the owner signs again with a photo only');

-- Sara is Lead (check right) but not the creator: she may check.
select pg_temp.as_user('a3');
select lives_ok(
  $$select public.check_item(current_setting('test.item')::uuid)$$,
  'a member with the check right checks and closes it');
select is((select status || ' by ' || checked_by::text from public.work_items
           where id = current_setting('test.item')::uuid),
  'checked by 00000000-0000-0000-0000-0000000007a3', 'Checked, by Sara');
select throws_ok(
  $$select public.send_back(current_setting('test.item')::uuid, 'not_finished', null)$$,
  'P0001', null, 'a Checked item cannot be sent back');

-- Self-check (rule 5): Omar raises an item for himself; he can't check it.
select pg_temp.as_user('a1');
select set_config('test.self',
  public.create_work_item(current_setting('test.space')::uuid, 'Sign the permit',
    '00000000-0000-0000-0000-0000000007a1')::text, true);
select lives_ok($$select public.sign_done(current_setting('test.self')::uuid, 'Signed.', '[]')$$,
  'an admin signs their own item as done');
select throws_ok($$select public.check_item(current_setting('test.self')::uuid)$$,
  '42501', null, 'nobody checks an item they own, even its creator and an admin');
select pg_temp.as_user('a3');
select lives_ok($$select public.check_item(current_setting('test.self')::uuid)$$,
  'someone else checks it');

-- Events are append-only (rule 1) ----------------------------------------------------------

select throws_ok($$update public.work_item_events set note = 'changed'$$,
  '42501', null, 'the app cannot change events');
select throws_ok($$delete from public.work_item_events$$,
  '42501', null, 'the app cannot delete events');
reset role;
select throws_ok($$update public.work_item_events set note = 'changed'$$,
  '42501', null, 'not even the database owner changes an event');
select throws_ok($$delete from public.work_item_events$$,
  '42501', null, 'not even the database owner deletes an event');

-- Discussion ---------------------------------------------------------------------------------

select pg_temp.as_user('a4');
set local role authenticated;
select lives_ok($$select public.add_comment(current_setting('test.item2')::uuid, 'Is the cover on site?')$$,
  'a Viewer comments');
select throws_ok($$select public.add_comment(current_setting('test.item2')::uuid, ' ')$$,
  '22023', null, 'an empty comment is refused');
select pg_temp.as_user('a5');
select throws_ok($$select public.add_comment(current_setting('test.item2')::uuid, 'hi')$$,
  '42501', null, 'a non-member cannot comment');

-- Needs you (rule 9) ------------------------------------------------------------------------

select pg_temp.as_user('a2');
select is((select count(*) from public.needs_you()
           where kind = 'open_owned' and work_item_id = current_setting('test.item2')::uuid),
  1::bigint, 'an Open item I own needs me');
select pg_temp.as_user('a2');
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

-- Shown work (rule 10) ------------------------------------------------------------------------

select pg_temp.as_user('a1');
select throws_ok($$select public.set_shown_work(current_setting('test.item')::uuid, true)$$,
  '42501', null, 'only the owner shows an item');
select pg_temp.as_user('a2');
select throws_ok($$select public.set_shown_work(current_setting('test.item2')::uuid, true)$$,
  'P0001', null, 'only Checked work can be shown');
select pg_temp.as_user('a5');
select is((select count(*) from public.public_shown_work), 0::bigint,
  'nothing is shown by default');
select pg_temp.as_user('a2');
select lives_ok($$select public.set_shown_work(current_setting('test.item')::uuid, true)$$,
  'the owner shows a Checked item');

select pg_temp.as_user('a5');
select results_eq(
  $$select title, place_text, checked_by_name, project_name from public.public_shown_work$$,
  $$values ('Fix rebar at grid C7'::text, 'Grid C7'::text, 'Sara Ali'::text, 'Kuwait City Tower'::text)$$,
  'anyone signed in sees the title, place, checker and project');
select is((select photo_path from public.public_shown_work),
  current_setting('test.space') || '/00000000-0000-0000-0000-00000000c001/done.jpg',
  'one photo: the Done sign-off''s');
select is(
  (select array_agg(column_name::text collate "C" order by ordinal_position)
   from information_schema.columns
   where table_schema = 'public' and table_name = 'public_shown_work'),
  array['work_item_id', 'profile_id', 'title', 'place_text', 'photo_path',
        'checked_by_name', 'checked_at', 'project_name']::text[],
  'the public view has only these fields (no Space name, discussion or files)');

-- Evidence photos (rule 11) -------------------------------------------------------------------

reset role;
insert into storage.objects (bucket_id, name) values
  ('space-files', current_setting('test.space') || '/00000000-0000-0000-0000-00000000c001/done.jpg'),
  ('space-files', current_setting('test.space') || '/00000000-0000-0000-0000-00000000c001/raised.jpg');
select pg_temp.as_user('a5');
set local role authenticated;
select is((select count(*) from storage.objects where bucket_id = 'space-files'), 1::bigint,
  'a non-member reads only the shown photo');
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('space-files', current_setting('test.space') || '/x/eve.jpg')$$,
  '42501', null, 'a non-member cannot upload into a Space');
select pg_temp.as_user('a4');
select is((select count(*) from storage.objects where bucket_id = 'space-files'), 2::bigint,
  'members read every photo in their Space');

reset role;
select * from finish();
rollback;
