-- Migration 4: profiles and project records (task 10).
-- docs/product/data-model.md §2 and §4; design: docs/design/profile/.
--
-- - profile_open_to: what a person is open to, with its own visibility
--   (Everyone / Connections only / Only me).
-- - projects: a shared record with no owner. Created only through
--   create_project() (after "Is it already here?"); there is no update
--   policy: corrections go through project_edit_suggestions.
-- - cv_projects: a project on a person's CV, with their role and dates.
--   Others see it only when show_on_profile is on.
-- - cv_project_confirmations: who confirmed it (written by the Spaces flow,
--   migration 5); "Confirmed" vs "Waiting" on the proof card.
-- - avatars storage bucket: each person writes only in their own folder.
--
-- Projects keep a start and end month (the design shows "Mar 2023"), not
-- only a year as the data model first said.

create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Open to
-- ---------------------------------------------------------------------------

create table public.profile_open_to (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  options text[] not null default '{}'
    check (options <@ array['contract', 'consulting', 'full_time', 'part_time', 'mentoring']),
  note text check (length(note) <= 200),
  visibility text not null default 'everyone'
    check (visibility in ('everyone', 'connections', 'only_me')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profile_open_to_updated_at before update on public.profile_open_to
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Projects
-- ---------------------------------------------------------------------------

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 120),
  type_id text not null references public.project_types (id),
  market_id text not null references public.markets (id),
  place_id text references public.places (id),
  location_text text check (length(location_text) <= 120),
  start_month date check (start_month is null or extract(day from start_month) = 1),
  end_month date check (end_month is null or extract(day from end_month) = 1),
  -- The end month is a forecast ("Expected 2026").
  end_expected boolean not null default false,
  created_by uuid references public.profiles (id) on delete set null,
  status text not null default 'active' check (status in ('active', 'merged')),
  merged_into uuid references public.projects (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_month is null or start_month is null or end_month >= start_month),
  check ((status = 'merged') = (merged_into is not null))
);
create index projects_name_trgm on public.projects
  using gin (name extensions.gin_trgm_ops);
create index projects_place_idx on public.projects (place_id);
create index projects_market_idx on public.projects (market_id);

create trigger projects_updated_at before update on public.projects
  for each row execute function public.set_updated_at();
create trigger projects_place_in_market
  before insert or update of place_id, market_id on public.projects
  for each row execute function public.check_place_in_market();

create table public.project_edit_suggestions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  suggested_by uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  field text not null
    check (field in ('name', 'type', 'location', 'dates', 'duplicate')),
  correct_value text not null check (length(trim(correct_value)) between 1 and 300),
  -- Reviewed in the back office (service role only).
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now()
);
create index project_edit_suggestions_project_idx
  on public.project_edit_suggestions (project_id);

create table public.cv_projects (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  project_id uuid not null references public.projects (id) on delete cascade,
  role_title text not null check (length(trim(role_title)) between 1 and 120),
  start_month date check (start_month is null or extract(day from start_month) = 1),
  -- Null means "present".
  end_month date check (end_month is null or extract(day from end_month) = 1),
  show_on_profile boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, project_id),
  check (end_month is null or start_month is null or end_month >= start_month)
);
create index cv_projects_project_idx on public.cv_projects (project_id);

create trigger cv_projects_updated_at before update on public.cv_projects
  for each row execute function public.set_updated_at();

create table public.cv_project_confirmations (
  cv_project_id uuid not null references public.cv_projects (id) on delete cascade,
  confirmed_by uuid not null references public.profiles (id) on delete cascade,
  source text not null check (source in ('space_member', 'teammate')),
  -- References spaces once migration 5 adds them.
  space_id uuid,
  created_at timestamptz not null default now(),
  primary key (cv_project_id, confirmed_by)
);

-- ---------------------------------------------------------------------------
-- Functions
-- ---------------------------------------------------------------------------

-- Creates a project record. The app offers find_similar_projects first;
-- the server limits how many a person can create in a day.
create or replace function public.create_project(
  p_name text,
  p_type_id text,
  p_market_id text,
  p_place_id text default null,
  p_location_text text default null,
  p_start_month date default null,
  p_end_month date default null,
  p_end_expected boolean default false
)
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
    start_month, end_month, end_expected, created_by
  ) values (
    trim(p_name), p_type_id, p_market_id, p_place_id,
    nullif(trim(p_location_text), ''),
    p_start_month, p_end_month, coalesce(p_end_expected, false), v_me
  )
  returning id into v_id;
  return v_id;
end;
$$;

