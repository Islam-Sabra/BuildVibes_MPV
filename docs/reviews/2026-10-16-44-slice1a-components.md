# Review 44: slice 1a (Daybook components) and the six server questions — 16 Oct 2026

Branch `slice1-daybook` (be64021). I compared the 18 sheets in `docs/screens/slice1/` with D1 `2518:33001`, E `2524:33180` and the AR frames `2547:35195` and `2547:35369`.

**What held up:**
- The slip, the torn edge, the four stamp sizes and colours, and the paper clip on the end side (left in Arabic).
- The timeline and its Now dot, the day divider, the month drop-down (week start from the market pack), and the post bar with its Viewer version.
- The long-press menus, the send-back card (the reasons are one single choice, rule 6), the give-to picker and the undo bar.
- Mirroring is right throughout: the send icon points left in Arabic, the month arrows behave correctly, and the stamps sit on the start side.
- I accept the paper clip sticking out above the slip. In Figma it sits at y −14 too; only the scrolled frame cuts it off.
- I accept one stamp position for every word, as long as a stamp never covers the title.

**Verdict:** approved after C1–C5. They are small; do them at the start of 1b.

## C1. Avatar initials
- **Arabic names get one letter:** "ع" for عمر حداد, "س" for سارة, as the AR frames show. Two joined Arabic letters read as a word ("سم", "عح"). Latin names keep two letters.
- **Latin initials are the first letters of the first and last name as typed:** Sara Al-Mutairi is "SA" (D1 and E show SA). Don't drop the "Al-".
- **"You" and "أنت" are labels, never initials.** The avatar shows the person's own initials or photo. The sheets show "Y" and "أ".

## C2. Arabic wording
- "For you, by today 2 pm" reads in Arabic as "before today": "لك، قبل اليوم 2 م". The AR frame has **"لك، قبل الساعة 2 ظهرًا اليوم"**. Fix this ARB pattern, and check the other due patterns (tomorrow, a weekday, a date) read the same way.
- Demo and test words come from the AR frames, never a fresh translation:
  - "sleeves" are **جلب** (the AR frame has "تركيب الجلب عند المحور C7"), never أكمام, which means clothing sleeves;
  - a level is **الدور** ("الدور 4", "بلاطة الدور 3");
  - "ركّبت الست كلها وراجعتها مع فريق الكهروميكانيك."
  - This matters most for `seed_daybook.sql`, because the founder will see it.
- People in the seed are the prototype's: Islam Ahmed, Sara Al-Mutairi, Omar Haddad, Rakesh Nair, Lina Khalil, Mona Adel, Yousef Karam. Not Lina Saad or Mona Faris.

## C3. The writing card has a straight dashed edge
In Figma (E `2524:33180`, AR `2547:35369`) the writing card is a dashed rectangle with a small radius. The torn edge belongs to a posted slip; a draft hasn't been torn off yet. The prototype wins, so use the straight dashed edge.

## C4. Tap targets: keep the look, enlarge the touch area
Keep the visual size of the month arrows, the Sign as done pill, the microphone and the photo's remove button. Give each one a touch area of at least 48×48 (rule 2: a foreman on site, with gloves). A test should check the hit area.

## C5. Show only what works in slice 1
These components are fine as built. On screens, show only what slice 1 can actually do:
- **Kind chip:** Work item only (the other kinds come in slice 2). With one kind, show the chip without the drop-down arrow.
- **Writing ⋯ menu:**
  - hide **Template** until slice 7;
  - keep **Checklist** (points on a work item) only if it works end to end through `edit_space_post`; otherwise hide it until slice 2.
- **First-day card:** hide **Pin an announcement** until slice 2.
- **Give-to picker** (in 1d): only Lead and Crew members, active and allowed to see the post; a Viewer can't own a work item. The server already refuses this; the picker shouldn't offer it.

## The six questions
| # | Question | Answer |
|---|---|---|
| 1 | Weather | **Founder's decision** (it needs an outside provider). The lead recommends leaving it out of the MVP: the masthead hides it. Until he answers, build the masthead without it. |
| 2 | "Day 41 on site" | **Lead's call:** an optional **"On site since"** date that a Space admin sets in Space info. "Day N" counts calendar days from it, with that day as day 1. If it isn't set, the line shows only the date. Never count from the Space's creation date, which would be a misleading number for a Space opened mid-project (rule 3). I'll add the row to SI1 (EN and AR) in Figma before part 1e. |
| 3 | Due time | **Yes, optional.** Add `due_at timestamptz` next to `due_date`. The phone sends both (its own date and time), so no time zone goes in SQL. A timed item is Late after `due_at`; a date-only item is Late from the next day, as now. Editing and the "Edited: due moved…" line cover the time too. |
| 4 | Undo of a check | **No server change.** The app holds the check for the 5 seconds of the undo bar, then sends it through the outbox. If the app is closed during those seconds, it sends on the next open. The owner never gets a "Checked" push for a check that was undone. Use the same rule for every action with an undo bar. |
| 5 | Month drop-down | **Yes:** one read function for the days in a range (at most 62) that have posts the caller can see, and the days with something due that isn't checked or cancelled. Team posts follow `can_see_space_post`. The phone groups by its own days, with no time zone in SQL, as `my_calendar` does. A dot per day, never a count. |
| 6 | 12- or 24-hour clock | **Follow the phone's own setting** (`MediaQuery.alwaysUse24HourFormat`), not the market pack. Use one format everywhere on a screen. The prototype mixes "09:40" and "2 pm"; that's a drawing slip. |

## Migration 23 (branch `daybook-extras-db`, before part 1b)
- `space_posts.due_at` (optional) through create and edit, plus the Late rule (answer 3).
- `spaces.site_start_date` (optional), set only by a Space admin with a function (answer 2), and shown on the daybook page.
- The month drop-down read function (answer 5).
- **If the founder says yes to weather:** nothing in this migration. That would be a separate decision about a provider.
- Each with SQL tests:
  - a non-member reads nothing;
  - a Team's post never lights a day for someone outside the Team;
  - only an admin sets the start date.
- Update `data-model.md`.
- Timestamp after `20261016180000`.
- Push the branch and report, then I review it. It goes live with the founder's yes and must be the only file in the push.

Then part 1b on `slice1-daybook`, with C1–C5 first.
