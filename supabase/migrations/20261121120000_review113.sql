-- Migration 60 (review 113): the founder's test of the Space and the
-- notebook (1 Nov 2026). The server side, as the review's contract says.
--
-- 1. Reactions (RX1): Like, Heart or Bravo, one per person per post; the
--    same again takes it back, another replaces it. Never on a check-in.
--    The card shows who reacted (faces, never a number), and the author
--    gets one quiet push, grouped: at most one per post per 10 minutes.
-- 2. Share into the Space's Chat: share_post_to_thread (migration 52) as it
--    is; its checks are confirmed in the tests.
-- 3. Hold a post: the card's "hold" says Delete (my post, nobody acted) or
--    Archive (my post, someone acted); reactions don't count; a Checked
--    work item has neither. Delete is refused once someone acted.
--    Archiving an open work item stops it (no sign-off, no check, no
--    reminder) and tells its owner once.
-- 4. The check-in nudge (17): a Space that used check-in before, a working
--    day, no check-in running today, 30 minutes before its usual time: one
--    push to the last check-in's creator if still a Lead there.
-- 5. Need you now (18): a call on the strong channel to someone in a shared
--    Space, not a Viewer, not across a block, at most 3 an hour to the same
--    person; answered once, On my way or Can't now.
-- 6. Library folders (8) and link folders (9): each shared with only me, a
--    person, a Team or the whole Space; a file in a folder inherits its
--    sharing (can_read_library_file, which every Library read goes through).
--    A link folder is a OneDrive, Google Drive or Dropbox https link.
--
-- The lock-screen rule (migration 14, push_settings.message_text, off unless
-- the person turned it on): only then does a push carry a title, a Space's
-- name, a person's name, a reason or a place (check_in_shows_text).

-- ---------------------------------------------------------------------------
-- 1. Reactions
-- ---------------------------------------------------------------------------

create table public.post_reactions (
  post_id uuid not null references public.space_posts (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('like', 'heart', 'bravo')),
  created_at timestamptz not null default now(),
  primary key (post_id, profile_id)
);
create index post_reactions_profile_idx on public.post_reactions (profile_id);

alter table public.post_reactions enable row level security;
create policy post_reactions_read on public.post_reactions
  for select to authenticated
  using (public.can_see_space_post(post_id));
revoke all on public.post_reactions from public, anon, authenticated;
grant select on public.post_reactions to authenticated;
grant all on public.post_reactions to service_role;

-- The card's "reactions": each kind with at least one person, Like, Heart,
-- Bravo in that order; its people newest first, at most 20, named as the
-- reader may see them (space_person_name: blocked and hidden people have
-- none). Never a count. A check-in has none.
create or replace function public.post_reactions_json(p_post public.space_posts)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_post.kind = 'check_in' then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object('kind', k.kind, 'people', k.people) order by k.ord)
    from (
      select x.kind, x.ord,
             (select jsonb_agg(jsonb_build_object('id', r.profile_id,
                                                  'name', public.space_person_name(r.profile_id))
                               order by r.created_at desc, r.profile_id)
              from (select * from public.post_reactions r
                    where r.post_id = p_post.id and r.kind = x.kind
                    order by r.created_at desc, r.profile_id
                    limit 20) r) as people
      from (values ('like', 1), ('heart', 2), ('bravo', 3)) x(kind, ord)
    ) k
    where k.people is not null), '[]'::jsonb) end;
$$;

