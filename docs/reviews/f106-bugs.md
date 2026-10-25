# F106 bugs: the notebook on build 585 — 25 Oct 2026

Found by Claude Code before F107 (review 92), on `claude/f106` (a812cb8, build 585). Driven by hand on the emulator (`emulator-5554`, Android 16, 1080×2400), signed in as Omar Haddad on the live project, in English and Arabic, with and without signal. The code behind each path was read too; bugs a tap can't show are marked **found in code**.

Paths walked: write; switch kind; checklist Enter and Backspace; to-do with by when and Remind me; photo (the emulator's camera); voice note (the bar's mic and the slip's Voice tool); Back to a draft; reopen the draft; leave the notebook and come back; edit a saved note; delete; pin and unpin; Put in a Space (NBKCH SITE TEAM); Arabic; airplane mode (write, photo, delete, signal back).

Clean-up: the work item made by Put in a Space (**NST-032 "Call the pump supplier"**, for Omar himself, posted 8:16 am) was cancelled from its menu at 8:17 am. All 12 test notes were deleted (a checklist, two to-dos, four voice notes, four notes, one pinned), so the notebook is empty again, with no draft and no reminder left set. The app is back in English and airplane mode is off.

Screenshots: `docs/screens/f106-bugs/`.

**Marks.** *gone with F107*: part of the writing UI F107 replaces (the title and body fields, the kind chip, the point editor, the Voice tool). *fix anyway*: drafts, saving, reminders, data or the list; fixed on `claude/f107`, each with a test.

| | Bug | Mark |
|---|---|---|
| B1 | Enter in the title makes a second title line | gone with F107 |
| B2 | Backspace on the empty "Add a point" line does nothing | gone with F107 |
| B3 | Taking a photo puts the slip down as a Draft | fix anyway |
| B4 | The Voice tool's voice note lands out of sight | gone with F107 |
| B5 | Remind me asks "Due by a time?" | fix anyway |
| B6 | A note's time changes after it is read again | fix anyway |
| B7 | A sent or edited note jumps to the end of its day | fix anyway |
| B8 | Waiting notes don't go when the signal comes back | fix anyway |
| B9 | The list doesn't show the end of today | fix anyway |
| B10 | The slip grows under the tools bar | gone with F107 |
| B11 | Put in a Space drops the note's photos | fix anyway |
| B12 | A reminder can come up to an hour late | fix anyway |
| B13 | Send forgets the draft before the note is kept | fix anyway, found in code |
| B14 | An edit sends the pin as it was when the edit began | fix anyway, found in code |
| B15 | A refused save loses the note without a word | fix anyway, found in code |
| B16 | A reminder that passed while it was a draft is kept silently | fix anyway, found in code |
| B17 | The bar's mic has no spoken label | fix anyway |

Counts: **gone with F107: 4** (B1, B2, B4, B10). **fix anyway: 13** (B3, B5–B9, B11–B17), of which **found in code: 4** (B13–B16).

---

## B1 · Enter in the title makes a second title line — gone with F107
- **Steps:** Note → type "Pour slab L3" → Enter → type "Check rebar cover".
- **What happened:** both lines stay in the bold title field; the body stays empty ("Write a note…" still shows under them). Switching to Checklist keeps both lines as a two-line bold title instead of turning the second into a point. On a reopened edit the note splits at the first line again, so the same note opens differently from how it was written.
- **Expected:** Enter in the title moves to the next line of the note (the body, or the first point).
- Screenshot: `B1-title-enter.png`.

## B2 · Backspace on the empty "Add a point" line does nothing — gone with F107
- **Steps:** Checklist → type three points with Enter after each → the cursor is on the empty "Add a point" line → Backspace.
- **What happened:** nothing; the cursor stays on the empty line. (Backspace on an emptied real point works: it goes and the one before takes the cursor.)
- **Expected:** as Work (F40): Backspace on the empty last line goes back to the last point.
- Code: `_PointsEditorState._key` returns early when the line isn't a point yet (`at < 0`).

## B3 · Taking a photo puts the slip down as a Draft — fix anyway
- **Steps:** Note → write a to-do → Photo → take the picture → Done.
- **What happened:** back from the camera, the slip is a **Draft** ("Kept as you left it. Tap to go on writing."), the keyboard and the tools are gone, and the bar is back. The person has to tap the draft to go on.
- **Expected:** back from the camera (or the file picker, or a permission prompt), the slip is still being written, with the new photo and the keyboard.
- **Why:** `AppLifecycleListener(onHide: _putDown)` treats the camera's activity as the app going behind.
- Screenshot: `B3-photo-puts-down.png`.

## B4 · The Voice tool's voice note lands out of sight — gone with F107
- **Steps:** Note → type "Site walk" → hold the slip's Voice tool for 3–5 s → let go.
- **What happened:** the recording bar shows while holding, then nothing seems to happen. The voice note *was* saved, as its own slip **after** the writing slip, below the tools bar, so it can't be seen; I made three before finding them by scrolling.
- **Expected (F107):** Voice records a voice block inside the note.
- Screenshot: `B4-voice-out-of-sight.png`.

## B5 · Remind me asks "Due by a time?" — fix anyway
- **Steps:** Note → Remind me (bell) → pick a day.
- **What happened:** the time step is the due picker's, headed "Due by a time?", with "No time" (which means 9 am for a reminder, but doesn't say so). It also opens on the current minute, so OK at once is refused as a time gone by.
- **Expected:** the reminder's own words: "Remind me at…", and "No time" reading as the morning, and a start time that isn't already past.
- Screenshot: `B5-remind-due-title.png`.