-- "Is it already here?": active projects with a similar name, or on the
-- same site. Runs as the caller, so it only sees what RLS allows.
create or replace function public.find_similar_projects(
  p_name text,
  p_place_id text default null
)
returns table (
  id uuid,
  name text,
  type_id text,
  market_id text,
  place_id text,
  start_month date,
  end_month date,
  end_expected boolean,
  reason text
)
language sql
stable
set search_path = ''
as $$
  with q as (select trim(coalesce(p_name, '')) as term)
  select p.id, p.name, p.type_id, p.market_id, p.place_id,
         p.start_month, p.end_month, p.end_expected,
         case
           when length(q.term) >= 2 and (
             p.name ilike '%' || q.term || '%'
             or extensions.similarity(p.name, q.term) > 0.3
           ) then 'same_name'
           else 'same_site'
         end as reason
  from public.projects p, q
  where p.status = 'active'
    and (
      (length(q.term) >= 2 and (
        p.name ilike '%' || q.term || '%'
        or extensions.similarity(p.name, q.term) > 0.3
      ))
      or (p_place_id is not null and p.place_id = p_place_id)
    )
  order by
    (length(q.term) >= 2 and p.name ilike '%' || q.term || '%') desc,
    extensions.similarity(p.name, q.term) desc,
    p.name
  limit 10;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.profile_open_to enable row level security;
alter table public.projects enable row level security;
alter table public.project_edit_suggestions enable row level security;
alter table public.cv_projects enable row level security;
alter table public.cv_project_confirmations enable row level security;

create policy profile_open_to_read on public.profile_open_to
  for select to authenticated
  using (
    profile_id = auth.uid()
    or (
      not public.is_blocked_with(profile_id)
      and (
        visibility = 'everyone'
        or (visibility = 'connections' and public.is_connected_with(profile_id))
      )
    )
  );
create policy profile_open_to_insert_own on public.profile_open_to
  for insert to authenticated with check (profile_id = auth.uid());
create policy profile_open_to_update_own on public.profile_open_to
  for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy profile_open_to_delete_own on public.profile_open_to
  for delete to authenticated using (profile_id = auth.uid());

-- Projects: read by anyone signed in. No insert, update or delete policy.
create policy projects_read on public.projects
  for select to authenticated using (true);

-- Suggestions: you send them and see your own.
create policy project_edit_suggestions_insert_own on public.project_edit_suggestions
  for insert to authenticated with check (suggested_by = auth.uid());
create policy project_edit_suggestions_read_own on public.project_edit_suggestions
  for select to authenticated using (suggested_by = auth.uid());

-- CV projects: the owner manages them; others see the ones shown, unless
-- either side has blocked the other.
create policy cv_projects_read on public.cv_projects
  for select to authenticated
  using (
    profile_id = auth.uid()
    or (show_on_profile and not public.is_blocked_with(profile_id))
  );
create policy cv_projects_insert_own on public.cv_projects
  for insert to authenticated with check (profile_id = auth.uid());
create policy cv_projects_update_own on public.cv_projects
  for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy cv_projects_delete_own on public.cv_projects
  for delete to authenticated using (profile_id = auth.uid());

-- Confirmations are visible with the CV project they belong to.
create policy cv_project_confirmations_read on public.cv_project_confirmations
  for select to authenticated
  using (exists (
    select 1 from public.cv_projects c where c.id = cv_project_id
  ));

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on public.profile_open_to, public.projects,
  public.project_edit_suggestions, public.cv_projects,
  public.cv_project_confirmations
  from anon, authenticated;

grant select, delete on public.profile_open_to to authenticated;
grant insert (profile_id, options, note, visibility) on public.profile_open_to
  to authenticated;
grant update (options, note, visibility) on public.profile_open_to
  to authenticated;

grant select on public.projects to authenticated;

grant select on public.project_edit_suggestions to authenticated;
grant insert (project_id, field, correct_value) on public.project_edit_suggestions
  to authenticated;

grant select, delete on public.cv_projects to authenticated;
grant insert (project_id, role_title, start_month, end_month, show_on_profile)
  on public.cv_projects to authenticated;
grant update (role_title, start_month, end_month, show_on_profile)
  on public.cv_projects to authenticated;

grant select on public.cv_project_confirmations to authenticated;

revoke execute on function
  public.create_project(text, text, text, text, text, date, date, boolean),
  public.find_similar_projects(text, text)
  from public, anon;
grant execute on function
  public.create_project(text, text, text, text, text, date, date, boolean),
  public.find_similar_projects(text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Profile photos (storage bucket "avatars")
-- ---------------------------------------------------------------------------
-- Public read (the path holds a random id), write only in your own folder:
-- avatars/<your user id>/<file>.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy avatars_read_own on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
