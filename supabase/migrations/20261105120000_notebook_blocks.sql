-- Migration 44 (F107, review 92): a note is a page of blocks, with a
-- location and PDF files. Not live.
--
-- - notes.blocks: the note's page, in the same block format as a Work
--   post's page (id, type, text …) with the notebook's own kinds: text,
--   heading (level 1 or 2), todo, bullet, numbered, toggle, table, callout,
--   quote, divider and voice. At most 200 blocks (a toggle's included), a
--   block's text up to 5,000 characters (is_valid_note_blocks).
-- - notes.title: a block note's bold first line (up to 200).
-- - Old notes keep body and points; the app reads either and saves blocks
--   (with kind 'text') when one is opened and saved. Nothing is migrated in
--   SQL. A block note's body is its words as plain text, for My calendar
--   and the reminders.
-- - A block note may have a date (due_at), shown in My calendar.
-- - Location: typed (location_text, up to 120), the phone's GPS
--   (location_lat, location_lng, location_accuracy_m), or both. Private to
--   the note, as the note is.
-- - note_files.kind gains 'file': a PDF, up to the Library's 25 MB (the
--   bucket's limit), at most 10 on a note, in the same private bucket, with
--   its name. A block note's voice blocks are its voice files.
-- - save_note takes the blocks, the title, the location and the phone's
--   time (B6 in docs/reviews/f106-bugs.md).
-- - note_for_space: what "Put in a Space" carries from a note: the words,
--   the blocks and the typed location; the GPS only when asked.
-- - my_calendar and export_my_data read the new columns.
-- RLS is unchanged: only the owner reads a note and its files.

-- ---------------------------------------------------------------------------
-- Blocks
-- ---------------------------------------------------------------------------

-- A note's page: a list of blocks, each with its own uuid, at most 200 in
-- all (a toggle's own included), a block's text up to 5,000 characters, a
-- table's cell up to 200. The same shape as validate_blocks' (migration
-- 20), with the notebook's kinds; block_text_ok is shared with it.
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
  v_text text[] := array['text', 'heading', 'todo', 'bullet', 'numbered', 'toggle',
                         'callout', 'quote'];
begin
  if p_blocks is null or jsonb_typeof(p_blocks) <> 'array' then
    return false;
  end if;
  if octet_length(p_blocks::text) > 524288 then
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
         when 'text' then array['id', 'type', 'text']
         when 'heading' then array['id', 'type', 'text', 'level']
         when 'todo' then array['id', 'type', 'text', 'done']
         when 'bullet' then array['id', 'type', 'text']
         when 'numbered' then array['id', 'type', 'text']
         when 'toggle' then array['id', 'type', 'text', 'children']
         when 'table' then array['id', 'type', 'rows']
         when 'callout' then array['id', 'type', 'text']
         when 'quote' then array['id', 'type', 'text']
         when 'divider' then array['id', 'type']
         when 'voice' then array['id', 'type', 'path', 'duration_ms']
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
    if v_type = 'toggle' then
      if jsonb_typeof(v_block -> 'children') is distinct from 'array' then
        return false;
      end if;
      for v_child in select * from jsonb_array_elements(v_block -> 'children') loop
        -- A toggle holds words and tables; not another toggle, nor a voice.
        if jsonb_typeof(v_child) <> 'object'
           or (v_child ->> 'type') not in ('text', 'heading', 'todo', 'bullet', 'numbered',
                                           'table', 'callout', 'quote', 'divider') then
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

-- The voice files a page's voice blocks use, in order (toggles hold none).
create or replace function public.note_block_voices(p_blocks jsonb)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(b ->> 'path' order by o), '{}')
  from jsonb_array_elements(case when jsonb_typeof(p_blocks) = 'array' then p_blocks
                                 else '[]'::jsonb end) with ordinality x(b, o)
  where b ->> 'type' = 'voice';
$$;

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

alter table public.notes
  add column title text check (title is null or char_length(title) <= 200),
  add column blocks jsonb check (blocks is null or public.is_valid_note_blocks(blocks)),
  add column location_text text
    check (location_text is null or char_length(location_text) between 1 and 120),
  add column location_lat numeric(9, 6) check (location_lat between -90 and 90),
  add column location_lng numeric(9, 6) check (location_lng between -180 and 180),
  add column location_accuracy_m numeric(8, 1) check (location_accuracy_m > 0),
  -- A position is both numbers; its accuracy only with them.
  add constraint notes_location_pair
    check ((location_lat is null) = (location_lng is null)
           and (location_accuracy_m is null or location_lat is not null)),
  -- A page is a text note's.
  add constraint notes_blocks_kind check (blocks is null or kind = 'text');

-- A to-do has a time and a tick; a block note may have a date (its tick is
-- each to-do block's own).
alter table public.notes drop constraint notes_check1;
alter table public.notes
  add constraint notes_due_kind check (due_at is null or kind = 'todo' or blocks is not null),
  add constraint notes_done_kind check (done_at is null or kind = 'todo');

alter table public.note_files drop constraint note_files_kind_check;
alter table public.note_files
  add constraint note_files_kind_check check (kind in ('photo', 'voice', 'file')),
  add column name text check (name is null or char_length(name) between 1 and 200);

-- PDFs, in the same bucket; its 25 MB limit is the Library's.
update storage.buckets
set allowed_mime_types = array_append(allowed_mime_types, 'application/pdf')
where id = 'notebook-files' and not ('application/pdf' = any (allowed_mime_types));

-- ---------------------------------------------------------------------------
-- Files
-- ---------------------------------------------------------------------------

-- Upload: as before, and a .pdf.
create or replace function public.may_upload_note_file(p_name text)
returns boolean
language sql
stable security definer
set search_path = ''
as $function$
  select auth.uid() is not null
    and not public.is_hidden_account(auth.uid())
    and split_part(p_name, '/', 1) = auth.uid()::text
    and array_length(string_to_array(p_name, '/'), 1) = 3
    and split_part(p_name, '/', 2)
        ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and split_part(p_name, '/', 3) ~* '^[^/]+\.(jpg|jpeg|png|webp|heic|m4a|aac|mp3|mp4|pdf)$'
    and p_name not like '%..%'
    -- A note that already exists must be the caller's.
    and not exists (select 1 from public.notes n
                    where n.id::text = split_part(p_name, '/', 2)
                      and n.owner_id <> auth.uid())
    and (select count(*) < 200 and coalesce(sum((o.metadata ->> 'size')::bigint), 0) < 209715200
         from storage.objects o
         where o.bucket_id = 'notebook-files'
           and o.name collate "C" >= auth.uid()::text || '/'
           and o.name collate "C" < auth.uid()::text || '0'
           and o.owner_id = auth.uid()::text
           and o.created_at > now() - interval '1 day');
$function$;

-- Replace [p_note]'s files with [p_files]: [{path, mime?, bytes?, width?,
-- height?, duration_ms?, name?}]: at most 10 photos, 10 PDFs and 10
-- recordings. Each must be the caller's upload in notebook-files at
-- <me>/<note_id>/<file>; its type comes from Storage (the app's claim only
-- when Storage has none). A PDF keeps its name. Returns (photos, voices).
create or replace function public.set_note_files(p_note uuid, p_files jsonb,
                                                 out photos integer, out voices integer)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_me uuid := auth.uid();
  v_file jsonb;
  v_path text;
  v_mime text;
  v_kind text;
  v_name text;
  v_files integer := 0;
  v_sort integer := 0;
