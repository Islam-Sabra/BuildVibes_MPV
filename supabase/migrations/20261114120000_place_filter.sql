-- Migration 53 (review 105C part A): Search finds a Space's places.
--
-- search_space (as in 20261107120000_post_numbers) also returns the
-- Space's places whose name matches (kind 'place': the place's id, its
-- name as the title), for its members only, as the rest. Work then shows
-- that place's posts: the app filters the cards it reads by
-- space_posts.place_id (migration 52), so no other function changes.
-- Same signature, same grants.
--
-- The lead's check M2: deleting a place in use first copies its name into
-- place_text of every post that has it (a trigger), so a Checked item's
-- proof keeps its location once place_id is set null.

create or replace function public.search_space(p_space uuid, p_q text)
returns table (kind text, id uuid, post_id uuid, thread_id uuid, team_id uuid, post_kind text,
               post_status text, ref text, title text, snippet text, author_name text,
               created_at timestamptz, mine boolean, exact boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := public.search_fold(regexp_replace(trim(coalesce(p_q, '')), '\s+', ' ', 'g'));
  v_raw text := upper(translate(trim(coalesce(p_q, '')),
                                '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
                                '01234567890123456789'));
  v_parts text[];
  v_number integer;
  v_pat text;
  v_threads uuid[];
begin
  if char_length(v_q) > 100 then
    raise exception 'search too long' using errcode = '22023';
  end if;
  if not public.is_member(p_space) then
    return;
  end if;
  -- "NST-023", "NST023", "nst 23", "023", "23": this Space's prefix, or
  -- none, then the number.
  v_parts := regexp_match(v_raw, '^([A-Z]{2,4})?[ -]?0*([0-9]{1,9})$');
  if v_parts is not null and v_parts[2] <> ''
     and (v_parts[1] is null
          or v_parts[1] = (select s.ref_prefix from public.spaces s where s.id = p_space)) then
    v_number := v_parts[2]::integer;
  end if;
  if char_length(v_q) < 2 and v_number is null then
    return;
  end if;
  v_pat := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_threads := array(select t.id from public.threads t
                     where t.space_id = p_space and public.can_use_thread(t.id));

  return query
  with hits as (
    (select 'post'::text as kind, p.id, p.id as post_id, null::uuid as thread_id, p.team_id,
            p.kind as post_kind, p.status as post_status, p.ref, p.title,
            null::text as snippet, p.author_id, p.created_at, true as exact
     from public.space_posts p
     where p.space_id = p_space and p.number = v_number and p.deleted_at is null
       and (p.team_id is null or public.can_see_space_post(p.id)))
    union all
    (select 'post'::text, p.id, p.id, null::uuid, p.team_id,
            p.kind, p.status, p.ref, p.title,
            case when public.search_fold(p.title) like v_pat then null
                 else public.search_snippet(
                   coalesce(p.body, '') || ' ' || public.blocks_plain_text(p.blocks), v_q)
            end,
            p.author_id, p.created_at, false
     from public.space_posts p
     where p.space_id = p_space and p.deleted_at is null
       and p.number is distinct from v_number
       and p.search_text like v_pat
       and (p.team_id is null or public.can_see_space_post(p.id))
     order by p.created_at desc, p.id desc limit 30)
    union all
    (select 'point', c.id, p.id, null, p.team_id, p.kind, p.status, p.ref, p.title, c.text,
            p.author_id, c.created_at, false
     from public.checklist_points c
     join public.space_posts p on p.id = c.post_id
     where p.space_id = p_space and p.deleted_at is null
       and c.search_text like v_pat
       and (p.team_id is null or public.can_see_space_post(p.id))
     order by c.created_at desc, c.id desc limit 30)
    union all
    (select 'message', m.id, null, m.thread_id, t.team_id, null, null, null, null,
            public.search_snippet(m.body, v_q), m.author_id, m.created_at, false
     from public.messages m
     join public.threads t on t.id = m.thread_id
     where m.space_id = p_space and m.thread_id = any (v_threads)
       and m.deleted_at is null and m.body is not null
       and m.search_text like v_pat
       and not public.reported_by_me('message', m.id)
     order by m.created_at desc, m.id desc limit 30)
    union all
    -- Review 105C: the Space's places, by name; a tap shows their work.
    (select 'place', sp.id, null, null, null, null, null, null, sp.name, null,
            sp.created_by, sp.created_at, false
     from public.space_places sp
     where sp.space_id = p_space
       and public.search_fold(sp.name) like v_pat
     order by sp.name, sp.id limit 10)
    union all
    (select 'file', f.id, null, null, f.team_id, null, null, null, f.name, f.rev_label,
            f.uploaded_by, f.created_at, false
     from public.library_files f
     where f.space_id = p_space and f.deleted_at is null
       and f.search_text like v_pat
       and (f.team_id is null or public.can_read_library_file(f.id))
       and public.library_file_in_force(f.id)
     order by f.created_at desc, f.id desc limit 30)
  )
  select h.kind, h.id, h.post_id, h.thread_id, h.team_id, h.post_kind, h.post_status, h.ref,
         h.title, h.snippet, public.space_person_name(h.author_id), h.created_at,
         coalesce(h.author_id = auth.uid(), false), h.exact
  from hits h
  -- The full rules again on at most 131 rows, so a later change to the
  -- short-cuts above can't leak.
  where (h.post_id is null or public.can_see_space_post(h.post_id))
    and (h.kind <> 'file' or public.can_read_library_file(h.id))
  -- The places first (at most 10), so newer posts never crowd them out.
  order by h.exact desc, (h.kind = 'place') desc, h.created_at desc, h.id desc
  limit 30;
end;
$$;

revoke execute on function public.search_space(uuid, text) from public, anon;
grant execute on function public.search_space(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- A place deleted keeps its name on its posts (M2)
-- ---------------------------------------------------------------------------

-- Before a place goes, its name as it is now becomes place_text of every
-- post that points to it; place_id is then set null by its foreign key.
-- Security definer: a Lead deleting a place can't write others' posts.
create or replace function public.keep_place_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.space_posts
  set place_text = left(trim(old.name), 80)
  where place_id = old.id;
  return old;
end;
$$;

revoke execute on function public.keep_place_name() from public, anon, authenticated;

create trigger space_places_keep_name before delete on public.space_places
  for each row execute function public.keep_place_name();
