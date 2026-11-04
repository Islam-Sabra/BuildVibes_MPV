-- Review 116: the lead's check of claude/r116 at 30009056 (P1, P2, P7, P10,
-- P11, P12). Run with: supabase test db
--
-- Omar (a1) made the Space "Check site": its admin, a Lead. Bilal (b2) and
-- Fadi (f6) are Crew, Vera (c3) a Viewer, Dana (d4) a Lead, Gil (a7) Crew
-- who will leave. Eve (e5) is not in the Space. Bilal and Dana are the
-- Team "Steel".

begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000067' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@pollcheck.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('d4'), ('e5'), ('f6'), ('a7')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l, photo_path = n.ph
from (values ('a1', 'Omar', 'Haddad', null), ('b2', 'Bilal', 'Nair', null),
             ('c3', 'Vera', 'Lane', null), ('d4', 'Dana', 'Saad', null),
             ('e5', 'Eve', 'Out', null), ('f6', 'Fadi', 'Aziz', 'f6/me.jpg'),
             ('a7', 'Gil', 'Gone', null)) n(id, f, l, ph)
where p.id = ('00000000-0000-0000-0000-0000000067' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000067' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000067' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0067-' || lpad(p, 12, '0'))::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.opts(p_poll text, variadic p_labels text[]) returns jsonb language sql as $$
  select jsonb_agg(jsonb_build_object('id', pg_temp.id(p_poll || 'b' || i), 'label', l) order by i)
  from unnest(p_labels) with ordinality u(l, i);
$$;
create function pg_temp.opt(p_poll text, p_n int) returns uuid language sql as $$
  select pg_temp.id(p_poll || 'b' || p_n);
$$;
create function pg_temp.vote(p_id text, p_post text, p_opts uuid[]) returns void language plpgsql as $$
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  perform public.vote_poll(pg_temp.id(p_post), p_opts);
  reset role;
end;
$$;
create function pg_temp.poll(p_id text, p_post text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  select c.card -> 'poll' into v from public.daybook_card(pg_temp.id(p_post)) c;
  reset role;
  return v;
end;
$$;
create function pg_temp.reads(p_id text, p_sql text) returns integer language plpgsql as $$
declare v integer;
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return v;
end;
$$;
-- [p_reader]'s card: the voter [p_voter] on [p_post]'s option [p_n].
create function pg_temp.voter(p_reader text, p_post text, p_n int, p_voter text) returns jsonb
language sql as $$
  select v from jsonb_array_elements(pg_temp.poll(p_reader, p_post) -> 'options') o,
                jsonb_array_elements(o -> 'voters') v
  where (o ->> 'id')::uuid = pg_temp.opt(p_post, p_n) and (v ->> 'id')::uuid = pg_temp.uid(p_voter);
$$;
create function pg_temp.def(p_fn regprocedure) returns text language sql as $$
  select lower(pg_get_functiondef(p_fn));
$$;

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Check site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1')
from (values ('b2', 'crew'), ('c3', 'viewer'), ('d4', 'lead'), ('f6', 'crew'), ('a7', 'crew')) x(id, pass);
insert into public.teams (id, space_id, name, created_by)
values (pg_temp.id('7ea'), pg_temp.sp(), 'Steel', pg_temp.uid('a1'));
insert into public.team_members (team_id, profile_id)
values (pg_temp.id('7ea'), pg_temp.uid('b2')), (pg_temp.id('7ea'), pg_temp.uid('d4'));

-- A poll for the whole Space; Fadi and Omar choose the first.
select pg_temp.as_user('a1');
set local role authenticated;
select public.create_poll(pg_temp.id('c1'), pg_temp.sp(), 'Which crane?',
  pg_temp.opts('c1', 'Tower', 'Mobile'));
reset role;
select pg_temp.vote('f6', 'c1', array[pg_temp.opt('c1', 1)]);
select pg_temp.vote('a1', 'c1', array[pg_temp.opt('c1', 1)]);

-- P1. Names and faces across a block, and of accounts going away.
select is(pg_temp.voter('c3', 'c1', 1, 'f6') ->> 'name', 'Fadi Aziz', 'a voter''s name, as a rule');
select is(pg_temp.voter('c3', 'c1', 1, 'f6') ->> 'avatar', 'f6/me.jpg', 'and their face');
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('b2'), pg_temp.uid('f6'));
select is(pg_temp.voter('b2', 'c1', 1, 'f6') ->> 'name', null, 'P1: no name across a block');
select is(pg_temp.voter('b2', 'c1', 1, 'f6') ->> 'avatar', null, 'P1: and no photo');
select is(pg_temp.voter('c3', 'c1', 1, 'f6') ->> 'name', 'Fadi Aziz', 'others still see it');
-- Not yet, for Bilal (blocks Fadi, who voted) and for Vera once she blocks
-- Dana: Bilal, Vera, Dana and Gil haven't voted.
select is((pg_temp.poll('c3', 'c1') -> 'not_yet' ->> 'more')::int
          + jsonb_array_length(pg_temp.poll('c3', 'c1') -> 'not_yet' -> 'names'), 4,
  'Not yet: four who haven''t');
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('c3'), pg_temp.uid('d4'));
select is((pg_temp.poll('c3', 'c1') -> 'not_yet' ->> 'more')::int
          + jsonb_array_length(pg_temp.poll('c3', 'c1') -> 'not_yet' -> 'names'), 3,
  'P1: Not yet leaves out someone across a block');
