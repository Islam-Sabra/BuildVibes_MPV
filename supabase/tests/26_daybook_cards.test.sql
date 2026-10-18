-- Migration 26: one card per work item, ordered by last activity, with its
-- proof, history and needs_me; replies on the feed card (F30).
-- Run with: supabase test db
--
-- Omar (e1) made the Space and is its admin (Lead). Rakesh (e2) is Crew,
-- Vera (e4) a Viewer, Tariq (e6) Crew in the MEP Team, Lina (e7) Crew who
-- leaves, Sami (e8) Crew. Eve (e5) is not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(110);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000026' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@cards26.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e4'), ('e5'), ('e6'), ('e7'), ('e8')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e4', 'Vera', 'Lane'),
             ('e5', 'Eve', 'Out'), ('e6', 'Tariq', 'Aziz'), ('e7', 'Lina', 'Khalil'),
             ('e8', 'Sami', 'Fares')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000026' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000026' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000026' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000026' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.team() returns uuid language sql as $$
  select current_setting('test.team')::uuid;
$$;
create function pg_temp.card(p_id uuid) returns jsonb language sql as $$
  select c.card from public.daybook_cards(pg_temp.sp(), null, 100) c where c.id = p_id;
$$;
create function pg_temp.needs(p_id uuid) returns text language sql as $$
  select pg_temp.card(p_id) ->> 'needs_me';
$$;
create function pg_temp.order_ids() returns uuid[] language sql as $$
  select array_agg(c.id order by c.last_activity_at desc, c.id desc)
  from public.daybook_cards(pg_temp.sp(), null, 100) c;
$$;
create function pg_temp.activity(p_id uuid) returns timestamptz language sql as $$
  select p.last_activity_at from public.space_posts p where p.id = p_id;
$$;
create function pg_temp.kinds(p_id uuid) returns text[] language sql as $$
  select array_agg(h ->> 'kind' order by n)
  from jsonb_array_elements(pg_temp.card(p_id) -> 'history') with ordinality x(h, n);
$$;
-- Run as the database owner: what was made just now moves to a time of its
-- own (a test runs in one transaction, so now() never moves), and each
-- post's last activity is worked out again from its record.
create function pg_temp.stamp(p_minutes_ago integer) returns void language sql as $$
  alter table public.work_item_events disable trigger work_item_events_append_only;
  alter table public.post_edits disable trigger post_edits_append_only;
  update public.work_item_events set created_at = now() - make_interval(mins => p_minutes_ago)
  where created_at = now();
  update public.post_edits set created_at = now() - make_interval(mins => p_minutes_ago)
  where created_at = now();
  alter table public.work_item_events enable trigger work_item_events_append_only;
  alter table public.post_edits enable trigger post_edits_append_only;
  update public.space_posts set created_at = now() - make_interval(mins => p_minutes_ago)
  where created_at = now();
  update public.space_posts set cancelled_at = now() - make_interval(mins => p_minutes_ago)
  where cancelled_at = now();
  update public.space_posts set edited_at = now() - make_interval(mins => p_minutes_ago)
  where edited_at = now();
  update public.space_posts p set last_activity_at = greatest(
    p.created_at, p.cancelled_at,
    (select max(e.created_at) from public.work_item_events e where e.work_item_id = p.id),
    (select max(pe.created_at) from public.post_edits pe where pe.post_id = p.id))
  where p.space_id = pg_temp.sp();
$$;

-- Setup ---------------------------------------------------------------------------------------

select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Cards site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e4', 'viewer'), ('e6', 'crew'), ('e7', 'crew'), ('e8', 'crew')) x(id, pass);
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.team', public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('e6')])::text, true);

-- Last activity: set at insert, raised by events, edits, reassignment, cancel -----------------

select lives_ok($$select public.create_work_item(pg_temp.sp(), 'Sleeves at grid C7', pg_temp.uid('e2'),
                    p_id => pg_temp.item('c001'))$$, 'Omar raises a work item for Rakesh');
select is(pg_temp.activity(pg_temp.item('c001')),
          (select p.created_at from public.space_posts p where p.id = pg_temp.item('c001')),
  'a new post''s last activity is when it was made');
