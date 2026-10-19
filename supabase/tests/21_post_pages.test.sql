-- Migration 20: pages, walk mode, meeting notes, templates, reports and
-- search. Run with: supabase test db
--
-- Omar (e1) made the Space and is its admin (Lead). Rakesh (e2) and Lina
-- (e7) are Crew, Sara (e3) is Lead, Vera (e4) a Viewer, Tariq (e6) Crew in
-- the MEP Team. Eve (e5) is not in the Space. Omar also runs "Other site".
-- Phones: e2, e6, e7.

begin;
create extension if not exists pgtap with schema extensions;
select plan(146);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000020' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@pages20.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e5'), ('e6'), ('e7')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e4', 'Vera', 'Lane'), ('e5', 'Eve', 'Out'), ('e6', 'Tariq', 'Aziz'),
             ('e7', 'Lina', 'Saad')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000020' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000020' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000020' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000020' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
create function pg_temp.everyone() returns uuid language sql as $$
  select id from public.threads where space_id = pg_temp.sp() and team_id is null;
$$;
create function pg_temp.team_thread() returns uuid language sql as $$
  select id from public.threads where team_id = pg_temp.team();
$$;
-- A post's own file, and a work item's proof photo, uploaded by [p_who].
create function pg_temp.post_path(p_post text, p_file text) returns text language sql as $$
  select current_setting('test.space') || '/posts/' || pg_temp.item(p_post) || '/' || p_file;
$$;
create function pg_temp.ev_path(p_item text, p_file text) returns text language sql as $$
  select current_setting('test.space') || '/' || pg_temp.item(p_item) || '/' || p_file;
$$;
create function pg_temp.upload(p_who text, p_path text, p_mime text default 'image/jpeg')
returns text language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('space-files', p_path, pg_temp.uid(p_who)::text,
          jsonb_build_object('mimetype', p_mime, 'size', 1000))
  returning name;
$$;
create function pg_temp.b(p_id text, p_type text, p_rest jsonb default '{}') returns jsonb
language sql as $$
  select jsonb_build_object('id', pg_temp.item(p_id), 'type', p_type) || p_rest;
$$;
create function pg_temp.ver(p_post text) returns integer language sql as $$
  select blocks_version from public.space_posts where id = pg_temp.item(p_post);
$$;
-- Run as the database owner.
create function pg_temp.n(p_who text, p_kind text, p_post text) returns bigint language sql as $$
  select count(*) from public.notifications
  where profile_id = pg_temp.uid(p_who) and kind = p_kind
    and coalesce(space_post_id, work_item_id) = pg_temp.item(p_post);
$$;
create function pg_temp.hits(p_q text) returns uuid[] language sql as $$
  select coalesce(array_agg(s.id), '{}') from public.search_space(pg_temp.sp(), p_q) s;
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Pages site')::text, true);
select set_config('test.space2', public.create_space('Other site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e3', 'lead'), ('e4', 'viewer'), ('e6', 'crew'), ('e7', 'crew')) x(id, pass);
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('e6')])::text, true);
reset role;
insert into public.push_tokens (token, profile_id, platform)
select 'fcm-token-for-' || x.id || '-0123456789abcdef', pg_temp.uid(x.id), 'android'
from (values ('e2'), ('e6'), ('e7')) x(id);
insert into public.library_files (id, space_id, team_id, name, storage_path, mime, bytes, uploaded_by)
values
  (pg_temp.item('f001'), pg_temp.sp(), null, 'Zebra doors',
   pg_temp.sp() || '/library/' || pg_temp.item('f001') || '/doors.pdf', 'application/pdf', 1000, pg_temp.uid('e3')),
  (pg_temp.item('f002'), pg_temp.sp(), pg_temp.team(), 'Zebra sleeves',
   pg_temp.sp() || '/library/' || pg_temp.item('f002') || '/sleeves.pdf', 'application/pdf', 1000, pg_temp.uid('e6'));
select pg_temp.upload('e3', pg_temp.post_path('a001', 'p1.jpg'));
select pg_temp.upload('e3', pg_temp.post_path('a002', 'p2.jpg'));

select ok((select relrowsecurity from pg_class where oid = 'public.post_templates'::regclass),
  'post_templates has row-level security');

-- A page ----------------------------------------------------------------------------------------

select pg_temp.as_user('e3');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Level 3 slab', pg_temp.uid('e2'), p_id => pg_temp.item('a001'));
select public.create_work_item(pg_temp.sp(), 'Other slab', pg_temp.uid('e2'), p_id => pg_temp.item('a002'),
  p_files => jsonb_build_array(jsonb_build_object('path', pg_temp.post_path('a002', 'p2.jpg'))));
select is(public.save_blocks(pg_temp.item('a001'), jsonb_build_array(
            pg_temp.b('e001', 'text', '{"text": "Pour from grid C7"}'),
            pg_temp.b('e002', 'photo', jsonb_build_object('path', pg_temp.post_path('a001', 'p1.jpg'))),
            pg_temp.b('e003', 'table', '{"rows": [["Grid", "Size"], ["C7 Quokkas", "150"]]}'),
            pg_temp.b('e004', 'toggle', jsonb_build_object('text', 'Why the sizes matter',
              'children', jsonb_build_array(pg_temp.b('e005', 'text', '{"text": "Sleeves first"}')))),
            pg_temp.b('e006', 'file', jsonb_build_object('library_file_id', pg_temp.item('f001')))),
          0, jsonb_build_array(jsonb_build_object('path', pg_temp.post_path('a001', 'p1.jpg')),
                               jsonb_build_object('library_file_id', pg_temp.item('f001')))),
  1, 'the author saves a page, with a new photo and a Library file');
select is(jsonb_array_length(public.post_page(pg_temp.item('a001')) -> 'blocks'), 5,
  'it opens with its blocks');
