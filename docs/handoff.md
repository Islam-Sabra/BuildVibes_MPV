# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

## Last update: 20 Oct 2026, cloud session (branch `claude/test-tw7wuv`)

**Done here:**
- Review 63 (`docs/reviews/2026-10-20-63-migration29-review.md`): migration 29 approved once R1 and R2 are in.
- R1 and R2 applied to migration 29 (`20261020120000_slice2_live.sql`, still **not live**):
  - R1: the chat's `thread:<id>` channel may be joined by whoever `can_use_thread` (receive only);
  - R2: only Got it takes a new time after an edit, and Received keeps its first time.
  - 13 new SQL checks; all 2,171 pass on the stand-in.
- Founder's yes (20 Oct, "I will go with your recommendation") covers two steps:
  - the migration 29 push;
  - turning off public channels later, once the private-channel build is on every test phone.
- The SQL stand-in for sessions without the Supabase CLI is in `supabase/dev/standin/`.

**Next, on the PC (in order):**
1. `git fetch`, then merge `origin/claude/test-tw7wuv` into `slice2-live-db`. It carries `slice2-live-db` plus R1, R2 and review 63, so it merges without conflict.
2. Run `supabase test db` (all 2,171 should pass). Then check against the local Realtime server: a private join to a `thread:` channel works for a member and is refused for an outsider, and with public access off a chat message still arrives live.
3. Push migration 29 to the live database. `supabase db push` must list only `20261020120000_slice2_live.sql`. Do the read-only check after, then merge `slice2-live-db` into `main`.
4. App, on `slice2-app`:
   - join `daybook:` and `thread:` with `private: true`;
   - gather live re-reads to at most one a second per Space (review 63 R3);
   - Unpin for the acting admin;
   - `my_ack_at`, so an edited announcement opens again;
   - the Note kind and the kind menu with Note first (F58);
   - F54 (tick feel), F56 (one "who" flow; the picker never posts), F57 (no "Late").
5. Migration 30: `daily_report_fill` gains the day's notes (review 63).
6. Turn off public channels on the live project, only after the step 4 build is on every test phone.

**Who has which branch now:** nobody is working on any branch. The PC takes `slice2-live-db` and `slice2-app` tomorrow.
