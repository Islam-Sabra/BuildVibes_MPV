-- Migration 41, review 50 F102: message pushes as WhatsApp, and mute for a
-- time. Not live.
--
-- - Every direct message and every Space chat message queues a push. The
--   5-minute quiet time (20261012190000_push.sql, 20261016180000_dm.sql)
--   and F97's follow-up (20261031120000_slice10_notifications.sql) end.
--   'dm_follow_up' stays a valid kind (rows already queued on the live
--   server still go through claim_push), but nothing queues it any more.
-- - Each message push carries, in data.count (a string, as FCM data is),
--   that person's unread messages in that conversation, counted when the
--   push is QUEUED, in the trigger, so the new message is included. The
--   push function writes "3 new messages" from it, and Android replaces
--   the conversation's one notification (same tag).
-- - Mute for a time: space_members.notify_until and dm_members.muted_until.
--   A level other than 'all' (or a DM mute) with a null time means always;
--   with a time that has passed it counts as 'all' (unmuted) by itself,
--   with no job needed. space_push_level, the chat push and the DM mute
--   check read the time.
-- - set_space_notifications and mute_dm take an optional until and act on
--   the caller's own row only (auth.uid()); the tables stay read-only to
--   the app, so nobody can set another person's level or mute.
-- - my_spaces, dm_list_row and dm_thread_page return the level or mute in
--   force now, for the bell-slash on the rows.
--
-- Changed functions are re-created from their latest definitions (dumped
-- from the local database with pg_get_functiondef), changing only what
-- F102 needs; each change is marked "F102".
--
-- Live order (from the PC, each with the founder's yes): migration 40
-- (20261101120000_dm_broadcast.sql) is live; then this migration, then the
-- push function deploy, then a build.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

-- Until when a level other than 'all' holds; null = always.
alter table public.space_members add column notify_until timestamptz;
-- Until when a mute holds; null = always.
alter table public.dm_members add column muted_until timestamptz;

-- ---------------------------------------------------------------------------
-- What is in force now
-- ---------------------------------------------------------------------------

-- A Space level now: a passed time puts it back to 'all'.
create or replace function public.space_notify_now(p_notify text, p_until timestamptz)
returns text
language sql
stable
set search_path = ''
as $$
  select case when p_notify is distinct from 'all'
                   and p_until is not null and p_until <= now()
              then 'all' else coalesce(p_notify, 'all') end;
$$;

-- A direct message mute now: a passed time unmutes it.
create or replace function public.dm_muted_now(p_muted boolean, p_until timestamptz)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(p_muted, false) and (p_until is null or p_until > now());
$$;

-- As in 20261012190000_push.sql. F102: the level in force now.
create or replace function public.space_push_level(p_space uuid, p_profile uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select public.space_notify_now(m.notify, m.notify_until)
                   from public.space_members m
                   where m.space_id = p_space and m.profile_id = p_profile
                     and m.left_at is null), 'all');
$$;

-- ---------------------------------------------------------------------------
-- Space chat: a push for every message
-- ---------------------------------------------------------------------------

-- A new chat message (as in 20261012190000_push.sql): a push for each
-- reader whose level in force now is "all". F102: no 5-minute quiet time;
-- each push carries the reader's unread count in the thread (as the
-- thread list counts it: others' messages, not deleted, after the
-- reader's last read), never less than 1.
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
                              'message_id', new.id,
                              -- F102: the reader's unread messages here.
                              'count', greatest(1, (
                                select count(*) from public.messages x
                                where x.thread_id = new.thread_id
                                  and x.deleted_at is null
                                  and x.author_id is distinct from m.profile_id
                                  and x.created_at > coalesce(
                                    (select r.last_read_at from public.thread_reads r
                                     where r.thread_id = new.thread_id
                                       and r.profile_id = m.profile_id), '-infinity')
                                  and not public.blocked_between(m.profile_id, x.author_id)
                              ))::text),
           case when coalesce(ps.message_text, false) and new.kind = 'text'
                then left(new.body, 200) end
    from public.space_members m
    left join public.push_settings ps on ps.profile_id = m.profile_id
    where m.space_id = new.space_id
      and m.left_at is null
      -- F102: the level in force now (a passed mute time is "all").
      and public.space_notify_now(m.notify, m.notify_until) = 'all'
      and m.profile_id is distinct from new.author_id
      -- Who may read the thread (as can_use_thread, for each reader).
      and (v_team is null or m.is_admin
           or exists (select 1 from public.team_members tm
                      where tm.team_id = v_team and tm.profile_id = m.profile_id))
      and not public.blocked_between(m.profile_id, new.author_id)
      and exists (select 1 from public.push_tokens pt where pt.profile_id = m.profile_id);
  exception when others then
    raise warning 'push queue (message %): %', new.id, sqlerrm;
  end;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Direct messages: a push for every message
