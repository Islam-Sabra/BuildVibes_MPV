-- Migration 5: sign-in by email code only (decision 04,
-- docs/reviews/2026-10-11-04-decision-email-only.md).
--
-- 1. An optional, private mobile number on About you (E9), for phone
--    sign-in and account recovery later. Only the owner can read it.
-- 2. The home market must be live, except for a person who signed up with
--    a valid Space invite: they may choose any country.

-- ---------------------------------------------------------------------------
-- 1. Private mobile number
-- ---------------------------------------------------------------------------

alter table public.profile_private
  add column mobile_e164 text
    check (mobile_e164 is null or mobile_e164 ~ '^\+[1-9][0-9]{6,14}$');

grant update (mobile_e164) on public.profile_private to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Invited people may choose any home market
-- ---------------------------------------------------------------------------

-- True when [p_user] signed up with a Space invite code that is valid.
-- People can edit their own metadata, but a made-up code is never valid.
create or replace function public.signed_up_with_invite(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.is_valid_invite_code(
    (select u.raw_user_meta_data ->> 'invite_code'
     from auth.users u where u.id = p_user)
  ), false);
$$;

revoke execute on function public.signed_up_with_invite(uuid)
  from public, anon, authenticated;

create or replace function public.check_home_market_live()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.home_market_id is not null
     and new.home_market_id is distinct from old.home_market_id
     and not exists (
       select 1 from public.markets m
       where m.id = new.home_market_id and m.status = 'live'
     )
     and not public.signed_up_with_invite(new.id) then
    raise exception 'market % is not open yet', new.home_market_id
      using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke execute on function public.check_home_market_live()
  from public, anon, authenticated;

-- New users: take a home market from sign-up if it is live, or if they
-- came with a valid invite.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_locale text := new.raw_user_meta_data ->> 'locale';
  v_market text := new.raw_user_meta_data ->> 'home_market_id';
  v_invite text := new.raw_user_meta_data ->> 'invite_code';
begin
  if v_locale is null or v_locale not in ('en', 'ar') then
    v_locale := 'en';
  end if;
  if v_market is not null
     and not exists (select 1 from public.markets m where m.id = v_market)
  then
    v_market := null;
  elsif v_market is not null
     and not exists (
       select 1 from public.markets m where m.id = v_market and m.status = 'live'
     )
     and not coalesce(public.is_valid_invite_code(v_invite), false)
  then
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
