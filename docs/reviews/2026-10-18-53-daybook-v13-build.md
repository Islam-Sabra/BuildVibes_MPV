# Review 53: Daybook v13 (one card per work item, two text sizes) and the retest fixes — 18 Oct 2026

During the retest, the founder found that a work item and what happened to it read as separate posts. He also found that the time column narrows the slips and that the headings are too big. He approved three changes:
- **one card per work item** (F25);
- **full-width cards with the time inside** (F26);
- **two text sizes** (F27).

All three are drawn in Figma and written into `docs/product/daybook.md` ("The daybook (v13)"). The findings are in review 50.

**Figma (the prototype for this round):**
- **English:**
  - `2581:35611` Islam's daybook;
  - `2582:35982` Omar after a send-back;
  - `2582:36114` checked, with Undo;
  - `2582:77206` Add update above the keyboard.
- **Arabic:** `2583:373`.
- **Text sizes:** `2583:76944`.

Branches:
- `slice1-v13` from `main` (after the merge in Part 0), for the app;
- `daybook-cards-db` from `main`, for migration 26.

Push and report after each part. About 2–3 days.

## Part 0: finish the retest first (done, 18 Oct)
The retest is complete; the findings are in review 50. The slice 1 loop works on a real phone, so first:
1. Merge `slice1-fixes` into `slice1-daybook`, then `slice1-daybook` into `main` (after `test-fixes-db`, which is live). Analyze and tests must be clean on `main`.
2. Branch `slice1-v13` from `main` and start Part A.

**Part D includes F30 and F32:** the founder approved H1 v4 and A1 v3 on 18 Oct; the EN and AR frames are listed with each item.

## Part A: the server (migration 26, `daybook-cards-db`, not live)
- **`space_posts.last_activity_at`** (not null):
  - set at insert;
  - raised by a trigger on every new `work_item_events` row, and on any edit, reassignment or cancel that already writes an event;
  - back-filled from the latest event or `created_at`;
  - index `(space_id, last_activity_at desc, id desc) where deleted_at is null`.
- **`daybook_cards(p_space, p_before, p_limit, p_before_id)`:** one row per visible post, newest activity first, with the cursor `(last_activity_at, id)`. Each row carries:
  - the post as `daybook_post_json` gives it today;
  - `last_activity_at`;
  - **`proof`:** the latest sign-off's photos and note, and its outcome (`done`, `checked`, `sent_back`, `cancelled`), with who and when. This is the card's photo and stamp.
  - **`history`:** the post's events, newest first, up to 50. Each has its kind, who (id and name), note, reason, time and, for a sign-off, its photo paths. Plus a `history_more` flag.
  - **`needs_me`:** `to_sign`, `to_check` or null. This drives the paper clip and the card's one action.
- **`post_history(p_post, p_before, p_before_id, p_limit)`** serves "Show earlier" beyond the first 50.
- **Visibility is as today:** `is_member` and `can_see_space_post`. A deleted post's history goes with it; a cancelled one stays.
- **Kept for now:**
  - `daybook_page` stays until no build calls it; a later migration drops it;
  - `daybook_month` is unchanged.
- **The traces are made by the app, not the server** (Part B). Paging by last activity means any card with activity on an older day is already loaded when that day is on screen.
- **Tests:**
  - order by last activity, and a new event moves a card to the top;
  - cursor paging with equal times;
  - a non-member gets nothing;
  - a Viewer gets cards but `needs_me` is null;
  - the history cap and `post_history` paging;
  - a deleted post is hidden, a cancelled one stays.
- **Push it alone and report.** It goes live with the founder's yes, as the only file in the push.

## Part B: the daybook in the app (`slice1-v13`)
Follow the frames above, in English and Arabic.
- **Masthead:** one line, the day (bold) and the date (grey). No weather.
- **Cards:** no hour spine and no time column. Cards are full width, 16 from each edge, paper with the torn top edge.
- **One card per work item.** From top to bottom:
  - the header: author, ref, and at the end the time of the latest activity;
  - the title;
  - the facts (owner and due, place) as grey lines with icons;
  - the latest proof photo with its stamp;
  - the history: the last three lines, each with a small face and its time, behind a thin line on the leading side. **Show earlier** opens the rest in place (then `post_history`);
  - the one action for the viewer: "Sign as done" for the owner while open or sent back; the double-tap hint for the author while done; nothing once checked.
- **New activity moves the card to Now.**
  - If the person is reading older days, the scroll position stays and the "New ↓" chip appears (F11).
  - Undo (5 s) still holds a check or a sign-off before anything is sent; the card shows the result at once.
