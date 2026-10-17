-- LOCAL ONLY: the prototype's daybook (Figma D1 2518:33001, L1 2539:34633,
-- DY1 2541:34679), so every screen can be checked against its frame. Never
-- run on the live project, and not part of config.toml's automatic seed.
-- Run after a reset of the local database:
--   supabase db reset --local
--   docker exec -i supabase_db_BuildVibes_MVP psql -U postgres -d postgres -q < supabase/dev/seed_daybook.sql
--
-- Sign in with any of the emails below; the 6-digit code arrives in the
-- local mail catcher (Mailpit, http://127.0.0.1:54324). Every address is
-- @example.com, never a real one.
--   islam.ahmed@example.com   Islam Ahmed, BIM Manager: Space admin, Lead (D1)
--   sara.almutairi@example.com Sara Al-Mutairi, site engineer: Lead
--   omar.haddad@example.com   Omar Haddad, MEP foreman: Crew, MEP Team (L1)
--   rakesh.nair@example.com   Rakesh Nair, electrician: Crew, MEP Team
--   lina.khalil@example.com   Lina Khalil, architect: Crew
--   mona.adel@example.com     Mona Adel, client representative: Viewer (V1)
--   yousef.karam@example.com  Yousef Karam, foreman: asking to join
--
-- The Space "Kuwait City Tower — Site team" (reference prefix from its
-- project, KCT) has been on site since 40 days ago, so today is "day 41".
-- Posts are in English, as people wrote them; the app never translates
-- them. Times are on the Kuwait clock (the project's market).
--   Yesterday 11:20  Cable tray hangers, level 4: Islam for Omar, due
--                    yesterday, open: Late by 1 day on Omar's daybook (L1).
--   Yesterday 16:20  Gate 3 access cleared for the pump truck: Islam for
--                    Omar, signed and checked (DY1).
--   Today 08:14      Sleeves at grid C7 before the pour: Islam for Omar,
--                    signed as done, waiting for Islam's check (D1).
--   Today 10:05      Rebar spacing, level 3 slab: Sara for Islam, due today
--                    at 14:00, moved from next Thursday (D1), so it is on
--                    Islam's "Due today" strip until 14:00.
\set ON_ERROR_STOP on
begin;

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, raw_app_meta_data, confirmation_token, recovery_token,
  email_change_token_new, email_change, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', u.id::uuid, 'authenticated', 'authenticated',
       u.email, now(), '{"home_market_id": "kw", "locale": "en"}',
       '{"provider": "email", "providers": ["email"]}', '', '', '', '', now(), now()
from (values
  ('dbdb0000-0000-0000-0000-000000000001', 'islam.ahmed@example.com'),
  ('dbdb0000-0000-0000-0000-000000000002', 'sara.almutairi@example.com'),
  ('dbdb0000-0000-0000-0000-000000000003', 'omar.haddad@example.com'),
  ('dbdb0000-0000-0000-0000-000000000004', 'rakesh.nair@example.com'),
  ('dbdb0000-0000-0000-0000-000000000005', 'lina.khalil@example.com'),
  ('dbdb0000-0000-0000-0000-000000000006', 'mona.adel@example.com'),
  ('dbdb0000-0000-0000-0000-000000000007', 'yousef.karam@example.com')
) as u (id, email);
insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at, last_sign_in_at)
select gen_random_uuid(), u.id, u.id::text,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
from auth.users u where u.id::text like 'dbdb0000-%';

update public.profiles p set first_name = v.first_name, last_name = v.last_name,
  trade_id = v.trade_id, headline = v.headline
from (values
  ('dbdb0000-0000-0000-0000-000000000001', 'Islam', 'Ahmed', 'bim_specialist', 'BIM Manager'),
  ('dbdb0000-0000-0000-0000-000000000002', 'Sara', 'Al-Mutairi', 'site_engineer', null),
  ('dbdb0000-0000-0000-0000-000000000003', 'Omar', 'Haddad', 'foreman', 'MEP Foreman'),
  ('dbdb0000-0000-0000-0000-000000000004', 'Rakesh', 'Nair', 'electrician', null),
  ('dbdb0000-0000-0000-0000-000000000005', 'Lina', 'Khalil', 'architect', null),
  ('dbdb0000-0000-0000-0000-000000000006', 'Mona', 'Adel', 'other', 'Client representative'),
  ('dbdb0000-0000-0000-0000-000000000007', 'Yousef', 'Karam', 'foreman', null)
) as v (id, first_name, last_name, trade_id, headline)
where p.id = v.id::uuid;

-- As Islam: the project, the Space and its day 1 on site.
select set_config('request.jwt.claims', '{"sub": "dbdb0000-0000-0000-0000-000000000001", "role": "authenticated"}', false);
set role authenticated;
select set_config('seed.project', public.create_project('Kuwait City Tower', 'commercial', 'kw', 'kw-capital')::text, false);
select set_config('seed.space', public.create_space('Kuwait City Tower — Site team',
  'Daily site work for the structure and MEP crews.', current_setting('seed.project')::uuid)::text, false);
select public.set_site_start_date(current_setting('seed.space')::uuid, current_date - 40);
reset role;

-- The team, confirmed by Islam; Yousef waits for his yes.
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select current_setting('seed.space')::uuid, m.id::uuid, m.pass, 'dbdb0000-0000-0000-0000-000000000001'
from (values
  ('dbdb0000-0000-0000-0000-000000000002', 'lead'),
  ('dbdb0000-0000-0000-0000-000000000003', 'crew'),
  ('dbdb0000-0000-0000-0000-000000000004', 'crew'),
  ('dbdb0000-0000-0000-0000-000000000005', 'crew'),
  ('dbdb0000-0000-0000-0000-000000000006', 'viewer')
) as m (id, pass);
insert into public.space_join_requests (space_id, profile_id, via, invited_by)
values (current_setting('seed.space')::uuid, 'dbdb0000-0000-0000-0000-000000000007', 'code',
        'dbdb0000-0000-0000-0000-000000000003');

set role authenticated;
select set_config('seed.team', public.create_team(current_setting('seed.space')::uuid, 'MEP Team',
  array['dbdb0000-0000-0000-0000-000000000003', 'dbdb0000-0000-0000-0000-000000000004']::uuid[])::text, false);

-- As Islam: three work items for Omar.
select set_config('seed.trays', public.create_work_item(
  p_space => current_setting('seed.space')::uuid,
  p_title => 'Cable tray hangers, level 4',
  p_owner => 'dbdb0000-0000-0000-0000-000000000003',
  p_due => current_date - 1)::text, false);
select set_config('seed.gate', public.create_work_item(
  p_space => current_setting('seed.space')::uuid,
  p_title => 'Gate 3 access cleared for the pump truck',
  p_owner => 'dbdb0000-0000-0000-0000-000000000003',
  p_due => current_date - 1,
  p_place => 'Gate 3',
  p_points => '[{"text": "Cones moved clear of the gate"}, {"text": "Banksman at the gate"}]')::text, false);
select set_config('seed.sleeves', public.create_work_item(
  p_space => current_setting('seed.space')::uuid,
  p_title => 'Sleeves at grid C7 before the pour',
  p_owner => 'dbdb0000-0000-0000-0000-000000000003',
  p_due => current_date,
  p_place => 'Level 2, grid C7',
  p_points => '[{"text": "Six sleeves fixed"}, {"text": "Checked with MEP"}]')::text, false);

-- As Sara: one for Islam, due next Thursday, then moved to today at 14:00.
select set_config('request.jwt.claims', '{"sub": "dbdb0000-0000-0000-0000-000000000002", "role": "authenticated"}', false);
select set_config('seed.rebar', public.create_work_item(
  p_space => current_setting('seed.space')::uuid,
  p_title => 'Rebar spacing, level 3 slab',
  p_owner => 'dbdb0000-0000-0000-0000-000000000001',
  p_due => current_date + (10 - extract(dow from current_date)::int) % 7 + 1)::text, false);
select public.edit_space_post(current_setting('seed.rebar')::uuid, jsonb_build_object(
  'due', current_date,
  'due_at', (current_date + time '14:00') at time zone 'Asia/Kuwait'));

-- As Omar: signs the gate and the sleeves.
select set_config('request.jwt.claims', '{"sub": "dbdb0000-0000-0000-0000-000000000003", "role": "authenticated"}', false);
select public.sign_done(current_setting('seed.gate')::uuid, 'Gate clear, cones moved.');
select public.sign_done(current_setting('seed.sleeves')::uuid, 'All six fixed and checked with MEP.');
-- As Islam, the author: checks the gate.
select set_config('request.jwt.claims', '{"sub": "dbdb0000-0000-0000-0000-000000000001", "role": "authenticated"}', false);
select public.check_item(current_setting('seed.gate')::uuid);
reset role;

-- The prototype's times on the spine (the functions stamp "now").
update public.space_posts p set created_at = v.at
from (values
  (current_setting('seed.trays'), (current_date - 1 + time '11:20') at time zone 'Asia/Kuwait'),
  (current_setting('seed.gate'), (current_date - 1 + time '16:20') at time zone 'Asia/Kuwait'),
  (current_setting('seed.sleeves'), (current_date + time '08:14') at time zone 'Asia/Kuwait'),
  (current_setting('seed.rebar'), (current_date + time '10:05') at time zone 'Asia/Kuwait')
) as v (id, at)
where p.id = v.id::uuid;
update public.work_items w set created_at = p.created_at
from public.space_posts p where p.id = w.id and p.space_id = current_setting('seed.space')::uuid;
commit;

select w.ref, w.status, p.title, p.due_date, p.due_at, p.created_at
from public.work_items w join public.space_posts p on p.id = w.id
where p.space_id = current_setting('seed.space')::uuid
order by p.created_at;
