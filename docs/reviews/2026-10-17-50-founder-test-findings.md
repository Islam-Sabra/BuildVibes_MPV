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
- **Also the post page's reply bar** (retest step 11, emulator): it sits behind the keyboard while it opens, so the first tap on send missed. The bar must ride on top of the keyboard from the first frame.
- The keyboard's ✓ key sends the update at once. That's fine for a one-line update, once the text is visible.
- **Test:** a widget test with a 300-point keyboard inset: the field and the send button are fully on screen, for each sheet, in EN and AR.

## F25. A work item and what happened to it read as separate posts
- **What the founder said:** the work item, its proof, the send-back, the check and the update each appear as a separate slip with its own area. At first look they read as separate issues. He wants a work item and its updates to read as **one element**.
- **Founder's ok (18 Oct): one card per work item.** Redrawn as Daybook v13 (see `daybook.md`, "The daybook (v13)").
  - The card holds the item (title, owner, due, place), its current stamp (OPEN, DONE, SENT BACK, CHECKED), the latest proof photo, and a short trail inside, one line per event ("Omar signed as done · 10:56", "Sent back: Photo missing · 10:52", "Islam: Area cleaned · 10:59"). The last three lines show; "Show earlier" opens the rest.
  - When something new happens, the card moves down to Now, as a chat moves to the top in WhatsApp. On the earlier day, a thin one-line trace stays ("Omar signed as done · Fix door closer ▸"), so each day's record is still true; tapping it goes to the card.
  - The gestures stay: double-tap the photo to check, long-press for the menu, the paper clip when it needs you.
  - Slice 2's checklists, announcements and files follow the same rule: one card, its trail inside.
- **Cost:** the lead redraws D1, S1, E and the AR daybook in Figma first, for the founder's look. Then a server change (`daybook_page` returns one entry per post, at its last activity, with its events inside, plus the traces) and the slip rework: about 2–3 days, before slice 2.
- **Cheaper alternative, not recommended:** keep separate slips and link them (a thread line on the spine, a ref chip). About a day, but an item still takes four slips on screen.

## F26. No hour spine: cards take the full width, the time goes inside the card
- **What the founder said:** the time column on the leading side takes space and makes the slips narrow. Put the time inside the card so it uses the full width.
- **Decision (lead, with F25):** no hour spine and no time column. Cards are full width (16 from each edge). The card's header ends with the time of its latest activity; each history line has its own time. Day dividers stay.
- Figma: v13 frames, EN `2581:35611`, `2582:35982`, `2582:36114`, `2582:77206`; AR `2583:373`.

## F27. Text sizes: headings are too big next to the content, on every screen
- **What the founder said:** the day name ("Thursday", 28; Arabic 32) and Home's "Your day" (24; Arabic 28) are very big next to the cards. All screens' text sizes need a study.
- **Founder's choice (18 Oct): two sizes on every working screen** (Figma board `2583:76944`; compared side by side with five sizes).
  - **Main: 15 (Arabic 16)** for everything people read: the day, titles, facts, history, names, buttons. Titles and the day are **bold**; names and actions medium; the rest regular, in grey where secondary.
  - **Small: 12 (Arabic 13)** for times, refs, day dividers and labels.
  - Bigger text only on sign-in and the brand screen, plus three named exceptions: the large avatar's initials, the invite code tag and the code field.
- **In code:** the daybook masthead uses `displayBrand`; `spaces_day_tab.dart` uses `headingXl`; `activity_screen.dart` and `profile_parts.dart` use `headingLg` for titles. Each moves to the rule above. A test fails if a file outside `entry/` and the three exceptions uses `displayBrand`, `headingXl` or `headingLg`.
- **Check:** the lead compares every built screen with the rule (EN and AR) in the next review, with screenshots.

## F28. Home → Spaces: works, four details to fix
Step 9 on the founder's phone: one compact date line ✓; New Space and Enter an invite code ✓; Needs you cards with the Space name first and Open on the end side ✓; every Space once ✓.
- **The second button is cut:** "Enter an invite co…". Use **"Join with a code"** (Arabic **"انضم برمز"**), and let both buttons share the width equally with no truncation in EN or AR at the new main size.
- **Two orange "Open" buttons.** The whole card already opens the item, and only the screen's main action gets the full orange fill (daybook rule 6). Replace "Open" with a quiet **›** on the end side.
- **The same Space name repeats** on each Needs you card. Group by Space, as review 48 said: the Space name and emblem once, then its items under it as rows (what happened, ref and time, ›).
- **Wording and missing time:**
  - "Omar Haddad commented on NST-006" → **"Omar Haddad added an update · NST-006: fix door closer"**, the daybook's word;
  - a Space with nothing new ("Test site") still shows the time of its last activity, as F10 says;
  - the Space tile uses the Space's floor-plan emblem, as in the Space header, not a letter.

## F29. Withdrawn: the place was never set
The founder confirms "Room 3" was only typed in the title; ⋯ → Location wasn't used, so NST-007 correctly has no place. **Not a bug.** Claude Code still checks once on the emulator that a place set through ⋯ → Location reaches the server, online and from the outbox (a cheap guard, since F22 and F29 were both close calls).

