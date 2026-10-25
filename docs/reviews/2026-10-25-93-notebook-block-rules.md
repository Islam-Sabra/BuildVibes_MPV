# Review 93: how the notebook's categories behave together (lists, nesting, numbering, Turn into) — 25 Oct 2026

**Founder, 25 Oct (on build 605):**
- a numbered list goes 1, 2; then the person makes a callout or a note; then picks numbered list again, and it starts at 1 again;
- they may want **a numbered list with a toggle**, or **a numbered list with a sub-note**;
- "the relation between the categories needs to be well studied; check how similar tools built it."

## How the leading tools do it
- **Notion:**
  - each list line is its own block;
  - Tab and Shift+Tab (on a phone, the toolbar's indent and outdent buttons) make a block the **child** of the one above;
  - lists, to-dos and toggles can hold children;
  - plain headings, dividers and tables can't hold children, but can sit inside a toggle;
  - **moving or turning a parent takes its children with it**;
  - a numbered list counts **consecutive** numbered blocks **at the same level**;
  - anything else at the same level **ends** the list, so the next numbered block starts at 1;
  - **a child never breaks the count;**
  - deeper levels count in letters, then roman numerals.
- **Google Docs and Word** add the manual escape hatch: **"Continue previous numbering"** or **"Restart at 1"** on a list item.
- **Apple Notes and Bear:**
  - the same indent and outdent idea;
  - on a phone, **Return on an empty list line** ends the list or steps out one level;
  - users repeatedly ask for **indent and outdent buttons above the keyboard**, because Tab doesn't exist on a phone keyboard.

**So the founder's case has two answers, and we give both:**
1. **The sub-note belongs inside the item.** Put the callout or note *under* item 2 (indented), and it's a child: item 3 still says 3. This is the normal way, and the one we teach with the buttons below.
2. **When it really is a break,** for example a heading between two parts, the next list starts at 1. But its ⋮⋮ menu offers **"Continue numbering (3)"**, and a list can always **"Restart at 1"**.

## The rules to build
1. **Levels.** Every line has a level from 0 to 3 (four levels; more is unreadable on a phone).
   - **Can hold children:** text, to-do, bulleted, numbered and toggle.
   - **Can't hold children, but can be a child:** heading, subheading, callout, quote, divider, table and voice note.
   - A line can be at most one level deeper than the line above it.
2. **Indent and outdent on the phone.**
   - When the cursor is in a line that can move, the additions bar shows **⇥ Indent** and **⇤ Outdent** right after the ＋, the way Bear, Apple Notes and Notion work.
   - **In Arabic they mirror:** indent moves the line to the left.
   - **Return on an empty list line** steps out one level; at level 0 it turns the line into plain text, which ends the list.
   - **Backspace at the very start of a list line** turns it into plain text, keeping its level. A second Backspace merges it into the line above.
3. **Numbering.**
   - Numbered lines count 1, 2, 3 **while they're consecutive, at the same level, under the same parent**.
   - **Children in between never break the count**, whatever their category.
   - Any other line at the same level breaks it, and the next numbered line starts at 1.
   - Levels count as **1. 2. 3. → a. b. c. → i. ii. iii. → 1. 2. 3.**
   - In Arabic, numbers stay **Western digits** (1. 2. 3.), and letters stay Latin (a. b. c.). That's the app's rule, and the Arabic glossary doesn't change it.
4. **Continue and restart** (the ⋮⋮ menu of a numbered line):
   - **"Continue numbering (N)"** shows only on the first line of a list when an earlier list at the same level and under the same parent exists. N is where it would continue.
   - **"Restart at 1"** shows on any numbered line, and starts a new count from there.
   - Stored as `start` on that line (a whole number from 1 to 999, or none for automatic).
5. **A list item that folds:** "numbered list with a toggle".
   - **Any text, to-do, bulleted or numbered line that has children shows a small fold arrow** before its number or bullet. A tap hides or shows the children, and the count goes on unchanged.
   - So a numbered list can fold like a toggle, with no new category.
   - The **Toggle** category stays as it is: a line whose only job is to fold.
6. **Turn into** (⋮⋮ or the ＋ grid on a line that has words):
   - the words, the level and the children **always stay**;
   - **if the new kind can't hold children** (heading, callout, quote…), the children move out one level and stay right below it, in order. Nothing is ever lost.
   - **Numbered to bulleted to to-do** keeps everything, and to-do lines start unticked; **to-do to anything** drops the tick.
   - **Turning into a numbered line next to another numbered list at the same level joins that count.**
7. **Moving with ⋮⋮** moves the line **with its children**. Dropping it between numbered lines renumbers both lists at once.
8. **Delete:** deleting a line moves its children up one level (they aren't deleted). Deleting a folded line asks first: "Delete this line and the 3 lines under it?"
9. **The ＋ grid** inserts at the cursor's level. Choosing **Numbered list** right under a numbered list at the same level **continues** its count automatically (this is the founder's exact case, now fixed).

## Storage (the same `blocks`)
- Each line gains `level` (0–3) and, for numbered lines, an optional `start`.
- Toggles keep their `children` (as in Work's page).
- Numbers are **never stored**: they're always worked out when shown.

**The server's block check must accept and limit these fields.** That's migration 45 (not live), with a test that rejects level 4 and a `start` of 0.

**Old notes** have no `level`, which counts as 0.

## Tests (EN and AR)
- **The founder's case:** 1, 2, a callout at level 0, then numbered gives 1; the menu "Continue numbering (3)" gives 3. With the callout indented under 2, the next item is 3 automatically.
- Each level's style: 1. → a. → i.
- Return on an empty item steps out, then ends the list; Backspace at the start turns it into text.
- Turn into a heading moves the children out, and nothing is lost.
- Moving a parent moves its children.
- Deleting a parent lifts its children.
- Fold and unfold keep the count.
- The Arabic mirrors indent and keeps Western digits.
- **Screenshots:**
  - a numbered list with a folded item;
  - a nested 1 / a / i list;
  - the ⋮⋮ menu showing "Continue numbering (3)";
  - the bar with ⇥ ⇤, in EN and AR.

Sources: Notion's parent and child blocks (thomasjfrank.com/learn-notion/parent-and-child-blocks); indenting in Notion (thebricks.com/resources/how-to-indent-in-notion); indenting lists in Apple Notes (iphonelife.com); the Bear community's request for indent and outdent above the keyboard (community.bear.app).
