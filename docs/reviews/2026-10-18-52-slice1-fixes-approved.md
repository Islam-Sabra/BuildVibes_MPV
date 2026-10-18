# Review 52: slice 1 fix round approved; migration 25 approved — 18 Oct 2026

Branches: `slice1-fixes` (944b4f7, Parts A–E) and `test-fixes-db` (c95a7a5, migration 25).

## Migration 25
On my side, on Postgres 16 with the Supabase stand-in, all migrations apply from scratch and **all 1,672 SQL checks pass** (25 files).

**What held up:**
- **`add_reply`:** it accepts any live reply on the same post, never across a block, and files it under the top comment. `reply_to_person` keeps who was answered (back-filled for old replies). A retry with the same id stays one reply.
- **The notification** goes to the person answered, and not twice when that person is the post's author.
- **`drop_stale_push_tokens`:** service role only, refuses less than 7 days, and uses `updated_at`. `register_push_token` already refreshes that on every start, so no second column is needed.

**Verdict: approved to go live,** with the founder's yes. The push lists only `20261017220000_test_fixes.sql`. Scheduling `drop_stale_push_tokens` nightly is a separate step for the founder's yes, later, with the other cleanups.

## The fix round (Parts A–E)
**Part A causes, accepted:**
- **F18:** the post was on the server. The feed couldn't be pulled to refresh when shorter than the screen, and never reloaded on return.
- **F12:** no app crash on record; the emulator restarted. **Closed.**
- **The three replies** were three separate sends. Not a bug.

**What held up in the screenshots (EN and AR):**
- **F19:** the feed cards and the post page now match H1: ⋯ level with the name, the semibold name with its headline, cards that hug short posts, replies as slips with "Replying to …" / "ردًا على …", and the reply bar.
- **F3 + F10:** Home → Spaces has one compact date line, then New Space and Enter an invite code. Needs you cards put the Space name first, with Open on the end side and the whole card tappable. Under Your Spaces, every Space appears once with no repeated Needs you item.
- **F1:** Create offers "Post to everyone" or "Work item in a Space ▸", each with a one-line explanation.
- **F13:** Activity rows open what they're about. The REV stamp and the A–F letters are gone.
- **F6 + F7:** "Take a photo" or a note alone, and "Signed as done · Undo" before anything is sent.
- **F9:** "Notifications aren't reaching this phone · Fix it" on Home and in Settings.
- **F4:** the general phrases no longer assume a site, and a test guards new ones. The kept ones are reasonable. The New Space hint becomes **"e.g. Tower B — Design team"**, which is neutral.
- **F15:** the 12-hour period sits on a small second line, so the Arabic times fit.

**One condition:** the anonymous "no token" report goes through Crashlytics. Crash and diagnostic reports must be named in the privacy text (market pack legal) before the pilot, along with what is sent (no user id, no content).

**Still open:** **F14**, "تم الفحص" → "تم التحقق", is the founder's decision.

**Verdict: approved.** Next:
1. With the founder's yes, migration 25 goes live.
2. Install this build on his phone and the emulator, for the 15-minute retest.
3. Once he says slice 1 works, merge `slice1-fixes` into `slice1-daybook` and then into `main`, and slice 2 starts.