## F30. The feed card doesn't show that a post has replies
- **What the founder said:** on Home, a post with replies looks the same as one without. He only found Omar's reply by opening the post. He had asked for this before.
- **Fix (lead's call):** under the post's text, one quiet line with **the latest reply**: the replier's small face and name, and the start of the reply ("Omar Haddad: Seen it, thanks Islam"). When more than one person has replied, up to three small faces sit before it. Tapping the line opens the post at that reply.
  - **No number** (rule 3): faces and the latest words show that there are replies, and who replied.
  - A reply that answers you is in bold until you open the post.
  - The same line goes on the post card wherever it appears (Home feed, profile, project).
- **Server:** the feed and post JSON carry the latest live reply (id, author, first 80 characters, time) and up to three distinct reply authors. A blocked person's replies are never used.
- **Figma (founder ok, 18 Oct):** H1 v4 EN `2587:35849`, AR `2588:412`: the reply line on both cards, plus the v13 rules for Home (no hour spine, full-width cards, one-line date, two sizes).

## F31. A "Reply" button on your own reply
- **What happened:** after the founder answered Omar, his own reply showed a Reply button.
- **Fix:** no **Reply** and no **Useful** on your own replies; only ⋯ (Edit, Delete). Others can still reply to your reply.
- Step 11 itself passed: the reply sits under Omar's, reads "Replying to Omar Haddad" (F2 ✓), and the keyboard didn't hide the text on the phone.

## F32. Activity is split into blocks, so Home's activity sits at the bottom
- **What the founder said:** Activity shows Needs you with the Space names first, then a block per Space (what changed, newest to oldest), and only at the very bottom the activity from Home (replies to his posts). Something that just happened can be far down. The screen needs rethinking.
- **Cause:** A1 v2 groups rows by source (each Space, Your record, Your network, Your posts) and sorts the groups, not the rows.
- **Activity v3 (lead's call):**
  - **One list, newest first,** grouped only by day ("Today", "Yesterday", "Wednesday 14 October"). Spaces, your posts, people and your record are mixed in time order.
  - **Each row** (at least 64 points tall):
    - the person's face;
    - one line saying what happened ("Omar Haddad replied to your post: Seen it, thanks Islam");
    - under it, in small grey, where it happened ("NBKCH SITE TEAM" or "Your post · retest post");
    - the time on the end side.
    - An unread row has a dot and a bold name. Tapping the row opens the exact thing (F20).
  - **No Needs you block:** Needs you lives on Home → Spaces, and showing it twice was the duplication of F10. At the top sits one slim line, "2 things need you ›", which opens Home → Spaces. A row that still needs you carries the paper clip.
  - No groups by source, no REV stamp, no letters. The last 30 days, loading more as you scroll.
  - Two text sizes (F27).
- **Figma (founder ok, 18 Oct):** A1 v3 EN `2587:76920`, AR `2589:445`.

## F33. The Arabic font: Almarai
- **What the founder asked:** Arabic that reads like Facebook. Facebook has no Arabic font of its own; it uses the phone's font. Shown six options side by side (AR page `2590:471`), the founder chose **Almarai** (18 Oct).
- **Change:** Almarai replaces Noto Sans Arabic, in Regular and Bold, subset to Arabic so Latin and digits stay in Plus Jakarta Sans. Details are in review 53 Part C. `CLAUDE.md` and the Figma `Type/Arabic/*` styles are updated.

# Retest of build 298, 19 Oct 2026

## F34. Who the item is for must stand out
- **What the founder said:** "For Omar Haddad · by today 5 pm" is all in the same grey as the other facts. Who it's assigned to should be bold.
- **Fix:** on the card's facts line, **the owner's name is in the medium weight, in the primary colour** ("For **Omar Haddad**", "For **you**"; Arabic: Almarai Bold). The due time stays grey unless it's today (primary colour) or late (red, as now). The same applies in Needs you rows and Activity.

## F35. Why the ref (NST-009) is on the card
- **The founder asked why it's shown.** The ref is the item's short number, so people can name it in a call or a WhatsApp ("is NST-009 done?"), in search, and in the daily and week reports.
- **Lead's call:** keep it, small and grey, in the header. If the founder prefers, it can move to the end of the card, next to the time.

## F36. Finished work folds by week (founder, 19 Oct)
- **What the founder asked:** once a phase is done (e.g. the concrete works), its many work items clutter the daybook. He suggested a manual or scheduled "archive".
- **Decision:** the daybook tidies itself, by week, with no setting.
  - **This week:** every card shows in full, finished or not.
  - **When the week ends** (the market pack's week start), each Checked or Cancelled card of that week folds to **one slim line** on its day: "✓ NST-009 Fix socket Room 4 · checked by Islam Ahmed". Tapping it opens the full card (photo, history).
  - **Open, Done or Sent back items never fold,** wherever they are, so nothing waiting is hidden.
  - **Phases** use "work items under one" (slice 6): one parent card ("Concrete works, level 3 · 6 of 8 checked") that folds the same way when all its items are checked.
  - **No archive schedule setting** (rule 7): the weekly fold is the same for everyone. A manual "close a phase" for admins can come after the pilot if teams ask for it.
  - Folding is display only. Nothing moves or is deleted, and search, reports and profile proof still see everything.
- **Backups are not a user setting.** The record lives on the server, and backing it up is our job. Before the pilot: confirm daily backups on the Supabase plan and do one restore test (pre-pilot checklist).
- **When:** the next app round (after slice 1 closes), with F34. The lead draws the folded line first.

## F37. Switching the phone to 24-hour needs an app restart
- **What the founder saw (Xiaomi, build 298):** after switching the phone to 24-hour, the times didn't change. They changed after the app was closed and opened again. Once they changed, all times changed together, so A1 (one formatter) holds.
- **Likely cause:** one of two.
  - The app reads the setting once and keeps it (a provider or a cached `DateFormat`). The formatter must read `MediaQuery.alwaysUse24HourFormat` each time it builds.
  - Or Android doesn't pass the change to Flutter until the app restarts. In that case, read the setting again when the app comes back to the front (`AppLifecycleState.resumed`), through a small platform call (`DateFormat.is24HourFormat`), and rebuild.
- **Test:** switch the setting while the app is in the background, come back, and every time shows the new style without a restart.
- **Priority:** low. It doesn't block closing slice 1; it goes in the next app round with F34–F36.

## F38. "Due today" keeps an item after it is signed as done
- **What Claude Code saw (retest of build 298):** the Due today strip keeps an item that the owner has signed as done until it is checked or sent back.
- **Fix:** the strip shows what the person still has to **do**. An item leaves it once it is signed as done, and comes back if it is sent back. For the author, a Done item already appears in Needs you as "to check".
- **When:** the next app round, with F34–F37.

## Retest of build 298: result (19 Oct)
- **Steps 1–5 passed:** the owner sees the item, signs with a photo, the push arrives, the card shows DONE with one new history line at Now, a double-tap checks with Undo, and a send-back plus an update each add one line, with the sheet above the keyboard.
- **Step 6:** one time style everywhere, in both modes. The style only switches after a restart (F37).
- **Verdict:** slice 1 is closed. Merge `slice1-v13` into `main`. F34–F37 go in the next app round.

## Retest results (steps 1–13, complete 18 Oct)
- **Passed:** no "Notifications aren't reaching this phone" line; + offers "Post to everyone" or "Work item in a Space ▸"; sign without a photo with the note required (F6); "Sign as done" only opens the proof screen (F7); the send-back slip takes the clip and Sign as done, never twice; long-press menu on a slip (F16).
- **Step 11, reply to a reply:** under Omar's reply, "Replying to Omar Haddad" (F2 ✓); the keyboard didn't hide the text on the Xiaomi.
- **Step 12, Activity:** rows open what they're about; REV and the letters are gone (F13 ✓). Back returns to Activity, as in other apps (founder agreed to keep it).
- **Step 13, Arabic:** times, تم التحقق and no "site" wording checked by the founder; nothing wrong (F14, F15, F4 ✓).
- **Verdict:** the slice 1 loop works on a real phone. The open items (F20, F23, F24, F25–F28, F30–F32) are in review 53.
- **Step 10, a post to everyone:** in Omar's feed without a restart, and pull-to-refresh works on a short feed (F18 ✓).
- **Step 8, no signal:** "Waiting to send", then one slip once the signal returned. The due date and time reached the server (17:00) and the push reached Omar in 5 seconds. No place was set (F29 withdrawn). "Waiting to send" went away at once, leaving one slip (F17 ✓).
- **Undo after "Send as done" (F7):** Undo at 1.2 s sent nothing and brought back the proof screen with the photo. Left alone, the sign-off reached the server after exactly 5 seconds.
- **Pushes to the emulator:** sent on live with no error. They didn't reach the emulator because its Play services connection had gone stale after the PC changed networks. After switching the emulator's network off and on, the push landed within 6 seconds. Not an app bug.

## Test note: emulators and pushes
Before testing pushes on an emulator, switch its network off and on, especially after the PC has changed networks. A stale Play services connection looks exactly like F9 ("no push"), but the server log shows the push sent with no error.

# Slice 2 test, build 333 (19 Oct 2026, evening)

- **Step 1, the model view:** "Supply Air" opens with the ductwork picture and V1. The blank viewer is fixed (review 61 G4).

## F39. 📎 does different things depending on the kind
- **What the founder saw:** on the writing card, with the kind still Work item, 📎 offered a file or a photo (K4). After he switched the kind to Checklist, 📎 went straight to the photo gallery.
- **Rule:** 📎 opens the **same K4 sheet** on every kind: a photo from the gallery or a file.
  - If the server takes PDFs on that kind (check `create_space_post`'s `p_files`), allow them.
  - If not, show the File row in grey with one small line: "A file goes in a File post" / "الملف يُنشر كمنشور ملف". Tapping that row switches the card's kind to File and keeps what was typed.
  - The sheet is never skipped, so the button always behaves the same way.
- **Test:** 📎 opens K4 on each of the five kinds, in EN and AR.

## F40. Typing a checklist point closes the keyboard after every letter (blocker)
- **What the founder saw (Xiaomi, build 333):** in a checklist point, the keyboard closes after each letter, and then "something wrong happens".
- **Likely cause:** each keystroke rebuilds the point's field. The field gets a new key, controller or focus node every time, so it loses focus.
  - Each point must keep a stable key (its id) and its own controller and focus node, for the life of the writing card.
  - Typing must not rebuild the list.
- **Also check:** the Enter key adds the next point and moves focus to it, and Backspace on an empty point removes it and moves focus back. Both are normal checklist behaviour.
- **Test:** a widget test types "Ceiling paint" into point 1, letter by letter, and focus stays on that point with the full text kept. Then check it by hand on the emulator, in EN and AR.

- **Step 3, ticks (founder's phone):** a tick shows the check, the name and the time on the point, and the card moves to the bottom of the day (Now). Passed.

## F41. Checklist points show in reverse order (found by Claude Code)
- **What happened:** "Supply air check" is saved as Duct supports, Fire dampers, Diffusers, but the card shows them in reverse. The server's order is right.
- **Fix:** the app shows points in the server's order (`sort`), on the card, the writing card and the post page.
- **Test:** three points come back in the order they were typed, in EN and AR.

## F42 and F43. A point's lines on the card follow its current state
- **F42 (Claude Code):** on "Cleaning", the card shows "You · unticked: running", but "running" is ticked again. Omar ticked it, un-ticked it and ticked it again, and G2 hides the final tick, so the line on show no longer matches the box.
- **F43 (founder):** ticking by mistake and un-ticking a moment later leaves an "unticked" line that is only noise.
- **One rule for the card** (the full history and "Show earlier" still show every line):
  - **ticked point:** no line, because the point itself shows who ticked it and when;
  - **un-ticked point:** one "unticked" line, with who and when, **unless** the person who un-ticked it is the one who ticked it, and did so **within 1 minute**. That is a correction, not a step of the work, so nothing shows.
  - **The server's log is not changed:** every tick and un-tick stays in the record.
- **Test:**
  - tick, un-tick, tick again: no line;
  - tick, then un-tick after 5 minutes: one line;
  - tick, then the same person un-ticks within 1 minute: no line;
  - Omar ticks and Islam un-ticks within 1 minute: one line, because it's a different person.

- **Step 4, the announcement:** pinned under the date line on Omar's side, with Got it, and no card covered by it. Passed.
- **Step 5, Got it:** it folds to one slim line ("📌 Friday is half day ›"), the cards don't move, and the author sees Omar's face. Passed.

## F44. A pinned announcement has no menu, so its author can't edit it
- **What the founder saw:** long-pressing the pinned announcement does nothing. Tapping it only opens or folds it, and there's no ⋯. The author has no way to edit, unpin or cancel it, so step 6 couldn't be tested.
- **Fix:** a pinned announcement, full or folded, takes the same **long-press menu** as any card, with the same rights as on the card:
  - **the author:** Edit, Unpin and Cancel;
  - **an admin acting for an author who has left:** the same;
  - **everyone else:** what they get on other cards.
  
  Tapping still opens and folds it.
- **Unpin:** the announcement becomes an ordinary card on its day. Unpinning doesn't move it to Now.
- **Test:** long-press on the full and on the folded announcement opens the menu, in EN and AR. After an edit, Omar sees it in full again, until he taps Got it (review 61 G1).

## F45. The people picker can't be closed, so the post went out by mistake
- **What the founder saw (step 7, scheduled activity):** after he picked Omar, the people list stayed open. There was no way to say "that's all", and trying to close it posted the activity before he meant to.
- **Fix, for every picker where you can choose more than one person** (activity, checklist, "For"):
  - a fixed **Done** button at the bottom of the sheet ("Done" / "تم"), with the chosen people's faces next to it and no number;
  - **dragging the sheet down, tapping outside it or pressing Back** also closes it and **keeps** the choice;
  - choosing a person never closes the sheet by itself, since more can be added;
  - **while the sheet is open, nothing under it can be tapped,** so the send button can't fire;
  - pickers where you choose only one person (a work item's owner) still close on the first tap, as now.
- **Test:** pick one person, then Done; pick two, then drag down. Both come back to the writing card with the right faces and nothing is posted. In EN and AR.

- **Step 7, the scheduled activity:**
  - On my way shows within 3 hours of the start.
  - The author sees "Omar Haddad · On my way" and his own line, and the card doesn't move.
  - Times follow the phone's 24-hour setting ("23:01 to 00:01").
  
  Passed, apart from F45 (the picker) and F46.

## F46. A cancelled activity still counts down
- **What the founder's phone shows:** the activity he posted by mistake (F45) and then cancelled carries the CANCELLED stamp, but still says "starts in 59 min".
- **Fix:** a cancelled activity shows its date block, its title and the time struck through, with the stamp:
  - no "starts in";
  - no Add to my calendar;
  - no On my way.
  
  Its reminder doesn't fire, and it leaves My calendar (check `my_calendar`).
- **Test:** cancel an activity an hour before it starts. The card shows no countdown and no actions, and nothing fires at the start time.

## F47. A file post and a Received don't appear until the Space is reopened
- **What the founder saw (step 8):**
  - after he posted a File from the Library, it didn't appear in the daybook until he went back to Home and opened the Space again;
  - Omar's Received showed at once on the emulator, but on the founder's phone only after leaving the Space and opening it again.
- **Rule, as for work items in slice 1** (F18):
  - **your own post** appears at Now as soon as you send it, the same way a work item's draft card does, for every kind;
  - **what others do** reaches an open daybook live, within a few seconds, with no reopen and no pull-to-refresh: new posts, ticks and un-ticks, Got it, Received, On my way, In my calendar, edits and cancels.
- **Likely cause:** the live updates only cover work item events. Listen to the changes behind the other kinds as well (`space_posts`, `checklist_points` / `post_point_events`, `post_acks`, `post_edits`), within the existing visibility rules, and update the card in place. A card moves only by the review 60 rule.
- **Test:** with two devices, each of these shows on the other device within 5 seconds, with no reopen: a file post, a Received, a tick, a Got it (the author's faces) and an edit.

## F48. A file card says Received twice
- **What the founder saw:** under the file there is "Received by Omar Haddad" with his face, and below that a history line, "Omar Haddad · Received 22:46". Both say the same thing, as the ticks did before G2.
- **Rule** (the same as G2 and F42: what the card already shows is not repeated as a line):
  - **the file card** shows only the summary, "Received by …", with up to three faces and no number;
  - **tapping the summary** opens a small sheet listing each person and the time they tapped Received, newest first. That's where the time is, for document control;
  - **Received lines** don't show in the card's history, but they stay in "Show earlier" and on the post page;
  - **Got it** follows the same pattern for the author (faces, and tapping them gives the list with times).
  - **On my way keeps its lines** (K3): the time someone set off is the point, and there's no summary line.
- **Test:** after Received, the file card has one summary line and no Received history line. Tapping the summary lists Omar with 22:46. In EN and AR.

- **Step 9, attach:** 📎 on a work item opens K4. Two gallery photos were chosen, but only one was posted (F51).

## F49. The File row names the format only (founder, supersedes review 61 G3)
- **The founder's call:** no examples. The File row's small line names only the format the server accepts: **"PDF"** / **"PDF"**.
- If more formats are accepted later, the line lists them ("PDF, DWG"). The text comes from the same list the server checks, not from a sentence written in the app.

## F50. The "File" kind is renamed for what it does (founder ok, 19 Oct; to look at again after the pilot)
- **What the founder saw:** with both the File kind and 📎 → File, there are two ways to post a PDF, and the difference isn't clear.
- **Decision:**
  - **The kind** in the menu reads **"Document for receipt"** / **"مستند للاستلام"**, with the small line "Each person confirms they received it" / "كل شخص يؤكد الاستلام". The card's kind word changes from "· file" to "· for receipt" / "· للاستلام".
  - **📎 → File stays** for attaching a PDF to any other post.
  - "Issue a document" isn't used, because "issue" reads as "problem" to most site workers.
- **Server:** no change. The kind stays `file`, and only the words change.
- **Figma:** the lead updates the kind menu (E6) and K2.

## F51. Only one of the chosen gallery photos is posted
- **What the founder saw:** he chose 2 photos from the gallery, and the post carried only 1.
- **Fix:**
  - **every photo chosen** (up to 10) is uploaded and saved on the post, in the order chosen;
  - **while uploading,** the writing card shows each one as a thumbnail with its own progress;
  - **if one fails,** it shows "Couldn't send · Try again" on that thumbnail only, and the others still post;
  - **on the card,** the first photo is shown large with up to two more as small thumbnails beside it. Tapping opens all of them in a swipeable viewer.
- **Check the server first:** confirm `create_space_post` (`p_files`) receives every path. If it does, the fault is in the app's upload loop.
- **Test:** choosing 2 and 10 photos posts 2 and 10, in order, on a work item and on a checklist.

- **Step 10:** the owner sees "For **you** · by today 11:55 pm". After a sign-off and a send-back, Omar's card shows the SENT BACK stamp and Sign as done again, and after the check, تم التحقق. The Due today strip (F38) wasn't seen; check it in the next test.
- **Step 11, 24-hour:** every time switches at once when the founder comes back to the app, with no restart. F37 passed.
- **Step 12, Arabic (founder's phone):**
  - the folded pin sits on the right;
  - the ledger lines read naturally ("أنت · إرجاع: غير مكتمل", "Omar Haddad · توقيع كمنجز", "أنت · تحقّق");
  - each time has its period on a second line (F15).
  
  One problem: F52.

## F52. "لOmar Haddad": the Arabic "for" sticks to a Latin name
- **What the founder's phone shows:** the facts line reads "لOmar Haddad · قبل الساعة 11:55 مساءً اليوم". The Arabic ل is joined straight onto the Latin name.
- **Fix:** one pattern for every name, whatever its script: **"لـ" + a space + the name** ("لـ Omar Haddad", "لـ عمر حداد"), and **"لك"** for yourself.
- **Names are never translated or transliterated** (founder, 19 Oct): a name shows exactly as its owner typed it, in both languages. "Omar Haddad" stays "Omar Haddad" in the Arabic UI, and "عمر حداد" stays "عمر حداد" in the English UI. That also holds for the initials on stamps and faces. The name keeps F34's weight. The same applies in Needs you rows and Activity.
- **Check every Arabic string** that puts a word such as ل or ب before a name. All of them use the "لـ " form with a space.
- **Test:** a Latin and an Arabic owner name, both in the Arabic UI, on a card and a Needs you row.

## F53. Arabic stamp: "مساءً" sits next to the name, not the time
- **What the founder's phone shows:** the تم التحقق stamp reads "مساءً ISLAM A · 10:58". Arabic ordering puts the period at the far end, next to the name.
- **Fix:** the time and its period are **one unit**, kept together with Unicode isolates (FSI…PDI) or as a single text span, so the stamp reads in Arabic as **"ISLAM A · 10:58 مساءً"**, with the period beside the time.
  - The same applies wherever a Latin name and a 12-hour Arabic time share a line: stamps, history lines and Activity rows.
  - In 24-hour mode there is no period, so nothing changes.
- **Test:** an Arabic stamp in 12-hour mode with a Latin name and with an Arabic name. In both, the period touches the time.

## Slice 2 test on build 333: result (19 Oct, 23:00)
- **Passed:**
  - the model view;
  - ticks;
  - the pinned announcement and Got it;
  - the scheduled activity and On my way;
  - Received (apart from F47 and F48);
  - the send-back loop;
  - the 24-hour switch;
  - Arabic (apart from F52).
- **The fix round** on `slice2-app`, then one new build:
  - **blockers:** F40 (typing a point) and F47 (not live);
  - **then:** F39, F41, F42/F43, F44, F45, F46, F48, F49, F50, F51, F52 and F53.
- **To test again on the new build:**
  - step 2 (type a checklist);
  - step 6 (edit a pinned announcement; F44);
  - F38 (Due today);
  - F47 (live updates on two devices);
  - F51 (several photos).
- **Lead to-do:**
  - Figma E6 and K2 with "Document for receipt" (F50);
  - K1b, the folded announcement;
  - K1 with "· checklist".

# Retest of build 349 (20 Oct 2026, morning)
- **Step 2, typing a checklist (F40):** the keyboard stays open and Enter starts the next point. Done in the people picker closes it without posting (F45). Passed.
- **F47, live updates:** the checklist appears on Omar's side, and Omar's tick reaches the founder's phone, without reopening. Passed.
- **Step 6, editing a pinned announcement (F44):** long-press gives Edit. After the edit, it opens in full again on Omar's side, with Got it. Passed.

## F54. A tick you can feel and a change you notice (founder ok, 20 Oct)
- **What the founder asked:** a tick shouldn't be silent. He wants to feel it, and to notice when someone else ticks.
- **Your own tick:**
  - the box fills with a short check animation (about 300 ms);
  - a light haptic (`HapticFeedback.lightImpact`);
  - the name and time slide in beside the point.
  
  An un-tick reverses the animation, with the same haptic.
- **Someone else's change arriving live** (a tick, Got it on your announcement, Received, On my way, a new line in a history):
  - the changed point or line glows softly in the action colour for about 2 seconds, then fades;
  - if the card is out of view, the existing "New ↓" chip appears (F11).
  
  No sound inside the app: pushes cover the time when the app is closed.
- **No 5-second hold on ticks.** A 20-point walk would cost almost 2 minutes, and a mistaken tick is fixed by tapping again (F43). The 5-second Undo stays only on Sign as done and Check, which close the work.
- **The same feel everywhere a point can be ticked:** a checklist, the points of a work item, and Notebook to-dos.
- **Reduced motion:** if the phone's "remove animations" setting is on, the change shows at once, with no glow. The haptic stays.
- **Test:** a widget test for the glow on a live tick, and the animation and haptic on your own tick. By hand on the Xiaomi.
- **F51, photos:** 3 gallery photos are posted, with the first large and two small. Passed.

## F55. A late item says it twice (superseded by F57)
- **What the emulator shows:** "For you · was due today 8:06 am" in red, and then a second line, "Late", in red.
- **Fix:** one line only. The facts line itself turns red and says it: **"For you · late, due 8:06 am"** / **"لك · متأخر، الموعد 8:06 ص"**. For an earlier day: **"late by 1 day"** / **"متأخر يومًا"** (daybook.md). There's no separate "Late" line.

## F56. Choosing who a post is for: one flow for every kind (founder, 20 Oct)
- **What the founder saw:** on a work item with no owner, Send opened "Who is it for?" and picking Omar **posted at once**. The same happens on every kind that needs people. The founder wants the whole flow revised: choosing a person must never post.
- **The rule, for every kind:**
  - **The writing card shows its "who" row from the start**, as a visible line under the title. It's required on a work item ("For: Choose ›" / "لـ: اختر ›"), a checklist ("For") and a scheduled activity ("Who's coming"). An announcement and a Document for receipt show "To: Everyone ›" or a Team, already filled.
  - **Tapping the row opens the picker.** A single choice (a work item's owner) closes on the tap and returns to the card. A multiple choice closes with Done (F45). **The picker never posts.**
  - **Send is grey until the title and the required "who" are set.** Tapping grey Send makes the missing row pulse once, with "Choose who it's for" / "اختر لمن", and posts nothing.
  - **Only the send button posts,** and every post keeps its 5-second Undo where it has one today.
- **Test:** on each kind, choosing people only fills the row, and the post goes out only on Send. A work item with no owner can't be sent, and the "who" row asks for it.

## F57. A due date is a reminder, not a record (founder, 20 Oct)
- **The founder's rule:** site work is human work. A due date is there to remind people to finish, not to judge them afterwards. If a thousand items carry "late" in red for ever, red stops meaning anything.
- **What changes:**
  - **There is no "Late" word anywhere,** and no separate Late line (this replaces F55 and the "Late by 1 day" line in daybook.md).
  - **While an item is open or sent back,** its due shows on the facts line as a reminder:
    - before the time, grey ("by today 14:00");
    - today, in ink;
    - once passed, in the **action colour**, not red ("was due 8:06" / "الموعد كان 8:06").
    
    Only the owner and the author see the passed-due colour. Everyone else sees it grey.
  - **Once signed as done, the due line disappears from the card,** and it doesn't come back after Checked. The card and the folded weekly line (F36) show no lateness. Only the post page keeps "Due was 8:06" in grey, for anyone who wants the history.
  - **Red is kept for SENT BACK and real failures** ("Couldn't send"), so it keeps its weight.
  - **Due today** (the strip) is "still to do": the owner's open and sent-back items due today or earlier, oldest first. An item leaves it once signed as done (F38). An earlier day's item shows its day in grey ("Mon"), with no "late".
  - **No lateness in profiles, counts or reports.** Daily and week reports list what is still open, with its due, and never "N late" (rule 3).
- **Server:** no change. `due_at` stays as it is, and the rule is about display only.
- **Docs:** daybook.md's "Late …" line is replaced by this rule.

## F58. A Note: the plain post, for information (founder ok, 20 Oct)
- **The founder's condition:** no SaaS forms. Kinds are **presets on one post**, not separate forms.
- **So a Note is the base.** It has a title or text and photos or files, with no "who" and no buttons. Every other kind is the same card plus one preset:
  - **a work item:** + an owner and Sign as done;
  - **a checklist:** + points to tick;
  - **an announcement:** + a pin and Got it;
  - **a scheduled activity:** + a time and On my way;
  - **a Document for receipt:** + a document and Received.
- **The kind menu** puts **Note** / **ملاحظة** first, with the small line "For information, nobody needs to act" / "للعلم، لا يلزم أي إجراء". Switching kinds keeps everything typed (F39) and only adds or removes the preset's one line.
- **On the card:** the author, the time, the text and the photos (as in F51), and its history (edits). No faces, no buttons and no paper clip. It goes into the daily report.
- **Server:** migration 29 adds `note` to the kinds. `create_space_post` takes it with no people, and the same visibility, edit and cancel rules apply as on an announcement.
- **The "who" sheet (F56)** on a work item with no owner gets one line: "Just for information? Post as a Note" / "للعلم فقط؟ انشرها كملاحظة".
- **Figma:** the lead draws the Note card and the kind menu with Note first.

## Figma, lead to-do done (20 Oct)
| Frame | EN | AR |
|---|---|---|
| K1 v13: the checklist header reads "· checklist" (AR "قائمة تحقق ·"), and the Arabic facts line reads "لـ سارة المطيري وعمر حداد" (F52) | `2594:35942` (edited) | `2595:471` (edited) |
| K1b v13: the announcement folded to one line after Got it (review 61 G1) | `2598:36165` | `2599:614` |
| K5 v13: a Note card, for information, with three photos (F58, F51) | `2598:36260` | `2599:721` |
| E6 v14: the kind menu as presets, with Note first and "Document for receipt" (F50, F58) | `2598:36360` | `2599:833` |

# Slice 2 retest, build 375 (21 Oct 2026)

## F59. At the bottom (Now) the masthead must say Today (founder, 21 Oct; replaces part of F23)
- **What the founder saw:** at the bottom of the daybook, a large Note from yesterday filled the top half of the screen, so the masthead said yesterday's date. People will wonder whether that's today, or what the date means.
- **Rule:**
  - **At Now** (the bottom, the place you write), the masthead always reads **"Today"** in bold, then the date in grey: "**Today** · Wednesday 21 October" / "**اليوم** · الأربعاء 21 أكتوبر". This holds even when an older card fills the screen.
  - **There's always a "Today" divider** right above the writing area, even if nothing has been posted yet today, so a card from yesterday sits clearly above it. With nothing posted today, a small grey line sits under the divider: "Nothing yet today" / "لا شيء بعد اليوم".
  - **Only when you scroll back** (Now out of view) does the masthead follow the day of the content at the top of the screen (F23), with the "Today ↓" chip to jump back. Back at Now, it returns to Today.
  - The Space header stays as it is (the name and "Private work"). The date has one place, the masthead.
- **Test:**
  - at Now with yesterday's card filling the top, the masthead reads Today;
  - after scrolling back a day, it reads that day and the chip shows;
  - tapping the chip returns to Now and Today;
  - in EN and AR.

- **Photo location (21 Oct):** both photos of the Note "ocfice" are stored with no GPS and no XMP, upright (1205×1600), with the time taken kept. Passed.

## F60. Photos also lose the device's identity
- **Seen in the check:** the stored photos still carry the phone's make and model ("Xiaomi 22120RN86G").
- **Fix:** `photo_privacy.dart` also empties:
  - Make and Model;
  - the camera's body and lens serial numbers (BodySerialNumber, LensSerialNumber);
  - OwnerName / CameraOwnerName, and Artist.
  
  Orientation and the time taken stay, because the proof needs the time. A serial number can identify one phone across every photo it takes, and proof photos can appear on a profile.
- **Test:** a JPEG with those tags comes out without them, still upright and with its time.

- **Step 1, Due today (lead on the emulator as Omar, 10:17–10:21):**
  - the strip listed Sun gffggg · Sun Paint Room 3 · Mon fix socket in room 4 · Tue ggfff, oldest first;
  - Omar signed ggfff as done: it left the strip at once, and the card dropped its due line and showed DONE (F38 and F57 passed);
  - the founder sent it back from his phone: it came back into the strip, and the card showed SENT BACK and "was due Tue 20 Oct 8:06 am" in orange, live with no reopening (F47).
  
  Passed, apart from F61.

## F61. The strip: its name and its colours
- **Seen:** the whole strip is orange-red, the day names included, and it's called "Due today" while it lists Sunday's and Monday's items.
- **Fix:**
  - **Name:** **"To do"** / **«مطلوب منك»**. It's what is still yours to do, today or from earlier days.
  - **Colours:** the label and the item titles in the action colour; the day names ("Sun", "Mon") in **grey** (F57: an earlier day is never a warning). Today's items carry no day.
  - It still lists the oldest first, wraps to at most two lines, and ends with "+ more ›" if it overflows. "More" here is not a number.

## F62. A due date belongs to whoever must act next (founder ok, 21 Oct)
- **The founder's point:** once Omar has signed as done, the old due is unfair to him if it's still shown while the item waits for the check. After a send-back, the old due is stale: the real time to finish depends on the site, a delivery, logistics or the design office.
- **Rule, by stage:**
  - **Open:** "By Tue 8:06". It turns the action colour once passed, for the owner and the author only (F57).
  - **Done, waiting for the check:** **no due on the card.** The author's Needs you row reads "Done 10:21 · waiting for your check" / «منجز 10:21 · بانتظار تحققك», never red.
  - **Sent back:** the send-back sheet adds one single choice (rule 6), with **nothing preselected**: **Today · Tomorrow · Pick a date · No new date** / **اليوم · غدًا · اختر تاريخًا · بلا موعد جديد**.
    - With a date, the card shows the **new** due. The history line reads "Islam Ahmed · Send back: Photo missing · new date Thu 23 Oct" / «إسلام أحمد · إرجاع: الصورة ناقصة · موعد جديد الخميس 23 أكتوبر».
    - With "No new date", the old due is **not** shown again. The item has no due, so it isn't in the To do strip. It's in the owner's Needs you with the paper clip (review 72).
  - **Checked:** no date. No lateness is recorded anywhere (F57).
- **When things change before Done:** the owner adds an update (it exists), and the author moves the due (edit exists, with its history line). The pilot gets no "ask for more time" button.
- **Server: migration 33, `claude/review72-db` (see review 72):**
  - `send_back` takes an optional new due (`p_due_at`, or `p_due` for a date only), set in the same transaction as the event;
  - the event carries the new due, so the history line can show it;
  - only the author (or `acts_for_author`) may set it, as for an edit.
  - **Tests:** a send-back with and without a new date; the card's due after each; a non-author can't set it.
- **App:** the sheet's new row; the card hides the due while Done; the Needs you wording for the author.

- **Step 2, the Note:** first in the kind menu, it posts with nothing to choose, and the card says "· note" with no buttons. Passed, apart from F63.

## F63. The kind menu has no description lines (founder, 21 Oct)
- **The founder's call:** remove "For information, nobody needs to act" under Note. People understand the words.
- **For consistency, the same goes for "Each person confirms they received it"** under Document for receipt. The menu is six plain rows: icon, word and the check on the chosen one (Figma E6 v14 updated, EN `2598:36360`, AR `2599:833`).
- **"Just for information? Post as a Note"** under the owner picker (F56) **stays**, because it's an action, not a description.

# Test of build 386 (`claude/review72-app`, 21 Oct afternoon; the lead on the emulator as Omar, the founder on his phone)
- **Step 3, the who row:** "For: Choose ›" shows from the start. Tapping grey Post shows "Choose who it's for" and posts nothing. Choosing Islam closes the picker without posting. Only Post posts (NST-016). Passed, apart from F66.
- **Step 4, no Late:** "was due Tue 20 Oct 8:06 am" in the action colour while open; no due once signed. Passed.
- **Step 6, an announcement edited after Got it:** opens in full again on Omar's side, with Got it. Passed.
- **F59:** "**Today** · Wednesday 21 October" at Now. Passed.
- **F61:** "To do:" with the days in grey. Tapping it opens the To do sheet, oldest first. Passed, apart from F65.
- **F62:** NST-016, sent back with a new date: the card reads "For Islam Ahmed · by today", and the line "You sent it back: Not finished · new date Wed 21 Oct". Passed, apart from F64.
- **F63:** the kind menu has six plain rows. Passed.
- **About:** shows "Version 0.9.0 · build 386 · caee2c0". Help and feedback sits inside About BuildVibes and legal (support@aecox.com).
- **Still to see:** step 5 (the tick feel on the founder's phone: the haptic, and Omar's tick glowing), and F60 with a real phone photo.

## F64. The new date on Send back: three optional chips (founder, 21 Oct; replaces part of F62)
- **The founder's call:** no "No new date" chip. The sheet offers **Today · Tomorrow · Pick a date**, and **choosing none means no new date.**
- **So:** nothing is preselected, and **Send back is enabled as soon as a reason is chosen.** A date is optional. Tapping the chosen chip again un-chooses it.
- **The call:** with a chip, `send_back(…, p_due_set: true, p_due, p_due_at)`; with no chip, `p_due_set: true` and both null. The old date is still never shown again (F62).
- **The history line** stays "· new date Thu 23 Oct" or "· no new date" (review 73).
- Remove the `daybookSendBackNoNewDate` chip string. Keep `daybookLineNoNewDate` for the line.

## F65. The To do strip lists an item raised for someone else
- **Seen on Omar's side:** the strip ends "· Lead test: who row". That's NST-016, which Omar raised **for Islam** and sent back, so it's Islam's to do, not Omar's.
- **Fix:** the strip and its sheet list only items **the viewer owns** (`owner_id` = me), open or sent back, due today or earlier (F57). An item I raised for someone else never appears in my strip. A Done item waiting for my check stays in Needs you ("Done 10:21 · waiting for your check"), not in the strip.
- **Test:** Omar's strip doesn't show an item he raised for Islam, in any state.

## F66. The writing card loses "For" after a person is chosen
- **Seen:** before choosing, the row reads "For: Choose ›". After choosing, it shows only the face and "Islam Ahmed". The posted card reads "For Islam Ahmed".
- **Fix:** after choosing, the writing card's row reads "**For** Islam Ahmed ›", or "**لـ** Islam Ahmed ›" in Arabic, matching the card (F34, F52). Tapping it reopens the picker.

## Terms draft
- §10 says "Settings → Help and feedback". In the app it is **Settings → About BuildVibes and legal → Help and feedback**. Fix the path in the Terms draft.

## F67. The tick's vibration isn't felt on the founder's Xiaomi (step 5)
- **Seen:** ticking a point gives no vibration the founder can feel. (Was the check animation seen? Ask with the next build.)
- **Likely cause:** `HapticFeedback.lightImpact` becomes Android's VIRTUAL_KEY, which many phones (MIUI among them) play very weakly, or not at all when the phone's touch feedback is off or set low.
- **Fix:**
  - use a stronger, explicit tick: `HapticFeedback.mediumImpact`. If that's still not felt on the Xiaomi with touch feedback on, use the platform's tick effect through a small vibration call (`VibrationEffect.EFFECT_TICK`, about 20 ms). It stays one short tick, never a buzz;
  - the same for check and sign-off, which use the strong haptic (daybook.md).
- **Test on the Xiaomi:** with Settings → Sound & vibration → Haptic feedback on, one tick is felt every time. With it off, nothing is felt, because the phone's own choice wins.
- **The founder's check:** that Haptic feedback is on in the phone's settings.

- **F60 (founder, 21 Oct):** a photo is posted from the phone; Claude Code checks that the stored file has no make, model or serials.

## F67 passed (build 394, 21 Oct)
- The founder feels the vibration on tick and on un-tick.

## F68. The To do strip is one light line with a count (founder, 21 Oct; replaces the look in F61)
- **Seen (build 394):** the strip lists every title with its day on a tinted band: "To do: Sun gffggg · Sun Paint Room 3 · Mon fix socket in room 4 · Tue ggfff · dddd". It's heavy and hard to read.
- **Fix:**
  - **One line, the same pattern as the folded announcement (K1b):** the calendar icon, **"To do · 5"** / **«مطلوب منك · 5»**, then ›.
  - **No tinted band.** Use the page background with a hairline under it. The icon and "To do" are in the action colour, the count is in ink, and › is grey.
  - **No titles and no days on the strip.** Tapping it opens the To do sheet (A1, review 73), which lists the titles, oldest first, with the earlier days in grey (F57).
  - **The count is the viewer's own open and sent-back items** due today or earlier (F65). It's a personal list, not a quality signal (rule 3).
  - **With 0 items the strip is not shown.**
  - **Arabic:** mirrored, with the chevron pointing left and Western digits.
- **Test:**
  - 5 items show "To do · 5", with no titles on the strip;
  - tapping opens the sheet with the 5 titles;
  - 0 items: no strip;
  - EN and AR at 390×844.

## Build 394 test (21 Oct, 16:40): F64, F65, F66 passed
- **F64:** Islam sent "dddd" (NST-017) back with no date chip. It went through, and the history reads "Islam Ahmed sent it back: Not finished · no new date". Checked by the lead on the emulator as Omar.
- **F65:**
  - Omar's strip lists his own items: gffggg, Paint Room 3, fix socket in room 4, ggfff (sent back to him) and dddd;
  - Islam's strip on the phone shows neither dddd nor ggfff (founder);
  - after Omar signed dddd as done again (the lead, note only), it left his strip (F38).
- **F66:** the writing card read "For Omar Haddad" after Omar was chosen (founder).
- **Still to test in the next build:** F68 and F60 (review 74).
- **F68 screenshots approved** (`claude/review72-app` 4e7b639):
  - one line, "To do · 3" / «مطلوب منك · 3», with no band and no titles;
  - mirrored, with Western digits;
  - "was due Thu 15 Oct" is in the action colour, as F57 says.
  
  The founder's phone check comes with the next build.

## F68b. The To do line becomes a work docket (founder, 21 Oct; replaces F68's look)
- **Seen (build 402):** "To do · 1" is correct, but generic. It says nothing about the work and uses none of the site-paperwork language (rule 1).
- **Design (lead, Figma):** EN `2604:36305` (PROTOTYPE · Full app v1 · EN), AR `2604:37123` (PROTOTYPE · Core journeys · AR). A small tear-off **docket**, like a site job ticket, under the masthead and above a pinned announcement:
  - **The card:** surface/elevated, a 1 px border/subtle line, radius 8, 16 px from the screen edges, 8 px below the masthead.
  - **The stub** at the start: surface/brand-soft, with the list-checks icon in icon/action (20 px). A **dashed perforation** line (border/subtle, 3/3) separates it from the body.
  - **Body line 1** (main size, Medium; Almarai Bold in Arabic): what it is, with its number.
    - EN: "1 work item for you", "2 work items for you", "3 work items for you".
    - AR (ICU plural): «بند عمل واحد لك», «بندا عمل لك», «{n} بنود عمل لك» (3–10), «{n} بند عمل لك» (11+).
  - **Body line 2** (small size, text/secondary): the oldest item, so the line describes the work itself.
    - **One item:** its title and due, as the card's facts line: "dddd · by 6:30 pm", or "· from Sun" for an earlier day (grey, F57).
    - **More than one:** the oldest title, its day, then the rest. EN: "Paint Room 3 · from Sun, and 1 more" / "…, and 2 more". AR: «Paint Room 3 · منذ الأحد، وبند آخر» / «…، و{n} بنود أخرى».
    - The title is cut with … on one line.
  - **The chevron** (› in EN, ‹ in AR) is grey. The whole docket opens the To do sheet.
  - **0 items:** no docket.
  - **What stays from F68:** the count is my own open and sent-back items, due today or earlier (F65). There's no tinted band.
- **Masthead:** both frames also show F59 ("Today · Thursday 15 October" / «اليوم · الخميس 15 أكتوبر»).
- **Test:**
  - 1, 2 and 12 items in EN and AR, with the plurals right;
  - a long title cut with …;
  - tapping opens the sheet;
  - 0 items: no docket;
  - 390×844.

## F69. The picker lists me among the others (founder, 21 Oct)
- **Seen:** on a new post, the "who" picker shows the founder's own name in the list like anyone else's, which reads as a mistake.
- **Rule (unchanged):** a work item may be for yourself, as a reminder of your own site task. You never check your own work: a Space admin checks it, or a Lead when you are the only admin (data-model §, "Only the author checks").
- **Fix:**
  - **I appear once, at the top, as "You" / «أنت»,** with my face, then a hairline, then everyone else in the usual order. My name doesn't appear again in the list.
  - **When the picker is searched,** "You" shows only if my name matches.
  - **Chosen:** the row reads "For you" / «لك», as on the card.
  - This applies to a work item, a checklist and a scheduled activity. The give-to picker on an existing item, and the To/Everyone row, are unchanged.
- **Test:**
  - "You" is first and my name isn't listed twice;
  - choosing "You" gives "For you" on the card and puts the item in my To do;
  - a Space admin other than me sees it in Needs you to check once it's Done.

## Build 473 test, slices 3–6 (22 Oct)
- **Step 8 passed** (Claude Code, on the emulator as Omar). As a Viewer, Omar sees "Viewer · Read only" with no writing card and no camera, only Search and Space info in ⋯, and no "Add a file" in the Library.

## F70. The Library's empty line has no side margin
- "No files yet. Drawings and photos shared in this Space appear here." touches the screen's edge. **Fix:** 16 px on both sides, as on every screen.

## F71. "Is it a new version of a file?" lists every file (founder)
- **Seen:** after picking a file, the card lists every Library file it might replace. With 100 files the list is endless.
- **Fix (rule 6):**
  - one single choice, **"New file"** / **"New version of a file"** («ملف جديد» / «نسخة جديدة من ملف»), with "New file" chosen at first;
  - "New version of a file" opens a sheet with **Search files** at the top and the Library's files in use, newest first, so you type a few letters and pick one;
  - the card then reads "Replaces A-501 · V2" with ✕ to undo.

## F72. Two ways to add a file on the writing card (founder)
- **Seen:** the paper clip and the ⋯ row both add files, one from the phone and one from the Library, and it's not clear which is which.
- **Fix:**
  - **One way in.** The paper clip opens one sheet with Camera, Photos, Files on the phone and **From the Library**;
  - the ⋯ row no longer adds files.
- **"To: Everyone" can't be changed on a file:** this is right, because Team-only and person-only files are not in the pilot (founder, 22 Oct). So the row must not look tappable:
  - "To: Everyone" with no ›;
  - its sheet, if opened, says "A file goes to the whole Space. To send it to one person, use a direct message."

## F73. A large file while it uploads looks like "no signal" (founder)
- **Seen:** an 8.7 MB PDF showed the same line as having no signal while it was uploading.
- **Fix:**
  - **While it sends with a signal:** "Sending · 3.1 of 8.7 MB" / «يُرسل · 3.1 من 8.7 ميغابايت», with a thin progress line on the card;
  - **only with no signal:** "Waiting to send".
- **Test:**
  - a 9 MB file shows Sending with a growing number;
  - airplane mode shows Waiting to send.

## F74. "· for receipt" on a file post's header isn't understood (founder)
- **Fix:**
  - the header says **"· file"** / «· ملف»;
  - the kind menu's "Document for receipt" becomes **"File"** / «ملف»;
  - the request to confirm stays on the card: the **Received** pill, and "Received by …" with faces.

## F75. Versions are numbered by the app; the revision is the document's own (founder)
- **Seen:** the versions list shows "Version in use" and "Version · Islam Ahmed · today", with no number.
- **Rule:**
  - **The app gives every version a number, V1, V2, V3…**, in the order they were added. Nobody can type or change it, and a number is never reused, even after a version is removed (as model views do, migration 27 R3).
  - **The revision ("Rev C") is optional**, typed from the document itself, and shown after the number when given.
- **Shown:**
  - "**V2** · Rev B · in use", then "Islam Ahmed · today";
  - older ones: "**V1** · Rev A", then "Islam Ahmed · 14 Oct" · Open;
  - the card's stamp: "NEW VERSION · V2" and "Replaces V1".
- **Server:** a small migration.
  - `library_files.version_no`: set on insert as the chain's highest number plus one, under the same lock as the chain, never updated;
  - existing chains are numbered by `created_at`;
  - tests: the numbers, a removed middle version doesn't renumber, and two versions added at once get 2 and 3.

## F76. A new version makes a second post: the first one must say so (founder)
- **Rule:** each version is its own post, because each asks people to receive it.
- **The older post:**
  - shows one grey line, "Replaced by V2 · today ›" / «استُبدلت بـ V2 · اليوم ›», which opens the new post;
  - its Received pill goes, since nobody should confirm an old version;
  - its file chip reads "V1" in grey.
- **The Library** shows only the version in use (F75), with the others under Versions.

## F77. "Share in chat" should open the chat with the file ready (founder)
- **Seen:** sharing showed "Shared to Everyone" and stayed on the file page, so no message could go with the file.
- **Fix:**
  - "Share in chat" opens the Space's chat with the file **attached in the message box, not sent**, so words can be added before Send (as in WhatsApp);
  - the toast goes.

## F78. There is no way to find a person to message (Claude Code, build 473; must before the pilot)
- **Seen:**
  - Messages' **+ (New message)** opens Explore, which says "This part of the app is being built";
  - Home's **"Search people"** does the same.
  
  The only way to message someone new is from their profile, reached through one of their posts. People search is in the MVP.
- **Fix:**
  - **+ in Messages** opens **"New message"**: a search field (name, role or company), and before typing, the people you share a Space with, A–Z with their role. Tapping a person opens the conversation (`start_dm` on the first message). Blocked and hidden accounts never show.
  - **Home's "Search people"** opens the same people search, where a tap opens the profile.
  - The rest of Explore stays out of the MVP.
- **Test:**
  - finding Omar by part of his name;
  - finding him by his role;
  - someone you blocked doesn't show;
  - Arabic, with the names unchanged.

## F79. A person on the Space's People tab opens their pass, not them (Claude Code, build 473)
- **Seen:**
  - tapping a person opens the pass screen, with no way to their profile and no Message button;
  - a Crew member also sees a "CHANGE PASS" section that does nothing.
- **Fix:** tapping a person opens a short sheet:
  - their face, name, role and company, and their pass tag;
  - **View profile** and **Message**, for everyone;
  - **Pass** (Lead / Crew / Viewer, one choice) and **Remove from the Space**, **only for a Space admin**. Nobody else sees them at all.
  - For yourself: View profile only.

## F80. A file's version shows both "CURRENT" and "superseded" (Claude Code, build 473)
- **Seen:** one version card says "CURRENT" and "22 Oct · superseded, kept in the record".
- **Fix:** with F75 and F76:
  - the version in use says only "V2 · in use";
  - only older versions say "replaced 22 Oct, kept in the record".
- **Test:** a chain of 3 shows exactly one "in use".

## F81. A new direct message doesn't appear until the app is closed and opened again (founder, build 473; must before the pilot)
- **Seen:** Omar's message reached the server (and its push was sent), but Messages on the founder's phone didn't show it until he closed the app and opened it again.
- **Expected:** a new message shows at once, in the list and in an open conversation (migration 31, DM live).
- **Fix:** find why the update was missed. The list and the open thread:
  - listen to the DM changes (Realtime) while the app is open;
  - read again when the app comes back to the front;
  - read again when a DM push arrives while the app is open.
  
  Any one of these alone would have shown it. Check that the Realtime subscription is made after sign-in, and made again after the phone was locked or offline.
- **No push arrived either (founder).** The update may have changed the phone's push token. Check, read-only:
  - the `push_queue` row for Omar's message (sent, failed, or no token);
  - that the app registers its token again on every start after sign-in;
  - that BuildVibes may show notifications on the Xiaomi (MIUI's notification and Autostart settings).
- **Test:**
  - the founder's phone on the Messages list, Omar sends: it shows within 2 seconds;
  - the same with the phone locked for a minute first;
  - the same with the conversation open.

## Build 473: step 9 passed (founder)
- Omar's direct message → hold → Put in a Space → posted as an announcement, with his words quoted.

- **Server checked (Claude Code, read-only):** the DM reached the server at 08:38:39, and its push row was sent to FCM at 08:38:41 with no error. The loss is on the phone's side. The founder had the app open.
- **Fix (app):**
  - **Messages listens app-wide while signed in**, not only inside an open conversation. The Messages list, the Home messages dot and the tab badge update from the DM Realtime changes, and again on resume and on a push.
  - **A push that arrives while the app is open** shows a quiet in-app banner, "Omar Haddad: Gate 2 is blocked…", unless that conversation is already on screen. A tap opens it.
- **Fix (push function):**
  - record FCM's answer for each token;
  - delete a token that FCM calls UNREGISTERED or NOT_FOUND.
  - **Don't delete a person's other tokens when a new one registers**, because a person may use a phone and a tablet. Replace only the token of the same install: the app sends a random install id with its token.

## F82. An announcement can be pinned until a time, not only a day (founder)
- **Why:** site events last hours ("Gate 2 closed until 2 pm"), so a pin to the end of the day stays up too long.
- **Server:** no change. `pinned_until` is already a time (later than now, and at most 90 days ahead).
- **The writing card's "Pinned until" row:**
  - **the day:** the usual single choice, Today / Tomorrow / Pick a date;
  - then an optional **"+ Time"** / «+ وقت», which opens the time picker (12- or 24-hour as the phone's setting, F37). ✕ takes the time away.
  - **With no time, the pin ends at the end of that day,** in the Space's market time zone, as now.
- **Shown:**
  - "Until 2:00 pm" / «حتى 2:00 مساءً» when it is today;
  - "Until Wed 2:00 pm" / «حتى الأربعاء 2:00 مساءً» on another day;
  - with no time, "Until Wed" as now.
- **When the time passes,** the announcement unpins by itself (`pinned_until > now()` already does this). It becomes an ordinary card on its day.
- **Test:**
  - a pin until 2 minutes from now unpins after 2 minutes, with no reload;
  - a time earlier than now today is refused on the card before sending ("Choose a later time");
  - Arabic.

## F83. An announcement made from a quoted message loses the quote once posted (founder, build 473, step 9)
- **Seen:** Omar's direct message → Put in a Space → Announcement. The writing card showed Omar's words as a quote, but the posted announcement shows only the title the founder typed.
- **Server:** `create_space_post` keeps `p_quote` for every kind, and the card JSON carries `quote`.
- **Find which side drops it:**
  - read the post's `quote` column (read-only);
  - if it is empty, the app didn't send `p_quote` for an announcement;
  - if it is there, the announcement card (full or folded) doesn't draw it.
- **Fix:**
  - every kind made from a quote (work item, checklist, announcement, scheduled activity, note) **posts the quote and shows it** on its card, as the work item does: "From Omar Haddad · 8:38", then the words, with the start-side bar;
  - **on a folded announcement** (K1b) the quote shows when it is opened.
- **A work item keeps it (founder, 10:01):** NST-019 "gate blocked" shows "From Omar Haddad · 8:38 am" and his words. So only the other kinds lose the quote.
- **Test:** each kind from a quoted direct message and from a quoted Space chat message shows the quote after posting, in EN and AR.

## F84. ~~My own card's header shows my name, not "You"~~ — withdrawn (lead, 11:20)
- The screenshot was from the emulator, signed in as Omar, so "Islam Ahmed · For you" is right. The emulator shows "You · NST-022" on Omar's own walk.
- **Seen (NST-019):** "Islam Ahmed · NST-019" on the founder's own work item, while the line under it says "For you".
- **Fix:** on a card's header, the author is **"You"** / «أنت» when it is the reader, as in K1–K5 (v13). The same applies to history lines ("You signed as done" already does). Other people see the name.

## F85. An announcement's end date is too small to notice (founder, 10:03)
- **Seen:** "Until Fri" sits in the header in small grey, where the time usually is. How long an announcement lasts is what matters most on it.
- **Fix: the end moves to the facts line under the title**, at the main size, like a work item's due:
  - the push-pin icon, then **"Until Friday 23 Oct"** / «حتى الجمعة 23 أكتوبر», with F82's time when there is one: "Until Friday 23 Oct · 2:00 pm";
  - **today:** "Until today · 2:00 pm" in ink;
  - **on the last day without a time:** "Until today".
  - The header goes back to its usual end: the time it was posted.
- **The folded line (K1b)** ends with the same "until Fri" in grey before ›, so the end is visible even when folded.

## F86. ~~The author is asked to tap "Got it" on their own announcement~~ — withdrawn (lead, 11:20)
- The screenshot was Omar's view on the emulator, and Omar must give Got it. Keep only the server check that `ack(got_it)` from the author is refused.
- **Seen:** "gate 2 blocked", by Islam Ahmed, shows **Got it** to Islam himself.
- **Rule (review 61 G1):**
  - the author never gives Got it;
  - they see the faces of who did, and their own announcement starts folded for them.
- **Fix:**
  - no Got it pill for the author, and none for whoever acts for the author;
  - the server refuses `ack(got_it)` from the author (check it does; add a test if not).

## Build 473: step 10 (founder, 10:56)
- **Passed in part:** Space chat → hold → Turn into a work item. The work item shows the message as a quote.

## F87. Tapping a work item's quote doesn't open its chat message
- **Seen:** on a work item made from a Space chat message, tapping the quote does nothing.
- **Rule (S8m):** the quote links back. A tap opens the Space's Chat at that message, scrolled to it and highlighted for a moment, reading back through older messages if needed (as search does since the pre-test fixes).
- **Edge cases:**
  - a message that was deleted shows the quote without a link (pre-test fix);
  - a quote from a **direct message** opens that conversation only for its two people. For anyone else, the quote isn't tappable.
- **Test:**
  - a quote from today and one from last week both open their message;
  - a deleted message's quote does nothing;
  - Arabic.

## Build 473: steps 11 and 12 (founder, 11:00)
- **Step 11:** the draft and its quote are kept (see F88).
- **Step 12:** "Waiting to send" shows in airplane mode. Whether it sent once after the signal came back is still to confirm.

## F88. A kept draft loses its "Draft" label after leaving the Space
- **Seen:** leaving the writing card, the card shows as **Draft** (E4). After going to Home and back into the Space, the draft is still there with its words and quote, but the **"Draft" word is gone**, so it looks like a card being written now.
- **Fix:** a writing card that holds an unsent draft **always** shows E4's "Draft" label, however it was reached: back from Home, from another Space, after the app was closed, or after a restart. The label goes when the person types again, as now.
- **Test:** make a draft → Home → back to the Space: "Draft" shows. The same after closing the app fully.

## Build 473: steps 12 and 13 (founder, 11:04)
- **Step 12 passed:** with the signal back, the waiting work item was sent, once.
- **Step 13 in part:** headings, text and tables can be added, and + row works. See F89 and F90.

## F89. A table's "+ column" does nothing
- **Seen:** on a page table, + row adds a row, but + column adds nothing.
- **Fix:** + column adds an empty cell to the end of every row, up to 8 columns (`validate_blocks`). The table then scrolls sideways when it is wider than the page. At 8, the + column button goes.
- **Test:** 2×2 → + column → 2×3, saved and read back; at 8 columns no + column; Arabic, where the new column comes on the left.

## F90. Writing inside a toggle feels like a form, not writing (founder)
- **Seen:** inside an open toggle, each line is followed by its own "+ Add text" button, like the table's + row. It works, but it's not how people write.
- **Fix: write inside a toggle as on the page itself:**
  - an open toggle shows its lines, then one empty line ready to type, with a grey hint, "Type inside" / «اكتب هنا»;
  - **Enter** at the end of a line starts a new line inside the toggle;
  - **Enter on an empty last line** leaves the toggle and starts a line after it;
  - **"/"** on an empty line inside offers what a toggle may hold: text, heading, table, photo, file (`validate_blocks`);
  - there's no "+ Add text" button.
- **Test:**
  - write three lines in a toggle with Enter;
  - Enter twice to leave it;
  - close and open the toggle, and the three lines are there;
  - the same in Arabic.

## Build 473: step 13 (founder, 11:05)
- **Passed in part:**
  - after Done, the card shows "Open the page ›", and the page opens with its table and toggle;
  - the toggle opens in place.
  
  F89 and F90 stand.

## F91. A work item's page doesn't show its quote
- **Seen:** NST-021 "ddd" shows Omar's quote on its card, but its page goes straight from "For you" to the table.
- **Fix:**
  - the page shows the quote where the card does: after the facts line and before the words and blocks, with "From Omar Haddad · 8:38 am" and the start-side bar;
  - a tap opens its message (F87).
- **The history line on the card** reads "Islam Ahmed edited it". For the reader's own edit it is **"You edited the page"** / «عدّلتَ الصفحة» (F84), and for others "Islam Ahmed edited the page", since only the page changed.

## Build 473: slice 6, run by the lead on the emulator as Omar (22 Oct, 11:15–11:19)
- **Step 19 passed:** Space ⋯ › Walk mode; name "Lead test walk, level 2" and place "Level 2"; the phone's camera opens.
- **Step 20 passed:**
  - three photos, each with its line;
  - the owner Islam was kept for the second photo, then changed to Omar for the third;
  - the facts line reads "Level 2 · 22 Oct 11:16 am · You".
- **Step 21 in part:** a tap on a thumbnail goes back to that photo with its line and owner. Taking one out with a long press wasn't tried.
- **Step 22 passed:** one card, NST-022: "You · NST-022 · 11:18 am", the title, the place, "3 photos, each one a work item", the photos, a row per work item with the owner's face, "Sign as done" on Omar's own row, and "0 of 3 checked".
- **Step 23 passed** (migration 37 live): the walk's work items show only inside its card. A row opens that work item's own card (NST-025) on a sheet.
- **Step 24 passed:** Omar signed his row as done without a photo, with a note. The sheet shows DONE · OMAR H · 11:19 am, and the walk's row shows DONE.
  - Islam's two rows wait for him: **the founder signs one on his phone**, then checks Omar's as the walk's author.
- **Step 25 passed:** ✕ asks "Throw this walk away? Its photos aren't sent", with Keep walking / Throw away.
- **Not run:** 21's long press and 26 (airplane mode).
- **Small:** in the walk's "Who does it" picker, the chosen person's row reads "Islam Ahmed · now". "now" means nothing there, so drop it.

## Build 473: more steps run by the lead on the emulator as Omar (22 Oct, 11:21–11:27)
- **Step 13 passed:** on Omar's own NST-026: Edit page, then "+" and "/" open the block menu; added a heading, a checklist of two points and a table; Done saves; the page head shows **Edit page** for the author.
- **Step 15 passed:** holding ⋮⋮ drags a block (the heading moved below the checklist); ⋮⋮ › Delete on the table, "Block deleted · Undo", and Undo brings it back.
- **Step 16 passed in part:** "/" › Work item under this one: a title and an owner (Islam), and it shows on the page as a row. The card becomes a target, with the row, "0 of 1 checked" and no Sign as done. Photo and file on a page weren't tried.
- **Step 17 failed:** see F92.
- **Step 26 passed:** in airplane mode a 2-photo walk shows its photos, its rows and "Waiting to send". When the signal is back it sends, and each row asks "Sign as done". See F94 for the order.
- **Step 7 passed (work items):** Space ⋯ › Search "riser" gives the group "Work items" (two work items and a checklist point), and a result opens its card on a sheet. Files and chat weren't in this Space's results.

## F92. A checklist point can't be turned into a work item
- **Seen:** in Edit page, a checklist block has one ⋮⋮ for the whole block, and its menu offers only Delete. A long press on a point selects its text. Nothing offers Turn into for one point, so migration 36's function can't be reached.
- **Fix (N4):**
  - **each point has its own ⋮⋮** while editing, at the start of its line;
  - **its menu:** Turn into › Text / Checklist point ✓ / Work item under this one, then Delete;
  - **a ticked point:** the menu says "A ticked point stays as it is", with no Turn into;
  - the block's own ⋮⋮ keeps drag and Delete.
- **Test:** turn the second of two points into a work item for Islam. The point is gone, the work item row takes its place on the page, and the card shows the row.

## F89, more (lead)
- A new table starts with **one column**, not 2 × 2 as planned (review 76 §5), and "+ Add a column" does nothing. Start at 2 × 2, and make + column work.

## F93. One edit session writes several "edited it" lines
- **Seen:** NST-026 shows "You edited it" three times (11:23, 11:23, 11:24) after one session: the save, a work item added under it, and Done.
- **Fix:**
  - the same person's edits to the same post within 10 minutes are **one history line**, with the latest time;
  - the words are "You edited the page" / "Omar Haddad edited the page" (F91);
  - a work item added under it has its own line: "Added a work item under this one: Seal the riser sleeve".
- **Server or app:** the app can fold the lines on the card. If it does, the post page still lists every edit.

## F94. A walk's rows change order after it is sent
- **Seen:** taken in the order "loose cable tray", then "missing label"; the waiting card showed them in that order, but once sent, "missing label" came first.
- **Cause:** `create_walk` inserts every work item in one transaction, so they share one `created_at`. The card orders rows by `created_at, id`, so the order depends on random ids.
- **Fix (a small migration):**
  - `create_walk` gives each work item `created_at = now() + n microseconds` in the order of `p_items`, or a `walk_position` it orders by;
  - existing walks keep the order they have;
  - test: a 5-photo walk comes back in photo order.

## F95. Walk mode doesn't remember the last place
- **Seen:** the second walk's "Where" was empty, though the first used "Level 2" a few minutes before.
- **Fix (review 77 §1):** prefill "Where" with the last place used for a walk in this Space on this phone; the person can change it.

## Small (lead)
- **Search results** show the reader's own name ("Omar Haddad · today"). Use "You" there too.
- **The walk's "Who does it" picker** shows "now" under the chosen person. Drop it (also noted above).

## F96. The phone can't get a push token for a while: the app keeps trying (Claude Code, build 529)
- **Seen:** on the founder's Xiaomi, on a phone hotspot, Google Play services answered "FCM Registration failed!" four times in 22 seconds (21:40), so the new install id never reached the server. The same happened on 17 Oct, and a restart fixed it then.
- **Why it matters for the pilot:** site phones often live on hotspots and weak signal. Today the app gives up after its four tries until the next start, so a phone can go a whole day without pushes and nobody notices.
- **Fix:**
  - **keep trying** on every resume and when the signal comes back, then every 30 minutes while the app is open, until a token is registered for this install;
  - **if there's still none after a day,** Settings › Notifications shows one quiet line, "This phone isn't getting notifications yet. Restart the phone, then open BuildVibes." / «لا يصل الإشعار إلى هذا الهاتف بعد. أعد تشغيل الهاتف ثم افتح BuildVibes.»
- **Test:** with the token call failing, the app tries again on resume and on reconnect, and registers as soon as it works.

## F97. A direct message inside the 5-minute quiet time is never pushed (slice 10)
- **Seen (Claude Code, 22:08):** the server pushes one DM per conversation every 5 minutes. "Test 2", sent 78 seconds after "Test 1", got no push at all.
- **Risk on site:** the later message is often the one that matters ("stop the pour").
- **Fix:** keep the quiet time, but at its end, if newer messages are still unread, send **one** push: "Omar Haddad · 2 new messages" / «عمر حداد · رسالتان جديدتان», which opens the conversation. Never more than one per quiet time.
- **Test:** 3 messages in 2 minutes give the first push, then one "2 new messages" at 5 minutes if unread, and nothing if they were read.

## Build 529 test (22 Oct, evening): F81 passed in part
- **Closed app:** "Test 3" (22:27) reached the phone as **one** notification with sound, and a tap opened the conversation. The 13 Oct token answers on another device, not this phone.
- **The screen not waking** for a notification is the Xiaomi's own setting ("Wake screen when notifications arrive"). No change.
- **Still to check:** the banner while the app is open.

## F98. A new conversation starts with who you're talking to (founder, "ok")
- **Seen:** in a new conversation the first message sits at the bottom, with the whole screen empty above it.
- **Fix (as WhatsApp does):**
  - messages stay anchored above the typing box;
  - the empty top of a conversation's beginning holds a small **person card**: face, name, role · company, the Spaces you share ("Both in NBKCH SITE TEAM"), and **View profile** / «عرض الملف»;
  - the card is the first thing in the conversation, so it scrolls away as messages come and is there when scrolling back to the start;
  - a request (someone who shares no Space) shows the same card, with the request's Accept / Block under it.
- **Test:** a new conversation shows the card at the top and the first message near the typing box; with 30 messages the card is reached by scrolling up; EN and AR.

## Build 529 test (23 Oct, morning): the banner shows, but for a blink
- **Screen off (Test 4, 10:21):** a notification with sound; a tap opened the conversation. ✓ (as 22 Oct).
- **App open on Home (Test 5, 10:44):** the in-app banner appeared for about 0.1–0.2 s, then went. Too short to read or tap.

## F99. The in-app banner must stay long enough to read and tap
- **Seen:** the banner for a direct message flashes and disappears at once.
- **Likely cause (to confirm):** something rebuilds or replaces it straight after it shows, for example the Messages refresh from Realtime or the push, a second banner call for the same message, or the shell's overlay being rebuilt.
- **Fix:**
  - it stays **4 seconds**, then slides away;
  - a tap opens the conversation; a swipe up dismisses it;
  - a second message from the same conversation while it shows updates the same banner (text and count), without restarting it from zero; a different conversation replaces it;
  - not shown while that conversation is open;
  - no sound inside the app (the phone's own sound is for a closed or background app).
- **Test:** a widget test pumps the banner, then a Messages refresh, and it is still there at 3.9 s and gone at 4.5 s; a tap opens the conversation.

## Build 547 test (23 Oct, 11:55): F99 passed; nothing shows inside the quiet time
- **F99 ✓:** Test 6, app open on Home: the banner stayed 4 seconds.
- **Seen:** Test 7 and 7b, two messages 2 seconds apart a minute later, app open on Home: **no banner and no unread dot** on Home or the Messages tab.

## F100. With the app open, a new message must show at once, push or no push
**Cause, from the code (`dm_live.dart` on `slice2-app`):**
1. **The banner comes only from a push** (`_arrived`). Inside a conversation's 5-minute quiet time no push is sent (by design, for the lock screen), so the app shows nothing. The quiet time is for the phone's notifications, not for the open app.
2. **`dmPushKinds` lacks `dm_follow_up`**, so F97's follow-up arriving while the app is open is ignored: no banner, no list refresh.
3. **The live channel didn't refresh the dot.** Each thread's `dm:<id>` private channel (migration 31) should invalidate the inbox on a new row, but Home and the tab didn't change. That matches the founder's 22 Oct finding ("I have to close the app and open it again to see Omar's message"), so the live path has likely never worked on the phone.

**Fix:**
- **Find why the live channel is silent.** On the phone over adb, log each `dm:` channel's `subscribe` status and error, and whether a callback ever arrives when Omar sends. Likely suspects:
  - the private join is refused;
  - Postgres changes on a private channel aren't authorised by `daybook_live_receive` (broadcast only);
  - the channel is never subscribed for the thread.
  
  Fix the cause. If Postgres changes can't run on the private topic, use a broadcast from a `dm_messages` insert trigger (`realtime.send` to `dm:<thread>`, as the daybook does), in a new migration with a test that a non-member can't receive it.
- **The banner comes from the live update when the app is open:** a new message from the other person, in a thread that isn't on screen, shows the banner (name, and the text only if the lock-screen setting allows, as the push does). It's deduplicated by `message_id`, so the push for the same message doesn't show it twice.
- **Add `dm_follow_up` to `dmPushKinds`.** A follow-up while the app is open only refreshes the list. No banner, since each message already had its live banner.
- **Tests:**
  - a live insert with no push shows the banner and the dot;
  - the same message arriving by live and push shows one banner;
  - a follow-up push refreshes and shows no banner;
  - the SQL test for any new broadcast policy.

## Build 560 test (24 Oct, 08:35): F97 passed; F100's live path confirmed silent
- **F97 ✓:** Omar sent "Ttt" (08:35:25) and "ttttt" (08:35:29). The first was pushed at once. The second, inside the quiet time and left unread, came at about 08:41 as one follow-up: "Message from Omar Haddad · 1 new message", with no text.
- **Background, 2 messages, 1 notification:** as designed.
- **App open on Home:** message 1's banner came from its push. Message 2 changed nothing: no new banner text, no dot, no list refresh.
- **The phone's `BV-LIVE` lines:** the `dm:` channel was joined throughout the test (it closed at 08:32:39 and rejoined at 08:32:41), but no live update arrived. So Postgres changes don't reach the private `dm:` channel on the live server, though they did on the local one.
- **Next:** F100's fallback on `claude/f100-broadcast`: migration 40 broadcasts ids to `dm:<thread>` on insert and delete, as the daybook does, and the app listens for that broadcast.

## Build from `claude/f100-broadcast` (24 Oct, 09:30): F100's live path works
- **Seen:** with the app open on Home, a message sent just after a banner ended showed a new banner at once. That message was inside the quiet time (no push), so it came by migration 40's broadcast. F100 ✓ for the live update.
- **Seen:** a second message sent while the banner still showed changed nothing visible. The founder's "Show message text on lock screen" is off, so both read "Message from Omar Haddad · New message"; the words were replaced by the same words.

## F101. A second message on a showing banner must be visible when the text is hidden
- **Fix:** while a banner of one conversation shows and the text is hidden, each newer message from it counts up: "2 new messages" / «رسالتان جديدتان», "3 new messages" / «3 رسائل جديدة», "11 new messages" / «11 رسالة جديدة». Same words and Arabic counting forms as F97's follow-up push. The 4 seconds restart, with no new slide-in. With the text allowed, it shows the newest message's words, as now.
- **The count:** messages from this conversation since the banner first showed, still unread. A new banner (after it ended) starts again at "New message".
- **Test:** text hidden, 3 messages 1 s apart: "New message", "2 new messages", "3 new messages", still there at 3.9 s after the third; in EN and AR.

## Build 565 test (24 Oct, 09:30–09:57): F100 ✓, F101 ✓, pushes ✓
- **App open:** the banner counts up ("New message", "2 new messages", "3 new messages"), and the dot and list update. F100 and F101 pass.
- **"No notification with the app closed":** checked on live. Every push was queued, held or sent as designed, with FCM 200 for both tokens. The two sent at 09:30 and 09:48 arrived while the app was open, so the app showed its banner rather than the phone's own notification.
- **Locked, clean test:**
  - the follow-up for 12 held messages arrived on the lock screen ("12 new messages");
  - one message after the quiet time arrived at once, with sound;
  - the next one, inside the quiet time, gave no sound and left the notification as it was, as designed (F97).
- **Still to test:** F47, the daybook live update in an open Space.

## F102. Message notifications as WhatsApp, with mute for a time (founder, 24 Oct: "make it the same way, and add an option to mute a Space, like other apps")
**Today:** a conversation's first message rings; the next ones within 5 minutes change nothing on the lock screen; one follow-up comes at 5 minutes if unread (F97). The lock screen lags behind for up to 5 minutes.

**New, for direct messages and Space chat alike:**
- **Every message pushes.** It updates the **same** notification for that conversation (same tag), so the phone shows one per conversation, never a pile:
  - with "Show message text on lock screen" on: the newest words, with "Omar Haddad" as the title, and the count when there is more than one ("3 new messages" under the latest words, Android's messaging style);
  - with it off: "Message from Omar Haddad · 3 new messages" / «رسالة من عمر حداد · 3 رسائل جديدة»;
  - Space chat: the thread's name never shows (the notifications rule, never a Space or project name). It reads "Message from Omar Haddad in a Space chat · 3 new messages".
- **Sound and vibration on each message,** as WhatsApp. Android itself limits how often one app may sound.
- **The count** is that person's unread messages in that conversation, counted when the push is sent. Opening the conversation clears the notification (the app cancels it by tag).
- **The 5-minute quiet time and F97's follow-up end** for messages: `handle_dm_push` and the Space chat push queue every message; `dm_follow_up` stays a valid kind but is no longer queued.
- **With the app open:** the F99/F101 banner as now; no phone notification.

**Mute, as WhatsApp ("Mute notifications"):**
- **A Space:** Space info → Notifications keeps its single choice (All / Needs you only / Off). Choosing Off or Needs you only asks **for how long**: 8 hours / 1 week / Always (one single choice). After the time, it goes back to All by itself.
- **A direct message:** Mute asks the same: 8 hours / 1 week / Always.
- **Quick way in:** long-press a Space in the Spaces list, or a conversation in Messages, to get Mute / Unmute.
- **A muted row** shows Phosphor's bell-slash beside its name. A muted conversation still shows its unread dot.
- **Server:** `space_members.notify_until` and `dm_members.muted_until` (null = always). `space_push_level` and the DM mute check treat a passed time as unmuted. RLS: only the person themselves sets their own.

**Tests:**
- **SQL:** 3 messages in 10 seconds queue 3 pushes, each with its count (1, 2, 3); a muted Space or conversation queues none until its time passes, then queues again; nobody can set another person's mute.
- **App:** the mute sheet's three choices in EN and AR; the bell-slash on the row; long-press Mute; opening a conversation clears its notification.
- **Phone (founder):** locked, Omar sends 3 messages 2 seconds apart; one notification updating 1, 2, 3, with sound each time. Then mute for 8 hours, and nothing comes.
