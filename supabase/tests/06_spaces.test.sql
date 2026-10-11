-- Migration 6: Spaces. Run with: supabase test db
--
-- Omar (o1) creates the Space and is its admin. Ahmed (a3) asks to join
-- and is confirmed as Crew. Nadia (n4) is declined, then confirmed as
-- Viewer. Sara (s2) joins as Lead. Eve (e5) is never a member. Mona (m6)
-- signs up with the invite code.

begin;
create extension if not exists pgtap with schema extensions;
select plan(91);

insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000006a1', 'authenticated', 'authenticated', 'omar@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000006a2', 'authenticated', 'authenticated', 'sara@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000006a3', 'authenticated', 'authenticated', 'ahmed@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000006a4', 'authenticated', 'authenticated', 'nadia@example.com', '{"home_market_id": "kw"}'),
  ('00000000-0000-0000-0000-0000000006a5', 'authenticated', 'authenticated', 'eve@example.com', '{"home_market_id": "kw"}');
update public.profiles set first_name = 'Omar', last_name = 'Haddad'
where id = '00000000-0000-0000-0000-0000000006a1';

-- Signed out ----------------------------------------------------------------------------

set local role anon;
select throws_ok($$select * from public.spaces$$, '42501', null,
  'signed out: Spaces are not readable');
select throws_ok($$select public.create_space('X', null, null)$$, '42501', null,
  'signed out: cannot create a Space');
select throws_ok($$select * from public.invite_preview('ZZZZZZ')$$, '42501', null,
  'signed out: codes cannot be tried');

-- Omar creates the Space -----------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a1", "role": "authenticated"}', true);
set local role authenticated;

select set_config('test.project',
  public.create_project('Kuwait City Tower', 'commercial', 'kw', 'kw-capital')::text, true);
select set_config('test.space',
  public.create_space('  Kuwait City Tower — Site team ', 'Site team',
                      current_setting('test.project')::uuid)::text, true);

select is((select name from public.spaces where id = current_setting('test.space')::uuid),
  'Kuwait City Tower — Site team', 'the creator sees the Space, name trimmed');
select is((select kind || '/' || access from public.spaces
           where id = current_setting('test.space')::uuid),
  'work/private', 'a new Space is private work');
select ok((select is_admin and pass = 'lead' from public.space_members
           where space_id = current_setting('test.space')::uuid
             and profile_id = '00000000-0000-0000-0000-0000000006a1'),
  'the creator is an admin with a Lead pass');
select throws_ok(
  $$insert into public.spaces (name) values ('Typed in')$$,
  '42501', null, 'Spaces are never inserted directly');
select throws_ok(
  $$update public.space_members set is_admin = true$$,
  '42501', null, 'members are never updated directly');

select set_config('test.code',
  (select code from public.current_invite(current_setting('test.space')::uuid)), true);
select matches(current_setting('test.code'), '^[A-HJKMNP-Z2-9]{6}$',
  'the invite code is 6 characters without look-alikes');
select is((select code from public.current_invite(current_setting('test.space')::uuid)),
  current_setting('test.code'), 'asking again gives the same live code');
select ok((select expires_at between now() + interval '6 days 23 hours' and now() + interval '7 days 1 minute'
           from public.current_invite(current_setting('test.space')::uuid)),
  'the code works for 7 days');

select set_config('test.team',
  public.create_team(current_setting('test.space')::uuid, 'Structure team')::text, true);
select throws_ok(
  $$select public.create_team(current_setting('test.space')::uuid, 'structure TEAM ')$$,
  '23505', null, 'two Teams in a Space cannot share a name');
select throws_ok(
  format($$select public.create_team(%L, 'MEP Team', array['00000000-0000-0000-0000-0000000006a5']::uuid[])$$,
         current_setting('test.space')),
  '22023', null, 'only Space members can be put in a Team');

-- Eve, an outsider ------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a5", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*) from public.spaces), 0::bigint,
  'a non-member sees no Space (no error)');