reset role;
select pg_temp.stamp(100);
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Door closers', pg_temp.uid('e2'), p_id => pg_temp.item('c002'));
reset role;
select pg_temp.stamp(90);
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Fire stopping', pg_temp.uid('e2'), p_id => pg_temp.item('c003'));
reset role;
select pg_temp.stamp(80);
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.order_ids(), array[pg_temp.item('c003'), pg_temp.item('c002'), pg_temp.item('c001')],
  'cards come newest activity first');

select public.add_comment(pg_temp.item('c001'), 'Started on the east side.');
select is(pg_temp.activity(pg_temp.item('c001')), now(), 'a new event raises the last activity');
select is((pg_temp.order_ids())[1], pg_temp.item('c001'), 'and moves the card to the top');
select is(pg_temp.card(pg_temp.item('c001')) ->> 'last_activity_at',
          to_jsonb(now()) #>> '{}', 'the card carries its last activity');
reset role;
select ok((select p.edited_at is null from public.space_posts p where p.id = pg_temp.item('c001'))
          and not exists (select 1 from public.post_edits pe where pe.post_id = pg_temp.item('c001')),
  'last activity is never an edit: no edited_at, no Edited line');
select pg_temp.stamp(70);

select pg_temp.as_user('e1');
set local role authenticated;
select public.edit_space_post(pg_temp.item('c002'), '{"title": "Fix door closers"}'::jsonb);
select is(pg_temp.activity(pg_temp.item('c002')), now(), 'an edit raises it');
select is(pg_temp.card(pg_temp.item('c002')) -> 'history' -> 0 ->> 'kind', 'edited',
  'and is the newest history line');
select is(pg_temp.card(pg_temp.item('c002')) -> 'history' -> 0 -> 'changes' -> 'title' ->> 'to',
  'Fix door closers', 'with its changes');
reset role;
select pg_temp.stamp(60);

select pg_temp.as_user('e1');
set local role authenticated;
select public.reassign_work_item(pg_temp.item('c003'), pg_temp.uid('e8'));
select is(pg_temp.activity(pg_temp.item('c003')), now(), 'giving it to someone else raises it');
select is(pg_temp.card(pg_temp.item('c003')) -> 'history' -> 0 ->> 'to_name', 'Sami Fares',
  'the history says to whom');
select is(pg_temp.card(pg_temp.item('c003')) -> 'history' -> 0 ->> 'from_name', 'Rakesh Nair',
  'and instead of whom');
reset role;
select ok((select p.edited_at is null from public.space_posts p where p.id = pg_temp.item('c003')),
  'a reassignment is not an edit either');
select pg_temp.stamp(55);

select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Skirting', pg_temp.uid('e2'), p_id => pg_temp.item('c004'));
reset role;
select pg_temp.stamp(50);
select pg_temp.as_user('e1');
set local role authenticated;
select public.cancel_space_post(pg_temp.item('c004'), 'Not needed.');
select is(pg_temp.activity(pg_temp.item('c004')), now(), 'a cancel raises it');
select is(pg_temp.card(pg_temp.item('c004')) ->> 'status', 'cancelled', 'a cancelled post keeps its card');
select is(pg_temp.card(pg_temp.item('c004')) -> 'history' -> 0 ->> 'kind', 'cancelled',
  'the cancel is its newest history line');
select is(pg_temp.card(pg_temp.item('c004')) -> 'history' -> 0 ->> 'note', 'Not needed.',
  'with the note');
reset role;
select pg_temp.stamp(45);
-- An event older than the last activity never lowers it.
alter table public.work_item_events disable trigger work_item_events_notify;
insert into public.work_item_events (work_item_id, actor_id, kind, note, created_at)
values (pg_temp.item('c002'), pg_temp.uid('e2'), 'comment', 'Late arrival.', now() - interval '2 hours');
alter table public.work_item_events enable trigger work_item_events_notify;
select is(pg_temp.activity(pg_temp.item('c002')), now() - interval '60 minutes',
  'an older event never lowers the last activity');

-- needs_me in each state ----------------------------------------------------------------------

select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.needs(pg_temp.item('c001')), 'to_sign', 'open: the owner is asked to sign');
select pg_temp.as_user('e1');
select is(pg_temp.needs(pg_temp.item('c001')), null, 'the author is asked nothing while it is open');
select ok(pg_temp.card(pg_temp.item('c001')) ? 'needs_me',
  'needs_me is always there (null replaces the post JSON''s boolean)');
