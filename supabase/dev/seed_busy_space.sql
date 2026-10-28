-- LOCAL ONLY (review 101 A): a busy Space and a full notebook, to try the
-- long lists by hand. Never run on the live project, and not part of
-- config.toml's automatic seed. Run on the local database (after a reset,
-- or next to the other dev seeds; its ids are its own):
--   docker exec -i supabase_db_BuildVibes_MVP psql -U postgres -d postgres -q < supabase/dev/seed_busy_space.sql
--
-- Sign in with one of these; the 6-digit code arrives in the local mail
-- catcher (Mailpit, http://127.0.0.1:54324). Every address is @example.com,
-- never a real one.
--   busy.lead@example.com    Hana Saleh, site engineer: Space admin, Lead;
--                            her notebook holds the 300 entries
--   busy.second@example.com  Tarek Nabil, site engineer: Lead
--   busy.foreman@example.com Faisal Darwish, foreman: Crew
--   busy.viewer@example.com  Noura Ali, client representative: Viewer
--
-- The Space "Busy site — test week" holds 500 posts over the last 30 days,
-- one every 86 minutes, of every kind in turn: work item, checklist,
-- announcement, activity, file and daily report. Every fourth work item is
-- signed as done with a photo, every eighth also checked; every fourth
-- announcement has a photo. Photos and files are seed rows only: nothing is
-- uploaded, so the app shows their grey places and the files don't open.
-- The notebook: 5 pages of 60 entries each, over the same 30 days.
\set ON_ERROR_STOP on
begin;

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
  raw_user_meta_data, raw_app_meta_data, confirmation_token, recovery_token,
  email_change_token_new, email_change, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', u.id::uuid, 'authenticated', 'authenticated',
       u.email, now(), '{"home_market_id": "kw", "locale": "en"}',
       '{"provider": "email", "providers": ["email"]}', '', '', '', '', now(), now()
from (values
  ('b05e0000-0000-0000-0000-000000000001', 'busy.lead@example.com'),
  ('b05e0000-0000-0000-0000-000000000002', 'busy.second@example.com'),
  ('b05e0000-0000-0000-0000-000000000003', 'busy.foreman@example.com'),
  ('b05e0000-0000-0000-0000-000000000004', 'busy.viewer@example.com')
) as u (id, email);
insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at, last_sign_in_at)
select gen_random_uuid(), u.id, u.id::text,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
from auth.users u where u.id::text like 'b05e0000-%';

update public.profiles p set first_name = v.first_name, last_name = v.last_name,
  trade_id = v.trade_id, headline = v.headline
from (values
  ('b05e0000-0000-0000-0000-000000000001', 'Hana', 'Saleh', 'site_engineer', 'Site engineer'),
  ('b05e0000-0000-0000-0000-000000000002', 'Tarek', 'Nabil', 'site_engineer', null),
  ('b05e0000-0000-0000-0000-000000000003', 'Faisal', 'Darwish', 'foreman', 'Foreman'),
  ('b05e0000-0000-0000-0000-000000000004', 'Noura', 'Ali', 'other', 'Client representative')
) as v (id, first_name, last_name, trade_id, headline)
where p.id = v.id::uuid;

-- As Hana: the project and the Space, on site since 30 days ago.
select set_config('request.jwt.claims', '{"sub": "b05e0000-0000-0000-0000-000000000001", "role": "authenticated"}', false);
set role authenticated;
select set_config('busy.project', public.create_project('Busy site', 'commercial', 'kw', 'kw-capital')::text, false);
select set_config('busy.space', public.create_space('Busy site — test week',
  'Thirty days of site work, to try the long Daybook.', current_setting('busy.project')::uuid)::text, false);
select public.set_site_start_date(current_setting('busy.space')::uuid, current_date - 30);
reset role;

insert into public.space_members (space_id, profile_id, pass, confirmed_by)
select current_setting('busy.space')::uuid, m.id::uuid, m.pass, 'b05e0000-0000-0000-0000-000000000001'
from (values
  ('b05e0000-0000-0000-0000-000000000002', 'lead'),
  ('b05e0000-0000-0000-0000-000000000003', 'crew'),
  ('b05e0000-0000-0000-0000-000000000004', 'viewer')
) as m (id, pass);

