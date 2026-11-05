-- Migration 69 (review 121): key people ("Who to call") and the phone number.
--
-- 1. Key roles per Space: up to 6, each with up to 2 people (current
--    members) and a short note. Set by the Space admin only, through
--    save_key_role, delete_key_role and reorder_key_roles. Every member,
--    Viewers too, reads them through space_key_people; nobody outside does.
-- 2. A holder who leaves (or is removed) is taken off the role. When that
--    empties it, each Space admin gets one Activity line (key_role_empty).
-- 3. KP2: space_members.key_people_seen_at. Who made the Space, and everyone
--    already in a Space now, has seen it.
-- 4. profiles.phone (E.164, optional) and phone_visibility (one choice,
--    Nobody by default). No client selects phone: profiles has column grants
--    from here on, so a new profiles column needs its own grant. The number
--    is read only through person_phone, one person at a time, 30 a day.
-- 5. markets.key_role_suggestions: the role names the market pack offers.

-- ---------------------------------------------------------------------------
-- The market pack's role names (rule 5)
-- ---------------------------------------------------------------------------

alter table public.markets
  add column key_role_suggestions jsonb not null default '[]'::jsonb
  check (jsonb_typeof(key_role_suggestions) = 'array');

-- «ضابط السلامة», never «مسؤول السلامة»: «مسؤول» is the Lead pass word.
update public.markets set key_role_suggestions = '[
  {"en": "Safety officer", "ar": "ضابط السلامة"},
  {"en": "Project engineer", "ar": "مهندس المشروع"},
  {"en": "Site manager", "ar": "مدير الموقع"},
  {"en": "Site nurse", "ar": "ممرض الموقع"},
  {"en": "Storekeeper", "ar": "أمين المخزن"}
]'::jsonb
where id in ('kw', 'eg');

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.space_key_roles (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 40),
  call_for text check (length(call_for) <= 120),
  position smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index space_key_roles_space_idx on public.space_key_roles (space_id, position);

create trigger space_key_roles_updated_at before update on public.space_key_roles
  for each row execute function public.set_updated_at();

create table public.space_key_holders (
  role_id uuid not null references public.space_key_roles (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  note text check (length(note) <= 24),
  position smallint not null default 0,
  primary key (role_id, profile_id)
);
create index space_key_holders_profile_idx on public.space_key_holders (profile_id);

-- Who asked for a number, for the daily limit. Nothing else is kept.
create table public.phone_reads (
  caller_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);
create index phone_reads_caller_idx on public.phone_reads (caller_id, created_at);

-- No policies and no grants: only the functions below read or write them.
alter table public.space_key_roles enable row level security;
alter table public.space_key_holders enable row level security;
alter table public.phone_reads enable row level security;
revoke all on public.space_key_roles, public.space_key_holders, public.phone_reads
  from public, anon, authenticated;

alter table public.space_members add column key_people_seen_at timestamptz;
update public.space_members set key_people_seen_at = now() where left_at is null;

-- Whoever makes the Space is its first admin: they set the key people, so
-- Who to call isn't news to them.
create function public.key_people_seen_by_maker()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.is_admin then
    new.key_people_seen_at := coalesce(new.key_people_seen_at, now());
  end if;
  return new;
end;
$$;
create trigger space_members_key_people_seen
  before insert on public.space_members
  for each row execute function public.key_people_seen_by_maker();

-- ---------------------------------------------------------------------------
-- The phone number
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column phone text check (phone ~ '^\+[1-9][0-9]{6,14}$'),
  add column phone_visibility text not null default 'nobody'
    check (phone_visibility in ('nobody', 'spaces', 'spaces_and_dms'));

-- Column grants: every column but phone. Nothing about profiles' update
-- grant changes: phone and phone_visibility go through set_my_phone.
revoke select on public.profiles from authenticated;
do $$
declare
  v_columns text;
begin
  select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position)
  into v_columns
  from information_schema.columns c
  where c.table_schema = 'public' and c.table_name = 'profiles' and c.column_name <> 'phone';
  execute format('grant select (%s) on public.profiles to authenticated', v_columns);
