-- Migration 18: the daybook core. Run with: supabase test db
--
-- Omar (e1) made the Space and is its admin (Lead). Rakesh (e2) and Lina
-- (e7) are Crew, Sara (e3) is Lead, Vera (e4) a Viewer, Tariq (e6) Crew in
-- the MEP Team. Eve (e5) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(122);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000018' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@daybook18.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e5'), ('e6'), ('e7')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e4', 'Vera', 'Lane'), ('e5', 'Eve', 'Out'), ('e6', 'Tariq', 'Aziz'),
             ('e7', 'Lina', 'Saad')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000018' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000018' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000018' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000018' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.post_path(p_item text, p_file text) returns text language sql as $$
  select current_setting('test.space') || '/posts/' || pg_temp.item(p_item)::text || '/' || p_file;
$$;
create function pg_temp.raise(p_item text, p_title text, p_owner text,
                              p_parent text default null, p_team uuid default null)
returns uuid language sql as $$
  select public.create_work_item(pg_temp.sp(), p_title, pg_temp.uid(p_owner), null, p_team, null,
    '[]'::jsonb, pg_temp.item(p_item),
    p_parent => case when p_parent is null then null else pg_temp.item(p_parent) end);
$$;
-- Run as the database owner: count notifications of a kind for a person.
create function pg_temp.n(p_who text, p_kind text) returns bigint language sql as $$
  select count(*) from public.notifications where profile_id = pg_temp.uid(p_who) and kind = p_kind;
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Daybook site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e3', 'lead'), ('e4', 'viewer'), ('e6', 'crew'), ('e7', 'crew')) x(id, pass);
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.team',
  public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('e6')])::text, true);
reset role;

select ok((select relrowsecurity from pg_class where oid = 'public.space_posts'::regclass),
  'space_posts has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.post_edits'::regclass),
  'post_edits has row-level security');
select ok((select relrowsecurity from pg_class where oid = 'public.post_files'::regclass),
  'post_files has row-level security');

-- The backfill: every existing work item becomes a post with the same id ---------------------

-- Replay the migration's backfill on an item made the old way (no post).
alter table public.work_items drop constraint work_items_post_fkey;
insert into public.work_items (id, space_id, number, ref, title, owner_id, created_by, team_id,
                               place_text, due_date)
values (pg_temp.item('b001'), pg_temp.sp(), 900, 'DS-900', 'Old item from before', pg_temp.uid('e2'),
        pg_temp.uid('e3'), current_setting('test.team')::uuid, 'Gate 2', '2026-11-02');
insert into public.space_posts (id, space_id, team_id, kind, author_id, title, place_text,
                                due_date, created_at)
select w.id, w.space_id, w.team_id, 'work_item', w.created_by, w.title, w.place_text,
       w.due_date, w.created_at
from public.work_items w
where not exists (select 1 from public.space_posts p where p.id = w.id);
alter table public.work_items
  add constraint work_items_post_fkey
  foreign key (id) references public.space_posts (id) on delete cascade;
select is((select row(p.kind, p.title, p.place_text, p.due_date, p.team_id, p.author_id)::text
           from public.space_posts p where p.id = pg_temp.item('b001')),
  row('work_item', 'Old item from before', 'Gate 2', '2026-11-02'::date,
      current_setting('test.team')::uuid, pg_temp.uid('e3'))::text,
  'the backfill gives an old item a post with the same id, title, place, due, Team and author');
select is((select count(*) from public.work_items w
           where not exists (select 1 from public.space_posts p where p.id = w.id)), 0::bigint,
  'every work item has its post');
delete from public.space_posts where id = pg_temp.item('b001');

-- Who can post (A0) --------------------------------------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select lives_ok($$select pg_temp.raise('a004', 'Crew raises this', 'e3')$$, 'Crew can post work');
select pg_temp.as_user('e4');
select throws_ok($$select pg_temp.raise('a099', 'Viewer tries', 'e2')$$, '42501', null,
  'a Viewer can''t post');
select pg_temp.as_user('e5');
select throws_ok($$select pg_temp.raise('a098', 'Stranger tries', 'e2')$$, '42501', null,
  'a non-member can''t post');
