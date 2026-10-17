-- Migration 24: a send-back is its own daybook entry, with the owner's
-- paper clip. Run with: supabase test db
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
create function pg_temp.entry(p_kind text, p_id uuid) returns jsonb language sql as $$
  select d.entry from public.daybook_page(pg_temp.sp(), null, 100) d
  where d.kind = p_kind and d.id = p_id;
$$;
-- The n-th event of a kind on a work item, oldest first.
create function pg_temp.ev(p_item text, p_kind text, p_n integer) returns uuid language sql as $$
  select e.id from public.work_item_events e
  where e.work_item_id = pg_temp.item(p_item) and e.kind = p_kind
  order by e.created_at, e.id offset p_n - 1 limit 1;
$$;
-- Run as the database owner: the events just made move to a time of
-- their own (a test runs in one transaction, so now() never moves).
create function pg_temp.stamp(p_minutes_ago integer) returns void language sql as $$
  alter table public.work_item_events disable trigger work_item_events_append_only;
  update public.work_item_events set created_at = now() - make_interval(mins => p_minutes_ago)
  where created_at = now();
  alter table public.work_item_events enable trigger work_item_events_append_only;
$$;
create function pg_temp.clip(p_kind text, p_id uuid) returns boolean language sql as $$
  select (pg_temp.entry(p_kind, p_id) ->> 'needs_me')::boolean;
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

-- Never signed: the clip is on the slip --------------------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select ok(pg_temp.clip('post', pg_temp.item('c001')), 'never signed, the owner''s clip is on the slip');
select public.sign_done(pg_temp.item('c001'), 'All six fixed.');
reset role;
select pg_temp.stamp(60);

-- Sent back: its own entry, with the owner's clip ----------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select lives_ok($$select public.send_back(pg_temp.item('c001'), 'not_finished', 'Two sleeves are loose.')$$,
  'Omar sends it back');
reset role;
select pg_temp.stamp(50);
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.entry('sent_back', pg_temp.ev('c001', 'sent_back', 1)) ->> 'title', 'Sleeves at grid C7',
  'a send-back is its own entry, quoting the work item');
select is(pg_temp.entry('sent_back', pg_temp.ev('c001', 'sent_back', 1)) ->> 'reason', 'not_finished',
  'with the reason');
select is(pg_temp.entry('sent_back', pg_temp.ev('c001', 'sent_back', 1)) ->> 'note', 'Two sleeves are loose.',
  'the note');
select is(pg_temp.entry('sent_back', pg_temp.ev('c001', 'sent_back', 1)) ->> 'actor_name', 'Omar Haddad',
  'who sent it back');
select is((pg_temp.entry('sent_back', pg_temp.ev('c001', 'sent_back', 1)) ->> 'at')::timestamptz,
  now() - interval '50 minutes', 'and when');
select ok(pg_temp.clip('sent_back', pg_temp.ev('c001', 'sent_back', 1)),
  'the owner''s clip is on the send-back');
select ok(not pg_temp.clip('post', pg_temp.item('c001')),
  'not on the work item slip: never two');
select ok(not pg_temp.clip('sign_off', pg_temp.ev('c001', 'done', 1)),
  'nor on the sign-off it answered');
select is(pg_temp.entry('sign_off', pg_temp.ev('c001', 'done', 1)) -> 'outcome' ->> 'kind', 'sent_back',
  'which is stamped SENT BACK');
select pg_temp.as_user('e1');
select ok(not pg_temp.clip('sent_back', pg_temp.ev('c001', 'sent_back', 1)),
  'the one who sent it back has no clip on it');
select pg_temp.as_user('e4');
select ok(pg_temp.entry('sent_back', pg_temp.ev('c001', 'sent_back', 1)) is not null
          and not pg_temp.clip('sent_back', pg_temp.ev('c001', 'sent_back', 1)),
  'a Viewer sees it, with no clip');

-- Signed again: the clip moves to the new sign-off ---------------------------------------------

select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('c001'), 'Tightened.');
reset role;
select pg_temp.stamp(40);
select pg_temp.as_user('e2');
set local role authenticated;
select ok(not pg_temp.clip('sent_back', pg_temp.ev('c001', 'sent_back', 1)),
  'signed again, the send-back loses the owner''s clip');
select ok(not pg_temp.clip('post', pg_temp.item('c001')), 'and the slip has none');
select pg_temp.as_user('e1');
select ok(pg_temp.clip('sign_off', pg_temp.ev('c001', 'done', 2)),
  'the checker''s clip is on the new sign-off');

-- Sent back twice: only the latest carries the clip --------------------------------------------

select public.send_back(pg_temp.item('c001'), 'photo_missing');
reset role;
select pg_temp.stamp(30);
select pg_temp.as_user('e2');
set local role authenticated;
select ok(pg_temp.clip('sent_back', pg_temp.ev('c001', 'sent_back', 2))
          and not pg_temp.clip('sent_back', pg_temp.ev('c001', 'sent_back', 1)),
  'only the latest send-back carries the owner''s clip');