select is((select d.card ->> 'has_page' from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.id = pg_temp.item('a001')), 'true', 'and the slip knows it has a page');
reset role;
select is((select count(*) from public.post_edits where post_id = pg_temp.item('a001') and changes ? 'page'),
  1::bigint, 'the save is in the record');
select pg_temp.as_user('e3');
set local role authenticated;
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), '[]', 0)$$, '40001', null,
  'a save from an old version is refused, to reload');
select is(pg_temp.ver('a001'), 1, 'and changes nothing');
select pg_temp.as_user('e1');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), '[]', 1)$$, '42501', null,
  'a Space admin can''t save someone''s page');
select pg_temp.as_user('e2');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), '[]', 1)$$, '42501', null,
  'nor can the owner');
select pg_temp.as_user('e5');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), '[]', 1)$$, '42501', null,
  'nor a non-member');
select pg_temp.as_user('e3');

-- What a page may hold.
select throws_ok($$select public.save_blocks(pg_temp.item('a001'),
                    jsonb_build_array(pg_temp.b('e101', 'video')), 1)$$, '22023', null,
  'an unknown block is refused');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'),
                    (select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'text', 'text', 'x'))
                     from generate_series(1, 201)), 1)$$, '22023', null, 'more than 200 blocks');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'),
                    (select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'text',
                                                         'text', repeat('x', 800)))
                     from generate_series(1, 150)), 1)$$, '22023', null, 'more than 100 KB');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'),
                    jsonb_build_array(pg_temp.b('e102', 'text', '{"text": "a"}'),
                                      pg_temp.b('e102', 'text', '{"text": "b"}')), 1)$$, '22023', null,
  'a block id used twice');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'),
                    jsonb_build_array(pg_temp.b('e103', 'toggle', jsonb_build_object('text', 'Outer',
                      'children', jsonb_build_array(pg_temp.b('e104', 'toggle', '{"text": "Inner", "children": []}'))))), 1)$$,
  '22023', null, 'a toggle inside a toggle');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), jsonb_build_array(pg_temp.b('e105', 'table',
                    jsonb_build_object('rows', (select jsonb_agg(jsonb_build_array('a')) from generate_series(1, 21))))), 1)$$,
  '22023', null, 'a table of 21 rows');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), jsonb_build_array(pg_temp.b('e106', 'table',
                    jsonb_build_object('rows', jsonb_build_array(
                      (select jsonb_agg('c'::text) from generate_series(1, 9)))))), 1)$$,
  '22023', null, 'a table of 9 columns');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), jsonb_build_array(pg_temp.b('e107', 'table',
                    '{"rows": [["a", "b"], ["c"]]}')), 1)$$, '22023', null, 'rows of different widths');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), jsonb_build_array(pg_temp.b('e108', 'table',
                    '{"rows": [[1, {"a": 1}]]}')), 1)$$, '22023', null, 'a cell that isn''t text');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), jsonb_build_array(pg_temp.b('e109', 'photo',
                    jsonb_build_object('path', pg_temp.post_path('a002', 'p2.jpg')))), 1)$$, '22023', null,
  'a photo of another post');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), jsonb_build_array(pg_temp.b('e110', 'child_item',
                    jsonb_build_object('post_id', pg_temp.item('a002')))), 1)$$, '22023', null,
  'a work item that isn''t under this one');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), jsonb_build_array(pg_temp.b('e111', 'heading',
                    '{"key": "on_site"}')), 1)$$, '22023', null, 'a heading with no words (keys are for templates)');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), jsonb_build_array(pg_temp.b('e112', 'item_ref',
                    jsonb_build_object('post_id', pg_temp.item('a002')))), 1)$$, '22023', null,
  'a work item reference only in a report');
select lives_ok($$select public.save_blocks(pg_temp.item('a001'),
                    (select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'text', 'text', 'x'))
                     from generate_series(1, 200)), 1)$$, '200 blocks are fine');

-- References: points and work items under it; what the page shows stays.
select public.edit_space_post(pg_temp.item('a001'), jsonb_build_object('points', jsonb_build_object('add',
  jsonb_build_array(jsonb_build_object('id', pg_temp.item('b001'), 'text', 'Ties at 200')))));
select public.create_work_item(pg_temp.sp(), 'Sleeve C7', pg_temp.uid('e7'), p_id => pg_temp.item('a003'),
  p_parent => pg_temp.item('a001'));
select is(public.save_blocks(pg_temp.item('a001'), jsonb_build_array(
            pg_temp.b('e001', 'text', '{"text": "Pour from grid C7"}'),
            pg_temp.b('e002', 'photo', jsonb_build_object('path', pg_temp.post_path('a001', 'p1.jpg'))),
            pg_temp.b('e003', 'table', '{"rows": [["Grid", "Size"], ["C7 Quokkas", "150"]]}'),
            pg_temp.b('e006', 'file', jsonb_build_object('library_file_id', pg_temp.item('f001'))),
            pg_temp.b('e007', 'checklist_ref', jsonb_build_object('point_ids', jsonb_build_array(pg_temp.item('b001')))),
            pg_temp.b('e008', 'child_item', jsonb_build_object('post_id', pg_temp.item('a003')))), 2),
  3, 'a page shows its points and the work items under it');
select throws_ok(format($$select public.edit_space_post(pg_temp.item('a001'), '{"remove_files": [%s]}')$$,
                        to_jsonb((select id from public.post_files where storage_path = pg_temp.post_path('a001', 'p1.jpg')))),
  'P0001', null, 'a photo the page shows can''t be removed');
select throws_ok($$select public.edit_space_post(pg_temp.item('a001'), jsonb_build_object('points',
                    jsonb_build_object('remove', jsonb_build_array(pg_temp.item('b001')))))$$,
  'P0001', null, 'nor a point it shows');
select throws_ok($$select public.delete_library_file(pg_temp.item('f001'))$$, 'P0001', null,
  'nor a Library file it shows, from the Library');
select throws_ok($$update public.space_posts set blocks = '[]' where id = pg_temp.item('a001')$$, '42501', null,
  'pages change only through save_blocks');
