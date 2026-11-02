-- Check-in (review 109): the opening pushes and the creator's summary, and
-- the day's report into the Library.
--
-- NOT RUN. A live change: run it once, with the founder's yes, after
-- migration 59 (20261120120000) is live, the push function with the
-- check_in_open and check_in_summary texts is deployed, and the
-- check-in-report function is deployed with its secret. Paste it in the
-- Supabase dashboard (SQL editor) for the BuildVibes MVP project.
--
-- Before running, replace:
--   <project-ref>  the project's reference (Project settings → General).
-- The secret must already be in Vault as check_in_report_secret (the same
-- value as the function's CHECK_IN_REPORT_SECRET). It never goes in this
-- file or in git.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Every minute: check-in and check-out opening pushes, once per day per
-- window, and the summary when check-in closes. Only fills push_queue; the
-- push_queue_call trigger (push_webhook.sql) sends each row.
select cron.schedule('check-in-notify', '* * * * *',
  $job$ select public.check_in_notify(); $job$);

-- Every 15 minutes: a job for each check-in whose day has ended in its
-- Space's time zone; the function is called only when one is waiting.
select cron.schedule(
  'check-in-daily-report',
  '*/15 * * * *',
  $job$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/check-in-report',
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-report-secret', (select decrypted_secret from vault.decrypted_secrets
                          where name = 'check_in_report_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000)
  where public.check_in_daily_report() > 0;
  $job$
);

-- Review 113 (17), after migration 60 (20261121120000) is live and the push
-- function with the check_in_nudge text is deployed. Every minute: the
-- Lead's nudge when a Space that used check-in has none 30 minutes before
-- its usual time, once per Space per day. Only fills push_queue.
select cron.schedule('check-in-nudge', '* * * * *',
  $job$ select public.check_in_nudge(); $job$);

-- To check:   select jobname, schedule, active from cron.job;
-- To undo:    select cron.unschedule('check-in-notify');
--             select cron.unschedule('check-in-daily-report');
--             select cron.unschedule('check-in-nudge');
