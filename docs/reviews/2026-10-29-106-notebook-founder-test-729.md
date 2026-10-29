# Review 106: the founder's notebook findings on build 729 — 29 Oct 2026

## T1. Status icons: their own row, one per kind, no "+N" (corrects review 104 N12)
- **Founder, 08:07:** "I said add icons, but you added +2 … the icons, the time and the pin are all in a very narrow area, and difficult to use."
- **Frames:** NS1 EN `2680:38781`, AR `2680:38875`. **Status: approved (founder, 29 Oct 08:27).**

**The top line holds only the kind and the time.** The pin leaves it too.

**The status row**
- It sits **at the bottom of the entry**, aligned to the end: at the right in English, at the left in Arabic.
- **One icon per kind,** in this order: pinned · reminder · feed · Space · message. All of them always show; **there is no "+N" and no limit.** There are only five kinds, so the row always fits.
- **Each icon is a 32 round tap target:** a 16 icon on the sunk colour, 6 apart.
- **Colours:**
  - the reminder icon is in the accent colour while it's still to ring, grey after;
  - a tapped icon is shown selected, with the soft fill and an accent ring.
- **The row only appears when the entry has a status.** An entry with none has no empty row.

**Tapping an icon** opens a small card under it listing **every** share of that kind, with the real names and times. For example, two Spaces show as:
- "Kuwait City Tower · 08:45"
- "NBKCH Site team · 09:02"

The reminder's card keeps **Change**.

**Screen readers** use the same labels as review 104.

**Data:** the app keeps every share already (`note_shares`). Today it shows only the latest one of each kind; the card now lists all of them. **No database change.**

**Shots changed on purpose:** BH2, BH3, NB-reminder-slip, NB-remind-menu, and every notebook shot with a pinned or shared entry. Any other changed shot is listed, not accepted.

## T2. Inside a page, every entry shows in full, and each can be folded
- **Founder, 08:10:** entries in a page should be expanded by default, "as it's a page already", with a small button at the start of the title to collapse an entry, so he can organise and present his page.
- **Frames:** NS2 EN `2682:38819`, AR `2682:38903`. **Status: approved (founder, 29 Oct 08:27).**

**Inside a page, an entry shows in full by default:** every line, with text wrapping. Today it shows 3 single-line rows (`slipLines`).

**The entry's head is:** fold control · title · time.
- An entry with no title uses its first line as the title.

**The fold control**
- It is a 24 chevron at the start of the head: ⌄ when open, › when folded (‹ in Arabic). Its tap area is 44.
- **A folded entry** shows the head plus one line: "3 lines hidden" («3 أسطر مخفية») at the start and **its status icons at the end. The icons stay visible and tappable when folded** (founder, 08:13).
- Tapping the chevron (or the folded head) opens it again. **Tapping the text of an open entry still edits it,** as now.

**The page's ⋯** gains **Collapse all · Expand all**. They act on this page only.

**Folding is remembered on the entry.** It is the same on another phone and after an update. This needs **one migration:**
- `notes.collapsed boolean not null default false`;
- an owner-only update through the existing notes RLS;
- a pgTAP test that someone else can't change it.

**Elsewhere nothing changes:** the "My notebook" list keeps its short 3-line cards. Search and Filter open a folded entry when it is the match.

**Hold, swipe and line folding (toggles) work as now.** A line's own fold stays separate from the entry's fold.

## T3. Filter by status
- **Founder, 08:14:** add a status filter to the notebook's filter.
- **Frames:** NS3 EN `2685:38859`, AR `2685:38978`. **Status: approved (founder, 29 Oct 08:27).**

**A new STATUS section** («الحالة») goes in the Filter card, between SHOW and IN. It offers:
- Pinned («مثبّتة»);
- Reminder («تذكير»);
- Shared to the feed («نُشرت في الأخبار»);
- Shared to a Space («نُشرت في مساحة»);
- Sent in a message («أُرسلت في رسالة»).

Each has the same icon as its status icon.

**Choices**
- **Reminders moves** from SHOW to STATUS, as Reminder. SHOW keeps To-dos open · Photos · Files · Voice notes · Archived.
- **SHOW and STATUS are each one single choice** (rule 6). One of each can be on together: "To-dos open" plus "Shared to a Space" shows open to-dos that went to a Space.
  - Tapping the chosen option again clears it.
- **Each active choice shows as its own chip under the top bar, with ✕.**