reset role;
select is((select count(*) from public.notifications n
           join public.post_edits e on e.id = (n.payload ->> 'edit_id')::uuid
           where n.profile_id = pg_temp.uid('e2') and n.kind = 'item_edited'
             and n.work_item_id = pg_temp.item('a001') and e.changes ? 'page'), 1::bigint,
  'the owner hears of three page saves once (10 minutes), not each time');
select pg_temp.as_user('e2');
set local role authenticated;
select public.sign_done(pg_temp.item('a001'), 'Poured.');
select pg_temp.as_user('e3');
select throws_ok($$select public.save_blocks(pg_temp.item('a001'), '[]', 3)$$, 'P0001', null,
  'no page saves after Done');
select throws_ok($$select public.save_blocks(pg_temp.item('a002'), '[{"type": "text", "text": "x"}]', 0)$$,
  '22023', null, 'a block without its id is refused');
select throws_ok($$select public.save_blocks(pg_temp.item('a002'), jsonb_build_array(jsonb_build_object(
                    'id', upper(gen_random_uuid()::text), 'type', 'text', 'text', 'x')), 0)$$,
  '22023', null, 'ids are lower-case uuids');
select pg_temp.as_user('e1');
select public.create_work_item(pg_temp.sp(), 'Everyone parent', pg_temp.uid('e2'), p_id => pg_temp.item('a005'));
select public.create_work_item(pg_temp.sp(), 'Team child', pg_temp.uid('e6'), null, pg_temp.team(),
  p_id => pg_temp.item('a006'), p_parent => pg_temp.item('a005'));
select throws_ok($$select public.save_blocks(pg_temp.item('a005'), jsonb_build_array(pg_temp.b('e301', 'child_item',
                    jsonb_build_object('post_id', pg_temp.item('a006')))), 0)$$, '22023', null,
  'an Everyone page can''t show a Team''s work item (its readers would see its id)');
select public.create_work_item(pg_temp.sp(), 'Sent back slab', pg_temp.uid('e2'), p_id => pg_temp.item('a00a'));
select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('a00a'), 'Done.');
select pg_temp.as_user('e1');
select public.send_back(pg_temp.item('a00a'), 'not_finished');
select is(public.save_blocks(pg_temp.item('a00a'), jsonb_build_array(pg_temp.b('e302', 'text', '{"text": "Redo"}')), 0),
  1, 'after Send back the author saves the page again');
reset role;
update public.space_members set pass = 'viewer' where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e1');
select pg_temp.as_user('e3');
set local role authenticated;
select public.create_space_post(pg_temp.item('a00b'), pg_temp.sp(), 'announcement', 'Sara''s note');
reset role;
update public.space_members set pass = 'viewer' where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e3');
select pg_temp.as_user('e3');
set local role authenticated;
select throws_ok($$select public.save_blocks(pg_temp.item('a00b'), '[]', 0)$$, '42501', null,
  'an author lowered to Viewer can''t save the page');
reset role;
update public.space_members set pass = 'lead' where space_id = pg_temp.sp()
  and profile_id in (pg_temp.uid('e1'), pg_temp.uid('e3'));
select pg_temp.as_user('e3');
set local role authenticated;

-- Walk mode ----------------------------------------------------------------------------------------

reset role;
select pg_temp.upload('e3', pg_temp.post_path('6101', '1.jpg'));
select pg_temp.upload('e3', pg_temp.post_path('6102', '2.jpg'));
select pg_temp.upload('e3', pg_temp.post_path('6103', '3.jpg'));
select pg_temp.upload('e3', pg_temp.post_path('6111', '1.jpg'));
select pg_temp.upload('e3', pg_temp.post_path('6112', '2.jpg'));
create function pg_temp.walk(p_ids text[], p_owners text[]) returns jsonb language sql as $$
  select jsonb_agg(jsonb_build_object('id', pg_temp.item(i), 'line', 'Line ' || n, 'owner', pg_temp.uid(o),
                                      'photo', jsonb_build_object('path', pg_temp.post_path(i, n || '.jpg')))
                   order by n)
  from unnest(p_ids, p_owners) with ordinality u(i, o, n);
$$;
select pg_temp.as_user('e3');
set local role authenticated;
select is(public.create_walk(pg_temp.sp(), pg_temp.item('6100'), 'Walk, level 4',
            pg_temp.walk(array['6101', '6102', '6103'], array['e2', 'e2', 'e7']), 'Level 4'),
  pg_temp.item('6100'), 'a walk makes one parent');
select is((select count(*) from public.space_posts where parent_id = pg_temp.item('6100')), 3::bigint,
  'and a work item per photo');
select is((select d.card -> 'children' ->> 'total' from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.id = pg_temp.item('6100')), '3', 'the slip shows them');
select is((select jsonb_array_length(d.card -> 'children' -> 'rows') from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.id = pg_temp.item('6100')), 3, 'with their rows');
select ok((select bool_and(f.storage_path is not null) from public.space_posts p
           join public.post_files f on f.post_id = p.id where p.parent_id = pg_temp.item('6100')),
  'each with its photo');
select is(public.create_walk(pg_temp.sp(), pg_temp.item('6100'), 'Walk, level 4',
            pg_temp.walk(array['6101', '6102', '6103'], array['e2', 'e2', 'e7'])),
  pg_temp.item('6100'), 'sending the walk again makes nothing new');
select is((select count(*) from public.space_posts where parent_id = pg_temp.item('6100')), 3::bigint,
  'still three');
select is((select count(*) from public.needs_you() where work_item_id = pg_temp.item('6100')), 0::bigint,
  'the walk itself isn''t in its author''s Needs you');
select throws_ok($$select public.sign_done(pg_temp.item('6100'), 'All done')$$, 'P0001', null,
  'a walk isn''t signed as done: it is done when its work items are checked');
select pg_temp.as_user('e1');
select is((select count(*) from public.needs_you() where work_item_id = pg_temp.item('6100')), 0::bigint,
  'and nobody is asked to check it');
