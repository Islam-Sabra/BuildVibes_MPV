-- Review 105C-B: a work item's table of tasks, and the removal sheet's
-- list.
--
-- 1. The table of tasks (Part 4, SP3): a block of its own,
--    {"id", "type": "task_table", "rows": [{"id", "text", "note", "ticked"}]},
--    on a work item only. The item keeps its one owner and Sign as done
--    stays once for the whole item; a tick is not a signature.
--    - validate_blocks (as in 20261021120000_report_notes.sql) takes it:
--      1 to 20 rows, each with its own id, a task of 1 to 200 characters
--      (as add_task_row), a note of up to 200, and a tick. A tick that changes, or a ticked row whose
--      words change or that goes, is the owner's or a Lead's
--      (may_tick_task), so the author's save can't tick or untick.
--    - tick_task_row: the owner or a Lead (not an admin on another pass)
--      ticks a row while the item is Open. add_task_row: they, or the
--      author, add one ("Add a row").
--      Each moves the page's version on, so an editor open elsewhere reads
--      the page again before it saves.
--    - space_task_tables: the tables of the Space's work items the caller
--      can see, for the cards.
--    A new kind of block, so an older app keeps it as it came.
-- 2. The removal sheet (Part 9, SP9): open_work_to_hand_over lists the open
--    work items a member owns, with each item's maker as the default new
--    owner when they may own it. For the Space's admin (Remove) and for the
--    member themself (Leave). The handover itself is migration 52's.

-- ---------------------------------------------------------------------------
-- 1. The table of tasks
-- ---------------------------------------------------------------------------