## B6 · A note's time changes after it is read again — fix anyway
- **Steps:** open a slip at 7:58 → write a checklist → Send at 8:00 → leave the app's notebook state (Put in a Space, back) so the notes are read from the server.
- **What happened:** the checklist said "7:58 am", then "8:02 am"; the to-do went from 8:02 to 8:07; "Site walk" from 8:08 to 8:10.
- **Expected:** one time, the same before and after.
- **Why:** the phone shows the time the slip opened (`NoteDraft.toNote` uses `startedAt`), but `save_note` inserts `created_at = now()` (when the server gets it, after a send queue or an offline wait).

## B7 · A sent or edited note jumps to the end of its day — fix anyway
- **Steps:** with notes at 8:08 and 8:10 → edit the 8:08 note ("Site walk" → "Site walk B2") → Send.
- **What happened:** the 8:08 note now shows **after** the 8:10 one; a note sent from a slip opened earlier also lands after later voice notes.
- **Expected:** each day stays in time order.
- **Why:** `NoteChange.applyTo('save')` puts the saved note first in the list ("newest"), whatever its time.
- Screenshot: `B7-edit-jumps.png`.

## B8 · Waiting notes don't go when the signal comes back — fix anyway
- **Steps:** airplane mode on → write "Offline note" → Send; write "Offline photo" with a photo → Send (both "Waiting to send") → airplane mode off → wait a minute → leave the notebook and open it again.
- **What happened:** both still "Waiting to send" after 45 s and after reopening. They went only when I made another change (a delete).
- **Expected:** they go as soon as something gets through again, when the notebook opens, and when the app comes back to the front.
- **Why:** `Notebook._send` runs only from a change or from `build()`, and `notebookProvider` is never rebuilt (it is kept alive, and the reminder host listens to it), so "goes when the notebook opens again" never happens.

## B9 · The list doesn't show the end of today — fix anyway
- **Steps:** with a dozen notes → Send a new one; or leave the notebook and open it again.
- **What happened:** after Send, the new note sits under the bar, cut off. Reopening, the list starts at the top (the pinned band and the first notes), so the newest notes and a Draft are off screen.
- **Expected:** the notebook opens at the end of today (bottom-aligned, newest last, as review 90 says), and a sent note is shown.

