-- Migration 11: the cleanup age floor, and sharing Library files in chat.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000011c1', 'authenticated', 'authenticated', 'omar11@example.com', '{"home_market_id": "kw"}');
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000011c1", "role": "authenticated"}', true);
set local role authenticated;
select set_config('test.space', public.create_space('Site team', null, null)::text, true);
reset role;

insert into storage.objects (bucket_id, name, owner_id, metadata, created_at)
select 'space-files', current_setting('test.space') || '/' || gen_random_uuid() || '/' || f.name,
       '00000000-0000-0000-0000-0000000011c1',
       '{"mimetype": "image/jpeg", "size": 100}'::jsonb, now() - f.age
from (values ('hour.jpg', interval '1 hour'), ('twodays.jpg', interval '2 days')) as f(name, age);

set local role service_role;
select is((select count(*) from public.claim_orphan_files(interval '0 seconds')), 1::bigint,
  'asking for any age still skips files younger than a day');
select ok((select storage_path from public.file_cleanup_claims) like '%/twodays.jpg',
  'only the two-day-old file is claimed');
select is((select count(*) from public.claim_orphan_files()), 0::bigint,
  'by default (7 days) a two-day-old file is not claimed');
reset role;

-- Sharing a Library file in chat ------------------------------------------------------

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000011c2', 'authenticated', 'authenticated', 'rakesh11@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000011c3', 'authenticated', 'authenticated', 'eve11@example.com', '{"home_market_id": "kw"}');
insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (current_setting('test.space')::uuid, '00000000-0000-0000-0000-0000000011c2', 'crew', '00000000-0000-0000-0000-0000000011c1'),
  (current_setting('test.space')::uuid, '00000000-0000-0000-0000-0000000011c3', 'crew', '00000000-0000-0000-0000-0000000011c1');
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000011c1", "role": "authenticated"}', true);
set local role authenticated;
select set_config('test.team', public.create_team(current_setting('test.space')::uuid, 'MEP Team',
  array['00000000-0000-0000-0000-0000000011c2']::uuid[])::text, true);
reset role;
select set_config('test.everyone', (select id from public.threads
  where space_id = current_setting('test.space')::uuid and team_id is null)::text, true);

-- Omar adds an Everyone drawing and a MEP Team file to the Library.
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('space-files', current_setting('test.space') || '/library/00000000-0000-0000-0000-00000011f001/plan.pdf',
   '00000000-0000-0000-0000-0000000011c1', '{"mimetype": "application/pdf", "size": 1000}'),
  ('space-files', current_setting('test.space') || '/library/00000000-0000-0000-0000-00000011f002/mep.pdf',
   '00000000-0000-0000-0000-0000000011c1', '{"mimetype": "application/pdf", "size": 1000}');
set local role authenticated;
select public.add_library_file('00000000-0000-0000-0000-00000011f001', current_setting('test.space')::uuid,
  'Level 3 plan.pdf', current_setting('test.space') || '/library/00000000-0000-0000-0000-00000011f001/plan.pdf',
  'application/pdf', 1000);
select public.add_library_file('00000000-0000-0000-0000-00000011f002', current_setting('test.space')::uuid,
  'MEP risers.pdf', current_setting('test.space') || '/library/00000000-0000-0000-0000-00000011f002/mep.pdf',
  'application/pdf', 1000, current_setting('test.team')::uuid);

-- Eve (Crew, not in the MEP Team) shares the Everyone drawing.
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000011c3", "role": "authenticated"}', true);
select is(public.share_library_file('00000000-0000-0000-0000-00000011a001',
  current_setting('test.everyone')::uuid, '00000000-0000-0000-0000-00000011f001', 'Rev C is here'),
  '00000000-0000-0000-0000-00000011a001'::uuid, 'a member shares an Everyone file in Everyone');
select is(public.share_library_file('00000000-0000-0000-0000-00000011a001',
  current_setting('test.everyone')::uuid, '00000000-0000-0000-0000-00000011f001', 'Rev C is here'),
  '00000000-0000-0000-0000-00000011a001'::uuid, 'a retry returns the same message');
select is((select row(kind, library_file_id::text)::text from public.messages
           where id = '00000000-0000-0000-0000-00000011a001'),
  '(file,00000000-0000-0000-0000-00000011f001)', 'the message points at the Library file');
select is((select count(*) from public.library_files where name = 'Level 3 plan.pdf'), 1::bigint,
  'no second copy in the Library');
select throws_ok(format($q$select public.share_library_file(gen_random_uuid(), %L, '00000000-0000-0000-0000-00000011f002')$q$,
  current_setting('test.everyone')), '42501', null,
  'Eve can''t see the MEP Team file, so she can''t share it');

-- Omar (admin) may see it, but a Team file stays in its Team's thread.
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000011c1", "role": "authenticated"}', true);
select throws_ok(format($q$select public.share_library_file(gen_random_uuid(), %L, '00000000-0000-0000-0000-00000011f002')$q$,
  current_setting('test.everyone')), '22023', 'a Team file can only be shared in that Team''s thread',
  'a Team file is never shared in Everyone');
reset role;

select * from finish();
rollback;
