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
