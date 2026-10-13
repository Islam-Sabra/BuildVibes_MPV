-- Migration 14: push notifications (week 7 part 3). Brief: docs/reviews/2026-10-12-16-home-activity.md §4.
--
-- - push_tokens: one row per phone (FCM token), with its platform and the
--   language its pushes are written in. Kept by register_push_token and
--   unregister_push_token; a token signed in on another account moves. At
--   most the newest 10 phones per person; phones not seen for 60 days go.
-- - push_settings: the S3 switches. New followers and Replies are on, and
--   "Show message text on lock screen" is off, until the person changes them.
-- - push_queue: what to send. Rows come only from triggers:
--   - a new notification, when the person wants it pushed:
--     - work item and Space kinds follow the Space's level
--       (space_members.notify): off sends none; needs_you and all send them;
--     - a confirmed role always; a follower or a reply by the S3 switch;
--     - Useful never.
--   - a new chat message, for each person who may read the thread and set
--     the Space to "all": never the author, never across a block, at most
--     one per thread per person every 5 minutes. Chat makes no Activity row.
--   Only people with a phone registered get rows. A push problem never
--   blocks the post, message or work item step that caused it.
-- - The queue holds ids for the deep link, never a project, Space or work
--   item name (founder decision), and the message text only when the
--   person turned "Show message text on lock screen" on. Deleting the
--   message, or sending the push, clears that text.
-- - Sending: the Edge Function `push` (supabase/functions/push), called by
--   a database webhook on push_queue inserts. It claims a row with
--   claim_push (so a repeated call sends once), then marks it sent or
--   failed (finish_push), or gives it back for a retry (release_push).
--   retry_push_queue and prune_push_queue run from cron. The call on each
--   insert (a trigger reading the secret from Vault, not a dashboard
--   webhook) and the schedule are in supabase/ops/; deploying the function
--   and running them are live changes that wait for the founder's yes.
-- Review 21 and 22 fixes are in this file (it wasn't live yet).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.push_tokens (
  token text primary key check (length(token) between 20 and 4096),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  -- The language pushes to this phone are written in.
  locale text not null default 'en' check (locale in ('en', 'ar')),
  updated_at timestamptz not null default now()
);
create index push_tokens_profile_idx on public.push_tokens (profile_id, updated_at desc);

create table public.push_settings (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  followers boolean not null default true,
  replies boolean not null default true,
  message_text boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.push_queue (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in (
    'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
    'join_request', 'join_confirmed', 'role_confirmed', 'follow', 'post_reply',
    'chat_message')),
  actor_id uuid references public.profiles (id) on delete cascade,
  notification_id uuid references public.notifications (id) on delete cascade,
  thread_id uuid references public.threads (id) on delete cascade,
  -- Ids for the deep link only (space, item, post, request, thread, message).
  data jsonb not null default '{}'::jsonb,
  -- Only when "Show message text on lock screen" is on, until sent.
  message_text text check (length(message_text) <= 200),
  created_at timestamptz not null default now(),
  -- Sending: claimed by the function, then sent (or failed for good).
  claimed_at timestamptz,
  attempts integer not null default 0 check (attempts >= 0),
  -- FCM asked to wait (Retry-After).
  not_before timestamptz,
  sent_at timestamptz,
  error text check (length(error) <= 500)
);
create index push_queue_thread_idx
  on public.push_queue (profile_id, thread_id, created_at desc)
  where kind = 'chat_message';
create index push_queue_unsent_idx on public.push_queue (created_at) where sent_at is null;
create index push_queue_message_idx
  on public.push_queue ((data ->> 'message_id')) where kind = 'chat_message';

-- ---------------------------------------------------------------------------
-- Who gets a push
-- ---------------------------------------------------------------------------

-- The Space's level for [p_profile]: 'all' when the row is missing (a
-- request confirmed this moment; confirm_join resets the level to 'all').
create or replace function public.space_push_level(p_space uuid, p_profile uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select m.notify from public.space_members m
                   where m.space_id = p_space and m.profile_id = p_profile
                     and m.left_at is null), 'all');
$$;

-- A new notification: queue a push if the person wants this kind.
create or replace function public.handle_notification_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_settings public.push_settings;
  v_wanted boolean;
begin
  begin
    if not exists (select 1 from public.push_tokens t where t.profile_id = new.profile_id) then
      return null;
    end if;
    select * into v_settings from public.push_settings s where s.profile_id = new.profile_id;
    v_wanted := case
      when new.kind in ('item_assigned', 'item_done', 'item_checked', 'item_sent_back',
                        'item_comment', 'join_request')
        then public.space_push_level(new.space_id, new.profile_id) in ('all', 'needs_you')
      when new.kind = 'join_confirmed' then true
      when new.kind = 'role_confirmed' then true
      when new.kind = 'follow' then coalesce(v_settings.followers, true)
      when new.kind = 'post_reply' then coalesce(v_settings.replies, true)
      else false
    end;
    if v_wanted then
      insert into public.push_queue (profile_id, kind, actor_id, notification_id, data)
      values (new.profile_id, new.kind, new.actor_id, new.id,
              jsonb_strip_nulls(jsonb_build_object(
                'space_id', new.space_id, 'work_item_id', new.work_item_id,
                'post_id', new.post_id, 'request_id', new.request_id)));
    end if;
  exception when others then
    -- A push problem never blocks the step that caused it.
    raise warning 'push queue (notification %): %', new.id, sqlerrm;
  end;
  return null;
