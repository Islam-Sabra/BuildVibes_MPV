# Pilot targets (proposed 21 Oct 2026; the founder approves)

The four measures in `mvp-plan.md` §1, each with a number, so that on 1 March 2027 we can say plainly whether the pilot worked. They are for the founder only and are never shown in the app (rule 3).

**How to read them:** run `supabase/ops/pilot_targets.sql` in the Supabase SQL editor (read only), with the pilot Space's id, the first day and the roster size on its first lines. The measures for every Space stay in `supabase/ops/pilot_measures.sql`.

| # | Measure | Target | Why this number |
|---|---|---|---|
| 1 | **Joining:** of the people the site team planned to have in the Space (the roster), how many are in by the end of week 1 | **80% or more** | A few will be on leave or have no email. Below 80%, the sign-in is the problem (watch for people with no email: plan risk 3). |
| 2 | **Daily use:** working days in weeks 2–4 with at least one work item raised **and** one signed as done or checked | **80% or more** (weekends from the market pack) | It shows the app is part of the day, not a week 1 novelty. |
| 2b | **No fall-off:** items signed as done in week 4, against week 1 | **At least half** | Week 1 is inflated by curiosity; half is a healthy floor. |
| 3 | **The crew sign off themselves:** different Crew members who sign as done with a photo by the end of week 2 | **3 or more**, and the founder sees one foreman do it unaided in under a minute | Rule 2: a foreman with a phone manages the main action alone. |
| 4 | **Proof on profiles:** different members who choose to show at least one checked item | **3 or more** by the end of week 4 | It's the reason a person keeps using BuildVibes after the pilot. |

**Also watched, no target:** the median time from signed as done to checked (Leads keeping up), how many items are sent back, and join requests left waiting.

**If a target is missed:** it's a finding, not a failure. Each one points at a fix: sign-in (1), habit and Needs you (2), the sign-off flow (3), or the profile's value (4).
