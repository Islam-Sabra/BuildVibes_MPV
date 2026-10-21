-- Migration 33: a new date when a work item is sent back (review 50 F62).
-- Run with: supabase test db
--
-- Omar (e1) made the Space and is its admin (Lead). Rakesh (e2) is Crew and
-- owns the items, Vera (e4) a Viewer. Eve (e5) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000033' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@dueback33.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e4'), ('e5')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e4', 'Vera', 'Lane'),
             ('e5', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000033' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000033' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000033' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000033' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.card(p_item text) returns jsonb language sql as $$
  select d.card from public.daybook_cards(pg_temp.sp(), null, 100) d where d.id = pg_temp.item(p_item);
$$;
-- The newest send-back's line on the card.
create function pg_temp.back_line(p_item text) returns jsonb language sql as $$
  select h from jsonb_array_elements(pg_temp.card(p_item) -> 'history') h
  where h ->> 'kind' = 'sent_back' order by h ->> 'at' desc limit 1;
$$;
-- Read as the database owner.
create function pg_temp.due(p_item text) returns text language sql as $$
  select coalesce(p.due_date::text, '-') || '|' || coalesce(p.due_at::text, '-') || '|'
         || coalesce(w.due_date::text, '-')
  from public.space_posts p join public.work_items w on w.id = p.id
  where p.id = pg_temp.item(p_item);
$$;

-- Setup: three items for Rakesh, due Tuesday, each signed as done.
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Due back site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e4', 'viewer')) x(id, pass);
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Sleeves at grid C7', pg_temp.uid('e2'),
                               current_date - 1, p_id => pg_temp.item('c001'));
select public.create_work_item(pg_temp.sp(), 'Paint room 3', pg_temp.uid('e2'),
                               current_date - 1, p_id => pg_temp.item('c002'));
select public.create_work_item(pg_temp.sp(), 'Fix socket room 4', pg_temp.uid('e2'),
                               current_date - 1, p_id => pg_temp.item('c003'));
select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item(x), 'Done.') from unnest(array['c001', 'c002', 'c003']) x;
reset role;

-- An earlier build: three arguments, the due stays -------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.send_back(pg_temp.item('c001'), 'not_finished', 'Two loose.')$$,
  'a send-back without a choice still works (earlier builds)');
reset role;
select is(pg_temp.due('c001'), (current_date - 1)::text || '|-|' || (current_date - 1)::text,
  'and the due stays as it was');
select is((select new_due from public.work_item_events
           where work_item_id = pg_temp.item('c001') and kind = 'sent_back'), null,
  'the event records no new date');
select pg_temp.as_user('e2');
set local role authenticated;
select ok(not (pg_temp.back_line('c001') ? 'new_due'), 'its line carries no new_due');
reset role;

-- A new date ------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.send_back(pg_temp.item('c002'), 'photo_missing', null,
                                          true, current_date + 2)$$,
  'Omar sends it back with a new date');
reset role;
select is(pg_temp.due('c002'), (current_date + 2)::text || '|-|' || (current_date + 2)::text,
  'the post and the work item take the new date, with no time');
select is((select w.status from public.work_items w where w.id = pg_temp.item('c002')), 'open',
  'and the item is open again');
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.back_line('c002') -> 'new_due' ->> 'date', (current_date + 2)::text,
  'the owner''s card line says the new date');
reset role;
select pg_temp.as_user('e4');
set local role authenticated;
select is(pg_temp.back_line('c002') -> 'new_due' ->> 'date', (current_date + 2)::text,
  'a Viewer sees it too');
reset role;

-- A new date and time ---------------------------------------------------------------------------

select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('c002'), 'Photo added.');
select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok(format($$select public.send_back(pg_temp.item('c002'), 'not_as_asked', null,
                                                 true, %L::date, %L::timestamptz)$$,
                       current_date + 3, ((current_date + 3)::timestamp + interval '14 hours') at time zone 'UTC'),
  'a new date with a time');
reset role;
select is(split_part(pg_temp.due('c002'), '|', 1), (current_date + 3)::text, 'the date');
select isnt(split_part(pg_temp.due('c002'), '|', 2), '-', 'and the time are set');
select pg_temp.as_user('e2');
set local role authenticated;
-- Both send-backs share one now() in a test, so find this one by its date.
select ok(exists (select 1 from jsonb_array_elements(pg_temp.card('c002') -> 'history') h
                  where h -> 'new_due' ->> 'date' = (current_date + 3)::text
                    and h -> 'new_due' ? 'at'),
  'the line carries the time');
reset role;

-- No new date -----------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.send_back(pg_temp.item('c003'), 'other', 'Wait for the cable.', true)$$,
  'Omar sends it back with no new date');
reset role;
select is(pg_temp.due('c003'), '-|-|-', 'the old date is gone, from the post and the item');
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.back_line('c003') -> 'new_due', '{}'::jsonb,
  'the line says no new date ({} after strip_nulls)');

-- Refused ---------------------------------------------------------------------------------------

select public.sign_done(pg_temp.item('c003'), 'Cable in.');
select throws_ok($$select public.send_back(pg_temp.item('c003'), 'not_finished', null, true, current_date)$$,
  '42501', 'not allowed', 'the owner can''t send back, so can''t set the date');
reset role;
select pg_temp.as_user('e5');
set local role authenticated;
select throws_ok($$select public.send_back(pg_temp.item('c003'), 'not_finished', null, true, current_date)$$,
  '42501', 'not allowed', 'nor can someone outside the Space');
reset role;
select pg_temp.as_user('e1');
set local role authenticated;
select throws_ok($$select public.send_back(pg_temp.item('c003'), 'not_finished', null, true, null, now())$$,
  '22023', 'a due time needs its day', 'a time with no day is refused');
select throws_ok(format($$select public.send_back(pg_temp.item('c003'), 'not_finished', null, true, %L::date, %L::timestamptz)$$,
                        current_date + 1, ((current_date + 5)::timestamp) at time zone 'UTC'),
  '22023', 'a due time on its due day', 'a time on another day is refused');
select throws_ok($$select public.send_back(pg_temp.item('c003'), 'not_finished', null, false, current_date)$$,
  '22023', 'say that a new date was chosen', 'a date without the choice is refused');
select is((select w.status from public.work_items w where w.id = pg_temp.item('c003')), 'done',
  'nothing changed after the refusals');
select throws_ok($$update public.work_item_events set new_due = '{}' where work_item_id = pg_temp.item('c002')$$,
  '42501', null, 'a signed-in person can''t rewrite an event''s date');
reset role;

-- The record ------------------------------------------------------------------------------------

select throws_ok($$insert into public.work_item_events (work_item_id, actor_id, kind, note, space_id, new_due)
                   values (pg_temp.item('c003'), pg_temp.uid('e1'), 'comment', 'x', pg_temp.sp(), '{}')$$,
  '23514', null, 'only a send-back carries a new date');

select * from finish();
rollback;