select pg_temp.as_user('e4');
select ok(pg_temp.card(pg_temp.item('c001')) is not null
          and pg_temp.needs(pg_temp.item('c001')) is null,
  'a Viewer gets the card, with needs_me null');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100) c
           where c.card ->> 'needs_me' is not null), 0::bigint,
  'a Viewer is never asked anything');
select is(pg_temp.card(pg_temp.item('c001')) ->> 'proof', null, 'never signed: no proof');

select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('c001'), 'All six fixed.');
reset role;
insert into public.work_item_evidence (event_id, work_item_id, storage_path, taken_at, place_text)
select e.id, e.work_item_id, pg_temp.sp() || '/items/c001/one.jpg', now() - interval '41 minutes', 'Grid C7'
from public.work_item_events e where e.work_item_id = pg_temp.item('c001') and e.kind = 'done';
select pg_temp.stamp(40);
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.needs(pg_temp.item('c001')), 'to_check', 'done: the author is asked to check');
select pg_temp.as_user('e2');
select is(pg_temp.needs(pg_temp.item('c001')), null, 'the owner waits, asked nothing');
select is(pg_temp.card(pg_temp.item('c001')) -> 'proof' ->> 'note', 'All six fixed.',
  'the proof is the sign-off''s note');
select is(pg_temp.card(pg_temp.item('c001')) -> 'proof' -> 'photos' -> 0 ->> 'place', 'Grid C7',
  'and its photos, with their place');
select is(pg_temp.card(pg_temp.item('c001')) -> 'proof' -> 'by' ->> 'name', 'Rakesh Nair',
  'who signed it');
select is(pg_temp.card(pg_temp.item('c001')) -> 'proof' -> 'outcome' ->> 'kind', 'done',
  'its outcome: done');
select is(pg_temp.card(pg_temp.item('c001')) -> 'history' -> 0 -> 'photos' -> 0 ->> 'taken_at',
  to_jsonb(now() - interval '41 minutes') #>> '{}', 'a sign-off''s history line has its photos');

select pg_temp.as_user('e1');
select public.send_back(pg_temp.item('c001'), 'not_finished', 'Two sleeves are loose.');
reset role;
select pg_temp.stamp(30);
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.needs(pg_temp.item('c001')), 'to_sign', 'sent back: the owner is asked to sign again');
select is(pg_temp.card(pg_temp.item('c001')) -> 'proof' -> 'outcome' ->> 'kind', 'sent_back',
  'the proof is stamped SENT BACK');
select is(pg_temp.card(pg_temp.item('c001')) -> 'proof' -> 'outcome' ->> 'by_name', 'Omar Haddad',
  'by whom');
select is(pg_temp.card(pg_temp.item('c001')) -> 'proof' -> 'outcome' ->> 'reason', 'not_finished',
  'and why');
select pg_temp.as_user('e1');
select is(pg_temp.needs(pg_temp.item('c001')), null, 'the author is asked nothing after a send-back');

select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('c001'), 'Tightened.');
reset role;
select pg_temp.stamp(20);
select pg_temp.as_user('e1');
set local role authenticated;
select public.check_item(pg_temp.item('c001'));
reset role;
select pg_temp.stamp(10);
select pg_temp.as_user('e2');
set local role authenticated;
select is(pg_temp.card(pg_temp.item('c001')) -> 'proof' ->> 'note', 'Tightened.',
  'the proof is the latest sign-off');
select is(pg_temp.card(pg_temp.item('c001')) -> 'proof' -> 'outcome' ->> 'kind', 'checked',
  'stamped CHECKED');
select is((pg_temp.card(pg_temp.item('c001')) -> 'proof' -> 'outcome' ->> 'at')::timestamptz,
  now() - interval '10 minutes', 'with when');
select is(pg_temp.needs(pg_temp.item('c001')), null, 'checked: the owner is asked nothing');
select pg_temp.as_user('e1');
select is(pg_temp.needs(pg_temp.item('c001')), null, 'nor the author');
select is(pg_temp.kinds(pg_temp.item('c001')),
  array['checked', 'done', 'sent_back', 'done', 'comment', 'raised'],
  'the history: every event, newest first');
