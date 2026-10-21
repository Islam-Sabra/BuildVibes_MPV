-- Migration 37: a target's work items fold into its card (review 77,
-- slice 6).
-- Run with: supabase test db
--
-- Omar (e1) made the Space and walks the site. Rakesh (e2) and Sara (e3)
-- are Crew and own the photos' work items, Vera (e4) a Viewer. Eve (e5) is
-- not in the Space.

begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000037' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@target37.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('e1'), ('e2'), ('e3'), ('e4'), ('e5')) x(id);
update public.profiles p set first_name = n.f, last_name = n.l
from (values ('e1', 'Omar', 'Haddad'), ('e2', 'Rakesh', 'Nair'), ('e3', 'Sara', 'Ali'),
             ('e4', 'Vera', 'Lane'), ('e5', 'Eve', 'Out')) n(id, f, l)
where p.id = ('00000000-0000-0000-0000-0000000037' || n.id)::uuid;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000037' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.uid(p_id text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-0000000037' || p_id)::uuid;
$$;
create function pg_temp.item(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000037' || p)::uuid;
$$;
create function pg_temp.sp() returns uuid language sql as $$
  select current_setting('test.space')::uuid;
$$;
create function pg_temp.post_path(p_post text, p_file text) returns text language sql as $$
  select current_setting('test.space') || '/posts/' || pg_temp.item(p_post) || '/' || p_file;
$$;
create function pg_temp.upload(p_who text, p_path text) returns text language sql as $$
  insert into storage.objects (bucket_id, name, owner_id, metadata)
  values ('space-files', p_path, pg_temp.uid(p_who)::text,
          jsonb_build_object('mimetype', 'image/jpeg', 'size', 1000))
  returning name;
$$;
-- A walk's items: ids a01.., each with its photo, for [p_owners].
create function pg_temp.walk(p_prefix text, p_owners text[]) returns jsonb language sql as $$
  select jsonb_agg(jsonb_build_object(
           'id', pg_temp.item(p_prefix || lpad(n::text, 2, '0')),
           'line', 'Line ' || n, 'owner', pg_temp.uid(o),
           'photo', jsonb_build_object('path',
             pg_temp.post_path(p_prefix || lpad(n::text, 2, '0'), n || '.jpg')))
         order by n)
  from unnest(p_owners) with ordinality u(o, n);
$$;
-- The daybook's ids as [p_who] reads it.
create function pg_temp.ids(p_who text) returns uuid[] language plpgsql as $$
declare v uuid[];
begin
  perform pg_temp.as_user(p_who);
  execute 'set local role authenticated';
  select array_agg(d.id) into v from public.daybook_cards(pg_temp.sp(), null, 100) d;
  execute 'reset role';
  return coalesce(v, '{}');
end;
$$;
create function pg_temp.card(p_who text, p_item text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_who);
  execute 'set local role authenticated';
  select d.card into v from public.daybook_cards(pg_temp.sp(), null, 100) d
  where d.id = pg_temp.item(p_item);
  execute 'reset role';
  return v;
end;
$$;
create function pg_temp.row_need(p_who text, p_parent text, p_item text) returns text language sql as $$
  select r ->> 'needs_me'
  from jsonb_array_elements(pg_temp.card(p_who, p_parent) -> 'children' -> 'rows') r
  where r ->> 'id' = pg_temp.item(p_item)::text;
$$;

-- Setup -----------------------------------------------------------------------------------------
-- a00: Omar's walk of three photos (a01, a02 for Rakesh, a03 for Sara).
-- b00: Omar's work item for Rakesh, with b01 under it (not a target: its
-- owner isn't its author). c00: a walk of 12 photos.
select pg_temp.as_user('e1');
set local role authenticated;
select set_config('test.space', public.create_space('Target site')::text, true);
reset role;
insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select pg_temp.sp(), pg_temp.uid(x.id), x.pass, pg_temp.uid('e1')
from (values ('e2', 'crew'), ('e3', 'crew'), ('e4', 'viewer')) x(id, pass);
select pg_temp.upload('e1', pg_temp.post_path('a00' || n, n || '.jpg')) from generate_series(1, 3) n;
select pg_temp.upload('e1', pg_temp.post_path('c0' || lpad(n::text, 2, '0'), n || '.jpg'))
from generate_series(1, 12) n;

select pg_temp.as_user('e1');
set local role authenticated;
select public.create_walk(pg_temp.sp(), pg_temp.item('a000'), 'Walk, level 4',
                          pg_temp.walk('a0', array['e2', 'e2', 'e3']), 'Level 4');
select public.create_work_item(pg_temp.sp(), 'Sleeves at C7', pg_temp.uid('e2'),
                               p_id => pg_temp.item('b000'));
select public.create_work_item(pg_temp.sp(), 'Fire collars', pg_temp.uid('e2'),
                               p_id => pg_temp.item('b001'), p_parent => pg_temp.item('b000'));
select public.create_walk(pg_temp.sp(), pg_temp.item('c000'), 'Walk, roof',
                          pg_temp.walk('c0', array['e2', 'e2', 'e2', 'e2', 'e2', 'e2',
                                                  'e3', 'e3', 'e3', 'e3', 'e3', 'e3']));
reset role;

-- One card per walk --------------------------------------------------------------------------

select ok(pg_temp.item('a000') = any (pg_temp.ids('e2')), 'Rakesh sees the walk');
select ok(not (pg_temp.ids('e2') && array[pg_temp.item('a001'), pg_temp.item('a002'),
                                        pg_temp.item('a003')]),
  'and not its work items as cards of their own');
select ok(not (pg_temp.ids('e1') && array[pg_temp.item('a001'), pg_temp.item('a003')]),
  'nor does Omar, who walked');
select ok(pg_temp.item('a000') = any (pg_temp.ids('e4'))
          and not (pg_temp.ids('e4') && array[pg_temp.item('a001')]),
  'a Viewer: the walk, folded');
select ok(pg_temp.item('b001') = any (pg_temp.ids('e2')),
  'a work item under one that is not a target stays a card of its own');
select is(pg_temp.ids('e5'), '{}'::uuid[], 'someone outside the Space sees nothing');

-- The card's rows ----------------------------------------------------------------------------

select is(pg_temp.card('e2', 'a000') -> 'children' ->> 'target', 'true', 'the walk is a target');
select is(jsonb_array_length(pg_temp.card('e2', 'a000') -> 'children' -> 'rows'), 3,
  'with a row per work item');
select ok((select bool_and(r ? 'ref')
           from jsonb_array_elements(pg_temp.card('e2', 'a000') -> 'children' -> 'rows') r),
  'each with its ref');
select is(pg_temp.row_need('e2', 'a000', 'a001'), 'to_sign', 'Rakesh is asked to sign his row');
select is(pg_temp.row_need('e2', 'a000', 'a003'), null, 'not Sara''s');
select is(pg_temp.row_need('e3', 'a000', 'a003'), 'to_sign', 'Sara is asked to sign hers');
select is(pg_temp.card('e2', 'a000') ->> 'needs_me', null, 'the walk itself asks nobody');
select is(jsonb_array_length(pg_temp.card('e2', 'c000') -> 'children' -> 'rows'), 12,
  'a walk of 12 photos shows all 12 rows (up to 30)');
select is(pg_temp.card('e2', 'b000') -> 'children' ->> 'target', 'false',
  'a work item for someone else, with one under it, is not a target');

-- Activity moves the walk ----------------------------------------------------------------------

update public.space_posts set last_activity_at = now() - interval '1 day'
where id in (pg_temp.item('a000'), pg_temp.item('a001'));
select pg_temp.as_user('e2');
set local role authenticated;
select public.sign_done(pg_temp.item('a001'), 'Fixed.');
reset role;
select ok((select last_activity_at from public.space_posts where id = pg_temp.item('a000'))
          >= (select last_activity_at from public.space_posts where id = pg_temp.item('a001')),
  'a sign-off on a row moves the walk to its time');
select is(pg_temp.row_need('e1', 'a000', 'a001'), 'to_check', 'and Omar is asked to check that row');
select is((pg_temp.card('e1', 'a000') -> 'children' -> 'rows' -> 0 ->> 'item_status'), 'done',
  'the row shows it done');
update public.space_posts set last_activity_at = now() + interval '1 day'
where id = pg_temp.item('a000');
update public.space_posts set last_activity_at = now() where id = pg_temp.item('a002');
select ok((select last_activity_at from public.space_posts where id = pg_temp.item('a000'))
          > now(), 'and never moves it back');

-- One card: a target's work item, from its row --------------------------------------------------

create function pg_temp.one(p_who text, p_item text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_who);
  execute 'set local role authenticated';
  select d.card into v from public.daybook_card(pg_temp.item(p_item)) d;
  execute 'reset role';
  return v;
end;
$$;
select is(pg_temp.one('e2', 'a002') ->> 'parent_id', pg_temp.item('a000')::text,
  'one work item''s card, with the walk that holds it');
select is(pg_temp.one('e2', 'a002') ->> 'needs_me', 'to_sign', 'asking its owner to sign');
select is(pg_temp.one('e4', 'a002') ->> 'needs_me', null, 'a Viewer reads it, asked nothing');
select is(pg_temp.one('e5', 'a002'), null, 'someone outside the Space gets nothing');
select ok(not has_function_privilege('anon', 'public.daybook_card(uuid)', 'execute'),
  'anon may not run it');

-- The trigger's function is the database's only ---------------------------------------------

select ok(not has_function_privilege('authenticated', 'public.post_activity_to_parent()', 'execute'),
  'a signed-in person may not run the trigger''s function');
select ok(not has_function_privilege('anon', 'public.post_activity_to_parent()', 'execute'),
  'nor anon');

select * from finish();
rollback;
