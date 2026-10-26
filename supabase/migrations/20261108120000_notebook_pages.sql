-- Migration 47 (review 99A): the notebook becomes pages.
--
-- - notebook_pages: a person's own pages, as deep as they like (parent_id),
--   each with a title, one icon of a fixed twelve, a pin, a "new" mark,
--   when it was made, its latest activity and, once deleted or emptied by
--   a merge, when (deleted_at: Deleted items, review 99B). Only the owner
--   reads them; every change goes through the functions below.
-- - Every entry (a `notes` row) is in one page of its owner's: notes.page_id,
--   never empty. Old builds don't send a page: a new entry from one goes
--   into the owner's latest page, or a new "My notes".
-- - Backfill: each person's notes go into one page, "My notes" (named
--   'my_notes', the app says it in the person's language), in their date
--   order. Drafts are on the phone and stay there.
-- - save_entry: save_note with the page: an existing page of mine, or a
--   new one made with the entry, titled from its first line and marked new.
-- - create_notebook_page, update_notebook_page (a rename takes the "new"
--   mark off), open_notebook_page, pin_notebook_pages, move_notebook_pages
--   (Move into…), move_notes (Move to page…), merge_notebook_pages and
--   delete_notebook_pages: each all or nothing, on my own pages only.
-- - search_notebook: page titles, entry titles and the words of every
--   line, with Arabic letter forms and digits folded as in Space search.
-- - My calendar leaves out the entries of a deleted page.

-- ---------------------------------------------------------------------------
-- Pages
-- ---------------------------------------------------------------------------

create table public.notebook_pages (
  -- Chosen by the app, so a page made with no signal is the same page.
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  parent_id uuid references public.notebook_pages (id) on delete cascade,
  -- Empty: the app names it ("My notes" for named 'my_notes', else
  -- "Untitled").
  title text not null default '' check (char_length(title) <= 120),
  named text check (named in ('my_notes')),
  icon text not null default 'notebook'
    check (icon in ('folder', 'hard_hat', 'building', 'phone', 'list', 'calendar', 'camera',
                    'warning', 'star', 'wrench', 'ruler', 'notebook')),
  pinned boolean not null default false,
  is_new boolean not null default false,
  created_at timestamptz not null default now(),
  last_activity_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (parent_id is distinct from id)
);
create index notebook_pages_owner_idx on public.notebook_pages (owner_id, last_activity_at desc);
create index notebook_pages_parent_idx on public.notebook_pages (parent_id);

