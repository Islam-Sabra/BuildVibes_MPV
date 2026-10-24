-- Migration 42: a Space's daybook kept live by the database (review 50,
-- F47 reopened). Not live.
--
-- On build 565 the founder's phone, with NBKCH SITE TEAM open, never saw
-- Omar's tick or his Got it live. Until now the acting phone sent the
-- broadcast itself (DaybookLive.changed, from 6 places), sometimes on a
-- second channel opened just to send: the pattern that failed for direct
-- messages (F100, migration 40). So, as there, the database sends it.
--
-- - After a statement that changes what a card shows, one private
--   broadcast per post it touched, on 'daybook:<space id>', event
--   'changed', payload {space_id, post_id} (realtime.send adds its own id).
--   Ids only, never any text: every open daybook reads the page again
--   through daybook_cards, under the post's own rules.
-- - Statement-level triggers with transition tables, so a statement that
--   writes many rows (a walk's items, several points) sends one broadcast
--   per post, not one per row. And at most one per post per transaction
--   (daybook_send keeps the posts it sent in a transaction-local setting):
--   one action that writes a post, its files one by one and their history
--   still sends once. Nothing is lost: Realtime delivers a broadcast only
--   after the transaction commits, and everyone then reads the page.
--   - space_posts: insert, and update (state, due, pin, cancel, edit,
--     delete, a child moving its parent: any change to the row);
--   - work_items: update (state, owner, due, check);
--   - post_point_events: insert (a tick, an untick, a point's change);
--   - post_acks: insert and delete (Got it, Received, On my way);
--   - work_item_events: insert (a work item's history: done, checked,
--     sent back, a comment, a new owner or date);
--   - post_edits: insert (the history line of an edit);
--   - post_files: insert and delete (photos and files on a card).
-- - A broadcast problem never blocks the action: each send is wrapped in
--   "exception when others then raise warning" (realtime.send swallows
--   its own errors too).
-- - The trigger functions are security definer with search_path '' and
--   nobody may call them.
-- - Receiving is unchanged: daybook_live_receive (migration 29) lets a
--   member of the Space receive on its topic. Sending from the app is
--   closed: daybook_live_send is dropped, so no policy lets anyone insert
--   into realtime.messages. Nothing else needs app sends: chat 'thread:'
--   channels are receive only (migration 29), and 'dm:' is sent by
--   migration 40's trigger.
--
-- Live order (from the PC, each with the founder's yes): migration 41,
-- then the push function, then this migration, then one build. An older
-- build on this migration still receives; its own sends are refused (it
-- logs them and carries on), so the others still see its changes, now
-- from the database.

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------

-- One broadcast about [p_post] on its Space's topic, once per transaction.
-- Never fails.
create function public.daybook_send(p_space uuid, p_post uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sent text;
begin
  if p_space is null or p_post is null then
    return;
  end if;
  begin
    v_sent := coalesce(current_setting('bv.daybook_sent', true), '');
    if position(p_post::text in v_sent) > 0 then
      return;
    end if;
    perform realtime.send(
      jsonb_build_object('space_id', p_space, 'post_id', p_post),
      'changed', 'daybook:' || p_space::text, true);
    perform set_config('bv.daybook_sent', v_sent || ' ' || p_post::text, true);
  exception when others then
    raise warning 'daybook broadcast (post %): %', p_post, sqlerrm;
  end;
end;
$$;

-- space_posts: a new post, or any change to one.
create function public.handle_space_post_broadcast()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    if tg_op = 'INSERT' then
      perform public.daybook_send(x.space_id, x.id)
      from (select distinct n.space_id, n.id from new_rows n) x;
    else
      perform public.daybook_send(x.space_id, x.id)
      from (select distinct n.space_id, n.id
            from new_rows n join old_rows o on o.id = n.id
            where row(n.*) is distinct from row(o.*)) x;
    end if;
  exception when others then
    raise warning 'daybook broadcast (space_posts): %', sqlerrm;
  end;
  return null;
end;
$$;

-- work_items: a work item's state, owner, due date or check.
create function public.handle_work_item_broadcast()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    perform public.daybook_send(x.space_id, x.id)
    from (select distinct n.space_id, n.id
          from new_rows n join old_rows o on o.id = n.id
          where row(n.*) is distinct from row(o.*)) x;
  exception when others then
    raise warning 'daybook broadcast (work_items): %', sqlerrm;
  end;
  return null;
end;
$$;

-- work_item_events: a line in a work item's history (a comment too).
create function public.handle_work_item_event_broadcast()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    perform public.daybook_send(x.space_id, x.work_item_id)
    from (select distinct w.space_id, n.work_item_id
          from new_rows n join public.work_items w on w.id = n.work_item_id) x;
  exception when others then
    raise warning 'daybook broadcast (work_item_events): %', sqlerrm;
  end;
  return null;
end;
$$;

-- Rows of a post (ticks, acknowledgements, edits' history, files): the
-- post they belong to, once per statement. Inserted rows, or deleted ones.
create function public.handle_post_row_broadcast()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    if tg_op = 'DELETE' then
      perform public.daybook_send(x.space_id, x.id)
      from (select distinct p.space_id, p.id
            from old_rows o join public.space_posts p on p.id = o.post_id) x;
    else
      perform public.daybook_send(x.space_id, x.id)
      from (select distinct p.space_id, p.id
            from new_rows n join public.space_posts p on p.id = n.post_id) x;
    end if;
  exception when others then
    raise warning 'daybook broadcast (%): %', tg_table_name, sqlerrm;
  end;
  return null;
end;
$$;

create trigger space_posts_broadcast_insert after insert on public.space_posts
  referencing new table as new_rows
  for each statement execute function public.handle_space_post_broadcast();
create trigger space_posts_broadcast_update after update on public.space_posts
  referencing old table as old_rows new table as new_rows
  for each statement execute function public.handle_space_post_broadcast();
create trigger work_items_broadcast_update after update on public.work_items
  referencing old table as old_rows new table as new_rows
  for each statement execute function public.handle_work_item_broadcast();
create trigger work_item_events_broadcast after insert on public.work_item_events
  referencing new table as new_rows
  for each statement execute function public.handle_work_item_event_broadcast();
create trigger post_point_events_broadcast after insert on public.post_point_events
  referencing new table as new_rows
  for each statement execute function public.handle_post_row_broadcast();
create trigger post_acks_broadcast_insert after insert on public.post_acks
  referencing new table as new_rows
  for each statement execute function public.handle_post_row_broadcast();
create trigger post_acks_broadcast_delete after delete on public.post_acks
  referencing old table as old_rows
  for each statement execute function public.handle_post_row_broadcast();
create trigger post_edits_broadcast after insert on public.post_edits
  referencing new table as new_rows
  for each statement execute function public.handle_post_row_broadcast();
create trigger post_files_broadcast_insert after insert on public.post_files
  referencing new table as new_rows
  for each statement execute function public.handle_post_row_broadcast();
create trigger post_files_broadcast_delete after delete on public.post_files
  referencing old table as old_rows
  for each statement execute function public.handle_post_row_broadcast();

-- ---------------------------------------------------------------------------
-- The app no longer sends on a daybook topic
-- ---------------------------------------------------------------------------

-- Migration 29's insert policy: with it gone, no policy lets the app write
-- realtime.messages, so only the database sends.
drop policy daybook_live_send on realtime.messages;

revoke execute on function
  public.daybook_send(uuid, uuid),
  public.handle_space_post_broadcast(),
  public.handle_work_item_broadcast(),
  public.handle_work_item_event_broadcast(),
  public.handle_post_row_broadcast()
  from public, anon, authenticated;