select is((select count(*) from public.daybook_page(pg_temp.sp(), null, 100) d
           where (d.entry ->> 'needs_me')::boolean
             and coalesce(d.entry ->> 'post_id', d.entry ->> 'id') = pg_temp.item('c001')::text),
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
select ok(pg_temp.clip('sent_back', pg_temp.ev('c002', 'sent_back', 1)),
  'the Team owner gets the send-back, with the clip');
select pg_temp.as_user('e2');
select ok(pg_temp.entry('sent_back', pg_temp.ev('c002', 'sent_back', 1)) is null,
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
select is((select count(*) from public.daybook_page(pg_temp.sp(), null, 100)), 0::bigint,
  'someone outside the Space gets no entry');

-- When the clip stays on the slip ---------------------------------------------------------------

-- Sent back, then the owner left: the author's clip stays on the slip, next
-- to Give to someone else (only the owner can sign).
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
select ok(pg_temp.clip('post', pg_temp.item('c003'))
          and not pg_temp.clip('sent_back', pg_temp.ev('c003', 'sent_back', 1)),
  'the owner left: the author''s clip is on the slip, not the send-back');

-- Sent back, then given to someone else: the new owner's clip is on the slip.
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
select ok(pg_temp.clip('post', pg_temp.item('c004'))
          and not pg_temp.clip('sent_back', pg_temp.ev('c004', 'sent_back', 1)),
  'given to someone else after a send-back: the new owner''s clip is on the slip');
select pg_temp.as_user('e2');
select ok(not pg_temp.clip('post', pg_temp.item('c004'))
          and not pg_temp.clip('sent_back', pg_temp.ev('c004', 'sent_back', 1)),
  'the old owner has none');

-- Sent back, then cancelled: no clip anywhere; the record stays.
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
select ok(pg_temp.entry('sent_back', pg_temp.ev('c005', 'sent_back', 1)) is not null
          and not pg_temp.clip('sent_back', pg_temp.ev('c005', 'sent_back', 1))
          and not pg_temp.clip('post', pg_temp.item('c005')),
  'cancelled after a send-back: the send-back stays as the record, with no clip');
reset role;
update public.space_posts set deleted_at = now() where id = pg_temp.item('c005');
select pg_temp.as_user('e2');
set local role authenticated;
select ok(pg_temp.entry('sent_back', pg_temp.ev('c005', 'sent_back', 1)) is null,
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
select ok(pg_temp.clip('sent_back', pg_temp.ev('c006', 'sent_back', 1)), 'the owner''s clip, before');
select public.create_work_item(pg_temp.sp(), 'Bay 1', pg_temp.uid('e2'),
                               p_parent => pg_temp.item('c006'), p_id => pg_temp.item('c007'));
reset role;
select pg_temp.stamp(97);
select pg_temp.as_user('e2');
set local role authenticated;
select ok(not pg_temp.clip('sent_back', pg_temp.ev('c006', 'sent_back', 1))
          and not pg_temp.clip('post', pg_temp.item('c006')),
  'once work items hang under it, nobody is asked to sign it');

-- One cursor for every kind --------------------------------------------------------------------

reset role;
create function pg_temp.walk() returns bigint language plpgsql as $$
declare
  v_at timestamptz;
  v_id uuid;
  v_seen uuid[] := '{}';
  v_row record;
begin
  loop
    select d.created_at, d.id into v_row from public.daybook_page(pg_temp.sp(), v_at, 1, v_id) d;
    exit when v_row.id is null;
    v_seen := v_seen || v_row.id;
    v_at := v_row.created_at;
    v_id := v_row.id;
  end loop;
  return (select count(distinct x) from unnest(v_seen) x);
end;
$$;
-- Two more send-backs at the same moment as other entries.
select pg_temp.as_user('e2');
set local role authenticated;
select public.sign_done(pg_temp.item('c001'), 'Photo added.');
select public.add_comment(pg_temp.item('c001'), 'Area cleaned.');
select pg_temp.as_user('e1');
select public.send_back(pg_temp.item('c001'), 'other', 'Label the sleeves.');
select is(pg_temp.walk(), (select count(*) from public.daybook_page(pg_temp.sp(), null, 100)),
  'one at a time, the cursor reaches every entry once, send-backs included');
select ok((select count(distinct d.kind) from public.daybook_page(pg_temp.sp(), null, 100) d
           where d.created_at = now() and d.kind <> 'post') = 3,
  'with a sign-off, an update and a send-back made at the same moment');

-- Someone who left, and a deleted Space, get nothing.
reset role;
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e4');
select pg_temp.as_user('e4');
set local role authenticated;
select is((select count(*) from public.daybook_page(pg_temp.sp(), null, 100)), 0::bigint,
  'someone who left gets no entry');
reset role;
update public.spaces set deleted_at = now() where id = pg_temp.sp();
select pg_temp.as_user('e1');
set local role authenticated;
select is((select count(*) from public.daybook_page(pg_temp.sp(), null, 100)), 0::bigint,
  'a deleted Space has no entries, even for its admin');

select * from finish();
rollback;