-- The caller may tick [p_post]'s rows now: its owner, or a Lead of its
-- Space who can see it (an admin on another pass can't); the item Open
-- and live.
create or replace function public.may_tick_task(p_post public.space_posts)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and p_post.id is not null
    and p_post.kind = 'work_item'
    and p_post.status = 'live' and p_post.deleted_at is null
    and not public.is_hidden_account(auth.uid())
    and exists (select 1 from public.space_members m
                join public.spaces s on s.id = m.space_id and s.deleted_at is null
                where m.space_id = p_post.space_id and m.profile_id = auth.uid()
                  and m.left_at is null)
    and exists (select 1 from public.work_items w
                where w.id = p_post.id and w.status = 'open'
                  and (w.owner_id = auth.uid()
                       or exists (select 1 from public.space_members l
                                  where l.space_id = p_post.space_id
                                    and l.profile_id = auth.uid() and l.left_at is null
                                    and l.pass = 'lead')))
    and public.can_see_space_post(p_post.id);
$$;

-- As in 20261021120000_report_notes.sql, with the table of tasks.
CREATE OR REPLACE FUNCTION public.validate_blocks(p_post space_posts, p_blocks jsonb)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_block jsonb;
  v_child jsonb;
  v_ids text[] := '{}';
  v_points text[] := '{}';
  v_count integer := 0;
  v_type text;
  v_keys text[];
  v_row jsonb;
  v_width integer;
  v_cell jsonb;
  v_point jsonb;
  v_ref uuid;
  v_old jsonb;
  v_row_ids text[];
  v_tick_change boolean := false;
  v_kind text := p_post.kind;
  v_template boolean := p_post.id is null;
begin
  if p_blocks is null or jsonb_typeof(p_blocks) <> 'array' then
    raise exception 'a page is a list of blocks' using errcode = '22023';
  end if;
  if octet_length(p_blocks::text) > 102400 then
    raise exception 'a page is at most 100 KB' using errcode = '22023';
  end if;
  if not v_template and v_kind = 'file' then
    raise exception 'a file post has no page' using errcode = '22023';
  end if;

  for v_block in
    select b from jsonb_array_elements(p_blocks) b
    union all
    select c from jsonb_array_elements(p_blocks) b,
                  jsonb_array_elements(case when jsonb_typeof(b -> 'children') = 'array'
                                            then b -> 'children' else '[]'::jsonb end) c
  loop
    v_count := v_count + 1;
    if v_count > 200 then
      raise exception 'at most 200 blocks' using errcode = '22023';
    end if;
    if jsonb_typeof(v_block) <> 'object' or jsonb_typeof(v_block -> 'id') is distinct from 'string'
       or (v_block ->> 'id') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'each block has its id' using errcode = '22023';
    end if;
    if (v_block ->> 'id') = any (v_ids) then
      raise exception 'a block id is used twice' using errcode = '22023';
    end if;
    v_ids := v_ids || (v_block ->> 'id');
    v_type := v_block ->> 'type';
    select array_agg(k) into v_keys from jsonb_object_keys(v_block) k;
    if not (v_keys <@ (case v_type
         when 'text' then array['id', 'type', 'text']
         when 'heading' then array['id', 'type', 'text', 'level', 'key']
         when 'toggle' then array['id', 'type', 'text', 'children']
         when 'table' then array['id', 'type', 'rows']
         when 'photo' then array['id', 'type', 'path', 'caption']
         when 'file' then array['id', 'type', 'library_file_id']
         when 'checklist_ref' then array['id', 'type', 'point_ids']
         when 'child_item' then array['id', 'type', 'post_id']
         when 'item_ref' then array['id', 'type', 'post_id']
         when 'task_table' then array['id', 'type', 'rows']
         else array[]::text[] end)) or v_type is null then
      raise exception 'not a kind of block' using errcode = '22023';
    end if;

    if v_type = 'text' then
      if not public.block_text_ok(v_block -> 'text', 0, 2000) then
        raise exception 'a text block holds up to 2000 characters' using errcode = '22023';
      end if;
    elsif v_type = 'heading' then
      if v_block ? 'key' then
        if not v_template or v_block ? 'text'
           or (v_block ->> 'key') not in ('on_site', 'done_today', 'problems') then
          raise exception 'a heading has its words' using errcode = '22023';
        end if;
      elsif not public.block_text_ok(v_block -> 'text', 1, 200) then
        raise exception 'a heading of 1 to 200 characters' using errcode = '22023';
      end if;
      if v_block ? 'level' and (v_block -> 'level') not in ('1'::jsonb, '2'::jsonb) then
        raise exception 'a heading is level 1 or 2' using errcode = '22023';
      end if;
    elsif v_type = 'toggle' then
      if not public.block_text_ok(v_block -> 'text', 1, 200) then
        raise exception 'a toggle of 1 to 200 characters' using errcode = '22023';
      end if;
      if jsonb_typeof(v_block -> 'children') is distinct from 'array' then
        raise exception 'a toggle holds a list of blocks' using errcode = '22023';
      end if;
      for v_child in select * from jsonb_array_elements(v_block -> 'children') loop
        if jsonb_typeof(v_child) <> 'object'
           or (v_child ->> 'type') not in ('text', 'heading', 'table', 'photo', 'file') then
          raise exception 'a toggle holds text, headings, tables, photos and files' using errcode = '22023';
        end if;
      end loop;
    elsif v_type = 'table' then
      if jsonb_typeof(v_block -> 'rows') is distinct from 'array'
         or jsonb_array_length(v_block -> 'rows') not between 1 and 20 then
        raise exception 'a table has 1 to 20 rows' using errcode = '22023';
      end if;
      v_width := null;
      for v_row in select * from jsonb_array_elements(v_block -> 'rows') loop
        if jsonb_typeof(v_row) <> 'array' or jsonb_array_length(v_row) not between 1 and 8
           or (v_width is not null and jsonb_array_length(v_row) <> v_width) then
          raise exception 'every row has 1 to 8 cells, all as wide' using errcode = '22023';
        end if;
        v_width := jsonb_array_length(v_row);
        for v_cell in select * from jsonb_array_elements(v_row) loop
          if not public.block_text_ok(v_cell, 0, 200) then
            raise exception 'a cell holds up to 200 characters of text' using errcode = '22023';
          end if;
        end loop;
      end loop;
    elsif v_type = 'task_table' then
      -- Review 105 Part 4: a table of tasks, only on a work item (never a
      -- template). Each row: its id, the task, a note and its tick.
      if v_template or v_kind <> 'work_item' then
        raise exception 'a table of tasks goes on a work item' using errcode = '22023';
      end if;
      if jsonb_typeof(v_block -> 'rows') is distinct from 'array'
         or jsonb_array_length(v_block -> 'rows') not between 1 and 20 then
        raise exception 'a table of tasks has 1 to 20 rows' using errcode = '22023';
      end if;
      v_row_ids := '{}';
      for v_row in select * from jsonb_array_elements(v_block -> 'rows') loop
        if jsonb_typeof(v_row) <> 'object'
           or not (select coalesce(array_agg(k), '{}') from jsonb_object_keys(v_row) k)
                  <@ array['id', 'text', 'note', 'ticked']
           or jsonb_typeof(v_row -> 'id') is distinct from 'string'
           or (v_row ->> 'id') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
           or (v_row ->> 'id') = any (v_row_ids)
           or jsonb_typeof(v_row -> 'ticked') is distinct from 'boolean'
           or not public.block_text_ok(v_row -> 'text', 1, 200)
           or (v_row ? 'note' and not public.block_text_ok(v_row -> 'note', 0, 200)) then
          raise exception 'each row has its id, a task of 1 to 200 characters, a note of up to 200, and its tick'
            using errcode = '22023';
        end if;
        v_row_ids := v_row_ids || (v_row ->> 'id');
        -- The row as it was saved: a tick that changes, or a ticked row
        -- whose words change, is the owner's or a Lead's (below).
        select r into v_old
        from jsonb_array_elements(case when jsonb_typeof(p_post.blocks) = 'array'
                                       then p_post.blocks else '[]'::jsonb end) b,
             jsonb_array_elements(case when b ->> 'type' = 'task_table'
                                            and jsonb_typeof(b -> 'rows') = 'array'
                                       then b -> 'rows' else '[]'::jsonb end) r
        where b ->> 'id' = v_block ->> 'id' and r ->> 'id' = v_row ->> 'id'
        limit 1;
        if (v_row -> 'ticked') is distinct from coalesce(v_old -> 'ticked', 'false'::jsonb)
           or (v_old -> 'ticked' = 'true'::jsonb
               and (v_row -> 'text' is distinct from v_old -> 'text'
                    or coalesce(v_row ->> 'note', '') <> coalesce(v_old ->> 'note', ''))) then
          v_tick_change := true;
        end if;
        v_old := null;
      end loop;
    elsif v_template then
      -- A template holds words only.
      raise exception 'a template holds words only' using errcode = '22023';
    elsif v_type = 'photo' then
      if v_block ? 'caption' and not public.block_text_ok(v_block -> 'caption', 0, 300) then
        raise exception 'a caption of up to 300 characters' using errcode = '22023';
      end if;
      if not exists (select 1 from public.post_files f
                     where f.post_id = p_post.id and f.storage_path = v_block ->> 'path'
                       and f.mime like 'image/%') then
        raise exception 'a photo block shows a photo of this post' using errcode = '22023';
      end if;
    elsif v_type = 'file' then
      if not exists (select 1 from public.post_files f
                     where f.post_id = p_post.id
                       and f.library_file_id::text = v_block ->> 'library_file_id') then
        raise exception 'a file block shows a file on this post' using errcode = '22023';
      end if;
    elsif v_type = 'checklist_ref' then
      if v_kind not in ('work_item', 'checklist')
         or jsonb_typeof(v_block -> 'point_ids') is distinct from 'array'
         or jsonb_array_length(v_block -> 'point_ids') = 0 then
        raise exception 'points go on a work item or a checklist' using errcode = '22023';
      end if;
      for v_point in select * from jsonb_array_elements(v_block -> 'point_ids') loop
        if jsonb_typeof(v_point) <> 'string' or (v_point #>> '{}') = any (v_points)
           or not exists (select 1 from public.checklist_points c
                          where c.post_id = p_post.id and c.id::text = v_point #>> '{}') then
          raise exception 'each point is one of this post''s, once' using errcode = '22023';
        end if;
        v_points := v_points || (v_point #>> '{}');
      end loop;
    elsif v_type = 'child_item' then
      if v_kind <> 'work_item' or p_post.parent_id is not null then
        raise exception 'a work item under this one' using errcode = '22023';
      end if;
      -- Already on the saved page: kept, so a page never stops saving
      -- because a work item it shows went (readers' views filter it).
      if not (v_block -> 'post_id') <@ coalesce((select jsonb_agg(r) from jsonb_path_query(p_post.blocks,
                'strict $.** ? (@.type == "child_item").post_id') r), '[]'::jsonb)
         and not exists (select 1 from public.space_posts c
                         where c.id::text = v_block ->> 'post_id' and c.parent_id = p_post.id
                           and c.kind = 'work_item' and c.deleted_at is null
                           and (c.team_id is null or c.team_id is not distinct from p_post.team_id)
                           and public.can_see_space_post(c.id)) then
        raise exception 'a work item under this one, for the same readers' using errcode = '22023';
      end if;
    elsif v_type = 'item_ref' then
      begin
        v_ref := (v_block ->> 'post_id')::uuid;
      exception when invalid_text_representation then
        v_ref := null;
      end;
      if v_kind <> 'report' or v_ref is null
         or (not (v_block -> 'post_id') <@ coalesce((select jsonb_agg(r) from jsonb_path_query(p_post.blocks,
                   'strict $.** ? (@.type == "item_ref").post_id') r), '[]'::jsonb)
             and not exists (
           select 1 from public.space_posts c
           where c.id = v_ref and c.space_id = p_post.space_id
             and (c.kind = 'work_item' or (c.kind = 'note' and c.status = 'live'))
             and c.deleted_at is null
             and (c.team_id is null or c.team_id is not distinct from p_post.team_id)
             and public.can_see_space_post(c.id))) then
        raise exception 'a work item or note this report''s readers can see' using errcode = '22023';
      end if;
    end if;
  end loop;

  -- A ticked row stays while the page is saved, unless the owner or a Lead
  -- saves it.
  if not v_template and exists (
       select 1
       from jsonb_array_elements(case when jsonb_typeof(p_post.blocks) = 'array'
                                      then p_post.blocks else '[]'::jsonb end) b,
            jsonb_array_elements(case when b ->> 'type' = 'task_table'
                                           and jsonb_typeof(b -> 'rows') = 'array'
                                      then b -> 'rows' else '[]'::jsonb end) r
       where r -> 'ticked' = 'true'::jsonb
         and not exists (
           select 1
           from jsonb_array_elements(p_blocks) nb,
                jsonb_array_elements(case when nb ->> 'type' = 'task_table'
                                               and jsonb_typeof(nb -> 'rows') = 'array'
                                          then nb -> 'rows' else '[]'::jsonb end) nr
           where nb ->> 'id' = b ->> 'id' and nr ->> 'id' = r ->> 'id')) then
    v_tick_change := true;
  end if;
  if v_tick_change and not public.may_tick_task(p_post) then
    raise exception 'only the owner or a Lead ticks a row' using errcode = '42501';
  end if;
end;
$function$;

-- [p_on] on [p_row] of the table [p_block]: the page's new version. The
-- same tick again changes nothing.
create or replace function public.tick_task_row(p_post uuid, p_block text, p_row text, p_on boolean)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post public.space_posts;
  v_block integer;
  v_row integer;
  v_was jsonb;
begin
  -- The post first, then the work item (as tick_point).
  select * into v_post from public.space_posts where id = p_post for update;
  if v_post.id is null or v_post.kind <> 'work_item' or not public.can_see_space_post(v_post.id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform 1 from public.work_items where id = p_post for update;
  if not public.post_is_editable(v_post) then
    raise exception 'this can no longer be ticked' using errcode = 'P0001';
  end if;
  if not public.may_tick_task(v_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select b.n - 1, r.m - 1, r.x -> 'ticked' into v_block, v_row, v_was
  from jsonb_array_elements(v_post.blocks) with ordinality b(x, n),
       jsonb_array_elements(case when b.x ->> 'type' = 'task_table'
                                 then b.x -> 'rows' else '[]'::jsonb end) with ordinality r(x, m)
  where b.x ->> 'id' = p_block and r.x ->> 'id' = p_row;
  if v_block is null then
    raise exception 'this row was removed' using errcode = 'P0001';
  end if;
  if v_was = to_jsonb(coalesce(p_on, true)) then
    return v_post.blocks_version;
  end if;
  update public.space_posts
  set blocks = jsonb_set(blocks, array[v_block::text, 'rows', v_row::text, 'ticked'],
                         to_jsonb(coalesce(p_on, true))),
      blocks_version = blocks_version + 1
  where id = p_post;
  if auth.uid() is distinct from v_post.author_id then
    insert into public.post_others (post_id) values (p_post) on conflict do nothing;
  end if;
  return v_post.blocks_version + 1;
end;
$$;

-- "Add a row": [p_text] and [p_note] as a new row [p_row] at the end of the
-- table [p_block], by the author, the owner or a Lead while the item is
-- Open. The page's new version; sent again with the same id, nothing more.
create or replace function public.add_task_row(p_post uuid, p_block text, p_row uuid, p_text text,
                                               p_note text default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post public.space_posts;
  v_block integer;
  v_rows jsonb;
  v_text text := trim(coalesce(p_text, ''));
  v_note text := trim(coalesce(p_note, ''));
begin
  select * into v_post from public.space_posts where id = p_post for update;
  if v_post.id is null or v_post.kind <> 'work_item' or not public.can_see_space_post(v_post.id)
     or p_row is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform 1 from public.work_items where id = p_post for update;
  if not public.post_is_editable(v_post) then
    raise exception 'this can no longer be edited' using errcode = 'P0001';
  end if;
  if not public.may_tick_task(v_post)
     and not (v_post.author_id = auth.uid() and not public.is_hidden_account(auth.uid())
              and public.is_member(v_post.space_id)
              and public.can(v_post.space_id, 'create_items')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select b.n - 1, b.x -> 'rows' into v_block, v_rows
  from jsonb_array_elements(v_post.blocks) with ordinality b(x, n)
  where b.x ->> 'id' = p_block and b.x ->> 'type' = 'task_table';
  if v_block is null then
    raise exception 'this table was removed' using errcode = 'P0001';
  end if;
  if exists (select 1 from jsonb_array_elements(v_rows) r where r ->> 'id' = p_row::text) then
    return v_post.blocks_version;
  end if;
  if length(v_text) not between 1 and 200 or length(v_note) > 200 then
    raise exception 'a task of 1 to 200 characters, a note of up to 200' using errcode = '22023';
  end if;
  if jsonb_array_length(v_rows) >= 20 then
    raise exception 'a table of tasks has at most 20 rows' using errcode = '54000';
  end if;
  update public.space_posts
  set blocks = jsonb_set(blocks, array[v_block::text, 'rows'],
                         v_rows || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
                           'id', p_row, 'text', v_text, 'note', nullif(v_note, ''),
                           'ticked', false)))),
      blocks_version = blocks_version + 1
  where id = p_post;
  if auth.uid() is distinct from v_post.author_id then
    insert into public.post_others (post_id) values (p_post) on conflict do nothing;
  end if;
  return v_post.blocks_version + 1;
end;
$$;

-- The tables of tasks on the work items of [p_space] the caller can see,
-- each post's in its page's order, for the cards. Archived ones aren't
-- in Work.
create or replace function public.space_task_tables(p_space uuid)
returns table (post_id uuid, blocks jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, jsonb_agg(b.x order by b.n)
  from public.space_posts p
  cross join lateral jsonb_array_elements(p.blocks) with ordinality b(x, n)
  where p.space_id = p_space and p.kind = 'work_item'
    and p.status = 'live' and p.deleted_at is null and p.archived_at is null
    and p.blocks @> '[{"type": "task_table"}]'::jsonb
    and b.x ->> 'type' = 'task_table'
    and public.is_member(p_space)
    and public.can_see_space_post(p.id)
  group by p.id;
$$;

-- ---------------------------------------------------------------------------
-- 2. The removal sheet's list
-- ---------------------------------------------------------------------------

-- The open work items [p_member] owns in [p_space], as hand_over_open_work
-- counts them, oldest first: id, ref, title, team, and the maker
-- (maker_id, maker_name) with maker_may_own when the maker may take it.
-- For the Space's admin, or the member themself.
create or replace function public.open_work_to_hand_over(p_space uuid, p_member uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.is_space_admin(p_space)
          or (p_member = auth.uid() and public.is_member(p_space))) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
             'id', w.id, 'ref', w.ref, 'title', p.title, 'team_id', p.team_id,
             'maker_id', w.created_by,
             'maker_name', public.space_person_name(w.created_by),
             'maker_may_own', w.created_by is not null and w.created_by <> p_member
                              and public.may_be_post_person(p_space, p.team_id, 'work_item',
                                                            w.created_by)
                              and public.member_can(p_space, w.created_by, 'mark_done')))
             order by p.created_at, w.id)
    from public.work_items w
    join public.space_posts p on p.id = w.id
    where w.space_id = p_space and w.owner_id = p_member and w.status = 'open'
      and p.status = 'live' and p.deleted_at is null), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.may_tick_task(public.space_posts),
  public.validate_blocks(public.space_posts, jsonb),
  public.tick_task_row(uuid, text, text, boolean),
  public.add_task_row(uuid, text, uuid, text, text),
  public.space_task_tables(uuid),
  public.open_work_to_hand_over(uuid, uuid)
  from public, anon;
-- Internal: answers for the caller about any post, or checks without its
-- own lock.
revoke execute on function
  public.may_tick_task(public.space_posts),
  public.validate_blocks(public.space_posts, jsonb)
  from authenticated;
grant execute on function
  public.tick_task_row(uuid, text, text, boolean),
  public.add_task_row(uuid, text, uuid, text, text),
  public.space_task_tables(uuid),
  public.open_work_to_hand_over(uuid, uuid)
  to authenticated;
