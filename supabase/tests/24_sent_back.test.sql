-- Migration 24: a send-back on the daybook, with the owner's paper clip.
-- Since migration 28 (daybook_page dropped) these are read from the card:
-- the send-back is a line of its history, and the one clip is the card's
-- needs_me. Run with: supabase test db
--
-- Omar (e1) made the Space and is its admin (Lead). Rakesh (e2) is Crew,
-- Vera (e4) a Viewer, Tariq (e6) Crew in the MEP Team, Lina (e7) Crew who
-- leaves. Eve (e5) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(36);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000024' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@sentback24.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e4'), ('e5'), ('e6'), ('e7')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e4', 'Vera', 'Lane'),
             ('e5', 'Eve', 'Out'), ('e6', 'Tariq', 'Aziz'), ('e7', 'Lina', 'Khalil')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000024' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000024' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000024' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000024' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
create function pg_temp.card(p_item text) returns jsonb language sql as $$
  select d.card from public.daybook_cards(pg_temp.sp(), null, 100) d where d.id = pg_temp.item(p_item);
$$;
-- The card's one clip for the signed-in person.
create function pg_temp.needs(p_item text) returns text language sql as $$
  select pg_temp.card(p_item) ->> 'needs_me';
$$;
-- The n-th event of a kind on a work item, oldest first.
create function pg_temp.ev(p_item text, p_kind text, p_n integer) returns uuid language sql as $$
  select e.id from public.work_item_events e
  where e.work_item_id = pg_temp.item(p_item) and e.kind = p_kind
  order by e.created_at, e.id offset p_n - 1 limit 1;
$$;
-- That event's line in the card's history.
create function pg_temp.line(p_item text, p_kind text, p_n integer) returns jsonb language sql as $$
  select h from jsonb_array_elements(pg_temp.card(p_item) -> 'history') h
  where h ->> 'id' = pg_temp.ev(p_item, p_kind, p_n)::text;
$$;
-- Run as the database owner: the events just made move to a time of
-- their own (a test runs in one transaction, so now() never moves).
create function pg_temp.stamp(p_minutes_ago integer) returns void language sql as $$
  alter table public.work_item_events disable trigger work_item_events_append_only;
  update public.work_item_events set created_at = now() - make_interval(mins => p_minutes_ago)
  where created_at = now();
  alter table public.work_item_events enable trigger work_item_events_append_only;
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Sent back site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e4', 'viewer'), ('e6', 'crew'), ('e7', 'crew')) x(id, pass);
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('e6')])::text, true);
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Sleeves at grid C7', pg_temp.uid('e2'),
                    p_id => pg_temp.item('c001'))$$, 'Omar raises a work item for Rakesh');
reset role;
select pg_temp.stamp(90);

-- Never signed: the owner is asked to sign ----------------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.needs('c001'), 'to_sign', 'never signed, the owner''s clip is on the card');
select public.sign_done(pg_temp.item('c001'), 'All six fixed.');
reset role;
select pg_temp.stamp(60);

-- Sent back: a line of its own, and the owner's clip -------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.send_back(pg_temp.item('c001'), 'not_finished', 'Two sleeves are loose.')$$,
  'Omar sends it back');
reset role;
select pg_temp.stamp(50);
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.line('c001', 'sent_back', 1) ->> 'kind', 'sent_back',
  'a send-back is a line of the work item''s card');
select is(pg_temp.line('c001', 'sent_back', 1) ->> 'reason', 'not_finished',
  'with the reason');
select is(pg_temp.line('c001', 'sent_back', 1) ->> 'note', 'Two sleeves are loose.',
  'the note');
select is(pg_temp.line('c001', 'sent_back', 1) ->> 'by_name', 'Omar Haddad',
  'who sent it back');
select is((pg_temp.line('c001', 'sent_back', 1) ->> 'at')::timestamptz,
  now() - interval '50 minutes', 'and when');
select is(pg_temp.needs('c001'), 'to_sign',
  'the owner is asked to sign again');
select is(pg_temp.card('c001') -> 'history' -> 0 ->> 'id', pg_temp.ev('c001', 'sent_back', 1)::text,
  'the send-back is the newest line');
select is(pg_temp.card('c001') -> 'proof' ->> 'event_id', pg_temp.ev('c001', 'done', 1)::text,
  'the proof is still the sign-off it answered');
select is(pg_temp.card('c001') -> 'proof' -> 'outcome' ->> 'kind', 'sent_back',
  'which is stamped SENT BACK');
select pg_temp.as_user('e1');
select is(pg_temp.needs('c001'), null,
  'the one who sent it back has no clip on it');
