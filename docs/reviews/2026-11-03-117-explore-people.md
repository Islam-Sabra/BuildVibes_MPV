# Review 117: Explore as people search (proposal, 3 Nov evening, cloud session)

**Status:** waiting for the founder's ok on the scope (a business call).

**Today:** the Explore tab shows "This part of the app is being built." (`lib/features/explore/explore_screen.dart` is a placeholder). People search already exists as F78 (`people_search_screen.dart`, reached from Messages' + and "Search people"), with the server's rule that blocked and hidden accounts never show.

## The frozen frames (page `2145:3`) and the MVP's scope
The prototype's Explore is wider than the MVP: E1 v3 `2336:37906` has By trade, **Wanted near you (jobs)** and From your projects. E4–E7 and E12 have tabs for People, Projects, Companies, Jobs and Spaces. E11 v2 `2328:37757` has filters including **Looking for work** and **Experience in years**. CLAUDE.md puts **Jobs and hiring**, and **Explore beyond people search**, outside the MVP.

## The lead's recommendation: Explore = people, nothing else
- **E1 (Explore home), people only:**
  - the search field, "Search people by name, trade or company";
  - **By trade**, the grid from E1 (from the market pack's trades, not typed);
  - **From your Spaces:** people you share a Space with, with Follow.
  - No "Wanted near you", no projects, no companies.
- **E2/E3:** recent searches, and results while typing, **people only** (no Project, Company or Jobs groups).
- **E5 v2 (results):** the People list with its groups, in this order:
  - Share a project with you;
  - Confirmed by people you follow;
  - Same trade or role.
  - No All/Projects/Companies/Jobs chips.
- **E11 (filters), cut to:**
  - Trade or role;
  - Location (from the market pack);
  - Proof: "Confirmed on a project", "Worked with someone I know".
  - **Out:**
    - Looking for work, which is hiring, out of the MVP;
    - Experience in years: rule 3, years must not act as a rank;
    - Has credentials, until credentials exist.
- **E8 / E10:** no results, and loading, as drawn.
- **Server:** one `search_people(p_query, p_trade, p_location, p_proof)` that returns only what `profiles_read` allows, excludes blocks both ways and hidden accounts, and ranks by the groups above. pgTAP: a blocked person never shows; a hidden one never shows.
- **The F78 screen becomes this one,** so Messages' + and "Search people" open the same search.

## Why not more
The pilot is one site team working in a Space for four weeks. Explore is where a foreman finds the electrician he worked with last year: people, by trade, with proof. Projects, companies and jobs come with Growth and Hiring after the pilot.

## Ask
**Founder: ok with Explore = people only for the pilot?** If yes, the frames above are used as they are, cut as listed. No new frames are needed.
