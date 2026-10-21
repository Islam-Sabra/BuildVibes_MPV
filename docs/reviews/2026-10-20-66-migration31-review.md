# Review 66: migration 31 (a private channel for direct messages) approved — 20 Oct 2026

Independent review of `20261021180000_dm_live.sql` and `31_dm_live.test.sql` (cloud, branch `claude/test-tw7wuv`).

## What was checked
- **On the stand-in**, every migration applies from scratch and all SQL checks pass.
- **The policy:** `daybook_live_receive` keeps migration 29's condition word for word:
  - `to authenticated`, select only;
  - `extension = 'broadcast'` and `topic = realtime.topic()`;
  - the daybook and thread branches.
  
  It only adds the `dm:` branch. `daybook_live_send` is unchanged, so it stays daybook-only.
- **Who can join, probed:**
  - a third person and anon get nothing;
  - a block either way closes the channel to both people;
  - a purged account gets nothing, while the other person keeps the thread;
  - in a request, and after Decline, the person can still receive: their thread still reads for them, so the channel follows the thread's own read rule.
- **Safety:**
  - only a full id after `dm:` reaches the cast, with no errors;
  - anon can't run the function;
  - it has `search_path = ''`;
  - broadcast and presence inserts on a `dm:` topic are both refused.
- **Postgres Changes:** joining is checked once. The message rows still pass the `dm_messages` read rule for each change, so a block made after joining stops the contents at once.

**No high or medium problem.**

## Low findings
1. **An uppercase topic is accepted** (`~*`). It's the same thread under the same rule, so nothing leaks, and the daybook and thread rules do the same. **Accepted:** the app always writes lowercase, and changing all three now would reopen migration 29.
2. **Test gaps: fixed.** There are now checks for a presence insert being refused, and for receiving after Decline (14 checks in the file).
3. **Hard deletes** send only the message's id to subscribers: Realtime doesn't apply table rules to DELETE. Messages are soft-deleted (`deleted_at`), and hard deletes happen only when a whole thread goes, so only ids could show. No action; keep soft delete.

## Verdict
**Approved.** It goes live with the founder's yes (given 20 Oct), on the order and checks in `docs/handoff.md`.
