# Review 100: the notebook's behaviour, from the founder's test of build 640 — 26 Oct 2026

**Founder (26 Oct, 14:46–15:00), testing build 640:**
- the keyboard drops between lines;
- a saved entry shows twice after Back;
- the ⋮⋮ menu goes under the keyboard;
- "Write in this page" opens an old draft;
- ⋯ is slow and opens two menus;
- the big "New entry" button confuses;
- the page rows say nothing useful;
- he wants a filter;
- the menus, the `+` grid and the bar look generic;
- long-press and ⋯ repeat each other.

His rule for this review: **behaviour first, then Figma, then the build.**

**Status:** draft, waiting for the founder's look at frames BH1–BH12 (drawn 26 Oct). Bugs B1–B5 are with Cursor on `claude/r100-bugs`; nothing in Parts 3–8 is built until he says yes.

**Decisions taken (founder, 26 Oct):**
- long-press = select, with Share · Move · Duplicate · Delete;
- **swipe** an entry (founder, 26 Oct 16:37–16:38): toward the end it shows Pin · Reminder, toward the start it shows Archive (new). There is no ⋯ on entries;
- **Archive** is approved: an entry is kept but leaves the page's list;
- **back by swipe** everywhere (B6);
- tap = edit;
- Share = Feed · Space · **Message** (Message approved 14:59);
- compact menu cards, not tall rows;
- New entry is a small button.

**References** (behaviour followed, no code copied):

| Behaviour | Reference |
|---|---|
| Long-press selects, with a top action bar; tap adds to the selection | WhatsApp chats and messages; Google Photos; Gmail |
| A compact card next to what was pressed: quick icons on top, rows under, Delete last in red | iPhone context menus; Notion mobile's block menu |
| One 📎 for every attachment; hold the mic to record | WhatsApp composer |
| About five buttons above the keyboard, the rest behind one | Apple Notes |
| `+` and `/` open the same compact block list, with shortcuts shown | Notion |
| Leaving a saved page saves it: no Save button, no copy | Notion, Apple Notes, AppFlowy |
| The keyboard stays up while moving between lines | Every notes app |

---

## Part 0: one product language (founder, 26 Oct 16:45: "maintain the product language and relations")
Each gesture means one thing, on everything it can act on.

| Gesture | Means | Entry | Line (while writing) | Page |
|---|---|---|---|---|
| **Tap** | open or edit | edit it | put the cursor | open it |
| **Hold** | select, then act from one bar | bottom bar: **Share · Move · Duplicate · Delete** | **the line's start** (its number, bullet, box, or the empty start strip on a plain line): the keyboard goes down on purpose, and the same bottom bar shows **Share · Move · Duplicate · Delete** | bottom bar: Merge · Move · Pin · Delete |
| **Swipe** | quick personal marks | Pin · Reminder / Archive | — | — |
| **⋮⋮** | the line's structure | — | Turn into ›, Move up, Move down, Indent, Outdent | — |
| **⋯** | this screen's own settings | — | — | in a page's top bar: Rename, Icon ›; the notebook has none |

- **Lines: the start versus the words** (founder, 26 Oct 16:55–16:58):
  - **Holding the words** opens the phone's own text menu (Select, Select All, Copy, Paste, Look Up…), unchanged. Nothing is added to it or removed from it.
  - **Holding a line's start** selects the line with its children. The start is a strip about a finger wide: the marker, or, on a plain line or heading, an empty strip that shows a faint dot under the finger.
  - **A text selection** dragged across several lines stays a text selection; it never turns into a line selection under the finger.
  - **More lines:** tap other lines' starts to add them. ✕ ends the selection and brings the keyboard back on the line you were writing.
  - **Hold and let go** selects. **Hold and move** will lift the line to drag it, in the drag review later; the rule is fixed now, so the two never clash.
- **No action shows in two places.**
  - Duplicate, Move and Delete live in the selection bars only. Review 98's line menu loses Duplicate, Delete and Move to page….
  - Pin lives in the swipe (entries) or the pages' bar (pages).