select pg_temp.as_user('e1');
select lives_ok($$select public.set_member_pass(pg_temp.sp(), pg_temp.uid('e7'), 'crew',
                    '{"create_items": false}')$$,
  'an admin can switch posting off for one Crew member');
select is(public.member_rights(pg_temp.sp(), pg_temp.uid('e7')) ->> 'is_custom', 'true',
  'and that pass shows as Custom');
select ok(not (public.member_rights(pg_temp.sp(), pg_temp.uid('e1')) ? 'check_items'),
  'check_items is no longer a right');
select ok(not public.can(pg_temp.sp(), 'check_items'), 'nobody has check_items, admins included');
select pg_temp.as_user('e7');
select throws_ok($$select pg_temp.raise('a097', 'Switched off', 'e2')$$, '42501', null,
  'a Crew member with posting switched off can''t post');
select pg_temp.as_user('e1');
select public.set_member_pass(pg_temp.sp(), pg_temp.uid('e4'), 'viewer', '{"create_items": true}');
select is(public.member_rights(pg_temp.sp(), pg_temp.uid('e4')) ->> 'create_items', 'false',
  'a Viewer can''t be given posting with a custom right');
select pg_temp.as_user('e4');
select throws_ok($$select pg_temp.raise('a096', 'Viewer with a custom right', 'e2')$$, '42501', null,
  'so that Viewer still can''t post');
select pg_temp.as_user('e1');
select public.set_member_pass(pg_temp.sp(), pg_temp.uid('e7'), 'crew', '{}');

-- The items for the rest of the file.
select pg_temp.as_user('e3');
select pg_temp.raise('a001', 'Fix the gate', 'e2');
select pg_temp.raise('a006', 'Fresh one', 'e2');
select pg_temp.raise('a007', 'Has an update', 'e2');
select pg_temp.raise('a008', 'Level 3 target', 'e2');
select lives_ok($$select pg_temp.raise('a009', 'Under the target', 'e2', p_parent => 'a008')$$,
  'the author adds a work item under their own work item');
select pg_temp.raise('a011', 'To be cancelled', 'e2');
select pg_temp.raise('a012', 'Under the cancelled one', 'e6', p_parent => 'a011');
select pg_temp.raise('a016', 'Sara gives this to Tariq', 'e6');
select pg_temp.raise('a017', 'Signed before delete', 'e2');
select pg_temp.as_user('e7');
select pg_temp.raise('a003', 'Lina raised this', 'e2');
select pg_temp.raise('a015', 'Lina leaves this open', 'e2');
select pg_temp.as_user('e6');
select pg_temp.raise('a005', 'MEP sleeve', 'e6', p_team => current_setting('test.team')::uuid);
select throws_ok($$select pg_temp.raise('a090', 'Under someone else''s', 'e2', p_parent => 'a008')$$,
  '42501', null, 'nobody else adds a work item under someone''s work item (review 34 D1)');

select pg_temp.as_user('e5');
select is((select count(*) from public.space_posts), 0::bigint, 'a non-member reads no posts');
select is((select count(*) from public.daybook_cards(pg_temp.sp())), 0::bigint,
  'and gets no daybook cards');
select is(public.post_page(pg_temp.item('a001')), null, 'and no post page');

-- No chat card on a new event (A0) --------------------------------------------------------------

reset role;
select is((select count(*) from public.messages where kind = 'work_item'), 0::bigint,
  'raising work posts no card in chat');
set local role authenticated;

-- Editing: the author only, while Open ------------------------------------------------------------

select pg_temp.as_user('e1');
select throws_ok($$select public.edit_space_post(pg_temp.item('a001'), '{"title": "Admin rewrite"}')$$,
  '42501', null, 'a Space admin can''t rewrite someone''s post');
select pg_temp.as_user('e2');
select throws_ok($$select public.edit_space_post(pg_temp.item('a001'), '{"title": "Owner rewrite"}')$$,
  '42501', null, 'nor can the owner (they post an update instead)');
select pg_temp.as_user('e5');
select throws_ok($$select public.edit_space_post(pg_temp.item('a001'), '{"title": "Stranger"}')$$,
  '42501', null, 'nor a non-member');
select pg_temp.as_user('e3');
select lives_ok($$select public.edit_space_post(pg_temp.item('a001'),
                   '{"title": "Fix the north gate", "due": "2026-11-09"}')$$,
  'the author edits the title and the due date');
