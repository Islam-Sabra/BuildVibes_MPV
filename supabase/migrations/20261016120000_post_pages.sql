-- Migration 20: opening a post in place, walk mode, meeting notes,
-- templates, the daily and week reports, and search (review 33 A3 and its
-- clarifications; docs/product/daybook.md). Branch post-pages-db. Not live.
--
-- Goes live after migration 21 (review 38 N1): its copy of export_my_data
-- is 21's, plus this one's additions.
--
-- - space_posts.blocks and blocks_version: a post's page (text, heading,
--   toggle, table, photo, file, checklist_ref, child_item, and item_ref in
--   a report). validate_blocks checks shape, size and that every reference
--   belongs to the post; save_blocks saves a page by version (a stale one
--   is refused with 40001, and the app reloads).
-- - create_walk and create_from_message: a parent work item and one work
--   item per photo or line, in one call, all or nothing, idempotent by the
--   parent id. Each owner gets one push for the batch.
-- - post_templates (with one built-in, the Daily report), save_template,
--   delete_template, space_templates; create_space_post takes a template
--   and blocks, and posts reports.
-- - daily_report_fill, week_report and share_week_report (a chat message of
--   kind report).
-- - search_space: posts and their pages, checklist points, chat and
--   Library file names, as each person may read them, newest first.
--
-- Choices for the lead to confirm (review 39):
-- - The Daily report's headings follow the prototype (R2): On site, Done
--   today, Problems, not A3's Done today, Tomorrow, Notes. The built-in
--   stores keys; the app gives the words in each language.
-- - The parent of a walk or of meeting notes is a work item owned by the
--   person who posts it. While it has work items under it, it isn't in
--   their Needs you (it is a target, done when its items are checked).
-- - Photo and file blocks point at the post's own files (post_files), so
--   the 10-file limit holds for a page.
-- - A template keeps the Team of the post it came from, and only that Team
--   (and the admins) see it.
-- - Page saves tell a work item's owner at most once in 10 minutes.
-- - Search folds Arabic letter forms (أ/إ/آ to ا, ة to ه, ى to ي, Arabic
--   digits to 0-9) and ignores harakat; no stemming.

-- ---------------------------------------------------------------------------
-- Search: one folded text per row, indexed
-- ---------------------------------------------------------------------------