select is(pg_temp.card(pg_temp.item('c001')) -> 'history' -> 2 ->> 'reason', 'not_finished',
  'a send-back line has its reason');
select is(pg_temp.card(pg_temp.item('c001')) -> 'history' -> 2 ->> 'by_name', 'Omar Haddad',
  'and who');
select is((pg_temp.card(pg_temp.item('c001')) ->> 'history_more')::boolean, false,
  'a short history has no more');
select is((pg_temp.order_ids())[1], pg_temp.item('c001'), 'the check moved it to the top again');

-- A cancelled item asks nobody.
select pg_temp.as_user('e2');
select is(pg_temp.needs(pg_temp.item('c004')), null, 'cancelled: the owner is asked nothing');

-- The owner left: the author's clip, Give to someone else.
select pg_temp.as_user('e1');
select public.create_work_item(pg_temp.sp(), 'Ceiling grid', pg_temp.uid('e7'), p_id => pg_temp.item('c005'));
reset role;
select pg_temp.stamp(9);
update public.space_members set left_at = now()
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e7');
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.needs(pg_temp.item('c005')), 'give_to',
  'the owner left: the author is asked to give it to someone else');
select pg_temp.as_user('e7');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100)), 0::bigint,
  'someone who left gets no card');

-- A target (work items under it, its author owns it) asks nobody to sign it.
select pg_temp.as_user('e2');
select public.create_work_item(pg_temp.sp(), 'Level 4 ceilings', pg_temp.uid('e2'), p_id => pg_temp.item('c006'));
select public.create_work_item(pg_temp.sp(), 'Bay 1', pg_temp.uid('e2'),
                               p_parent => pg_temp.item('c006'), p_id => pg_temp.item('c007'));
select is(pg_temp.needs(pg_temp.item('c006')), null, 'a target asks nobody to sign');
select is(pg_temp.needs(pg_temp.item('c007')), 'to_sign', 'the work item under it does');

-- A checklist with points left for me: 'to_tick'.
select public.create_space_post(pg_temp.item('c020'), pg_temp.sp(), 'checklist', 'Before the pour',
                                p_people => array[pg_temp.uid('e8')],
                                p_points => jsonb_build_array(jsonb_build_object(
                                  'id', pg_temp.item('a001'), 'text', 'Rebar spacing')));
select pg_temp.as_user('e8');
select is(pg_temp.needs(pg_temp.item('c020')), 'to_tick', 'a checklist for me: points to tick');
select pg_temp.as_user('e2');
select is(pg_temp.needs(pg_temp.item('c020')), null, 'not for its author');
select is(pg_temp.card(pg_temp.item('c020')) -> 'history', '[]'::jsonb,
  'a post with no events has an empty history');
reset role;
select pg_temp.stamp(8);

-- More that raises a card: a parent's cancel, a page saved; a cancelled sign-off.
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Level 2 walk', pg_temp.uid('e2'), p_id => pg_temp.item('c040'));
select public.create_work_item(pg_temp.sp(), 'Bay A', pg_temp.uid('e2'),
                               p_parent => pg_temp.item('c040'), p_id => pg_temp.item('c041'));
select public.create_work_item(pg_temp.sp(), 'Handrails', pg_temp.uid('e2'), p_id => pg_temp.item('c042'));
select public.create_work_item(pg_temp.sp(), 'Pour notes', pg_temp.uid('e2'), p_id => pg_temp.item('c043'));
select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('c042'), 'Fixed.');
reset role;
select pg_temp.stamp(8);
select pg_temp.as_user('e1');
set local role authenticated;
select public.cancel_space_post(pg_temp.item('c040'));
select is(pg_temp.activity(pg_temp.item('c041')), now(),
  'a work item under it rises with its parent''s cancel');
select public.cancel_space_post(pg_temp.item('c042'));
select is(pg_temp.card(pg_temp.item('c042')) -> 'proof' -> 'outcome' ->> 'kind', 'cancelled',
  'a sign-off on a cancelled item is stamped CANCELLED');
select is(pg_temp.card(pg_temp.item('c042')) -> 'proof' -> 'outcome' ->> 'by_name', 'Omar Haddad',
  'with who cancelled it');