select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('6101'), 'Fixed.');
select public.sign_done(pg_temp.item('6102'), 'Fixed.');
select pg_temp.as_user('e7');
select public.sign_done(pg_temp.item('6103'), 'Fixed.');
select pg_temp.as_user('e3');
select public.check_item(pg_temp.item('6101'));
select public.check_item(pg_temp.item('6102'));
select public.check_item(pg_temp.item('6103'));
select is((select d.card -> 'children' ->> 'checked' from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.id = pg_temp.item('6100')), '3', 'its progress is its work items''');
select is((select status from public.work_items where id = pg_temp.item('6100')), 'open',
  'it takes no stamp of its own');
select is((select count(*) from public.my_delivered_work() w where w.work_item_id = pg_temp.item('6100')),
  0::bigint, 'and never counts as proof on a profile');
select throws_ok($$select public.create_walk(pg_temp.sp(), pg_temp.item('6110'), 'Bad walk',
                    pg_temp.walk(array['6111', '6112'], array['e2', 'e4']))$$, '22023', null,
  'a photo for a Viewer refuses the whole walk');
reset role;
select is((select count(*) from public.space_posts
           where id in (pg_temp.item('6110'), pg_temp.item('6111'), pg_temp.item('6112'))), 0::bigint,
  'and nothing of it is made');
select is((select count(*) from public.push_queue where kind = 'item_assigned'
           and profile_id = pg_temp.uid('e2') and data ->> 'work_item_id' = pg_temp.item('6100')::text),
  1::bigint, 'two photos for Rakesh: one push');
select is((select count(*) from public.push_queue where kind = 'item_assigned'
           and profile_id = pg_temp.uid('e2') and data ->> 'work_item_id' in (
             pg_temp.item('6101')::text, pg_temp.item('6102')::text)), 0::bigint,
  'not one per photo');
select is(pg_temp.n('e2', 'item_assigned', '6101') + pg_temp.n('e2', 'item_assigned', '6102'), 2::bigint,
  'each still in his Activity');
select pg_temp.as_user('e2');
set local role authenticated;
select throws_ok($$select public.create_walk(pg_temp.sp(), pg_temp.item('6100'), 'Mine',
                    pg_temp.walk(array['6121'], array['e2']))$$, '42501', null,
  'someone else''s walk id is refused');
select pg_temp.as_user('e4');
select throws_ok($$select public.create_walk(pg_temp.sp(), pg_temp.item('6130'), 'Viewer',
                    pg_temp.walk(array['6131'], array['e2']))$$, '42501', null, 'a Viewer doesn''t walk');
reset role;
select pg_temp.upload('e6', pg_temp.post_path('6141', '1.jpg'));
select pg_temp.as_user('e6');
set local role authenticated;
select public.create_walk(pg_temp.sp(), pg_temp.item('6140'), 'MEP walk', pg_temp.walk(array['6141'], array['e2']),
  null, pg_temp.team());
reset role;
select is((select data ->> 'work_item_id' from public.push_queue where kind = 'item_assigned'
           and profile_id = pg_temp.uid('e2') and data ->> 'work_item_id' in (
             pg_temp.item('6140')::text, pg_temp.item('6141')::text)), pg_temp.item('6141')::text,
  'an owner outside a Team walk gets one push, to the work item they can open');
select pg_temp.as_user('e3');
set local role authenticated;
select throws_ok(format($$select public.create_walk(pg_temp.sp(), pg_temp.item('6150'), 'Case',
                    jsonb_build_array(jsonb_build_object('id', %L, 'line', 'Same as the walk', 'owner', pg_temp.uid('e2'),
                      'photo', jsonb_build_object('path', pg_temp.post_path('6151', '1.jpg')))))$$,
                    upper(pg_temp.item('6150')::text)), '22023', null,
  'an item with the walk''s own id, in capitals, is refused');
select public.create_work_item(pg_temp.sp(), 'Signed early', pg_temp.uid('e3'), p_id => pg_temp.item('a007'));
select public.sign_done(pg_temp.item('a007'), 'Done early.');
select public.create_work_item(pg_temp.sp(), 'Added later', pg_temp.uid('e2'), p_id => pg_temp.item('a008'),
  p_parent => pg_temp.item('a007'));
select pg_temp.as_user('e1');
select throws_ok($$select public.check_item(pg_temp.item('a007'))$$, '42501', null,
  'a target signed before work went under it is never checked (no proof)');
select pg_temp.as_user('e4');

-- Meeting notes --------------------------------------------------------------------------------------

select pg_temp.as_user('e6');
select public.post_message(pg_temp.item('c201'), pg_temp.team_thread(), 'MEP meeting 10:00');
select lives_ok($$select public.create_from_message(pg_temp.sp(), pg_temp.item('c201'), pg_temp.item('9100'),
                    'MEP meeting', jsonb_build_array(
                      jsonb_build_object('id', pg_temp.item('9101'), 'text', 'Sleeves C7', 'owner', pg_temp.uid('e6')),
                      jsonb_build_object('id', pg_temp.item('9102'), 'text', 'Tray L2', 'owner', pg_temp.uid('e6'))))$$,
  'meeting notes from a chat message make work items');
reset role;
select is((select count(*) from public.space_posts
           where id in (pg_temp.item('9100'), pg_temp.item('9101'), pg_temp.item('9102'))
             and team_id = pg_temp.team() and source_message_id = pg_temp.item('c201')), 3::bigint,
  'a Team thread''s message keeps them in the Team, with the message');
select pg_temp.as_user('e6');
set local role authenticated;
select is(public.create_from_message(pg_temp.sp(), pg_temp.item('c201'), pg_temp.item('9100'), 'MEP meeting',
            '[]'), pg_temp.item('9100'), 'sending them again makes nothing new');
