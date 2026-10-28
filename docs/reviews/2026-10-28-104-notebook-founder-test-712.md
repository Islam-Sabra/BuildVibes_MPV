# Review 104: the founder's notebook findings on build 712 — 28 Oct 2026

**Founder, 28 Oct 20:26–20:37.** Approved from these written rules ("yes"). No database change.

## N6. Confirm before delete, then Undo
- **Every delete in the notebook** first shows a confirm: entries, pages, lines selected with the bottom bar, a Draft's Discard, and a swipe's full Archive is **not** a delete.
  - The title is "Delete this entry?" («حذف هذه التدوينة؟»), or for a page "Delete this page and everything in it?", or for lines "Delete these lines?".
  - The body is "It goes to Deleted items for {n} days.", using the person's 7, 30 or 90.
  - The buttons are **Cancel · Delete**, with Delete in red, as words.
- **After Delete,** the "Deleted · Undo" bar still shows for 5 s, as now.
- **Not affected:** Delete forever and Empty now keep their own stronger confirm, in Deleted items.

## N7. Sorting, complete (replaces review 102's N5 lists)
| Where | SORT (one single choice) |
|---|---|
| **Pages list** | Latest activity (default) · Name A–Z · Newest created · Oldest created |
| **Inside a page** | Newest first (default) · Oldest first · Name A–Z · Type |

- **Name A–Z** inside a page sorts by the entry's title, or its first line when it has none. Each alphabet stays together, with the app language's first (as N5).
- **Type** groups entries under small labels: To-dos · Checklists · Photos · Files · Voice notes · Text.
  - An entry goes under its first kind found in that order. Newest first inside each group.
- **Day headers** show only in the two date sorts. **The hand order (N3)** applies only in the date sorts.
- **Pinned stays on top** in every sort. A sort that isn't the default shows as a chip, and its ✕ resets it.
- **Arabic:**
  - «آخر نشاط · الاسم أ–ي · الأحدث إنشاءً · الأقدم إنشاءً»;
  - «الأحدث أولًا · الأقدم أولًا · الاسم أ–ي · النوع»;
  - the groups: «مهام · قوائم تحقق · صور · ملفات · ملاحظات صوتية · نص».

## N8. Bug: a table shows collapsed
- After a table is made and OK is tapped, the saved entry (on the page, and when reopened) shows only the table's title or header.
- **The fix:** a saved entry shows the whole table, every row and column, with sideways scrolling when it's wider than the card. EN and AR (columns mirror).
- **Test first:** a table saved with 3 rows and 3 columns shows all of them in the entry card, on the page and in the editor.

## N9. Share → Space uses the Space's own kinds
- The choice reads **Note · Work item · Checklist** («ملاحظة · بند عمل · قائمة تحقق»), with the same icons as the Space's kind chips.
- **Note is the default.** "Post" is gone.
- Announcements and scheduled activities aren't offered here; they're written inside the Space.

## N10. "For" and "Team" are pickers, not chip rows
- **Team** is one row, "Team: Whole Space ›" («الفريق: كل المساحة ›»). It opens a list of the Space's Teams.
- **For** is one row, "For: {name} ›" («إلى: …»). It opens the Space's existing **Give to** picker (`bv_give_to_picker.dart`):
  - search by name;
  - the chosen Team's people first, then the rest A–Z;
  - **a work item allows exactly one person** (the Space rule), and the default is me;
  - **a checklist** follows the Space's own checklist rule. Several people show as "Omar Haddad + 2".
- **No chip row lists the members.** It must work with 100 members or more.
- **Test:** a Space with 120 members shows one For row, the picker searches, and a work item can't take two people.

## N11. The time picker keeps the clock (corrects review 102's N2)
- **The clock face stays,** and it's the default.
- **The mode switch** (where typed input used to be) now switches between the **clock** and the **wheels**: hour 1–12, minutes in 5-minute steps. There is **no typed input** anywhere.
- **AM/PM** stays above as one choice, with no helper line (N1).
- Both modes allow only valid times, and grey out times already past today.
- **The last mode used is remembered** on the phone.
- It's the same picker everywhere (`BvTimeWheel` becomes the wheel mode of one shared `BvTimePicker`).

## N12. Status icons on an entry, instead of text marks
- **A small icon row at the top end of each entry card,** beside its time:
  - 📌 pinned;
  - 🔔 a reminder, in the accent colour while it's still to ring, grey after;
  - 📣 shared to the feed;
  - 👷 shared to a Space;
  - 💬 sent to a person.
  - **The icons are the same glyphs** as their actions (swipe, Share).
- **Size and colour:** 14, grey, with a 4 gap. At most 3 icons; past 3, the third becomes "+N".
- **Tap an icon** to open a compact card with its detail:
  - "Shared to the feed · 08:30";
  - "Shared to {Space name} · 08:45" (the real name);
  - "Sent to Ahmed · 08:50";
  - "Reminder · Fri 7:00", with Change.
- **The text marks under the entry ("Shared to…") go.**
- **Arabic:** the row mirrors, and the time and icons sit at the start of the reading direction's end.
- **Screen readers:** each icon has a label ("Pinned", "Reminder, Friday 7:00", "Shared to the feed at 08:30").

## Tests and shots
- Each rule gets a test in EN and AR.
- **Shots changed on purpose:**
  - BH3 and PG4 (icons replace the marks);
  - BH4 and BH5 (Note · Work item · Checklist, and the For and Team rows);
  - the N2 time shots (now the clock face, plus the wheels in a second shot);
  - the BH9 sort parts.
- **Any other changed shot** is listed with before/after and not accepted.
