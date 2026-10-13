-- Migration 15: safety (week 8 part 1). Brief: docs/reviews/2026-10-13-23-week8-brief.md §2.
--
-- - reports: anyone may report a post, a reply, a person or a Space chat
--   message they can see, never their own, at most 20 a day. The reported
--   post, reply or message is hidden for the reporter at once (the read
--   rules below). Nobody reads reports in the app: the reported person is
--   never told who reported, and the reporter sees nothing back.
-- - The founder decides, as the service role, through supabase/ops/
--   moderation.sql: dismiss, or remove. A removal soft-deletes the content
--   for everyone (as its author's delete does), keeps a private copy so an
--   appeal can bring it back, and tells the author in Activity.
-- - content_removals: what was removed, why, and the author's one appeal
--   (within 14 days, at most 500 characters). The author reads their own
--   rows; the copy of the content stays service-role only.
-- - block(person, on): the existing blocks table. Every block rule already
--   on the server (posts, replies, photos, profiles, Activity, pushes)
--   applies to blocks made here.
-- - markets.moderation_email: where report alerts go, per market (the
--   report-alert function, supabase/ops/report_alert_webhook.sql).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

alter table public.markets
  add column moderation_email text
    check (moderation_email is null or moderation_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$');
comment on column public.markets.moderation_email is
  'Where report alerts go for this market. Set by the founder; null sends none.';

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  target_kind text not null check (target_kind in ('post', 'reply', 'profile', 'message')),
  target_id uuid not null,
  -- The six R1 reasons.
  reason text not null check (reason in (
    'spam', 'scam_or_misleading', 'inappropriate_content', 'harassment',
    'unsafe_construction_advice', 'other')),
  -- Needed for "Something else".
  note text check (note is null or length(note) between 1 and 500),
  status text not null default 'open' check (status in ('open', 'removed', 'dismissed')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (reporter_id, target_kind, target_id),
  check (reason <> 'other' or note is not null)
);
create index reports_target_idx on public.reports (target_kind, target_id);
create index reports_open_idx on public.reports (created_at) where status = 'open';

create table public.content_removals (
  id uuid primary key default gen_random_uuid(),
  target_kind text not null check (target_kind in ('post', 'reply', 'message')),
  target_id uuid not null,
  author_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null check (reason in (
    'spam', 'scam_or_misleading', 'inappropriate_content', 'harassment',
    'unsafe_construction_advice', 'other')),
  report_id uuid references public.reports (id) on delete set null,
  removed_at timestamptz not null default now(),
  appeal_note text check (appeal_note is null or length(appeal_note) between 1 and 500),
  appeal_at timestamptz,
  appeal_status text not null default 'none'
    check (appeal_status in ('none', 'open', 'upheld', 'reversed')),
  check ((appeal_status = 'none') = (appeal_at is null))
);
create index content_removals_author_idx on public.content_removals (author_id, removed_at desc);

-- The removed text, so an appeal can restore it. Service role only.
create table public.removed_content (
  removal_id uuid primary key references public.content_removals (id) on delete cascade,
  body text
);

-- Activity: "Your post was removed" and the appeal's result.
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow',
  'post_reply', 'post_useful', 'content_removed', 'appeal_decided'));

-- ---------------------------------------------------------------------------
-- Hidden for the reporter
-- ---------------------------------------------------------------------------

-- True when the caller reported [p_kind] [p_id].
create or replace function public.reported_by_me(p_kind text, p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.reports r
                 where r.reporter_id = auth.uid() and r.target_kind = p_kind
                   and r.target_id = p_id);
$$;

drop policy posts_read on public.posts;
create policy posts_read on public.posts
  for select to authenticated
  using (deleted_at is null
         and (author_id = auth.uid() or not public.is_blocked_with(author_id))
         and not public.reported_by_me('post', id));

drop policy post_replies_read on public.post_replies;
create policy post_replies_read on public.post_replies
  for select to authenticated
  using (deleted_at is null and public.can_see_post(post_id)
         and (author_id = auth.uid() or not public.is_blocked_with(author_id))
         and not public.reported_by_me('reply', id));

