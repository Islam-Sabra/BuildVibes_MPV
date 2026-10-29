-- Migration 51 (review 106 T5): when an entry's content last changed, for
-- "changed since shared". notes.content_changed_at moves only when the
-- content does: its title, its words and lines, its photos and files.
-- Ticking a to-do, pinning, folding, moving it to another page and a
-- reminder don't move it. It is worked out when the change is made for
-- good (a deferred trigger), so a save that sends the same files again
-- doesn't count. Only the owner reads it; nobody writes it but the server.
--
-- The lead's check of r106b: K1, a share keeps the entry's content_key
-- from when it was made, and it is older exactly when that key differs
-- from the entry's now (no clocks). K2, the key can't be shifted by a
-- missing field. K6, a voice recording counts.
-- Run with: supabase test db
--
-- Omar (a1) owns the notebook; Rakesh (b2) is someone else.

begin;
create extension if not exists pgtap with schema extensions;
select plan(30);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000051' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@versions51.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000051' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000051' || p)::uuid;
$$;
-- The entry's lines: two to-dos, the first ticked or not, and [extra].
create function pg_temp.lines(p_done boolean, p_extra text default null) returns jsonb language sql as $$
  select jsonb_build_array(
    jsonb_build_object('id', pg_temp.id('c001'), 'type', 'todo', 'text', 'Gloves', 'done', p_done),
    jsonb_build_object('id', pg_temp.id('c002'), 'type', 'todo', 'text', 'Helmet', 'done', false))
    || case when p_extra is null then '[]'::jsonb
            else jsonb_build_array(jsonb_build_object('id', pg_temp.id('c003'), 'type', 'text', 'text', p_extra)) end;
$$;
-- When the entry's content last changed, once its changes are made for good.
create function pg_temp.changed() returns timestamptz language plpgsql as $$
begin
  set constraints all immediate;
  set constraints all deferred;
  return (select content_changed_at from public.notes where id = pg_temp.id('b001'));
end;
$$;
-- A share is older than its entry: its key isn't the entry's (K1).
create function pg_temp.older(p text) returns boolean language sql as $$
  select s.content_key is distinct from n.content_key
  from public.note_shares s join public.notes n on n.id = s.note_id
  where s.id = pg_temp.id(p);
$$;
create temp table seen (step text primary key, at timestamptz);
grant all on seen to authenticated;

select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.create_notebook_page(pg_temp.id('e001'), 'Site log')$$, 'a page');
select lives_ok($$select public.create_notebook_page(pg_temp.id('e002'), 'Snags')$$, 'another');
select lives_ok($$select public.save_entry(p_id => pg_temp.id('b001'), p_kind => 'text',
  p_page => pg_temp.id('e001'), p_title => 'Before the walk', p_blocks => pg_temp.lines(false))$$,
  'an entry with two to-dos');
insert into seen values ('new', pg_temp.changed());
select isnt((select at from seen where step = 'new'), null, 'a new entry has its change time');

-- What doesn't count -------------------------------------------------------------------------------

select lives_ok($$select public.save_entry(p_id => pg_temp.id('b001'), p_kind => 'text',
  p_page => pg_temp.id('e001'), p_title => 'Before the walk', p_blocks => pg_temp.lines(true))$$,
  'a to-do ticked (the entry saved again)');
select is(pg_temp.changed(), (select at from seen where step = 'new'), 'a tick doesn''t count');
select lives_ok($$select public.pin_note(pg_temp.id('b001'), true)$$, 'pinned');
select lives_ok($$select public.set_notes_collapsed(array[pg_temp.id('b001')], true)$$, 'folded');
select lives_ok($$select public.move_notes(array[pg_temp.id('b001')], pg_temp.id('e002'))$$,
  'moved to another page');
select lives_ok($$select public.save_entry(p_id => pg_temp.id('b001'), p_kind => 'text',
  p_page => pg_temp.id('e002'), p_title => 'Before the walk', p_blocks => pg_temp.lines(true),
  p_remind_at => now() + interval '1 day', p_pinned => true)$$, 'a reminder set');
select is(pg_temp.changed(), (select at from seen where step = 'new'),
  'pinning, folding, moving and a reminder don''t count');

-- What counts --------------------------------------------------------------------------------------

select lives_ok($$select public.save_entry(p_id => pg_temp.id('b001'), p_kind => 'text',
  p_page => pg_temp.id('e002'), p_title => 'Before the walk', p_blocks => pg_temp.lines(true, 'Bring the snag list'),
  p_pinned => true)$$, 'a line added');
insert into seen values ('line', pg_temp.changed());
select cmp_ok((select at from seen where step = 'line'), '>', (select at from seen where step = 'new'),
  'a new line counts');
