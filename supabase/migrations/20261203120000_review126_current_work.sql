-- Review 126 P1: your current company comes from Experience only (one source).
--
-- Before, "where I work now" lived in two places: profiles.company_id /
-- company_name_text (the basics) and the Experience entry with no end month.
-- The Space rows and Teams from companies read only the basics, so someone
-- who filled in only Experience had no company there. Now:
--   * current_work(profile) is the current Experience entry: no end month,
--     the latest start if several. It shows only to whoever may read that
--     entry (experience_read), never across a block or a demo split: never
--     more than the profile already allowed. The function serves SQL; the
--     view of the same name serves the app (embedded from profiles, under
--     the reader's own row-level security).
--   * Space rows (through the app), Teams from companies, key-role rows,
--     direct messages, the feed, search and Near you read it.
--   * The basics and onboarding company field writes the current entry
--     (set_current_company).
--   * Every profile with a basics company and no current entry gets one
--     (title = headline, else the role; from the profile's creation month);
--     then the basics columns go, with their grants, checks and trigger.
-- Rule 4 stays: a typed name stays plain text; only a picked registered
-- company is linked. Nothing here creates a company.

-- current_work ----------------------------------------------------------------------------------------

create function public.current_work(p_profile uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
           'id', e.id, 'title', e.title,
           'company_id', e.company_id, 'company_name_text', e.company_name_text,
           'company_name', coalesce(c.name, nullif(trim(e.company_name_text), '')))
  from public.experience e
  left join public.companies c on c.id = e.company_id
  where e.profile_id = p_profile
    and e.end_month is null
    -- experience_read, plus the profile's own demo split.
    and (e.profile_id = auth.uid()
         or (not public.is_blocked_with(e.profile_id)
             and not public.demo_apart(e.profile_id)
             and (e.visibility = 'everyone'
                  or (e.visibility = 'connections' and public.is_connected_with(e.profile_id)))))
  order by e.start_month desc, e.created_at desc, e.id
  limit 1;
$$;

revoke all on function public.current_work(uuid) from public, anon;
grant execute on function public.current_work(uuid) to authenticated, service_role;

-- The same, one row per person, for the app: experience_read and
-- companies_read apply as the reader; the demo split as on profiles.
create view public.current_work with (security_invoker = true) as
select distinct on (e.profile_id)
       e.profile_id, e.id, e.title, e.company_id, e.company_name_text,
       coalesce(c.name, nullif(trim(e.company_name_text), '')) as company_name
from public.experience e
left join public.companies c on c.id = e.company_id
where e.end_month is null
  and (e.profile_id = auth.uid() or not public.demo_apart(e.profile_id))
order by e.profile_id, e.start_month desc, e.created_at desc, e.id;

revoke all on public.current_work from public, anon;
grant select on public.current_work to authenticated, service_role;

-- The basics' company, written to the current entry. With a current entry,
-- its company changes (its title stays). With none, a company makes one,
-- titled with the headline, else the role (trade) in the profile's language,
-- from [p_start]'s month; with no title at all nothing is made (null).
create function public.current_work_from_basics(
  p_profile uuid, p_company_id uuid, p_company_name_text text, p_start date)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_text text := case when p_company_id is null then nullif(trim(p_company_name_text), '') end;
  v_title text;
begin
  select e.id into v_id
  from public.experience e
  where e.profile_id = p_profile and e.end_month is null
  order by e.start_month desc, e.created_at desc, e.id
  limit 1;
  if v_id is not null then
    update public.experience
    set company_id = p_company_id, company_name_text = v_text
    where id = v_id;
    return v_id;
  end if;
  if p_company_id is null and v_text is null then
    return null;
  end if;
  select left(coalesce(nullif(trim(p.headline), ''), t.name ->> p.locale, t.name ->> 'en'), 120)
  into v_title
  from public.profiles p
  left join public.trades t on t.id = p.trade_id
  where p.id = p_profile;
  if v_title is null then
    return null;
  end if;
  insert into public.experience (profile_id, title, company_id, company_name_text, start_month)
  values (p_profile, v_title, p_company_id, v_text, date_trunc('month', p_start)::date)
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.current_work_from_basics(uuid, uuid, text, date)
  from public, anon, authenticated;

-- The basics and onboarding company field: always the caller's own entry.
create function public.set_current_company(p_company_id uuid, p_company_name_text text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return public.current_work_from_basics(auth.uid(), p_company_id, p_company_name_text, current_date);
end;
$$;

revoke all on function public.set_current_company(uuid, text) from public, anon;
grant execute on function public.set_current_company(uuid, text) to authenticated;

-- Search and Near you: the people whose current company's name contains
-- [p_query], or who are at the registered company [p_company]; not the
-- caller. Row-level security on profiles applies (blocks, demo split).
create function public.people_at_current_company(p_query text, p_company uuid)
returns setof uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select p.id
  from public.profiles p
  cross join lateral (select public.current_work(p.id) as work) w
  where p.id is distinct from auth.uid()
    and w.work is not null
    and (nullif(trim(p_query), '') is not null or p_company is not null)
    and (p_company is null or (w.work ->> 'company_id')::uuid = p_company)
    and (nullif(trim(p_query), '') is null
         or strpos(lower(w.work ->> 'company_name'), lower(trim(p_query))) > 0)
  order by p.id
  limit 30;
$$;

revoke all on function public.people_at_current_company(text, uuid) from public, anon;
grant execute on function public.people_at_current_company(text, uuid) to authenticated;

-- Readers ---------------------------------------------------------------------------------------------

-- A person's current company, for a Team match (TM4).
create or replace function public.person_company(p_profile uuid)
 returns text
 language sql
 stable security definer
 set search_path to ''
as $function$
  select public.current_work(p_profile) ->> 'company_name';
$function$;

CREATE OR REPLACE FUNCTION public.company_team_preview(p_space uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
           w.work ->> 'company_name' as company,
           public.company_key(w.work ->> 'company_name') as key,
           (w.work ->> 'company_id') is not null as registered
    from public.space_members m
    join public.profiles p on p.id = m.profile_id
    cross join lateral (select public.current_work(p.id) as work) w
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
           -- A Lead, else Crew, first to join; never a Viewer (V3).
           (array_agg(s.id order by (s.pass = 'lead') desc, s.joined, s.id)
              filter (where s.pass <> 'viewer'))[1] as suggested
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
        'people', g.people, 'admin_id', g.admin_id,
        -- V6: the name of whoever Create will set, even if already in the Team.
        'admin_name', public.space_person_name(g.admin_id)) order by g.name, g.key)
      from shown g), '[]'),
    'similar', coalesce((select jsonb_agg(jsonb_build_object('a', a.key, 'b', b.key)
                                          order by a.key, b.key)
      from shown a join shown b on a.key < b.key
      where public.company_keys_similar(a.key, b.key)), '[]'),
    -- V4: a group that looks like an existing Team it isn't already: merge offered.
    'similar_teams', coalesce((select jsonb_agg(jsonb_build_object(
        'key', g.key, 'team_id', t.id, 'team_name', t.name) order by g.key, t.name, t.id)
      from shown g
      join public.teams t on t.space_id = p_space and t.id is distinct from g.team_id
      where public.company_key(t.name) is not null
        and public.company_keys_similar(g.key, public.company_key(t.name))), '[]'),
    'no_company', coalesce((select jsonb_agg(jsonb_build_object('id', pe.id, 'name', pe.name, 'pass', pe.pass)
                                             order by pe.joined, pe.id)
      from people pe where pe.key is null), '[]'))
  into v_result;
  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.space_key_people(p_space uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
                          'trade', (select jsonb_build_object('name', t.name)
                                    from public.trades t where t.id = p.trade_id),
                          'current_work', public.current_work(p.id),
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
$function$;

CREATE OR REPLACE FUNCTION public.dm_person(p_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case
    when p.id is null or p.deletion_scheduled_at is not null or public.dm_blocked(auth.uid(), p.id)
      then jsonb_build_object('id', p_id, 'former', true)
    else jsonb_strip_nulls(jsonb_build_object(
      'id', p.id,
      'name', nullif(trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), ''),
      'photo_path', p.photo_path,
      'headline', coalesce(public.current_work(p.id) ->> 'title', p.headline),
      'company', public.current_work(p.id) ->> 'company_name'))
  end
  from (select 1) one
  left join public.profiles p on p.id = p_id;
$function$;

-- The feed: the author's current title and company.
create or replace view public.post_cards with (security_invoker = true) as
SELECT p.id,
    p.author_id,
    a.first_name AS author_first_name,
    a.last_name AS author_last_name,
    COALESCE(aw.work ->> 'title'::text, a.headline) AS author_headline,
    aw.work ->> 'company_name'::text AS author_company,
    a.photo_path AS author_photo,
    p.body,
    p.lang,
    sp.id AS project_id,
    sp.name AS project_name,
    sp.type_id AS project_type_id,
    sp.place_id AS project_place_id,
    sp.location_text AS project_location,
    p.market_id,
    p.created_at,
    p.edited_at,
    COALESCE(( SELECT jsonb_agg(jsonb_build_object('path', m.storage_path, 'width', m.width, 'height', m.height) ORDER BY m.sort) AS jsonb_agg
           FROM post_media m
          WHERE m.post_id = p.id), '[]'::jsonb) AS media,
    (EXISTS ( SELECT 1
           FROM useful_marks u
          WHERE u.target_kind = 'post'::text AND u.target_id = p.id AND u.profile_id = auth.uid())) AS my_useful,
    ( SELECT jsonb_strip_nulls(jsonb_build_object('id', r.id, 'body', "left"(r.body, 80), 'author_id', r.author_id, 'author_name', NULLIF(TRIM(BOTH FROM (COALESCE(ra.first_name, ''::text) || ' '::text) || COALESCE(ra.last_name, ''::text)), ''::text), 'author_photo', ra.photo_path, 'created_at', r.created_at, 'to_me', r.author_id IS DISTINCT FROM auth.uid() AND (NOT r.reply_to_person IS DISTINCT FROM auth.uid() OR r.reply_to IS NULL AND p.author_id = auth.uid()))) AS jsonb_strip_nulls
           FROM post_replies r
             JOIN profiles ra ON ra.id = r.author_id
          WHERE r.post_id = p.id
          ORDER BY r.created_at DESC, r.id DESC
         LIMIT 1) AS latest_reply,
    COALESCE(( SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object('id', f.author_id, 'name', NULLIF(TRIM(BOTH FROM (COALESCE(fa.first_name, ''::text) || ' '::text) || COALESCE(fa.last_name, ''::text)), ''::text), 'photo', fa.photo_path)) ORDER BY f.last_at DESC, f.author_id) AS jsonb_agg
           FROM ( SELECT r.author_id,
                    max(r.created_at) AS last_at
                   FROM post_replies r
                     JOIN profiles ra ON ra.id = r.author_id
                  WHERE r.post_id = p.id
                  GROUP BY r.author_id
                  ORDER BY (max(r.created_at)) DESC, r.author_id
                 LIMIT 3) f
             JOIN profiles fa ON fa.id = f.author_id), '[]'::jsonb) AS reply_faces
   FROM posts p
     JOIN profiles a ON a.id = p.author_id
     CROSS JOIN LATERAL ( SELECT public.current_work(a.id) AS work) aw
     LEFT JOIN projects sp ON sp.id = shown_project(p.project_id);

-- Back-fill, then drop the basics company ------------------------------------------------------------

do $$
declare
  v_row record;
  v_skipped integer := 0;
begin
  for v_row in
    select p.id, p.company_id, p.company_name_text, p.created_at
    from public.profiles p
    where (p.company_id is not null or nullif(trim(p.company_name_text), '') is not null)
      and not exists (select 1 from public.experience e
                      where e.profile_id = p.id and e.end_month is null)
  loop
    if public.current_work_from_basics(v_row.id, v_row.company_id, v_row.company_name_text,
                                       v_row.created_at::date) is null then
      v_skipped := v_skipped + 1;
    end if;
  end loop;
  raise notice 'review 126 P1: % profile(s) with a basics company but no headline or role, not back-filled',
    v_skipped;
end;
$$;

drop trigger profiles_demo_link on public.profiles;
-- Their foreign key, checks, index and column grants go with them.
alter table public.profiles
  drop column company_id,
  drop column company_name_text;
