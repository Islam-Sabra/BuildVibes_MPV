-- Review 116: Poll. Run with: supabase test db
--
-- Omar (a1) made the Space "Poll site": its admin, a Lead. Bilal (b2) is
-- Crew, Vera (c3) a Viewer, Dana (d4) a Lead who isn't an admin. Eve (e5)
-- is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(48);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000066' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@poll.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('d4'), ('e5')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('a1', 'Omar', 'Haddad'), ('b2', 'Bilal', 'Nair'), ('c3', 'Vera', 'Lane'),
             ('d4', 'Dana', 'Saad'), ('e5', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000066' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000066' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000066' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0066-' || lpad(p, 12, '0'))::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
-- [p_options] labels as the app sends them: ids o1, o2, … of [p_poll].
create function pg_temp.opts(p_poll text, variadic p_labels text[]) returns jsonb language sql as $$
  select jsonb_agg(jsonb_build_object('id', pg_temp.id(p_poll || 'b' || i), 'label', l) order by i)
  from unnest(p_labels) with ordinality u(l, i);
$$;
create function pg_temp.opt(p_poll text, p_n int) returns uuid language sql as $$
  select pg_temp.id(p_poll || 'b' || p_n);
$$;
-- [p_id] votes [p_opts] on [p_post].
create function pg_temp.vote(p_id text, p_post text, p_opts uuid[]) returns void language plpgsql as $$
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  perform public.vote_poll(pg_temp.id(p_post), p_opts);
  reset role;
end;
$$;
-- [p_post]'s card as [p_id] reads it: its "poll".
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

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Poll site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1')
from (values ('b2', 'crew'), ('c3', 'viewer'), ('d4', 'lead')) x(id, pass);

-- Who makes one.
select pg_temp.as_user('b2');
set local role authenticated;
select is(public.create_poll(pg_temp.id('a1'), pg_temp.sp(), 'Pour on Friday or Sunday?',
            pg_temp.opts('a1', 'Friday', 'Sunday')), pg_temp.id('a1'), 'Crew makes a poll');
select is(public.create_poll(pg_temp.id('a1'), pg_temp.sp(), 'Pour on Friday or Sunday?',
            pg_temp.opts('a1', 'Friday', 'Sunday')), pg_temp.id('a1'), 'the same id again is the same poll');
select throws_ok($$select public.create_poll(pg_temp.id('a9'), pg_temp.sp(), 'One?',
                   pg_temp.opts('a9', 'Only'))$$, '22023', null, 'at least 2 options');
select throws_ok($$select public.create_poll(pg_temp.id('a9'), pg_temp.sp(), 'Seven?',
                   pg_temp.opts('a9', 'a', 'b', 'c', 'd', 'e', 'f', 'g'))$$, '22023', null, 'at most 6');
select throws_ok($$select public.create_poll(pg_temp.id('a9'), pg_temp.sp(), 'Q?',
                   pg_temp.opts('a9', 'a', repeat('x', 61)))$$, '22023', null, 'an option is 1 to 60');
select throws_ok($$select public.create_poll(pg_temp.id('a9'), pg_temp.sp(), 'Q',
                   pg_temp.opts('a9', 'a', 'b'))$$, '22023', null, 'a question is 2 to 140');
reset role;
select pg_temp.as_user('c3');
set local role authenticated;
select throws_ok($$select public.create_poll(pg_temp.id('a9'), pg_temp.sp(), 'Viewer?',
                   pg_temp.opts('a9', 'a', 'b'))$$, '42501', null, 'a Viewer doesn''t make one');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok($$select public.create_poll(pg_temp.id('a9'), pg_temp.sp(), 'Outside?',
                   pg_temp.opts('a9', 'a', 'b'))$$, '42501', null, 'nor someone outside');
reset role;

select is((select kind || ' ' || title from public.space_posts where id = pg_temp.id('a1')),
  'poll Pour on Friday or Sunday?', 'a poll post, the question its title');
select is((select array_agg(label order by sort) from public.poll_options where post_id = pg_temp.id('a1')),
  array['Friday', 'Sunday'], 'its options, in order');