select lives_ok($$select public.save_entry(p_id => pg_temp.id('b001'), p_kind => 'text',
  p_page => pg_temp.id('e002'), p_title => 'Before the site walk', p_blocks => pg_temp.lines(true, 'Bring the snag list'),
  p_pinned => true)$$, 'the title edited');
insert into seen values ('title', pg_temp.changed());
select cmp_ok((select at from seen where step = 'title'), '>', (select at from seen where step = 'line'),
  'the title counts');
reset role;
-- A photo added (as set_note_files keeps it), then the files sent again unchanged.
insert into public.note_files (note_id, storage_path, kind, mime, bytes, sort)
values (pg_temp.id('b001'), '00000000-0000-0000-0000-0000000051a1/b001/one.jpg', 'photo', 'image/jpeg', 10, 0);
insert into seen values ('photo', pg_temp.changed());
select cmp_ok((select at from seen where step = 'photo'), '>', (select at from seen where step = 'title'),
  'a photo counts');
delete from public.note_files where note_id = pg_temp.id('b001');
insert into public.note_files (note_id, storage_path, kind, mime, bytes, sort)
values (pg_temp.id('b001'), '00000000-0000-0000-0000-0000000051a1/b001/one.jpg', 'photo', 'image/jpeg', 10, 0);
select is(pg_temp.changed(), (select at from seen where step = 'photo'),
  'the same files sent again don''t count');

-- K1: older is the server's one rule, by key ---------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.save_entry(p_id => pg_temp.id('b001'), p_kind => 'text',
  p_page => pg_temp.id('e002'), p_title => 'Site walk at 9', p_blocks => pg_temp.lines(true))$$,
  'edited');
reset role;
-- Shared in the same breath, before the edit's triggers have run.
insert into public.note_shares (id, note_id, owner_id, target)
values (pg_temp.id('d001'), pg_temp.id('b001'), '00000000-0000-0000-0000-0000000051a1', 'feed');
select pg_temp.changed();
select isnt((select content_key from public.note_shares where id = pg_temp.id('d001')), null,
  'a share keeps the entry''s key');
select is(pg_temp.older('d001'), false, 'a share right after an edit is not older');
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.save_entry(p_id => pg_temp.id('b001'), p_kind => 'text',
  p_page => pg_temp.id('e002'), p_title => 'Site walk at 10', p_blocks => pg_temp.lines(true))$$,
  'edited after the share');
reset role;
select pg_temp.changed();
select is(pg_temp.older('d001'), true, 'an edit after a share is older');
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.save_entry(p_id => pg_temp.id('b001'), p_kind => 'text',
  p_page => pg_temp.id('e002'), p_title => 'Site walk at 9', p_blocks => pg_temp.lines(false))$$,
  'edited back to the shared words (a tick apart)');
reset role;
select pg_temp.changed();
select is(pg_temp.older('d001'), false, 'editing back to the shared text is not older');
insert into seen values ('back', (select content_changed_at from public.notes where id = pg_temp.id('b001')));

-- K6: a voice recording counts --------------------------------------------------------------------

insert into public.note_files (note_id, storage_path, kind, mime, bytes, sort)
values (pg_temp.id('b001'), '00000000-0000-0000-0000-0000000051a1/b001/voice.m4a', 'voice', 'audio/mp4', 10, 1);
insert into seen values ('voice', pg_temp.changed());
select cmp_ok((select at from seen where step = 'voice'), '>', (select at from seen where step = 'back'),
  'a voice recording counts');

-- K2: a missing field can't shift the others -----------------------------------------------------------

insert into public.notes
select (jsonb_populate_record(null::public.notes, to_jsonb(n) || jsonb_build_object(
  'id', pg_temp.id('b002'), 'title', 'T', 'body', '[]', 'blocks', null, 'points', null))).*
from public.notes n where n.id = pg_temp.id('b001');
insert into public.notes
select (jsonb_populate_record(null::public.notes, to_jsonb(n) || jsonb_build_object(
  'id', pg_temp.id('b003'), 'title', 'T', 'body', null, 'blocks', '[]'::jsonb, 'points', null))).*
from public.notes n where n.id = pg_temp.id('b001');
select isnt(public.note_content_key(pg_temp.id('b002')), public.note_content_key(pg_temp.id('b003')),
  'words "[]" and an empty page are different keys');

-- Who reads and writes it --------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$update public.notes set content_changed_at = now() where id = pg_temp.id('b001')$$,
  '42501', null, 'even the owner can''t write it');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select is((select count(*) from public.notes where id = pg_temp.id('b001'))::integer, 0,
  'someone else can''t read it');
select throws_ok($$update public.notes set content_changed_at = null where id = pg_temp.id('b001')$$,
  '42501', null, 'someone else can''t change it');
reset role;
select is((select at from seen where step = 'voice'),
  (select content_changed_at from public.notes where id = pg_temp.id('b001')), 'it is as it was');

select * from finish();
rollback;