-- ---------------------------------------------------------------------------

-- A new message (as in 20261031120000_slice10_notifications.sql). F102: in
-- an open thread, every message queues a push with the unread count (the
-- text only if the person chose); no quiet time and no follow-up. A
-- request, one push per new person (none within 30 days of a decline),
-- never with text, unchanged. Not when muted now, declined, across a block
-- or to a hidden account. No Activity row. A push problem never blocks the
-- message.
create or replace function public.handle_dm_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_to public.dm_members;
begin
  begin
    select * into v_to from public.dm_members m
    where m.thread_id = new.thread_id and m.profile_id is distinct from new.author_id;
    -- F102: a mute whose time has passed no longer holds.
    if v_to.profile_id is null or public.dm_muted_now(v_to.muted, v_to.muted_until)
       or v_to.state = 'declined'
       or public.is_hidden_account(v_to.profile_id)
       or public.dm_blocked(v_to.profile_id, new.author_id) then
      return null;
    end if;
    if v_to.state = 'request' then
      if v_to.request_pushed_at is not null
         and (v_to.declined_at is null or v_to.declined_at >= now() - interval '30 days'
              or v_to.request_pushed_at > v_to.declined_at + interval '30 days') then
        return null;
      end if;
      update public.dm_members set request_pushed_at = now()
      where thread_id = new.thread_id and profile_id = v_to.profile_id;
      if exists (select 1 from public.push_tokens t where t.profile_id = v_to.profile_id) then
        insert into public.push_queue (profile_id, kind, actor_id, dm_thread_id, data)
        values (v_to.profile_id, 'dm_request', new.author_id, new.thread_id,
                jsonb_build_object('dm_thread_id', new.thread_id, 'message_id', new.id));
      end if;
      return null;
    end if;
    if not exists (select 1 from public.push_tokens t where t.profile_id = v_to.profile_id) then
      return null;
    end if;
    -- F102: every message, with the person's unread count in the thread.
    insert into public.push_queue (profile_id, kind, actor_id, dm_thread_id, data, message_text)
    select v_to.profile_id, 'dm_message', new.author_id, new.thread_id,
           jsonb_build_object('dm_thread_id', new.thread_id, 'message_id', new.id,
                              'count', greatest(1, (
                                select count(*) from public.dm_messages x
                                where x.thread_id = new.thread_id
                                  and x.author_id is distinct from v_to.profile_id
                                  and x.deleted_at is null
                                  and x.created_at > coalesce(v_to.last_read_at, '-infinity')
                              ))::text),
           case when coalesce(ps.message_text, false) and new.kind = 'text' then left(new.body, 200) end
    from (select 1) one
    left join public.push_settings ps on ps.profile_id = v_to.profile_id;
  exception when others then
    raise warning 'push queue (direct message %): %', new.id, sqlerrm;
  end;
  return null;
end;
$$;

-- As in 20261031120000_slice10_notifications.sql: follow-ups queued before
-- this migration still go out (or close) as designed. F102: the mute check
-- reads its time.
create or replace function public.claim_push(p_id bigint)
returns setof public.push_queue
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_row public.push_queue;
  v_count integer;
begin
  update public.push_queue
  set claimed_at = now(), attempts = attempts + 1
  where id = p_id
    and sent_at is null
    and (claimed_at is null or claimed_at < now() - interval '1 minute')
    and (not_before is null or not_before <= now())
    and attempts < 5
  returning * into v_row;
  if v_row.id is null then
    return;
  end if;
  if v_row.kind = 'dm_follow_up' then
    if exists (select 1 from public.push_queue q
               where q.profile_id = v_row.profile_id and q.kind = 'dm_message'
                 and q.dm_thread_id = v_row.dm_thread_id
                 and q.created_at >= v_row.not_before) then
      update public.push_queue
      set sent_at = now(), claimed_at = null, error = 'superseded'
      where id = v_row.id;
      return;
    end if;
    select count(*) into v_count
    from public.dm_messages m
    join public.dm_members me on me.thread_id = m.thread_id and me.profile_id = v_row.profile_id
    where m.thread_id = v_row.dm_thread_id
      and m.author_id = v_row.actor_id
      and m.deleted_at is null
      and m.created_at > (v_row.data ->> 'since')::timestamptz
      and m.created_at < v_row.not_before
      and (me.last_read_at is null or m.created_at > me.last_read_at)
      and me.state = 'open' and not public.dm_muted_now(me.muted, me.muted_until)
      and not public.dm_blocked(v_row.profile_id, v_row.actor_id);
    if v_count = 0 then
      update public.push_queue
      set sent_at = now(), claimed_at = null, error = 'read in time'
      where id = v_row.id;
      return;
    end if;
    update public.push_queue
    set data = data || jsonb_build_object('count', v_count::text)
    where id = v_row.id
    returning * into v_row;
  end if;
  return next v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- Setting your own level or mute, with an optional until