select is((pg_temp.card(pg_temp.item('c042')) -> 'proof' -> 'outcome' ->> 'at')::timestamptz, now(),
  'and when');
select public.save_blocks(pg_temp.item('c043'),
  jsonb_build_array(jsonb_build_object('id', pg_temp.item('a002'), 'type', 'text', 'text', 'Pour from C7')), 0);
select is(pg_temp.activity(pg_temp.item('c043')), now(), 'saving its page raises it');
reset role;
select pg_temp.stamp(8);

-- Who gets which cards -------------------------------------------------------------------------

select pg_temp.as_user('e6');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'MEP risers', pg_temp.uid('e6'),
                               p_team => pg_temp.team(), p_id => pg_temp.item('c008'));
select public.add_comment(pg_temp.item('c008'), 'Risers in.');
select ok(pg_temp.card(pg_temp.item('c008')) is not null, 'the Team gets its card');
select is((select count(*) from public.post_history(pg_temp.item('c008'))), 2::bigint,
  'and its history');
select pg_temp.as_user('e2');
select ok(pg_temp.card(pg_temp.item('c008')) is null, 'someone outside the Team never gets it');
select is((select count(*) from public.post_history(pg_temp.item('c008'))), 0::bigint,
  'nor its history');
select pg_temp.as_user('e1');
select ok(pg_temp.card(pg_temp.item('c008')) is not null, 'the Space admin does');
select pg_temp.as_user('e5');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100)), 0::bigint,
  'someone outside the Space gets no card');
select is((select count(*) from public.post_history(pg_temp.item('c001'))), 0::bigint,
  'nor any history');

select pg_temp.as_user('e1');
select public.create_work_item(pg_temp.sp(), 'Wrong one', pg_temp.uid('e2'), p_id => pg_temp.item('c009'));
select public.delete_space_post(pg_temp.item('c009'));
select ok(pg_temp.card(pg_temp.item('c009')) is null, 'a deleted post has no card');
select is((select count(*) from public.post_history(pg_temp.item('c009'))), 0::bigint,
  'and its history goes with it');
reset role;
select pg_temp.stamp(7);

-- The history cap and post_history paging -------------------------------------------------------

-- 55 updates made at the same moment, on top of the raised line: 56 lines.
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Long story', pg_temp.uid('e2'), p_id => pg_temp.item('c010'));
reset role;
select pg_temp.stamp(6);
select pg_temp.as_user('e2');
set local role authenticated;
select public.add_comment(pg_temp.item('c010'), 'Update ' || g) from generate_series(1, 55) g;
select is(jsonb_array_length(pg_temp.card(pg_temp.item('c010')) -> 'history'), 50,
  'the card carries the newest 50 lines');
select is((pg_temp.card(pg_temp.item('c010')) ->> 'history_more')::boolean, true, 'and says there are more');
select is((select array_agg(h.id order by h.at desc, h.id desc) from public.post_history(pg_temp.item('c010')) h),
          (select array_agg((x ->> 'id')::uuid order by n)
           from jsonb_array_elements(pg_temp.card(pg_temp.item('c010')) -> 'history') with ordinality y(x, n)),
  'post_history''s first page is the card''s history');
create temp table last_line as
  select (x ->> 'at')::timestamptz as at, (x ->> 'id')::uuid as id
  from jsonb_array_elements(pg_temp.card(pg_temp.item('c010')) -> 'history') with ordinality y(x, n)
  where n = 50;
select is((select count(*) from public.post_history(pg_temp.item('c010'),
                                                    (select at from last_line), (select id from last_line))),
  6::bigint, 'Show earlier: the next page has the other six, though all made at one moment');
select is((select h.event ->> 'kind' from public.post_history(pg_temp.item('c010'),
             (select at from last_line), (select id from last_line)) h
           order by h.at, h.id limit 1), 'raised', 'ending with the raised line');
select is((select count(distinct x.id) from (
             select h.id from public.post_history(pg_temp.item('c010')) h
             union all
             select h.id from public.post_history(pg_temp.item('c010'),
                                                  (select at from last_line), (select id from last_line)) h) x),
  56::bigint, 'two pages reach every line once');
select is((select count(*) from public.post_history(pg_temp.item('c010'), p_limit => 0)), 1::bigint,
  'a page has at least one line');

