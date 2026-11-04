-- Migration 68 (review 103): scanned documents. A scan is a PDF made on the
-- phone, in the places that already take a PDF; no new table.
--
-- 1. library_files and note_files: `scanned` and `page_count` (1–20), so
--    lists say "Scanned · 3 pages". The Library's uploader marks the file
--    after add_library_file (mark_library_file_scanned); a note's files
--    carry it in set_note_files.
-- 2. A work item's proof can be a scanned PDF: evidence kind 'scan' with
--    its page count. add_evidence takes a photo (.jpg, .jpeg) or a PDF
--    (.pdf) in the item's folder, nothing else.
-- Each follows its place's existing read rules.

alter table public.library_files
  add column scanned boolean not null default false,
  add column page_count smallint check (page_count between 1 and 20);

alter table public.note_files
  add column scanned boolean not null default false,
  add column page_count smallint check (page_count between 1 and 20);

alter table public.work_item_evidence drop constraint work_item_evidence_kind_check;
alter table public.work_item_evidence
  add constraint work_item_evidence_kind_check check (kind in ('photo', 'scan')),
  add column page_count smallint check (page_count between 1 and 20);

-- The Library file [p_file], just added by the caller, was scanned: [p_pages]
-- pages.
create function public.mark_library_file_scanned(p_file uuid, p_pages integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_file public.library_files;
begin
  select * into v_file from public.library_files where id = p_file;
  if auth.uid() is null or v_file.id is null or v_file.deleted_at is not null
     or v_file.uploaded_by is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_file.mime <> 'application/pdf' or p_pages is null or p_pages not between 1 and 20 then
    raise exception 'a scan is a PDF of 1 to 20 pages' using errcode = '22023';
  end if;
  update public.library_files set scanned = true, page_count = p_pages where id = p_file;
end;
$$;
revoke all on function public.mark_library_file_scanned(uuid, integer) from public, anon;
grant execute on function public.mark_library_file_scanned(uuid, integer) to authenticated;

create function pg_temp.r103_patch(p_fn regprocedure, p_old text, p_new text)
returns void language plpgsql as $$
declare
  -- Live has CRLF in some function bodies.
  v_def text := replace(pg_get_functiondef(p_fn), chr(13), '');
begin
  if position(p_old in v_def) = 0
     or position(p_old in substr(v_def, position(p_old in v_def) + 1)) > 0 then
    raise exception 'review 103: % is not as expected', p_fn;
  end if;
  execute replace(v_def, p_old, p_new);
end;
$$;

-- set_note_files: a PDF keeps its scanned mark and pages.
select pg_temp.r103_patch(
  'public.set_note_files(uuid, jsonb)',
  $old$    insert into public.note_files (note_id, storage_path, kind, mime, bytes, width, height,
                                   duration_ms, sort, name)
    values (p_note, v_path, v_kind, v_mime,
            nullif(v_file ->> 'bytes', '')::bigint,
            nullif(v_file ->> 'width', '')::integer,
            nullif(v_file ->> 'height', '')::integer,
            nullif(v_file ->> 'duration_ms', '')::integer,
            v_sort, v_name);$old$,
  $new$    insert into public.note_files (note_id, storage_path, kind, mime, bytes, width, height,
                                   duration_ms, sort, name, scanned, page_count)
    values (p_note, v_path, v_kind, v_mime,
            nullif(v_file ->> 'bytes', '')::bigint,
            nullif(v_file ->> 'width', '')::integer,
            nullif(v_file ->> 'height', '')::integer,
            nullif(v_file ->> 'duration_ms', '')::integer,
            v_sort, v_name,
            -- Review 103: a scanned PDF.
            v_kind = 'file' and coalesce((v_file ->> 'scanned')::boolean, false),
            case when v_kind = 'file' then nullif(v_file ->> 'page_count', '')::smallint end);$new$);

-- add_evidence: a photo or a scanned PDF, nothing else; a PDF is a scan.
select pg_temp.r103_patch(
  'public.add_evidence(public.work_items, uuid, jsonb)',
  $old$       or v_path like '%..%' then$old$,
  $new$       or v_path like '%..%'
       -- Review 103: a photo, or a scanned PDF.
       or lower(v_path) !~ '\.(jpe?g|pdf)$' then$new$);
select pg_temp.r103_patch(
  'public.add_evidence(public.work_items, uuid, jsonb)',
  $old$    insert into public.work_item_evidence (event_id, work_item_id, storage_path, taken_at, place_text)
    values (p_event, p_item.id, v_path,
            nullif(v_photo ->> 'taken_at', '')::timestamptz,
            nullif(trim(v_photo ->> 'place'), ''));$old$,
  $new$    insert into public.work_item_evidence (event_id, work_item_id, storage_path, taken_at, place_text,
                                           kind, page_count)
    values (p_event, p_item.id, v_path,
            nullif(v_photo ->> 'taken_at', '')::timestamptz,
            nullif(trim(v_photo ->> 'place'), ''),
            case when lower(v_path) like '%.pdf' then 'scan' else 'photo' end,
            case when lower(v_path) like '%.pdf'
                 then nullif(v_photo ->> 'page_count', '')::smallint end);$new$);

-- The lead's check (D1): a scanned proof is a PDF upload; a photo stays a
-- photo. Each path's own type, as the phone sent it.
select pg_temp.r103_patch(
  'public.add_evidence(public.work_items, uuid, jsonb)',
  $old$    if coalesce(public.upload_mime(v_path, null), 'image/') not like 'image/%' then
      raise exception 'evidence must be a photo' using errcode = '22023';$old$,
  $new$    if lower(v_path) like '%.pdf' then
      if coalesce(public.upload_mime(v_path, null), '') <> 'application/pdf' then
        raise exception 'evidence must be a photo or a scanned PDF' using errcode = '22023';
      end if;
    elsif coalesce(public.upload_mime(v_path, null), 'image/') not like 'image/%' then
      raise exception 'evidence must be a photo or a scanned PDF' using errcode = '22023';$new$);