select is((select count(*)::int from public.notifications
           where space_post_id = pg_temp.id('a1') and kind = 'poll_new'), 3,
  'everyone else in the Space hears of it, as an announcement');

-- Who reads it.
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
select is(pg_temp.reads('e5', $$select count(*)::int from public.polls$$), 0,
  'someone outside reads no poll');
select is(pg_temp.reads('e5', $$select count(*)::int from public.poll_options$$), 0, 'nor its options');
select is(pg_temp.reads('c3', $$select count(*)::int from public.poll_options$$), 2, 'a Viewer reads them');
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$insert into public.poll_votes (option_id, profile_id)
                   values (pg_temp.opt('a1', 1), pg_temp.uid('b2'))$$, '42501', null,
  'no vote is written directly');
reset role;

-- Voting, one answer.
select pg_temp.vote('c3', 'a1', array[pg_temp.opt('a1', 1)]);
select is(pg_temp.reads('a1', $$select count(*)::int from public.poll_votes$$), 1, 'a Viewer votes');
select throws_ok($$select pg_temp.vote('c3', 'a1', array[pg_temp.opt('a1', 1), pg_temp.opt('a1', 2)])$$,
  '22023', null, 'one answer is one');
select pg_temp.vote('c3', 'a1', array[pg_temp.opt('a1', 2)]);
select is((select array_agg(option_id) from public.poll_votes where profile_id = pg_temp.uid('c3')),
  array[pg_temp.opt('a1', 2)], 'choosing another changes it');
select pg_temp.vote('c3', 'a1', '{}');
select is((select count(*)::int from public.poll_votes where profile_id = pg_temp.uid('c3')), 0,
  'and none takes it back');
select throws_ok($$select pg_temp.vote('e5', 'a1', array[pg_temp.opt('a1', 1)])$$, '42501', null,
  'someone outside can''t vote');
select throws_ok($$select pg_temp.vote('c3', 'a1', array[pg_temp.id('ffff')])$$, '22023', null,
  'only this poll''s options');

-- Editing: until the first vote.
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok($$select public.edit_poll(pg_temp.id('a1'), 'Pour Friday or Sunday?',
                  pg_temp.opts('a1', 'Friday', 'Sunday', 'Monday'), false, null)$$,
  'its creator edits it before any vote');
reset role;
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok($$select public.edit_poll(pg_temp.id('a1'), 'Mine?', pg_temp.opts('a1', 'a', 'b'), false, null)$$,
  '42501', null, 'nobody else edits it');
reset role;
select pg_temp.vote('a1', 'a1', array[pg_temp.opt('a1', 1)]);
select pg_temp.vote('d4', 'a1', array[pg_temp.opt('a1', 1)]);
select pg_temp.vote('c3', 'a1', array[pg_temp.opt('a1', 2)]);
select pg_temp.as_user('b2');
set local role authenticated;
select throws_ok($$select public.edit_poll(pg_temp.id('a1'), 'Changed?', pg_temp.opts('a1', 'a', 'b'), false, null)$$,
  '22023', null, 'not after the first vote');
reset role;

-- The card.
select is((pg_temp.poll('a1', 'a1') -> 'options' -> 0 ->> 'count')::int, 2, 'the card: each option''s choices');
select is((pg_temp.poll('a1', 'a1') -> 'options' -> 0 ->> 'mine')::boolean, true, 'mine is ticked');
select is((pg_temp.poll('c3', 'a1') -> 'options' -> 0 ->> 'mine')::boolean, false, 'not someone else''s');
select ok((pg_temp.poll('c3', 'a1') -> 'options' -> 0 -> 'voters') @> '[{"name": "Omar Haddad"}]',
  'with who chose it');
select is(pg_temp.poll('a1', 'a1') -> 'not_yet', '{"names": ["Bilal"], "more": 0}'::jsonb,
  'Not yet: who could answer and hasn''t');
select is((pg_temp.poll('a1', 'a1') ->> 'voted')::boolean, true, 'someone voted');
select is(pg_temp.poll('a1', 'a1') ->> 'closed_at', null, 'still open');

