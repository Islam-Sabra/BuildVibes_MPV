-- Review 116b (V1, the founder's test on build 1042): a vote, an edit, a
-- close (the five-minute job's too) and a tie's pick each tell the Space's
-- open daybooks (daybook_send, migration 20261103120000), so a vote shows
-- on other phones at once. A refused call sends nothing. Run with:
-- supabase test db
--
-- Omar (a1) made the Space "Live poll site"; Bilal (b2) is Crew, Vera
-- (c3) a Viewer. Eve (e5) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000068' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@polllive.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2'), ('c3'), ('e5')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000068' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000068' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0068-' || lpad(p, 12, '0'))::uuid;
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
-- The Space's daybook broadcasts about [p_post] so far (read as the
-- test's owner).
create function pg_temp.casts(p_post text) returns bigint language sql as $$
  select count(*) from realtime.messages
  where topic = 'daybook:' || pg_temp.sp()::text and event = 'changed'
    and payload ->> 'post_id' = pg_temp.id(p_post)::text;
$$;
-- [p_sql] as [p_id], then how many broadcasts about [p_post] it added. The
-- once-per-transaction mark is cleared first: each call here stands for
-- its own transaction, as on a phone.
create function pg_temp.sent(p_id text, p_post text, p_sql text) returns bigint language plpgsql as $$
declare v_before bigint := pg_temp.casts(p_post);
begin
  perform set_config('bv.daybook_sent', '', true);
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  begin
    execute p_sql;
  exception when others then
    null;
  end;
  reset role;
  return pg_temp.casts(p_post) - v_before;
end;
$$;

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Live poll site')::text, true);
select public.create_poll(pg_temp.id('a1'), pg_temp.sp(), 'Pour today?', pg_temp.opts('a1', 'Yes', 'No'));
select public.create_poll(pg_temp.id('a2'), pg_temp.sp(), 'Gate?', pg_temp.opts('a2', 'North', 'South'));
select public.create_poll(pg_temp.id('a3'), pg_temp.sp(), 'Lunch?', pg_temp.opts('a3', 'Noon', 'One'),
  false, now() + interval '1 hour');
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('a1')
from (values ('b2', 'crew'), ('c3', 'viewer')) x(id, pass);

-- Edit, before anyone votes.
select is(pg_temp.sent('a1', 'a1', format($$select public.edit_poll(%L, 'Pour today, then?',
            pg_temp.opts('a1', 'Yes', 'No'), false, null)$$, pg_temp.id('a1'))), 1::bigint,
  'V1: an edit tells the Space');
-- A vote, and a refused one.
select is(pg_temp.sent('c3', 'a1', format($$select public.vote_poll(%L, array[%L]::uuid[])$$,
            pg_temp.id('a1'), pg_temp.opt('a1', 1))), 1::bigint,
  'V1: a vote writes one broadcast on daybook:<space> with its post_id');
select is(pg_temp.sent('e5', 'a1', format($$select public.vote_poll(%L, array[%L]::uuid[])$$,
            pg_temp.id('a1'), pg_temp.opt('a1', 2))), 0::bigint,
  'V1: a refused vote writes none');
select is((select count(*)::int from public.poll_votes where profile_id = pg_temp.uid('c3')), 1,
  'the vote is there');
-- Closing.
select is(pg_temp.sent('a1', 'a1', format($$select public.close_poll(%L)$$, pg_temp.id('a1'))), 1::bigint,
  'V1: closing tells the Space');
-- A tie, and its creator's pick.
select pg_temp.sent('b2', 'a2', format($$select public.vote_poll(%L, array[%L]::uuid[])$$,
         pg_temp.id('a2'), pg_temp.opt('a2', 1)));
select pg_temp.sent('c3', 'a2', format($$select public.vote_poll(%L, array[%L]::uuid[])$$,
         pg_temp.id('a2'), pg_temp.opt('a2', 2)));
select pg_temp.sent('a1', 'a2', format($$select public.close_poll(%L)$$, pg_temp.id('a2')));
select is(pg_temp.sent('a1', 'a2', format($$select public.decide_poll(%L, %L)$$,
            pg_temp.id('a2'), pg_temp.opt('a2', 2))), 1::bigint,
  'V1: a tie''s pick tells the Space');
-- The five-minute job.
update public.polls set closes_at = now() - interval '1 minute' where post_id = pg_temp.id('a3');
select set_config('bv.daybook_sent', '', true);
select set_config('test.before', pg_temp.casts('a3')::text, true);
select public.close_due_polls();
select is(pg_temp.casts('a3') - current_setting('test.before')::bigint, 1::bigint,
  'V1: the job''s close tells the Space too');
select is((select closed_at is not null from public.polls where post_id = pg_temp.id('a3')), true,
  'and it is closed');

select * from finish();
rollback;
