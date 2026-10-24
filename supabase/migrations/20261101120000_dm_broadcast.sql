-- Migration 40: a direct message's live update as a database broadcast
-- (review 50 F100). Not live; goes live before a build from branch
-- f100-broadcast, from the PC with the founder's yes.
--
-- On the founder's phone (build 560) the private 'dm:<thread>' channel
-- joins, but no Postgres-changes callback ever arrives for a new
-- dm_messages row; on the local stack the same setup works. So the app no
-- longer listens for Postgres changes: the database sends a broadcast on
-- the thread's topic instead, as realtime.send writes it to
-- realtime.messages.
--
-- The broadcast carries only ids (thread, message, author) and what
-- happened ('insert' or 'delete'), never the words: the app reads the
-- message again by id, under dm_messages' own read rule.
--
-- Receiving needs no change: daybook_live_receive (migration 29, with
-- may_use_dm_topic from migration 31) already lets the thread's two
-- people, while neither has blocked the other, receive a broadcast on
-- 'dm:<thread>'. Sending stays closed to the app: daybook_live_send allows
-- only a daybook topic, so only this trigger sends on a thread's topic.

create or replace function public.handle_dm_broadcast()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_op text;
begin
  if tg_op = 'INSERT' then
    v_op := 'insert';
  elsif new.deleted_at is not null and old.deleted_at is null then
    v_op := 'delete';
  else
    return null;
  end if;
  begin
    perform realtime.send(
      jsonb_build_object('thread_id', new.thread_id, 'message_id', new.id,
                         'author_id', new.author_id, 'op', v_op),
      'dm', 'dm:' || new.thread_id::text, true);
  exception when others then
    -- A live-update problem never blocks sending or deleting a message.
    raise warning 'dm broadcast (message %): %', new.id, sqlerrm;
  end;
  return null;
end;
$$;

revoke execute on function public.handle_dm_broadcast() from public, anon, authenticated;

create trigger dm_messages_broadcast after insert on public.dm_messages
  for each row execute function public.handle_dm_broadcast();
create trigger dm_messages_deleted_broadcast after update of deleted_at on public.dm_messages
  for each row execute function public.handle_dm_broadcast();
