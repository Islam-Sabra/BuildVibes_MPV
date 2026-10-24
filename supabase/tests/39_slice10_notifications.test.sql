-- Migration 39 (review 87): F97's one follow-up push per quiet time, and
-- Activity rows about a daybook post. Since migration 41 (F102) nothing
-- queues a follow-up; claim_push still handles one queued before.
-- Run with: supabase test db
--
-- Omar (e1) runs the Space; Rakesh (e2) and Sara (e3) are Crew in it, so
-- their conversations with Omar are open. Phones: e1, e2, e3.

begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000039' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@slice10.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000039' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000039' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000039' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000039' || p)::uuid;
$$;
-- Run as the database owner: pushes queued of a kind for someone.
create function pg_temp.q(p_who text, p_kind text) returns bigint language sql as $$
  select count(*) from public.push_queue where profile_id = pg_temp.uid(p_who) and kind = p_kind;
$$;
create function pg_temp.follow_up(p_who text) returns public.push_queue language sql as $$
  select * from public.push_queue
  where profile_id = pg_temp.uid(p_who) and kind = 'dm_follow_up'
  order by id desc limit 1;
$$;
-- The quiet time began two minutes ago: the first message and its push.
create function pg_temp.two_minutes_ago(p_thread text) returns void language sql as $$
  update public.push_queue set created_at = now() - interval '2 minutes'
  where dm_thread_id = pg_temp.id(p_thread) and kind = 'dm_message';
  update public.dm_messages set created_at = now() - interval '2 minutes'
  where thread_id = pg_temp.id(p_thread);
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Slice 10 site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select current_setting('test.space')::uuid, pg_temp.uid(x.id), 'crew', pg_temp.uid('e1')
from (values ('e2'), ('e3')) x(id);
insert into public.push_tokens (token, profile_id, platform)
select 'fcm-token-for-' || x.id || '-0123456789abcdef', pg_temp.uid(x.id), 'android'
from (values ('e1'), ('e2'), ('e3')) x(id);

-- F97, after migration 41 (F102): every message pushes, no follow-up is queued --------------

select pg_temp.as_user('e1');
set local role authenticated;
select public.start_dm(pg_temp.id('a001'), pg_temp.uid('e2'), pg_temp.id('b001'), 'Pour at 7');
reset role;
select pg_temp.two_minutes_ago('a001');
select is(pg_temp.q('e2', 'dm_message'), 1::bigint, 'the first message is pushed');

select pg_temp.as_user('e1');
set local role authenticated;
select public.send_dm(pg_temp.id('b002'), pg_temp.id('a001'), 'Pump is late');
select public.send_dm(pg_temp.id('b003'), pg_temp.id('a001'), 'Stop the pour');
reset role;
select is(pg_temp.q('e2', 'dm_message'), 3::bigint, '(F102) inside the old quiet time each message pushes');
select is(pg_temp.q('e2', 'dm_follow_up'), 0::bigint, '(F102) and no follow-up is queued');

-- A follow-up queued on the live server before migration 41 still goes
-- through claim_push as designed (review 88 S1). It is put in by hand.
create function pg_temp.old_follow_up(p_who text, p_from text, p_thread text) returns void language sql as $$
  insert into public.push_queue (profile_id, kind, actor_id, dm_thread_id, data, not_before)
  select pg_temp.uid(p_who), 'dm_follow_up', pg_temp.uid(p_from), pg_temp.id(p_thread),
         jsonb_build_object('dm_thread_id', pg_temp.id(p_thread), 'since', min(q.created_at)),
         min(q.created_at) + interval '5 minutes'
  from public.push_queue q
  where q.profile_id = pg_temp.uid(p_who) and q.dm_thread_id = pg_temp.id(p_thread)
    and q.kind = 'dm_message';
$$;
-- The two later messages and their pushes came after the first, inside
-- its 5 minutes.
update public.push_queue set created_at = now() - interval '90 seconds'
where profile_id = pg_temp.uid('e2') and kind = 'dm_message'
  and data ->> 'message_id' in (pg_temp.id('b002')::text, pg_temp.id('b003')::text);
update public.dm_messages set created_at = now() - interval '90 seconds'
where id in (pg_temp.id('b002'), pg_temp.id('b003'));
select pg_temp.old_follow_up('e2', 'e1', 'a001');
select is((select count(*) from public.claim_push((pg_temp.follow_up('e2')).id)), 0::bigint,
  'an old follow-up isn''t sent before its time');
update public.push_queue set not_before = now() - interval '1 second'
where id = (pg_temp.follow_up('e2')).id;
select is((select data ->> 'count' from public.claim_push((pg_temp.follow_up('e2')).id)), '2',
  'at its time, unread: one push for the 2 new messages');
