-- Migration 39, slice 10 (review 87): no signal and notifications. Not live.
--
-- F97 (review 50): a direct message inside the 5-minute quiet time of its
-- conversation is no longer lost. At the quiet time's end, one follow-up
-- push ("2 new messages") goes if the newer messages are
-- still unread; never more than one per quiet time, never with text.
--
-- Activity rows about a daybook post (a new announcement, a checklist for
-- you, an invitation, a new file version, a change or a cancel) need no
-- change: activity_rows() (20261019180000_slice2_cards.sql) already gives
-- the post's title, space_post_id and post_kind, and only while the reader
-- may see the post. Test 39 proves it.
--
-- Goes live after 38 (20261029120000) and 34 (20261030120000), with the
-- push function's new text (supabase/functions/push), from the PC with
-- the founder's yes.

-- ---------------------------------------------------------------------------
-- F97: one follow-up push per quiet time
-- ---------------------------------------------------------------------------

alter table public.push_queue drop constraint push_queue_kind_check;
alter table public.push_queue add constraint push_queue_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'announcement_new', 'checklist_for_you', 'activity_invited', 'activity_starting',
  'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow', 'post_reply', 'chat_message',
  'dm_message', 'dm_request', 'dm_follow_up'));
drop index public.push_queue_dm_thread_idx;
create index push_queue_dm_thread_idx on public.push_queue (profile_id, dm_thread_id, created_at desc)
  where kind in ('dm_message', 'dm_request', 'dm_follow_up');

-- A new message (as in 20261016180000_dm.sql, with the follow-up added): in
-- an open thread, one push per thread every 5 minutes (the text only if
-- the person chose); inside that quiet time, one follow-up queued for its
-- end. A request, one push per new person (none within 30 days of a
-- decline), never with text. Not when muted, declined, across a block or
-- to a hidden account. No Activity row. A push problem never blocks the
-- message.
create or replace function public.handle_dm_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_to public.dm_members;
  v_first public.push_queue;
begin
  begin
    select * into v_to from public.dm_members m
    where m.thread_id = new.thread_id and m.profile_id is distinct from new.author_id;
    if v_to.profile_id is null or v_to.muted or v_to.state = 'declined'
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
    -- The push that opened this conversation's quiet time, if one did in
    -- the last 5 minutes.
    select * into v_first from public.push_queue q
    where q.profile_id = v_to.profile_id and q.kind = 'dm_message'
      and q.dm_thread_id = new.thread_id
      and q.created_at > now() - interval '5 minutes'
    order by q.created_at desc
    limit 1;
    if v_first.id is null then
      insert into public.push_queue (profile_id, kind, actor_id, dm_thread_id, data, message_text)
      select v_to.profile_id, 'dm_message', new.author_id, new.thread_id,
             jsonb_build_object('dm_thread_id', new.thread_id, 'message_id', new.id),
             case when coalesce(ps.message_text, false) and new.kind = 'text' then left(new.body, 200) end
      from (select 1) one
      left join public.push_settings ps on ps.profile_id = v_to.profile_id;
    elsif not exists (select 1 from public.push_queue q
                      where q.profile_id = v_to.profile_id and q.kind = 'dm_follow_up'
                        and q.dm_thread_id = new.thread_id
                        and q.created_at >= v_first.created_at) then
      -- F97: one follow-up at the quiet time's end; claim_push sends it
      -- only if what came after the first push is still unread.
      insert into public.push_queue (profile_id, kind, actor_id, dm_thread_id, data, not_before)
      values (v_to.profile_id, 'dm_follow_up', new.author_id, new.thread_id,
              jsonb_build_object('dm_thread_id', new.thread_id, 'since', v_first.created_at),
              v_first.created_at + interval '5 minutes');
    end if;
  exception when others then
    raise warning 'push queue (direct message %): %', new.id, sqlerrm;
  end;
  return null;
end;
$$;

-- Takes one row to send, once (as in 20261012190000_push.sql): unsent, not
-- claimed in the last minute (a send that crashed is claimed again), and
-- not asked to wait. Empty when another call has it, or it is done.
-- A follow-up (F97) goes only if the messages after its first push and
-- before the quiet time's end are still unread, still muted-free and open,
-- with how many in "count"; otherwise it is closed without a push. If a new
-- quiet time has already begun with its own push (the cron sends up to a
-- minute after not_before), that push has the news: the follow-up is
-- closed as 'superseded' (review 88 S1).
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
      and me.state = 'open' and not me.muted
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
