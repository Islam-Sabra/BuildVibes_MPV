# Review 50: the founder's slice 1 test, findings — 17 Oct 2026 (running list)

The founder is testing slice 1 (build af2802b) on his Xiaomi and the emulator. The findings collect here; fixes are decided at the end of the test.

## F1. The + (Create) is expected to make a work item
On his first try, the founder tapped the orange + to write a work item and landed in the Home feed composer. A foreman will do the same. Create is for public posts (H2); a work item is written from inside a Space ("Work item" bar). Fix to be decided after the test.
- **Lead's first thought:** + opens one small choice, "Post to everyone" or "Work item in a Space ▸" (last Space first). That would be one tap more for posts, and no dead end.

## F2. A reply to a reply loses who was answered (Home feed)
- **What the founder saw:** A comments on a post, B replies to A, then C replies to B. C's reply shows as a reply to A.
- **Cause (server, migration 12 `reply_post`):** `reply_to` may only point at a top-level reply (`r.reply_to is null`). So a reply to a reply is stored against the top comment, and the person actually answered is lost.
- **The rule (as LinkedIn and Facebook do it), to confirm with the founder:**
  - keep **two levels** on screen: a comment, and its replies under it;
  - a reply to a reply sits under the same comment but reads **"Replying to {the person answered}"**, and that person gets the notification.
  - No deeper nesting: it doesn't fit a phone.
- **Fix:** a small migration plus the app.
  - `reply_post` accepts a reply to any reply on the same post. It stores the person answered and files the reply under the top comment.
  - The thread shows "Replying to …" with that person's name.
  - The `post_reply` notification goes to the person answered (and the post's author, as now).
  - Tests: three levels of answering; the notification goes to the right person; a deleted reply's answers stay under the same comment.

## F3. No way into your Spaces from Home, and no way to create or join one
Home → Spaces (`SpacesDayTab`, "your day") lists only Spaces with something new today, so on a quiet day it shows nothing, even though the founder has two Spaces. New Space is reachable only through Profile → people icon → My Spaces → Create.
- **Fix:** Home → Spaces always lists **all your Spaces**: Spaces with news today first, then the rest, most recent first.
- Above the list sit **New Space** and **Enter an invite code**. With no Space, the empty state shows the same two, large.
- A foreman with a code from his engineer must reach "Enter an invite code" in one tap from Home.

## F4. No "site only" wording (the founder's rule, repeated)
BuildVibes is for the whole industry: offices, BIM, design, suppliers as well as sites (rule 2). "Your day on site" says this is for site works only.
- **Remove or neutralise every general phrase that assumes a site**, in English and Arabic:
  - `homeDayTitle` "Your day on site" → **"Your day"**;
  - `postWritingHint` "What happened on site today?" → **"What happened at work today?"**;
  - `feedEmpty` "Share what happened on site today." → **"Share what happened at work today."**;
  - `spacesEmptyBody` "site updates" → **"updates"**;
  - `daybookPlaceHint` "Where on site" → **"Where"** (a room, a level, a drawing or an office);
  - `spacesInviteHow` "read it out on site" → **"read it out"**.
- **Kept, because it's only shown when chosen:** "day N on site" in the daybook masthead appears only when a Space admin sets **On site since**. An office or BIM Space never sets it, so it never sees it.
- **Check:** grep both ARB files for "site" and "موقع" and list any other general phrase in the report.
