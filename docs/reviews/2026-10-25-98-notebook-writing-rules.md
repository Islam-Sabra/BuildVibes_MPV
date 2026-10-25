# Review 98: the notebook writes like Notion and AppFlowy — rules, our own editor — 25 Oct 2026

**Founder (25 Oct):** keep our own editor and build the proven behaviour into it ("B"). The reference is the doc "Notion and AppFlowy: how they organise work" (claude.ai artifact, 25 Oct), from hands-on tests of both apps and AppFlowy's code. Nothing is copied from either app; only their behaviour is followed. The AppFlowy editor trial (review 97) failed to compile; its branch `claude/editor-trial` is kept for later.

**Status:** the rules below are for the founder's approval. The Figma frames for the two new pieces (the line menu and the hints in the menus) follow his yes, then the build.

**No database change.** Everything fits the `notes.blocks` format of migrations 44 and 45.

## Where this applies
- The notebook's page editor (`note_page_editor.dart`).
- A Space post's page (`daybook_page_editor.dart`), wherever the code is shared (`PageBlockEditing`). Both should behave the same.

## The rules

### 1. Typed shortcuts (new)
At the **start of a text line**, typing these and then a space turns the line into that kind. The typed characters disappear.

| Type | Becomes |
|---|---|
| `1.` or `1)` | Numbered list (Arabic-Indic `١.` too; it still shows Western digits) |
| `-` or `*` | Bulleted list |
| `[]` or `[ ]` | To-do |
| `#` / `##` | Heading / Subheading |
| `>` | Toggle (fold) — as in Notion and AppFlowy |
| `"` | Quote — as in Notion and AppFlowy |
| `---` | Divider, then a new text line after it |

- Only at the start of a **text** line. In a to-do, `1. ` stays as written.
- **Undo right after** gives back the typed characters as text, as Notion does.
- A light click (haptic) when a line changes kind.

### 2. The `/` menu
- `/` opens it **at the start of any line, or after a space**. Today it opens only on an empty line.
- **Typing filters it.** It matches the EN or AR name and simple keywords: "num", "todo", "مهام". Enter picks the first match; Escape, or a space with no match, closes it and leaves the `/` as typed.
- **It opens next to the line** as a small card, not a sheet, so the line stays in sight.
- **Each kind shows its shortcut** at the end of its row in small grey type (`1.`, `-`, `[]`, `#`, `>`, `"`, `---`). People learn the shortcuts from it.

### 3. The categories grid (`+` on the bar)
- It stays as built (NBX2), with each tile's shortcut under its name in small grey type.
- **`+` adds a new line below** the current one and its children, at its level, and opens the grid for that new line. On an empty text line, the grid turns that line instead.
- **Turn into** (in the line menu) changes the current line and never adds one.

### 4. The bar follows the line
- **⇥ ⇤ show only when they can act:** ⇥ when the line can go one level deeper, ⇤ when it can come out one. Otherwise they are hidden, not greyed.
- The additions (location, image, file, date, voice) and Save stay where they are.

### 5. The line menu (replaces the ⋮⋮ drag on phones)
- **Open it:**
  - tap ⋮⋮ on the line being written, as today;
  - or press and hold that line's marker (its number, bullet or to-do box).
  - Pressing and holding the **words** keeps selecting text, as in every phone app.
- **It opens next to the line,** as a small card from `BvPopoverMenu`, not a bottom sheet. Its rows:
  1. Turn into ›
  2. Move up
  3. Move down
  4. Indent
  5. Outdent
  6. Duplicate
  7. Continue numbering / Restart at 1 (numbered lines only, as today)
  8. Delete (in the destructive colour)
- **Rows that can't act are hidden:** no Move up on the first line, no Indent when it can't go deeper.
- **No dragging lines on phones.** Drag with ⋮⋮ is removed on phones (AppFlowy does the same; it is the riskiest gesture). Move up and Move down replace it.

### 6. A line carries its children (as review 93, now for every action)
- **Move up / Move down** jump over the whole neighbouring group, and the line's own children go with it.
- **Duplicate** copies the line with its children, right after them.
- **Turn into, Indent, Outdent, fold and Delete** keep the rules of review 93.

### 7. One undo for the line's actions
- Turn into, Move up, Move down, Indent, Outdent, Duplicate, Delete and a typed shortcut each show the existing Undo bar for 5 seconds ("Moved · Undo", «نُقل · تراجع»).
- Undo puts the whole note back as it was, children included.
- Typing itself is undone by the keyboard, as today.

### 8. Motion (only where it helps; nothing on typing)
- The line menu and the `/` card open in 150 ms, from the line.
- Move up and Move down slide the line and its group to the new place in 180 ms.
- A fold slides its children closed in 180 ms, and the arrow turns.
- Typing, Enter and Backspace have no animation.
- Reduce motion: nothing moves.

## Tests (EN and AR)
- Each shortcut in the table turns a text line, and undo gives the characters back. Shortcuts don't fire inside other kinds or mid-line. `١.` works.
- The `/` menu:
  - opens after a space;
  - filters by EN, AR and keywords;
  - Enter picks the first match;
  - Escape leaves the `/`.
- `+` adds a line below, but turns an empty line.
- ⇥ ⇤ hide when they can't act.
- The line menu:
  - opens from ⋮⋮ and from holding the marker;
  - holding the words selects text;
  - rows that can't act are hidden.
- Move up and Move down carry children and jump over a whole group. Duplicate copies children.
- Undo after each line action restores the note exactly.
- No drag on ⋮⋮ on a phone.
- Reduce motion.

**Screenshots (390×844, EN and AR):**
- NBY1: the `/` card filtered to "num";
- NBY2: the line menu on a numbered line with children;
- NBY3: the bar on a list line, with ⇥ ⇤;
- NBY4: the bar on a heading line, with no ⇥ ⇤;
- NBY5: Moved · Undo.

## Founder, 25 Oct 22:32: nothing left out — four steps
The founder wants everything in: dates and reminders inside the text, dragging on phones, pages inside pages, databases and colours. They come in four steps, each with its own rules, Figma frames and the founder's yes, so the pilot (1 Feb 2027) is never blocked by the bigger ones.

| Step | Review | What | Database change |
|---|---|---|---|
| 1 | 98 (this one) | The rules above | None |
| 2 | 99 | **Dates and reminders as chips inside a line** (`@` menu: Today, Tomorrow, a date, Remind me), each chip tapped to change; **dragging lines on phones** the Notion way (hold the marker with the keyboard closed, the line lifts, a drop line shows its landing place and indent, the group it joins is shaded, a click at each slot) | Yes: a date chip inside a text run, and reminders per chip (one migration) |
| 3 | 100 | **Pages inside pages:** a line can be a sub-page of the note ("Pour checklist ›"), opened in place, with a back path, any depth. The notebook list shows top pages only | Yes: a parent link between notes (one migration) |
| 4 | 101 | **Databases and colours:** a simple table can be turned into a small database (a few field types: text, number, date, person, select, checkbox), shown as a grid or a board; text and background colours from a fixed palette in the tokens (no free colour picker) | Yes (one migration) |

Rules that still hold in every step:
- **Personal notebook only.** Work in a Space stays as work items: they already are the Space's database (rule 8).
- **No unnecessary settings:** a database starts from a table and offers few field types, never a settings page.
- **Colours** come from tokens, with a fixed short palette, the same in EN and AR.
- **Arabic, one-minute rule, Western digits, no hard-coded strings,** as always.
