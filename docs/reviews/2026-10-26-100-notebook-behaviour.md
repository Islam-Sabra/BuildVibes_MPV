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

**Status:** draft, waiting for the founder's look at frames BH1–BH10 (drawn 26 Oct). Bugs B1–B5 are with Cursor on `claude/r100-bugs`; nothing in Parts 3–8 is built until he says yes.

**Decisions taken (founder, 26 Oct):**
- long-press = select, with Share · Move · Duplicate · Delete;
- ⋯ = the entry's own settings, Pin and Reminder;
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

## Part 1: what each touch does (one rule for the whole notebook)

| Touch | On an entry card | On a page row | While writing, on a line's marker or ⋮⋮ |
|---|---|---|---|
| **Tap** | Opens it to edit, with the cursor where you tapped (or at the end) | Opens the page | Puts the cursor there |
| **Long-press** (500 ms, with a light haptic) | Selects it (Part 3) | Selects it (pages' bar) | Opens the line menu (review 98) |
| **⋯** | The entry's settings card (Part 4) | The page's settings card: Rename, Icon, Pin | — |

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
  - Its ⋯ has one row: Discard, with Undo.
- **Test:** open a saved entry, change it, go Back. The page has one card, with the new words. Then Undo gives back the old words.

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

## Part 4: the compact menu card (one design everywhere)

Used for:
- an entry's ⋯;
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
- **The entry's ⋯ card:**
  - the header (title, page · time);
  - Pin / Unpin;
  - Reminder, showing its time when set, which opens the Remind me sheet.
  - More rows can come later, as the founder said.
- **The page's ⋯ card:** Rename, Icon ›, Pin / Unpin.

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

Share opens on one selected entry, or on a line from the line menu (the line with the lines under it). The card turns into its three choices:

```
‹ Share
📣 Feed       a public post on Home
👷 Space      a post, work item or checklist in a Space
💬 Message    to one person
```

- **Every choice shows a preview first,** exactly as the other side will see it, with Post / Send and Cancel. Nothing leaves in one tap.
  - The GPS position never goes unless "Include my GPS position" is ticked on the preview.
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
  - **Show** is one single choice (rule 6): All entries · To-dos open · Photos · Files · Voice notes · Dates · Places;
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
  - Dates come from a due date or a date block.
  - Places come from the location.
  - This goes in the 99B migration, with tests in EN and AR, and a test for someone else's pages.

## Part 9: what this changes in review 99B
- **B1 is replaced** by Parts 3, 4 and 6. Edit isn't a menu row: tapping an entry edits it.
- **B2** keeps the preview rules, with Message added.
- **B3 Deleted items** is unchanged. The Deleted items button comes back with 99B.

## Bugs are fixed first, test-first
- B1–B5 are bugs on build 640. Each gets a failing test first (`superpowers:systematic-debugging`, then `test-driven-development`), then the fix.
- They ship before the redesign, so the founder's next build is usable while the frames are reviewed.
- **B5 is ⋯:** it opens at once and only ever opens one menu (Part 1).

## Figma frames
On "PROTOTYPE · Full app v1 · EN", at 390×844, named "… · R100 · PROPOSAL". The EN row is at y 58400 and the AR row at y 59400.

| Frame | EN | AR |
|---|---|---|
| BH1 · Pages list: round New entry, "7 entries · today" | `2638:37859` | `2638:37957` |
| BH2 · An entry selected: ✕ · 1 selected on top; Share · Move · Duplicate · Delete at the bottom | `2639:37911` | `2639:38261` |
| BH3 · An entry's ⋯ card: header, Pin, Reminder | `2639:38016` | `2639:38366` |
| BH4 · Share › Feed · Space · Message (same card, no stacking) | `2639:38132` | `2639:38482` |
| BH5 · Share → Message: preview, GPS off, Cancel / Send | `2642:38161` | `2642:38410` |
| BH6 · The bar: + · Photo · Add · Voice · Send | `2640:38023` | `2640:38551` |
| BH7 · 📎 Add: File, Location (set), Date, Reminder (set) | `2640:38122` | `2640:38650` |
| BH8 · `+` opens the block list (same card as `/`), scrolls inside | `2640:38248` | `2640:38776` |
| BH9 · Filter card from the top bar: Show (one choice) · In (page) | `2647:38235` | `2647:38391` |
| BH11 · Filtered list: "To-dos open ✕" · "All pages ▾", results by page | `2642:38280` | `2642:38529` |
| BH10 · The line menu opens above the line (no room below), never under the keyboard | `2640:38416` | `2640:38944` |

**Notes for the build:**
- **Shortcuts stay left to right.** The shortcuts at the end of the block list's rows (`#`, `[]`, `>`, `---`) are always laid out left to right, also in Arabic. Without that, `>` shows mirrored as `<`.
- **The pages keep the DS icons.** The design system has no hard hat icon, so BH1 keeps the crane for Site A, as the app's own 12-icon set does.
- **No mockup for hold-to-record.** The 🎤 hold-to-record follows WhatsApp, as Part 5 describes; its states aren't drawn.