end;
$$;

-- May [p_viewer] have [p_owner]'s number, asked from [p_space] (null: from a
-- direct message)? Internal: it answers about any two people.
create function public.phone_shown_to(p_owner uuid, p_viewer uuid, p_space uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((
    select p.phone_visibility <> 'nobody'
      and p_owner is distinct from p_viewer
      and not public.is_hidden_account(p_owner)
      and not public.is_hidden_account(p_viewer)
      and not public.blocked_between(p_owner, p_viewer)
      and (
        (p_space is not null
         and public.is_active_member(p_space, p_owner)
         and public.is_active_member(p_space, p_viewer))
        -- A direct message counts only once the owner has it open.
        or (p.phone_visibility = 'spaces_and_dms'
            and exists (select 1 from public.dm_threads t
                        join public.dm_members o on o.thread_id = t.id
                          and o.profile_id = p_owner and o.state = 'open'
                        where t.a_id = least(p_owner, p_viewer)
                          and t.b_id = greatest(p_owner, p_viewer))))
    from public.profiles p
    where p.id = p_owner), false);
$$;

-- NUM1: my number and who sees it.
create function public.my_phone()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('phone', p.phone, 'visibility', p.phone_visibility)
  from public.profiles p
  where p.id = auth.uid();
$$;

-- [p_phone] in E.164 from a market the pack knows, a mobile number there, or
-- null to take it away. A null [p_visibility] keeps the choice as it is.
create function public.set_my_phone(p_phone text, p_visibility text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_phone text := nullif(trim(p_phone), '');
  v_national text;
  v_rules jsonb;
begin
  if v_me is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_visibility is not null and p_visibility not in ('nobody', 'spaces', 'spaces_and_dms') then
    raise exception 'unknown choice' using errcode = '22023';
  end if;
  if v_phone is not null then
    if v_phone !~ '^\+[1-9][0-9]{6,14}$' then
      raise exception 'not an E.164 number' using errcode = '22023';
    end if;
    select substr(v_phone, length(m.dial_code) + 1), m.phone_rules
    into v_national, v_rules
    from public.markets m
    where m.status in ('live', 'soon') and v_phone like m.dial_code || '%'
    order by length(m.dial_code) desc
    limit 1;
    if v_national is null
       or (v_rules ? 'national_length' and length(v_national) <> (v_rules ->> 'national_length')::int)
       or (jsonb_array_length(coalesce(v_rules -> 'mobile_prefixes', '[]')) > 0
           and not exists (select 1 from jsonb_array_elements_text(v_rules -> 'mobile_prefixes') x(prefix)
                           where v_national like x.prefix || '%')) then
      raise exception 'not a mobile number of a known market' using errcode = '22023';
    end if;
  end if;
  update public.profiles
  set phone = v_phone, phone_visibility = coalesce(p_visibility, phone_visibility)
  where id = v_me;
end;
$$;

-- The number, when its owner's choice lets the caller have it; otherwise
-- null. Asked one person at a time, when Call is tapped: 30 a day.
create function public.person_phone(p_profile uuid, p_space uuid default null)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtext('phone_reads'), hashtext(v_me::text));
  -- Only the last day counts: older reads go.
  delete from public.phone_reads r
  where r.caller_id = v_me and r.created_at <= now() - interval '1 day';
  if (select count(*) from public.phone_reads r
      where r.caller_id = v_me and r.created_at > now() - interval '1 day') >= 30 then
    raise exception 'too many numbers today' using errcode = '54000';
  end if;
  insert into public.phone_reads (caller_id) values (v_me);
  if not public.phone_shown_to(p_profile, v_me, p_space) then
    return null;
  end if;
  return (select p.phone from public.profiles p where p.id = p_profile);
end;
$$;

-- ---------------------------------------------------------------------------
-- Key people
-- ---------------------------------------------------------------------------

-- KP1 / OC1 / KP2: the roles in order, each with its people (as the app's
-- person embed) and whether Call shows for them, never the number; and
-- whether the caller has seen Who to call.
create function public.space_key_people(p_space uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
begin
  if not public.is_member(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'seen', (select m.key_people_seen_at is not null from public.space_members m
             where m.space_id = p_space and m.profile_id = v_me),
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', r.id, 'name', r.name, 'call_for', r.call_for,
               'holders', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'id', p.id, 'first_name', p.first_name, 'last_name', p.last_name,
                          'headline', p.headline, 'trade_id', p.trade_id,
                          'company_name_text', p.company_name_text,
                          'trade', (select jsonb_build_object('name', t.name)
                                    from public.trades t where t.id = p.trade_id),
                          'company', (select jsonb_build_object('name', c.name)
                                      from public.companies c where c.id = p.company_id),
                          'note', h.note,
                          'can_call', p.phone is not null
                                      and public.phone_shown_to(p.id, v_me, p_space))
                        order by h.position, h.profile_id)
                 from public.space_key_holders h
                 join public.profiles p on p.id = h.profile_id
                 where h.role_id = r.id
                   and not public.is_hidden_account(p.id)
                   and not public.blocked_between(p.id, v_me)), '[]'))
             order by r.position, r.created_at, r.id)
      from public.space_key_roles r
      where r.space_id = p_space), '[]'));
