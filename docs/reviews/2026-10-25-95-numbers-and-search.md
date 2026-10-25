# Review 95: one number for every post, and Search in the Space header — 25 Oct 2026

**Founder's ok, 25 Oct 14:35.** It starts **after** review 94 (Hold to confirm) is merged into `slice2-app` and build 612 is on his phone. Branch: `claude/r95`, from `slice2-app` once 94 is in.

**Why:**
- **Numbers:** in a Space, only work items have a number ("NST-023"); notes, checklists, announcements, scheduled activities, files and reports don't. The founder reads that as inconsistent, and it is. On a site, everything that gets logged has a serial: site instructions, notices, transmittals, daily reports.
- **Search** is built (`search_space`), but:
  - it sits behind ⋯, so the founder couldn't find it, and a foreman won't either (the one-minute rule);
  - it can't find a number: typing "NST-023" or "23" finds nothing, because `search_text` holds only the title, body and page.

## A. One number for every post

- **One counter per Space** (`spaces.next_item_number`, the one work items use now), for **every kind of post**:
  - note, work item, checklist, announcement, scheduled activity, file, report;
  - a work item under another work item and walk-mode items as today;
  - every item a meeting note makes gets its own number, as today.
- **The number belongs to the post:** `space_posts.number` (not null after the backfill, unique per Space).
  - A work item's `work_items.number` / `ref` is the same as its post's, so there is never a second number or a skipped one. Keep `work_items.ref` if dropping it touches too much; it must always equal the post's.
- **The ref** is shown as today: the Space's `ref_prefix`, a dash, and at least three digits (NST-031).
  - It is always Latin letters and Western digits, kept left to right inside Arabic text, as work item refs are now.
- **When it is taken:** when the post is posted, never for a draft. Drafts stay on the phone, as now.
- **One place assigns it:** a single server path (a `before insert` trigger on `space_posts`, or one function every insert calls), with the Space row locked as now.
  - Every existing insert path must go through it: plain posts, work items, walk mode, meeting notes, templates, reports, the outbox retry.
  - A retry of the same post id never takes a second number.
- **Gaps are accepted:** a Team's post or a cancelled one still uses its number, so others may see NST-030 then NST-032. This is already true for work items.
- **Backfill (one migration, test data only; the pilot hasn't started):**
  - work item posts copy their existing number, so no work item changes its ref;
  - every other post without a number, in each Space, takes the next numbers in `created_at, id` order;
  - then `next_item_number` is set past the highest number.
- **Where the ref shows** for every kind, wherever a work item's ref shows now:
  - the card header (author · ref · time);
  - the folded week line;
  - the "Discuss in chat" quote;
  - Activity rows;
  - report `item_ref` rows;
  - search results;
  - the opened post's page header.
  - Kinds that had no ref get it in the same place and the same small grey style. No new prefixes ("CL-", "NT-"): the kind chip already says what it is.
- `daybook_page`, `search_space`, `my_activity` and the report fill functions return `ref` for every post kind, not only for work items.

## B. Search in the Space header, and search by number

- **The header:** a Search button (Phosphor magnifying glass, 24, a 48×48 target) sits just before ⋯, at the end side.
  - **Search leaves the ⋯ menu**, which keeps Walk, Week report, Daily report and Space info.
  - **Figma:** the "Space header" component (`2080:11849`, DS · Spaces) now has the button. All 118 headers in EN and AR updated with it. The name column fills what is left and ends in "…".
  - The search screen itself (`2543:35148`) is unchanged.
- **Search by number** in `search_space`:
  - the query is trimmed and upper-cased, and Arabic-Indic digits (٠–٩, ۰–۹) are turned into Western digits;
  - "NST-023", "NST023", "nst 23", "023" and "23" all match post number 23 of this Space;
  - another Space's prefix ("ABC-023") matches nothing;
  - a number hit comes **first**, marked as the exact match, then the usual text hits, if the same query also matches words;
  - the reader rule is unchanged: a post the caller can't see (another Team's) is never returned, even by number;
  - tapping the hit opens the card in the daybook, as other post hits do now.
- The search field's hint becomes "Search words or a number, e.g. 23" / «ابحث بكلمة أو رقم، مثل 23».
  - The digits come from the string, not from the code.
  - In Arabic the example stays in Western digits.

## Tests

**SQL:**
- every post kind gets a number, and numbers are unique per Space;
- a work item's two numbers are always equal;
- the same post retried keeps one number;
- two writers posting at once never get the same number;
- the backfill numbers non-work posts in order and leaves work item refs unchanged;
- `search_space` finds by every form above, including Arabic digits;
- it never returns another Team's post by number;
- a non-member gets nothing.

**App:**
- the ref shows on a note, a checklist, an announcement, a scheduled activity, a file and a report card;
- the header has Search, and ⋯ no longer does;
- typing "23" puts NST-023 first;
- the hint in EN and AR.

**Screenshots (EN and AR, 390×844):**
- R1: a daybook with a note, a checklist and a work item, each with its ref;
- R2: the Space header with Search;
- R3: the search screen with "23" typed and the number hit first;
- re-shoot any frame where a header or card changed.

## Live
- One new migration, **not live** until the lead checks it on the stand-in and the founder says yes. It is pushed from the PC as the only file, then a read-only check:
  - no post without a number;
  - no duplicate numbers in a Space;
  - work item refs unchanged.
- No function deploy is needed.
