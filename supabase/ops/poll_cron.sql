-- Polls: close those whose time has passed (review 116, migration 66).
--
-- NOT RUN. A live change: run it once, with the founder's yes, after
-- migration 20261125120000_review116_poll is live and the push function
-- with the poll texts is deployed. Paste it in the Supabase dashboard (SQL
-- editor) for the BuildVibes MVP project.
--
-- No secret: close_due_polls() closes each poll, stamps the most chosen
-- option, and tells its creator (poll_closed, or poll_tied for a tie); the
-- notification's push goes through push_queue as every other.

create extension if not exists pg_cron;

-- Every 5 minutes: the polls whose closing time has passed.
select cron.schedule('poll-close', '*/5 * * * *',
  $job$ select public.close_due_polls(); $job$);

-- To check:   select jobname, schedule, active from cron.job;
-- To undo:    select cron.unschedule('poll-close');
