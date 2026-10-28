-- Migration 48 (review 99B, review 100 Parts 3b, 6 and 8): Deleted items,
-- Archive, Share and the Filter, and a base version on save_note.
--
-- - Deleted items (99B B3): notes.deleted_at (pages have theirs). Delete
--   an entry, a line group (it becomes an entry of its own, "Part of an
--   entry", part_of) or a page with everything inside. Restore puts it back
--   in its page, or in a new page with the old title when that page is
--   gone. Delete forever and Empty now remove for good (deleted_notes keeps
--   the id, so a late save can't bring it back). Nothing deleted shows in
--   search, on the Filter or on My calendar.
-- - Keep deleted items for 7, 30 or 90 days (profile_private, 30 by
--   default), set by one function. The daily purge (purge_notebook, the
--   service role's only) removes what is past it; the files it frees are
--   then orphans that orphan_note_files gives the notebook-purge job to
--   delete from Storage.
-- - Archive (100 Part 3b): notes.archived_at, set and cleared only through
--   a function. An archived entry leaves search and My calendar; the
--   Filter shows it under Archived.
-- - Share (100 Part 6): an entry or a line group to a Space (create_space_post
--   or create_work_item, with the Space's rules and passes), to the feed
--   (create_post) or to a person by message (start_dm, with its rules:
--   block, the hidden account, the request and spam guard). Its words go
--   as plain text, to-dos as [ ] and [x] (J2: every phone's font has
--   them); the location (typed words and its
--   map pin) only when included. Each share leaves a mark (note_shares).
-- - The Filter (100 Part 8): search_notebook gains a kind (todos_open,
--   photos, files, voice, reminders, archived) and a page, with its
--   sub-pages.
-- - save_note takes the version the edit started from: a save based on an
--   older one is refused ("changed on another phone", 40001). Without it
--   (an older build) it saves as before.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

alter table public.notes
  add column deleted_at timestamptz,
  add column archived_at timestamptz,
  add column version integer not null default 1 check (version >= 1),
  -- A line group deleted out of an entry (B3: "Part of an entry").
  add column part_of uuid,
  -- Its page's title when it was deleted, for Restore into a new page.
  add column page_title text check (page_title is null or char_length(page_title) <= 120);

-- An entry in Deleted items may outlive its page (the page purged first).
alter table public.notes alter column page_id drop not null;
alter table public.notes
  add constraint notes_page_or_deleted check (page_id is not null or deleted_at is not null);
alter table public.notes drop constraint notes_page_id_fkey;
alter table public.notes
  add constraint notes_page_id_fkey foreign key (page_id)
  references public.notebook_pages (id) on delete set null;
create index notes_deleted_idx on public.notes (owner_id, deleted_at) where deleted_at is not null;

alter table public.profile_private
  add column notebook_keep_days smallint not null default 30
  check (notebook_keep_days in (7, 30, 90));

-- Each share's mark on the entry (100 Part 6): "Shared to the feed ·
-- 08:45", "Shared to NBKCH Site team · 08:45", "Sent to Ahmed · 08:45".
create table public.note_shares (
  id uuid primary key default gen_random_uuid(),
  note_id uuid not null references public.notes (id) on delete cascade,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  target text not null check (target in ('space', 'feed', 'message')),
  space_post_id uuid references public.space_posts (id) on delete set null,
  feed_post_id uuid references public.posts (id) on delete set null,
  dm_thread_id uuid references public.dm_threads (id) on delete set null,
  -- The Space's or the person's name as it was.
  target_name text,
  created_at timestamptz not null default now()
);
create index note_shares_note_idx on public.note_shares (note_id, created_at);
alter table public.note_shares enable row level security;
create policy note_shares_read_own on public.note_shares
  for select to authenticated using (owner_id = auth.uid());
revoke all on public.note_shares from anon, authenticated;
grant select on public.note_shares to authenticated;
grant all on public.note_shares to service_role;

-- ---------------------------------------------------------------------------
-- An entry's page, now that a deleted one may have none
-- ---------------------------------------------------------------------------

create or replace function public.note_page_ok()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.page_id is null and tg_op = 'INSERT' then
    new.page_id := nullif(current_setting('bv.note_page', true), '')::uuid;
    if new.page_id is null then
      select p.id into new.page_id from public.notebook_pages p
      where p.owner_id = new.owner_id and p.deleted_at is null
      order by p.last_activity_at desc, p.id desc
      limit 1;
    end if;
    if new.page_id is null then
      insert into public.notebook_pages (owner_id, named, icon)
      values (new.owner_id, 'my_notes', 'notebook')
      on conflict (owner_id) where named = 'my_notes' and deleted_at is null do nothing
      returning id into new.page_id;
    end if;
    if new.page_id is null then
      select p.id into new.page_id from public.notebook_pages p
      where p.owner_id = new.owner_id and p.named = 'my_notes' and p.deleted_at is null;
    end if;
  end if;
  -- Only an entry in Deleted items is without a page (its page purged).
  if new.page_id is null then
    if new.deleted_at is null then
      raise exception 'an entry is in a page' using errcode = '23514';
    end if;
    return new;
  end if;
  if not exists (select 1 from public.notebook_pages p
                 where p.id = new.page_id and p.owner_id = new.owner_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- [p_id], an entry of mine not in Deleted items, locked; or refused.
create or replace function public.my_live_note(p_id uuid)
returns public.notes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note public.notes;
begin
  select * into v_note from public.notes n
  where n.id = p_id and n.owner_id = auth.uid() and n.deleted_at is null
  for update;
  if v_note.id is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return v_note;
end;
$$;

-- A page's name for a person: its title, or "" for one the app names.
create or replace function public.notebook_page_title(p_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(p.title, '') from public.notebook_pages p where p.id = p_id;
$$;

-- An entry's words, and the words of [p_lines] only when given (a line
-- group), as plain text to share: the title first (the whole entry), a
-- line each, to-dos as [ ] and [x] (J2), numbered lines counted, bullets as •,
-- each level two spaces in; a toggle's lines under it; a table's rows with
-- " · "; then, when [p_include_location], the location as one line:
-- "📍 Gate 2 · 29.375900, 47.977400" (the pin only when it has one).
create or replace function public.note_words(
  p_note public.notes, p_lines text[], p_include_location boolean
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_out text[] := '{}';
  v_block jsonb;
  v_child jsonb;
  v_row jsonb;
  v_type text;
  v_pad text;
  v_count integer := 0;
  v_point jsonb;
  v_loc text;
begin
  if p_lines is null and nullif(trim(coalesce(p_note.title, '')), '') is not null then
    v_out := v_out || trim(p_note.title);
  end if;
  if p_note.blocks is null then
    -- An older entry: its words, a checklist's points.
    if p_lines is null then
      if p_note.kind = 'checklist' then
        if nullif(trim(coalesce(p_note.body, '')), '') is not null then
          v_out := v_out || trim(p_note.body);
        end if;
        for v_point in select * from jsonb_array_elements(coalesce(p_note.points, '[]')) loop
          v_out := v_out || (case when coalesce((v_point ->> 'done')::boolean, false)
                                  then '[x] ' else '[ ] ' end || (v_point ->> 'text'));
        end loop;
      elsif p_note.kind = 'todo' then
        v_out := v_out || (case when p_note.done_at is null then '[ ] ' else '[x] ' end
                           || coalesce(p_note.body, ''));
      elsif nullif(trim(coalesce(p_note.body, '')), '') is not null then
        v_out := v_out || trim(p_note.body);
      end if;
    end if;
  else
    for v_block in select * from jsonb_array_elements(p_note.blocks) loop
      if p_lines is not null and not ((v_block ->> 'id') = any (p_lines)) then
        continue;
      end if;
      v_type := v_block ->> 'type';
      v_pad := repeat('  ', coalesce((v_block ->> 'indent')::integer, 0));
      if v_type = 'numbered' then
        v_count := v_count + 1;
      elsif coalesce((v_block ->> 'indent')::integer, 0) = 0 then
        v_count := 0;
      end if;
      case v_type
        when 'todo' then
          v_out := v_out || (v_pad || case when coalesce((v_block ->> 'done')::boolean, false)
                                           then '[x] ' else '[ ] ' end || (v_block ->> 'text'));
        when 'bullet' then
          v_out := v_out || (v_pad || '• ' || (v_block ->> 'text'));
        when 'numbered' then
          v_out := v_out || (v_pad || v_count || '. ' || (v_block ->> 'text'));
        when 'toggle' then
          v_out := v_out || (v_pad || (v_block ->> 'text'));
          for v_child in select * from jsonb_array_elements(coalesce(v_block -> 'children', '[]')) loop
            v_out := v_out || (v_pad || '  ' ||
              case when v_child ->> 'type' = 'todo' then
                     case when coalesce((v_child ->> 'done')::boolean, false) then '[x] ' else '[ ] ' end
                   else '' end || coalesce(v_child ->> 'text', ''));
          end loop;
        when 'table' then
          for v_row in select * from jsonb_array_elements(coalesce(v_block -> 'rows', '[]')) loop
            v_out := v_out || (v_pad || (select string_agg(c #>> '{}', ' · ')
                                         from jsonb_array_elements(v_row) c));
          end loop;
        when 'divider' then
          v_out := v_out || (v_pad || '—');
        when 'voice' then
          null;
        else
          if nullif(trim(coalesce(v_block ->> 'text', '')), '') is not null then
            v_out := v_out || (v_pad || (v_block ->> 'text'));
          end if;
      end case;
    end loop;
  end if;
  if p_include_location and (p_note.location_text is not null or p_note.location_lat is not null) then
    v_loc := '📍 ' || concat_ws(' · ', p_note.location_text,
      case when p_note.location_lat is not null
           then p_note.location_lat::text || ', ' || p_note.location_lng::text end);
    v_out := v_out || v_loc;
  end if;
  return array_to_string(v_out, E'\n');
end;
$$;

-- What Share sends from [p_note] of mine (the preview shows the same).
create or replace function public.note_share_text(
  p_note uuid, p_lines text[] default null, p_include_location boolean default false
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.notebook_writer();
  return public.note_words(public.my_live_note(p_note), p_lines, p_include_location);
end;
$$;

-- ---------------------------------------------------------------------------
-- Keep deleted items for
-- ---------------------------------------------------------------------------

create or replace function public.set_notebook_keep_days(p_days integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.notebook_writer();
  if p_days is null or p_days not in (7, 30, 90) then
    raise exception 'keep for 7, 30 or 90 days' using errcode = '22023';
  end if;
  update public.profile_private set notebook_keep_days = p_days where id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- Delete, Restore, Delete forever, Empty now
-- ---------------------------------------------------------------------------

-- Entries of mine to Deleted items; one already there is skipped (a delete
-- sent again).
create or replace function public.delete_entries(p_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.notebook_writer();
  if exists (select 1 from unnest(coalesce(p_ids, '{}')) i(id)
             where not exists (select 1 from public.notes n
                               where n.id = i.id and n.owner_id = auth.uid())) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.notes n
  set deleted_at = now(), page_title = public.notebook_page_title(n.page_id)
  where n.id = any (p_ids) and n.deleted_at is null;
end;
$$;

-- The lines [p_lines] of my entry [p_note] (a line with the lines under
-- it) to Deleted items, as an entry of its own, [p_part] ("Part of an
-- entry"); its levels start again at 0 and its voice blocks take their
-- recordings. The same [p_part] again returns it (sent again).
create or replace function public.delete_note_lines(p_note uuid, p_lines text[], p_part uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note public.notes;
  v_kept jsonb;
  v_gone jsonb;
  v_base integer;
begin
  perform public.notebook_writer();
  if p_part is null then
    raise exception 'a part needs its id' using errcode = '22023';
  end if;
  if exists (select 1 from public.notes n where n.id = p_part) then
    if exists (select 1 from public.notes n
               where n.id = p_part and n.owner_id = auth.uid() and n.part_of = p_note) then
      return p_part;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  v_note := public.my_live_note(p_note);
  if v_note.blocks is null or coalesce(cardinality(p_lines), 0) = 0
     or exists (select 1 from unnest(p_lines) l(id)
                where not exists (select 1 from jsonb_array_elements(v_note.blocks) b
                                  where b ->> 'id' = l.id)) then
    raise exception 'those lines aren''t in the entry' using errcode = '22023';
  end if;
  select coalesce(jsonb_agg(b order by o) filter (where not ((b ->> 'id') = any (p_lines))), '[]'),
         coalesce(jsonb_agg(b order by o) filter (where (b ->> 'id') = any (p_lines)), '[]')
  into v_kept, v_gone
  from jsonb_array_elements(v_note.blocks) with ordinality x(b, o);
  v_base := coalesce((v_gone -> 0 ->> 'indent')::integer, 0);
  select jsonb_agg(
           case when coalesce((b ->> 'indent')::integer, 0) - v_base > 0
                then b || jsonb_build_object('indent', (b ->> 'indent')::integer - v_base)
                else b - 'indent' end order by o)
  into v_gone
  from jsonb_array_elements(v_gone) with ordinality x(b, o);
  if not public.is_valid_note_blocks(v_kept) or not public.is_valid_note_blocks(v_gone) then
    raise exception 'take a line with the lines under it' using errcode = '22023';
  end if;
  insert into public.notes (id, owner_id, kind, body, title, blocks, page_id, created_at,
                            deleted_at, part_of, page_title)
  values (p_part, v_note.owner_id, 'text',
          left(public.blocks_plain_text(v_gone), 5000), null, v_gone, v_note.page_id,
          v_note.created_at, now(), p_note, public.notebook_page_title(v_note.page_id));
  -- Its recordings go with its voice blocks.
  update public.note_files f set note_id = p_part
  where f.note_id = p_note and f.kind = 'voice'
    and f.storage_path in (select v from unnest(public.note_block_voices(v_gone)) v);
  update public.notes n
  set blocks = v_kept,
      body = left(concat_ws(E'\n', nullif(trim(coalesce(n.title, '')), ''),
                            nullif(public.blocks_plain_text(v_kept), '')), 5000),
      version = n.version + 1,
      updated_at = now()
  where n.id = p_note;
  return p_part;
end;
$$;

-- Deleted items, as the screen lists them: each entry, part of an entry and
-- page deleted on its own (a page's sub-pages and entries go with it), its
-- page, when it was deleted and when it goes for good.
create or replace function public.my_deleted_items()
returns table (kind text, id uuid, title text, page_id uuid, page_title text,
               deleted_at timestamptz, purge_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  with keep as (
    select make_interval(days => pp.notebook_keep_days) as days
    from public.profile_private pp where pp.id = auth.uid()
  )
  select case when n.part_of is null then 'entry' else 'part' end, n.id,
         coalesce(nullif(trim(coalesce(n.title, '')), ''), split_part(coalesce(n.body, ''), E'\n', 1)),
         n.page_id,
         coalesce(case when p.deleted_at is null then p.title end, n.page_title, p.title, ''),
         n.deleted_at, n.deleted_at + (select days from keep)
  from public.notes n
  left join public.notebook_pages p on p.id = n.page_id
  where n.owner_id = auth.uid() and n.deleted_at is not null
  union all
  select 'page', p.id, p.title, p.parent_id,
         coalesce((select up.title from public.notebook_pages up where up.id = p.parent_id), ''),
         p.deleted_at, p.deleted_at + (select days from keep)
  from public.notebook_pages p
  where p.owner_id = auth.uid() and p.deleted_at is not null
    -- Not a sub-page deleted with its page.
    and not exists (select 1 from public.notebook_pages up
                    where up.id = p.parent_id and up.deleted_at = p.deleted_at)
  order by 6 desc, 2;
$$;

-- Restore: an entry (or part of one) back in its page, or in a new page
-- with the old title when that page is gone; a page with what was deleted
-- with it, at the top when its parent is gone. Not deleted: skipped.
create or replace function public.restore_items(p_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_note public.notes;
  v_page public.notebook_pages;
  v_new uuid;
begin
  perform public.notebook_writer();
  foreach v_id in array coalesce(p_ids, '{}') loop
    select * into v_note from public.notes n where n.id = v_id for update;
    if v_note.id is not null then
      if v_note.owner_id <> auth.uid() then
        raise exception 'not allowed' using errcode = '42501';
      end if;
      if v_note.deleted_at is null then
        continue;
      end if;
      if v_note.page_id is not null and public.notebook_page_in_force(v_note.page_id) then
        update public.notes n set deleted_at = null, page_title = null where n.id = v_id;
      else
        v_new := gen_random_uuid();
        insert into public.notebook_pages (id, owner_id, title)
        values (v_new, v_note.owner_id,
                coalesce(v_note.page_title, public.notebook_page_title(v_note.page_id), ''));
        update public.notes n set page_id = v_new, deleted_at = null, page_title = null
        where n.id = v_id;
      end if;
      continue;
    end if;
    select * into v_page from public.notebook_pages p where p.id = v_id for update;
    if v_page.id is null or v_page.owner_id <> auth.uid() then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if v_page.deleted_at is null then
      continue;
    end if;
    -- A second "My notes" in force can't be: this one comes back unnamed.
    if v_page.named = 'my_notes' and exists (
         select 1 from public.notebook_pages p
         where p.owner_id = v_page.owner_id and p.named = 'my_notes' and p.deleted_at is null) then
      update public.notebook_pages p set named = null where p.id = v_id;
    end if;
    update public.notebook_pages p set deleted_at = null
    where p.deleted_at = v_page.deleted_at
      and p.id in (select t from public.notebook_page_tree(v_id) t);
    if v_page.parent_id is not null and not public.notebook_page_in_force(v_page.parent_id) then
      update public.notebook_pages p set parent_id = null where p.id = v_id;
    end if;
  end loop;
end;
$$;

-- For good, [p_ids] of [p_owner]'s Deleted items (entries, parts, pages
-- with everything inside); the files they held, for Storage. Internal.
create or replace function public.notebook_remove(p_owner uuid, p_ids uuid[])
returns table (path text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_notes uuid[];
  v_pages uuid[];
begin
  v_pages := array(
    select t from public.notebook_pages p, public.notebook_page_tree(p.id) t
    where p.id = any (p_ids) and p.owner_id = p_owner and p.deleted_at is not null);
  -- The entries that go: those asked for, and those inside the pages that
  -- weren't deleted on their own (those keep their own time).
  v_notes := array(
    select n.id from public.notes n
    where n.owner_id = p_owner
      and ((n.id = any (p_ids) and n.deleted_at is not null)
           or (n.page_id = any (v_pages) and n.deleted_at is null)));
  return query
  select f.storage_path from public.note_files f where f.note_id = any (v_notes);
  insert into public.deleted_notes (id, owner_id, created_at)
  select n.id, n.owner_id, n.created_at from public.notes n where n.id = any (v_notes)
  on conflict do nothing;
  delete from public.notes n where n.id = any (v_notes);
  delete from public.notebook_pages p where p.id = any (v_pages);
end;
$$;

-- Delete forever, after one confirm (in the app): only what is in my
-- Deleted items. Returns the files to remove from Storage.
create or replace function public.delete_forever(p_ids uuid[])
returns table (path text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform public.notebook_writer();
  foreach v_id in array coalesce(p_ids, '{}') loop
    if exists (select 1 from public.notes n where n.id = v_id and n.owner_id <> auth.uid())
       or exists (select 1 from public.notebook_pages p
                  where p.id = v_id and p.owner_id <> auth.uid()) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if not exists (select 1 from public.notes n where n.id = v_id and n.deleted_at is not null)
       and not exists (select 1 from public.notebook_pages p
                       where p.id = v_id and p.deleted_at is not null) then
      raise exception 'only what is in Deleted items' using errcode = '22023';
    end if;
  end loop;
  return query select r.path from public.notebook_remove(auth.uid(), p_ids) r;
end;
$$;

-- Empty now: everything in my Deleted items, for good.
create or replace function public.empty_deleted_items()
returns table (path text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.notebook_writer();
  return query select r.path from public.notebook_remove(auth.uid(), array(
    select d.id from public.my_deleted_items() d)) r;
end;
$$;

-- The daily purge (the service role's: pg_cron via the notebook-purge job,
-- supabase/ops/notebook_purge_cron.sql): what has been in Deleted items
-- longer than its owner keeps them goes for good. Its files are then
-- orphans, which orphan_note_files gives the job to delete from Storage.
-- Returns how many entries and pages went.
create or replace function public.purge_notebook()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner record;
  v_count integer := 0;
  v_ids uuid[];
begin
  for v_owner in
    select pp.id, make_interval(days => pp.notebook_keep_days) as keep
    from public.profile_private pp
    where exists (select 1 from public.notes n
                  where n.owner_id = pp.id and n.deleted_at is not null)
       or exists (select 1 from public.notebook_pages p
                  where p.owner_id = pp.id and p.deleted_at is not null)
  loop
    v_ids := array(
      select n.id from public.notes n
      where n.owner_id = v_owner.id and n.deleted_at < now() - v_owner.keep
      union all
      select p.id from public.notebook_pages p
      where p.owner_id = v_owner.id and p.deleted_at < now() - v_owner.keep
        and not exists (select 1 from public.notebook_pages up
                        where up.id = p.parent_id and up.deleted_at = p.deleted_at));
    if cardinality(v_ids) > 0 then
      perform public.notebook_remove(v_owner.id, v_ids);
      v_count := v_count + cardinality(v_ids);
    end if;
  end loop;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Archive (100 Part 3b)
-- ---------------------------------------------------------------------------

create or replace function public.archive_note(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.notebook_writer();
  perform public.my_live_note(p_id);
  update public.notes n set archived_at = coalesce(n.archived_at, now()) where n.id = p_id;
end;
$$;

create or replace function public.unarchive_note(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.notebook_writer();
  perform public.my_live_note(p_id);
  update public.notes n set archived_at = null where n.id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Share (100 Part 6)
-- ---------------------------------------------------------------------------

-- To a Space [p_space] as [p_kind]: 'note' (a post), 'checklist' (its
-- to-dos are the points; for [p_people]) or 'work_item' (for [p_owner]),
-- in [p_team];
-- [p_files] are the copies the app put in the Space's bucket. The Space's
-- rules and passes are create_space_post's and create_work_item's. The
-- location goes only with [p_include_location]: a work item's place, and
-- on a post or a checklist its last line ("📍 Gate 2 · …"), as a post
-- takes no place.
create or replace function public.share_note_to_space(
  p_note uuid, p_post uuid, p_space uuid, p_kind text,
  p_lines text[] default null, p_team uuid default null, p_owner uuid default null,
  p_include_location boolean default false, p_files jsonb default '[]'::jsonb,
  p_people uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note public.notes;
  v_title text;
  v_body text;
  v_place text;
  v_points jsonb := '[]';
  v_block jsonb;
  v_id uuid;
  v_loc text;
begin
  perform public.notebook_writer();
  v_note := public.my_live_note(p_note);
  if p_kind is null or p_kind not in ('note', 'checklist', 'work_item') then
    raise exception 'a post, a work item or a checklist' using errcode = '22023';
  end if;
  v_title := nullif(trim(coalesce(case when p_lines is null then v_note.title end, '')), '');
  v_body := public.note_words(v_note, p_lines, false);
  if v_title is not null then
    v_body := nullif(substr(v_body, char_length(v_title) + 2), '');
  else
    v_title := split_part(v_body, E'\n', 1);
    v_body := nullif(substr(v_body, char_length(v_title) + 2), '');
  end if;
  v_title := left(regexp_replace(v_title, '^(\[ \]|\[x\]|•) ', ''), 200);
  if p_include_location and p_kind = 'work_item' then
    v_place := v_note.location_text;
  end if;
  if p_include_location and (v_note.location_text is not null or v_note.location_lat is not null) then
    v_loc := '📍 ' || concat_ws(' · ', v_note.location_text,
      case when v_note.location_lat is not null
           then v_note.location_lat::text || ', ' || v_note.location_lng::text end);
  end if;
  if p_kind = 'checklist' then
    for v_block in
      select b from jsonb_array_elements(coalesce(v_note.blocks, '[]')) b
      where b ->> 'type' = 'todo' and (p_lines is null or (b ->> 'id') = any (p_lines))
    loop
      v_points := v_points || jsonb_build_object('text', v_block ->> 'text');
    end loop;
    if jsonb_array_length(v_points) = 0 then
      raise exception 'a checklist needs a to-do' using errcode = '22023';
    end if;
    v_id := public.create_space_post(p_post, p_space, 'checklist', v_title, v_loc, p_team,
                                     p_people => p_people, p_points => v_points,
                                     p_files => p_files);
  elsif p_kind = 'work_item' then
    v_id := public.create_work_item(p_space, v_title, p_owner, p_team => p_team, p_place => v_place,
                                    p_id => p_post, p_body => concat_ws(E'
', v_body, v_loc),
                                    p_files => p_files);
  else
    v_id := public.create_space_post(p_post, p_space, 'note', v_title,
                                     nullif(concat_ws(E'
', v_body, v_loc), ''), p_team,
                                     p_files => p_files);
  end if;
  insert into public.note_shares (note_id, owner_id, target, space_post_id, target_name)
  select p_note, v_note.owner_id, 'space', v_id, s.name from public.spaces s where s.id = p_space;
  update public.notes n set put_in_post_id = v_id where n.id = p_note;
  return v_id;
end;
$$;

-- To the feed: a public post on Home in [p_lang], with an optional project
-- tag and [p_media] (the copies the app put in post-media); create_post's
-- rules apply.
create or replace function public.share_note_to_feed(
  p_note uuid, p_post uuid, p_lang text,
  p_lines text[] default null, p_project uuid default null,
  p_include_location boolean default false, p_media jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note public.notes;
  v_id uuid;
begin
  perform public.notebook_writer();
  v_note := public.my_live_note(p_note);
  v_id := public.create_post(p_post, left(public.note_words(v_note, p_lines, p_include_location), 3000),
                             p_lang, p_project, p_media);
  insert into public.note_shares (note_id, owner_id, target, feed_post_id)
  values (p_note, v_note.owner_id, 'feed', v_id);
  return v_id;
end;
$$;

-- To [p_person] by message: start_dm (the thread is [p_thread] when it's
-- new), with its rules: block, the hidden account, the request and the spam
-- guard. A copy of the words; [p_attachments] are the copies the app put in
-- dm-files. Returns start_dm's answer.
create or replace function public.share_note_to_person(
  p_note uuid, p_message uuid, p_person uuid, p_thread uuid,
  p_lines text[] default null, p_include_location boolean default false,
  p_attachments jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note public.notes;
  v_sent jsonb;
begin
  perform public.notebook_writer();
  v_note := public.my_live_note(p_note);
  v_sent := public.start_dm(p_thread, p_person, p_message,
                            -- J1: a message holds 3,000, as dm_post does.
                            left(public.note_words(v_note, p_lines, p_include_location), 3000),
                            p_attachments);
  if v_sent ->> 'thread' is not null then
    insert into public.note_shares (note_id, owner_id, target, dm_thread_id, target_name)
    select p_note, v_note.owner_id, 'message', (v_sent ->> 'thread')::uuid,
           trim(concat_ws(' ', p.first_name, p.last_name))
    from public.profiles p where p.id = p_person;
  end if;
  return v_sent;
end;
$$;

-- ---------------------------------------------------------------------------
-- Writing: the version an edit started from
-- ---------------------------------------------------------------------------

drop function public.save_entry(uuid, text, uuid, text, text, jsonb, timestamptz, timestamptz,
                                boolean, jsonb, text, jsonb, jsonb, timestamptz);
drop function public.save_note(uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb,
                               text, jsonb, jsonb, timestamptz);

-- As in migration 44, with [p_base_version] (review 100 D1): the version
-- the edit started from; an older one is refused ("changed on another
-- phone", 40001); none (an older build) saves as before. An entry in
-- Deleted items returns null, as a deleted one does.
create function public.save_note(
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
  p_created_at timestamptz default null,
  p_base_version integer default null
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
  -- Review 99B: an entry in Deleted items stays there until Restore.
  if v_note.id is not null and v_note.deleted_at is not null then
    return null;
  end if;
  -- Review 100 D1: an edit started from an older version is refused.
  if v_note.id is not null and p_base_version is not null and v_note.version <> p_base_version then
    raise exception 'changed on another phone' using errcode = '40001';
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
        version = version + 1,
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


-- As in migration 47, with [p_base_version] passed to save_note.
create function public.save_entry(
  p_id uuid,
  p_kind text,
  p_page uuid default null,
  p_new_page_title text default null,
  p_body text default null,
  p_points jsonb default null,
  p_due_at timestamptz default null,
  p_remind_at timestamptz default null,
  p_pinned boolean default null,
  p_files jsonb default null,
  p_title text default null,
  p_blocks jsonb default null,
  p_location jsonb default null,
  p_created_at timestamptz default null,
  p_base_version integer default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_saved uuid;
  v_made boolean := false;
begin
  perform public.notebook_writer();
  if p_page is not null then
    if p_new_page_title is not null
       and not exists (select 1 from public.notebook_pages p where p.id = p_page) then
      perform public.new_notebook_page(p_page, left(trim(p_new_page_title), 120), null, null, true);
      v_made := true;
    end if;
    perform public.my_notebook_page(p_page);
  end if;
  -- A new entry goes in straight into its page (note_page_ok).
  perform set_config('bv.note_page', coalesce(p_page::text, ''), true);
  v_saved := public.save_note(p_id, p_kind, p_body, p_points, p_due_at, p_remind_at, p_pinned,
                              p_files, p_title, p_blocks, p_location, p_created_at,
                              p_base_version);
  perform set_config('bv.note_page', '', true);
  if v_saved is null then
    -- The entry was deleted: no page is made for it.
    if v_made then
      delete from public.notebook_pages p where p.id = p_page;
    end if;
    return null;
  end if;
  if p_page is not null then
    update public.notes n set page_id = p_page
    where n.id = v_saved and n.page_id is distinct from p_page;
  end if;
  return v_saved;
end;
$$;

-- ---------------------------------------------------------------------------
-- Search and the Filter (100 Part 8)
-- ---------------------------------------------------------------------------

-- As in migration 47, with [p_kind] and [p_page] (the Filter's Show and In):
-- todos_open (an unticked to-do line, inside a toggle too, or an open
-- to-do), photos, files, voice (an entry's files and voice blocks),
-- reminders (one still to ring) and archived (only there do archived
-- entries show); [p_page] with its sub-pages. With a kind, words are
-- optional. Nothing in Deleted items, or in a deleted page.
drop function public.search_notebook(text);
create function public.search_notebook(
  p_q text default '', p_kind text default null, p_page uuid default null
)
returns table (kind text, page_id uuid, note_id uuid, title text, snippet text,
               created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := public.search_fold(regexp_replace(trim(coalesce(p_q, '')), '\s+', ' ', 'g'));
  v_pat text;
  v_pages uuid[];
  v_most integer := 30;
begin
  if auth.uid() is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if char_length(v_q) > 100 then
    raise exception 'search too long' using errcode = '22023';
  end if;
  if p_kind is not null
     and p_kind not in ('todos_open', 'photos', 'files', 'voice', 'reminders', 'archived') then
    raise exception 'show to-dos open, photos, files, voice notes, reminders or archived'
      using errcode = '22023';
  end if;
  if p_page is not null then
    if not exists (select 1 from public.notebook_pages p
                   where p.id = p_page and p.owner_id = auth.uid()) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    v_pages := array(select t from public.notebook_page_tree(p_page) t);
  end if;
  if v_q = '' and p_kind is null then
    return;
  end if;
  -- One digit is enough ("3"); otherwise two characters, as in Space search.
  if v_q <> '' and char_length(v_q) < 2 and v_q !~ '^[0-9]$' then
    return;
  end if;
  if p_kind is not null then
    v_most := 100;
  end if;
  v_pat := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return query
  (select 'page'::text, p.id, null::uuid, p.title, null::text, p.last_activity_at
   from public.notebook_pages p
   where p_kind is null and v_q <> ''
     and p.owner_id = auth.uid() and p.deleted_at is null
     and (v_pages is null or p.id = any (v_pages))
     and public.search_fold(p.title) like v_pat
     and public.notebook_page_in_force(p.id)
   order by p.last_activity_at desc, p.id desc
   limit 30)
  union all
  (select 'entry', n.page_id, n.id, coalesce(n.title, ''),
          case when v_q = '' then null else public.search_snippet(
            concat_ws(' ', n.body, public.blocks_plain_text(n.blocks),
                      (select string_agg(x ->> 'text', ' ')
                       from jsonb_array_elements(coalesce(n.points, '[]')) x)), v_q) end,
          n.created_at
   from public.notes n
   where n.owner_id = auth.uid() and n.deleted_at is null
     and (n.archived_at is not null) = (p_kind is not distinct from 'archived')
     and (v_pages is null or n.page_id = any (v_pages))
     and (v_q = '' or public.search_fold(concat_ws(' ', n.title, n.body,
                                                   public.blocks_plain_text(n.blocks),
                                                   (select string_agg(x ->> 'text', ' ')
                                                    from jsonb_array_elements(coalesce(n.points, '[]')) x)))
                      like v_pat)
     and (p_kind is null or p_kind = 'archived'
          or (p_kind = 'todos_open'
              and ((n.kind = 'todo' and n.done_at is null)
                   or exists (select 1 from jsonb_path_query(coalesce(n.blocks, '[]'), 'strict $.**') b
                              where jsonb_typeof(b) = 'object' and b ->> 'type' = 'todo'
                                and coalesce((b ->> 'done')::boolean, false) = false)
                   or exists (select 1 from jsonb_array_elements(coalesce(n.points, '[]')) x
                              where coalesce((x ->> 'done')::boolean, false) = false)))
          or (p_kind = 'photos'
              and exists (select 1 from public.note_files f where f.note_id = n.id and f.kind = 'photo'))
          or (p_kind = 'files'
              and exists (select 1 from public.note_files f where f.note_id = n.id and f.kind = 'file'))
          or (p_kind = 'voice'
              and (n.kind = 'voice'
                   or exists (select 1 from public.note_files f
                              where f.note_id = n.id and f.kind = 'voice')))
          or (p_kind = 'reminders' and n.remind_at > now()))
     and public.notebook_page_in_force(n.page_id)
   order by n.created_at desc, n.id desc
   limit v_most);
end;
$$;

-- ---------------------------------------------------------------------------
-- My calendar: as in migration 47, without entries in Deleted items or
-- archived (one change: the last union's where).
-- ---------------------------------------------------------------------------

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
    and n.deleted_at is null and n.archived_at is null
    and public.notebook_page_in_force(n.page_id)
  order by 10 nulls last, 9 nulls last, 7;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Download my data (F1): pages, each entry's page, Deleted items, archived
-- entries, the keep-days choice and share records.
-- ---------------------------------------------------------------------------

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
    'notebook_pages', coalesce((select jsonb_agg(jsonb_build_object(
                                 'id', np.id, 'title', np.title, 'named', np.named,
                                 'icon', np.icon,
                                 'parent_id', np.parent_id, 'pinned', np.pinned,
                                 'deleted_at', np.deleted_at,
                                 'created_at', np.created_at))
                               from public.notebook_pages np where np.owner_id = r.profile_id), '[]'),
    'notes', coalesce((select jsonb_agg(jsonb_build_object(
                        'kind', n.kind, 'title', n.title, 'body', n.body, 'points', n.points,
                        'blocks', n.blocks, 'location_text', n.location_text,
                        'location_lat', n.location_lat, 'location_lng', n.location_lng,
                        'due_at', n.due_at, 'done_at', n.done_at, 'pinned', n.pinned,
                        'remind_at', n.remind_at,
                        'page_id', n.page_id,
                        'deleted_at', n.deleted_at,
                        'archived_at', n.archived_at,
                        'created_at', n.created_at,
                        'files', (select jsonb_agg(f.storage_path order by f.sort)
                                  from public.note_files f where f.note_id = n.id)))
                      from public.notes n where n.owner_id = r.profile_id), '[]'),
    'note_shares', coalesce((select jsonb_agg(jsonb_build_object(
                              'note_id', ns.note_id, 'target', ns.target,
                              'target_name', ns.target_name,
                              'space_post_id', ns.space_post_id,
                              'feed_post_id', ns.feed_post_id,
                              'dm_thread_id', ns.dm_thread_id,
                              'created_at', ns.created_at))
                            from public.note_shares ns where ns.owner_id = r.profile_id), '[]'),
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
  public.my_live_note(uuid),
  public.notebook_page_title(uuid),
  public.note_words(public.notes, text[], boolean),
  public.notebook_remove(uuid, uuid[]),
  public.purge_notebook()
  from public, anon, authenticated;
grant execute on function public.purge_notebook() to service_role;
revoke execute on function
  public.note_share_text(uuid, text[], boolean),
  public.set_notebook_keep_days(integer),
  public.delete_entries(uuid[]),
  public.delete_note_lines(uuid, text[], uuid),
  public.my_deleted_items(),
  public.restore_items(uuid[]),
  public.delete_forever(uuid[]),
  public.empty_deleted_items(),
  public.archive_note(uuid),
  public.unarchive_note(uuid),
  public.share_note_to_space(uuid, uuid, uuid, text, text[], uuid, uuid, boolean, jsonb, uuid[]),
  public.share_note_to_feed(uuid, uuid, text, text[], uuid, boolean, jsonb),
  public.share_note_to_person(uuid, uuid, uuid, uuid, text[], boolean, jsonb),
  public.save_note(uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb, text, jsonb,
                   jsonb, timestamptz, integer),
  public.save_entry(uuid, text, uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb,
                    text, jsonb, jsonb, timestamptz, integer),
  public.search_notebook(text, text, uuid)
  from public, anon;
grant execute on function
  public.note_share_text(uuid, text[], boolean),
  public.set_notebook_keep_days(integer),
  public.delete_entries(uuid[]),
  public.delete_note_lines(uuid, text[], uuid),
  public.my_deleted_items(),
  public.restore_items(uuid[]),
  public.delete_forever(uuid[]),
  public.empty_deleted_items(),
  public.archive_note(uuid),
  public.unarchive_note(uuid),
  public.share_note_to_space(uuid, uuid, uuid, text, text[], uuid, uuid, boolean, jsonb, uuid[]),
  public.share_note_to_feed(uuid, uuid, text, text[], uuid, boolean, jsonb),
  public.share_note_to_person(uuid, uuid, uuid, uuid, text[], boolean, jsonb),
  public.save_note(uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb, text, jsonb,
                   jsonb, timestamptz, integer),
  public.save_entry(uuid, text, uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb,
                    text, jsonb, jsonb, timestamptz, integer),
  public.search_notebook(text, text, uuid)
  to authenticated;
