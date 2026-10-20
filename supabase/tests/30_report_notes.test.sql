-- Migration 30: notes in the daily report (review 63). Run with: supabase test db
--
-- Omar (f1) made the Space and is its admin. Rakesh (f2) and Sara (f3) are
-- Crew, Tariq (f9) Crew in the MEP Team. Eve (f5) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000030' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@reportnotes30.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('f1'), ('f2'), ('f3'), ('f5'), ('f9')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('f1', 'Omar', 'Haddad'), ('f2', 'Rakesh', 'Nair'), ('f3', 'Sara', 'Ali'),
             ('f5', 'Eve', 'Out'), ('f9', 'Tariq', 'Aziz')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000030' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000030' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000030' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000030' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
create function pg_temp.b(p_id text, p_type text, p_rest jsonb default '{}') returns jsonb
language sql as $$
  select jsonb_build_object('id', pg_temp.item(p_id), 'type', p_type) || p_rest;
$$;
create function pg_temp.post_path(p_item text, p_file text) returns text language sql as $$
  select pg_temp.sp() || '/posts/' || pg_temp.item(p_item) || '/' || p_file;
$$;
create function pg_temp.upload(p_name text, p_owner text, p_mime text) returns void language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('space-files', p_name, pg_temp.uid(p_owner)::text,
          jsonb_build_object('mimetype', p_mime, 'size', 120000));
$$;
-- Today's notes for the report, by post id, as the caller.
create function pg_temp.notes(p_team uuid) returns uuid[] language sql as $$
  select coalesce(array_agg(n.post_id order by n.created_at), '{}')
  from public.daily_report_notes(pg_temp.sp(), p_team,
         date_trunc('day', now()), date_trunc('day', now()) + interval '1 day') n;
