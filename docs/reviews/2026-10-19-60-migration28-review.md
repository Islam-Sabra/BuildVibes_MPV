# Review 60: migration 28 (slice 2 cards) approved, with one change — 19 Oct 2026

Branch `slice2-db` (3b241cf). One migration file, `20261019180000_slice2_cards.sql`, and its tests `28_slice2_cards.test.sql`.

## What I checked
- **On the stand-in**, every migration applies from scratch and **all 2,050 SQL checks pass** (28 files).
- **Dropped functions:** after the migration, no function in the database still calls `daybook_page` or `daybook_post_json`, and neither does the app on main (`lib/`). So the drop breaks nothing at run time.
- **Old tests:** the five old test files that read `daybook_page` now read the cards. Each keeps the same number of checks (18: 122, 19: 138, 21: 146, 23: 122, 24: 36). Nothing was dropped.
- **Ticks:**
  - the log is append-only;
  - the point keeps its words as they were when it was ticked;
  - it survives rewording, removal and account deletion;
  - the app has no direct access to it.
  `tick_point` and `ack` both lock the post first, so the activity trigger never takes a lock out of order.
- **The face rule on history lines:**
  - Received lines are shown to everyone who sees the post;
  - Got it, On my way and In my calendar lines are shown only to their own person, or to whoever acts for the author;
  - a Team's lines stay in the Team.
- **`my_spaces().last_activity_at`** works out who can see what in its own query instead of calling `can_see_space_post`. I compared it with the live `can_see_space_post` and `is_space_admin` (a hidden admin falls back to the member's rules), and a test proves it gives the same answer for an owner outside the Team and for an author who has left the Team. Approved.
- **Activity and pushes:** `unread_activity` uses the same rules as `activity_rows` over 30 days, and the push data now carries `event_id`.

## S1. Only lines everyone can see move the card (must change before going live)
`last_activity_at` is one value per post, the same for everyone. Today, a Got it or an On my way raises it, but **only the author sees those lines**. Everyone else would see the card jump to Now with nothing new on it. That breaks the v13 rule that a card moves because something happened on it.

**Change:**
- Only **a tick, an un-tick and a Received** raise `last_activity_at`, because everyone who sees the post sees those lines.
- **Got it and On my way don't move the card.** The author still gets the lines in the history and the faces on the card.
- Change the `post_acks_activity` trigger to `when (new.kind = 'received')`, and change the back-fill to match.
- **Tests:**
  - Got it and On my way leave `last_activity_at` unchanged;
  - Received still raises it.

This also settles the open question about taking back and giving again. Only Received can move a card that way, which is rare and visible to everyone. Accepted for the pilot.

**Docs:** in `data-model.md` and `daybook.md`, write the rule as "a card moves for what everyone who sees it can see". Review 56's "Got it … On my way move the card" is superseded.

## Verdict
**Approved once S1 is in** and all SQL checks pass. With the founder's yes, the push lists only `20261019180000_slice2_cards.sql`.

**The order matters:** this push drops `daybook_page`. Build 298 doesn't call it, but any older build still on a phone or emulator would break, so uninstall older builds first.