select is((select count(*) from public.space_members), 0::bigint,
  'a non-member sees no members');
select is((select count(*) from public.teams), 0::bigint,
  'a non-member sees no Teams');
select is((select count(*) from public.space_join_requests), 0::bigint,
  'a non-member sees no requests');
select throws_ok($$select * from public.space_invites$$, '42501', null,
  'invite codes are never read directly');
select throws_ok(
  format($$select * from public.current_invite(%L)$$, current_setting('test.space')),
  '42501', null, 'a non-member cannot get the invite code');
select is(public.request_join('WRONG1') ->> 'status', 'not_valid',
  'a wrong code says only that it is not valid');
select is(
  (select space_name from public.invite_preview(
     ' ' || lower(substr(current_setting('test.code'), 1, 3)) || '-' ||
     substr(current_setting('test.code'), 4) || ' ')),
  'Kuwait City Tower — Site team',
  'a code typed in lower case with a dash still works');
select is(
  (select invited_by_name from public.invite_preview(current_setting('test.code'))),
  'Omar Haddad', 'the preview names who shared the code');
select throws_ok(
  format($$select public.update_space(%L, 'Mine now', null, 'everyone')$$,
         current_setting('test.space')),
  '42501', null, 'a non-member cannot change the Space');

-- Ahmed asks to join ----------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a3", "role": "authenticated"}', true);
set local role authenticated;

insert into public.cv_projects (project_id, role_title)
values (current_setting('test.project')::uuid, 'Steel fixer foreman');

select is(public.request_join(current_setting('test.code')) ->> 'status', 'requested',
  'a live code sends a request to join');
select is(public.request_join(current_setting('test.code')) ->> 'status', 'pending',
  'asking again shows the request is waiting');
select is((select count(*) from public.spaces), 0::bigint,
  'before the admin confirms, the Space stays hidden');
select is((select space_name || '/' || status from public.my_join_requests()),
  'Kuwait City Tower — Site team/pending', 'you see your own request with the Space name');
select is((select count(*) from public.space_join_requests), 0::bigint,
  'requests are not read from the table by the person who asked');
select throws_ok(
  format($$select public.confirm_join((select request_id from public.my_join_requests() limit 1), 'lead')$$),
  '42501', null, 'you cannot confirm yourself');

-- Nadia asks too.
reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a4", "role": "authenticated"}', true);
set local role authenticated;
select is(public.request_join(current_setting('test.code')) ->> 'status', 'requested',
  'a second person can ask with the same code');

-- Omar answers ----------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a1", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*) from public.space_join_requests where status = 'pending'),
  2::bigint, 'the admin sees the requests');
select is((select pending_requests from public.my_spaces()), 2,
  'My Spaces shows the admin how many are waiting');
select ok((select invited_by = '00000000-0000-0000-0000-0000000006a1' and via = 'code'
           from public.space_join_requests
           where profile_id = '00000000-0000-0000-0000-0000000006a3'),
  'the request says who shared the code');

select throws_ok(
  format($$select public.confirm_join(%L, 'boss')$$,
         (select id from public.space_join_requests
          where profile_id = '00000000-0000-0000-0000-0000000006a3')),
  '22023', null, 'a pass must be Lead, Crew or Viewer');
select lives_ok(
  format($$select public.confirm_join(%L, 'crew', array[%L]::uuid[])$$,
         (select id from public.space_join_requests
          where profile_id = '00000000-0000-0000-0000-0000000006a3'),
         current_setting('test.team')),
  'the admin confirms Ahmed as Crew in the Structure team');
select throws_ok(
  format($$select public.confirm_join(%L, 'crew')$$,
         (select id from public.space_join_requests
          where profile_id = '00000000-0000-0000-0000-0000000006a3')),
  'P0001', null, 'a request is answered once');

select lives_ok(
  format($$select public.decline_join(%L)$$,
         (select id from public.space_join_requests
          where profile_id = '00000000-0000-0000-0000-0000000006a4')),
  'the admin declines Nadia');

