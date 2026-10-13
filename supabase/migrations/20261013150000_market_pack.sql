-- Migration 17: market pack audit (week 8 part 4). Brief:
-- docs/reviews/2026-10-13-23-week8-brief.md §5; the audit is in
-- docs/market-pack-review.md.
--
-- - markets.time_zone: the pack's time zone (IANA name). Kuwait
--   Asia/Kuwait, Egypt Africa/Cairo (summer time included).
-- - local_day(person): "today" in the person's pack time zone, for the
--   server's own day boundaries when no phone passes its midnight. UTC when
--   the person has no market.
-- - add_notification: one Useful row per post per day now counts the
--   author's own day, not UTC's (Kuwait's day started at 3 a.m.).
--
-- Not to confuse with the translate branch's migration 17
-- (20261013140000_translate.sql), which is out of the pilot (review 28) and
-- not merged: if it comes back, it is renamed after this one.

alter table public.markets
  add column time_zone text
    check (time_zone is null or time_zone ~ '^[A-Za-z]+(/[A-Za-z0-9_+-]+)+$');

update public.markets set time_zone = 'Asia/Kuwait' where id = 'kw';
update public.markets set time_zone = 'Africa/Cairo' where id = 'eg';

-- An unknown zone name is refused (the format check can't see that).
create or replace function public.check_market_time_zone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.time_zone is not null
     and not exists (select 1 from pg_catalog.pg_timezone_names z where z.name = new.time_zone) then
    raise exception 'unknown time zone %', new.time_zone using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger markets_time_zone_check
  before insert or update of time_zone on public.markets
  for each row execute function public.check_market_time_zone();

-- "Today" for [p_profile], in their pack's time zone.
create or replace function public.local_day(p_profile uuid)
returns date
language sql
stable
security definer
set search_path = ''
as $$
  select (now() at time zone coalesce(
    (select m.time_zone from public.profiles p
     join public.markets m on m.id = p.home_market_id
     where p.id = p_profile),
    'UTC'))::date;
$$;

-- As in migration 13, with the recipient's own day for Useful.
create or replace function public.add_notification(
  p_to uuid,
  p_kind text,
  p_actor uuid,
  p_space uuid default null,
  p_item uuid default null,
  p_post uuid default null,
  p_reply uuid default null,
  p_request uuid default null,
  p_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_to is null or p_to is not distinct from p_actor
     or public.blocked_between(p_to, p_actor) then
    return;
  end if;
  -- Space news only for people still in the Space. A confirmed request
  -- is written just before the new member's row.
  if p_space is not null and p_kind <> 'join_confirmed'
     and not public.is_active_member(p_space, p_to) then
    return;
  end if;

  -- Asking again within a day after cancelling: the same row, now
  -- pointing at the new request and unread again. No new row, so no new
  -- push. A request after one that was answered is a new row (review 20).
  if p_kind = 'join_request' then
    update public.notifications n
    set request_id = p_request, read_at = null
    where n.profile_id = p_to and n.kind = 'join_request' and n.actor_id = p_actor
      and n.space_id = p_space and n.created_at > now() - interval '1 day'
      and exists (select 1 from public.space_join_requests r
                  where r.id = n.request_id and r.status = 'cancelled');
    if found then
      return;
    end if;
  end if;
  -- Follow, unfollow, follow: one row a week.
  if p_kind = 'follow' and exists (
    select 1 from public.notifications
    where profile_id = p_to and kind = 'follow' and actor_id = p_actor
      and created_at > now() - interval '7 days') then
    return;
  end if;

  if p_kind = 'post_useful' then
    -- No actor kept: who marked it is never stored on the author's row.
    insert into public.notifications (profile_id, kind, post_id, payload, day)
    values (p_to, p_kind, p_post, p_payload, public.local_day(p_to))
    on conflict (profile_id, post_id, day) where kind = 'post_useful'
    do update set created_at = excluded.created_at, read_at = null;
  else
    insert into public.notifications (profile_id, kind, actor_id, space_id, work_item_id,
                                      post_id, reply_id, request_id, payload)
    values (p_to, p_kind, p_actor, p_space, p_item, p_post, p_reply, p_request, p_payload);
  end if;
end;
$$;

revoke execute on function public.local_day(uuid), public.check_market_time_zone()
  from public, anon, authenticated;
grant execute on function public.local_day(uuid) to service_role;