select pg_temp.as_user('e3');
select throws_ok($$select public.create_from_message(pg_temp.sp(), pg_temp.item('c201'), pg_temp.item('9110'),
                    'Not mine', jsonb_build_array(jsonb_build_object('id', pg_temp.item('9111'),
                      'text', 'x y', 'owner', pg_temp.uid('e2'))))$$, '42501', null,
  'not from a message the caller can''t read');
select pg_temp.as_user('e2');
select public.post_message(pg_temp.item('c202'), pg_temp.everyone(), 'Gate and hoarding');
select pg_temp.as_user('e3');
select public.report('message', pg_temp.item('c202'), 'spam');
select throws_ok($$select public.create_from_message(pg_temp.sp(), pg_temp.item('c202'), pg_temp.item('9120'),
                    'Reported', jsonb_build_array(jsonb_build_object('id', pg_temp.item('9121'),
                      'text', 'x y', 'owner', pg_temp.uid('e2'))))$$, '42501', null,
  'nor from one the caller reported');
select pg_temp.as_user('e2');
select public.post_message(pg_temp.item('c205'), pg_temp.everyone(), 'Coordination 10:00');
select throws_ok($$select public.create_from_message(pg_temp.sp(), pg_temp.item('c205'), pg_temp.item('9130'),
                    'Coordination', jsonb_build_array(
                      jsonb_build_object('id', pg_temp.item('9131'), 'text', 'Gate', 'owner', pg_temp.uid('e2')),
                      jsonb_build_object('id', pg_temp.item('9132'), 'text', 'Fence', 'owner', pg_temp.uid('e4'))))$$,
  '22023', null, 'a line for a Viewer refuses the whole meeting');
reset role;
select is((select count(*) from public.space_posts
           where id in (pg_temp.item('9130'), pg_temp.item('9131'), pg_temp.item('9132'))), 0::bigint,
  'and nothing of it is made');
select pg_temp.as_user('e3');
set local role authenticated;

-- Templates ----------------------------------------------------------------------------------------

select pg_temp.as_user('e5');
select is((select count(*) from public.post_templates where builtin_key = 'daily_report'), 1::bigint,
  'the Daily report is built in');
select is((select count(*) from public.post_templates where space_id is not null), 0::bigint,
  'a non-member reads no Space''s templates');
select throws_ok($$insert into public.post_templates (id, space_id, kind, name)
                   values (gen_random_uuid(), pg_temp.sp(), 'report', 'x')$$, '42501', null,
  'and can''t write one');
select pg_temp.as_user('e3');
select lives_ok($$select public.save_template(pg_temp.item('7001'), pg_temp.sp(), pg_temp.item('a001'), 'Pour check')$$,
  'a Lead saves a post as a template');
select ok((select not exists (select 1 from jsonb_array_elements(blocks) b
                              where b ->> 'type' in ('photo', 'file', 'checklist_ref', 'child_item'))
                  and fields -> 'points' = '["Ties at 200"]'::jsonb
           from public.post_templates where id = pg_temp.item('7001')),
  'with its words only: no photos, files or work items; the points as text');
select is(public.save_template(pg_temp.item('7001'), pg_temp.sp(), pg_temp.item('a001'), 'Pour check'),
  pg_temp.item('7001'), 'saving it again makes no second one');
select pg_temp.as_user('e2');
select throws_ok($$select public.save_template(pg_temp.item('7002'), pg_temp.sp(), pg_temp.item('a001'), 'x')$$,
  '42501', null, 'Crew can''t save a template');
select is((select count(*) from public.space_templates(pg_temp.sp()) where id = pg_temp.item('7001')), 1::bigint,
  'but uses it');
select pg_temp.as_user('e1');
select lives_ok($$select public.save_template(pg_temp.item('7003'), pg_temp.sp(), pg_temp.item('9100'), 'MEP meeting')$$,
  'a template from a Team post');
select is((select count(*) from public.space_templates(current_setting('test.space2')::uuid)
           where id = pg_temp.item('7001')), 0::bigint, 'another Space doesn''t see this Space''s templates');
select pg_temp.as_user('e2');
select is((select count(*) from public.post_templates where id = pg_temp.item('7003')), 0::bigint,
  'a Team''s template stays in the Team');
select is((select count(*) from public.space_templates(pg_temp.sp()) where id = pg_temp.item('7003')), 0::bigint,
  'also through space_templates');
select pg_temp.as_user('e3');
select throws_ok($$select public.save_template(pg_temp.item('7202'), pg_temp.sp(), pg_temp.item('9100'), 'x')$$,
  '42501', null, 'a Lead outside the Team can''t save its post as a template');
select pg_temp.as_user('e5');
select is((select count(*) from public.post_templates where id in (pg_temp.item('7001'), pg_temp.item('7003'))),
  0::bigint, 'a non-member reads none of the Space''s templates');
select is((select count(*) from public.space_templates(pg_temp.sp())), 0::bigint, 'nor lists them');
select throws_ok($$select public.delete_template(pg_temp.item('7001'))$$, '42501', null, 'nor deletes one');
select throws_ok($$select public.save_template(pg_temp.item('7203'), pg_temp.sp(), pg_temp.item('a001'), 'x')$$,
  '42501', null, 'nor saves one');
select throws_ok($$delete from public.post_templates where id = pg_temp.item('7001')$$, '42501', null,
  'nor writes the table');
select pg_temp.as_user('e1');
select public.create_space_post(pg_temp.item('8101'), current_setting('test.space2')::uuid, 'report', 'Other report');
select public.save_template(pg_temp.item('7101'), current_setting('test.space2')::uuid, pg_temp.item('8101'), 'Other');
select throws_ok($$select public.create_space_post(pg_temp.item('8102'), pg_temp.sp(), 'report', 'x',
                    p_template => pg_temp.item('7101'))$$, '42501', null,
  'a template of another Space can''t be used here');
select throws_ok($$select public.create_work_item(pg_temp.sp(), 'Everyone from Team', pg_temp.uid('e2'),
                    p_id => pg_temp.item('8103'), p_template => pg_temp.item('7003'))$$, '22023', null,
  'a Team''s template only for that Team''s posts');
