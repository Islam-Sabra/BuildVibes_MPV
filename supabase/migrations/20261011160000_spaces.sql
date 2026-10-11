-- Migration 6: Spaces (week 4). DRAFT by the lead, branch spaces-db.
-- Spec: docs/product/data-model.md §5, docs/product/space-project-model.md,
-- docs/reviews/2026-10-11-06-spaces.md. Design: Figma S1 v2, S5 v2, S10k*,
-- S11k, S12, S15 v2k, S15k-*, S16, S17k*.
--
-- MVP scope: private work Spaces only (community Spaces are after the
-- pilot). People join with an invite code; a Space admin confirms every
-- join and gives a pass (Lead / Crew / Viewer). Teams inside a Space.
--
-- Every change goes through a function below. The app can read the tables
-- (row-level security) but never writes to them directly.
--
-- "Owners" in the design are the Space admins: there can be several, and
-- "Transfer ownership" makes someone else an admin and steps you down.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 80),
  about text check (length(about) <= 300),
  -- 'community' arrives after the pilot; create_space() only makes 'work'.
  kind text not null default 'work' check (kind in ('work', 'community')),
  access text not null default 'private' check (access in ('private', 'invite_only', 'open')),
  project_id uuid references public.projects (id) on delete set null,
  who_can_invite text not null default 'admins'
    check (who_can_invite in ('admins', 'admins_leads', 'everyone')),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index spaces_project_idx on public.spaces (project_id) where deleted_at is null;

create trigger spaces_updated_at before update on public.spaces
  for each row execute function public.set_updated_at();

