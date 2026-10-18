-- Migration 25: fixes from the founder's slice 1 test. Run with: supabase test db
--
-- Omar (f1) posts. Rakesh (f2) comments, Sami (f3) answers Rakesh, Lina
-- (f4) answers Sami, Mona (f5) answers Lina. All in Kuwait.

begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000025' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@fixes25.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('f1'), ('f2'), ('f3'), ('f4'), ('f5')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('f1', 'Omar', 'Haddad'), ('f2', 'Rakesh', 'Nair'), ('f3', 'Sami', 'Ali'),
             ('f4', 'Lina', 'Khalil'), ('f5', 'Mona', 'Adel')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000025' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000025' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000025' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000025' || p)::uuid;
$$;
-- Run as the database owner: post_reply notifications someone got for a reply.
create function pg_temp.told(p_who text, p_reply text) returns bigint language sql as $$
  select count(*) from public.notifications
  where profile_id = pg_temp.uid(p_who) and kind = 'post_reply' and reply_id = pg_temp.id(p_reply);
$$;
create function pg_temp.reply(p_who text, p_id text, p_to text, p_body text) returns void
language plpgsql as $$
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  perform public.add_reply(pg_temp.id(p_id), pg_temp.id('a001'),
                           case when p_to is null then null else pg_temp.id(p_to) end, p_body);
  reset role;
end;
$$;

-- Answers to answers (F2) ---------------------------------------------------------------------

select pg_temp.as_user('f1');
set local role authenticated;
select lives_ok($$select public.create_post(pg_temp.id('a001'), 'Slab poured on level 3.', 'en')$$,
  'Omar posts');
reset role;
select pg_temp.reply('f2', 'b001', null, 'Well done.');
select pg_temp.reply('f3', 'b002', 'b001', 'Agreed, Rakesh.');
select pg_temp.reply('f4', 'b003', 'b002', 'Sami, which pour?');
select pg_temp.reply('f5', 'b004', 'b003', 'The morning one, Lina.');

select is((select reply_to from public.post_replies where id = pg_temp.id('b002')), pg_temp.id('b001'),
  'an answer to a comment sits under it');
select is((select reply_to_person from public.post_replies where id = pg_temp.id('b002')), pg_temp.uid('f2'),
  'and keeps the person answered');
select is((select reply_to from public.post_replies where id = pg_temp.id('b003')), pg_temp.id('b001'),
  'an answer to an answer sits under the same comment');
select is((select reply_to_person from public.post_replies where id = pg_temp.id('b003')), pg_temp.uid('f3'),
  'and keeps the person it answered, not the comment''s author');
select is((select reply_to from public.post_replies where id = pg_temp.id('b004')), pg_temp.id('b001'),
  'three levels deep, still under the same comment');
select is((select reply_to_person from public.post_replies where id = pg_temp.id('b004')), pg_temp.uid('f4'),
  'answering the right person');

select is(pg_temp.told('f3', 'b003'), 1::bigint, 'the person answered is told');
select is(pg_temp.told('f2', 'b003'), 0::bigint, 'the comment''s author isn''t, for an answer to someone else');
select is(pg_temp.told('f1', 'b003'), 1::bigint, 'the post''s author is told, as before');
select is(pg_temp.told('f4', 'b004'), 1::bigint, 'and so on down the thread');

-- Answering yourself tells nobody twice, and not you.
select pg_temp.reply('f5', 'b005', 'b004', 'And it set well.');
select is(pg_temp.told('f5', 'b005'), 0::bigint, 'nobody is told about their own answer');
select is((select reply_to_person from public.post_replies where id = pg_temp.id('b005')), pg_temp.uid('f5'),
  'even then the person answered is kept');

-- A deleted reply: its answers stay put; it can't be answered.
select pg_temp.as_user('f3');
set local role authenticated;
select lives_ok($$select public.delete_reply(pg_temp.id('b002'))$$, 'Sami deletes his answer');
reset role;
select ok((select reply_to = pg_temp.id('b001') and deleted_at is null
           from public.post_replies where id = pg_temp.id('b003')),
  'the answers to it stay, under the same comment');
select pg_temp.as_user('f4');
set local role authenticated;
select throws_ok($$select public.add_reply(gen_random_uuid(), pg_temp.id('a001'), pg_temp.id('b002'), 'x')$$,
  '22023', null, 'a deleted reply can''t be answered');
select throws_ok($$select public.add_reply(gen_random_uuid(), pg_temp.id('a001'), gen_random_uuid(), 'x')$$,
  '22023', null, 'nor a reply that doesn''t exist');
-- A retry with the same id is the same reply.
select is(public.add_reply(pg_temp.id('b003'), pg_temp.id('a001'), pg_temp.id('b002'), 'Sami, which pour?'),
  pg_temp.id('b003'), 'a retry with the same id returns the same reply');
reset role;
select is((select count(*) from public.post_replies where author_id = pg_temp.uid('f4')), 1::bigint,
  'and adds nothing');

-- Push tokens nobody has seen for 30 days (F9) ---------------------------------------------

insert into public.push_tokens (token, profile_id, platform, locale, updated_at) values
  ('fcm-token-old-0123456789abcdef', pg_temp.uid('f1'), 'android', 'en', now() - interval '31 days'),
  ('fcm-token-new-0123456789abcdef', pg_temp.uid('f2'), 'android', 'en', now() - interval '2 days');
select pg_temp.as_user('f1');
set local role authenticated;
select throws_ok($$select public.drop_stale_push_tokens()$$, '42501', null,
  'the app can''t run the cleanup');
reset role;
set local role service_role;
select is(public.drop_stale_push_tokens(), 1, 'the cleanup drops a token not seen for 30 days');
select throws_ok($$select public.drop_stale_push_tokens(interval '1 day')$$, '22023', null,
  'and never one seen this week');
reset role;
select ok(not exists (select 1 from public.push_tokens where token = 'fcm-token-old-0123456789abcdef')
          and exists (select 1 from public.push_tokens where token = 'fcm-token-new-0123456789abcdef'),
  'the recent token stays');
-- Registering again is the "seen" time.
update public.push_tokens set updated_at = now() - interval '29 days' where token = 'fcm-token-new-0123456789abcdef';
select pg_temp.as_user('f2');
set local role authenticated;
select public.register_push_token('fcm-token-new-0123456789abcdef', 'android', 'en');
reset role;
select ok((select updated_at > now() - interval '1 minute' from public.push_tokens
           where token = 'fcm-token-new-0123456789abcdef'),
  'each start of the app refreshes when the token was last seen');

select * from finish();
rollback;
