# Review 113: the founder's test of the Space and the notebook on build 919 (1 Nov 2026)

**Founder, 18:32–21:29.** 18 comments, each decided in the chat. **Status: decisions agreed; frames to be drawn by the lead before building.**

## Scope decision
- **(6) The Home feed is hidden from the MVP** and comes back after the pilot.
  - The bottom bar loses Home, and the app opens on **Spaces**.
  - The notebook share offers Space and Message only.
  - The feed's code stays, behind one switch, so it's quick to turn back on.
  - The feed notes (`2026-11-01-feed-notes.md`) wait for after the pilot.

## The Spaces tab
- **(2) No repeated information.**
  - Keep **one** "N need you" line at the top. It opens everything across Spaces that needs me.
  - Each Space row keeps its own small "needs you" mark.
  - The separate highlighted "Space with activity" block is removed.
- **(3) "New Space" and "Join with a code"** become small word buttons, not big cards. They sit at the end of the list, and in the empty state when I have no Space.
- **(4) No Search in the Spaces tab's top bar.** Search lives in Explore only. Messages and Notebook stay.

## Inside a Space
- **(5) Work · Chat:** Work first, in that order. The first open is Work. After that, **the Space remembers the last tab I used in it**.
- **Cards: React and Share**, always visible on every post (13, 15):
  - **React:** 👍 Like · ❤️ Heart · 👏 Bravo only.
    - One per person per post; tapping again removes it.
    - Under the post: the icons with the small faces of who reacted, never a number. Tapping shows the names.
    - The author gets one quiet notification, grouped.
    - No reactions on a Check-in.
  - **Share:** sends the post **into this Space's Chat** as a card (Everyone, or a Team chat I'm in). Never outside the Space.