select is((select changes from public.post_edits where post_id = pg_temp.item('a001')),
  '{"due": {"to": "2026-11-09", "from": null}, "title": {"to": "Fix the north gate", "from": "Fix the gate"}}'::jsonb,
  'the edit is recorded field by field');
select is((select title || ' ' || due_date from public.work_items where id = pg_temp.item('a001')),
  'Fix the north gate 2026-11-09', 'the work item reads the same');
select throws_ok($$select public.edit_space_post(pg_temp.item('a001'), '{"owner": "x"}')$$,
  '22023', null, 'the owner is changed by giving it to someone else, not by editing');
reset role;
select is(pg_temp.n('e2', 'item_edited'), 1::bigint, 'the owner is told about the edit');

-- The post's own files, added and removed in an edit.
insert into storage.objects (bucket_id, name, owner_id, metadata)
values ('space-files', pg_temp.post_path('a001', 'plan.jpg'), pg_temp.uid('e3')::text,
        '{"mimetype": "image/jpeg", "size": 1000}');
select pg_temp.as_user('e3');
set local role authenticated;
select lives_ok(format($$select public.edit_space_post(pg_temp.item('a001'),
                   '{"add_files": [{"path": %s}]}')$$, to_jsonb(pg_temp.post_path('a001', 'plan.jpg'))),
  'the author adds a photo to the post');
select is((select count(*) from public.post_files where post_id = pg_temp.item('a001')), 1::bigint,
  'it is on the post');
select pg_temp.as_user('e2');
select is((select count(*) from storage.objects where name = pg_temp.post_path('a001', 'plan.jpg')),
  1::bigint, 'and a member can see the file');
select pg_temp.as_user('e5');
select is((select count(*) from storage.objects where name = pg_temp.post_path('a001', 'plan.jpg')),
  0::bigint, 'a non-member can''t');
select is((select count(*) from public.post_files), 0::bigint, 'a non-member reads no post files');
select pg_temp.as_user('e3');
select lives_ok(format($$select public.edit_space_post(pg_temp.item('a001'), '{"remove_files": [%s]}')$$,
                       to_jsonb((select id from public.post_files where post_id = pg_temp.item('a001')))),
  'and removes it again');
select is((select count(*) from public.post_edits
           where post_id = pg_temp.item('a001') and changes ? 'files'), 2::bigint,
  'both file changes are in the record');
select pg_temp.as_user('e5');
select is((select count(*) from public.post_edits), 0::bigint, 'a non-member reads no edits');

-- Locked after Done, reopened by Send back, locked for good after Checked.
select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('a001'), 'Gate fixed.');
select pg_temp.as_user('e3');
select throws_ok($$select public.edit_space_post(pg_temp.item('a001'), '{"title": "After done"}')$$,
  'P0001', null, 'no edits after Done');
select pg_temp.as_user('e1');
select throws_ok($$select public.check_item(pg_temp.item('a001'))$$, '42501', null,
  'a Space admin who isn''t the author can''t check');
select pg_temp.as_user('e2');
select throws_ok($$select public.check_item(pg_temp.item('a001'))$$, '42501', null,
  'the owner never checks');
select pg_temp.as_user('e3');
select is((select count(*) from public.needs_you() where kind = 'to_check'
           and work_item_id = pg_temp.item('a001')), 1::bigint, 'the author is asked to check');
select pg_temp.as_user('e1');
select is((select count(*) from public.needs_you() where work_item_id = pg_temp.item('a001')),
  0::bigint, 'a Lead or admin who isn''t the author is not');
select pg_temp.as_user('e3');
-- The 0.9.0 test build still sends the old name.
select lives_ok($$select public.send_back(pg_temp.item('a001'), 'not_as_drawing')$$,
  'the old reason name from the 0.9.0 app is still accepted');
reset role;
select is((select string_agg(reason, ',') from public.work_item_events
           where work_item_id = pg_temp.item('a001') and kind = 'sent_back'), 'not_as_asked',
  'and stored as Not as asked');
select is((select payload ->> 'reason' from public.notifications
           where profile_id = pg_temp.uid('e2') and kind = 'item_sent_back'
             and work_item_id = pg_temp.item('a001')), 'not_as_asked',
  'the owner is told the new name');
