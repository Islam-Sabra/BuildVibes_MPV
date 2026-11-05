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
