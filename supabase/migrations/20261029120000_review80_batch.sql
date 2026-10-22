-- Migration 38: the fix batch from the build 473 test (review 80 §C).
-- Branch claude/review80. Not live. After 36 and 37 (live); migration 34
-- is dated after this one, 20261030120000 (review 81 §5).
--
-- - F75: the app numbers a Library file's versions V1, V2, V3… in the
--   order they were added. library_files.version_no is set on insert as
--   the chain's highest plus one, under a lock on the chain's id, and
--   never changes (unique in its chain, review 81 R1); a removed version's number is never used again.
--   chain_id is the chain's first file. Existing chains are numbered by
--   created_at. The post JSON's file says its number, the one it replaces,
--   and (F76) the version in use now when this one isn't.
-- - F94: a walk's work items keep the order of its photos: create_walk
--   gives each one created_at now() plus its place in microseconds (rows
--   order by created_at, id). Walks already posted keep their order.
-- - F86: the author (or whoever acts for the author) never gives Got it on
--   their own announcement: ack(got_it) from them is refused.
-- - Search (review 80, small): each hit says whether the reader wrote it
--   (search_space's new column mine), so the app says "You" there as
--   everywhere else, never the reader's own name.
-- - F81: a phone's push token says which install it came from
--   (push_tokens.install_id). Registering replaces only that install's old
--   token, so a person's phone and tablet both keep theirs. The push
--   function keeps FCM's answer for each phone on the queue row
--   (push_queue.answers). The function goes live after this migration.

-- F75 ------------------------------------------------------------------------------------------

alter table public.library_files
  -- No foreign key: the chain keeps its first file's id even if that row goes.
  add column chain_id uuid,
  add column version_no integer check (version_no >= 1);

-- Existing chains: the first file of each, then numbers by created_at.
with recursive chain as (
  select f.id, f.id as root from public.library_files f where f.supersedes_id is null
  union all
  select f.id, c.root from public.library_files f join chain c on f.supersedes_id = c.id
)
update public.library_files f set chain_id = c.root from chain c where c.id = f.id;
-- A file whose older version is gone (supersedes_id set null) starts its own chain.
update public.library_files set chain_id = id where chain_id is null;
update public.library_files f set version_no = n.no
from (select id, row_number() over (partition by chain_id order by created_at, id) as no
      from public.library_files) n
where n.id = f.id;

alter table public.library_files alter column version_no set not null;
-- Review 81 R1: a number is used once in its chain. The trigger's lock
-- keeps two versions added at once apart; if anything ever slipped by it,
-- the second would be refused here, never saved twice.
create unique index library_files_chain_version_uidx
  on public.library_files (chain_id, version_no);

create function public.library_file_number()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_chain uuid;
begin
  if tg_op = 'UPDATE' then
    -- Never renumbered.
    new.version_no := old.version_no;
    new.chain_id := old.chain_id;
    return new;
  end if;
  select coalesce(o.chain_id, o.id) into v_chain
  from public.library_files o where o.id = new.supersedes_id;
  if v_chain is null then
    new.chain_id := new.id;
    new.version_no := 1;
    return new;
  end if;
  -- Two versions added at once wait here, one after the other: 2, then 3.
  -- The lock is on the chain's id, not on its first file's row, so it
  -- holds even if that row is ever removed for good (review 81 R1).
  perform pg_advisory_xact_lock(hashtextextended('library_files.chain:' || v_chain, 0));
  new.chain_id := v_chain;
  new.version_no := coalesce((select max(f.version_no) from public.library_files f
                              where f.chain_id = v_chain), 0) + 1;
  return new;
end;
$$;

create trigger library_files_number
  before insert or update on public.library_files
  for each row execute function public.library_file_number();

revoke execute on function public.library_file_number() from public, anon, authenticated;

-- The post JSON's file, with its number and the version in use (F75, F76).
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

-- F94 ------------------------------------------------------------------------------------------

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
  v_n bigint;
begin
  -- A retry running at the same time waits here, then returns the parent.
  perform pg_advisory_xact_lock(hashtextextended('batch:' || coalesce(p_parent::text, ''), 0));
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
  if (select count(distinct (x ->> 'id')::uuid) from jsonb_array_elements(p_items) x)
     <> jsonb_array_length(p_items)
     or exists (select 1 from jsonb_array_elements(p_items) x
                where jsonb_typeof(x -> 'photo') is distinct from 'object'
                   or (x ->> 'id') is null or (x ->> 'id')::uuid = p_parent) then
    raise exception 'each photo has its own id and its photo' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_array_elements(p_items) x
             join public.space_posts p on p.id = (x ->> 'id')::uuid) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  perform set_config('bv.batch', 'on', true);
  perform public.create_work_item(p_space, p_title, v_me, null, p_team, p_place, '[]'::jsonb,
                                  p_parent);
  for v_item, v_n in select x, n from jsonb_array_elements(p_items) with ordinality t(x, n) loop
    perform public.create_work_item(p_space, v_item ->> 'line', (v_item ->> 'owner')::uuid, null,
                                    p_team, p_place, '[]'::jsonb, (v_item ->> 'id')::uuid,
                                    p_parent => p_parent,
                                    p_files => jsonb_build_array(v_item -> 'photo'));
    -- The photos' order (F94): one transaction gives them all one now().
    update public.space_posts
    set created_at = now() + make_interval(secs => v_n / 1000000.0),
        last_activity_at = now() + make_interval(secs => v_n / 1000000.0)
    where id = (v_item ->> 'id')::uuid;
  end loop;
  perform public.batch_pushes(p_parent);
  perform set_config('bv.batch', 'off', true);
  return p_parent;
