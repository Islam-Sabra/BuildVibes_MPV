-- Review 118 F3: a vote is acting. Once anyone other than its creator has
-- voted, holding the poll offers Archive, never Delete, and
-- delete_space_post refuses it. The creator's own vote doesn't count.
-- Run with: supabase test db
--
-- Omar (a1) made the Space; Bilal (b2) is Crew.

begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000074' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@pollhold.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('b2')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000074' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000074' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0074-' || lpad(p, 12, '0'))::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.opts(p_poll text) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('id', pg_temp.id(p_poll || 'b1'), 'label', 'Tower'),
                           jsonb_build_object('id', pg_temp.id(p_poll || 'b2'), 'label', 'Mobile'));
$$;
create function pg_temp.vote(p_id text, p_post text) returns void language plpgsql as $$
begin
  perform pg_temp.as_user(p_id);
  set local role authenticated;
  perform public.vote_poll(pg_temp.id(p_post), array[pg_temp.id(p_post || 'b1')]);
  reset role;
end;
$$;
create function pg_temp.hold(p_post text) returns text language plpgsql as $$
declare v text;
begin
  perform pg_temp.as_user('a1');
  set local role authenticated;
  select c.card ->> 'hold' into v from public.daybook_card(pg_temp.id(p_post)) c;
  reset role;
  return v;
end;
$$;

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Hold site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
values (pg_temp.sp(), pg_temp.uid('b2'), 'crew', pg_temp.uid('a1'));

select pg_temp.as_user('a1');
set local role authenticated;
select public.create_poll(pg_temp.id('c1'), pg_temp.sp(), 'Which crane?', pg_temp.opts('c1'));
select public.create_poll(pg_temp.id('c2'), pg_temp.sp(), 'Which gate?', pg_temp.opts('c2'));
reset role;

select is(pg_temp.hold('c1'), 'delete', 'nobody voted: Delete');
select pg_temp.vote('a1', 'c1');
select is(pg_temp.hold('c1'), 'delete', 'only its creator voted: still Delete');
select pg_temp.vote('b2', 'c1');
select is(pg_temp.hold('c1'), 'archive', 'F3: someone else voted: Archive');

select pg_temp.as_user('a1');
set local role authenticated;
select throws_ok($$select public.delete_space_post(pg_temp.id('c1'))$$, '22023', null,
  'F3: delete refuses a poll with other people''s votes');
select lives_ok($$select public.archive_space_post(pg_temp.id('c1'))$$, 'F3: it archives');
reset role;

select pg_temp.vote('a1', 'c2');
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.delete_space_post(pg_temp.id('c2'))$$,
  'its creator''s own vote alone: it deletes');
reset role;
select ok((select deleted_at is not null from public.space_posts where id = pg_temp.id('c2')), 'deleted');

select * from finish();
rollback;
