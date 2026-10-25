# Review 97: trial of AppFlowy's editor package for the notebook — 25 Oct 2026

**Founder's yes (25 Oct):** try the `appflowy_editor` package under its **MPL 2.0** licence. This is a **trial on its own branch**: nothing merges, nothing goes live, nothing is installed. The result is a pass/fail report and a recommendation.

**Why:** the notebook should write like Notion and AppFlowy. See the reference doc "Notion and AppFlowy: how they organise work" (claude.ai artifact, 25 Oct). AppFlowy's editor is used by many people and already does most of what we need. The question is whether it fits *our* rules (Arabic, tokens, our bar, our data) at a lower cost than improving our own editor.

## Rules for the trial
- **Branch:** `claude/editor-trial` from `origin/slice2-app`. A cloud session pushes only there.
- **Licence:**
  - add `appflowy_editor` from pub.dev at an **exact version** (6.1.0 or the latest stable), used under **MPL 2.0**;
  - list it in `assets/licences/` (or the existing third-party notice) with its licence text;
  - **don't edit the package's own files.** If a change inside the package is unavoidable, stop and report it: under MPL a changed file must be published.
- **Never copy code from the AppFlowy app** (`github.com/AppFlowy-IO/AppFlowy`, or `D:\Projects\AppFlowy`). It is AGPL. Read its behaviour, not its code. Only the package may be used.
- **Behind a dev route only:** one screen, "Editor trial", reachable only from a debug-only entry. Production navigation doesn't change, and the current notebook stays as it is.
- **No database change and no new migration.** The trial reads and writes the existing `notes.blocks` format (migrations 44 and 45) through a converter.

## The checklist
Mark each line **pass**, **fail** or **partly**, with a test or a screenshot. Lines marked **(PC)** need the emulator or a phone: a cloud session marks them "PC later".

| # | Check | Pass means |
|---|---|---|
| 1 | Builds | `flutter analyze` is clean and the app builds for Android on our Flutter version. Note the release APK's size change. |
| 2 | Typed shortcuts | `1.` `-` `[]` `#` `>` at the start of a line become our kinds. A shortcut can be turned off or remapped. |
| 3 | `/` menu | Shows **our** kinds only, with **our** EN/AR names from ARB files and the shortcut beside each. Grouped as on AppFlowy phones. It filters as you type, in Arabic too. |
| 4 | Arabic | Right-to-left lines and list markers on the right. Mixed Arabic, Latin and digits keep the right order. Numbers show Western digits; letters a. b. c. stay Latin (review 93). Indent moves toward the left. |
| 5 | Children | Children live inside their parent: indent, outdent, fold, Move up and Move down carry them. Numbering goes 1. → a. → i. and restarts or continues as review 93 says. |
| 6 | Our bar | Their phone toolbar can be replaced by ours: +, Indent and Outdent on list lines, the additions (location, image, file, date, voice) and Save. Nothing of their look remains. |
| 7 | Line menu | Long-press on a line can open **our** menu: Turn into, Move up, Move down, Indent, Outdent, Duplicate, Delete. With the keyboard open, the long-press still works. **(PC)** for feel |
| 8 | `+` vs Turn into | `+` inserts a new line below and opens the menu there; Turn into changes the current line. |
| 9 | Our blocks | Voice note, photo, file (PDF), location chip and date/reminder chip work as custom blocks in the editor, drawn with our widgets. |
| 10 | Our data | A converter turns `notes.blocks` (every kind, with `indent`, `start` and `folded`) into the editor's document and back with **nothing lost**. Round-trip tests run on every sample note, EN and AR. |
| 11 | Tokens | Colours, sizes and spacing come from `bv_tokens` and `BvType` only (two-size rule, Almarai for Arabic). No raw colours in our code. |
| 12 | Undo | Undo and redo work for typing, Turn into, indent and moves. |
| 13 | Speed | A 200-block note scrolls and types without visible lag on the emulator. **(PC)** |
| 14 | Screen reader | TalkBack reads each line with its kind ("To-do, not done, Cover at the edges"). **(PC)** |
| 15 | Tests | Widget tests drive the editor (type, shortcut, `/`, indent) under `flutter test`. |

## The report
Write `docs/reviews/editor-trial-report.md` with:
- the table above, filled in;
- what had to be worked around, and anything that would need a change inside the package;
- **the size of adopting it:** what moves out of `note_page_editor.dart` and `daybook_page_editor.dart`, and what stays;
- **a recommendation:** adopt it for the notebook (and later post pages), or keep our editor and add the same rules ourselves.

Then stop. The lead reviews the report and the founder decides. If it fails, the branch is deleted and nothing is lost.