-- The drawings the file posts carry, one each (i = 4, 10, 16 … 496).
insert into public.library_files (id, space_id, name, storage_path, mime, bytes, rev_label, uploaded_by)
select ('b05e0000-0000-0000-0001-' || lpad(i::text, 12, '0'))::uuid,
       current_setting('busy.space')::uuid,
       'Drawing ' || i || '.pdf',
       current_setting('busy.space') || '/library/b05e0000-0000-0000-0001-' || lpad(i::text, 12, '0')
         || '/Drawing ' || i || '.pdf',
       'application/pdf', 1200000, 'Rev A', 'b05e0000-0000-0000-0000-000000000001'
from generate_series(4, 499, 6) as i;

-- The 500 posts, by the two Leads in turn; post i is i × 86 minutes old
-- (its times are set after: the functions stamp "now").
set role authenticated;
do $$
declare
  v_space uuid := current_setting('busy.space')::uuid;
  v_foreman uuid := 'b05e0000-0000-0000-0000-000000000003';
  v_author text;
  v_id uuid;
begin
  for i in 0..499 loop
    v_author := case when i % 2 = 0 then 'b05e0000-0000-0000-0000-000000000001'
                     else 'b05e0000-0000-0000-0000-000000000002' end;
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_author, 'role', 'authenticated')::text, true);
    v_id := ('b05e0000-0000-0000-0002-' || lpad(i::text, 12, '0'))::uuid;
    case i % 6
      when 0 then
        perform public.create_work_item(
          p_space => v_space,
          p_title => 'Work item ' || i || ', level ' || (i % 9 + 1),
          p_owner => v_foreman,
          p_place => 'Level ' || (i % 9 + 1) || ', grid ' || chr(65 + i % 8) || (i % 12 + 1),
          p_id => v_id);
      when 1 then
        perform public.create_space_post(
          p_id => v_id, p_space => v_space, p_kind => 'checklist',
          p_title => 'Checklist ' || i,
          p_people => array[v_foreman],
          p_points => '[{"text": "Area clear"}, {"text": "Tools back"}, {"text": "Photos taken"}]');
      when 2 then
        perform public.create_space_post(
          p_id => v_id, p_space => v_space, p_kind => 'announcement',
          p_title => 'Announcement ' || i,
          p_body => 'Gate 2 closed from 13:00 for the crane lift.');
      when 3 then
        perform public.create_space_post(
          p_id => v_id, p_space => v_space, p_kind => 'activity',
          p_title => 'Concrete pour ' || i,
          p_place => 'Level ' || (i % 9 + 1),
          p_starts_at => now() + interval '1 day');
      when 4 then
        perform public.create_space_post(
          p_id => v_id, p_space => v_space, p_kind => 'file',
          p_library_file => ('b05e0000-0000-0000-0001-' || lpad(i::text, 12, '0'))::uuid);
      else
        perform public.create_space_post(
          p_id => v_id, p_space => v_space, p_kind => 'report',
          p_title => 'Daily report ' || i,
          p_body => 'On site: steel fixers 12, electricians 6.');
    end case;
  end loop;

  -- The foreman signs every fourth work item; the author checks every
  -- eighth.
  for i in 0..499 by 24 loop
    perform set_config('request.jwt.claims',
      '{"sub": "b05e0000-0000-0000-0000-000000000003", "role": "authenticated"}', true);
    perform public.sign_done(('b05e0000-0000-0000-0002-' || lpad(i::text, 12, '0'))::uuid,
      'Done, photo attached.');
    if i % 48 = 0 then
      perform set_config('request.jwt.claims',
        '{"sub": "b05e0000-0000-0000-0000-000000000001", "role": "authenticated"}', true);
      perform public.check_item(('b05e0000-0000-0000-0002-' || lpad(i::text, 12, '0'))::uuid);
    end if;
  end loop;
end;
$$;
reset role;

-- The photos: on each sign-off, and on every fourth announcement.
insert into public.work_item_evidence (event_id, work_item_id, storage_path, taken_at, place_text)
select e.id, e.work_item_id,
       current_setting('busy.space') || '/' || e.work_item_id || '/proof.jpg',
       now(), 'On site'
from public.work_item_events e
join public.space_posts p on p.id = e.work_item_id
where p.space_id = current_setting('busy.space')::uuid and e.kind = 'done';
insert into public.post_files (post_id, storage_path, added_by, mime, width, height)
select p.id, current_setting('busy.space') || '/posts/' || p.id || '/photo.jpg',
       p.author_id, 'image/jpeg', 1600, 1200
