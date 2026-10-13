-- Migration 17: Translate on posts (week 8 part 3). Brief:
-- docs/reviews/2026-10-13-23-week8-brief.md §4.
--
-- - The Edge Function translate (supabase/functions/translate, not
--   deployed) reads the post with the caller's own token, so every read
--   rule (blocks, hidden accounts, removals, reports, deletes) still
--   applies. Everything below is for the service role only.
-- - post_translations: one cached translation per post and language. A
--   cached copy older than the post's last edit is never used.
-- - translation_uses: each new translation from Google, per person, so
--   nobody can ask for more than 100 a day. Cache hits are free.
-- - Only 'en' and 'ar'. The function never logs the text.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.post_translations (
  post_id uuid not null references public.posts (id) on delete cascade,
  lang text not null check (lang in ('en', 'ar')),
  body text not null check (length(body) between 1 and 6000),
  created_at timestamptz not null default now(),
  primary key (post_id, lang)
);

create table public.translation_uses (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);
create index translation_uses_profile_idx on public.translation_uses (profile_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Functions (service role: the translate function)
-- ---------------------------------------------------------------------------

-- The cached translation of [p_post] into [p_lang], if it is newer than
-- the post's last edit.
create or replace function public.cached_translation(p_post uuid, p_lang text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select t.body
  from public.post_translations t
  join public.posts p on p.id = t.post_id
  where t.post_id = p_post and t.lang = p_lang
    and p.deleted_at is null
    and t.created_at >= coalesce(p.edited_at, p.created_at);
$$;

-- Counts one new translation for [p_profile]. False when they already had
-- 100 in the last 24 hours (nothing is counted then).
create or replace function public.claim_translation(p_profile uuid)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  -- One claim per person at a time, so two at once can't both pass.
  perform pg_advisory_xact_lock(hashtextextended('translate:' || p_profile::text, 0));
  if (select count(*) from public.translation_uses u
      where u.profile_id = p_profile and u.created_at > now() - interval '1 day') >= 100 then
    return false;
  end if;
  insert into public.translation_uses (profile_id) values (p_profile);
  return true;
end;
$$;

-- Stores (or replaces) a translation. Only for a post that is still there.
create or replace function public.save_translation(p_post uuid, p_lang text, p_body text)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  insert into public.post_translations (post_id, lang, body)
  select p.id, p_lang, p_body from public.posts p
  where p.id = p_post and p.deleted_at is null
  on conflict (post_id, lang) do update
    set body = excluded.body, created_at = now();
$$;

-- The nightly cleanup can drop old counts (not scheduled; a day is enough).
create or replace function public.prune_translation_uses()
returns integer
language sql
volatile
security definer
set search_path = ''
as $$
  with gone as (
    delete from public.translation_uses where created_at < now() - interval '2 days'
    returning 1
  )
  select count(*)::int from gone;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security and grants: service role only
-- ---------------------------------------------------------------------------

alter table public.post_translations enable row level security;
alter table public.translation_uses enable row level security;

revoke all on public.post_translations, public.translation_uses from anon, authenticated;
grant all on public.post_translations, public.translation_uses to service_role;

revoke execute on function
  public.cached_translation(uuid, text),
  public.claim_translation(uuid),
  public.save_translation(uuid, text, text),
  public.prune_translation_uses()
  from public, anon, authenticated;
grant execute on function
  public.cached_translation(uuid, text),
  public.claim_translation(uuid),
  public.save_translation(uuid, text, text),
  public.prune_translation_uses()
  to service_role;
