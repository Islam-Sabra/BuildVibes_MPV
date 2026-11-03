# Review 111: Teams from companies, and Team admins (31 Oct 2026)

**Founder, 19:31–19:37.** Posts can go to one Team, seen only by that Team. The admin makes Teams from the companies already in the Space, in one go. Each Team has a Team admin.

**Status: approved (founder, 19:37: "Exactly"). Build before the pilot, after reviews 110 and 109.**

## Frames
| Frame | What | EN | AR |
|---|---|---|---|
| TM1 | People → Teams (Space admin): **Make Teams from companies**; each Team shows its admin | `2728:39665` | `2728:39978` |
| TM2 | The companies found, all ticked, people inside, a suggested Team admin, one spelling merge, **Create** | `2728:39726` | `2728:40039` |
| TM3 | A Team: its admin on top; the Team admin adds or removes its people | `2728:39812` | `2728:40125` |
| TM4 | A join request from a known company: its Team is already chosen | `2728:39875` | `2728:40188` |
| TM5 | Posting: Who sees it lists Everyone and my own Teams, plus every Team for a Team admin or Space admin | `2728:39925` | `2728:40238` |

## Rules (founder)
**Who sees a Team post (as today):** that Team, the Space admins, its author and, for a work item, its owner.

**Who can post where:**
- A member posts to **Everyone or their own Teams**.
- A **Team admin** or a **Space admin** can post to **any Team**, to coordinate.

**Team admin (new):**
- One per Team.
- **Can:**
  - add and remove people **in their own Team**;
  - post to any Team.
- **Can't:** change passes, Space settings, other Teams' people, or who the Team admin is. Only the Space admin changes the Team admin.

**Make Teams from companies (TM1, TM2):** the Space admin only.
- **Grouping:**
  - A member's company is their registered company, or else their typed company name, compared with case, dots, spaces and a trailing "Co./Company/شركة" ignored. Typed names stay plain text (rule 4), and no company is created.
  - When two spellings look alike, the sheet offers **merge** and doesn't merge on its own.
  - People with no company go under "No company", unticked.
- **Each company becomes a Team** named after the company, with its people inside.
- **The suggested Team admin** is the Lead in that company with the earliest join date, or else the earliest member. The Space admin can change it in the sheet.
- **One step:** everything ticked is created at once, as all or nothing, and a company that already has a Team of the same name gets its new people added to it instead.
- **Later:**
  - **TM4:** a join request from someone whose company matches a Team has that Team already chosen on the confirm sheet, with the line "Chosen because … works at …".
  - When **2 or more** members share a company that has no Team, the Teams tab shows one line: "2 new people from Delta Steel: make a Team?". It opens TM2 with only that company.
- Teams can still be made by hand ("New Team by hand").

## Server (one migration)
- **`teams.admin_id`** (null allowed): a member of that Team.
- **Functions** (security definer, `search_path = ''`):
  - **`set_team_admin(team, profile)`:** Space admin only.
  - **`company_team_preview(space)`:** Space admin only. It returns the groups (company key, display name, people, suggested admin, similar-spelling pairs).
  - **`create_company_teams(space, groups)`:** Space admin only. All or nothing, and a retry is safe.
  - **`set_team_members`:** now also allowed to that Team's admin, but only for their own Team.
- **Post rules:** a Team post from a member requires membership of the Team, **or being any Team's admin**, or being a Space admin.
- **pgTAP:**
  - a non-member, Crew and a Team admin of another Team can't create company Teams or change a Team admin;
  - a Team admin can add or remove people in their own Team only;
  - a Team admin can post to another Team;
  - a member can't;
  - the grouping ignores case and dots;
  - create is all or nothing.

## App
- **TM1:** the Teams tab in People. The **Make Teams from companies** card shows only to Space admins, and only when 2 or more members share a company with no Team.
- **TM2:** the sheet. Each company row has a tick, the name with its count, the Team admin (tap → pick from its people), and the merge line when one is found. Then **Create N Teams**.
- **TM3:** the Team page. The admin row comes first with a green **Team admin** badge. **Add people** shows for the Team admin and the Space admin. The ⋯ menu has **Make Team admin** (Space admin).
- **TM4:** the confirm sheet chooses the matching Team.
- **TM5:** the composer's **Team** line lists what the person may post to; the sub-line says "Your Team" or "You post here as a Team admin".
- Tests in EN and AR for each, and shots into `docs/reviews/shots-111/`.

