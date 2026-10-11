-- Migration 3: sign-up gate and onboarding reference data (task 9).
-- Design: docs/design/entry/README.md (E2p, E9, E9b).
--
-- 1. Who can create an account: a phone number from a live market, or
--    anyone holding a valid Space invite (whatever their phone country), or
--    an email sign-up. Existing accounts always sign in.
-- 2. Trades grouped as in the role picker (E9b), with a short description
--    each, and a "popular in {country}" list per market.
-- 3. A person's home market must be a live market.

-- ---------------------------------------------------------------------------
-- 1. Sign-up gate (Supabase Auth hook "before user created")
-- ---------------------------------------------------------------------------

-- Space invites arrive with migration 4 (space_invites). Until then no code
-- is valid, so the invite path is ready but closed.
create or replace function public.is_valid_invite_code(p_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select false;
$$;

-- True when [p_phone] (E.164 digits, with or without "+") belongs to a live
-- market.
create or replace function public.is_live_market_phone(p_phone text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.markets m
    where m.status = 'live'
      and ltrim(coalesce(p_phone, ''), '+') like ltrim(m.dial_code, '+') || '%'
  );
$$;

create or replace function public.hook_before_user_created(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_phone text := nullif(event -> 'user' ->> 'phone', '');
  v_invite text := nullif(event -> 'user' -> 'user_metadata' ->> 'invite_code', '');
begin
  -- Email sign-ups pick a live home market during onboarding.
  if v_phone is null then
    return '{}'::jsonb;
  end if;
  if public.is_live_market_phone(v_phone) then
    return '{}'::jsonb;
  end if;
  if v_invite is not null and public.is_valid_invite_code(v_invite) then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object(
    'error', jsonb_build_object(
      'http_code', 403,
      'message', 'signup_not_open_for_country'
    )
  );
end;
$$;

revoke execute on function
  public.is_valid_invite_code(text),
  public.is_live_market_phone(text),
  public.hook_before_user_created(jsonb)
  from public, anon, authenticated;
grant execute on function public.hook_before_user_created(jsonb)
  to supabase_auth_admin;
grant usage on schema public to supabase_auth_admin;

-- New users: only take a home market from sign-up if it is live.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_locale text := new.raw_user_meta_data ->> 'locale';
  v_market text := new.raw_user_meta_data ->> 'home_market_id';
begin
  if v_locale is null or v_locale not in ('en', 'ar') then
    v_locale := 'en';
  end if;
  if v_market is not null and not exists (
    select 1 from public.markets m where m.id = v_market and m.status = 'live'
  ) then
    v_market := null;
  end if;

  insert into public.profiles (id, locale, home_market_id)
  values (new.id, v_locale, v_market)
  on conflict (id) do nothing;

  insert into public.profile_private (id, phone_e164)
  values (new.id, case when new.phone is null or new.phone = '' then null
                       else '+' || ltrim(new.phone, '+') end)
  on conflict (id) do nothing;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Role picker groups, descriptions and popular trades
-- ---------------------------------------------------------------------------

alter table public.trades
  add column description jsonb check (description is null or public.is_label(description));

alter table public.market_trades
  add column popular_sort smallint;

-- Three groups, as in E9b: site and trades; engineering and design;
-- management and supply.
update public.role_families
set name = '{"en": "Site and trades", "ar": "الموقع والحِرف"}', sort = 1
where id = 'trades';
update public.role_families set sort = 2 where id = 'engineering';
update public.role_families
set name = '{"en": "Management and supply", "ar": "الإدارة والتوريد"}', sort = 3
where id = 'management';

update public.trades set family_id = 'management', sort = 6 where id = 'supplier';
update public.trades set family_id = 'management', sort = 7 where id = 'other';
delete from public.role_families where id in ('supply', 'other');

update public.trades as t
set description = d.description::jsonb
from (values
  ('site_engineer',     '{"en": "Runs the work on site day to day", "ar": "يدير العمل في الموقع يومياً"}'),
  ('design_engineer',   '{"en": "Drawings, calculations, design checks", "ar": "مخططات وحسابات ومراجعة تصميم"}'),
  ('architect',         '{"en": "Design, drawings, site visits", "ar": "تصميم ومخططات وزيارات موقع"}'),
  ('bim_specialist',    '{"en": "Models, coordination, clash checks", "ar": "نماذج وتنسيق وكشف تعارضات"}'),
  ('mep_engineer',      '{"en": "Electrical, plumbing, HVAC systems", "ar": "أنظمة الكهرباء والسباكة والتكييف"}'),
  ('quantity_surveyor', '{"en": "Quantities, costs, valuations", "ar": "كميات وتكاليف ومستخلصات"}'),
  ('project_manager',   '{"en": "Programme, budget, client", "ar": "البرنامج الزمني والميزانية والعميل"}'),
  ('site_manager',      '{"en": "Whole site, crews, safety", "ar": "الموقع كاملاً والفرق والسلامة"}'),
  ('site_supervisor',   '{"en": "Checks work and keeps crews moving", "ar": "يتابع العمل ويوجّه الفرق"}'),
  ('foreman',           '{"en": "Leads a crew on site", "ar": "يقود فريق عمل في الموقع"}'),
  ('safety_officer',    '{"en": "Site safety, permits, toolbox talks", "ar": "سلامة الموقع والتصاريح والتوعية"}'),
  ('electrician',       '{"en": "Wiring, panels, testing", "ar": "تمديدات ولوحات واختبارات"}'),
  ('plumber',           '{"en": "Pipes, drainage, fittings", "ar": "مواسير وصرف وتركيبات"}'),
  ('steel_fixer',       '{"en": "Rebar cutting and fixing", "ar": "قص وتركيب حديد التسليح"}'),
  ('carpenter',         '{"en": "Formwork, shuttering, joinery", "ar": "قوالب وشدات ونجارة"}'),
  ('mason',             '{"en": "Block, stone, plaster", "ar": "طابوق وحجر ولياسة"}'),
  ('tiler',             '{"en": "Floor and wall tiles", "ar": "بلاط الأرضيات والجدران"}'),
  ('painter',           '{"en": "Paint, coatings, finishes", "ar": "دهانات وطلاءات وتشطيبات"}'),
  ('welder',            '{"en": "Steel welding and fabrication", "ar": "لحام وتشكيل الحديد"}'),
  ('hvac_technician',   '{"en": "AC units, ducts, servicing", "ar": "وحدات تكييف ومجاري هواء وصيانة"}'),
  ('equipment_operator','{"en": "Cranes, loaders, plant", "ar": "رافعات ولودرات ومعدات"}'),
  ('supplier',          '{"en": "Materials, equipment, trading", "ar": "مواد ومعدات وتجارة"}'),
  ('other',             '{"en": "Your role in your own words", "ar": "دورك بكلماتك"}')
) as d(id, description)
where t.id = d.id;

-- Popular in Kuwait (from the E9b design). PLACEHOLDER for Egypt: a local
-- must confirm the list.
update public.market_trades as mt
set popular_sort = p.sort
from (values
  ('bim_specialist', 1), ('site_engineer', 2), ('electrician', 3),
  ('steel_fixer', 4), ('foreman', 5), ('site_manager', 6), ('plumber', 7)
) as p(trade_id, sort)
where mt.trade_id = p.trade_id and mt.market_id in ('kw', 'eg');
update public.market_trades
set needs_review = true
where market_id = 'eg' and popular_sort is not null;

-- ---------------------------------------------------------------------------
-- 3. Home market must be live
-- ---------------------------------------------------------------------------

create or replace function public.check_home_market_live()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.home_market_id is not null
     and new.home_market_id is distinct from old.home_market_id
     and not exists (
       select 1 from public.markets m
       where m.id = new.home_market_id and m.status = 'live'
     ) then
    raise exception 'market % is not open yet', new.home_market_id
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger profiles_home_market_live
  before update of home_market_id on public.profiles
  for each row execute function public.check_home_market_live();

revoke execute on function public.check_home_market_live()
  from public, anon, authenticated;
