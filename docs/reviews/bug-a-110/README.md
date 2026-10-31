# Bug A (review 110): the founder's screen recording on build 852, 31 Oct 22:39

- **phone-852-whole.png:** frames every 0.5 s. He holds the note, and the hold icons show. He taps the **Space** icon (the 4th).
- **phone-852-space-card.png:** frames every 0.1 s from 6.8 s.
  - 7.4 s: the card opens at the Space level: **"‹ Space" and nothing under it: no rows, no title.**
  - It stays empty for over a second.
  - 8.5 s: he taps "‹ Space" (it greys) and the card closes.
  - The same happens on every try.

**Reading:** the card draws. `workItemSpacesProvider` is **loading or in error** (an empty but loaded list would show the "no Space" title). It never reaches data on his phone in release. In debug on the emulator, with the same account and data, it loads.
