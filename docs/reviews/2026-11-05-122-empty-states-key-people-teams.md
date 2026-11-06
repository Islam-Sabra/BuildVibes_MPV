# Review 122: show the way in when Who to call and Teams from companies are still empty

**From:** the lead, 5 Nov 2026, after the founder's phone check on build 1092: "no key people, no phone numbers, no Teams from companies".

**What was actually happening:** nothing was broken. Live data was read with the connector, read-only:
- In all three of the founder's Spaces he is Space admin, with **0 key roles**.
- His profile has **no phone number** saved.
- **No company in any of his Spaces has 2 or more members.** In his Spaces, at most one member has a company on their profile at all.
- By design, Who to call shows only once roles exist, and Make Teams from companies shows only for companies of 2 or more people. **So nothing appeared, and nothing pointed the way in.** The fault is in the design, and this review fixes it.

**Status:** APPROVED (lead's call: this is the design, not a business question).

## Frames (page `2145:3`)
| # | What | EN | AR |
|---|---|---|---|
| KP0 | People, Space admin, no key roles yet: a **Set who to call** card on top, which opens KP3 | `2756:40341` | `2756:40432` |
| TM0 | Teams, Space admin, no company with 2 or more people: a quiet line explaining when Teams from companies are offered | `2756:40523` | `2756:40639` |

## Rules
- **KP0:**
  - Only the **Space admin** sees it, and only while the Space has **no key roles**.
  - Members and Viewers see nothing there, as before.
  - Tapping it opens KP3. Once a role exists, the card is gone and Who to call shows instead.
  - Words: "Set who to call" / «حدّد بمن يتصل الناس». Line: "Safety officer, project engineer… they show on top of People and to every new member." / «ضابط السلامة، مهندس المشروع… يظهرون أعلى الأشخاص ولكل عضو جديد.»
- **TM0:**
  - Only the **Space admin** sees it, and only when the server's preview has no company of 2 or more people without a Team.
  - It sits under the Teams label, above the Team cards.
  - Words: "Teams from companies are offered once 2 or more people have the same company on their profile." / «تُقترح الفرق من الشركات عندما يكتب شخصان أو أكثر اسم الشركة نفسها في ملفاتهم.»
  - It goes away when the offer card or the one-company line shows.
- **KP3, a holder with no number:**
  - Under that holder's name: "No number shared · Message only" / «لم يشارك رقمه · رسالة فقط».
  - This way the admin knows why there's no Call button. Use `can_call`, never the number.
- **Edit profile:** the Phone number row already exists ("Not added"). No change.
- **Tests:**
  - widget tests in EN and AR: KP0 shows for the admin with 0 roles, is hidden for a Crew member, and is hidden after a role is saved;
  - TM0 shows and hides as above;
  - the KP3 holder line;
  - goldens.

## Not in this review
Nothing on the server changes.

## The lead's check: `claude/r122` at `21a8427d` (6 Nov), accepted with one fix
- **No server change** in the diff. Cursor's database run matches the last one (4,702 checks).
- **Shots viewed (AR):**
  - KP0: the card sits on top, only for the admin, and reads right to left;
  - TM0: the note sits under Teams, quiet;
  - KP3: "لم يشارك رقمه · رسالة فقط" sits under the right person.
- **Shared widget for the brand cards:** accepted.
- **Answers to Cursor's questions:**
  1. **One person per line in Key people:** yes, keep it.
  2. **F1, before merge:** move the **"Call them for" line directly under the role tag**, above the people. The order becomes tag → what to call them for → each person (with "No number shared · Message only" under that person). The two grey lines then never sit together.
- **Go live after F1, with the founder's yes:**
  1. merge;
  2. build;
  3. install.
  - No re-check by the lead is needed for F1, but put its EN and AR shots in the report.

## 122b. Role names are free, and the screen must say so (founder, 6 Nov)
- **The founder's note:** "roles shouldn't be fixed; I gave examples only". BuildVibes serves the whole AECO industry, so any role must be possible.
- **What the code does:** the role name is already free text (`BvTextField`, 40 characters). The chips only fill the field. **But the screen hides this:** the field is empty with no hint, and the chips sit right under it, so they read as the only choices.
- **Fixes (KP4), test first:**
  - **The name field's hint, in the founder's words (6 Nov):** «ابحث عن دور... للتواصل السريع» / "Search for a role... for quick contact". Use exactly this, with the three dots as typed.
  - **It works as a search with free text:** as the person types, the suggestion chips narrow to the ones that contain the text, matched in either language and ignoring Arabic letter forms (أ/إ/ا, ة/ه, ى/ي).
  - **Whatever is typed is kept**, even if nothing matches. With no match, there are simply no chips, and Save saves the typed name.
  - **The field opens with the keyboard up** (autofocus) when a new role is added.
  - **No caption above the chips** (the search hint says enough). The chips stay **after** the field, as shortcuts.
  - **Chips and typing work together:** a chip fills the field, and it can still be edited. Typing something else turns the chip off.
  - **The same for "Call them for":** it's free text (already true), with the 122 hint.
- **Market pack:** the suggestions stay examples, never a list to choose from. Keep 5 to 8 per pack; no change now.
- **Tests:**
  - widget: a typed role that isn't in the suggestions saves and shows as typed, in EN and AR;
  - the hint shows when the field is empty;
  - typing «سلا» narrows the chips to «ضابط السلامة», and typing «مشغّل رافعة» shows no chips and saves as typed;
  - a chip, then an edit, saves the edited text.
- **No server change.** `save_key_role` already takes any name of up to 40 characters.

## The lead's check of 122b: `claude/r122b` at `e3e7c93a` (6 Nov), accepted
- **No server change** in the diff.
- **Shots viewed (AR):**
  - the empty sheet shows «ابحث عن دور... للتواصل السريع» with the keyboard up;
  - «سلا» narrows to «ضابط السلامة»;
  - «مشغّل رافعة» saves as typed and shows in Key people with «لا أحد بعد».
- **Reusing the notebook's search helper:** accepted. There's one place for letter-form matching.
- **Cursor's question (Save behind the keyboard):** yes, as its own item, **review 123**. It's real: with the keyboard up, a foreman can't see Save (rule 2).
- **Go live, with the founder's yes:** merge, then the build. **Install 122b and 123 together**, or 122b alone if 123 isn't ready by then.

# Review 123: a sheet's main button always sits above the keyboard
- **The problem:**
  - on bottom sheets with text fields (KP4, and every sheet built the same way), the main button (Save, Send, Post…) is hidden under the keyboard until the person scrolls;
  - KP4's new autofocus makes this show straight away.
- **The fix, in the shared sheet:**
  - The sheet's **main action becomes a footer pinned to the bottom of the sheet**, lifted by the keyboard's height (`MediaQuery.viewInsets.bottom`), with the sheet's usual bottom padding.
  - The fields above it scroll. The focused field stays visible (`Scrollable.ensureVisible`).
  - **When the keyboard is closed, it looks exactly as now.**
  - The footer gets the sheet's surface colour and a 1 px `border/subtle` line on top, **only while the content scrolls under it**.
- **Where:** only in `lib/shared/widgets/`, through the sheet component(s). Then every sheet with a text field and a main button uses it: KP4, holder note, Team name, new Space, poll composer, file rename, report… **List every sheet changed in the report.**
- **Tests:**
  - A widget test with a simulated keyboard (viewInsets 300): the main button is hit-testable and fully on screen, in EN and AR, for KP4 and two other sheets.
  - The goldens with no keyboard must not change.
- **No server change.**

## The lead's check of review 123: `claude/r123` at `0e8f2fda` (6 Nov), accepted
- **No server change** in the diff. 26 files.
- **The fix is made once**, in `lib/shared/widgets/bv_sheet.dart`, and **18 sheets** use it.
  - "File rename" and "poll composer" aren't sheets in the code, so they're correctly left alone.
  - Search-only sheets have no main button, so they're unchanged.
- **Shots viewed (AR, keyboard up):**
  - KP4: «حفظ» sits above the keyboard (disabled while empty), and a line shows over it while fields scroll under;
  - Edit Space: «حفظ» is in view;
  - New folder: «إضافة المجلد» is in view.
- **The keyboard-closed goldens are unchanged (772).** The 4 px clip on Arabic letter tails was fixed in the shared sheet. Accepted.
- **Go live, with the founder's yes:**
  1. merge;
  2. **one** release build with 122b and 123;
  3. install;
  4. the size against WhatsApp in the report (rule 9).

## 122c. Too much text (founder, 6 Nov, phone check of 1103)
- **The founder:** the KP0 card explains too much. Keep the screens short, not explanatory.
- **KP0:**
  - one line only: shield icon + **"Set who to call"** / «حدّد بمن يتصل الناس» + chevron;
  - **remove the description line**;
  - the card's height drops to one row (`BvSpace` row padding).
- **TM0:** shorten it to **"Teams from companies need 2 people with the same company."** / «فرق الشركات تحتاج شخصين من نفس الشركة.»
- **KP3 intro text:** remove it. The screen title says enough.
- **Rule from now on, for the lead and Cursor:**
  - empty states and prompts are **one short line**: no explanations of what a feature does;
  - **if a screen needs a paragraph to be understood, the design is wrong.**
- **Test first:** update the KP0, TM0 and KP3 widget tests and goldens in EN and AR. No server change.