-- Closing: the creator or a Space admin, final.
select pg_temp.as_user('d4');
set local role authenticated;
select throws_ok($$select public.close_poll(pg_temp.id('a1'))$$, '42501', null,
  'a Lead who isn''t its creator or an admin can''t close it');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.close_poll(pg_temp.id('a1'))$$, 'a Space admin closes it');
reset role;
select is((select decided_option from public.polls where post_id = pg_temp.id('a1')), pg_temp.opt('a1', 1),
  'the most chosen is decided');
select is(pg_temp.poll('c3', 'a1') ->> 'closed_by_name', 'Omar Haddad', 'the card says who closed it');
select throws_ok($$select pg_temp.vote('b2', 'a1', array[pg_temp.opt('a1', 1)])$$, '22023', null,
  'no vote after it closes');
select is((select count(*)::int from public.notifications
           where space_post_id = pg_temp.id('a1') and kind = 'poll_closed'
             and profile_id = pg_temp.uid('b2')), 1, 'its creator hears it closed');

-- More than one, a tie, and the creator decides.
select pg_temp.as_user('b2');
set local role authenticated;
select public.create_poll(pg_temp.id('a2'), pg_temp.sp(), 'Which gates?',
  pg_temp.opts('a2', 'Gate 1', 'Gate 2', 'Gate 3'), true);
reset role;
select pg_temp.vote('a1', 'a2', array[pg_temp.opt('a2', 1), pg_temp.opt('a2', 2)]);
select is((select count(*)::int from public.poll_votes v join public.poll_options o on o.id = v.option_id
           where v.profile_id = pg_temp.uid('a1') and o.post_id = pg_temp.id('a2')), 2,
  'more than one: each option counts');
select pg_temp.as_user('b2');
set local role authenticated;
select public.close_poll(pg_temp.id('a2'));
reset role;
select is((pg_temp.poll('b2', 'a2') ->> 'tied')::boolean, true, 'a tie is tied');
select is((select decided_option from public.polls where post_id = pg_temp.id('a2')), null,
  'with nothing decided');
select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.decide_poll(pg_temp.id('a2'), pg_temp.opt('a2', 3))$$, '22023', null,
  'only one of the tied options');
reset role;
select pg_temp.as_user('b2');
set local role authenticated;
select lives_ok($$select public.decide_poll(pg_temp.id('a2'), pg_temp.opt('a2', 2))$$,
  'its creator picks the winner');
reset role;
select is((select decided_option from public.polls where post_id = pg_temp.id('a2')), pg_temp.opt('a2', 2),
  'and it is decided');

-- Nobody voted; and the closing time.
select pg_temp.as_user('b2');
set local role authenticated;
select public.create_poll(pg_temp.id('a3'), pg_temp.sp(), 'Anyone?', pg_temp.opts('a3', 'Yes', 'No'),
  false, now() + interval '1 hour');
select public.create_poll(pg_temp.id('a4'), pg_temp.sp(), 'Nobody?', pg_temp.opts('a4', 'Yes', 'No'));
select public.close_poll(pg_temp.id('a4'));
reset role;
select is((select coalesce(decided_option::text, '-') || ' ' || (closed_at is not null)::text
           from public.polls where post_id = pg_temp.id('a4')), '- true', 'nobody voted: closed, nothing decided');
select pg_temp.vote('c3', 'a3', array[pg_temp.opt('a3', 1)]);
update public.polls set closes_at = now() - interval '1 minute' where post_id = pg_temp.id('a3');
select throws_ok($$select pg_temp.vote('a1', 'a3', array[pg_temp.opt('a3', 2)])$$, '22023', null,
  'no vote once its time has passed');
select ok(public.close_due_polls() >= 1, 'the five-minute job closes it');
select is((select decided_option from public.polls where post_id = pg_temp.id('a3')), pg_temp.opt('a3', 1),
  'and decides it');
select ok(not has_function_privilege('authenticated', 'public.close_due_polls()', 'execute'),
  'the job is not the app''s');

select * from finish();
rollback;
