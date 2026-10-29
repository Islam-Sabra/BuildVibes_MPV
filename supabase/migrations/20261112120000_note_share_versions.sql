-- Migration 51 (review 106 T5): "changed since shared".
--
-- A share keeps the version that was sent. To say a share is older, the
-- app compares when it was made (note_shares.created_at) with when the
-- entry's content last changed: notes.content_changed_at. No share
-- changes, and no share function either.
--
-- notes.version can't be used: it moves on every save_note, and ticking a
-- to-do or setting a reminder is a save. So the content is fingerprinted:
-- - notes.content_key: md5 of the entry's kind, title, words (an older
--   note's body), lines and checklist points without their ticks and
--   folds ("done", "folded"), and its files' paths. Pinning, folding the
--   entry, moving it, arranging it and a reminder aren't in it.
-- - notes.content_changed_at: when content_key last changed.
-- They are worked out by deferred triggers, when a change is made for
-- good: save_note sends the files by deleting and inserting them again,
-- so only the end of it is compared, and the same files sent again don't
-- count.
-- Existing entries get their key now and no change time: their shares
-- don't read as older until the entry changes. Read like the rest of a
-- note (the owner only); written only here (notes has no write grants).

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
    n.kind,
    coalesce(n.title, ''),
    case when n.blocks is null then n.body end,
    public.note_strip_marks(n.blocks)::text,
    public.note_strip_marks(n.points)::text,
    (select string_agg(f.storage_path, E'\x1e' order by f.storage_path)
     from public.note_files f where f.note_id = n.id)))
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

revoke all on function public.note_strip_marks(jsonb) from public, anon, authenticated;
revoke all on function public.note_content_key(uuid) from public, anon, authenticated;
revoke all on function public.note_content_touched() from public, anon, authenticated;

-- Before the triggers: every entry's key, no change time.
update public.notes n set content_key = public.note_content_key(n.id);

create constraint trigger notes_content_changed
  after insert or update of kind, title, body, blocks, points on public.notes
  deferrable initially deferred
  for each row execute function public.note_content_touched();

create constraint trigger note_files_content_changed
  after insert or delete on public.note_files
  deferrable initially deferred
  for each row execute function public.note_content_touched();
