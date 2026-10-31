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
