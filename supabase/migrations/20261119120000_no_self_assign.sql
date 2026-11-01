-- Review 112 (founder, 1 Nov): a work item is always for someone else.
-- What's yours alone belongs in My notebook. This replaces review 50 F69
-- (a work item may be for yourself).
--
-- 1. A new work item is never for the person making it, whichever way it is
--    made: create_work_item (and so the notebook share, a walk's lines,
--    work items from a message, a template), and a scheduled one when it
--    goes out (it runs as its author). Give to (reassign_work_item) refuses
--    yourself too. A handover is not "for yourself": when a member is
--    removed or leaves, or Send back needs a new owner because theirs left,
--    their open work may still go to the admin (review 105B L1). Items
--    already for their author stay as they are.
-- 2. A work item can't be scheduled for yourself either: refused when it is
--    scheduled, not only when it goes out.
-- 3. my_postable_spaces(): the notebook share's Space list in one call.

-- ---------------------------------------------------------------------------
-- 1. Never for yourself
-- ---------------------------------------------------------------------------

create or replace function public.work_item_not_for_self()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.owner_id is null or new.owner_id is distinct from auth.uid() then
    return new;
  end if;
  -- A walk's, or a message's, parent item is its author's: it holds the
  -- lines, which are each for someone else (create_walk and
  -- create_from_message make it first, in a batch, with no parent).
  if coalesce(current_setting('bv.batch', true), 'off') = 'on'
     and exists (select 1 from public.space_posts p
                 where p.id = new.id and p.parent_id is null) then
    return new;
  end if;
  raise exception 'a work item is for someone else' using errcode = '22023';
end;
$$;

create trigger work_items_not_for_self
  before insert on public.work_items
  for each row execute function public.work_item_not_for_self();

-- ---------------------------------------------------------------------------
-- 2. Not scheduled for yourself
-- ---------------------------------------------------------------------------

create or replace function public.scheduled_not_for_self()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (new.fn = 'create_work_item'
      or (new.fn = 'share_note_to_space' and new.params ->> 'p_kind' = 'work_item'))
     and new.params ->> 'p_owner' = new.author_id::text then
    raise exception 'a work item is for someone else' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger scheduled_posts_not_for_self
  before insert or update of params on public.scheduled_posts
  for each row execute function public.scheduled_not_for_self();

-- As in 20261015120000_daybook.sql, and Give to yourself is refused.
create or replace function public.reassign_work_item(p_item uuid, p_owner uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_item public.work_items;
  v_post public.space_posts;
begin
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
  if p_owner is not null and p_owner = v_me then
    raise exception 'a work item is for someone else' using errcode = '22023';
  end if;
  if p_owner is null or not public.member_can(v_item.space_id, p_owner, 'mark_done') then
    raise exception 'choose an owner who can sign it as done' using errcode = '22023';
  end if;
  insert into public.work_item_events (work_item_id, actor_id, kind, from_owner_id, to_owner_id)
  values (p_item, v_me, 'reassigned', v_item.owner_id, p_owner);
  update public.work_items set owner_id = p_owner where id = p_item;
end;
$$;

revoke all on function public.work_item_not_for_self() from public, anon, authenticated;
revoke all on function public.scheduled_not_for_self() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. The Spaces I can give work in, in one call
-- ---------------------------------------------------------------------------

-- Review 112 part 2: the notebook share's list called fetchSpace for every
-- Space (4 requests each). This returns my Spaces where I may create work
-- items, the ones I posted in last first, then the newest I joined.
create or replace function public.my_postable_spaces()
returns table (space_id uuid, name text, pass text, is_admin boolean, project_id uuid,
               project_name text, project_type_id text, last_used_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.name, m.pass, m.is_admin, s.project_id, p.name, p.type_id,
         (select max(sp.created_at) from public.space_posts sp
          where sp.space_id = s.id and sp.author_id = auth.uid() and sp.deleted_at is null)
  from public.space_members m
  join public.spaces s on s.id = m.space_id
  left join public.projects p on p.id = s.project_id
  where m.profile_id = auth.uid() and m.left_at is null and s.deleted_at is null
    and not public.is_hidden_account(auth.uid())
    and public.member_can(s.id, auth.uid(), 'create_items')
  order by 8 desc nulls last, m.confirmed_at desc, s.id;
$$;

revoke all on function public.my_postable_spaces() from public, anon;
grant execute on function public.my_postable_spaces() to authenticated;
