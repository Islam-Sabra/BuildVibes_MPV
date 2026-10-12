-- Local test data for the feed (week 7). Run after seed_work_items.sql:
--   docker exec -i supabase_db_BuildVibes_MVP psql -U postgres -d postgres < supabase/dev/seed_feed.sql
-- Omar (…01), Sami (…02), Rakesh (…03). Rakesh has Kuwait City Tower on his
-- CV, confirmed by Omar, so he may tag it.

begin;

select set_config('seed.project', (select id from public.projects where name = 'Kuwait City Tower')::text, true);

insert into public.cv_projects (id, profile_id, project_id, role_title, start_month)
values ('22222222-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000003',
        current_setting('seed.project')::uuid, 'MEP Foreman', '2025-03-01')
on conflict do nothing;
insert into public.cv_project_confirmations (cv_project_id, confirmed_by, source)
values ('22222222-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'teammate')
on conflict do nothing;
-- Sami follows Omar, so he sees Omar's name on the proof line.
insert into public.follows (follower_id, followee_id)
values ('11111111-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001')
on conflict do nothing;

insert into public.posts (id, author_id, body, lang, project_id, market_id, created_at) values
  ('33333333-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001',
   'First pour on the podium transfer slab is done. Thanks to the concrete crew for a clean night shift.',
   'en', current_setting('seed.project')::uuid, 'kw', now() - interval '3 hours'),
  ('33333333-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000002',
   'تم اليوم: مراجعة التعارضات للأدوار 20 إلى 28.' || chr(10) || 'التالي: تسليم النموذج المحدّث لفريق التنفيذ.',
   'ar', null, 'kw', now() - interval '5 hours'),
  ('33333333-0000-0000-0000-000000000003', '11111111-0000-0000-0000-000000000002',
   'Sharing our BEP checklist for ISO 19650 handovers. Ask me if you want the template.',
   'en', null, 'kw', now() - interval '40 days');

-- Rakesh found Omar's pour useful; Sami replied.
insert into public.useful_marks (target_kind, target_id, profile_id)
values ('post', '33333333-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000003');
insert into public.post_replies (id, post_id, author_id, body, created_at)
values ('44444444-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001',
        '11111111-0000-0000-0000-000000000002', 'Good work. Was the sleeve size confirmed with MEP?',
        now() - interval '1 hour');

commit;

select count(*) as posts from public.posts;
