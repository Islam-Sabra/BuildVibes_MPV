# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

## Last update: 21 Oct 2026, PC session

**Done on the PC:**
- `claude/test-tw7wuv` merged into `slice2-live-db` and `slice2-app`; main (reviews 50 and 69, the founder's D1–D6) merged into both. Generated l10n files come from `flutter gen-l10n` and match.
- Local checks: 2,251 SQL checks in 32 files, `flutter analyze` clean, 1,318 app tests.
- Local Realtime check (13 of 13): members join the private `daybook:`, `thread:` and `dm:` channels and receive live; outsiders, and a Space member outside a DM, are refused. With public channels off locally, a public join is refused and a chat message still arrives live.
  - The local Realtime server rewrites its tenant row on every start, so to test "public off" set `_realtime.tenants.private_only` as `supabase_admin` **without** restarting it.
- **Live: migrations 29, 30, 31 and 32**, one file per push, each with a read-only check. `main` has them.
- **Public channels on the live project are still ON.** The founder says when to turn them off, once the new build is on every test phone.
- Review 69's wording fixes in `docs/legal/`, `docs/store/listing-draft.md`, `docs/pilot/quick-guide.md`, and the D3 positioning line in `docs/product/rules.md`.
- **Slice 2 retest build 375** from branch `slice2-retest` (38a3d37) = `a2e330f` (tag `slice2-candidate`) + the code of 8af5dee (photo location removal). It applied cleanly, and 1,288 tests pass. It is on the emulator (Omar signed in).
- Screenshots re-shot on the PC (Windows fonts), 211 checks, on `slice2-app` (a4adec7).

**Waiting:**
- **The founder's phone:** build 375 isn't on it yet (wireless debugging address needed). Install, then the founder's retest (order below).
- **Step 6, photo location:** on the founder's phone with location on, take a photo, post it, download it from Storage and check that it has no GPS and keeps its orientation. Needs the phone.
- **Retest order for the founder:**
  1. Due today strip (F38/F57);
  2. the Note;
  3. the who row;
  4. no "Late";
  5. the tick feel;
  6. an announcement edited after Got it;
  7. live updates on both devices.
- **After the retest passes:** the rest of slice 3 (DM4–DM5 Put in a Space, S8m Turn into a work item), then slice 4 (review 67, with review 69 §1). Not before.
- **Review 69, still to do:**
  - D4: the store reviewer's Edge Function and demo Space seed, on their own branch, before 13 Dec; going live needs its own yes.
  - Store listing items outside the listed fixes: the English long description and the header note still say "AECO" (D3 says "construction"); "the place" in "Proof that is yours" could say "typed on the work item"; old lead notes on lines 78 and 115.

**On the PC, not in git:**
- The main folder has the lead's uncommitted `docs/reviews/2026-10-20-63-model-views-3d.md` and an edit to `docs/product/model-views.md`. Left untouched. Note that review 63 also names the cloud's `2026-10-20-63-migration29-review.md`, so the 3D review needs another number.
- The `BuildVibes-slice1` worktree has a stash, "PC agent partial F54-F58, 20 Oct", superseded by the cloud's work. Drop it once the retest passes.

**Who has which branch:**
- PC: `slice2-app` (slice 2 + slice 3 part 1, worktree `BuildVibes-slice1`) and `slice2-retest` (the retest build, worktree `BuildVibes-phone`).
- `slice2-live-db` equals main.
- `claude/test-tw7wuv` is merged; a new cloud session starts its own `claude/...` branch from `slice2-app`.
