-- Push: call the push function for each new push_queue row (review 22, A1).
--
-- NOT RUN. A live change: run it once, with the founder's yes, after
-- migration 14 is live, the push function is deployed, and the secret is in
-- Vault. Then run push_cron.sql.
--
-- This replaces a dashboard database webhook, which would keep the secret
-- header in plain text in the database catalog (readable by every role, and
-- copied into any dump). Here the secret is read from Vault at call time.
--
-- Before running, replace <project-ref> with the project's reference
-- (Project settings → General). The secret must already be in Vault as
-- push_webhook_secret; it never goes in this file or in git.

create extension if not exists pg_net;

create or replace function public.call_push_function()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Only the row id: the function reads the row from the database.
  perform net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/push',
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-push-secret', (select decrypted_secret from vault.decrypted_secrets
                        where name = 'push_webhook_secret')),
    body := jsonb_build_object('record', jsonb_build_object('id', new.id)),
    timeout_milliseconds := 5000);
  return null;
exception when others then
  -- Never blocks the insert: cron's retry picks the row up.
  raise warning 'push call (queue row %): %', new.id, sqlerrm;
  return null;
end;
$$;

revoke execute on function public.call_push_function() from public, anon, authenticated;

drop trigger if exists push_queue_call on public.push_queue;
create trigger push_queue_call
  after insert on public.push_queue
  for each row execute function public.call_push_function();

-- To check:  select tgname from pg_trigger where tgname = 'push_queue_call';
-- To undo:   drop trigger push_queue_call on public.push_queue;
--            drop function public.call_push_function();
