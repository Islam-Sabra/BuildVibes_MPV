-- LOCAL ONLY: test data for week 5 screenshots on this computer (migration 7
-- is not live). Never run on the live project. Run after `supabase db reset`:
--   docker exec -i supabase_db_BuildVibes_MVP psql -U postgres -d postgres -q < supabase/dev/seed_work_items.sql
-- Test numbers 96550000001 (Omar), 96550000002 (Sami), 96550000003 (Rakesh), code 123456.
-- `supabase test db` expects an empty database: run `supabase db reset` first.
\set ON_ERROR_STOP on
begin;
insert into auth.users (instance_id, id, aud, role, phone, phone_confirmed_at,
  raw_user_meta_data, raw_app_meta_data, confirmation_token, recovery_token,
  email_change_token_new, email_change, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '11111111-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
   '96550000001', now(), '{"home_market_id": "kw", "locale": "en"}', '{"provider": "phone", "providers": ["phone"]}', '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '11111111-0000-0000-0000-000000000002', 'authenticated', 'authenticated',
   '96550000002', now(), '{"home_market_id": "kw", "locale": "en"}', '{"provider": "phone", "providers": ["phone"]}', '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '11111111-0000-0000-0000-000000000003', 'authenticated', 'authenticated',
   '96550000003', now(), '{"home_market_id": "kw", "locale": "en"}', '{"provider": "phone", "providers": ["phone"]}', '', '', '', '', now(), now());
insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at, last_sign_in_at)
select gen_random_uuid(), u.id, u.id::text, jsonb_build_object('sub', u.id::text, 'phone', u.phone), 'phone', now(), now(), now()
from auth.users u where u.id::text like '11111111-%';

update public.profiles set first_name = 'Omar', last_name = 'Haddad', trade_id = 'site_engineer'
where id = '11111111-0000-0000-0000-000000000001';
update public.profiles set first_name = 'Sami', last_name = 'Al-Mansour', trade_id = 'bim_specialist', headline = 'BIM Manager'
where id = '11111111-0000-0000-0000-000000000002';
update public.profiles set first_name = 'Rakesh', last_name = 'Nair', trade_id = 'foreman', headline = 'MEP Foreman'
where id = '11111111-0000-0000-0000-000000000003';

-- As Omar: the project and the Space.
select set_config('request.jwt.claims', '{"sub": "11111111-0000-0000-0000-000000000001", "role": "authenticated"}', false);
set role authenticated;
select set_config('seed.project', public.create_project('Kuwait City Tower', 'commercial', 'kw', 'kw-capital')::text, false);
select set_config('seed.space', public.create_space('Site team', 'Daily site work for the structure and MEP crews.',
  current_setting('seed.project')::uuid)::text, false);
reset role;

insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (current_setting('seed.space')::uuid, '11111111-0000-0000-0000-000000000002', 'lead', '11111111-0000-0000-0000-000000000001'),
  (current_setting('seed.space')::uuid, '11111111-0000-0000-0000-000000000003', 'crew', '11111111-0000-0000-0000-000000000001');

set role authenticated;
select set_config('seed.team', public.create_team(current_setting('seed.space')::uuid, 'MEP Team',
  array['11111111-0000-0000-0000-000000000003']::uuid[])::text, false);
select set_config('seed.structure', public.create_team(current_setting('seed.space')::uuid, 'Structure',
  array['11111111-0000-0000-0000-000000000001']::uuid[])::text, false);

-- As Sami (Lead): KCT-001 for Omar, then KCT-003 and KCT-004 for Rakesh.
select set_config('request.jwt.claims', '{"sub": "11111111-0000-0000-0000-000000000002", "role": "authenticated"}', false);
select public.create_work_item(current_setting('seed.space')::uuid, 'Confirm level 3 beam schedule Rev C',
  '11111111-0000-0000-0000-000000000001', current_date + 1, current_setting('seed.structure')::uuid, 'Level 3 · all grids');
-- As Omar: KCT-002 for Rakesh.
select set_config('request.jwt.claims', '{"sub": "11111111-0000-0000-0000-000000000001", "role": "authenticated"}', false);
select set_config('seed.i2', public.create_work_item(current_setting('seed.space')::uuid, 'Sleeves at grid C7 before the pour',
  '11111111-0000-0000-0000-000000000003', current_date + 2, current_setting('seed.team')::uuid, 'Level 2 · Grid C7')::text, false);
select set_config('request.jwt.claims', '{"sub": "11111111-0000-0000-0000-000000000002", "role": "authenticated"}', false);
select public.create_work_item(current_setting('seed.space')::uuid, 'Photos of upstands before the second coat',
  '11111111-0000-0000-0000-000000000003', current_date + 3, current_setting('seed.team')::uuid, 'Level 1 · north wall');
select set_config('seed.i4', public.create_work_item(current_setting('seed.space')::uuid, 'Shoring removal sequence, level 2',
  '11111111-0000-0000-0000-000000000003', current_date - 1, null, 'Level 2 · bays 1-4')::text, false);
-- As Omar: KCT-005 for Rakesh, to be checked by Omar (its author).
select set_config('request.jwt.claims', '{"sub": "11111111-0000-0000-0000-000000000001", "role": "authenticated"}', false);
select set_config('seed.i5', public.create_work_item(current_setting('seed.space')::uuid, 'Gate 3 access cleared for the pump truck',
  '11111111-0000-0000-0000-000000000003', null, null, 'Site · gate 3')::text, false);

-- As Rakesh: signs KCT-002 and KCT-005 as done.
select set_config('request.jwt.claims', '{"sub": "11111111-0000-0000-0000-000000000003", "role": "authenticated"}', false);
select public.sign_done(current_setting('seed.i2')::uuid, 'Sleeves fixed and checked with MEP', '[]');
select public.sign_done(current_setting('seed.i5')::uuid, 'Gate cleared, cones moved', '[]');
-- As Omar, its author: checks KCT-005 (only the author checks, migration 18).
select set_config('request.jwt.claims', '{"sub": "11111111-0000-0000-0000-000000000001", "role": "authenticated"}', false);
select public.check_item(current_setting('seed.i5')::uuid);
reset role;
commit;
select ref, status, title from public.work_items order by number;