end;
$$;
create trigger notifications_push
  after insert on public.notifications
  for each row execute function public.handle_notification_push();

-- A new chat message: a push for each reader who set the Space to "all".
-- Work item cards in chat are skipped: their event already notified.
create or replace function public.handle_message_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_team uuid;
begin
  if new.kind = 'work_item' or new.deleted_at is not null then
    return null;
  end if;
  begin
    select t.team_id into v_team from public.threads t where t.id = new.thread_id;

    insert into public.push_queue (profile_id, kind, actor_id, thread_id, data, message_text)
    select m.profile_id, 'chat_message', new.author_id, new.thread_id,
           jsonb_build_object('space_id', new.space_id, 'thread_id', new.thread_id,
                              'message_id', new.id),
           case when coalesce(ps.message_text, false) and new.kind = 'text'
                then left(new.body, 200) end
    from public.space_members m
    left join public.push_settings ps on ps.profile_id = m.profile_id
    where m.space_id = new.space_id
      and m.left_at is null
      and m.notify = 'all'
      and m.profile_id is distinct from new.author_id
      -- Who may read the thread (as can_use_thread, for each reader).
      and (v_team is null or m.is_admin
           or exists (select 1 from public.team_members tm
                      where tm.team_id = v_team and tm.profile_id = m.profile_id))
      and not public.blocked_between(m.profile_id, new.author_id)
      and exists (select 1 from public.push_tokens pt where pt.profile_id = m.profile_id)
      -- At most one push per thread per person every 5 minutes.
      and not exists (select 1 from public.push_queue q
                      where q.profile_id = m.profile_id and q.kind = 'chat_message'
                        and q.thread_id = new.thread_id
                        and q.created_at > now() - interval '5 minutes');
  exception when others then
    raise warning 'push queue (message %): %', new.id, sqlerrm;
  end;
  return null;
end;
$$;
create trigger messages_push
  after insert on public.messages
  for each row execute function public.handle_message_push();

-- A deleted message: its text leaves the queue, so a late or repeated send
-- can't show it.
create or replace function public.handle_message_deleted_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    update public.push_queue set message_text = null
    where kind = 'chat_message' and data ->> 'message_id' = new.id::text
      and message_text is not null;
  end if;
  return null;
end;
$$;
create trigger messages_deleted_push
  after update of deleted_at on public.messages
  for each row execute function public.handle_message_deleted_push();

-- ---------------------------------------------------------------------------
-- Sending (the push function, as the service role)
-- ---------------------------------------------------------------------------

-- Takes one row to send, once: unsent, not claimed in the last minute (a
-- send that crashed is claimed again), and not asked to wait. Empty when
-- another call has it, or it is done.
create or replace function public.claim_push(p_id bigint)
returns setof public.push_queue
language sql
volatile
security definer
set search_path = ''
as $$
  update public.push_queue
  set claimed_at = now(), attempts = attempts + 1
  where id = p_id
    and sent_at is null
    and (claimed_at is null or claimed_at < now() - interval '1 minute')
    and (not_before is null or not_before <= now())
    and attempts < 5
  returning *;
$$;

-- Sent, or failed for good: the lock-screen text goes either way.
create or replace function public.finish_push(p_id bigint, p_error text default null)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.push_queue
  set sent_at = now(), message_text = null, claimed_at = null, error = left(p_error, 500)
  where id = p_id;
$$;

-- A temporary failure (FCM 429 or 5xx, a network error): back in the
-- queue, after [p_wait] when FCM said Retry-After. After the 5th attempt
-- it stops: marked finished, and its text goes at once (review 22).
create or replace function public.release_push(p_id bigint, p_wait interval default null, p_error text default null)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.push_queue
  set claimed_at = null,
      not_before = case when p_wait is null or attempts >= 5 then null else now() + p_wait end,
      sent_at = case when attempts >= 5 then now() end,
      message_text = case when attempts >= 5 then null else message_text end,
      error = left(p_error, 500)
  where id = p_id and sent_at is null;
$$;

