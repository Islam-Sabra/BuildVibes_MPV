-- LOCAL ONLY (review 121): the frames' Space, "NBKCH Site", with its key
-- people and three Teams, Ali and Hassan in two of them. Never run on the
-- live project, and not part of config.toml's automatic seed. Run on the
-- local database (after a reset, or next to the other dev seeds; its ids
-- are its own):
--   docker exec -i supabase_db_BuildVibes_MVP psql -U postgres -d postgres -q < supabase/dev/seed_key_people.sql
--
-- Sign in with one of these; the 6-digit code arrives in the local mail
-- catcher (Mailpit). Every address is @example.com, never a real one.
--   kp.admin@example.com   Islam Sabra: Space admin (KP3, KP4)
--   kp.new@example.com     Nabil Hamdan: Crew, just let in (KP2, KP1, OC1)
--   kp.khalid@example.com  Khalid Al-Mansour: Safety officer, shows his number
--                          to his Spaces (Call)
\set ON_ERROR_STOP on
begin;

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, raw_app_meta_data, confirmation_token, recovery_token,
  email_change_token_new, email_change, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', ('c1210000-0000-0000-0000-0000000000' || u.n)::uuid,
       'authenticated', 'authenticated', u.email, now(), '{"home_market_id": "kw", "locale": "en"}',
       '{"provider": "email", "providers": ["email"]}', '', '', '', '', now(), now()
from (values
  ('01', 'kp.admin@example.com'), ('02', 'kp.khalid@example.com'),
  ('03', 'kp.omar@example.com'), ('04', 'kp.rakesh@example.com'),
  ('05', 'kp.ali@example.com'), ('06', 'kp.hassan@example.com'),
  ('07', 'kp.tariq@example.com'), ('08', 'kp.mona@example.com'),
  ('09', 'kp.joseph@example.com'), ('10', 'kp.sami@example.com'),
  ('11', 'kp.new@example.com')
) as u (n, email);
insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at, last_sign_in_at)
select gen_random_uuid(), u.id, u.id::text,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
from auth.users u where u.id::text like 'c1210000-%';

update public.profiles p set first_name = v.f, last_name = v.l, headline = v.h,
  company_name_text = v.c
from (values
  ('01', 'Islam', 'Sabra', 'BIM manager', 'AECOX'),
  ('02', 'Khalid', 'Al-Mansour', 'Safety', 'NBKCH'),
  ('03', 'Omar', 'Haddad', 'Project engineer', 'NBKCH'),
  ('04', 'Rakesh', 'Nair', 'MEP engineer', 'Gulf MEP'),
  ('05', 'Ali', 'Saleh', 'Electrician', 'Gulf MEP'),
  ('06', 'Hassan', 'Karim', 'Foreman', 'Gulf MEP'),
  ('07', 'Tariq', 'Rahman', 'Safety', 'NBKCH'),
  ('08', 'Mona', 'Adel', 'Surveyor', 'NBKCH'),
  ('09', 'Joseph', 'Mathew', 'Plumber', 'Gulf MEP'),
  ('10', 'Sami', 'Youssef', 'Carpenter', 'NBKCH'),
  ('11', 'Nabil', 'Hamdan', 'Steel fixer', 'NBKCH')
) as v (n, f, l, h, c)
where p.id = ('c1210000-0000-0000-0000-0000000000' || v.n)::uuid;
-- Khalid's number, shown to his Spaces (NUM1); Tariq's to nobody.
update public.profiles set phone = '+96555123456', phone_visibility = 'spaces'
where id = 'c1210000-0000-0000-0000-000000000002';
update public.profiles set phone = '+96566123456'
where id = 'c1210000-0000-0000-0000-000000000007';

select set_config('request.jwt.claims', '{"sub": "c1210000-0000-0000-0000-000000000001", "role": "authenticated"}', false);
set role authenticated;
select set_config('kp.project', public.create_project('NBKCH Site', 'commercial', 'kw', 'kw-capital')::text, false);
select set_config('kp.space', public.create_space('NBKCH Site', null, current_setting('kp.project')::uuid)::text, false);
reset role;

-- Everyone but Nabil has seen Who to call; Nabil was just let in (KP2).
insert into public.space_members (space_id, profile_id, pass, confirmed_by, key_people_seen_at)
select current_setting('kp.space')::uuid, ('c1210000-0000-0000-0000-0000000000' || m.n)::uuid, m.pass,
       'c1210000-0000-0000-0000-000000000001', case when m.n = '11' then null else now() end
from (values ('02', 'crew'), ('03', 'lead'), ('04', 'lead'), ('05', 'crew'), ('06', 'crew'),
             ('07', 'crew'), ('08', 'crew'), ('09', 'crew'), ('10', 'crew'), ('11', 'crew')) as m (n, pass);

set role authenticated;
select public.set_team_admin(public.create_team(current_setting('kp.space')::uuid, 'Civil',
  array['c1210000-0000-0000-0000-000000000003', 'c1210000-0000-0000-0000-000000000006',
        'c1210000-0000-0000-0000-000000000008', 'c1210000-0000-0000-0000-000000000010']::uuid[]),
  'c1210000-0000-0000-0000-000000000003');
select public.set_team_admin(public.create_team(current_setting('kp.space')::uuid, 'Gulf MEP',
  array['c1210000-0000-0000-0000-000000000004', 'c1210000-0000-0000-0000-000000000005',
        'c1210000-0000-0000-0000-000000000009', 'c1210000-0000-0000-0000-000000000006']::uuid[]),
  'c1210000-0000-0000-0000-000000000004');
select public.set_team_admin(public.create_team(current_setting('kp.space')::uuid, 'Night shift',
  array['c1210000-0000-0000-0000-000000000002', 'c1210000-0000-0000-0000-000000000007',
        'c1210000-0000-0000-0000-000000000005', 'c1210000-0000-0000-0000-000000000006',
        'c1210000-0000-0000-0000-000000000008']::uuid[]),
  'c1210000-0000-0000-0000-000000000002');
select public.save_key_role(current_setting('kp.space')::uuid, null, 'Safety officer',
  'hazards, accidents, work permits',
  '[{"profile_id": "c1210000-0000-0000-0000-000000000002", "note": "Day shift"},
    {"profile_id": "c1210000-0000-0000-0000-000000000007", "note": "Night shift"}]');
select public.save_key_role(current_setting('kp.space')::uuid, null, 'Project engineer',
  'drawings, method statements, site changes',
  '[{"profile_id": "c1210000-0000-0000-0000-000000000003"}]');
reset role;

commit;