select pg_temp.as_user('e2');
set local role authenticated;
select public.sign_done(pg_temp.item('a001'), 'Done, as asked.');
select pg_temp.as_user('e3');
select throws_ok($$select public.send_back(pg_temp.item('a001'), 'not_as_shown')$$, '22023', null,
  'a reason that isn''t on the list is refused');
select lives_ok($$select public.send_back(pg_temp.item('a001'), 'not_as_asked')$$,
  'the author sends it back: Not as asked');
select lives_ok($$select public.edit_space_post(pg_temp.item('a001'), '{"place": "North gate"}')$$,
  'editing is open again after Send back');
select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('a001'), 'Done again.');
select pg_temp.as_user('e3');
select lives_ok($$select public.check_item(pg_temp.item('a001'))$$, 'the author checks it');
select throws_ok($$select public.edit_space_post(pg_temp.item('a001'), '{"title": "After checked"}')$$,
  'P0001', null, 'no edits after Checked');
select throws_ok($$select public.cancel_space_post(pg_temp.item('a001'))$$, 'P0001', null,
  'checked work can''t be cancelled');
reset role;
select is((select count(*) from public.messages where kind = 'work_item'), 0::bigint,
  'no chat card after done, send back or check either');

-- Updates (comments): the owner, Lead and Crew; Viewers read only -----------------------------

select pg_temp.as_user('e4');
set local role authenticated;
select throws_ok($$select public.add_comment(pg_temp.item('a007'), 'Viewer here')$$, '42501', null,
  'a Viewer can''t add an update');
select is((select count(*) from public.space_posts where id = pg_temp.item('a007')), 1::bigint,
  'but reads the post');
select pg_temp.as_user('e2');
select lives_ok($$select public.add_comment(pg_temp.item('a007'), 'On it')$$,
  'the owner adds an update');
select pg_temp.as_user('e6');
select lives_ok($$select public.add_comment(pg_temp.item('a007'), 'Crew note')$$,
  'a Crew member adds one');

-- Delete while nothing was added; Cancel after ----------------------------------------------------

select pg_temp.as_user('e3');
select throws_ok($$select public.delete_space_post(pg_temp.item('a007'))$$, 'P0001', null,
  'delete is refused once someone else added an update');
select throws_ok($$select public.delete_space_post(pg_temp.item('a008'))$$, 'P0001', null,
  'and once a work item is under it, even the author''s own');
select pg_temp.as_user('e1');
select throws_ok($$select public.delete_space_post(pg_temp.item('a006'))$$, '42501', null,
  'only the author deletes');
select pg_temp.as_user('e3');
select public.reassign_work_item(pg_temp.item('a006'), pg_temp.uid('e6'));
select public.edit_space_post(pg_temp.item('a006'), '{"title": "Fresh one, renamed"}');
select lives_ok($$select public.delete_space_post(pg_temp.item('a006'))$$,
  'the author deletes a post nobody else touched (their own reassign and edit don''t count)');
select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('a017'), 'Signed.');
select pg_temp.as_user('e3');
select throws_ok($$select public.delete_space_post(pg_temp.item('a017'))$$, 'P0001', null,
  'a sign-off by the owner ends Delete');
select pg_temp.as_user('e2');
select is((select count(*) from public.space_posts where id = pg_temp.item('a006')), 0::bigint,
  'it leaves the daybook');
select is((select count(*) from public.work_items where id = pg_temp.item('a006')), 0::bigint,
  'and the work item with it');
select is((select count(*) from public.needs_you() where work_item_id = pg_temp.item('a006')),
  0::bigint, 'and it needs nobody');

select pg_temp.as_user('e1');
select throws_ok($$select public.cancel_space_post(pg_temp.item('a011'))$$, '42501', null,
  'an admin can''t cancel while the author is still in the Space');
select pg_temp.as_user('e3');
select lives_ok($$select public.cancel_space_post(pg_temp.item('a011'), 'Not needed now')$$,
  'the author cancels it');
select is((select string_agg(status, ',' order by id) from public.space_posts
           where id in (pg_temp.item('a011'), pg_temp.item('a012'))), 'cancelled,cancelled',
  'the work items under it are cancelled with it');
