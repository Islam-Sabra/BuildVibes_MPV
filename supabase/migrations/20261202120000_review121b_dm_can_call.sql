-- Review 121b: Call from a direct message.
--
-- 1. dm_can_call(p_other): whether the phone icon shows in my direct
--    message with [p_other]. It never gives the number and never counts
--    against person_phone's 30 a day.
-- 2. phone_shown_to answers false when the owner has no number, so neither
--    Who to call nor a direct message shows a Call that can't ring.

create or replace function public.phone_shown_to(p_owner uuid, p_viewer uuid, p_space uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((
    select p.phone is not null
      and p.phone_visibility <> 'nobody'
      and p_owner is distinct from p_viewer
      and not public.is_hidden_account(p_owner)
      and not public.is_hidden_account(p_viewer)
      and not public.blocked_between(p_owner, p_viewer)
      and (
        (p_space is not null
         and public.is_active_member(p_space, p_owner)
         and public.is_active_member(p_space, p_viewer))
        -- A direct message counts only once the owner has it open.
        or (p.phone_visibility = 'spaces_and_dms'
            and exists (select 1 from public.dm_threads t
                        join public.dm_members o on o.thread_id = t.id
                          and o.profile_id = p_owner and o.state = 'open'
                        where t.a_id = least(p_owner, p_viewer)
                          and t.b_id = greatest(p_owner, p_viewer))))
    from public.profiles p
    where p.id = p_owner), false);
$$;

create function public.dm_can_call(p_other uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and public.phone_shown_to(p_other, auth.uid(), null);
$$;

revoke all on function public.dm_can_call(uuid) from public, anon, authenticated;
grant execute on function public.dm_can_call(uuid) to authenticated;
