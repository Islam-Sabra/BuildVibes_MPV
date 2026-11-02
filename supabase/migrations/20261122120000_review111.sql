-- Migration 61 (review 111): Teams from companies, and Team admins.
--
-- 1. teams.admin_id: one per Team, a member of that Team. It is held by a
--    foreign key to team_members, so every way out of a Team (or the Space,
--    or the account) clears it, whichever function does it.
-- 2. A Team admin adds and removes people in their own Team and posts to any
--    Team of that Space. Nothing else: no passes, no settings, no other
--    Team's people, and only the Space admin changes who the Team admin is.
-- 3. Make Teams from companies, Space admin only: company_team_preview and
--    create_company_teams. A typed company name stays plain text (rule 4);
--    no company is ever created here, and profiles are never written.
-- 4. company_team_for: the Team the confirm sheet already chooses (TM4).
-- 5. The post rule, one function: can_post_to_team. create_work_item had no
--    Team check until now; it has the same one, except for an item that
--    takes its Team from a parent or a Team chat message.

create extension if not exists fuzzystrmatch with schema extensions;

-- ---------------------------------------------------------------------------
-- teams.admin_id
-- ---------------------------------------------------------------------------

alter table public.teams add column admin_id uuid;
alter table public.teams
  -- Named by PostgREST: admin:profiles!teams_admin_id_fkey(...).
  add constraint teams_admin_id_fkey
    foreign key (admin_id) references public.profiles (id) on delete set null,
  add constraint teams_admin_in_team_fkey
    foreign key (id, admin_id) references public.team_members (team_id, profile_id)
    on delete set null (admin_id);
create index teams_admin_idx on public.teams (admin_id) where admin_id is not null;

-- ---------------------------------------------------------------------------
-- A retry of Create: the result of each run. It holds Team ids only, nothing
-- about a person. No policy and no grant: only create_company_teams uses it.
-- ---------------------------------------------------------------------------

create table public.company_team_runs (
  id uuid primary key,
  space_id uuid not null references public.spaces (id) on delete cascade,
  result jsonb not null,
  created_at timestamptz not null default now()
);
create index company_team_runs_space_idx on public.company_team_runs (space_id);
alter table public.company_team_runs enable row level security;
revoke all on public.company_team_runs from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Who
-- ---------------------------------------------------------------------------

