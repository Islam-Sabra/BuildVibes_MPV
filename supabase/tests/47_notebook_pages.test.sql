-- Migration 47 (review 99A): the notebook's pages. Run with: supabase test db
--
-- Omar (a1) owns the pages; Rakesh (b2) is someone else.

begin;
create extension if not exists pgtap with schema extensions;
select plan(124);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000047' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@pages47.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000047' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000047' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000047' || p)::uuid;
$$;
-- A text line.
create function pg_temp.line(p_text text) returns jsonb language sql as $$
  select jsonb_build_object('id', gen_random_uuid(), 'type', 'text', 'text', p_text);
$$;

-- Grants -----------------------------------------------------------------------------------------

select ok(not has_table_privilege('anon', 'public.notebook_pages', 'select'), 'signed out: no pages');
select ok(not has_table_privilege('authenticated', 'public.notebook_pages', 'insert'),
  'pages are written only through the functions');
select ok(not has_function_privilege('anon', 'public.save_entry(uuid, text, uuid, text, text, jsonb,
  timestamptz, timestamptz, boolean, jsonb, text, jsonb, jsonb, timestamptz)', 'execute'),
  'signed out: no save_entry');
select ok(not has_function_privilege('anon', 'public.search_notebook(text)', 'execute'),
  'signed out: no search');
select ok(not has_function_privilege('authenticated', 'public.notes_into_my_notes()', 'execute'),
  'nobody runs the backfill');