-- Proof: Ahmed's CV entry is now confirmed by the Space.
reset role;
select is(
  (select confirmed_by::text || '/' || source || '/' || (space_id = current_setting('test.space')::uuid)::text
   from public.cv_project_confirmations c
   join public.cv_projects p on p.id = c.cv_project_id
   where p.profile_id = '00000000-0000-0000-0000-0000000006a3'),
  '00000000-0000-0000-0000-0000000006a1/space_member/true',
  'confirming a member confirms their CV entry for the linked project');

-- Ahmed, now Crew --------------------------------------------------------------------------

select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a3", "role": "authenticated"}', true);
set local role authenticated;

select is((select count(*) from public.spaces), 1::bigint, 'a confirmed member sees the Space');
select is((select count(*) from public.space_members where left_at is null), 2::bigint,
  'members see each other');
select is((select count(*) from public.team_members
           where profile_id = '00000000-0000-0000-0000-0000000006a3'), 1::bigint,
  'he is in the Team he was given');
select ok(not public.can(current_setting('test.space')::uuid, 'create_items'),
  'Crew cannot create work items');
select ok(public.can(current_setting('test.space')::uuid, 'add_files'),
  'Crew can add files');
select ok(public.can(current_setting('test.space')::uuid, 'mark_done'),
  'Crew can mark his own items done');
select throws_ok(
  format($$select * from public.current_invite(%L)$$, current_setting('test.space')),
  '42501', null, 'Crew cannot invite while only admins invite');
select throws_ok(
  format($$select public.set_member_pass(%L, %L, 'lead')$$,
         current_setting('test.space'), '00000000-0000-0000-0000-0000000006a3'),
  '42501', null, 'a member cannot change his own pass');

-- Nadia, declined -------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a4", "role": "authenticated"}', true);
set local role authenticated;
select is((select status from public.my_join_requests()), 'declined',
  'a declined person sees it was not confirmed');
select is((select count(*) from public.spaces), 0::bigint, 'and still cannot see the Space');
select is(public.request_join(current_setting('test.code')) ->> 'status', 'declined',
  'after a decline, asking again waits a day');

-- Omar: undo, Viewer, Sara as Lead, custom rights -----------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a1", "role": "authenticated"}', true);
set local role authenticated;

select lives_ok(
  format($$select public.undo_decline(%L)$$,
         (select id from public.space_join_requests
          where profile_id = '00000000-0000-0000-0000-0000000006a4')),
  'Undo puts the request back');
select lives_ok(
  format($$select public.confirm_join(%L, 'viewer')$$,
         (select id from public.space_join_requests
          where profile_id = '00000000-0000-0000-0000-0000000006a4')),
  'then the admin confirms Nadia as Viewer');
select is(public.member_rights(current_setting('test.space')::uuid,
                               '00000000-0000-0000-0000-0000000006a4') ->> 'mark_done',
  'false', 'a Viewer cannot mark items done');

-- Sara joins as Lead.
reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a2", "role": "authenticated"}', true);
set local role authenticated;
select is(public.request_join(current_setting('test.code')) ->> 'status', 'requested',
  'Sara asks to join');
reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a1", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok(
  format($$select public.confirm_join(%L, 'lead')$$,
         (select id from public.space_join_requests
          where profile_id = '00000000-0000-0000-0000-0000000006a2')),
  'Sara is confirmed as Lead');

select lives_ok(
  format($$select public.set_member_pass(%L, %L, 'crew', '{"create_items": true, "add_files": true}')$$,
         current_setting('test.space'), '00000000-0000-0000-0000-0000000006a3'),
  'the admin opens "create work items" for Ahmed');
select is((select custom from public.space_members
           where profile_id = '00000000-0000-0000-0000-0000000006a3'),
  '{"create_items": true}'::jsonb, 'only the change from the Crew preset is kept');
