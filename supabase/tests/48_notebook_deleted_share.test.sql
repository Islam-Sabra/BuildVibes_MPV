-- Migration 48 (review 99B, review 100 Parts 3b, 6, 8): Deleted items and
-- their purge, Archive, Share (Space, feed, message), the Filter, and a
-- base version on save_note. Run with: supabase test db
--
-- Omar (a1) owns the notebook and made "Share site"; Rakesh (b2) is Crew
-- there and is someone else; Eve (c3) is blocked by Omar.

begin;
create extension if not exists pgtap with schema extensions;
select plan(156);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000048' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@deleted48.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('a1', 'Omar', 'Haddad'), ('b2', 'Rakesh', 'Nair'), ('c3', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000048' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000048' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000048' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000048' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
-- A line of [p_type] with id [p_id] and words [p_text].
create function pg_temp.b(p_id text, p_type text, p_text text, p_extra jsonb default '{}')
returns jsonb language sql as $$
  select jsonb_build_object('id', p_id, 'type', p_type, 'text', p_text) || p_extra;
$$;
-- The ids search_notebook gives the caller, as text, sorted.
create function pg_temp.found(p_q text, p_kind text default null, p_page uuid default null)
returns text[] language sql as $$
  select coalesce(array_agg(coalesce(s.note_id, s.page_id)::text
                            order by coalesce(s.note_id, s.page_id)::text), '{}')
  from public.search_notebook(p_q, p_kind, p_page) s;
$$;
-- The day's rows of My calendar for the caller: their note ids.
create function pg_temp.calendar() returns uuid[] language sql as $$
  select coalesce(array_agg(c.note_id), '{}') from public.my_calendar(
    current_date - 2, current_date + 2, now() - interval '2 days', now() + interval '2 days') c
  where c.note_id is not null;
$$;

-- Setup -------------------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Share site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp(), pg_temp.uid('b2'), 'crew', pg_temp.uid('a1'));
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('a1'), pg_temp.uid('c3'));
select pg_temp.as_user('a1');
set local role authenticated;

select lives_ok($$select public.create_notebook_page(pg_temp.id('e001'), 'Site A – Tower')$$, 'Site A');
select lives_ok($$select public.create_notebook_page(pg_temp.id('e002'), 'Level 3', pg_temp.id('e001'))$$,
  'Level 3 in it');
select lives_ok($$select public.create_notebook_page(pg_temp.id('e003'), 'موقع ٢٣')$$, 'an Arabic page');

select is(public.save_entry(p_id => pg_temp.id('b001'), p_kind => 'text', p_page => pg_temp.id('e001'),
  p_title => 'Before the pour', p_due_at => now() + interval '1 hour',
  p_blocks => jsonb_build_array(
    pg_temp.b('c0000000-0000-4000-8000-000000000a01', 'todo', 'Clean the formwork'),
    pg_temp.b('c0000000-0000-4000-8000-000000000a02', 'todo', 'Check the cover', '{"done": true}'),
    pg_temp.b('c0000000-0000-4000-8000-000000000a03', 'numbered', 'Pump at 7'),
    pg_temp.b('c0000000-0000-4000-8000-000000000a04', 'bullet', 'Spacers', '{"indent": 1}')),
  p_location => '{"text": "Gate 2", "lat": 29.3759, "lng": 47.9774, "accuracy_m": 8}'),
  pg_temp.id('b001'), 'an entry with to-dos, a date and a location');
select is(public.save_entry(p_id => pg_temp.id('b002'), p_kind => 'text', p_page => pg_temp.id('e002'),
  p_title => 'Rebar', p_blocks => jsonb_build_array(pg_temp.b('c0000000-0000-4000-8000-000000000b01', 'text', 'Spacers at the beams')),
  p_remind_at => now() + interval '1 day'),
  pg_temp.id('b002'), 'an entry in Level 3, with a reminder');
select is(public.save_entry(p_id => pg_temp.id('b003'), p_kind => 'text', p_page => pg_temp.id('e003'),
  p_title => 'الصب', p_blocks => jsonb_build_array(pg_temp.b('c0000000-0000-4000-8000-000000000c01', 'text', 'غطاء الحديد ٥٠ مم'),
                                                   pg_temp.b('c0000000-0000-4000-8000-000000000c02', 'todo', 'إبلاغ الحارس'))),
  pg_temp.id('b003'), 'an Arabic entry');