select ok(not (pg_temp.poll('c3', 'c1') -> 'not_yet' -> 'names') ? 'Dana', 'P1: never by name');
-- An account going away: no name, no face.
select pg_temp.vote('a7', 'c1', array[pg_temp.opt('c1', 2)]);
update public.profiles set deletion_scheduled_at = now(), photo_path = 'a7/me.jpg'
where id = pg_temp.uid('a7');
select is(pg_temp.voter('c3', 'c1', 2, 'a7') ->> 'name', null, 'P1: no name of a hidden account');
select is(pg_temp.voter('c3', 'c1', 2, 'a7') ->> 'avatar', null, 'P1: nor its photo');
-- P11: a hidden account can't vote.
select throws_ok($$select pg_temp.vote('a7', 'c1', array[pg_temp.opt('c1', 1)])$$, '42501', null,
  'P11: a hidden account can''t vote');
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('a7');
-- Who closed it, across a block.
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('a1'), pg_temp.uid('d4'));
select pg_temp.as_user('a1');
set local role authenticated;
select public.close_poll(pg_temp.id('c1'));
reset role;
select is(pg_temp.poll('c3', 'c1') ->> 'closed_by_name', 'Omar Haddad', 'who closed it');
select is(pg_temp.poll('d4', 'c1') ->> 'closed_by_name', null, 'P1: but not across a block');

-- P2. Races: each call takes the poll's row lock first, and the winner is
-- worked out after it. Two picks of a tie: the second is refused.
select ok(pg_temp.def('public.vote_poll(uuid, uuid[])') ~ 'from public\.polls[^;]*for update',
  'P2: vote_poll locks the poll');
select ok(pg_temp.def('public.edit_poll(uuid, text, jsonb, boolean, timestamptz)')
          ~ 'from public\.polls[^;]*for update', 'P2: edit_poll locks the poll');
select ok(pg_temp.def('public.poll_close(uuid, uuid)') ~ 'from public\.polls[^;]*for update',
  'P2: closing locks the poll');
select ok(pg_temp.def('public.poll_close(uuid, uuid)')
          ~ 'for update.*poll_leaders', 'P2: and counts after the lock');
select ok(pg_temp.def('public.decide_poll(uuid, uuid)') ~ 'from public\.polls[^;]*for update',
  'P2: decide_poll locks the poll');
select ok(pg_temp.def('public.decide_poll(uuid, uuid)') ~ 'decided_option is null',
  'P2: and decides only what is undecided');

select pg_temp.as_user('b2');
set local role authenticated;
select public.create_poll(pg_temp.id('c2'), pg_temp.sp(), 'Gate?', pg_temp.opts('c2', 'North', 'South'));
reset role;
select pg_temp.vote('b2', 'c2', array[pg_temp.opt('c2', 1)]);
select pg_temp.vote('d4', 'c2', array[pg_temp.opt('c2', 2)]);
select pg_temp.as_user('a1');
set local role authenticated;
select public.close_poll(pg_temp.id('c2'));
reset role;
-- P7: a tie tells its creator to pick the winner.
select is((select array_agg(kind) from public.notifications
           where space_post_id = pg_temp.id('c2') and profile_id = pg_temp.uid('b2')
             and kind in ('poll_closed', 'poll_tied')), array['poll_tied'],
  'P7: a tie is "poll_tied", not "poll_closed"');
