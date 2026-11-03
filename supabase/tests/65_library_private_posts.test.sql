-- libfix (Z14, privacy): a post opens its files for everyone who sees it,
-- so a post never carries a Library file from an only-me or a person's
-- folder, and a Team folder's file only on that Team's post. Checked where
-- every way in lands: a file post (space_posts.library_file_id), a post's
-- files (post_files) and a work item's attachments. Run with: supabase test db
--
-- Omar (a1) made the Space "Lib fix" and its Team "Steel" with Rakesh (b2).
-- Omar has four folders: only me, for Rakesh, for Steel, the whole Space;
-- one file in each, and one at the Library's top level.

begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000065' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@libfix.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000065' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000065' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000065' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Lib fix')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp(), pg_temp.uid('b2'), 'crew', pg_temp.uid('a1'));
select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'Steel',
  array[pg_temp.uid('b2')])::text, true);
reset role;

insert into public.library_folders (id, space_id, name, kind, share, share_person, share_team, created_by)
values (pg_temp.id('d001'), pg_temp.sp(), 'Only me', 'folder', 'only_me', null, null, pg_temp.uid('a1')),
       (pg_temp.id('d002'), pg_temp.sp(), 'For Rakesh', 'folder', 'person', pg_temp.uid('b2'), null,
        pg_temp.uid('a1')),
       (pg_temp.id('d003'), pg_temp.sp(), 'Steel', 'folder', 'team', null, pg_temp.team(), pg_temp.uid('a1')),
       (pg_temp.id('d004'), pg_temp.sp(), 'Everyone', 'folder', 'space', null, null, pg_temp.uid('a1'));
insert into public.library_files (id, space_id, name, storage_path, mime, uploaded_by, folder_id)
select pg_temp.id(x.f), pg_temp.sp(), x.f || '.pdf',
       pg_temp.sp()::text || '/library/' || pg_temp.id(x.f)::text || '/' || x.f || '.pdf',
       'application/pdf', pg_temp.uid('a1'), case when x.d is not null then pg_temp.id(x.d) end
from (values ('f001', 'd001'), ('f002', 'd002'), ('f003', 'd003'), ('f004', 'd004'),
             ('f005', null)) x(f, d);

-- A file post: the file it shares.
create function pg_temp.file_post(p_post text, p_file text, p_team uuid default null)
returns void language sql as $$
  insert into public.space_posts (id, space_id, team_id, kind, author_id, title, library_file_id)
  values (pg_temp.id(p_post), pg_temp.sp(), p_team, 'file', pg_temp.uid('a1'), 'A file',
          pg_temp.id(p_file));
$$;

select throws_ok($$select pg_temp.file_post('a001', 'f001')$$, '42501', null,
  'a file post never shares an only-me file');
select throws_ok($$select pg_temp.file_post('a002', 'f002')$$, '42501', null,
  'nor a file from a person''s folder');
select throws_ok($$select pg_temp.file_post('a003', 'f003')$$, '42501', null,
  'nor a Team folder''s file with the whole Space');
select lives_ok($$select pg_temp.file_post('a004', 'f003', pg_temp.team())$$,
  'a Team folder''s file with that Team');
select lives_ok($$select pg_temp.file_post('a005', 'f004')$$, 'a whole-Space folder''s file');
select lives_ok($$select pg_temp.file_post('a006', 'f005')$$, 'a file at the Library''s top level');
select throws_ok($$update public.space_posts set library_file_id = pg_temp.id('f001')
                   where id = pg_temp.id('a006')$$, '42501', null,
  'nor changed to an only-me file afterwards');
select throws_ok($$update public.space_posts set team_id = null where id = pg_temp.id('a004')$$,
  '42501', null, 'nor a Team post with a Team file opened to the whole Space');

-- A post's own files.
select pg_temp.as_user('a1');
set local role authenticated;
select public.create_space_post(pg_temp.id('b001'), pg_temp.sp(), 'note', 'A note');
select public.create_space_post(pg_temp.id('b002'), pg_temp.sp(), 'note', 'Steel note',
  p_team => pg_temp.team());
reset role;
select throws_ok($$insert into public.post_files (post_id, library_file_id)
                   values (pg_temp.id('b001'), pg_temp.id('f001'))$$, '42501', null,
  'a post''s files: never an only-me file');
select throws_ok($$insert into public.post_files (post_id, library_file_id)
                   values (pg_temp.id('b001'), pg_temp.id('f003'))$$, '42501', null,
  'nor a Team folder''s file on a whole-Space post');
select lives_ok($$insert into public.post_files (post_id, library_file_id)
                  values (pg_temp.id('b002'), pg_temp.id('f003'))$$,
  'a Team folder''s file on that Team''s post');
select lives_ok($$insert into public.post_files (post_id, library_file_id)
                  values (pg_temp.id('b001'), pg_temp.id('f004'))$$,
  'a whole-Space folder''s file on a post');

-- A work item's attachments, as its owner attaches them.
select pg_temp.as_user('a1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Fix the rebar', pg_temp.uid('b2'), p_id => pg_temp.id('c001'));
select throws_ok($$select public.attach_library_file(pg_temp.id('c001'), pg_temp.id('f001'))$$,
  '42501', null, 'a work item never carries an only-me file');
select throws_ok($$select public.attach_library_file(pg_temp.id('c001'), pg_temp.id('f002'))$$,
  '42501', null, 'nor a file from a person''s folder');
select lives_ok($$select public.attach_library_file(pg_temp.id('c001'), pg_temp.id('f005'))$$,
  'a top-level file attaches');
reset role;

-- So nobody but its owner ever opens the only-me file.
select pg_temp.as_user('b2');
set local role authenticated;
select is(public.can_open_library_file(pg_temp.id('f001')), false,
  'Rakesh can''t open Omar''s only-me file');
reset role;

select * from finish();
rollback;