-- Paging the cards ------------------------------------------------------------------------------

reset role;
create function pg_temp.walk(p_step integer) returns bigint language plpgsql as $$
declare
  v_at timestamptz;
  v_id uuid;
  v_seen uuid[] := '{}';
  v_n integer;
  v_row record;
begin
  loop
    v_n := 0;
    for v_row in select c.id, c.last_activity_at from public.daybook_cards(pg_temp.sp(), v_at, p_step, v_id) c loop
      v_seen := v_seen || v_row.id;
      v_at := v_row.last_activity_at;
      v_id := v_row.id;
      v_n := v_n + 1;
    end loop;
    exit when v_n = 0;
  end loop;
  return (select count(*) from unnest(v_seen) x) * 1000 + (select count(distinct x) from unnest(v_seen) x);
end;
$$;
-- More cards at the same moment as the long one.
select pg_temp.as_user('e1');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Same time ' || g, pg_temp.uid('e2'))
from generate_series(1, 4) g;
select ok((select count(*) from public.daybook_cards(pg_temp.sp(), null, 100) c
           where c.last_activity_at = now()) >= 5, 'five cards share one last activity');
select is(pg_temp.walk(1), (select count(*) * 1001 from public.daybook_cards(pg_temp.sp(), null, 100)),
  'one at a time, the cursor reaches every card once');
select is(pg_temp.walk(3), (select count(*) * 1001 from public.daybook_cards(pg_temp.sp(), null, 100)),
  'three at a time too');
select is((select count(*) from public.daybook_cards(pg_temp.sp(), null, 2)), 2::bigint,
  'a page stops at its limit');

-- The triggers alone (nothing worked out again afterwards): later events and
-- an edit, each at its own time, put their cards on top in that order.
reset role;
alter table public.work_item_events disable trigger work_item_events_notify;
insert into public.work_item_events (work_item_id, actor_id, kind, note, created_at)
values (pg_temp.item('c002'), pg_temp.uid('e2'), 'comment', 'Later.', now() + interval '1 minute'),
       (pg_temp.item('c003'), pg_temp.uid('e8'), 'comment', 'Even later.', now() + interval '2 minutes');
alter table public.work_item_events enable trigger work_item_events_notify;
insert into public.post_edits (post_id, editor_id, changes, created_at)
values (pg_temp.item('c001'), pg_temp.uid('e1'), '{"body": {"from": null, "to": "Note"}}',
        now() + interval '3 minutes');
select pg_temp.as_user('e1');
set local role authenticated;
select is((pg_temp.order_ids())[1:3], array[pg_temp.item('c001'), pg_temp.item('c003'), pg_temp.item('c002')],
  'the triggers alone order the cards by their latest activity');

-- F30: replies on the feed card -----------------------------------------------------------------

select pg_temp.as_user('e1');
select public.create_post(pg_temp.item('f0f1'), 'Slab poured on level 3.', 'en');
select is((select latest_reply from public.post_cards where id = pg_temp.item('f0f1')), null,
  'no replies: no latest reply');
select is((select reply_faces from public.post_cards where id = pg_temp.item('f0f1')), '[]'::jsonb,
  'and no faces');
select pg_temp.as_user('e2');
select public.add_reply(pg_temp.item('b001'), pg_temp.item('f0f1'), null, 'Great work.');
reset role;
update public.post_replies set created_at = now() - interval '40 minutes' where id = pg_temp.item('b001');
select pg_temp.as_user('e4');
set local role authenticated;
select public.add_reply(pg_temp.item('b002'), pg_temp.item('f0f1'), null, 'Well done.');
reset role;
update public.post_replies set created_at = now() - interval '30 minutes' where id = pg_temp.item('b002');
select pg_temp.as_user('e6');
set local role authenticated;
select public.add_reply(pg_temp.item('b003'), pg_temp.item('f0f1'), pg_temp.item('b001'), 'Agreed, Rakesh.');
reset role;
update public.post_replies set created_at = now() - interval '20 minutes' where id = pg_temp.item('b003');
select pg_temp.as_user('e2');
set local role authenticated;
select public.add_reply(pg_temp.item('b004'), pg_temp.item('f0f1'), null, 'Seen it, thanks Islam');
reset role;
update public.post_replies set created_at = now() - interval '15 minutes' where id = pg_temp.item('b004');
select pg_temp.as_user('e8');
set local role authenticated;
select public.add_reply(pg_temp.item('b005'), pg_temp.item('f0f1'), null, repeat('Long reply ', 20));
reset role;
update public.post_replies set created_at = now() - interval '10 minutes' where id = pg_temp.item('b005');

