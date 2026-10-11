# MVP plan (11 Oct 2026)

**Target:** pilot live on **Friday 1 January 2027**, with one real site team. The founder has the pilot company and contacts them himself.

**Scope:** sections 2 and 3 are Claude's recommendation. The founder confirms that Jobs and direct messages wait until after the pilot.

## 1. What the MVP must prove
One real site team runs its daily work in a BuildVibes Space for four weeks, and its members get proof on their profiles from work that was checked and closed.

**Pilot measures** (proposed):
- Most invited members join in the first week.
- Work items are created and closed every working day, not only in week 1.
- A foreman can sign a work item as done, with a photo, without help.
- Several members choose to show at least one checked item on their profile.

## 2. In the MVP
| Area | In V1 |
|---|---|
| **Sign-up and sign-in** | Phone code, Google, Apple and email code. No passwords. Short onboarding: name, role or trade, company. |
| **Language** | Arabic and English, right to left. Western digits. |
| **Profile** | Photo, headline, experience, projects on the CV, Work you delivered (hidden until the person chooses), share link, follower counts. |
| **Projects** | Shared record with no owner. "Is it already here?" and Add to my CV. Suggest an edit goes to a simple review queue. |
| **Spaces** | Create a Space and link a project. Invite link and code. Join requests confirmed by the admin with a Lead, Crew or Viewer pass. Teams. Space info: Access, Who can invite, Notifications. |
| **Space chat** | Everyone and Team threads, with photos, files and voice notes. Work item cards in the chat. |
| **Work items** | Open → Done (with a photo or note) → Checked, or Sent back with a reason. One owner, due date, Team, place on site, attachments. Filters. Needs you. |
| **Library** | Files and drawings per Space, with preview. |
| **Home** | Feed (public posts with photos, tagged to a project) and the Spaces tab with Needs you. |
| **Activity and push** | Work item assigned, done, checked or sent back. Join requests. Mentions. |
| **Basics** | Report and block, delete account, privacy settings, photo upload that copes with a weak signal. |

## 3. Not in V1 (after the pilot starts)
- Jobs, hiring, and company pages with job management
- Explore beyond a simple people search
- Notebook and Planner
- Community question Spaces
- Direct messages and "Message about work"
- CV import and CV PDF versions
- Connected accounts, paid plan, sponsored posts

## 4. Build order
Weeks start on Sunday. The live status is in `docs/progress.md`.

| Week | Dates | Work |
|---|---|---|
| 1 | 11–17 Oct | Audit. New app, backend and repo. Data model and permission rules |
| 2 | 18–24 Oct | Components in Flutter. Sign-up and sign-in |
| 3 | 25–31 Oct | Profile, project records, "Is it already here?", Add to my CV |
| 4 | 1–7 Nov | Spaces: create, link a project, invite link and code, join requests, passes, Teams |
| 5 | 8–14 Nov | Work items: create, Needs you, sign as done with a photo, check or send back, filters |
| 6 | 15–21 Nov | Space chat (live), item cards in the chat, Library and file preview |
| 7 | 22–28 Nov | Home feed and posts, Spaces tab, Activity, push notifications |
| 8 | 29 Nov–5 Dec | Arabic pass, market pack, privacy, report and block, delete account |
| 9 | 6–12 Dec | Internal test with 3–5 people. Fixes |
| 10 | 13–19 Dec | App Store and Google Play submission. Fix review feedback |
| 11 | 20–26 Dec | Pilot prep: pilot Space with their admin, seed the project, final fixes |
| 12 | 27–31 Dec | Buffer |

## 5. Technical decisions
- **A clean Flutter app** in this folder, porting the proven parts of the old app (see `codebase-audit.md`).
- **A new Supabase project**, "BuildVibes MVP": Postgres, auth with phone codes and Google, Apple or email codes, storage, realtime.
  - Free tier while building; a paid plan from the pilot, for daily backups.
  - Every permission is enforced on the server with row-level security.
- **One component set.** Arabic uses Flutter's `Directionality`, so nothing is drawn twice.
- **Market pack as data.**
- **Photos queue and retry** on a weak site signal.
- **Measures from day one:** active Spaces, members per Space, work items closed per week, storage used.

## 6. Risks
1. **Scope pressure.** If the plan slips, Library preview and voice notes are cut first. Work items are never cut.
2. **Store review timing in December.** That's why submission is early and the last week is buffer.
3. **Phone code cost grows with every sign-in.** Google, Apple and email codes reduce it.