- **Hold a post** (14, 16):
  - **My post that nobody has acted on** (reactions don't count): **Delete**.
  - **My post that someone has acted on** (an update, a sign-off, a check, a file, a tick, Got it, a check-in): **Archive**. It leaves the daily view and stays in the record, in the Archive.
    - Archiving an **open work item** stops it, and its owner gets one notification ("… archived: no longer needed").
    - A repeating Check-in also has **Stop**.
  - **Someone else's post:** nothing to hold.
  - **Duplicate is removed from the Space.** "Save as template" from a post comes after the pilot.
  - A Checked work item can never be deleted or archived by its author, as today.

## The composer
- **(1) Discard.** The composer's top bar gets **Discard** («تجاهل»). × keeps the draft. Discard asks once ("Discard this draft?") and removes it.
- **(10) Type, For and Team are pinned to the bottom of the composer,** just above the bar, always in the same place:
  - Title and details fill the space above and scroll there.
  - **Type** is the first of the three lines ("Type · Work item ›"). It opens the kinds grid, and **the # button is removed from the bar**.
  - The second and third lines follow the kind (review 110's table): For · Team for a work item, When · Team for an activity, To · For for Thanks.
  - Added extras (Place, Due, Tag) show as chips just above the three lines.
- **(11) The bar is + · camera · mic · Send.**
  - **Hold the mic** to record a voice note, as in WhatsApp. The note attaches to the post and plays on the card.
  - Hold Send = Post later, as today.
- **(12) A long press in the text** keeps the phone's own menu (Paste, Select all) and **adds Date & time · Bullets · Table**.
  - Date & time inserts today's date and time as text.
  - Typing **/** at the start of a line opens the same short menu.

## Check-in
- **(17) Lead forgot:**
  - **Before the pilot:** "Every day" covers the repeats. If a Space has used check-in before and a working day has **no check-in 30 minutes before its usual time**, the Lead gets one push: "No check-in posted for today. Post one?" Tapping it opens the composer filled from the last check-in.
  - **After the pilot:** "I'm on site", a self check-in at the Space's saved point.

## A new action
- **(18) "Need you now"** («مطلوب الآن»):
  - **Where:** from a person's face, or the Space's People list.
  - **What it sends:** an optional one-line reason and Place, sent on the **strong channel** (as Check-in), even with the app closed. It reads "Omar needs you now · NBKCH Site: Gate 2, concrete truck waiting".
  - **Its buttons:** **On my way · Can't now**. The sender sees the answer.
  - **Who:** only people in a shared Space; not Viewers; not across a block.
  - **Limit:** at most 3 to the same person per hour.
  - **Privacy:** the lock-screen rule applies.

## The Library
- **(8) Folders.** The Library gets folders, each shared with **only me · a person · a Team · the whole Space**. A file inherits its folder's sharing. Today's files stay where they are.
- **(9) Link folder** («ربط مجلد»):
  - **Adding:** paste a share link from **OneDrive, Google Drive** (or Dropbox), and give it a name. It shows as a folder with that service's icon, with the same sharing choices as (8).
  - **Opening:** it opens in the browser, with no sign-in to the service from BuildVibes.
  - **The warning line:** "Anyone with this link can open it, even outside BuildVibes."
  - **Later:** seeing the files inside, in the app, needs a real connection (after the pilot).

## Bug
- **(7) "Couldn't send · Tap to fix" after uploading a file.**
- **The live log (lead, read-only):** two **Library PDF uploads** in NBKCH were refused by storage with **HTTP 400**:
  - 16:02:09 and 16:02:26 UTC;
  - path `space-files/<space>/library/125848ae-…/<file>.pdf`.
  - No `library_files` row was made.
- **What's ruled out:** his permission is fine. Run as him, `may_upload` on that path is **true**, `can(add_files)` is true, and he has 0 loose and 0 today uploads.
- **So the refusal is the bucket's own check.** The likely causes:
  - **size over the bucket's 25 MB limit** (`file_size_limit = 26214400`); Supabase answers 400 with an inner 413;
  - or a **content type not in the bucket's list.** The PDF is sent as `application/octet-stream` by some file pickers or drives, and the bucket allows only `application/pdf` (plus images, audio and .xlsx).
- **Fix, test first:**
  - Before uploading, check the size, and send the right content type from the file's extension (`.pdf` → `application/pdf`).
  - Over the limit, say so in plain words before uploading: "This file is 38 MB. The most is 25 MB." («حجم الملف 38 ميجابايت. الحد الأقصى 25 ميجابايت.»). Offer **Link folder** (9) for big drawings.
  - "Tap to fix" opens a line saying **what's wrong**, with **Try again** or **Remove**. Never a dead end.
  - Map storage's errors (size, type) to those lines.

## Order
1. **Frames** by the lead for the changed screens:
   - the Spaces tab;
   - the card with React and Share and the reactions;
   - the hold bar;
   - the composer with the pinned lines, the mic and Discard;
   - the long-press menu;
   - "Need you now" (the send sheet and the notification);
   - the nudge;
   - Library folders and Link folder.
2. **The founder's ok** on the frames.
3. **The build,** as one review, **before review 111** (founder, 21:34: "ok").

**Status update (21:34):** the frames are approved by the founder. Build next.

## Frames (drawn 1 Nov, waiting for the founder's ok)
| Frame | What | EN | AR |
|---|---|---|---|
| CV3 | Composer: Discard in the top bar; writing on top; chips; **Type · For · Team pinned**; bar + · camera · mic · Send | `2730:39817` | `2730:40277` |
| RX1 | Cards with **React · Share**; reactions as icons with faces; the React picker (Like · Heart · Bravo) | `2730:39887` | `2730:40347` |
| NN1 | **Need you now** sheet: person, optional reason, Add place, send | `2730:39983` | `2730:40443` |
| NN2 | Its notification (app closed): **On my way · Can't now** | `2730:40034` | `2730:40494` |
| ST1 | Spaces tab: one needs-you line, each Space with its mark, small **New Space · Join with a code**, no Search; bottom bar without Home | `2730:40062` | `2730:40522` |
| LB1 | Library folders with who sees each (Whole Space · a Team · a person · Only me), and a linked OneDrive folder | `2730:40149` | `2730:40609` |
| LB2 | + → **Link folder**: paste, service found, name, who sees it, the warning, Add folder | `2730:40228` | `2730:40688` |
