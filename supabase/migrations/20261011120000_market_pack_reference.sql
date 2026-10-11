-- Migration 1: market pack and reference data (docs/product/data-model.md §1).
--
-- Everything country-specific lives here, never in app code (rule 5).
-- These tables are read-only for the app: anyone, signed in or not, can read
-- them; nobody can write to them through the API. They change only through
-- migrations.
--
-- PLACEHOLDERS: values a local reviewer must confirm are flagged in the data
-- itself: markets.needs_review lists the fields to check, and rows in
-- places / market_trades carry needs_review = true. Search for "PLACEHOLDER".

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- A translated label: {"en": "...", "ar": "..."}, both required.
create or replace function public.is_label(value jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(value) = 'object'
    and coalesce(length(value ->> 'en'), 0) > 0
    and coalesce(length(value ->> 'ar'), 0) > 0;
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.markets (
  id text primary key check (id ~ '^[a-z]{2}$'),
  status text not null default 'hidden'
    check (status in ('live', 'soon', 'hidden')),
  name jsonb not null check (public.is_label(name)),
  default_locale text not null check (default_locale in ('en', 'ar')),
  dial_code text not null check (dial_code ~ '^\+[0-9]{1,4}$'),
  -- {"national_length": 8, "mobile_prefixes": ["5","6","9"], "example": "..."}
  phone_rules jsonb not null default '{}'::jsonb,
  code_channel text not null check (code_channel in ('whatsapp', 'sms')),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  currency_decimals smallint not null check (currency_decimals between 0 and 3),
  -- 0 = Sunday … 6 = Saturday
  week_start smallint not null check (week_start between 0 and 6),
  weekend smallint[] not null default '{}',
  -- {"terms": {"en": url, "ar": url}, "privacy": {...}}
  legal jsonb not null default '{}'::jsonb,
  -- Fields a local reviewer must still confirm. Empty when the pack is final.
  needs_review text[] not null default '{}',
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.places (
  id text primary key,
  market_id text not null references public.markets (id),
  parent_id text references public.places (id),
  level text not null check (level in ('city', 'area')),
  name jsonb not null check (public.is_label(name)),
  sort smallint not null default 0,
  needs_review boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- An area always sits under a city; a city never has a parent.
  check ((level = 'city') = (parent_id is null))
);
create index places_market_idx on public.places (market_id, level, sort);
create index places_parent_idx on public.places (parent_id);

create table public.role_families (
  id text primary key,
  name jsonb not null check (public.is_label(name)),
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.trades (
  id text primary key,
  family_id text not null references public.role_families (id),
  name jsonb not null check (public.is_label(name)),
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index trades_family_idx on public.trades (family_id, sort);

create table public.market_trades (
  market_id text not null references public.markets (id),
  trade_id text not null references public.trades (id),
  visible boolean not null default true,
  -- What people in this market call the trade, when it differs.
  local_name jsonb check (local_name is null or public.is_label(local_name)),
  needs_review boolean not null default false,
  primary key (market_id, trade_id)
);
create index market_trades_trade_idx on public.market_trades (trade_id);

create table public.company_kinds (
  id text primary key,
  name jsonb not null check (public.is_label(name)),
  sort smallint not null default 0
);

create table public.project_types (
  id text primary key,
  name jsonb not null check (public.is_label(name)),
  sort smallint not null default 0
);

create trigger markets_updated_at before update on public.markets
  for each row execute function public.set_updated_at();
create trigger places_updated_at before update on public.places
  for each row execute function public.set_updated_at();
create trigger role_families_updated_at before update on public.role_families
  for each row execute function public.set_updated_at();
create trigger trades_updated_at before update on public.trades
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Access: read for everyone, write for nobody (through the API)
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'markets', 'places', 'role_families', 'trades', 'market_trades',
    'company_kinds', 'project_types'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select on public.%I to anon, authenticated', t);
    execute format(
      'create policy %I on public.%I for select to anon, authenticated using (true)',
      t || '_read', t
    );
  end loop;
end;
$$;

-- Hidden markets are not shown to the app.
drop policy markets_read on public.markets;
create policy markets_read on public.markets
  for select to anon, authenticated
  using (status <> 'hidden');

-- ---------------------------------------------------------------------------
-- Seed: markets
-- ---------------------------------------------------------------------------

insert into public.markets (
  id, status, name, default_locale, dial_code, phone_rules, code_channel,
  currency, currency_decimals, week_start, weekend, legal, needs_review, sort
) values
  (
    'kw', 'live',
    '{"en": "Kuwait", "ar": "الكويت"}', 'ar', '+965',
    -- PLACEHOLDER: confirm mobile prefixes with a local reviewer.
    '{"national_length": 8, "mobile_prefixes": ["5", "6", "9"], "example": "5000 0000"}',
    -- PLACEHOLDER: confirm WhatsApp is the right default for sign-in codes.
    'whatsapp',
    'KWD', 3,
    0, '{5,6}',
    -- PLACEHOLDER: legal pages are not written yet.
    '{}',
    '{phone_rules,code_channel,legal}',
    1
  ),
  (
    'eg', 'soon',
    '{"en": "Egypt", "ar": "مصر"}', 'ar', '+20',
    -- PLACEHOLDER: confirm mobile prefixes with a local reviewer.
    '{"national_length": 10, "mobile_prefixes": ["10", "11", "12", "15"], "example": "100 000 0000"}',
    -- PLACEHOLDER: confirm WhatsApp is the right default for sign-in codes.
    'whatsapp',
    'EGP', 2,
    -- PLACEHOLDER: confirm the week start (Saturday or Sunday).
    6, '{5,6}',
    -- PLACEHOLDER: legal pages are not written yet.
    '{}',
    '{phone_rules,code_channel,week_start,legal,status}',
    2
  );

-- ---------------------------------------------------------------------------
-- Seed: places. PLACEHOLDER: both lists must be confirmed by a local.
-- Kuwait: the six governorates, with common areas ported from the old app.
-- Egypt: main construction cities and districts.
-- ---------------------------------------------------------------------------

insert into public.places (id, market_id, parent_id, level, name, sort, needs_review) values
  ('kw-capital',    'kw', null, 'city', '{"en": "Capital", "ar": "العاصمة"}', 1, true),
  ('kw-hawalli',    'kw', null, 'city', '{"en": "Hawalli", "ar": "حولي"}', 2, true),
  ('kw-farwaniya',  'kw', null, 'city', '{"en": "Farwaniya", "ar": "الفروانية"}', 3, true),
  ('kw-mubarak',    'kw', null, 'city', '{"en": "Mubarak Al-Kabeer", "ar": "مبارك الكبير"}', 4, true),
  ('kw-ahmadi',     'kw', null, 'city', '{"en": "Ahmadi", "ar": "الأحمدي"}', 5, true),
  ('kw-jahra',      'kw', null, 'city', '{"en": "Jahra", "ar": "الجهراء"}', 6, true),
  ('eg-cairo',      'eg', null, 'city', '{"en": "Cairo", "ar": "القاهرة"}', 1, true),
  ('eg-giza',       'eg', null, 'city', '{"en": "Giza", "ar": "الجيزة"}', 2, true),
  ('eg-alexandria', 'eg', null, 'city', '{"en": "Alexandria", "ar": "الإسكندرية"}', 3, true),
  ('eg-new-capital','eg', null, 'city', '{"en": "New Administrative Capital", "ar": "العاصمة الإدارية الجديدة"}', 4, true);

insert into public.places (id, market_id, parent_id, level, name, sort, needs_review) values
  ('kw-kuwait-city',   'kw', 'kw-capital',   'area', '{"en": "Kuwait City", "ar": "مدينة الكويت"}', 1, true),
  ('kw-shuwaikh',      'kw', 'kw-capital',   'area', '{"en": "Shuwaikh", "ar": "الشويخ"}', 2, true),
  ('kw-salmiya',       'kw', 'kw-hawalli',   'area', '{"en": "Salmiya", "ar": "السالمية"}', 1, true),
  ('kw-jabriya',       'kw', 'kw-hawalli',   'area', '{"en": "Jabriya", "ar": "الجابرية"}', 2, true),
  ('kw-rumaithiya',    'kw', 'kw-hawalli',   'area', '{"en": "Rumaithiya", "ar": "الرميثية"}', 3, true),
  ('kw-salwa',         'kw', 'kw-hawalli',   'area', '{"en": "Salwa", "ar": "سلوى"}', 4, true),
  ('kw-mishref',       'kw', 'kw-hawalli',   'area', '{"en": "Mishref", "ar": "مشرف"}', 5, true),
  ('kw-farwaniya-area','kw', 'kw-farwaniya', 'area', '{"en": "Farwaniya", "ar": "الفروانية"}', 1, true),
  ('kw-sabah-al-salem','kw', 'kw-mubarak',   'area', '{"en": "Sabah Al-Salem", "ar": "صباح السالم"}', 1, true),
  ('kw-fahaheel',      'kw', 'kw-ahmadi',    'area', '{"en": "Fahaheel", "ar": "الفحيحيل"}', 1, true),
  ('kw-mangaf',        'kw', 'kw-ahmadi',    'area', '{"en": "Mangaf", "ar": "المنقف"}', 2, true),
  ('kw-mahboula',      'kw', 'kw-ahmadi',    'area', '{"en": "Mahboula", "ar": "المهبولة"}', 3, true),
  ('kw-jahra-area',    'kw', 'kw-jahra',     'area', '{"en": "Jahra", "ar": "الجهراء"}', 1, true),
  ('eg-new-cairo',     'eg', 'eg-cairo',     'area', '{"en": "New Cairo", "ar": "القاهرة الجديدة"}', 1, true),
  ('eg-nasr-city',     'eg', 'eg-cairo',     'area', '{"en": "Nasr City", "ar": "مدينة نصر"}', 2, true),
  ('eg-maadi',         'eg', 'eg-cairo',     'area', '{"en": "Maadi", "ar": "المعادي"}', 3, true),
  ('eg-october',       'eg', 'eg-giza',      'area', '{"en": "6th of October", "ar": "السادس من أكتوبر"}', 1, true),
  ('eg-sheikh-zayed',  'eg', 'eg-giza',      'area', '{"en": "Sheikh Zayed", "ar": "الشيخ زايد"}', 2, true);

-- ---------------------------------------------------------------------------
-- Seed: role families and trades (the Figma role picker, plus the others in
-- the same families). Arabic names follow docs/product/arabic-glossary.md
-- style: simple standard Arabic.
-- ---------------------------------------------------------------------------

insert into public.role_families (id, name, sort) values
  ('engineering', '{"en": "Engineering and design", "ar": "الهندسة والتصميم"}', 1),
  ('management',  '{"en": "Site and project management", "ar": "إدارة المواقع والمشاريع"}', 2),
  ('trades',      '{"en": "Trades", "ar": "الحِرف"}', 3),
  ('supply',      '{"en": "Supply", "ar": "التوريد"}', 4),
  ('other',       '{"en": "Other", "ar": "أخرى"}', 5);

insert into public.trades (id, family_id, name, sort) values
  ('site_engineer',    'engineering', '{"en": "Site engineer", "ar": "مهندس موقع"}', 1),
  ('design_engineer',  'engineering', '{"en": "Design engineer", "ar": "مهندس تصميم"}', 2),
  ('architect',        'engineering', '{"en": "Architect", "ar": "مهندس معماري"}', 3),
  ('bim_specialist',   'engineering', '{"en": "BIM specialist", "ar": "أخصائي BIM"}', 4),
  ('mep_engineer',     'engineering', '{"en": "MEP engineer", "ar": "مهندس كهروميكانيك"}', 5),
  ('quantity_surveyor','engineering', '{"en": "Quantity surveyor", "ar": "مهندس كميات"}', 6),
  ('project_manager',  'management',  '{"en": "Project manager", "ar": "مدير مشروع"}', 1),
  ('site_manager',     'management',  '{"en": "Site manager", "ar": "مدير موقع"}', 2),
  ('site_supervisor',  'management',  '{"en": "Site supervisor", "ar": "مشرف موقع"}', 3),
  ('foreman',          'management',  '{"en": "Foreman", "ar": "رئيس عمال"}', 4),
  ('safety_officer',   'management',  '{"en": "Safety officer", "ar": "مسؤول سلامة"}', 5),
  ('electrician',      'trades',      '{"en": "Electrician", "ar": "كهربائي"}', 1),
  ('plumber',          'trades',      '{"en": "Plumber", "ar": "سبّاك"}', 2),
  ('steel_fixer',      'trades',      '{"en": "Steel fixer", "ar": "حدّاد تسليح"}', 3),
  ('carpenter',        'trades',      '{"en": "Carpenter", "ar": "نجّار"}', 4),
  ('mason',            'trades',      '{"en": "Mason", "ar": "بنّاء"}', 5),
  ('tiler',            'trades',      '{"en": "Tiler", "ar": "مبلّط"}', 6),
  ('painter',          'trades',      '{"en": "Painter", "ar": "دهّان"}', 7),
  ('welder',           'trades',      '{"en": "Welder", "ar": "لحّام"}', 8),
  ('hvac_technician',  'trades',      '{"en": "HVAC technician", "ar": "فني تكييف"}', 9),
  ('equipment_operator','trades',     '{"en": "Equipment operator", "ar": "مشغّل معدات"}', 10),
  ('supplier',         'supply',      '{"en": "Supplier or trader", "ar": "مورّد أو تاجر"}', 1),
  ('other',            'other',       '{"en": "Other", "ar": "أخرى"}', 1);

-- Every trade is offered in both markets.
insert into public.market_trades (market_id, trade_id)
select m.id, t.id from public.markets m cross join public.trades t;

-- PLACEHOLDER: local names where the everyday word differs. A local must
-- confirm these and add others.
update public.market_trades
set local_name = '{"en": "Steel fixer", "ar": "حدّاد مسلّح"}', needs_review = true
where market_id = 'eg' and trade_id = 'steel_fixer';
update public.market_trades
set local_name = '{"en": "Plumber", "ar": "سبّاك"}', needs_review = true
where market_id = 'eg' and trade_id = 'plumber';
update public.market_trades
set local_name = '{"en": "Foreman", "ar": "فورمن"}', needs_review = true
where market_id = 'kw' and trade_id = 'foreman';

-- ---------------------------------------------------------------------------
-- Seed: company kinds and project types
-- ---------------------------------------------------------------------------

insert into public.company_kinds (id, name, sort) values
  ('contractor',    '{"en": "Contractor", "ar": "مقاول"}', 1),
  ('subcontractor', '{"en": "Subcontractor", "ar": "مقاول باطن"}', 2),
  ('consultant',    '{"en": "Consultant", "ar": "استشاري"}', 3),
  ('developer',     '{"en": "Developer or owner", "ar": "مطوّر أو مالك"}', 4),
  ('supplier',      '{"en": "Supplier", "ar": "مورّد"}', 5),
  ('manufacturer',  '{"en": "Manufacturer", "ar": "مصنّع"}', 6),
  ('government',    '{"en": "Government body", "ar": "جهة حكومية"}', 7);

insert into public.project_types (id, name, sort) values
  ('residential',    '{"en": "Residential", "ar": "سكني"}', 1),
  ('commercial',     '{"en": "Commercial", "ar": "تجاري"}', 2),
  ('mixed_use',      '{"en": "Mixed use", "ar": "متعدد الاستخدامات"}', 3),
  ('infrastructure', '{"en": "Infrastructure", "ar": "بنية تحتية"}', 4),
  ('industrial',     '{"en": "Industrial", "ar": "صناعي"}', 5),
  ('healthcare',     '{"en": "Healthcare", "ar": "صحي"}', 6),
  ('education',      '{"en": "Education", "ar": "تعليمي"}', 7),
  ('hospitality',    '{"en": "Hospitality", "ar": "فندقي"}', 8),
  ('government',     '{"en": "Government", "ar": "حكومي"}', 9);