select is(public.member_rights(current_setting('test.space')::uuid,
                               '00000000-0000-0000-0000-0000000006a3') ->> 'is_custom',
  'true', 'his pass shows as Custom');
select throws_ok(
  format($$select public.set_member_pass(%L, %L, 'crew', '{"delete_space": true}')$$,
         current_setting('test.space'), '00000000-0000-0000-0000-0000000006a3'),
  '22023', null, 'unknown rights are refused');

select lives_ok(
  format($$select public.update_space(%L, 'Kuwait City Tower — Site team', 'Site team', 'admins_leads')$$,
         current_setting('test.space')),
  'the admin lets Leads invite');

-- Sara (Lead) can invite now; Ahmed (Crew) still can't.
reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a2", "role": "authenticated"}', true);
set local role authenticated;
select is((select code from public.current_invite(current_setting('test.space')::uuid)),
  current_setting('test.code'), 'a Lead can share the code when Leads may invite');
select throws_ok(
  format($$select * from public.renew_invite(%L)$$, current_setting('test.space')),
  '42501', null, 'only admins can replace the code');

-- Sara adds the project to her CV after joining: confirmed at once.
insert into public.cv_projects (project_id, role_title)
values (current_setting('test.project')::uuid, 'Senior Structural Engineer');
select is((select count(*) from public.cv_project_confirmations c
           join public.cv_projects p on p.id = c.cv_project_id
           where p.profile_id = '00000000-0000-0000-0000-0000000006a2'), 1::bigint,
  'a project added to the CV later is confirmed by the Space');

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a3", "role": "authenticated"}', true);
set local role authenticated;
select ok(public.can(current_setting('test.space')::uuid, 'create_items'),
  'Ahmed can create work items now');
select throws_ok(
  format($$select * from public.current_invite(%L)$$, current_setting('test.space')),
  '42501', null, 'Crew still cannot invite');

-- Sign-up with the code (E1b) -------------------------------------------------------------

reset role;
insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000006a6', 'authenticated', 'authenticated', 'mona@example.com',
   jsonb_build_object('invite_code', current_setting('test.code'), 'home_market_id', 'eg'));
select is((select home_market_id from public.profiles
           where id = '00000000-0000-0000-0000-0000000006a6'), 'eg',
  'signing up with a live code opens any home country');
select is((select count(*) from public.space_join_requests
           where profile_id = '00000000-0000-0000-0000-0000000006a6'), 0::bigint,
  'no request is sent before the email code is verified');
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a6", "role": "authenticated"}', true);
set local role authenticated;
select is(public.request_join(current_setting('test.code')) ->> 'status', 'requested',
  'once signed in, the app sends the request with the saved code');
reset role;

-- Admins ----------------------------------------------------------------------------------

select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a1", "role": "authenticated"}', true);
set local role authenticated;

select throws_ok(
  format($$select public.leave_space(%L)$$, current_setting('test.space')),
  'P0001', null, 'the last admin cannot leave');
select throws_ok(
  format($$select public.set_member_admin(%L, %L, false)$$,
         current_setting('test.space'), '00000000-0000-0000-0000-0000000006a1'),
  'P0001', null, 'the last admin cannot step down');
select lives_ok(
  format($$select public.remove_member(%L, %L)$$,
         current_setting('test.space'), '00000000-0000-0000-0000-0000000006a4'),
  'the admin removes Nadia');
select lives_ok(
  format($$select * from public.renew_invite(%L)$$, current_setting('test.space')),
  'the admin replaces the code');
select is((select count(*) from public.invite_preview(current_setting('test.code'))), 0::bigint,
  'the old code stops working at once');
select lives_ok(
  format($$select public.transfer_ownership(%L, %L)$$,
         current_setting('test.space'), '00000000-0000-0000-0000-0000000006a2'),
  'Omar transfers ownership to Sara');
select ok(not public.is_space_admin(current_setting('test.space')::uuid),
  'after the transfer Omar is a member, not an admin');
select lives_ok(
  format($$select public.leave_space(%L)$$, current_setting('test.space')),
  'now Omar can leave');