-- ---------------------------------------------------------------------------

-- As in 20261011160000_spaces.sql, with [p_until]: until when a level
-- other than 'all' holds (null = always). 'all' clears the time. A time
-- that has already passed is refused. Only the caller's own row.
drop function public.set_space_notifications(uuid, text);
create function public.set_space_notifications(
  p_space uuid, p_level text, p_until timestamptz default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_member(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_level is distinct from 'all' and p_until is not null and p_until <= now() then
    raise exception 'until has passed' using errcode = '22023';
  end if;
  update public.space_members
  set notify = p_level,
      notify_until = case when p_level = 'all' then null else p_until end
  where space_id = p_space and profile_id = auth.uid();
end;
$$;

-- As in 20261016180000_dm.sql, with [p_until]: until when the mute holds
-- (null = always). Unmuting clears the time. A time that has already
-- passed is refused. Only the caller's own row.
drop function public.mute_dm(uuid, boolean);
create function public.mute_dm(p_thread uuid, p_on boolean, p_until timestamptz default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_read_dm(p_thread) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if coalesce(p_on, true) and p_until is not null and p_until <= now() then
    raise exception 'until has passed' using errcode = '22023';
  end if;
  update public.dm_members
  set muted = coalesce(p_on, true),
      muted_until = case when coalesce(p_on, true) then p_until end
  where thread_id = p_thread and profile_id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- What the rows show
-- ---------------------------------------------------------------------------

-- As in 20261019180000_slice2_cards.sql. F102: two more columns, the level
-- in force now and, when it isn't 'all', until when (null = always). The
-- return type changes, so it is dropped and made again with its grants.
drop function public.my_spaces();
create function public.my_spaces()
returns table (space_id uuid, name text, kind text, access text, project_id uuid,
               project_name text, project_type_id text, pass text, is_admin boolean,
               pending_requests integer, joined_at timestamptz, needs_you integer,
               last_activity_at timestamptz, notify text, notify_until timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  -- needs_you() once for all Spaces, then counted per Space.
  with needs as (
    select n.space_id, count(*)::int as n
    from public.needs_you() n
    group by n.space_id
  )
  select s.id, s.name, s.kind, s.access, s.project_id, p.name, p.type_id,
         m.pass, m.is_admin,
         case when m.is_admin then (
           select count(*)::int from public.space_join_requests r
           where r.space_id = s.id and r.status = 'pending') else 0 end,
         m.confirmed_at,
         coalesce(needs.n, 0),
         case when m.is_admin and not hidden.yes then (
           select sp.last_activity_at from public.space_posts sp
           where sp.space_id = s.id and sp.deleted_at is null
           order by sp.last_activity_at desc, sp.id desc
           limit 1)
         else greatest(
           (select sp.last_activity_at from public.space_posts sp
            where sp.space_id = s.id and sp.deleted_at is null and sp.team_id is null
            order by sp.last_activity_at desc
            limit 1),
           (select max(t.at)
            from public.team_members tm
            cross join lateral (
              select sp.last_activity_at as at from public.space_posts sp
              where sp.team_id = tm.team_id and sp.space_id = s.id
                and sp.deleted_at is null and sp.team_id is not null
              order by sp.last_activity_at desc
              limit 1) t
            where tm.profile_id = auth.uid()),
           (select sp.last_activity_at from public.space_posts sp
            where sp.author_id = auth.uid() and sp.space_id = s.id
              and sp.deleted_at is null and sp.team_id is not null
            order by sp.last_activity_at desc
            limit 1),
           (select max(sp.last_activity_at)
            from public.work_items w
            join public.space_posts sp on sp.id = w.id
            where w.owner_id = auth.uid() and w.space_id = s.id
              and sp.deleted_at is null and sp.team_id is not null))
         end,
         -- F102: the level in force now, and its time.
         public.space_notify_now(m.notify, m.notify_until),
         case when public.space_notify_now(m.notify, m.notify_until) <> 'all'
              then m.notify_until end
  from public.space_members m
  join public.spaces s on s.id = m.space_id
  left join public.projects p on p.id = s.project_id
  left join needs on needs.space_id = s.id
  cross join (select public.is_hidden_account(auth.uid()) as yes) hidden
  where m.profile_id = auth.uid() and m.left_at is null and s.deleted_at is null
  order by m.confirmed_at desc;
$$;

-- As in 20261016180000_dm.sql. F102: the mute in force now, and its time.
create or replace function public.dm_list_row(p_thread public.dm_threads, p_member public.dm_members)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'thread', p_thread.id,
    'person', public.dm_person(public.dm_other(p_thread, auth.uid())),
    'last_message_at', p_thread.last_message_at,
    'muted', public.dm_muted_now(p_member.muted, p_member.muted_until),
    'muted_until', case when public.dm_muted_now(p_member.muted, p_member.muted_until)
                        then p_member.muted_until end,
    -- A dot, never a number.
    'unread', exists (select 1 from public.dm_messages m
                      where m.thread_id = p_thread.id and m.author_id is distinct from auth.uid()
                        and m.deleted_at is null
                        and m.created_at > coalesce(p_member.last_read_at, '-infinity'::timestamptz)
                        and not public.reported_by_me('dm_message', m.id)),
    'last', public.dm_preview(p_thread.id));
$$;

-- As in 20261016180000_dm.sql. F102: the mute in force now,
-- and its time.
create or replace function public.dm_thread_page(
  p_thread uuid, p_before timestamptz default null, p_before_id uuid default null,
  p_limit integer default 50)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when public.can_read_dm(t.id) then jsonb_build_object(
    'thread', t.id,
    'person', public.dm_person(public.dm_other(t, auth.uid())),
    'state', case when me.state = 'request'
                       and public.dm_work_link(auth.uid(), public.dm_other(t, auth.uid()))
                  then 'open' else me.state end,
    'muted', public.dm_muted_now(me.muted, me.muted_until),
    'muted_until', case when public.dm_muted_now(me.muted, me.muted_until)
                        then me.muted_until end,
    'shared_space', public.dm_shared_space(t.id),
    'messages', coalesce((
      select jsonb_agg(x.row order by x.created_at desc, x.id desc) from (
        select m.id, m.created_at, jsonb_strip_nulls(jsonb_build_object(
                 'id', m.id, 'from_me', m.author_id is not distinct from auth.uid(),
                 'kind', m.kind, 'body', m.body, 'deleted', m.deleted_at is not null,
                 'created_at', m.created_at,
                 'reply_to', (select jsonb_strip_nulls(jsonb_build_object(
                                       'id', r.id, 'text', left(r.body, 120),
                                       'from_me', r.author_id is not distinct from auth.uid(),
                                       'deleted', r.deleted_at is not null))
                              from public.dm_messages r
                              where r.id = m.reply_to and not public.reported_by_me('dm_message', r.id)),
                 'tap_to_show', case when (me.state = 'declined'
                                           or (me.state = 'request'
                                               and not public.dm_work_link(auth.uid(), public.dm_other(t, auth.uid()))))
                                          and m.author_id is distinct from auth.uid()
                                          and exists (select 1 from public.dm_attachments a
                                                      where a.message_id = m.id)
                                     then true end,
                 'files', (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                    'path', a.storage_path, 'name', a.name, 'mime', a.mime,
                                    'bytes', a.bytes, 'width', a.width, 'height', a.height,
                                    'duration_ms', a.duration_ms)) order by a.sort)
                           from public.dm_attachments a
                           where a.message_id = m.id and m.deleted_at is null))) as row
        from public.dm_messages m
        where m.thread_id = t.id and not public.reported_by_me('dm_message', m.id)
          and (p_before is null or (m.created_at, m.id) < (p_before, coalesce(p_before_id, m.id)))
        order by m.created_at desc, m.id desc
        limit least(greatest(coalesce(p_limit, 50), 1), 200)) x), '[]'::jsonb)) end
  from public.dm_threads t
  join public.dm_members me on me.thread_id = t.id and me.profile_id = auth.uid()
  where t.id = p_thread;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.space_notify_now(text, timestamptz),
  public.dm_muted_now(boolean, timestamptz),
  public.set_space_notifications(uuid, text, timestamptz),
  public.mute_dm(uuid, boolean, timestamptz),
  public.my_spaces()
  from public, anon;
-- Internal helpers.
revoke execute on function
  public.space_notify_now(text, timestamptz),
  public.dm_muted_now(boolean, timestamptz)
  from authenticated;
grant execute on function
  public.set_space_notifications(uuid, text, timestamptz),
  public.mute_dm(uuid, boolean, timestamptz),
  public.my_spaces()
  to authenticated;