**One card, two tabs** (founder, 08:19). The ☰ button opens one card. At its top is **a switch with one word beside it** (founder, 08:26): off = "Filter" («تصفية»), on = "Sort" («ترتيب»). Flipping the switch changes the word and the list under it. The card opens in the mode used last.
- The switch is 44×26; its tap area is the whole row. The knob moves to the end when on (to the left in Arabic). Screen readers say "Filter, switch off" or "Sort, switch on".
- **Filter mode** is SHOW · STATUS · IN (NS3).
- **Sort mode** (NS4, EN `2688:38923`, AR `2688:39062`) is one single choice:
  - **inside a page:** Newest first · Oldest first · Name A–Z · Type · **Status**;
  - **on the pages list:** Latest activity · Name A–Z · Newest created · Oldest created.
  - **Type** groups by kind (N7). **Status, new,** groups by status in the order Pinned · Reminder · Shared to the feed · Shared to a Space · Sent in a message, then entries with no status. An entry goes under its first status, newest first inside each group.
- **Sort and Filter work together:** for example, filter "To-dos open" and sort by "Status".

**It works everywhere the Filter does:** My notebook, and inside a page. Like the status row, it uses the shares the app already keeps. **No database change for T3.**

## The lead's check of `r106` (29 Oct, at `fbe1691`)
- **Runs:** SQL stand-in 3,053 checks (15 new), 0 failing. Cursor reported analyze clean and 2,525 tests passing.
- **Two reviewers** (standards, spec): no hard violations, and nothing in T1–T3 missing.
- **Shots:** the 11 changed and 4 new shots are looked at. They match NS1–NS4 apart from G2 and G3 below.

### Accepted
- Folding is saved through a security-definer function (`set_notes_collapsed`, owner only), as every notes write already is, rather than an RLS update.
- The switch keeps the design system's off colour; the N5 shots open in Sort mode; the selected icon has a screen-reader state.
- Type and Status in the sort list have a hint line.
- The head is about 6 px taller because of the 44 tap area.

### Fixes before merge
- **G1.** Archived entries in a page keep the short 3-line card, as before. "In full" is for a page's live entries only.
- **G2. An untitled entry.** The head is fold · time only, with no title, and **the text shows as the body in normal weight**. This applies to every kind: note, checklist, to-do, voice. The kind words don't come back.
  - When folded, the head shows the first line in normal weight, cut to one line.
  - This replaces the 3-line bold head in NB-put-in-space.
- **G3.** The fold chevron shows only when folding would hide something. A folded entry with 0 hidden lines and no status draws no empty row.
- **G4. Migration 50:**
  - the `update` also filters `owner_id = v_me`;
  - pgTAP adds three checks: the entry's `version` doesn't change; a deleted entry is refused; an empty array or a null `p_on` gives 22023.
  - The migration isn't live yet, so edit file 50 itself.
- **G5.** The Status grouping is written once: `EntrySort.order` is used by the page screen, instead of a second copy in `byStatus`.

Noted only, for the tidy list: the duplicated `_setFilter` in two screens; `statusHits` copying the server's search rules; `entryHead` and `entryLines` living in a screen file; the `'collapse'` / `'expand'` strings.

### G1–G5 done (`r106` at `ed0695a`)
- The lead checked the three shots that changed (NB-put-in-space, NB-reminder-slip, NB-remind-menu) and **accepted** them, along with all of r106's shots. pgTAP has 20 checks in file 50. Next: update the goldens, merge, push migration 50 live with the founder's yes, build.

### Live (29 Oct, 10:21)
- Merged into `slice2-app` (11e99eb). Migration 50 is live (the lead confirmed it on the live list). Build 744 is installed on the founder's phone over 729, with his data kept.

## T4. On hold, the status icons are the actions (founder, 10:35; approved 10:38)
- **Frames:** NS5 EN `2694:38925`, AR `2694:39077`.

**Holding one entry**
- It is selected, and **its status row shows all five icons:** Pin · Reminder · Feed · Space · Message.
  - **Used ones** are filled, as now.
  - **Unused ones** are outlined: a card fill with a line ring.
  - A quiet "Tap to do it" («اضغط للتنفيذ») sits at the start of the row.
- **Tapping an icon does the action straight away:**
  - Pin pins or unpins;
  - Reminder opens the time picker;
  - Feed, Space and Message open their existing share steps (the preview, and For / Team for a Space).
  - Tapping a used one does it again (share again, change the reminder, unpin).
  - When the action is done, the selection ends and the icon shows as a status.
- **The bottom bar becomes Move to… · Duplicate · Delete.** Share and its sub-menu are gone, because they moved to the icons.

**Holding two or more entries:** no icon rows. The bar offers **Pin** · Move to… · Duplicate · Delete. Sharing many entries at once isn't offered.

**Outside hold, nothing changes:** tapping an icon opens its detail card (T1).