begin
  photos := 0;
  voices := 0;
  if p_files is null or jsonb_typeof(p_files) = 'null' then
    p_files := '[]'::jsonb;
  end if;
  if jsonb_typeof(p_files) <> 'array' or jsonb_array_length(p_files) > 30 then
    raise exception 'at most 10 files on a note' using errcode = '22023';
  end if;
  delete from public.note_files where note_id = p_note;
  for v_file in select * from jsonb_array_elements(p_files) loop
    if jsonb_typeof(v_file) <> 'object' then
      raise exception 'a file must be an object' using errcode = '22023';
    end if;
    v_path := v_file ->> 'path';
    if v_path is null or v_path like '%..%'
       or v_path not like v_me::text || '/' || p_note::text || '/%'
       or array_length(string_to_array(v_path, '/'), 1) <> 3 then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    select coalesce(nullif(o.metadata ->> 'mimetype', ''), v_file ->> 'mime') into v_mime
    from storage.objects o
    where o.bucket_id = 'notebook-files' and o.name = v_path and o.owner_id = v_me::text;
    if not found then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    v_name := null;
    if v_mime like 'image/%' then
      v_kind := 'photo';
      photos := photos + 1;
    elsif v_mime like 'audio/%' then
      v_kind := 'voice';
      voices := voices + 1;
    elsif v_mime = 'application/pdf' then
      v_kind := 'file';
      v_files := v_files + 1;
      v_name := nullif(left(trim(replace(coalesce(v_file ->> 'name', ''), '/', ' ')), 200), '');
    else
      raise exception 'photos, PDFs and voice notes only' using errcode = '22023';
    end if;
    if photos > 10 or voices > 10 or v_files > 10 then
      raise exception 'at most 10 files on a note' using errcode = '22023';
    end if;
    insert into public.note_files (note_id, storage_path, kind, mime, bytes, width, height,
                                   duration_ms, sort, name)
    values (p_note, v_path, v_kind, v_mime,
            nullif(v_file ->> 'bytes', '')::bigint,
            nullif(v_file ->> 'width', '')::integer,
            nullif(v_file ->> 'height', '')::integer,
            nullif(v_file ->> 'duration_ms', '')::integer,
            v_sort, v_name);
    v_sort := v_sort + 1;
  end loop;
