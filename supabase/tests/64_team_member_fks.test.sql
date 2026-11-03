-- Review 111, bug on build 987: teams and team_members are joined by two
-- foreign keys, so any PostgREST embed between them must name one. The app
-- reads a Team's members with team_members!team_members_team_id_fkey
-- (space_repository.dart, teamsSelect). A new key here means checking
-- every embed between the two tables again.
begin;
create extension if not exists pgtap with schema extensions;
select plan(1);

select is(
  (select array_agg(c.conname::text || ' ' || c.conrelid::regclass::text || '->'
                    || c.confrelid::regclass::text order by c.conname)
   from pg_constraint c
   where c.contype = 'f'
     and ((c.conrelid = 'public.teams'::regclass and c.confrelid = 'public.team_members'::regclass)
       or (c.conrelid = 'public.team_members'::regclass and c.confrelid = 'public.teams'::regclass))),
  array['team_members_team_id_fkey team_members->teams',
        'teams_admin_in_team_fkey teams->team_members'],
  'teams and team_members: exactly these two foreign keys (embeds must name team_members_team_id_fkey)');

select * from finish();
rollback;