-- Grants ------------------------------------------------------------------------------------------

select ok(not has_function_privilege('anon', 'public.restore_items(uuid[])', 'execute'),
  'signed out: no Restore');
select ok(not has_function_privilege('anon', 'public.share_note_to_feed(uuid, uuid, text, text[], uuid, boolean, jsonb)', 'execute'),
  'signed out: no Share');
select ok(not has_function_privilege('authenticated', 'public.purge_notebook()', 'execute'),
  'nobody signed in runs the purge');
select ok(has_function_privilege('service_role', 'public.purge_notebook()', 'execute'),
  'the scheduled job does');

-- Keep deleted items for ---------------------------------------------------------------------------

select is((select notebook_keep_days from public.profile_private where id = pg_temp.uid('a1')),
  30::smallint, '30 days by default');
select lives_ok($$select public.set_notebook_keep_days(7)$$, '7 days');
select is((select notebook_keep_days from public.profile_private where id = pg_temp.uid('a1')),
  7::smallint, 'kept');
select throws_ok($$select public.set_notebook_keep_days(45)$$, '22023', null, '7, 30 or 90 only');
select lives_ok($$select public.set_notebook_keep_days(30)$$, 'back to 30');

-- Delete and Restore an entry ---------------------------------------------------------------------

select lives_ok($$select public.delete_entries(array[pg_temp.id('b001')])$$, 'an entry deleted');
select ok((select deleted_at is not null from public.notes where id = pg_temp.id('b001')),
  'it is in Deleted items');
select lives_ok($$select public.delete_entries(array[pg_temp.id('b001')])$$, 'deleted again: skipped');
select is(pg_temp.found('pour'), '{}', 'search doesn''t find it');
select is(pg_temp.found('', 'todos_open'), array[pg_temp.id('b003')::text],
  'nor the Filter');
select ok(not (pg_temp.id('b001') = any (pg_temp.calendar())), 'nor My calendar');
select is((select kind || '/' || title || '/' || page_title from public.my_deleted_items()
           where id = pg_temp.id('b001')),
  'entry/Before the pour/Site A – Tower', 'Deleted items shows it, its page and title');
select ok((select purge_at = deleted_at + interval '30 days' from public.my_deleted_items()
           where id = pg_temp.id('b001')), 'and when it goes for good');
select is(public.save_entry(p_id => pg_temp.id('b001'), p_kind => 'text', p_body => 'x'), null,
  'a deleted entry isn''t saved: it stays in Deleted items');

select lives_ok($$select public.restore_items(array[pg_temp.id('b001')])$$, 'Restore');
select ok((select deleted_at is null and page_id = pg_temp.id('e001') from public.notes
           where id = pg_temp.id('b001')), 'back in its page');
select is(pg_temp.found('pour'), array[pg_temp.id('b001')::text], 'found again');
select ok(pg_temp.id('b001') = any (pg_temp.calendar()), 'on My calendar again');

-- Restore when its page is gone: a new page with the old title
select lives_ok($$select public.delete_entries(array[pg_temp.id('b002')])$$, 'Rebar deleted');
select lives_ok($$select public.delete_notebook_pages(array[pg_temp.id('e002')])$$, 'then its page');
select lives_ok($$select public.restore_items(array[pg_temp.id('b002')])$$, 'Rebar restored');
select ok((select n.page_id <> pg_temp.id('e002') and p.title = 'Level 3' and p.deleted_at is null
           from public.notes n join public.notebook_pages p on p.id = n.page_id
           where n.id = pg_temp.id('b002')), 'into a new page named as its old one');

-- A line group ------------------------------------------------------------------------------------

select is(public.delete_note_lines(pg_temp.id('b001'), array['c0000000-0000-4000-8000-000000000a03', 'c0000000-0000-4000-8000-000000000a04'], pg_temp.id('b0f1')),
  pg_temp.id('b0f1'), 'a line with the line under it deleted');
select is((select array_agg(b ->> 'id') from public.notes n, jsonb_array_elements(n.blocks) b
           where n.id = pg_temp.id('b001')), array['c0000000-0000-4000-8000-000000000a01', 'c0000000-0000-4000-8000-000000000a02'], 'they leave the entry');
select is((select kind || '/' || page_title from public.my_deleted_items()
           where id = pg_temp.id('b0f1')), 'part/Site A – Tower', 'Deleted items: part of an entry');
