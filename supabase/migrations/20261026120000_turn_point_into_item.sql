-- Migration 36: Turn into, in one step (review 76, slice 5). Branch
-- claude/slice5. Not live. After migration 35 (the 3D notes); it changes
-- nothing they touch.
--
-- On a work item's page, its author turns a checklist point into a work
-- item under this one. Three calls would do it (create_work_item with
-- p_parent, save_blocks, edit_space_post removing the point), but a lost
-- signal halfway leaves both the point and its new work item on the page.
-- turn_point_into_item does it in one transaction:
-- - the author (acts_for_author), while they may post and the item is
--   editable (Open); a top-level work item only;
-- - the point is this post's and not ticked (a ticked point is a record);
-- - the new work item takes the point's words as its title (2 to 140
--   characters), the post's Team and [p_owner] (create_work_item's rules:
--   someone who can sign it as done), and its owner is told as for any work
--   item;
-- - on the page (saved before the point goes, as edit_space_post wants),
--   the point leaves its checklist block (the block goes when
--   it was its last point) and a child_item block takes its place; a page
--   with no blocks yet keeps none, as the page shows a post's points and
--   work items under it without blocks;
-- - idempotent by [p_item_id]: a retry after a lost answer returns the
--   page's version and changes nothing;
-- - a stale [p_base_version] is refused with 40001 (the app reloads).
-- Returns the page's new blocks_version.

create function public.turn_point_into_item(p_post uuid, p_point uuid, p_item_id uuid,
                                            p_owner uuid, p_base_version integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_point public.checklist_points;
  v_title text;
  v_blocks jsonb;
  v_out jsonb := '[]'::jsonb;
  v_block jsonb;
  v_ids jsonb;
  v_placed boolean := false;
  v_child jsonb;
  v_version integer;
begin
  if p_post is null or p_point is null or p_item_id is null then
    raise exception 'nothing to turn' using errcode = '22023';
  end if;
  -- The post first, then its work item (as edit, delete and cancel).
  select * into v_post from public.space_posts where id = p_post for update;
  if v_post.id is null or v_post.author_id is distinct from v_me
     or not public.acts_for_author(v_post)
     or not public.can(v_post.space_id, 'create_items') then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  -- Already turned (a retry): the same answer, nothing changed.
  if exists (select 1 from public.space_posts c
             where c.id = p_item_id and c.parent_id = p_post and c.author_id = v_me) then
    return v_post.blocks_version;
  end if;

  if v_post.kind <> 'work_item' or v_post.parent_id is not null then
    raise exception 'a point turns into a work item under a top-level work item'
      using errcode = '22023';
  end if;
  perform 1 from public.work_items where id = p_post for update;
  if not public.post_is_editable(v_post) then
    raise exception 'this can no longer be edited' using errcode = 'P0001';
  end if;
  if p_base_version is distinct from v_post.blocks_version then
    raise exception 'this page changed; reload it' using errcode = '40001';
  end if;

  select * into v_point from public.checklist_points
  where id = p_point and post_id = p_post for update;
  if v_point.id is null then
    raise exception 'not a point of this post' using errcode = '22023';
  end if;
  if v_point.ticked_at is not null then
    raise exception 'a ticked point stays as it is' using errcode = 'P0001';
  end if;
  v_title := trim(v_point.text);
  if length(v_title) not between 2 and 140 then
    raise exception 'a work item''s title is 2 to 140 characters' using errcode = '22023';
  end if;

  -- The work item under this one (its owner is told by create_work_item).
  perform public.create_work_item(
    p_space => v_post.space_id, p_title => v_title, p_owner => p_owner,
    p_team => v_post.team_id, p_id => p_item_id, p_parent => p_post);

  -- The page: the point's block gives way to the new work item.
  v_blocks := v_post.blocks;
  if jsonb_array_length(v_blocks) > 0 then
    v_child := jsonb_build_object('id', gen_random_uuid()::text, 'type', 'child_item',
                                  'post_id', p_item_id::text);
    for v_block in select b from jsonb_array_elements(v_blocks) b loop
      if v_block ->> 'type' = 'checklist_ref'
         and (v_block -> 'point_ids') @> jsonb_build_array(p_point::text) then
        select coalesce(jsonb_agg(i), '[]'::jsonb) into v_ids
        from jsonb_array_elements(v_block -> 'point_ids') i
        where i #>> '{}' <> p_point::text;
        if jsonb_array_length(v_ids) > 0 then
          v_out := v_out || jsonb_build_array(jsonb_set(v_block, '{point_ids}', v_ids));
        end if;
        v_out := v_out || jsonb_build_array(v_child);
        v_placed := true;
      else
        v_out := v_out || jsonb_build_array(v_block);
      end if;
    end loop;
    if not v_placed then
      v_out := v_out || jsonb_build_array(v_child);
    end if;
  end if;

  -- The page first: edit_space_post refuses to remove a point the page
  -- still shows. Then the point goes (recorded as an edit).
  if jsonb_array_length(v_blocks) > 0 then
    v_version := public.save_blocks(p_post, v_out, v_post.blocks_version);
  else
    v_version := v_post.blocks_version;
  end if;
  perform public.edit_space_post(p_post, jsonb_build_object(
    'points', jsonb_build_object('remove', jsonb_build_array(p_point::text))));
  return v_version;
end;
$$;

revoke execute on function public.turn_point_into_item(uuid, uuid, uuid, uuid, integer)
  from public, anon;
grant execute on function public.turn_point_into_item(uuid, uuid, uuid, uuid, integer)
  to authenticated;