$$;
create function pg_temp.report(p_id text, p_team uuid, p_ref text) returns uuid language sql as $$
  select public.create_space_post(pg_temp.item(p_id || '00'), pg_temp.sp(), 'report', 'Today', p_team => p_team,
           p_template => '00000000-0000-4000-8000-0000000d0001',
           p_blocks => jsonb_build_array(
             pg_temp.b(p_id || '01', 'heading', '{"text": "On site"}'),
             pg_temp.b(p_id || '02', 'item_ref', jsonb_build_object('post_id', pg_temp.item(p_ref)))));
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('f1');
set local role authenticated;
select set_config('test.space', public.create_space('Report site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('f1')
from (values ('f2', 'crew'), ('f3', 'crew'), ('f9', 'crew')) x(id, pass);
select pg_temp.as_user('f1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('f9')])::text, true);
reset role;
select pg_temp.upload(pg_temp.post_path('b001', 'wall.jpg'), 'f2', 'image/jpeg');
select pg_temp.upload(pg_temp.post_path('b001', 'letter.pdf'), 'f2', 'application/pdf');

select pg_temp.as_user('f2');
set local role authenticated;
select lives_ok(format($$select public.create_space_post(pg_temp.item('b001'), pg_temp.sp(), 'note',
                    'Water on level 2', p_files => %L)$$,
                    jsonb_build_array(jsonb_build_object('path', pg_temp.post_path('b001', 'letter.pdf')),
                                      jsonb_build_object('path', pg_temp.post_path('b001', 'wall.jpg')))),
  'Rakesh posts a note with a letter and a photo');
select public.create_space_post(pg_temp.item('b002'), pg_temp.sp(), 'note', 'Scaffold moved');
select public.create_space_post(pg_temp.item('b003'), pg_temp.sp(), 'note', 'Posted twice');
select public.cancel_space_post(pg_temp.item('b003'), 'Posted twice');
select public.create_space_post(pg_temp.item('b004'), pg_temp.sp(), 'note', 'Yesterday''s note');
select public.create_space_post(pg_temp.item('b005'), pg_temp.sp(), 'announcement', 'Not a note');
select pg_temp.as_user('f9');
select public.create_space_post(pg_temp.item('b006'), pg_temp.sp(), 'note', 'Panel B is live',
                                p_team => pg_temp.team());
reset role;
update public.space_posts set created_at = now() - interval '1 day 1 minute'
where id = pg_temp.item('b004');
update public.space_posts set created_at = now() - interval '1 minute'
where id = pg_temp.item('b001');

-- daily_report_notes ------------------------------------------------------------------------

select pg_temp.as_user('f3');
set local role authenticated;
select is(pg_temp.notes(null), array[pg_temp.item('b001'), pg_temp.item('b002')],
  'today''s live notes, oldest first: not cancelled ones, not yesterday''s, no other kind');
select is((select n.photo_path from public.daily_report_notes(pg_temp.sp(), null,
             date_trunc('day', now()), date_trunc('day', now()) + interval '1 day') n
           where n.post_id = pg_temp.item('b001')),
  pg_temp.post_path('b001', 'wall.jpg'), 'with its first photo, never a PDF');
select is((select n.author_name || ' / ' || n.title from public.daily_report_notes(pg_temp.sp(), null,
             date_trunc('day', now()), date_trunc('day', now()) + interval '1 day') n
           where n.post_id = pg_temp.item('b001')),
  'Rakesh Nair / Water on level 2', 'and its author and title');
select is((select n.photo_path from public.daily_report_notes(pg_temp.sp(), null,
             date_trunc('day', now()), date_trunc('day', now()) + interval '1 day') n
           where n.post_id = pg_temp.item('b002')), null, 'a note without a photo has none');

select pg_temp.as_user('f1');
select ok(not (pg_temp.item('b006') = any (pg_temp.notes(null))),
  'an Everyone report never brings in a Team''s note, even for an admin');
select ok(pg_temp.item('b006') = any (pg_temp.notes(pg_temp.team())), 'a Team report does');
select pg_temp.as_user('f3');
select ok(not (pg_temp.item('b006') = any (pg_temp.notes(pg_temp.team()))),
  'naming a Team doesn''t show its note to someone outside it');
select pg_temp.as_user('f5');
select is(pg_temp.notes(null), '{}'::uuid[], 'a non-member gets nothing');
select pg_temp.as_user('f3');
select throws_ok($$select * from public.daily_report_notes(pg_temp.sp(), null, now(), now() + interval '2 days')$$,
  '22023', null, 'one day at a time');

-- A block hides the name, as everywhere in a Space.
select pg_temp.as_user('f3');
select public.block(pg_temp.uid('f2'), true);
select is((select n.author_name from public.daily_report_notes(pg_temp.sp(), null,
             date_trunc('day', now()), date_trunc('day', now()) + interval '1 day') n
           where n.post_id = pg_temp.item('b001')), null, 'across a block the note stays, without the name');
select public.block(pg_temp.uid('f2'), false);

-- A note in the report --------------------------------------------------------------------------

select pg_temp.as_user('f3');
select lives_ok($$select pg_temp.report('c1', null, 'b001')$$, 'Sara''s report points at Rakesh''s note');
select is(public.post_page(pg_temp.item('c100')) -> 'refs' -> pg_temp.item('b001')::text ->> 'kind', 'note',
  'the ref says it is a note');
select is(public.post_page(pg_temp.item('c100')) -> 'refs' -> pg_temp.item('b001')::text ->> 'author_name',
  'Rakesh Nair', 'with its author');
select is(public.post_page(pg_temp.item('c100')) -> 'refs' -> pg_temp.item('b001')::text ->> 'photo_path',
  pg_temp.post_path('b001', 'wall.jpg'), 'and its first photo');
select ok(not (public.post_page(pg_temp.item('c100')) -> 'refs' -> pg_temp.item('b001')::text ? 'item_status'),
  'and no work item fields');
select throws_ok($$select pg_temp.report('c2', null, 'b005')$$, '22023',
  'a work item or note this report''s readers can see',
  'an announcement can''t be a ref');
select throws_ok($$select pg_temp.report('c3', null, 'b006')$$, '22023',
  'a work item or note this report''s readers can see',
  'an Everyone report can''t point at a Team''s note');
select pg_temp.as_user('f9');
select lives_ok($$select pg_temp.report('c4', pg_temp.team(), 'b006')$$, 'a Team report can');
select pg_temp.as_user('f3');
select is(public.post_page(pg_temp.item('c400')), null, 'and Sara, outside the Team, sees neither');

-- Cancelled after the report: the ref says so.
select pg_temp.as_user('f2');
select public.cancel_space_post(pg_temp.item('b001'), 'Wrong level');
select pg_temp.as_user('f3');
select is(public.post_page(pg_temp.item('c100')) -> 'refs' -> pg_temp.item('b001')::text ->> 'status', 'cancelled',
  'a note cancelled after the report shows as cancelled in it');

reset role;
select ok(not has_function_privilege('anon', 'public.daily_report_notes(uuid, uuid, timestamptz, timestamptz)', 'execute')
          and has_function_privilege('authenticated', 'public.daily_report_notes(uuid, uuid, timestamptz, timestamptz)', 'execute')
          and not has_function_privilege('authenticated', 'public.post_cover_path(uuid)', 'execute'),
  'the notes list is for signed-in people; the cover helper is internal');

select * from finish();
rollback;