select pg_temp.as_user('e2');
select throws_ok($$select public.delete_template(pg_temp.item('7001'))$$, '42501', null,
  'Crew can''t delete a template');
select pg_temp.as_user('e1');
select throws_ok($$select public.delete_template('00000000-0000-4000-8000-0000000d0001')$$, '42501', null,
  'nobody deletes a built-in');
select pg_temp.as_user('e3');
select lives_ok($$select public.delete_template(pg_temp.item('7001'))$$, 'a Lead deletes one');
select pg_temp.as_user('e2');
select is((select count(*) from public.post_templates where id = pg_temp.item('7001')), 0::bigint,
  'and it is gone');
select pg_temp.as_user('e3');
select public.save_template(pg_temp.item('7004'), pg_temp.sp(), pg_temp.item('a002'), 'Slab check');
select pg_temp.as_user('e2');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Slab check, B2', pg_temp.uid('e7'),
                    p_id => pg_temp.item('a00c'), p_template => pg_temp.item('7004'),
                    p_points => jsonb_build_array(jsonb_build_object('text', 'Cover blocks')),
                    p_blocks => jsonb_build_array(pg_temp.b('e303', 'text', '{"text": "As the template"}')))$$,
  'a work item is raised from a work item template, with its points and page');
select is((select template_id::text || ' ' || jsonb_array_length(blocks) from public.space_posts
           where id = pg_temp.item('a00c')), pg_temp.item('7004')::text || ' 1', 'recording the template');
select is((select count(*) from public.checklist_points where post_id = pg_temp.item('a00c')), 1::bigint,
  'and its points');

-- The daily report ------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
select public.create_work_item(pg_temp.sp(), 'Gate cleared', pg_temp.uid('e2'), p_id => pg_temp.item('d101'));
select public.create_work_item(pg_temp.sp(), 'MEP sleeves in', pg_temp.uid('e6'), null, pg_temp.team(),
  p_id => pg_temp.item('d102'));
select public.create_work_item(pg_temp.sp(), 'Yesterday''s work', pg_temp.uid('e2'), p_id => pg_temp.item('d103'));
reset role;
select pg_temp.upload('e2', pg_temp.ev_path('d101', 'done.jpg'));
select pg_temp.as_user('e2');
set local role authenticated;
select public.sign_done(pg_temp.item('d101'), null,
  jsonb_build_array(jsonb_build_object('path', pg_temp.ev_path('d101', 'done.jpg'))));
select public.sign_done(pg_temp.item('d103'), 'Done.');
select pg_temp.as_user('e6');
select public.sign_done(pg_temp.item('d102'), 'Done.');
select pg_temp.as_user('e1');
select public.check_item(pg_temp.item('d101'));
select public.check_item(pg_temp.item('d102'));
select public.check_item(pg_temp.item('d103'));
reset role;
update public.work_items set checked_at = now() - interval '1 day' where id = pg_temp.item('d103');
select pg_temp.as_user('e2');
set local role authenticated;
select is((select array_agg(f.post_id) from public.daily_report_fill(pg_temp.sp(), null,
             date_trunc('day', now()), date_trunc('day', now()) + interval '1 day') f
           where f.post_id in (pg_temp.item('d101'), pg_temp.item('d102'), pg_temp.item('d103'))),
  array[pg_temp.item('d101')], 'today''s checked work for the report');
select is((select f.done_photo_path from public.daily_report_fill(pg_temp.sp(), null,
             date_trunc('day', now()), date_trunc('day', now()) + interval '1 day') f
           where f.post_id = pg_temp.item('d101')),
  pg_temp.ev_path('d101', 'done.jpg'), 'with its Done photo');
select pg_temp.as_user('e1');
select is((select count(*) from public.daily_report_fill(pg_temp.sp(), null,
             date_trunc('day', now()), date_trunc('day', now()) + interval '1 day') f
           where f.post_id = pg_temp.item('d102')), 0::bigint,
  'an Everyone report never brings in a Team''s work, even for an admin');
select is((select count(*) from public.daily_report_fill(pg_temp.sp(), pg_temp.team(),
             date_trunc('day', now()), date_trunc('day', now()) + interval '1 day') f
           where f.post_id in (pg_temp.item('d101'), pg_temp.item('d102'), pg_temp.item('d103'))), 2::bigint,
  'a Team report does');
select pg_temp.as_user('e2');
select is((select count(*) from public.daily_report_fill(pg_temp.sp(), pg_temp.team(),
             date_trunc('day', now()), date_trunc('day', now()) + interval '1 day') f
           where f.post_id = pg_temp.item('d102')), 0::bigint,
  'naming a Team doesn''t show its work to someone outside it');
select pg_temp.as_user('e5');
select is((select count(*) from public.daily_report_fill(pg_temp.sp(), null,
             date_trunc('day', now()), date_trunc('day', now()) + interval '1 day')), 0::bigint,
  'a non-member gets nothing');
select pg_temp.as_user('e1');
select throws_ok($$select * from public.daily_report_fill(pg_temp.sp(), null, now(), now() + interval '2 days')$$,
  '22023', null, 'one day at a time');
select pg_temp.as_user('e2');
select lives_ok($$select public.create_space_post(pg_temp.item('8001'), pg_temp.sp(), 'report', 'Thursday 15 October',
                    p_template => '00000000-0000-4000-8000-0000000d0001',
                    p_blocks => jsonb_build_array(
                      pg_temp.b('e201', 'heading', '{"text": "Done today"}'),
                      pg_temp.b('e202', 'item_ref', jsonb_build_object('post_id', pg_temp.item('d101')))))$$,
  'Crew posts a daily report from the built-in, with today''s work');
select is((select template_id from public.space_posts where id = pg_temp.item('8001')),
  '00000000-0000-4000-8000-0000000d0001'::uuid, 'it records the template');
