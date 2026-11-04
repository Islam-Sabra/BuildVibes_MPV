-- Migration 67 (review 116b, V1; the founder's test on build 1042): a
-- poll's vote, edit, close (the five-minute job's too) and a tie's pick
-- tell the Space's open daybooks, so a vote shows on other phones at once.
-- They change only polls, poll_options or poll_votes, which have no
-- broadcast trigger; each now ends with daybook_send (migration
-- 20261103120000), which sends once per transaction and never fails.

create function pg_temp.r116b_patch(p_fn regprocedure, p_old text, p_new text)
returns void language plpgsql as $$
declare
  -- Live has CRLF in some function bodies.
  v_def text := replace(pg_get_functiondef(p_fn), chr(13), '');
begin
  if position(p_old in v_def) = 0
     or position(p_old in substr(v_def, position(p_old in v_def) + 1)) > 0 then
    raise exception 'review 116b: % is not as expected', p_fn;
  end if;
  execute replace(v_def, p_old, p_new);
end;
$$;

select pg_temp.r116b_patch(
  'public.vote_poll(uuid, uuid[])',
  $old$  select o, v_me from unnest(v_options) o
  on conflict do nothing;$old$,
  $new$  select o, v_me from unnest(v_options) o
  on conflict do nothing;
  -- Review 116b: the Space's open daybooks read the card again.
  perform public.daybook_send(v_post.space_id, p_post);$new$);

select pg_temp.r116b_patch(
  'public.edit_poll(uuid, text, jsonb, boolean, timestamptz)',
  $old$  on conflict (id) do update set label = excluded.label, sort = excluded.sort;$old$,
  $new$  on conflict (id) do update set label = excluded.label, sort = excluded.sort;
  -- Review 116b: also when only the options changed.
  perform public.daybook_send(v_post.space_id, p_post);$new$);

-- poll_close serves close_poll and close_due_polls alike.
select pg_temp.r116b_patch(
  'public.poll_close(uuid, uuid)',
  $old$  return true;$old$,
  $new$  -- Review 116b: closed, by a person or by its time.
  perform public.daybook_send(v_post.space_id, p_post);
  return true;$new$);

select pg_temp.r116b_patch(
  'public.decide_poll(uuid, uuid)',
  $old$  where post_id = p_post and decided_option is null;$old$,
  $new$  where post_id = p_post and decided_option is null;
  -- Review 116b: the winner shows at once.
  perform public.daybook_send(v_post.space_id, p_post);$new$);
