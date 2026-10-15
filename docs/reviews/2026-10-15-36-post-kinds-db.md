# Review 36: migration 19 (other kinds of post) — 15 Oct 2026

Branch `post-kinds-db` (8e399c4). On my side, on Postgres 16 with the Supabase stand-in: all migrations apply from scratch and **all 1,123 SQL checks pass**.

**What held up:**
- **Who may post:** Lead and Crew (`create_items`), a file post also needs the files right, never a Viewer or a hidden account; a Team post only from inside the Team or by an admin; a Team chat message stays in its Team.
- **Ticking:** Lead or Crew only, never a Viewer; untick by whoever ticked or the author; a ticked point can't be removed or reworded; points close when a work item leaves Open.
- **Acknowledgements:** your own rows only in the table; `post_acks_for` is the only way to see others'; `post_others` is never readable, so nobody learns that someone acknowledged.
- **Delete vs Cancel:** any tick or acknowledgement by someone else ends Delete for good (clarification 2).
- **Notifications:** every fan-out (announcement, new file version, edit, cancel, reminder) checks `can_see_space_post_as`, so a Team post never reaches someone outside the Team, and a hidden account gets nothing.
- **Reminders:** a 25–35 minute window every 5 minutes, once per person and start time (a moved activity is reminded again); only pushes, no Activity rows.
- **Grants:** every internal helper is closed to the app; `due_activity_reminders` is service role only.
- **Push texts** never name a post, a Space or a project, in English and Arabic.

**Verdict:** approved after R1 below (small; rerun the tests, push the branch; no recheck needed unless a test fails).

## R1. Received faces on file posts: everyone who can see the post
The prototype shows "who received" faces on file posts and in the Library to the Space (frames K2 `2535:34023`, LV `2543:35101`). The prototype wins (CLAUDE.md). It is also the point of the feature: a foreman needs to see that the crew has Rev D.
- In `may_see_acks` (or `post_acks_for`): **`received` rows** go to anyone who can see the post (`can_see_space_post`). **`got_it`, `on_my_way`, `in_my_calendar`** stay with the author (or an admin for an author who is gone), as the prototype shows them.
- Still faces and names only, never a count (product rule 3).
- Tests: a Crew member who can see a file post reads its Received faces; the same member reads no Got it faces on an announcement; someone outside the Team reads neither.
- Update `data-model.md`.

## Choices confirmed
1. **"Starts in 30 min" even when the Space is Off:** yes. The person was invited or put it in their calendar; one push per activity.
2. **On my way from 3 hours before the start:** yes.
3. **Points on a work item are added by editing it** after it is created: yes for now. Walk mode and meeting notes (migration 20) don't need points.
4. **A checklist with unticked points is in its people's Needs you:** yes.

## Going live (each with the founder's yes, in this order)
1. Deploy the `push` Edge Function with the new texts (it must know the new kinds before any are queued).
2. `supabase db push`: must list only `20261015180000_post_kinds.sql`; otherwise stop and send a screenshot. Then a read-only check (names and counts only): the five new tables exist with row-level security on.
3. Run `supabase/ops/activity_reminders_cron.sql` once; check `cron.job` lists `activity-reminders` as active.
4. Update `progress.md`, commit, push. Then start migration 20 (review 33 A3) on branch `post-pages-db`.
