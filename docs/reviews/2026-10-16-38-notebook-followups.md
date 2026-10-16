# Review 38: migration 21 follow-ups (Claude Code's check of review 37) — 16 Oct 2026

Claude Code checked migration 21 on `notebook-db` (6b6d814): all 1,211 checks pass, no privacy or permission holes. It raised four points. The lead agrees with all four. Make them on `notebook-db`, inside migration 21, then push; I'll recheck.

## N1. Go-live order: 21 first, then 20 (the lead's mistake in review 37)
Review 37 said either may go first. Wrong: both replace `export_my_data`, and a push of 21 after 20 is out of order (the tool refuses it, and forcing it would drop what 20 adds to the export).
- **Migration 21 goes live first, then 20.** `post-pages-db` stays based on `notebook-db`, so 20 builds on 21's version of the shared functions.
- Correct the wording in the migration's opening comment, `data-model.md` §16 and review 37 ("21 before 20; 20 is built on 21").

## N2. My calendar returns the place
CAL1 (`2557:35587`) shows the place on a row ("Kuwait City Tower · Gate office"). Add a `place text` column to `my_calendar`: the post's `place_text` for work items, checklists and activities; null for to-dos. Test it on an activity.

## N3. A deleted note can't come back
Keep a small record of deleted notes: `deleted_notes (id uuid pk, owner_id uuid references profiles on delete cascade, created_at timestamptz, deleted_at timestamptz)`, written by `delete_note`, owner-only read (or no read at all), no app writes.
- `save_note` on an id in `deleted_notes` changes nothing and **returns null**; the app treats null as "this note was deleted" and drops its queued edit.
- The 500-a-day limit counts notes created in the last day **plus** deleted ones created in the last day, so deleting doesn't make room.
- Add to `data-model.md` §16 (it replaces A4's `deleted_at`: a deleted note is gone, only its id stays). Tests: a save after delete returns null and makes no row; delete-then-create doesn't beat the daily limit; another person can't read the record.

## N4. The six test gaps
Add the tests Claude Code listed: a recording still on a note is never claimed by the cleanup; the Team rule in My calendar on an activity and a work item, not only a checklist; an "In my calendar" activity appears (and goes when taken back); each date-range limit tested on its own (62 days of days, 62 days plus an hour of time); someone else can't delete your unused file; someone can't attach your note to their own post (and you can't attach it to someone else's post).

## Then
Rerun everything, push `notebook-db`, report the hash and counts. Not live. Then continue migration 20 on `post-pages-db`, rebased on the new `notebook-db`.
