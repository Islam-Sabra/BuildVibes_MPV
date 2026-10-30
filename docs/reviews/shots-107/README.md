# Review 107: the shots, after the lead's check (Q1–Q6)

`flutter test test_screens` on the PC, branch `claude/r107`, without `--update-goldens`: **480 pass, 20 fail.**
- The 480 are every accepted shot: **none changed**, so there are no old/new pairs. The first-run tips don't show in them (no tips repository in those scenarios).
- The 20 failures are the new shots (10 scenarios × EN and AR). They fail only because they have no golden yet ("non-existent file").
- Goldens are not updated, and nothing in `docs/screens/` changed.

## New (no golden yet)

They are in `test_screens/r107_test.dart`, in the folder `r107`.
- They were drawn by running that one file alone with `--update-goldens`, which wrote them into a new `docs/screens/r107/`.
- They were copied here byte for byte as `r107--<shot>_<lang>-new.png`, and `docs/screens/r107/` was then deleted.
- OB5 uses the market pack's trades as migration 20261116120000 leaves them: nine popular in Kuwait (Q6).

| Shot | Frame | What it shows |
|---|---|---|
| r107/OB1-welcome | 2698:38995 | The language at the top end, the four role cards (Architect, Project manager, Supplier, Site engineer), BuildVibes, the line, then Continue with email · I have an invite code · Just looking. |
| r107/OB2-email | 2698:39029 | "Your email", one field filled, Send code. |
| r107/OB3-code-checking | 2698:39057 | The six boxes filled while the code is checked: "Checking…". The address is masked (s•••@gulfbuild.co), with the resend timer, and Try another way is off while checking. |
| r107/OB4-name | 2698:39095 | First and last name, step 1 of 3. |
| r107/OB4b-name-joining | Q1 | With an invite code kept: "Joining Kuwait City Tower — Site team" under the title, right after sign-in. |
| r107/OB5-work | 2699:39043 | Nine tiles, popular first (BIM specialist · Site engineer · Electrician · Steel fixer · Foreman · Site manager · Plumber · Carpenter · Mason), Steel fixer picked; the search; "Not listed? Type it"; step 2 of 3. |
| r107/OB6-join-space | 2699:39123 | K7Q4MD in the boxes (left to right in Arabic too) and the Space it opens: "Private work · Islam Sabra lets people in". Ask to join, Skip for now, step 3 of 3. |
| r107/OB7-tip1-camera | 2699:39168 | Tip 1 of 3: the spotlight on the camera. |
| r107/OB7-tip2-hold | – | Tip 2 of 3: the spotlight on the first card, with the card's corners. |
| r107/OB7-tip3-sign-done | – | Tip 3 of 3: the spotlight on Sign as done on the item given to me. |

## For the lead

- **The titles** are the main size of the two-size rule (`BvType`, founder 18 Oct), not the frames' larger titles, as with every screen.
- **The Architect card's icon square** is the plain soft tint: the token set has no soft blue.
- **OB6 has no back arrow:** your work is saved by then, and going back would open Edit profile. Skip for now leaves the step.
- **OB7 in Arabic at 390 wide:** the spotlight and the card stay on screen, and the card sits above or below the control (Q4).
- **Not drawn:**
  - OB4 with a code that didn't work (Change code · Skip);
  - OB5 with "Not listed?" open;
  - Try another way's sheet;
  - the invite code sheet on OB1.

  They are covered in `test/features/entry/onboarding_v2_test.dart`, in EN and AR. Say which of them you want drawn.
