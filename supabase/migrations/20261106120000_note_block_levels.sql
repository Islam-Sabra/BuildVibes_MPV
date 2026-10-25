-- Migration 45 (review 93): a note's lines under each other.
--
-- - Each line of a note's page may carry `indent`, its level: a whole
--   number from 0 to 3, none for 0 (old notes have none). Not `level`: a
--   heading's `level` is its size. The first line is at 0, and no line is
--   more than one deeper than the line before it. A toggle's own lines
--   stay inside it, at 0.
-- - A numbered line may carry `start`, where its count begins: a whole
--   number from 1 to 999 ("Continue numbering" or "Restart at 1"). Numbers
--   themselves are never kept.
-- - A text, to-do, bulleted or numbered line may carry `folded`, true or
--   false: whether the lines under it are folded shut, so the note opens
--   again as it was left. Folded is true only on a line with children.
-- - Only is_valid_note_blocks changes; the notes.blocks check and
--   save_note already call it. Every saved note stays valid.

create or replace function public.is_valid_note_blocks(p_blocks jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_block jsonb;
  v_child jsonb;
  v_ids text[] := '{}';
  v_count integer := 0;
  v_type text;
  v_keys text[];
  v_row jsonb;
  v_width integer;
  v_cell jsonb;
  v_level integer;
  v_before integer := -1;
  v_shut boolean := false;
  v_text text[] := array['text', 'heading', 'todo', 'bullet', 'numbered', 'toggle',
                         'callout', 'quote'];
begin
  if p_blocks is null or jsonb_typeof(p_blocks) <> 'array' then
    return false;
  end if;
  if octet_length(p_blocks::text) > 524288 then
    return false;
  end if;
  -- The page's own lines, in order: each at most one level deeper than
  -- the line before it.
  for v_block in select b from jsonb_array_elements(p_blocks) b loop
    if jsonb_typeof(v_block) <> 'object' then
      return false;
    end if;
    if v_block ? 'indent' then
      if jsonb_typeof(v_block -> 'indent') <> 'number'
         or (v_block ->> 'indent') !~ '^[0-3]$' then
        return false;
      end if;
      v_level := (v_block ->> 'indent')::integer;
    else
      v_level := 0;
    end if;
    if v_level > v_before + 1 then
      return false;
    end if;
    -- The line before was folded: this one is under it.
    if v_shut and v_level <= v_before then
      return false;
    end if;
    if v_block ? 'folded' and jsonb_typeof(v_block -> 'folded') <> 'boolean' then
      return false;
    end if;
    v_shut := coalesce((v_block ->> 'folded')::boolean, false);
    v_before := v_level;
  end loop;
  if v_shut then
    return false;
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
      return false;
    end if;
    if jsonb_typeof(v_block) <> 'object' or jsonb_typeof(v_block -> 'id') is distinct from 'string'
       or (v_block ->> 'id') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or (v_block ->> 'id') = any (v_ids) then
      return false;
    end if;
    v_ids := v_ids || (v_block ->> 'id');
    v_type := v_block ->> 'type';
    select array_agg(k) into v_keys from jsonb_object_keys(v_block) k;
    if v_type is null or not (v_keys <@ (case v_type
         when 'text' then array['id', 'type', 'text', 'indent', 'folded']
         when 'heading' then array['id', 'type', 'text', 'level', 'indent']
         when 'todo' then array['id', 'type', 'text', 'done', 'indent', 'folded']
         when 'bullet' then array['id', 'type', 'text', 'indent', 'folded']
         when 'numbered' then array['id', 'type', 'text', 'indent', 'start', 'folded']
         when 'toggle' then array['id', 'type', 'text', 'children', 'indent']
         when 'table' then array['id', 'type', 'rows', 'indent']
         when 'callout' then array['id', 'type', 'text', 'indent']
         when 'quote' then array['id', 'type', 'text', 'indent']
         when 'divider' then array['id', 'type', 'indent']
         when 'voice' then array['id', 'type', 'path', 'duration_ms', 'indent']
         else array[]::text[] end)) then
      return false;
    end if;
    if v_type = any (v_text) and not public.block_text_ok(v_block -> 'text', 0, 5000) then
      return false;
    end if;
    if v_type = 'heading' and v_block ? 'level'
       and (v_block -> 'level') not in ('1'::jsonb, '2'::jsonb) then
      return false;
    end if;
    if v_type = 'todo' and v_block ? 'done' and jsonb_typeof(v_block -> 'done') <> 'boolean' then
      return false;
    end if;
    if v_type = 'numbered' and v_block ? 'start'
       and (jsonb_typeof(v_block -> 'start') <> 'number'
            or (v_block ->> 'start') !~ '^[1-9][0-9]{0,2}$') then
      return false;
    end if;
    if v_type = 'toggle' then
      if jsonb_typeof(v_block -> 'children') is distinct from 'array' then
        return false;
      end if;
      for v_child in select * from jsonb_array_elements(v_block -> 'children') loop
        -- A toggle holds words and tables, at its own level; not another
        -- toggle, nor a voice.
        if jsonb_typeof(v_child) <> 'object'
           or (v_child ->> 'type') not in ('text', 'heading', 'todo', 'bullet', 'numbered',
                                           'table', 'callout', 'quote', 'divider')
           or (v_child ? 'indent' and (v_child -> 'indent') <> '0'::jsonb)
           or (v_child ? 'folded' and (v_child -> 'folded') <> 'false'::jsonb) then
          return false;
        end if;
      end loop;
    elsif v_type = 'table' then
      if jsonb_typeof(v_block -> 'rows') is distinct from 'array'
         or jsonb_array_length(v_block -> 'rows') not between 1 and 20 then
        return false;
      end if;
      v_width := null;
      for v_row in select * from jsonb_array_elements(v_block -> 'rows') loop
        if jsonb_typeof(v_row) <> 'array' or jsonb_array_length(v_row) not between 1 and 8
           or (v_width is not null and jsonb_array_length(v_row) <> v_width) then
          return false;
        end if;
        v_width := jsonb_array_length(v_row);
        for v_cell in select * from jsonb_array_elements(v_row) loop
          if not public.block_text_ok(v_cell, 0, 200) then
            return false;
          end if;
        end loop;
      end loop;
    elsif v_type = 'voice' then
      if jsonb_typeof(v_block -> 'path') is distinct from 'string'
         or (v_block ? 'duration_ms' and (jsonb_typeof(v_block -> 'duration_ms') <> 'number'
                                          or (v_block ->> 'duration_ms')::numeric < 0)) then
        return false;
      end if;
    end if;
  end loop;
  return true;
end;
$$;

-- The grants are kept by create or replace; said again so this file stands
-- alone.
revoke execute on function public.is_valid_note_blocks(jsonb) from public, anon;
grant execute on function public.is_valid_note_blocks(jsonb) to authenticated;