select is((select count(*) from public.spaces), 0::bigint,
  'after leaving, the Space is hidden again');

-- Nadia was removed.
reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a4", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.spaces), 0::bigint,
  'a removed member no longer sees the Space');

-- Sara unlinks the project, then deletes the Space -----------------------------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a2", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok(
  format($$select public.set_space_project(%L, null)$$, current_setting('test.space')),
  'the new admin unlinks the project');
reset role;
select is((select count(*) from public.cv_project_confirmations
           where space_id = current_setting('test.space')::uuid), 0::bigint,
  'unlinking removes the confirmations that link gave');
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a2", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok(
  format($$select public.delete_space(%L)$$, current_setting('test.space')),
  'an admin deletes the Space');

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a3", "role": "authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.spaces), 0::bigint,
  'a deleted Space is gone for every member');
select is((select count(*) from public.my_spaces()), 0::bigint,
  'and is no longer in My Spaces');
select ok(not public.can(current_setting('test.space')::uuid, 'add_files'),
  'and nobody has rights in it');

-- Creating your own Space does not open a coming-soon home country ----------------------

reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a5", "role": "authenticated"}', true);
set local role authenticated;
select set_config('test.space2', public.create_space('Eve test')::text, true);
select throws_ok(
  $$update public.profiles set home_market_id = 'eg'
    where id = '00000000-0000-0000-0000-0000000006a5'$$,
  '23514', null, 'your own Space does not count as an invite');

-- The last admin's account is deleted --------------------------------------------------------

select set_config('test.code2',
  (select code from public.current_invite(current_setting('test.space2')::uuid)), true);
reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a3", "role": "authenticated"}', true);
set local role authenticated;
select is(public.request_join(current_setting('test.code2')) ->> 'status', 'requested',
  'Ahmed asks to join Eve''s Space');
reset role;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a5", "role": "authenticated"}', true);
set local role authenticated;
select lives_ok(
  format($$select public.confirm_join(%L, 'lead')$$,
         (select id from public.space_join_requests
          where space_id = current_setting('test.space2')::uuid and status = 'pending')),
  'Eve confirms him as Lead');
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-0000000006a5';
select ok((select is_admin from public.space_members
           where space_id = current_setting('test.space2')::uuid
             and profile_id = '00000000-0000-0000-0000-0000000006a3'),
  'when the only admin''s account is deleted, the Lead becomes admin');

-- Two accounts confirming each other prove nothing -------------------------------------------

select ok(public.is_space_proof(current_setting('test.space2')::uuid,
  '00000000-0000-0000-0000-0000000006a3', '00000000-0000-0000-0000-0000000006a1'),
  'a confirmation by someone else counts, even after they leave');
insert into public.space_members (space_id, profile_id, pass, confirmed_by) values
  (current_setting('test.space2')::uuid, '00000000-0000-0000-0000-0000000006a4', 'lead',
   '00000000-0000-0000-0000-0000000006a3');
update public.space_members set confirmed_by = '00000000-0000-0000-0000-0000000006a4'
where space_id = current_setting('test.space2')::uuid
  and profile_id = '00000000-0000-0000-0000-0000000006a3';
select ok(not public.is_space_proof(current_setting('test.space2')::uuid,
  '00000000-0000-0000-0000-0000000006a3', '00000000-0000-0000-0000-0000000006a4'),
  'two people who confirmed each other give no proof');

-- Too many wrong codes ---------------------------------------------------------------------

select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000006a4", "role": "authenticated"}', true);
set local role authenticated;
do $$ begin for i in 1..10 loop perform public.request_join('NOPE' || i); end loop; end $$;
select is(public.request_join('NOPE99') ->> 'status', 'too_many_tries',
  'after ten wrong codes in an hour, you must wait');
select is((select count(*) from public.invite_preview(current_setting('test.code2'))), 0::bigint,
  'and the preview stops answering too, even for a good code');

select * from finish();
rollback;
