-- Report alerts: call the report-alert function for each new report
-- (review 23 §2). The same pattern as push_webhook.sql.
--
-- NOT RUN. A live change: run it once, with the founder's yes, after
-- migration 15 is live, the report-alert function is deployed with its
-- secrets, and the secret is in Vault as report_alert_secret (the same
-- value as the function's REPORT_ALERT_SECRET; never in this file or in git).
--
-- Before running, replace <project-ref> with the project's reference.

create extension if not exists pg_net;

create or replace function public.call_report_alert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Only the report's id: the function reads the rest, never the content.
  perform net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/report-alert',
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-alert-secret', (select decrypted_secret from vault.decrypted_secrets
                         where name = 'report_alert_secret')),
    body := jsonb_build_object('record', jsonb_build_object('id', new.id)),
    timeout_milliseconds := 5000);
  return null;
exception when others then
  -- Never blocks the report.
  raise warning 'report alert (report %): %', new.id, sqlerrm;
  return null;
end;
$$;

revoke execute on function public.call_report_alert() from public, anon, authenticated;

drop trigger if exists reports_alert on public.reports;
create trigger reports_alert
  after insert on public.reports
  for each row execute function public.call_report_alert();

-- To check:  select tgname from pg_trigger where tgname = 'reports_alert';
-- To undo:   drop trigger reports_alert on public.reports;
--            drop function public.call_report_alert();