select pg_temp.as_user('e1');
set local role authenticated;
select is((select latest_reply ->> 'id' from public.post_cards where id = pg_temp.item('f0f1')),
  pg_temp.item('b005')::text, 'the card has the latest reply');
select is((select latest_reply ->> 'author_name' from public.post_cards where id = pg_temp.item('f0f1')),
  'Sami Fares', 'with its author');
select is((select length(latest_reply ->> 'body') from public.post_cards where id = pg_temp.item('f0f1')),
  80, 'and the first 80 characters');
select is((select latest_reply ->> 'to_me' from public.post_cards where id = pg_temp.item('f0f1')),
  'true', 'a top comment on my post answers me');
select is((select array_agg(f ->> 'name' order by n)
           from public.post_cards c, jsonb_array_elements(c.reply_faces) with ordinality x(f, n)
           where c.id = pg_temp.item('f0f1')),
  array['Sami Fares', 'Rakesh Nair', 'Tariq Aziz'], 'up to three faces, each person once, latest first');
insert into public.blocks (blocker_id, blocked_id) values (pg_temp.uid('e1'), pg_temp.uid('e8'));
select is((select latest_reply ->> 'id' from public.post_cards where id = pg_temp.item('f0f1')),
  pg_temp.item('b004')::text, 'a blocked person''s reply is never the latest');
select is((select array_agg(f ->> 'id' order by n)
           from public.post_cards c, jsonb_array_elements(c.reply_faces) with ordinality x(f, n)
           where c.id = pg_temp.item('f0f1')),
  array[pg_temp.uid('e2')::text, pg_temp.uid('e6')::text, pg_temp.uid('e4')::text],
  'nor a face');
select pg_temp.as_user('e2');
select public.delete_reply(pg_temp.item('b004'));
select pg_temp.as_user('e1');
select is((select latest_reply ->> 'id' from public.post_cards where id = pg_temp.item('f0f1')),
  pg_temp.item('b003')::text, 'a deleted reply is never the latest');
select is((select latest_reply ->> 'to_me' from public.post_cards where id = pg_temp.item('f0f1')),
  'false', 'an answer to someone else doesn''t answer me');
select pg_temp.as_user('e8');
select is((select latest_reply ->> 'id' from public.post_cards where id = pg_temp.item('f0f1')),
  null, 'across the block, the blocked person doesn''t even get the post');
select pg_temp.as_user('e6');
select is((select latest_reply ->> 'id' from public.post_cards where id = pg_temp.item('f0f1')),
  pg_temp.item('b005')::text, 'others still see the latest reply');
select ok(not exists (
            select 1 from information_schema.columns
            where table_schema = 'public' and table_name = 'post_cards'
              and (column_name like '%count%' or column_name like '%total%'))
          and not exists (
            select 1 from public.post_cards c, jsonb_object_keys(coalesce(c.latest_reply, '{}')) k
            where c.id = pg_temp.item('f0f1') and (k like '%count%' or k like '%total%')),
  'never a count');

-- An answer to my reply answers me; a reply I reported, or from a hidden
-- account, is never shown.
select pg_temp.as_user('e1');
select public.create_post(pg_temp.item('f0f2'), 'Formwork struck on level 2.', 'en');
select pg_temp.as_user('e2');
select public.add_reply(pg_temp.item('b011'), pg_temp.item('f0f2'), null, 'Nice, clean edges.');
reset role;
update public.post_replies set created_at = now() - interval '5 minutes' where id = pg_temp.item('b011');
select pg_temp.as_user('e6');
set local role authenticated;
select public.add_reply(pg_temp.item('b012'), pg_temp.item('f0f2'), pg_temp.item('b011'), 'Rakesh, which crew?');
select pg_temp.as_user('e2');
select is((select latest_reply ->> 'id' from public.post_cards where id = pg_temp.item('f0f2')),
  pg_temp.item('b012')::text, 'an answer to my reply is the latest');