## The lead's check of `claude/r111` at `5f541fa4` (2 Nov)
**What was run:**
- The SQL stand-in on `5f541fa4`: **60 files, 4,341 checks, PASS**.
- Two independent reviews: spec, and security/standards.
- All 12 new shots (TM1–TM5) and the 24 changed pairs, viewed in English and Arabic.

**Verdict: not ready to merge.** Fix V1–V14 test-first on `claude/r111`. Then update the 24 goldens (accepted, apart from V12 and V13) and report.

### Blocker
- **V1. A child work item skips the Team post rule** (`review111.sql:403`). The check is skipped whenever there is a parent, but the old body forces the parent's Team only when the parent *has* one.
  - **Scenario:** a Crew member makes an Everyone item, then a child with `p_team` set to a Team they're not in. The child lands in that Team.
  - **Fix:** skip only when the Team really was inherited (`v_team is not distinct from v_parent.team_id`, or from `v_thread_team`).
  - **pgTAP:** a parent with no Team, plus a foreign `p_team` → refused.

### Fix before merge
- **V2. `company_team_for` accepts any profile** (`review111.sql:347-365`). A Space admin could probe the typed company of anyone, including someone who blocked them.
  - Require a pending join request or active membership of `p_profile` in that Space, `not is_blocked_with`, and `not is_hidden_account`.
  - pgTAP for each.
- **V3. A Viewer can't be a Team admin** (the lead's call: a Viewer only reads).
  - `set_team_admin` refuses a Viewer.
  - The suggestion picks by pass (Lead, then Crew), then join date, and never a Viewer.
  - When a member's pass becomes Viewer, their Team-admin role clears.
  - pgTAP.
