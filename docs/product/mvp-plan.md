# MVP plan (11 Oct 2026)

**Target:** pilot live on **Monday 1 February 2027**, with one real site team. The founder has the pilot company and contacts them himself.

**Scope:** sections 2 and 3 are Claude's recommendation. The founder confirms that Jobs and direct messages wait until after the pilot.

## 1. What the MVP must prove
One real site team runs its daily work in a BuildVibes Space for four weeks, and its members get proof on their profiles from work that was checked and closed.

**Pilot measures** (proposed; numbers in `pilot-targets.md`):
- Most invited members join in the first week.
- Work items are created and closed every working day, not only in week 1.
- A foreman can sign a work item as done, with a photo, without help.
- Several members choose to show at least one checked item on their profile.

## 2. In the MVP
| Area | In V1 |
|---|---|
| **Sign-up and sign-in** | 6-digit email code only (decision 04). No passwords. Google and Apple are built but hidden until their keys exist. Phone code comes after the pilot. Short onboarding: name, country, role or trade, company, optional private mobile number. |
| **Language** | Arabic and English, right to left. Western digits. |
| **Profile** | Photo, headline, experience, projects on the CV, Work you delivered (hidden until the person chooses), share link, follower counts. |
| **Projects** | Shared record with no owner. "Is it already here?" and Add to my CV. Suggest an edit goes to a simple review queue. |
| **Spaces** | Create a Space and link a project. Invite link and code. Join requests confirmed by the admin with a Lead, Crew or Viewer pass. Teams. Space info: Access, Who can invite, Notifications. |
| **Space chat** | Everyone and Team threads, with photos, files and voice notes. Work stays in the daybook; a chat message can be turned into a work item. |
| **Work items** | Open → Done (with a photo or note) → Checked, or Sent back with a reason. One owner, due date, Team, place on site, attachments. Filters. Needs you. In the Daybook design: see `daybook.md`. |
| **Work (Daybook)** | Writing in place with drafts; work item, checklist, announcement, scheduled activity and file posts; opening a post in place (blocks, /, turn into, tables); work items under one work item; walk mode; templates; daily report; meeting notes into work items; management report. See `daybook.md`. |
| **Planning** | The personal notebook (private notes, checklists, to-dos, pinned notes, "Put in a Space") and My calendar across all Spaces. |
| **Direct messages** | Between two people. |
| **Library** | Files and drawings per Space, with preview. |
| **Home** | Feed (public posts with photos, tagged to a project) and the Spaces tab with Needs you. |
| **Activity and push** | Work item assigned, done, checked or sent back. Join requests. Mentions. |
| **Basics** | Report and block, delete account, privacy settings, photo upload that copes with a weak signal. |

## 3. Not in V1 (after the pilot starts)
- Export a work item's record as PDF
- Approval codes
- Repeating work items
- Translate
- Phone and WhatsApp sign-in
- Jobs and hiring
- Company job management
- Community question Spaces
- Sponsored posts
- The paid plan
- CV import
- Connected accounts
- Explore beyond people search

## Plan to 1 February
| When | What |
|---|---|
| 16–31 Oct | Design finish (lead): Daybook components, the rest of the app in Daybook, notebook, direct messages, Arabic |
| 1–14 Nov | Database changes for the new scope, every rule enforced and tested on the server (review 33) |
| by 1 Nov | Founder enrols in the Apple Developer Program and Google Play Console |
| 15 Nov – 17 Jan | Build in 10 slices; the founder tests each on the emulator before the next starts: 1 daybook and the work item loop · 2 other kinds of post · 3 chat and direct messages · 4 people and Library · 5 opening a post in place · 6 walk mode and work items under one · 7 templates and daily report · 8 personal notebook and My calendar · 9 management report · 10 no signal and notifications |
| by 15 Dec | First Play closed test and first TestFlight build; safety line for slices not started |
| 18–24 Jan | Test week with 3–5 real people, then fixes |
| 25–31 Jan | Freeze: fixes only, backups ready |
| 1 Feb | Pilot starts |

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
- **A new Supabase project**, "BuildVibes MVP": Postgres, auth with email codes (sent through Resend from mail.aecox.com; Google and Apple later, phone codes after the pilot), storage, realtime.
  - Free tier while building; a paid plan from the pilot, for daily backups.
  - Every permission is enforced on the server with row-level security.