-- A page's parent is the same person's, and never the page itself or one
-- of its own sub-pages.
create or replace function public.notebook_page_parent_ok()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.parent_id is null then
    return new;
  end if;
  if not exists (select 1 from public.notebook_pages p
                 where p.id = new.parent_id and p.owner_id = new.owner_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if exists (
    with recursive up as (
      select p.id, p.parent_id from public.notebook_pages p where p.id = new.parent_id
      union
      select p.id, p.parent_id from public.notebook_pages p join up on p.id = up.parent_id
    )
    select 1 from up where up.id = new.id
  ) then
    raise exception 'a page can''t go inside itself' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger notebook_pages_parent_ok
  before insert or update of parent_id, owner_id on public.notebook_pages
  for each row execute function public.notebook_page_parent_ok();

-- A hidden (deleting) account writes nothing new (migration 16).
create trigger notebook_pages_hidden_writer before insert on public.notebook_pages
  for each row execute function public.refuse_hidden_writer();

alter table public.notebook_pages enable row level security;
create policy notebook_pages_read_own on public.notebook_pages
  for select to authenticated using (owner_id = auth.uid());

revoke all on public.notebook_pages from anon, authenticated;
grant select on public.notebook_pages to authenticated;
grant all on public.notebook_pages to service_role;

-- ---------------------------------------------------------------------------
-- Entries in pages
-- ---------------------------------------------------------------------------

alter table public.notes
  add column page_id uuid references public.notebook_pages (id) on delete cascade;
create index notes_page_idx on public.notes (page_id, created_at desc);

-- Every note of a person's with no page goes into one page of theirs,
-- "My notes", made for it, in date order (A6). Run once below; kept for the
-- test, and for nobody else.
create or replace function public.notes_into_my_notes()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_moved integer;
begin
  insert into public.notebook_pages (owner_id, named, icon, created_at, last_activity_at)
  select n.owner_id, 'my_notes', 'notebook', min(n.created_at), max(n.created_at)
  from public.notes n
  where n.page_id is null
    and not exists (select 1 from public.notebook_pages p
                    where p.owner_id = n.owner_id and p.named = 'my_notes'
                      and p.deleted_at is null)
  group by n.owner_id;
  update public.notes n
  set page_id = p.id
  from public.notebook_pages p
  where n.page_id is null and p.owner_id = n.owner_id and p.named = 'my_notes'
    and p.deleted_at is null;
  get diagnostics v_moved = row_count;
  return v_moved;
end;
$$;

select public.notes_into_my_notes();

alter table public.notes alter column page_id set not null;

-- A note from a build that sends no page goes into the owner's latest page,
-- or a new "My notes"; a note's page is always the owner's own.
create or replace function public.note_page_ok()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.page_id is null then
    select p.id into new.page_id from public.notebook_pages p
    where p.owner_id = new.owner_id and p.deleted_at is null
    order by p.last_activity_at desc, p.id desc
    limit 1;
    if new.page_id is null then
      insert into public.notebook_pages (owner_id, named, icon)
      values (new.owner_id, 'my_notes', 'notebook')
      returning id into new.page_id;
    end if;
  end if;
  if not exists (select 1 from public.notebook_pages p
                 where p.id = new.page_id and p.owner_id = new.owner_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger notes_page_ok
  before insert or update of page_id, owner_id on public.notes
  for each row execute function public.note_page_ok();

-- A page's latest activity: an entry written, changed or moved into it.
create or replace function public.note_page_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.notebook_pages p
  set last_activity_at = greatest(p.last_activity_at, now())
  where p.id = new.page_id;
  return null;
end;
$$;

create trigger notes_page_activity
  after insert or update on public.notes
  for each row execute function public.note_page_activity();

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- The caller, signed in and not leaving.
create or replace function public.notebook_writer()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or public.is_hidden_account(auth.uid()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return auth.uid();
end;
$$;

-- [p_id], one of my pages that isn't deleted, locked; or refused.
create or replace function public.my_notebook_page(p_id uuid)
returns public.notebook_pages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_page public.notebook_pages;
begin
  select * into v_page from public.notebook_pages p
  where p.id = p_id and p.owner_id = auth.uid() and p.deleted_at is null
  for update;
  if v_page.id is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return v_page;
end;
$$;

-- [p_id] and every page under it, as deep as they go.
create or replace function public.notebook_page_tree(p_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  with recursive down as (
    select p.id from public.notebook_pages p where p.id = p_id
    union
    select p.id from public.notebook_pages p join down on p.parent_id = down.id
  )
  select id from down;
$$;

-- A new page of mine, [p_id], unless it is already there. At most 2000.
create or replace function public.new_notebook_page(
  p_id uuid, p_title text, p_parent uuid, p_icon text, p_is_new boolean
)
returns public.notebook_pages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.notebook_writer();
  v_page public.notebook_pages;
  v_title text := coalesce(trim(regexp_replace(p_title, '\s+', ' ', 'g')), '');
begin
  if p_id is null then
    raise exception 'a page needs its id' using errcode = '22023';
  end if;
  select * into v_page from public.notebook_pages p where p.id = p_id;
  if v_page.id is not null then
    if v_page.owner_id <> v_me then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    return v_page;
  end if;
  if char_length(v_title) > 120 then
    raise exception 'a title of up to 120 characters' using errcode = '22023';
  end if;
  if p_parent is not null then
    perform public.my_notebook_page(p_parent);
  end if;
  perform pg_advisory_xact_lock(hashtextextended('notebook_page:' || v_me::text, 0));
  if (select count(*) from public.notebook_pages p where p.owner_id = v_me) >= 2000 then
    raise exception 'that''s 2000 pages' using errcode = '54000';
  end if;
  insert into public.notebook_pages (id, owner_id, parent_id, title, icon, is_new)
  values (p_id, v_me, p_parent, v_title, coalesce(p_icon, 'notebook'), coalesce(p_is_new, false))
  on conflict (id) do nothing
  returning * into v_page;
  if v_page.id is null then
    -- Made by a retry running now.
    select * into v_page from public.notebook_pages p where p.id = p_id and p.owner_id = v_me;
    if v_page.id is null then
      raise exception 'not allowed' using errcode = '42501';
    end if;
  end if;
  return v_page;
end;
$$;

-- ---------------------------------------------------------------------------
-- Writing
-- ---------------------------------------------------------------------------

-- An entry saved into a page (A2): save_note as it is, then its page.
-- - [p_page] null: a new entry goes into my latest page (as from an old
--   build); an edit stays where it is.
-- - [p_page] one of mine: it goes there (an edit too).
-- - [p_page] not there yet and [p_new_page_title] given: the page is made
--   with the entry, titled from it, marked new; a retry is the same page.
-- Null, as save_note, when the entry was deleted.
create or replace function public.save_entry(
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
  p_created_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_saved uuid;
begin
  perform public.notebook_writer();
  if p_page is not null then
    if p_new_page_title is not null
       and not exists (select 1 from public.notebook_pages p where p.id = p_page) then
      perform public.new_notebook_page(p_page, left(trim(p_new_page_title), 120), null, null, true);
    end if;
    perform public.my_notebook_page(p_page);
  end if;
  v_saved := public.save_note(p_id, p_kind, p_body, p_points, p_due_at, p_remind_at, p_pinned,
                              p_files, p_title, p_blocks, p_location, p_created_at);
  if v_saved is not null and p_page is not null then
    update public.notes n set page_id = p_page
    where n.id = v_saved and n.page_id is distinct from p_page;
  end if;
  return v_saved;
end;
$$;

-- "+ New page" (A1), or a sub-page.
create or replace function public.create_notebook_page(
  p_id uuid, p_title text default '', p_parent uuid default null, p_icon text default 'notebook'
)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select (public.new_notebook_page(p_id, p_title, p_parent, p_icon, false)).id;
$$;

-- The title and icon, edited in place (A3). A page named, renamed or given
-- an icon is no longer new.
create or replace function public.update_notebook_page(p_id uuid, p_title text, p_icon text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text := coalesce(trim(regexp_replace(p_title, '\s+', ' ', 'g')), '');
begin
  perform public.notebook_writer();
  perform public.my_notebook_page(p_id);
  if char_length(v_title) > 120 then
    raise exception 'a title of up to 120 characters' using errcode = '22023';
  end if;
  update public.notebook_pages p
  set title = v_title, icon = coalesce(p_icon, p.icon), is_new = false
  where p.id = p_id;
end;
$$;

-- The page opened: no longer new.
create or replace function public.open_notebook_page(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.notebook_writer();
  update public.notebook_pages p set is_new = false
  where p.id = p_id and p.owner_id = auth.uid() and p.is_new;
end;
$$;

-- Pin or unpin pages, all of them mine.
create or replace function public.pin_notebook_pages(p_ids uuid[], p_on boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform public.notebook_writer();
  foreach v_id in array coalesce(p_ids, '{}') loop
    perform public.my_notebook_page(v_id);
  end loop;
  update public.notebook_pages p set pinned = coalesce(p_on, false)
  where p.id = any (p_ids);
end;
$$;

-- Move into… (A4): pages into [p_parent] (null: the top of My notebook).
-- Never a page into itself or under itself.
create or replace function public.move_notebook_pages(p_ids uuid[], p_parent uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform public.notebook_writer();
  if p_parent is not null then
    perform public.my_notebook_page(p_parent);
  end if;
  foreach v_id in array coalesce(p_ids, '{}') loop
    perform public.my_notebook_page(v_id);
    update public.notebook_pages p set parent_id = p_parent where p.id = v_id;
  end loop;
end;
$$;

-- Move to page… (A4): entries of mine into one of my pages.
create or replace function public.move_notes(p_ids uuid[], p_page uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.notebook_writer();
  perform public.my_notebook_page(p_page);
  if exists (select 1 from unnest(coalesce(p_ids, '{}')) i(id)
             where not exists (select 1 from public.notes n
                               where n.id = i.id and n.owner_id = auth.uid())) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.notes n set page_id = p_page
  where n.id = any (p_ids) and n.page_id is distinct from p_page;
end;
$$;

-- Merge (A4, PG5b): every entry of [p_pages], and the entries [p_notes],
-- into [p_into]: one of mine, or (not there yet, [p_new_title] given) a new
-- page. Their sub-pages go under it too. Each emptied page is deleted (to
-- Deleted items, review 99B). All or nothing.
create or replace function public.merge_notebook_pages(
  p_pages uuid[], p_notes uuid[], p_into uuid, p_new_title text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.notebook_writer();
  v_id uuid;
  v_into public.notebook_pages;
  v_gone uuid[];
  v_up uuid;
begin
  if p_into is null then
    raise exception 'choose the page that stays' using errcode = '22023';
  end if;
  foreach v_id in array coalesce(p_pages, '{}') loop
    perform public.my_notebook_page(v_id);
  end loop;
  if exists (select 1 from unnest(coalesce(p_notes, '{}')) i(id)
             where not exists (select 1 from public.notes n
                               where n.id = i.id and n.owner_id = v_me)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_new_title is not null and not exists (select 1 from public.notebook_pages p where p.id = p_into) then
    perform public.new_notebook_page(p_into, left(trim(p_new_title), 120), null, null, false);
  end if;
  v_into := public.my_notebook_page(p_into);
  v_gone := array(select x from unnest(coalesce(p_pages, '{}')) x where x <> p_into);

  -- The page that stays climbs out of any page that goes.
  v_up := v_into.parent_id;
  while v_up = any (v_gone) loop
    select p.parent_id into v_up from public.notebook_pages p where p.id = v_up;
  end loop;
  update public.notebook_pages p set parent_id = v_up
  where p.id = p_into and p.parent_id is distinct from v_up;

  update public.notes n set page_id = p_into
  where (n.page_id = any (v_gone) or n.id = any (coalesce(p_notes, '{}')))
    and n.owner_id = v_me and n.page_id is distinct from p_into;
  update public.notebook_pages p set parent_id = p_into
  where p.parent_id = any (v_gone) and p.id <> p_into and not (p.id = any (v_gone));
  update public.notebook_pages p set deleted_at = now(), pinned = false
  where p.id = any (v_gone);
  update public.notebook_pages p set is_new = false, last_activity_at = now()
  where p.id = p_into;
  return p_into;
end;
$$;

-- Delete pages, with every page under them (A4's bar). Their entries go
-- with them, to Deleted items (review 99B).
create or replace function public.delete_notebook_pages(p_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform public.notebook_writer();
  foreach v_id in array coalesce(p_ids, '{}') loop
    perform public.my_notebook_page(v_id);
  end loop;
  update public.notebook_pages p set deleted_at = now(), pinned = false
  where p.deleted_at is null
    and p.id in (select t from unnest(p_ids) i(id), public.notebook_page_tree(i.id) t);
end;
$$;

-- A page in force: it and every page above it not deleted.
create or replace function public.notebook_page_in_force(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with recursive up as (
    select p.id, p.parent_id, p.deleted_at from public.notebook_pages p where p.id = p_id
    union
    select p.id, p.parent_id, p.deleted_at from public.notebook_pages p
    join up on p.id = up.parent_id
  )
  select exists (select 1 from up) and not exists (select 1 from up where deleted_at is not null);
$$;

-- ---------------------------------------------------------------------------
-- Search (A5)
-- ---------------------------------------------------------------------------

-- My pages and entries whose title or words hold [p_q] (2 to 100
-- characters, or one digit, as typed; Arabic letter forms and digits folded, as in
-- search_space). Pages first, then entries newest first; 30 of each at
-- most. Nothing in a deleted page.
create or replace function public.search_notebook(p_q text)
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
begin
  if auth.uid() is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if char_length(v_q) > 100 then
    raise exception 'search too long' using errcode = '22023';
  end if;
  -- One digit is enough ("3"); otherwise two characters, as in Space search.
  if char_length(v_q) < 2 and v_q !~ '^[0-9]$' then
    return;
  end if;
  v_pat := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return query
  (select 'page'::text, p.id, null::uuid, p.title, null::text, p.last_activity_at
   from public.notebook_pages p
   where p.owner_id = auth.uid() and p.deleted_at is null
     and public.search_fold(p.title) like v_pat
     and public.notebook_page_in_force(p.id)
   order by p.last_activity_at desc, p.id desc
   limit 30)
  union all
  (select 'entry', n.page_id, n.id, coalesce(n.title, ''),
          public.search_snippet(
            concat_ws(' ', n.body, public.blocks_plain_text(n.blocks),
                      (select string_agg(x ->> 'text', ' ')
                       from jsonb_array_elements(coalesce(n.points, '[]')) x)), v_q),
          n.created_at
   from public.notes n
   where n.owner_id = auth.uid()
     and public.search_fold(concat_ws(' ', n.title, n.body, public.blocks_plain_text(n.blocks),
                                      (select string_agg(x ->> 'text', ' ')
                                       from jsonb_array_elements(coalesce(n.points, '[]')) x)))
         like v_pat
     and public.notebook_page_in_force(n.page_id)
   order by n.created_at desc, n.id desc
   limit 30);
end;
$$;

-- ---------------------------------------------------------------------------
-- My calendar: as in migration 44, without a deleted page's entries (one
-- change: the last union's where).
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
    and public.notebook_page_in_force(n.page_id)
  order by 10 nulls last, 9 nulls last, 7;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.notebook_page_parent_ok(),
  public.notes_into_my_notes(),
  public.note_page_ok(),
  public.note_page_activity(),
  public.notebook_writer(),
  public.my_notebook_page(uuid),
  public.notebook_page_tree(uuid),
  public.new_notebook_page(uuid, text, uuid, text, boolean),
  public.notebook_page_in_force(uuid)
  from public, anon, authenticated;
revoke execute on function
  public.save_entry(uuid, text, uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb,
                    text, jsonb, jsonb, timestamptz),
  public.create_notebook_page(uuid, text, uuid, text),
  public.update_notebook_page(uuid, text, text),
  public.open_notebook_page(uuid),
  public.pin_notebook_pages(uuid[], boolean),
  public.move_notebook_pages(uuid[], uuid),
  public.move_notes(uuid[], uuid),
  public.merge_notebook_pages(uuid[], uuid[], uuid, text),
  public.delete_notebook_pages(uuid[]),
  public.search_notebook(text)
  from public, anon;
grant execute on function
  public.save_entry(uuid, text, uuid, text, text, jsonb, timestamptz, timestamptz, boolean, jsonb,
                    text, jsonb, jsonb, timestamptz),
  public.create_notebook_page(uuid, text, uuid, text),
  public.update_notebook_page(uuid, text, text),
  public.open_notebook_page(uuid),
  public.pin_notebook_pages(uuid[], boolean),
  public.move_notebook_pages(uuid[], uuid),
  public.move_notes(uuid[], uuid),
  public.merge_notebook_pages(uuid[], uuid[], uuid, text),
  public.delete_notebook_pages(uuid[]),
  public.search_notebook(text)
  to authenticated;
