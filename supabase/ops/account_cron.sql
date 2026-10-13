-- Accounts and reports: the nightly cleanup (review 23 §3, §10).
--
-- NOT RUN. A live change: run it once, with the founder's yes, after
-- migration 16 is live and the account-purge function is deployed. Paste it
-- in the Supabase dashboard (SQL editor) for the BuildVibes MVP project.
--
-- Before running, replace:
--   <project-ref>  the project's reference (Project settings → General).
-- The secret must already be in Vault as account_purge_secret (the same
-- value as the function's ACCOUNT_PURGE_SECRET). It never goes in this file
-- or in git.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Nightly at 02:45 UTC: accounts asked to be deleted over 30 days ago go
-- for good (their stored photos first, then the account).
select cron.schedule(
  'account-purge',
  '45 2 * * *',
  $job$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/account-purge',
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-purge-secret', (select decrypted_secret from vault.decrypted_secrets
                         where name = 'account_purge_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000);
  $job$
);

-- Nightly at 03:00 UTC: reports decided over 12 months ago.
select cron.schedule('reports-prune', '0 3 * * *', $job$ select public.prune_reports(); $job$);

-- To check:   select jobname, schedule, active from cron.job;
-- To undo:    select cron.unschedule('account-purge'); select cron.unschedule('reports-prune');
