-- Minimal Supabase stand-in for running migrations and pgTAP tests on plain Postgres 16.
do $$ declare r text; begin
  foreach r in array array['anon','authenticated','service_role','authenticator','supabase_admin',
    'supabase_auth_admin','supabase_storage_admin','supabase_realtime_admin','dashboard_user'] loop
    if not exists (select 1 from pg_roles where rolname = r) then execute format('create role %I nologin', r); end if;
  end loop; end $$;
alter role service_role bypassrls;
grant anon, authenticated, service_role to authenticator;
create schema if not exists extensions; create schema if not exists auth; create schema if not exists storage; create schema if not exists realtime;
grant usage on schema public, extensions, auth, storage, realtime to anon, authenticated, service_role;
grant usage on schema auth to supabase_auth_admin; grant all on schema public to supabase_auth_admin;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;
alter database postgres set search_path = "$user", public, extensions;
set search_path = "$user", public, extensions;

create table auth.users (
  instance_id uuid, id uuid primary key default gen_random_uuid(), aud varchar(255), role varchar(255),
  email varchar(255), encrypted_password varchar(255), email_confirmed_at timestamptz, invited_at timestamptz,
  confirmation_token varchar(255), recovery_token varchar(255), last_sign_in_at timestamptz,
  raw_app_meta_data jsonb, raw_user_meta_data jsonb, is_super_admin boolean,
  created_at timestamptz default now(), updated_at timestamptz default now(),
  phone text unique, phone_confirmed_at timestamptz, banned_until timestamptz,
  deleted_at timestamptz, is_sso_user boolean not null default false, is_anonymous boolean not null default false);
grant select on auth.users to service_role, supabase_auth_admin;
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid $$;
create function auth.role() returns text language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'))::text $$;
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim', true), ''),
                  nullif(current_setting('request.jwt.claims', true), ''))::jsonb $$;
grant execute on all functions in schema auth to anon, authenticated, service_role;

create table storage.buckets (id text primary key, name text not null unique, owner uuid, owner_id text,
  created_at timestamptz default now(), updated_at timestamptz default now(), public boolean default false,
  avif_autodetection boolean default false, file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets(id),
  name text, owner uuid, owner_id text, created_at timestamptz default now(), updated_at timestamptz default now(),
  last_accessed_at timestamptz default now(), metadata jsonb, path_tokens text[] generated always as (string_to_array(name, '/')) stored,
  version text, user_metadata jsonb, unique (bucket_id, name));
alter table storage.buckets enable row level security; alter table storage.objects enable row level security;
grant all on storage.buckets, storage.objects to anon, authenticated, service_role;
create function storage.foldername(name text) returns text[] language plpgsql immutable as $$
declare _parts text[]; begin select string_to_array(name, '/') into _parts; return _parts[1:array_length(_parts,1)-1]; end $$;
create function storage.filename(name text) returns text language plpgsql immutable as $$
declare _parts text[]; begin select string_to_array(name, '/') into _parts; return _parts[array_length(_parts,1)]; end $$;
create function storage.extension(name text) returns text language plpgsql immutable as $$
declare _parts text[]; _filename text; begin select string_to_array(name, '/') into _parts;
  select _parts[array_length(_parts,1)] into _filename; return reverse(split_part(reverse(_filename), '.', 1)); end $$;
create function storage.protect_delete() returns trigger language plpgsql as $$ begin
  if coalesce(current_setting('storage.allow_delete_query', true), 'false') <> 'true' then
    raise exception 'Direct deletion from storage tables is not allowed. Use the Storage API instead.' using errcode = '42501';
  end if; return null; end $$;
create trigger protect_objects_delete before delete on storage.objects for each statement execute function storage.protect_delete();
create trigger protect_buckets_delete before delete on storage.buckets for each statement execute function storage.protect_delete();
grant execute on all functions in schema storage to anon, authenticated, service_role;

create table realtime.messages (id bigserial, topic text not null, extension text not null, payload jsonb, event text,
  private boolean default false, updated_at timestamp not null default now(), inserted_at timestamp not null default now(),
  primary key (id, inserted_at));
alter table realtime.messages enable row level security;
grant select, insert on realtime.messages to anon, authenticated; grant all on realtime.messages to service_role;
grant usage on sequence realtime.messages_id_seq to anon, authenticated, service_role;
create function realtime.topic() returns text language sql stable as $$ select nullif(current_setting('realtime.topic', true), '')::text $$;
grant execute on function realtime.topic() to anon, authenticated, service_role;
-- As Supabase's realtime.send: a broadcast row in realtime.messages.
create function realtime.send(payload jsonb, event text, topic text, private boolean default true) returns void
language plpgsql as $$ begin
  insert into realtime.messages (payload, event, topic, private, extension)
  values (payload, event, topic, private, 'broadcast');
exception when others then
  raise warning 'ErrorSendingBroadcastMessage: %', sqlerrm;
end $$;
