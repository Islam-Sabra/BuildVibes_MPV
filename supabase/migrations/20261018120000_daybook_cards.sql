-- Migration 26: one card per work item on the daybook (review 53, Part A;
-- review 50, F25 and F30). Branch daybook-cards-db. Not live.
--
-- - space_posts.last_activity_at: set at insert (= created_at), raised by
--   every new work_item_events row, every post_edits row and a cancel.
--   Back-filled. It is never an edit: edited_at and post_edits are untouched.
-- - The functions that write events lock the post before the work item, the
--   order cancel and delete already use, so raising last_activity_at from
--   an event can't deadlock with a cancel running at the same moment.
-- - daybook_cards(space, before, limit, before_id): one card per visible
--   post, newest activity first, cursor (last_activity_at, id). Each card is
--   the daybook post JSON plus last_activity_at, proof (the latest sign-off
--   and its outcome), history (newest first, up to 50, with history_more)
--   and needs_me ('to_sign' | 'to_check' | 'give_to' | 'to_tick' | null).
-- - post_history(post, before, before_id, limit): older history lines.
-- - F30: post_cards gains latest_reply and reply_faces (up to three
--   repliers). Never a count.
-- - daybook_page and daybook_month are unchanged; a later migration drops
--   daybook_page once no build calls it.

-- ---------------------------------------------------------------------------
-- Last activity
-- ---------------------------------------------------------------------------

alter table public.space_posts add column last_activity_at timestamptz;
update public.space_posts p
set last_activity_at = greatest(
  p.created_at,
  p.cancelled_at,
  (select max(e.created_at) from public.work_item_events e where e.work_item_id = p.id),
  (select max(pe.created_at) from public.post_edits pe where pe.post_id = p.id));
alter table public.space_posts
  alter column last_activity_at set default now(),
  alter column last_activity_at set not null;

create index space_posts_activity_idx on public.space_posts
  (space_id, last_activity_at desc, id desc) where deleted_at is null;
-- A card's proof and history read a sign-off's photos by its event.
create index work_item_evidence_event_idx on public.work_item_evidence (event_id);

-- A new post: its last activity is when it was made.
create function public.post_activity_on_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.last_activity_at := new.created_at;
  return new;
end;
$$;

create trigger space_posts_activity_insert
  before insert on public.space_posts
  for each row execute function public.post_activity_on_insert();

-- A cancel is activity (it writes no event).
create function public.post_activity_on_cancel()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.last_activity_at := greatest(new.last_activity_at, new.cancelled_at);
  return new;
end;
$$;

create trigger space_posts_activity_cancel
  before update of cancelled_at on public.space_posts
  for each row
  when (new.cancelled_at is not null and new.cancelled_at is distinct from old.cancelled_at)
  execute function public.post_activity_on_cancel();

-- An event or an edit raises its post's last activity (never lowers it).
-- Only space_posts is written: the event and edit rows stay as they are.
create function public.post_activity_on_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'post_edits' then
    update public.space_posts set last_activity_at = new.created_at
    where id = new.post_id and last_activity_at < new.created_at;
  else
    update public.space_posts set last_activity_at = new.created_at
    where id = new.work_item_id and last_activity_at < new.created_at;
  end if;
  return null;
end;
$$;

create trigger work_item_events_activity
  after insert on public.work_item_events
  for each row execute function public.post_activity_on_event();

create trigger post_edits_activity
  after insert on public.post_edits
  for each row execute function public.post_activity_on_event();

-- The functions that write an event now lock the post first (then the work
-- item), as cancel_space_post and delete_space_post do: the event's trigger
-- updates the post, and the reverse order would deadlock with a cancel.
-- Each is as before (20261012120000_work_items.sql, 20261012130000_work_items_followups.sql,
-- 20261015120000_daybook.sql), with that one line added.

CREATE OR REPLACE FUNCTION public.sign_done(p_item uuid, p_note text DEFAULT NULL::text, p_evidence jsonb DEFAULT '[]'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me uuid := auth.uid();
  v_item public.work_items;
  v_event uuid;
  v_photos integer;
begin
  perform 1 from public.space_posts where id = p_item for no key update;
  select * into v_item from public.work_items where id = p_item for update;
  if v_item.id is null or v_item.owner_id is distinct from v_me
     or not public.member_can(v_item.space_id, v_me, 'mark_done') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.post_is_live(p_item) then
    raise exception 'this work item was cancelled' using errcode = 'P0001';
  end if;
  if v_item.status <> 'open' then
    raise exception 'only an open item can be signed as done' using errcode = 'P0001';
  end if;
  if public.is_target(p_item) then
    raise exception 'it is done when the work items under it are checked' using errcode = 'P0001';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, note)
  values (p_item, v_me, 'done', nullif(trim(p_note), ''))
  returning id into v_event;
  v_photos := public.add_evidence(v_item, v_event, p_evidence);
  if v_photos = 0 and nullif(trim(p_note), '') is null then
    raise exception 'add a photo or a note' using errcode = '22023';
  end if;
  update public.work_items set status = 'done', done_at = now() where id = p_item;
