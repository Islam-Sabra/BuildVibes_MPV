# Review 121: key people ("Who to call") and the Space as an organisation

**From:** the lead, 5 Nov 2026. **Status:** APPROVED by the founder (5 Nov, 10:26), including the section on one person in several Teams.

**The founder's decisions (4 Nov, "ok" to all four recommendations):**
1. Key people are set by the **Space admin only**.
2. The **Call** button shows only when the key person chose to show their number. Disclosure by choice, rule 4.
3. The organisation view is **built from Teams**. There is no "reports to" line per person.
4. A new member sees **Who to call once** when they join. After that it stays **pinned on top of People**.

Calls inside the app are paused (review 120). Here **Call** opens the phone's own dialler (`tel:`). Message opens the direct message.

## Frames (page `2145:3`)
| # | What | EN | AR |
|---|---|---|---|
| KP1 | People: **Who to call** on top for everyone, then Everyone | `2749:40207` | `2750:40274` |
| OC1 | Teams: the Space as an organisation (who runs it, Who to call, the Teams with their admins) | `2749:40326` | `2750:40363` |
| KP2 | Just joined: Who to call first, shown once | `2749:40475` | `2750:40482` |
| KP3 | Space settings → Key people (Space admin) | `2749:40579` | `2750:40538` |
| KP4 | New key role: name (market-pack suggestions), what to call them for, who holds it (up to 2) | `2749:40660` | `2750:40583` |
| NUM1 | Profile → Phone number + **Who sees my number** (one choice, Nobody by default) | `2749:40758` | `2750:40633` |

## Rules
- **Key roles:**
  - Up to **6 roles** per Space, and up to **2 people** per role, each with an optional short note ("Night shift", 24 characters at most).
  - Role name: 40 characters at most. "Call for" line: 120 at most.
  - Order: as the admin sets it.
- **Holders must be current members.** When a holder leaves or is removed, they're taken off the role. If that empties the role, the Space admin gets one Activity line: "Safety officer has no one now".
- **Who sees Who to call:** every member, Viewers included. Nobody outside the Space does.
- **Role name suggestions** come from the market pack (`key_role_suggestions`, EN and AR), never typed in code (rule 5). Kuwait and Egypt packs get at least: Safety officer, Project engineer, Site manager, Site nurse, Storekeeper.
- **Arabic words:**
  - Key people: «الأشخاص الأساسيون»
  - Who to call: «بمن تتصل»
  - Call: «اتصال»
  - Call for: «اتصل به من أجل»
  - Safety officer: «ضابط السلامة». **Never «مسؤول السلامة»**: «مسؤول» is the Lead pass word.
  - Work permits: «أذونات العمل». «تصريح» is reserved for passes.
- **KP2:**
  - It shows the first time the person opens the Space after being let in, and only if the Space has key roles.
  - Store `space_members.key_people_seen_at`. "Got it" sets it, and so does closing the sheet.
- **OC1 (the Teams switch):**
  - **Runs this Space** lists every Space admin.
  - Then **Who to call** as compact chips; tapping one opens the person sheet with Call and Message.
  - Then each Team card: the name, its Team admin with «مشرف الفريق», and up to 5 faces. **No people count** (rule 3).
  - Tapping a card opens TM3 as today.
  - For a Space admin, the "Make Teams from companies" card and "New Team by hand" stay as in review 111.
  - Lines between the blocks are 2 px `border/default`.
- **NUM1, phone number:**
  - Optional, on the profile's edit page.
  - The format and country code come from the market pack.
  - Saved in E.164 and checked on the server.
  - **Who sees my number** is one single choice (rule 6): Nobody (the default) / Members of my Spaces / My Spaces and people I message. It is the same control review 120 uses for calls.
- **The number never appears** in search, on the public profile, in `profiles` selects, or in any list. It is read only through `person_phone()`, one person at a time, when Call is tapped.

## Server
- **Tables**, all with RLS:
  - `space_key_roles`: id, space_id, name, call_for, position, created_at, updated_at.
  - `space_key_holders`: role_id, profile_id, note, position; primary key (role_id, profile_id).
- **Reading:** members read both tables through `space_key_people(p_space)`. It returns each role, its holders with name and title · company, and `can_call` (bool), but never the number itself.
- **Writing:** only through `save_key_role(...)`, `delete_key_role(id)` and `reorder_key_roles(...)`. All are security definer with `search_path=''`, and the Space admin is checked in SQL. The limits (6 and 2) and the membership of each holder are checked in SQL too.
- **A holder leaves:** a trigger on `space_members` deletes their holder rows.
- **Profiles:**
  - `profiles.phone` (text, E.164, nullable) and `profiles.phone_visibility` (`nobody` | `spaces` | `spaces_and_dms`, default `nobody`);
  - column grants so that **no client role can select `phone` directly**.
- **`person_phone(p_profile, p_space)`:**
  - returns the number only if the visibility allows it and the caller shares that Space;
  - for `spaces_and_dms`, a direct-message thread between the two also counts;
  - each call is rate-limited per caller (30 a day).
- **pgTAP tests:**
  - a non-member can't read the roles;
  - a Crew or Lead member can't write;
  - the limits hold;
  - a leaving holder is removed;
  - `phone` can't be selected;
  - `person_phone` returns null for Nobody, for a stranger, and for spaces-only from a DM.

