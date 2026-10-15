# Daybook: the design style and the Space Work experience

Founder decisions, 14–15 Oct 2026. Figma: EN page "PROTOTYPE · Full app v1 · EN" (`2145:3`), flow "★ Space · all scenarios (Daybook)" (`2545:35161`). The full scenario map is in `space-scenarios.md`.

**Name:** Daybook (Arabic: دفتر اليومية). It names the style and the Work experience. "Make it Daybook" means: paper slips, ink stamps, the time spine, writing in place, the keyboard toolbar, and gestures.

**Design terms behind it:** light skeuomorphism (tactile paper), a timeline or journal layout, content-first in-place editing with a keyboard accessory toolbar, progressive disclosure, gesture-first.

## Rules
1. **Chat is WhatsApp; Work is the Daybook.** Talk stays in the Space chat. Work stays in the Work tab.
2. **No SaaS screens.** No field grids, labelled form sections, comment boxes or big form buttons. No list of records that opens another screen.
3. **Minimal by default, depth on choice.** A post shows only what its author added. Depth comes through More, "/" and opening a post in place.
4. **The app's own words are neutral.** App text never uses trade words (no RFI, WIR, snag, drawing, level, grid, inspection, pour). What people type can be in their trade's language. Trade names appear only in templates a company names itself.
5. **No description lines under menu options.** If a word needs explaining, change the word.
6. **Only the main action on a screen gets the full orange fill** (Post, Sign as done, Check). Everything else is a text button or a soft pill.
7. **The one-minute test.** A foreman must manage every main action in under a minute without help.

## The daybook
- Each day opens with a masthead: the day name large, the date, the day count on site, and the weather from the phone. While typing it shrinks to one line.
- A thin hour spine runs down the leading edge. Each post hangs on it at its time. Days are separated by a day divider. Tap the date to drop down the month (dots for posts, rings for due dates).
- Posts are paper slips with a torn top edge and a soft shadow. Photos are big.
- Stamps are tilted ink stamps with name and time: DONE (action colour), CHECKED (positive), SENT BACK (destructive), CANCELLED (grey), NEW VERSION.
- **Needs you** is a paper clip on the slip's top trailing corner.

## Writing, in place
1. Tap **Work item** in the bottom bar. An empty card appears at the bottom of the daybook (at "Now"), not in a sheet. A dashed edge means not posted.
2. The card holds the kind chip ("Work item ▾"), a large title and a text line. Nothing else.
3. A slim toolbar sits on the keyboard: camera, attach, more (⋯), and a round send button (grey until there is a title).
4. **More:** Assign, Location, Due date, Checklist, Template. Choices show as one quiet line under the title. A cover photo has a small ×.
5. Nothing is posted until send. If the app closes, the card stays in place as a **Draft** (only the author sees it) and reopens in writing mode.
6. **Kind chip** (one single-choice menu): Work item, Checklist, Announcement, Scheduled activity, File.

## Kinds of posts
- **Work item:** one owner, due date, place, files, checklist points. Sign as done with a photo; check or send back.
- **Checklist:** title, who it is for (one or more), due date, points ticked in place (struck through, with who and when), a thin progress line, "2 of 5 ticked".
- **Announcement:** pinned under the masthead until a date, to everyone or a Team. **Got it**; the author sees faces, no number.
- **Scheduled activity:** calendar leaf (weekday, day, month), title, time, place, people. "Add to my calendar". On the day it appears again ("starts in 30 min", **On my way**).
- **File:** big preview, NEW VERSION stamp when it replaces an older one ("Replaces Rev C · 2.4 MB"), a note, **Received**, faces of who received it.

## Acting on work items
- **Owner:** a "Sign as done" chip on the slip, or hold the round camera button: the camera opens linked to that work item (its name at the top; the photo labelled with place, date, time and name). Holding fills a ring; releasing sends it as done.
- **Author:** double-tap the proof photo to check it (stamp drops 130%→100%, −15°→−9°, 180 ms, one strong haptic; "Checked" toast with Undo for 5 s, then locked). Long-press the proof: Check, Send back, Add update, Discuss in chat.
- **Send back** stays in place: one choice (Photo missing, Not as asked, Not finished, Something else), optional note or voice. The owner sees SENT BACK on the photo, the reason, the paper clip, and "Sign as done" again.
- **Swipe a slip** (towards the trailing edge) to add an update. It hangs under the work item as a small note quoting it.
- **Long-press your own work item:** Edit, Add update, Give to someone else, Discuss in chat, Cancel work item.
- Edited: a grey line ("Edited: due moved from Sun to Mon"). Cancelled: faded, struck-through title, CANCELLED stamp. Reassigned: "Given to Rakesh Nair instead of Omar Haddad at 12:30". Late: "Late by 1 day" in red; a "Due today" strip under the masthead.

## Opening a post in place (the Notion depth)
- Tap a slip: its full page rises over the daybook as the same paper sheet.
- Blocks: text, heading, checklist, toggle, table, photo, file, work items under this one. The author gets drag handles (⋮⋮), + between blocks, "/" to pick a block, and **Turn into** (text ↔ checklist point ↔ work item under this one).
- **Work items under one** (a target): mini rows with owner and stamp, a progress line, "2 of 4 checked".

## Who can do what (enforced on the server)
| Action | Who |
|---|---|
| Post | Lead and Crew |
| Edit (title, text, owner, due, place, files, points) | The author only |
| Add an update, tick a point | The owner, and any Lead or Crew member |
| Sign as done | The owner only |
| Check or Send back | The author only |
| Read | Everyone in the Space, Viewers included |

- Edits after posting are shown and notify the owner. Drafts are private.
- After Done the author can only Check or Send back; Send back reopens editing. After Checked nobody can edit.
- Delete only while nobody has added anything; after that, Cancel (stays with a CANCELLED stamp).
- The owner disagrees by posting an update, never by editing.
- The Space admin can't rewrite anyone's post; they can reassign or cancel only if the author has left the Space.

## Other Space parts in Daybook style
- **Walk mode** (camera mode "Photo · Walk"): each shot gets one line (typed or voice) and an owner; Finish posts one item with a work item per photo under it.
- **Daily report:** a template; "Done today" fills from what was checked that day; Share as PDF.
- **Meeting notes:** long-press a chat message, tick the action lines, give each an owner, post them as one item with work items under it.
- **People:** join request as a quiet row (Decline text, Let in pill), then one pass choice (Lead, Crew, Viewer). A Viewer's daybook has no writing bar, only a "Viewer · Read only" mark.
- **Library:** files with stacked versions and who received them. **Search** sits behind ⋯ in the Space header.
- **No signal:** a strip under the masthead; posts show "Waiting to send" with upload progress; failures say "Couldn't send the photo. Tap to try again."
- **Push** opens the exact slip. **Needs you** across Spaces is grouped by Space, with paper clips.
