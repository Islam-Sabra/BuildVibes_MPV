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
- **Status:** the whole emulator restarted (not only the app), and the log wasn't read before the restart. Not reproduced: the same Sign as done then worked on the emulator (the send-back and check loop afterwards).
- **In the fix round:** search the emulator's and the phone's logs for any `FATAL EXCEPTION` in BuildVibes today. If one is found, it's the first fix, with a test. If not, close F12 as an emulator restart.

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

## F16. Updates by press, not swipe
The founder expects to add an update with a **press**, not a swipe. A swipe is hidden: nothing on screen says it exists, and a foreman won't discover it (rule 2).
- **Fix:**
  - **Long-press** a slip: "Add update" is in the menu for everyone who may add one (owner, Lead, Crew), on every work item, sign-off and send-back slip, not only on your own.
  - **Short press** a slip: it opens the slip (its full page comes in slice 5). Until then, a short press shows the same menu, so a tap is never a dead end.
  - The swipe stays as a shortcut for those who find it, never the only way.

## F17. "Waiting to send" stays after the post has sent
- **What happened:** in airplane mode the work item showed "Waiting to send" (right). With airplane mode off, it reached the server: Omar's emulator showed it. On the founder's phone the slip kept saying "Waiting to send" for a while after that, then the label went by itself. **Downgraded:** it isn't stuck, only late.
- **Fix:** when the outbox sends a post, its local slip is replaced by the server's entry, matched by the app-chosen id, and the label goes at once.
  - Check there is no second, duplicate slip.
  - Test: a post made with no signal, then the signal returns, then exactly one slip, without the label, within a few seconds, with the app open and also after it's reopened.
- It's the same family as F11 (the page must reflect the server).

## F18. A Home post appears on the founder's phone but not in Omar's feed
- **What happened:** a post written with + appears on the phone. On the emulator (Omar), it doesn't appear even after pull-to-refresh and switching tabs. Posts are public to everyone signed in (§9), so Omar should see it.
- **To check (Claude Code, read-only):**
  - did the post reach the server, or is the phone showing only its local slip?
  - does `feed_page` as Omar return it?
  - is there a block or mute between them?
- The cause and the fix go here.

## F19. The feed card and the post page don't look like the agreed design
The founder compared Omar's screens (emulator, Arabic) with what was agreed: text size, spacing and alignment aren't at the prototype's level. Measured against AR H1 `2564:184` (and EN H1 `2555:35276`).

**Feed card (Home):**
- **The ⋯ menu** sits on its own line, lower than the name. In the frame it's level with the author's name, at the card's top trailing corner (top-left in Arabic).
- **The author block** is small and light. The frame has the avatar, the **name in semibold** and the **headline under it** ("رئيس عمال MEP، جلف بيلد"). When a person has no headline, the name sits centred with the avatar, with no empty line.
- **The text** is smaller and further from the author than in the frame. Use the frame's body style and spacing (text directly under the author block). No large empty area inside a short post: the card hugs its content.
- **The actions** (مفيد, رد, and the share arrow on the far side) take the frame's size and position, with 48-point tap areas.
- **Time:** the spine shows the time (F15 fixes the cut "1:5…").

**Post page (replies):** this screen still has the 0.9.0 look and wasn't restyled in slice 1.
- **The post at the top:** the same card as the feed.
- **Each reply** is a small slip:
  - the avatar, then the **name and time on one line**;
  - "Replying to …" under them when it answers a reply (F2);
  - the text in the body style;
  - مفيد and رد under the text, aligned with it;
  - ⋯ level with the name, at the top trailing corner.
  - No reply without an avatar. Consistent widths, not bubbles of random width.
- **The reply bar:** the frame's input style, with the sender's avatar, the field, and the send button on the end side.
- **The same post, three identical replies** ("hello islam" ×2, "helllo islam") from Islam Ahmed: check whether that was three sends or a retry that posted twice. The id is chosen by the app, so a retry must never duplicate. If it was a retry, it's a bug; add a test.

**Check:** a screenshot test of a feed card with no headline, a long post, a short post, and a post page with 3 replies (one "Replying to"), in EN and AR, compared with H1.

---

# Retest, 18 Oct 2026 (build 7060c03)

## F20. An Activity row opens the Space, not the work item
- **What happened:** the founder tapped an Activity row about a work item. The Space opened at its newest entries, and he had to find the item himself.
- **Expected:** the row opens **the slip it's about**: the Space scrolls to that entry and highlights it briefly, wherever it sits in the daybook. For a sign-off, that's the proof slip; for a send-back, the send-back slip; for an update, the update.
- **Bring it forward from slice 10:** a foreman who taps "Omar signed as done" must land on that proof, not search for it. The same target is used by pushes, Needs you cards, and Activity rows.
  - If the entry is older than the loaded page, load around it (by its cursor), not from Now.
  - If it was deleted, open the Space with a short "This entry was removed".
- **Test:** an Activity row for an entry three days old opens with that slip on screen and highlighted, in EN and AR.