select is((select daybook.card -> 'stamp' ->> 'kind' from public.daybook_cards(pg_temp.sp(), null, 100) daybook
           where daybook.id = pg_temp.item('a011')), 'cancelled',
  'it stays in the daybook with a CANCELLED stamp');
select pg_temp.as_user('e2');
select throws_ok($$select public.sign_done(pg_temp.item('a011'), 'too late')$$, 'P0001', null,
  'a cancelled item can''t be signed as done');
reset role;
select is(pg_temp.n('e2', 'item_cancelled') + pg_temp.n('e6', 'item_cancelled'), 2::bigint,
  'each owner is told');

-- Work items under one work item -------------------------------------------------------------------

select pg_temp.as_user('e3');
set local role authenticated;
select throws_ok($$select pg_temp.raise('a010', 'Too deep', 'e2', p_parent => 'a009')$$, '22023', null,
  'one level only');
select is((select (daybook.card -> 'children') - 'rows' from public.daybook_cards(pg_temp.sp(), null, 100) daybook
           where daybook.id = pg_temp.item('a008')), '{"total": 1, "checked": 0}'::jsonb,
  'the parent shows its progress');
select is(jsonb_array_length(public.post_page(pg_temp.item('a008')) -> 'under'), 1,
  'opening it lists the work item under it');

-- The author has left: an admin acts for them -------------------------------------------------------

select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('a003'), 'Done for Lina.');
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e7');
select pg_temp.as_user('e3');
set local role authenticated;
select throws_ok($$select public.check_item(pg_temp.item('a003'))$$, '42501', null,
  'a Lead who isn''t the author can''t check, even when the author left');
select pg_temp.as_user('e1');
select is((select count(*) from public.needs_you() where kind = 'to_check'
           and work_item_id = pg_temp.item('a003')), 1::bigint,
  'an admin is asked to check when the author left');
select lives_ok($$select public.check_item(pg_temp.item('a003'))$$,
  'and an admin checks it for them');
select lives_ok($$select public.reassign_work_item(pg_temp.item('a015'), pg_temp.uid('e6'))$$,
  'an admin reassigns for an author who left');
select lives_ok($$select pg_temp.raise('a018', 'Under Lina''s item', 'e2', p_parent => 'a015')$$,
  'and adds a work item under it for them');
select lives_ok($$select public.cancel_space_post(pg_temp.item('a015'))$$,
  'and cancels for them');

-- Work given to yourself: an admin checks it.
select pg_temp.as_user('e6');
select public.sign_done(pg_temp.item('a005'), 'Sleeve in.');
select throws_ok($$select public.check_item(pg_temp.item('a005'))$$, '42501', null,
  'the author who owns it can''t check their own work');
select pg_temp.as_user('e1');
select lives_ok($$select public.check_item(pg_temp.item('a005'))$$,
  'a Space admin checks work its author gave to themselves');

-- Reassign: the author; an admin only when the author left ------------------------------------------

select pg_temp.as_user('e1');
select throws_ok($$select public.reassign_work_item(pg_temp.item('a007'), pg_temp.uid('e6'))$$,
  '42501', null, 'an admin can''t give away work while its author is in the Space');
select pg_temp.as_user('e3');
select lives_ok($$select public.reassign_work_item(pg_temp.item('a007'), pg_temp.uid('e6'))$$,
  'the author gives it to someone else');

-- Team posts: that Team, the admins, the author and the owner -----------------------------------------

select pg_temp.as_user('e2');
select is((select count(*) from public.space_posts where id = pg_temp.item('a005')), 0::bigint,
  'a member outside the Team doesn''t see a Team post');
select is((select count(*) from public.work_items where id = pg_temp.item('a005')), 0::bigint,
  'nor its work item through the old table');
select is((select count(*) from public.work_item_events where work_item_id = pg_temp.item('a005')),
  0::bigint, 'nor its record');
select pg_temp.as_user('e1');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100) d where d.id = pg_temp.item('a005')),
  1::bigint, 'a Space admin does');
select throws_ok($$select public.delete_team(current_setting('test.team')::uuid)$$, 'P0001', null,
  'a Team with posts can''t be deleted (its posts would reach everyone)');
select pg_temp.as_user('e2');
select is((select count(*) from public.space_posts where id = pg_temp.item('a005')), 0::bigint,
  'so the Team post stays hidden from the rest of the Space');