- **V4. Look-alike spellings are never dropped** (the builder's choice 4, overruled). If merge isn't tapped, the look-alike shows as its own ticked row, so nobody is silently left out of a Team. The look-alike check also compares against the names of the Space's **existing** Teams, so "Delta Steal" offers merge into an existing "Delta Steel". Tests.
- **V5. "No company"** (choice 6): that row is **left out** of the suggestion. Those people stay without a Team, and the admin can add them by hand. No Team is ever called "No company".
- **V6. The suggested admin shown on the row** (`make_teams_sheet.dart:150`) is always the person Create will set, even when they are already in an existing Team. Never "Team admin: —" followed by someone being set anyway.
- **V7. A Team file opens for its uploader** while they are a member of the Space (`uploaded_by = me and is_member(space)`), not only while they are a Team admin (`review111.sql:443`).
- **V8. `create_company_teams` checks Space admin before it locks the `spaces` row** (`review111.sql:271`).
- **V9. `r111_patch` raises** when its text appears more than once, as well as when it's missing.
- **V10. Arabic wording.**
  - **Team admin is «مشرف الفريق»**, never «مسؤول الفريق», because «مسؤول» is the Lead pass. Add it to the glossary in `CLAUDE.md` and `docs/product/arabic-glossary.md`.
  - TM1's line reads «بضغطة واحدة، وراجِعها قبل الحفظ» (review, not undo).
- **V11. The B2 storage log:**
  - log each file's **folder relative to the top folder, its extension and its size, never its name**, plus a total per subfolder;
  - log `e.runtimeType` only;
  - wrap each file in its own try/catch;
  - gate it on `bool.fromEnvironment('BV_STORAGE_LOG')`, passed in the pilot build;
  - remove the test that asserts the flag is on.
- **V12. Team page line (TM3/T1):** "Only the Space admin changes the Team admin (…)" ends with a literal "(…)" in both languages. Fill it with the Space admin's name, or end the sentence.
- **V13. Who sees it (TM5):** the rows read "You post here as a Team admin" while the viewer is the Space admin. A Space admin gets "as a Space admin" (as F56 already does). Test both.
- **V14. Team admin and templates and Team chat:** decide in SQL and test that a Team admin outside the Team can use that Team's templates and post in its chat, the same as posting to it.

### The builder's choices
| # | Choice | The lead |
|---|---|---|
| 1 | Counts drawn in TM1, TM3 and Team rows dropped (rule 3); the count on TM2 company rows kept (it says what Create will do) | **Accepted.** This departs from the frozen frames on purpose: rule 3 wins. |
| 2 | TM1: 2 or more waiting companies → card; exactly 1 → line | **Accepted** |
| 3 | The join sheet preselects **Crew** when the person's company matches a Team | **The founder's call.** Recommendation: keep it |
| 4 | Look-alikes folded and left without a Team | **Overruled:** V4 |
| 5 | Added copy | **Accepted,** with V10 |
| 6 | "No company" becomes a Team | **Overruled:** V5 |
| 7 | Unused strings removed | **Accepted** |

**Server choices:** "شركة" is also stripped from the start of a name, and a Crew Team admin still can't post a check-in. Both are **accepted.**

### Before going live (from the PC, with the founder's yes)
- Check the live Postgres version (15 or later is needed for `on delete set null (admin_id)`).
- Check that `fuzzystrmatch` isn't already installed in `public`. If it is, stop and report.
- Then: `db push` → the build → install.

### Cloud session, 2 Nov evening: the server side done on `claude/r111-cloud`
- **Done, test first:** V1, V2, V3, V4 (server: `similar_teams`), V6 (server: `admin_name`), V8 and V9. The failing tests were committed first (`62_review111_lead.test.sql`). pgTAP: **61 files, 4,363 checks, PASS**.
- **V7 reversed by the lead:** kept as built. Loosening it broke an older rule (27_model_views): out of the Team, your Team view closes. An uploader reads a Team file only while they are a member of that Team or some Team's admin.
- **V14 decided:** a Team admin outside a Team **posts** to it but doesn't read its chat or templates. They stay with the Team's members and the Space admin. Tested.
- **For the PC:** merge `claude/r111-cloud` into `claude/r111` first, then the app side (V4–V6, V10–V13), choice 3 and the goldens.

## The lead's second check: `claude/r111` at `564cb11e` (3 Nov)
- **What was run:**
  - The SQL stand-in: **61 files, 4,363 checks, PASS**.
  - The storage log read line by line: folder, extension and size only, behind `BV_STORAGE_LOG`.
  - The TM shots and changed pairs viewed in English and Arabic: «مشرف الفريق», «وراجِعها», the ended Team-page sentence, the look-alike as its own ticked row, no "No company" row.
- **Accepted:** V4 one step deep, and the new merge line "Looks like the Team "X": add to it".
- **Verdict: ready to merge** once the founder answers choice 3. Then live from the PC, with his yes:
  1. Check the Postgres version (15 or later) and that `fuzzystrmatch` is not in `public`.
  2. `db push` (20261122120000_review111).
  3. A release build with `--dart-define=BV_STORAGE_LOG=true`.
  4. Install on the Xiaomi 22120RN86G.
  5. Phone checks: B1 both paths, the storage log read with `adb logcat`, Teams from companies on NBKCH.

## Bug on build 987: Teams in NBKCH shows "Something went wrong" (3 Nov, founder)
- **The live log:** every read of `/rest/v1/teams?select=id,name,admin_id,admin_name,members:team_members(profile_id)&space_id=eq.<NBKCH>` returns **HTTP 300, PostgREST PGRST201** (ambiguous embedding), from 07:01 to 07:02 UTC, again and again.
- **Why:** review 111 added `teams_admin_in_team_fkey` (teams → team_members), so there are now **two** relationships between `teams` and `team_members`. The other is `team_members_team_id_fkey` (team_members → teams). PostgREST can't choose, so the embed `team_members(...)` fails.
- **Why the tests missed it:** pgTAP doesn't go through PostgREST, and the app tests use fakes.
- **Fix (app, one line):** `space_repository.dart:373`: `members:team_members!team_members_team_id_fkey(profile_id)`. That's the only place in `lib/` that embeds `team_members` from `teams`.
- **Guard against it happening again:**
  - a Dart test that this select names the relationship;
  - a pgTAP test listing the foreign keys between `teams` and `team_members`, with a comment that any embed between them must name `team_members_team_id_fkey`.
- **Ship:** hotfix build 988 now, so the founder can test Teams. No server change.
