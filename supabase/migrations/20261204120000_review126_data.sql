-- Review 126 P2 + P3, stage 1: data and server (no screens yet).
--
--   * Projects for any kind of work (P3): a kind (Building … Other) and an
--     optional stage, from reference data. Only a building still needs its
--     building type; where it is stays optional for every kind.
--   * A CV entry gains what I did, status, featured (6 at most), "with"
--     (up to 2 registered companies, or a typed name: rule 4), one link,
--     tools (the market pack's list plus my own), and who sees it:
--     everyone | team_only | hidden. show_on_profile stays as its mirror
--     (true only for everyone), so today's readers keep their meaning.
--   * cv_project_media: ordered photos and videos (the first is the
--     cover), 10 at most, in the private bucket cv-media under the owner's
--     folder. A Space photo can be added only by whoever posted it (copied
--     on choice: rule 8).
--   * cv_project_teammates: people tagged on an entry. Each gets one
--     notification; no confirmation (proof comes later). "Team only" means
--     the owner and these teammates.
--   * experience_timeline(profile): roles by company, newest first, with a
--     promotion where two roles in a row are at the same company (P2). No
--     new column.
--   * my_profile_completion(): Finish your profile, from the server.

-- Reference data -------------------------------------------------------------------------------------

create table public.project_kinds (
  id text primary key check (id ~ '^[a-z][a-z_]{1,29}$'),
  name jsonb not null check (public.is_label(name)),
  -- A place on the ground (the app offers where it is).
  physical boolean not null default false,
  sort smallint not null default 0
);

alter table public.project_kinds enable row level security;
create policy project_kinds_read on public.project_kinds for select to anon, authenticated using (true);
grant select on public.project_kinds to anon, authenticated;

insert into public.project_kinds (id, name, physical, sort) values
  ('building', '{"en": "Building", "ar": "مبنى"}', true, 1),
  ('infrastructure', '{"en": "Infrastructure", "ar": "بنية تحتية"}', true, 2),
  ('interior', '{"en": "Interior", "ar": "تصميم داخلي"}', true, 3),
  ('design_study', '{"en": "Design study", "ar": "دراسة تصميم"}', false, 4),
  ('software', '{"en": "Software", "ar": "برمجيات"}', false, 5),
  ('website', '{"en": "Website", "ar": "موقع إلكتروني"}', false, 6),
  ('plugin_tool', '{"en": "Plugin or tool", "ar": "إضافة أو أداة"}', false, 7),
  ('research', '{"en": "Research", "ar": "بحث"}', false, 8),
  ('course', '{"en": "Course", "ar": "دورة تدريبية"}', false, 9),
  ('other', '{"en": "Other", "ar": "أخرى"}', false, 10);

create table public.project_stages (
  id text primary key check (id ~ '^[a-z][a-z_]{1,29}$'),
  name jsonb not null check (public.is_label(name)),
  sort smallint not null default 0
);

alter table public.project_stages enable row level security;
create policy project_stages_read on public.project_stages for select to anon, authenticated using (true);
grant select on public.project_stages to anon, authenticated;

insert into public.project_stages (id, name, sort) values
  ('design', '{"en": "Design", "ar": "تصميم"}', 1),
  ('tender', '{"en": "Tender", "ar": "مناقصة"}', 2),
  ('construction', '{"en": "Construction", "ar": "تنفيذ"}', 3),
  ('handover', '{"en": "Handover", "ar": "تسليم"}', 4);

-- The tools a market's people pick from (the market pack); their own
-- are typed beside them.
create table public.market_tools (
  market_id text not null references public.markets(id),
  id text not null check (id ~ '^[a-z][a-z0-9_]{1,29}$'),
  name jsonb not null check (public.is_label(name)),
  sort smallint not null default 0,
  primary key (market_id, id)
);

alter table public.market_tools enable row level security;
create policy market_tools_read on public.market_tools for select to authenticated using (true);
grant select on public.market_tools to authenticated;

insert into public.market_tools (market_id, id, name, sort)
select m.id, t.id, jsonb_build_object('en', t.name, 'ar', t.name), t.sort
from public.markets m
cross join (values ('revit', 'Revit', 1), ('autocad', 'AutoCAD', 2), ('navisworks', 'Navisworks', 3),
                   ('civil_3d', 'Civil 3D', 4), ('tekla', 'Tekla Structures', 5), ('etabs', 'ETABS', 6),
                   ('sap2000', 'SAP2000', 7), ('primavera_p6', 'Primavera P6', 8),
                   ('ms_project', 'Microsoft Project', 9), ('excel', 'Excel', 10),
                   ('sketchup', 'SketchUp', 11), ('dynamo', 'Dynamo', 12)) t(id, name, sort)
where m.id in ('kw', 'eg');

-- Projects for any kind of work ------------------------------------------------------------------

alter table public.projects
  add column kind_id text not null default 'building' references public.project_kinds(id),
  add column stage_id text references public.project_stages(id),
  alter column type_id drop not null;

-- A building still needs its building type (today's rule); no other kind
-- does.
create function public.project_kind_fits()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.kind_id = 'building' and new.type_id is null then
    raise exception 'a building needs its type' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger projects_kind_fits before insert or update of kind_id, type_id on public.projects
  for each row execute function public.project_kind_fits();

drop function public.create_project(text, text, text, text, text, date, date, boolean);
create function public.create_project(
  p_name text, p_type_id text, p_market_id text, p_place_id text default null,
  p_location_text text default null, p_start_month date default null, p_end_month date default null,
  p_end_expected boolean default false, p_kind_id text default 'building', p_stage_id text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if (select count(*) from public.projects p
      where p.created_by = v_me and p.created_at > now() - interval '1 day') >= 10 then
    raise exception 'too many projects today' using errcode = 'P0001';
  end if;
  insert into public.projects (
    name, type_id, market_id, place_id, location_text,
    start_month, end_month, end_expected, created_by, kind_id, stage_id
  ) values (
    trim(p_name), p_type_id, p_market_id, p_place_id,
    nullif(trim(p_location_text), ''),
    p_start_month, p_end_month, coalesce(p_end_expected, false), v_me,
    coalesce(p_kind_id, 'building'), p_stage_id
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.create_project(text, text, text, text, text, date, date, boolean, text, text)
  from public, anon;
grant execute on function public.create_project(text, text, text, text, text, date, date, boolean, text, text)
  to authenticated;

-- A CV entry ------------------------------------------------------------------------------------------

alter table public.cv_projects
  add column what_i_did text check (what_i_did is null or length(what_i_did) <= 200),
  add column status text check (status in ('in_progress', 'completed')),
  add column featured boolean not null default false,
  add column featured_order smallint check (featured_order >= 1),
  add column with_company_ids uuid[] not null default '{}' check (cardinality(with_company_ids) <= 2),
  add column with_company_text text
    check (with_company_text is null or length(trim(with_company_text)) between 1 and 120),
  add column link text check (link is null or (link ~* '^https?://[^[:space:]]+$' and length(link) <= 500)),
  add column tool_ids text[] not null default '{}' check (cardinality(tool_ids) <= 10),
  add column tools_text text[] not null default '{}' check (cardinality(tools_text) <= 5),
  add column visibility text not null default 'everyone'
    check (visibility in ('everyone', 'team_only', 'hidden')),
  add constraint cv_projects_one_with check (cardinality(with_company_ids) = 0 or with_company_text is null),
  add constraint cv_projects_featured_order check (featured = (featured_order is not null));

create unique index cv_projects_featured_order_idx on public.cv_projects (profile_id, featured_order)
  where featured;

update public.cv_projects
set status = case when end_month is null then 'in_progress' else 'completed' end,
    visibility = case when show_on_profile then 'everyone' else 'hidden' end;

alter table public.cv_projects alter column status set not null;

-- With no status given, an entry with an end is completed, otherwise in
-- progress. show_on_profile mirrors visibility (true only for everyone);
-- setting the old switch sets visibility to everyone or hidden. Each "with" company
-- is registered (rule 4: typed names stay text), and on the caller's side
-- of the demo split; each tool is in the owner's market list; my own
-- tools are 1-40 characters.
create function public.cv_project_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is null then
    new.status := case when new.end_month is null then 'in_progress' else 'completed' end;
  end if;
  if tg_op = 'INSERT' then
    if not new.show_on_profile and new.visibility = 'everyone' then
      new.visibility := 'hidden';
    end if;
  elsif new.show_on_profile is distinct from old.show_on_profile
        and new.visibility is not distinct from old.visibility then
    new.visibility := case when new.show_on_profile then 'everyone' else 'hidden' end;
  end if;
  new.show_on_profile := new.visibility = 'everyone';

  if exists (select 1 from unnest(new.with_company_ids) x
             where not exists (select 1 from public.companies c where c.id = x)) then
    raise exception 'not a registered company' using errcode = '23503';
  end if;
  if auth.uid() is not null and exists (
       select 1 from public.companies c
       where c.id = any(new.with_company_ids) and c.is_demo is distinct from public.viewer_is_demo()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if exists (select 1 from unnest(new.tool_ids) x
             where not exists (select 1 from public.market_tools t
                               join public.profiles p on p.id = new.profile_id
                               where t.market_id = p.home_market_id and t.id = x)) then
    raise exception 'not a listed tool' using errcode = '23503';
  end if;
  if exists (select 1 from unnest(new.tools_text) x where length(trim(x)) not between 1 and 40) then
    raise exception 'a tool is 1-40 characters' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger cv_projects_fields before insert or update on public.cv_projects
  for each row execute function public.cv_project_fields();

-- Six featured at most (counted once the statement is done).
create function public.cv_projects_featured_max()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.featured and (select count(*) from public.cv_projects c
                       where c.profile_id = new.profile_id and c.featured) > 6 then
    raise exception 'six featured projects at most' using errcode = 'P0001';
  end if;
  return null;
end;
$$;

create constraint trigger cv_projects_featured_max after insert or update of featured on public.cv_projects
  for each row execute function public.cv_projects_featured_max();

grant insert (what_i_did, status, featured, featured_order, with_company_ids, with_company_text, link,
              tool_ids, tools_text, visibility),
      update (what_i_did, status, featured, featured_order, with_company_ids, with_company_text, link,
              tool_ids, tools_text, visibility),
      select (what_i_did, status, featured, featured_order, with_company_ids, with_company_text, link,
              tool_ids, tools_text, visibility)
  on public.cv_projects to authenticated;

-- Teammates ---------------------------------------------------------------------------------------------

create table public.cv_project_teammates (
  cv_project_id uuid not null references public.cv_projects(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (cv_project_id, profile_id)
);

create index cv_project_teammates_profile_idx on public.cv_project_teammates (profile_id);

-- Who may read a CV entry: its owner; or, not across a block, anyone for
-- everyone, and its tagged teammates for team only.
create function public.can_read_cv_project(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.cv_projects c
    where c.id = p_id
      and (c.profile_id = auth.uid()
           or (not public.is_blocked_with(c.profile_id)
               and (c.visibility = 'everyone'
                    or (c.visibility = 'team_only'
                        and exists (select 1 from public.cv_project_teammates t
                                    where t.cv_project_id = c.id and t.profile_id = auth.uid()))))));
$$;

revoke all on function public.can_read_cv_project(uuid) from public, anon;
grant execute on function public.can_read_cv_project(uuid) to authenticated;

drop policy cv_projects_read on public.cv_projects;
create policy cv_projects_read on public.cv_projects for select to authenticated
  using (public.can_read_cv_project(id));

alter table public.cv_project_teammates enable row level security;
create policy cv_project_teammates_read on public.cv_project_teammates for select to authenticated
  using (profile_id = auth.uid() or public.can_read_cv_project(cv_project_id));
-- The entry's owner tags; the owner or the teammate removes.
create policy cv_project_teammates_insert on public.cv_project_teammates for insert to authenticated
  with check (exists (select 1 from public.cv_projects c
                      where c.id = cv_project_id and c.profile_id = auth.uid()));
create policy cv_project_teammates_delete on public.cv_project_teammates for delete to authenticated
  using (profile_id = auth.uid()
         or exists (select 1 from public.cv_projects c
                    where c.id = cv_project_id and c.profile_id = auth.uid()));
grant select, delete on public.cv_project_teammates to authenticated;
grant insert (cv_project_id, profile_id) on public.cv_project_teammates to authenticated;

-- Not myself, never across a block or to an account going away, 20 at most.
create function public.cv_teammate_fits()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid := (select c.profile_id from public.cv_projects c where c.id = new.cv_project_id);
begin
  if new.profile_id = v_owner then
    raise exception 'not yourself' using errcode = '23514';
  end if;
  if public.blocked_between(v_owner, new.profile_id) or public.is_hidden_account(new.profile_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if (select count(*) from public.cv_project_teammates t where t.cv_project_id = new.cv_project_id) >= 20 then
    raise exception 'twenty teammates at most' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger cv_project_teammates_fits before insert on public.cv_project_teammates
  for each row execute function public.cv_teammate_fits();

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check (kind = any (array[
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment', 'item_edited',
  'item_cancelled', 'announcement_new', 'checklist_for_you', 'activity_invited', 'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow', 'post_reply', 'post_useful',
  'content_removed', 'appeal_decided', 'poll_new', 'poll_closed', 'poll_tied', 'key_role_empty',
  'cv_teammate']));

-- One notification per person and entry, even if tagged again.
create function public.cv_teammate_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.cv_projects;
begin
  select * into v_entry from public.cv_projects c where c.id = new.cv_project_id;
  if not exists (select 1 from public.notifications n
                 where n.profile_id = new.profile_id and n.kind = 'cv_teammate'
                   and n.payload ->> 'cv_project_id' = new.cv_project_id::text) then
    insert into public.notifications (profile_id, kind, actor_id, payload)
    values (new.profile_id, 'cv_teammate', v_entry.profile_id,
            jsonb_build_object('cv_project_id', v_entry.id, 'project_id', v_entry.project_id));
  end if;
  return null;
end;
$$;

create trigger cv_project_teammates_notify after insert on public.cv_project_teammates
  for each row execute function public.cv_teammate_notify();

-- Photos and videos -------------------------------------------------------------------------------------

create table public.cv_project_media (
  id uuid primary key default gen_random_uuid(),
  cv_project_id uuid not null references public.cv_projects(id) on delete cascade,
  profile_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  -- <owner>/<entry>/<file> in cv-media.
  storage_path text not null unique check (storage_path !~ '\.\.'),
  mime text not null check (mime ~ '^(image|video)/[a-z0-9.+-]+$'),
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  duration_ms integer check (duration_ms is null or duration_ms between 1 and 600000),
  -- The first is the cover.
  sort smallint not null default 0 check (sort >= 0),
  -- A photo the owner posted in a Space, copied on choice (rule 8).
  source_post_file_id uuid references public.post_files(id) on delete set null,
  created_at timestamptz not null default now()
);

create index cv_project_media_entry_idx on public.cv_project_media (cv_project_id, sort);

alter table public.cv_project_media enable row level security;
create policy cv_project_media_read on public.cv_project_media for select to authenticated
  using (public.can_read_cv_project(cv_project_id));
create policy cv_project_media_insert on public.cv_project_media for insert to authenticated
  with check (profile_id = auth.uid()
              and split_part(storage_path, '/', 1) = auth.uid()::text
              and exists (select 1 from public.cv_projects c
                          where c.id = cv_project_id and c.profile_id = auth.uid()));
create policy cv_project_media_update on public.cv_project_media for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy cv_project_media_delete on public.cv_project_media for delete to authenticated
  using (profile_id = auth.uid());
grant select, delete on public.cv_project_media to authenticated;
grant insert (cv_project_id, storage_path, mime, width, height, duration_ms, sort, source_post_file_id),
      update (sort)
  on public.cv_project_media to authenticated;

-- A Space photo: only one the caller posted, a photo or a video.
create function public.cv_media_source_fits()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.source_post_file_id is not null and not exists (
       select 1 from public.post_files f
       where f.id = new.source_post_file_id and f.added_by = auth.uid()
         and f.mime ~ '^(image|video)/') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger cv_project_media_source before insert on public.cv_project_media
  for each row execute function public.cv_media_source_fits();

-- Ten per entry at most (counted once the statement is done).
create function public.cv_project_media_max()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.cv_project_media m where m.cv_project_id = new.cv_project_id) > 10 then
    raise exception 'ten photos or videos at most' using errcode = 'P0001';
  end if;
  return null;
end;
$$;

create constraint trigger cv_project_media_max after insert on public.cv_project_media
  for each row execute function public.cv_project_media_max();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cv-media', 'cv-media', false, 26214400,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'video/mp4', 'video/quicktime'])
on conflict (id) do nothing;

-- Upload: into the caller's own folder, <me>/<entry>/<file>, a photo or
-- a video, not from an account going away.
create function public.may_upload_cv_media(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and not public.is_hidden_account(auth.uid())
    and split_part(p_name, '/', 1) = auth.uid()::text
    and array_length(string_to_array(p_name, '/'), 1) = 3
    and p_name not like '%..%'
    and split_part(p_name, '/', 3) ~* '^[^/]+\.(jpg|jpeg|png|webp|heic|mp4|mov)$';
$$;

revoke all on function public.may_upload_cv_media(text) from public, anon;
grant execute on function public.may_upload_cv_media(text) to authenticated;

-- Change and delete: the owner's own folder. Read (signed URLs): the
-- owner, or whoever may read the entry the file belongs to.
create policy cv_media_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'cv-media' and public.may_upload_cv_media(name));
create policy cv_media_update on storage.objects for update to authenticated
  using (bucket_id = 'cv-media' and split_part(name, '/', 1) = auth.uid()::text)
  with check (bucket_id = 'cv-media' and split_part(name, '/', 1) = auth.uid()::text);
create policy cv_media_delete on storage.objects for delete to authenticated
  using (bucket_id = 'cv-media' and split_part(name, '/', 1) = auth.uid()::text);
create policy cv_media_read on storage.objects for select to authenticated
  using (bucket_id = 'cv-media'
         and (split_part(name, '/', 1) = auth.uid()::text
              or exists (select 1 from public.cv_project_media m
                         where m.storage_path = name and public.can_read_cv_project(m.cv_project_id))));

-- Experience: roles by company, with promotions (P2) ----------------------------------------------------

-- [p_profile]'s Experience as the caller may read it (experience_read
-- applies), newest first, in runs of roles at the same company. A role is
-- a promotion (promoted_on, its start) when the role before it, in the
-- same run, was at the same company.
create function public.experience_timeline(p_profile uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with e as (
    select x.id, x.title, x.company_id, x.start_month, x.end_month, x.created_at,
           coalesce(c.name, nullif(trim(x.company_name_text), '')) as company_name,
           coalesce(x.company_id::text, lower(nullif(trim(x.company_name_text), ''))) as company_key
    from public.experience x
    left join public.companies c on c.id = x.company_id
    where x.profile_id = p_profile
  ),
  ordered as (
    select e.*,
           row_number() over w as n,
           lag(e.company_key) over w as newer_key,
           lead(e.company_key) over w as older_key
    from e
    window w as (order by e.start_month desc, e.created_at desc, e.id)
  ),
  grouped as (
    select o.*,
           sum(case when o.company_key is not null and o.company_key = o.newer_key then 0 else 1 end)
             over (order by o.n) as run
    from ordered o
  )
  select coalesce(jsonb_agg(r.company order by r.run), '[]'::jsonb)
  from (
    select g.run,
           jsonb_build_object(
             'company_id', (array_agg(g.company_id order by g.n))[1],
             'company_name', (array_agg(g.company_name order by g.n))[1],
             'roles', jsonb_agg(jsonb_build_object(
                        'id', g.id, 'title', g.title,
                        'start_month', g.start_month, 'end_month', g.end_month,
                        'promoted_on', case when g.company_key is not null and g.company_key = g.older_key
                                            then g.start_month end)
                      order by g.n)) as company
    from grouped g
    group by g.run
  ) r;
$$;

revoke all on function public.experience_timeline(uuid) from public, anon;
grant execute on function public.experience_timeline(uuid) to authenticated;

-- Finish your profile -------------------------------------------------------------------------------------

-- The caller's own steps, in order: photo, title, current work, summary,
-- first project, and the phone number only while they are in a Space.
create function public.my_profile_completion()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_p public.profiles;
  v_work jsonb;
  v_steps text[];
  v_done boolean[];
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  select * into v_p from public.profiles p where p.id = v_me;
  v_work := public.current_work_entry(v_me, true);
  v_steps := array['photo', 'title', 'current_work', 'summary', 'first_project'];
  v_done := array[
    v_p.photo_path is not null,
    nullif(trim(coalesce(v_work ->> 'title', v_p.headline)), '') is not null,
    v_work is not null,
    nullif(trim(v_p.about), '') is not null,
    exists (select 1 from public.cv_projects c where c.profile_id = v_me)];
  if exists (select 1 from public.space_members m where m.profile_id = v_me and m.left_at is null) then
    v_steps := array_append(v_steps, 'phone');
    v_done := array_append(v_done, v_p.phone is not null);
  end if;
  return jsonb_build_object(
    'steps', to_jsonb(v_steps),
    'missing', coalesce((select jsonb_agg(s order by i) from unnest(v_steps, v_done) with ordinality x(s, d, i)
                         where not d), '[]'::jsonb),
    'done', (select count(*) from unnest(v_done) d where d),
    'total', cardinality(v_steps));
end;
$$;

revoke all on function public.my_profile_completion() from public, anon;
grant execute on function public.my_profile_completion() to authenticated;