-- From a Team chat message: the post stays in that Team.
select pg_temp.as_user('e6');
select public.post_message(pg_temp.item('c001'),
  (select t.id from public.threads t where t.team_id = current_setting('test.team')::uuid),
  'Sleeves at C7 need checking');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'From the MEP chat', pg_temp.uid('e6'),
                    p_id => pg_temp.item('a013'), p_source_message => pg_temp.item('c001'))$$,
  'a work item can be made from a chat message');
select is((select team_id from public.space_posts where id = pg_temp.item('a013')),
  current_setting('test.team')::uuid, 'a Team chat message makes a Team post');
select pg_temp.as_user('e3');
select throws_ok($$select public.create_work_item(pg_temp.sp(), 'From a chat I can''t read',
                    pg_temp.uid('e2'), p_id => pg_temp.item('a014'),
                    p_source_message => pg_temp.item('c001'))$$,
  '42501', null, 'not from a message the caller can''t read');

-- Retrying the same id gives the same post ---------------------------------------------------------------

select pg_temp.as_user('e2');
select is(pg_temp.raise('a004', 'Crew raises this', 'e3'), pg_temp.item('a004'),
  'sending the same post again (a weak signal) makes no second one');
select pg_temp.as_user('e3');
select throws_ok($$select pg_temp.raise('a004', 'Someone else''s id', 'e2')$$, '42501', null,
  'someone else''s post id is refused');

-- Reading the daybook ---------------------------------------------------------------------------------------

select pg_temp.as_user('e6');
select is((select daybook.card ->> 'needs_me' from public.daybook_cards(pg_temp.sp(), null, 100) daybook
           where daybook.id = pg_temp.item('a007')), 'to_sign',
  'the paper clip: work given to me needs me');
reset role;
update public.space_posts set created_at = now() + interval '1 minute', last_activity_at = now() + interval '1 minute'
where id = pg_temp.item('a004');
select pg_temp.as_user('e6');
set local role authenticated;
select is((select daybook.id from public.daybook_cards(pg_temp.sp(), null, 1) daybook),
  pg_temp.item('a004'), 'newest first');
with page as (select d.id, d.last_activity_at, row_number() over () as n
              from public.daybook_cards(pg_temp.sp(), null, 3) d)
select is((select d.id from page c, public.daybook_cards(pg_temp.sp(), c.last_activity_at, 1, c.id) d
           where c.n = 2),
  (select id from page where n = 3),
  'the next page starts right after the last post, even at the same moment');
select ok(jsonb_array_length(public.post_page(pg_temp.item('a007')) -> 'events') >= 3,
  'opening a post shows its whole record');

-- A lowered author can't edit; an author waiting for deletion is gone -----------------------

select pg_temp.as_user('e1');
select public.set_member_pass(pg_temp.sp(), pg_temp.uid('e2'), 'viewer');
select pg_temp.as_user('e2');
select throws_ok($$select public.edit_space_post(pg_temp.item('a004'), '{"title": "As a Viewer"}')$$,
  '42501', null, 'an author lowered to Viewer can''t edit their post');
select ok(not public.may_upload(pg_temp.post_path('a004', 'late.jpg')),
  'nor upload into it');
select pg_temp.as_user('e1');
select public.set_member_pass(pg_temp.sp(), pg_temp.uid('e2'), 'crew');

-- Rakesh raises work for Tariq, then is lowered to Viewer (review 34 D2).
select pg_temp.as_user('e2');
select pg_temp.raise('a019', 'Rakesh asks Tariq', 'e6');
select pg_temp.as_user('e6');
select public.sign_done(pg_temp.item('a019'), 'Done for Rakesh.');
select pg_temp.as_user('e1');
select public.set_member_pass(pg_temp.sp(), pg_temp.uid('e2'), 'viewer');
select pg_temp.as_user('e2');
select throws_ok($$select public.check_item(pg_temp.item('a019'))$$, '42501', null,
  'an author lowered to Viewer can''t check');
select throws_ok($$select public.send_back(pg_temp.item('a019'), 'not_finished')$$, '42501', null,
  'or send back');