end;
$$;

-- KP4: a new role ([p_id] null) or a change to one. [p_holders] is
-- [{"profile_id": …, "note": …}] in order, at most 2, current members only.
create function public.save_key_role(p_space uuid, p_id uuid, p_name text, p_call_for text,
                                     p_holders jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid := p_id;
  v_name text := trim(coalesce(p_name, ''));
  v_call_for text := nullif(trim(coalesce(p_call_for, '')), '');
  v_holders jsonb := coalesce(p_holders, '[]'::jsonb);
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  -- One change at a time per Space, so two admins can't both add the sixth.
  perform 1 from public.spaces where id = p_space for update;
  if length(v_name) not between 1 and 40 or length(coalesce(v_call_for, '')) > 120 then
    raise exception 'a name of 1 to 40 characters, and a Call for line of 120 at most'
      using errcode = '22023';
  end if;
  if jsonb_typeof(v_holders) <> 'array' then
    raise exception 'holders is a list' using errcode = '22023';
  end if;
  if jsonb_array_length(v_holders) > 2 then
    raise exception 'up to 2 people a role' using errcode = '54000';
  end if;
  if exists (select 1 from jsonb_array_elements(v_holders) h
             where length(h ->> 'note') > 24
                or (h ->> 'profile_id') is null
                or not public.is_active_member(p_space, (h ->> 'profile_id')::uuid)
                or public.is_hidden_account((h ->> 'profile_id')::uuid))
     or (select count(distinct h ->> 'profile_id') from jsonb_array_elements(v_holders) h)
        <> jsonb_array_length(v_holders) then
    raise exception 'each holder is a current member, once, with a note of 24 at most'
      using errcode = '22023';
  end if;

  if v_id is null then
    if (select count(*) from public.space_key_roles where space_id = p_space) >= 6 then
      raise exception 'up to 6 key roles' using errcode = '54000';
    end if;
    insert into public.space_key_roles (space_id, name, call_for, position)
    values (p_space, v_name, v_call_for,
            coalesce((select max(position) + 1 from public.space_key_roles where space_id = p_space), 0))
    returning id into v_id;
  else
    update public.space_key_roles set name = v_name, call_for = v_call_for
    where id = v_id and space_id = p_space;
    if not found then
      raise exception 'no such role here' using errcode = '22023';
    end if;
    delete from public.space_key_holders where role_id = v_id;
  end if;

  insert into public.space_key_holders (role_id, profile_id, note, position)
  select v_id, (h ->> 'profile_id')::uuid, nullif(trim(coalesce(h ->> 'note', '')), ''), o - 1
  from jsonb_array_elements(v_holders) with ordinality x(h, o);
  return v_id;
end;
$$;

create function public.delete_key_role(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_space uuid;
begin
  select r.space_id into v_space from public.space_key_roles r where r.id = p_id;
  if v_space is null or not public.is_space_admin(v_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from public.space_key_roles where id = p_id;
end;
$$;

-- KP3: the order as the admin sets it: every role of the Space, once.
create function public.reorder_key_roles(p_space uuid, p_ids uuid[])
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform 1 from public.spaces where id = p_space for update;
  if (select coalesce(array_agg(id order by id), '{}') from public.space_key_roles
      where space_id = p_space)
     is distinct from
     (select coalesce(array_agg(x order by x), '{}') from unnest(coalesce(p_ids, '{}')) x) then
    raise exception 'every role of the Space, once' using errcode = '22023';
  end if;
  update public.space_key_roles r set position = o - 1
  from unnest(p_ids) with ordinality x(id, o)
  where r.id = x.id and r.position is distinct from (o - 1)::smallint;
end;
$$;

-- KP2: Got it, or the sheet closed.
create function public.mark_key_people_seen(p_space uuid)
returns void language sql security definer set search_path = '' as $$
  update public.space_members set key_people_seen_at = now()
  where space_id = p_space and profile_id = auth.uid() and left_at is null
    and key_people_seen_at is null;
$$;

-- ---------------------------------------------------------------------------
-- A holder leaves
-- ---------------------------------------------------------------------------

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check (kind in (
  'item_assigned', 'item_done', 'item_checked', 'item_sent_back', 'item_comment',
  'item_edited', 'item_cancelled',
  'announcement_new', 'checklist_for_you', 'activity_invited', 'file_new_version',
  'join_request', 'join_confirmed', 'role_confirmed', 'follow',
  'post_reply', 'post_useful', 'content_removed', 'appeal_decided',
  'poll_new', 'poll_closed', 'poll_tied', 'key_role_empty'));

-- Whatever way out of the Space (leave, removal, a deleted account), the
-- person is off its roles; a role left with no one tells each Space admin,
-- in Activity only ("Safety officer has no one now").
create function public.key_holder_left()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_role record;
  v_admin uuid;
begin
  for v_role in
    delete from public.space_key_holders h
    using public.space_key_roles r
    where r.id = h.role_id and r.space_id = old.space_id and h.profile_id = old.profile_id
    returning r.id, r.name
  loop
    continue when exists (select 1 from public.space_key_holders h where h.role_id = v_role.id);
    for v_admin in
      select m.profile_id from public.space_members m
      where m.space_id = old.space_id and m.is_admin and m.left_at is null
        and m.profile_id <> old.profile_id
    loop
      perform public.add_notification(v_admin, 'key_role_empty', null, old.space_id,
                                      p_payload => jsonb_build_object('role', v_role.name));
    end loop;
  end loop;
  return null;
end;
$$;
create trigger space_members_key_holder_left
  after update of left_at on public.space_members
  for each row when (old.left_at is null and new.left_at is not null)
  execute function public.key_holder_left();
create trigger space_members_key_holder_deleted
  after delete on public.space_members
  for each row when (old.left_at is null)
  execute function public.key_holder_left();

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function
  public.key_people_seen_by_maker(),
  public.phone_shown_to(uuid, uuid, uuid),
  public.my_phone(),
  public.set_my_phone(text, text),
  public.person_phone(uuid, uuid),
  public.space_key_people(uuid),
  public.save_key_role(uuid, uuid, text, text, jsonb),
  public.delete_key_role(uuid),
  public.reorder_key_roles(uuid, uuid[]),
  public.mark_key_people_seen(uuid),
  public.key_holder_left()
from public, anon, authenticated;

grant execute on function
  public.my_phone(),
  public.set_my_phone(text, text),
  public.person_phone(uuid, uuid),
  public.space_key_people(uuid),
  public.save_key_role(uuid, uuid, text, text, jsonb),
  public.delete_key_role(uuid),
  public.reorder_key_roles(uuid, uuid[]),
  public.mark_key_people_seen(uuid)
to authenticated;
