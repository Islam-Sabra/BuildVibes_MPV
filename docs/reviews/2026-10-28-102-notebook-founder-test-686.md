# Review 102: the founder's notebook findings on builds 686/701 — 28 Oct 2026

**Founder, 28 Oct 15:05–15:13.** He said "fix what I sent while I keep checking". More findings may be added as N6 and later.

**Status:** approved by the founder, from these written rules. No new frames, except that the lead updates BH9 (the Filter card) for N5 in Figma.

## N1. The time picker: no helper line
- Under the time, a line reads "in the morning". It doesn't follow AM/PM, which is a bug, and it adds nothing.
- **Remove it** in English and Arabic, everywhere the time picker is used:
  - the notebook's Remind me (swipe → Reminder, and 📎 → Reminder);
  - dates and times in Spaces (due, scheduled activity, pin until).
- AM / PM stays above the time, as one single choice (rule 6). In Arabic it reads «ص / م».

## N2. Time by scroll wheels, never typed
- The clock face, and its switch to typed boxes, both go. Typing allowed impossible times ("111", "75").
- **One control:** scroll wheels for the **hour (1–12)** and the **minutes, in 5-minute steps** (00, 05, … 55), with AM / PM (N1) above. Only valid times can be chosen.
- **The wheels:**
  - they snap to a value;
  - the chosen row shows between two lines, in the main text size;
  - the rows above and below fade;
  - each step gives a light haptic.
- **Arabic:** Western digits, with the wheels' order mirrored (minutes, then hour, reading right to left).
- **Screen readers:** each wheel is an adjustable control ("Hour, 9", swipe up and down to change).
- **One shared widget** (`BvTimeWheel` in `lib/shared/widgets/`), used by every time picker in the app.
- **Limits:**
  - a time already passed today can't be set for a reminder today: the wheel greys those out;
  - the default is the next 5-minute mark after now plus one hour.

## N3. Arrange entries by hand: hold, then move
- **Hold and let go:** the entry is selected (unchanged).
- **Hold and move the finger without lifting:**
  - the card **lifts**, with the lifted-slip shadow and a light haptic, and follows the finger;
  - the other entries slide aside (180 ms);
  - a line shows where it will land;
  - near the top or bottom edge, the page scrolls by itself.
- **Release:** it lands there, with "Moved · Undo" for 5 s. The new order is saved.
- **Only within its own day**, so the dates stay true. At its day's edge it stops; to change day or page, use **Move to…** (N4).
- **On the server:** an entry gets a `day_position` within its day, in a new migration, owner only, with pgTAP tests (including that someone else's entry can't be moved). An old build ignores it and keeps the date order.
- **Not during a swipe**, and not while entries are selected.
  - A move must start with a hold. A sideways drag stays a swipe, and an up-or-down drag without a hold stays a scroll.
- **Screen readers:** "Move up" and "Move down" as actions on the card.
- **Reduce motion:** no lift and no sliding, but the move still works.
- Lines inside an entry get the same gesture later, with the drag work already queued.

## N4. "Move" → "Move to…"
- The selection bar's label (entries and lines) becomes **"Move to…" / «نقل إلى…»**, with the same icon.
- The page picker's title becomes "Move to…" too.

## N5. Sorting, inside the Filter card
- **The Filter card gets a third part, SORT** (one single choice):
  - **on the pages list:** Latest activity (default) · Name A–Z · Newest created. **Pinned pages always stay on top.**
  - **inside a page:** Newest first (default) · Oldest first. N3's hand order is kept inside each day in both directions.
- **The choice is remembered** on the phone: once for the pages list, and per page inside pages.
- **When the sort isn't the default,** it shows as a chip under the top bar ("Name A–Z ✕"), like the filter chips; ✕ resets it.
- **Arabic:** «ترتيب: آخر نشاط · الاسم أ–ي · الأحدث إنشاءً» and «الأحدث أولًا · الأقدم أولًا».
  - **"Name A–Z"** compares Arabic and Latin titles each in their own alphabet, Arabic first in Arabic and Latin first in English.

## Tests
- Each rule gets a test, in EN and AR:
  - N1: no helper line;
  - N2: no typed input, only valid values, 5-minute steps, today's past times greyed;
  - N3: hold-and-let-go selects; hold-and-move lifts and reorders within the day only; Undo; screen-reader actions;
  - N4: the labels;
  - N5: each sort, pinned on top, the chip and reset, kept after a restart.
- New shots: the time wheel (EN, AR), and the Filter card with SORT (BH9 again).