select is((pg_temp.follow_up('e2')).message_text, null, 'never with the text');
select is(array(select id from public.retry_push_queue()
                where id = (pg_temp.follow_up('e2')).id), '{}'::bigint[],
  'claimed: the minute''s retry leaves it');

-- An old follow-up: read in time ---------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select public.start_dm(pg_temp.id('a002'), pg_temp.uid('e3'), pg_temp.id('b011'), 'Gate at 7?');
reset role;
select pg_temp.two_minutes_ago('a002');
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_dm(pg_temp.id('b012'), pg_temp.id('a002'), 'Or 8?');
reset role;
delete from public.push_queue
where profile_id = pg_temp.uid('e3') and data ->> 'message_id' = pg_temp.id('b012')::text;
select pg_temp.old_follow_up('e3', 'e1', 'a002');
update public.dm_messages set created_at = now() - interval '90 seconds' where id = pg_temp.id('b012');
update public.dm_members set last_read_at = now() - interval '60 seconds'
where thread_id = pg_temp.id('a002') and profile_id = pg_temp.uid('e3');
update public.push_queue set not_before = now() - interval '1 second'
where id = (pg_temp.follow_up('e3')).id;
select is((select count(*) from public.claim_push((pg_temp.follow_up('e3')).id)), 0::bigint,
  'read before its time: no follow-up push');
select ok((pg_temp.follow_up('e3')).sent_at is not null, 'and it is closed');

-- Muted ------------------------------------------------------------------------------------------

update public.dm_members set muted = true
where thread_id = pg_temp.id('a002') and profile_id = pg_temp.uid('e3');
delete from public.push_queue where profile_id = pg_temp.uid('e3');
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_dm(pg_temp.id('b013'), pg_temp.id('a002'), 'Muted?');
select public.send_dm(pg_temp.id('b014'), pg_temp.id('a002'), 'Still muted?');
reset role;
select is(pg_temp.q('e3', 'dm_message') + pg_temp.q('e3', 'dm_follow_up'), 0::bigint,
  'a muted conversation gets neither');

-- An old follow-up after a newer push (review 88 S1) ------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select public.start_dm(pg_temp.id('a003'), pg_temp.uid('e3'), pg_temp.id('b021'), 'Rebar is here');
reset role;
select pg_temp.two_minutes_ago('a003');
select pg_temp.old_follow_up('e3', 'e2', 'a003');
-- Now it is minute 5:20: the follow-up is due, and a newer message has
-- its own push.
update public.push_queue set created_at = created_at - interval '3 minutes 20 seconds',
                             not_before = not_before - interval '3 minutes 20 seconds'
where dm_thread_id = pg_temp.id('a003');
update public.dm_messages set created_at = created_at - interval '3 minutes 20 seconds'
where thread_id = pg_temp.id('a003');
select pg_temp.as_user('e2');
set local role authenticated;
select public.send_dm(pg_temp.id('b023'), pg_temp.id('a003'), 'Near gate 2');
reset role;
select is((select count(*) from public.claim_push(
             (select id from public.push_queue
              where dm_thread_id = pg_temp.id('a003') and kind = 'dm_follow_up'))), 0::bigint,
  'an old follow-up after a newer push is not sent');
select is((select error from public.push_queue
           where dm_thread_id = pg_temp.id('a003') and kind = 'dm_follow_up'), 'superseded',
  'it is closed as superseded');
select is((select data ->> 'message_id' from public.claim_push(
             (select id from public.push_queue
              where dm_thread_id = pg_temp.id('a003') and kind = 'dm_message'
              order by created_at desc limit 1))), pg_temp.id('b023')::text,
  'the newer message''s push goes');

-- Activity: a daybook post's rows -------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select public.create_space_post(pg_temp.id('c001'), current_setting('test.space')::uuid,
                                'announcement', 'Friday is a half day');
-- activity_rows is internal: read here as the owner, for Rakesh.
reset role;
select pg_temp.as_user('e2');
select is((select work_item_title from public.activity_rows() where kind = 'announcement_new'),
  'Friday is a half day', 'an announcement''s row has its title');
select is((select space_post_id from public.activity_rows() where kind = 'announcement_new'),
  pg_temp.id('c001'), 'and opens its card');
update public.space_posts set deleted_at = now() where id = pg_temp.id('c001');
select is((select count(*) from public.activity_rows() where kind = 'announcement_new'), 0::bigint,
  'a deleted post''s row leaves');

select * from finish();
rollback;