- **Traces:**
  - for each loaded card, every earlier local day (phone time) on which it had an event gets one row at that day's latest event time: the face, "{who} {what} · {title}", the time, and ›;
  - tapping a trace scrolls to the card and opens its history at that event.
- **Gestures:**
  - double-tap the photo to check (the author, while done);
  - long-press or tap the card for the menu (Check, Send back, Add update, Edit, Give to someone else, Cancel, as allowed);
  - the swipe stays as a shortcut.
- **Writing in place is unchanged:** the draft card appears at Now.
- **Removed:**
  - the separate sign-off, update and send-back entries and their slips;
  - the hour spine and its time column.
- **Tests:**
  - a card's history shows the latest three in order, with Show earlier;
  - a new event moves the card and keeps the reading position;
  - a trace appears on each earlier day and opens its card;
  - golden screenshots of the four frames, in EN and AR.

## Part C: text sizes v2, two sizes (founder's choice)
Change the values in `BvType`, so every screen follows. The token names stay.

| Role | Latin | Arabic | Tokens |
|---|---|---|---|
| Main, bold | 15/22 Bold | 16/26 Bold | `headingMd`, `titleLg` |
| Main, semibold | 15/22 SemiBold | 16/26 SemiBold | `titleMd`, `labelLg`, `button` |
| Main, medium | 15/22 Medium | 16/26 Medium | `labelMd` |
| Main, regular | 15/22 Regular | 16/26 Regular | `bodyLg`, `bodyMd`, `bodySm` |
| Small | 12/16 Medium | 13/18 Medium | `labelSm`, `overline` (SemiBold) |
| Small, regular | 12/16 Regular | 13/18 Regular | `metadata` |

- **`displayBrand`, `headingXl` and `headingLg` keep their values**, but are used only in `lib/features/entry/` (sign-in, loading).
  - There are three exceptions: `BvAvatar` xl initials, `BvCodeTag` (the invite code) and `BvCodeField`.
  - A test fails on any other use.
  - Today's other uses move to the main size:
    - the daybook masthead;
    - `spaces_day_tab.dart`;
    - `activity_screen.dart`;
    - `profile_parts.dart`;
    - `home_screen.dart`'s wordmark (Bold, main size).
- **Then check every built screen** in EN and AR at 390×844:
  - Home (feed and Spaces);
  - the post page;
  - Create;
  - the Space (daybook, Space info, People);
  - Activity;
  - the profile;
  - Settings;
  - the sheets.

  Fix any overflow, then send the screenshots. The lead reviews them all against the rule.

## Part D: the retest fixes
- **F20, open the exact card:**
  - an Activity row, a push or a Needs you card opens the Space **at that card**, loading around its cursor, and highlights it for a second;
  - for an event, the card's history opens at that line;
  - if the post was deleted: "This was removed".
- **F23:** the masthead shows the day of the content at the top of the screen; one divider per day, never the same day twice in a row.
- **F24, the keyboard:**
  - every sheet with a field (update, send-back note, proof note, reply) sits above the keyboard, as in `2582:77206`;
  - the item is quoted in one line with a small thumbnail;
  - test: a 300-point keyboard inset in EN and AR, and check on the founder's Xiaomi.
- **A build number for each build:**
  - `versionCode` goes up with every build;
  - Settings → About shows the version, the build number and the short commit, so the founder and the lead can see which build is on a phone.
- **F29 (withdrawn):** check once that a place set through ⋯ → Location reaches the server, online and from the outbox, and add that to the outbox test.
- **F28, Home → Spaces:** "Join with a code" instead of the cut "Enter an invite co…"; a quiet › instead of the orange Open buttons; Needs you grouped by Space; "added an update" wording; the last-activity time on every Space; the Space emblem in the tile.
- **F30, replies visible on the feed card:** the latest reply line with up to three faces, no number (review 50). Server: the latest live reply and up to three reply authors in the feed and post JSON; it can go in migration 26. Frames (founder ok, 18 Oct): H1 v4 EN `2587:35849`, AR `2588:412`, which also brings Home in line with v13: no hour spine, full-width cards, the one-line date, two sizes. The wordmark is a logo and keeps its size.
- **F31:** no Reply and no Useful on your own replies.
- **F32, Activity v3:** one list, newest first, grouped by day, all sources mixed; one slim "Needs you ›" line at the top that opens Home → Spaces (review 50). Frames (founder ok, 18 Oct): A1 v3 EN `2587:76920`, AR `2589:445`.
- **F21** (attach a file) is slice 2. Nothing in this round.

## Part E: report
- Push after each part.
- Send screenshots of the four frames and the Part C screens, in EN and AR.
- Migration 26 waits for the lead's review and then the founder's yes.
- After that: a build on the founder's phone and the emulator, and a short retest of the daybook loop.
