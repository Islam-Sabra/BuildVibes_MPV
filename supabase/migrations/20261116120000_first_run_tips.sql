-- Review 107 (OB7): the first-run tips each account has seen.
--
-- - profile_tips_seen: one row per tip an account has seen or dismissed:
--   'camera' (tap the camera to post a photo), 'hold' (hold a card to
--   share or delete) and 'sign_done' (sign as done when your work is
--   finished). Kept on the server, so a tip seen on one phone isn't shown
--   again on another.
-- - The owner reads their own rows through the policy. Nobody writes the
--   table directly: mark_tip_seen(p_tip) adds the caller's own row, once.
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