select is((select (blocks -> 1 ->> 'indent')::int from public.notes where id = pg_temp.id('b0f1')),
  1, 'with its levels');
select is(public.delete_note_lines(pg_temp.id('b001'), array['c0000000-0000-4000-8000-000000000a03', 'c0000000-0000-4000-8000-000000000a04'], pg_temp.id('b0f1')),
  pg_temp.id('b0f1'), 'sent again: the same part');
select throws_ok($$select public.delete_note_lines(pg_temp.id('b001'), array['c0000000-0000-4000-8000-000000000e99'], pg_temp.id('b0f2'))$$,
  '22023', null, 'a line that isn''t in the entry');
select lives_ok($$select public.restore_items(array[pg_temp.id('b0f1')])$$, 'the part restored');
select ok((select deleted_at is null and page_id = pg_temp.id('e001') from public.notes
           where id = pg_temp.id('b0f1')), 'an entry of its own in the page');

-- A page with everything inside -------------------------------------------------------------------

select lives_ok($$select public.create_notebook_page(pg_temp.id('e004'), 'Pour day', pg_temp.id('e001'))$$,
  'a sub-page');
select is(public.save_entry(p_id => pg_temp.id('b004'), p_kind => 'text', p_page => pg_temp.id('e004'),
  p_body => 'Pump booked'), pg_temp.id('b004'), 'with an entry');
select lives_ok($$select public.delete_notebook_pages(array[pg_temp.id('e001')])$$, 'Site A deleted');
select is((select count(*)::int from public.my_deleted_items() where id = pg_temp.id('e001')), 1,
  'Deleted items: the page once');
select is((select count(*)::int from public.my_deleted_items() where id = pg_temp.id('e004')), 0,
  'not its sub-page on its own');
select is(pg_temp.found('booked'), '{}', 'nothing in it shows in search');
select lives_ok($$select public.restore_items(array[pg_temp.id('e001')])$$, 'the page restored');
select is((select count(*)::int from public.notebook_pages
           where id in (pg_temp.id('e001'), pg_temp.id('e004')) and deleted_at is null), 2,
  'with its sub-page');
select is(pg_temp.found('booked'), array[pg_temp.id('b004')::text], 'and its entries');

-- Delete forever, Empty now -----------------------------------------------------------------------

select lives_ok($$select public.delete_entries(array[pg_temp.id('b004')])$$, 'an entry deleted');
select lives_ok($$select * from public.delete_forever(array[pg_temp.id('b004')])$$, 'then for good');
select is((select count(*)::int from public.notes where id = pg_temp.id('b004')), 0, 'gone');
reset role;
select ok(exists (select 1 from public.deleted_notes where id = pg_temp.id('b004')),
  'a late save can''t bring it back');
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select * from public.delete_forever(array[pg_temp.id('b001')])$$, '22023', null,
  'only what is in Deleted items');
select lives_ok($$select public.delete_notebook_pages(array[pg_temp.id('e004')])$$, 'a page deleted');
select is(public.save_entry(p_id => pg_temp.id('b005'), p_kind => 'text', p_page => pg_temp.id('e003'),
  p_body => 'Kept'), pg_temp.id('b005'), 'another entry, not deleted');
select lives_ok($$select public.delete_entries(array[pg_temp.id('b005')])$$, 'then deleted');
select lives_ok($$select * from public.empty_deleted_items()$$, 'Empty now');
select is((select count(*)::int from public.my_deleted_items()), 0, 'Deleted items is empty');
select is((select count(*)::int from public.notebook_pages where id = pg_temp.id('e004')), 0,
  'the page is gone');
select ok((select count(*) from public.notes where id in (pg_temp.id('b001'), pg_temp.id('b003'))) = 2,
  'what wasn''t deleted stays');

-- Archive -----------------------------------------------------------------------------------------

select lives_ok($$select public.archive_note(pg_temp.id('b001'))$$, 'an entry archived');
select is(pg_temp.found('pour'), '{}', 'search leaves it out');
select is(pg_temp.found('', 'archived'), array[pg_temp.id('b001')::text], 'the Filter''s Archived has it');
select is(pg_temp.found('pour', 'archived'), array[pg_temp.id('b001')::text], 'with words too');
select ok(not (pg_temp.id('b001') = any (pg_temp.calendar())), 'off My calendar');
select lives_ok($$select public.unarchive_note(pg_temp.id('b001'))$$, 'unarchived');
select is(pg_temp.found('pour'), array[pg_temp.id('b001')::text], 'back');
select lives_ok($$select public.delete_entries(array[pg_temp.id('b0f1')])$$, 'an entry deleted');
select throws_ok($$select public.archive_note(pg_temp.id('b0f1'))$$, '42501', null,
  'a deleted entry isn''t archived');