## F21. The attach button only opens the photo gallery
- **What happened:** in the writing card, attach (📎) opens the phone's pictures only, while the founder expects attachments (PDF, documents, drawings). The camera button opens the camera, which is correct.
- **Expected (daybook.md: a work item has "files"):** attach opens a small choice: **Photo from gallery** or **File** (PDF, Office documents, images). A file goes into the Space's Library and is shown on the slip with its name and revision (`attachments` in `daybook_post_json`, review 45).
- **When:** with **slice 2**, which builds the file post and file upload, not as a slice 1 fix. Slice 1 shows the gallery only. The server side (Library, `space-files`) is already live.
- **Proof photos stay camera only** (founder's decision, review 47). This choice is for attachments to a post, never for the proof of "Sign as done".

## F22. Withdrawn: the due date, time and place were never added
Claude Code saw NST-006 on live with no place, due date or time and reported them lost. The founder confirms he posted it with an owner only, so the server row is correct. **Not a bug.** Test due date, time and place on the next work item, through + → Work item in a Space ▸.

## F23. The masthead shows the wrong day while older slips are in view
- **What happened:** the masthead said "Sunday 18 October" above Saturday's 4:07 and 4:08 pm slips, and then a divider said "Sunday 18 October" again before today's slips.
- **Expected (D1):** the masthead follows the day of the slips at the top of the screen. Above Saturday's slips it says Saturday; the divider before Sunday's slips says Sunday. The same day never appears twice in a row.
- **Test:** a daybook with two days. Scrolled to the older day, the masthead shows that day; at Now, it shows today, with exactly one divider between them, in EN and AR.

## F24. The keyboard hides the update being written
- **What happened:** on the founder's Xiaomi, after Add update the keyboard opened over the field, so he couldn't see what he was typing. He typed blind, then pressed the keyboard's OK to close it and read the text.
- **Severity: high.** Every text field must stay visible while typing, above the keyboard; a foreman can't type blind.
- **Fix:** the update sheet (and every sheet with a text field: send-back note, proof note, reply) moves up with the keyboard (`viewInsets.bottom`, `isScrollControlled`, the sheet scrolls so the field and its send button sit just above the keyboard).
  - Check on the Xiaomi (HyperOS, gesture bar) and with the keyboard's suggestion strip on, not only on the emulator.
  - The keyboard's action key sends only where a single line makes sense; in a multi-line note it adds a new line, and the send button stays visible.
- **Cause seen in the founder's screenshot:** the Add update sheet quotes the whole slip, with its full-size photo and stamp, so the field is pushed below the keyboard. **The sheet quotes the item in one line** (ref, title, a small thumbnail), with the field right under it.
- The keyboard's ✓ key sends the update at once. That's fine for a one-line update, once the text is visible.
- **Test:** a widget test with a 300-point keyboard inset: the field and the send button are fully on screen, for each sheet, in EN and AR.

## F25. A work item and what happened to it read as separate posts
- **What the founder said:** the work item, its proof, the send-back, the check and the update each appear as a separate slip with its own area. At first look they read as separate issues. He wants a work item and its updates to read as **one element**.
- **Lead's recommendation (needs the founder's ok: it changes the signed-off prototype):** **one card per work item**.
  - The card holds the item (title, owner, due, place), its current stamp (OPEN, DONE, SENT BACK, CHECKED), the latest proof photo, and a short trail inside, one line per event ("Omar signed as done · 10:56", "Sent back: Photo missing · 10:52", "Islam: Area cleaned · 10:59"). The last three lines show; "Show earlier" opens the rest.
  - When something new happens, the card moves down to Now, as a chat moves to the top in WhatsApp. On the earlier day, a thin one-line trace stays ("Omar signed as done · Fix door closer ▸"), so each day's record is still true; tapping it goes to the card.
  - The gestures stay: double-tap the photo to check, long-press for the menu, the paper clip when it needs you.
  - Slice 2's checklists, announcements and files follow the same rule: one card, its trail inside.
- **Cost:** the lead redraws D1, S1, E and the AR daybook in Figma first, for the founder's look. Then a server change (`daybook_page` returns one entry per post, at its last activity, with its events inside, plus the traces) and the slip rework: about 2–3 days, before slice 2.
- **Cheaper alternative, not recommended:** keep separate slips and link them (a thread line on the spine, a ref chip). About a day, but an item still takes four slips on screen.

## Retest results so far (steps 1–6)
- **Passed:** no "Notifications aren't reaching this phone" line; + offers "Post to everyone" or "Work item in a Space ▸"; sign without a photo with the note required (F6); "Sign as done" only opens the proof screen (F7); the send-back slip takes the clip and Sign as done, never twice; long-press menu on a slip (F16).
- **Undo after "Send as done" (F7):** Undo at 1.2 s sent nothing and brought back the proof screen with the photo. Left alone, the sign-off reached the server after exactly 5 seconds.
- **Pushes to the emulator:** sent on live with no error. They didn't reach the emulator because its Play services connection had gone stale after the PC changed networks. After switching the emulator's network off and on, the push landed within 6 seconds. Not an app bug.

## Test note: emulators and pushes
Before testing pushes on an emulator, switch its network off and on, especially after the PC has changed networks. A stale Play services connection looks exactly like F9 ("no push"), but the server log shows the push sent with no error.
