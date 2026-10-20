-- Migration 30: notes in the daily report (review 63, "how a Note goes into
-- the daily report", F58). Branch claude/test-tw7wuv. Not live; needs
-- migration 29 first.
--
-- - daily_report_notes(space, team, from, to): the day's live notes for the
--   report's "On site" suggestions, with the same rules as daily_report_fill:
--   only notes everyone who reads the report may see (an Everyone report
--   never brings in a Team's note; naming a Team shows nothing to someone
--   outside it), a member only, one day at a time. Title, author (no name
--   across a block, as everywhere in a Space), time and the first photo.
-- - An item_ref block on a report may point at a note as well as a work
--   item, with the same "this report's readers can see it" rule. A new
--   one only at a live note (review 65); one already on the page stays
--   when the note is cancelled later.
-- - refs in the post JSON carry each ref's kind and status; a note's ref
--   has its author's name, time and first photo instead of the work item's
--   fields. A work item's ref is as before, plus kind and status.

-- The first photo of a post: the same pick as a walk's cover (migration 20).
-- Invoker: only definer functions call it (review 65).
create function public.post_cover_path(p_post uuid)
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select f.storage_path from public.post_files f
  where f.post_id = p_post and f.storage_path is not null and f.mime like 'image/%'
  order by f.sort, f.created_at
  limit 1;
$$;

create function public.daily_report_notes(p_space uuid, p_team uuid, p_from timestamptz,
                                          p_to timestamptz)
returns table (post_id uuid, title text, author_name text, created_at timestamptz,
               photo_path text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_member(p_space) then
    return;
  end if;
  if p_from is null or p_to is null or p_to <= p_from or p_to - p_from > interval '1 day 1 hour' then
    raise exception 'choose a day' using errcode = '22023';
  end if;
  return query
  select p.id, p.title, public.space_person_name(p.author_id), p.created_at,
         public.post_cover_path(p.id)
  from public.space_posts p
  where p.space_id = p_space and p.kind = 'note' and p.status = 'live' and p.deleted_at is null
    and p.created_at >= p_from and p.created_at < p_to
    and (p.team_id is null or p.team_id is not distinct from p_team)
    and public.can_see_space_post(p.id)
  order by p.created_at, p.id
  limit 100;
end;
$$;

-- As migration 20, with a note allowed in an item_ref.
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
end;
$function$;

-- As migration 29, with notes in refs.
CREATE OR REPLACE FUNCTION public.space_post_json(p_post space_posts, p_full boolean)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', p_post.id,
    'space_id', p_post.space_id,
    'kind', p_post.kind,
    'status', p_post.status,
    'team_id', p_post.team_id,
    'author_id', p_post.author_id,
    'author_name', public.space_person_name(p_post.author_id),
    'title', p_post.title,
    'body', p_post.body,
    'place', p_post.place_text,
    'due_date', p_post.due_date,
    'due_at', p_post.due_at,
    'parent_id', p_post.parent_id,
    'source_message_id', p_post.source_message_id,
    'quote', p_post.quote,
    'created_at', p_post.created_at,
    'edited_at', p_post.edited_at,
    'cancelled_at', p_post.cancelled_at,
    'cancelled_by_name', public.space_person_name(p_post.cancelled_by),
    'cancel_note', p_post.cancel_note,
    'pinned_until', case when p_post.pinned_until > now() then p_post.pinned_until end,
    'starts_at', p_post.starts_at,
    'ends_at', p_post.ends_at,
    'item', (
      select jsonb_build_object(
        'ref', w.ref, 'status', w.status,
        'owner_id', w.owner_id, 'owner_name', public.space_person_name(w.owner_id),
        'done_at', w.done_at, 'checked_at', w.checked_at,
        'checked_by_name', public.space_person_name(w.checked_by))
      from public.work_items w where w.id = p_post.id),
    'people', (
      select jsonb_agg(jsonb_build_object('id', pp.profile_id,
                                          'name', public.space_person_name(pp.profile_id))
                       order by pp.created_at, pp.profile_id)
      from public.post_people pp where pp.post_id = p_post.id),
    'points', (
      select jsonb_build_object('total', count(*),
                                'ticked', count(*) filter (where c.ticked_at is not null))
      from public.checklist_points c where c.post_id = p_post.id
      having count(*) > 0),
    'my_acks', (
      select jsonb_agg(a.kind order by a.kind)
      from public.post_acks a where a.post_id = p_post.id and a.profile_id = auth.uid()),
    -- When the caller gave each of them, {"got_it": "<time>"} or {}
    -- (migration 29): only the caller's own.
    'my_ack_at', coalesce((
      select jsonb_object_agg(a.kind, a.created_at order by a.kind)
      from public.post_acks a where a.post_id = p_post.id and a.profile_id = auth.uid()),
      '{}'::jsonb),
    'file', (
      select jsonb_build_object(
        'id', lf.id, 'name', lf.name, 'mime', lf.mime, 'bytes', lf.bytes,
        'rev_label', lf.rev_label, 'note', lf.note, 'path', lf.storage_path,
        'replaces', (select jsonb_build_object('name', o.name, 'rev_label', o.rev_label,
                                               'bytes', o.bytes)
                     from public.library_files o where o.id = lf.supersedes_id),
        'has_newer', exists (select 1 from public.library_files n
                             where n.supersedes_id = lf.id and n.deleted_at is null
                               and public.can_read_library_file(n.id)))
      from public.library_files lf
      where lf.id = p_post.library_file_id and public.can_read_library_file(lf.id)),
    -- The latest stamp on the slip.
    'stamp', (
      select case
        when p_post.status = 'cancelled' then jsonb_build_object(
          'kind', 'cancelled', 'at', p_post.cancelled_at,
          'by_name', public.space_person_name(p_post.cancelled_by))
        when w.status = 'checked' then jsonb_build_object(
          'kind', 'checked', 'at', w.checked_at, 'by_name', public.space_person_name(w.checked_by))
        when w.status = 'done' then jsonb_build_object(
          'kind', 'done', 'at', w.done_at, 'by_name', public.space_person_name(w.owner_id))
        when last.kind = 'sent_back' then jsonb_build_object(
          'kind', 'sent_back', 'at', last.created_at, 'reason', last.reason,
          'by_name', public.space_person_name(last.actor_id))
        when lf.supersedes_id is not null then jsonb_build_object(
          'kind', 'new_version', 'at', p_post.created_at)
      end
      -- Any kind can be cancelled; work items and new file versions have
      -- their own stamps.
      from (select 1) one
      left join public.work_items w on w.id = p_post.id
      left join public.library_files lf on lf.id = p_post.library_file_id
      left join lateral (
        select e.kind, e.created_at, e.reason, e.actor_id
        from public.work_item_events e
        where e.work_item_id = w.id and e.kind in ('done', 'checked', 'sent_back')
        order by e.created_at desc, e.id desc limit 1) last on true),
    -- The paper clip: this needs the caller.
    'needs_me', coalesce((
      select public.item_needs_me(w, p_post) is not null
      from public.work_items w where w.id = p_post.id), public.checklist_needs_me(p_post)),
    -- A work item's first three Library files, for the slip's chips, and
    -- whether there are more (review 45 M3). The full page lists them all.
    'attachments', (
      select jsonb_agg(jsonb_build_object('library_file_id', a.id, 'name', a.name,
                                          'rev_label', a.rev_label) order by a.created_at, a.id)
      from (select lf.id, lf.name, lf.rev_label, wa.created_at
            from public.work_item_attachments wa
            join public.library_files lf on lf.id = wa.library_file_id
            where wa.work_item_id = p_post.id and public.can_read_library_file(lf.id)
            order by wa.created_at, lf.id limit 3) a),
    'attachments_more', (
      select true
      from public.work_item_attachments wa
      where wa.work_item_id = p_post.id and public.can_read_library_file(wa.library_file_id)
      having count(*) > 3),
    -- The last time it was given to someone else.
    'given_to', (
      select jsonb_build_object('from_id', e.from_owner_id,
                                'from_name', public.space_person_name(e.from_owner_id),
                                'to_id', e.to_owner_id,
                                'to_name', public.space_person_name(e.to_owner_id),
                                'at', e.created_at)
      from public.work_item_events e
      where e.work_item_id = p_post.id and e.kind = 'reassigned'
      order by e.created_at desc, e.id desc limit 1),
    'has_page', jsonb_array_length(p_post.blocks) > 0,
    'template_id', p_post.template_id,
    'cover_path', (
      select f.storage_path from public.post_files f
      where f.post_id = p_post.id and f.storage_path is not null and f.mime like 'image/%'
      order by f.sort, f.created_at limit 1),
    'children', (
      select jsonb_build_object(
        'total', count(*),
        'checked', count(*) filter (where w.status = 'checked'),
        -- The first 10, for a walk's slip (R1b).
        'rows', (select jsonb_agg(r.row order by r.created_at, r.id) from (
                   select c2.id, c2.created_at, jsonb_strip_nulls(jsonb_build_object(
                            'id', c2.id, 'title', c2.title, 'item_status', w2.status,
                            'owner_id', w2.owner_id,
                            'owner_name', public.space_person_name(w2.owner_id),
                            'cover_path', (select f.storage_path from public.post_files f
                                           where f.post_id = c2.id and f.storage_path is not null
                                             and f.mime like 'image/%'
                                           order by f.sort, f.created_at limit 1))) as row
                   from public.space_posts c2
                   join public.work_items w2 on w2.id = c2.id
                   where c2.parent_id = p_post.id and c2.deleted_at is null and c2.status = 'live'
                     and public.can_see_space_post(c2.id)
                   order by c2.created_at, c2.id
                   limit 10) r))
      from public.space_posts c
      join public.work_items w on w.id = c.id
      where c.parent_id = p_post.id and c.deleted_at is null and c.status = 'live'
        and public.can_see_space_post(c.id)
      having count(*) > 0),
    'edits', (
      select jsonb_agg(jsonb_build_object(
               'at', e.created_at, 'by_name', public.space_person_name(e.editor_id),
               'changes', e.changes) order by e.created_at desc)
      from (select * from public.post_edits pe where pe.post_id = p_post.id
            order by pe.created_at desc limit case when p_full then 1000 else 3 end) e)
  )) || case when not p_full then '{}'::jsonb else jsonb_strip_nulls(jsonb_build_object(
    'point_list', (
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'text', c.text, 'ticked_at', c.ticked_at,
               'ticked_by_name', public.space_person_name(c.ticked_by),
               'ticked_by_me', c.ticked_by is not distinct from auth.uid() and c.ticked_at is not null)
             order by c.sort, c.id)
      from public.checklist_points c where c.post_id = p_post.id),
    'files', (
      select jsonb_agg(jsonb_build_object(
               'id', f.id, 'path', f.storage_path, 'library_file_id', f.library_file_id,
               'name', lf.name, 'mime', f.mime, 'bytes', f.bytes,
               'width', f.width, 'height', f.height) order by f.sort, f.created_at)
      from public.post_files f
      left join public.library_files lf on lf.id = f.library_file_id
      where f.post_id = p_post.id
        and (f.library_file_id is null or public.can_read_library_file(f.library_file_id))),
    'events', (
      select jsonb_agg(jsonb_build_object(
               'id', e.id, 'kind', e.kind, 'actor_id', e.actor_id,
               'actor_name', public.space_person_name(e.actor_id),
               'note', e.note, 'reason', e.reason,
               'from_owner_name', public.space_person_name(e.from_owner_id),
               'to_owner_name', public.space_person_name(e.to_owner_id),
               'at', e.created_at,
               'photos', (select jsonb_agg(jsonb_build_object(
                                   'path', ev.storage_path, 'taken_at', ev.taken_at,
                                   'place', ev.place_text) order by ev.created_at)
                          from public.work_item_evidence ev where ev.event_id = e.id))
             order by e.created_at, e.id)
      from public.work_item_events e where e.work_item_id = p_post.id),
    'attachments', (
      select jsonb_agg(jsonb_build_object('library_file_id', lf.id, 'name', lf.name,
                                          'rev_label', lf.rev_label,
                                          'mime', lf.mime, 'bytes', lf.bytes)
                       order by a.created_at, lf.id)
      from public.work_item_attachments a
      join public.library_files lf on lf.id = a.library_file_id
      where a.work_item_id = p_post.id and public.can_read_library_file(lf.id)),
    'blocks', p_post.blocks,
    'blocks_version', p_post.blocks_version,
    -- A report's work items and notes, as this reader may see them
    -- (migration 20; notes and kind in migration 30).
    'refs', (
      select jsonb_object_agg(c.id, jsonb_strip_nulls(jsonb_build_object(
               'kind', c.kind, 'status', c.status,
               'author_name', case when c.kind = 'note' then public.space_person_name(c.author_id) end,
               'created_at', case when c.kind = 'note' then c.created_at end,
               'photo_path', case when c.kind = 'note' then public.post_cover_path(c.id) end,
               'title', c.title, 'ref', w.ref, 'item_status', w.status,
               'owner_name', public.space_person_name(w.owner_id),
               'checked_at', w.checked_at,
               'checker_name', public.space_person_name(w.checked_by),
               'done_photo_path', public.done_photo_path(w.id))))
      from public.space_posts c
      left join public.work_items w on w.id = c.id
      where c.id::text in (select r #>> '{}' from jsonb_path_query(p_post.blocks,
                             'strict $.** ? (@.type == "item_ref").post_id') r)
        and c.space_id = p_post.space_id and c.deleted_at is null
        and c.kind in ('work_item', 'note')
        and public.can_see_space_post(c.id)),
    'under', (
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'title', c.title, 'status', c.status, 'ref', w.ref,
               'item_status', w.status, 'owner_id', w.owner_id,
               'owner_name', public.space_person_name(w.owner_id),
               'cover_path', (select f.storage_path from public.post_files f
                              where f.post_id = c.id and f.storage_path is not null
                                and f.mime like 'image/%'
                              order by f.sort, f.created_at limit 1))
             order by c.created_at, c.id)
      from public.space_posts c
      join public.work_items w on w.id = c.id
      where c.parent_id = p_post.id and c.deleted_at is null
        and public.can_see_space_post(c.id)),
    'parent', (
      select jsonb_build_object('id', pp.id, 'title', pp.title)
      from public.space_posts pp
      where pp.id = p_post.parent_id and public.can_see_space_post(pp.id))
  )) end;
$function$;

revoke execute on function
  public.post_cover_path(uuid),
  public.daily_report_notes(uuid, uuid, timestamptz, timestamptz)
  from public, anon;
-- Internal: answers about any post.
revoke execute on function public.post_cover_path(uuid) from authenticated;
grant execute on function public.daily_report_notes(uuid, uuid, timestamptz, timestamptz)
  to authenticated;
