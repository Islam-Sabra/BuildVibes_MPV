-- Migration 51 (review 106 T5; the lead's check of r106b, K1 and K2):
-- "changed since shared".
--
-- NOTE for later migrations: a later migration that writes notes or
-- note_files and then alters notes must `set constraints all immediate`
-- first (the triggers below are deferred, and a table with pending
-- trigger events can't be altered).
--
-- One truth, on the server (K1). Each entry has a fingerprint of its
-- content, notes.content_key, and each share keeps the key the entry had
-- when it was made (note_shares.content_key, filled at share time). A
-- share is older exactly when its key differs from the entry's key now:
-- no clocks are compared, and an entry edited and then put back to the
-- shared words reads as the same again. notes.content_changed_at stays
-- only for the words "changed at {time}". The phone reads both from here;
-- it has no rule of its own.
--
-- notes.version can't be used: it moves on every save_note, and ticking a
-- to-do or setting a reminder is a save. So the content is fingerprinted:
-- - notes.content_key: md5 of the entry's kind, title, words (an older
--   note's body), lines and checklist points without their ticks and
--   folds ("done", "folded"), and its files' paths (photos, PDFs and
--   voice recordings: a voice block's recording is a note_files row, and
--   its path is in the block too). Pinning, folding the entry, moving it,
--   arranging it and a reminder aren't in it. Every field is coalesced, so
--   a missing one can't shift the others (K2).
-- - notes.content_changed_at: when content_key last changed.
-- They are worked out by deferred triggers, when a change is made for
-- good: save_note sends the files by deleting and inserting them again,
-- so only the end of it is compared, and the same files sent again don't
-- count. A share works its key out at once, so a share made in the same
-- transaction as an edit keeps the edited key.
-- Existing entries get their key now and no change time, and existing
-- shares get their entry's key: they don't read as older until the entry
-- changes. Read like the rest of a note or a share (the owner only);
-- written only here (neither table has write grants).

alter table public.notes
  add column content_key text,
  add column content_changed_at timestamptz;

-- A block list or a checklist without its ticks and folds, at any depth
-- (a toggle's lines).
create or replace function public.note_strip_marks(p jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case jsonb_typeof(p)
    when 'object' then (
      select coalesce(jsonb_object_agg(e.key, public.note_strip_marks(e.value)), '{}'::jsonb)
      from jsonb_each(p) e
      where e.key not in ('done', 'folded'))
    when 'array' then (
      select coalesce(jsonb_agg(public.note_strip_marks(a.value) order by a.n), '[]'::jsonb)
      from jsonb_array_elements(p) with ordinality a(value, n))
    else p
  end;
$$;

create or replace function public.note_content_key(p_note uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select md5(concat_ws(E'\x1f',
    coalesce(n.kind, ''),
    coalesce(n.title, ''),
    coalesce(case when n.blocks is null then n.body end, ''),
    coalesce(public.note_strip_marks(n.blocks)::text, ''),
    coalesce(public.note_strip_marks(n.points)::text, ''),
    coalesce((select string_agg(f.storage_path, E'\x1e' order by f.storage_path)
              from public.note_files f where f.note_id = n.id), '')))
  from public.notes n
  where n.id = p_note;
$$;

-- The entry's key again; its change time moves only when the key did.
create or replace function public.note_content_touched()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := (to_jsonb(coalesce(new, old))
                ->> case when tg_table_name = 'notes' then 'id' else 'note_id' end)::uuid;
  v_key text := public.note_content_key(v_id);
begin
  update public.notes n
  set content_key = v_key, content_changed_at = clock_timestamp()
  where n.id = v_id and n.content_key is distinct from v_key;
  return null;
end;
$$;

-- A share keeps the key its entry has as it is made (K1).
create or replace function public.note_share_keyed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.content_key := public.note_content_key(new.note_id);
  return new;
end;
$$;

revoke all on function public.note_strip_marks(jsonb) from public, anon, authenticated;
revoke all on function public.note_content_key(uuid) from public, anon, authenticated;
revoke all on function public.note_content_touched() from public, anon, authenticated;
revoke all on function public.note_share_keyed() from public, anon, authenticated;

alter table public.note_shares
  add column content_key text;

-- Before the triggers: every entry's key, no change time; every share
-- its entry's key, so none reads as older.
update public.notes n set content_key = public.note_content_key(n.id);
update public.note_shares s set content_key = n.content_key
from public.notes n where n.id = s.note_id;

create trigger note_shares_keyed
  before insert on public.note_shares
  for each row execute function public.note_share_keyed();

create constraint trigger notes_content_changed
  after insert or update of kind, title, body, blocks, points on public.notes
  deferrable initially deferred
  for each row execute function public.note_content_touched();

create constraint trigger note_files_content_changed
  after insert or delete on public.note_files
  deferrable initially deferred
  for each row execute function public.note_content_touched();
