# Review 107 S1: OB1's larger welcome title

- **The change:** on OB1 only, `obWelcomeTitle` now uses `headingXl`: 24/30 Latin and 28/36 Arabic (Almarai Bold). These are existing tokens. Everything else on OB1–OB7 keeps the two sizes.
- **The guard:** `test/core/design/large_type_guard_test.dart` (moved out of `bv_type_test.dart`).
  - The entry screens are no longer exempt as a whole.
  - OB1's welcome title is a named exception, with exactly one large line.
  - The test failed first, then passed.
- **How these were made:**
  - The OB1 shot was drawn alone with `--update-goldens`, then the committed goldens were restored from git. So `docs/screens/r107/` is unchanged.
  - `-old.png` is the committed golden and `-new.png` is the new drawing, each copied byte for byte.

| Shot | What changed |
|---|---|
| r107/OB1-welcome (EN, AR) | The welcome title is larger: two lines in English, three in Arabic. Nothing else moves except what sits under it. |

They become goldens when the lead accepts them.