create function public.is_any_team_admin(p_space uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_member(p_space)
    and not public.is_hidden_account(auth.uid())
    and exists (select 1 from public.teams t
                where t.space_id = p_space and t.admin_id = auth.uid());
$$;

create function public.is_team_admin(p_team uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.teams t
                 where t.id = p_team and t.admin_id = auth.uid()
                   and public.is_member(t.space_id)
                   and not public.is_hidden_account(auth.uid()));
$$;

-- The post rule: a member of the Team, any Team's admin, or a Space admin.
create function public.can_post_to_team(p_space uuid, p_team uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.teams t
    where t.id = p_team and t.space_id = p_space
      and (public.is_space_admin(p_space)
           or exists (select 1 from public.team_members tm
                      where tm.team_id = t.id and tm.profile_id = auth.uid())
           or public.is_any_team_admin(p_space)));
$$;

-- ---------------------------------------------------------------------------
-- Companies, compared
-- ---------------------------------------------------------------------------

-- A company name with case, dots, commas, spaces and the word for company
-- ignored; null when nothing is left. The word goes from the end, and from
-- the start in Arabic, where it is written first.
create function public.company_key(p_name text)
returns text language sql immutable security definer set search_path = '' as $$
  select nullif(replace(regexp_replace(regexp_replace(regexp_replace(
           trim(regexp_replace(
             regexp_replace(lower(translate(coalesce(p_name, ''), chr(160), ' ')), '[.,،]', '', 'g'),
             '\s+', ' ', 'g')),
           ' (co|company)$', ''), ' شركة$', ''), '^شركة ', ''), ' ', ''), '');
$$;

-- Two keys that may be one company: they differ, and one holds the other or
-- they are a letter or two apart. Short names are too thin to compare.
create function public.company_keys_similar(p_a text, p_b text)
returns boolean language sql immutable security definer set search_path = '' as $$
  select p_a <> p_b
    and least(char_length(p_a), char_length(p_b)) >= 4
    and (position(p_a in p_b) > 0 or position(p_b in p_a) > 0
         or extensions.levenshtein(p_a, p_b)
            <= case when least(char_length(p_a), char_length(p_b)) >= 6 then 2 else 1 end);
$$;

-- A person's company: the registered one, or else the name as they typed it.
create function public.person_company(p_profile uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce(c.name, nullif(trim(p.company_name_text), ''))
  from public.profiles p
  left join public.companies c on c.id = p.company_id
  where p.id = p_profile;
$$;

-- The Team of that company in this Space, if any. A Team takes 40 characters,
-- so a longer company name matches the Team it was cut to.
create function public.team_for_company(p_space uuid, p_key text, p_name text)
returns uuid language sql stable security definer set search_path = '' as $$
  select t.id from public.teams t
  where t.space_id = p_space
    and (public.company_key(t.name) = p_key
         or public.company_key(t.name) = public.company_key(left(trim(p_name), 40))
         or lower(trim(t.name)) = lower(trim(left(trim(p_name), 40))))
  order by t.created_at, t.id
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- The Team admin
-- ---------------------------------------------------------------------------

-- The admin's name beside a Team in the app's own read of teams, as a
-- computed field: select=id,name,admin_id,admin_name. Null across a block.
create function public.admin_name(p_team public.teams)
returns text language sql stable security definer set search_path = '' as $$
  select public.space_person_name(t.admin_id)
  from public.teams t
  where t.id = p_team.id and public.is_member(t.space_id);
$$;

create function public.set_team_admin(p_team uuid, p_profile uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_space uuid;
begin
  select t.space_id into v_space from public.teams t where t.id = p_team for update;
  if v_space is null or not public.is_space_admin(v_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_profile is not null and (
       not exists (select 1 from public.team_members tm
                   where tm.team_id = p_team and tm.profile_id = p_profile)
       or public.is_hidden_account(p_profile)) then
    raise exception 'a Team admin is a member of that Team' using errcode = '22023';
  end if;
  update public.teams set admin_id = p_profile where id = p_team;
end;
$$;

-- As before, and also for that Team's admin. Taking the admin out clears
-- admin_id, which only the Space admin may do; the Team admin is refused.
create or replace function public.set_team_members(p_team uuid, p_members uuid[])
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_space uuid;
  v_space_admin boolean;
begin
  select t.space_id into v_space from public.teams t where t.id = p_team for update;
  v_space_admin := v_space is not null and public.is_space_admin(v_space);
  if v_space is null or not (v_space_admin or public.is_team_admin(p_team)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform public.check_team_members(v_space, p_members);
  if not v_space_admin and not (auth.uid() = any (coalesce(p_members, '{}'))) then
    raise exception 'the Space admin changes the Team admin' using errcode = 'BV002';
  end if;
  delete from public.team_members
  where team_id = p_team and not (profile_id = any (coalesce(p_members, '{}')));
  insert into public.team_members (team_id, profile_id, added_by)
  select p_team, x.id, auth.uid() from unnest(coalesce(p_members, '{}')) x(id)
  on conflict do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Make Teams from companies
-- ---------------------------------------------------------------------------

create function public.company_team_preview(p_space uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_result jsonb;
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with people as (
    select m.profile_id as id,
           trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')) as name,
           m.pass, m.confirmed_at as joined,
           public.person_company(m.profile_id) as company,
           public.company_key(public.person_company(m.profile_id)) as key,
           p.company_id is not null as registered
    from public.space_members m
    join public.profiles p on p.id = m.profile_id
    where m.space_id = p_space and m.left_at is null
      and not public.is_hidden_account(m.profile_id)
      and not public.is_blocked_with(m.profile_id)
  ),
  spelled as (
    select pe.*, count(*) over (partition by pe.key, pe.company) as uses
    from people pe where pe.key is not null
  ),
  firms as (
    select s.key,
           -- The registered name, or the spelling most people typed.
           (array_agg(s.company order by s.registered desc, s.uses desc, s.joined, s.id))[1] as name,
           (array_agg(s.id order by (s.pass = 'lead') desc, s.joined, s.id))[1] as suggested
    from spelled s group by s.key
  ),
  groups as (
    select f.key, f.name, t.id as team_id, t.name as team_name,
           coalesce(t.admin_id, f.suggested) as admin_id,
           (select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'pass', s.pass)
                             order by s.joined, s.id)
            from spelled s
            where s.key = f.key
              and not exists (select 1 from public.team_members tm
                              where tm.team_id = t.id and tm.profile_id = s.id)) as people
    from firms f
    left join public.teams t on t.id = public.team_for_company(p_space, f.key, f.name)
  ),
  shown as (
    select * from groups g where g.people is not null
  )
  select jsonb_build_object(
    'groups', coalesce((select jsonb_agg(jsonb_build_object(
        'key', g.key, 'name', g.name, 'team_id', g.team_id, 'team_name', g.team_name,
        'people', g.people, 'admin_id', g.admin_id) order by g.name, g.key)
      from shown g), '[]'),
    'similar', coalesce((select jsonb_agg(jsonb_build_object('a', a.key, 'b', b.key)
                                          order by a.key, b.key)
      from shown a join shown b on a.key < b.key
      where public.company_keys_similar(a.key, b.key)), '[]'),
    'no_company', coalesce((select jsonb_agg(jsonb_build_object('id', pe.id, 'name', pe.name, 'pass', pe.pass)
                                             order by pe.joined, pe.id)
      from people pe where pe.key is null), '[]'))
  into v_result;
  return v_result;
end;
$$;

-- All or nothing: any refusal raises, so nothing of the run stays. The same
-- p_id again returns the first result and changes nothing.
create function public.create_company_teams(p_id uuid, p_space uuid, p_groups jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_run public.company_team_runs;
  v_group jsonb;
  v_name text;
  v_team uuid;
  v_admin uuid;
  v_people uuid[];
  v_ids uuid[] := '{}';
  v_result jsonb;
begin
  -- One change to a Space's Teams at a time, and one run of an id.
  perform 1 from public.spaces where id = p_space for update;
  if p_id is null or not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_run from public.company_team_runs where id = p_id;
  if v_run.id is not null then
    if v_run.space_id <> p_space then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    return v_run.result;
  end if;

  if p_groups is null or jsonb_typeof(p_groups) <> 'array' or jsonb_array_length(p_groups) = 0 then
    raise exception 'a list of groups' using errcode = '22023';
  end if;

  for v_group in select value from jsonb_array_elements(p_groups) loop
    if jsonb_typeof(v_group) <> 'object'
       or jsonb_typeof(v_group -> 'people') is distinct from 'array' then
      raise exception 'a list of groups' using errcode = '22023';
    end if;
    v_name := trim(coalesce(v_group ->> 'name', ''));
    v_team := nullif(v_group ->> 'team_id', '')::uuid;
    v_admin := nullif(v_group ->> 'admin_id', '')::uuid;
    v_people := array(select x::uuid from jsonb_array_elements_text(v_group -> 'people') x);
    perform public.check_team_members(p_space, v_people);

    if v_team is not null then
      if not exists (select 1 from public.teams t where t.id = v_team and t.space_id = p_space) then
        raise exception 'team not in this Space' using errcode = '22023';
      end if;
    else
      if v_name = '' then
        raise exception 'a Team has a name' using errcode = '22023';
      end if;
      -- Made since the preview, or two groups of one name: its people join it.
      v_team := public.team_for_company(p_space, public.company_key(v_name), v_name);
      if v_team is null then
        if cardinality(v_people) = 0 then
          raise exception 'a new Team needs its people' using errcode = '22023';
        end if;
        insert into public.teams (space_id, name, created_by)
        values (p_space, trim(left(v_name, 40)), v_me)
        returning id into v_team;
      end if;
    end if;

    insert into public.team_members (team_id, profile_id, added_by)
    select v_team, x.id, v_me from unnest(v_people) x(id)
    on conflict do nothing;

    -- Null leaves a Team's admin as it is.
    if v_admin is not null then
      if not exists (select 1 from public.team_members tm
                     where tm.team_id = v_team and tm.profile_id = v_admin)
         or public.is_hidden_account(v_admin) then
        raise exception 'a Team admin is a member of that Team' using errcode = '22023';
      end if;
      update public.teams set admin_id = v_admin where id = v_team;
    end if;

    if not v_team = any (v_ids) then
      v_ids := v_ids || v_team;
    end if;
  end loop;

  v_result := jsonb_build_object('team_ids', to_jsonb(v_ids));
  insert into public.company_team_runs (id, space_id, result) values (p_id, p_space, v_result);
  return v_result;
exception
  when invalid_text_representation then
    raise exception 'a list of groups' using errcode = '22023';
end;
$$;

-- TM4: for the confirm sheet, so the person may not be a member yet.
create function public.company_team_for(p_space uuid, p_profile uuid)
returns table (team_id uuid, team_name text, company text)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_company text;
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  v_company := public.person_company(p_profile);
  if public.company_key(v_company) is null then
    return;
  end if;
  return query
    select t.id, t.name, v_company
    from public.teams t
    where t.id = public.team_for_company(p_space, public.company_key(v_company), v_company);
end;
$$;

-- ---------------------------------------------------------------------------
-- The post rule in the functions that hold it
-- ---------------------------------------------------------------------------

create function pg_temp.r111_patch(p_fn regprocedure, p_old text, p_new text)
returns void language plpgsql as $$
declare
  -- Live has CRLF in some function bodies.
  v_def text := replace(pg_get_functiondef(p_fn), chr(13), '');
begin
  if position(p_old in v_def) = 0 then
    raise exception 'review 111: % is not as expected', p_fn;
  end if;
  execute replace(v_def, p_old, p_new);
end;
$$;

select pg_temp.r111_patch(
  'public.create_space_post(uuid, uuid, text, text, text, uuid, text, date, timestamptz, timestamptz, timestamptz, uuid, uuid[], jsonb, uuid, jsonb, jsonb, uuid, jsonb, timestamptz)',
  $old$  -- A Team post only from inside that Team (or a Space admin).
  if v_team is not null and not public.is_space_admin(p_space) and not exists (
       select 1 from public.team_members tm where tm.team_id = v_team and tm.profile_id = v_me) then$old$,
  $new$  -- A Team post: its members, any Team's admin, a Space admin (review 111).
  if v_team is not null and not public.can_post_to_team(p_space, v_team) then$new$);

select pg_temp.r111_patch(
  'public.create_walk(uuid, uuid, text, jsonb, text, uuid)',
  $old$if p_team is not null and not public.is_space_admin(p_space) and not exists (
       select 1 from public.team_members tm where tm.team_id = p_team and tm.profile_id = v_me) then$old$,
  $new$if p_team is not null and not public.can_post_to_team(p_space, p_team) then$new$);

select pg_temp.r111_patch(
  'public.create_work_item(uuid, text, uuid, date, uuid, text, jsonb, uuid, text, uuid, uuid, jsonb, jsonb, uuid, jsonb, jsonb, timestamptz, text)',
  $old$  -- From a work item template (migration 20): one the caller may read in$old$,
  $new$  -- A Team work item: the post rule, unless its Team came with a parent or
  -- a Team chat message the caller was already checked for above.
  if v_team is not null and v_parent.id is null and v_thread_team is null
     and not public.can_post_to_team(p_space, v_team) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  -- From a work item template (migration 20): one the caller may read in$new$);

-- A file post carries a Library file of that Team, and a model view goes the
-- same way; a Team admin outside the Team may read what they put there.
select pg_temp.r111_patch(
  'public.add_library_file(uuid, uuid, text, text, text, bigint, uuid, text, text, uuid, uuid)',
  $old$if p_team is not null and not exists (
       select 1 from public.teams t where t.id = p_team and t.space_id = p_space
         and (public.is_space_admin(p_space)
              or exists (select 1 from public.team_members m
                         where m.team_id = t.id and m.profile_id = auth.uid()))) then$old$,
  $new$if p_team is not null and not public.can_post_to_team(p_space, p_team) then$new$);

select pg_temp.r111_patch(
  'public.publish_model_view(uuid, uuid, uuid, text, text, text, text, bigint, text, uuid, text, text, text, text, integer, integer, text)',
  $old$if p_team is not null and not exists (
       select 1 from public.teams t where t.id = p_team and t.space_id = p_space
         and (public.is_space_admin(p_space)
              or exists (select 1 from public.team_members m
                         where m.team_id = t.id and m.profile_id = auth.uid()))) then$old$,
  $new$if p_team is not null and not public.can_post_to_team(p_space, p_team) then$new$);

select pg_temp.r111_patch(
  'public.my_publish_targets()',
  $old$where public.is_space_admin(mine.id)
       or exists (select 1 from public.team_members tm
                  where tm.team_id = t.id and tm.profile_id = auth.uid())$old$,
  $new$where public.can_post_to_team(mine.id, t.id)$new$);

select pg_temp.r111_patch(
  'public.can_read_library_file(uuid)',
  $old$            or exists (select 1 from public.team_members m
                       where m.team_id = f.team_id and m.profile_id = auth.uid()))$old$,
  $new$            or exists (select 1 from public.team_members m
                       where m.team_id = f.team_id and m.profile_id = auth.uid())
            or (f.uploaded_by = auth.uid() and public.is_any_team_admin(f.space_id)))$new$);

-- My data: the Teams I am admin of.
select pg_temp.r111_patch(
  'public.export_my_data(uuid)',
  $old$    'exported_at', now(),$old$,
  $new$    'exported_at', now(),
    'team_admin_of', coalesce((select jsonb_agg(jsonb_build_object('team', t.name, 'space', s.name))
                               from public.teams t
                               join public.spaces s on s.id = t.space_id
                               where t.admin_id = r.profile_id), '[]'),$new$);

drop function pg_temp.r111_patch(regprocedure, text, text);

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function public.is_any_team_admin(uuid) from public, anon, authenticated;
revoke all on function public.is_team_admin(uuid) from public, anon, authenticated;
revoke all on function public.can_post_to_team(uuid, uuid) from public, anon, authenticated;
revoke all on function public.company_key(text) from public, anon, authenticated;
revoke all on function public.company_keys_similar(text, text) from public, anon, authenticated;
revoke all on function public.person_company(uuid) from public, anon, authenticated;
revoke all on function public.team_for_company(uuid, text, text) from public, anon, authenticated;
revoke all on function public.admin_name(public.teams) from public, anon;
revoke all on function public.set_team_admin(uuid, uuid) from public, anon;
revoke all on function public.company_team_preview(uuid) from public, anon;
revoke all on function public.create_company_teams(uuid, uuid, jsonb) from public, anon;
revoke all on function public.company_team_for(uuid, uuid) from public, anon;

grant execute on function public.admin_name(public.teams) to authenticated;
grant execute on function public.set_team_admin(uuid, uuid) to authenticated;
grant execute on function public.company_team_preview(uuid) to authenticated;
grant execute on function public.create_company_teams(uuid, uuid, jsonb) to authenticated;
grant execute on function public.company_team_for(uuid, uuid) to authenticated;