select ok(not has_function_privilege('authenticated', 'public.new_notebook_page(uuid, text, uuid,
  text, boolean)', 'execute'), 'nor the page maker');
select ok(has_function_privilege('authenticated', 'public.merge_notebook_pages(uuid[], uuid[], uuid,
  text)', 'execute'), 'signed in: merge');

-- Backfill (A6) ----------------------------------------------------------------------------------

-- Old notes with no page, as before the migration.
alter table public.notes alter column page_id drop not null;
alter table public.notes disable trigger notes_page_ok;
alter table public.notes disable trigger notes_page_activity;
alter table public.notes disable trigger notes_page_activity_change;
insert into public.notes (id, owner_id, kind, body, created_at) values
  (pg_temp.id('a001'), pg_temp.uid('a1'), 'text', 'Oldest', now() - interval '3 days'),
  (pg_temp.id('a002'), pg_temp.uid('a1'), 'text', 'Middle', now() - interval '2 days'),
  (pg_temp.id('a003'), pg_temp.uid('a1'), 'todo', 'Newest', now() - interval '1 day'),
  (pg_temp.id('a004'), pg_temp.uid('b2'), 'text', 'Rakesh''s', now() - interval '1 day');
select is(public.notes_into_my_notes(), 4, 'every note without a page is moved');
alter table public.notes enable trigger notes_page_ok;
alter table public.notes enable trigger notes_page_activity;
alter table public.notes enable trigger notes_page_activity_change;
alter table public.notes alter column page_id set not null;
select is((select count(*)::integer from public.notes where page_id is null), 0, 'no note is left out');
select is((select count(*)::integer from public.notebook_pages
           where owner_id = pg_temp.uid('a1') and named = 'my_notes'), 1,
  'one "My notes" for Omar');
select is((select count(distinct page_id)::integer from public.notes
           where owner_id = pg_temp.uid('a1')), 1, 'all his notes in it');
select ok((select p.owner_id = pg_temp.uid('b2') from public.notes n
           join public.notebook_pages p on p.id = n.page_id where n.id = pg_temp.id('a004')),
  'Rakesh''s note in his own "My notes"');
select ok((select p.created_at = now() - interval '3 days'
              and p.last_activity_at = now() - interval '1 day'
           from public.notebook_pages p
           where p.owner_id = pg_temp.uid('a1') and p.named = 'my_notes'),
  'made at the oldest note; its latest activity the newest');
select is(public.notes_into_my_notes(), 0, 'run again, nothing moves');

-- Writing into a page (A2) -----------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;

select is((select count(*)::integer from public.notebook_pages), 1, 'Omar reads only his own pages');

select is(public.create_notebook_page(pg_temp.id('e001'), 'Site A – Tower', null, 'hard_hat'),
  pg_temp.id('e001'), '+ New page');
select is(public.create_notebook_page(pg_temp.id('e001'), 'Something else', null, 'star'),
  pg_temp.id('e001'), 'a retry is the same page');
select is((select title || '/' || icon from public.notebook_pages where id = pg_temp.id('e001')),
  'Site A – Tower/hard_hat', 'the retry changes nothing');
select throws_ok($$select public.create_notebook_page(pg_temp.id('e009'), 'x', null, 'smiley')$$,
  '23514', null, 'an icon from the twelve only');
select throws_ok($$select public.create_notebook_page(pg_temp.id('e009'), repeat('x', 121))$$,
  '22023', null, 'a title of up to 120 characters');

select is(public.save_entry(p_id => pg_temp.id('b001'), p_kind => 'text',
  p_page => pg_temp.id('e001'), p_title => 'Before the pour, level 3',
  p_blocks => jsonb_build_array(pg_temp.line('Clean the formwork'))),
  pg_temp.id('b001'), 'an entry into a page');
select is((select page_id from public.notes where id = pg_temp.id('b001')), pg_temp.id('e001'),
  'it is in that page');

select is(public.save_entry(p_id => pg_temp.id('b002'), p_kind => 'text',
  p_page => pg_temp.id('e002'), p_new_page_title => 'Pump booked 2 pm', p_body => 'Gate 2'),
  pg_temp.id('b002'), 'an entry with "New page"');
select is((select title || '/' || is_new::text from public.notebook_pages where id = pg_temp.id('e002')),
  'Pump booked 2 pm/true', 'the page is titled from it and marked new');
select is((select page_id from public.notes where id = pg_temp.id('b002')), pg_temp.id('e002'),
  'the entry is in the new page');
select is(public.save_entry(p_id => pg_temp.id('b002'), p_kind => 'text',
  p_page => pg_temp.id('e002'), p_new_page_title => 'Pump booked 2 pm', p_body => 'Gate 2'),
  pg_temp.id('b002'), 'a retry');
select is((select count(*)::integer from public.notebook_pages where title = 'Pump booked 2 pm'), 1,
  'makes no second page');
select throws_ok($$select public.save_entry(p_id => pg_temp.id('b003'), p_kind => 'text',
  p_page => pg_temp.id('e404'), p_body => 'x')$$, '42501', null,
  'a page that isn''t there, with no title: refused');

select is(public.save_entry(p_id => pg_temp.id('b002'), p_kind => 'text', p_body => 'Gate 3'),
  pg_temp.id('b002'), 'an edit with no page');
select is((select page_id from public.notes where id = pg_temp.id('b002')), pg_temp.id('e002'),
  'stays in its page');

select ok(public.save_note(p_id => pg_temp.id('b004'), p_kind => 'text', p_body => 'Old build')
  is not null, 'an old build''s save_note');
select is((select page_id from public.notes where id = pg_temp.id('b004')), pg_temp.id('e002'),
  'goes into the latest page');

select ok((select last_activity_at >= now() from public.notebook_pages where id = pg_temp.id('e002')),
  'writing in a page is its latest activity');

-- Inside a page (A3) -----------------------------------------------------------------------------

select lives_ok($$select public.open_notebook_page(pg_temp.id('e002'))$$, 'opened');
select ok(not (select is_new from public.notebook_pages where id = pg_temp.id('e002')),
  'no longer new');
select lives_ok($$select public.update_notebook_page(pg_temp.id('e001'), '  Site A  –  Tower ', 'building')$$,
  'renamed, with a new icon');
select is((select title || '/' || icon from public.notebook_pages where id = pg_temp.id('e001')),
  'Site A – Tower/building', 'kept, its spaces tidied');
select throws_ok($$select public.update_notebook_page(pg_temp.id('e001'), 'x', 'emoji')$$,
  '23514', null, 'an icon from the twelve only');

select is(public.create_notebook_page(pg_temp.id('e003'), 'Level 3', pg_temp.id('e001'), 'folder'),
  pg_temp.id('e003'), 'a sub-page');
select is(public.create_notebook_page(pg_temp.id('e004'), 'Rebar', pg_temp.id('e003'), 'folder'),
  pg_temp.id('e004'), 'a sub-page of a sub-page');
select throws_ok($$select public.move_notebook_pages(array[pg_temp.id('e001')], pg_temp.id('e004'))$$,
  '22023', null, 'a page can''t go under its own sub-page');
select throws_ok($$select public.move_notebook_pages(array[pg_temp.id('e001')], pg_temp.id('e001'))$$,
  null, 'nor into itself');
select lives_ok($$select public.move_notebook_pages(array[pg_temp.id('e004')], null)$$,
  'Move into the top');
select is((select parent_id from public.notebook_pages where id = pg_temp.id('e004')), null,
  'it is at the top');
select lives_ok($$select public.move_notebook_pages(array[pg_temp.id('e004')], pg_temp.id('e003'))$$,
  'and back in');

select lives_ok($$select public.pin_notebook_pages(array[pg_temp.id('e001'), pg_temp.id('e002')], true)$$,
  'pin two');
select is((select count(*)::integer from public.notebook_pages where pinned), 2, 'both pinned');

-- Move to page (A4) ------------------------------------------------------------------------------

select lives_ok($$select public.move_notes(array[pg_temp.id('b004')], pg_temp.id('e003'))$$,
  'an entry moved to a page');
select is((select page_id from public.notes where id = pg_temp.id('b004')), pg_temp.id('e003'),
  'it is there');

-- Merge (A4): all or nothing ---------------------------------------------------------------------

select throws_ok($$select public.merge_notebook_pages(
  array[pg_temp.id('e002'), (select page_id from public.notes where id = pg_temp.id('a004'))],
  null, pg_temp.id('e002'))$$, '42501', null, 'a merge with someone else''s page is refused');
select is((select count(*)::integer from public.notebook_pages where deleted_at is not null), 0,
  'and nothing changed');

select is(public.merge_notebook_pages(array[pg_temp.id('e001'), pg_temp.id('e002')], null,
  pg_temp.id('e001')), pg_temp.id('e001'), 'two pages merged into one');
select is((select count(*)::integer from public.notes where page_id = pg_temp.id('e001')), 2,
  'every entry is in the page that stays');
select ok((select deleted_at is not null and pinned from public.notebook_pages
           where id = pg_temp.id('e002')), 'the emptied page is deleted and keeps its pin');
select is((select parent_id from public.notebook_pages where id = pg_temp.id('e003')),
  pg_temp.id('e001'), 'sub-pages stay under the page that stays');

select is(public.merge_notebook_pages(array[pg_temp.id('e003')], array[pg_temp.id('b001')],
  pg_temp.id('e005'), 'Merged'), pg_temp.id('e005'), 'a page and an entry into a new page');
select is((select title || '/' || coalesce(parent_id::text, 'top') from public.notebook_pages
           where id = pg_temp.id('e005')), 'Merged/top', 'the new page, at the top');
select is((select count(*)::integer from public.notes where page_id = pg_temp.id('e005')), 2,
  'its entries');
select is((select parent_id from public.notebook_pages where id = pg_temp.id('e004')),
  pg_temp.id('e005'), 'the merged page''s sub-page under the new one');

select is(public.merge_notebook_pages(array[pg_temp.id('e005'), pg_temp.id('e004')], null,
  pg_temp.id('e004')), pg_temp.id('e004'), 'merged into its own sub-page');
select is((select parent_id from public.notebook_pages where id = pg_temp.id('e004')), null,
  'which climbs out of the page that goes');

select throws_ok($$select public.merge_notebook_pages(array[pg_temp.id('e004')], null, null)$$,
  '22023', null, 'the page that stays is chosen');

-- Delete ----------------------------------------------------------------------------------------

select is(public.create_notebook_page(pg_temp.id('e006'), 'Pour day', pg_temp.id('e004')),
  pg_temp.id('e006'), 'a sub-page to delete with its page');
select is(public.save_entry(p_id => pg_temp.id('b005'), p_kind => 'text', p_page => pg_temp.id('e006'),
  p_body => 'Pump at gate 2'), pg_temp.id('b005'), 'with an entry');
select lives_ok($$select public.delete_notebook_pages(array[pg_temp.id('e004')])$$, 'a page deleted');
select is((select count(*)::integer from public.notebook_pages
           where id in (pg_temp.id('e004'), pg_temp.id('e006')) and deleted_at is not null), 2,
  'with the page under it');
select throws_ok($$select public.save_entry(p_id => pg_temp.id('b006'), p_kind => 'text',
  p_page => pg_temp.id('e004'), p_body => 'x')$$, '42501', null, 'nothing goes into a deleted page');

-- Search (A5) ------------------------------------------------------------------------------------

select is(public.create_notebook_page(pg_temp.id('e007'), 'موقع ٢٣', null, 'building'),
  pg_temp.id('e007'), 'an Arabic page');
select is(public.save_entry(p_id => pg_temp.id('b007'), p_kind => 'text', p_page => pg_temp.id('e007'),
  p_title => 'الصب', p_blocks => jsonb_build_array(pg_temp.line('غطاء الحديد 50 مم'))),
  pg_temp.id('b007'), 'with an entry');

select is((select array_agg(kind || ':' || coalesce(note_id, page_id)::text order by kind desc)
           from public.search_notebook('23')),
  array['page:' || pg_temp.id('e007')], 'Western digits find Arabic ones, in a title');
select is((select array_agg(note_id) from public.search_notebook('٥٠')),
  array[pg_temp.id('b007')], 'Arabic digits find Western ones, in a line');
select is((select array_agg(note_id) from public.search_notebook('الحديد')),
  array[pg_temp.id('b007')], 'the words of a line');
select is((select array_agg(note_id) from public.search_notebook('الصب')),
  array[pg_temp.id('b007')], 'an entry''s title');
select is((select count(*)::integer from public.search_notebook('Pump at gate')), 0,
  'nothing in a deleted page');
select is((select count(*)::integer from public.search_notebook('Oldest')), 1, 'an old note');
select is((select count(*)::integer from public.search_notebook('x')), 0, 'one letter is too short');

-- C1: the page that stays climbs out of every page that goes ----------------------------------------

select lives_ok($$select public.create_notebook_page(pg_temp.id('e101'), 'G')$$, 'G');
select lives_ok($$select public.create_notebook_page(pg_temp.id('e102'), 'X', pg_temp.id('e101'))$$, 'X in G');
select lives_ok($$select public.create_notebook_page(pg_temp.id('e103'), 'I', pg_temp.id('e102'))$$, 'I in X');
select is(public.save_entry(p_id => pg_temp.id('b101'), p_kind => 'text', p_page => pg_temp.id('e101'),
  p_body => 'In G'), pg_temp.id('b101'), 'an entry in G');
select is(public.merge_notebook_pages(array[pg_temp.id('e101')], null, pg_temp.id('e103')),
  pg_temp.id('e103'), 'G merged into I, deeper inside it');
select is((select parent_id from public.notebook_pages where id = pg_temp.id('e103')), null,
  'I takes G''s place');
select is((select parent_id from public.notebook_pages where id = pg_temp.id('e102')), pg_temp.id('e103'),
  'X goes under I');
select is((select page_id from public.notes where id = pg_temp.id('b101')), pg_temp.id('e103'),
  'G''s entry is in I');

-- C3: safe to send twice ------------------------------------------------------------------------

select is(public.merge_notebook_pages(array[pg_temp.id('e101')], null, pg_temp.id('e103')),
  pg_temp.id('e103'), 'the same merge again: the same page, nothing more');
select lives_ok($$select public.create_notebook_page(pg_temp.id('e104'), 'To delete')$$, 'a page');
select lives_ok($$select public.delete_notebook_pages(array[pg_temp.id('e104')])$$, 'deleted');
select lives_ok($$select public.delete_notebook_pages(array[pg_temp.id('e104')])$$, 'deleted again: skipped');
select lives_ok($$select public.pin_notebook_pages(array[pg_temp.id('e103')], true)$$, 'pinned');
select lives_ok($$select public.pin_notebook_pages(array[pg_temp.id('e103')], true)$$, 'pinned again');
select ok((select pinned from public.notebook_pages where id = pg_temp.id('e103')), 'still pinned');

-- Ruling 7: a merge's new page carries the new mark ----------------------------------------------

select lives_ok($$select public.create_notebook_page(pg_temp.id('e105'), 'A')$$, 'A');
select is(public.merge_notebook_pages(array[pg_temp.id('e105')], null, pg_temp.id('e106'), ''),
  pg_temp.id('e106'), 'A merged into a new page');
select ok((select is_new from public.notebook_pages where id = pg_temp.id('e106')), 'marked new');

-- C4: a new entry goes straight into its page; what counts as activity -------------------------

reset role;
update public.notebook_pages set last_activity_at = now() - interval '1 day'
where owner_id = pg_temp.uid('a1');
select pg_temp.as_user('a1');
set local role authenticated;

select is(public.save_entry(p_id => pg_temp.id('b102'), p_kind => 'text', p_page => pg_temp.id('e106'),
  p_body => 'Into the new one'), pg_temp.id('b102'), 'an entry into a page that isn''t the latest');
select ok((select last_activity_at = now() from public.notebook_pages where id = pg_temp.id('e106')),
  'its page is stamped');
select is((select count(*)::integer from public.notebook_pages
           where owner_id = pg_temp.uid('a1') and last_activity_at = now()), 1,
  'and no other page');
select lives_ok($$select public.pin_note(pg_temp.id('a001'), true)$$, 'an entry in My notes pinned');
select ok((select last_activity_at < now() from public.notebook_pages
           where owner_id = pg_temp.uid('a1') and named = 'my_notes'), 'a pin isn''t activity');
select lives_ok($$select public.save_note(p_id => pg_temp.id('a001'), p_kind => 'text', p_body => 'Oldest',
  p_remind_at => now() + interval '1 day')$$, 'a reminder set, the words the same');
select ok((select last_activity_at < now() from public.notebook_pages
           where owner_id = pg_temp.uid('a1') and named = 'my_notes'), 'a reminder isn''t activity');
select lives_ok($$select public.save_note(p_id => pg_temp.id('a001'), p_kind => 'text',
  p_body => 'Oldest, changed')$$, 'its words changed');
select ok((select last_activity_at = now() from public.notebook_pages
           where owner_id = pg_temp.uid('a1') and named = 'my_notes'), 'changed words are activity');

select is(public.save_entry(p_id => pg_temp.id('b103'), p_kind => 'text', p_body => 'Gone'),
  pg_temp.id('b103'), 'an entry');
select lives_ok($$select public.delete_note(pg_temp.id('b103'))$$, 'deleted');
select is(public.save_entry(p_id => pg_temp.id('b103'), p_kind => 'text', p_page => pg_temp.id('e107'),
  p_new_page_title => 'Never', p_body => 'Gone'), null, 'a late save of it comes back empty');
select is((select count(*)::integer from public.notebook_pages where id = pg_temp.id('e107')), 0,
  'and makes no page');

reset role;
select throws_ok($$insert into public.notebook_pages (owner_id, named) values (pg_temp.uid('a1'), 'my_notes')$$,
  '23505', null, 'one "My notes" a person');
select pg_temp.as_user('a1');
set local role authenticated;

reset role;

-- Someone else ----------------------------------------------------------------------------------

select pg_temp.as_user('b2');
set local role authenticated;

select is((select count(*)::integer from public.notebook_pages where owner_id = pg_temp.uid('a1')), 0,
  'Rakesh can''t read Omar''s pages');
select is((select count(*)::integer from public.search_notebook('Oldest')), 0,
  'nor find them in search');
select throws_ok($$select public.save_entry(p_id => pg_temp.id('c001'), p_kind => 'text',
  p_page => pg_temp.id('e001'), p_body => 'x')$$, '42501', null,
  'nor write into one');
select throws_ok($$select public.move_notes(array[pg_temp.id('a004')], pg_temp.id('e001'))$$,
  '42501', null, 'nor move into one');
select throws_ok($$select public.move_notes(array[pg_temp.id('a001')],
  (select page_id from public.notes where id = pg_temp.id('a004')))$$,
  '42501', null, 'nor move Omar''s entry out');
select throws_ok($$select public.merge_notebook_pages(array[pg_temp.id('e001')], null,
  pg_temp.id('e001'))$$, '42501', null, 'nor merge them');
select throws_ok($$select public.create_notebook_page(pg_temp.id('e001'), 'Mine now')$$,
  '42501', null, 'nor take one''s id');
select throws_ok($$select public.update_notebook_page(pg_temp.id('e001'), 'x', null)$$,
  '42501', null, 'nor rename one');
select throws_ok($$select public.delete_notebook_pages(array[pg_temp.id('e001')])$$,
  '42501', null, 'nor delete one');
select throws_ok($$select public.create_notebook_page(pg_temp.id('c002'), 'x', pg_temp.id('e001'))$$,
  '42501', null, 'nor put a page of his under one');
select throws_ok($$select public.pin_notebook_pages(array[pg_temp.id('e103')], true)$$,
  '42501', null, 'nor pin one');
select throws_ok($$select public.move_notebook_pages(array[pg_temp.id('e103')], null)$$,
  '42501', null, 'nor move one');
select throws_ok($$select public.move_notebook_pages(
  array[(select page_id from public.notes where id = pg_temp.id('a004'))], pg_temp.id('e103'))$$,
  '42501', null, 'nor move a page of his into one');
select throws_ok($$select public.open_notebook_page(pg_temp.id('e106'))$$,
  '42501', null, 'nor mark one opened');
select is((select count(*)::integer from public.search_notebook('23')), 0,
  'search finds none of Omar''s pages');
select is((select count(*)::integer from public.search_notebook('Into the new')), 0,
  'nor his entries');

reset role;

select * from finish();
rollback;
