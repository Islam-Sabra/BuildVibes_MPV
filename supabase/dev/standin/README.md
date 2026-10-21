# SQL stand-in (for sessions without the Supabase CLI)

Plain Postgres 16 with pgTAP and a small shim for what the migrations use from Supabase: the roles, `auth.users` and `auth.uid()`, `storage.buckets` and `storage.objects` (with the delete guard), and `realtime.messages` with `realtime.topic()`. It is for the SQL checks only. The real check is still `supabase test db`, and anything that touches Realtime itself is checked against the local Realtime server.

```
apt-get install -y postgresql-16-pgtap
pg_ctlcluster 16 main start
supabase/dev/standin/run.sh "$PWD"     # drops and rebuilds database "bv", applies every migration, runs every test file
```

The `postgres` user must be able to read the repo and this folder.
