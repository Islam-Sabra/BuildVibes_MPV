-- Migration 69 (review 103, OCR, approved for before the pilot): "Extract
-- text". When someone taps it on a file they can open, the edge function
-- extract-text reads the file with Google Cloud Vision (document text
-- detection) and keeps the text here. Never automatic.
--
-- 1. file_texts: one text per file. A Library file by its id; a note's file
--    by its storage path (a note's file rows are written again on each
--    save, its path stays). Read exactly as the file is read; written only
--    by the edge function (service role).
-- 2. file_for_text: as the caller, the file's bucket and path, or 42501.
--    The edge function asks it with the caller's own sign-in.
-- 3. save_file_text: the service role keeps a text, at most 20 pages; a
--    file over 20 pages is kept marked partial (the first 20). A day's
--    pages are in ocr_usage, reserved before Vision is asked
--    (reserve_text_pages, one person at a time) and given back when it
--    fails (release_text_pages): 50 a person a day.
-- 4. Searchable: Space search finds a Library file by its text, notebook
--    search a note by its files' text.

create table public.file_texts (
  id uuid primary key default gen_random_uuid(),
  file_kind text not null check (file_kind in ('library', 'note')),
  file_ref text not null check (char_length(file_ref) between 1 and 400),
  lang text check (char_length(lang) <= 16),
  text text not null check (char_length(text) <= 200000),
  pages smallint not null check (pages between 0 and 20),
  -- The lead's check, D3: the first 20 pages of a longer file.
  partial boolean not null default false,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (file_kind, file_ref)
);
create index file_texts_by_idx on public.file_texts (created_by, created_at);