select lives_ok($$select public.restore_items(array[pg_temp.id('b0f1')])$$, 'restored');

-- The Filter (search_notebook's kind and page) ----------------------------------------------------

reset role;
insert into public.note_files (note_id, storage_path, kind, mime)
values (pg_temp.id('b001'), pg_temp.uid('a1') || '/' || pg_temp.id('b001') || '/p.jpg', 'photo', 'image/jpeg'),
       (pg_temp.id('b003'), pg_temp.uid('a1') || '/' || pg_temp.id('b003') || '/f.pdf', 'file', 'application/pdf');
select pg_temp.as_user('a1');
set local role authenticated;
select is(public.save_entry(p_id => pg_temp.id('b006'), p_kind => 'text', p_page => pg_temp.id('e001'),
  p_title => 'Remind', p_blocks => jsonb_build_array(pg_temp.b('c0000000-0000-4000-8000-000000000d01', 'toggle', 'Inside', jsonb_build_object(
    'children', jsonb_build_array(pg_temp.b('c0000000-0000-4000-8000-000000000d02', 'todo', 'Nested to-do'))))),
  p_remind_at => now() + interval '2 hours'), pg_temp.id('b006'), 'a to-do inside a toggle, a reminder');

select is(pg_temp.found('', 'todos_open'),
  (select array_agg(x order by x) from unnest(array[pg_temp.id('b001')::text, pg_temp.id('b003')::text,
                                                   pg_temp.id('b006')::text]) x),
  'To-dos open: unticked lines, inside toggles too');
select is(pg_temp.found('', 'photos'), array[pg_temp.id('b001')::text], 'Photos');
select is(pg_temp.found('', 'files'), array[pg_temp.id('b003')::text], 'Files');
select is(pg_temp.found('', 'voice'), '{}', 'Voice notes: none');
select is(pg_temp.found('', 'reminders'),
  (select array_agg(x order by x) from unnest(array[pg_temp.id('b002')::text, pg_temp.id('b006')::text]) x),
  'Reminders still to ring');
select is(pg_temp.found('', 'todos_open', pg_temp.id('e003')), array[pg_temp.id('b003')::text],
  'in one page');
select is(pg_temp.found('٥٠'), array[pg_temp.id('b003')::text], 'Arabic digits');
select is(pg_temp.found('50'), array[pg_temp.id('b003')::text], 'Western digits find them');
select is(pg_temp.found('الحارس', 'todos_open'), array[pg_temp.id('b003')::text],
  'words and a kind together');
select throws_ok($$select pg_temp.found('', 'places')$$, '22023', null, 'a kind it knows');
select is(pg_temp.found(''), '{}', 'no words and no kind: nothing');

-- Share -------------------------------------------------------------------------------------------

select is(public.note_share_text(pg_temp.id('b001'), null, false),
  E'Before the pour\n[ ] Clean the formwork\n[x] Check the cover',
  'the words to share: the title, to-dos as [ ] and [x] (J2)');
select is(public.note_share_text(pg_temp.id('b001'), null, true),
  E'Before the pour\n[ ] Clean the formwork\n[x] Check the cover\n📍 Gate 2 · 29.375900, 47.977400',
  'the location only when included, as one line');
select is(public.note_share_text(pg_temp.id('b003'), array['c0000000-0000-4000-8000-000000000c02'], false), '[ ] إبلاغ الحارس',
  'a line group: only its lines, Arabic kept');

select is(public.share_note_to_space(pg_temp.id('b001'), pg_temp.id('d001'), pg_temp.sp(), 'note'),
  pg_temp.id('d001'), 'to a Space as a post');
select is((select title || '|' || coalesce(place_text, '-') || '|' || body from public.space_posts
           where id = pg_temp.id('d001')),
  E'Before the pour|-|[ ] Clean the formwork\n[x] Check the cover', 'its words, no place, no position');
select is(public.share_note_to_space(pg_temp.id('b001'), pg_temp.id('d002'), pg_temp.sp(), 'note',
  p_include_location => true), pg_temp.id('d002'), 'again, with the location');
select is((select split_part(body, E'
', 3) from public.space_posts where id = pg_temp.id('d002')),
  '📍 Gate 2 · 29.375900, 47.977400', 'the location goes with it, as its last line');
select is(public.share_note_to_space(pg_temp.id('b001'), pg_temp.id('d003'), pg_temp.sp(), 'checklist',
  p_people => array[pg_temp.uid('b2')]),
  pg_temp.id('d003'), 'as a checklist');
select is((select array_agg(c.text order by c.sort) from public.checklist_points c
           where c.post_id = pg_temp.id('d003')), array['Clean the formwork', 'Check the cover'],
  'its to-dos are the points');
select is(public.share_note_to_space(pg_temp.id('b001'), pg_temp.id('d004'), pg_temp.sp(), 'work_item',
  p_owner => pg_temp.uid('b2'), p_include_location => true), pg_temp.id('d004'),
  'as a work item, inside the Space, with the location');
select is((select owner_id from public.work_items where id = pg_temp.id('d004')), pg_temp.uid('b2'),
  'Rakesh owns it');
select is((select place_text from public.space_posts where id = pg_temp.id('d004')), 'Gate 2',
  'its place is the typed location');
select is(public.share_note_to_space(pg_temp.id('b003'), pg_temp.id('d006'), pg_temp.sp(), 'note',
  p_lines => array['c0000000-0000-4000-8000-000000000c02']), pg_temp.id('d006'),
  'a to-do line as a post');
select is((select title from public.space_posts where id = pg_temp.id('d006')), 'إبلاغ الحارس',
  'its title without the [ ] (J2)');
select throws_ok($$select public.share_note_to_space(pg_temp.id('b001'), pg_temp.id('d005'),
  pg_temp.sp(), 'diary')$$, '22023', null, 'a post, a work item or a checklist');

select is(public.share_note_to_feed(pg_temp.id('b003'), pg_temp.id('d101'), 'ar'), pg_temp.id('d101'),
  'to the feed');
select is((select body || '|' || lang from public.posts where id = pg_temp.id('d101')),
  E'الصب\nغطاء الحديد ٥٠ مم\n[ ] إبلاغ الحارس|ar', 'its words, in Arabic');

select ok((public.share_note_to_person(pg_temp.id('b001'), pg_temp.id('d201'), pg_temp.uid('b2'),
  pg_temp.id('d2f1')) ->> 'thread') is not null, 'to Rakesh by message');
select is((select body from public.dm_messages where id = pg_temp.id('d201')),
  E'Before the pour\n[ ] Clean the formwork\n[x] Check the cover', 'the message: a copy of its words');
select throws_ok($$select public.share_note_to_person(pg_temp.id('b001'), pg_temp.id('d202'),
  pg_temp.uid('c3'), pg_temp.id('d2f2'))$$, '42501', null, 'never to someone blocked');

-- J1: a message holds 3,000 characters, as dm_post does: a longer entry is
-- cut there, never refused.
select lives_ok($$select public.save_note(pg_temp.id('b0f1'), 'text', repeat('x', 3500))$$,
  'a long entry');
select ok((public.share_note_to_person(pg_temp.id('b0f1'), pg_temp.id('d203'), pg_temp.uid('b2'),
  pg_temp.id('d2f1')) ->> 'thread') is not null, 'it goes to Rakesh by message');
select is((select char_length(body) from public.dm_messages where id = pg_temp.id('d203')), 3000,
  'cut at 3,000 characters');
-- J2: no share kind writes a mark the fonts lack.
select ok(not exists (
    select 1 from public.space_posts where id in (pg_temp.id('d001'), pg_temp.id('d002'))
      and body ~ '[☐☑]'
    union all
    select 1 from public.posts where id = pg_temp.id('d101') and body ~ '[☐☑]'
    union all
    select 1 from public.dm_messages where id = pg_temp.id('d201') and body ~ '[☐☑]'),
  'no ☐ or ☑ in a post, a feed post or a message');

select is((select array_agg(target order by target) from public.note_shares
           where note_id = pg_temp.id('b001')),
  array['message', 'space', 'space', 'space', 'space'], 'each share leaves its mark on the entry');
select is((select target_name from public.note_shares where space_post_id = pg_temp.id('d001')),
  'Share site', 'with the Space''s name');

-- A base version on save_note ---------------------------------------------------------------------

select is(public.save_entry(p_id => pg_temp.id('b007'), p_kind => 'text', p_page => pg_temp.id('e003'),
  p_body => 'Version 1'), pg_temp.id('b007'), 'a new entry');
select is((select version from public.notes where id = pg_temp.id('b007')), 1, 'version 1');
select is(public.save_entry(p_id => pg_temp.id('b007'), p_kind => 'text', p_body => 'Version 2',
  p_base_version => 1), pg_temp.id('b007'), 'an edit from version 1');
select is((select version from public.notes where id = pg_temp.id('b007')), 2, 'version 2');
select throws_ok($$select public.save_entry(p_id => pg_temp.id('b007'), p_kind => 'text',
  p_body => 'Old phone', p_base_version => 1)$$, '40001', 'changed on another phone',
  'an edit from an older version is refused');
select is((select body from public.notes where id = pg_temp.id('b007')), 'Version 2', 'nothing lost');
select lives_ok($$select public.save_note(p_id => pg_temp.id('b007'), p_kind => 'text',
  p_body => 'Old build')$$, 'an old build, with no version, still saves');

reset role;

-- The daily purge ---------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.set_notebook_keep_days(7)$$, 'Omar keeps 7 days');
select lives_ok($$select public.delete_entries(array[pg_temp.id('b007'), pg_temp.id('b006')])$$,
  'two entries deleted');
reset role;
update public.notes set deleted_at = now() - interval '8 days' where id = pg_temp.id('b007');
update public.notes set deleted_at = now() - interval '3 days' where id = pg_temp.id('b006');
select pg_temp.as_user('b2');
set local role authenticated;
select is(public.save_entry(p_id => pg_temp.id('c001'), p_kind => 'text', p_body => 'Rakesh''s'),
  pg_temp.id('c001'), 'Rakesh''s entry');
select lives_ok($$select public.delete_entries(array[pg_temp.id('c001')])$$, 'deleted');
reset role;
update public.notes set deleted_at = now() - interval '8 days' where id = pg_temp.id('c001');
select ok(public.purge_notebook() >= 1, 'the purge runs');
select is((select count(*)::int from public.notes where id = pg_temp.id('b007')), 0,
  'past Omar''s 7 days: gone');
select is((select count(*)::int from public.notes where id = pg_temp.id('b006')), 1,
  '3 days: still in Deleted items');
select is((select count(*)::int from public.notes where id = pg_temp.id('c001')), 1,
  'Rakesh keeps 30 days: still there');

-- Someone else ------------------------------------------------------------------------------------

select pg_temp.as_user('b2');
set local role authenticated;
select is((select count(*)::int from public.my_deleted_items() where id = pg_temp.id('b006')), 0,
  'Rakesh doesn''t see Omar''s Deleted items');
select is((select count(*)::int from public.note_shares), 0, 'nor his marks');
select is((select notebook_keep_days from public.profile_private where id = pg_temp.uid('a1')), null,
  'nor his choice');
select throws_ok($$select public.restore_items(array[pg_temp.id('b006')])$$, '42501', null,
  'nor restore his');
select throws_ok($$select * from public.delete_forever(array[pg_temp.id('b006')])$$, '42501', null,
  'nor delete them for good');
select throws_ok($$select public.delete_entries(array[pg_temp.id('b001')])$$, '42501', null,
  'nor delete his');
select throws_ok($$select public.delete_note_lines(pg_temp.id('b001'), array['c0000000-0000-4000-8000-000000000a01'], pg_temp.id('c0f1'))$$,
  '42501', null, 'nor his lines');
select throws_ok($$select public.archive_note(pg_temp.id('b001'))$$, '42501', null, 'nor archive his');
select throws_ok($$select public.share_note_to_feed(pg_temp.id('b001'), pg_temp.id('c101'), 'en')$$,
  '42501', null, 'nor share his');
select throws_ok($$select public.note_share_text(pg_temp.id('b001'), null, true)$$, '42501', null,
  'nor read his words that way');
select throws_ok($$select pg_temp.found('', 'todos_open', pg_temp.id('e001'))$$, '42501', null,
  'nor filter his pages');
select is(pg_temp.found('', 'todos_open'), '{}', 'his own Filter has none of Omar''s');
select throws_ok($$select public.purge_notebook()$$, '42501', null, 'nor run the purge');

reset role;

-- Download my data (F1) --------------------------------------------------------------------------

-- Omar's export: archive b003 so it appears under archived.
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.archive_note(pg_temp.id('b003'))$$, 'b003 archived for the export');
select set_config('test.req48', public.request_my_data()::text, true);
reset role;

-- F1: pages
select ok(public.export_my_data(current_setting('test.req48')::uuid) ? 'notebook_pages',
  'the export has pages');
select ok(jsonb_array_length(public.export_my_data(current_setting('test.req48')::uuid) -> 'notebook_pages') >= 2,
  'at least two pages (Site A and the Arabic one)');
select ok(exists (select 1 from jsonb_array_elements(
    public.export_my_data(current_setting('test.req48')::uuid) -> 'notebook_pages') p
  where p ->> 'title' = 'Site A – Tower' and p ? 'icon' and p ? 'pinned'),
  'each page has its title, icon and pinned');
select ok(exists (select 1 from jsonb_array_elements(
    public.export_my_data(current_setting('test.req48')::uuid) -> 'notebook_pages') p
  where p ->> 'parent_id' is not null),
  'and its parent when it has one');

-- F1: each entry's page
select ok(exists (select 1 from jsonb_array_elements(
    public.export_my_data(current_setting('test.req48')::uuid) -> 'notes') n
  where n ->> 'page_id' is not null),
  'each entry carries its page');

-- F1: Deleted items, with when each was deleted
select ok(exists (select 1 from jsonb_array_elements(
    public.export_my_data(current_setting('test.req48')::uuid) -> 'notes') n
  where n ->> 'deleted_at' is not null),
  'deleted entries carry deleted_at');

-- F1: archived entries
select ok(exists (select 1 from jsonb_array_elements(
    public.export_my_data(current_setting('test.req48')::uuid) -> 'notes') n
  where n ->> 'archived_at' is not null),
  'archived entries carry archived_at');

-- F1: keep-days choice
select is(public.export_my_data(current_setting('test.req48')::uuid)
          -> 'private' ->> 'notebook_keep_days', '7',
  'the keep-days choice is in the export');

-- F1: share records
select ok(public.export_my_data(current_setting('test.req48')::uuid) ? 'note_shares',
  'the export has share records');
select ok(jsonb_array_length(
    public.export_my_data(current_setting('test.req48')::uuid) -> 'note_shares') >= 1,
  'with at least one share');
select ok(exists (select 1 from jsonb_array_elements(
    public.export_my_data(current_setting('test.req48')::uuid) -> 'note_shares') s
  where s ? 'target' and s ? 'created_at'),
  'each share has its target and when');
select ok(exists (select 1 from jsonb_array_elements(
    public.export_my_data(current_setting('test.req48')::uuid) -> 'note_shares') s
  where s ->> 'target_name' is not null),
  'and the Space or person''s name');

-- F1: none of anyone else's
select pg_temp.as_user('b2');
set local role authenticated;
select set_config('test.req48b', public.request_my_data()::text, true);
reset role;
select ok(public.export_my_data(current_setting('test.req48b')::uuid) ? 'notebook_pages',
  'Rakesh''s export has the pages key');
select is(jsonb_array_length(
    public.export_my_data(current_setting('test.req48b')::uuid) -> 'notebook_pages'), 1,
  'only his own page (My notes)');
-- J3 (G1): "My notes" comes out named, not untitled.
select is((public.export_my_data(current_setting('test.req48b')::uuid)
           -> 'notebook_pages' -> 0 ->> 'named'), 'my_notes',
  'the page''s named goes with it');
select is(jsonb_array_length(
    public.export_my_data(current_setting('test.req48b')::uuid) -> 'note_shares'), 0,
  'none of Omar''s shares');
select ok(not exists (select 1 from jsonb_array_elements(
    public.export_my_data(current_setting('test.req48b')::uuid) -> 'notes') n
  where (n ->> 'page_id')::uuid in (pg_temp.id('e001'), pg_temp.id('e003'))),
  'none of Omar''s entries');

-- Undo the archive so the state is left clean.
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.unarchive_note(pg_temp.id('b003'))$$, 'b003 unarchived');
reset role;

select * from finish();
rollback;
