-- Migration 63 (review 114): the alerts setup after sign-up. The server
-- side, as the review's build notes say.
--
-- 1. send_test_alert(): "Send me a test" queues one need_you_test push to
--    the caller, and only the caller: it takes no person, so it can reach
--    nobody else, in a Space or not. At most 3 an hour per person. The push
--    goes on the strong channel (the push function: the need_you channel,
--    iOS time-sensitive), and carries no name, Space or text.
-- 2. The push function puts sent_at (the queue row's created_at, ISO 8601
--    UTC) in the data part of every push, so the app can tell how late one
--    arrived (PS3). Nothing here: claim_push already returns the row.

-- ---------------------------------------------------------------------------
-- Push kinds
-- ---------------------------------------------------------------------------

alter table public.push_queue drop constraint push_queue_kind_check;
alter table public.push_queue add constraint push_queue_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'announcement_new', 'checklist_for_you', 'activity_invited', 'activity_starting',
  'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow', 'post_reply', 'chat_message',
  'dm_message', 'dm_request', 'dm_follow_up',
  'work_reminder', 'scheduled_failed',
  'check_in_open', 'check_in_summary',
  'post_reaction', 'work_item_archived', 'check_in_nudge', 'need_you', 'need_you_answer',
  'scheduled_expiring',
  'need_you_test'));

-- ---------------------------------------------------------------------------
-- 1. Send me a test
-- ---------------------------------------------------------------------------

-- PS1: one need_you_test push to the caller. Signed out, or an account
-- going away (is_hidden_account): refused. The fourth in an hour: refused
-- with 'at most 3 an hour'. A caller with no phone registered (no push
-- token): nothing is queued and the call returns, as every other push does
-- (the app registers its token before the screen shows; without one there
-- is nowhere to send), and it uses none of the 3.
create or replace function public.send_test_alert()
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
  if public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not exists (select 1 from public.push_tokens t where t.profile_id = v_me) then
    return;
  end if;
  -- Two at once can't both be the fourth.
  perform pg_advisory_xact_lock(hashtextextended('need_you_test:' || v_me::text, 0));
  if (select count(*) from public.push_queue q
      where q.profile_id = v_me and q.kind = 'need_you_test'
        and q.created_at > now() - interval '1 hour') >= 3 then
    raise exception 'at most 3 an hour' using errcode = '22023';
  end if;
  insert into public.push_queue (profile_id, kind) values (v_me, 'need_you_test');
end;
$$;

revoke all on function public.send_test_alert() from public, anon;
grant execute on function public.send_test_alert() to authenticated;