select pg_temp.as_user('e4');
select ok(pg_temp.line('c001', 'sent_back', 1) is not null and pg_temp.needs('c001') is null,
  'a Viewer sees it, with no clip');

-- Signed again: the clip moves to the checker -------------------------------------------------

select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('c001'), 'Tightened.');
reset role;
select pg_temp.stamp(40);
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.needs('c001'), null,
  'signed again, the owner loses the clip');
select is(pg_temp.card('c001') -> 'proof' ->> 'event_id', pg_temp.ev('c001', 'done', 2)::text,
  'and the proof is the new sign-off');
select pg_temp.as_user('e1');
select is(pg_temp.needs('c001'), 'to_check',
  'the checker''s clip is on the card');

-- Sent back twice: one clip ---------------------------------------------------------------------

select public.send_back(pg_temp.item('c001'), 'photo_missing');
reset role;
select pg_temp.stamp(30);
select pg_temp.as_user('e2');
set local role authenticated;
select ok(pg_temp.line('c001', 'sent_back', 2) ->> 'reason' = 'photo_missing'
          and pg_temp.line('c001', 'sent_back', 1) is not null,
  'both send-backs are in the history');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100) d
           where d.card ->> 'needs_me' is not null and d.id = pg_temp.item('c001')),
  1::bigint, 'one clip for the owner on the whole item');

-- A Team's send-back stays in the Team ---------------------------------------------------------

select pg_temp.as_user('e6');
select lives_ok($$select public.create_work_item(pg_temp.sp(), 'MEP risers', pg_temp.uid('e6'),
                    p_team => pg_temp.team(), p_id => pg_temp.item('c002'))$$, 'a Team work item');
reset role;
select pg_temp.stamp(320);
select pg_temp.as_user('e6');
set local role authenticated;
select public.sign_done(pg_temp.item('c002'), 'Risers in.');
reset role;
select pg_temp.stamp(310);
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_back(pg_temp.item('c002'), 'not_as_asked', 'Wrong level.');
reset role;
select pg_temp.stamp(300);
select pg_temp.as_user('e6');
set local role authenticated;
select ok(pg_temp.line('c002', 'sent_back', 1) is not null and pg_temp.needs('c002') = 'to_sign',
  'the Team owner gets the send-back, with the clip');
select pg_temp.as_user('e2');
select ok(pg_temp.card('c002') is null,
  'someone outside the Team never gets it');
select ok(not exists (select 1 from public.daybook_month(pg_temp.sp(), current_date - 30, current_date + 30,
                                                         now() - interval '30 days', now() + interval '30 days') m
                      where m.kind = 'posts'
                        and m.at = date_bin('15 minutes', now() - interval '300 minutes',
                                            timestamptz '2000-01-01 00:00+00')),
  'nor a month dot for it');
select pg_temp.as_user('e1');
select ok(exists (select 1 from public.daybook_month(pg_temp.sp(), current_date - 30, current_date + 30,
                                                     now() - interval '30 days', now() + interval '30 days') m
                  where m.kind = 'posts'
                    and m.at = date_bin('15 minutes', now() - interval '300 minutes',
                                        timestamptz '2000-01-01 00:00+00')),
  'a send-back lights its quarter hour');
select pg_temp.as_user('e5');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100)), 0::bigint,
  'someone outside the Space gets no card');

-- When the owner can't be asked ---------------------------------------------------------------

-- Sent back, then the owner left: the author is asked to give it to
-- someone else (only the owner can sign).
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Door closers', pg_temp.uid('e7'), p_id => pg_temp.item('c003'));
reset role;
select pg_temp.stamp(200);
select pg_temp.as_user('e7');
set local role authenticated;
select public.sign_done(pg_temp.item('c003'), 'Fitted.');
reset role;
select pg_temp.stamp(190);
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_back(pg_temp.item('c003'), 'not_finished');
reset role;
select pg_temp.stamp(180);
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e7');
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.needs('c003'), 'give_to',
  'the owner left: the author is asked to give it to someone else');

-- Sent back, then given to someone else: the new owner is asked to sign.
select public.create_work_item(pg_temp.sp(), 'Fire stopping', pg_temp.uid('e2'), p_id => pg_temp.item('c004'));
reset role;
select pg_temp.stamp(170);
select pg_temp.as_user('e2');
set local role authenticated;
select public.sign_done(pg_temp.item('c004'), 'Sealed.');
reset role;
select pg_temp.stamp(160);
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_back(pg_temp.item('c004'), 'photo_missing');
reset role;
select pg_temp.stamp(150);
select pg_temp.as_user('e1');
set local role authenticated;
select public.reassign_work_item(pg_temp.item('c004'), pg_temp.uid('e6'));
reset role;
select pg_temp.stamp(140);
select pg_temp.as_user('e6');
set local role authenticated;
select is(pg_temp.needs('c004'), 'to_sign',
  'given to someone else after a send-back: the new owner is asked to sign');