-- Lower case, NFKC, without tatweel, harakat or direction marks, Arabic
-- letter forms and digits folded. Stored columns use it, so a change here
-- needs "update t set col = col" on each table.
create or replace function public.search_fold(p text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select translate(
    regexp_replace(lower(normalize(coalesce(p, ''), nfkc)),
                   '[ـً-ٰٟۖ-ۭ​-‏]', '', 'g'),
    'أإآٱىیةؤئک٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
    'ااااييهءءك01234567890123456789');
$$;

-- The words of a page: every "text" at any depth and every table cell.
create or replace function public.blocks_plain_text(p jsonb)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select coalesce(string_agg(v #>> '{}', ' '), '')
  from (select jsonb_path_query(coalesce(p, '[]'::jsonb), 'strict $.**.text') v
        union all
        select jsonb_path_query(coalesce(p, '[]'::jsonb), 'strict $.**.rows[*][*]')) x
  where jsonb_typeof(v) = 'string';
$$;

-- About 160 characters of [p_text] around the first match of [p_q].
create or replace function public.search_snippet(p_text text, p_q text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case when p_text is null then null
              else substring(p_text from greatest(1, strpos(public.search_fold(p_text), p_q) - 40)
                             for 160) end;
$$;

-- ---------------------------------------------------------------------------
-- Pages, templates and report messages
-- ---------------------------------------------------------------------------

create table public.post_templates (
  id uuid primary key,
  -- Null: a built-in, the same for every Space.
  space_id uuid references public.spaces (id) on delete cascade,
  -- The Team of the post it came from; only that Team and the admins see it.
  team_id uuid references public.teams (id) on delete cascade,
  kind text not null check (kind in ('work_item', 'checklist', 'announcement', 'report')),
  -- A built-in's key; the app gives its name in each language.
  builtin_key text unique,
  name text check (name is null or length(trim(name)) between 1 and 60),
  blocks jsonb not null default '[]'::jsonb,
  -- {title, body, points: [text]}
  fields jsonb not null default '{}'::jsonb check (jsonb_typeof(fields) = 'object'),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((space_id is null) = (builtin_key is not null)),
  check ((space_id is null) or name is not null),
  check (team_id is null or space_id is not null)
);
create index post_templates_space_idx on public.post_templates (space_id, created_at desc)
  where deleted_at is null;
create trigger post_templates_hidden_writer before insert on public.post_templates
  for each row execute function public.refuse_hidden_writer();

alter table public.space_posts
  add column blocks jsonb not null default '[]'::jsonb
    check (jsonb_typeof(blocks) = 'array' and octet_length(blocks::text) <= 102400),
  add column blocks_version integer not null default 0 check (blocks_version >= 0),
  add constraint space_posts_template_fkey
    foreign key (template_id) references public.post_templates (id) on delete set null;
alter table public.space_posts add column search_text text
  generated always as (public.search_fold(
    title || ' ' || coalesce(body, '') || ' ' || public.blocks_plain_text(blocks))) stored;
alter table public.checklist_points add column search_text text
  generated always as (public.search_fold(text)) stored;
alter table public.messages add column search_text text
  generated always as (public.search_fold(body)) stored;
alter table public.library_files add column search_text text
  generated always as (public.search_fold(name)) stored;

create index space_posts_search_trgm on public.space_posts
  using gin (search_text extensions.gin_trgm_ops) where deleted_at is null;
create index checklist_points_search_trgm on public.checklist_points
  using gin (search_text extensions.gin_trgm_ops);
create index messages_search_trgm on public.messages
  using gin (search_text extensions.gin_trgm_ops) where deleted_at is null and body is not null;
create index library_files_search_trgm on public.library_files
  using gin (search_text extensions.gin_trgm_ops) where deleted_at is null;

-- A week report shared in chat: the week it starts on. Opened with the
-- reader's own rights.
alter table public.messages add column report_week date;
alter table public.messages drop constraint messages_kind_check;
alter table public.messages add constraint messages_kind_check
  check (kind in ('text', 'photo', 'file', 'voice', 'work_item', 'report'));
alter table public.messages add constraint messages_report_week_check
  check ((kind = 'report') = (report_week is not null));

-- The built-in Daily report (R2): three headings, as keys.
insert into public.post_templates (id, space_id, kind, builtin_key, blocks, fields)
values ('00000000-0000-4000-8000-0000000d0001', null, 'report', 'daily_report',
        '[{"id": "00000000-0000-4000-8000-0000000d0011", "type": "heading", "key": "on_site"},
          {"id": "00000000-0000-4000-8000-0000000d0012", "type": "heading", "key": "done_today"},
          {"id": "00000000-0000-4000-8000-0000000d0013", "type": "heading", "key": "problems"}]',
        '{}');

-- A template the caller may read: a built-in, or one of a Space they are in
-- (a Team's only for that Team and the admins).
create or replace function public.can_read_template(p_template public.post_templates)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_template.deleted_at is null
    and (p_template.space_id is null
         or (public.is_member(p_template.space_id)
             and (p_template.team_id is null
                  or public.is_space_admin(p_template.space_id)
                  or exists (select 1 from public.team_members tm
                             where tm.team_id = p_template.team_id
                               and tm.profile_id = auth.uid()))));
$$;

alter table public.post_templates enable row level security;
create policy post_templates_read on public.post_templates
  for select to authenticated using (public.can_read_template(post_templates));
revoke all on public.post_templates from anon, authenticated;
grant select on public.post_templates to authenticated;
grant all on public.post_templates to service_role;

-- ---------------------------------------------------------------------------
-- Checking a page
-- ---------------------------------------------------------------------------

-- One text field of a block: a string of at most [p_max] characters (at
-- least 1 when [p_min] is 1).
create or replace function public.block_text_ok(p_value jsonb, p_min integer, p_max integer)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_value is not null and jsonb_typeof(p_value) = 'string'
    and char_length(p_value #>> '{}') <= p_max
    and (p_min = 0 or length(trim(p_value #>> '{}')) >= p_min);
$$;

-- Check a page for [p_post] (null for a template, which may hold no
-- references). Types and keys:
-- - text {text 0-2000}; heading {text 1-200, level 1|2} (a template's may
--   hold {key} instead); toggle {text 1-200, children: text, heading,
--   table, photo or file}; table {rows: 1-20 rows of 1-8 strings of at most
--   200, every row as wide};
-- - photo {path, caption?}: a photo of this post (post_files);
-- - file {library_file_id}: a Library file on this post (post_files);
-- - checklist_ref {point_ids}: points of this post (work items and
--   checklists), each in one block only;
-- - child_item {post_id}: a work item under this post (top-level work items);
-- - item_ref {post_id} (reports): a work item of this Space whose audience
--   covers the report's (an Everyone report shows Everyone work only).
-- At most 200 blocks, toggle children included; at most 100 KB; ids unique.
create or replace function public.validate_blocks(p_post public.space_posts, p_blocks jsonb)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
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
    if jsonb_typeof(v_block) <> 'object' or jsonb_typeof(v_block -> 'id') <> 'string'
       or (v_block ->> 'id') !~ '^[0-9a-fA-F-]{36}$' then
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
      if v_kind <> 'work_item' or p_post.parent_id is not null
         or not exists (select 1 from public.space_posts c
                        where c.id::text = v_block ->> 'post_id' and c.parent_id = p_post.id
                          and c.kind = 'work_item' and c.deleted_at is null) then
        raise exception 'a work item under this one' using errcode = '22023';
      end if;
    elsif v_type = 'item_ref' then
      begin
        v_ref := (v_block ->> 'post_id')::uuid;
      exception when invalid_text_representation then
        v_ref := null;
      end;
      if v_kind <> 'report' or v_ref is null or not exists (
           select 1 from public.space_posts c
           where c.id = v_ref and c.space_id = p_post.space_id and c.kind = 'work_item'
             and c.deleted_at is null
             and (c.team_id is null or c.team_id is not distinct from p_post.team_id)
             and public.can_see_space_post(c.id)) then
        raise exception 'a work item this report''s readers can see' using errcode = '22023';
      end if;
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Saving a page
-- ---------------------------------------------------------------------------

-- Save [p_id]'s page as [p_blocks], if it is still at [p_base_version]
-- (otherwise 40001: someone saved in between; the app reloads and applies
-- its change again). [p_add_files] first adds the post's own files (as
-- add_post_files), so a new photo and the block that shows it save
-- together. The author only, while they may post, under the edit rules (a
-- work item only while Open). One post_edits row per save ("Page edited");
-- a work item's owner hears of it at most once in 10 minutes. Returns the
-- new version.
create or replace function public.save_blocks(p_id uuid, p_blocks jsonb, p_base_version integer,
                                              p_add_files jsonb default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_added integer := 0;
  v_owner uuid;
  v_edit uuid;
begin
  -- The post first, then the work item (as edit, delete and cancel).
  select * into v_post from public.space_posts where id = p_id for update;
  if v_post.id is null or v_post.author_id is distinct from v_me
     or not public.is_member(v_post.space_id) or public.is_hidden_account(v_me)
     or not public.can(v_post.space_id, 'create_items')
     or (p_add_files is not null and jsonb_typeof(p_add_files) = 'array'
         and jsonb_array_length(p_add_files) > 0
         and not public.can(v_post.space_id, 'add_files')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_post.kind = 'work_item' then
    select w.owner_id into v_owner from public.work_items w where w.id = p_id for update;
  end if;
  if not public.post_is_editable(v_post) then
    raise exception 'this can no longer be edited' using errcode = 'P0001';
  end if;
  if p_base_version is distinct from v_post.blocks_version then
    raise exception 'this page changed; reload it' using errcode = '40001';
  end if;
  if p_add_files is not null then
    v_added := public.add_post_files(v_post, p_add_files);
  end if;
  perform public.validate_blocks(v_post, p_blocks);

  update public.space_posts
  set blocks = p_blocks, blocks_version = blocks_version + 1, edited_at = now()
  where id = p_id;
  insert into public.post_edits (post_id, editor_id, changes)
  values (p_id, v_me, jsonb_build_object('page', jsonb_build_object(
            'from', v_post.blocks_version, 'to', v_post.blocks_version + 1))
          || case when v_added > 0
                  then jsonb_build_object('files', jsonb_build_object('added', v_added, 'removed', 0))
                  else '{}'::jsonb end)
  returning id into v_edit;
  if v_owner is not null and not exists (
       select 1 from public.notifications n
       where n.profile_id = v_owner and n.kind = 'item_edited' and n.work_item_id = p_id
         and n.created_at > now() - interval '10 minutes') then
    perform public.add_notification(v_owner, 'item_edited', v_me, v_post.space_id, p_id,
                                    p_payload => jsonb_build_object('edit_id', v_edit));
  end if;
  return v_post.blocks_version + 1;
end;
$$;

-- ---------------------------------------------------------------------------
-- Templates
-- ---------------------------------------------------------------------------

-- The caller may manage templates in [p_space]: a Lead or a Space admin.
create or replace function public.may_manage_templates(p_space uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and not public.is_hidden_account(auth.uid())
    and (public.is_space_admin(p_space)
         or exists (select 1 from public.space_members m
                    join public.spaces s on s.id = m.space_id and s.deleted_at is null
                    where m.space_id = p_space and m.profile_id = auth.uid()
                      and m.left_at is null and m.pass = 'lead'));
$$;

-- Save [p_from_post] as a template [p_name] of [p_space] (a Lead or a
-- Space admin; at most 50 in a Space). Only the words come: text, headings,
-- toggles and tables, the title, body and points; never photos, files or
-- the work items under it. The template keeps the post's Team. A retry
-- with the same id returns it.
create or replace function public.save_template(p_id uuid, p_space uuid, p_from_post uuid,
                                                p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_existing public.post_templates;
  v_post public.space_posts;
  v_blocks jsonb;
  v_name text := trim(p_name);
begin
  select * into v_existing from public.post_templates where id = p_id;
  if v_existing.id is not null then
    if v_existing.created_by = v_me and v_existing.space_id = p_space then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.may_manage_templates(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_post from public.space_posts where id = p_from_post;
  if v_post.id is null or v_post.space_id <> p_space or not public.can_see_space_post(v_post.id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_post.kind not in ('work_item', 'checklist', 'announcement', 'report') then
    raise exception 'this kind of post can''t be a template' using errcode = '22023';
  end if;
  if v_name is null or length(v_name) not between 1 and 60 then
    raise exception 'a name of 1 to 60 characters' using errcode = '22023';
  end if;
  if (select count(*) from public.post_templates t
      where t.space_id = p_space and t.deleted_at is null) >= 50 then
    raise exception 'at most 50 templates in a Space' using errcode = '54000';
  end if;

  select coalesce(jsonb_agg(
           case when b ->> 'type' = 'toggle' then jsonb_set(b, '{children}', coalesce((
                  select jsonb_agg(c order by m)
                  from jsonb_array_elements(b -> 'children') with ordinality cc(c, m)
                  where c ->> 'type' in ('text', 'heading', 'table')), '[]'::jsonb))
                else b end order by n), '[]'::jsonb)
  into v_blocks
  from jsonb_array_elements(v_post.blocks) with ordinality t(b, n)
  where b ->> 'type' in ('text', 'heading', 'toggle', 'table');
  perform public.validate_blocks(null::public.space_posts, v_blocks);

  insert into public.post_templates (id, space_id, team_id, kind, name, blocks, fields, created_by)
  values (p_id, p_space, v_post.team_id, v_post.kind, v_name, v_blocks,
          jsonb_strip_nulls(jsonb_build_object(
            'title', v_post.title, 'body', v_post.body,
            'points', (select jsonb_agg(c.text order by c.sort, c.id)
                       from public.checklist_points c where c.post_id = v_post.id))),
          v_me);
  return p_id;
end;
$$;

-- Delete a Space's template (a Lead or a Space admin of that Space).
-- Built-ins stay.
create or replace function public.delete_template(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_template public.post_templates;
begin
  select * into v_template from public.post_templates where id = p_id for update;
  if v_template.id is null or v_template.space_id is null
     or not public.may_manage_templates(v_template.space_id)
     or not public.can_read_template(v_template) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.post_templates set deleted_at = now() where id = p_id;
end;
$$;

-- The templates the caller may use in [p_space]: the built-ins and the
-- Space's own (a Team's only for that Team and the admins).
create or replace function public.space_templates(p_space uuid)
returns table (id uuid, kind text, builtin_key text, name text, team_id uuid, blocks jsonb,
               fields jsonb, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id, t.kind, t.builtin_key, t.name, t.team_id, t.blocks, t.fields, t.created_at
  from public.post_templates t
  where public.is_member(p_space)
    and (t.space_id is null or t.space_id = p_space)
    and public.can_read_template(t)
  order by t.space_id nulls first, t.created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Walk mode and meeting notes: a parent and its work items in one call
-- ---------------------------------------------------------------------------

-- One push per owner for a batch (a walk of 10 photos for Omar sends Omar
-- one push, not 10). Each work item still has its Activity row.
create or replace function public.batch_pushes(p_parent uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.push_queue (profile_id, kind, actor_id, data)
  select o.owner_id, 'item_assigned', auth.uid(),
         jsonb_build_object('space_id', p.space_id, 'work_item_id', p.id)
  from public.space_posts p
  join lateral (
    select distinct w.owner_id
    from public.space_posts c
    join public.work_items w on w.id = c.id
    where c.parent_id = p.id and w.owner_id is distinct from auth.uid()) o on true
  where p.id = p_parent
    and exists (select 1 from public.push_tokens t where t.profile_id = o.owner_id)
    and public.space_push_level(p.space_id, o.owner_id) in ('all', 'needs_you')
    and not public.blocked_between(o.owner_id, auth.uid())
    and public.can_see_space_post_as(p.id, o.owner_id);
$$;

-- Walk mode (R1, R1b): a parent work item [p_parent] titled [p_title], and
-- under it one work item per photo: [p_items] = [{id, line, owner,
-- photo: {path, mime?, bytes?, width?, height?}}], 1 to 30, each photo
-- already uploaded to <space>/posts/<item id>/. The parent is owned by its
-- author (a target, done when its work items are checked). All or nothing;
-- the same parent id again returns it.
create or replace function public.create_walk(p_space uuid, p_parent uuid, p_title text,
                                              p_items jsonb, p_place text default null,
                                              p_team uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_existing public.space_posts;
  v_item jsonb;
begin
  select * into v_existing from public.space_posts where id = p_parent;
  if v_existing.id is not null then
    if v_existing.author_id = v_me and v_existing.space_id = p_space
       and v_existing.kind = 'work_item' then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.can(p_space, 'create_items') or public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_team is not null and not public.is_space_admin(p_space) and not exists (
       select 1 from public.team_members tm where tm.team_id = p_team and tm.profile_id = v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) not between 1 and 30 then
    raise exception 'a walk has 1 to 30 photos' using errcode = '22023';
  end if;
  if (select count(distinct x ->> 'id') from jsonb_array_elements(p_items) x)
     <> jsonb_array_length(p_items)
     or exists (select 1 from jsonb_array_elements(p_items) x
                where jsonb_typeof(x -> 'photo') is distinct from 'object'
                   or (x ->> 'id') is null or (x ->> 'id') = p_parent::text) then
    raise exception 'each photo has its own id and its photo' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_array_elements(p_items) x
             join public.space_posts p on p.id::text = x ->> 'id') then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  perform set_config('bv.batch', 'on', true);
  perform public.create_work_item(p_space, p_title, v_me, null, p_team, p_place, '[]'::jsonb,
                                  p_parent);
  for v_item in select * from jsonb_array_elements(p_items) loop
    perform public.create_work_item(p_space, v_item ->> 'line', (v_item ->> 'owner')::uuid, null,
                                    p_team, p_place, '[]'::jsonb, (v_item ->> 'id')::uuid,
                                    p_parent => p_parent,
                                    p_files => jsonb_build_array(v_item -> 'photo'));
  end loop;
  perform public.batch_pushes(p_parent);
  perform set_config('bv.batch', 'off', true);
  return p_parent;
exception
  when invalid_text_representation then
    raise exception 'an id is not valid' using errcode = '22023';
end;
$$;

-- Meeting notes (R3): from a chat message [p_message] the caller can read
-- (text, in this Space, not reported, not by someone blocked), a parent
-- work item [p_parent] titled [p_title] and one work item per line:
-- [p_lines] = [{id, text, owner}], 1 to 30. All of them record the
-- message, and a Team thread's message keeps them in that Team. All or
-- nothing; the same parent id again returns it.
create or replace function public.create_from_message(p_space uuid, p_message uuid, p_parent uuid,
                                                      p_title text, p_lines jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_existing public.space_posts;
  v_msg public.messages;
  v_line jsonb;
begin
  select * into v_existing from public.space_posts where id = p_parent;
  if v_existing.id is not null then
    if v_existing.author_id = v_me and v_existing.space_id = p_space
       and v_existing.kind = 'work_item' then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.can(p_space, 'create_items') or public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_msg from public.messages where id = p_message;
  if v_msg.id is null or v_msg.space_id <> p_space or v_msg.deleted_at is not null
     or v_msg.kind <> 'text' or v_msg.body is null
     or not public.can_use_thread(v_msg.thread_id)
     or public.reported_by_me('message', v_msg.id)
     or public.blocked_between(v_me, v_msg.author_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) not between 1 and 30 then
    raise exception 'meeting notes have 1 to 30 lines' using errcode = '22023';
  end if;
  if (select count(distinct x ->> 'id') from jsonb_array_elements(p_lines) x)
     <> jsonb_array_length(p_lines)
     or exists (select 1 from jsonb_array_elements(p_lines) x
                where (x ->> 'id') is null or (x ->> 'id') = p_parent::text) then
    raise exception 'each line has its own id' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_array_elements(p_lines) x
             join public.space_posts p on p.id::text = x ->> 'id') then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  perform set_config('bv.batch', 'on', true);
  perform public.create_work_item(p_space, p_title, v_me, null, null, null, '[]'::jsonb, p_parent,
                                  p_source_message => p_message);
  for v_line in select * from jsonb_array_elements(p_lines) loop
    perform public.create_work_item(p_space, v_line ->> 'text', (v_line ->> 'owner')::uuid, null,
                                    null, null, '[]'::jsonb, (v_line ->> 'id')::uuid,
                                    p_parent => p_parent, p_source_message => p_message);
  end loop;
  perform public.batch_pushes(p_parent);
  perform set_config('bv.batch', 'off', true);
  return p_parent;
exception
  when invalid_text_representation then
    raise exception 'an id is not valid' using errcode = '22023';
end;
$$;

-- ---------------------------------------------------------------------------
-- The daily report and the week report
-- ---------------------------------------------------------------------------

-- The photo its owner signed a work item as done with, latest first.
create or replace function public.done_photo_path(p_item uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select ev.storage_path
  from public.work_item_events e
  join public.work_items w on w.id = e.work_item_id
  join public.work_item_evidence ev on ev.event_id = e.id
  where e.work_item_id = p_item and e.kind = 'done' and e.actor_id = w.owner_id
  order by e.created_at desc, ev.created_at
  limit 1;
$$;

-- What was checked between [p_from] and [p_to] (the phone's day, at most a
-- day and an hour), for a daily report to [p_team] (null: Everyone): only
-- work its readers may all see (an Everyone report never shows a Team's),
-- and the caller can see. The app drops these into "Done today" as
-- item_ref blocks.
create or replace function public.daily_report_fill(p_space uuid, p_team uuid, p_from timestamptz,
                                                    p_to timestamptz)
returns table (post_id uuid, ref text, title text, owner_name text, checked_at timestamptz,
               checker_name text, done_photo_path text)
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
  select p.id, w.ref, p.title, public.space_person_name(w.owner_id), w.checked_at,
         public.space_person_name(w.checked_by), public.done_photo_path(w.id)
  from public.work_items w
  join public.space_posts p on p.id = w.id
  where p.space_id = p_space and p.deleted_at is null and w.status = 'checked'
    and w.checked_at >= p_from and w.checked_at < p_to
    and (p.team_id is null or p.team_id is not distinct from p_team)
    and public.can_see_space_post(p.id)
  order by w.checked_at, p.id
  limit 100;
end;
$$;

-- The week report (MR1) for [p_from] to [p_to] (the phone's week, at most
-- 7 days and an hour; [p_today] the phone's day): what needs a decision
-- (late, sent back, waiting for a check), what was checked, targets (work
-- items with work items under them, and their progress), and what is
-- coming up in the next 7 days. Each person sees only what they may read.
-- Rows with names, never per-person totals (rule 3). At most 30 a section.
create or replace function public.week_report(p_space uuid, p_today date, p_from timestamptz,
                                              p_to timestamptz)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_member(p_space) then
    return null;
  end if;
  if p_today is null or p_from is null or p_to is null or p_to <= p_from
     or p_to - p_from > interval '7 days 1 hour' then
    raise exception 'choose a week' using errcode = '22023';
  end if;
  return jsonb_build_object(
    'needs_decision', coalesce((
      select jsonb_agg(x.row order by x.at desc, x.id) from (
        select p.id, coalesce(w.done_at, last.created_at, p.created_at) as at,
               jsonb_strip_nulls(jsonb_build_object(
                 'post_id', p.id, 'title', p.title, 'ref', w.ref,
                 'state', case when w.status = 'done' then 'done'
                               when last.kind = 'sent_back' then 'sent_back'
                               else 'late' end,
                 'owner_name', public.space_person_name(w.owner_id),
                 'reason', case when w.status = 'open' and last.kind = 'sent_back' then last.reason end,
                 'due_date', p.due_date, 'done_at', w.done_at,
                 'needs_me', public.item_needs_me(w, p) is not null)) as row
        from public.work_items w
        join public.space_posts p on p.id = w.id
        left join lateral (
          select e.kind, e.reason, e.created_at from public.work_item_events e
          where e.work_item_id = w.id and e.kind in ('done', 'checked', 'sent_back')
          order by e.created_at desc, e.id desc limit 1) last on true
        where p.space_id = p_space and p.deleted_at is null and p.status = 'live'
          and (w.status = 'done'
               or (w.status = 'open' and (last.kind = 'sent_back' or p.due_date < p_today)))
          and public.can_see_space_post(p.id)
        order by 2 desc, p.id
        limit 30) x), '[]'::jsonb),
    'checked', coalesce((
      select jsonb_agg(x.row order by x.at desc, x.id) from (
        select p.id, w.checked_at as at, jsonb_strip_nulls(jsonb_build_object(
                 'post_id', p.id, 'title', p.title, 'ref', w.ref,
                 'done_photo_path', public.done_photo_path(w.id),
                 'checker_name', public.space_person_name(w.checked_by),
                 'checked_at', w.checked_at)) as row
        from public.work_items w
        join public.space_posts p on p.id = w.id
        where p.space_id = p_space and p.deleted_at is null and w.status = 'checked'
          and w.checked_at >= p_from and w.checked_at < p_to
          and public.can_see_space_post(p.id)
        order by w.checked_at desc, p.id
        limit 30) x), '[]'::jsonb),
    'targets', coalesce((
      select jsonb_agg(x.row order by x.at desc, x.id) from (
        select p.id, p.created_at as at, jsonb_strip_nulls(jsonb_build_object(
                 'post_id', p.id, 'title', p.title, 'ref', w.ref, 'due_date', p.due_date,
                 'children', ch.progress)) as row
        from public.work_items w
        join public.space_posts p on p.id = w.id
        join lateral (
          select jsonb_build_object('total', count(*),
                                    'checked', count(*) filter (where cw.status = 'checked')) as progress
          from public.space_posts c
          join public.work_items cw on cw.id = c.id
          where c.parent_id = p.id and c.deleted_at is null and c.status = 'live'
            and public.can_see_space_post(c.id)
          having count(*) > 0) ch on true
        where p.space_id = p_space and p.deleted_at is null and p.status = 'live'
          and p.parent_id is null and w.status <> 'checked'
          and public.can_see_space_post(p.id)
        order by p.created_at desc, p.id
        limit 30) x), '[]'::jsonb),
    'coming_up', coalesce((
      select jsonb_agg(x.row order by x.at, x.id) from (
        select p.id, p.starts_at as at, jsonb_strip_nulls(jsonb_build_object(
                 'post_id', p.id, 'kind', 'activity', 'title', p.title,
                 'starts_at', p.starts_at, 'ends_at', p.ends_at, 'place', p.place_text)) as row
        from public.space_posts p
        where p.space_id = p_space and p.kind = 'activity' and p.deleted_at is null
          and p.status = 'live' and p.starts_at >= p_to and p.starts_at < p_to + interval '7 days'
          and public.can_see_space_post(p.id)
        union all
        select p.id, p.due_date::timestamptz, jsonb_strip_nulls(jsonb_build_object(
                 'post_id', p.id, 'kind', 'work_item', 'title', p.title, 'ref', w.ref,
                 'due_date', p.due_date, 'owner_name', public.space_person_name(w.owner_id)))
        from public.work_items w
        join public.space_posts p on p.id = w.id
        where p.space_id = p_space and p.deleted_at is null and p.status = 'live'
          and w.status in ('open', 'done')
          and p.due_date >= p_today and p.due_date < p_today + 7
          and public.can_see_space_post(p.id)
        order by 2, 1
        limit 30) x), '[]'::jsonb));
end;
$$;

-- Share the week starting [p_week_start] in a chat thread: a message of
-- kind report. Whoever taps it opens week_report with their own rights.
-- Anyone who may write in the thread; a retry with the same id posts once.
create or replace function public.share_week_report(p_id uuid, p_thread uuid, p_week_start date)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_thread public.threads;
  v_existing public.messages;
begin
  if v_me is null or public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_existing from public.messages where id = p_id;
  if v_existing.id is not null then
    if v_existing.author_id = v_me and v_existing.thread_id = p_thread
       and v_existing.kind = 'report' then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_thread from public.threads where id = p_thread;
  if v_thread.id is null or not public.can_use_thread(p_thread) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_week_start is null or p_week_start > current_date + 1
     or p_week_start < current_date - 366 then
    raise exception 'choose a week' using errcode = '22023';
  end if;
  if (select count(*) from public.messages m
      where m.author_id = v_me and m.kind <> 'work_item'
        and m.created_at > now() - interval '1 minute') >= 30 then
    raise exception 'too many messages, wait a moment' using errcode = 'P0001';
  end if;
  insert into public.messages (id, thread_id, space_id, author_id, kind, report_week)
  values (p_id, p_thread, v_thread.space_id, v_me, 'report', p_week_start);
  return p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Search
-- ---------------------------------------------------------------------------

-- [p_q] in [p_space]: posts (titles, words and pages), checklist points,
-- chat messages and Library file names the caller may read, newest first,
-- 30 at most. As typed, with Arabic letter forms folded (search_fold); 2
-- to 100 characters. Never private notes or direct messages. Names as
-- space_person_name gives them (none across a block).
create or replace function public.search_space(p_space uuid, p_q text)
returns table (kind text, id uuid, post_id uuid, thread_id uuid, team_id uuid, post_kind text,
               post_status text, ref text, title text, snippet text, author_name text,
               created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := public.search_fold(regexp_replace(trim(coalesce(p_q, '')), '\s+', ' ', 'g'));
  v_pat text;
  v_threads uuid[];
begin
  if char_length(v_q) > 100 then
    raise exception 'search too long' using errcode = '22023';
  end if;
  if char_length(v_q) < 2 or not public.is_member(p_space) then
    return;
  end if;
  v_pat := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_threads := array(select t.id from public.threads t
                     where t.space_id = p_space and public.can_use_thread(t.id));

  return query
  with hits as (
    (select 'post'::text as kind, p.id, p.id as post_id, null::uuid as thread_id, p.team_id,
            p.kind as post_kind, p.status as post_status, w.ref, p.title,
            case when public.search_fold(p.title) like v_pat then null
                 else public.search_snippet(
                   coalesce(p.body, '') || ' ' || public.blocks_plain_text(p.blocks), v_q)
            end as snippet,
            p.author_id, p.created_at
     from public.space_posts p
     left join public.work_items w on w.id = p.id
     where p.space_id = p_space and p.deleted_at is null
       and p.search_text like v_pat
       and (p.team_id is null or public.can_see_space_post(p.id))
     order by p.created_at desc, p.id desc limit 30)
    union all
    (select 'point', c.id, p.id, null, p.team_id, p.kind, p.status, w.ref, p.title, c.text,
            p.author_id, c.created_at
     from public.checklist_points c
     join public.space_posts p on p.id = c.post_id
     left join public.work_items w on w.id = p.id
     where p.space_id = p_space and p.deleted_at is null
       and c.search_text like v_pat
       and (p.team_id is null or public.can_see_space_post(p.id))
     order by c.created_at desc, c.id desc limit 30)
    union all
    (select 'message', m.id, null, m.thread_id, t.team_id, null, null, null, null,
            public.search_snippet(m.body, v_q), m.author_id, m.created_at
     from public.messages m
     join public.threads t on t.id = m.thread_id
     where m.space_id = p_space and m.thread_id = any (v_threads)
       and m.deleted_at is null and m.body is not null
       and m.search_text like v_pat
       and not public.reported_by_me('message', m.id)
     order by m.created_at desc, m.id desc limit 30)
    union all
    (select 'file', f.id, null, null, f.team_id, null, null, null, f.name, f.rev_label,
            f.uploaded_by, f.created_at
     from public.library_files f
     where f.space_id = p_space and f.deleted_at is null
       and f.search_text like v_pat
       and (f.team_id is null or public.can_read_library_file(f.id))
     order by f.created_at desc, f.id desc limit 30)
  )
  select h.kind, h.id, h.post_id, h.thread_id, h.team_id, h.post_kind, h.post_status, h.ref,
         h.title, h.snippet, public.space_person_name(h.author_id), h.created_at
  from hits h
  -- The full rules again on at most 120 rows, so a later change to the
  -- short-cuts above can't leak.
  where (h.post_id is null or public.can_see_space_post(h.post_id))
    and (h.kind <> 'file' or public.can_read_library_file(h.id))
  order by h.created_at desc, h.id desc
  limit 30;
end;
$$;

-- ---------------------------------------------------------------------------
-- Copies of live functions with their changes
-- ---------------------------------------------------------------------------

-- Posting: also a report, from a template, with a page (as in 20261015180000_post_kinds.sql, with those changes only).
drop function public.create_space_post(uuid, uuid, text, text, text, uuid, text, date, timestamptz, timestamptz, timestamptz, uuid, uuid[], jsonb, uuid, jsonb, jsonb);
CREATE FUNCTION public.create_space_post(p_id uuid, p_space uuid, p_kind text, p_title text DEFAULT NULL::text, p_body text DEFAULT NULL::text, p_team uuid DEFAULT NULL::uuid, p_place text DEFAULT NULL::text, p_due date DEFAULT NULL::date, p_pinned_until timestamp with time zone DEFAULT NULL::timestamp with time zone, p_starts_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_ends_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_library_file uuid DEFAULT NULL::uuid, p_people uuid[] DEFAULT '{}'::uuid[], p_points jsonb DEFAULT '[]'::jsonb, p_source_message uuid DEFAULT NULL::uuid, p_quote jsonb DEFAULT NULL::jsonb, p_files jsonb DEFAULT '[]'::jsonb, p_template uuid DEFAULT NULL::uuid, p_blocks jsonb DEFAULT NULL::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me uuid := auth.uid();
  v_id uuid := coalesce(p_id, gen_random_uuid());
  v_post public.space_posts;
  v_msg public.messages;
  v_thread_team uuid;
  v_team uuid := p_team;
  v_file public.library_files;
  v_title text := trim(p_title);
  v_point jsonb;
  v_sort integer := 0;
  v_member record;
  v_template public.post_templates;
begin
  -- The same id again (a retry): the same post, if it is the caller's.
  select * into v_post from public.space_posts where id = v_id;
  if v_post.id is not null then
    if v_post.author_id = v_me and v_post.space_id = p_space and v_post.kind = p_kind then
      return v_post.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if p_kind is null or p_kind not in ('checklist', 'announcement', 'activity', 'file', 'report') then
    raise exception 'choose a kind of post' using errcode = '22023';
  end if;
  if not public.can(p_space, 'create_items') or public.is_hidden_account(v_me)
     or (p_kind = 'file' and not public.can(p_space, 'add_files')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if public.folder_has_others_files_in(p_space::text || '/posts/' || v_id::text || '/') then
    raise exception 'this id is taken' using errcode = '42501';
  end if;
  if v_team is not null and not exists (
       select 1 from public.teams t where t.id = v_team and t.space_id = p_space) then
    raise exception 'team not in this Space' using errcode = '22023';
  end if;
  if p_quote is not null and not public.is_valid_post_quote(p_quote) then
    raise exception 'a quote needs its text' using errcode = '22023';
  end if;

  -- From a chat message the caller can read; a Team thread's message stays
  -- in that Team (as create_work_item).
  if p_source_message is not null then
    select * into v_msg from public.messages where id = p_source_message;
    if v_msg.id is null or v_msg.space_id <> p_space or v_msg.deleted_at is not null
       or v_msg.kind = 'work_item' or not public.can_use_thread(v_msg.thread_id)
       or public.reported_by_me('message', v_msg.id) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    select t.team_id into v_thread_team from public.threads t where t.id = v_msg.thread_id;
    if v_thread_team is not null then
      if v_team is null then
        v_team := v_thread_team;
      elsif v_team <> v_thread_team then
        raise exception 'a Team chat message stays in that Team' using errcode = '22023';
      end if;
    end if;
  end if;
  -- A Team post only from inside that Team (or a Space admin).
  if v_team is not null and not public.is_space_admin(p_space) and not exists (
       select 1 from public.team_members tm where tm.team_id = v_team and tm.profile_id = v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  -- What each kind takes.
  if (p_pinned_until is not null and p_kind <> 'announcement')
     or ((p_starts_at is not null or p_ends_at is not null) and p_kind <> 'activity')
     or (p_library_file is not null and p_kind <> 'file')
     or (p_due is not null and p_kind <> 'checklist')
     or (nullif(trim(p_place), '') is not null and p_kind <> 'activity')
     or (coalesce(cardinality(p_people), 0) > 0 and p_kind not in ('checklist', 'activity'))
     or (coalesce(jsonb_array_length(case when jsonb_typeof(p_points) = 'array' then p_points end), 0) > 0
         and p_kind <> 'checklist') then
    raise exception 'that doesn''t go on this kind of post' using errcode = '22023';
  end if;
  if p_kind = 'file' then
    if p_library_file is null then
      raise exception 'choose a file' using errcode = '22023';
    end if;
    v_file := public.post_library_file(p_space, v_team, p_library_file);
    v_title := coalesce(nullif(v_title, ''), v_file.name);
  end if;
  if v_title is null or length(v_title) not between 1 and 200 then
    raise exception 'a title of 1 to 200 characters' using errcode = '22023';
  end if;
  if length(p_body) > 5000 then
    raise exception 'at most 5000 characters' using errcode = '22023';
  end if;
  if length(trim(p_place)) > 80 then
    raise exception 'at most 80 characters' using errcode = '22023';
  end if;
  if p_pinned_until is not null
     and (p_pinned_until <= now() or p_pinned_until > now() + interval '90 days') then
    raise exception 'pin it until a day in the next 90 days' using errcode = '22023';
  end if;
  if p_kind = 'activity' then
    if p_starts_at is null or p_starts_at <= now() then
      raise exception 'an activity starts in the future' using errcode = '22023';
    end if;
    if p_ends_at is not null
       and (p_ends_at <= p_starts_at or p_ends_at > p_starts_at + interval '1 day') then
      raise exception 'it ends after it starts, within a day' using errcode = '22023';
    end if;
  end if;
  if p_kind = 'checklist' then
    if coalesce(cardinality(p_people), 0) = 0 then
      raise exception 'choose who the checklist is for' using errcode = '22023';
    end if;
    if p_points is null or jsonb_typeof(p_points) <> 'array'
       or jsonb_array_length(p_points) not between 1 and 50 then
      raise exception 'a checklist has 1 to 50 points' using errcode = '22023';
    end if;
  end if;

  -- From a template (migration 20): a built-in or one of this Space the
  -- caller may read, of the same kind and audience.
  if p_template is not null then
    select * into v_template from public.post_templates t where t.id = p_template;
    if v_template.id is null or not public.can_read_template(v_template)
       or (v_template.space_id is not null and v_template.space_id <> p_space) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if v_template.kind <> p_kind
       or (v_template.team_id is not null and v_template.team_id is distinct from v_team) then
      raise exception 'this template is for another kind of post or Team' using errcode = '22023';
    end if;
  end if;

  insert into public.space_posts (id, space_id, team_id, kind, author_id, title, body,
                                  place_text, due_date, source_message_id, quote,
                                  pinned_until, starts_at, ends_at, library_file_id,
                                  template_id)
  values (v_id, p_space, v_team, p_kind, v_me, v_title, nullif(trim(p_body), ''),
          nullif(trim(p_place), ''), p_due, p_source_message, p_quote,
          p_pinned_until, p_starts_at, p_ends_at, p_library_file, p_template)
  returning * into v_post;

  if p_kind = 'checklist' then
    for v_point in select * from jsonb_array_elements(p_points) loop
      if jsonb_typeof(v_point) <> 'object' then
        raise exception 'a point must be an object' using errcode = '22023';
      end if;
      insert into public.checklist_points (id, post_id, sort, text)
      values (coalesce(nullif(v_point ->> 'id', '')::uuid, gen_random_uuid()), v_id, v_sort,
              public.point_text(v_point ->> 'text'));
      v_sort := v_sort + 1;
    end loop;
  end if;
  perform public.add_post_people(v_post, p_people);
  perform public.add_post_files(v_post, p_files);
  -- The page, once its files and points are there (migration 20).
  if p_blocks is not null then
    perform public.validate_blocks(v_post, p_blocks);
    update public.space_posts set blocks = p_blocks where id = v_id;
  end if;

  -- Tell the audience of an announcement, and whoever received an older
  -- version of a new file.
  if p_kind = 'announcement' then
    for v_member in
      select m.profile_id from public.space_members m
      where m.space_id = p_space and m.left_at is null
        and public.can_see_space_post_as(v_id, m.profile_id)
    loop
      perform public.add_notification(v_member.profile_id, 'announcement_new', v_me, p_space,
                                      p_space_post => v_id);
    end loop;
  elsif p_kind = 'file' and v_file.supersedes_id is not null then
    for v_member in
      with recursive older (id) as (
        select v_file.supersedes_id
        union
        select f.supersedes_id from public.library_files f
        join older o on o.id = f.id
        where f.supersedes_id is not null)
      select distinct a.profile_id
      from older o
      join public.space_posts p on p.library_file_id = o.id and p.deleted_at is null
      join public.post_acks a on a.post_id = p.id and a.kind = 'received'
      where public.can_see_space_post_as(v_id, a.profile_id)
    loop
      perform public.add_notification(v_member.profile_id, 'file_new_version', v_me, p_space,
                                      p_space_post => v_id);
    end loop;
  end if;
  return v_id;
exception
  when invalid_text_representation then
    raise exception 'a point id is not valid' using errcode = '22023';
end;
$function$;

-- Editing: a point or a file the page shows can't be removed (as in 20261015180000_post_kinds.sql, with that change only).
CREATE OR REPLACE FUNCTION public.edit_space_post(p_id uuid, p_changes jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_owner uuid;
  v_diff jsonb := '{}'::jsonb;
  v_title text;
  v_body text;
  v_place text;
  v_due date;
  v_pinned timestamptz;
  v_starts timestamptz;
  v_ends timestamptz;
  v_added integer := 0;
  v_removed integer := 0;
  v_edit uuid;
  v_key text;
  v_points jsonb;
  v_people jsonb;
  v_item jsonb;
  v_point public.checklist_points;
  v_text text;
  v_p_added integer := 0;
  v_p_removed integer := 0;
  v_p_reworded integer := 0;
  v_p_moved boolean := false;
  v_sort integer;
  v_order uuid[];
  v_people_added integer := 0;
  v_people_removed integer := 0;
  v_new uuid[];
  v_person record;
begin
  select * into v_post from public.space_posts where id = p_id for update;
  -- The author, while they may still post (not lowered to Viewer, posting
  -- not switched off); files need the files right too.
  if v_post.id is null or v_post.author_id is distinct from v_me
     or not public.is_member(v_post.space_id) or public.is_hidden_account(v_me)
     or not public.can(v_post.space_id, 'create_items')
     or ((p_changes ? 'add_files' or p_changes ? 'remove_files')
         and not public.can(v_post.space_id, 'add_files')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_changes is null or jsonb_typeof(p_changes) <> 'object' then
    raise exception 'nothing to change' using errcode = '22023';
  end if;
  for v_key in select jsonb_object_keys(p_changes) loop
    if v_key not in ('title', 'body', 'place', 'due', 'add_files', 'remove_files', 'points',
                     'people', 'pinned_until', 'starts_at', 'ends_at')
       or (v_key = 'place' and v_post.kind not in ('work_item', 'checklist', 'activity'))
       or (v_key = 'due' and v_post.kind not in ('work_item', 'checklist'))
       or (v_key = 'points' and v_post.kind not in ('work_item', 'checklist'))
       or (v_key = 'people' and v_post.kind not in ('checklist', 'activity'))
       or (v_key = 'pinned_until' and v_post.kind <> 'announcement')
       or (v_key in ('starts_at', 'ends_at') and v_post.kind <> 'activity') then
      raise exception 'that can''t be edited here' using errcode = '22023';
    end if;
  end loop;
  if v_post.kind = 'work_item' then
    perform 1 from public.work_items where id = p_id for update;
  end if;
  if not public.post_is_editable(v_post) then
    raise exception 'this can no longer be edited' using errcode = 'P0001';
  end if;

  if p_changes ? 'title' then
    v_title := trim(p_changes ->> 'title');
    if v_title is null or length(v_title) not between
         (case when v_post.kind = 'work_item' then 2 else 1 end)
         and (case when v_post.kind = 'work_item' then 140 else 200 end) then
      raise exception 'a title of the right length' using errcode = '22023';
    end if;
    if v_title is distinct from v_post.title then
      v_diff := v_diff || jsonb_build_object('title', jsonb_build_object('from', v_post.title, 'to', v_title));
    end if;
  end if;
  if p_changes ? 'body' then
    v_body := nullif(trim(p_changes ->> 'body'), '');
    if length(v_body) > 5000 then
      raise exception 'at most 5000 characters' using errcode = '22023';
    end if;
    if v_body is distinct from v_post.body then
      v_diff := v_diff || jsonb_build_object('body', jsonb_build_object('from', v_post.body, 'to', v_body));
    end if;
  end if;
  if p_changes ? 'place' then
    v_place := nullif(trim(p_changes ->> 'place'), '');
    if length(v_place) > 80 then
      raise exception 'at most 80 characters' using errcode = '22023';
    end if;
    if v_place is distinct from v_post.place_text then
      v_diff := v_diff || jsonb_build_object('place', jsonb_build_object('from', v_post.place_text, 'to', v_place));
    end if;
  end if;
  if p_changes ? 'due' then
    begin
      v_due := nullif(p_changes ->> 'due', '')::date;
    exception when others then
      raise exception 'a due date' using errcode = '22023';
    end;
    if v_due is distinct from v_post.due_date then
      v_diff := v_diff || jsonb_build_object('due', jsonb_build_object('from', v_post.due_date, 'to', v_due));
    end if;
  end if;
  begin
    if p_changes ? 'pinned_until' then
      v_pinned := nullif(p_changes ->> 'pinned_until', '')::timestamptz;
    end if;
    v_starts := case when p_changes ? 'starts_at'
                     then nullif(p_changes ->> 'starts_at', '')::timestamptz
                     else v_post.starts_at end;
    v_ends := case when p_changes ? 'ends_at'
                   then nullif(p_changes ->> 'ends_at', '')::timestamptz
                   else v_post.ends_at end;
  exception when others then
    raise exception 'a time' using errcode = '22023';
  end;
  if p_changes ? 'pinned_until' then
    if v_pinned is not null
       and (v_pinned <= now() or v_pinned > now() + interval '90 days') then
      raise exception 'pin it until a day in the next 90 days' using errcode = '22023';
    end if;
    if v_pinned is distinct from v_post.pinned_until then
      v_diff := v_diff || jsonb_build_object('pinned_until',
                  jsonb_build_object('from', v_post.pinned_until, 'to', v_pinned));
    end if;
  end if;
  if p_changes ? 'starts_at' or p_changes ? 'ends_at' then
    if v_starts is null
       or (v_starts is distinct from v_post.starts_at and v_starts <= now()) then
      raise exception 'an activity starts in the future' using errcode = '22023';
    end if;
    if v_ends is not null and (v_ends <= v_starts or v_ends > v_starts + interval '1 day') then
      raise exception 'it ends after it starts, within a day' using errcode = '22023';
    end if;
    if v_starts is distinct from v_post.starts_at then
      v_diff := v_diff || jsonb_build_object('starts_at',
                  jsonb_build_object('from', v_post.starts_at, 'to', v_starts));
    end if;
    if v_ends is distinct from v_post.ends_at then
      v_diff := v_diff || jsonb_build_object('ends_at',
                  jsonb_build_object('from', v_post.ends_at, 'to', v_ends));
    end if;
  end if;

  -- Points: locked first, so a tick running now lands before the tests.
  if p_changes ? 'points' then
    v_points := p_changes -> 'points';
    if jsonb_typeof(v_points) <> 'object' then
      raise exception 'points must be an object' using errcode = '22023';
    end if;
    perform 1 from public.checklist_points where post_id = p_id order by id for update;
    if v_points ? 'remove' then
      for v_item in select * from jsonb_array_elements(v_points -> 'remove') loop
        select * into v_point from public.checklist_points
        where id = (v_item #>> '{}')::uuid and post_id = p_id;
        if v_point.id is null then
          raise exception 'not a point of this post' using errcode = '22023';
        end if;
        if v_point.ticked_at is not null then
          raise exception 'a ticked point stays' using errcode = 'P0001';
        end if;
        if exists (select 1 from jsonb_path_query(v_post.blocks,
                     'strict $.** ? (@.type == "checklist_ref").point_ids[*]') r
                   where r #>> '{}' = v_point.id::text) then
          raise exception 'the page shows this point; take it off the page first'
            using errcode = 'P0001';
        end if;
        delete from public.checklist_points where id = v_point.id;
        v_p_removed := v_p_removed + 1;
      end loop;
    end if;
    if v_points ? 'edit' then
      for v_item in select * from jsonb_array_elements(v_points -> 'edit') loop
        select * into v_point from public.checklist_points
        where id = (v_item ->> 'id')::uuid and post_id = p_id;
        if v_point.id is null then
          raise exception 'not a point of this post' using errcode = '22023';
        end if;
        v_text := public.point_text(v_item ->> 'text');
        if v_text is distinct from v_point.text then
          if v_point.ticked_at is not null then
            raise exception 'a ticked point stays as it is' using errcode = 'P0001';
          end if;
          update public.checklist_points set text = v_text where id = v_point.id;
          v_p_reworded := v_p_reworded + 1;
        end if;
      end loop;
    end if;
    if v_points ? 'add' then
      select coalesce(max(sort) + 1, 0) into v_sort from public.checklist_points where post_id = p_id;
      for v_item in select * from jsonb_array_elements(v_points -> 'add') loop
        insert into public.checklist_points (id, post_id, sort, text)
        values (coalesce(nullif(v_item ->> 'id', '')::uuid, gen_random_uuid()), p_id, v_sort,
                public.point_text(v_item ->> 'text'));
        v_sort := v_sort + 1;
        v_p_added := v_p_added + 1;
      end loop;
    end if;
    if v_points ? 'order' then
      select array_agg(x::uuid order by n) into v_order
      from jsonb_array_elements_text(v_points -> 'order') with ordinality t(x, n);
      if coalesce(cardinality(v_order), 0) <> (select count(*) from public.checklist_points where post_id = p_id)
         or exists (select 1 from public.checklist_points c
                    where c.post_id = p_id and not (c.id = any (v_order)))
         or cardinality(v_order) <> (select count(distinct x) from unnest(v_order) x) then
        raise exception 'order lists every point once' using errcode = '22023';
      end if;
      v_p_moved := v_order is distinct from (
        select array_agg(c.id order by c.sort, c.id)
        from public.checklist_points c where c.post_id = p_id);
      update public.checklist_points c set sort = o.n - 1
      from unnest(v_order) with ordinality o(id, n)
      where c.id = o.id and c.post_id = p_id;
    end if;
    if (select count(*) from public.checklist_points where post_id = p_id) > 50
       or (v_post.kind = 'checklist'
           and not exists (select 1 from public.checklist_points where post_id = p_id)) then
      raise exception 'a checklist has 1 to 50 points' using errcode = '22023';
    end if;
    if v_p_added + v_p_removed + v_p_reworded > 0 or v_p_moved then
      v_diff := v_diff || jsonb_build_object('points', jsonb_build_object(
                  'added', v_p_added, 'removed', v_p_removed, 'reworded', v_p_reworded,
                  'reordered', v_p_moved));
    end if;
  end if;

  if p_changes ? 'people' then
    v_people := p_changes -> 'people';
    if jsonb_typeof(v_people) <> 'object' then
      raise exception 'people must be an object' using errcode = '22023';
    end if;
    if v_people ? 'remove' then
      with gone as (
        delete from public.post_people pp
        where pp.post_id = p_id
          and pp.profile_id::text in (select jsonb_array_elements_text(v_people -> 'remove'))
        returning 1)
      select count(*) into v_people_removed from gone;
    end if;
    if v_people ? 'add' then
      select array_agg(x::uuid) into v_new from jsonb_array_elements_text(v_people -> 'add') x;
      v_people_added := public.add_post_people(v_post, v_new);
    end if;
    if v_post.kind = 'checklist' and not exists (select 1 from public.post_people where post_id = p_id) then
      raise exception 'choose who the checklist is for' using errcode = '22023';
    end if;
    if v_people_added + v_people_removed > 0 then
      v_diff := v_diff || jsonb_build_object('people', jsonb_build_object(
                  'added', v_people_added, 'removed', v_people_removed));
    end if;
  end if;

  if p_changes ? 'remove_files' then
    if jsonb_typeof(p_changes -> 'remove_files') <> 'array' then
      raise exception 'files must be a list' using errcode = '22023';
    end if;
    -- A file the page shows stays until the page no longer shows it.
    if exists (
         select 1 from public.post_files f
         where f.post_id = p_id
           and f.id::text in (select jsonb_array_elements_text(p_changes -> 'remove_files'))
           and (f.storage_path in (
                  select r #>> '{}' from jsonb_path_query(v_post.blocks,
                    'strict $.** ? (@.type == "photo").path') r)
                or f.library_file_id::text in (
                  select r #>> '{}' from jsonb_path_query(v_post.blocks,
                    'strict $.** ? (@.type == "file").library_file_id') r))) then
      raise exception 'the page shows this file; take it off the page first' using errcode = 'P0001';
    end if;
    -- The post's own files only. An upload goes to the cleanup once nothing
    -- references it.
    with gone as (
      delete from public.post_files f
      where f.post_id = p_id
        and f.id::text in (select jsonb_array_elements_text(p_changes -> 'remove_files'))
      returning 1)
    select count(*) into v_removed from gone;
  end if;
  if p_changes ? 'add_files' then
    v_added := public.add_post_files(v_post, p_changes -> 'add_files');
  end if;
  if v_added > 0 or v_removed > 0 then
    v_diff := v_diff || jsonb_build_object('files', jsonb_build_object('added', v_added, 'removed', v_removed));
  end if;

  if v_diff = '{}'::jsonb then
    return;
  end if;

  update public.space_posts
  set title = coalesce(v_title, title),
      body = case when p_changes ? 'body' then v_body else body end,
      place_text = case when p_changes ? 'place' then v_place else place_text end,
      due_date = case when p_changes ? 'due' then v_due else due_date end,
      pinned_until = case when p_changes ? 'pinned_until' then v_pinned else pinned_until end,
      starts_at = case when kind = 'activity' then v_starts else starts_at end,
      ends_at = case when kind = 'activity' then v_ends else ends_at end,
      edited_at = now()
  where id = p_id;
  -- The work item keeps the same words, for everything that reads it.
  if v_post.kind = 'work_item' then
    update public.work_items
    set title = coalesce(v_title, title),
        place_text = case when p_changes ? 'place' then v_place else place_text end,
        due_date = case when p_changes ? 'due' then v_due else due_date end
    where id = p_id
    returning owner_id into v_owner;
  end if;

  insert into public.post_edits (post_id, editor_id, changes)
  values (p_id, v_me, v_diff)
  returning id into v_edit;
  if v_owner is not null then
    perform public.add_notification(v_owner, 'item_edited', v_me, v_post.space_id, p_id,
                                    p_payload => jsonb_build_object('edit_id', v_edit));
  end if;
  -- A checklist's or an activity's people (and calendar adds), unless only
  -- people changed: those added were just told, those removed aren't.
  if v_post.kind in ('checklist', 'activity') and (v_diff - 'people') <> '{}'::jsonb then
    for v_person in
      select x.profile_id from (
        select pp.profile_id from public.post_people pp
        where pp.post_id = p_id and not (pp.profile_id = any (coalesce(v_new, '{}')))
        union
        select a.profile_id from public.post_acks a
        where a.post_id = p_id and a.kind = 'in_my_calendar') x
      where public.can_see_space_post_as(p_id, x.profile_id)
    loop
      perform public.add_notification(v_person.profile_id, 'item_edited', v_me, v_post.space_id,
                                      p_space_post => p_id,
                                      p_payload => jsonb_build_object('edit_id', v_edit));
    end loop;
  end if;
exception
  when invalid_text_representation then
    raise exception 'an id is not valid' using errcode = '22023';
end;
$function$;

-- Reading a post: its page, a walk's work items on the slip, a report's work items (as in 20261015180000_post_kinds.sql, with those changes only).
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
                                          'mime', lf.mime, 'bytes', lf.bytes)
                       order by a.created_at)
      from public.work_item_attachments a
      join public.library_files lf on lf.id = a.library_file_id
      where a.work_item_id = p_post.id and public.can_read_library_file(lf.id)),
    'blocks', p_post.blocks,
    'blocks_version', p_post.blocks_version,
    -- A report's work items, as this reader may see them (migration 20).
    'refs', (
      select jsonb_object_agg(c.id, jsonb_strip_nulls(jsonb_build_object(
               'title', c.title, 'ref', w.ref, 'item_status', w.status,
               'owner_name', public.space_person_name(w.owner_id),
               'checked_at', w.checked_at,
               'checker_name', public.space_person_name(w.checked_by),
               'done_photo_path', public.done_photo_path(w.id))))
      from public.space_posts c
      join public.work_items w on w.id = c.id
      where c.id::text in (select r #>> '{}' from jsonb_path_query(p_post.blocks,
                             'strict $.** ? (@.type == "item_ref").post_id') r)
        and c.space_id = p_post.space_id and c.deleted_at is null
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

-- Needs you: a target isn't its author's to sign (as in 20261015120000_daybook.sql, with that change only).
CREATE OR REPLACE FUNCTION public.item_needs_me(p_item work_items, p_post space_posts)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case
    when p_post.status <> 'live' or p_post.deleted_at is not null then null
    -- A target (work items under it, owned by its author) is done when they
    -- are checked; it doesn't wait in its author's Needs you.
    when p_item.status = 'open' and p_item.owner_id = auth.uid()
         and public.member_can(p_item.space_id, auth.uid(), 'mark_done')
         and not (p_post.author_id is not distinct from p_item.owner_id
                  and exists (select 1 from public.space_posts c
                              where c.parent_id = p_post.id and c.deleted_at is null
                                and c.status = 'live')) then 'open_owned'
    when p_item.status = 'done' and public.may_check(p_item, auth.uid()) then 'to_check'
    when p_item.status = 'open'
         and not public.member_can(p_item.space_id, p_item.owner_id, 'mark_done')
         and public.acts_for_author(p_post) then 'owner_left'
  end;
$function$;

-- Push: a batch's work items push once per owner (as in 20261015180000_post_kinds.sql, with that change only).
CREATE OR REPLACE FUNCTION public.handle_notification_push()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_settings public.push_settings;
  v_wanted boolean;
begin
  begin
    if not exists (select 1 from public.push_tokens t where t.profile_id = new.profile_id) then
      return null;
    end if;
    select * into v_settings from public.push_settings s where s.profile_id = new.profile_id;
    v_wanted := case
      -- A batch (walk, meeting notes) sends one push per owner itself.
      when new.kind = 'item_assigned' and current_setting('bv.batch', true) = 'on' then false
      when new.kind in ('item_assigned', 'item_done', 'item_checked', 'item_sent_back',
                        'item_comment', 'item_edited', 'item_cancelled', 'announcement_new',
                        'checklist_for_you', 'activity_invited', 'join_request')
        then public.space_push_level(new.space_id, new.profile_id) in ('all', 'needs_you')
      -- Only for Spaces set to everything (review 33 A2).
      when new.kind = 'file_new_version'
        then public.space_push_level(new.space_id, new.profile_id) = 'all'
      when new.kind = 'join_confirmed' then true
      when new.kind = 'role_confirmed' then true
      when new.kind = 'follow' then coalesce(v_settings.followers, true)
      when new.kind = 'post_reply' then coalesce(v_settings.replies, true)
      else false
    end;
    if v_wanted then
      insert into public.push_queue (profile_id, kind, actor_id, notification_id, data)
      values (new.profile_id, new.kind, new.actor_id, new.id,
              jsonb_strip_nulls(jsonb_build_object(
                'space_id', new.space_id, 'work_item_id', new.work_item_id,
                'post_id', new.post_id, 'request_id', new.request_id,
                'space_post_id', new.space_post_id)));
    end if;
  exception when others then
    -- A push problem never blocks the step that caused it.
    raise warning 'push queue (notification %): %', new.id, sqlerrm;
  end;
  return null;
end;
$function$;

-- Download my data: pages and the templates the person saved (as in 20261015230000_notebook.sql, with that change only).
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
                              'place', p.place_text, 'due_date', p.due_date,
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
    'post_people', coalesce((select jsonb_agg(jsonb_build_object(
                              'post', p.title, 'created_at', pp.created_at))
                            from public.post_people pp join public.space_posts p on p.id = pp.post_id
                            where pp.profile_id = r.profile_id), '[]'),
    'notes', coalesce((select jsonb_agg(jsonb_build_object(
                        'kind', n.kind, 'body', n.body, 'points', n.points,
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
    'push_settings', (select to_jsonb(ps) from public.push_settings ps where ps.profile_id = r.profile_id)
  )
  from public.data_requests r
  where r.id = p_request;
$function$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

-- search_fold, blocks_plain_text and search_snippet compute stored columns
-- as whoever writes the row, so the signed-in role keeps them.
revoke execute on function
  public.search_fold(text),
  public.blocks_plain_text(jsonb),
  public.search_snippet(text, text),
  public.can_read_template(public.post_templates),
  public.block_text_ok(jsonb, integer, integer),
  public.validate_blocks(public.space_posts, jsonb),
  public.save_blocks(uuid, jsonb, integer, jsonb),
  public.may_manage_templates(uuid),
  public.save_template(uuid, uuid, uuid, text),
  public.delete_template(uuid),
  public.space_templates(uuid),
  public.batch_pushes(uuid),
  public.create_walk(uuid, uuid, text, jsonb, text, uuid),
  public.create_from_message(uuid, uuid, uuid, text, jsonb),
  public.done_photo_path(uuid),
  public.daily_report_fill(uuid, uuid, timestamptz, timestamptz),
  public.week_report(uuid, date, timestamptz, timestamptz),
  public.share_week_report(uuid, uuid, date),
  public.search_space(uuid, text),
  public.create_space_post(uuid, uuid, text, text, text, uuid, text, date, timestamptz,
                           timestamptz, timestamptz, uuid, uuid[], jsonb, uuid, jsonb, jsonb,
                           uuid, jsonb)
  from public, anon;
-- Internal: answers about anyone, or writes without its own checks.
revoke execute on function
  public.block_text_ok(jsonb, integer, integer),
  public.validate_blocks(public.space_posts, jsonb),
  public.may_manage_templates(uuid),
  public.batch_pushes(uuid),
  public.done_photo_path(uuid)
  from authenticated;
-- The read rule calls it as the signed-in person.
grant execute on function public.can_read_template(public.post_templates) to authenticated;
grant execute on function
  public.search_fold(text),
  public.blocks_plain_text(jsonb),
  public.search_snippet(text, text),
  public.save_blocks(uuid, jsonb, integer, jsonb),
  public.save_template(uuid, uuid, uuid, text),
  public.delete_template(uuid),
  public.space_templates(uuid),
  public.create_walk(uuid, uuid, text, jsonb, text, uuid),
  public.create_from_message(uuid, uuid, uuid, text, jsonb),
  public.daily_report_fill(uuid, uuid, timestamptz, timestamptz),
  public.week_report(uuid, date, timestamptz, timestamptz),
  public.share_week_report(uuid, uuid, date),
  public.search_space(uuid, text),
  public.create_space_post(uuid, uuid, text, text, text, uuid, text, date, timestamptz,
                           timestamptz, timestamptz, uuid, uuid[], jsonb, uuid, jsonb, jsonb,
                           uuid, jsonb)
  to authenticated;
