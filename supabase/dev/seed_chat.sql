-- Local test data for Space chat (week 6). Run after seed_work_items.sql:
--   docker exec -i supabase_db_BuildVibes_MVP psql -U postgres -d postgres < supabase/dev/seed_chat.sql
-- Omar (…01) is the Space admin, Sami (…02) Lead, Rakesh (…03) Crew in
-- the MEP Team. Work item cards are already there: the server posted them.

begin;

create function pg_temp.say(p_who text, p_thread uuid, p_body text,
  p_ago interval, p_reply uuid default null)
returns uuid language plpgsql as $$
declare
  v_id uuid := gen_random_uuid();
begin
  perform set_config('request.jwt.claims',
    '{"sub": "11111111-0000-0000-0000-0000000000' || p_who || '", "role": "authenticated"}', true);
  set local role authenticated;
  perform public.post_message(v_id, p_thread, p_body, p_reply);
  reset role;
  update public.messages set created_at = now() - p_ago where id = v_id;
  return v_id;
end;
$$;

-- The work items were raised earlier this morning: their cards too.
update public.messages set created_at = now() - interval '1 hour'
where kind = 'work_item';

select set_config('seed.everyone', (select t.id from public.threads t
  join public.spaces s on s.id = t.space_id
  where s.name = 'Site team' and t.team_id is null)::text, true);
select set_config('seed.mep', (select t.id from public.threads t
  join public.teams tm on tm.id = t.team_id where tm.name = 'MEP Team')::text, true);

select pg_temp.say('01', current_setting('seed.everyone')::uuid,
  'Friday site walk is still on. Meet at the gate office at 7.', interval '28 minutes');
select set_config('seed.gate', pg_temp.say('03', current_setting('seed.everyone')::uuid,
  'Gate 2 is blocked by the crane. Use gate 3.', interval '25 minutes')::text, true);
select pg_temp.say('02', current_setting('seed.everyone')::uuid,
  'Noted. I''ll bring the level 3 drawings.', interval '20 minutes');
select pg_temp.say('01', current_setting('seed.everyone')::uuid,
  'Thanks, I''ll tell the pump truck driver.', interval '18 minutes',
  current_setting('seed.gate')::uuid);

-- Rakesh posts in the wrong thread, then deletes it.
select set_config('seed.oops', pg_temp.say('03', current_setting('seed.everyone')::uuid,
  'Upstand photos tomorrow', interval '15 minutes')::text, true);
select set_config('request.jwt.claims',
  '{"sub": "11111111-0000-0000-0000-000000000003", "role": "authenticated"}', true);
set local role authenticated;
select public.delete_message(current_setting('seed.oops')::uuid);
reset role;

select pg_temp.say('03', current_setting('seed.mep')::uuid,
  'Need photos of the upstand before second coat.', interval '12 minutes');
select pg_temp.say('01', current_setting('seed.mep')::uuid,
  'Sending after the walk.', interval '9 minutes');
select pg_temp.say('03', current_setting('seed.mep')::uuid,
  'OK. The north wall first, please.', interval '5 minutes');

commit;

select t.team_id is null as everyone, count(*) as messages
from public.messages m join public.threads t on t.id = m.thread_id
group by 1 order by 1 desc;