- **One component set.** Arabic uses Flutter's `Directionality`, so nothing is drawn twice.
- **Market pack as data.**
- **Photos queue and retry** on a weak site signal.
- **Measures from day one:** active Spaces, members per Space, work items closed per week, storage used.

## 6. Risks
1. **Scope pressure.** If the plan slips, Library preview and voice notes are cut first. Work items are never cut.
2. **Store review timing in December.** That's why submission is early and the last week is buffer.
3. **Some foremen and labour may not use email** (decision 04, risk accepted by the founder). Mitigations: most Android phones already have a Google account, so Google sign-in can be switched on; the Space admin can help people join on site; phone sign-in returns after the pilot if email proves to be a barrier.

## 7. The lead's queue to the pilot (updated 26 Oct)
In order. Each step is a review with Figma frames, then the founder's yes, then the build, a lead's check, and a test on his phone. The live status is in `docs/progress.md`.

| # | Step | Review | State |
|---|---|---|---|
| 1 | Notebook bugs B1–B6 (keyboard, edit in place, drafts, menus over the keyboard, ⋯, back by swipe), then one build on the founder's phone with 99A | 100 (D1–D13) | Claude Code is fixing them on `claude/r100-bugs` |
| 2 | The notebook redesign: one product language (tap, hold, swipe, ⋮⋮, ⋯), the selection bars, swipe for Pin · Reminder / Archive, compact cards, the new bar and `+` list, Filter, Share → Feed · Space · Message. With 99B's server work: Archive, Deleted items 7 · 30 · 90, the purge, share from an entry, filter kinds, a base version on `save_note` | 100 (Parts 0, 3–8) + 99B | Frames BH1–BH12 are waiting for the founder's ok |
| 3 | Figma tidy-up: the PG frames (title size, Arabic words, calendar icon) | — | Lead |
| 3b | **Linked folders in a Space's Library** (founder, 28 Oct: **before the pilot**).
- **Linking:** a member links a folder from their own account. It is visible only to them, and opens through their own sign-in.
- **Sharing:** they share a folder or single files with the Space when their pass allows adding files. Shared files open directly from the source, with no copy in our database.
- **Records:** a work item pins the version it used. Unshare at any time. "Unavailable" shows when the sharer's access ends; files already opened are cached on the phone.
- **Services, in order:**
  1. OneDrive/SharePoint (Microsoft Graph, a Microsoft app registration);
  2. ACC (Autodesk Platform Services);
  3. Google Drive, only if Google's security review for folder access passes in time; otherwise file-by-file picking.
- A company's IT or ACC admin may have to allow BuildVibes once on their side. | new (103) | Lead writes the review and frames; the founder asks the pilot company which service they use |
| 4 | **Scan documents** (founder, 26 Oct): the phone's own scanner (Google's on Android, Apple's on iPhone), with a normal photo as the fallback (Huawei); multi-page PDF. In the notebook's 📎, as a work item's proof, as a file post, in the Library. No text reading (OCR) yet | new | To write |
| 5 | Dates and reminders as chips inside a line; drag lines on phones (hold and move; hold and let go selects) | new | To write |
| 6 | **One gesture map for the whole app** (founder, 26 Oct), proved on the notebook first, then rolled out in order: Messages (swipe to reply, hold to select, as WhatsApp) → the Spaces list → work item cards → the feed last, or not at all. A swipe never does a formal or shared action: signing, Checked and Send back stay on Hold to confirm | new | To write |
| 7 | The Space's feel: tap a card to open it full screen and swipe item by item; Needs you one at a time; a long-press card popover; Discard with Undo | new | To write |
| 8 | Databases and colours in the notebook (review 98's step 4) | later | Only if 1–7 are done by mid-December; otherwise after the pilot starts |
| 9 | Sentry crash reports, about 2 weeks before the pilot (mid-January), with the app review | — | Planned |
| 10 | The stores: Apple enrolment, Codemagic, exact alarm and data safety forms; first Play closed test and TestFlight by 15 December | — | The founder's enrolment is open |
| 11 | Test week with 3–5 real people (18–24 January), then the freeze (25–31 January) | — | Planned |

**Ideas the founder raised, for after the pilot (28 Oct, no decision yet):**
- **Shimmer loading** on the feed's placeholder cards.
- **Dark mode** that follows the phone's setting, with no switch.
- **Hero animations** for photos and cards.

**Parked (not before the pilot):**
- the celebration feature;
- the promo motion reel and the designer brief;
- reading the text in scans (OCR) for Arabic.
