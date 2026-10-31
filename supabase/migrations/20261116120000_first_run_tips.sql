-- Review 107 (OB7): the first-run tips each account has seen.
--
-- - profile_tips_seen: one row per tip an account has seen or dismissed:
--   'camera' (tap the camera to post a photo), 'hold' (hold a card to
--   share or delete) and 'sign_done' (sign as done when your work is
--   finished). Kept on the server, so a tip seen on one phone isn't shown
--   again on another.
-- - The owner reads their own rows through the policy. Nobody writes the
--   table directly: mark_tip_seen(p_tip) adds the caller's own row, once.
-- - Q1 (the lead's check): invite_preview also gives the Space's market.
-- - Q6: nine popular trades in each market pack (Carpenter, Mason).
-- - Onboarding needs no change here: E9 saved through an RLS update of
--   profiles, and the fields that left the flow (company, country, mobile)
--   were already optional or are filled without asking.

create table public.profile_tips_seen (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  tip text not null check (tip in ('camera', 'hold', 'sign_done')),
  seen_at timestamptz not null default now(),
  primary key (profile_id, tip)
);

alter table public.profile_tips_seen enable row level security;

create policy profile_tips_seen_own on public.profile_tips_seen
  for select to authenticated
  using (profile_id = auth.uid());

revoke all on public.profile_tips_seen from public, anon, authenticated;
grant select on public.profile_tips_seen to authenticated;
grant all on public.profile_tips_seen to service_role;

-- The caller has seen [p_tip]: kept once. An unknown tip is refused.
create or replace function public.mark_tip_seen(p_tip text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_tip is null or p_tip not in ('camera', 'hold', 'sign_done') then
    raise exception 'unknown tip' using errcode = '22023';
  end if;
  insert into public.profile_tips_seen (profile_id, tip)
  values (auth.uid(), p_tip)
  on conflict (profile_id, tip) do nothing;
end;
$$;

revoke all on function public.mark_tip_seen(text) from public, anon;
grant execute on function public.mark_tip_seen(text) to authenticated;

-- ---------------------------------------------------------------------------
-- The lead's check of r107, Q1: an invite's market, right after sign-in
-- ---------------------------------------------------------------------------

-- As in 20261013130000_account.sql, with the Space's market: its
-- project's (as space_time_zone), else null. Onboarding takes it as the
-- home market of someone who came with the code. The return type changes,
-- so it is dropped and made again with the same grants.
drop function public.invite_preview(text);

create function public.invite_preview(p_code text)
returns table (space_name text, invited_by_name text, expires_at timestamptz,
               market_id text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite public.space_invites;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if public.too_many_code_tries() then
    return;
  end if;
  v_invite := public.live_invite(p_code);
  if v_invite.id is null then
    insert into public.space_code_attempts (profile_id) values (auth.uid());
    return;
  end if;
  return query
  select s.name,
         case when public.is_hidden_account(v_invite.created_by) then null
              else nullif(trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
         end,
         v_invite.expires_at,
         pr.market_id
  from public.spaces s
  left join public.profiles p on p.id = v_invite.created_by
  left join public.projects pr on pr.id = s.project_id
  where s.id = v_invite.space_id;
end;
$$;

revoke all on function public.invite_preview(text) from public, anon;
grant execute on function public.invite_preview(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Q6: nine trades on OB5
-- ---------------------------------------------------------------------------

-- The welcome's "What's your work?" shows nine tiles: the market's popular
-- trades. Seven were listed (20261011130000_entry_onboarding.sql);
-- Carpenter and Mason follow. Egypt's list still needs a local's review.
update public.market_trades as mt
set popular_sort = p.sort
from (values ('carpenter', 8), ('mason', 9)) as p(trade_id, sort)
where mt.trade_id = p.trade_id and mt.market_id in ('kw', 'eg');
update public.market_trades
set needs_review = true
where market_id = 'eg' and trade_id in ('carpenter', 'mason');
