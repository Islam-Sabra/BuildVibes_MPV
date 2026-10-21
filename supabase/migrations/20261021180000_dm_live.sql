-- Migration 31: a private live channel for a direct message thread
-- (review 64, slice 3). Branch claude/test-tw7wuv. Not live; after
-- migrations 29 and 30.
--
-- As review 63 R1 did for the chat: the app's live updates for a thread
-- are Postgres changes on dm_messages (already in the realtime
-- publication), joined on the private topic 'dm:<thread id>'. With public
-- channels off, joining needs a policy on realtime.messages, so
-- daybook_live_receive also lets in may_use_dm_topic: the thread's two
-- people, while neither has blocked the other (can_read_dm, the thread's
-- own read rule). Receive only: nothing is sent on a thread's topic, so
-- daybook_live_send stays as it is.

create function public.may_use_dm_topic(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_topic ~* '^dm:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.can_read_dm(substr(p_topic, 4)::uuid)
    else false
  end;
$$;

alter policy daybook_live_receive on realtime.messages
  using (realtime.messages.extension = 'broadcast'
         and realtime.messages.topic = (select realtime.topic())
         and ((select public.may_use_daybook_topic((select realtime.topic())))
              or (select public.may_use_thread_topic((select realtime.topic())))
              or (select public.may_use_dm_topic((select realtime.topic())))));

revoke execute on function public.may_use_dm_topic(text) from public, anon;
grant execute on function public.may_use_dm_topic(text) to authenticated;
