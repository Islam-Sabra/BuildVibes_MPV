-- The store reviewers' demo Space (review 69 §6, founder's D4). Run once in
-- the Supabase SQL editor of the live project, with the founder's yes,
-- AFTER the reviewer account exists (sign in once with the reviewer email,
-- or create it under Authentication → Users) and has a name.
--
-- Set the reviewer's id on the first line, then run the whole file. It
-- stops if the Space is already there, and changes nothing else.
--
-- What it makes, all through the app's own functions:
-- - two demo teammates, "Omar (demo)" and "Sara (demo)". Their emails end
--   in .invalid, so nobody can sign in as them, and they have no country,
--   company or city, so the app never suggests them to real people;
-- - the Space "Demo — Tower A", the reviewer its admin, Omar Crew, Sara
--   Lead;
-- - one work item in each state: done and waiting for the reviewer's
--   check, checked, sent back with a new date, open for the reviewer;
-- - a checklist with one point ticked, an announcement, a chat message in
--   Everyone and a direct message to the reviewer.
--
-- Not here: a document for receipt needs an uploaded file. Post one from
-- the reviewer's phone once (Work → + → Document for receipt).
--
-- To remove it after review: delete the Space from Space info, and delete
-- the two demo users under Authentication → Users.

begin;
select set_config('demo.reviewer', '00000000-0000-0000-0000-000000000000', true);

create function pg_temp.act(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.reviewer() returns uuid language sql as $$
  select current_setting('demo.reviewer')::uuid;
$$;
create function pg_temp.omar() returns uuid language sql as $$
  select 'de000000-0000-4000-8000-000000000001'::uuid;
$$;
create function pg_temp.sara() returns uuid language sql as $$
  select 'de000000-0000-4000-8000-000000000002'::uuid;
$$;
create function pg_temp.space() returns uuid language sql as $$
  select current_setting('demo.space')::uuid;
$$;

do $$
begin
  if not exists (select 1 from public.profiles where id = pg_temp.reviewer()) then
    raise exception 'set demo.reviewer to the reviewer account''s id first';
  end if;
  if exists (select 1 from public.spaces s
             where s.created_by = pg_temp.reviewer() and s.name = 'Demo — Tower A'
               and s.deleted_at is null) then
    raise exception 'the demo Space is already there';
  end if;
end;
$$;

-- The demo teammates: no password, no way in, no country.
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data,
                        raw_app_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', pg_temp.omar(), 'authenticated', 'authenticated',
   'omar.demo@buildvibes-review.invalid', '{"locale": "en"}', '{"demo": true}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', pg_temp.sara(), 'authenticated', 'authenticated',
   'sara.demo@buildvibes-review.invalid', '{"locale": "en"}', '{"demo": true}', now(), now())
on conflict (id) do nothing;
update public.profiles p set first_name = n.f, last_name = n.l, headline = n.h
from (values (pg_temp.omar(), 'Omar', '(demo)', 'MEP foreman'),
             (pg_temp.sara(), 'Sara', '(demo)', 'Site engineer')) n(id, f, l, h)
where p.id = n.id;

-- The Space, as the reviewer.
select pg_temp.act(pg_temp.reviewer());
set local role authenticated;
select set_config('demo.space', public.create_space('Demo — Tower A')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.space(), pg_temp.omar(), 'crew', pg_temp.reviewer()),
       (pg_temp.space(), pg_temp.sara(), 'lead', pg_temp.reviewer());

-- Work items, raised by the reviewer for Omar.
select pg_temp.act(pg_temp.reviewer());
set local role authenticated;
select public.create_work_item(pg_temp.space(), 'Sleeves at grid C7 before the pour',
                               pg_temp.omar(), p_due => current_date,
                               p_place => 'Level 2, grid C7',
                               p_id => 'de000000-0000-4000-8000-0000000000a1');
select public.create_work_item(pg_temp.space(), 'Cable tray hangers, level 4',
                               pg_temp.omar(), p_place => 'Level 4 corridor',
                               p_id => 'de000000-0000-4000-8000-0000000000a2');
select public.create_work_item(pg_temp.space(), 'Fire stopping, riser 2',
                               pg_temp.omar(), p_due => current_date,
                               p_id => 'de000000-0000-4000-8000-0000000000a3');
select public.create_space_post('de000000-0000-4000-8000-0000000000b1', pg_temp.space(),
  'checklist', 'Before the pour, level 3', p_people => array[pg_temp.omar()],
  p_points => jsonb_build_array(
    jsonb_build_object('id', 'de000000-0000-4000-8000-0000000000c1', 'text', 'Rebar spacing checked'),
    jsonb_build_object('id', 'de000000-0000-4000-8000-0000000000c2', 'text', 'Cover blocks in place'),
    jsonb_build_object('id', 'de000000-0000-4000-8000-0000000000c3', 'text', 'Formwork clean')));

-- Omar signs all three as done.
select pg_temp.act(pg_temp.omar());
select public.sign_done('de000000-0000-4000-8000-0000000000a1', 'All six fixed.', '[]'::jsonb);
select public.sign_done('de000000-0000-4000-8000-0000000000a2', 'Hangers every 1.5 m.', '[]'::jsonb);
select public.sign_done('de000000-0000-4000-8000-0000000000a3', 'Done.', '[]'::jsonb);
select public.tick_point('de000000-0000-4000-8000-0000000000c1', true);

-- The reviewer checks one and sends one back with a new date; the first
-- waits for the reviewer's check (Needs you).
select pg_temp.act(pg_temp.reviewer());
select public.check_item('de000000-0000-4000-8000-0000000000a2');
select public.send_back('de000000-0000-4000-8000-0000000000a3', 'photo_missing',
                        'Please add a photo of the sealed riser.', true,
                        current_date + 1, null);

-- Sara: a work item for the reviewer, an announcement and a chat message.
select pg_temp.act(pg_temp.sara());
select public.create_work_item(pg_temp.space(), 'Approve the door schedule',
                               pg_temp.reviewer(), p_due => current_date + 1,
                               p_id => 'de000000-0000-4000-8000-0000000000a4');
select public.create_space_post('de000000-0000-4000-8000-0000000000b2', pg_temp.space(),
  'announcement', 'Concrete pour on Thursday',
  'Level 3 slab, from 6 am. Keep the north gate clear.');
select public.post_message('de000000-0000-4000-8000-0000000000d1',
  (select t.id from public.threads t where t.space_id = pg_temp.space() and t.team_id is null),
  'The pump truck arrives at 6. Gate office at 5:45.', null, '[]'::jsonb);
select public.start_dm('de000000-0000-4000-8000-0000000000e1', pg_temp.reviewer(),
  'de000000-0000-4000-8000-0000000000e2',
  'Hi, the door schedule is in the daybook for you.', '[]'::jsonb);
reset role;

select 'demo Space made: ' || pg_temp.space()::text as done;
commit;
