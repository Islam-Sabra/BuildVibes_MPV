-- Migration 14: push notifications (week 7 part 3). Brief: docs/reviews/2026-10-12-16-home-activity.md §4.
--
-- - push_tokens: one row per phone (FCM token), with its platform and the
--   language its pushes are written in. Kept by register_push_token and
--   unregister_push_token; a token signed in on another account moves.
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
--   Only people with a phone registered get rows.
-- - The queue holds ids for the deep link, never a project, Space or work
--   item name (founder decision), and the message text only when the
--   person turned "Show message text on lock screen" on.
-- - Sending: the Edge Function `push` (supabase/functions/push), called by
--   a database webhook on push_queue inserts. Deploying it and adding the
--   webhook are live changes and wait for the founder's yes.

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
create index push_tokens_profile_idx on public.push_tokens (profile_id);

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
  -- Only when "Show message text on lock screen" is on.
  message_text text check (length(message_text) <= 200),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  error text check (length(error) <= 500)
);
create index push_queue_thread_idx
  on public.push_queue (profile_id, thread_id, created_at desc)
  where kind = 'chat_message';
create index push_queue_unsent_idx on public.push_queue (created_at) where sent_at is null;

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
  return null;
end;
$$;
create trigger messages_push
  after insert on public.messages
  for each row execute function public.handle_message_push();

-- ---------------------------------------------------------------------------
-- The app's calls
-- ---------------------------------------------------------------------------

-- On sign-in, and whenever FCM gives the phone a new token. A token signed
-- in on another account before moves to this one.
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
          case when p_locale = 'ar' then 'ar' else 'en' end, now())
  on conflict (token) do update
  set profile_id = excluded.profile_id, platform = excluded.platform,
      locale = excluded.locale, updated_at = excluded.updated_at;
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

-- For the nightly cleanup (service role): drop rows sent, or failed, over
-- 7 days ago. Scheduling it waits for the founder's yes.
create or replace function public.prune_push_queue()
returns integer
language sql
volatile
security definer
set search_path = ''
as $$
  with gone as (
    delete from public.push_queue
    where created_at < now() - interval '7 days'
    returning 1
  )
  select count(*)::int from gone;
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
  public.register_push_token(text, text, text),
  public.unregister_push_token(text),
  public.my_push_settings(),
  public.set_push_settings(boolean, boolean, boolean),
  public.prune_push_queue()
  from public, anon;
revoke execute on function
  public.space_push_level(uuid, uuid),
  public.handle_notification_push(),
  public.handle_message_push(),
  public.prune_push_queue()
  from authenticated;
grant execute on function
  public.register_push_token(text, text, text),
  public.unregister_push_token(text),
  public.my_push_settings(),
  public.set_push_settings(boolean, boolean, boolean)
  to authenticated;
grant execute on function public.prune_push_queue() to service_role;