select pg_temp.as_user('b2');
set local role authenticated;
select public.decide_poll(pg_temp.id('c2'), pg_temp.opt('c2', 2));
select throws_ok($$select public.decide_poll(pg_temp.id('c2'), pg_temp.opt('c2', 1))$$, '22023', null,
  'P2: a second pick is refused');
reset role;
select is((select decided_option from public.polls where post_id = pg_temp.id('c2')), pg_temp.opt('c2', 2),
  'the first pick stands');
select throws_ok($$select pg_temp.vote('d4', 'c2', array[pg_temp.opt('c2', 1)])$$, '22023', null,
  'P2: no vote after it closes');

-- P11. Who can't read or vote.
select is(pg_temp.reads('e5', $$select count(*)::int from public.poll_votes$$), 0,
  'P11: someone outside reads no vote');
select is(pg_temp.reads('c3', $$select count(*)::int from public.poll_votes$$) > 0, true,
  'a member reads them');
select pg_temp.as_user('b2');
set local role authenticated;
select public.create_poll(pg_temp.id('c3'), pg_temp.sp(), 'Steel only?',
  pg_temp.opts('c3', 'Yes', 'No'), false, null, pg_temp.id('7ea'));
reset role;
select is(pg_temp.reads('c3', format($$select count(*)::int from public.poll_options where post_id = %L$$,
                                     pg_temp.id('c3'))), 0,
  'P11: someone outside the Team reads none of its poll');
select throws_ok($$select pg_temp.vote('c3', 'c3', array[pg_temp.opt('c3', 1)])$$, '42501', null,
  'P11: nor votes on it');
select lives_ok($$select pg_temp.vote('d4', 'c3', array[pg_temp.opt('c3', 1)])$$, 'the Team votes');
update public.space_members set left_at = now() where space_id = pg_temp.sp() and profile_id = pg_temp.uid('a7');
select pg_temp.as_user('a1');
set local role authenticated;
select public.create_poll(pg_temp.id('c4'), pg_temp.sp(), 'Lunch?', pg_temp.opts('c4', 'Noon', 'One'),
  false, now() + interval '1 hour');
reset role;
select throws_ok($$select pg_temp.vote('a7', 'c4', array[pg_temp.opt('c4', 1)])$$, '42501', null,
  'P11: someone who left can''t vote');
-- The five-minute job tells the creator.
select pg_temp.vote('c3', 'c4', array[pg_temp.opt('c4', 1)]);
update public.polls set closes_at = now() - interval '1 minute' where post_id = pg_temp.id('c4');
select ok(public.close_due_polls() >= 1, 'the job closes it');
select is((select count(*)::int from public.notifications
           where space_post_id = pg_temp.id('c4') and profile_id = pg_temp.uid('a1')
             and kind = 'poll_closed' and actor_id is null), 1,
  'P11: and its creator hears it closed');

-- P12. A malformed option id is 22023, not a raw 22P02.
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.create_poll(pg_temp.id('c9'), pg_temp.sp(), 'Bad ids?',
                   '[{"id": "------------------------------------", "label": "a"},
                     {"id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa-", "label": "b"}]'::jsonb)$$,
  '22023', null, 'P12: a malformed id is refused as 22023');
reset role;

-- P10. My data: my poll votes (the poll, the option, when).
select pg_temp.as_user('c3');
set local role authenticated;
select set_config('test.req', public.request_my_data()::text, true);
reset role;
select is(jsonb_array_length(public.export_my_data(current_setting('test.req')::uuid) -> 'poll_votes'), 1,
  'P10: my poll votes are in my data');
select is(public.export_my_data(current_setting('test.req')::uuid) -> 'poll_votes' -> 0 ->> 'option', 'Noon',
  'P10: with the option, the poll and when');

select * from finish();
rollback;