-- RX1: the caller's reaction to [p_post]: [p_kind] sets it; the same kind
-- again takes it back; another kind replaces it. Returns the kind held now,
-- or null. The author gets one quiet push per post per 10 minutes (later
-- reactions in the window send nothing new), never for their own.
create or replace function public.react_to_post(p_post uuid, p_kind text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_old text;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  select * into v_post from public.space_posts where id = p_post;
  if v_post.id is null or v_post.deleted_at is not null
     or not public.is_member(v_post.space_id) or public.is_hidden_account(v_me)
     or not public.can_see_space_post(p_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_post.kind = 'check_in' then
    raise exception 'no reactions on a check-in' using errcode = '22023';
  end if;
  if p_kind is null or p_kind not in ('like', 'heart', 'bravo') then
    raise exception 'like, heart or bravo' using errcode = '22023';
  end if;

  select r.kind into v_old from public.post_reactions r
  where r.post_id = p_post and r.profile_id = v_me
  for update;
  if v_old = p_kind then
    delete from public.post_reactions where post_id = p_post and profile_id = v_me;
    return null;
  end if;
  insert into public.post_reactions as r (post_id, profile_id, kind)
  values (p_post, v_me, p_kind)
  on conflict (post_id, profile_id) do update set kind = excluded.kind, created_at = now();

  -- One push per post per 10 minutes: two reactions at once can't both send.
  perform pg_advisory_xact_lock(hashtextextended('post_reaction:' || p_post::text, 0));
  insert into public.push_queue (profile_id, kind, actor_id, data)
  select v_post.author_id, 'post_reaction', v_me,
         jsonb_build_object('post_id', p_post, 'space_id', v_post.space_id, 'kind', p_kind)
         || case when public.check_in_shows_text(v_post.author_id)
                 then jsonb_build_object('title', v_post.title,
                                         'space_name', (select s.name from public.spaces s
                                                        where s.id = v_post.space_id))
                 else '{}'::jsonb end
  where v_post.author_id is not null and v_post.author_id <> v_me
    and public.can_see_space_post_as(p_post, v_post.author_id)
    and not exists (select 1 from public.blocks b
                    where (b.blocker_id = v_me and b.blocked_id = v_post.author_id)
                       or (b.blocker_id = v_post.author_id and b.blocked_id = v_me))
    and public.space_push_level(v_post.space_id, v_post.author_id) = 'all'
    and exists (select 1 from public.push_tokens t where t.profile_id = v_post.author_id)
    and not exists (select 1 from public.push_queue q
                    where q.kind = 'post_reaction' and q.profile_id = v_post.author_id
                      and q.data ->> 'post_id' = p_post::text
                      and q.created_at > now() - interval '10 minutes');
  return p_kind;
end;
$$;

-- A reaction changes its card for everyone who reads it (migration 44's
-- broadcast, as an acknowledgement does).
create trigger post_reactions_broadcast_insert after insert on public.post_reactions
  referencing new table as new_rows
  for each statement execute function public.handle_post_row_broadcast();
create trigger post_reactions_broadcast_update after update on public.post_reactions
  referencing new table as new_rows
  for each statement execute function public.handle_post_row_broadcast();
create trigger post_reactions_broadcast_delete after delete on public.post_reactions
  referencing old table as old_rows
  for each statement execute function public.handle_post_row_broadcast();

-- ---------------------------------------------------------------------------
-- 3. Hold: Delete or Archive
-- ---------------------------------------------------------------------------

-- Someone has acted on [p_post]: what ended Delete before (post_has_others:
-- an update, a sign-off, a check, a file, a tick, Got it, a work item under
-- it), and a check-in mark. Reactions never count.
create or replace function public.post_has_action(p_post public.space_posts)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.post_has_others(p_post)
      or exists (select 1 from public.check_in_marks k where k.post_id = p_post.id);
$$;

-- The card's "hold" for the reader: 'delete' (my post, nobody acted),
-- 'archive' (my post, someone acted), or null (someone else's post, a
-- Checked work item, or one already archived).
create or replace function public.post_hold(p_post public.space_posts)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when auth.uid() is null or p_post.author_id is distinct from auth.uid() then null
    when p_post.deleted_at is not null or p_post.archived_at is not null then null
    when public.is_hidden_account(auth.uid()) then null
    when exists (select 1 from public.work_items w
                 where w.id = p_post.id and w.status = 'checked') then null
    when public.post_has_action(p_post) then 'archive'
    else 'delete'
  end;
$$;

-- delete_space_post (migration 18), as it was, and refused with 22023
-- 'someone has acted on it' (was P0001) once someone acted, a check-in
-- mark included, and always for a Checked work item.
create or replace function public.delete_space_post(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post public.space_posts;
begin
  select * into v_post from public.space_posts where id = p_id for update;
  if v_post.id is null or v_post.author_id is distinct from auth.uid()
     or not public.is_member(v_post.space_id) or public.is_hidden_account(auth.uid()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_post.deleted_at is not null then
    return;
  end if;
  if v_post.kind = 'work_item' then
    perform 1 from public.work_items where id = p_id for update;
  end if;
  if public.post_has_action(v_post)
     or exists (select 1 from public.work_items w where w.id = p_id and w.status = 'checked') then
    raise exception 'someone has acted on it' using errcode = '22023';
  end if;
  update public.space_posts set deleted_at = now() where id = p_id;
end;
$$;

-- archive_space_post (migration 52), as it was (a Lead archives a Checked
-- work item, review 105B), and the author's Archive: my post someone acted
-- on, never a Checked work item. Archiving an open work item (open, or done
-- and waiting for its check) stops it: its waiting reminders go, it can no
-- longer be signed or checked (refuse_archived_item) or reminded
-- (refuse_archived_reminder), and its owner gets one push.
create or replace function public.archive_space_post(p_post uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_item public.work_items;
begin
  select * into v_post from public.space_posts where id = p_post for update;
  if v_post.id is not null and v_me is not null and v_post.author_id = v_me
     and v_post.deleted_at is null and public.is_member(v_post.space_id)
     and not public.is_hidden_account(v_me)
     and not exists (select 1 from public.work_items w
                     where w.id = p_post and w.status = 'checked')
     and public.post_has_action(v_post) then
    if v_post.archived_at is not null then
      return;
    end if;
    update public.space_posts set archived_at = now(), archived_by = v_me where id = p_post;
    select * into v_item from public.work_items where id = p_post for update;
    if v_item.id is not null and v_item.status in ('open', 'done') and v_post.status = 'live' then
      delete from public.work_item_reminders where post_id = p_post and sent_at is null;
      insert into public.push_queue (profile_id, kind, actor_id, data)
      select v_item.owner_id, 'work_item_archived', v_me,
             jsonb_build_object('post_id', p_post, 'space_id', v_post.space_id)
             || case when public.check_in_shows_text(v_item.owner_id)
                     then jsonb_build_object('title', v_post.title) else '{}'::jsonb end
      where v_item.owner_id is not null and v_item.owner_id <> v_me
        and public.is_active_member(v_post.space_id, v_item.owner_id)
        and not public.is_hidden_account(v_item.owner_id)
        and public.space_push_level(v_post.space_id, v_item.owner_id) in ('all', 'needs_you')
        and exists (select 1 from public.push_tokens t where t.profile_id = v_item.owner_id)
        and not exists (select 1 from public.push_queue q
                        where q.kind = 'work_item_archived' and q.profile_id = v_item.owner_id
                          and q.data ->> 'post_id' = p_post::text);
    end if;
    return;
  end if;
  perform public.require_archivable(p_post);
  update public.space_posts set archived_at = now(), archived_by = v_me
  where id = p_post and archived_at is null;
end;
$$;

-- An archived work item is stopped: nobody signs, sends back or checks it.
create or replace function public.refuse_archived_item()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status
     and exists (select 1 from public.space_posts p
                 where p.id = new.id and p.archived_at is not null) then
    raise exception 'archived: no longer needed' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger work_items_refuse_archived
  before update of status on public.work_items
  for each row execute function public.refuse_archived_item();

-- Nor is it reminded.
create or replace function public.refuse_archived_reminder()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.space_posts p
             where p.id = new.post_id and p.archived_at is not null) then
    raise exception 'archived: no longer needed' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger work_item_reminders_refuse_archived
  before insert on public.work_item_reminders
  for each row execute function public.refuse_archived_reminder();

-- item_needs_me (migration 21), as it was, and an archived work item needs
-- nobody.
create or replace function public.item_needs_me(p_item public.work_items, p_post public.space_posts)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_post.status <> 'live' or p_post.deleted_at is not null then null
    -- Review 113: archived, it is stopped.
    when p_post.archived_at is not null then null
    -- A target is done when its work items are checked: nobody is asked to
    -- sign or check it (review 39).
    when public.is_target(p_item.id) then null
    when p_item.status = 'open' and p_item.owner_id = auth.uid()
         and public.member_can(p_item.space_id, auth.uid(), 'mark_done') then 'open_owned'
    when p_item.status = 'done' and public.may_check(p_item, auth.uid()) then 'to_check'
    when p_item.status = 'open'
         and not public.member_can(p_item.space_id, p_item.owner_id, 'mark_done')
         and public.acts_for_author(p_post) then 'owner_left'
  end;
$$;

-- ---------------------------------------------------------------------------
-- The card: space_post_json (migration 59), as it was, and "reactions",
-- "my_reaction" and "hold" (outside jsonb_strip_nulls: their nulls say
-- something).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.space_post_json(p_post space_posts, p_full boolean)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  -- Migration 46: every post's own number, as its ref (NST-031).
  select jsonb_strip_nulls(jsonb_build_object('ref', p_post.ref,
    'archived_at', p_post.archived_at, 'place_id', p_post.place_id) || jsonb_build_object(
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
    -- Review 110 F (HV1): the short card's quiet line, "1 table".
    'table_count', (select count(*) from jsonb_array_elements(p_post.blocks) b
                    where b ->> 'type' = 'table'),
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
  ) || jsonb_build_object(
    -- Migration 58: a work item's tag, with its name and danger.
    'tag', (
      select public.work_tag_json(p_post.space_id, w.tag)
      from public.work_items w where w.id = p_post.id and w.tag is not null),
    -- A Thanks: to whom, for what (only a work item the reader can see),
    -- whether it is on its person's profile, and whether the reader is
    -- that person (only they see Show on my profile).
    'thanks', (
      select jsonb_build_object(
        'to_kind', th.to_kind,
        'to_profile_id', th.to_profile,
        'to_profile_name', public.space_person_name(th.to_profile),
        'to_team_id', th.to_team,
        'to_team_name', (select t.name from public.teams t where t.id = th.to_team),
        'for', (select jsonb_build_object('id', f.id, 'title', f.title, 'ref', f.ref)
                from public.space_posts f
                where f.id = th.for_post and public.can_see_space_post(f.id)),
        'show_on_profile', th.show_on_profile,
        'mine', th.to_profile is not null and th.to_profile = auth.uid())
      from public.space_thanks th where th.post_id = p_post.id)
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
  )) end
  -- Migration 59: a check-in's times, the reader's stamps and whether they
  -- see the list; outside jsonb_strip_nulls, since its nulls say something
  -- ("out_time": null is no check-out).
  || case when p_post.kind = 'check_in'
          then jsonb_build_object('check_in', public.check_in_card(p_post, now()))
          else '{}'::jsonb end
  -- Migration 60 (review 113): who reacted (never a count), the reader's
  -- own reaction, and what holding the post offers the reader.
  || jsonb_build_object(
    'reactions', public.post_reactions_json(p_post),
    'my_reaction', case when p_post.kind <> 'check_in' then (
      select r.kind from public.post_reactions r
      where r.post_id = p_post.id and r.profile_id = auth.uid()) end,
    'hold', public.post_hold(p_post));
$function$;

-- ---------------------------------------------------------------------------
-- 4. The check-in nudge (every minute)
-- ---------------------------------------------------------------------------

-- What check_in_nudge has sent: once per Space per day.
create table public.check_in_nudges (
  space_id uuid not null references public.spaces (id) on delete cascade,
  day date not null,
  profile_id uuid references public.profiles (id) on delete set null,
  from_post_id uuid references public.space_posts (id) on delete set null,
  sent_at timestamptz not null default now(),
  primary key (space_id, day)
);
alter table public.check_in_nudges enable row level security;
revoke all on public.check_in_nudges from public, anon, authenticated;
grant all on public.check_in_nudges to service_role;

-- At [p_now]: for each Space that has had a check-in, its most recent one
-- gives the usual time, the time zone and the working days (check-in's own
-- rules: check_in_zone, check_in_market). On a working day with no
-- check-in running today, from 30 minutes before that time until the time
-- itself, one push to that check-in's creator if still a Lead or the admin
-- there. At most one per Space per day. Returns the pushes queued.
create or replace function public.check_in_nudge(p_now timestamptz default now())
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v record;
  v_c public.check_in_posts;
  v_zone text;
  v_today date;
  v_at timestamptz;
  v_new boolean;
  v_rows integer;
  v_queued integer := 0;
begin
  for v in
    select distinct on (p.space_id) p.space_id, p.id as post_id, p.author_id, s.name as space_name
    from public.space_posts p
    join public.check_in_posts c on c.post_id = p.id
    join public.spaces s on s.id = p.space_id and s.deleted_at is null
    where p.kind = 'check_in' and p.deleted_at is null
    order by p.space_id, p.created_at desc, p.id desc
  loop
    select * into v_c from public.check_in_posts where post_id = v.post_id;
    v_zone := public.check_in_zone(v_c);
    v_today := (p_now at time zone v_zone)::date;
    continue when extract(dow from v_today)::smallint
                  = any (coalesce((public.check_in_market(v_c)).weekend, '{}'::smallint[]));
    v_at := (v_today + v_c.in_time) at time zone v_zone;
    continue when p_now < v_at - interval '30 minutes' or p_now >= v_at;
    continue when exists (
      select 1 from public.check_in_posts c2
      join public.space_posts p2 on p2.id = c2.post_id
      where c2.space_id = v.space_id and p2.deleted_at is null and p2.status = 'live'
        and public.check_in_ran_on(c2, v_today));
    continue when v.author_id is null
               or public.is_hidden_account(v.author_id)
               or not exists (select 1 from public.space_members m
                              where m.space_id = v.space_id and m.profile_id = v.author_id
                                and m.left_at is null and (m.pass = 'lead' or m.is_admin));
    v_new := null;
    insert into public.check_in_nudges (space_id, day, profile_id, from_post_id)
    values (v.space_id, v_today, v.author_id, v.post_id)
    on conflict do nothing
    returning true into v_new;
    continue when v_new is null;
    insert into public.push_queue (profile_id, kind, data)
    select v.author_id, 'check_in_nudge',
           jsonb_build_object('space_id', v.space_id, 'from_post_id', v.post_id)
           || case when public.check_in_shows_text(v.author_id)
                   then jsonb_build_object('space_name', v.space_name) else '{}'::jsonb end
    where exists (select 1 from public.push_tokens t where t.profile_id = v.author_id);
    get diagnostics v_rows = row_count;
    v_queued := v_queued + v_rows;
  end loop;
  return v_queued;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Need you now
-- ---------------------------------------------------------------------------

create table public.need_you_calls (
  id uuid primary key,
  space_id uuid not null references public.spaces (id) on delete cascade,
  from_id uuid not null references public.profiles (id) on delete cascade,
  to_id uuid not null references public.profiles (id) on delete cascade,
  reason text check (char_length(reason) between 1 and 120),
  place text check (char_length(place) between 1 and 80),
  created_at timestamptz not null default now(),
  answer text check (answer in ('coming', 'cant')),
  answered_at timestamptz,
  check (from_id <> to_id),
  check ((answer is null) = (answered_at is null))
);
create index need_you_calls_pair_idx on public.need_you_calls (from_id, to_id, created_at);
create index need_you_calls_to_idx on public.need_you_calls (to_id, created_at);

alter table public.need_you_calls enable row level security;
create policy need_you_calls_read on public.need_you_calls
  for select to authenticated
  using (from_id = auth.uid() or to_id = auth.uid());
revoke all on public.need_you_calls from public, anon, authenticated;
grant select on public.need_you_calls to authenticated;
grant all on public.need_you_calls to service_role;

-- NN1: the caller calls [p_to] in [p_space], with an optional one-line
-- [p_reason] and [p_place]. Both active members there, neither a Viewer,
-- not blocked either way, not oneself; at most 3 from me to the same
-- person in an hour. The same [p_id] again is the same call. The push goes
-- on the strong channel; under the lock-screen rule off it carries only
-- the ids ("Someone needs you now").
create or replace function public.send_need_you(
  p_id uuid,
  p_space uuid,
  p_to uuid,
  p_reason text default null,
  p_place text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_old public.need_you_calls;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_place text := nullif(trim(coalesce(p_place, '')), '');
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_id is null then
    raise exception 'its id is the app''s' using errcode = '22023';
  end if;
  select * into v_old from public.need_you_calls where id = p_id;
  if v_old.id is not null then
    if v_old.from_id = v_me and v_old.space_id = p_space and v_old.to_id = p_to then
      return v_old.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.is_member(p_space) or public.is_hidden_account(v_me)
     or public.member_pass(p_space) is distinct from 'lead'
        and public.member_pass(p_space) is distinct from 'crew' then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_to is null or p_to = v_me then
    raise exception 'not to yourself' using errcode = '22023';
  end if;
  if not exists (select 1 from public.space_members m
                 where m.space_id = p_space and m.profile_id = p_to and m.left_at is null
                   and m.pass in ('lead', 'crew'))
     or public.is_hidden_account(p_to)
     or exists (select 1 from public.blocks b
                where (b.blocker_id = v_me and b.blocked_id = p_to)
                   or (b.blocker_id = p_to and b.blocked_id = v_me)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if char_length(v_reason) > 120 then
    raise exception 'a reason of up to 120 characters' using errcode = '22023';
  end if;
  if char_length(v_place) > 80 then
    raise exception 'a place of up to 80 characters' using errcode = '22023';
  end if;
  -- Two at once can't both be the fourth.
  perform pg_advisory_xact_lock(hashtextextended('need_you:' || v_me::text || ':' || p_to::text, 0));
  if (select count(*) from public.need_you_calls c
      where c.from_id = v_me and c.to_id = p_to
        and c.created_at > now() - interval '1 hour') >= 3 then
    raise exception 'at most 3 an hour' using errcode = '22023';
  end if;
  insert into public.need_you_calls (id, space_id, from_id, to_id, reason, place)
  values (p_id, p_space, v_me, p_to, v_reason, v_place);

  insert into public.push_queue (profile_id, kind, actor_id, data)
  select p_to, 'need_you',
         case when public.check_in_shows_text(p_to) then v_me end,
         jsonb_build_object('call_id', p_id, 'space_id', p_space)
         || case when public.check_in_shows_text(p_to) then jsonb_strip_nulls(jsonb_build_object(
                   'from_name', (select nullif(trim(coalesce(pr.first_name, '') || ' '
                                                    || coalesce(pr.last_name, '')), '')
                                 from public.profiles pr where pr.id = v_me),
                   'reason', v_reason,
                   'place', v_place,
                   'space_name', (select s.name from public.spaces s where s.id = p_space)))
                 else '{}'::jsonb end
  where exists (select 1 from public.push_tokens t where t.profile_id = p_to);
  return p_id;
exception
  when invalid_text_representation then
    raise exception 'an id is not valid' using errcode = '22023';
end;
$$;

-- NN2: the person called answers, once: 'coming' (On my way) or 'cant'
-- (Can't now). The caller gets a push; their name only under the
-- lock-screen rule.
create or replace function public.answer_need_you(p_call uuid, p_answer text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_call public.need_you_calls;
begin
  select * into v_call from public.need_you_calls where id = p_call for update;
  if v_me is null or v_call.id is null or v_call.to_id <> v_me then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_answer is null or p_answer not in ('coming', 'cant') then
    raise exception 'coming or cant' using errcode = '22023';
  end if;
  if v_call.answer is not null then
    raise exception 'already answered' using errcode = '22023';
  end if;
  update public.need_you_calls set answer = p_answer, answered_at = now() where id = p_call;

  insert into public.push_queue (profile_id, kind, actor_id, data)
  select v_call.from_id, 'need_you_answer',
         case when public.check_in_shows_text(v_call.from_id) then v_me end,
         jsonb_build_object('call_id', p_call, 'answer', p_answer, 'space_id', v_call.space_id)
         || case when public.check_in_shows_text(v_call.from_id) then jsonb_strip_nulls(
                   jsonb_build_object('name', (select nullif(trim(coalesce(pr.first_name, '') || ' '
                                                                  || coalesce(pr.last_name, '')), '')
                                               from public.profiles pr where pr.id = v_me)))
                 else '{}'::jsonb end
  where exists (select 1 from public.push_tokens t where t.profile_id = v_call.from_id)
    and not exists (select 1 from public.blocks b
                    where (b.blocker_id = v_me and b.blocked_id = v_call.from_id)
                       or (b.blocker_id = v_call.from_id and b.blocked_id = v_me));
end;
$$;

-- The calls I made or got in the last 24 hours, newest first; in
-- [p_space] only, when given. Names as I may see them.
create or replace function public.my_need_you_calls(p_space uuid default null)
returns table (id uuid, space_id uuid, from_id uuid, from_name text, to_id uuid, to_name text,
               reason text, place text, created_at timestamptz, answer text,
               answered_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.space_id, c.from_id, public.space_person_name(c.from_id), c.to_id,
         public.space_person_name(c.to_id), c.reason, c.place, c.created_at, c.answer,
         c.answered_at
  from public.need_you_calls c
  where auth.uid() is not null
    and (c.from_id = auth.uid() or c.to_id = auth.uid())
    and c.created_at > now() - interval '24 hours'
    and (p_space is null or c.space_id = p_space)
  order by c.created_at desc, c.id;
$$;

-- ---------------------------------------------------------------------------
-- 6. Library folders and link folders
-- ---------------------------------------------------------------------------

create table public.library_folders (
  id uuid primary key,
  space_id uuid not null references public.spaces (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 80),
  kind text not null check (kind in ('folder', 'link')),
  url text check (char_length(url) <= 2000),
  service text check (service in ('onedrive', 'google_drive', 'dropbox')),
  share text not null check (share in ('only_me', 'person', 'team', 'space')),
  -- Set null when the person or the Team goes: the folder narrows to its
  -- creator (and the admin), never widens.
  share_person uuid references public.profiles (id) on delete set null,
  share_team uuid references public.teams (id) on delete set null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  check ((kind = 'link') = (url is not null)),
  check ((kind = 'link') = (service is not null)),
  check (share = 'person' or share_person is null),
  check (share = 'team' or share_team is null)
);
create index library_folders_space_idx on public.library_folders (space_id);

alter table public.library_files
  add column folder_id uuid references public.library_folders (id);
alter table public.library_files add constraint library_files_folder_id_check
  check (folder_id is null or source <> 'check_in_report');
create index library_files_folder_idx on public.library_files (folder_id) where folder_id is not null;

-- Who reads [p_folder], an active member of its Space: only me, its
-- creator; a person, the creator and that person; a Team, the creator, its
-- members and the Space admin; the whole Space, every member. Once the
-- creator has left (or is gone), the Space admin reads a person's folder
-- too, so its files are never lost. An only-me folder is never the
-- admin's: it goes when its creator leaves (drop_only_me_folders).
create or replace function public.can_read_library_folder(p_folder uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select auth.uid() is not null and public.is_member(f.space_id) and (
      case f.share
        when 'space' then true
        when 'only_me' then f.created_by = auth.uid()
        when 'person' then f.created_by = auth.uid() or f.share_person = auth.uid()
        when 'team' then f.created_by = auth.uid() or public.is_space_admin(f.space_id)
                         or exists (select 1 from public.team_members m
                                    where m.team_id = f.share_team and m.profile_id = auth.uid())
        else false
      end
      or (f.share = 'person' and public.is_space_admin(f.space_id)
          and (f.created_by is null or not public.is_active_member(f.space_id, f.created_by)
               or public.is_hidden_account(f.created_by))))
    from public.library_folders f where f.id = p_folder), false);
$$;

-- The lead (2 Nov): [p_profile]'s only-me folders in [p_space] go when they
-- leave or are removed (and any whose creator is gone), with their files'
-- Library rows. The stored objects are then referenced by nothing, so the
-- space-files cleanup (claim_orphan_files, then the Storage API) deletes
-- them. A file a post still carries (space_posts.library_file_id) can't
-- lose its row: it is deleted (deleted_at, read by nobody) and leaves the
-- folder.
create or replace function public.drop_only_me_folders(p_space uuid, p_profile uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_folders uuid[];
begin
  v_folders := array(select f.id from public.library_folders f
                     where f.space_id = p_space and f.share = 'only_me'
                       and (f.created_by = p_profile or f.created_by is null)
                     for update);
  if cardinality(v_folders) = 0 then
    return;
  end if;
  update public.library_files f
  set deleted_at = coalesce(f.deleted_at, now()), folder_id = null
  where f.folder_id = any (v_folders)
    and exists (select 1 from public.space_posts sp where sp.library_file_id = f.id);
  delete from public.library_files f where f.folder_id = any (v_folders);
  delete from public.library_folders f where f.id = any (v_folders);
end;
$$;

create or replace function public.handle_member_gone_folders()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    if old.left_at is null then
      perform public.drop_only_me_folders(old.space_id, old.profile_id);
    end if;
    return old;
  end if;
  if old.left_at is null and new.left_at is not null then
    perform public.drop_only_me_folders(new.space_id, new.profile_id);
  end if;
  return new;
end;
$$;

create trigger space_members_only_me_folders
  after update of left_at or delete on public.space_members
  for each row execute function public.handle_member_gone_folders();

alter table public.library_folders enable row level security;
create policy library_folders_read on public.library_folders
  for select to authenticated
  using (public.can_read_library_folder(id));
revoke all on public.library_folders from public, anon, authenticated;
grant select on public.library_folders to authenticated;
grant all on public.library_folders to service_role;

-- can_read_library_file (migration 59), as it was, and a file in a folder
-- reads only where its folder does.
create or replace function public.can_read_library_file(p_file uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select f.deleted_at is null
       and public.is_member(f.space_id)
       and (f.team_id is null
            or public.is_space_admin(f.space_id)
            or exists (select 1 from public.team_members m
                       where m.team_id = f.team_id and m.profile_id = auth.uid()))
       and (f.source <> 'check_in_report'
            or coalesce(f.only_profile_id = auth.uid(), false)
            or ((f.only_profile_id is null
                 or not public.is_active_member(f.space_id, f.only_profile_id)
                 or public.is_hidden_account(f.only_profile_id))
                and public.is_space_admin(f.space_id)))
       and (f.folder_id is null or public.can_read_library_folder(f.folder_id))
    from public.library_files f where f.id = p_file
  ), false);
$$;

-- The service of a share link: https only, no user part, no port but 443;
-- OneDrive (onedrive.live.com, 1drv.ms, any *.sharepoint.com), Google Drive
-- (drive.google.com, docs.google.com) or Dropbox (www.dropbox.com,
-- dropbox.com). Null for anything else.
create or replace function public.library_link_service(p_url text)
returns text
language sql
immutable
security definer
set search_path = ''
as $$
  select case
    when p_url is null or p_url ~ '\s' or char_length(p_url) > 2000
         or p_url !~* '^https://[^/?#@:]+(:443)?([/?#]|$)' then null
    else (select case
            when h.host in ('onedrive.live.com', '1drv.ms')
                 or h.host ~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\.sharepoint\.com$'
              then 'onedrive'
            when h.host in ('drive.google.com', 'docs.google.com') then 'google_drive'
            when h.host in ('www.dropbox.com', 'dropbox.com') then 'dropbox'
          end
          from (select lower(substring(p_url from '^[A-Za-z]+://([^/?#@:]+)')) as host) h)
  end;
$$;

-- The checks a folder's name and sharing pass, for create and update.
create or replace function public.library_folder_check(
  p_space uuid, p_name text, p_share text, p_share_person uuid, p_share_team uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if char_length(trim(coalesce(p_name, ''))) not between 1 and 80 then
    raise exception 'a name of up to 80 characters' using errcode = '22023';
  end if;
  if p_share is null or p_share not in ('only_me', 'person', 'team', 'space') then
    raise exception 'only me, a person, a Team or the whole Space' using errcode = '22023';
  end if;
  if p_share = 'person' and (
       p_share_person is null
       or not public.is_active_member(p_space, p_share_person)
       or public.is_hidden_account(p_share_person)) then
    raise exception 'a person in this Space' using errcode = '22023';
  end if;
  if p_share = 'team' then
    if p_share_team is null
       or not exists (select 1 from public.teams t where t.id = p_share_team and t.space_id = p_space) then
      raise exception 'a Team of this Space' using errcode = '22023';
    end if;
    if not public.is_space_admin(p_space)
       and not exists (select 1 from public.team_members m
                       where m.team_id = p_share_team and m.profile_id = auth.uid()) then
      raise exception 'not allowed for this Team' using errcode = '42501';
    end if;
  end if;
end;
$$;

-- LB1, LB2: a folder in [p_space]'s Library, shared by [p_share]; with
-- [p_url], a link folder (its service found from the link). Anyone who
-- may add files. The same [p_id] again is the same folder.
create or replace function public.create_library_folder(
  p_id uuid,
  p_space uuid,
  p_name text,
  p_share text,
  p_share_person uuid default null,
  p_share_team uuid default null,
  p_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_old public.library_folders;
  v_url text := nullif(trim(coalesce(p_url, '')), '');
  v_service text;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_id is null then
    raise exception 'its id is the app''s' using errcode = '22023';
  end if;
  select * into v_old from public.library_folders where id = p_id;
  if v_old.id is not null then
    if v_old.created_by = v_me and v_old.space_id = p_space then
      return v_old.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.can(p_space, 'add_files') or public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform public.library_folder_check(p_space, p_name, p_share, p_share_person, p_share_team);
  if v_url is not null then
    v_service := public.library_link_service(v_url);
    if v_service is null then
      raise exception 'a OneDrive, Google Drive or Dropbox link' using errcode = '22023';
    end if;
  end if;
  insert into public.library_folders (id, space_id, name, kind, url, service, share, share_person,
                                      share_team, created_by)
  values (p_id, p_space, trim(p_name), case when v_url is null then 'folder' else 'link' end,
          v_url, v_service, p_share,
          case when p_share = 'person' then p_share_person end,
          case when p_share = 'team' then p_share_team end, v_me);
  return p_id;
end;
$$;

-- A folder's name and sharing: its creator or the Space admin. Its link
-- stays.
create or replace function public.update_library_folder(
  p_id uuid,
  p_name text,
  p_share text,
  p_share_person uuid default null,
  p_share_team uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_f public.library_folders;
begin
  select * into v_f from public.library_folders where id = p_id for update;
  if auth.uid() is null or v_f.id is null or not public.is_member(v_f.space_id)
     or public.is_hidden_account(auth.uid())
     or not (v_f.created_by = auth.uid() or public.is_space_admin(v_f.space_id)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform public.library_folder_check(v_f.space_id, p_name, p_share, p_share_person, p_share_team);
  update public.library_folders
  set name = trim(p_name), share = p_share,
      share_person = case when p_share = 'person' then p_share_person end,
      share_team = case when p_share = 'team' then p_share_team end
  where id = p_id;
end;
$$;

-- A folder goes once it holds no file: its creator or the Space admin.
create or replace function public.delete_library_folder(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_f public.library_folders;
begin
  select * into v_f from public.library_folders where id = p_id for update;
  if auth.uid() is null or v_f.id is null or not public.is_member(v_f.space_id)
     or public.is_hidden_account(auth.uid())
     or not (v_f.created_by = auth.uid() or public.is_space_admin(v_f.space_id)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if exists (select 1 from public.library_files f where f.folder_id = p_id and f.deleted_at is null) then
    raise exception 'empty it first' using errcode = '22023';
  end if;
  -- Its deleted files (never read again) let it go.
  update public.library_files set folder_id = null where folder_id = p_id;
  delete from public.library_folders where id = p_id;
end;
$$;

-- LB1: the folders of [p_space] I can see, A–Z: who sees each, and how
-- many of its files I can open (the version in use of each).
create or replace function public.space_library_folders(p_space uuid)
returns table (id uuid, name text, kind text, url text, service text, share text,
               share_person_name text, share_team_name text, file_count integer,
               created_by uuid, mine boolean, share_person uuid, share_team uuid,
               created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select f.id, f.name, f.kind, f.url, f.service, f.share,
         public.space_person_name(f.share_person),
         (select t.name from public.teams t where t.id = f.share_team),
         (select count(*)::int from public.library_files lf
          where lf.folder_id = f.id and lf.deleted_at is null
            and public.can_read_library_file(lf.id) and public.library_file_in_force(lf.id)),
         f.created_by, f.created_by is not distinct from auth.uid(), f.share_person, f.share_team,
         f.created_at
  from public.library_folders f
  where f.space_id = p_space and public.can_read_library_folder(f.id)
  order by lower(f.name), f.id;
$$;

-- add_library_file (migration 14, with model views' branch), as it was, and
-- [p_folder]: a folder of this Space I can read, never a link folder. A new
-- version goes in its older file's folder (given or not).
drop function public.add_library_file(uuid, uuid, text, text, text, bigint, uuid, text, text, uuid);
create function public.add_library_file(
  p_id uuid,
  p_space uuid,
  p_name text,
  p_path text,
  p_mime text,
  p_bytes bigint default null,
  p_team uuid default null,
  p_rev_label text default null,
  p_note text default null,
  p_supersedes uuid default null,
  p_folder uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_folder uuid := p_folder;
begin
  if not public.can(p_space, 'add_files') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if exists (select 1 from public.library_files f where f.id = p_id) then
    raise exception 'this id is taken' using errcode = '22023';
  end if;
  if p_path is null or p_path not like p_space::text || '/library/' || p_id::text || '/%'
     or p_path like '%..%' or array_length(string_to_array(p_path, '/'), 1) <> 4
     or not public.is_my_upload(p_path) then
    raise exception 'file not uploaded' using errcode = '22023';
  end if;
  if public.upload_mime(p_path, p_mime) is distinct from p_mime then
    raise exception 'file type does not match the upload' using errcode = '22023';
  end if;
  if p_mime is null or not (p_mime like 'image/%' or p_mime = 'application/pdf') then
    raise exception 'file type not allowed' using errcode = '22023';
  end if;
  if p_team is not null and not exists (
       select 1 from public.teams t where t.id = p_team and t.space_id = p_space
         and (public.is_space_admin(p_space)
              or exists (select 1 from public.team_members m
                         where m.team_id = t.id and m.profile_id = auth.uid()))) then
    raise exception 'not allowed for this Team' using errcode = '42501';
  end if;
  if v_folder is null and p_supersedes is not null then
    v_folder := (select f.folder_id from public.library_files f where f.id = p_supersedes);
  end if;
  if v_folder is not null then
    if not exists (select 1 from public.library_folders lf
                   where lf.id = v_folder and lf.space_id = p_space)
       or not public.can_read_library_folder(v_folder) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if exists (select 1 from public.library_folders lf where lf.id = v_folder and lf.kind = 'link') then
      raise exception 'not into a link folder' using errcode = '22023';
    end if;
  end if;
  if p_supersedes is not null and not exists (
       select 1 from public.library_files f
       where f.id = p_supersedes and f.space_id = p_space
         and f.team_id is not distinct from p_team
         and f.folder_id is not distinct from v_folder
         and public.can_read_library_file(f.id)) then
    raise exception 'the older file is not in this Space or Team' using errcode = '22023';
  end if;
  if p_supersedes is not null and exists (
       select 1 from public.library_files f
       where f.id = p_supersedes and f.source = 'model_view') then
    raise exception 'a model view''s versions come only from BuildVibes 360' using errcode = '22023';
  end if;
  insert into public.library_files
    (id, space_id, team_id, name, storage_path, mime, bytes, rev_label, note,
     supersedes_id, uploaded_by, folder_id)
  values (p_id, p_space, p_team, trim(p_name), p_path, p_mime, p_bytes,
          nullif(trim(p_rev_label), ''), nullif(trim(p_note), ''), p_supersedes, auth.uid(),
          v_folder);
  return p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Push kinds
-- ---------------------------------------------------------------------------

alter table public.push_queue drop constraint push_queue_kind_check;
alter table public.push_queue add constraint push_queue_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'announcement_new', 'checklist_for_you', 'activity_invited', 'activity_starting',
  'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow', 'post_reply', 'chat_message',
  'dm_message', 'dm_request', 'dm_follow_up',
  'work_reminder', 'scheduled_failed',
  'check_in_open', 'check_in_summary',
  'post_reaction', 'work_item_archived', 'check_in_nudge', 'need_you', 'need_you_answer'));

-- ---------------------------------------------------------------------------
-- My data: export_my_data (migration 59), as it was, and my reactions, my
-- calls and the folders I made.
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
  ) || jsonb_build_object(
    -- Migration 59: the person's own check-in marks, never anyone else's
    -- (and never a point: none is kept).
    'check_in_marks', coalesce((select jsonb_agg(jsonb_build_object(
                                  'check_in', p.title, 'space', s.name, 'day', k.day,
                                  'kind', k.kind, 'at', k.at, 'on_time', k.on_time,
                                  'place', k.place) order by k.day, k.at)
                                from public.check_in_marks k
                                join public.space_posts p on p.id = k.post_id
                                join public.spaces s on s.id = p.space_id
                                where k.user_id = r.profile_id), '[]'))
  || jsonb_build_object(
    -- Migration 60: my reactions, the calls I made or got, and the folders
    -- I made (never anyone else's).
    'post_reactions', coalesce((select jsonb_agg(jsonb_build_object(
                                  'post', p.title, 'kind', x.kind, 'created_at', x.created_at)
                                  order by x.created_at)
                                from public.post_reactions x
                                join public.space_posts p on p.id = x.post_id
                                where x.profile_id = r.profile_id), '[]'),
    'need_you_calls', coalesce((select jsonb_agg(jsonb_build_object(
                                  'space', s.name, 'made', c.from_id = r.profile_id,
                                  'reason', c.reason, 'place', c.place, 'answer', c.answer,
                                  'created_at', c.created_at, 'answered_at', c.answered_at)
                                  order by c.created_at)
                                from public.need_you_calls c
                                join public.spaces s on s.id = c.space_id
                                where c.from_id = r.profile_id or c.to_id = r.profile_id), '[]'),
    'library_folders', coalesce((select jsonb_agg(jsonb_build_object(
                                   'space', s.name, 'name', f.name, 'kind', f.kind, 'url', f.url,
                                   'share', f.share, 'created_at', f.created_at)
                                   order by f.created_at)
                                 from public.library_folders f
                                 join public.spaces s on s.id = f.space_id
                                 where f.created_by = r.profile_id), '[]'))
  from public.data_requests r
  where r.id = p_request;
$function$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function public.post_reactions_json(public.space_posts) from public, anon, authenticated;
revoke all on function public.react_to_post(uuid, text) from public, anon;
revoke all on function public.post_has_action(public.space_posts) from public, anon, authenticated;
revoke all on function public.post_hold(public.space_posts) from public, anon, authenticated;
revoke all on function public.delete_space_post(uuid) from public, anon;
revoke all on function public.archive_space_post(uuid) from public, anon;
revoke all on function public.refuse_archived_item() from public, anon, authenticated;
revoke all on function public.refuse_archived_reminder() from public, anon, authenticated;
revoke all on function public.item_needs_me(public.work_items, public.space_posts) from public, anon, authenticated;
revoke all on function public.space_post_json(public.space_posts, boolean) from public, anon, authenticated;
revoke all on function public.check_in_nudge(timestamptz) from public, anon, authenticated;
revoke all on function public.send_need_you(uuid, uuid, uuid, text, text) from public, anon;
revoke all on function public.answer_need_you(uuid, text) from public, anon;
revoke all on function public.my_need_you_calls(uuid) from public, anon;
-- Used by the folders' RLS: callable, and it says only whether the caller
-- reads the folder.
revoke all on function public.can_read_library_folder(uuid) from public, anon;
revoke all on function public.can_read_library_file(uuid) from public, anon;
revoke all on function public.library_link_service(text) from public, anon, authenticated;
revoke all on function public.drop_only_me_folders(uuid, uuid) from public, anon, authenticated;
revoke all on function public.handle_member_gone_folders() from public, anon, authenticated;
revoke all on function public.library_folder_check(uuid, text, text, uuid, uuid) from public, anon, authenticated;
revoke all on function public.create_library_folder(uuid, uuid, text, text, uuid, uuid, text) from public, anon;
revoke all on function public.update_library_folder(uuid, text, text, uuid, uuid) from public, anon;
revoke all on function public.delete_library_folder(uuid) from public, anon;
revoke all on function public.space_library_folders(uuid) from public, anon;
revoke all on function public.add_library_file(uuid, uuid, text, text, text, bigint, uuid, text, text, uuid, uuid)
  from public, anon;
revoke all on function public.export_my_data(uuid) from public, anon, authenticated;

grant execute on function public.react_to_post(uuid, text) to authenticated;
grant execute on function public.delete_space_post(uuid) to authenticated;
grant execute on function public.archive_space_post(uuid) to authenticated;
grant execute on function public.send_need_you(uuid, uuid, uuid, text, text) to authenticated;
grant execute on function public.answer_need_you(uuid, text) to authenticated;
grant execute on function public.my_need_you_calls(uuid) to authenticated;
grant execute on function public.can_read_library_folder(uuid) to authenticated;
grant execute on function public.can_read_library_file(uuid) to authenticated;
grant execute on function public.create_library_folder(uuid, uuid, text, text, uuid, uuid, text) to authenticated;
grant execute on function public.update_library_folder(uuid, text, text, uuid, uuid) to authenticated;
grant execute on function public.delete_library_folder(uuid) to authenticated;
grant execute on function public.space_library_folders(uuid) to authenticated;
grant execute on function public.add_library_file(uuid, uuid, text, text, text, bigint, uuid, text, text, uuid, uuid)
  to authenticated;
grant execute on function public.check_in_nudge(timestamptz) to service_role;