-- Whether the caller reads [p_kind]'s file [p_ref], as the file itself.
create function public.can_read_file_text(p_kind text, p_ref text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_kind
    when 'library' then
      p_ref ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      and public.can_open_library_file(p_ref::uuid)
    when 'note' then exists (
      select 1 from public.note_files nf
      join public.notes n on n.id = nf.note_id
      where nf.storage_path = p_ref and nf.kind = 'file' and n.owner_id = auth.uid()
        and n.deleted_at is null)
    else false
  end;
$$;

alter table public.file_texts enable row level security;
create policy file_texts_read on public.file_texts
  for select to authenticated using (public.can_read_file_text(file_kind, file_ref));
revoke all on public.file_texts from public, anon, authenticated;
grant select on public.file_texts to authenticated;
grant all on public.file_texts to service_role;

-- The file the caller asks to read: its bucket, path and type. Only a PDF
-- or a photo.
create function public.file_for_text(p_kind text, p_ref text)
returns table (bucket text, path text, mime text, bytes bigint, done boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.can_read_file_text(p_kind, p_ref) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_kind = 'library' then
    return query
      select 'space-files'::text, f.storage_path, f.mime, f.bytes,
             exists (select 1 from public.file_texts t
                     where t.file_kind = 'library' and t.file_ref = p_ref)
      from public.library_files f
      where f.id = p_ref::uuid and f.deleted_at is null
        and (f.mime = 'application/pdf' or f.mime like 'image/%');
  else
    return query
      select 'notebook-files'::text, nf.storage_path, nf.mime, nf.bytes,
             exists (select 1 from public.file_texts t
                     where t.file_kind = 'note' and t.file_ref = p_ref)
      from public.note_files nf
      where nf.storage_path = p_ref
      limit 1;
  end if;
end;
$$;
revoke all on function public.file_for_text(text, text) from public, anon;
grant execute on function public.file_for_text(text, text) to authenticated;

-- The lead's check, D5: each person's pages read today, the server's
-- own count (never what file_texts says).
create table public.ocr_usage (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  pages integer not null default 0 check (pages between 0 and 50),
  primary key (profile_id, day)
);
alter table public.ocr_usage enable row level security;
revoke all on public.ocr_usage from public, anon, authenticated;
grant all on public.ocr_usage to service_role;

-- Pages [p_who] may still have read today (50 a day).
create function public.text_pages_left(p_who uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select greatest(50 - coalesce((select u.pages from public.ocr_usage u
                                 where u.profile_id = p_who and u.day = current_date), 0), 0)::integer;
$$;

-- Holds [p_pages] of [p_who]'s day before Vision is asked; false when
-- they would pass 50. One person's calls wait for each other.
create function public.reserve_text_pages(p_who uuid, p_pages integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_who is null or p_pages is null or p_pages not between 1 and 20 then
    raise exception 'one to 20 pages' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('ocr:' || p_who::text, 103));
  if p_pages > public.text_pages_left(p_who) then
    return false;
  end if;
  insert into public.ocr_usage (profile_id, day, pages)
  values (p_who, current_date, p_pages)
  on conflict (profile_id, day) do update set pages = public.ocr_usage.pages + excluded.pages;
  return true;
end;
$$;

-- Gives back what [reserve_text_pages] held when Vision failed.
create function public.release_text_pages(p_who uuid, p_pages integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('ocr:' || p_who::text, 103));
  update public.ocr_usage set pages = greatest(pages - greatest(coalesce(p_pages, 0), 0), 0)
  where profile_id = p_who and day = current_date;
end;
$$;

-- The service role keeps what Vision read of [p_kind]'s file [p_ref] for
-- [p_who]: [p_pages] pages.
create function public.save_file_text(
  p_kind text, p_ref text, p_who uuid, p_lang text, p_text text, p_pages integer,
  p_partial boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_kind not in ('library', 'note') or p_ref is null or p_who is null then
    raise exception 'not a file' using errcode = '22023';
  end if;
  if p_pages is null or p_pages not between 0 and 20 then
    raise exception 'at most 20 pages a file' using errcode = '22023';
  end if;
  -- The day's pages were reserved before Vision was asked (D5).
  insert into public.file_texts (file_kind, file_ref, lang, text, pages, partial, created_by)
  values (p_kind, p_ref, nullif(left(trim(coalesce(p_lang, '')), 16), ''),
          left(coalesce(p_text, ''), 200000), p_pages, coalesce(p_partial, false), p_who)
  on conflict (file_kind, file_ref) do update
    set lang = excluded.lang, text = excluded.text, pages = excluded.pages,
        partial = excluded.partial, created_by = excluded.created_by, created_at = now();
end;
$$;
revoke all on function public.save_file_text(text, text, uuid, text, text, integer, boolean)
  from public, anon, authenticated;
revoke all on function public.text_pages_left(uuid) from public, anon, authenticated;
revoke all on function public.reserve_text_pages(uuid, integer) from public, anon, authenticated;
revoke all on function public.release_text_pages(uuid, integer) from public, anon, authenticated;
grant execute on function public.reserve_text_pages(uuid, integer) to service_role;
grant execute on function public.release_text_pages(uuid, integer) to service_role;
revoke all on function public.can_read_file_text(text, text) from public, anon;
-- Used by file_texts' read rule: says only whether the caller reads that file.
grant execute on function public.can_read_file_text(text, text) to authenticated;
grant execute on function public.save_file_text(text, text, uuid, text, text, integer, boolean)
  to service_role;
grant execute on function public.text_pages_left(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- Searchable
-- ---------------------------------------------------------------------------

create function pg_temp.r103_ocr_patch(p_fn regprocedure, p_old text, p_new text)
returns void language plpgsql as $$
declare
  v_def text := replace(pg_get_functiondef(p_fn), chr(13), '');
begin
  if position(p_old in v_def) = 0
     or position(p_old in substr(v_def, position(p_old in v_def) + 1)) > 0 then
    raise exception 'review 103: % is not as expected', p_fn;
  end if;
  execute replace(v_def, p_old, p_new);
end;
$$;

select pg_temp.r103_ocr_patch(
  'public.search_space(uuid, text)',
  $old$       and f.search_text like v_pat
       and public.can_read_library_file(f.id)$old$,
  $new$       and (f.search_text like v_pat
            -- Review 103: or the words Extract text read in it.
            or exists (select 1 from public.file_texts ft
                       where ft.file_kind = 'library' and ft.file_ref = f.id::text
                         and public.search_fold(ft.text) like v_pat))
       and public.can_read_library_file(f.id)$new$);

-- The text Extract text read in [p_note]'s files, for its owner's search.
create function public.note_files_text(p_note uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select string_agg(ft.text, ' ')
  from public.note_files nf
  join public.file_texts ft on ft.file_kind = 'note' and ft.file_ref = nf.storage_path
  where nf.note_id = p_note and nf.kind = 'file';
$$;
revoke all on function public.note_files_text(uuid) from public, anon, authenticated;

-- The note's own words and its files' text, for the snippet and the match.
select pg_temp.r103_ocr_patch(
  'public.search_notebook(text, text, uuid)',
  $old$            concat_ws(' ', n.body, public.blocks_plain_text(n.blocks),$old$,
  $new$            concat_ws(' ', n.body, public.blocks_plain_text(n.blocks),
                      public.note_files_text(n.id),$new$);
select pg_temp.r103_ocr_patch(
  'public.search_notebook(text, text, uuid)',
  $old$     and (v_q = '' or public.search_fold(concat_ws(' ', n.title, n.body,
                                                   public.blocks_plain_text(n.blocks),$old$,
  $new$     and (v_q = '' or public.search_fold(concat_ws(' ', n.title, n.body,
                                                   public.blocks_plain_text(n.blocks),
                                                   public.note_files_text(n.id),$new$);

-- ---------------------------------------------------------------------------
-- The lead's check, D6: a text goes with its file
-- ---------------------------------------------------------------------------

-- A Library file deleted (to the bin, or for good): its text goes.
create function public.drop_library_file_text()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' or new.deleted_at is not null then
    delete from public.file_texts
    where file_kind = 'library' and file_ref = old.id::text;
  end if;
  return null;
end;
$$;
create trigger library_files_drop_text
  after update of deleted_at or delete on public.library_files
  for each row execute function public.drop_library_file_text();

-- A note deleted for good (or with its account): its files' texts go.
create function public.drop_note_texts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.file_texts
  where file_kind = 'note'
    and file_ref like old.owner_id::text || '/' || old.id::text || '/%';
  return null;
end;
$$;
create trigger notes_drop_texts
  after delete on public.notes
  for each row execute function public.drop_note_texts();
revoke all on function public.drop_library_file_text() from public, anon, authenticated;
revoke all on function public.drop_note_texts() from public, anon, authenticated;

-- A file taken off a note: set_note_files writes the note's files again
-- each save; a path no longer there takes its text with it.
select pg_temp.r103_ocr_patch(
  'public.set_note_files(uuid, jsonb)',
  $old$    v_sort := v_sort + 1;
  end loop;$old$,
  $new$    v_sort := v_sort + 1;
  end loop;
  -- Review 103 (D6): texts of files no longer on the note go.
  delete from public.file_texts t
  where t.file_kind = 'note'
    and t.file_ref like v_me::text || '/' || p_note::text || '/%'
    and not exists (select 1 from public.note_files nf
                    where nf.note_id = p_note and nf.storage_path = t.file_ref);$new$);
