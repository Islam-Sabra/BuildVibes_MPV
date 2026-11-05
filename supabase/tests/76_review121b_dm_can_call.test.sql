-- Migration 20261202120000 (review 121b). Run with: supabase test db
--
-- Eve (e1) has a direct message open with each of: Gus (a2, Spaces and DMs),
-- Khalid (b3, Spaces only), Nadia (c4, Spaces and DMs but no number) and
-- Hamid (d5, Spaces and DMs).

begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000001221' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@r121b.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('a2'), ('b3'), ('c4'), ('d5')) x(id);
update public.profiles p set first_name = n.f, last_name = 'Test'
from (values ('e1', 'Eve'), ('a2', 'Gus'), ('b3', 'Khalid'), ('c4', 'Nadia'), ('d5', 'Hamid')) n(id, f)
where p.id = ('00000000-0000-0000-0000-0000001221' || n.id)::uuid;
update public.profiles p set phone = n.phone, phone_visibility = n.v
from (values ('a2', '+96590001234', 'spaces_and_dms'), ('b3', '+96555123456', 'spaces'),
             ('c4', null, 'spaces_and_dms'), ('d5', '+96566123456', 'spaces_and_dms')) n(id, phone, v)
where p.id = ('00000000-0000-0000-0000-0000001221' || n.id)::uuid;

create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000001221' || p_id)::uuid;
$$;
create function pg_temp.thread(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00001221d0' || p_id)::uuid;
$$;
-- Whether [p_who] gets a phone icon in the direct message with [p_other].
create function pg_temp.can(p_who text, p_other text) returns boolean language plpgsql as $$
declare v boolean;
begin
  perform set_config('request.jwt.claims',
    '{"sub": "' || pg_temp.uid(p_who) || '", "role": "authenticated"}', true);
  set local role authenticated;
  v := public.dm_can_call(pg_temp.uid(p_other));
  reset role;
  return v;
end;
$$;

insert into public.dm_threads (id, a_id, b_id, started_by)
select pg_temp.thread(o), least(pg_temp.uid('e1'), pg_temp.uid(o)),
       greatest(pg_temp.uid('e1'), pg_temp.uid(o)), pg_temp.uid('e1')
from (values ('a2'), ('b3'), ('c4'), ('d5')) x(o);
insert into public.dm_members (thread_id, profile_id, state)
select pg_temp.thread(o), p, 'open'
from (values ('a2'), ('b3'), ('c4'), ('d5')) x(o),
     lateral (values (pg_temp.uid('e1')), (pg_temp.uid(o))) m(p);

-- Who may call it.
select is(has_function_privilege('authenticated', 'public.dm_can_call(uuid)', 'execute'), true,
          'signed-in people may ask');
select is(has_function_privilege('anon', 'public.dm_can_call(uuid)', 'execute'), false,
          'nobody signed out');

-- The answer.
select is(pg_temp.can('e1', 'a2'), true, 'Spaces and DMs, the thread open: true');
select is(pg_temp.can('e1', 'b3'), false, 'Spaces only: false');
select is(pg_temp.can('e1', 'c4'), false, 'no number set: false, no dead button');
select is(pg_temp.can('a2', 'a2'), false, 'never for myself');

update public.dm_members set state = 'request'
where thread_id = pg_temp.thread('a2') and profile_id = pg_temp.uid('a2');
select is(pg_temp.can('e1', 'a2'), false, 'not while Gus hasn''t opened it');
update public.dm_members set state = 'open'
where thread_id = pg_temp.thread('a2') and profile_id = pg_temp.uid('a2');

insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('a2'), pg_temp.uid('e1'));
select is(pg_temp.can('e1', 'a2'), false, 'Gus blocked Eve: false');
delete from public.blocks where blocker_id = pg_temp.uid('a2');
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('e1'), pg_temp.uid('a2'));
select is(pg_temp.can('e1', 'a2'), false, 'Eve blocked Gus: false');
delete from public.blocks where blocker_id = pg_temp.uid('e1');

update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('d5');
select is(pg_temp.can('e1', 'd5'), false, 'a hidden account: false');
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('d5');
select is(pg_temp.can('e1', 'd5'), true, 'back again: true');

-- It never counts against the 30 a day.
select is(pg_temp.can('e1', 'a2'), true, 'asked again');
select is((select count(*)::int from public.phone_reads where caller_id = pg_temp.uid('e1')), 0,
          'no read counted');

-- The Space side drops a dead Call too: no number, no Call.
select is(public.phone_shown_to(pg_temp.uid('c4'), pg_temp.uid('e1'), null), false,
          'phone_shown_to: no number, false');

select * from finish();
rollback;