end;
$function$;

CREATE OR REPLACE FUNCTION public.check_item(p_item uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me uuid := auth.uid();
  v_item public.work_items;
begin
  perform 1 from public.space_posts where id = p_item for no key update;
  select * into v_item from public.work_items where id = p_item for update;
  if v_item.id is null or not public.may_check(v_item, v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.status <> 'done' then
    raise exception 'only a done item can be checked' using errcode = 'P0001';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind)
  values (p_item, v_me, 'checked');
  update public.work_items
  set status = 'checked', checked_by = v_me, checked_at = now()
  where id = p_item;
end;
$function$;

CREATE OR REPLACE FUNCTION public.send_back(p_item uuid, p_reason text, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me uuid := auth.uid();
  v_item public.work_items;
  -- The 0.9.0 test build still sends the old name; it is stored as the new
  -- one. Remove this once 0.9.0 is retired.
  v_reason text := case when p_reason = 'not_as_drawing' then 'not_as_asked' else p_reason end;
begin
  perform 1 from public.space_posts where id = p_item for no key update;
  select * into v_item from public.work_items where id = p_item for update;
  if v_item.id is null or not public.may_check(v_item, v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.status <> 'done' then
    raise exception 'only a done item can be sent back' using errcode = 'P0001';
  end if;
  if v_reason is null
     or v_reason not in ('photo_missing', 'not_as_asked', 'not_finished', 'other') then
    raise exception 'choose a reason' using errcode = '22023';
  end if;
  if v_reason = 'other' and nullif(trim(p_note), '') is null then
    raise exception 'say what is wrong' using errcode = '22023';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, reason, note)
  values (p_item, v_me, 'sent_back', v_reason, nullif(trim(p_note), ''));
  update public.work_items set status = 'open', done_at = null where id = p_item;
end;
$function$;

CREATE OR REPLACE FUNCTION public.add_comment(p_item uuid, p_note text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_item public.work_items;
  v_id uuid;
begin
  perform 1 from public.space_posts where id = p_item for no key update;
  select * into v_item from public.work_items where id = p_item;
  if v_item.id is null or not public.can_see_space_post(p_item)
     or not (v_item.owner_id = auth.uid()
             or public.member_pass(v_item.space_id) in ('lead', 'crew')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.post_is_live(p_item) then
    raise exception 'this work item was cancelled' using errcode = 'P0001';
  end if;
  if nullif(trim(p_note), '') is null then
    raise exception 'write a comment' using errcode = '22023';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, note)
  values (p_item, auth.uid(), 'comment', trim(p_note))
  returning id into v_id;
  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.reassign_work_item(p_item uuid, p_owner uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me uuid := auth.uid();
  v_item public.work_items;
  v_post public.space_posts;
begin
  perform 1 from public.space_posts where id = p_item for no key update;
  select * into v_item from public.work_items where id = p_item for update;
  select * into v_post from public.space_posts where id = p_item;
  if v_item.id is null or v_post.id is null or not public.acts_for_author(v_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_post.status <> 'live' or v_post.deleted_at is not null then
    raise exception 'this work item was cancelled' using errcode = 'P0001';
  end if;
  if v_item.status <> 'open' then
    raise exception 'only an open item can be reassigned' using errcode = 'P0001';
  end if;
  if p_owner is null or not public.member_can(v_item.space_id, p_owner, 'mark_done') then
    raise exception 'choose an owner who can sign it as done' using errcode = '22023';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, from_owner_id, to_owner_id)
  values (p_item, v_me, 'reassigned', v_item.owner_id, p_owner);
  update public.work_items set owner_id = p_owner where id = p_item;
end;
$function$;

-- ---------------------------------------------------------------------------
-- A card's history
-- ---------------------------------------------------------------------------

-- The id half of a (time, id) cursor, for one row comparison
-- `(at, id) < (coalesce(p_before, 'infinity'), cursor_id(p_before, p_before_id))`:
-- no cursor reads from the top; a time without an id means strictly before
-- that time (no id is below the zero uuid). Immutable, so it can sit in an
-- index condition.
create function public.cursor_id(p_before timestamptz, p_before_id uuid)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select coalesce(p_before_id,
                  case when p_before is null then 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid
                       else '00000000-0000-0000-0000-000000000000'::uuid end);
$$;

-- A post's history lines, newest first, before (p_before, p_before_id): its
-- work item events (raised, done, checked, sent_back, comment, reassigned),
-- its edits ('edited', with the changes) and its cancel ('cancelled', with
-- the post's id). Internal: no visibility check of its own. The lines are
-- picked first and only the page is built; each person's name is looked up
-- once per call.
create function public.post_history_rows(p_post public.space_posts, p_before timestamptz,
                                         p_before_id uuid, p_limit integer)
returns table (id uuid, at timestamptz, event jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  with picked as (
    select x.id, x.at, x.src from (
      (select e.id, e.created_at as at, 'event'::text as src
       from public.work_item_events e
       where e.work_item_id = p_post.id
         and (e.created_at, e.id) < (coalesce(p_before, 'infinity'), public.cursor_id(p_before, p_before_id))
       order by e.created_at desc, e.id desc
       limit p_limit)
      union all
      (select pe.id, pe.created_at, 'edit'::text
       from public.post_edits pe
       where pe.post_id = p_post.id
         and (pe.created_at, pe.id) < (coalesce(p_before, 'infinity'), public.cursor_id(p_before, p_before_id))
       order by pe.created_at desc, pe.id desc
       limit p_limit)
      union all
      select p_post.id, p_post.cancelled_at, 'cancel'::text
      where p_post.cancelled_at is not null
        and (p_post.cancelled_at, p_post.id)
            < (coalesce(p_before, 'infinity'), public.cursor_id(p_before, p_before_id))
    ) x
    order by x.at desc, x.id desc
    limit p_limit
  ),
  lines as (
    select k.id, k.at, e.kind, e.actor_id as by_id, e.note, e.reason,
           e.from_owner_id, e.to_owner_id, null::jsonb as changes
    from picked k join public.work_item_events e on e.id = k.id
    where k.src = 'event'
    union all
    select k.id, k.at, 'edited', pe.editor_id, null, null, null, null, pe.changes
    from picked k join public.post_edits pe on pe.id = k.id
    where k.src = 'edit'
    union all
    select k.id, k.at, 'cancelled', p_post.cancelled_by, p_post.cancel_note, null, null, null, null
    from picked k
    where k.src = 'cancel'
  ),
  people as materialized (
    select u.pid, public.space_person_name(u.pid) as name
    from (select distinct x.pid
          from lines l, unnest(array[l.by_id, l.from_owner_id, l.to_owner_id]) x(pid)
          where x.pid is not null) u
  )
  select l.id, l.at, jsonb_strip_nulls(jsonb_build_object(
           'id', l.id, 'kind', l.kind,
           'by_id', l.by_id, 'by_name', (select n.name from people n where n.pid = l.by_id),
           'note', l.note, 'reason', l.reason, 'at', l.at,
           'from_id', l.from_owner_id,
           'from_name', (select n.name from people n where n.pid = l.from_owner_id),
           'to_id', l.to_owner_id,
           'to_name', (select n.name from people n where n.pid = l.to_owner_id),
           'changes', l.changes,
           'photos', (select jsonb_agg(jsonb_build_object(
                               'path', ev.storage_path, 'taken_at', ev.taken_at,
                               'place', ev.place_text) order by ev.created_at, ev.id)
                      from public.work_item_evidence ev where ev.event_id = l.id)))
  from lines l
  order by l.at desc, l.id desc;
$$;

-- Older history lines for "Show earlier": newest first, before the cursor
-- (the last line's at and id), at most 100. Only for a post the caller sees.
create function public.post_history(p_post uuid, p_before timestamptz default null,
                                    p_before_id uuid default null, p_limit integer default 50)
returns table (id uuid, at timestamptz, event jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select h.id, h.at, h.event
  from public.space_posts p
  cross join lateral public.post_history_rows(
    p, p_before, p_before_id, least(greatest(coalesce(p_limit, 50), 1), 100)) h
  where p.id = p_post and public.can_see_space_post(p.id)
  order by h.at desc, h.id desc;
$$;

-- ---------------------------------------------------------------------------
-- The card
-- ---------------------------------------------------------------------------

-- What the card asks of the caller (the paper clip and the one action):
-- - 'to_sign': the owner, while the item is Open (never signed, or sent back);
-- - 'to_check': whoever may check, while it is Done;
-- - 'give_to': the owner left (or can no longer sign), for whoever acts for
--   the author: only the owner can sign, so the action is Give to someone
--   else (the author's clip of migration 24, now on the one card);
-- - 'to_tick': a checklist with points left for one of its people;
-- - null: everyone else, Viewers, a target, a cancelled or checked item.
create function public.card_needs_me(p_post public.space_posts)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_post.kind = 'work_item' then (
      select case public.item_needs_me(w, p_post)
               when 'open_owned' then 'to_sign'
               when 'to_check' then 'to_check'
               when 'owner_left' then 'give_to'
             end
      from public.work_items w where w.id = p_post.id)
    when p_post.kind = 'checklist' and public.checklist_needs_me(p_post) then 'to_tick'
  end;
$$;

-- The daybook as cards: every post the caller may see (cancelled ones kept,
-- deleted ones gone), newest activity first, at most 100. The next page
-- passes the last card's last_activity_at and id. Read from
-- space_posts_activity_idx, stopping at the page.
--
-- Each card is the post as daybook_post_json gives it (space_post_json; its
-- boolean needs_me is replaced below), plus:
-- - last_activity_at;
-- - proof: the latest sign-off (event_id, photos, note, at, by {id, name})
--   and its outcome, as daybook_event_json gives it (done, checked,
--   sent_back, cancelled), with who and when;
-- - history: post_history_rows, newest first, up to 50, and history_more;
-- - needs_me: card_needs_me.
-- Everything is built in this one query, so each helper is planned once per
-- page rather than once per card.
create function public.daybook_cards(p_space uuid, p_before timestamptz default null,
                                     p_limit integer default 30, p_before_id uuid default null)
returns table (id uuid, last_activity_at timestamptz, card jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if not public.is_member(p_space) then
    return;
  end if;
  return query
    select pg.id, pg.last_activity_at,
           public.space_post_json(pg.post, false)
           || jsonb_build_object(
                'last_activity_at', pg.last_activity_at,
                'proof', case when pf.j is not null then jsonb_strip_nulls(jsonb_build_object(
                  'event_id', (pf.ev).id,
                  'photos', pf.j -> 'photos',
                  'note', (pf.ev).note,
                  'at', (pf.ev).created_at,
                  'by', jsonb_build_object('id', (pf.ev).actor_id, 'name', pf.j ->> 'actor_name'),
                  'outcome', case pf.j -> 'outcome' ->> 'kind'
                    when 'done' then (pf.j -> 'outcome') || jsonb_build_object(
                      'by_id', (pf.ev).actor_id, 'by_name', pf.j ->> 'actor_name',
                      'at', (pf.ev).created_at)
                    when 'cancelled' then (pf.j -> 'outcome') || jsonb_build_object(
                      'by_id', (pg.post).cancelled_by,
                      'by_name', pf.j ->> 'cancelled_by_name',
                      'at', (pg.post).cancelled_at)
                    else pf.j -> 'outcome'
                  end)) end,
                'history', coalesce(h.list, '[]'::jsonb),
                'history_more', coalesce(h.more, false),
                'needs_me', to_jsonb(public.card_needs_me(pg.post)))
    from (
      select p.id, p.last_activity_at, p as post
      from public.space_posts p
      where p.space_id = p_space and p.deleted_at is null
        -- One row comparison, so the cursor stays in the index condition
        -- under a cached (generic) plan too.
        and (p.last_activity_at, p.id) < (coalesce(p_before, 'infinity'), public.cursor_id(p_before, p_before_id))
        and public.can_see_space_post(p.id)
      order by p.last_activity_at desc, p.id desc
      limit least(greatest(coalesce(p_limit, 30), 1), 100)
    ) pg
    left join lateral (
      select s.ev, public.daybook_event_json(s.ev, pg.post)
                   || jsonb_build_object('cancelled_by_name',
                                         public.space_person_name((pg.post).cancelled_by)) as j
      from (select e as ev from public.work_item_events e
            where e.work_item_id = pg.id and e.kind = 'done'
            order by e.created_at desc, e.id desc limit 1) s
    ) pf on true
    left join lateral (
      select jsonb_agg(r.event order by r.at desc, r.id desc) filter (where r.n <= 50) as list,
             count(*) > 50 as more
      from (select hr.id, hr.at, hr.event,
                   row_number() over (order by hr.at desc, hr.id desc) as n
            from public.post_history_rows(pg.post, null, null, 51) hr) r
    ) h on true
    order by pg.last_activity_at desc, pg.id desc;
end;
$$;

-- ---------------------------------------------------------------------------
-- F30: replies on the feed card
-- ---------------------------------------------------------------------------

-- post_cards as before (20261012170000_feed.sql), with two columns at the
-- end. The view runs as the caller, so the replies and their authors follow
-- post_replies' and profiles' row-level security: no deleted reply, none
-- across a block or from a hidden account, none the caller reported.
-- - latest_reply: the newest such reply: id, the first 80 characters,
--   author (id, name, photo), time, and to_me (it answers the caller: a
--   reply to them, or a top comment on their post, not their own).
-- - reply_faces: up to three people who replied, the most recent first
--   (id, name, photo). Never a count.
create or replace view public.post_cards
with (security_invoker = true) as
  select p.id,
         p.author_id,
         a.first_name as author_first_name,
         a.last_name as author_last_name,
         a.headline as author_headline,
         coalesce(co.name, a.company_name_text) as author_company,
         a.photo_path as author_photo,
         p.body,
         p.lang,
         sp.id as project_id,
         sp.name as project_name,
         sp.type_id as project_type_id,
         sp.place_id as project_place_id,
         sp.location_text as project_location,
         p.market_id,
         p.created_at,
         p.edited_at,
         coalesce((
           select jsonb_agg(jsonb_build_object('path', m.storage_path,
                    'width', m.width, 'height', m.height) order by m.sort)
           from public.post_media m where m.post_id = p.id), '[]'::jsonb) as media,
         exists (select 1 from public.useful_marks u
                 where u.target_kind = 'post' and u.target_id = p.id
                   and u.profile_id = auth.uid()) as my_useful,
         (select jsonb_strip_nulls(jsonb_build_object(
                   'id', r.id,
                   'body', left(r.body, 80),
                   'author_id', r.author_id,
                   'author_name', nullif(trim(coalesce(ra.first_name, '') || ' '
                                              || coalesce(ra.last_name, '')), ''),
                   'author_photo', ra.photo_path,
                   'created_at', r.created_at,
                   'to_me', r.author_id is distinct from auth.uid()
                            and (r.reply_to_person is not distinct from auth.uid()
                                 or (r.reply_to is null and p.author_id = auth.uid()))))
          from public.post_replies r
          join public.profiles ra on ra.id = r.author_id
          where r.post_id = p.id
          order by r.created_at desc, r.id desc
          limit 1) as latest_reply,
         coalesce((
           select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                    'id', f.author_id,
                    'name', nullif(trim(coalesce(fa.first_name, '') || ' '
                                        || coalesce(fa.last_name, '')), ''),
                    'photo', fa.photo_path)) order by f.last_at desc, f.author_id)
           from (select r.author_id, max(r.created_at) as last_at
                 from public.post_replies r
                 join public.profiles ra on ra.id = r.author_id
                 where r.post_id = p.id
                 group by r.author_id
                 order by max(r.created_at) desc, r.author_id
                 limit 3) f
           join public.profiles fa on fa.id = f.author_id), '[]'::jsonb) as reply_faces
  from public.posts p
  join public.profiles a on a.id = p.author_id
  left join public.companies co on co.id = a.company_id
  left join public.projects sp on sp.id = public.shown_project(p.project_id);

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke execute on function
  public.post_activity_on_insert(),
  public.post_activity_on_cancel(),
  public.post_activity_on_event(),
  public.cursor_id(timestamptz, uuid),
  public.post_history_rows(public.space_posts, timestamptz, uuid, integer),
  public.post_history(uuid, timestamptz, uuid, integer),
  public.card_needs_me(public.space_posts),
  public.daybook_cards(uuid, timestamptz, integer, uuid)
  from public, anon;
-- Internal helpers: they answer about any post, without its own checks.
revoke execute on function
  public.post_activity_on_insert(),
  public.post_activity_on_cancel(),
  public.post_activity_on_event(),
  public.cursor_id(timestamptz, uuid),
  public.post_history_rows(public.space_posts, timestamptz, uuid, integer),
  public.card_needs_me(public.space_posts)
  from authenticated;
grant execute on function
  public.post_history(uuid, timestamptz, uuid, integer),
  public.daybook_cards(uuid, timestamptz, integer, uuid)
  to authenticated;
