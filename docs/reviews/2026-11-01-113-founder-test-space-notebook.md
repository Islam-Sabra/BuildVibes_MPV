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

## The lead's check of `claude/r113` at `e96e9bf5` (2 Nov)
**What was run:**
- The SQL stand-in (`git archive` of e96e9bf5 → `/srv/bvdb/run.sh`): **59 files, 4,130 checks, PASS**.
- Two independent code reviews: spec, and security/standards.
- All 38 new shots, viewed in English and Arabic.

**Verdict: not ready to merge.** Fix Z1–Z13 test-first on `claude/r113`, then go to the steps below. The screens are good. Two privacy holes must close before the migration goes live.

### Blockers
- **Z1. Search shows file names from private folders.**
  - `search_space` (last in `20261114120000_place_filter.sql`) filters Library files with `(f.team_id is null or can_read_library_file(f.id))`. A folder file has no team, so any member sees the name, uploader and revision of files in "Only me", person and Team folders.
  - Fix: redefine `search_space` in the 113 migration to call `public.can_read_library_file(f.id)` for **every** file.
  - pgTAP: a member searches for a file in someone's only-me folder, in a person folder for someone else, and in a Team folder they're not in. All three get 0 rows. The owner, the person and the Team member get 1 row.
- **Z2. The Space admin can open someone's "Only me" folder.**
  - `update_library_folder` lets the admin change sharing on any folder, so they can set "Only me" to the whole Space and read every file in it.
  - Fix: the admin may rename or delete a folder they didn't make. They may **not** change its sharing when it is `only_me`, or when it is `person` and its creator is still an active member. Only the creator changes those.
  - pgTAP for each case.

### Fix before merge
- **Z3. Proof on shared work survives a member leaving and the 30-day Library purge** (the lead's call; rule: proof comes from checked and closed work).
  - A file that is attached to a work item or posted (`post_files`, `work_item_attachments`) is **never** deleted by `drop_only_me_folders`, `library_gone` or `purge_deleted_library_files`. Only its Library row and folder go; the attachment and the storage object stay.
  - Unreferenced only-me files of someone who **left or was removed** get the same **7-day grace** as the sweep, then go. If the person rejoins inside 7 days, their folder comes back.
  - pgTAP:
    - an only-me file attached to a Checked item keeps its attachment after the owner is removed;
    - a soft-deleted Library file attached to a post keeps its attachment after 30 days;
    - an unreferenced only-me file is still there on day 6 and gone on day 8.
- **Z4. `forget_cleanup_claims` lost `'dm-files'`.** Put the bucket back, and test that a dm-files claim is cleared.
- **Z5. Copying the place of a check-in you can't see** (`post_check_in` with `p_same_place_as`).
  - Require `public.can_see_space_post(p_same_place_as)`.
  - Return **one** error (42501, "not allowed") for every failure: missing, other Space, not a check-in, deleted, not visible.
  - pgTAP: a Lead copies from a check-in limited to another Team → refused.
- **Z6. Archive push before the Undo window ends.**
  - The owner's "… archived: no longer needed" push goes only after the Undo window closes. Queue it with `send_after = now() + undo window` on the existing per-minute reminders job.
  - `unarchive_space_post` cancels the queued push and restores the item's reminders.
  - Test both.
- **Z7. Lock-screen rule for the new pushes.** `post_reaction` and `work_item_archived` name the actor only when the person has lock-screen text on, as the migration's own header says and as Need you now already does. Older reminder pushes stay as they are (after the pilot).
- **Z8. Long-press menu.** Put **Date & time · Bullets · Table first**, then the phone's own items, so ours never fall under ⋮. Widget test: the three are the first three buttons. Phone check on the Xiaomi.
- **Z9. Share errors.** In `work_share.dart`, show the "Team only" line only for the server's team-only refusal (match its errcode or message). Any other bad-input error gets the plain "Couldn't share. Try again." line. Test both.
- **Z10. Link folder hosts.**
  - Remove `docs.google.com` from both lists (server and `library_folder.dart`). A folder link is `drive.google.com`.
  - Keep `*.sharepoint.com`, because OneDrive for work lives there and the warning line covers it.
  - Run `linkServiceOf` again before `launchUrl`, and refuse with the "wrong link" line if it fails.
  - Tests on both sides.
- **Z11. Blocked people.**
  - In `react_to_post`, refuse a reaction to the post of someone who blocked you, or whom you blocked (the same rule as Need you now).
  - `post_reactions_json` leaves out people blocked either way for the viewer.
  - pgTAP.
- **Z12. Small server gaps.**
  - `answer_need_you` checks that the person called is still a member of that Space.
  - Writes to `scheduled_posts.params` take `lock_file_path` on each file path, as the sweep does.
  - The check-in nudge respects the Lead's mute on that Space.
  - Tests.
- **Z13. Old drafts.** When a draft is opened or sent and one of its files is gone (the 7-day sweep), the file chip shows the existing "Couldn't send" line with Remove. Never a silent failure. Widget test.

### Accepted as built
- **NN3/NN4.** The Need you now line under Work · Chat has no frame of its own, but it uses the same needs-you strip and the NN2 buttons (On my way · Can't now). The sender sees Waiting, then the answer. Accepted.
- **Check-in shows four pinned lines** (Type · For · Check-in · Place). A check-in needs both its time and its place. Accepted.
- **The CV3_long_press labels draw as blocks** only in the shot renderer (the phone's own menu text). Phone check.
- **A Space admin may Stop someone else's repeating Check-in** (109 Y6), so the hold bar shows only Stop on those. Accepted.
- **A Lead can still archive their own Checked item** (105B). Accepted.
- **The needs-you number on each Space row** counts things waiting for you, not a quality signal. Accepted.
- **A Space row says "new today" with no number.** Accepted.
- **When a file's size is unknown,** storage's refusal is mapped instead. Accepted.

### Next steps (each live step is from the PC, with the founder's yes)
1. Fix Z1–Z13 on `claude/r113`. Then run `flutter analyze`, `flutter test` and the pgTAP run, and update the goldens (`--update-goldens`) for the 113 shots, including Z8's menu order.
2. Merge into `slice2-app` and push.
3. **Live, in this order:**
   - `supabase db push` (20261121120000);
   - the read-only `select count(*) from public.orphan_space_files()`;
   - time one run on a copy of that count and set `NIGHTLY_CAP`;
   - only then deploy `notebook-purge`;
   - check the cron list.
4. A release build, installed on the Xiaomi 22120RN86G.
5. **Phone checks:**
   - a voice note, recorded and played;
   - Need you now from the app closed, with On my way and Can't now (MIUI);
   - the Reactions channel is quiet;
   - the long-press menu order;
   - a 38 MB PDF refused before upload, and a 3 MB PDF that uploads;
   - Library folders and a OneDrive link opening in the browser;
   - the 109 checks still open (one notification, Android 14 location from the button, the stamp, Autostart).
