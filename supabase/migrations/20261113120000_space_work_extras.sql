-- Migration 52 (review 105B): a Space's Work extras, in six parts.
--
-- 1. Places (site tags): space_places, a name unique in its Space whatever
--    its case and spaces. Members read; those who may post work add;
--    Leads rename and delete. space_posts.place_id points to one of its
--    own Space's; the free-text place_text stays readable on older posts.
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
-- 5. The Space's time zone: space_time_zone(space), from its market pack
--    (markets.time_zone, migration 13): its project's market, else its
--    maker's home market, else UTC; for members only. Also read with the
--    Space as spaces.time_zone (a computed column). The app ends a pinned
--    announcement at midnight there.
-- 6. Handover: remove_member_with_handover and leave_space_with_handover
--    give every open work item the person owns a new owner who may own work
--    (an active member who may sign it as done, of its Team or an admin),
--    or nothing changes. Their Done and Checked work stays where it is.

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
  insert into public.messages (id, thread_id, space_id, author_id, kind, post_id)
  values (p_id, p_thread, v_thread.space_id, v_me, 'post', p_post);
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
  return coalesce(
    (select m.time_zone from public.spaces s
     join public.projects pr on pr.id = s.project_id
     join public.markets m on m.id = pr.market_id
     where s.id = p_space),
    (select m.time_zone from public.spaces s
     join public.profiles pf on pf.id = s.created_by
     join public.markets m on m.id = pf.home_market_id
     where s.id = p_space),
    'UTC');
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
  if not public.is_member(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform public.hand_over_open_work(p_space, auth.uid(), p_assignments);
  perform public.leave_space(p_space);
end;
$$;

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
-- Who may call what
-- ---------------------------------------------------------------------------

revoke all on function public.check_post_place() from public, anon, authenticated;
revoke all on function public.require_archivable(uuid) from public, anon, authenticated;
revoke all on function public.hand_over_open_work(uuid, uuid, jsonb) from public, anon, authenticated;
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
