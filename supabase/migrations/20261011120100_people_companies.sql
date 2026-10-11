-- Migration 2: people and companies (docs/product/data-model.md §2 and §3).
--
-- Access in short:
-- - profiles: signed-in users read them, except across a block (either
--   side). Owners update only their own editable columns.
-- - profile_private: the owner only.
-- - experience: by its visibility (everyone / connections / only me).
-- - follows: you follow and unfollow for yourself. Counts are kept on the
--   profile by a trigger and are never used for ranking.
-- - blocks: only the blocker sees and manages them.
-- - companies: anyone reads; only the company's admins edit. A company is
--   created only through register_company(), never from typed text.
--
-- Rows are created and changed through these functions, which run as the
-- owner (security definer) with an empty search_path:
--   handle_new_user (trigger), register_company, add_company_admin,
--   remove_company_admin.

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null default '' check (length(first_name) <= 60),
  last_name text not null default '' check (length(last_name) <= 60),
  headline text check (length(headline) <= 120),
  trade_id text references public.trades (id),
  home_market_id text references public.markets (id),
  place_id text references public.places (id),
  -- A registered company, or the name as the person typed it, or neither.
  company_id uuid,
  company_name_text text
    check (company_name_text is null or length(trim(company_name_text)) between 1 and 120),
  photo_path text,
  about text check (length(about) <= 2000),
  locale text not null default 'en' check (locale in ('en', 'ar')),
  -- Kept by a trigger on follows. Shown on profiles; never a ranking signal.
  follower_count integer not null default 0 check (follower_count >= 0),
  following_count integer not null default 0 check (following_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_one_company check (num_nonnulls(company_id, company_name_text) <= 1)
);
create index profiles_company_idx on public.profiles (company_id);
create index profiles_market_idx on public.profiles (home_market_id);

create table public.profile_private (
  id uuid primary key references public.profiles (id) on delete cascade,
  -- Copied from the verified sign-in phone; not editable from the app.
  phone_e164 text check (phone_e164 ~ '^\+[1-9][0-9]{6,14}$'),
  recovery_email text
    check (recovery_email is null or recovery_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index blocks_blocked_idx on public.blocks (blocked_id);

create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);
create index follows_followee_idx on public.follows (followee_id);

-- ---------------------------------------------------------------------------
-- Companies
-- ---------------------------------------------------------------------------

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 120),
  kind_id text not null references public.company_kinds (id),
  market_id text not null references public.markets (id),
  place_id text references public.places (id),
  logo_path text,
  about text check (length(about) <= 2000),
  created_by uuid references public.profiles (id) on delete set null,
  -- Set by the back office only (service role).
  verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index companies_market_idx on public.companies (market_id);
create index companies_name_idx on public.companies (lower(name));

create table public.company_admins (
  company_id uuid not null references public.companies (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (company_id, profile_id)
);
create index company_admins_profile_idx on public.company_admins (profile_id);

alter table public.profiles
  add constraint profiles_company_fk
  foreign key (company_id) references public.companies (id) on delete set null;

create table public.experience (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 120),
  company_id uuid references public.companies (id) on delete set null,
  company_name_text text
    check (company_name_text is null or length(trim(company_name_text)) between 1 and 120),
  -- First day of the month.
  start_month date not null check (extract(day from start_month) = 1),
  end_month date check (end_month is null or extract(day from end_month) = 1),
  visibility text not null default 'everyone'
    check (visibility in ('everyone', 'connections', 'only_me')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint experience_one_company check (num_nonnulls(company_id, company_name_text) <= 1),
  check (end_month is null or end_month >= start_month)
);
create index experience_profile_idx on public.experience (profile_id);

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger profile_private_updated_at before update on public.profile_private
  for each row execute function public.set_updated_at();
create trigger companies_updated_at before update on public.companies
  for each row execute function public.set_updated_at();
create trigger experience_updated_at before update on public.experience
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Checks that need other tables
-- ---------------------------------------------------------------------------

-- A profile's or company's place must be in its market.
create or replace function public.check_place_in_market()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_market text;
begin
  if new.place_id is null then
    return new;
  end if;
  -- The market column is home_market_id on profiles and market_id on
  -- companies; read it by name so one function serves both tables.
  v_market := to_jsonb(new) ->> case tg_table_name
    when 'profiles' then 'home_market_id'
    else 'market_id'
  end;
  if v_market is null or not exists (
    select 1 from public.places p
    where p.id = new.place_id and p.market_id = v_market
  ) then
    raise exception 'place % is not in market %', new.place_id, v_market
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger profiles_place_in_market
  before insert or update of place_id, home_market_id on public.profiles
  for each row execute function public.check_place_in_market();
create trigger companies_place_in_market
  before insert or update of place_id, market_id on public.companies
  for each row execute function public.check_place_in_market();

-- ---------------------------------------------------------------------------
-- Helpers used by policies. They only answer questions about the caller.
-- ---------------------------------------------------------------------------

-- True when the caller and [other] have blocked each other, either way.
create or replace function public.is_blocked_with(other uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = other)
       or (b.blocker_id = other and b.blocked_id = auth.uid())
  );
