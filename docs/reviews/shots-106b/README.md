# Review 106b shots: old and new

The lead's check of `claude/r106b`: `test_screens` run **without updating**
(no goldens changed), in the cloud session at `claude/r106b` with K1–K6.

## How these pairs were made

The committed goldens (`docs/screens/`) were drawn on the founder's PC
(Windows). The cloud draws text a little differently: run against the
goldens, 452 of 454 shot tests differ by 0.3–29% (median 3%), the same
shots on the base commit too. So the goldens can't show what changed here.

To compare like with like, both sides were drawn in this cloud session,
each `test_screens` run without updating:

- **`-old.png`**: the shot at `609622d` (slice2-app, 105A live), which
  draws the committed goldens on the PC.
- **`-new.png`**: the shot at `claude/r106b` with K1–K6.

Every shot was compared pixel by pixel (RGB). **10 images differ: 5 shots,
EN and AR.** Every other shot is pixel-identical old to new. The PNGs are
the test's own files, copied byte for byte.

A third run at `bd911bd` (T4 and T5, before K1–K6) shows which change made
each one.

| Shot | Golden (PC) | What changed | From |
|---|---|---|---|
| BH2-entry-selected | `docs/screens/r100/` | the held entry shows its five icons and "Tap to do it"; the bar is Move to… · Duplicate · Delete (no Share) | T4 |
| BH4-share | `docs/screens/r100/` | the bar's Share card is gone; the held entry with its icons (NS5) | T4 |
| BH5-message-preview | `docs/screens/r100/` | the share starts from the held entry's Message icon, not the bar's Share; the screen behind the preview differs | T4 |
| NB-put-in-space | `docs/screens/slice8/` | the share starts from the held entry's Space icon, not the bar's Share; the screen behind the step differs | T4 |
| NS1-status-card | `docs/screens/r106/` | **Share again** at the end of the card, though no share is older | K4 |

BH3 (swipe) did not change. No shot has a share older than its entry, so
the dot, "Older version · changed …" and K5's day don't appear in any shot
(they are covered by `test/features/notebook/changed_since_share_test.dart`).

## For the PC

When the lead accepts them, make the goldens on the PC (its renderer), from
`test_screens` there, for these 10 images only.
