-- LOCAL ONLY: the starting point of the end-to-end test
-- (integration_test/main_journey_test.dart). Never run on the live project.
-- Run after `supabase db reset --local` (integration_test/run_e2e.ps1 does both):
--   docker exec -i supabase_db_BuildVibes_MVP psql -U postgres -d postgres -q < supabase/dev/seed_e2e.sql
--
-- Omar (96550000001) runs the Space "E2E site", whose invite code is E2ETST.
-- Rakesh (96550000003) is outside it. Both are onboarded. Code 123456 for
-- both (supabase/config.toml, [auth.sms.test_otp]).
\set ON_ERROR_STOP on
begin;
insert into auth.users (instance_id, id, aud, role, phone, phone_confirmed_at,
  raw_user_meta_data, raw_app_meta_data, confirmation_token, recovery_token,
  email_change_token_new, email_change, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '22222222-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
   '96550000001', now(), '{"home_market_id": "kw", "locale": "en"}', '{"provider": "phone", "providers": ["phone"]}', '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '22222222-0000-0000-0000-000000000003', 'authenticated', 'authenticated',
   '96550000003', now(), '{"home_market_id": "kw", "locale": "en"}', '{"provider": "phone", "providers": ["phone"]}', '', '', '', '', now(), now());
insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at, last_sign_in_at)
select gen_random_uuid(), u.id, u.id::text, jsonb_build_object('sub', u.id::text, 'phone', u.phone), 'phone', now(), now(), now()
from auth.users u where u.id::text like '22222222-%';

update public.profiles set first_name = 'Omar', last_name = 'Haddad', trade_id = 'site_engineer'
where id = '22222222-0000-0000-0000-000000000001';
update public.profiles set first_name = 'Rakesh', last_name = 'Nair', trade_id = 'foreman'
where id = '22222222-0000-0000-0000-000000000003';

-- As Omar: the Space.
select set_config('request.jwt.claims', '{"sub": "22222222-0000-0000-0000-000000000001", "role": "authenticated"}', false);
set role authenticated;
select set_config('seed.space', public.create_space('E2E site', 'The end-to-end test Space.', null)::text, false);
reset role;

-- A known invite code instead of a random one.
delete from public.space_invites where space_id = current_setting('seed.space')::uuid;
insert into public.space_invites (space_id, code, created_by)
values (current_setting('seed.space')::uuid, 'E2ETST', '22222222-0000-0000-0000-000000000001');
commit;