select throws_ok($$select public.reassign_work_item(pg_temp.item('a004'), pg_temp.uid('e6'))$$,
  '42501', null, 'or reassign');
select throws_ok($$select public.cancel_space_post(pg_temp.item('a004'))$$, '42501', null,
  'or cancel');
select pg_temp.as_user('e1');
select is((select count(*) from public.needs_you() where kind = 'to_check'
           and work_item_id = pg_temp.item('a019')), 1::bigint,
  'the admin is asked to check for them');
select lives_ok($$select public.send_back(pg_temp.item('a019'), 'not_finished')$$,
  'and sends it back for them');
select lives_ok($$select public.reassign_work_item(pg_temp.item('a004'), pg_temp.uid('e6'))$$,
  'and reassigns for them');
select public.set_member_pass(pg_temp.sp(), pg_temp.uid('e2'), 'crew');
select pg_temp.as_user('e6');
select public.sign_done(pg_temp.item('a019'), 'Done again.');
select pg_temp.as_user('e1');
select throws_ok($$select public.check_item(pg_temp.item('a019'))$$, '42501', null,
  'raised back to Crew: the admin no longer acts for them');
select throws_ok($$select public.reassign_work_item(pg_temp.item('a004'), pg_temp.uid('e3'))$$,
  '42501', null, 'nor reassigns for them');
select pg_temp.as_user('e2');
select lives_ok($$select public.check_item(pg_temp.item('a019'))$$,
  'and the author checks again');

-- D3: the only admin gives work to themselves; a Lead checks it.
select pg_temp.as_user('e1');
select pg_temp.raise('a020', 'Omar signs the permit', 'e1');
select public.sign_done(pg_temp.item('a020'), 'Permit signed.');
select throws_ok($$select public.check_item(pg_temp.item('a020'))$$, '42501', null,
  'the sole admin can''t check work they gave themselves');
select pg_temp.as_user('e6');
select throws_ok($$select public.check_item(pg_temp.item('a020'))$$, '42501', null,
  'nor can a Crew member');
select pg_temp.as_user('e3');
select is((select count(*) from public.needs_you() where kind = 'to_check'
           and work_item_id = pg_temp.item('a020')), 1::bigint,
  'with no other admin, a Lead is asked to check it (review 34 D3)');
select lives_ok($$select public.check_item(pg_temp.item('a020'))$$,
  'and checks it');

select pg_temp.as_user('e6');
select public.sign_done(pg_temp.item('a016'), 'Done for Sara.');
reset role;
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('e3');
select pg_temp.as_user('e1');
set local role authenticated;
select is((select count(*) from public.needs_you() where kind = 'to_check'
           and work_item_id = pg_temp.item('a016')), 1::bigint,
  'an admin is asked to check when the author''s account is being deleted');
select lives_ok($$select public.check_item(pg_temp.item('a016'))$$,
  'and checks it for them');
reset role;
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('e3');
set local role authenticated;

-- Nobody writes the tables directly ------------------------------------------------------------------------

select pg_temp.as_user('e5');
select throws_ok($$insert into public.space_posts (id, space_id, kind, author_id, title)
                   values (gen_random_uuid(), pg_temp.sp(), 'announcement', auth.uid(), 'x')$$,
  '42501', null, 'a non-member can''t write space_posts');
select throws_ok($$insert into public.post_edits (post_id, editor_id, changes)
                   values (pg_temp.item('a007'), auth.uid(), '{"title": {}}')$$,
  '42501', null, 'or post_edits');
select throws_ok($$insert into public.post_files (post_id, storage_path)
                   values (pg_temp.item('a007'), 'x/posts/y/z.jpg')$$,
  '42501', null, 'or post_files');
select pg_temp.as_user('e3');
select throws_ok($$update public.space_posts set title = 'direct' where id = pg_temp.item('a007')$$,
  '42501', null, 'even the author writes only through the functions');

-- The record of edits is kept --------------------------------------------------------------------------------

reset role;
select throws_ok($$update public.post_edits set changes = '{"title": {"to": "rewritten"}}'
                   where post_id = pg_temp.item('a001')$$,
  '42501', null, 'an edit in the record can''t be changed');
select throws_ok($$delete from public.post_edits where post_id = pg_temp.item('a001')$$,
  '42501', null, 'or deleted');

select * from finish();
rollback;
