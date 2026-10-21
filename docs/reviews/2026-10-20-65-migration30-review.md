# Review 65: migration 30 (notes in the daily report) approved — 20 Oct 2026

Independent review of `20261021120000_report_notes.sql` and `30_report_notes.test.sql` (cloud, branch `claude/test-tw7wuv`).

## What was checked
- **On the stand-in**, every migration applies from scratch and all SQL checks pass.
- **Copied bodies:** `validate_blocks` and `space_post_json` were diffed against their last versions (migrations 20 and 29). Nothing was dropped: `my_ack_at` and the other migration 29 fields are there.
- **Grants:** `post_cover_path` can't be called by anyone signed in or out, and `daily_report_notes` only by signed-in people. The two replaced functions keep their earlier revokes. All four have `search_path = ''`.
- **Leaks, probed:**
  - a note from another Space is refused as a ref;
  - a Team's note written straight into an Everyone report's page doesn't reach a reader outside the Team, because `can_see_space_post` is checked per reader;
  - an announcement written in as a ref doesn't appear in `refs` (the kind filter), so the LEFT JOIN changes nothing for work items;
  - names follow `space_person_name`, so they're hidden across a block.
- **Day window:** backwards, or longer than a day and an hour, is refused. A Team id from outside the Space only returns the Everyone notes.

**No high or medium problem.**

## Low findings, all fixed
1. **A new ref could point at a cancelled note.** Now only a live note can be added. A note cancelled after the report keeps its ref, and the report still saves.
2. **`post_cover_path` was `security definer`.** It's now `security invoker`: only definer functions call it, and it stays closed to everyone.
3. **Test gaps:** a work item's ref now says `kind = 'work_item'` (test 21), a new ref to a cancelled note is refused, and a report with a note cancelled later still saves.

## Verdict
**Approved.** It goes live with the founder's yes (given 20 Oct), right after migration 29, as the only file in its push.