exception
  when invalid_text_representation then
    raise exception 'an id is not valid' using errcode = '22023';
end;
$$;

-- F86 ------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.ack(p_post uuid, p_kind text, p_on boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_end timestamptz;
begin
  select * into v_post from public.space_posts where id = p_post for update;
  if v_post.id is null or not public.can_see_space_post(v_post.id)
     or public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  -- A note takes no acknowledgement (migration 29): it isn't in this list.
  if (v_post.kind, p_kind) not in (('announcement', 'got_it'), ('file', 'received'),
                                   ('activity', 'on_my_way'), ('activity', 'in_my_calendar')) then
    raise exception 'that doesn''t go on this kind of post' using errcode = '22023';
  end if;

  -- The author never confirms their own announcement (review 61 G1, F86):
  -- they see the faces of who did.
  if p_kind = 'got_it' and coalesce(p_on, true)
     and (v_me = v_post.author_id or public.acts_for_author(v_post)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if not coalesce(p_on, true) then
    delete from public.post_acks where post_id = p_post and profile_id = v_me and kind = p_kind;
    return;
  end if;
  if v_post.status <> 'live' or v_post.deleted_at is not null then
    raise exception 'this was cancelled' using errcode = 'P0001';
  end if;
  if v_post.kind = 'activity' then
    v_end := coalesce(v_post.ends_at, v_post.starts_at + interval '1 hour');
    if now() >= v_end
       or (p_kind = 'on_my_way' and now() < v_post.starts_at - interval '3 hours') then
      raise exception 'not at this time' using errcode = 'P0001';
    end if;
  end if;
  -- Got it given again after an edit (migration 29, review 61 G1): it takes
  -- the new time, so my_ack_at is later than the edit. Only Got it (review
  -- 63 R2): Received keeps its first time, the record of receipt. Otherwise
  -- a second tap changes nothing.
  insert into public.post_acks as a (post_id, profile_id, kind) values (p_post, v_me, p_kind)
  on conflict (post_id, profile_id, kind) do update set created_at = now()
  where a.kind = 'got_it' and a.created_at < v_post.edited_at;
  if v_me is distinct from v_post.author_id then
    insert into public.post_others (post_id) values (p_post) on conflict do nothing;
  end if;
end;
$function$;

-- F81 ------------------------------------------------------------------------------------------

alter table public.push_tokens add column install_id uuid;
create index push_tokens_install_idx on public.push_tokens (install_id) where install_id is not null;
alter table public.push_queue add column answers jsonb
  check (answers is null or (jsonb_typeof(answers) = 'array' and jsonb_array_length(answers) <= 20));

drop function public.register_push_token(text, text, text);
create function public.register_push_token(
  p_token text,
  p_platform text,
  p_locale text default 'en',
  p_install uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_token is null or length(p_token) not between 20 and 4096 then
    raise exception 'not a push token' using errcode = '22023';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'android or ios' using errcode = '22023';
  end if;
  -- This install's old token goes (it changed); the person's other phones
  -- keep theirs.
  if p_install is not null then
    delete from public.push_tokens t
    where t.install_id = p_install and t.token <> p_token;
  end if;
  insert into public.push_tokens (token, profile_id, platform, locale, install_id, updated_at)
  values (p_token, auth.uid(), p_platform,
          case when p_locale = 'ar' then 'ar' else 'en' end, p_install, clock_timestamp())
  on conflict (token) do update
  set profile_id = excluded.profile_id, platform = excluded.platform,
      locale = excluded.locale, install_id = coalesce(excluded.install_id, push_tokens.install_id),
      updated_at = excluded.updated_at;
  delete from public.push_tokens t
  where t.profile_id = auth.uid()
    and t.token not in (select k.token from public.push_tokens k
                        where k.profile_id = auth.uid()
                        order by k.updated_at desc limit 10);
end;
$$;

drop function public.finish_push(bigint, text);
create function public.finish_push(p_id bigint, p_error text default null,
                                   p_answers jsonb default null)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.push_queue
  set sent_at = now(), message_text = null, claimed_at = null, error = left(p_error, 500),
      answers = p_answers
  where id = p_id;
$$;

drop function public.release_push(bigint, interval, text);
create function public.release_push(p_id bigint, p_wait interval default null,
                                    p_error text default null, p_answers jsonb default null)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.push_queue
  set claimed_at = null,
      not_before = case when p_wait is null or attempts >= 5 then null else now() + p_wait end,
      sent_at = case when attempts >= 5 then now() end,
      message_text = case when attempts >= 5 then null else message_text end,
      error = left(p_error, 500),
      answers = p_answers
  where id = p_id and sent_at is null;
$$;

revoke execute on function
  public.register_push_token(text, text, text, uuid),
  public.finish_push(bigint, text, jsonb),
  public.release_push(bigint, interval, text, jsonb)
  from public, anon;
revoke execute on function
  public.finish_push(bigint, text, jsonb),
  public.release_push(bigint, interval, text, jsonb)
  from authenticated;
grant execute on function public.register_push_token(text, text, text, uuid) to authenticated;
grant execute on function
  public.finish_push(bigint, text, jsonb),
  public.release_push(bigint, interval, text, jsonb)
  to service_role;

-- Search: as in 20261022120000_library_receipts.sql, with one more column:
-- mine, the reader wrote it. A new column changes the return type, so the
-- function is dropped and made again, with the same grants.
drop function public.search_space(uuid, text);
create function public.search_space(p_space uuid, p_q text)
returns table (kind text, id uuid, post_id uuid, thread_id uuid, team_id uuid, post_kind text,
               post_status text, ref text, title text, snippet text, author_name text,
               created_at timestamptz, mine boolean)
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
       and public.library_file_in_force(f.id)
     order by f.created_at desc, f.id desc limit 30)
  )
  select h.kind, h.id, h.post_id, h.thread_id, h.team_id, h.post_kind, h.post_status, h.ref,
         h.title, h.snippet, public.space_person_name(h.author_id), h.created_at,
         coalesce(h.author_id = auth.uid(), false)
  from hits h
  -- The full rules again on at most 120 rows, so a later change to the
  -- short-cuts above can't leak.
  where (h.post_id is null or public.can_see_space_post(h.post_id))
    and (h.kind <> 'file' or public.can_read_library_file(h.id))
  order by h.created_at desc, h.id desc
  limit 30;
end;
$$;

revoke execute on function public.search_space(uuid, text) from public, anon;
grant execute on function public.search_space(uuid, text) to authenticated;
