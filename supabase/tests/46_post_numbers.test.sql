-- Migration 46 (review 95): one number for every post, and search by it.
-- Run with: supabase test db
--
-- Omar (a1) made "Numbers site" and is its admin; Rakesh (a2) is Crew;
-- Tariq (a3) is Crew in its MEP Team; Eve (a4) is in no Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(43);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000046' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@numbers46.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('a1'), ('a2'), ('a3'), ('a4')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('a1', 'Omar', 'Haddad'), ('a2', 'Rakesh', 'Nair'), ('a3', 'Tariq', 'Aziz'),
             ('a4', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000046' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000046' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000046' || p_id)::uuid;
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000046' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.num(p text) returns integer language sql as $$
  select number from public.space_posts where id = pg_temp.id(p);
$$;
create function pg_temp.prefix() returns text language sql as $$
  select ref_prefix from public.spaces where id = pg_temp.sp();
$$;
-- What search_space gives [p_who] for [p_q]: the hits' post ids, exact first.
create function pg_temp.found(p_who text, p_q text) returns setof record language plpgsql as $$
begin
  perform pg_temp.as_user(p_who);
  set local role authenticated;
  return query select s.post_id, s.exact, s.ref from public.search_space(pg_temp.sp(), p_q) s;
  reset role;
end;
$$;

-- Setup -------------------------------------------------------------------------------------------

select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.space', public.create_space('Numbers site')::text, true);
select set_config('test.space2', public.create_space('Other numbers')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), 'crew', pg_temp.uid('a1')
from (values ('a2'), ('a3')) x(id);
select pg_temp.as_user('a1');
set local role authenticated;
select set_config('test.team',
  public.create_team(pg_temp.sp(), 'MEP Team', array[pg_temp.uid('a3')])::text, true);

-- Every kind takes the next number ---------------------------------------------------------------

select public.create_space_post(pg_temp.id('b001'), pg_temp.sp(), 'note', 'Gate 2 closed');
select public.create_work_item(pg_temp.sp(), 'Sleeves at C7', pg_temp.uid('a2'),
                               p_id => pg_temp.id('b002'));
select public.create_space_post(pg_temp.id('b003'), pg_temp.sp(), 'checklist', 'Before the pour',
                                p_people => array[pg_temp.uid('a2')],
                                p_points => jsonb_build_array(
                                  jsonb_build_object('id', pg_temp.id('c001'), 'text', 'Sleeves'),
                                  jsonb_build_object('id', pg_temp.id('c002'), 'text', 'Formwork')));
select public.create_space_post(pg_temp.id('b004'), pg_temp.sp(), 'announcement', 'Hot works');
select public.create_space_post(pg_temp.id('b005'), pg_temp.sp(), 'activity', 'Pour level 3',
                                p_starts_at => now() + interval '1 day');
reset role;
insert into public.library_files (id, space_id, name, storage_path, mime, version_no)
values (pg_temp.id('f001'), pg_temp.sp(), 'A-501.pdf', 'x/A-501.pdf', 'application/pdf', 1);
insert into public.space_posts (id, space_id, kind, author_id, title, library_file_id)
values (pg_temp.id('b006'), pg_temp.sp(), 'file', pg_temp.uid('a1'), 'A-501', pg_temp.id('f001'));
insert into public.space_posts (id, space_id, kind, author_id, title)
values (pg_temp.id('b007'), pg_temp.sp(), 'report', pg_temp.uid('a1'), 'Daily report');

select is(
  (select array_agg(p.number order by p.number) from public.space_posts p
   where p.id = any (array[pg_temp.id('b001'), pg_temp.id('b002'), pg_temp.id('b003'),
                           pg_temp.id('b004'), pg_temp.id('b005'), pg_temp.id('b006'),
                           pg_temp.id('b007')])),
  array[1, 2, 3, 4, 5, 6, 7],
  'a note, a work item, a checklist, an announcement, an activity, a file and a report: 1 to 7');
select is((select ref from public.space_posts where id = pg_temp.id('b001')),
  pg_temp.prefix() || '-001', 'the ref: the prefix, a dash, three digits');
select is((select array[w.number::text, w.ref] from public.work_items w
           where w.id = pg_temp.id('b002')),
  (select array[p.number::text, p.ref] from public.space_posts p
   where p.id = pg_temp.id('b002')),
  'a work item''s number and ref are its post''s');
select is((select next_item_number from public.spaces where id = pg_temp.sp()), 8,
  'the counter goes on from there');
select is((select number from public.space_posts where space_id = current_setting('test.space2')::uuid
           order by number limit 1), null, 'another Space counts on its own');

select pg_temp.as_user('a1');
set local role authenticated;
select public.create_space_post(pg_temp.id('b001'), pg_temp.sp(), 'note', 'Gate 2 closed');
select is(pg_temp.num('b001'), 1, 'the same post sent again keeps its number');
select is((select next_item_number from public.spaces where id = pg_temp.sp()), 8,
  'and takes no other');
select public.create_work_item(pg_temp.sp(), 'Sleeves at C7', pg_temp.uid('a2'),
                               p_id => pg_temp.id('b002'));
select is((select next_item_number from public.spaces where id = pg_temp.sp()), 8,
  'nor does a work item sent again');

-- A work item under another, and one under that: each its own number.
select public.create_work_item(pg_temp.sp(), 'Level 2 walk', pg_temp.uid('a2'),
                               p_id => pg_temp.id('b010'));
select public.create_work_item(pg_temp.sp(), 'Tile cracked', pg_temp.uid('a2'),
                               p_id => pg_temp.id('b011'), p_parent => pg_temp.id('b010'));
select public.create_work_item(pg_temp.sp(), 'Hanger missing', pg_temp.uid('a2'),
                               p_id => pg_temp.id('b012'), p_parent => pg_temp.id('b010'));
select is(array[pg_temp.num('b010'), pg_temp.num('b011'), pg_temp.num('b012')], array[8, 9, 10],
  'a work item and two under it: three numbers in turn');
select is((select count(*) from public.work_items w join public.space_posts p on p.id = w.id
           where w.number <> p.number or w.ref <> p.ref), 0::bigint,
  'no work item anywhere has another number than its post');

-- A Team's post takes the next number too; others see a gap.
select public.create_space_post(pg_temp.id('b013'), pg_temp.sp(), 'note', 'MEP only',
                                p_team => current_setting('test.team')::uuid);
select public.create_space_post(pg_temp.id('b014'), pg_temp.sp(), 'note', 'After the Team note');
select is(array[pg_temp.num('b013'), pg_temp.num('b014')], array[11, 12],
  'a Team''s post uses its number: Rakesh sees 10, then 12');
reset role;

-- One place numbers -------------------------------------------------------------------------------

select throws_ok($$insert into public.work_items (id, space_id, number, ref, title)
  values (pg_temp.id('b014'), pg_temp.sp(), 99, 'ZZ-099', 'Another number')$$,
  '23514', null, 'a work item can''t take another number than its post''s');
select throws_ok($$update public.work_items set number = 99 where id = pg_temp.id('b002')$$,
  '23514', null, 'nor be given one after');
insert into public.space_posts (id, space_id, kind, author_id, title, number, ref)
values (pg_temp.id('b015'), pg_temp.sp(), 'note', pg_temp.uid('a1'), 'Says 500', 500, 'XX-500');
select is(array[pg_temp.num('b015')::text, (select ref from public.space_posts where id = pg_temp.id('b015'))],
  array['13', pg_temp.prefix() || '-013'], 'a number given at insert is replaced by the next one');
select throws_ok($$update public.space_posts set number = 1 where id = pg_temp.id('b014')$$,
  '23505', null, 'numbers are unique in a Space');
select ok(exists (select 1 from pg_constraint where conname = 'space_posts_space_number'),
  'unique (space_id, number)');
select is((select count(*) from public.space_posts where number is null or ref is null), 0::bigint,
  'no post anywhere without a number');
select is((select count(*) from (select space_id, number from public.space_posts
                                 group by 1, 2 having count(*) > 1) d), 0::bigint,
  'no number twice in a Space');
select is(public.post_ref('NST', 1234), 'NST-1234', 'past 999, the digits aren''t cut');
-- The counter row is locked while a post takes its number, so two writers
-- wait for each other: the trigger updates the Space row, as before.
select ok(pg_get_functiondef('public.number_space_post()'::regprocedure)
            like '%update public.spaces s%set next_item_number = s.next_item_number + 1%',
  'the number comes from the Space row, locked by its update');
select ok(not has_function_privilege('anon', 'public.post_ref(text, integer)', 'execute'),
  'signed out: no post_ref');

-- The backfill, as it ran on this database: posts made before 46 that
-- weren't work items are numbered in their Space in the order they were made.
select is((select count(*) from (
             select p.space_id,
                    p.number - lag(p.number) over (partition by p.space_id order by p.number) as step,
                    p.created_at < lag(p.created_at) over (partition by p.space_id order by p.number)
                      as earlier
             from public.space_posts p
             where not exists (select 1 from public.work_items w where w.id = p.id)
               and p.created_at < (select min(created_at) from public.space_posts
                                   where id = pg_temp.id('b001'))) x
           where x.earlier), 0::bigint,
  'older posts are numbered oldest first');

-- The post's ref in its JSON and on Activity -----------------------------------------------------

select is((select public.space_post_json(p, false) ->> 'ref' from public.space_posts p
           where p.id = pg_temp.id('b001')), pg_temp.prefix() || '-001', 'a note''s JSON has its ref');
select is((select public.space_post_json(p, false) ->> 'ref' from public.space_posts p
           where p.id = pg_temp.id('b002')), pg_temp.prefix() || '-002', 'a work item''s too');
select is((select public.space_post_json(p, false) -> 'item' ->> 'ref' from public.space_posts p
           where p.id = pg_temp.id('b002')), pg_temp.prefix() || '-002', 'and its item''s, the same');

-- Search by number --------------------------------------------------------------------------------

select is((select array_agg(x.post_id) from pg_temp.found('a2', pg_temp.prefix() || '-002')
             as x(post_id uuid, exact boolean, ref text) where x.exact),
  array[pg_temp.id('b002')], 'PREFIX-002 finds number 2');
select is((select array_agg(x.post_id) from pg_temp.found('a2', pg_temp.prefix() || '002')
             as x(post_id uuid, exact boolean, ref text) where x.exact),
  array[pg_temp.id('b002')], 'PREFIX002');
select is((select array_agg(x.post_id) from pg_temp.found('a2', lower(pg_temp.prefix()) || ' 2')
             as x(post_id uuid, exact boolean, ref text) where x.exact),
  array[pg_temp.id('b002')], 'prefix 2, in small letters');
select is((select array_agg(x.post_id) from pg_temp.found('a2', '002')
             as x(post_id uuid, exact boolean, ref text) where x.exact),
  array[pg_temp.id('b002')], '002');
select is((select array_agg(x.post_id) from pg_temp.found('a2', '2')
             as x(post_id uuid, exact boolean, ref text) where x.exact),
  array[pg_temp.id('b002')], 'one digit: 2');
select is((select array_agg(x.post_id) from pg_temp.found('a2', ' 12 ')
             as x(post_id uuid, exact boolean, ref text) where x.exact),
  array[pg_temp.id('b014')], 'spaces around: 12');
select is((select array_agg(x.post_id) from pg_temp.found('a2', '١٢')
             as x(post_id uuid, exact boolean, ref text) where x.exact),
  array[pg_temp.id('b014')], 'Arabic-Indic digits: ١٢');
select is((select array_agg(x.post_id) from pg_temp.found('a2', '۱۲')
             as x(post_id uuid, exact boolean, ref text) where x.exact),
  array[pg_temp.id('b014')], 'Eastern Arabic-Indic digits: ۱۲');
select is((select count(*) from pg_temp.found('a2', 'ABC-002')
             as x(post_id uuid, exact boolean, ref text) where x.exact), 0::bigint,
  'another Space''s prefix finds no number');
select is((select count(*) from pg_temp.found('a2', '11')
             as x(post_id uuid, exact boolean, ref text)), 0::bigint,
  'another Team''s post is never found, even by its number');
select is((select array_agg(x.post_id) from pg_temp.found('a3', '11')
             as x(post_id uuid, exact boolean, ref text) where x.exact),
  array[pg_temp.id('b013')], 'its Team finds it');
select is((select count(*) from pg_temp.found('a4', '2')
             as x(post_id uuid, exact boolean, ref text)), 0::bigint,
  'someone not in the Space gets nothing');
select is((select count(*) from pg_temp.found('a2', '999')
             as x(post_id uuid, exact boolean, ref text)), 0::bigint,
  'a number no post has: nothing');

-- The exact hit comes first, then the words.
select pg_temp.as_user('a1');
set local role authenticated;
select public.create_space_post(pg_temp.id('b016'), pg_temp.sp(), 'note', 'Bay 2 cleared');
reset role;
select is((select x.post_id from pg_temp.found('a2', '2') as x(post_id uuid, exact boolean, ref text)
           limit 1), pg_temp.id('b002'), 'the number first');
select is((select count(*) from pg_temp.found('a2', '2') as x(post_id uuid, exact boolean, ref text)
           where x.exact), 1::bigint, 'one exact hit');
select is((select x.ref from pg_temp.found('a2', 'Gate 2') as x(post_id uuid, exact boolean, ref text)
           where x.post_id = pg_temp.id('b001')), pg_temp.prefix() || '-001',
  'a word hit on a note carries its ref');
select is((select count(*) from pg_temp.found('a2', 'G') as x(post_id uuid, exact boolean, ref text)),
  0::bigint, 'one letter still finds nothing');
select ok(not has_function_privilege('anon', 'public.search_space(uuid, text)', 'execute'),
  'signed out: no search');

select * from finish();
rollback;
