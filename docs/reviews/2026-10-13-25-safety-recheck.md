# Review 25: migration 15 recheck and week 8 part 1 screens — 13 Oct 2026

## A. Migration 15 (`safety-db`, 963813d): passed
All 716 SQL checks pass on my side. The independent review re-ran every probe, and all review 24 fixes hold:
- a removed chat PDF is hidden for everyone and comes back on reverse;
- a reported reply leaves your Activity;
- the moderation address is closed to the app (`market_moderation`, service role only);
- NULL actions are refused, and a double tap gives one report;
- reported posts leave every list and count;
- the reporter can't open a reported message's attachments;
- photos are kept while an appeal is open;
- the alert timeout is handled.

The new pieces add no holes:
- a file a work item uses is never touched;
- a reversal can't bring back a file deleted on its own;
- the reason ids are safe;
- no earlier function lost anything.

**Accepted:** the reporter can still open a reported chat PDF through its separate Library copy. Hiding for the reporter is a courtesy; removal is the real control, and it now hides the copy for everyone.

**Two small additions before go-live** (in place, no lead recheck needed):
1. In `supabase/ops/moderation.sql`, add a note: a PDF a work item uses stays visible after removal (as with an author's own delete). Detach it from the item by hand if needed.
2. In `orphan_post_media`, repeat the open-appeal condition in the re-check under the lock.

**Go-live:** as review 24 §Go-live. Step 1 is ready now with the founder's yes. The dry run must list `20261013120000_safety.sql` as not yet applied.

Steps 2–4 wait for the founder:
- the moderation and support email;
- a Resend API key with sending access only.

## B. Part 1 screens: passed
Checked in English and Arabic against `docs/design/account/`:
- R1 reasons and the "Something else" note;
- R2 with Block this account;
- the block dialog and the toast with Undo;
- S7 with Unblock;
- R3 (post and message), R4, R5;
- the Activity rows for removal and appeal.

**Accepted:**
- **Block dialog wording.** It describes what blocking really does in the MVP, since there are no messages.
- **"We'll look at it again"** instead of "a different reviewer".
- **R1's six reasons,** as drawn.

**Small fixes:**
1. R3 "Your post · {date}" shows the date the post was **posted**, in the app's date format (EN "12 Sep", AR "12 سبتمبر"), not the removal date.
2. "Read the community rules" appears once the legal pages exist (week 8 part 2, `markets.legal`). Until then, leave it hidden, as now.

Merge `safety-db` and `safety` into main after go-live step 1. Then go on to part 2 (migration 16, account and Settings).