from public.space_posts p
where p.space_id = current_setting('busy.space')::uuid and p.kind = 'announcement'
  and right(p.id::text, 12)::int % 24 = 2;

-- Each post at its own time, 86 minutes apart; its events after it.
update public.space_posts p
set created_at = now() - right(p.id::text, 12)::int * interval '86 minutes'
where p.space_id = current_setting('busy.space')::uuid;
update public.space_posts p
set starts_at = p.created_at + interval '1 hour'
where p.space_id = current_setting('busy.space')::uuid and p.kind = 'activity';
update public.work_items w set created_at = p.created_at
from public.space_posts p where p.id = w.id and p.space_id = current_setting('busy.space')::uuid;
-- Events are append-only; a seed is the one exception.
alter table public.work_item_events disable trigger work_item_events_append_only;
update public.work_item_events e
set created_at = least(now(), p.created_at + case e.kind
    when 'done' then interval '40 minutes'
    when 'checked' then interval '70 minutes'
    else interval '0' end)
from public.space_posts p
where p.id = e.work_item_id and p.space_id = current_setting('busy.space')::uuid;
alter table public.work_item_events enable trigger work_item_events_append_only;
update public.work_item_evidence v set taken_at = e.created_at
from public.work_item_events e
where e.id = v.event_id and v.storage_path like current_setting('busy.space') || '/%';
alter table public.post_edits disable trigger post_edits_append_only;
update public.post_edits pe set created_at = p.created_at
from public.space_posts p
where p.id = pe.post_id and p.space_id = current_setting('busy.space')::uuid;
alter table public.post_edits enable trigger post_edits_append_only;
update public.post_files f set created_at = p.created_at
from public.space_posts p
where p.id = f.post_id and p.space_id = current_setting('busy.space')::uuid;
update public.work_items w set done_at = e.created_at
from public.work_item_events e, public.space_posts p
where e.work_item_id = w.id and e.kind = 'done'
  and p.id = w.id and p.space_id = current_setting('busy.space')::uuid;
update public.work_items w set checked_at = e.created_at
from public.work_item_events e, public.space_posts p
where e.work_item_id = w.id and e.kind = 'checked'
  and p.id = w.id and p.space_id = current_setting('busy.space')::uuid;
-- Each post's last activity, worked out again from its new times, as
-- migration 26's back-fill does.
update public.space_posts p
set last_activity_at = greatest(
  p.created_at,
  p.cancelled_at,
  (select max(e.created_at) from public.work_item_events e where e.work_item_id = p.id),
  (select max(pe.created_at) from public.post_edits pe where pe.post_id = p.id))
where p.space_id = current_setting('busy.space')::uuid;

-- Hana's notebook: 5 pages, 60 entries each; entry j is j × 144 minutes
-- old, in page j % 5.
set role authenticated;
select set_config('request.jwt.claims', '{"sub": "b05e0000-0000-0000-0000-000000000001", "role": "authenticated"}', false);
select count(public.create_notebook_page(
  ('b05e0000-0000-0000-0003-' || lpad(k::text, 12, '0'))::uuid, v.title, null, 'notebook')) as pages
from (values (0, 'Site A – Tower'), (1, 'Site B – Villa'), (2, 'Meetings'),
             (3, 'Phone numbers'), (4, 'Snags')) as v (k, title);
select count(public.save_entry(
  p_id => ('b05e0000-0000-0000-0004-' || lpad(j::text, 12, '0'))::uuid,
  p_kind => 'text',
  p_page => ('b05e0000-0000-0000-0003-' || lpad((j % 5)::text, 12, '0'))::uuid,
  p_title => 'Entry ' || j,
  p_body => 'Checked the formwork at grid ' || chr(65 + j % 8) || (j % 12 + 1) || '.')) as entries
from generate_series(0, 299) as j;
reset role;
update public.notes n
set created_at = now() - right(n.id::text, 12)::int * interval '144 minutes'
where n.id::text like 'b05e0000-0000-0000-0004-%';

commit;

select p.kind, count(*), min(p.created_at)::date as first_day, max(p.created_at)::date as last_day
from public.space_posts p
where p.space_id = current_setting('busy.space')::uuid
group by p.kind order by p.kind;
select pg.title, count(n.id) as entries
from public.notebook_pages pg left join public.notes n on n.page_id = pg.id
where pg.id::text like 'b05e0000-0000-0000-0003-%'
group by pg.title order by pg.title;
