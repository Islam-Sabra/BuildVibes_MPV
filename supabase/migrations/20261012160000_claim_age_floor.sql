-- Migration 11: review 13 part A follow-up.
-- The cleanup never claims a file younger than one day, whatever age the
-- job asks for: an upload still going on a weak site signal is left alone.

create or replace function public.claim_orphan_files(
  p_age interval default interval '7 days',
  p_limit integer default 200
)
returns table (name text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  for v_name in
    select o.name from public.orphan_space_files(greatest(p_age, interval '1 day')) o
    order by o.created_at
    limit greatest(p_limit, 0)
  loop
    perform public.lock_file_path(v_name);
    if not public.is_referenced_file(v_name) then
      insert into public.file_cleanup_claims (storage_path)
      values (v_name)
      on conflict (storage_path) do nothing;
      name := v_name;
      return next;
    end if;
  end loop;
end;
$$;
