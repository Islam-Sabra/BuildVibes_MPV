-- Migration 46 (review 95): one number for every post, and search by it.
--
-- - Every post in a Space takes the Space's next number as it goes in
--   (one before-insert trigger, the Space row locked as before): a note, a
--   work item, a checklist, an announcement, an activity, a file, a report.
--   Never a draft: drafts stay on the phone. A retried post id returns
--   before it inserts, so it never takes a second number.
-- - space_posts.number and space_posts.ref ("NST-031": the Space's prefix,
--   a dash, at least three digits). A work item's work_items.number and
--   ref are its post's, always: create_work_item no longer counts on its
--   own, and a check refuses any other.
-- - Gaps stay possible (another Team's post, a cancelled one), as for
--   work items before.
-- - Backfill (test data only; the pilot hasn't started): work item posts
--   keep their number; every other post takes the next numbers in its
--   Space, oldest first; then the counter goes past the highest.
-- - space_post_json returns ref for every kind, activity rows carry it,
--   and search_space finds a post by its number ("NST-023", "nst 23",
--   "023", "23", Arabic-Indic digits too), first and marked exact, under
--   the same reader rule.

-- A post's ref: the prefix, a dash, the number in at least three digits.
create or replace function public.post_ref(p_prefix text, p_number integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select p_prefix || '-' || lpad(p_number::text, greatest(3, length(p_number::text)), '0');
$$;

alter table public.space_posts
  add column number integer check (number >= 1),
  add column ref text;

-- Work item posts keep theirs.
update public.space_posts p
set number = w.number, ref = w.ref
from public.work_items w
where w.id = p.id;

-- Every other post: the next numbers in its Space, oldest first.
with numbered as (
  select p.id, s.ref_prefix,
         s.next_item_number - 1
           + row_number() over (partition by p.space_id order by p.created_at, p.id) as n
  from public.space_posts p
  join public.spaces s on s.id = p.space_id
  where p.number is null
)
update public.space_posts p
set number = x.n, ref = public.post_ref(x.ref_prefix, x.n::integer)
from numbered x
where x.id = p.id;

update public.spaces s
set next_item_number = greatest(
  s.next_item_number,
  coalesce((select max(p.number) from public.space_posts p where p.space_id = s.id), 0) + 1);

alter table public.space_posts
  alter column number set not null,
  alter column ref set not null,
  add constraint space_posts_space_number unique (space_id, number);

-- The one place a post is numbered.
create or replace function public.number_space_post()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prefix text;
begin
  update public.spaces s
  set next_item_number = s.next_item_number + 1
  where s.id = new.space_id
  returning s.next_item_number - 1, s.ref_prefix into new.number, v_prefix;
  new.ref := public.post_ref(v_prefix, new.number);
  return new;
end;
$$;

create trigger space_posts_number
before insert on public.space_posts
for each row execute function public.number_space_post();

-- A work item's number is its post's, always.
create or replace function public.work_item_number_is_post()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.space_posts p
                 where p.id = new.id and p.number = new.number and p.ref = new.ref) then
    raise exception 'a work item has its post''s number' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger work_items_number_is_post
before insert or update of number, ref on public.work_items
for each row execute function public.work_item_number_is_post();

revoke execute on function
  public.number_space_post(),
  public.work_item_number_is_post()
  from public, anon, authenticated;
grant execute on function public.post_ref(text, integer) to authenticated;
revoke execute on function public.post_ref(text, integer) from public, anon;

-- create_work_item: as in 20261017120000_daybook_extras.sql, numbered by its post.
create or replace function public.create_work_item(p_space uuid, p_title text, p_owner uuid, p_due date DEFAULT NULL::date, p_team uuid DEFAULT NULL::uuid, p_place text DEFAULT NULL::text, p_evidence jsonb DEFAULT '[]'::jsonb, p_id uuid DEFAULT NULL::uuid, p_body text DEFAULT NULL::text, p_parent uuid DEFAULT NULL::uuid, p_source_message uuid DEFAULT NULL::uuid, p_quote jsonb DEFAULT NULL::jsonb, p_files jsonb DEFAULT '[]'::jsonb, p_template uuid DEFAULT NULL::uuid, p_blocks jsonb DEFAULT NULL::jsonb, p_points jsonb DEFAULT NULL::jsonb, p_due_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me uuid := auth.uid();
  v_id uuid := coalesce(p_id, gen_random_uuid());
  v_post public.space_posts;
  v_parent public.space_posts;
  v_msg public.messages;
  v_thread_team uuid;
  v_team uuid := p_team;
  v_item public.work_items;
  v_number integer;
  v_prefix text;
  v_event uuid;
  v_template public.post_templates;
  v_point jsonb;
  v_sort integer := 0;
begin
  -- The same id again (a retry): the same post, if it is the caller's.
  select * into v_post from public.space_posts where id = v_id;
  if v_post.id is not null then
    if v_post.author_id = v_me and v_post.space_id = p_space and v_post.kind = 'work_item' then
      return v_post.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if not public.can(p_space, 'create_items') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if public.folder_has_others_files(p_space, v_id)
     or public.folder_has_others_files_in(p_space::text || '/posts/' || v_id::text || '/') then
    raise exception 'this id is taken' using errcode = '42501';
  end if;
  if p_title is null or length(trim(p_title)) not between 2 and 140 then
    raise exception 'a title of 2 to 140 characters' using errcode = '22023';
  end if;
  if length(p_body) > 5000 then
    raise exception 'at most 5000 characters' using errcode = '22023';
  end if;
  if p_owner is null or not public.member_can(p_space, p_owner, 'mark_done') then
    raise exception 'choose an owner who can sign it as done' using errcode = '22023';
  end if;
  if v_team is not null and not exists (
       select 1 from public.teams t where t.id = v_team and t.space_id = p_space) then
    raise exception 'team not in this Space' using errcode = '22023';
  end if;
  if p_quote is not null and not public.is_valid_post_quote(p_quote) then
    raise exception 'a quote needs its text' using errcode = '22023';
  end if;

  -- Under one work item: a live, top-level work item the caller can see in
  -- this Space. A child of a Team item stays in that Team.
  if p_parent is not null then
    -- For share: a Cancel or Delete of the parent running now finishes
    -- first, and the checks below see its result.
    select * into v_parent from public.space_posts where id = p_parent for share;
    -- Only under your own work item, or one you act for (review 34 D1).
    if v_parent.id is null or v_parent.space_id <> p_space or v_parent.kind <> 'work_item'
       or not public.can_see_space_post(v_parent.id)
       or not public.acts_for_author(v_parent) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if v_parent.status <> 'live' or v_parent.parent_id is not null then
      raise exception 'work items go under one live work item, one level only' using errcode = '22023';
    end if;
    if v_parent.team_id is not null then
      if v_team is null then
        v_team := v_parent.team_id;
      elsif v_team <> v_parent.team_id then
        raise exception 'a work item under a Team item stays in that Team' using errcode = '22023';
      end if;
    end if;
  end if;

  -- From a chat message the caller can read; a Team thread's message stays
  -- in that Team, so Team chat never becomes an Everyone post.
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

  -- From a work item template (migration 20): one the caller may read in
  -- this Space, for the same Team.
  if p_template is not null then
    select * into v_template from public.post_templates t where t.id = p_template;
    if v_template.id is null or not public.can_read_template(v_template)
       or (v_template.space_id is not null and v_template.space_id <> p_space) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if v_template.kind <> 'work_item'
       or (v_template.team_id is not null and v_template.team_id is distinct from v_team) then
      raise exception 'this template is for another kind of post or Team' using errcode = '22023';
    end if;
  end if;
  if p_points is not null and (jsonb_typeof(p_points) <> 'array'
                               or jsonb_array_length(p_points) > 50) then
    raise exception 'at most 50 points' using errcode = '22023';
  end if;
  if p_due_at is not null and not public.due_at_fits(p_due, p_due_at) then
    raise exception 'a due time on its due day' using errcode = '22023';
  end if;

  insert into public.space_posts (id, space_id, team_id, kind, author_id, title, body,
                                  place_text, due_date, due_at, parent_id, source_message_id,
                                  quote, template_id)
  values (v_id, p_space, v_team, 'work_item', v_me, trim(p_title), nullif(trim(p_body), ''),
          nullif(trim(p_place), ''), p_due, p_due_at, p_parent, p_source_message, p_quote,
          p_template)
  returning * into v_post;

  -- Migration 46: the post took the Space's next number as it went in;
  -- the work item has the same one.
  v_number := v_post.number;

  insert into public.work_items (id, space_id, number, ref, title, owner_id, created_by,
                                 team_id, place_text, due_date)
  values (v_id, p_space, v_number, v_post.ref,
          trim(p_title), p_owner, v_me, v_team, nullif(trim(p_place), ''), p_due)
  returning * into v_item;

  insert into public.work_item_events (work_item_id, actor_id, kind)
  values (v_id, v_me, 'raised')
  returning id into v_event;
  perform public.add_evidence(v_item, v_event, p_evidence);
  perform public.add_post_files(v_post, p_files);
  -- Its points and page (migration 20).
  for v_point in select * from jsonb_array_elements(coalesce(p_points, '[]'::jsonb)) loop
    if jsonb_typeof(v_point) <> 'object' then
      raise exception 'a point must be an object' using errcode = '22023';
    end if;
    insert into public.checklist_points (id, post_id, sort, text)
    values (coalesce(nullif(v_point ->> 'id', '')::uuid, gen_random_uuid()), v_id, v_sort,
            public.point_text(v_point ->> 'text'));
    v_sort := v_sort + 1;
  end loop;
  if p_blocks is not null then
    perform public.validate_blocks(v_post, p_blocks);
    update public.space_posts set blocks = p_blocks where id = v_id;
  end if;
  return v_id;
end;
$function$;

-- space_post_json: as in 20261029120000_review80_batch.sql, with the post's ref for every kind.
create or replace function public.space_post_json(p_post space_posts, p_full boolean)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  -- Migration 46: every post's own number, as its ref (NST-031).
  select jsonb_strip_nulls(jsonb_build_object('ref', p_post.ref) || jsonb_build_object(
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
        'version_no', lf.version_no,
        'replaces', (select jsonb_build_object('name', o.name, 'rev_label', o.rev_label,
                                               'bytes', o.bytes, 'version_no', o.version_no)
                     from public.library_files o where o.id = lf.supersedes_id),
        -- The version in use now, when this one isn't (F76): its number, when
        -- it came, and the newest post carrying it the reader can see.
        'newer', (select jsonb_build_object(
                           'version_no', n.version_no, 'at', n.created_at,
                           'post_id', (select sp.id from public.space_posts sp
                                       where sp.library_file_id = n.id and sp.deleted_at is null
                                         and sp.status = 'live'
                                         and public.can_see_space_post(sp.id)
                                       order by sp.created_at desc limit 1))
                  from public.library_files n
                  where n.chain_id = lf.chain_id and n.version_no > lf.version_no
                    and n.deleted_at is null and public.can_read_library_file(n.id)
                  order by n.version_no desc limit 1),
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
        -- A target (a walk, meeting notes): its work items fold into its
        -- card (migration 37).
        'target', public.is_target(p_post.id),
        -- Up to 30 (a walk's most), each with what it needs of the reader.
        'rows', (select jsonb_agg(r.row order by r.created_at, r.id) from (
                   select c2.id, c2.created_at, jsonb_strip_nulls(jsonb_build_object(
                            'id', c2.id, 'title', c2.title, 'item_status', w2.status,
                            'ref', w2.ref,
                            'needs_me', public.card_needs_me(c2),
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
                   limit 30) r))
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

-- activity_rows: as in 20261019180000_slice2_cards.sql; a row about any post carries its ref.
create or replace function public.activity_rows()
 RETURNS SETOF activity_row
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with mine as (
    select n.*,
           case when n.kind in ('role_confirmed', 'content_removed', 'appeal_decided') then 'record'
                when n.kind = 'follow' then 'network'
                when n.kind in ('post_reply', 'post_useful') then 'posts'
                else 'space' end as group_kind
    from public.notifications n
    where n.profile_id = auth.uid()
      and n.created_at >= now() - interval '30 days'
      and not public.blocked_between(auth.uid(), n.actor_id)
  ),
  shown as (
    select r.*, s.name as space_name, m.pass, coalesce(w.ref, sp.ref) as ref,
           coalesce(w.title, sp.title) as title,
           sp.kind as post_kind,
           case when r.kind = 'post_reply' then left(pr.body, 120)
                when r.post_id is not null then left(p.body, 120) end as context,
           jr.status as request_status, cp.project_id, prj.name as project_name,
           nullif(trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')), '')
             as actor_name
    from mine r
    left join public.spaces s on s.id = r.space_id
    left join public.space_members m
      on m.space_id = r.space_id and m.profile_id = auth.uid() and m.left_at is null
    left join public.work_items w on w.id = r.work_item_id
    left join public.space_posts sp on sp.id = r.space_post_id
    left join public.posts p on p.id = r.post_id
    left join public.post_replies pr on pr.id = r.reply_id
    left join public.space_join_requests jr on jr.id = r.request_id
    left join public.cv_projects cp on cp.id = (r.payload ->> 'cv_project_id')::uuid
    left join public.projects prj on prj.id = cp.project_id
    left join public.profiles a on a.id = r.actor_id
    where (r.space_id is null or (s.deleted_at is null and m.profile_id is not null))
      -- Requests to join only while you are still an admin.
      and (r.kind <> 'join_request' or m.is_admin)
      -- Post rows only while you may see the post (not across a block).
      and (r.post_id is null or public.can_see_post(r.post_id))
      and (r.reply_id is null or pr.deleted_at is null)
      -- A reply you reported, with its text, leaves your Activity (review 24).
      and (r.reply_id is null or not public.reported_by_me('reply', r.reply_id))
      and (r.kind <> 'role_confirmed' or cp.id is not null)
      -- A work item row only while you may see it (a deleted post leaves).
      and (r.work_item_id is null or public.can_see_space_post(r.work_item_id))
      and (r.space_post_id is null or public.can_see_space_post(r.space_post_id))
  )
  select x.id, x.kind, x.group_kind, x.space_id, x.space_name, x.pass,
         x.work_item_id, x.ref, x.title, x.post_id, x.reply_id, x.context,
         x.request_id, x.request_status, x.project_id, x.project_name,
         x.actor_id, x.actor_name, x.payload, x.created_at, x.read_at,
         (row_number() over (partition by x.group_kind, x.space_id
                             order by x.created_at, x.id))::int,
         case when x.kind = 'post_useful' then
           array(select u.name from public.useful_names(x.post_id) u) end,
         x.space_post_id, x.post_kind
  from shown x;
$function$;

-- Search (as in 20261029120000_review80_batch.sql) gains the exact
-- number hit, first. A new column changes the return type, so the
-- function is dropped and made again, with the same grants.
drop function public.search_space(uuid, text);
create function public.search_space(p_space uuid, p_q text)
returns table (kind text, id uuid, post_id uuid, thread_id uuid, team_id uuid, post_kind text,
               post_status text, ref text, title text, snippet text, author_name text,
               created_at timestamptz, mine boolean, exact boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := public.search_fold(regexp_replace(trim(coalesce(p_q, '')), '\s+', ' ', 'g'));
  v_raw text := upper(translate(trim(coalesce(p_q, '')),
                                '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
                                '01234567890123456789'));
  v_parts text[];
  v_number integer;
  v_pat text;
  v_threads uuid[];
begin
  if char_length(v_q) > 100 then
    raise exception 'search too long' using errcode = '22023';
  end if;
  if not public.is_member(p_space) then
    return;
  end if;
  -- "NST-023", "NST023", "nst 23", "023", "23": this Space's prefix, or
  -- none, then the number.
  v_parts := regexp_match(v_raw, '^([A-Z]{2,4})?[ -]?0*([0-9]{1,9})$');
  if v_parts is not null and v_parts[2] <> ''
     and (v_parts[1] is null
          or v_parts[1] = (select s.ref_prefix from public.spaces s where s.id = p_space)) then
    v_number := v_parts[2]::integer;
  end if;
  if char_length(v_q) < 2 and v_number is null then
    return;
  end if;
  v_pat := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_threads := array(select t.id from public.threads t
                     where t.space_id = p_space and public.can_use_thread(t.id));

  return query
  with hits as (
    (select 'post'::text as kind, p.id, p.id as post_id, null::uuid as thread_id, p.team_id,
            p.kind as post_kind, p.status as post_status, p.ref, p.title,
            null::text as snippet, p.author_id, p.created_at, true as exact
     from public.space_posts p
     where p.space_id = p_space and p.number = v_number and p.deleted_at is null
       and (p.team_id is null or public.can_see_space_post(p.id)))
    union all
    (select 'post'::text, p.id, p.id, null::uuid, p.team_id,
            p.kind, p.status, p.ref, p.title,
            case when public.search_fold(p.title) like v_pat then null
                 else public.search_snippet(
                   coalesce(p.body, '') || ' ' || public.blocks_plain_text(p.blocks), v_q)
            end,
            p.author_id, p.created_at, false
     from public.space_posts p
     where p.space_id = p_space and p.deleted_at is null
       and p.number is distinct from v_number
       and p.search_text like v_pat
       and (p.team_id is null or public.can_see_space_post(p.id))
     order by p.created_at desc, p.id desc limit 30)
    union all
    (select 'point', c.id, p.id, null, p.team_id, p.kind, p.status, p.ref, p.title, c.text,
            p.author_id, c.created_at, false
     from public.checklist_points c
     join public.space_posts p on p.id = c.post_id
     where p.space_id = p_space and p.deleted_at is null
       and c.search_text like v_pat
       and (p.team_id is null or public.can_see_space_post(p.id))
     order by c.created_at desc, c.id desc limit 30)
    union all
    (select 'message', m.id, null, m.thread_id, t.team_id, null, null, null, null,
            public.search_snippet(m.body, v_q), m.author_id, m.created_at, false
     from public.messages m
     join public.threads t on t.id = m.thread_id
     where m.space_id = p_space and m.thread_id = any (v_threads)
       and m.deleted_at is null and m.body is not null
       and m.search_text like v_pat
       and not public.reported_by_me('message', m.id)
     order by m.created_at desc, m.id desc limit 30)
    union all
    (select 'file', f.id, null, null, f.team_id, null, null, null, f.name, f.rev_label,
            f.uploaded_by, f.created_at, false
     from public.library_files f
     where f.space_id = p_space and f.deleted_at is null
       and f.search_text like v_pat
       and (f.team_id is null or public.can_read_library_file(f.id))
       and public.library_file_in_force(f.id)
     order by f.created_at desc, f.id desc limit 30)
  )
  select h.kind, h.id, h.post_id, h.thread_id, h.team_id, h.post_kind, h.post_status, h.ref,
         h.title, h.snippet, public.space_person_name(h.author_id), h.created_at,
         coalesce(h.author_id = auth.uid(), false), h.exact
  from hits h
  -- The full rules again on at most 121 rows, so a later change to the
  -- short-cuts above can't leak.
  where (h.post_id is null or public.can_see_space_post(h.post_id))
    and (h.kind <> 'file' or public.can_read_library_file(h.id))
  order by h.exact desc, h.created_at desc, h.id desc
  limit 30;
end;
$$;

revoke execute on function public.search_space(uuid, text) from public, anon;
grant execute on function public.search_space(uuid, text) to authenticated;