-- Every minute (cron): rows to send again. Unsent for over a minute,
-- under an hour old, fewer than 5 attempts.
create or replace function public.retry_push_queue()
returns table (id bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select q.id from public.push_queue q
  where q.sent_at is null
    and q.created_at < now() - interval '1 minute'
    and q.created_at > now() - interval '1 hour'
    and q.attempts < 5
    and (q.claimed_at is null or q.claimed_at < now() - interval '1 minute')
    and (q.not_before is null or q.not_before <= now())
  order by q.id
  limit 500;
$$;

-- Nightly (cron): rows sent over a day ago, rows that gave up (over a day
-- old), and phones not seen for 60 days.
create or replace function public.prune_push_queue()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_rows integer;
  v_phones integer;
begin
  delete from public.push_queue where created_at < now() - interval '1 day';
  get diagnostics v_rows = row_count;
  delete from public.push_tokens where updated_at < now() - interval '60 days';
  get diagnostics v_phones = row_count;
  return v_rows + v_phones;
end;
$$;

-- ---------------------------------------------------------------------------
-- The app's calls
-- ---------------------------------------------------------------------------

-- On sign-in, and whenever FCM gives the phone a new token or the app
-- language changes. A token signed in on another account before moves to
-- this one. The newest 10 phones per person are kept.
create or replace function public.register_push_token(
  p_token text,
  p_platform text,
  p_locale text default 'en'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_token is null or length(p_token) not between 20 and 4096 then
    raise exception 'not a push token' using errcode = '22023';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'android or ios' using errcode = '22023';
  end if;
  insert into public.push_tokens (token, profile_id, platform, locale, updated_at)
  values (p_token, auth.uid(), p_platform,
          case when p_locale = 'ar' then 'ar' else 'en' end, clock_timestamp())
  on conflict (token) do update
  set profile_id = excluded.profile_id, platform = excluded.platform,
      locale = excluded.locale, updated_at = excluded.updated_at;
  delete from public.push_tokens t
  where t.profile_id = auth.uid()
    and t.token not in (select k.token from public.push_tokens k
                        where k.profile_id = auth.uid()
                        order by k.updated_at desc limit 10);
end;
$$;

-- On sign-out: this phone gets no more pushes for this account.
create or replace function public.unregister_push_token(p_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.push_tokens where token = p_token and profile_id = auth.uid();
$$;

-- S3. Missing row: the defaults.
create or replace function public.my_push_settings()
returns table (followers boolean, replies boolean, message_text boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(s.followers, true), coalesce(s.replies, true),
         coalesce(s.message_text, false)
  from (select 1) one
  left join public.push_settings s on s.profile_id = auth.uid();
$$;

create or replace function public.set_push_settings(
  p_followers boolean,
  p_replies boolean,
  p_message_text boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_followers is null or p_replies is null or p_message_text is null then
    raise exception 'each switch is on or off' using errcode = '22023';
  end if;
  insert into public.push_settings (profile_id, followers, replies, message_text, updated_at)
  values (auth.uid(), p_followers, p_replies, p_message_text, now())
  on conflict (profile_id) do update
  set followers = excluded.followers, replies = excluded.replies,
      message_text = excluded.message_text, updated_at = excluded.updated_at;
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security and grants
-- ---------------------------------------------------------------------------

alter table public.push_tokens enable row level security;
alter table public.push_settings enable row level security;
alter table public.push_queue enable row level security;

-- Your own phones and switches only. The queue: the service role only.
create policy push_tokens_read_own on public.push_tokens
  for select to authenticated using (profile_id = auth.uid());
create policy push_settings_read_own on public.push_settings
  for select to authenticated using (profile_id = auth.uid());

revoke all on public.push_tokens, public.push_settings, public.push_queue
  from anon, authenticated;
grant select on public.push_tokens, public.push_settings to authenticated;
grant all on public.push_tokens, public.push_settings, public.push_queue to service_role;

revoke execute on function
  public.space_push_level(uuid, uuid),
  public.handle_notification_push(),
  public.handle_message_push(),
  public.handle_message_deleted_push(),
  public.claim_push(bigint),
  public.finish_push(bigint, text),
  public.release_push(bigint, interval, text),
  public.retry_push_queue(),
  public.prune_push_queue(),
  public.register_push_token(text, text, text),
  public.unregister_push_token(text),
  public.my_push_settings(),
  public.set_push_settings(boolean, boolean, boolean)
  from public, anon;
-- Internal, or the push function's and cron's only.
revoke execute on function
  public.space_push_level(uuid, uuid),
  public.handle_notification_push(),
  public.handle_message_push(),
  public.handle_message_deleted_push(),
  public.claim_push(bigint),
  public.finish_push(bigint, text),
  public.release_push(bigint, interval, text),
  public.retry_push_queue(),
  public.prune_push_queue()
  from authenticated;
grant execute on function
  public.register_push_token(text, text, text),
  public.unregister_push_token(text),
  public.my_push_settings(),
  public.set_push_settings(boolean, boolean, boolean)
  to authenticated;
grant execute on function
  public.claim_push(bigint),
  public.finish_push(bigint, text),
  public.release_push(bigint, interval, text),
  public.retry_push_queue(),
  public.prune_push_queue()
  to service_role;
