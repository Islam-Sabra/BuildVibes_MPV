# Review 92: F107, the notebook writes like Notion — categories and additions — 25 Oct 2026

**Founder, 25 Oct (testing F106, build 585):**
- "the notebook has many bugs";
- what he wants:
  - **categories** (what you write) open from a button as a **pop-up grid, like Notion**;
  - **additions** (what you attach: location, file, image…) sit **on the bar above the keyboard**;
- location: **typed and GPS, both**;
- bugs: "let Claude detect them".

## The frames (Figma `IcoK4u8JFO6K8l4YYiHNkm`, "PROTOTYPE · Full app v1 · EN")
| | EN | AR |
|---|---|---|
| NBX1 · the + for categories and the additions above the keyboard | `2619:36719` | `2619:37201` |
| NBX2 · categories: a grid, like Notion | `2619:36808` | `2619:37290` |
| NBX3 · a to-do list with a location, photos and a file | `2619:36951` | `2619:37433` |
| NBX4 · location: type it, add the GPS, or both | `2619:37076` | `2619:37558` |

EN is at y 50400, AR at y 51400, x 24000 onwards. NBW1–5 (F106) stay as the slip and draft reference.

## What changes from F106
1. **A note becomes a page of blocks, like a Work post's page.**
   - Reuse Work's page editor (`daybook_page_editor.dart`: blocks, drag ⋮⋮, `/`, Turn into, table, toggle). Don't write a second editor.
   - The slip, Now, Draft, Send and Back-keeps-a-draft from F106 stay as they are.
   - **The kind chip "Note ▾" and its menu go.**
2. **Categories, the `+` at the start of the bar** (accent, soft):
   - it opens a **sheet in place of the keyboard** with a **3-column grid of 12 tiles**: Text, Heading, Subheading, To-do list, Bulleted list, Numbered list, Toggle, Table, Callout, Quote, Divider, Voice note;
   - the current block's type is outlined;
   - a tap inserts that block at the cursor, or turns an empty line into it, and the keyboard comes back;
   - **"or type /"** in the corner: `/` opens the same list as now;
   - Arabic: «الأنواع», and the tiles read right to left.
3. **Additions, on the bar after a thin divider:**
   - **Location · Image · File · Date · Remind me · Voice**, then Send;
   - an addition in use is tinted (soft accent background, accent icon);
   - they attach to the **note**, not to a block, and show at the slip's end as in NBX3:
     - a location chip, photo thumbnails, a file row (PDF icon, name, size, ✕) and a date chip;
     - a reminder shows as a grey line on the saved slip, as now;
   - **Image:** camera or gallery, cleaned like every photo (F60);
   - **File:** PDF from the phone, up to the Library's size limit;
   - **Voice:** records a voice block inside the note (it no longer makes a separate voice note).
4. **Location, both (NBX4):** a sheet with
   - a typed field ("Level 3, grid C7");
   - "Add my GPS position": it asks the phone's permission the first time, and shows lat, long and ±accuracy, removable;
   - **Done**;
   - the chip reads "Level 3, grid C7 · GPS ±8 m";
   - GPS only is fine, and typed only is fine;
   - the position is **private to the note**, and **never** goes into a Space unless the person puts the note there. Putting it in a Space carries only the typed text, not the GPS, unless they tick "Include my GPS position".
5. **The saved slip in the list** shows:
   - the title, then the first 3 lines of blocks;
   - then the chips: location, date, and the count of photos and files as icons (no numbers needed beyond "2 photos");
   - a tap opens it for editing in place.

## Server (migration 44, dated after `20261104120000`, not live)
- **`notes.blocks jsonb`:**
  - the same block format as a Work post's page;
  - checked with a validator: at most 200 blocks, text ≤ 5,000 characters;
  - `body` and `points` are kept for old notes, and the app reads either;
  - new notes write `blocks`, with `kind` set to `text`.
  - **Old notes migrate on read, not in SQL:** opening an old note shows it as blocks, and saving writes blocks.
- **Location columns:** `location_text text` (≤ 120), `location_lat` and `location_lng` (numeric, valid ranges), and `location_accuracy_m` (positive).
- **`note_files.kind` gains `'file'`** (PDF, up to the Library's limit), at most 10 files per note, in the same private bucket.
- **RLS as now:** only the owner. Tests:
  - the owner writes and reads blocks, location and a file;
  - another person can't read any of them;
  - the validator refuses a bad block list;
  - "Put in a Space" sends the typed location but not the GPS, unless asked.

## The bugs: Claude Code finds them first
**Before building F107:** on `claude/f106` (build 585), drive the notebook on the emulator through every path: write, switch kind, checklist Enter and Backspace, to-do with date and remind, photo, voice, Back to draft, reopen a draft, edit a saved note, delete, pin, Put in a Space, Arabic, no signal.

List every bug with its steps and the expected result in `docs/reviews/f106-bugs.md`. Mark each one:
- **"gone with F107"** (part of the writing UI being replaced);
- or **"fix anyway"** (drafts, saving, reminders, data, list display).

Fix the "fix anyway" ones inside F107's branch.

## Checks
- Analyze, the tests and the SQL stand-in.
- **Widget tests, in EN and AR:**
  - + opens the grid, and each tile inserts its block;
  - the current type is outlined;
  - `/` still works;
  - each addition attaches, shows its chip, and ✕ removes it;
  - location typed only, GPS only, and both;
  - the draft keeps blocks and additions;
  - old notes open as blocks.
- **Screenshots** of NBX1–NBX4 in EN and AR at 390×844, compared with the frames.