select throws_ok($$select public.create_space_post(pg_temp.item('8002'), pg_temp.sp(), 'announcement', 'x',
                    p_template => '00000000-0000-4000-8000-0000000d0001')$$, '22023', null,
  'a template only for its own kind of post');
select pg_temp.as_user('e1');
select throws_ok($$select public.create_space_post(pg_temp.item('8003'), pg_temp.sp(), 'report', 'Friday',
                    p_blocks => jsonb_build_array(pg_temp.b('e203', 'item_ref',
                      jsonb_build_object('post_id', pg_temp.item('d102')))))$$, '22023', null,
  'an Everyone report can''t show a Team''s work');
select pg_temp.as_user('e7');
select ok(public.post_page(pg_temp.item('8001')) -> 'refs' ? pg_temp.item('d101')::text,
  'readers see the work it shows, as they may read it');
select pg_temp.as_user('e1');
select public.create_work_item(pg_temp.sp(), 'Soon gone', pg_temp.uid('e1'), p_id => pg_temp.item('a009'));
select pg_temp.as_user('e2');
select public.create_space_post(pg_temp.item('8005'), pg_temp.sp(), 'report', 'Friday report',
  p_blocks => jsonb_build_array(pg_temp.b('e304', 'item_ref', jsonb_build_object('post_id', pg_temp.item('a009')))));
select pg_temp.as_user('e1');
select public.delete_space_post(pg_temp.item('a009'));
select pg_temp.as_user('e2');
select is(public.save_blocks(pg_temp.item('8005'), jsonb_build_array(
            pg_temp.b('e304', 'item_ref', jsonb_build_object('post_id', pg_temp.item('a009'))),
            pg_temp.b('e305', 'text', '{"text": "Typo fixed"}')), 0), 1,
  'a report still saves after a work item it shows was deleted');
select is(public.post_page(pg_temp.item('8005')) -> 'refs', null, 'and readers no longer see it');
select pg_temp.as_user('e4');
select throws_ok($$select public.create_space_post(pg_temp.item('8004'), pg_temp.sp(), 'report', 'Viewer')$$,
  '42501', null, 'a Viewer doesn''t post a report');

-- The week report ------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
select public.create_work_item(pg_temp.sp(), 'Late one', pg_temp.uid('e2'), current_date - 2,
  p_id => pg_temp.item('6201'));
select public.create_work_item(pg_temp.sp(), 'Team late one', pg_temp.uid('e6'), current_date - 2,
  pg_temp.team(), p_id => pg_temp.item('6202'));
select public.create_space_post(pg_temp.item('6203'), pg_temp.sp(), 'activity', 'Next week walk',
  p_starts_at => date_trunc('day', now()) + interval '5 days 9 hours');
select public.create_space_post(pg_temp.item('6204'), pg_temp.sp(), 'activity', 'In an hour',
  p_starts_at => now() + interval '1 hour');
select pg_temp.as_user('e2');
create function pg_temp.week() returns jsonb language sql as $$
  select public.week_report(pg_temp.sp(), current_date, date_trunc('day', now()) - interval '3 days',
                            date_trunc('day', now()) + interval '4 days');
$$;
select ok(pg_temp.week() ?& array['needs_decision', 'checked', 'targets', 'coming_up'],
  'the week report has its four parts');
select ok(pg_temp.week() -> 'needs_decision' @> jsonb_build_array(jsonb_build_object(
            'post_id', pg_temp.item('6201'), 'state', 'late')),
  'late work needs a decision');
select ok(pg_temp.week() -> 'needs_decision' @> jsonb_build_array(jsonb_build_object(
            'post_id', pg_temp.item('a001'), 'state', 'done')),
  'and work waiting for a check');
select ok(pg_temp.week() -> 'checked' @> jsonb_build_array(jsonb_build_object(
            'post_id', pg_temp.item('d101'), 'done_photo_path', pg_temp.ev_path('d101', 'done.jpg'))),
  'what was checked, with its photo');
select ok(not (pg_temp.week() -> 'targets' @> jsonb_build_array(jsonb_build_object(
            'post_id', pg_temp.item('6100')))),
  'a target whose work items are all checked leaves the targets');
select ok(not (pg_temp.week() -> 'needs_decision' @> jsonb_build_array(jsonb_build_object(
            'post_id', pg_temp.item('6100')))),
  'and a target never needs a decision');
select ok(pg_temp.week() -> 'coming_up' @> jsonb_build_array(jsonb_build_object(
            'post_id', pg_temp.item('6203'))), 'and what is coming up');
select ok(pg_temp.week() -> 'coming_up' @> jsonb_build_array(jsonb_build_object(
            'post_id', pg_temp.item('6204'))), 'an activity later this week is coming up too');
select ok(not (pg_temp.week()::text ~ (pg_temp.item('6202')::text || '|' || pg_temp.item('d102')::text
                                          || '|' || pg_temp.item('9100')::text)),
  'nothing of a Team the reader isn''t in: late, checked or target');
select ok(not (pg_temp.week()::text ~ '"(count|counts|score|per_person)"'), 'and no per-person totals');
select pg_temp.as_user('e1');
select ok(pg_temp.week()::text like '%' || pg_temp.item('6202') || '%', 'an admin sees the Team''s work');
select ok(pg_temp.week() -> 'targets' @> jsonb_build_array(jsonb_build_object(
            'post_id', pg_temp.item('9100'), 'children', jsonb_build_object('total', 2, 'checked', 0))),
  'a target still open shows its progress');
select throws_ok($$select public.week_report(pg_temp.sp(), current_date, now(), now() + interval '8 days')$$,
  '22023', null, 'a week at a time');
select pg_temp.as_user('e5');
select is(pg_temp.week(), null, 'a non-member gets nothing');

-- Sharing the week report ------------------------------------------------------------------------------

select pg_temp.as_user('e2');
select lives_ok($$select public.share_week_report(pg_temp.item('5001'), pg_temp.everyone(), current_date - 3)$$,
  'a member shares the week report in chat');
