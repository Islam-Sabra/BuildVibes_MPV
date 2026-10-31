-- Reminders for someone else and Post later (review 108, migration 57).
--
-- NOT RUN. A live change: run it once, with the founder's yes, after
-- migration 57 (20261117120000) is live and the push function with the
-- two new texts (work_reminder, scheduled_failed) is deployed. Paste it in
-- the Supabase dashboard (SQL editor) for the BuildVibes MVP project.
--
-- No secret: both functions only fill push_queue (and publish posts); the
-- push_queue_call trigger (push_webhook.sql) sends each row, and
-- push-retry retries.

create extension if not exists pg_cron;

-- Every 5 minutes: the reminders due, once per person.
select cron.schedule('work-reminders', '*/5 * * * *',
  $job$ select public.due_work_reminders(); $job$);

-- Every 5 minutes: the scheduled posts due, each as its author.
select cron.schedule('publish-scheduled-posts', '*/5 * * * *',
  $job$ select public.publish_due_posts(); $job$);

-- To check:   select jobname, schedule, active from cron.job;
-- To undo:    select cron.unschedule('work-reminders');
--             select cron.unschedule('publish-scheduled-posts');