create table public.space_members (
  space_id uuid not null references public.spaces (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  pass text not null check (pass in ('lead', 'crew', 'viewer')),
  is_admin boolean not null default false,
  -- Rights the admin changed from the pass preset (S17k-b "Custom"). Only
  -- the keys create_items, check_items, add_files, invite; booleans.
  custom jsonb not null default '{}'::jsonb,
  -- Per-Space notifications (S15k-N).
  notify text not null default 'all' check (notify in ('all', 'needs_you', 'off')),
  confirmed_by uuid references public.profiles (id) on delete set null,
  confirmed_at timestamptz not null default now(),
  left_at timestamptz,
  removed_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (space_id, profile_id)
);
create index space_members_profile_idx on public.space_members (profile_id)
  where left_at is null;

create trigger space_members_updated_at before update on public.space_members
  for each row execute function public.set_updated_at();

create table public.space_invites (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  -- 6 characters from an alphabet without look-alikes (no 0/O, 1/I/L).
  code text not null check (code ~ '^[A-HJKMNP-Z2-9]{6}$'),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  revoked_at timestamptz
);
create unique index space_invites_code_live_idx on public.space_invites (code)
  where revoked_at is null;
create index space_invites_space_idx on public.space_invites (space_id);

create table public.space_join_requests (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  via text not null check (via in ('code', 'link')),
  invite_id uuid references public.space_invites (id) on delete set null,
  -- Whoever shared the code ("invite link shared by Omar Haddad").
  invited_by uuid references public.profiles (id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'declined', 'cancelled')),
  decided_by uuid references public.profiles (id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index space_join_requests_one_pending_idx
  on public.space_join_requests (space_id, profile_id) where status = 'pending';
create index space_join_requests_profile_idx on public.space_join_requests (profile_id);

-- Wrong codes, for the rate limit in request_join(). Not readable by anyone.
create table public.space_code_attempts (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);
create index space_code_attempts_idx on public.space_code_attempts (profile_id, created_at);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 40),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index teams_name_idx on public.teams (space_id, lower(trim(name)));

create trigger teams_updated_at before update on public.teams
  for each row execute function public.set_updated_at();

create table public.team_members (
  team_id uuid not null references public.teams (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  added_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (team_id, profile_id)
);
create index team_members_profile_idx on public.team_members (profile_id);

-- Confirmations on CV projects can now point at the Space they came from.
alter table public.cv_project_confirmations
  add constraint cv_project_confirmations_space_fk
  foreign key (space_id) references public.spaces (id) on delete set null;

-- ---------------------------------------------------------------------------
-- Passes and rights
-- ---------------------------------------------------------------------------

-- The rights a pass opens, with the admin's changes applied.
-- mark_done (own items) and chat are fixed by the pass and never custom.
create or replace function public.pass_rights(p_pass text, p_custom jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select (case p_pass
    when 'lead' then '{"create_items": true, "check_items": true, "add_files": true, "invite": true, "mark_done": true}'
    when 'crew' then '{"create_items": false, "check_items": false, "add_files": true, "invite": false, "mark_done": true}'
    else '{"create_items": false, "check_items": false, "add_files": false, "invite": false, "mark_done": false}'
  end)::jsonb || (coalesce(p_custom, '{}'::jsonb) - 'mark_done');
$$;

-- True when [p_custom] only holds the four custom rights, as booleans.
create or replace function public.is_valid_custom_rights(p_custom jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(p_custom) = 'object'
    and not exists (
      select 1 from jsonb_each(p_custom) e
      where e.key not in ('create_items', 'check_items', 'add_files', 'invite')
         or jsonb_typeof(e.value) <> 'boolean'
    );
$$;

alter table public.space_members
  add constraint space_members_custom_valid check (public.is_valid_custom_rights(custom));

-- What [p_profile] may do in [p_space]: 'create_items', 'check_items',
-- 'add_files', 'invite', 'mark_done' or 'chat'. Internal: the app calls can().
create or replace function public.member_can(p_space uuid, p_profile uuid, p_right text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case
      when p_right = 'chat' then true
      when p_right = 'invite' then
        m.is_admin
        or s.who_can_invite = 'everyone'
        or (s.who_can_invite = 'admins_leads'
            and coalesce((public.pass_rights(m.pass, m.custom) ->> 'invite')::boolean, false))
      when m.is_admin and p_right <> 'mark_done' then true
      else coalesce((public.pass_rights(m.pass, m.custom) ->> p_right)::boolean, false)
    end
    from public.space_members m
    join public.spaces s on s.id = m.space_id
    where m.space_id = p_space
      and m.profile_id = p_profile
      and m.left_at is null
      and s.deleted_at is null
  ), false);
$$;

-- ---------------------------------------------------------------------------
-- Helpers for policies (about the caller only)
-- ---------------------------------------------------------------------------

create or replace function public.is_member(p_space uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.space_members m
    join public.spaces s on s.id = m.space_id
    where m.space_id = p_space and m.profile_id = auth.uid()
      and m.left_at is null and s.deleted_at is null
  );
$$;

create or replace function public.is_space_admin(p_space uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.space_members m
    join public.spaces s on s.id = m.space_id
    where m.space_id = p_space and m.profile_id = auth.uid()
      and m.is_admin and m.left_at is null and s.deleted_at is null
  );
$$;

create or replace function public.member_pass(p_space uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.pass from public.space_members m
  join public.spaces s on s.id = m.space_id
  where m.space_id = p_space and m.profile_id = auth.uid()
    and m.left_at is null and s.deleted_at is null;
$$;

create or replace function public.can(p_space uuid, p_right text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.member_can(p_space, auth.uid(), p_right);
$$;

-- The rights of a member, for the pass screen (S17k). Members only.
create or replace function public.member_rights(p_space uuid, p_profile uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when public.is_member(p_space) then jsonb_build_object(
    'create_items', public.member_can(p_space, p_profile, 'create_items'),
    'check_items', public.member_can(p_space, p_profile, 'check_items'),
    'add_files', public.member_can(p_space, p_profile, 'add_files'),
    'invite', public.member_can(p_space, p_profile, 'invite'),
    'mark_done', public.member_can(p_space, p_profile, 'mark_done'),
    'is_custom', (select m.custom <> '{}'::jsonb from public.space_members m
                  where m.space_id = p_space and m.profile_id = p_profile)
  ) end;
$$;

-- ---------------------------------------------------------------------------
-- Invite codes
-- ---------------------------------------------------------------------------

-- Upper case, no spaces or dashes; Arabic and Persian digits become 0-9.
create or replace function public.normalize_invite_code(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(regexp_replace(
    translate(coalesce(p_code, ''), '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789'),
    '[^A-Za-z0-9]', '', 'g'));
$$;

-- The live invite for a code, or nothing.
create or replace function public.live_invite(p_code text)
returns public.space_invites
language sql
stable
security definer
set search_path = ''
as $$
  select i.* from public.space_invites i
  join public.spaces s on s.id = i.space_id
  where i.code = public.normalize_invite_code(p_code)
    and i.revoked_at is null
    and i.expires_at > now()
    and s.deleted_at is null
  limit 1;
$$;

-- Replaces the placeholder from migration 3: a code is valid while it is live.
create or replace function public.is_valid_invite_code(p_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (public.live_invite(p_code)).id is not null;
$$;

create or replace function public.new_invite(p_space uuid, p_by uuid)
returns public.space_invites
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
  v_bytes bytea;
  v_row public.space_invites;
begin
  loop
    -- gen_random_uuid() uses the server's strong random source; its first
    -- 6 bytes are fully random. Bytes of 248 and above are skipped so every
    -- letter is equally likely (248 = 8 x 31).
    v_code := '';
    while length(v_code) < 6 loop
      v_bytes := uuid_send(gen_random_uuid());
      for i in 0..5 loop
        if get_byte(v_bytes, i) < 248 and length(v_code) < 6 then
          v_code := v_code || substr(v_alphabet, 1 + get_byte(v_bytes, i) % 31, 1);
        end if;
      end loop;
    end loop;
    -- An expired code can be reused: retire it first.
    update public.space_invites set revoked_at = now()
    where code = v_code and revoked_at is null and expires_at <= now();
    exit when not exists (
      select 1 from public.space_invites where code = v_code and revoked_at is null
    );
  end loop;
  insert into public.space_invites (space_id, code, created_by)
  values (p_space, v_code, p_by)
  returning * into v_row;
  return v_row;
end;
$$;

-- The Space's live invite code (S16), made when there is none.
-- Anyone allowed to invite can read it.
create or replace function public.current_invite(p_space uuid)
returns table (code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.space_invites;
begin
  if not public.can(p_space, 'invite') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_row from public.space_invites i
  where i.space_id = p_space and i.revoked_at is null and i.expires_at > now()
  order by i.created_at desc limit 1;
  if v_row.id is null then
    v_row := public.new_invite(p_space, auth.uid());
  end if;
  return query select v_row.code, v_row.expires_at;
end;
$$;

-- A new code; the old one stops working at once. Admins only.
create or replace function public.renew_invite(p_space uuid)
returns table (code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.space_invites;
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.space_invites i set revoked_at = now()
  where i.space_id = p_space and i.revoked_at is null;
  v_row := public.new_invite(p_space, auth.uid());
  return query select v_row.code, v_row.expires_at;
end;
$$;

-- True when the caller typed ten wrong codes in the last hour.
create or replace function public.too_many_code_tries()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select count(*) from public.space_code_attempts a
          where a.profile_id = auth.uid()
            and a.created_at > now() - interval '1 hour') >= 10;
$$;

-- What a code opens, after sign-in (code sheet, E1b): the Space name and
-- who shared it. Nothing for a wrong or expired code. Signed-in only, and
-- wrong codes count towards the same limit as request_join(), so codes
-- can't be guessed.
create or replace function public.invite_preview(p_code text)
returns table (space_name text, invited_by_name text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite public.space_invites;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if public.too_many_code_tries() then
    return;
  end if;
  v_invite := public.live_invite(p_code);
  if v_invite.id is null then
    insert into public.space_code_attempts (profile_id) values (auth.uid());
    return;
  end if;
  return query
  select s.name,
         nullif(trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), ''),
         v_invite.expires_at
  from public.spaces s
  left join public.profiles p on p.id = v_invite.created_by
  where s.id = v_invite.space_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Proof: Space confirmations on CV projects
-- ---------------------------------------------------------------------------

-- When a Space is linked to a project, the admin's confirmation of a member
-- confirms that member's CV entry for the project ("Confirmed").
-- It counts only when the person who confirmed is not the member and was
-- not confirmed by that member in turn (two accounts confirming each other
-- prove nothing).
create or replace function public.is_space_proof(p_space uuid, p_member uuid, p_confirmer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_confirmer is not null
    and p_confirmer <> p_member
    and not exists (select 1 from public.space_members c
                    where c.space_id = p_space and c.profile_id = p_confirmer
                      and c.confirmed_by = p_member);
$$;

create or replace function public.add_space_confirmations(p_space uuid, p_profile uuid default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.cv_project_confirmations (cv_project_id, confirmed_by, source, space_id)
  select c.id, m.confirmed_by, 'space_member', s.id
  from public.spaces s
  join public.space_members m on m.space_id = s.id
  join public.cv_projects c on c.profile_id = m.profile_id and c.project_id = s.project_id
  where s.id = p_space
    and s.deleted_at is null
    and s.project_id is not null
    and m.left_at is null
    and public.is_space_proof(s.id, m.profile_id, m.confirmed_by)
    and (p_profile is null or m.profile_id = p_profile)
  on conflict do nothing;
$$;

-- A project added to a CV later is confirmed by the Space it belongs to.
create or replace function public.handle_cv_project_space_confirm()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.cv_project_confirmations (cv_project_id, confirmed_by, source, space_id)
  select new.id, m.confirmed_by, 'space_member', s.id
  from public.spaces s
  join public.space_members m on m.space_id = s.id
  where s.project_id = new.project_id
    and s.deleted_at is null
    and m.profile_id = new.profile_id
    and m.left_at is null
    and public.is_space_proof(s.id, m.profile_id, m.confirmed_by)
  on conflict do nothing;
  return new;
end;
$$;

create trigger cv_projects_space_confirm
  after insert or update of project_id on public.cv_projects
  for each row execute function public.handle_cv_project_space_confirm();

-- ---------------------------------------------------------------------------
-- Creating and managing a Space
-- ---------------------------------------------------------------------------

-- S5 v2: a private work Space. You become its admin, with a Lead pass.
create or replace function public.create_space(
  p_name text,
  p_about text default null,
  p_project_id uuid default null
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
  if (select count(*) from public.spaces s
      where s.created_by = v_me and s.created_at > now() - interval '1 day') >= 10 then
    raise exception 'too many Spaces today' using errcode = 'P0001';
  end if;
  insert into public.spaces (name, about, kind, access, project_id, created_by)
  values (trim(p_name), nullif(trim(p_about), ''), 'work', 'private', p_project_id, v_me)
  returning id into v_id;
  insert into public.space_members (space_id, profile_id, pass, is_admin, confirmed_by)
  values (v_id, v_me, 'lead', true, v_me);
  return v_id;
end;
$$;

-- S15 v2k: name, about and who can invite. Admins only.
create or replace function public.update_space(
  p_space uuid,
  p_name text,
  p_about text,
  p_who_can_invite text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.spaces
  set name = trim(p_name),
      about = nullif(trim(p_about), ''),
      who_can_invite = p_who_can_invite
  where id = p_space;
end;
$$;

-- Link, change or remove the project. Confirmations from the old link go.
create or replace function public.set_space_project(p_space uuid, p_project_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_project uuid;
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select s.project_id into v_old_project from public.spaces s where s.id = p_space for update;
  if v_old_project is not distinct from p_project_id then
    return;
  end if;
  delete from public.cv_project_confirmations where space_id = p_space;
  update public.spaces set project_id = p_project_id where id = p_space;
  perform public.add_space_confirmations(p_space);
  -- Another Space linked to the old project may still confirm the same
  -- people: give that proof back.
  perform public.add_space_confirmations(o.id)
  from public.spaces o
  where o.id <> p_space and o.deleted_at is null
    and o.project_id = v_old_project;
end;
$$;

-- "Delete Space" (owners only). Kept for the record; gone for everyone.
create or replace function public.delete_space(p_space uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.space_invites set revoked_at = now()
  where space_id = p_space and revoked_at is null;
  update public.space_join_requests
  set status = 'cancelled', decided_at = now()
  where space_id = p_space and status = 'pending';
  update public.spaces set deleted_at = now() where id = p_space;
end;
$$;

-- S15k-N: your notifications for this Space.
create or replace function public.set_space_notifications(p_space uuid, p_level text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_member(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.space_members set notify = p_level
  where space_id = p_space and profile_id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- Joining
-- ---------------------------------------------------------------------------

-- Ask to join with a code. Returns
--   {"status": "requested" | "pending" | "member" | "declined" | "not_valid" | "too_many_tries",
--    "space_id", "space_name", "request_id"}
-- A wrong code says nothing about any Space (S19). Ten wrong codes an hour
-- and the person must wait; after a decline, a day.
create or replace function public.request_join(p_code text, p_via text default 'code')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_invite public.space_invites;
  v_name text;
  v_request uuid;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if public.too_many_code_tries() then
    return jsonb_build_object('status', 'too_many_tries');
  end if;

  v_invite := public.live_invite(p_code);
  if v_invite.id is null then
    insert into public.space_code_attempts (profile_id) values (v_me);
    return jsonb_build_object('status', 'not_valid');
  end if;

  select s.name into v_name from public.spaces s where s.id = v_invite.space_id;

  if exists (select 1 from public.space_members m
             where m.space_id = v_invite.space_id and m.profile_id = v_me
               and m.left_at is null) then
    return jsonb_build_object('status', 'member', 'space_id', v_invite.space_id,
                              'space_name', v_name);
  end if;

  select r.id into v_request from public.space_join_requests r
  where r.space_id = v_invite.space_id and r.profile_id = v_me and r.status = 'pending';
  if v_request is not null then
    return jsonb_build_object('status', 'pending', 'space_id', v_invite.space_id,
                              'space_name', v_name, 'request_id', v_request);
  end if;

  -- After a decline, wait a day before asking the same Space again.
  if exists (select 1 from public.space_join_requests r
             where r.space_id = v_invite.space_id and r.profile_id = v_me
               and r.status = 'declined' and r.decided_at > now() - interval '1 day') then
    return jsonb_build_object('status', 'declined', 'space_id', v_invite.space_id,
                              'space_name', v_name);
  end if;

  insert into public.space_join_requests (space_id, profile_id, via, invite_id, invited_by)
  values (v_invite.space_id, v_me,
          case when p_via = 'link' then 'link' else 'code' end,
          v_invite.id, v_invite.created_by)
  returning id into v_request;

  return jsonb_build_object('status', 'requested', 'space_id', v_invite.space_id,
                            'space_name', v_name, 'request_id', v_request);
end;
$$;

-- Your own requests, with the Space name (you can't read the Space yet).
-- Who decided is never shown.
create or replace function public.my_join_requests()
returns table (
  request_id uuid,
  space_id uuid,
  space_name text,
  status text,
  created_at timestamptz,
  decided_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.space_id, s.name, r.status, r.created_at, r.decided_at
  from public.space_join_requests r
  join public.spaces s on s.id = r.space_id
  where r.profile_id = auth.uid()
    and s.deleted_at is null
    and (r.status = 'pending'
         or (r.status = 'declined' and r.decided_at > now() - interval '30 days'))
  order by r.created_at desc;
$$;

create or replace function public.cancel_join_request(p_request uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.space_join_requests
  set status = 'cancelled', decided_at = now()
  where id = p_request and profile_id = auth.uid() and status = 'pending';
  if not found then
    raise exception 'not allowed' using errcode = '42501';
  end if;
end;
$$;

-- S10k-C: confirm with a pass and, optionally, Teams. Admins only.
create or replace function public.confirm_join(
  p_request uuid,
  p_pass text,
  p_team_ids uuid[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_req public.space_join_requests;
begin
  select * into v_req from public.space_join_requests where id = p_request for update;
  if v_req.id is null or not public.is_space_admin(v_req.space_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'this request was already answered' using errcode = 'P0001';
  end if;
  if p_pass is null or p_pass not in ('lead', 'crew', 'viewer') then
    raise exception 'choose a pass' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(coalesce(p_team_ids, '{}')) t(id)
             where not exists (select 1 from public.teams tm
                               where tm.id = t.id and tm.space_id = v_req.space_id)) then
    raise exception 'team not in this Space' using errcode = '22023';
  end if;

  update public.space_join_requests
  set status = 'confirmed', decided_by = v_me, decided_at = now()
  where id = p_request;

  insert into public.space_members (space_id, profile_id, pass, is_admin, custom,
                                    confirmed_by, confirmed_at)
  values (v_req.space_id, v_req.profile_id, p_pass, false, '{}', v_me, now())
  on conflict (space_id, profile_id) do update
  set pass = excluded.pass, is_admin = false, custom = '{}', notify = 'all',
      confirmed_by = excluded.confirmed_by, confirmed_at = excluded.confirmed_at,
      left_at = null, removed_by = null;

  insert into public.team_members (team_id, profile_id, added_by)
  select t.id, v_req.profile_id, v_me from unnest(coalesce(p_team_ids, '{}')) t(id)
  on conflict do nothing;

  perform public.add_space_confirmations(v_req.space_id, v_req.profile_id);
end;
$$;

-- S10k-D: decline. The person isn't told why.
create or replace function public.decline_join(p_request uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_req public.space_join_requests;
begin
  select * into v_req from public.space_join_requests where id = p_request for update;
  if v_req.id is null or not public.is_space_admin(v_req.space_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'this request was already answered' using errcode = 'P0001';
  end if;
  update public.space_join_requests
  set status = 'declined', decided_by = auth.uid(), decided_at = now()
  where id = p_request;
end;
$$;

-- "Undo" on the declined toast: the request is waiting again.
create or replace function public.undo_decline(p_request uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_req public.space_join_requests;
begin
  select * into v_req from public.space_join_requests where id = p_request for update;
  if v_req.id is null or not public.is_space_admin(v_req.space_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_req.status <> 'declined' or exists (
       select 1 from public.space_join_requests r
       where r.space_id = v_req.space_id and r.profile_id = v_req.profile_id
         and r.status = 'pending') then
    raise exception 'nothing to undo' using errcode = 'P0001';
  end if;
  update public.space_join_requests
  set status = 'pending', decided_by = null, decided_at = null
  where id = p_request;
end;
$$;

-- ---------------------------------------------------------------------------
-- Members, passes and admins
-- ---------------------------------------------------------------------------

create or replace function public.require_active_member(p_space uuid, p_profile uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.space_members m
                 where m.space_id = p_space and m.profile_id = p_profile
                   and m.left_at is null) then
    raise exception 'not a member of this Space' using errcode = '22023';
  end if;
end;
$$;

-- S17k: change the pass and, optionally, single rights ("Custom").
-- Only differences from the pass preset are kept.
create or replace function public.set_member_pass(
  p_space uuid,
  p_profile uuid,
  p_pass text,
  p_custom jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_preset jsonb := public.pass_rights(p_pass, '{}');
  v_custom jsonb := '{}'::jsonb;
  v_key text;
  v_value jsonb;
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_pass is null or p_pass not in ('lead', 'crew', 'viewer') then
    raise exception 'choose a pass' using errcode = '22023';
  end if;
  if not public.is_valid_custom_rights(coalesce(p_custom, '{}'::jsonb)) then
    raise exception 'unknown right' using errcode = '22023';
  end if;
  perform public.require_active_member(p_space, p_profile);
  for v_key, v_value in select * from jsonb_each(coalesce(p_custom, '{}'::jsonb)) loop
    if v_preset -> v_key is distinct from v_value then
      v_custom := v_custom || jsonb_build_object(v_key, v_value);
    end if;
  end loop;
  update public.space_members set pass = p_pass, custom = v_custom
  where space_id = p_space and profile_id = p_profile;
end;
$$;

-- True when [p_space] has another active admin than [p_profile].
create or replace function public.has_other_admin(p_space uuid, p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.space_members m
                 where m.space_id = p_space and m.profile_id <> p_profile
                   and m.is_admin and m.left_at is null);
$$;

-- "Make admin" / remove admin. A Space always keeps one admin.
create or replace function public.set_member_admin(p_space uuid, p_profile uuid, p_admin boolean)
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
  perform public.require_active_member(p_space, p_profile);
  if not p_admin and not public.has_other_admin(p_space, p_profile) then
    raise exception 'a Space needs an admin' using errcode = 'P0001';
  end if;
  update public.space_members set is_admin = p_admin
  where space_id = p_space and profile_id = p_profile;
end;
$$;

-- S15d/e: someone else becomes an admin; you stay as a member.
create or replace function public.transfer_ownership(p_space uuid, p_profile uuid)
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
    raise exception 'choose someone else' using errcode = '22023';
  end if;
  perform public.require_active_member(p_space, p_profile);
  update public.space_members set is_admin = true
  where space_id = p_space and profile_id = p_profile;
  update public.space_members set is_admin = false
  where space_id = p_space and profile_id = auth.uid();
end;
$$;

-- "Remove from Space". Their closed work items stay in the record.
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
  update public.space_members
  set left_at = now(), removed_by = auth.uid(), is_admin = false
  where space_id = p_space and profile_id = p_profile;
  delete from public.team_members tm
  using public.teams t
  where t.id = tm.team_id and t.space_id = p_space and tm.profile_id = p_profile;
end;
$$;

-- S15c: leave. The last admin can't leave (make someone admin, or delete
-- the Space).
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
  if public.is_space_admin(p_space) and not public.has_other_admin(p_space, v_me) then
    raise exception 'a Space needs an admin' using errcode = 'P0001';
  end if;
  update public.space_members set left_at = now(), is_admin = false
  where space_id = p_space and profile_id = v_me;
  delete from public.team_members tm
  using public.teams t
  where t.id = tm.team_id and t.space_id = p_space and tm.profile_id = v_me;
end;
$$;

-- ---------------------------------------------------------------------------
-- Teams
-- ---------------------------------------------------------------------------

create or replace function public.check_team_members(p_space uuid, p_members uuid[])
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from unnest(coalesce(p_members, '{}')) x(id)
             where not exists (select 1 from public.space_members m
                               where m.space_id = p_space and m.profile_id = x.id
                                 and m.left_at is null)) then
    raise exception 'not a member of this Space' using errcode = '22023';
  end if;
end;
$$;

-- S12: a new Team with its first members. Admins only.
create or replace function public.create_team(p_space uuid, p_name text, p_members uuid[] default '{}')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform public.check_team_members(p_space, p_members);
  insert into public.teams (space_id, name, created_by)
  values (p_space, trim(p_name), auth.uid())
  returning id into v_id;
  insert into public.team_members (team_id, profile_id, added_by)
  select v_id, x.id, auth.uid() from unnest(coalesce(p_members, '{}')) x(id)
  on conflict do nothing;
  return v_id;
end;
$$;

create or replace function public.rename_team(p_team uuid, p_name text)
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
  update public.teams set name = trim(p_name) where id = p_team;
end;
$$;

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
  delete from public.teams where id = p_team;
end;
$$;

-- S11k "Add people": the Team's members become exactly [p_members].
create or replace function public.set_team_members(p_team uuid, p_members uuid[])
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
  perform public.check_team_members(v_space, p_members);
  delete from public.team_members
  where team_id = p_team and not (profile_id = any (coalesce(p_members, '{}')));
  insert into public.team_members (team_id, profile_id, added_by)
  select p_team, x.id, auth.uid() from unnest(coalesce(p_members, '{}')) x(id)
  on conflict do nothing;
end;
$$;

-- S17k "TEAMS": a member's Teams become exactly [p_team_ids].
create or replace function public.set_member_teams(p_space uuid, p_profile uuid, p_team_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform public.require_active_member(p_space, p_profile);
  if exists (select 1 from unnest(coalesce(p_team_ids, '{}')) t(id)
             where not exists (select 1 from public.teams tm
                               where tm.id = t.id and tm.space_id = p_space)) then
    raise exception 'team not in this Space' using errcode = '22023';
  end if;
  delete from public.team_members tm
  using public.teams t
  where t.id = tm.team_id and t.space_id = p_space and tm.profile_id = p_profile
    and not (tm.team_id = any (coalesce(p_team_ids, '{}')));
  insert into public.team_members (team_id, profile_id, added_by)
  select t.id, p_profile, auth.uid() from unnest(coalesce(p_team_ids, '{}')) t(id)
  on conflict do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Lists for the app
-- ---------------------------------------------------------------------------

-- S1 v2 "My Spaces": your Spaces, with the linked project and, for admins,
-- how many people are waiting to be confirmed (part of "Needs you").
create or replace function public.my_spaces()
returns table (
  space_id uuid,
  name text,
  kind text,
  access text,
  project_id uuid,
  project_name text,
  project_type_id text,
  pass text,
  is_admin boolean,
  pending_requests integer,
  joined_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.name, s.kind, s.access, s.project_id, p.name, p.type_id,
         m.pass, m.is_admin,
         case when m.is_admin then (
           select count(*)::int from public.space_join_requests r
           where r.space_id = s.id and r.status = 'pending') else 0 end,
         m.confirmed_at
  from public.space_members m
  join public.spaces s on s.id = m.space_id
  left join public.projects p on p.id = s.project_id
  where m.profile_id = auth.uid() and m.left_at is null and s.deleted_at is null
  order by m.confirmed_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Sign-up with an invite code (E1b)
-- ---------------------------------------------------------------------------

-- A person who signed up with a live code, who is waiting to join a Space,
-- or whom someone else confirmed in a Space, may choose any home country
-- (decision 04). Creating your own Space doesn't count.
create or replace function public.signed_up_with_invite(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.is_valid_invite_code(
           (select u.raw_user_meta_data ->> 'invite_code' from auth.users u where u.id = p_user)),
           false)
      or exists (select 1 from public.space_join_requests r
                 where r.profile_id = p_user and r.status in ('pending', 'confirmed'))
      or exists (select 1 from public.space_members m
                 where m.profile_id = p_user and m.confirmed_by is distinct from p_user);
$$;

-- The app sends the request to join (request_join) once the email code is
-- verified, never at sign-up: an unverified address must not reach an
-- admin's queue. handle_new_user() stays as in migration 5.

-- ---------------------------------------------------------------------------
-- A Space never loses its last admin
-- ---------------------------------------------------------------------------

-- When an admin's account is deleted, the longest-serving Lead (or, if
-- none, the longest-serving member) becomes admin. A Space left with no
-- members is deleted.
create or replace function public.handle_space_admin_gone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_next uuid;
begin
  if not old.is_admin or old.left_at is not null then
    return old;
  end if;
  perform 1 from public.spaces where id = old.space_id for update;
  if exists (select 1 from public.space_members m
             where m.space_id = old.space_id and m.is_admin and m.left_at is null) then
    return old;
  end if;
  select m.profile_id into v_next from public.space_members m
  where m.space_id = old.space_id and m.left_at is null
  order by (m.pass = 'lead') desc, m.confirmed_at
  limit 1;
  if v_next is null then
    update public.spaces set deleted_at = now()
    where id = old.space_id and deleted_at is null;
  else
    update public.space_members set is_admin = true
    where space_id = old.space_id and profile_id = v_next;
  end if;
  return old;
end;
$$;

create trigger space_members_admin_gone
  after delete on public.space_members
  for each row execute function public.handle_space_admin_gone();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.spaces enable row level security;
alter table public.space_members enable row level security;
alter table public.space_invites enable row level security;
alter table public.space_join_requests enable row level security;
alter table public.space_code_attempts enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;

-- A Space you don't belong to returns nothing, not an error.
create policy spaces_read on public.spaces
  for select to authenticated using (public.is_member(id));

-- Members see each other (including people who left, for the record).
create policy space_members_read on public.space_members
  for select to authenticated using (public.is_member(space_id));

-- Requests to join: the Space's admins. People see their own through
-- my_join_requests(), which hides who decided.
create policy space_join_requests_read on public.space_join_requests
  for select to authenticated using (public.is_space_admin(space_id));

-- Team names and members are visible to the whole Space (S12).
create policy teams_read on public.teams
  for select to authenticated using (public.is_member(space_id));
create policy team_members_read on public.team_members
  for select to authenticated
  using (exists (select 1 from public.teams t
                 where t.id = team_id and public.is_member(t.space_id)));

-- space_invites and space_code_attempts: no policies. Codes are read
-- through current_invite().

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on public.spaces, public.space_members, public.space_invites,
  public.space_join_requests, public.space_code_attempts, public.teams,
  public.team_members
  from anon, authenticated;

grant select on public.spaces, public.space_members, public.space_join_requests,
  public.teams, public.team_members
  to authenticated;

revoke execute on function
  public.pass_rights(text, jsonb),
  public.is_valid_custom_rights(jsonb),
  public.member_can(uuid, uuid, text),
  public.is_member(uuid),
  public.is_space_admin(uuid),
  public.member_pass(uuid),
  public.can(uuid, text),
  public.member_rights(uuid, uuid),
  public.normalize_invite_code(text),
  public.live_invite(text),
  public.is_valid_invite_code(text),
  public.new_invite(uuid, uuid),
  public.current_invite(uuid),
  public.renew_invite(uuid),
  public.invite_preview(text),
  public.add_space_confirmations(uuid, uuid),
  public.handle_cv_project_space_confirm(),
  public.create_space(text, text, uuid),
  public.update_space(uuid, text, text, text),
  public.set_space_project(uuid, uuid),
  public.delete_space(uuid),
  public.set_space_notifications(uuid, text),
  public.request_join(text, text),
  public.my_join_requests(),
  public.cancel_join_request(uuid),
  public.confirm_join(uuid, text, uuid[]),
  public.decline_join(uuid),
  public.undo_decline(uuid),
  public.require_active_member(uuid, uuid),
  public.set_member_pass(uuid, uuid, text, jsonb),
  public.has_other_admin(uuid, uuid),
  public.set_member_admin(uuid, uuid, boolean),
  public.transfer_ownership(uuid, uuid),
  public.remove_member(uuid, uuid),
  public.leave_space(uuid),
  public.check_team_members(uuid, uuid[]),
  public.create_team(uuid, text, uuid[]),
  public.rename_team(uuid, text),
  public.delete_team(uuid),
  public.set_team_members(uuid, uuid[]),
  public.set_member_teams(uuid, uuid, uuid[]),
  public.my_spaces(),
  public.signed_up_with_invite(uuid),
  public.too_many_code_tries(),
  public.is_space_proof(uuid, uuid, uuid),
  public.handle_space_admin_gone()
  from public, anon, authenticated;

-- Policies call these as the signed-in user.
grant execute on function
  public.is_member(uuid),
  public.is_space_admin(uuid),
  public.member_pass(uuid),
  public.can(uuid, text),
  public.member_rights(uuid, uuid),
  public.pass_rights(text, jsonb),
  public.current_invite(uuid),
  public.renew_invite(uuid),
  public.invite_preview(text),
  public.create_space(text, text, uuid),
  public.update_space(uuid, text, text, text),
  public.set_space_project(uuid, uuid),
  public.delete_space(uuid),
  public.set_space_notifications(uuid, text),
  public.request_join(text, text),
  public.my_join_requests(),
  public.cancel_join_request(uuid),
  public.confirm_join(uuid, text, uuid[]),
  public.decline_join(uuid),
  public.undo_decline(uuid),
  public.set_member_pass(uuid, uuid, text, jsonb),
  public.set_member_admin(uuid, uuid, boolean),
  public.transfer_ownership(uuid, uuid),
  public.remove_member(uuid, uuid),
  public.leave_space(uuid),
  public.create_team(uuid, text, uuid[]),
  public.rename_team(uuid, text),
  public.delete_team(uuid),
  public.set_team_members(uuid, uuid[]),
  public.set_member_teams(uuid, uuid, uuid[]),
  public.my_spaces()
  to authenticated;