$$;

-- True when the caller and [other] follow each other.
create or replace function public.is_connected_with(other uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.follows a
    join public.follows b
      on b.follower_id = a.followee_id and b.followee_id = a.follower_id
    where a.follower_id = auth.uid() and a.followee_id = other
  );
$$;

create or replace function public.is_company_admin(company uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.company_admins ca
    where ca.company_id = company and ca.profile_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------------
-- New users: one profile and one private row per auth user
-- ---------------------------------------------------------------------------

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
  if v_market is not null
     and not exists (select 1 from public.markets m where m.id = v_market) then
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

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keep the private phone in step with the verified sign-in phone.
create or replace function public.handle_user_phone_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profile_private
  set phone_e164 = case when new.phone is null or new.phone = '' then null
                        else '+' || ltrim(new.phone, '+') end
  where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_phone_changed
  after update of phone on auth.users
  for each row
  when (old.phone is distinct from new.phone)
  execute function public.handle_user_phone_change();

-- ---------------------------------------------------------------------------
-- Follow counts, and blocking removes follows both ways
-- ---------------------------------------------------------------------------

create or replace function public.handle_follow_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.profiles set following_count = following_count + 1
      where id = new.follower_id;
    update public.profiles set follower_count = follower_count + 1
      where id = new.followee_id;
    return new;
  else
    update public.profiles set following_count = greatest(following_count - 1, 0)
      where id = old.follower_id;
    update public.profiles set follower_count = greatest(follower_count - 1, 0)
      where id = old.followee_id;
    return old;
  end if;
end;
$$;

create trigger follows_counts
  after insert or delete on public.follows
  for each row execute function public.handle_follow_change();

create or replace function public.handle_block_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.follows f
  where (f.follower_id = new.blocker_id and f.followee_id = new.blocked_id)
     or (f.follower_id = new.blocked_id and f.followee_id = new.blocker_id);
  return new;
end;
$$;

create trigger blocks_remove_follows
  after insert on public.blocks
  for each row execute function public.handle_block_insert();

-- ---------------------------------------------------------------------------
-- Companies: create and manage admins only through these functions
-- ---------------------------------------------------------------------------

-- Registers a company on purpose (the "Register a company" flow) and makes
-- the caller its first admin. Never called with text typed elsewhere.
create or replace function public.register_company(
  p_name text,
  p_kind_id text,
  p_market_id text,
  p_place_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  -- Light abuse limit: a person registers a few companies a day at most.
  if (select count(*) from public.companies c
      where c.created_by = v_me and c.created_at > now() - interval '1 day') >= 5 then
    raise exception 'too many companies today' using errcode = 'P0001';
  end if;

  insert into public.companies (name, kind_id, market_id, place_id, created_by)
  values (trim(p_name), p_kind_id, p_market_id, p_place_id, v_me)
  returning id into v_id;

  insert into public.company_admins (company_id, profile_id) values (v_id, v_me);
  return v_id;
end;
$$;

create or replace function public.add_company_admin(p_company uuid, p_profile uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_company_admin(p_company) then
    raise exception 'only a company admin can add admins' using errcode = '42501';
  end if;
  insert into public.company_admins (company_id, profile_id)
  values (p_company, p_profile)
  on conflict do nothing;
end;
$$;

create or replace function public.remove_company_admin(p_company uuid, p_profile uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_company_admin(p_company) then
    raise exception 'only a company admin can remove admins' using errcode = '42501';
  end if;
  if (select count(*) from public.company_admins ca where ca.company_id = p_company) <= 1 then
    raise exception 'a company needs at least one admin' using errcode = 'P0001';
  end if;
  delete from public.company_admins
  where company_id = p_company and profile_id = p_profile;
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.profile_private enable row level security;
alter table public.blocks enable row level security;
alter table public.follows enable row level security;
alter table public.companies enable row level security;
alter table public.company_admins enable row level security;
alter table public.experience enable row level security;

-- Profiles
create policy profiles_read on public.profiles
  for select to authenticated
  using (id = auth.uid() or not public.is_blocked_with(id));
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Private details: the owner only.
create policy profile_private_read_own on public.profile_private
  for select to authenticated
  using (id = auth.uid());
create policy profile_private_update_own on public.profile_private
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Blocks: only the blocker sees and manages them.
create policy blocks_read_own on public.blocks
  for select to authenticated
  using (blocker_id = auth.uid());
create policy blocks_insert_own on public.blocks
  for insert to authenticated
  with check (blocker_id = auth.uid());
create policy blocks_delete_own on public.blocks
  for delete to authenticated
  using (blocker_id = auth.uid());

-- Follows
create policy follows_read on public.follows
  for select to authenticated
  using (
    not public.is_blocked_with(follower_id)
    and not public.is_blocked_with(followee_id)
  );
create policy follows_insert_own on public.follows
  for insert to authenticated
  with check (follower_id = auth.uid() and not public.is_blocked_with(followee_id));
create policy follows_delete_own on public.follows
  for delete to authenticated
  using (follower_id = auth.uid());

-- Companies: anyone reads; admins edit.
create policy companies_read on public.companies
  for select to anon, authenticated
  using (true);
create policy companies_update_admin on public.companies
  for update to authenticated
  using (public.is_company_admin(id))
  with check (public.is_company_admin(id));

create policy company_admins_read on public.company_admins
  for select to authenticated
  using (true);

-- Experience: by visibility; the owner always sees and manages their own.
create policy experience_read on public.experience
  for select to authenticated
  using (
    profile_id = auth.uid()
    or (
      not public.is_blocked_with(profile_id)
      and (
        visibility = 'everyone'
        or (visibility = 'connections' and public.is_connected_with(profile_id))
      )
    )
  );
create policy experience_insert_own on public.experience
  for insert to authenticated
  with check (profile_id = auth.uid());
create policy experience_update_own on public.experience
  for update to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());
create policy experience_delete_own on public.experience
  for delete to authenticated
  using (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Grants. Column lists make counts, ids, verified and created_by read-only.
-- ---------------------------------------------------------------------------

revoke all on public.profiles, public.profile_private, public.blocks,
  public.follows, public.companies, public.company_admins, public.experience
  from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (
  first_name, last_name, headline, trade_id, home_market_id, place_id,
  company_id, company_name_text, photo_path, about, locale
) on public.profiles to authenticated;

grant select on public.profile_private to authenticated;
grant update (recovery_email) on public.profile_private to authenticated;

grant select, insert, delete on public.blocks to authenticated;
grant select, insert, delete on public.follows to authenticated;

grant select on public.companies to anon, authenticated;
grant update (name, kind_id, place_id, logo_path, about)
  on public.companies to authenticated;
grant select on public.company_admins to authenticated;

grant select, delete on public.experience to authenticated;
grant insert (
  profile_id, title, company_id, company_name_text, start_month, end_month, visibility
) on public.experience to authenticated;
grant update (
  title, company_id, company_name_text, start_month, end_month, visibility
) on public.experience to authenticated;

-- Functions: nothing is callable by default; open only what the app needs.
revoke execute on function
  public.handle_new_user(),
  public.handle_user_phone_change(),
  public.handle_follow_change(),
  public.handle_block_insert(),
  public.check_place_in_market(),
  public.is_blocked_with(uuid),
  public.is_connected_with(uuid),
  public.is_company_admin(uuid),
  public.register_company(text, text, text, text),
  public.add_company_admin(uuid, uuid),
  public.remove_company_admin(uuid, uuid)
  from public, anon, authenticated;

grant execute on function
  public.is_blocked_with(uuid),
  public.is_connected_with(uuid),
  public.is_company_admin(uuid),
  public.register_company(text, text, text, text),
  public.add_company_admin(uuid, uuid),
  public.remove_company_admin(uuid, uuid)
  to authenticated;
