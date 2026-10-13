# Restoring a backup (review 30 §4)

**For:** whoever has to restore BuildVibes from a backup made by `supabase/ops/backup.ps1`.
The backup has three files: `roles.sql`, `schema.sql` and `data.sql`.

## Practice restore into the local database (done 13 Oct)

The first backup (`D:\BuildVibes backups\2026-10-13\`) was restored into the local database. Every table count matched live: users, profiles, posts, Spaces, notifications, reports, places and markets. The local copy was wiped straight after, because it holds live people's data.

Steps, from the project folder:
1. `supabase db reset --local`. The schema comes from the same migrations as live.
2. Empty the tables the dump fills, as the local superuser. Make a list of `truncate <table> cascade;` from the dump's `COPY` lines, after `set session_replication_role = replica;`, then:
   `docker exec -i supabase_db_BuildVibes_MVP psql -U supabase_admin -d postgres < that-list.sql`
3. Load the data:
   `docker exec -i supabase_db_BuildVibes_MVP psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 < "D:\BuildVibes backups\<date>\data.sql"`
   The dump turns triggers off itself while loading, because `library_files` points to itself.
4. Compare counts with live, then wipe the local copy: `supabase db reset --local`.

## A real restore, into a new Supabase project

1. Create the project, link it (`supabase link`) and push all migrations (`supabase db push`).
2. Load `data.sql` as above, against the new project's database URL.
3. **Not in the backup, so set again with the founder's yes:**
   - the Vault secrets (`push_webhook_secret`, `report_alert_secret`, `account_purge_secret`) and the matching function secrets: generate new ones;
   - the cron jobs and triggers: `supabase/ops/push_webhook.sql`, `push_cron.sql`, `report_alert_webhook.sql` and `account_cron.sql`;
   - the Edge Functions (`push`, `report-alert`, `account-purge`);
   - Auth settings: email code, Resend SMTP, rate limits;
   - the moderation and support addresses: `market_moderation` and `markets.support_email` are in `data.sql`, so check them;
   - Storage files: photos and documents are **not** in the backup (accepted for the pilot).
