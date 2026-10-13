-- Push: retry every minute, clean up nightly (review 21, fix 2).
--
-- NOT RUN. A live change: run it once, with the founder's yes, after
-- migration 14 is live and the push function is deployed. Paste it in the
-- Supabase dashboard (SQL editor) for the BuildVibes MVP project.
--
-- Before running, replace:
--   <project-ref>  the project's reference (Project settings → General).
-- The webhook secret must already be in Vault as push_webhook_secret (the
-- same value as the function's PUSH_WEBHOOK_SECRET). It never goes in this
-- file or in git.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Every minute: rows unsent for over a minute (under an hour old, fewer
-- than 5 attempts) go to the function again, one call each, like the
-- insert trigger (push_webhook.sql) does.
select cron.schedule(
  'push-retry',
  '* * * * *',
  $job$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/push',
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-push-secret', (select decrypted_secret from vault.decrypted_secrets
                        where name = 'push_webhook_secret')),
    body := jsonb_build_object('record', jsonb_build_object('id', r.id)),
    timeout_milliseconds := 5000)
  from public.retry_push_queue() r;
  $job$
);

-- Nightly at 02:30 UTC: rows over a day old, and phones not seen for 60 days.
select cron.schedule('push-prune', '30 2 * * *', $job$ select public.prune_push_queue(); $job$);

-- To check:   select jobname, schedule, active from cron.job;
-- To undo:    select cron.unschedule('push-retry'); select cron.unschedule('push-prune');
