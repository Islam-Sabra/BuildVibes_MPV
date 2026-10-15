-- Scheduled activities: the "starts in 30 min" push (review 33 A2,
-- migration 19).
--
-- NOT RUN. A live change: run it once, with the founder's yes, after
-- migration 19 is live and the push function with the new texts is
-- deployed. Paste it in the Supabase dashboard (SQL editor) for the
-- BuildVibes MVP project.
--
-- No secret: due_activity_reminders() only fills push_queue; the
-- push_queue_call trigger (push_webhook.sql) sends each row, and
-- push-retry retries.

create extension if not exists pg_cron;

-- Every 5 minutes: activities starting in 25 to 35 minutes, once per
-- person and start time.
select cron.schedule('activity-reminders', '*/5 * * * *',
  $job$ select public.due_activity_reminders(); $job$);

-- To check:   select jobname, schedule, active from cron.job;
-- To undo:    select cron.unschedule('activity-reminders');
