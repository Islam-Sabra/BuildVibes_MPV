# Shots that change on `claude/r100-bugs` (lead's second check, 27 Oct) — not accepted

Run: `flutter test test_screens` without updating, at E1. The same six change at `b79fc38`, before E1, so none comes from E1. Each `E1-run_<shot>.png` shows the committed shot (left) and this run (right).

| Shot | Why it changes |
|---|---|
| F78-new-message (en, ar) | The search field's blinking cursor is now drawn: the shot is taken at another moment of its blink, most likely because real page transitions now run in the tests (D12's `MaterialPage`). A 2-pixel bar, nothing else. |
| NBX2-categories (en, ar) | The same: the cursor at the end of the line is caught visible. Nothing else. |
| NBY1-slash-num (ar) | The "/" card sits about a pixel to the side and down: it is placed by D5/D6's new rules. Its rows and words are the same. |
| PG4-page (ar) | Each entry's ⋯ sits about a pixel to the side: D10's new ⋯ button. Nothing else on the page changed. |
