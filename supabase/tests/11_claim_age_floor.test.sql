-- Migration 11: the cleanup never claims files younger than a day.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

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

select * from finish();
rollback;
