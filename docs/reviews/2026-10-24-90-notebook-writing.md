# Review 90: F106, My notebook writes in place — 24 Oct 2026

**Founder, 24 Oct:** "the composer of the notebook is very generic and poor, not like a modern tool." The Space is good enough for the pilot. Improve the notebook now; the Space later.

**Why:** only the notebook's list was drawn, never its writing state, so it was built from standard parts: a sheet over a grey screen, Note / Checklist / To-do tabs, outlined boxes and a big orange Save. That breaks rule 1 and doesn't match Work's writing card.

## The frames (Figma `IcoK4u8JFO6K8l4YYiHNkm`, page "PROTOTYPE · Full app v1 · EN")
| | EN | AR |
|---|---|---|
| NBW1 · Tap Note: a slip opens at the end of today | `2613:36507` | `2613:37050` |
| NBW2 · The kind chip: Note, To-do or Checklist | `2613:36619` | `2613:37162` |
| NBW3 · A to-do with by when and Remind me | `2613:36731` | `2613:37274` |
| NBW4 · A checklist typed in place | `2613:36843` | `2613:37386` |
| NBW5 · Left unsent: kept as a draft | `2613:36956` | `2613:37499` |

The note beside them is `2613:78973`. Both rows sit at x 24000, at y 48300 (EN) and y 49300 (AR).

## What to build
1. **No sheet.** Tapping the bar's "Note" adds a **writing slip at the end of today**: the notebook's paper slip, white, with a dashed accent edge (as Work's writing card), and the keyboard comes up. The list stays visible above it, bottom-aligned, newest last.
2. **The slip's header:**
   - the **kind chip** "Note ▾" / «ملاحظة ▾» on the start side;
   - "Now" / «الآن» in small grey on the end side.
3. **The kind chip** opens a small menu above it, with Note / To-do / Checklist and a tick on the current one (NBW2). It's one single choice (rule 6), replacing the three tabs. Changing it keeps what's typed:
   - note to checklist: each line becomes a point;
   - checklist to note: the points become lines;
   - to-do: the first line.
4. **Note:**
   - the first line is the **title** (main size, bold), and placeholder "Title" / «العنوان»;
   - under it, plain text, with placeholder "Write a note…" / «اكتب ملاحظة…»;
   - no boxes or outlines.
5. **To-do:**
   - one tick line with the words (NBW3);
   - **by when** and **Remind me** show inside the slip as small chips, each with ✕: "📅 by today 4:00 pm" and "🔔 3:45 pm".
6. **Checklist:**
   - a bold title, then the points, each typed on its own tick line;
   - **Enter adds the next point**, and Backspace on an empty point removes it (as Work, F40);
   - the last line shows "Add a point" / «أضف نقطة» (NBW4).
7. **The tools row above the keyboard** (white, with a line on top):
   - Checklist (list-checks), Remind me (bell), By when (calendar), Photo (camera) and Voice (microphone), then Send at the end;
   - a tool in use is tinted (soft accent background, accent icon): Checklist when the kind is Checklist, and By when and Remind me once set;
   - Remind me and By when open the day-and-time picker that's already built, and Photo and Voice attach to the note.
   - **Send** is a 40 px circle. It's grey until there's something to keep, then accent; it **replaces the big Save**, and saves the note.
8. **A draft:**
   - leaving (Back, or the app closing) keeps the slip at the end of today, dashed, with a "Draft" / «مسودة» pill, and "Kept as you left it. Tap to go on writing." / «محفوظة كما تركتها. اضغط لتكمل الكتابة.» (NBW5);
   - a tap opens it again with the keyboard; one draft at a time;
   - empty drafts aren't kept.
9. **Reuse Work's writing card and its point editor** (`daybook_writing.dart` and the checklist point lines); don't build a second editor.
10. **Sizes and directions:**
    - the two-size rule: 15 / 12, and Arabic 16 / 13 in Almarai; times keep a no-break space;
    - in Arabic everything mirrors, and the Send arrow and Back flip;
    - Western digits.

## Checks
- **Widget tests, in EN and AR:**
  - Note opens the slip with the keyboard;
  - the chip changes the kind and keeps the text;
  - Enter adds a point, and Backspace on an empty point removes it;
  - by when and Remind me show as chips, and ✕ removes them;
  - Send is off when empty and saves when on;
  - leaving keeps a draft, and a tap reopens it;
  - an empty slip leaves no draft.
- **Screenshots** of NBW1–NBW5 in EN and AR at 390×844, compared with the frames.
- **No migration:** notes, kinds, `remind_at` and due dates already exist.