- **The same four actions, with the same icons and the same order,** appear wherever one or more things are selected: Share · Move · Duplicate · Delete, Delete last in red.
- **Discard:**
  - **While writing a new entry** that was never sent, the top bar's end reads **Discard** («تجاهل», in red), and tapping it shows "Discarded · Undo" for 5 s.
  - **While editing a saved entry,** there is no Discard: Back saves, and "Saved · Undo" gives the old version back (B2).
  - **A draft's card** on the page swipes to Discard (Part 3b).
- **Not in the app:** a bottom sheet of tall rows, or an action hidden behind two menus.

## Part 1: what each touch does (one rule for the whole notebook)

| Touch | On an entry card | On a page row | While writing, on a line's marker or ⋮⋮ |
|---|---|---|---|
| **Tap** | Opens it to edit, with the cursor where you tapped (or at the end) | Opens the page | Puts the cursor there |
| **Long-press** (500 ms, with a light haptic) | Selects it (Part 3) | Selects it (pages' bar) | **On the marker:** selects the line with its children, and the bar above the keyboard becomes Share · Move · Duplicate · Delete (BH12) |
| **⋮⋮** (tap) | — | — | The line's structure card: Turn into ›, Move up, Move down, Indent, Outdent (BH10) |
| **Swipe** | Toward the end: Pin · Reminder. Toward the start: Archive (Part 3b) | — | — |
| **⋯** | — (no ⋯ on entries) | The page's settings card: Rename, Icon, Pin | — |

- **⋯ never waits.** It is its own button, outside the card's long-press, so a tap opens it at once (B5).
- **One menu at a time.** While a menu is open:
  - taps on the screen behind it only close it;
  - a second tap on ⋯ closes the menu;
  - nothing opens a second menu behind the first.
- **Back** closes the open menu first. Then it leaves selection mode. Then it leaves the screen.

## Part 2: writing (bugs B1–B4)

**B1. The keyboard never drops while writing.**
- **What happens today:** Enter, Backspace on an empty line, or a tap on another line puts the cursor on the other line. The app takes focus off the old line first, so for one moment nothing has focus and Android hides the keyboard.
- **The rule:** the next line takes the cursor **in the same frame**. The keyboard stays up for the whole edit.
- **It hides only when the user:**
  - taps the keyboard's hide key;
  - drags the page down;
  - sends;
  - or leaves the entry.
- This covers to-dos, lists, headings and text alike.
- **Test:** on Enter in a to-do, the editor's focus never goes to null, and the line after it has focus in the same pump.

**B2. A saved entry is edited in place, never copied.**
- **Today,** tapping a saved entry and going Back leaves the original and a draft copy.
- **The rule:**
  - **Opening a saved entry** edits that entry; nothing is copied.
  - **While you edit,** the phone keeps your changes every few seconds, so a closed app loses nothing.
  - **Back or Done:**
    - with changes, the entry is saved in place and the Undo bar shows "Saved · Undo" for 5 s. Undo puts the entry back as it was before you opened it;
    - with no changes, nothing is saved and nothing is shown.
- **Drafts are only for a new entry that was never sent.**
  - A draft shows as its own card at the top of its page, marked "Draft", and a tap continues it.
  - Swiping it toward the start shows Discard, with Undo, in place of Archive.
- **Test:** open a saved entry, change it, go Back. The page has one card, with the new words. Then Undo gives back the old words.

**B6. Back by swipe, everywhere (founder, 26 Oct 16:38).**
- **Android:** the system back gesture (swipe in from either edge) does exactly what the ← button does, on every screen.
  - It uses Android's predictive back, so the screen underneath shows as you swipe.
  - It isn't swallowed by the app.
- **iPhone:** swipe from the left edge goes back (the right edge in Arabic), on every pushed screen.
- **What Back does is the same for the button and the gesture:**
  1. close the open menu or card;
  2. leave selection mode;
  3. save and leave an entry (B2);
  4. leave the screen.
- **Where Back asks first:** screens that ask before leaving (an unsent draft with words) use the same question for the gesture.
- **Test:** a widget test sends the system back on each screen with a menu open, while selecting, and while editing, and checks each step above.

**B3. "Write in this page" always starts a new entry.**
- It never opens a draft or the last entry. An unsent draft in that page stays as its Draft card.
- More than one draft can exist, one per new entry started and not sent.

**B4. A menu never goes under the keyboard.** This applies to the line menu, `/`, `+`, 📎 and every compact card:
1. **The visible area** is the screen minus the top bar and the keyboard, with 8 of margin.
2. **Where it opens:** below the line it belongs to, if it fits in that area; otherwise above the line.
3. **If it fits neither way,** the page first scrolls the line up until the menu fits below it.
4. **Longer than the area:** a menu taller than the visible area takes the area's height and scrolls inside.
5. **The keyboard** stays up under the line menu, `/`, `+` and 📎.
- **Test:** with the keyboard up and the line at the bottom of the visible area, the menu's bottom edge is above the keyboard's top.

## Part 3: selecting entries (long-press)

- **Long-press** selects the entry, with a haptic (founder, 26 Oct 16:32: the actions sit at the **bottom**, within thumb reach, the same as the pages selection in PG5):
  - the top bar shows ✕ and "1 selected" only;
  - a bar at the bottom of the screen has the actions:

  ```
  ✕  1 selected
  …
  ┌───────────────────────────────────────────┐
  │   ↗        📁         ⧉          🗑       │
  │  Share    Move    Duplicate    Delete     │
  └───────────────────────────────────────────┘
  ```

  - **Why a bar, and not a menu under the entry:** several entries can be selected; a menu under one entry would cover the next ones to tap and would move on scroll.
- **Adding and removing:** tap other entries to add them, and tap a selected one to remove it.
  - Unselecting the last one, or ✕, or Back, leaves selection mode.
  - Scrolling still works.
  - The "Write in this page" button hides while selecting.
- **Share** shows only when **one** entry is selected (Part 6).
- **Move** opens the page list at once:
  - the current page is marked and can't be chosen;
  - recent pages come first, then search, then + New page;
  - one tap moves every selected entry;
  - then a toast reads "Moved to {page} · Open", and selection mode ends.
- **Duplicate** puts a copy of each selected entry right under it, with the same time, marked "Copy".
  - Its reminders aren't copied, so nobody gets two alarms.
  - The Undo bar shows "Duplicated · Undo".
- **Delete:**
  - Undo shows for 5 s;
  - the change is kept in the phone's outbox, as in review 99 C7;
  - the entries go to Deleted items (99B).
- **Arabic:** both bars mirror. ✕ and the count sit on the right, and the actions run from the right (Share first).
- **Share** opens its card upward, from the bottom bar.
- **Entries have no ⋯** (Part 3b). In selection mode, swiping is off, because the bottom bar holds the actions (BH2, BH4).

## Part 3b: swipe an entry (replaces the entry's ⋯; founder, 26 Oct)
In English, "toward the end" means toward the right, and "toward the start" toward the left. In Arabic both mirror.

| Swipe | Shows | Full swipe |
|---|---|---|
| **Toward the end** | 📌 Pin / Unpin · 🔔 Reminder ("Change reminder" when set), as buttons behind the card | none: tap a button |
| **Toward the start** | 🗄 **Archive** (Unarchive on an archived entry; Discard on a draft) | archives at once, then "Archived · Undo" for 5 s |

- **How it looks** (founder, 26 Oct 16:41: no flat coloured blocks):
  - **The card lifts** as it moves: its shadow grows and it follows the finger.
  - **Under it, round buttons** sit on the page's own background, 48 round, each with its label under it: Pin in ink, Reminder in the warning colour (tokens).
  - **The buttons follow the swipe:** they grow from 60% to 100% size and fade in as the swipe uncovers them, the second one 40 ms after the first.
  - **Archive starts as one round button.** Past the full-swipe point, it stretches into a pill that follows the finger, with a haptic tick.
  - **On release past that point,** the card flies off in 200 ms, the row closes in 180 ms, and "Archived · Undo" shows.
  - **Released before that point,** the pill shrinks back to the round button.
- **Behaviour:**
  - a swipe counts only when it starts on the card, at least 24 from the screen's edge, so the system back gesture keeps the edges (B6);
  - half a swipe (past 25% of the card) opens the buttons, and they stay open until a tap elsewhere or a scroll;
  - only one card is open at a time;
  - a light haptic fires when the buttons open, and again at the full-swipe point;
  - with Reduce motion on, the card moves without the springing animation.
- **Teaching it:** the first time a page with entries opens, its top card slides open by a third, shows Pin · Reminder, and closes after 1 s. This happens once per person, kept on the phone.
- **Screen readers:** TalkBack and VoiceOver offer Pin, Reminder and Archive as custom actions on the card. A test checks this.
- **Off during selection:** swiping does nothing while entries are selected.

### Archive (new, founder's yes, 26 Oct)
- **What an archived entry does:**
  - it leaves the page's list but is kept, unlike Delete;
  - it isn't counted in the page row's "{n} entries";
  - it doesn't show on My calendar;
  - its reminders don't ring.
- **Where it is:** a quiet row "Archived ›" («المؤرشفة») at the end of each page that has any. It opens that page's archived entries, newest first.
- **The Filter** gets "Archived" under Show, for all pages or one.
- **Unarchive** (by swipe, or from the archived list) puts the entry back in its place by its date.
- **Server, in the 99B migration:**
  - `notes.archived_at`, set and cleared only through a function;
  - the owner only;
  - tests for archive, unarchive, the reminder not ringing, and someone else's entry.

## Part 4: the compact menu card (one design everywhere)

Used for:
- a page's ⋯;
- the line menu;
- `/` and `+`;
- 📎;
- Share's three choices.

```
┌──────────────────────────────┐
│ Before the pour, level 3     │  header: what it acts on (small, grey second line)
│ Site A – Tower · 10:40 am    │
├──────────────────────────────┤
│ 📌 Pin                       │  rows
│ 🔔 Reminder         Fri 7:00 │  value at the end, or ›
├──────────────────────────────┤
│ 🗑 Delete                    │  destructive last, in red (when the menu has one)
└──────────────────────────────┘
```

- **Width and rows:**
  - 260 wide (a token, not a number in widgets);
  - rows are **44 high**, the minimum tap size; row text is the main size, and the header is the small size;
  - group labels in small caps grey, where a menu has groups (`/`, `+`).
- **Quick-icon strip:** used when a menu has 3–4 actions used most. Icons are 24, with labels in the small size under them. The selection bar uses the same icons.
- **Look:**
  - surface, radius, shadow and divider all come from tokens;
  - there are no tall padded rows and no full-width bottom sheet.
- **Motion:**
  - opens in 150 ms from the item it belongs to, from 96% to 100% size, fading in;
  - closes in 100 ms;
  - with Reduce motion on, it only fades.
- **A row that leads on** (›) turns the same card into its next level, with a ‹ back row at the top. It never stacks a second card.
- **Rows that can't act are hidden,** as in review 98.
- **The page's ⋯ card:** Rename, Icon ›. Pin is in the pages' selection bar (PG5), so it isn't repeated here.

## Part 5: the bar above the keyboard, and `+`

```
[+]  [📷]  [📎]  (⇥ ⇤ only on a list line that can move)        [🎤]  [➤]
```

| Button | Does |
|---|---|
| **+** | Opens the block list (below). On an empty line it turns that line; otherwise it adds a line below (review 98, rule 3). |
| **📷 Photo** | Camera or gallery, as today's Image. |
| **📎 Add** | A compact card with File · Location · Date · Reminder. Each row shows its value once set ("Gate 2", "Fri 7:00"), with a ✕ at its end to remove it. |
| **🎤 Voice** | **Hold** to record, release to add the voice block to the entry (it doesn't send the entry). Slide toward the start to cancel. A short tap shows "Hold to record". |
| **➤ Send** | As today. Inside a saved entry it reads Done. |

- **When something is attached,** 📷 or 📎 shows a small dot. The chips stay at the end of the entry, as today.
- **The block list:**
  - `+` and `/` open the **same** compact card, so the 12-tile grid (NBX2) is retired;
  - its groups are TEXT (Text, Heading, Subheading, Quote), LISTS (To-do, Numbered, Bulleted, Toggle) and INSERT (Table, Divider);
  - each row has its shortcut in grey at the end, and the current kind has a ✓;
  - typing after `/` filters the list (review 98, rule 2).

## Part 6: Share (replaces review 99 B1's menu)

Share opens on one selected entry, or on one selected line (BH12; the line with the lines under it). The card turns into its three choices:

```
‹ Share
📣 Feed       a public post on Home
👷 Space      a post, work item or checklist in a Space
💬 Message    to one person
```

- **One location, shown once (founder, 26 Oct 16:50):**
  - The entry's location is whatever the user added with 📎 Location: typed words, a map pin, or both. Nothing is captured without the user adding it.
  - **The preview shows it as one line:** "📍 Gate 2 · on the map", where "· on the map" appears only when it includes a pin. A ✕ on that line leaves it out of this share only; the entry keeps it.
  - There is **no separate GPS tick**, and "GPS" is never in the app's words. Remove `notebookIncludeGps` wherever it's used: Put in a Space, Feed, Message.
- **The preview's buttons are words with an icon, not boxes:**
  - "✕ Cancel" in grey at the start, "➤ Send" (or "Post") in the action colour at the end;
  - the arrow flips in Arabic;
  - there's no second ✕ in the header.
- **Every choice shows a preview first,** exactly as the other side will see it, with Post / Send and Cancel. Nothing leaves in one tap.
- **Feed:**
  - the share check "Check it has nothing your client or company wouldn't share.";
  - an optional project tag;
  - the feed rules (report, block, no misleading numbers).
- **Space:**
  - the Space, then post, work item or checklist, then the Team;
  - the Space's rules and passes apply on the server;
  - a work item is only ever created inside a Space (rule 8).
- **Message (new, founder's yes, 26 Oct):**
  - **Choosing the person:** recent conversations first, then search among people you can already message (the existing direct-message rules).
  - **What arrives:** a message with the entry's title, its words as plain text (to-dos as ☐ / ☑ lines), and its photos. It is a copy: the person can't change your entry.
  - **Files and voice** go as the message's attachments, within the existing message limits.
  - **On the server,** one function sends it, reusing direct messages and their rules (block, report, the hidden account). There is a test that it can't reach someone you can't message.
- **The original stays** in its page, with a small mark: "Shared to the feed · 08:45", "Shared to NBKCH Site team · 08:45" (the Space's real name), or "Sent to Ahmed · 08:45".

## Part 7: the pages list

- **New entry** becomes a round button at the bottom end: ✎ with the label "New entry", like "Write in this page".
  - The big orange button at the top goes.
  - "+ New page" stays at the end of the list.
- **Each row:**
  - the icon and title;
  - under it, "{n} entries · {when}" (for example "7 entries · today", «7 تدوينات · اليوم»), where "when" is the date of the latest entry or change, which is also the list's order;
  - **no to-dos count** (founder, 26 Oct 16:27: the number of entries replaces it, it isn't shown beside it). Sub-page rows inside a page follow the same rule.
  - The latest entry's first line goes (founder: it adds nothing).
  - Counts use the Arabic plural rules: 1, 2, 3–10, 11+.
- The founder allowed counting entries: it's the user's own count, not a quality signal, so product rule 3 isn't touched. This reverses review 99's "no count of entries".

## Part 8: a Filter button next to Search and Calendar (founder, 26 Oct)
- **The notebook's top bar** reads Filter · Search · Calendar. **A page's top bar** reads Filter · Search · ⋯.
- **Filter** opens a compact card (Part 4) with two parts:
  - **Show** is one single choice (rule 6): **To-dos open · Photos · Files · Voice notes · Reminders · Archived** (founder, 26 Oct 16:53). "All entries" is gone because the ✕ on the active chip turns the filter off. "Places" is gone because Search finds a typed place;
  - **In** is All pages ›, which opens the page list, so you can pick one page (with its sub-pages).
- **With a filter on:**
  - the list shows the matching entries, grouped by page, newest first;
  - under the top bar, chips show what's on ("To-dos open ✕", "All pages ▾"), and ✕ clears it;
  - the Filter button stays highlighted.
- **Inside a page,** the filter starts with that page chosen.
- **Search** is for words, and it keeps the filter that is on.
- **Server:** `search_notebook` gains a kind and a page.
  - To-dos open come from the unticked to-do lines.
  - Photos, Files and Voice come from the entry's files and blocks.
  - Reminders come from an entry with a reminder still to ring. Dated entries show on My calendar.
  - This goes in the 99B migration, with tests in EN and AR, and a test for someone else's pages.

## Part 9: what this changes in review 99B
- **B1 is replaced** by Parts 3, 4 and 6. Edit isn't a menu row: tapping an entry edits it.
- **B2** keeps the preview rules, with Message added.
- **B3 Deleted items** is unchanged. The Deleted items button comes back with 99B.

## Bugs are fixed first, test-first
- B1–B6 are bugs on build 640 (B6: back by swipe). Each gets a failing test first (`superpowers:systematic-debugging`, then `test-driven-development`), then the fix.
- They ship before the redesign, so the founder's next build is usable while the frames are reviewed.
- **B5 is ⋯:** it opens at once and only ever opens one menu (Part 1).

## Figma frames
On "PROTOTYPE · Full app v1 · EN", at 390×844, named "… · R100 · PROPOSAL". The EN row is at y 58400 and the AR row at y 59400.

| Frame | EN | AR |
|---|---|---|
| BH1 · Pages list: round New entry, "7 entries · today" | `2638:37859` | `2638:37957` |
| BH2 · An entry selected: ✕ · 1 selected on top; Share · Move · Duplicate · Delete at the bottom | `2639:37911` | `2639:38261` |
| BH3 · Swipe an entry: → Pin · Reminder, ← Archive; "Archived ›" at the page's end | `2639:38016` | `2639:38366` |
| BH4 · Share › Feed · Space · Message (same card, no stacking) | `2639:38132` | `2639:38482` |
| BH5 · Share → Message: preview with one removable location line; ✕ Cancel · ➤ Send as words | `2642:38161` | `2642:38410` |
| BH6 · The bar: + · Photo · Add · Voice · Send | `2640:38023` | `2640:38551` |
| BH7 · 📎 Add: File, Location (set), Date, Reminder (set) | `2640:38122` | `2640:38650` |
| BH8 · `+` opens the block list (same card as `/`), scrolls inside | `2640:38248` | `2640:38776` |
| BH9 · Filter card from the top bar: Show (one choice) · In (page) | `2647:38235` | `2647:38391` |
| BH12 · Hold a line's start: the line is selected, the keyboard goes down, ✕ · 1 line selected on top, Share · Move · Duplicate · Delete at the bottom; the start strip on a plain line | `2654:38281` | `2654:38447` |
| BH11 · Filtered list: "To-dos open ✕" · "All pages ▾", results by page | `2642:38280` | `2642:38529` |
| BH10 · Tap ⋮⋮: Turn into · Move up/down · Indent/Outdent only; opens above the line, never under the keyboard | `2640:38416` | `2640:38944` |

**Notes for the build:**
- **Shortcuts stay left to right.** The shortcuts at the end of the block list's rows (`#`, `[]`, `>`, `---`) are always laid out left to right, also in Arabic. Without that, `>` shows mirrored as `<`.
- **The pages keep the DS icons.** The design system has no hard hat icon, so BH1 keeps the crane for Site A, as the app's own 12-icon set does.
- **No mockup for hold-to-record.** The 🎤 hold-to-record follows WhatsApp, as Part 5 describes; its states aren't drawn.

## Lead's check of `claude/r100-bugs` (26 Oct, 17:10)
**Branch:** `claude/r100-bugs` at `aa1ec48`.
**Verdict:** not yet. Fix D1–D13 on the same branch, then stop again.

**What I checked:**
- The diff, read against Part 1 (⋯), Part 2 (B1–B4) and CLAUDE.md. Two separate reviews ran in parallel, one for each.
- The main claims are confirmed in the code.
- There's no database change, so there was no SQL run.

**What holds:**
- Enter keeps the keyboard up.
- Each unsent draft is its own card.
- "Write in this page" starts a new entry.
- ⋯ opens at once, one menu at a time.
- The ARB keys are in both languages.
- The old single draft on the phone isn't lost.

### Fixes
**D1. An edit left open is never saved without the user.**
- **The problem:** `initState` calls `_finishEdit(quiet: true)` with nothing to compare against, so a leftover edit is sent whole. `save_note` keeps the last write, so an older edit can overwrite a newer version.
- **The fix:** when the page opens with a leftover edit of a saved entry, reopen it in the editor, where it was. Nothing is sent until the user goes Back (B2).
- **A note for 99B:** the 99B migration adds a base version to `save_note`. A save based on an older version is then refused, and the user's words come back as a Draft marked "Changed on another phone".

**D2. Never drop the draft before the save is stored.**
- `_finishEdit` must `await` the save, until it is written in the phone's outbox, before `discard()`.
- **Test:** Back while offline, with a delete waiting on its Undo bar. Kill and restart: the edit is still there.

**D3. Emptying a saved entry and going Back is a delete, with Undo.**
- Today the change is dropped without a word.
- **The rule:** it shows "Deleted · Undo" and follows the Delete rules.

**D4. Only a new entry comes back as a Draft when refused.**
- A refused **edit** stays an edit of that entry, with its link kept. The words come back in the editor, with the existing refused message.
- `NoteDraft.back(lost)` must keep `editing`. Otherwise the entry shows twice, which is the bug B2 fixed.
- **Test:** a refused edit leaves one card.

**D5. The keyboard inset is read where it is real.**
- `_roomForMenu` reads `MediaQuery.of(context)` under the Scaffold, where `viewInsets.bottom` is 0.
- Read the insets above the Scaffold (`MediaQuery.viewInsetsOf` on the route's context, or the overlay's), the same as the popover does.
- **Test:** with a Scaffold that removes the inset, the line still scrolls up before the card would have to scroll inside.

**D6. Scroll for the real card, for every card.**
- Step 3 of B4 uses `menuMostRows` for every card. Measure the real height of the card being opened (`/`, `+`, 📎, line menu).
- **Tests:** the above case, and the scroll-first case, not only the bottom edge.

**D7. No Material number for the top bar.**
- `bv_line_popover.dart` uses `kToolbarHeight` (56). Use the BV top bar's height token.

**D8. The keyboard stays up under `+` and 📎 (B4.5).**
- `_toggleCategories()` and Location still call `unfocus()` (`notebook_page_screen.dart` around lines 381–477). Remove those calls, so the card opens over the keyboard's space with the cursor kept.
- **Test:** `+` opens with the keyboard up.

**D9. B1 on every path.**
- These still use `focusBlockLater` after dropping the old field: the typed `---` (a divider, then a new line) and a toggle's new child line. Use `focusBlockNow`.
- **Tests:** both paths.

**D10. ⋯ is its own button.**
- The entry's ⋯ sits inside the card's `InkWell`, so a long-press on ⋯ selects the card.
- Take it out of the card's gesture, as Part 1 says.
- This is temporary, because the redesign removes ⋯ from entries. It still has to be right until then.

**D11. Housekeeping:**
- dispose the removed line's `FocusNode` in `dropField`;
- prune `_draftFocus` and `_draftKeys` when a draft is resumed or discarded;
- put `_menu`'s comment back on its own field;
- remove `notebookDraftFirst` (unused);
- make `notebookSavedEdit` Arabic «تم الحفظ».

**D12. B6, back by swipe (Part 2).** It isn't in the branch:
- add predictive back for Android in the manifest and the page transitions;
- the page screen's `PopScope(canPop: !_writing && !selecting)` turns the iPhone swipe off while writing. It must instead handle the gesture the way ← does, in the order: close the menu, leave the selection, save and leave the entry (B2), then leave the screen;
- tests as Part 2 says.

**D13. The Draft card's ⋯ sheet** (one row, Discard) is accepted as temporary, until the redesign's swipe to Discard (Part 3b). Mark it so in the code.

**Accepted extras:**
- "New entry" on the pages list always starts fresh, as B3 says. Empty drafts are thrown away.

### Then
1. Run analyze, test and `test_screens`, and report the results.
2. Push `claude/r100-bugs` and stop for the lead.
3. With the founder's yes: merge into `slice2-app` and build for his phone. There's no database change.

## Lead's second check of `claude/r100-bugs` (27 Oct)
**Branch:** `claude/r100-bugs` at `b79fc38`.
**Verdict:** approved, after one small fix (E1) and the PC's screenshot run.

**What I checked:**
- The diff since `aa1ec48` (28 files).
- **The router.** Every route is now a `MaterialPage` through `_Screen`. That is sound:
  - go_router's default page ignored the app's `MaterialApp`;
  - with `MaterialPage`, the iPhone gets its native edge swipe on every screen that can pop;
  - `BvBackSwipe` covers the screens that hold Back (writing, selecting, walk, a Space's daybook while writing, the proof camera), through `Navigator.maybePop`. Back's order holds, and the strip sits on the start edge in Arabic.
- **The longer test run** (about 11½ minutes) comes from real transitions now running in the tests. Accepted.
- **D9:** the paths kept the cursor already, so its four tests are guards. Accepted as guards.

### E1. Android shows the screen underneath as you swipe back
- `enableOnBackInvokedCallback` is on, so the gesture reaches the app. But nothing sets the theme's page transitions, so Android doesn't draw the predictive preview that Part 2 asks for.
- **The fix:** set `pageTransitionsTheme` in `bv_theme.dart`:
  - Android: `PredictiveBackPageTransitionsBuilder`;
  - iOS: `CupertinoPageTransitionsBuilder`.
- **Test:** the theme carries both builders.

### Found on the way (queued, not in this branch)
- **A heading picked with `/` inside a toggle isn't drawn.** It's a bug for the redesign build (step 2 of the queue). It gets a test first.
- **The top bar's height:** the frames draw it 48 high, while the app's `AppBar` theme uses 56 (`BvSize.topBar`). The frames win (CLAUDE.md). The lead lists which screens use the themed `AppBar` and decides in the redesign review. Nothing changes in this branch.
- **`photo_privacy` H1** fails only when run as root in the cloud. The PC run is the one that counts.

### Then, on the PC
1. Do E1 (test first) on `claude/r100-bugs`.
2. Run `flutter analyze`, `flutter test`, and `flutter test test_screens` without updating.
   - Any changed shot gets before/after in `docs/screens/r100/before-after/`, one line each on why.
   - Expected changes: shots with a menu card (placed by D5/D6) or the entry's ⋯ (D10).
3. Stop for the lead with the shot list.
4. **With the founder's yes:**
   - merge into `slice2-app`;
   - one release build on his phone, BuildVibes only.
   - There's no database change.

## Lead's third check (27 Oct, 08:15): approved for merge and build
**Branch:** `claude/r100-bugs` at `8c5426b`.

**E1:** done. Flutter 3.44 already used these two transitions by default, so the test is a guard: it stops a later Flutter release from changing them silently. Accepted.

**The six shots** (before/after in `docs/screens/r100/before-after/E1-run_*`):
- **NBY1 (AR), the `/` card:** about 1 px lower, from D5/D6. Accepted.
- **PG4 (AR), each entry's ⋯:** about 1 px, from D10. Accepted.
- **F78 (EN, AR) and NBX2 (EN, AR):** the only change is the text cursor, caught mid-blink now that real transitions run. **Not accepted as is.** A blinking cursor in a golden makes the shot depend on timing.
  - **The fix:** set `EditableText.debugDeterministicCursor = true` in `test_screens`' test config, so the cursor is always drawn the same way.
  - Then shoot those four again, and accept them only if they're stable over two runs.

**Then, with the founder's yes (given, 27 Oct 08:08):**
1. merge into `slice2-app`;
2. one release APK on his phone;
3. a copy of the same APK, named for sharing with a test user, on his PC.
