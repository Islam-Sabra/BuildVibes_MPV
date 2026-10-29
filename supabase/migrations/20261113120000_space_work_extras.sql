-- Migration 52 (review 105B): a Space's Work extras, in six parts.
--
-- 1. Places (site tags): space_places, a name unique in its Space whatever
--    its case and spaces. Members read; those who may post work add;
--    Leads rename and delete. space_posts.place_id points to one of its
--    own Space's, set with set_post_place (its author, its owner or a
--    Lead); the free-text place_text stays readable on older posts.
-- 2. Archive: space_posts.archived_at and archived_by.
--    archive_space_post and unarchive_space_post: a Lead of the Space, on a
--    Checked work item only. Work's list (daybook_cards, daybook_extras)
--    leaves archived posts out; opening one (daybook_card) and Search still
--    find it.
-- 3. Personal pins: space_post_pins, mine only, for posts I can see.
--    pin_space_post and unpin_space_post. Work's cards say pinned_by_me,
--    and daybook_extras lists mine (reason 'mine'). The Space-wide pin of
--    an announcement (pinned_until) stays as it is.
-- 4. Share to a chat thread: share_post_to_thread posts a message of kind
--    'post' carrying the post (messages.post_id), into a thread of the
--    same Space that the caller may write in, of a post they may read; a
--    Team's post only into that Team's thread. The work stays in its Space.
--    A retry with the same message id, even at the same moment, returns it.
-- 5. The Space's time zone: space_time_zone(space), from its market pack
--    (markets.time_zone, migration 13): its project's market, else none
--    (never a person's own market); for members only. Also read with the
--    Space as spaces.time_zone (a computed column). The app ends a pinned
--    announcement at midnight there, or at the phone's with none.
-- 6. Handover: remove_member_with_handover and leave_space_with_handover
--    give every open work item the person owns a new owner who may own work
--    (an active member who may sign it as done, of its Team or an admin),
--    or nothing changes. Their Done and Checked work stays where it is
--    (the founder, 29 Oct: the proof stays with whoever did it).
--    leave_space and remove_member refuse (BV001) while the person owns
--    open work, so there is no way around it. Both lock the Space first,
--    and a work item's owner is set under the same lock (for share), so
--    no item goes to someone in the middle of leaving.
-- 7. Send back to someone who has left: send_back on an item whose owner
--    may no longer sign it needs a new owner in the same call.
-- 8. daybook_month leaves archived posts out too.
-- 9. A post says it is archived, and its place (space_post_json), so a
--    Lead can Unarchive it from Search; shared_post_gone tells a reader
--    of a thread that a shared post was deleted, not only hidden.

-- ---------------------------------------------------------------------------
-- 1. Places
-- ---------------------------------------------------------------------------

create table public.space_places (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 80),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
-- "Level 3 slab" and " level 3  SLAB " are the same place.
create unique index space_places_name_key
  on public.space_places (space_id, lower(regexp_replace(name, '\s+', '', 'g')));
alter table public.space_places enable row level security;

create policy space_places_read on public.space_places
  for select using (public.is_member(space_id));
create policy space_places_add on public.space_places
  for insert with check (created_by = auth.uid() and public.can(space_id, 'create_items'));
create policy space_places_rename on public.space_places
  for update using (public.member_pass(space_id) = 'lead')
  with check (public.member_pass(space_id) = 'lead');
create policy space_places_delete on public.space_places
  for delete using (public.member_pass(space_id) = 'lead');

revoke all on public.space_places from anon, authenticated;
grant select, insert, delete on public.space_places to authenticated;
grant update (name) on public.space_places to authenticated;
grant all on public.space_places to service_role;

alter table public.space_posts
  add column place_id uuid references public.space_places (id) on delete set null;

-- A post's place is one of its own Space's.
create or replace function public.check_post_place()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.place_id is not null and not exists (
    select 1 from public.space_places sp where sp.id = new.place_id and sp.space_id = new.space_id) then
    raise exception 'a place of this Space' using errcode = '22023';
  end if;
  return new;
end;
$$;
create trigger space_posts_place_check before insert or update of place_id on public.space_posts
  for each row execute function public.check_post_place();

-- A post's place (the 105C picker): its author, its work item's owner, or
-- a Lead of its Space; [p_place] one of its Space's, or null to clear it.
create or replace function public.set_post_place(p_post uuid, p_place uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
begin
  select * into v_post from public.space_posts where id = p_post for no key update;
  if v_me is null or v_post.id is null or v_post.deleted_at is not null
     or not public.can_see_space_post(p_post)
     or not (v_post.author_id = v_me
             or public.member_pass(v_post.space_id) = 'lead'
             or exists (select 1 from public.work_items w
                        where w.id = p_post and w.owner_id = v_me)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.space_posts set place_id = p_place where id = p_post;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Archive
-- ---------------------------------------------------------------------------

alter table public.space_posts
  add column archived_at timestamptz,
  add column archived_by uuid references public.profiles (id) on delete set null;

-- A Lead of its Space, on a Checked work item.
create or replace function public.require_archivable(p_post uuid)
returns public.space_posts
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post public.space_posts;
begin
  select * into v_post from public.space_posts where id = p_post for update;
  if v_post.id is null or v_post.deleted_at is not null
     or public.member_pass(v_post.space_id) is distinct from 'lead'
     or not public.can_see_space_post(p_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_post.kind <> 'work_item' or v_post.status <> 'live'
     or not exists (select 1 from public.work_items w where w.id = p_post and w.status = 'checked') then
    raise exception 'only a Checked work item' using errcode = 'P0001';
  end if;
  return v_post;
end;
$$;

create or replace function public.archive_space_post(p_post uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_archivable(p_post);
  update public.space_posts set archived_at = now(), archived_by = auth.uid()
  where id = p_post and archived_at is null;
end;
$$;

create or replace function public.unarchive_space_post(p_post uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_archivable(p_post);
  update public.space_posts set archived_at = null, archived_by = null where id = p_post;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Personal pins
-- ---------------------------------------------------------------------------

create table public.space_post_pins (
  user_id uuid not null references public.profiles (id) on delete cascade,
  post_id uuid not null references public.space_posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create index space_post_pins_post_idx on public.space_post_pins (post_id);
alter table public.space_post_pins enable row level security;

create policy space_post_pins_read_own on public.space_post_pins
  for select using (user_id = auth.uid() and public.can_see_space_post(post_id));

-- Written only through pin_space_post and unpin_space_post.
revoke all on public.space_post_pins from anon, authenticated;
grant select on public.space_post_pins to authenticated;
grant all on public.space_post_pins to service_role;

create or replace function public.pin_space_post(p_post uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.can_see_space_post(p_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  insert into public.space_post_pins (user_id, post_id) values (auth.uid(), p_post)
  on conflict do nothing;
end;
$$;

create or replace function public.unpin_space_post(p_post uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from public.space_post_pins where user_id = auth.uid() and post_id = p_post;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Share to a chat thread
-- ---------------------------------------------------------------------------

alter table public.messages
  add column post_id uuid references public.space_posts (id) on delete cascade;
alter table public.messages drop constraint messages_kind_check;
alter table public.messages add constraint messages_kind_check
  check (kind in ('text', 'photo', 'file', 'voice', 'work_item', 'report', 'post'));
alter table public.messages add constraint messages_post_check
  check ((kind = 'post') = (post_id is not null));

-- [p_id] is chosen by the app: a retry with the same id posts once.
create or replace function public.share_post_to_thread(p_id uuid, p_post uuid, p_thread uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_thread public.threads;
  v_existing public.messages;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  select * into v_existing from public.messages where id = p_id;
  if v_existing.id is not null then
    if v_existing.author_id = v_me and v_existing.thread_id = p_thread
       and v_existing.post_id = p_post then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_post from public.space_posts where id = p_post;
  select * into v_thread from public.threads where id = p_thread;
  if v_post.id is null or v_thread.id is null
     or not public.can_see_space_post(p_post) or not public.can_use_thread(p_thread) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  -- Rule 8: the work stays in its Space.
  if v_thread.space_id <> v_post.space_id then
    raise exception 'a thread of the post''s own Space' using errcode = '22023';
  end if;
  -- Its card shows its title: a Team's post only where that Team reads.
  if v_post.team_id is not null and v_post.team_id is distinct from v_thread.team_id then
    raise exception 'a Team''s post only in that Team''s thread' using errcode = '22023';
  end if;
  if (select count(*) from public.messages m
      where m.author_id = v_me and m.kind <> 'work_item'
        and m.created_at > now() - interval '1 minute') >= 30 then
    raise exception 'too many messages, wait a moment' using errcode = 'P0001';
  end if;
  begin
    insert into public.messages (id, thread_id, space_id, author_id, kind, post_id)
    values (p_id, p_thread, v_thread.space_id, v_me, 'post', p_post);
  exception when unique_violation then
    -- The same id from a retry running at the same moment.
    select * into v_existing from public.messages where id = p_id;
    if v_existing.author_id = v_me and v_existing.thread_id = p_thread
       and v_existing.post_id = p_post then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end;
  return p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. The Space's time zone
-- ---------------------------------------------------------------------------

create or replace function public.space_time_zone(p_space uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_member(p_space) then
    return null;
  end if;
  -- Its project's market only: a person's own market says where they
  -- live, which a Space never tells.
  return (select m.time_zone from public.spaces s
          join public.projects pr on pr.id = s.project_id
          join public.markets m on m.id = pr.market_id
          where s.id = p_space);
end;
$$;

-- Read with the Space (select time_zone from spaces).
create or replace function public.time_zone(p_space public.spaces)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select public.space_time_zone(p_space.id);
$$;

-- ---------------------------------------------------------------------------
-- 6. Handover
-- ---------------------------------------------------------------------------

-- [p_assignments]: [{"item": work item, "owner": new owner}], one for every
-- open work item [p_member] owns in [p_space]; or nothing changes.
create or replace function public.hand_over_open_work(p_space uuid, p_member uuid, p_assignments jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_open uuid[];
  v_given uuid[];
  v_a record;
begin
  -- Locked while they change hands.
  select coalesce(array_agg(x.id order by x.id), '{}') into v_open
  from (select w.id
        from public.work_items w
        join public.space_posts p on p.id = w.id
        where w.space_id = p_space and w.owner_id = p_member and w.status = 'open'
          and p.status = 'live' and p.deleted_at is null
        for update of w) x;
  if jsonb_typeof(coalesce(p_assignments, '[]'::jsonb)) <> 'array' then
    raise exception 'every open work item needs a new owner' using errcode = '22023';
  end if;
  select coalesce(array_agg((a ->> 'item')::uuid order by (a ->> 'item')::uuid), '{}') into v_given
  from jsonb_array_elements(coalesce(p_assignments, '[]'::jsonb)) a;
  if not v_open <@ v_given then
    raise exception 'hand over their open work first' using errcode = 'BV001';
  end if;
  if v_given <> v_open then
    raise exception 'every open work item needs a new owner' using errcode = '22023';
  end if;
  for v_a in
    select (a ->> 'item')::uuid as item, (a ->> 'owner')::uuid as owner, p.team_id
    from jsonb_array_elements(p_assignments) a
    join public.space_posts p on p.id = (a ->> 'item')::uuid
  loop
    if v_a.owner is null or v_a.owner = p_member
       or not public.may_be_post_person(p_space, v_a.team_id, 'work_item', v_a.owner)
       or not public.member_can(p_space, v_a.owner, 'mark_done') then
      raise exception 'choose new owners who can own this work' using errcode = '22023';
    end if;
    insert into public.work_item_events (work_item_id, actor_id, kind, from_owner_id, to_owner_id)
    values (v_a.item, auth.uid(), 'reassigned', p_member, v_a.owner);
    update public.work_items set owner_id = v_a.owner where id = v_a.item;
  end loop;
end;
$$;

create or replace function public.remove_member_with_handover(p_space uuid, p_member uuid,
                                                              p_assignments jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1 from public.spaces where id = p_space for update;
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform public.require_active_member(p_space, p_member);
  perform public.hand_over_open_work(p_space, p_member, p_assignments);
  perform public.remove_member(p_space, p_member);
end;
$$;

create or replace function public.leave_space_with_handover(p_space uuid, p_assignments jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- The Space first, as leave_space and work items' owners (L4).
  perform 1 from public.spaces where id = p_space for update;
  if not public.is_member(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform public.hand_over_open_work(p_space, auth.uid(), p_assignments);
  perform public.leave_space(p_space);
end;
$$;

-- Does [p_member] own open work in [p_space]?
create or replace function public.owns_open_work(p_space uuid, p_member uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.work_items w
    join public.space_posts p on p.id = w.id
    where w.space_id = p_space and w.owner_id = p_member and w.status = 'open'
      and p.status = 'live' and p.deleted_at is null);
$$;

-- As in 20261013130000_account, refusing while I own open work: that goes
-- through leave_space_with_handover.
create or replace function public.leave_space(p_space uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
begin
  -- One change to a Space's admins at a time.
  perform 1 from public.spaces where id = p_space for update;
  if not public.is_member(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if public.owns_open_work(p_space, v_me) then
    raise exception 'hand over your open work first' using errcode = 'BV001';
  end if;
  if exists (select 1 from public.space_members
             where space_id = p_space and profile_id = v_me
               and is_admin and left_at is null)
     and not public.has_other_admin(p_space, v_me) then
    raise exception 'a Space needs an admin' using errcode = 'P0001';
  end if;
  update public.space_members set left_at = now(), is_admin = false
  where space_id = p_space and profile_id = v_me;
  delete from public.team_members tm
  using public.teams t
  where t.id = tm.team_id and t.space_id = p_space and tm.profile_id = v_me;
end;
$$;

-- As in 20261011160000_spaces, refusing while they own open work: that
-- goes through remove_member_with_handover.
create or replace function public.remove_member(p_space uuid, p_profile uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- One change to a Space's admins at a time.
  perform 1 from public.spaces where id = p_space for update;
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_profile = auth.uid() then
    raise exception 'use leave_space' using errcode = '22023';
  end if;
  perform public.require_active_member(p_space, p_profile);
  if public.owns_open_work(p_space, p_profile) then
    raise exception 'hand over their open work first' using errcode = 'BV001';
  end if;
  update public.space_members
  set left_at = now(), removed_by = auth.uid(), is_admin = false
  where space_id = p_space and profile_id = p_profile;
  delete from public.team_members tm
  using public.teams t
  where t.id = tm.team_id and t.space_id = p_space and tm.profile_id = p_profile;
end;
$$;

-- A work item's owner is set under its Space's lock (for share), after
-- any leave or removal running now, and must still be one who may sign it
-- (L4): create_work_item, Give to and Send back all come through here.
create or replace function public.check_work_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.owner_id is null
     or (tg_op = 'UPDATE' and new.owner_id is not distinct from old.owner_id) then
    return new;
  end if;
  perform 1 from public.spaces where id = new.space_id for share;
  if not public.member_can(new.space_id, new.owner_id, 'mark_done') then
    raise exception 'choose an owner who can sign it as done' using errcode = '22023';
  end if;
  return new;
end;
$$;
create trigger work_items_owner_check before insert or update of owner_id on public.work_items
  for each row execute function public.check_work_owner();

-- ---------------------------------------------------------------------------
-- Work's list: archived posts out (2), my pins in (3)
-- ---------------------------------------------------------------------------

-- As in migration 37, with archived posts left out and pinned_by_me.
create or replace function public.daybook_cards(p_space uuid, p_before timestamptz default null,
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
                'needs_me', to_jsonb(public.card_needs_me(pg.post)),
                'pinned_by_me', exists (select 1 from public.space_post_pins pin
                                        where pin.user_id = auth.uid() and pin.post_id = pg.id))
    from (
      select p.id, p.last_activity_at, p as post
      from public.space_posts p
      where p.space_id = p_space and p.deleted_at is null and p.archived_at is null
        -- One row comparison, so the cursor stays in the index condition
        -- under a cached (generic) plan too.
        and (p.last_activity_at, p.id) < (coalesce(p_before, 'infinity'), public.cursor_id(p_before, p_before_id))
        and public.can_see_space_post(p.id)
        -- A target's work items are on its card (migration 37).
        -- A cancelled one keeps its own card, with its CANCELLED stamp,
        -- as every cancelled post does; the target's rows are live ones.
        and not (p.parent_id is not null and p.kind = 'work_item' and p.status = 'live'
                 and public.is_target(p.parent_id)
                 and public.can_see_space_post(p.parent_id))
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

-- As in migration 19, with my pinned posts ('mine') and no archived post.
create or replace function public.daybook_extras(p_space uuid, p_from timestamptz,
                                                 p_to timestamptz)
returns table (id uuid, reason text, post jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select (x.r).id, x.reason, public.space_post_json(x.r, false)
  from (
    select p as r, 'pinned'::text as reason, p.created_at as at
    from public.space_posts p
    where p.space_id = p_space and p.kind = 'announcement' and p.pinned_until > now()
      and p.status = 'live' and p.deleted_at is null and p.archived_at is null
    union all
    select p, 'mine', pin.created_at
    from public.space_post_pins pin
    join public.space_posts p on p.id = pin.post_id
    where pin.user_id = auth.uid() and p.space_id = p_space
      and p.deleted_at is null and p.archived_at is null
    union all
    select p, 'activity', p.starts_at
    from public.space_posts p
    where p.space_id = p_space and p.kind = 'activity'
      and p.starts_at >= p_from and p.starts_at < p_to
      and p.status = 'live' and p.deleted_at is null and p.archived_at is null
  ) x
  where public.is_member(p_space) and public.can_see_space_post((x.r).id)
    and p_to > p_from and p_to - p_from <= interval '2 days'
  order by x.reason desc, x.at desc, (x.r).id desc
  limit 50;
$$;

-- ---------------------------------------------------------------------------
-- 7. Send back to someone who has left
-- ---------------------------------------------------------------------------

-- As in 20261023120000_send_back_due, with [p_owner] for an item whose
-- owner may no longer sign it.
drop function public.send_back(uuid, text, text, boolean, date, timestamptz);
create function public.send_back(p_item uuid, p_reason text, p_note text default null,
                                 p_due_set boolean default false, p_due date default null,
                                 p_due_at timestamptz default null, p_owner uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_item public.work_items;
  -- The 0.9.0 test build still sends the old name; it is stored as the new
  -- one. Remove this once 0.9.0 is retired.
  v_reason text := case when p_reason = 'not_as_drawing' then 'not_as_asked' else p_reason end;
  v_new_due jsonb;
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
  if coalesce(p_due_set, false) then
    if p_due is null and p_due_at is not null then
      raise exception 'a due time needs its day' using errcode = '22023';
    end if;
    if p_due_at is not null and not public.due_at_fits(p_due, p_due_at) then
      raise exception 'a due time on its due day' using errcode = '22023';
    end if;
    v_new_due := jsonb_build_object('date', p_due, 'at', p_due_at);
    update public.space_posts set due_date = p_due, due_at = p_due_at where id = p_item;
    update public.work_items set due_date = p_due where id = p_item;
  elsif p_due is not null or p_due_at is not null then
    raise exception 'say that a new date was chosen' using errcode = '22023';
  end if;
  -- Its owner may no longer sign it (they left, or their pass changed): a
  -- new owner from the Give to list, in the same call. Otherwise it stays
  -- theirs.
  if v_item.owner_id is null or not public.member_can(v_item.space_id, v_item.owner_id, 'mark_done') then
    if p_owner is null or p_owner is not distinct from v_item.owner_id then
      raise exception 'choose who does it now' using errcode = '22023';
    end if;
  elsif p_owner is not null and p_owner <> v_item.owner_id then
    raise exception 'use Give to' using errcode = '22023';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, reason, note, new_due)
  values (p_item, v_me, 'sent_back', v_reason, nullif(trim(p_note), ''), v_new_due);
  if p_owner is not null and p_owner is distinct from v_item.owner_id then
    insert into public.work_item_events (work_item_id, actor_id, kind, from_owner_id, to_owner_id)
    values (p_item, v_me, 'reassigned', v_item.owner_id, p_owner);
  end if;
  update public.work_items set status = 'open', done_at = null,
                               owner_id = coalesce(p_owner, owner_id)
  where id = p_item;
end;
$$;

revoke all on function public.send_back(uuid, text, text, boolean, date, timestamptz, uuid)
  from public, anon;
grant execute on function public.send_back(uuid, text, text, boolean, date, timestamptz, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 8. The month: archived posts out
-- ---------------------------------------------------------------------------

-- As in 20261017180000_sent_back, with no archived post (L10).
create or replace function public.daybook_month(p_space uuid, p_from_day date, p_to_day date,
                                     p_from timestamptz, p_to timestamptz)
returns table (kind text, at timestamptz, day date)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_from_day is null or p_to_day is null or p_to_day < p_from_day
     or p_to_day - p_from_day > 61
     or p_from is null or p_to is null or p_to <= p_from
     -- An hour of slack for a change of clock in the phone's time zone.
     or p_to - p_from > interval '62 days 1 hour' then
    raise exception 'choose up to 62 days' using errcode = '22023';
  end if;
  if not public.is_member(p_space) then
    return;
  end if;
  return query
  -- Posts and their sign-offs and updates in the window; each post's
  -- visibility is checked once.
  with seen as (
    select p.id as post_id, p.created_at as at
    from public.space_posts p
    where p.space_id = p_space and p.deleted_at is null
      and p.created_at >= p_from and p.created_at < p_to
    union all
    -- Sign-offs, send-backs and updates are entries too (reviews 45 and 47).
    select e.work_item_id, e.created_at
    from public.work_item_events e
    where e.space_id = p_space and e.kind in ('done', 'comment', 'sent_back')
      and e.created_at >= p_from and e.created_at < p_to
  ),
  visible as (
    select v.post_id
    from (select distinct seen.post_id from seen) v
    join public.space_posts p on p.id = v.post_id and p.deleted_at is null
      and p.archived_at is null
    where public.can_see_space_post(v.post_id)
  )
  select distinct 'posts'::text,
         date_bin('15 minutes', seen.at, timestamptz '2000-01-01 00:00+00'), null::date
  from seen
  join visible on visible.post_id = seen.post_id
  union
  select 'due'::text, null::timestamptz, p.due_date
  from public.space_posts p
  left join public.work_items w on w.id = p.id
  where p.space_id = p_space and p.deleted_at is null and p.status = 'live'
    and p.archived_at is null
    and ((p.kind = 'checklist'
          and exists (select 1 from public.checklist_points c
                      where c.post_id = p.id and c.ticked_at is null))
         or (p.kind = 'work_item' and w.status in ('open', 'done')))
    and p.due_date between p_from_day and p_to_day
    and public.can_see_space_post(p.id)
  order by 1, 2, 3;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. A post's archive and place; a shared post that is gone
-- ---------------------------------------------------------------------------

-- As in 20261107120000_post_numbers, with archived_at and place_id.
create or replace function public.space_post_json(p_post space_posts, p_full boolean)
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

-- A post shared in a thread I read (kind 'post') that was deleted: its
-- card says it isn't in Work any more, not that I can't see it.
create or replace function public.shared_post_gone(p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.messages m
    join public.space_posts p on p.id = m.post_id
    where m.post_id = p_post and m.kind = 'post' and m.deleted_at is null
      and public.can_use_thread(m.thread_id) and p.deleted_at is not null);
$$;

-- ---------------------------------------------------------------------------
-- Who may call what
-- ---------------------------------------------------------------------------

revoke all on function public.check_post_place() from public, anon, authenticated;
revoke all on function public.require_archivable(uuid) from public, anon, authenticated;
revoke all on function public.hand_over_open_work(uuid, uuid, jsonb) from public, anon, authenticated;
revoke all on function public.owns_open_work(uuid, uuid) from public, anon, authenticated;
revoke all on function public.check_work_owner() from public, anon, authenticated;
revoke all on function public.set_post_place(uuid, uuid) from public, anon;
revoke all on function public.shared_post_gone(uuid) from public, anon;
grant execute on function public.shared_post_gone(uuid) to authenticated;
grant execute on function public.set_post_place(uuid, uuid) to authenticated;
revoke all on function public.archive_space_post(uuid) from public, anon;
revoke all on function public.unarchive_space_post(uuid) from public, anon;
revoke all on function public.pin_space_post(uuid) from public, anon;
revoke all on function public.unpin_space_post(uuid) from public, anon;
revoke all on function public.share_post_to_thread(uuid, uuid, uuid) from public, anon;
revoke all on function public.space_time_zone(uuid) from public, anon;
revoke all on function public.time_zone(public.spaces) from public, anon;
revoke all on function public.remove_member_with_handover(uuid, uuid, jsonb) from public, anon;
revoke all on function public.leave_space_with_handover(uuid, jsonb) from public, anon;
grant execute on function public.archive_space_post(uuid) to authenticated;
grant execute on function public.unarchive_space_post(uuid) to authenticated;
grant execute on function public.pin_space_post(uuid) to authenticated;
grant execute on function public.unpin_space_post(uuid) to authenticated;
grant execute on function public.share_post_to_thread(uuid, uuid, uuid) to authenticated;
grant execute on function public.space_time_zone(uuid) to authenticated;
grant execute on function public.time_zone(public.spaces) to authenticated;
grant execute on function public.remove_member_with_handover(uuid, uuid, jsonb) to authenticated;
grant execute on function public.leave_space_with_handover(uuid, jsonb) to authenticated;
