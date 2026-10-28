-- Migration 49 (review 102 N3): entries arranged by hand within their day.
--
-- - notes.day_position: an entry's place in its day, 1 at the top as the
--   page shows it newest first. Null (every entry until its day is
--   arranged, and what an older build reads past) keeps the time order.
-- - arrange_day(p_ids): the caller's entries of one page and one day, top
--   to bottom in their new order, each once; they take the places 1, 2, ….
--   Owner only. Not across pages, nor across days (the dates stay true):
--   to change day or page, Move to…. Nothing else of an entry changes, and
--   its version doesn't move (an edit open elsewhere still saves).

alter table public.notes
  add column day_position integer check (day_position is null or day_position > 0);

create or replace function public.arrange_day(p_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.notebook_writer();
  v_count integer := coalesce(cardinality(p_ids), 0);
begin
  if v_count < 2 or (select count(distinct i) from unnest(p_ids) i) <> v_count then
    raise exception 'two or more entries, each once' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_ids) i(id)
             where not exists (select 1 from public.notes n
                               where n.id = i.id and n.owner_id = v_me
                                 and n.deleted_at is null)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if (select count(distinct n.page_id) from public.notes n where n.id = any (p_ids)) <> 1 then
    raise exception 'entries of one page' using errcode = '22023';
  end if;
  -- One day as a phone shows it: within a day of each other.
  if (select max(n.created_at) - min(n.created_at)
      from public.notes n where n.id = any (p_ids)) >= interval '1 day' then
    raise exception 'entries of one day' using errcode = '22023';
  end if;
  update public.notes n set day_position = i.place
  from unnest(p_ids) with ordinality i(id, place)
  where n.id = i.id and n.day_position is distinct from i.place::integer;
end;
$$;

revoke all on function public.arrange_day(uuid[]) from public, anon;
grant execute on function public.arrange_day(uuid[]) to authenticated;
