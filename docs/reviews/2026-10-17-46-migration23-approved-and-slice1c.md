# Review 46: migration 23 approved; slice 1c (writing in place) — 17 Oct 2026

## Migration 23 with M1–M4 (`daybook-extras-db`, e61905f)
On my side, on Postgres 16 with the Supabase stand-in, all migrations apply from scratch and **all 1,612 SQL checks pass** (23 files).

**What held up:**
- **Entries:**
  - `daybook_page` merges posts, sign-offs and updates newest first, with one cursor (time, id), each kind read from its own index.
  - An entry is seen exactly as its work item is (`can_see_space_post`). A deleted item's entries go with it; a cancelled item's stay.
- **Outcome:** each sign-off shows what followed it (checked, sent back, otherwise cancelled or still done).
- **The paper clip:** for whoever checks, it sits only on the latest sign-off while the item is Done; the owner's clip stays on the slip.
- **The slip:** the first three Library files the reader may open, with their revisions and a "more" flag, plus the last "given to".
- **Month dots:** they include sign-offs and updates, and each post's visibility is checked once.
- **Space column:** `work_item_events.space_id` is filled by a trigger and back-filled once. The append-only trigger is off only for that one update, and live has no events.
- **Grants:** the two JSON helpers are closed to the app.
- **The old app:** `daybook_page` changes shape, but the 0.9.0 build never calls it (I checked the `release` branch), so nothing breaks.

**Verdict: approved to go live.** With the founder's yes:
1. Merge `daybook-extras-db` into `main`.
2. `supabase db push` must list only `20261017120000_daybook_extras.sql`; otherwise stop and send a screenshot.
3. Read-only check (names and counts only):
   - `space_posts.due_at` exists;
   - `spaces.site_start_date` exists;
   - `work_item_events.space_id` exists and is not null.
4. Update `progress.md`, commit, push.

There is no Edge Function change this time.

**Tests with the seed loaded:** four older checks count every person or project in the database. Make them count only their own test rows, so the whole suite also passes on a database with `seed_daybook.sql` loaded. That is a test-only change.

## Slice 1c (2df013d)
I compared E1–E7, D1 and DY1 (EN and AR) with the frames.

**What held up:**
- The card opens in place at Now with the straight dashed edge.
- The kind chip shows only Work item, with no arrow.
- The ⋯ menu has only Assign, Location and Due date.
- The assign list shows Lead and Crew only.
- Draft and "Waiting to send" both work.
- The proof slip matches D1: the quote bar, the big photo, the large stamp "عمر ح · 09:40", the note, "Double-tap the photo to check it", and the clip on the proof only.
- The file chips read "M-201 Rev C", and older days hang above today on one scroll.
- The Arabic due wording is right everywhere I looked ("موعده الأحد 18 أكتوبر", "قبل الساعة 14:00 اليوم").

**The seven choices:**
| # | Choice | Answer |
|---|---|---|
| 1 | One cover photo; a new one replaces it | **Yes.** More photos come with opening a post in place (slice 5). |
| 2 | An owner is required | **Yes, but the button follows daybook.md:** Post turns active once there's a title. Tapping it with no owner opens the Assign picker, and choosing someone posts at once. One tap fewer for a foreman. |
| 3 | Checklist hidden | **Yes.** It comes in slice 2, where the point editor is drawn (K1). The same editor then serves points on a work item. |
| 4 | A due date can't be cleared | **No:** a wrong date must be removable. Tapping the date line while writing opens the picker with **Remove**. Editing after posting can remove it too; it's recorded as "Edited: due removed". |
| 5 | Arabic 12-hour clock | **Yes**, with fixed ranges: 00:00–11:59 صباحًا, 12:00–14:59 ظهرًا, 15:00–17:59 عصرًا, 18:00–23:59 مساءً. Add a test for each boundary. |
| 6 | A refused post keeps "Waiting to send" until slice 10 | **No.** A post the server refuses (not a missing signal) waits forever, and the foreman believes it was posted. Do the minimum now: it goes back to a **Draft** in place with a red line "Couldn't send. Tap to fix", and nothing is lost. The full Couldn't send screen stays in slice 10. |
| 7 | A draft is kept only with text | **No: keep it as soon as anything is entered** (a photo, an owner, a date, a place or text). A foreman often takes the photo first, and losing it when the app closes is the worst case. |

**Small fixes:**
- **Arabic avatar for names starting with an alef** (ا أ إ آ): at avatar size, "إ" reads as "!" (the sheets show "!" for إسلام أحمد). For these names use **two letters**: "إس", "أح". All other Arabic names keep one letter.
- **Assign picker wording:** the menu says "Assign", so the search field says **"Assign to…"**, not "Give to…". "Give to someone else" is for an item that's already posted (part 1d). The Arabic "التكليف إلى…" is already right.

## Order
1. With the founder's yes: migration 23 goes live, as above.
2. On `slice1-daybook`, the fixes above, then part 1d.
3. Once migration 23 is live, put the current build on the founder's phone (wireless debugging, as agreed) so he can try 1b–1c himself.
