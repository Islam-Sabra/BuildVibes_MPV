-- The notebook's Deleted items: the nightly purge (review 99B B3).
--
-- NOT RUN. A live change: run it once, with the founder's yes, after
-- migration 48 is live and the notebook-purge function is deployed. Paste it
-- in the Supabase dashboard (SQL editor) for the BuildVibes MVP project.
--
-- Before running, replace:
--   <project-ref>  the project's reference (Project settings → General).
-- The secret must already be in Vault as notebook_purge_secret (the same
-- value as the function's NOTEBOOK_PURGE_SECRET). It never goes in this file
-- or in git.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Nightly at 03:15 UTC: what has been in Deleted items longer than its
-- owner keeps them (7, 30 or 90 days) goes for good, then its files.
select cron.schedule(
  'notebook-purge',
  '15 3 * * *',
  $job$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/notebook-purge',
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-purge-secret', (select decrypted_secret from vault.decrypted_secrets
                         where name = 'notebook_purge_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000);
  $job$
);

-- To check:   select jobname, schedule, active from cron.job;
-- To undo:    select cron.unschedule('notebook-purge');
