# Review 106: the founder's notebook findings on build 729 — 29 Oct 2026

## T1. Status icons: their own row, one per kind, no "+N" (corrects review 104 N12)
- **Founder, 08:07:** "I said add icons, but you added +2 … the icons, the time and the pin are all in a very narrow area, and difficult to use."
- **Frames:** NS1 EN `2680:38781`, AR `2680:38875`. **Status: proposal, waiting for the founder's ok.**

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
- **Frames:** NS2 EN `2682:38819`, AR `2682:38903`. **Status: proposal, waiting for the founder's ok.**

**Inside a page, an entry shows in full by default:** every line, with text wrapping. Today it shows 3 single-line rows (`slipLines`).

**The entry's head is:** fold control · title · time.
- An entry with no title uses its first line as the title.

**The fold control**
- It is a 24 chevron at the start of the head: ⌄ when open, › when folded (‹ in Arabic). Its tap area is 44.
- **A folded entry** shows only the head, plus one quiet line: "3 lines hidden" («3 أسطر مخفية»). The status row is hidden too.
- Tapping the chevron (or the folded head) opens it again. **Tapping the text of an open entry still edits it,** as now.

**The page's ⋯** gains **Collapse all · Expand all**. They act on this page only.

**Folding is remembered on the entry.** It is the same on another phone and after an update. This needs **one migration:**
- `notes.collapsed boolean not null default false`;
- an owner-only update through the existing notes RLS;
- a pgTAP test that someone else can't change it.

**Elsewhere nothing changes:** the "My notebook" list keeps its short 3-line cards. Search and Filter open a folded entry when it is the match.

**Hold, swipe and line folding (toggles) work as now.** A line's own fold stays separate from the entry's fold.