## B10 · The slip grows under the tools bar — gone with F107
- **Steps:** write a to-do, add a by-when and a reminder, or a few lines.
- **What happened:** the slip's chips and its last lines go under the tools bar; the list only scrolls the slip into view when it opens.
- **Expected:** the line being written stays above the bar. (F107's slip must keep its end in view as it grows.)
- Screenshot: `B10-slip-under-bar.png`.

## B11 · Put in a Space drops the note's photos — fix anyway
- **Steps:** a to-do with a photo, a by-when and a reminder → … → Put in a Space → NBKCH SITE TEAM.
- **What happened:** the work item's card has the words and the due, but no photo, and nothing says the photo stayed behind.
- **Expected:** the photos go with it (the card takes up to its limit), or the card says what didn't go.
- Screenshot: `B11-put-no-photo.png`.

## B12 · A reminder can come up to an hour late — fix anyway
- **Steps:** set Remind me for 8:05 pm → Send → `adb shell dumpsys alarm`.
- **What happened:** the alarm is `RTC_WAKEUP … origWhen=2026-10-25 20:05:00 window=+1h0m0s`: Android may show it any time up to 9:05 pm.
- **Expected:** at 8:05 pm, or within a few minutes. The code's comment assumes "a few minutes late"; Android's inexact window is far wider.
- **Fix:** exact when the phone allows it (`SCHEDULE_EXACT_ALARM`, no prompt), inexact otherwise.

## B13 · Send forgets the draft before the note is kept — fix anyway (found in code)
- `_NotebookScreenState._send` awaits `_drafts.discard()` (draft gone from the phone) **before** `notebook.save()` writes the note to the waiting list. If the app is killed between the two, the note is gone. Keep the note first, then drop the draft.

## B14 · An edit sends the pin as it was when the edit began — fix anyway (found in code)
- A kept edit draft holds the note as it was (`NoteDraft.editing`); Send saves `editing.copyWith(…)`, and `save_note` is always sent `p_pinned`. A pin or unpin made since (another phone, or before the draft was reopened) is undone by Send. Send should start from the note as the notebook has it now.

## B15 · A refused save loses the note without a word — fix anyway (found in code)
- In `Notebook._send`, any refusal that isn't "no signal" (a Storage refusal of a photo or a recording, a limit) drops the change and reads the notebook again: the note disappears and nothing tells the person. It should say so ("Couldn't keep this note") and keep the words as a Draft when there's no Draft already.

## B16 · A reminder that passed while it was a draft is kept silently — fix anyway (found in code)
- Remind me checks "not gone by" only when it is picked. A draft left with a reminder at 8:05 pm and sent at 9:00 pm is saved with a past `remind_at`; `remindsAt` then hides it and no reminder is set. Send should drop a past reminder and say so.

## B17 · The bar's mic has no spoken label — fix anyway
- **Steps:** `uiautomator dump` of the notebook.
- **What happened:** the round mic in the bar has no label (it is the only control in the dump without one); the slip's Voice tool says "Voice note".
- **Expected:** "Hold to record a voice note" (TalkBack and tests).

---

## Seen and not counted
- The emulator's keyboard is a floating one, so the soft keyboard never covered the screen; nothing here depends on it.
- A voice note's slip reads "0, Voice note · 8:08 am" to TalkBack: the player's slider value comes first. Work's voice notes do the same; left for the voice player's own pass.
- Arabic: the slip, the kind menu, the chips («موعده الخميس 29 أكتوبر»), the tools and Send mirror correctly, with Western digits. No bug found that is Arabic-only.
- Logs (`logcat -s flutter`): only the photo clean-up line (`BV-PHOTO … result=cleaned`) and the DM live channel's status; no error from the notebook.

---

## On `claude/f107` (F107, 25 Oct)

Every "fix anyway" bug is fixed there, each with a test (`test/features/notebook/note_page_test.dart` unless named):

| | Fix | Test |
|---|---|---|
| B3 | the app going behind while the camera, the files or the mic's permission is in front doesn't put the slip down; back from it, the keyboard is on the line | B3 |
| B5 | Remind me has its own picker words ("Remind me at…", "In the morning") and starts 15 minutes on | B5 |
| B6 | a new note's time is when it is sent; `save_note` keeps the phone's time (`p_created_at`, migration 44) | `note_models_test`, pgTAP 44 |
| B7 | a saved note keeps its place; a new one goes where its time puts it | `note_models_test` (B7) |
| B8 | what waits goes when the signal is back, when the notebook opens, when the app comes back to the front, and on a timer (15 s, doubling to 5 min) | B8 |
| B9 | the notebook opens with the end of today in view, and a sent note is shown | B9 |
| B11 | Put in a Space carries the note's photos (copies for the card) and its typed place; the GPS only when "Include my GPS position" is ticked | B11, pgTAP 44 |
| B12 | reminders are exact when the phone allows exact alarms (`SCHEDULE_EXACT_ALARM`, never asked for), inexact otherwise | not testable without the device |
| B13 | Send keeps the note on the phone's list before the draft goes | B13 |
| B14 | an edit keeps the pin the notebook has now | B14 |
| B15 | a refused note says "Couldn't keep this note" and its words come back as the Draft | B15 |
| B16 | a reminder whose time went by in the Draft is taken off at Send, and said | B16 |
| B17 | the bar's mic is its own semantics node, read out as "Hold to record a voice note" | B17 (not re-checked on the device) |

The "gone with F107" ones are gone with the page editor: B1 (Enter in the title goes on to the first line), B2 (Backspace on an empty line takes it out), B4 (Voice records a voice block in the note) and B10 (the slip's end is kept in view as it grows).
