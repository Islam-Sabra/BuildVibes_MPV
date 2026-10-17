# Review 45: migration 23 and slice 1b (the daybook page) — 17 Oct 2026

## Migration 23 (`daybook-extras-db`, 48e53cc)
On my side, on Postgres 16 with the Supabase stand-in, all migrations apply from scratch and **all 1,563 SQL checks pass** (23 files).

**What held up:**
- `due_at` must fall on its `due_date` in some time zone. `is_late` uses the time when there is one, otherwise the phone's today.
- `set_site_start_date` is for admins only, with a sane range.
- `daybook_month` is members only, gives Team posts as `can_see_space_post`, never counts, and lets the phone group the 15-minute times by its own days.
- The old `create_work_item` and `create_space_post` signatures are dropped, so there's no second version, and the grants are right.

**Verdict:** approved, with M1–M4 added before it goes live, as Claude Code proposed.

Claude Code found the real gap: in the Daybook, a sign-off is **its own entry at its own time**, not a field on the work item. D1 `2518:33001` shows this: the work item at 08:14 carries a small DONE stamp; Omar's proof at 09:40 is a separate slip quoting the item, with the photo, the large stamp and the paper clip. `daybook_page` returns posts only, so the page can't draw it.

### M1. Sign-off and update entries in `daybook_page`
- The page returns **entries**, newest first, with one cursor (time, id):
  - `post`, as now;
  - `sign_off`: a `done` event;
  - `update`: a `comment` event, "a small note quoting it" (daybook.md).
- **A sign-off entry** has:
  - the work item's id, ref and title (shown as the quote);
  - who signed, the note, the photos (path, taken at, place) and the time;
  - **its outcome:**
    - `checked` (by, at) if this sign-off was checked;
    - `sent_back` (reason, note, by, at) if a send-back followed it;
    - otherwise `done`.
  - An item sent back and signed again has two sign-off entries: the older one stamped SENT BACK, the newer DONE or CHECKED.
- **An update entry** has who wrote it, the note, any photos, the time, and the item's title as the quote.
- **Visibility:** the same as the item (`can_see_space_post`). Entries of a deleted item go with it. A cancelled item's entries stay, as the record.

### M2. The paper clip goes where the action is
- For the author or a Lead who may check, `needs_me` is on the **latest sign-off entry** while the item is Done, never on the work item slip.
- For the owner (Open or Sent back), it stays on the work item slip, next to "Sign as done".
- This also fixes the clip and DONE stamp overlapping in D1.

### M3. The work item slip gains
- `attachments`: up to 3, each with a name and `rev_label` ("M-201 Rev C"), plus a "more" flag.
- `given_to`: the last reassignment (from, to, at), for the line "Given to Rakesh Nair instead of Omar Haddad at 12:30".

### M4. `daybook_month`
Days with sign-offs or updates get a dot too.

Tests:
- a sign-off entry never reaches someone outside a Team post's Team;
- each outcome after a send-back and a second sign-off;
- the clip moves from the owner's slip to the author's sign-off;
- the cursor doesn't skip entries made at the same moment.

Then push and report. I'll re-review M1–M4 only. Live goes to the founder for his yes, and the push must list only `20261017120000_daybook_extras.sql`.

## Slice 1b (52d2e5e)
I compared D1, L1, DY1, DY2, DY3 and V1 (EN and AR) with Figma.

**What held up:**
- The masthead with "day 41 on site", and no weather.
- The Due today strip, "Late by 1 day", and the day divider.
- The Viewer bar with no clips.
- Day one without the announcement option.
- C1–C5 are applied: initials, the prototype's Arabic site words and people, the straight dashed writing card, 48-point tap areas, and only slice 1's options.

**Fixes (with 1c):**
- **B1. One continuous daybook.** In D1 and V1 the top half is empty paper above 08:14, although Wednesday has posts (DY1 shows Wednesday at 16:20). Older days hang above today on the same scroll, with their divider, as in Figma. The empty first-day card is the only exception.
- **B2. Arabic due patterns:** "by Wed 14 Oct" became "قبل الأربعاء 14 أكتوبر", which means "before Wednesday", one day early. The same mistake as review 44 C2, in another pattern. Use these:

  | English | Arabic |
  |---|---|
  | by today, no time | **"خلال اليوم"** (confirmed) |
  | by tomorrow, no time | **"غدًا"** ("لك، غدًا") |
  | by a date | **"موعده الأربعاء 14 أكتوبر"** |
  | by a time | **"قبل الساعة 2 ظهرًا اليوم"** (the AR frame; in 24-hour: "قبل الساعة 14:00 اليوم") |
  | late | **"كان موعده …"** (confirmed) |

  A test should cover each pattern in Arabic.
- **B3.** Once M1 lands, draw the proof slip as in D1: the quote bar, the big photo, the large stamp on the photo, the note, and "Double-tap the photo to check it" for whoever may check.

## Order
1. M1–M4 on `daybook-extras-db`. Push and report.
2. After the lead's re-review and the founder's yes, migration 23 goes live.
3. Part 1c (writing in place) with B1–B3 on `slice1-daybook`. 1c doesn't need M1, so it can start while M1 is reviewed.
