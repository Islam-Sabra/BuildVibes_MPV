-- Migration 43: Space chat kept live by the database (review 89, F103).
-- Not live.
--
-- Space chat listened for Postgres changes on its private 'thread:<id>'
-- channel: the path F100 proved silent on the live server for direct
-- messages. So, as migration 40 did for 'dm:', the database broadcasts:
--
-- - After a new message, and after one is deleted (deleted_at set), a
--   private broadcast on 'thread:<thread id>', event 'chat', payload
--   {thread_id, message_id, author_id, op} with op 'insert' or 'delete'
--   (realtime.send adds its own id). Ids only, never the words: the app
--   reads the message again by id, under the thread's read rule.
-- - One broadcast per row: a chat statement writes one message.
-- - A broadcast problem never blocks the message (wrapped, and
--   realtime.send swallows its own errors too). Security definer, search
--   path '', and nobody may call the function.
-- - Receiving needs no change: daybook_live_receive (migration 29) admits
--   whoever may_use_thread_topic (can_use_thread: a Team's thread stays in
--   that Team). Sending stays closed to the app: since migration 42 no
--   policy lets anyone insert into realtime.messages.
--
-- Live order (from the PC, each with the founder's yes): 41, the push
-- function, 42, this migration, then one build. An older build still
-- listens for Postgres changes and gets what it got before.

create function public.handle_chat_broadcast()
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
      'chat', 'thread:' || new.thread_id::text, true);
  exception when others then
    -- A live-update problem never blocks sending or deleting a message.
    raise warning 'chat broadcast (message %): %', new.id, sqlerrm;
  end;
  return null;
end;
$$;

revoke execute on function public.handle_chat_broadcast() from public, anon, authenticated;

create trigger messages_broadcast after insert on public.messages
  for each row execute function public.handle_chat_broadcast();
create trigger messages_deleted_broadcast after update of deleted_at on public.messages
  for each row execute function public.handle_chat_broadcast();