select pg_temp.as_user('e2');
select is(pg_temp.needs('c004'), null,
  'the old owner has no clip');

-- Sent back, then cancelled: no clip; the record stays.
select pg_temp.as_user('e1');
select public.create_work_item(pg_temp.sp(), 'Skirting', pg_temp.uid('e2'), p_id => pg_temp.item('c005'));
reset role;
select pg_temp.stamp(130);
select pg_temp.as_user('e2');
set local role authenticated;
select public.sign_done(pg_temp.item('c005'), 'Done.');
reset role;
select pg_temp.stamp(120);
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_back(pg_temp.item('c005'), 'not_as_asked', 'Wrong colour.');
reset role;
select pg_temp.stamp(110);
select pg_temp.as_user('e1');
set local role authenticated;
select public.cancel_space_post(pg_temp.item('c005'));
select pg_temp.as_user('e2');
select ok(pg_temp.line('c005', 'sent_back', 1) is not null and pg_temp.needs('c005') is null,
  'cancelled after a send-back: the send-back stays as the record, with no clip');
reset role;
update public.space_posts set deleted_at = now() where id = pg_temp.item('c005');
select pg_temp.as_user('e2');
set local role authenticated;
select ok(pg_temp.card('c005') is null
          and not exists (select 1 from public.post_history(pg_temp.item('c005'))),
  'a deleted item''s send-backs go with it');

-- Sent back, then a work item put under it: a target (its author owns it)
-- asks nobody to sign.
select pg_temp.as_user('e2');
select public.create_work_item(pg_temp.sp(), 'Level 4 ceilings', pg_temp.uid('e2'), p_id => pg_temp.item('c006'));
reset role;
select pg_temp.stamp(100);
select pg_temp.as_user('e2');
set local role authenticated;
select public.sign_done(pg_temp.item('c006'), 'Done.');
reset role;
select pg_temp.stamp(99);
select pg_temp.as_user('e1');
set local role authenticated;
select public.send_back(pg_temp.item('c006'), 'not_finished');
reset role;
select pg_temp.stamp(98);
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.needs('c006'), 'to_sign', 'the owner''s clip, before');
select public.create_work_item(pg_temp.sp(), 'Bay 1', pg_temp.uid('e2'),
                               p_parent => pg_temp.item('c006'), p_id => pg_temp.item('c007'));
reset role;
select pg_temp.stamp(97);
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.needs('c006'), null,
  'once work items hang under it, nobody is asked to sign it');

-- History paging covers send-backs -------------------------------------------------------------

reset role;
-- Every line of a card, read through post_history one at a time.
create function pg_temp.walk(p_item text) returns bigint language plpgsql as $$
declare
  v_at timestamptz;
  v_id uuid;
  v_seen uuid[] := '{}';
  v_row record;
begin
  loop
    select h.at, h.id into v_row from public.post_history(pg_temp.item(p_item), v_at, v_id, 1) h;
    exit when v_row.id is null;
    v_seen := v_seen || v_row.id;
    v_at := v_row.at;
    v_id := v_row.id;
  end loop;
  return (select count(distinct x) from unnest(v_seen) x);
end;
$$;
-- A sign-off, an update and a send-back at the same moment.
select pg_temp.as_user('e2');
set local role authenticated;
select public.sign_done(pg_temp.item('c001'), 'Photo added.');
select public.add_comment(pg_temp.item('c001'), 'Area cleaned.');
select pg_temp.as_user('e1');
select public.send_back(pg_temp.item('c001'), 'other', 'Label the sleeves.');
select is(pg_temp.walk('c001'), jsonb_array_length(pg_temp.card('c001') -> 'history')::bigint,
  'one at a time, the cursor reaches every line once, send-backs included');
select ok((select count(distinct h ->> 'kind')
           from jsonb_array_elements(pg_temp.card('c001') -> 'history') h
           where (h ->> 'at')::timestamptz = now()) = 3,
  'with a sign-off, an update and a send-back made at the same moment');

-- Someone who left, and a deleted Space, get nothing.
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e4');
select pg_temp.as_user('e4');
set local role authenticated;
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100)), 0::bigint,
  'someone who left gets no card');
reset role;
update public.spaces set deleted_at = now() where id = pg_temp.sp();
select pg_temp.as_user('e1');
set local role authenticated;
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100)), 0::bigint,
  'a deleted Space has no cards, even for its admin');

select * from finish();
rollback;
