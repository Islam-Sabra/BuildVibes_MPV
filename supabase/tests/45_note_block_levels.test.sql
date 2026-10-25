-- Migration 45 (review 93): a note's lines under each other (`indent`, 0
-- to 3) and a numbered line's `start` (1 to 999). Run with: supabase test db
--
-- Omar (f1) owns the notes; Rakesh (f2) is someone else.

begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

insert into auth.users (id, aud, role, email, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000045' || x.id)::uuid, 'authenticated', 'authenticated',
       x.id || '@levels45.example.com', '{"home_market_id": "kw"}'::jsonb
from (values ('f1'), ('f2')) x(id);

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub": "00000000-0000-0000-0000-0000000045' || p_id || '", "role": "authenticated"}', true);
$$;
create function pg_temp.id(p text) returns uuid language sql as $$
  select ('00000000-0000-0000-0000-00000045' || p)::uuid;
$$;
-- A line of [p_type] at [p_indent] (none when null), with [p_extra].
create function pg_temp.b(p_type text, p_indent jsonb default null, p_extra jsonb default '{}')
returns jsonb language sql as $$
  select jsonb_build_object('id', gen_random_uuid(), 'type', p_type)
         || case when p_type in ('divider', 'table', 'voice') then '{}'::jsonb
                 else '{"text": "x"}'::jsonb end
         || case when p_indent is null then '{}'::jsonb
                 else jsonb_build_object('indent', p_indent) end
         || p_extra;
$$;
create function pg_temp.ok_page(variadic p_blocks jsonb[]) returns boolean language sql as $$
  select public.is_valid_note_blocks(to_jsonb(p_blocks));
$$;

-- Grants -----------------------------------------------------------------------------------------

select ok(not has_function_privilege('anon', 'public.is_valid_note_blocks(jsonb)', 'execute'),
  'signed out: no block check');
select ok(has_function_privilege('authenticated', 'public.is_valid_note_blocks(jsonb)', 'execute'),
  'signed in: the block check');

-- Levels -----------------------------------------------------------------------------------------

select ok(pg_temp.ok_page(pg_temp.b('text'), pg_temp.b('bullet')), 'an old page, no levels, is fine');
select ok(pg_temp.ok_page(pg_temp.b('numbered', '0'), pg_temp.b('numbered', '1'),
                          pg_temp.b('numbered', '2'), pg_temp.b('numbered', '3')),
  'levels 0 to 3, one deeper each time');
select ok(pg_temp.ok_page(pg_temp.b('todo', '0'), pg_temp.b('todo', '1'), pg_temp.b('todo', '2'),
                          pg_temp.b('callout', '0')), 'back out any number of levels at once');
select ok(not pg_temp.ok_page(pg_temp.b('numbered', '0'), pg_temp.b('numbered', '1'),
                              pg_temp.b('numbered', '2'), pg_temp.b('numbered', '3'),
                              pg_temp.b('numbered', '4')), 'level 4 is refused');
select ok(not pg_temp.ok_page(pg_temp.b('text', '1')), 'the first line is at 0');
select ok(not pg_temp.ok_page(pg_temp.b('text', '0'), pg_temp.b('text', '2')),
  'never two deeper than the line before');
select ok(not pg_temp.ok_page(pg_temp.b('text', '0'), pg_temp.b('text', '-1')), 'not below 0');
select ok(not pg_temp.ok_page(pg_temp.b('text', '0'), pg_temp.b('text', '"1"')), 'a number, not words');
select ok(not pg_temp.ok_page(pg_temp.b('text', '0'), pg_temp.b('text', '1.5')), 'a whole number');
select ok(not pg_temp.ok_page(pg_temp.b('text', '0'), pg_temp.b('text', 'null')), 'not empty');
select ok(pg_temp.ok_page(pg_temp.b('text'), pg_temp.b('heading', '1', '{"level": 2}')),
  'a heading keeps its size and takes a level');
select ok(pg_temp.ok_page(pg_temp.b('text'), pg_temp.b('divider', '1'),
                          pg_temp.b('table', '1', '{"rows": [["a"]]}'),
                          pg_temp.b('voice', '1', '{"path": "p", "duration_ms": 1}')),
  'a divider, a table and a voice note take a level');
select ok(pg_temp.ok_page(pg_temp.b('text'),
                          pg_temp.b('toggle', '1', jsonb_build_object('children',
                                    jsonb_build_array(pg_temp.b('text'))))),
  'a toggle takes a level; its lines stay inside it');
select ok(not pg_temp.ok_page(pg_temp.b('toggle', null, jsonb_build_object('children',
                                        jsonb_build_array(pg_temp.b('text', '1'))))),
  'a toggle''s own line has no level');
select ok(pg_temp.ok_page(pg_temp.b('toggle', null, jsonb_build_object('children',
                                    jsonb_build_array(pg_temp.b('text', '0'))))),
  'level 0 inside a toggle is fine');

-- Where a count starts ---------------------------------------------------------------------------

select ok(pg_temp.ok_page(pg_temp.b('numbered', null, '{"start": 1}')), 'Restart at 1');
select ok(pg_temp.ok_page(pg_temp.b('numbered', null, '{"start": 999}')), 'up to 999');
select ok(not pg_temp.ok_page(pg_temp.b('numbered', null, '{"start": 0}')), 'a start of 0 is refused');
select ok(not pg_temp.ok_page(pg_temp.b('numbered', null, '{"start": 1000}')), 'nor 1000');
select ok(not pg_temp.ok_page(pg_temp.b('numbered', null, '{"start": -3}')), 'nor below 1');
select ok(not pg_temp.ok_page(pg_temp.b('numbered', null, '{"start": 2.5}')), 'a whole number');
select ok(not pg_temp.ok_page(pg_temp.b('numbered', null, '{"start": "3"}')), 'a number, not words');
select ok(not pg_temp.ok_page(pg_temp.b('bullet', null, '{"start": 3}')), 'only a numbered line starts');

-- save_note keeps them; the owner alone reads them ---------------------------------------------

select pg_temp.as_user('f1');
set local role authenticated;

select lives_ok($$select public.save_note(p_id => pg_temp.id('c001'), p_kind => 'text',
  p_body => 'Pour', p_blocks => jsonb_build_array(
    jsonb_build_object('id', 'c0000000-0000-4000-8000-000000000001', 'type', 'numbered', 'text', 'Pour'),
    jsonb_build_object('id', 'c0000000-0000-4000-8000-000000000002', 'type', 'callout',
                       'text', 'Rain', 'indent', 1),
    jsonb_build_object('id', 'c0000000-0000-4000-8000-000000000003', 'type', 'numbered',
                       'text', 'Strip', 'start', 3)))$$,
  'save_note takes levels and a start');
select is((select blocks -> 1 -> 'indent' from public.notes where id = pg_temp.id('c001')),
  '1'::jsonb, 'the level is kept');
select is((select blocks -> 2 -> 'start' from public.notes where id = pg_temp.id('c001')),
  '3'::jsonb, 'the start is kept');
select throws_ok($$select public.save_note(p_id => pg_temp.id('c002'), p_kind => 'text',
  p_body => 'x', p_blocks => jsonb_build_array(pg_temp.b('text'), pg_temp.b('text', '1'),
                                               pg_temp.b('text', '2'), pg_temp.b('text', '3'),
                                               pg_temp.b('text', '4')))$$,
  '22023', null, 'save_note refuses level 4');
select throws_ok($$select public.save_note(p_id => pg_temp.id('c003'), p_kind => 'text',
  p_body => 'x', p_blocks => jsonb_build_array(pg_temp.b('numbered', null, '{"start": 0}')))$$,
  '22023', null, 'save_note refuses a start of 0');
select throws_ok($$update public.notes set blocks = '[]' where id = pg_temp.id('c001')$$,
  '42501', null, 'a note is written only through save_note');

reset role;
select throws_ok($$update public.notes set blocks = jsonb_build_array(pg_temp.b('text', '1'))
  where id = pg_temp.id('c001')$$, '23514', null, 'the table''s own check refuses a bad level too');

select pg_temp.as_user('f2');
set local role authenticated;
select is((select count(*) from public.notes where id = pg_temp.id('c001')), 0::bigint,
  'someone else can''t read the note');

reset role;
select * from finish();
rollback;
