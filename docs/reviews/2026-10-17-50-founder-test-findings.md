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

## F5. Posting gives a sound
- A short, soft sound with a light haptic when a post or a sign-off is accepted.
- It follows the phone's silent mode: silent means haptic only.
- Nothing plays for a post that is only waiting to send; the sound comes when it actually sends.

## F6. Sign as done must not always need a photo
The server already accepts **a photo or a note** (`sign_done`: "add a photo or a note"); only the app forces the camera.
- **Fix:** "Sign as done" opens the proof screen with the camera ready, plus a clear **"Without a photo"** link.
- Without a photo, the note is required ("What was done?").
- The proof slip shows the note, with no photo and no empty frame. The checker can still send it back with "Photo missing".
- Camera only stays the rule *when* a photo is added (founder's decision, review 47).

## F7. No accidental "done"
The founder worries that the owner signs by mistake while scrolling.
- **Fix:**
  - **A tap never signs.** "Sign as done" only opens the proof screen; nothing is sent until **"Send as done"** is pressed there.
  - After sending, the same **5-second Undo** bar as a check, and nothing goes to the server until it closes (review 44, answer 4).
  - The pill and the camera button keep a full 48-point tap area, but they react to a tap, never to a scroll that starts on them.
- No extra "Are you sure?" dialog: the proof screen plus Undo already protect it, without slowing every sign-off.

## F8. "Notion-like" pages in a work item
Not missing: **opening a post in place** (blocks, /, turn into, tables) is **slice 5**, and **work items under one** are slice 6. Their server side is live (migration 20), but no screens are built yet.

## F9. Pushes silently never reach the founder's Xiaomi
- **What happened:** Omar's join request reached Activity and Home → Spaces in the app, but no push arrived.
- **Cause:** the queue and the push function worked; the push went to an old token from 13 Oct. On the Xiaomi (22120RN86G, Android 14, HyperOS), Firebase Messaging fails at start ("FCM Registration failed!. Won't retry the operation."). The app swallows the error, so it never registers a token and shows nothing.
- **Phone side (founder):** Google Play services and BuildVibes set to "No restrictions" for battery, BuildVibes Autostart on, then restart. If that fails, clear Play services' cache.
- **App fix, in the test-fix round, not slice 10:** pushes are the pilot's lifeline, and cheap Xiaomis will be on site.
  - **Retry getting a token:** on each start, on return to the app, and with backoff. Re-register whenever the token changes, and on each start even when signed in from an older build.
  - **Show the real state:** if no token after a retry, a quiet line on Home and in Settings → Notifications: "Notifications aren't reaching this phone", with **"Fix it"**. On Xiaomi, that opens the app's settings page with short steps (Autostart, battery "No restrictions").
  - **Server cleanup:** a token not seen for 30 days is dropped, so pushes don't go to dead devices.
  - **Report the failure:** a "no token" state is visible to us (an anonymous count, no personal data), so the pilot shows how many phones are affected.

## F10. Home → Spaces cards: hierarchy and reach (Omar's screen, emulator)
- **The header takes too much of the screen:** "SATURDAY 17 OCTOBER / Your day on site / 1 thing needs you · 1 Space active" is about a fifth of the screen above the first card.
  - Make it **one compact line**: the date, then "1 thing needs you", in a small type.
  - The title goes (F4 already removes "on site"). The useful part is the list.
- **The Space name comes first, and bigger.** In a Needs you card, the order is:
  1. the **Space name** (a semibold label, with its emblem), as in the "Today in your Spaces" rows;
  2. **what happened** ("Islam Ahmed gave you a work item: Fix cable tray at level 2");
  3. the ref and time, small.
- **Open on the trailing side, within thumb reach:** the **whole card** opens the item.
  - The "Open" button moves to the **end side** of the card (right in English, left in Arabic), level with the text, not under it.
  - The card is at least 64 points tall, so it's easy to hit.
- The same order and the same tap rule apply to every card in Needs you (NY1) and to Activity rows.
- **No duplicates.** The same event showed twice: in Needs you ("gave you a work item") and in "Today in your Spaces" ("raised NST-002"). With F3, the tab has two parts:
  - **Needs you:** only what you must act on;
  - **Your Spaces:** every Space once, with its latest news *that isn't already in Needs you*. With nothing else new, just the name and the time of its last activity.
  - Never counts.

## F11. The daybook doesn't refresh when a push opens it
- **What happened:** the founder tapped the push for Omar's sign-off and the Space opened, but the old page was still showing. Only after going back to Home and in again did the proof slip appear.
- **Fix: the daybook is never stale.**
  - Load the newest page when it's opened from a push, when the app comes back to the front, and when a push for this Space arrives while it's open.
  - Pull down to refresh too.
  - New entries slide in at Now, with no jump of the scroll position if the person is reading older days; a small "New ↓" chip takes them there.
- Slice 10 still adds "open the exact slip". This fix is only about the page being current.

## F12. The app closed on "Sign as done" (emulator, Omar)
- **What happened:** on the second work item, tapping "Sign as done" closed the app completely. The first sign-off on the emulator had worked.
- **Status:** Claude Code reads the emulator's crash log. The cause and fix go here.
- A crash in the core loop is the most serious kind of finding: fix it first in the test-fix round, with a test that reproduces it.

## F13. Activity rows can't be tapped
- **What happened:** in Activity (Arabic), the rows are only notices. Tapping "فحص NST-003 من Islam Ahmed" does nothing.
- **Fix:** every row opens what it's about, as Needs you does:
  - a work item opens the Space's daybook (the exact slip comes in slice 10);
  - a join opens the Space;
  - a reply opens the post.
  - The whole row is the tap area; no row is a dead end.
- **The "REV F" box at the top of the Space card in Activity:** unclear to the founder. It reads like a drawing revision, not an activity. Remove it, or say plainly what it is. The A–F letters per row need the same check: they look like a revision table.

## F14. "تم الفحص" fits only real inspections
**Founder's decision; the lead's recommendation is below.**
- "Checked" in Arabic is "تم الفحص" (glossary). The founder notes it only fits work that was physically inspected; a drawing, a submittal or an office task isn't "فحص".
- **Lead's recommendation: "تم التحقق"** (verified). It fits site work and office work alike, and it's plain Arabic.
  - The verb is "تحقّق"; the button is "تحقّق"; "Double-tap the photo to verify it" is "انقر مرتين على الصورة للتحقق".
  - Avoid "مُراجَع", which is too close to "مُرجَع" (Sent back), and "مُعتمد", which suggests a formal approval (approval codes are out of the MVP).
- English stays "Checked".
- **If the founder agrees:** update the glossary in `CLAUDE.md`, `docs/product/arabic-glossary.md`, both ARB files, the stamps, and the AR Figma frames (lead).

## F15. The Arabic time column is cut off
On the Arabic daybook, the time beside the spine shows "3:5" and "4 عصرًا", because the 12-hour time with its period ("3:58 عصرًا") doesn't fit the column.
- **Fix:** the time column fits the longest time in the current language. Or, in the 12-hour clock, the period goes on a second, smaller line under the time.
- Add a screenshot test with "11:58 مساءً".