reset role;
select is((select kind || ' ' || report_week from public.messages where id = pg_temp.item('5001')),
  'report ' || (current_date - 3), 'as a report message for that week');
select pg_temp.as_user('e2');
set local role authenticated;
select is(public.share_week_report(pg_temp.item('5001'), pg_temp.everyone(), current_date - 3),
  pg_temp.item('5001'), 'sharing it again posts once');
select throws_ok($$select public.share_week_report(pg_temp.item('5002'), pg_temp.team_thread(), current_date)$$,
  '42501', null, 'not in a Team thread the caller isn''t in');
select pg_temp.as_user('e5');
select throws_ok($$select public.share_week_report(pg_temp.item('5003'), pg_temp.everyone(), current_date)$$,
  '42501', null, 'nor by a non-member');
select pg_temp.as_user('e2');
select throws_ok($$insert into public.messages (id, thread_id, space_id, author_id, kind, report_week)
                   values (gen_random_uuid(), pg_temp.everyone(), pg_temp.sp(), auth.uid(), 'report', current_date)$$,
  '42501', null, 'report messages only through share_week_report');

-- Search -------------------------------------------------------------------------------------------

select pg_temp.as_user('e2');
select public.create_space_post(pg_temp.item('4001'), pg_temp.sp(), 'announcement', 'Zebra crossing at gate 2');
select public.post_message(pg_temp.item('c301'), pg_temp.everyone(), 'The zebra gate is open');
select public.post_message(pg_temp.item('c303'), pg_temp.everyone(), 'Zebra typo');
select public.delete_message(pg_temp.item('c303'));
select pg_temp.as_user('e3');
select public.create_space_post(pg_temp.item('4003'), pg_temp.sp(), 'checklist', 'Before the walk',
  p_people => array[pg_temp.uid('e2')],
  p_points => jsonb_build_array(jsonb_build_object('id', pg_temp.item('b301'), 'text', 'Paint the zebra lines')));
select public.create_space_post(pg_temp.item('4004'), pg_temp.sp(), 'announcement', 'الأعمدة مسئولية المقاول');
select pg_temp.as_user('e6');
select public.create_space_post(pg_temp.item('4002'), pg_temp.sp(), 'announcement', 'Zebra MEP',
  p_team => pg_temp.team());
select public.post_message(pg_temp.item('c302'), pg_temp.team_thread(), 'Zebra tray');
select public.create_space_post(pg_temp.item('4901'), pg_temp.sp(), 'checklist', 'MEP list',
  p_team => pg_temp.team(), p_people => array[pg_temp.uid('e6')],
  p_points => jsonb_build_array(jsonb_build_object('id', pg_temp.item('b901'), 'text', 'Zebra point MEP')));
select public.create_space_post(pg_temp.item('4902'), pg_temp.sp(), 'announcement', 'Pour',
  p_body => E'Pour\nslab B2 tomorrow');
select pg_temp.as_user('e2');
select ok(pg_temp.hits('zebra') @> array[pg_temp.item('4001'), pg_temp.item('b301'), pg_temp.item('c301'),
                                         pg_temp.item('f001')],
  'search finds posts, points, chat and files, any case');
select ok(not (pg_temp.hits('zebra') && array[pg_temp.item('4002'), pg_temp.item('c302'), pg_temp.item('f002'),
                                         pg_temp.item('b901')]),
  'never a Team''s post, chat or file for someone outside the Team');
select ok(not (pg_temp.hits('zebra') && array[pg_temp.item('c303')]), 'nor a deleted message');
select ok(pg_temp.hits('quokkas') @> array[pg_temp.item('a001')], 'words in a page''s table are found');
select ok(pg_temp.hits('pour slab') @> array[pg_temp.item('4902')], 'across a line break');
select ok(public.search_snippet(repeat('بَِ', 150) || ' target here', 'target') like '%target%',
  'the snippet holds the match, harakat or not');
select ok(pg_temp.hits('الاعمده') @> array[pg_temp.item('4004')], 'Arabic letter forms fold (الأعمدة)');
select ok(pg_temp.hits('مسؤوليه') @> array[pg_temp.item('4004')], 'and hamza and ta marbuta (مسئولية)');
select is(cardinality(pg_temp.hits('z')), 0, 'one letter finds nothing');
select is(cardinality(pg_temp.hits('%_')), 0, '% and _ are taken as they are');
select throws_ok($$select * from public.search_space(pg_temp.sp(), repeat('a', 101))$$, '22023', null,
  'at most 100 characters');
select pg_temp.as_user('e6');
select ok(pg_temp.hits('zebra') @> array[pg_temp.item('4002'), pg_temp.item('c302'), pg_temp.item('f002')],
  'the Team finds its own');
select pg_temp.as_user('e3');
select ok(not (pg_temp.hits('gate and hoarding') && array[pg_temp.item('c202')]),
  'a message the caller reported isn''t found');
select pg_temp.as_user('e5');
select is(cardinality(pg_temp.hits('zebra')), 0, 'a non-member finds nothing');
reset role;
insert into public.space_posts (id, space_id, kind, author_id, title, created_at)
select gen_random_uuid(), pg_temp.sp(), 'announcement', pg_temp.uid('e2'), 'Quail ' || g,
       now() - make_interval(mins => g)
from generate_series(1, 31) g;
select pg_temp.as_user('e2');
set local role authenticated;
select is((select count(*) from public.search_space(pg_temp.sp(), 'quail')), 30::bigint, '30 results at most');
select is((select s.title from public.search_space(pg_temp.sp(), 'quail') s limit 1), 'Quail 1', 'newest first');

-- Direct writes ------------------------------------------------------------------------------------

select pg_temp.as_user('e3');
select throws_ok($$update public.space_posts set blocks_version = 9 where id = pg_temp.item('a001')$$,
  '42501', null, 'nobody sets a page version directly');
select throws_ok($$update public.post_templates set name = 'x'$$, '42501', null,
  'or changes a template directly');

select * from finish();
rollback;
