-- Migration 58 (review 110 E): Thanks, and tags on work items.
--
-- 1. Thanks («شكر», TH1, TH2): a new post kind, 'thanks', written only by
--    create_thanks. To a person (a current member other than the author) or
--    to a Team of the Space; For, optional, is a live work item of the same
--    Space the author can see. The words are the post's body (optional, up
--    to 5000 characters, as any post); a Thanks has no title (''), since
--    its card shows To, For and the words. It goes to the whole Space (no
--    Team line): a Team is thanked in front of everyone.
--    Who may thank: any current member of the Space, a Viewer too (the
--    founder, 1 Nov, review 110). Never a hidden account, and never to one,
--    nor to someone blocked either way (W3).
--    Its facts are in space_thanks, read by whoever can see the post and
--    written only by the functions. Only the person thanked chooses Show on
--    my profile (set_thanks_on_profile); a Team's Thanks has no profile.
--    profile_thanks gives a profile's shown ones: who thanked, the words,
--    the date and the project's name (as shown work gives it), never the
--    Space's name, the For item or its photos (rule 8: work stays in
--    Spaces). No counts and no rankings (rule 3). A hidden account's
--    Thanks, and a hidden profile's, show to nobody (W3).
--    A Thanks needs nobody: no needs-you, no sign-off, no reminder, no
--    notification (card_needs_me and every kind switch already leave it out).
-- 2. Tags on work items (TG1): a market-pack list, market_work_tags
--    (Safety, Quality, Design, Material, Admin for Kuwait and Egypt; Safety
--    is danger, shown red). work_items.tag is at most one id from the list
--    of the Space's market (its project's). A Space with no project takes
--    any id that is on some market's list. A trigger checks it on every
--    write. create_work_item takes p_tag (one function: the old signature is
--    dropped, and scheduled_call_sql pins the new one, so Post later keeps
--    working); set_work_item_tag changes it while the item is Open, for a
--    caller who may still make work items (W4: not one moved to Viewer). Cards
--    carry the tag with its name and danger; space_work_tags gives the
--    picker its list. The Work filter is the app's, on the cards it reads
--    (as the place filter, migration 53).
-- 3. delete_team also keeps a Team that was thanked ("it stays in the
--    record").
-- 4. Post later takes create_thanks too (W7), pinned to its signature.

-- ---------------------------------------------------------------------------
-- 1. The kind
-- ---------------------------------------------------------------------------

alter table public.space_posts drop constraint space_posts_kind_check;
alter table public.space_posts add constraint space_posts_kind_check
  check (kind in ('note', 'work_item', 'checklist', 'announcement', 'activity', 'file', 'report',
                  'thanks'));

-- A Thanks has no title; every other post has one of 1 to 200 characters.
alter table public.space_posts drop constraint space_posts_title_check;
alter table public.space_posts add constraint space_posts_title_check
  check (case when kind = 'thanks' then title = ''
              else length(trim(title)) between 1 and 200 end);

-- ---------------------------------------------------------------------------
-- 2. Thanks
-- ---------------------------------------------------------------------------

create table public.space_thanks (
  post_id uuid primary key references public.space_posts (id) on delete cascade,
  space_id uuid not null references public.spaces (id) on delete cascade,
  -- A person or a Team. A person who deletes their account leaves the
  -- Thanks to a former member (to_profile null), so the kind is kept here.
  to_kind text not null check (to_kind in ('person', 'team')),
  to_profile uuid references public.profiles (id) on delete set null,
  -- delete_team keeps a Team that was thanked.
  to_team uuid references public.teams (id),
  -- The work item it was for, if any.
  for_post uuid references public.space_posts (id) on delete set null,
  show_on_profile boolean not null default false,
  shown_at timestamptz,
  created_at timestamptz not null default now(),
  check ((to_kind = 'team') = (to_team is not null)),
  check (to_kind = 'person' or to_profile is null),
  check (not show_on_profile or to_kind = 'person'),
  check (show_on_profile = (shown_at is not null))
);
create index space_thanks_profile_idx on public.space_thanks (to_profile, created_at desc)
  where show_on_profile;
create index space_thanks_for_idx on public.space_thanks (for_post) where for_post is not null;
create index space_thanks_team_idx on public.space_thanks (to_team) where to_team is not null;

alter table public.space_thanks enable row level security;

create policy space_thanks_read on public.space_thanks
  for select to authenticated
  using (public.can_see_space_post(post_id));

revoke all on public.space_thanks from public, anon, authenticated;
grant select on public.space_thanks to authenticated;
grant all on public.space_thanks to service_role;

-- TH1: [p_body] thanks [p_to_person] or [p_to_team], for the work item
-- [p_for] (optional), with up to 10 photos [p_files] (as create_space_post).
-- The same [p_id] again is the same Thanks.
create or replace function public.create_thanks(
  p_id uuid,
  p_space uuid,
  p_body text default null,
  p_to_person uuid default null,
  p_to_team uuid default null,
  p_for uuid default null,
  p_files jsonb default '[]'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_for public.space_posts;
  v_body text := nullif(trim(coalesce(p_body, '')), '');
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_id is null then
    raise exception 'its id is the app''s' using errcode = '22023';
  end if;
  -- The same id again (a retry): the same post, if it is the caller's.
  select * into v_post from public.space_posts where id = p_id;
  if v_post.id is not null then
    if v_post.author_id = v_me and v_post.space_id = p_space and v_post.kind = 'thanks' then
      return v_post.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;

  -- Any current member, a Viewer too (the founder, 1 Nov).
  if not public.is_member(p_space) or public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if public.folder_has_others_files_in(p_space::text || '/posts/' || p_id::text || '/') then
    raise exception 'this id is taken' using errcode = '42501';
  end if;

  if (p_to_person is null) = (p_to_team is null) then
    raise exception 'thank a person or a team' using errcode = '22023';
  end if;
  if p_to_person = v_me then
    raise exception 'thank someone else' using errcode = '22023';
  end if;
  -- Never to a hidden account, nor to someone blocked either way (W3), as
  -- a direct message.
  if p_to_person is not null and (public.is_hidden_account(p_to_person)
                                  or public.is_blocked_with(p_to_person)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_to_person is not null and not exists (
       select 1 from public.space_members m
       where m.space_id = p_space and m.profile_id = p_to_person and m.left_at is null) then
    raise exception 'only someone in this Space' using errcode = '22023';
  end if;
  if p_to_team is not null and not exists (
       select 1 from public.teams t where t.id = p_to_team and t.space_id = p_space) then
    raise exception 'team not in this Space' using errcode = '22023';
  end if;
  if p_for is not null then
    select * into v_for from public.space_posts where id = p_for;
    if v_for.id is null or v_for.space_id <> p_space or v_for.kind <> 'work_item'
       or v_for.status <> 'live' or v_for.deleted_at is not null
       or not public.can_see_space_post(v_for.id) then
      raise exception 'only a work item of this Space' using errcode = '22023';
    end if;
  end if;
  if length(v_body) > 5000 then
    raise exception 'at most 5000 characters' using errcode = '22023';
  end if;

  insert into public.space_posts (id, space_id, kind, author_id, title, body)
  values (p_id, p_space, 'thanks', v_me, '', v_body)
  returning * into v_post;
  insert into public.space_thanks (post_id, space_id, to_kind, to_profile, to_team, for_post)
  values (p_id, p_space, case when p_to_team is null then 'person' else 'team' end,
          p_to_person, p_to_team, p_for);
  perform public.add_post_files(v_post, p_files);
  return p_id;
exception
  when invalid_text_representation then
    raise exception 'an id is not valid' using errcode = '22023';
end;
$$;

-- TH2: the person thanked shows it on their profile, or not. A Team's
-- Thanks has no profile choice.
create or replace function public.set_thanks_on_profile(p_post uuid, p_show boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.space_thanks;
begin
  select * into v_row from public.space_thanks where post_id = p_post for update;
  if v_row.post_id is null or auth.uid() is null or v_row.to_kind <> 'person'
     or v_row.to_profile is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not exists (select 1 from public.space_posts p
                 where p.id = p_post and p.status = 'live' and p.deleted_at is null) then
    raise exception 'this Thanks was cancelled' using errcode = 'P0001';
  end if;
  if coalesce(p_show, false) is distinct from v_row.show_on_profile then
    update public.space_thanks
    set show_on_profile = coalesce(p_show, false),
        shown_at = case when coalesce(p_show, false) then now() end
    where post_id = p_post;
  end if;
end;
$$;

-- The profile's Thanks: only the ones its person chose to show, of live
-- posts in Spaces that are not deleted. Who thanked (left out when the
-- reader and that person have blocked each other, as is the whole row),
-- the words, the date and the project's name. Signed-in readers only.
-- None from a hidden thanker, and none on a hidden profile (W3), even to
-- that person (is_blocked_with leaves out the reader's own account).
create or replace function public.profile_thanks(p_profile uuid)
returns table (post_id uuid, from_id uuid, from_name text, words text,
               created_at timestamptz, project_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select th.post_id, p.author_id, public.space_person_name(p.author_id), p.body,
         p.created_at, pr.name
  from public.space_thanks th
  join public.space_posts p on p.id = th.post_id and p.status = 'live' and p.deleted_at is null
  join public.spaces s on s.id = th.space_id and s.deleted_at is null
  left join public.projects pr on pr.id = s.project_id
  where auth.uid() is not null
    and th.to_profile = p_profile and th.to_kind = 'person' and th.show_on_profile
    and not public.is_hidden_account(p_profile)
    and not public.is_blocked_with(p_profile)
    and (p.author_id is null or (not public.is_hidden_account(p.author_id)
                                 and not public.is_blocked_with(p.author_id)))
  order by p.created_at desc, th.post_id desc
  limit 200;
$$;

-- delete_team (migration 4), as it was, and a thanked Team stays too.
create or replace function public.delete_team(p_team uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_space uuid := (select t.space_id from public.teams t where t.id = p_team);
begin
  if v_space is null or not public.is_space_admin(v_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if exists (select 1 from public.messages m join public.threads t on t.id = m.thread_id
             where t.team_id = p_team)
     or exists (select 1 from public.library_files f where f.team_id = p_team)
     or exists (select 1 from public.space_posts p where p.team_id = p_team)
     or exists (select 1 from public.space_thanks th where th.to_team = p_team) then
    raise exception 'this Team has chat, files or posts; it stays in the record'
      using errcode = 'P0001';
  end if;
  delete from public.teams where id = p_team;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Work tags
-- ---------------------------------------------------------------------------

create table public.market_work_tags (
  market_id text not null references public.markets (id),
  id text not null check (id ~ '^[a-z][a-z_]{1,29}$'),
  name jsonb not null check (public.is_label(name)),
  -- Shown red (Safety).
  danger boolean not null default false,
  sort smallint not null default 0,
  primary key (market_id, id)
);

alter table public.market_work_tags enable row level security;
create policy market_work_tags_read on public.market_work_tags
  for select to authenticated
  using (true);
revoke all on public.market_work_tags from public, anon, authenticated;
grant select on public.market_work_tags to authenticated;
grant all on public.market_work_tags to service_role;

insert into public.market_work_tags (market_id, id, name, danger, sort)
select m.id, t.id, t.name, t.danger, t.sort
from public.markets m
cross join (values
  ('safety', '{"en": "Safety", "ar": "سلامة"}'::jsonb, true, 1),
  ('quality', '{"en": "Quality", "ar": "جودة"}'::jsonb, false, 2),
  ('design', '{"en": "Design", "ar": "تصميم"}'::jsonb, false, 3),
  ('material', '{"en": "Material", "ar": "مواد"}'::jsonb, false, 4),
  ('admin', '{"en": "Admin", "ar": "إداري"}'::jsonb, false, 5)
) t(id, name, danger, sort)
where m.id in ('kw', 'eg');

alter table public.work_items add column tag text check (tag ~ '^[a-z][a-z_]{1,29}$');

-- The market whose list [p_space] uses: its project's. A Space with no
-- project shows the reader's home market's list.
create or replace function public.space_tag_market(p_space uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select pr.market_id from public.spaces s
     join public.projects pr on pr.id = s.project_id
     where s.id = p_space),
    (select p.home_market_id from public.profiles p where p.id = auth.uid()));
$$;

-- [p_tag] may go on a work item of [p_space]: on its project's market's
-- list; with no project, on any market's list.
create or replace function public.is_work_tag(p_space uuid, p_tag text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when (select s.project_id from public.spaces s where s.id = p_space) is not null then
      exists (select 1 from public.market_work_tags t
              join public.projects pr on pr.market_id = t.market_id
              join public.spaces s on s.project_id = pr.id
              where s.id = p_space and t.id = p_tag)
    else exists (select 1 from public.market_work_tags t where t.id = p_tag)
  end;
$$;

-- Every write of a tag.
create or replace function public.check_work_tag()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.tag is not null and not public.is_work_tag(new.space_id, new.tag) then
    raise exception 'a tag from the list' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger work_items_tag_check
  before insert or update of tag on public.work_items
  for each row execute function public.check_work_tag();

-- [p_tag] as a card shows it: its id, name and danger, from the Space's
-- market's list (the reader's home market's for a Space with no project,
-- then any market's). An id no longer on any list keeps its id only.
create or replace function public.work_tag_json(p_space uuid, p_tag text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_tag is not null then coalesce((
    select jsonb_build_object('id', t.id, 'name', t.name, 'danger', t.danger)
    from public.market_work_tags t
    join public.markets mk on mk.id = t.market_id
    where t.id = p_tag
    order by (t.market_id is not distinct from public.space_tag_market(p_space)) desc,
             mk.sort, mk.id
    limit 1), jsonb_build_object('id', p_tag)) end;
$$;

-- TG1: the list the picker shows for [p_space], for its members: its
-- market's (space_tag_market); with none, every id once.
create or replace function public.space_work_tags(p_space uuid)
returns table (id text, name jsonb, danger boolean, sort smallint)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_market text;
begin
  if not public.is_member(p_space) then
    return;
  end if;
  v_market := public.space_tag_market(p_space);
  if exists (select 1 from public.market_work_tags t where t.market_id = v_market) then
    return query
      select t.id, t.name, t.danger, t.sort from public.market_work_tags t
      where t.market_id = v_market
      order by t.sort, t.id;
  else
    return query
      select x.id, x.name, x.danger, x.sort from (
        select distinct on (t.id) t.id, t.name, t.danger, t.sort
        from public.market_work_tags t
        join public.markets mk on mk.id = t.market_id
        order by t.id, mk.sort, mk.id) x
      order by x.sort, x.id;
  end if;
end;
$$;

-- TG1: the tag of the work item [p_post], or none (null). Its creator,
-- its owner or a Lead, while it is Open, and only while they may make work
-- items (W4): someone moved down to Viewer can't.
create or replace function public.set_work_item_tag(p_post uuid, p_tag text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_post public.space_posts;
  v_item public.work_items;
  v_tag text := nullif(trim(coalesce(p_tag, '')), '');
begin
  select * into v_post from public.space_posts where id = p_post for no key update;
  if v_me is null or v_post.id is null or v_post.kind <> 'work_item'
     or v_post.status <> 'live' or v_post.deleted_at is not null
     or not public.is_member(v_post.space_id) or not public.can_see_space_post(p_post)
     or not public.can(v_post.space_id, 'create_items')
     or public.is_hidden_account(v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_item from public.work_items where id = p_post for update;
  if not (v_post.author_id = v_me or v_item.created_by = v_me or v_item.owner_id = v_me
          or public.member_pass(v_post.space_id) = 'lead') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.status is distinct from 'open' then
    raise exception 'only an open work item' using errcode = '22023';
  end if;
  if v_tag is distinct from v_item.tag then
    update public.work_items set tag = v_tag where id = p_post;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. create_work_item takes a tag (one function)
-- ---------------------------------------------------------------------------

drop function public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid,
                                      uuid, jsonb, jsonb, uuid, jsonb, jsonb, timestamptz);

-- create_work_item (migration 46), as it was, and p_tag: the work item's tag.
CREATE OR REPLACE FUNCTION public.create_work_item(p_space uuid, p_title text, p_owner uuid, p_due date DEFAULT NULL::date, p_team uuid DEFAULT NULL::uuid, p_place text DEFAULT NULL::text, p_evidence jsonb DEFAULT '[]'::jsonb, p_id uuid DEFAULT NULL::uuid, p_body text DEFAULT NULL::text, p_parent uuid DEFAULT NULL::uuid, p_source_message uuid DEFAULT NULL::uuid, p_quote jsonb DEFAULT NULL::jsonb, p_files jsonb DEFAULT '[]'::jsonb, p_template uuid DEFAULT NULL::uuid, p_blocks jsonb DEFAULT NULL::jsonb, p_points jsonb DEFAULT NULL::jsonb, p_due_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_tag text DEFAULT NULL::text)
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
                                 team_id, place_text, due_date, tag)
  values (v_id, p_space, v_number, v_post.ref,
          trim(p_title), p_owner, v_me, v_team, nullif(trim(p_place), ''), p_due,
          -- Migration 58: at most one tag, from the list (work_items_tag_check).
          nullif(trim(p_tag), ''))
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

-- ---------------------------------------------------------------------------
-- 5. Cards: the tag and the Thanks (space_post_json, which every card
--    reader uses: daybook_cards, daybook_card and the opened post)
-- ---------------------------------------------------------------------------

-- space_post_json (migration 52), as it was, and the tag and the Thanks.
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
  )) end;
$function$;
-- ---------------------------------------------------------------------------
-- 6. Post later: create_work_item's new signature, and create_thanks
-- ---------------------------------------------------------------------------

-- W7: a Thanks can be scheduled.
alter table public.scheduled_posts drop constraint scheduled_posts_fn_check;
alter table public.scheduled_posts add constraint scheduled_posts_fn_check
  check (fn in ('create_space_post', 'create_work_item', 'create_post',
                'share_note_to_feed', 'share_note_to_space', 'create_thanks'));

-- scheduled_call_sql (migration 57), as it was, with create_work_item's
-- signature now ending in p_tag text, and create_thanks (W7). Waiting rows
-- made before keep working: an argument they don't name takes its default.
create or replace function public.scheduled_call_sql(p_fn text, p_params jsonb)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  with fn as (
    select to_regprocedure(case p_fn
      when 'create_space_post' then 'public.create_space_post(uuid, uuid, text, text, text, uuid, text, date, timestamptz, timestamptz, timestamptz, uuid, uuid[], jsonb, uuid, jsonb, jsonb, uuid, jsonb, timestamptz)'
      when 'create_work_item' then 'public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid, uuid, jsonb, jsonb, uuid, jsonb, jsonb, timestamptz, text)'
      when 'create_post' then 'public.create_post(uuid, text, text, uuid, jsonb)'
      when 'share_note_to_feed' then 'public.share_note_to_feed(uuid, uuid, text, text[], uuid, boolean, jsonb)'
      when 'share_note_to_space' then 'public.share_note_to_space(uuid, uuid, uuid, text, text[], uuid, uuid, boolean, jsonb, uuid[])'
      when 'create_thanks' then 'public.create_thanks(uuid, uuid, text, uuid, uuid, uuid, jsonb)'
    end) as oid
  ),
  args as (
    select a.name, format_type(a.typ, null) as typ
    from fn
    join pg_proc p on p.oid = fn.oid
    cross join lateral unnest(p.proargnames[1:p.pronargs], p.proargtypes::oid[]) a(name, typ)
  )
  select case
    when (select oid from fn) is null then null
    when exists (select 1 from jsonb_object_keys(p_params) k
                 where k not in (select name from args)) then null
    else format('select public.%I(%s)', p_fn, coalesce((
      select string_agg(format('%I => %s', a.name, case
        when a.typ like '%[]' then format(
          '(case when jsonb_typeof($1 -> %L) = ''array'' then array(select jsonb_array_elements_text($1 -> %L))::%s end)',
          a.name, a.name, a.typ)
        when a.typ in ('jsonb', 'json') then format('nullif($1 -> %L, ''null''::jsonb)', a.name)
        else format('($1 ->> %L)::%s', a.name, a.typ)
      end), ', ')
      from args a where p_params ? a.name), ''))
  end;
$$;

-- schedule_post (migration 57), as it was, and create_thanks (W7).
create or replace function public.schedule_post(
  p_id uuid,
  p_fn text,
  p_params jsonb,
  p_at timestamptz,
  p_title text,
  p_note uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_space uuid;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if exists (select 1 from public.scheduled_posts where id = p_id and author_id = v_me) then
    return p_id;
  end if;
  if exists (select 1 from public.scheduled_posts where id = p_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_note is not null and not exists (select 1 from public.notes n
                                        where n.id = p_note and n.owner_id = v_me) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_fn is null or p_fn not in ('create_space_post', 'create_work_item', 'create_post',
                                  'share_note_to_feed', 'share_note_to_space', 'create_thanks')
     or p_params is null or jsonb_typeof(p_params) <> 'object'
     or public.scheduled_call_sql(p_fn, p_params) is null then
    raise exception 'only a post can be scheduled' using errcode = '22023';
  end if;
  if coalesce(p_params ->> case when p_fn like 'share_note_%' then 'p_post' else 'p_id' end, '')
     <> p_id::text then
    raise exception 'its id is the post''s' using errcode = '22023';
  end if;
  if p_at is null or p_at <= now() or p_at > now() + interval '1 year' then
    raise exception 'a time to come' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_title, ''))) not between 1 and 200 then
    raise exception 'what it says' using errcode = '22023';
  end if;
  v_space := nullif(p_params ->> 'p_space', '')::uuid;
  if v_space is not null and not public.is_member(v_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if (select count(*) from public.scheduled_posts
      where author_id = v_me and state = 'waiting') >= 100 then
    raise exception 'at most 100 waiting' using errcode = '22023';
  end if;
  insert into public.scheduled_posts (id, author_id, fn, params, space_id, title, publish_at, note_id)
  values (p_id, v_me, p_fn, p_params, v_space, trim(p_title), p_at, p_note);
  return p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function public.scheduled_call_sql(text, jsonb) from public, anon, authenticated;
revoke all on function public.space_post_json(public.space_posts, boolean) from public, anon, authenticated;
revoke all on function public.create_thanks(uuid, uuid, text, uuid, uuid, uuid, jsonb) from public, anon;
revoke all on function public.set_thanks_on_profile(uuid, boolean) from public, anon;
revoke all on function public.profile_thanks(uuid) from public, anon;
revoke all on function public.delete_team(uuid) from public, anon;
revoke all on function public.schedule_post(uuid, text, jsonb, timestamptz, text, uuid) from public, anon;
revoke all on function public.space_tag_market(uuid) from public, anon, authenticated;
revoke all on function public.is_work_tag(uuid, text) from public, anon, authenticated;
revoke all on function public.check_work_tag() from public, anon, authenticated;
revoke all on function public.work_tag_json(uuid, text) from public, anon, authenticated;
revoke all on function public.space_work_tags(uuid) from public, anon;
revoke all on function public.set_work_item_tag(uuid, text) from public, anon;
revoke all on function public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid,
                                               uuid, jsonb, jsonb, uuid, jsonb, jsonb, timestamptz, text)
  from public, anon;

grant execute on function public.create_thanks(uuid, uuid, text, uuid, uuid, uuid, jsonb) to authenticated;
grant execute on function public.set_thanks_on_profile(uuid, boolean) to authenticated;
grant execute on function public.profile_thanks(uuid) to authenticated;
grant execute on function public.delete_team(uuid) to authenticated;
grant execute on function public.schedule_post(uuid, text, jsonb, timestamptz, text, uuid) to authenticated;
grant execute on function public.space_work_tags(uuid) to authenticated;
grant execute on function public.set_work_item_tag(uuid, text) to authenticated;
grant execute on function public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid,
                                                  uuid, jsonb, jsonb, uuid, jsonb, jsonb, timestamptz, text)
  to authenticated;

-- Review 110 W8 (the lead's check): the app's notebook share no longer
-- offers Checklist as a kind; a note's to-do lines put in as a work item
-- become that item's checklist. 'checklist' is still taken here, for the
-- builds already on phones.
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
    -- Review 110 W8: the note's to-do lines (of the lines chosen) become
    -- the work item's checklist, and leave its words.
    for v_block in
      select b from jsonb_array_elements(coalesce(v_note.blocks, '[]')) b
      where b ->> 'type' = 'todo' and (p_lines is null or (b ->> 'id') = any (p_lines))
    loop
      v_points := v_points || jsonb_build_object('text', v_block ->> 'text');
    end loop;
    if jsonb_array_length(v_points) > 0 then
      v_body := nullif(trim(both E'\n' from regexp_replace(coalesce(v_body, ''),
                       '(^|\n)\s*\[( |x)\] [^\n]*', '', 'g')), '');
    end if;
    v_id := public.create_work_item(p_space, v_title, p_owner, p_team => p_team, p_place => v_place,
                                    p_id => p_post, p_body => nullif(concat_ws(E'\n', v_body, v_loc), ''),
                                    p_files => p_files, p_points => v_points);
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
