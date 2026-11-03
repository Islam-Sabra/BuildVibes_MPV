-- libfix (Z14, privacy; the lead, 3 Nov): a post opens its files for
-- everyone who sees it (can_open_library_file), so a Library file may go on
-- a post only where its folder already reaches that audience:
-- - a file at the Library's top level, or in a whole-Space folder: any post;
-- - a Team folder's file: only a post for that Team;
-- - an only-me or a person's folder's file: never.
-- Checked where every way in lands: a file post (space_posts.library_file_id),
-- a post's files (post_files) and a work item's attachments.

-- [p_file] may go on a post for [p_team] (null: the whole Space).
create or replace function public.library_file_fits_post(p_file uuid, p_team uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case
             when d.id is null then true
             when d.share = 'space' then true
             -- A whole-Space post (null) or a Team gone (null): no.
             when d.share = 'team' then coalesce(d.share_team = p_team, false)
             else false
           end
    from public.library_files f
    left join public.library_folders d on d.id = f.folder_id
    where f.id = p_file), true);
$$;
revoke all on function public.library_file_fits_post(uuid, uuid) from public, anon, authenticated;

create or replace function public.refuse_private_file_on_post()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_file uuid;
  v_team uuid;
begin
  if tg_table_name = 'space_posts' then
    v_file := new.library_file_id;
    v_team := new.team_id;
  elsif tg_table_name = 'post_files' then
    v_file := new.library_file_id;
    v_team := (select p.team_id from public.space_posts p where p.id = new.post_id);
  else
    v_file := new.library_file_id;
    v_team := (select p.team_id from public.space_posts p where p.id = new.work_item_id);
  end if;
  if v_file is not null and not public.library_file_fits_post(v_file, v_team) then
    raise exception 'a file from a private Library folder can''t go on this post'
      using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function public.refuse_private_file_on_post() from public, anon, authenticated;

create trigger space_posts_private_file
  before insert or update of library_file_id, team_id on public.space_posts
  for each row execute function public.refuse_private_file_on_post();
create trigger post_files_private_file
  before insert or update of library_file_id on public.post_files
  for each row execute function public.refuse_private_file_on_post();
create trigger work_item_attachments_private_file
  before insert or update of library_file_id on public.work_item_attachments
  for each row execute function public.refuse_private_file_on_post();

-- A post whose Team changes takes its files along: none may be a file its
-- new audience couldn't open (post_files and attachments, as above).
create or replace function public.refuse_team_change_with_private_files()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.team_id is distinct from old.team_id
     and (exists (select 1 from public.post_files f
                  where f.post_id = new.id and f.library_file_id is not null
                    and not public.library_file_fits_post(f.library_file_id, new.team_id))
          or exists (select 1 from public.work_item_attachments a
                     where a.work_item_id = new.id
                       and not public.library_file_fits_post(a.library_file_id, new.team_id))) then
    raise exception 'a file from a private Library folder can''t go on this post'
      using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function public.refuse_team_change_with_private_files() from public, anon, authenticated;

create trigger space_posts_team_private_files
  before update of team_id on public.space_posts
  for each row execute function public.refuse_team_change_with_private_files();
