-- Migration 50 (review 106 T2): an entry folded in its page.
--
-- - notes.collapsed: the entry shows only its head and "3 lines hidden" in
--   its page. False (every entry until it is folded, and what an older
--   build reads past) shows it in full. The same on every phone.
-- - set_notes_collapsed(p_ids, p_on): the caller's own entries folded or
--   opened; one for the fold control, a page's for Collapse all · Expand
--   all. Owner only, as every write to notes (they go through functions;
--   the table's own policy lets the owner read only). Nothing else of an
--   entry changes, and its version doesn't move (an edit open elsewhere
--   still saves).

alter table public.notes
  add column collapsed boolean not null default false;

create or replace function public.set_notes_collapsed(p_ids uuid[], p_on boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.notebook_writer();
begin
  if p_on is null or coalesce(cardinality(p_ids), 0) = 0 then
    raise exception 'one or more entries' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_ids) i(id)
             where not exists (select 1 from public.notes n
                               where n.id = i.id and n.owner_id = v_me
                                 and n.deleted_at is null)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.notes n set collapsed = p_on
  where n.id = any (p_ids) and n.owner_id = v_me
    and n.collapsed is distinct from p_on;
end;
$$;

revoke all on function public.set_notes_collapsed(uuid[], boolean) from public, anon;
grant execute on function public.set_notes_collapsed(uuid[], boolean) to authenticated;
