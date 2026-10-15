# Review 35: recheck of migration 18 after review 34 — 15 Oct 2026

Branch `daybook-db` (4234bf3). On my side: all migrations apply from scratch, **all 988 SQL checks pass**, and my own probes confirm each fix:
- **D1:** a Crew member who isn't the author is refused when adding a work item under someone else's item; the author can.
- **D2:** an author lowered to Viewer is refused on Check and on Cancel; the admin checks for them.
- **D3:** the only admin's work for themselves can't be checked by them or by Crew; a Lead sees it in Needs you and checks it.
- An author lowered to Viewer can still delete their own post while nobody else has added anything. That is fine: it removes only their own work.

**Verdict: approved.** Migration 18 and the app changes on this branch can go live together, with the founder's yes:
1. Merge `daybook-db` into `main`.
2. `supabase db push` must list only `20261015120000_daybook.sql`; otherwise stop and send a screenshot.
3. Confirm on live (read-only, names and counts only): `space_posts` has one row per work item; `post_edits` and `post_files` are empty; the chat-card trigger is gone.
4. Update `progress.md` (migration 18 live, date, founder's yes), commit, push.

Then start migration 19 (review 33 A2) on branch `post-kinds-db`.