exception
  when invalid_text_representation then
    raise exception 'a file is not valid' using errcode = '22023';
end;
$function$;

-- ---------------------------------------------------------------------------
-- Saving
-- ---------------------------------------------------------------------------

-- save_note gains its page, title, location and the phone's time: a new
-- signature, so the old one goes first (nothing else calls it).
drop function public.save_note(uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb);

-- Save [p_id] (new or the caller's own). Everything is replaced as given;
-- [p_pinned] null keeps the pin; [p_files] null keeps the files, a list
-- replaces them.
-- - text: words, a title, a photo, a PDF or (on a page) a voice block;
--   checklist: 1 to 50 points; todo: words; voice: one recording.
-- - [p_blocks]: a text note's page (is_valid_note_blocks); each voice
--   block is one of its recordings, and each recording a voice block's.
-- - [p_due_at]: a to-do's time, or a page's date.
-- - [p_location]: {text?, lat?, lng?, accuracy_m?}; null: none.
-- - [p_created_at]: when the phone sent it (kept when it is within the
--   last week and not ahead); a new note only.
-- - At most 500 new notes a day (counted under a per-person lock), deleted
--   ones included.
-- - A deleted note stays deleted: saving it again changes nothing and
--   returns null, so the app drops its queued edit.
create or replace function public.save_note(
  p_id uuid,
  p_kind text,
  p_body text default null,
  p_points jsonb default null,
  p_due_at timestamptz default null,
  p_remind_at timestamptz default null,
  p_pinned boolean default null,
  p_files jsonb default null,
  p_title text default null,
  p_blocks jsonb default null,
  p_location jsonb default null,
  p_created_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_me uuid := auth.uid();
  v_note public.notes;
  v_body text := nullif(trim(p_body), '');
  v_title text := nullif(trim(p_title), '');
  v_blocks jsonb := case when jsonb_typeof(p_blocks) = 'null' then null else p_blocks end;
  v_loc jsonb := case when jsonb_typeof(p_location) = 'object' then p_location end;
  v_loc_text text;
  v_lat numeric;
  v_lng numeric;
  v_accuracy numeric;
  v_photos integer;
  v_voices integer;
  v_pdfs integer;
  v_created timestamptz := now();
begin
  if v_me is null or public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_id is null then
    raise exception 'a note needs its id' using errcode = '22023';
  end if;
  if exists (select 1 from public.deleted_notes d where d.id = p_id) then
    if exists (select 1 from public.deleted_notes d where d.id = p_id and d.owner_id <> v_me) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    return null;
  end if;
  if p_kind is null or p_kind not in ('text', 'checklist', 'todo', 'voice') then
    raise exception 'choose a kind of note' using errcode = '22023';
  end if;
  if length(v_body) > 5000 then
    raise exception 'at most 5000 characters' using errcode = '22023';
  end if;
  if char_length(v_title) > 200 then
    raise exception 'a title of up to 200 characters' using errcode = '22023';
  end if;
  if v_blocks is not null then
    if p_kind <> 'text' then
      raise exception 'a page is a note''s' using errcode = '22023';
    end if;
    if not public.is_valid_note_blocks(v_blocks) then
      raise exception 'at most 200 blocks, each up to 5000 characters' using errcode = '22023';
    end if;
  end if;
  if p_kind = 'checklist' and (p_points is null or not public.is_valid_note_points(p_points)) then
    raise exception 'a checklist has 1 to 50 points' using errcode = '22023';
  end if;
  if p_kind <> 'checklist' and p_points is not null and jsonb_typeof(p_points) <> 'null' then
    raise exception 'only a checklist has points' using errcode = '22023';
  end if;
  if p_kind <> 'todo' and v_blocks is null and p_due_at is not null then
    raise exception 'only a to-do has a time' using errcode = '22023';
  end if;
  if p_kind = 'todo' and v_body is null then
    raise exception 'write the to-do' using errcode = '22023';
  end if;
  if p_remind_at is not null and p_remind_at > now() + interval '366 days' then
    raise exception 'a reminder within a year' using errcode = '22023';
  end if;
  if p_location is not null and jsonb_typeof(p_location) not in ('object', 'null') then
    raise exception 'a location is a place, a position or both' using errcode = '22023';
  end if;
  begin
    v_loc_text := nullif(trim(v_loc ->> 'text'), '');
    v_lat := (v_loc ->> 'lat')::numeric;
    v_lng := (v_loc ->> 'lng')::numeric;
    v_accuracy := (v_loc ->> 'accuracy_m')::numeric;
  exception
    when invalid_text_representation then
      raise exception 'a location is a place, a position or both' using errcode = '22023';
  end;
  if char_length(v_loc_text) > 120
     or (v_lat is null) <> (v_lng is null)
     or v_lat not between -90 and 90 or v_lng not between -180 and 180
     or v_accuracy <= 0 or v_accuracy >= 10000000
     or (v_accuracy is not null and v_lat is null) then
    raise exception 'a location is a place, a position or both' using errcode = '22023';
  end if;
  if p_created_at is not null and p_created_at > now() - interval '7 days' then
    v_created := least(p_created_at, now());
  end if;

  select * into v_note from public.notes where id = p_id for update;
  if v_note.id is not null and v_note.owner_id <> v_me then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if v_note.id is null then
    -- New: under a per-person lock, so the daily count holds and a retry of
    -- the same id running now becomes an update instead of a duplicate.
    perform pg_advisory_xact_lock(hashtextextended('note:' || v_me::text, 0));
    select * into v_note from public.notes where id = p_id for update;
    if v_note.id is not null and v_note.owner_id <> v_me then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    -- Deleted while this save waited.
    if v_note.id is null and exists (select 1 from public.deleted_notes d where d.id = p_id) then
      return null;
    end if;
  end if;
  if v_note.id is null then
    if (select count(*) from public.notes n
        where n.owner_id = v_me and n.created_at > now() - interval '1 day')
       + (select count(*) from public.deleted_notes d
          where d.owner_id = v_me and d.created_at > now() - interval '1 day') >= 500 then
      raise exception 'that''s 500 notes today; try again tomorrow' using errcode = '54000';
    end if;
    insert into public.notes (id, owner_id, kind, body, points, due_at, remind_at, pinned,
                              title, blocks, location_text, location_lat, location_lng,
                              location_accuracy_m, created_at)
    values (p_id, v_me, p_kind, v_body,
            case when p_kind = 'checklist' then p_points end,
            case when p_kind = 'todo' or v_blocks is not null then p_due_at end,
            p_remind_at, coalesce(p_pinned, false),
            v_title, v_blocks, v_loc_text, v_lat, v_lng, v_accuracy, v_created);
  else
    update public.notes
    set kind = p_kind,
        body = v_body,
        points = case when p_kind = 'checklist' then p_points end,
        due_at = case when p_kind = 'todo' or v_blocks is not null then p_due_at end,
        done_at = case when p_kind = 'todo' then done_at end,
        remind_at = p_remind_at,
        pinned = coalesce(p_pinned, pinned),
        title = v_title,
        blocks = v_blocks,
        location_text = v_loc_text,
        location_lat = v_lat,
        location_lng = v_lng,
        location_accuracy_m = v_accuracy,
        updated_at = now()
    where id = p_id;
  end if;

  if p_files is not null then
    select f.photos, f.voices into v_photos, v_voices from public.set_note_files(p_id, p_files) f;
  end if;
  select count(*) filter (where kind = 'photo'), count(*) filter (where kind = 'voice'),
         count(*) filter (where kind = 'file')
  into v_photos, v_voices, v_pdfs
  from public.note_files where note_id = p_id;
  if p_kind = 'voice' and v_voices <> 1 then
    raise exception 'a voice note has one recording' using errcode = '22023';
  end if;
  if p_kind <> 'text' and v_pdfs > 0 then
    raise exception 'a file goes on a note' using errcode = '22023';
  end if;
  if v_blocks is not null then
    -- Each voice block is one of the note's recordings, and each recording
    -- a voice block's.
    if (select coalesce(array_agg(f.storage_path order by f.storage_path), '{}')
        from public.note_files f where f.note_id = p_id and f.kind = 'voice')
       is distinct from
       (select coalesce(array_agg(v order by v), '{}')
        from unnest(public.note_block_voices(v_blocks)) v) then
      raise exception 'a voice block is one of the note''s recordings' using errcode = '22023';
    end if;
  elsif p_kind <> 'voice' and v_voices > 0 then
    raise exception 'a recording goes in a voice note' using errcode = '22023';
  end if;
  if p_kind = 'text' and v_body is null and v_title is null and v_photos = 0 and v_pdfs = 0
     and v_voices = 0 then
    raise exception 'write something or add a photo' using errcode = '22023';
  end if;
  return p_id;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Put in a Space
-- ---------------------------------------------------------------------------

-- What "Put in a Space" carries from [p_id] (yours) into the Space's
-- writing card: the kind, the title, the words, the points, the page, the
-- date, the photos and the typed location. The GPS position stays in the
-- notebook unless [p_include_gps] ("Include my GPS position", review 92).
-- Nothing is posted here: only Post posts.
create or replace function public.note_for_space(p_id uuid, p_include_gps boolean default false)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_note public.notes;
begin
  if auth.uid() is null or public.is_hidden_account(auth.uid()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_note from public.notes where id = p_id;
  if v_note.id is null or v_note.owner_id <> auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'id', v_note.id,
    'kind', v_note.kind,
    'title', v_note.title,
    'body', v_note.body,
    'points', v_note.points,
    'blocks', v_note.blocks,
    'due_at', v_note.due_at,
    'location_text', v_note.location_text,
    'location_lat', case when coalesce(p_include_gps, false) then v_note.location_lat end,
    'location_lng', case when coalesce(p_include_gps, false) then v_note.location_lng end,
    'location_accuracy_m',
      case when coalesce(p_include_gps, false) then v_note.location_accuracy_m end,
    'photos', (select jsonb_agg(f.storage_path order by f.sort)
               from public.note_files f where f.note_id = v_note.id and f.kind = 'photo')));
end;
$function$;

-- ---------------------------------------------------------------------------
-- Readers
-- ---------------------------------------------------------------------------

-- My calendar: as before; a block note with a date is a to-do row, by its
-- title (one change: the last union's where and title).
create or replace function public.my_calendar(p_from_day date, p_to_day date, p_from timestamp with time zone, p_to timestamp with time zone)
 returns table(kind text, space_id uuid, space_name text, team_id uuid, post_id uuid, note_id uuid, title text, place text, day date, starts_at timestamp with time zone, ends_at timestamp with time zone, status text, needs_me boolean)
 language plpgsql
 stable security definer
 set search_path to ''
as $function$
begin
  if auth.uid() is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_from_day is null or p_to_day is null or p_to_day < p_from_day
     or p_to_day - p_from_day > 61
     or p_from is null or p_to is null or p_to <= p_from
     -- An hour of slack for a change of clock in the phone's time zone.
     or p_to - p_from > interval '62 days 1 hour' then
    raise exception 'choose up to 62 days' using errcode = '22023';
  end if;
  return query
  with mine as (
    select m.space_id, s.name
    from public.space_members m
    join public.spaces s on s.id = m.space_id and s.deleted_at is null
    where m.profile_id = auth.uid() and m.left_at is null
  )
  select 'work_item'::text, p.space_id, mine.name, p.team_id, p.id, null::uuid, p.title,
         p.place_text, p.due_date, p.due_at, null::timestamptz, w.status,
         public.item_needs_me(w, p) is not null
  from mine
  join public.space_posts p on p.space_id = mine.space_id
  join public.work_items w on w.id = p.id
  where p.kind = 'work_item' and p.status = 'live' and p.deleted_at is null
    and w.status in ('open', 'done')
    and (w.owner_id = auth.uid() or p.author_id = auth.uid())
    and p.due_date between p_from_day and p_to_day
    and public.can_see_space_post(p.id)
  union all
  select 'checklist', p.space_id, mine.name, p.team_id, p.id, null, p.title,
         p.place_text, p.due_date, p.due_at, null, p.status, public.checklist_needs_me(p)
  from mine
  join public.space_posts p on p.space_id = mine.space_id
  where p.kind = 'checklist' and p.status = 'live' and p.deleted_at is null
    and p.due_date between p_from_day and p_to_day
    and exists (select 1 from public.post_people pp
                where pp.post_id = p.id and pp.profile_id = auth.uid())
    and public.can_see_space_post(p.id)
  union all
  select 'activity', p.space_id, mine.name, p.team_id, p.id, null, p.title,
         p.place_text, null, p.starts_at, p.ends_at, p.status, false
  from mine
  join public.space_posts p on p.space_id = mine.space_id
  where p.kind = 'activity' and p.status = 'live' and p.deleted_at is null
    and p.starts_at >= p_from and p.starts_at < p_to
    and (exists (select 1 from public.post_people pp
                 where pp.post_id = p.id and pp.profile_id = auth.uid())
         or exists (select 1 from public.post_acks a
                    where a.post_id = p.id and a.profile_id = auth.uid()
                      and a.kind = 'in_my_calendar'))
    and public.can_see_space_post(p.id)
  union all
  select 'todo', null, null, null, null, n.id,
         coalesce(left(coalesce(n.title, n.body), 200), ''), null, null, n.due_at, null,
         case when n.done_at is null then 'open' else 'done' end, false
  from public.notes n
  where n.owner_id = auth.uid() and (n.kind = 'todo' or n.blocks is not null)
    and n.due_at >= p_from and n.due_at < p_to
  order by 10 nulls last, 9 nulls last, 7;
end;
$function$;

-- Download my data: a note's title, page and location too (one change: the
-- notes object).
CREATE OR REPLACE FUNCTION public.export_my_data(p_request uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) - 'follower_count' - 'following_count'
                from public.profiles p where p.id = r.profile_id),
    'private', (select to_jsonb(pp) from public.profile_private pp where pp.id = r.profile_id),
    'experience', coalesce((select jsonb_agg(to_jsonb(e)) from public.experience e
                            where e.profile_id = r.profile_id), '[]'),
    'open_to', coalesce((select jsonb_agg(to_jsonb(o)) from public.profile_open_to o
                         where o.profile_id = r.profile_id), '[]'),
    'cv_projects', coalesce((select jsonb_agg(to_jsonb(c)) from public.cv_projects c
                             where c.profile_id = r.profile_id), '[]'),
    'following', coalesce((select jsonb_agg(f.followee_id) from public.follows f
                           where f.follower_id = r.profile_id), '[]'),
    'posts', coalesce((select jsonb_agg(jsonb_build_object(
                         'id', po.id, 'body', po.body, 'lang', po.lang,
                         'created_at', po.created_at, 'deleted_at', po.deleted_at))
                       from public.posts po where po.author_id = r.profile_id), '[]'),
    'replies', coalesce((select jsonb_agg(jsonb_build_object(
                           'id', pr.id, 'post_id', pr.post_id, 'body', pr.body,
                           'created_at', pr.created_at))
                         from public.post_replies pr where pr.author_id = r.profile_id), '[]'),
    'spaces', coalesce((select jsonb_agg(jsonb_build_object(
                          'space', s.name, 'pass', m.pass, 'admin', m.is_admin,
                          'joined_at', m.confirmed_at, 'left_at', m.left_at))
                        from public.space_members m join public.spaces s on s.id = m.space_id
                        where m.profile_id = r.profile_id), '[]'),
    'work_items_raised', coalesce((select jsonb_agg(jsonb_build_object(
                                     'ref', w.ref, 'title', w.title, 'status', w.status,
                                     'created_at', w.created_at))
                                   from public.work_items w where w.created_by = r.profile_id), '[]'),
    'work_items_owned', coalesce((select jsonb_agg(jsonb_build_object(
                                    'ref', w.ref, 'title', w.title, 'status', w.status,
                                    'checked_at', w.checked_at))
                                  from public.work_items w where w.owner_id = r.profile_id), '[]'),
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
                            'id', ms.id, 'kind', ms.kind, 'body', ms.body,
                            'created_at', ms.created_at))
                          from public.messages ms where ms.author_id = r.profile_id), '[]'),
    'work_item_notes', coalesce((select jsonb_agg(jsonb_build_object(
                                   'ref', w.ref, 'kind', e.kind, 'note', e.note,
                                   'created_at', e.created_at))
                                 from public.work_item_events e
                                 join public.work_items w on w.id = e.work_item_id
                                 where e.actor_id = r.profile_id and e.note is not null), '[]'),
    'library_files', coalesce((select jsonb_agg(jsonb_build_object(
                                 'space', s.name, 'name', f.name, 'created_at', f.created_at,
                                 'deleted_at', f.deleted_at))
                               from public.library_files f join public.spaces s on s.id = f.space_id
                               where f.uploaded_by = r.profile_id), '[]'),
    'blocked', coalesce((select jsonb_agg(jsonb_build_object(
                           'profile_id', b.blocked_id, 'created_at', b.created_at))
                         from public.blocks b where b.blocker_id = r.profile_id), '[]'),
    'muted', coalesce((select jsonb_agg(jsonb_build_object(
                         'profile_id', mu.muted_id, 'created_at', mu.created_at))
                       from public.mutes mu where mu.muter_id = r.profile_id), '[]'),
    'useful_marks', coalesce((select jsonb_agg(jsonb_build_object(
                                'target_kind', u.target_kind, 'target_id', u.target_id,
                                'created_at', u.created_at))
                              from public.useful_marks u where u.profile_id = r.profile_id), '[]'),
    'reports_made', coalesce((select jsonb_agg(jsonb_build_object(
                                'target_kind', rp.target_kind, 'reason', rp.reason, 'note', rp.note,
                                'status', rp.status, 'created_at', rp.created_at))
                              from public.reports rp where rp.reporter_id = r.profile_id), '[]'),
    'join_requests', coalesce((select jsonb_agg(jsonb_build_object(
                                 'space', s.name, 'via', j.via, 'status', j.status,
                                 'created_at', j.created_at))
                               from public.space_join_requests j join public.spaces s on s.id = j.space_id
                               where j.profile_id = r.profile_id), '[]'),
    'space_posts', coalesce((select jsonb_agg(jsonb_build_object(
                              'kind', p.kind, 'title', p.title, 'body', p.body,
                              'place', p.place_text, 'due_date', p.due_date, 'due_at', p.due_at,
                              'quote', p.quote, 'status', p.status,
                              'pinned_until', p.pinned_until, 'starts_at', p.starts_at,
                              'ends_at', p.ends_at,
                              'file', (select f.name from public.library_files f
                                       where f.id = p.library_file_id),
                              'blocks', p.blocks, 'template_id', p.template_id,
                              'created_at', p.created_at, 'deleted_at', p.deleted_at))
                            from public.space_posts p where p.author_id = r.profile_id), '[]'),
    'post_edits', coalesce((select jsonb_agg(jsonb_build_object(
                             'changes', e.changes, 'created_at', e.created_at))
                           from public.post_edits e where e.editor_id = r.profile_id), '[]'),
    'post_acks', coalesce((select jsonb_agg(jsonb_build_object(
                            'post', p.title, 'kind', a.kind, 'created_at', a.created_at))
                          from public.post_acks a join public.space_posts p on p.id = a.post_id
                          where a.profile_id = r.profile_id), '[]'),
    'checklist_ticks', coalesce((select jsonb_agg(jsonb_build_object(
                                  'point', c.text, 'ticked_at', c.ticked_at))
                                from public.checklist_points c where c.ticked_by = r.profile_id), '[]'),
    'tick_log', coalesce((select jsonb_agg(jsonb_build_object(
                           'post', p.title, 'kind', t.kind, 'point', t.point_text,
                           'created_at', t.created_at) order by t.created_at, t.id)
                         from public.post_point_events t join public.space_posts p on p.id = t.post_id
                         where t.actor_id = r.profile_id), '[]'),
    'post_people', coalesce((select jsonb_agg(jsonb_build_object(
                              'post', p.title, 'created_at', pp.created_at))
                            from public.post_people pp join public.space_posts p on p.id = pp.post_id
                            where pp.profile_id = r.profile_id), '[]'),
    'notes', coalesce((select jsonb_agg(jsonb_build_object(
                        'kind', n.kind, 'title', n.title, 'body', n.body, 'points', n.points,
                        'blocks', n.blocks, 'location_text', n.location_text,
                        'location_lat', n.location_lat, 'location_lng', n.location_lng,
                        'due_at', n.due_at, 'done_at', n.done_at, 'pinned', n.pinned,
                        'remind_at', n.remind_at, 'created_at', n.created_at,
                        'files', (select jsonb_agg(f.storage_path order by f.sort)
                                  from public.note_files f where f.note_id = n.id)))
                      from public.notes n where n.owner_id = r.profile_id), '[]'),
    'post_templates', coalesce((select jsonb_agg(jsonb_build_object(
                                 'name', t.name, 'kind', t.kind, 'blocks', t.blocks,
                                 'fields', t.fields, 'created_at', t.created_at,
                                 'deleted_at', t.deleted_at))
                               from public.post_templates t where t.created_by = r.profile_id), '[]'),
    'dm_messages', coalesce((select jsonb_agg(jsonb_build_object(
                              'thread_id', d.thread_id, 'kind', d.kind, 'body', d.body,
                              'created_at', d.created_at, 'deleted_at', d.deleted_at,
                              'files', (select jsonb_agg(a.name) from public.dm_attachments a
                                        where a.message_id = d.id)))
                            from public.dm_messages d where d.author_id = r.profile_id), '[]'),
    'dm_threads', coalesce((select jsonb_agg(jsonb_build_object(
                             'thread_id', m.thread_id, 'state', m.state,
                             'created_at', t.created_at))
                           from public.dm_members m join public.dm_threads t on t.id = m.thread_id
                           where m.profile_id = r.profile_id), '[]'),
    'push_settings', (select to_jsonb(ps) from public.push_settings ps where ps.profile_id = r.profile_id)
  )
  from public.data_requests r
  where r.id = p_request;
$function$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.is_valid_note_blocks(jsonb),
  public.note_block_voices(jsonb),
  public.save_note(uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb, text, jsonb,
                   jsonb, timestamptz),
  public.note_for_space(uuid, boolean)
  from public, anon;
grant execute on function
  public.is_valid_note_blocks(jsonb),
  public.save_note(uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb, text, jsonb,
                   jsonb, timestamptz),
  public.note_for_space(uuid, boolean)
  to authenticated;
