# Review 39: migration 21 approved; answers on migration 20's choices — 16 Oct 2026

## Migration 21 (`notebook-db`, 571a793): approved
On my side all migrations apply from scratch and **all 1,227 SQL checks pass**. N1–N4 from review 38 are in: the order wording ("21 before 20; 20 is built on 21"), the place in My calendar, the record of deleted notes (a late save returns null and makes nothing; deleting doesn't make room under the daily limit), and the six tests.

**Going live (founder's yes):** merge `notebook-db` into `main`; `supabase db push` must list only `20261015230000_notebook.sql` (otherwise stop and send a screenshot); read-only check that `notes`, `note_files` and `deleted_notes` have row-level security on and bucket `notebook-files` is private; update `progress.md`. Migration 20 goes live after it, never before.

## Migration 20: the six choices
1. **Daily report headings: the prototype's** (On site / Done today / Problems, frame R2 `2539:34498`). The prototype wins over review 33.
2. **Walk and meeting parent: a work item owned by the person who posts it.** Agreed, with three conditions:
   - while it has work items under it, it stays out of everyone's Needs you (no sign-off or check is asked of anyone for the parent itself);
   - its progress is its children's ("3 of 5 checked"); it needs no DONE or CHECKED stamp of its own;
   - **it never counts as proof** on anyone's profile (nobody else checked it). Add a test.
3. **Templates keep their Team:** yes. A template made from a Team post is seen only by that Team and the Space admins.
4. **Page-save notices at most once in 10 minutes** per work item to its owner: yes.
5. **Arabic search:** matching أ/إ/آ/ا, ة/ه, ى/ي and Arabic-Indic digits to Western digits, no stemming: yes. Apply the same folding to what is stored and to what is typed.
6. **0.9.0 shows a shared week report as an empty bubble:** acceptable. Nobody can share one from 0.9.0, and the first build with reports (slice 9) shows it properly.

Fix what your independent review confirms, rerun everything, push `post-pages-db`, and report. Not live.