drop policy messages_read on public.messages;
create policy messages_read on public.messages
  for select to authenticated
  using (public.can_use_thread(thread_id) and not public.reported_by_me('message', id));

-- A post you reported is gone for you, with its photos, replies and marks.
create or replace function public.can_see_post(p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.posts p
    where p.id = p_post and p.deleted_at is null
      and (p.author_id = auth.uid() or not public.is_blocked_with(p.author_id))
      and not public.reported_by_me('post', p.id));
$$;

-- The thread list: a message you reported is not its last message for you,
-- and doesn't count as unread.
create or replace function public.space_threads(p_space uuid)
returns table (
  thread_id uuid,
  team_id uuid,
  team_name text,
  last_message_id uuid,
  last_kind text,
  last_body text,
  last_author_id uuid,
  last_at timestamptz,
  last_deleted boolean,
  unread integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id, t.team_id, tm.name,
         lm.id, lm.kind, lm.body, lm.author_id, lm.created_at, lm.deleted_at is not null,
         (select count(*)::int from public.messages m
          where m.thread_id = t.id and m.deleted_at is null
            and m.author_id is distinct from auth.uid()
            and not public.reported_by_me('message', m.id)
            and m.created_at > coalesce(
              (select r.last_read_at from public.thread_reads r
               where r.thread_id = t.id and r.profile_id = auth.uid()), '-infinity'))
  from public.threads t
  left join public.teams tm on tm.id = t.team_id
  left join lateral (
    select m.* from public.messages m where m.thread_id = t.id
      and not public.reported_by_me('message', m.id)
    order by m.created_at desc limit 1) lm on true
  where t.space_id = p_space and public.can_use_thread(t.id)
  order by (t.team_id is not null), lm.created_at desc nulls last, tm.name;
$$;

-- Home's Today: a message you reported never makes the chat line.
create or replace function public.today_in_spaces(p_day_start timestamptz)
returns table (
  space_id uuid,
  space_name text,
  project_id uuid,
  project_name text,
  -- 'work_item', 'library' or 'chat': the Space tab to open.
  change text,
  work_item_id uuid,
  work_item_ref text,
  work_item_title text,
  event_kind text,
  file_id uuid,
  file_name text,
  thread_id uuid,
  team_id uuid,
  message_kind text,
  message_body text,
  actor_id uuid,
  actor_name text,
  at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select m.space_id, s.name, s.project_id,
           greatest(coalesce(v.seen_at, '-infinity'::timestamptz),
                    public.day_start(p_day_start)) as since
    from public.space_members m
    join public.spaces s on s.id = m.space_id and s.deleted_at is null
    left join public.space_visits v
      on v.space_id = m.space_id and v.profile_id = auth.uid()
    where m.profile_id = auth.uid() and m.left_at is null
  ),
  changes as (
    select mine.space_id, 1 as rank, ev.created_at as at, 'work_item' as change,
           w.id as item, w.ref, w.title, ev.kind as event_kind,
           null::uuid as file, null::text as file_name,
           null::uuid as thread, null::uuid as team,
           null::text as msg_kind, null::text as msg_body, ev.actor_id
    from public.work_item_events ev
    join public.work_items w on w.id = ev.work_item_id
    join mine on mine.space_id = w.space_id
    where ev.created_at > public.day_start(p_day_start)
      and ev.created_at > mine.since
      and ev.actor_id is distinct from auth.uid()
    union all
    select mine.space_id, 2, f.created_at, 'library', null, null, null, null,
           f.id, f.name, null, f.team_id, null, null, f.uploaded_by
    from mine
    join public.library_files f
      on f.space_id = mine.space_id and f.created_at > mine.since
    where f.deleted_at is null and f.uploaded_by is distinct from auth.uid()
      and public.can_read_library_file(f.id)
    union all
    -- Each thread you may read once, then its newest message by someone
    -- else since your visit (messages_thread_idx).
    select mine.space_id, 3, msg.created_at, 'chat', null, null, null, null,
           null, null, t.id, t.team_id, msg.kind, left(msg.body, 120),
           msg.author_id
    from mine
    join public.threads t on t.space_id = mine.space_id
    cross join lateral (
      select x.created_at, x.kind, x.body, x.author_id
      from public.messages x
      where x.thread_id = t.id and x.created_at > mine.since
        and x.deleted_at is null and x.author_id is distinct from auth.uid()
        and not public.blocked_between(auth.uid(), x.author_id)
        and not public.reported_by_me('message', x.id)
      order by x.created_at desc
      limit 1
    ) msg
    where public.can_use_thread(t.id)
  ),
  best as (
    select distinct on (c.space_id) c.*
    from changes c
    where not public.blocked_between(auth.uid(), c.actor_id)
    order by c.space_id, c.rank, c.at desc
  )
  select b.space_id, mine.name, mine.project_id, p.name, b.change,
         b.item, b.ref, b.title, b.event_kind, b.file, b.file_name,
         b.thread, b.team, b.msg_kind, b.msg_body, b.actor_id,
         nullif(trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')), ''),
         b.at
  from best b
  join mine on mine.space_id = b.space_id
  left join public.projects p on p.id = mine.project_id
  left join public.profiles a on a.id = b.actor_id
  order by b.at desc;
$$;

-- Activity: removals and appeal results belong to "Your record".
create or replace function public.activity_rows()
returns setof public.activity_row
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select n.*,
           case when n.kind in ('role_confirmed', 'content_removed', 'appeal_decided') then 'record'
                when n.kind = 'follow' then 'network'
                when n.kind in ('post_reply', 'post_useful') then 'posts'
                else 'space' end as group_kind
    from public.notifications n
    where n.profile_id = auth.uid()
      and n.created_at >= now() - interval '7 days'
      and not public.blocked_between(auth.uid(), n.actor_id)
  ),
  shown as (
    select r.*, s.name as space_name, m.pass, w.ref, w.title,
           case when r.kind = 'post_reply' then left(pr.body, 120)
                when r.post_id is not null then left(p.body, 120) end as context,
           jr.status as request_status, cp.project_id, prj.name as project_name,
           nullif(trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')), '')
             as actor_name
    from mine r
    left join public.spaces s on s.id = r.space_id
    left join public.space_members m
      on m.space_id = r.space_id and m.profile_id = auth.uid() and m.left_at is null
    left join public.work_items w on w.id = r.work_item_id
    left join public.posts p on p.id = r.post_id
    left join public.post_replies pr on pr.id = r.reply_id
    left join public.space_join_requests jr on jr.id = r.request_id
    left join public.cv_projects cp on cp.id = (r.payload ->> 'cv_project_id')::uuid
    left join public.projects prj on prj.id = cp.project_id
    left join public.profiles a on a.id = r.actor_id
    where (r.space_id is null or (s.deleted_at is null and m.profile_id is not null))
      -- Requests to join only while you are still an admin.
      and (r.kind <> 'join_request' or m.is_admin)
      -- Post rows only while you may see the post (not across a block).
      and (r.post_id is null or public.can_see_post(r.post_id))
      and (r.reply_id is null or pr.deleted_at is null)
      and (r.kind <> 'role_confirmed' or cp.id is not null)
  )
  select x.id, x.kind, x.group_kind, x.space_id, x.space_name, x.pass,
         x.work_item_id, x.ref, x.title, x.post_id, x.reply_id, x.context,
         x.request_id, x.request_status, x.project_id, x.project_name,
         x.actor_id, x.actor_name, x.payload, x.created_at, x.read_at,
         (row_number() over (partition by x.group_kind, x.space_id
                             order by x.created_at, x.id))::int,
         case when x.kind = 'post_useful' then
           array(select u.name from public.useful_names(x.post_id) u) end
  from shown x;
$$;

-- ---------------------------------------------------------------------------
-- Reporting and blocking (the app)
-- ---------------------------------------------------------------------------

create or replace function public.report(
  p_kind text,
  p_id uuid,
  p_reason text,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_author uuid;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_id uuid;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_kind not in ('post', 'reply', 'profile', 'message') then
    raise exception 'post, reply, profile or message' using errcode = '22023';
  end if;
  if p_reason is null or p_reason not in ('spam', 'scam_or_misleading', 'inappropriate_content',
                                          'harassment', 'unsafe_construction_advice', 'other') then
    raise exception 'choose a reason' using errcode = '22023';
  end if;
  if p_reason = 'other' and v_note is null then
    raise exception 'say what is wrong' using errcode = '22023';
  end if;
  if length(v_note) > 500 then
    raise exception 'at most 500 characters' using errcode = '22023';
  end if;

  -- Already reported (and so hidden for you now): the same report.
  select r.id into v_id from public.reports r
  where r.reporter_id = v_me and r.target_kind = p_kind and r.target_id = p_id;
  if v_id is not null then
    return v_id;
  end if;

  -- Only what you can see.
  v_author := case p_kind
    when 'post' then (select p.author_id from public.posts p
                      where p.id = p_id and public.can_see_post(p.id))
    when 'reply' then (select r.author_id from public.post_replies r
                       where r.id = p_id and r.deleted_at is null
                         and public.can_see_post(r.post_id)
                         and not public.is_blocked_with(r.author_id))
    when 'message' then (select m.author_id from public.messages m
                         where m.id = p_id and m.deleted_at is null and m.kind <> 'work_item'
                           and public.can_use_thread(m.thread_id))
    when 'profile' then (select pr.id from public.profiles pr
                         where pr.id = p_id and not public.is_blocked_with(pr.id))
  end;
  if v_author is null then
    raise exception 'not found' using errcode = '42501';
  end if;
  if v_author = v_me then
    raise exception 'you can''t report your own' using errcode = '22023';
  end if;

  -- At most 20 a day, counted under a per-person lock.
  perform pg_advisory_xact_lock(hashtextextended('report:' || v_me::text, 0));
  if (select count(*) from public.reports r
      where r.reporter_id = v_me and r.created_at > now() - interval '1 day') >= 20 then
    raise exception 'too many reports today' using errcode = 'P0001';
  end if;

  insert into public.reports (reporter_id, target_kind, target_id, reason, note)
  values (v_me, p_kind, p_id, p_reason, v_note)
  returning id into v_id;
  return v_id;
end;
$$;

-- Block or unblock a person (the profile ••• menu, S7). The blocks table
-- and its rules are migration 2's; following stops both ways on a block.
create or replace function public.block(p_person uuid, p_on boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_person is null or p_person = v_me then
    raise exception 'you can''t block yourself' using errcode = '22023';
  end if;
  if not exists (select 1 from public.profiles where id = p_person) then
    raise exception 'not found' using errcode = '42501';
  end if;
  if p_on then
    insert into public.blocks (blocker_id, blocked_id) values (v_me, p_person)
    on conflict do nothing;
  else
    delete from public.blocks where blocker_id = v_me and blocked_id = p_person;
  end if;
end;
$$;

-- S7: the people you blocked, newest first. Your own count is allowed.
create or replace function public.my_blocks()
returns table (profile_id uuid, first_name text, last_name text, headline text, blocked_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.first_name, p.last_name, p.headline, b.created_at
  from public.blocks b
  join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Removals and appeals
-- ---------------------------------------------------------------------------

-- R3 for the author: what was removed and why, a short copy of it, and
-- whether an appeal is still possible. Nothing for anyone else.
create or replace function public.my_removal(p_id uuid)
returns table (
  id uuid,
  target_kind text,
  reason text,
  removed_at timestamptz,
  excerpt text,
  appeal_status text,
  appeal_at timestamptz,
  can_appeal boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.target_kind, c.reason, c.removed_at, left(rc.body, 200),
         c.appeal_status, c.appeal_at,
         c.appeal_status = 'none' and c.removed_at > now() - interval '14 days'
  from public.content_removals c
  left join public.removed_content rc on rc.removal_id = c.id
  where c.id = p_id and c.author_id = auth.uid();
$$;

-- R4: the author asks once, within 14 days.
create or replace function public.appeal(p_removal uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.content_removals;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  select * into v_row from public.content_removals where id = p_removal for update;
  if v_row.id is null or v_row.author_id is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_row.appeal_status <> 'none' then
    raise exception 'you already asked' using errcode = 'P0001';
  end if;
  if v_row.removed_at < now() - interval '14 days' then
    raise exception 'the 14 days to ask have passed' using errcode = 'P0001';
  end if;
  if v_note is null or length(v_note) > 500 then
    raise exception 'say why, in at most 500 characters' using errcode = '22023';
  end if;
  update public.content_removals
  set appeal_note = v_note, appeal_at = now(), appeal_status = 'open'
  where id = p_removal;
end;
$$;

-- The founder (service role, supabase/ops/moderation.sql): dismiss, or
-- remove the post, reply or message. Every open report on the same thing
-- is decided with it. Returns the removal's id.
create or replace function public.decide_report(p_id uuid, p_action text, p_reason text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report public.reports;
  v_author uuid;
  v_body text;
  v_removal uuid;
begin
  select * into v_report from public.reports where id = p_id for update;
  if v_report.id is null then
    raise exception 'no such report' using errcode = 'P0002';
  end if;
  if v_report.status <> 'open' then
    raise exception 'already decided' using errcode = 'P0001';
  end if;
  if p_action = 'dismiss' then
    update public.reports set status = 'dismissed', decided_at = now()
    where target_kind = v_report.target_kind and target_id = v_report.target_id
      and status = 'open';
    return null;
  end if;
  if p_action <> 'remove' then
    raise exception 'remove or dismiss' using errcode = '22023';
  end if;
  if v_report.target_kind = 'profile' then
    raise exception 'a person is not removed: block, or ask them to leave' using errcode = '22023';
  end if;

  case v_report.target_kind
    when 'post' then
      select author_id, body into v_author, v_body from public.posts
      where id = v_report.target_id and deleted_at is null for update;
      if v_author is not null then
        update public.posts set deleted_at = now(), body = null where id = v_report.target_id;
      end if;
    when 'reply' then
      select author_id, body into v_author, v_body from public.post_replies
      where id = v_report.target_id and deleted_at is null for update;
      if v_author is not null then
        update public.post_replies set deleted_at = now(), body = null where id = v_report.target_id;
      end if;
    when 'message' then
      select author_id, body into v_author, v_body from public.messages
      where id = v_report.target_id and deleted_at is null for update;
      if v_author is not null then
        update public.messages set deleted_at = now(), body = null where id = v_report.target_id;
      end if;
  end case;

  update public.reports set status = 'removed', decided_at = now()
  where target_kind = v_report.target_kind and target_id = v_report.target_id
    and status = 'open';
  -- Already deleted by its author, or the account is gone: nothing to tell.
  if v_author is null then
    return null;
  end if;

  insert into public.content_removals (target_kind, target_id, author_id, reason, report_id)
  values (v_report.target_kind, v_report.target_id, v_author,
          coalesce(p_reason, v_report.reason), v_report.id)
  returning id into v_removal;
  insert into public.removed_content (removal_id, body) values (v_removal, v_body);
  perform public.add_notification(v_author, 'content_removed', null,
    p_payload => jsonb_build_object('removal_id', v_removal, 'target_kind', v_report.target_kind));
  return v_removal;
end;
$$;

-- The founder decides an appeal: uphold, or reverse (the content comes
-- back as it was). The author hears either way.
create or replace function public.decide_appeal(p_removal uuid, p_action text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.content_removals;
  v_body text;
begin
  select * into v_row from public.content_removals where id = p_removal for update;
  if v_row.id is null then
    raise exception 'no such removal' using errcode = 'P0002';
  end if;
  if v_row.appeal_status <> 'open' then
    raise exception 'no open appeal' using errcode = 'P0001';
  end if;
  if p_action not in ('uphold', 'reverse') then
    raise exception 'uphold or reverse' using errcode = '22023';
  end if;
  if p_action = 'reverse' then
    select body into v_body from public.removed_content where removal_id = p_removal;
    case v_row.target_kind
      when 'post' then
        update public.posts set deleted_at = null, body = v_body where id = v_row.target_id;
      when 'reply' then
        update public.post_replies set deleted_at = null, body = v_body where id = v_row.target_id;
      when 'message' then
        update public.messages set deleted_at = null, body = v_body where id = v_row.target_id;
    end case;
  end if;
  update public.content_removals
  set appeal_status = case when p_action = 'reverse' then 'reversed' else 'upheld' end
  where id = p_removal;
  perform public.add_notification(v_row.author_id, 'appeal_decided', null,
    p_payload => jsonb_build_object('removal_id', p_removal, 'target_kind', v_row.target_kind,
                                    'result', case when p_action = 'reverse' then 'reversed' else 'upheld' end));
end;
$$;

-- ---------------------------------------------------------------------------
-- The moderation alert (the report-alert function, as the service role)
-- ---------------------------------------------------------------------------

-- What the alert email may say: the report's id, kind, reason and time, and
-- where to send it: the moderation address of the reported author's market
-- (or the reporter's, for content without one). Never the content or names.
create or replace function public.report_alert(p_id uuid)
returns table (id uuid, target_kind text, reason text, created_at timestamptz, moderation_email text)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.target_kind, r.reason, r.created_at,
         coalesce(
           (select m.moderation_email from public.markets m
            join public.profiles a on a.home_market_id = m.id
            where a.id = case r.target_kind
              when 'post' then (select author_id from public.posts where id = r.target_id)
              when 'reply' then (select author_id from public.post_replies where id = r.target_id)
              when 'message' then (select author_id from public.messages where id = r.target_id)
              when 'profile' then r.target_id end),
           (select m.moderation_email from public.markets m
            join public.profiles rp on rp.home_market_id = m.id
            where rp.id = r.reporter_id))
  from public.reports r
  where r.id = p_id;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security and grants
-- ---------------------------------------------------------------------------

alter table public.reports enable row level security;
alter table public.content_removals enable row level security;
alter table public.removed_content enable row level security;

-- Your own removals (R3). Reports and the removed copies: no policy, so
-- nobody in the app reads them.
create policy content_removals_read_own on public.content_removals
  for select to authenticated using (author_id = auth.uid());

revoke all on public.reports, public.content_removals, public.removed_content
  from anon, authenticated;
grant select on public.content_removals to authenticated;
grant all on public.reports, public.content_removals, public.removed_content to service_role;

revoke execute on function
  public.reported_by_me(text, uuid),
  public.report(text, uuid, text, text),
  public.block(uuid, boolean),
  public.my_blocks(),
  public.my_removal(uuid),
  public.appeal(uuid, text),
  public.decide_report(uuid, text, text),
  public.decide_appeal(uuid, text),
  public.report_alert(uuid)
  from public, anon;
revoke execute on function
  public.decide_report(uuid, text, text),
  public.decide_appeal(uuid, text),
  public.report_alert(uuid)
  from authenticated;
grant execute on function
  -- Policies call it as the signed-in user.
  public.reported_by_me(text, uuid),
  public.report(text, uuid, text, text),
  public.block(uuid, boolean),
  public.my_blocks(),
  public.my_removal(uuid),
  public.appeal(uuid, text)
  to authenticated;
grant execute on function
  public.decide_report(uuid, text, text),
  public.decide_appeal(uuid, text),
  public.report_alert(uuid)
  to service_role;