**Screen readers:**
- an unused icon is announced as an action ("Share to a Space");
- a used one gives its status and the action ("Shared to Kuwait City Tower at 08:45. Share again").

## T5. Changed since shared (founder, 10:35; approved 10:38)
- **Frames:** NS6 EN `2694:39006`, AR `2694:39158`.

**Shared copies never change by themselves.** A feed post, a Space post or a message keeps the version that was sent.

**What counts as a change:** adding, editing or removing text, lines, photos or files in the entry, or its title.
- Ticking a to-do, pinning, folding and moving it to another page don't count.

**The dot**
- A share icon whose last share is older than the entry's last change gets a small accent dot (9 px, with a ring) at its top end.
- The dot goes when that kind is shared again.
- Each kind keeps its own dot.

**The detail card (the log)**
- It lists every share of that kind. A share older than the entry's last change says "Older version · changed at {time}" («نسخة أقدم · تغيّرت {time}»).
- **Share again** («شارك مجددًا») sends the current version through the same step. The old share stays in the log.

**The server**
- Each share needs to know the version it sent. `note_shares` may already store it; if not, this needs **one migration** (a `note_version` column on the share, filled when sharing) and a pgTAP test.
- The entry's content version already moves on edits. Make sure ticks and pins don't move it, or compare a content-only version.
- **Cursor checks this first and reports** before writing a migration.

**No full edit history in the MVP:** the log records shares and sends only.

## The lead's check of `claude/r106b` (29 Oct, at `bd911bd`)
- **Runs:** SQL stand-in 3,079 checks (21 new in file 51), 0 failing. The session reported analyze clean and 2,686 tests passing.
- **Two reviewers** (spec, standards): no hard violations. T4 is as specified.
- **T5 has one design flaw:** the phone and the server each decide "changed since" by their own rule and their own clock. They already disagree on title spaces, photo order, new entries and deleted lines. A dot that is right on one screen and wrong on another can't ship.

### Accepted
- Using a content fingerprint (`content_key`) instead of `notes.version`, because ticks and reminders move the version.
- The deferred triggers, and `set constraints all immediate` in test 47.
- A voice note shows four icons, because voice notes can't take reminders anywhere in the app.
- With no signal, a share icon says so and sends nothing.

### Fixes before the shots (migration 51 isn't live, so edit file 51 itself)
- **K1. One truth, on the server.**
  - `note_shares` gets `content_key`, filled at share time from the entry's key.
  - **A share is older when its `content_key` differs from the entry's `content_key`.** No clocks are compared. An entry edited and then put back to the shared text reads as the same again.
  - `content_changed_at` stays, only for the words "changed at {time}".
  - **Remove the phone's own rule** (`_contentChanged` and the phone stamp). The phone reads `content_key` from the server.
  - After a save or a share, refresh that entry, so the dot appears or goes within the refresh.
  - pgTAP covers: a share right after an edit is not older; an edit after a share is older; editing back to the shared text is not older.
- **K2. The key is unambiguous.** Coalesce every field inside `concat_ws` so a missing field can't shift the others. Add a header comment to migration 51: "a later migration that writes notes or note_files and then alters notes must `set constraints all immediate` first".
- **K3. The selection ends only when the action is done.** Cancelling the time picker, closing the share card, no signal or an error all keep the entry held.
- **K4. Share again** is at the end of every share card, not only on older ones.
- **K5. "changed at {time}"** shows the day when it isn't today (Today / Yesterday / the short date, as `reminderWhen`).
- **K6.** Check whether a voice recording counts as content (`note_files` or elsewhere) and say which. It should count.

Then run test_screens WITHOUT updating and put the old/new pairs in `docs/reviews/shots-106b/` (this session is on the PC). Expected: BH2, BH3, BH4 (now the held entry's icons), BH5, NB-put-in-space, and any shot where a share is older than its entry.

### K1–K6 done (`claude/r106b` at `80e8994`)
- **Accepted.** One truth on the server: `note_shares.content_key` is set at share time, and "older" means the keys differ. The phone has no rule of its own. Selection ends only when the action is done; Share again on every card; the day in "changed at"; a voice recording counts. SQL stand-in 3,088 (30 checks in file 51).
- **Shots** (drawn in the cloud, old and new side by side): BH2, BH4, BH5, NB-put-in-space and NS1 are accepted.
- **Still wanted:** a shot of the dot and its "Older version · changed at …" card (NS6), EN and AR. It is added when the goldens are made on the PC.
- **Next:** the PC makes the goldens and merges, together with 105B. Migrations 51 and 52 are pushed one at a time, then one build.