## App
- **KP1 / OC1:** `PeopleTab` and `TeamsView` read `spaceKeyPeopleProvider`. Who to call sits under the existing Needs you block for admins.
- **Call:** fetches `person_phone` on the tap, then opens `tel:`. If null, the button isn't shown at all, so there's no dead button. Check `url_launcher`'s size first (rule 9).
- **Message:** opens or creates the direct message.
- **KP3 / KP4:**
  - Space settings gets a **Key people** row, for the Space admin only.
  - The role sheet uses the existing sheet, field and chip components.
  - The holder picker lists Space members only.
- **Tests:**
  - widget tests in EN and AR for KP1, OC1, KP2 (shown once), KP3, KP4 and NUM1;
  - goldens;
  - Arabic: role names with Latin names keep their own direction (`textRun`).

## Not in this review
- Calls through the app (review 120, paused).
- A "reports to" line per person.
- Key people across several Spaces, or on the profile.

## One person in several Teams (founder, 5 Nov)
Teams can follow a company, a shift or a trade at the same time. For example, Ali is in **Gulf MEP** (his company) and in **Night shift**. **The database already allows this**: `team_members` has the primary key (team_id, profile_id) and no one-Team limit. The app and the flows must allow it everywhere too.

- **OC1:** a person shows in every Team they belong to. In the frame, Ali (AS) and Hassan (HK) are in Gulf MEP and in Night shift.
- **KP1 / P1:** a member's row lists **all** their Teams, as review 105 says. If they don't fit, show "Gulf MEP, Night shift +1".
- **TM3 Add people:** lists every Space member who isn't in **this** Team, including people already in other Teams.
- **TM4 confirm on join:** the Team choice becomes **several ticks**, not one choice. The company's Team is ticked already, and a shift Team can be ticked too. These choices don't exclude each other, so ticks are right (rule 6 covers only choices that do).
- **TM1 Make Teams from companies:** being in a shift Team must not hide a company from the offer. "No Team yet" means no Team made from **that company**, not "people with no Team".
- **Who sees it (TM5) and Team files:** a post or file for a Team reaches everyone in it, even when a person is in several. **A person in two Teams that are both chosen gets the post once**, with one push.
- **Team admin:** one person may be the admin of several Teams.
- **Tests:**
  - pgTAP: one person in 2 Teams sees both Teams' posts and files and gets one push for a post to both; removing them from one Team keeps the other.
  - widget: P1's row with 3 Teams; TM4 with 2 ticks.

## The lead's check: `claude/r121` at `39cc3202` (5 Nov), accepted with two small fixes
- **SQL stand-in:** fresh database, all migrations, **74 files, 4,688 checks, PASS**. This matches Cursor's count.
- **Read in the code:**
  - **`profiles.phone`:**
    - `authenticated` gets select on every column except `phone`;
    - every app select on `profiles` names its columns, so nothing selects `*`;
    - updates don't return rows.
  - **`phone_shown_to`:**
    - nobody, the owner themselves, hidden accounts and blocks all return false;
    - for a Space, both people must be active members;
    - for a DM, the visibility must be `spaces_and_dms` and the owner's thread must be open.
  - **`person_phone`:**
    - a per-caller lock and 30 reads a day;
    - it counts the read before answering, so probing costs reads too.
  - **`space_key_people`:**
    - gives `can_call` but never the number.
  - **Key-role writes:**
    - Space admin only, checked in SQL, with the limits checked in SQL;
    - a leaving holder is removed by trigger.
- **Shots viewed:** KP1, OC1, KP2, P1 with two Teams, NUM1, KP4 (AR). Directions, the faces and «مشرف الفريق» are right; there are no counts.
- **Rule for the data model:** from now on, `profiles` has column grants. **Any new `profiles` column needs its own `grant select (col)` in its migration, or the app can't read it.** Write this into `docs/product/data-model.md`.
- **Answers to Cursor's questions:**
  1. **KP2 wording:** a Space isn't always a site. Change it to "Before anything else: who to call in this Space." / «قبل أي شيء: بمن تتصل في هذه المساحة.»
  2. **The tags on member rows:** keep the pass and Team tags. The code is right, and the KP1 frame was only simplified.
  3. **"+965" in the phone field:** accepted, because it comes from the market pack. Keep the phone icon out.
  4. **A Call button in direct messages:** yes, as **121b** after this goes live (below).
- **Fixes before merge, small, test first:**
  - **F1:** the KP2 wording as in answer 1.
  - **F2:** KP4's "Call them for" field shows a hint when it's empty: "e.g. hazards, accidents, work permits" / «مثلاً: المخاطر والحوادث وأذونات العمل».
- **Then go live, with the founder's yes:**
  1. merge;
  2. `db push`, dry run first: only `20261201120000`;
  3. build and install on the phone.

## 121b. Call from a direct message (after 121 is live)
- **What the founder decided:** outside a Space the call is a phone call only (review 120). Option 3 of Who sees my number, "My Spaces and people I message", needs a place to call from.
- **Server:** `dm_can_call(p_other uuid) returns boolean`. It answers `phone_shown_to(p_other, auth.uid(), null)` and doesn't count against the 30. Grant it to `authenticated` only.
- **App:**
  - The DM's top bar gets a **phone icon** (Phosphor `phone`, regular, the same size as the bar's other icons), placed before the ··· button, and only when `dm_can_call` is true. No dead button.
  - Tapping it calls `person_phone(other, null)`, then opens the phone's dialler. If the answer is now null, show "This number isn't shared any more" / «لم يعد هذا الرقم متاحاً».
- **Tests:**
  - pgTAP: true only for `spaces_and_dms` with an open thread; false for spaces-only, a block, or a hidden account.
  - Widget tests in EN and AR.