select is((select latest_reply ->> 'to_me' from public.post_cards where id = pg_temp.item('f0f2')),
  'true', 'and it answers me');
select public.report('reply', pg_temp.item('b012'), 'spam');
select is((select latest_reply ->> 'id' from public.post_cards where id = pg_temp.item('f0f2')),
  pg_temp.item('b011')::text, 'a reply I reported is hidden from me');
select is((select latest_reply ->> 'to_me' from public.post_cards where id = pg_temp.item('f0f2')),
  'false', 'my own reply never answers me');
select pg_temp.as_user('e1');
select is((select latest_reply ->> 'id' from public.post_cards where id = pg_temp.item('f0f2')),
  pg_temp.item('b012')::text, 'others still see the reported reply');
reset role;
update public.profiles set deletion_scheduled_at = now() where id = pg_temp.uid('e6');
select pg_temp.as_user('e1');
set local role authenticated;
select is((select latest_reply ->> 'id' from public.post_cards where id = pg_temp.item('f0f2')),
  pg_temp.item('b011')::text, 'a hidden account''s reply is never the latest');
select ok(not exists (select 1 from public.post_cards c, jsonb_array_elements(c.reply_faces) f
                      where c.id in (pg_temp.item('f0f2'), pg_temp.item('f0f1'))
                        and f ->> 'id' = pg_temp.uid('e6')::text),
  'nor its face');
reset role;
update public.profiles set deletion_scheduled_at = null where id = pg_temp.uid('e6');

-- Viewers ----------------------------------------------------------------------------------------

select pg_temp.as_user('e8');
set local role authenticated;
select public.create_work_item(pg_temp.sp(), 'Bracket spacing', pg_temp.uid('e2'), p_id => pg_temp.item('c030'));
select public.create_work_item(pg_temp.sp(), 'Cable labels', pg_temp.uid('e2'), p_id => pg_temp.item('c031'));
select pg_temp.as_user('e2');
select public.sign_done(pg_temp.item('c030'), 'Spaced.');
reset role;
update public.space_members set pass = 'viewer'
where space_id = pg_temp.sp() and profile_id = pg_temp.uid('e8');
select pg_temp.as_user('e8');
set local role authenticated;
select is(pg_temp.needs(pg_temp.item('c030')), null, 'an author lowered to Viewer isn''t asked to check');
select is(pg_temp.needs(pg_temp.item('c031')), null, 'nor anything on an open item');
select pg_temp.as_user('e1');
select is(pg_temp.needs(pg_temp.item('c030')), 'to_check', 'the Space admin checks for the lowered author');
-- Open policy question (data-model §22): a Viewer pass doesn't stop an admin
-- acting for a gone author. This pins today's rule.
reset role;
update public.space_members set pass = 'viewer'
where space_id = pg_temp.sp() and profile_id in (pg_temp.uid('e1'), pg_temp.uid('e2'));
select pg_temp.as_user('e1');
set local role authenticated;
select is(pg_temp.needs(pg_temp.item('c030')), 'to_check',
  'a Space admin with a Viewer pass still checks for a gone author');
select is(pg_temp.needs(pg_temp.item('c031')), 'give_to',
  'and is asked to give away an item whose owner can no longer sign');

-- Grants -----------------------------------------------------------------------------------------

reset role;
select ok(has_function_privilege('authenticated', 'public.daybook_cards(uuid, timestamptz, integer, uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.post_history(uuid, timestamptz, uuid, integer)', 'execute')
          and not has_function_privilege('anon', 'public.daybook_cards(uuid, timestamptz, integer, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.post_history(uuid, timestamptz, uuid, integer)', 'execute'),
  'a signed-in person reads the cards and history; anon doesn''t');
select ok(not has_function_privilege('authenticated', 'public.post_history_rows(public.space_posts, timestamptz, uuid, integer)', 'execute')
          and not has_function_privilege('authenticated', 'public.card_needs_me(public.space_posts)', 'execute')
          and not has_function_privilege('authenticated', 'public.post_activity_on_event()', 'execute'),
  'the internal helpers can''t be called by the app');
select is((select reloptions from pg_class where oid = 'public.post_cards'::regclass),
  array['security_invoker=true'], 'post_cards still runs as the caller');

select * from finish();
rollback;
