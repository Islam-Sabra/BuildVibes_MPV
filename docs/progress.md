# MVP progress

Target: pilot live on **Fri 1 Jan 2027**. Weeks start on Sunday.

## Status
| Week | Dates | Plan | Status |
|---|---|---|---|
| 1 | 11–17 Oct | Audit the old app. Set up the new app, backend and repo. Data model and permission rules | Audit done. Flutter project, dependencies, fonts, theme, English/Arabic and the 5-tab shell done. Review 01 applied and pushed. Components done. Supabase linked; migrations 1 and 2 live |
| 2 | 18–24 Oct | BV components in Flutter. Sign-up and sign-in (phone, Google, Apple, email code) | Components done (week 1). Sign-up, sign-in and onboarding done; Google/Apple built but hidden until keys; email codes wait for an email sender |
| 3 | 25–31 Oct | Profile, project records, "Is it already here?", Add to my CV | Done early (11 Oct) |
| 4 | 1–7 Nov | Spaces: create, link a project, invite link and code, join requests, passes, Teams | — |
| 5 | 8–14 Nov | Work items: create, Needs you, sign as done with a photo, check or send back, filters | — |
| 6 | 15–21 Nov | Space chat (live), item cards in chat, Library and file preview | — |
| 7 | 22–28 Nov | Home feed and posts, Spaces tab, Activity, push notifications | Done early (13 Oct): feed and posts, Home Spaces tab, Activity, push live on Android (migrations 12–14) |
| 8 | 29 Nov–5 Dec | Arabic pass, market pack, privacy, report and block, delete account | — |
| 9 | 6–12 Dec | Internal test with 3–5 people. Fixes | — |
| 10 | 13–19 Dec | App Store and Google Play submission | — |
| 11 | 20–26 Dec | Pilot prep with the pilot Space admin | — |
| 12 | 27–31 Dec | Buffer | — |

## Live Supabase settings (project vnlkthmdoczlyhxpdkux)
What is set on the live project today. The source of truth is `supabase/config.toml`; nothing here is changed without the founder's yes (review 03).

| Setting | Value |
|---|---|
| Sign-ups | Allowed. New accounts by phone only for live-market numbers or a Space invite (hook `hook_before_user_created`) |
| Email | On. 6-digit code, valid 10 minutes, 1 minute between codes, confirmation required. Sender: Resend SMTP, `BuildVibes <no-reply@mail.aecox.com>` (saved by the founder, 11 Oct). Code email in English and Arabic (no link) applied 11 Oct with the founder's yes. Limit 60 emails an hour (founder's yes, 11 Oct) |
| Phone | On, for the test numbers only (founder's yes, 11 Oct). Supabase's "phone sign-ups" switch turns the whole phone provider off, which also locked out the test accounts. The app shows email only; the hook blocks numbers outside live markets; the placeholder Twilio account sends nothing. **Turn off before the pilot.** |
| Test phone numbers | +965 50000001, +965 50000002, +965 50000003, +20 1000000001, +91 9800000001 — code 123456 |
| Google, Apple, LinkedIn | Off |
| Redirect URLs | `com.buildvibes.buildvibes://login-callback` |
| Authenticator app (MFA TOTP) | On (restored) |
| Migrations applied | 1 market pack, 2 people and companies, 3 sign-up gate and onboarding, 4 profiles and projects, 5 email sign-in, 6 Spaces (all pushed with the founder's yes, 11 Oct), 7 work items, 8 work item follow-ups and Work you delivered, 9 chat and Library, 10 review 11 follow-ups, 11 chat and Library follow-ups, 12 feed, 13 Activity (founder's yes, 12 Oct), 14 push, 15 safety, 16 account, 17 market pack (founder's yes, 13 Oct), 18 daybook core, 19 other kinds of post (founder's yes, 15 Oct), 21 notebook and My calendar, 20 pages, templates, reports and search, 22 direct messages (founder's yes, 16 Oct) |
| Edge Functions | `push` (FCM HTTP v1) and `report-alert` (Resend), both `verify_jwt = false`, deployed 13 Oct with the founder's yes. `push` redeployed 15 Oct (version 5) with the migration 19 texts, and 16 Oct (version 6) with the direct message texts, each with the founder's yes |
| Function secrets | `FIREBASE_SERVICE_ACCOUNT` and `RESEND_API_KEY` (pasted by the founder), `PUSH_WEBHOOK_SECRET` and `REPORT_ALERT_SECRET` (generated, never printed), `ALERT_FROM` (the sign-in code sender). Names only here |
| Vault | `push_webhook_secret` and `report_alert_secret` (the same values as the function secrets) |
| Extensions | `pg_cron`, `pg_net` (13 Oct, for push) |
| Push wiring | Trigger `push_queue_call` on `push_queue` inserts (`supabase/ops/push_webhook.sql`); cron `push-retry` every minute and `push-prune` at 02:30 UTC (`supabase/ops/push_cron.sql`); all run 13 Oct with the founder's yes; cron `activity-reminders` every 5 minutes (`supabase/ops/activity_reminders_cron.sql`, 15 Oct with the founder's yes) |
| Account | Migration 16 live (13 Oct, founder's yes). Support email `support_email` set by SQL for both packs (Kuwait, Egypt); legal links empty until the pages are hosted. `account-purge` not deployed and `supabase/ops/account_cron.sql` not run: each waits for its own yes |
| Report alerts | Trigger `reports_alert` on `reports` inserts (`supabase/ops/report_alert_webhook.sql`), run 13 Oct with the founder's yes. Kuwait's moderation address is set in `market_moderation` by SQL (the founder's support alias; not in git). The founder moderates with `supabase/ops/moderation.sql` |
| Test accounts | `push-test-a@example.com` (Test Receiver), `push-test-b@example.com` (Test Follower), `push-test-c@example.com` (Test Third), made with the admin API for the push test (13 Oct); push-test-a's test post was reported and removed in the report-alert test. "Delete Test", a sign-up on a founder's Gmail alias (address kept out of git), for the S13 live test (13 Oct). **Delete all four before the pilot** |
| Storage | Bucket `avatars`: public read by link, each person writes only in their own folder |

## Log
- **11 Oct:**
  - Prototype signed off by the founder.
  - Old app audited (`docs/product/codebase-audit.md`). Decision: clean app here, porting proven parts.
  - Added `CLAUDE.md`, the product docs and `lib/core/design/bv_tokens.dart` (from the Figma variables).
  - Supabase project: `buildvibes-MVP`, ref `vnlkthmdoczlyhxpdkux`, region South Asia (Mumbai) ap-south-1, Free plan (Nano). Upgrade to a paid plan before the pilot for daily backups.
  - GitHub repo: https://github.com/Islam-Sabra/BuildVibes_MPV (private). `.gitignore` keeps `env/*.json` (Supabase keys) out of git.
  - Tasks 2–6 done, one commit each:
    - Dependencies added.
    - Fonts copied from the old app and registered (`PlusJakartaSans`, `NotoSansArabic`, weights 400–700).
    - `lib/core/theme/bv_theme.dart`: theme built only from the tokens; `BvTheme.forLocale` picks the Latin or Arabic type set.
    - Localisation: `l10n.yaml`, `lib/l10n/app_en.arb`, `app_ar.arb` (generated code in `lib/l10n/gen/`). App language follows the phone (English fallback) until chosen in Profile → App language; the choice is saved on the phone.
    - App shell: `go_router` with 4 tab branches (Home, Explore, Activity, Profile) and Create as a centre action that opens a sheet. Bottom bar is `lib/shared/widgets/bv_bottom_bar.dart`. Tabs are placeholders.
    - 13 tests pass, including the bar in English (left to right) and Arabic (right to left).
  - Review 01 (`docs/reviews/2026-10-11-01-app-shell.md`) applied:
    - Icons are Phosphor regular through `lib/core/design/bv_icons.dart`; no Material icons left. Only arrows and carets mirror in Arabic. The Phosphor font is bundled in `assets/fonts/` because `phosphor_flutter` 2.1.0 (the latest) doesn't compile on Flutter 3.44.
    - Bottom bar matches the Figma component `2022:18`: 64 high, 72×56 slots, orange indicator above the active icon, ink active colour, same label weight, Create button 40×28 in `actionPrimary`. Sizes are in `BvBottomBarSize` in the tokens file.
    - Arabic tab names: استكشف and ملفي.
    - 17 tests pass.
  - Task 7 done: the shared components from `docs/product/components.md`, in `lib/shared/widgets/`:
    - BvButton, BvChip (+ BvChipRow), BvTabs, BvTextField (+ BvSelect, BvPhoneField, BvCodeField, multi-line counter), BvSearchField, BvSwitch / BvCheckbox / BvRadio, BvListRow (+ BvListGroup), BvChoiceCard (+ BvChoiceList), BvAvatar (+ BvProjectAvatar), BvBadge, BvBottomSheet (`showBvSheet`), BvStamp, BvSiteTag, BvSignOffStrip, BvWorkItemCard, BvPassCard, BvSitePhoto.
    - All measurements are in `lib/core/design/bv_specs.dart`; widgets have no raw numbers.
    - The language sheet and Create sheet now use BvBottomSheet; the language choice uses BvChoiceCard.
    - Debug builds only: Profile → Components opens a gallery of every component in every state (`lib/features/dev/`). Sample photo in `assets/dev/`.
    - 103 tests pass; each component is tested in English and Arabic.
    - Choices made while building: Arabic text has taller lines, so field padding is worked out from the line height to keep fields 48 high; when a work item's reference and status don't fit on one line (long Arabic dates), the status wraps to a second line instead of being cut; phone and code fields are always left to right; Arabic and Persian digits typed into number fields become 0–9.
  - Review 02 applied (Arabic sample text: الفريق الإنشائي / إنشائي; SELECTED stamp is مختار).
  - Task 8 started:
    - Supabase CLI set up; this folder is linked to `vnlkthmdoczlyhxpdkux`. Local ports are 5632x so they don't clash with the old app's local projects (5432x, 5532x).
    - Migration 1 (`supabase/migrations/20261011120000_market_pack_reference.sql`): markets, places, role families, trades, market trades, company kinds, project types. Read-only for the app. Kuwait (live) and Egypt (soon) seeded. Values a local must confirm are flagged in the data: `markets.needs_review` lists the fields; places and some local trade names have `needs_review = true`.
    - Migration 2 (`…120100_people_companies.sql`): profiles (created by a trigger on sign-up), profile_private, experience, follows (counts kept by a trigger), blocks, companies (only via `register_company`), company_admins. RLS on every table; column grants stop the app from setting counts, phone or `verified`.
    - SQL tests in `supabase/tests/` (61 checks, run with `supabase test db`): signed-out access, owner-only rules, blocks both ways, experience visibility, company admin rules.
    - Both migrations pushed to the project and checked through the live API: markets readable signed out, profiles not.
    - App connected: `initSupabase()` in `main.dart` reads `env/dev.json`; `MarketRepository` reads the market pack. The gallery's phone field now shows the live dial code.
  - Founder to confirm: Egypt is set to "soon" (shown but not live) and Kuwait to "live".
  - Figma entry screens E1–E10 downloaded to `docs/design/entry/` (with README).
  - Task 9 done: sign-up, sign-in and the short onboarding.
    - Screens: E1 Welcome, E2 Join, E2p Phone, email entry, E3/E3e Code, E9 About you, E9b Your role, E10 People to follow, plus the guest join wall (H7) and a loading/offline screen. Router gate: signed out → Welcome; new account → About you; done → Home; guests browse the tabs.
    - Phone: any country code. New accounts open for live-market numbers (Kuwait) or anyone with a Space invite; Egypt numbers see "coming soon"; existing accounts always sign in. Enforced on the server too: migration 3 `hook_before_user_created` (Supabase Auth hook). Invite codes become valid with migration 4.
    - Email: 6-digit code, never a password.
    - Google and Apple: built (OAuth with the deep link `com.buildvibes.buildvibes://login-callback`), hidden until `SOCIAL_SIGN_IN` is true. LinkedIn not in the MVP.
    - Migration 3: sign-up gate, role groups as in E9b, trade descriptions, popular trades per market, home market must be live. Pushed.
    - Auth settings pushed from `supabase/config.toml`: phone sign-in on, test numbers (+965 50000001–3, +20 1000000001, +91 9800000001, code 123456), 6-digit email codes valid 10 minutes, a 1-minute wait between codes. Phone sending uses a placeholder Twilio account until the real provider is chosen.
    - Incident: an early `supabase config push` I meant as a preview applied the local defaults to the project (the CLI auto-answers "yes" for agents). No users were affected; every value was then set on purpose and the CLI is now run with `--agent no` for previews.
    - Fixes found on the emulator: lists came back in reverse order (the Supabase client sorts descending by default); the company link in profile queries was ambiguous; Arabic lines with Latin parts (numbers, emails, company names) now keep their order; Latin words in Arabic text use Plus Jakarta Sans; initials skip "Al-"/"El-".
    - 192 Flutter tests and 77 SQL tests pass. Screenshots of every screen in English and Arabic are in `docs/screens/` (not committed).
  - Founder to decide:
    - An email sender (SMTP) so email codes work: Supabase's free built-in sender can't send codes, only links.
    - The real phone code provider (WhatsApp or SMS), before the week 9 test. When it is set, make the SMS code last 10 minutes to match the screen text.
    - Google and Apple provider keys.
  - Review 03 applied: audience card wording, onboarding skips an empty step 2, live settings listed above; changing live settings now always waits for the founder's yes.
  - Task 10 done: profiles and project records (design: `docs/design/profile/`).
    - Own profile (R1): header with follower counts, proof card (each CV project Confirmed or Waiting, no totals), Finish your profile, Open to, About, Projects, Experience, Work you delivered (empty until week 5), tabs. Settings moved behind the gear (language, sign out, Components in debug).
    - Visitor profile (R5): Follow / Following, "…" with Block (asks first). Only what the person chose to show. Message, recommendations, credentials and the CV PDF are not in the MVP and are left out.
    - Edit profile (R8): name, photo and headline (photo upload, role, company, city or area); About; Experience (months, Everyone / Connections only / Only me); Projects (show or hide each); Open to.
    - Projects: "Is it already here?" (P13) → "This is it · add to my CV", or a new record (P14, title block) → Add to my CV. Project sheet (PJ1): title block, your CV entry, people who show it, Suggest an edit (PJ1-E, stored for back-office review).
    - Migration 4: profile_open_to, projects (created only by `create_project`, no edits from the app), project_edit_suggestions, cv_projects, cv_project_confirmations, `find_similar_projects`, avatars bucket. Projects keep months (the design shows "Mar 2023"), not only years.
    - Share profile is built but hidden until a web page opens shared profiles (founder decision).
    - Fixes found on the emulator: Open to save was refused (upsert wrote a locked column); CV people query was ambiguous; places listed with each city's areas ("Salmiya · Hawalli"); a signed-in, onboarded person could land on About you after signing in; English text written by people now keeps its punctuation in the Arabic app; save errors are now shown.
    - 237 Flutter tests and 109 SQL tests pass. Screenshots in English and Arabic are in `docs/screens/` (not committed).
  - Decision 04 applied in the app (sign-in by email code only):
    - E2: "Continue with email" is the main button; "Use email instead" is gone. Phone screens stay in the app behind the `phoneSignIn` flag (off).
    - E9: country from the device region ("You can change it in Settings."); no recovery email; an optional, private mobile number instead (only you can read it).
    - Invited people may choose any home country; everyone else a live market. Migration 5 enforces it on the server (pushed with the founder's yes).
    - `supabase/config.toml` holds the intended live values: Resend SMTP, the code email in English and Arabic, 60 emails an hour, phone sign-ups off. Code email and phone sign-ups off applied live with the founder's yes; the founder's Resend settings were not touched.
    - Review 05 (profiles) passed with no changes.
    - 249 Flutter tests and 121 SQL tests pass.
    - Live check: real code emails reach the founder's Gmail inbox (Updates tab, not spam), and the code signs in. Email limit raised to 60 an hour (founder's yes). New screenshots of E2, E3e and E9 in English and Arabic are in `docs/screens/` (not committed).
  - The lead (working from GitHub while the founder's computer was off):
    - Review 06 (`docs/reviews/2026-10-11-06-spaces.md`): the Spaces build brief for week 4. Figma frame list in `docs/design/spaces/README.md`; the 24 PNGs are now in that folder.
    - Branch `spaces-db`: migration 6 (Spaces, invite codes, join requests, passes, Teams, proof from linked Spaces) and `supabase/tests/06_spaces.test.sql`. All 212 SQL checks pass on Postgres 16. An independent review found 8 issues; all were fixed except "proof from a second account", which is a founder decision. Not pushed to the live project.
  - Spaces part 1 (review 06): My Spaces, the empty state, Enter an invite code, the waiting card, New Space and Invite people.
    - Home has Feed | Spaces tabs (each half the width, as in H1e). Spaces shows My Spaces until week 7; the header has Create. The Create sheet has New Space and Enter an invite code.
    - Code sheet: 6 characters, Latin, left to right, upper case; Arabic digits and pasted "K7Q 4MD" work. Shows the Space and "Invited by {name}" from the live server, then Ask to join. Wrong code, too many tries, already a member and declined each have a plain message.
    - Waiting card with Cancel request; "Not confirmed" with Dismiss (kept on the phone only; no reason, no name).
    - New Space (S5): Name, About, Link a project (your CV projects, or Add a project through P13). The preview shows "Private work", never a member count. Create opens the Space on People with Invite people on top.
    - Space screen: header and the Work · Chat · People · Library bar (S7k). Work, Chat and Library show "being built" (weeks 5–6); People gets its content in part 2.
    - Invite people (S16, MVP): the code on a site-tag card ("M8M FTW"), "Works until", Share code (the phone's share sheet) and, for admins, New code (asks first).
    - New shared parts: BvCodeTag, BvBadge "action" tone, a badge at the end of a list row, filled tabs, the bottom bar without Create.
    - share_plus added. Its file-path helper's newest Android and iOS parts need native build hooks that fail when the Flutter folder path has a space; pubspec pins the previous releases (see the note there).
    - Checked on the emulator with the live project: Omar created two Spaces, Sami asked to join "Salmiya Clinic - MEP Team" with the code, and Omar's My Spaces shows "1 needs you". A first test Space ("Harbour Tower - Site team") was created by a mis-tap without a project; it stays as test data until Delete Space (part 3).
    - 283 Flutter tests and 212 SQL tests pass. Screenshots (English and Arabic) in `docs/screens/`: H1e, S1, code sheet, waiting card, S5, S5 link a project, S16.
  - Review 07 applied: ink crane on S1 rows, the "needs you" badge is a full pill (other badges keep radius 6, as components.md says), no chevrons on S1 rows, the invite code field opens in capitals with no autocorrect.
  - Spaces part 2 (review 06): People, Confirm with a pass, Decline with Undo, and the member pass.
    - People (S10k): search, "Requests to join · you confirm" (admins only) with who, when ("2h ago") and whose code, then Owners and Members with their pass and Teams.
    - Confirm (S10k-C): three passes, nothing chosen first, then "Confirm as {pass}". It opens the new member's pass with "{name} joined as Crew".
    - Decline (S10k-D): "{name}'s request declined. They aren't told why." with Undo.
    - Member pass (S17k, S17k-b): the pass band and stamp ("CREW PASS · CUSTOM" in ink when changed), what the pass opens with Open / Lock for files, create, check and invite, Change pass, Teams, Make admin (the last admin can't step down) and Remove from Space (asks first). Members see it read-only. Rights come from the server (member_rights); the app has no copy of the pass presets.
    - Copy is gender-neutral in both languages (Figma says "him", "his", "He isn't told why").
    - Checked live on the emulator: Omar declined Sami and undid it, confirmed Sami as Crew, opened and locked rights, and Sami's Kuwait City Tower project on the profile changed from Waiting to Confirmed.
    - 305 Flutter tests and 212 SQL tests pass. Screenshots (English and Arabic) in `docs/screens/`: S10k, S10k-C, S10k-D, S17k, S17k-b, S10k-E (Arabic), and the confirmed proof.
  - Spaces part 3 (review 06): Teams, New Team, Space info with its sheets, Leave, Transfer ownership and Delete.
    - People: a Teams section ("2 members · you're in it"; Team sizes inside a Space are fine, founder 12 Oct) and New Team for admins.
    - Team (S11k): "A Team in {Space}…" (Figma copy fixed), Add people, Rename and Delete for admins. Team chat waits for week 6.
    - New Team (S12): name (a taken name is refused), members picked from the Space, "Create Team · 2 people".
    - Space info (S15 v2k / S15b, private-Space wording): Access read-only, Invite people, Members ("Owners: … and you", opens People), Who can invite (S15k-I), Notifications (S15k-N), Transfer ownership, Delete Space, Leave Space. Admins edit the name and About. The Space header and "…" open it.
    - Transfer (S15d, S15e): pick a member, confirm in a dialog; you stay as a member. Leave (S15c) and Delete ask first in a dialog; the last admin can't leave.
    - New shared parts: BvDialog, red (destructive) list rows, user-plus and user-switch icons.
    - Profile proof rows now say who confirmed them: "Confirmed by Omar Haddad", or two names "and others" (never a count).
    - Checked live on the emulator: Omar added an About, created the MEP Team with Sami, deleted the test Space "Harbour Tower - Site team", transferred Salmiya Clinic to Sami and left it. Sami's profile shows "Confirmed by Omar Haddad". Review 06's emulator flow is complete.
    - 331 Flutter tests and 212 SQL tests pass. Screenshots (English and Arabic) in `docs/screens/`: S11k, S12, S15, S15b, S15c, S15k-I, S15k-N, S15d, S15e, the proof row, and the delete dialog (Arabic).
- **12 Oct:**
  - Review 08 part A applied: Arabic transfer title "نقل الإدارة إلى {name}؟"; the TEAMS chips on the member pass were checked live (they show once a Space has Teams).
  - Week 5 (work items), database: migration 7 on branch `work-items-db` (pushed to GitHub, **not live**, waiting for the lead's review). Review 08 rules 1–12: Open → Done → Checked or sent back with a reason, functions only, append-only events, no self-check, KCT-001 references, needs_you(), public_shown_work, private bucket `space-files`. `supabase/tests/07_work_items.test.sql`: 65 checks; 277 in all.
  - Week 5 part 1, app, on branch `work-items` (built on `work-items-db`, so main keeps matching the live project): the Work tab (S20). Project title block and privacy line, filters All · Mine · Open · To check · Checked, sections Needs you / Open / Checked this week, work item cards with the action the server says is yours (needs_you), New item for people who can raise items, empty states. My Spaces' "N needs you" now counts work items too. W2 and W3 are placeholders until part 2.
  - Screenshots use the local Supabase on this computer (migration 7 isn't live): `env/local.json` (git-ignored), a debug-only Android setting for plain http to 10.0.2.2, and `supabase/dev/seed_work_items.sql` for test data.
  - 346 Flutter tests and 277 SQL tests pass.
  - Review 09 applied (migration 7 is still not live; ready for the lead's re-check on `work-items-db`): photos must be real uploads of the caller's, in the item's folder, and can never be replaced; only an item's creator or owner uploads (never a Viewer); reassign and "Owner left · reassign"; the public photo is the owner's Done photo; blocks, deleted accounts and deleted Spaces hide shown work; a pass changed to Viewer can't sign; cascades and the service role pass the append-only rule. 97 checks in `07_work_items.test.sql`, 309 in all. Work tab: the list's bottom padding clears New item; the "Owner left · reassign" row. 350 Flutter tests pass.
  - Week 5 part 2 (branch `work-items`): New work item (W2) and the item page (W3a–g).
    - W2: the photo first (camera, gallery as a fallback; about 1600 px, JPEG 80), stamped "{place} · {time} · You"; "NEW · KCT-006" from the Space's next number; title, Owner (never a Viewer), Due (No due date, Today, Tomorrow, a date), Place on site, Team; "{Owner} gets it in Needs you…". Voice note and attachments are hidden until week 6.
    - Weak signal: the photo is copied into the app's folder at once; the item waits in an outbox on the phone; uploads use a new name every try (3 tries); if it still fails, the Work tab shows "Not sent yet" with Retry. Nothing is lost.
    - W3: the site tag (with the tilted CHECKED stamp once closed), the banner for each state and role (to check, waiting, done, closed, sent back with its reason, owner left with Reassign), evidence photos on signed links, the sign-off strip ("You check it" while waiting), Discussion with comments, Reassign in "…", and the action buttons. Sign as done, Check and close and Send back open in part 3.
    - Shared: the site tag's checked stamp; the sign-off step's "waiting for" text.
    - Checked live against the local server: Omar raised KCT-006 with a camera photo (uploaded under the review 09 rules), commented on KCT-002, and the pages show correctly for Omar and Rakesh.
    - 374 Flutter tests pass. Screenshots (English and Arabic) in `docs/screens/`: W2, W3a, W3b, W3c, W3d, W3e.
  - Lead re-check passed (review 10 part A). With the founder's yes: `work-items-db` and `work-items` merged into main, and **migration 7 is live**. The emulator points at the live project again; the debug-only http setting stays for testing unreleased migrations locally.
  - Migration 8 (review 10 follow-ups and "Work you delivered") on branch `work-items-followups`, **not live**, waiting for the lead's review. `08_work_items_followups.test.sql`: 33 checks; 342 in all.
  - To do before the pilot: a nightly cleanup of loose photos older than 7 days. SQL can't delete storage files, so it needs a scheduled Edge Function calling the Storage API with `orphan_space_files()`; deploying it is a live change for the founder's yes.

  - Week 5 part 3 on branch `work-items-part3` (built on `work-items-followups`): review 10 part B and the rest of the work item flow.
    - Review 10B: the large CHECKED stamp (30 high, bold, −4°) on its own line above the title; the comment box is one pill that grows, with Send inside only when there is text.
    - W4 Sign as done: photos (up to 6) and/or a note; "Your name and the time go on the sign-off." Sent through the outbox, so a weak signal keeps it on the phone with "Sign-off not sent yet · Retry".
    - W5 Send back: one reason (single choice), a note (needed for "Other").
    - Check and close: asks first, then the Closed banner.
    - Owner's "Show on my profile" switch on a Checked item; Discussion shows "Reassigned from A to B".
    - Profile: "Work you delivered" shows the items the person chose (up to 4) and "See all" for the owner; RE2 (every Checked item, hidden until switched on) and RE1 (the public view: title, photo, place, project, who checked it; never the reference, the Space or the discussion).
    - Fixes from the emulator run: no pin or place chip when there is no place; a quiet dash for no due date; the dialog's short "Close it" button; the RE1 stamp hugs its label.
    - Checked end to end on the emulator against the local server (migration 8): Omar raised KCT-006 with a photo for Rakesh, Rakesh signed it done with a photo, Omar sent it back (Not finished), Rakesh signed again, Omar checked and closed it, Rakesh showed it on his profile, and the public view shows only the allowed facts.
    - 392 Flutter tests pass. Screenshots (English and Arabic) in `docs/screens/`: W4, W5, the check dialog, W3d, RE2, RE1, the profile section.

  - Review 11 (lead): migration 8 passed. With the founder's yes, `work-items-followups` and `work-items-part3` are merged into main and **migration 8 is live** (all 342 SQL checks pass from an empty database first). The nightly cleanup is not scheduled (founder: not yet).
  - Review 11 part B:
    - The comment pill: 44 high, filled, no outline (the theme's borders and padding are switched off), 16 at the sides, Send inside on the end side.
    - The page no longer puts the cursor back in the comment box after a sheet or dialog closes.
    - Retaken in English and Arabic: no place (no pin), the pill empty and with text, the "Close it" dialog, and the closed item. The earlier shots that showed the old pin are moved to `docs/screens/old/`.

- **12 Oct, week 6 (review 12).**
  - The chat design images were downloaded to `docs/design/chat/`.
  - The lead's `chat-library-db` (migration 9, chat and Library) passes all 408 SQL checks on the Supabase tools. Checked on this computer:
    - the bucket now allows 25 MB, PDF and audio;
    - `messages` is in the Realtime publication;
    - Storage records the type and size at upload. The type is the one the app declares, limited to the bucket's list.
  - Merged into main. **Not live** (waits for the founder's yes).
  - Migration 10 (`20261012150000_review11_followups.sql`, review 11 A) on branch `review11-followups`, **not live**, for the lead's review. `10_review11_followups.test.sql`: 27 checks, 435 in all.
    - Needs you starts from the caller's memberships, and My Spaces runs it once.
    - The upload totals look only in the caller's Space folders, using Storage's name index; checked with 20,000 files. An index on `owner_id` isn't possible: Storage owns the table.
    - Cleanup claims: each file is re-checked under a lock and claimed. Nothing can then reference it. The job deletes through the Storage API.
    - Checked work drops the checker's name across a block.
    - App: an unsent item that waits longer than the cleanup uploads its phone copy again.
  - Week 6 part 1 on branch `chat-part1`, built on `review11-followups`:
    - the thread list (S7k): Everyone first, then Teams, with the last line, time and unread count;
    - threads (S8k, S9k): names and avatars, your messages on the end side, day dividers, replies with a quote, "Message deleted", live updates (Realtime), read marks;
    - work item cards: one full card per item (its newest step); older steps are one line with the reference;
    - the actions sheet (S8b/S8d): Reply, Copy, and Delete for the author or an admin;
    - "Not sent · Retry", kept on the phone.
  - Each message keeps its own direction, so an English message reads correctly in Arabic and the other way round.
  - Not in part 1: attachments (part 2), voice notes (part 3).
  - Copy changes:
    - S9k says "Only MEP Team and the Space admins see this thread" instead of "Only the 6 people…", because admins see Team threads too.
    - The S7k footer drops the direct-messages line (not in the MVP).
  - Checked on the emulator against the local server, with migrations 9 and 10 and `supabase/dev/seed_chat.sql`: thread list, threads, a live message from another account, reply, the actions sheet, Not sent with the network off, then Retry. The emulator stays on the local server, because chat isn't live.
  - 419 Flutter tests and 435 SQL tests pass. Screenshots in `docs/screens/`: `s7k_*`, `s8k_*`, `s9k_*`, `s8b_en_actions_own`, `s8d_ar_actions_admin`, `s8k_en_not_sent`.

- **12 Oct, migrations 9 and 10 live (founder's yes, review 13 A).**
  - Migration 9 was pushed and checked on live:
    - the bucket allows 25 MB, PDF and audio;
    - each existing Space has its Everyone thread and each Team its own thread;
    - `messages` is in the Realtime publication;
    - row-level security is on for all six new tables.
  - Then `chat-part1` (with `review11-followups`) was merged into main and migration 10 pushed.
  - EXPLAIN on live: the bucket has no files yet, so the planner reads the empty table once. Live has the same Storage name index and Postgres 17.11 as the local copy, where the folder search used the index with 20,000 files.
  - The nightly cleanup is not scheduled (founder).
- Review 13 B on `chat-part2`:
  - bubbles hug their text, up to 75%;
  - Everyone has the group icon;
  - a card as a thread's last message says what happened ("Rakesh marked KCT-004 done"; Arabic in noun form, gender-neutral);
  - the "Not sent" line wraps.
- Migration 11 draft (`20261012160000_chat_library_followups.sql`), **not live**, for the lead's review:
  - the cleanup never claims files younger than a day (review 13 A);
  - `share_library_file` for F1 "Share in chat".

  `11_chat_library_followups.test.sql`: 9 checks, 444 in all.
- Week 6 part 2 on `chat-part2`:
  - Chat:
    - the paperclip (only with the "add files" right) offers Take a photo, Photo from your phone, or a PDF from your phone (it goes to the Library too);
    - picked files show above the message box;
    - photos show in the bubble (one large, or a grid);
    - a PDF shows as a file card that opens F1;
    - files stay on the phone until sent, with "Not sent · Retry".
  - Library (S13k):
    - search, All · Files (PDFs); only the newest revision of each file;
    - each row shows "From chat" or Everyone / the Team, who added it, and the size;
    - Add file: a PDF or photo, its title (from the file name), who sees it (Everyone or one Team, one single choice), revision and note. Up to 25 MB.
  - Preview (F1), dark like the drawing table:
    - the PDF with pinch-zoom (`pdfx`, the phone's own renderer);
    - the CURRENT stamp, upload date, note, "Used in KCT-002 · …", and older revisions ("superseded, kept in the record");
    - Upload a new revision (keeps the Team);
    - Share in chat (a Team file only in its Team's thread);
    - Download (the phone asks where to save), and share through the phone.
  - W2-A: "Attach a drawing or file":
    - from the Library (only Everyone files and the item's Team's), from the phone, or a photo for the tag;
    - files are attached once the item exists, through the outbox.
  - W3: "ATTACHED", "Attach a drawing or file", and "DISCUSSION · ALSO IN THE TEAM CHAT", which opens the Team thread.
  - `pdfrx` was tried first, but its native build step fails with spaces in the Flutter SDK path, which broke `flutter test`. Replaced by `pdfx`.
- Checked on the emulator against the local server, in English and Arabic:
  - Rakesh (Crew) posted a photo and a PDF in the MEP thread; the PDF went to the Library as "From chat" (MEP Team);
  - the F1 preview shows the real PDF;
  - Omar (admin) added an Everyone file (a 26 MB file was refused);
  - Omar attached the chat PDF to KCT-002 (the picker offered only files that fit), then deleted the chat message: the PDF stays in the Library and still opens from KCT-002;
  - "Not sent · Retry" with the network off, then sent once;
  - Sami as a Viewer has no paperclip.
- 447 Flutter tests and 444 SQL tests pass. Screenshots in `docs/screens/` (`s13k_*`, `f1_*`, `addfile_*`, `w2a_*`, `w2_*`, `w3_*_attached`, `chat_*`, `s8d_en_actions_copy`, `chat_ar_not_sent`).

- Review 14 applied on `chat-part2`:
  - migration 11, fixed in place:
    - sharing a Library file needs the "add files" right;
    - deleting a message clears its file link;
    - 4 more checks, 448 in all;
  - "File removed" in a bubble whose shared file is gone;
  - toasts float above bottom actions (`BvToastSpec.lift`), never over "Add file" or the footer buttons;
  - Add file's title comes from the file name without the extension, with `_` and `-` as spaces.

  452 Flutter tests pass.

- **12 Oct: `chat-part2` merged into main, and migration 11 is live** (founder's yes; the push listed only `20261012160000_chat_library_followups.sql`). Checked on live: the file link on messages, sharing needs "add files", deleting a message clears the link, and the cleanup's one-day floor.
- Week 6 part 3 on `chat-part3` (app only; the server already takes voice notes since migration 9):
  - **Recording:** voice notes in Space chat, AAC in .m4a, one channel at 32 kbit/s (about 240 KB a minute):
    - the orange mic shows when the message box is empty, only for passes that may add files;
    - hold to record, release to send, slide away to cancel;
    - a tap says "Hold to record";
    - under a second isn't sent; it sends itself at 2 minutes;
    - a refused microphone says how to allow it.
  - **Playback:** inline, one note at a time, with progress and the length ("0:42").
  - Notes go through the outbox like photos ("Not sent · Retry").
  - **Bug found on the emulator and fixed:** the first hold asks for the microphone, and the thumb was already up when recording started, so it kept recording. Now nothing records unless the thumb is still down; the first hold only grants the microphone. A test covers it.
  - Android asks for the microphone (`RECORD_AUDIO`). iOS now has camera and microphone texts in `Info.plist` (the camera text was missing). Arabic texts for the iOS prompts need an `ar.lproj` in the Xcode project: to do with the App Store work (week 10).
- Review 15 on `chat-part3`:
  - a hold pauses a note that plays;
  - the app going to the background (a call, the home button, a locked screen) cancels a recording and pauses playback;
  - the length comes from a clock (`clock.stopwatch()`), not counted timer ticks; the 2-minute cap uses the same clock.

  Tests for each.
- Review 15 C screenshots (English and Arabic) in `docs/screens/`: `c1_*_recording`, `c2_*_release_to_cancel`, `c3_*_viewer` (no mic, no paperclip), `c4_*_hold_hint`, `c4_*_mic_refused`. 479 Flutter tests pass.
  - Checked on the emulator against the local server, in English and Arabic: recorded, sent (`audio/mp4`, 3.5 s, 18.5 KB on the server), played to the end.
  - 473 Flutter tests and 448 SQL tests pass. Screenshots: `chat_*_recording`, `chat_*_voice_sent`, `chat_ar_voice_playing`.

- **12 Oct, week 7 part 1** (review 16).
  - The week 7 Figma images are in `docs/design/home/`.
  - Migration 12 (`20261012170000_feed.sql`) is **live** (pushed 12 Oct with the founder's yes; the dry run listed only that file). Reviews 17 and 18 A are applied in place:
    - one reply level;
    - photo delete, the cleanup function and a 100 MB daily cap;
    - faster tagged-post and upload queries;
    - per-person locks on the rate limits;
    - strict photo types and paths;
    - no home section without a market, and the 30-day window kept in the cursor;
    - tags follow merge chains;
    - the cleanup keeps the claim of a post photo that still exists (review 18 A: `forget_cleanup_claims` looks in both buckets).

    `12_feed.test.sql`: 72 checks, 520 in all. EXPLAIN on live: the post upload check uses the Storage name index.
  - The app, on `feed`:
    - Feed (H1 v2): home market, "Beyond {market}", the rest; skeleton (H4), couldn't load (H5), offline with the page kept on the phone (H6), empty with Create.
    - Post card: project strip with its type (no invented phase), author, text in its own direction, 1–4 photos with a viewer, proof line (two names at most, no counts), Useful · Reply. Save and Share are hidden (decision 2).
    - Card menu: Mute with Undo for others' posts; Edit and Delete for your own.
    - Composer (C1–C3, C10, C13, L5–L6): Posting to, "Start from" templates, Media and Project only, the new audience line, the post language (detected, or chosen), Discard.
    - Posting outbox (P3, P3b): kept on the phone, Retry, posts once.
    - Post page (H10, H10c, H17, H13–H14, P6): replies one level deep, "Replying to {name}", delete your own reply, Post unavailable.
    - Profile → Posts (R12, R16) and the project sheet's posts.
    - The Create sheet gets "New post"; the full Create-tab change is in part 2.
    - The Arabic Feed tab is now "الأخبار" (the Arabic frame), not "الخلاصة".
  - Found on the emulator and fixed:
    - the reply box and composer footer were hidden under the keyboard (a test covers it);
    - after a template, the text box now takes focus;
    - the text box was indented further than the cards;
    - the photo remove buttons were oversized.
  - Checked on the emulator against the local server (`supabase/dev/seed_feed.sql`), in English and Arabic:
    - Rakesh posted with two photos and the project tag with the network off ("Couldn't post. Saved as a draft."), then Retry; it reached the server once (two photo rows, tagged);
    - Omar marked it Useful and replied;
    - the Arabic feed, composer, discard and post page.
  - 514 Flutter tests pass. Screenshots in `docs/screens/`: `h1_*_feed`, `c1_en_composer`, `c2_*`, `c10_en_tag`, `c13_ar_discard`, `p3b_en_failed`, `h1_en_posted`, `h10_*_post`.
  - Review 18 B, on `feed` (`feed-db` and `feed` merged into main first):
    - the 8 screen fixes: the feed card on the post page, no avatar circles, role and Useful on replies, short times, the network or project tile, the C13 words, Retry, composer sizes; the offline copy is kept per person;
    - Mute's Undo now brings the posts back (it used a closed screen's link before; checked on the emulator, since the test passes either way);
    - found while taking the screenshots, and fixed:
      - H5 now matches its frame (icon, heading, a line of help, an orange Try again);
      - P6 uses the crossed-out eye and the larger title, and is centred in Arabic too;
      - H14 says "Delete comment?" with a short "Delete" button (the long label was cut off);
      - English quotes and English typed in the reply box keep their own direction in Arabic;
      - your own reply's text no longer gets pushed in by its "…" button;
      - "Written in English" names the language in the app's language (مكتوب بالإنجليزية);
      - the project page's "POSTS" heading matches the other headings.
    - 518 Flutter tests and 520 SQL checks pass.
    - Review 19 A: the composer's language sheet (L6) has "Detected automatically" with the language it found, and the line "We use this to offer Translate to readers who don't read it."; the title is "Language of this post". Retaken: `c13_*_discard` (Keep editing), `p3b_*_failed` (Retry), `l6_*_composer_language`.
    - Screenshots (EN and AR) in `docs/screens/`: `h4_*_skeleton`, `h5_*_couldnt_load`, `h6_*_offline`, `h8_*_menu`, `toast_*_muted`, `h8b_*_own_menu`, `h11_*_delete`, `p2_*_edited`, `p6_*_unavailable`, `h17_*_replying`, `h10_*_own_reply`, `h13_*_reply_menu`, `h14_*_reply_delete`, `l6_*_language`, `r12_*_profile_posts`, `r16_*_their_posts`, `project_*_posts`, `c2_en_ready`, `c_ar_edit`.

- **12 Oct, week 7 part 2, database** (review 16 §3).
  - Migration 13 (`20261012180000_activity.sql`) is **live** (pushed 12 Oct with the founder's yes; the dry run listed only that file). Reviews 19 B and 20 A are in place:
    - `notifications`, written only by triggers (work item events, join requests, confirmed roles, follows, post replies, Useful), never to the actor, never across a block, Space news only to members; a declined request makes none;
    - `space_visits` and `mark_space_seen`;
    - `my_activity`, `mark_activity_read`, `unread_activity` (yes or no);
    - `home_day` and `today_in_spaces` for the H1b header and rows, with "today" from the phone's midnight.
  - `13_activity.test.sql`: 59 checks, 579 in all. Review 20 A: a repeat request merges only after a cancel, and comes back unread.
  - Review 19 B, fixed in place (still not live):
    - Useful rows keep no marker; their line names at most two people you follow;
    - asking to join again within a day, or following again within a week, adds no row;
    - post rows hide when you may no longer see the post; requests to join hide once you're no longer an admin;
    - speed on a Space with 20,000 messages: `today_in_spaces` 2 ms and `home_day` 4 ms (were 1.0 s and 2.0 s).

- **12 Oct, week 7 part 2, screens** (review 16 §3; `activity-db` and `activity` merged into main):
  - Home → Spaces (H1b): the date, "Your day on site", the summary line (each part hidden at 0), at most 3 Needs-you cards with Open and "See all", Today in your Spaces (5 rows, opens the tab where the change is), "That's your day". No Space: H1e as before.
  - The Spaces label and the Activity tab get an orange dot, never a number.
  - Activity (A1 v2): Needs you with overlines and Open / Check / Review request; Changes to your record for 7 days, grouped by Space, Your record, Your network, Your posts, with REV stamps and letters (filled while unread). Opening it marks it read. A2: the ledger and "Add a project you worked on".
  - My Spaces (S1) is its own page from the new Profile Spaces icon, with Create (New Space, Enter an invite code). The Create tab opens the composer.
  - Opening a Space marks it seen.
  - Review 20 C: every value put into a sentence (names, titles, refs, Spaces) is wrapped in Unicode isolates by the shared helpers in `core/l10n/bidi.dart`, so Arabic lines with English names read in order (Needs you, Today, Activity, chat cards, work item, Library and Space lines). H1b Today times read "3h ago" / "قبل 3 ساعات", "Yesterday" / "أمس". Screenshots retaken: `h1b_*_spaces`, `a1_*_activity`, `w_ar_item_lines`, `chat_ar_item_card`. 535 Flutter tests pass.
  - 532 Flutter tests pass. Screenshots (EN and AR): `h1b_*_spaces`, `h1b_*_thats_your_day`, `a1_*_activity`, `a1_*_activity_more`, `a2_*_activity_empty`, `s1_*_my_spaces`, `s1_en_create_sheet`, `r1_*_profile_spaces_icon`.

- **12 Oct, week 7 part 3, push** (review 16 §4).
  - The founder created the Firebase project "BuildVibes MVP" with the Android app; `android/app/google-services.json` is git-ignored.
  - Migration 14 (`20261012190000_push.sql`) is on `push-db`, **not live**, for the lead's review: phones, S3 switches, the queue filled by triggers (Space levels, switches, chat readers, block, 5-minute chat throttle). `14_push.test.sql`: 38 checks, 617 in all.
  - Review 21, in place (still not live): a deleted message's text leaves the queue; claim, finish and release so a repeated call sends once and FCM 429/5xx are tried again; retry every minute and prune nightly (`supabase/ops/push_cron.sql`, not run); only an error naming the token deletes it; the webhook secret checked in constant time, `verify_jwt = false`; the newest 10 phones per person; a push problem never blocks the step. `14_push.test.sql`: 56 checks, 635 in all; 7 function tests.
  - Review 22 A, in place: the insert trigger with the secret from Vault (`supabase/ops/push_webhook.sql`) instead of a dashboard webhook; SENDER_ID_MISMATCH is a failure, not a dead phone; 10-second timeouts on both fetches; the 5th failed attempt finishes the row and drops its text. `14_push.test.sql`: 58 checks, 637 in all.
  - The Edge Function `push` is written (`supabase/functions/push/`), **not deployed**; no webhook yet. Its text and links are tested with Node (`node --experimental-strip-types --test supabase/functions/push/message.test.ts`, 5 tests).
  - The app, on `push` (from `push-db`):
    - Firebase Messaging (`firebase_core`, `firebase_messaging`), the Google services Gradle plugin, and a notification channel named in English and Arabic.
    - The first time the tabs open after onboarding, the system prompt (Android 13+), once. Then this phone's token is registered in the app language, again when the token or the language changes, and removed on sign-out. Guests are never asked.
    - A tapped push opens its page (the item, the thread, People, the post, the person, your profile); links outside the app's pages are ignored. A push with the app open refreshes Home and Activity.
    - Settings → Notifications (S3): New followers, Replies, Show message text on lock screen (off), the Spaces line to My Spaces, and the footer. S4: "Push notifications are off" with Open phone settings, and the switches faded.
    - The Android app name is now "BuildVibes" (it was "buildvibes" in the system prompt).
    - Checked on the emulator: the prompt, a real FCM token registered on the local server, a follow queued a push (not sent: no function or webhook), S3, S4 and Open phone settings, in English and Arabic.
    - Review 21: a test proves a language change registers the phone again in the new language; retaken `push_en_permission` ("Allow BuildVibes") and `s4_en_push_off` (faded switches, centred title).
    - 549 Flutter tests pass. Screenshots: `push_en_permission`, `s3_*_notifications`, `s4_*_push_off`.

- **13 Oct, push live** (review 22, each step with the founder's yes):
  - Review 22 A: the insert trigger reads the secret from Vault (no dashboard webhook); SENDER_ID_MISMATCH keeps phones; 10-second timeouts; the 5th failed attempt finishes the row. 637 SQL checks.
  - Migration 14 pushed (the dry run listed only `20261012190000_push.sql`). The webhook secret generated and stored in Vault and as `PUSH_WEBHOOK_SECRET`, never printed. The `push` function deployed. The trigger and the two cron jobs installed; `push-retry` runs and succeeds.
  - Tested on the Android emulator with Google Play, signed in to the live project as push-test-a:
    - B followed A: the push arrived ("Test Follower started following you."), with no Space or project name; the tap opened B's profile;
    - with New followers off, C followed A: an Activity row, no push queued; then New followers back on;
    - B replied to A's post: the push arrived with the new notification icon (a white silhouette, tinted orange) and opened the post.
  - Screenshots: `push_en_notification`, `push_en_tap_profile`, `s3_en_followers_off`, `push_en_switch_off_no_push`, `push_en_notification_icon`, `push_en_tap_post`.
  - `push-db` and `push` merged into main.

- **13 Oct, week 8 part 1, database** (review 23 §2).
  - Migration 15 (`20261013120000_safety.sql`) is **live** (pushed 13 Oct with the founder's yes; see below). Reviewed by the lead in reviews 24 and 25: reports (hidden for the reporter at once), removals with a private copy and one appeal within 14 days, `block()` and `my_blocks()`, decisions for the service role only, and the moderation address per market (`market_moderation`, service role only).
  - `15_safety.test.sql`: 79 checks, 716 in all. Review 24, in place: a removed chat message hides its Library copy (restored on reverse); a reported reply leaves your Activity; the moderation address in a service-role-only table; NULL is never a decision; a double tap returns the same report; feed pages, Home's replies count and a message's files leave out what you reported; the photo cleanup waits for appeals.
  - The `report-alert` Edge Function is written (`supabase/functions/report-alert/`, 2 Node tests), **not deployed**. The alert trigger (`supabase/ops/report_alert_webhook.sql`) is not run. The founder's commands are in `supabase/ops/moderation.sql`.
  - The founder still owes the moderation address for Kuwait (review 23 §6.2); until it is set, no alert is sent.

- **13 Oct, week 8 part 1, screens** (merged into main with `safety-db`, 13 Oct):
  - The week 8 Figma images are in `docs/design/account/`.
  - The report reasons follow the R1 frame (Spam or scam, Harassment or abuse, Wrong or misleading, This isn't real, Shares private information, Something else); migration 15 uses the same ids.
  - Report (R1, a note for "Something else", R2 with Block this account) from: someone else's post, someone else's reply (the reply menu now shows for every reply), a person's profile, and a chat message (S8c).
  - Block: the dialog and the toast with Undo, from the profile and from R2. The copy promises only what blocking does (no messages in the MVP): "You won't see each other's posts or profiles, and follows between you are removed. They aren't told."
  - S7 Blocked accounts with Unblock (Settings → Blocked accounts until part 2 rebuilds Settings).
  - R3 removed notice, R4 appeal, R5 received, with "We'll look at it again"; Activity rows "Your post was removed" and the appeal's result, under Your record. "Read the community rules" waits for the legal pages.
  - Found and fixed: Block from R2 did nothing after reporting a post, because the card left the list and took the screen with it; the card now leaves when R2 closes (as the R2 frame shows it behind the sheet).
  - Checked on the emulator against the local server, in English and Arabic: Rakesh reported Omar's post, it left his feed, he blocked and unblocked Omar; the service role removed the post; Omar saw R3, appealed (R4, R5); the appeal was reversed and the post came back with its replies.
  - 565 Flutter tests pass. Screenshots: `r_*_post_menu`, `r1_*_report`, `r1b_ar_note`, `r2_*_report_sent`, `block_*_dialog`, `toast_*_blocked`, `s7_*_blocked`, `r3_*_removed`, `r3_en_appeal_open`, `r3_ar_removed_message`, `r4_*_appeal`, `r5_*_appeal_received`, `a1_en_removed_row`, `a1_en_appeal_result`, `a1_ar_removed_rows`.

- **13 Oct, safety live** (review 25 and the review 24 go-live, each step with the founder's yes):
  - Review 25 in place: R3 shows when the post was written; the photo cleanup re-checks open appeals under the lock; a note in `moderation.sql` about work item PDFs. 717 SQL checks.
  - Migration 15 pushed (the dry run listed only `20261013120000_safety.sql`).
  - Kuwait's moderation address stored by SQL; the pack's support email waits for part 2's migration (founder's choice).
  - `REPORT_ALERT_SECRET` generated into Vault and the function secrets, never printed; `ALERT_FROM` set; `report-alert` deployed; the alert trigger installed.
  - Checked first: the deployed `push` (version 3) is the same code as main, and `push-retry` runs without errors.
  - Test on live: push-test-b reported push-test-a's test post; the alert function answered "sent" and the founder received the email; `moderation.sql` removed the post, and push-test-a got the removal notice.
  - `safety-db` and `safety` merged into main.

- **13 Oct, week 8 part 2, migration 16** (reviews 26 and 27; **live** 13 Oct, merged into main):
  - `20261013130000_account.sql`: delete account (a fresh sign-in code; refused while you are a Space's only admin; hidden at once like a block; restorable for 30 days; then removed by the `account-purge` function), Download my data (`data_requests`, the founder's export script), `markets.support_email` and the deletion page link, and the 12-month report cleanup.
  - New, not run or deployed: `supabase/functions/account-purge/`, `supabase/ops/account_cron.sql`, `supabase/ops/export_my_data.sql`.
  - 63 new SQL checks (780 in all); 3 function tests.
  - For the lead: while hidden, follower counts and Useful counts still include the person (accepted in review 26, L3).
  - Review 26 applied (M1–M4, L1, L2, L4): a hidden account has no admin rights and can't write; deleting is locked per Space; proof and reports stay after a purge; the purge locks the profile and waits for the photos; the export holds all of the person's own data. 101 checks in `16_account.test.sql` (818 in all).
  - Review 27 applied (R1–R3): several purged confirmers can stay on one project, so every purge succeeds; a hidden sole admin can't leave; the deletion locks every Space the person is in. 106 checks (823 in all).

- **13 Oct, week 8 part 2, screens** (passed review 27; merged into main 13 Oct):
  - S1 v2 Settings: who you are, "Your settings, in words" (blocked accounts, the three push switches, language with the pack's week start and country), Account and security, Notifications, Privacy and safety, Language and region, Help and feedback (the pack's support email), About and legal (the pack's links), Sign out with the S15 dialog (code wording).
  - S2, S5 (Blocked accounts only), S8 (language as one choice; country from live markets; week start read-only), S10/S11 Download my data, S12 → S12b (transfer each Space first) → S13 (an email code, not a password) → S14 (the gate shows only Restore while deletion is scheduled).
  - "Former member" / "عضو سابق" wherever a Space message, work item, event or file has no readable person.
  - Checked on the emulator against the local database in English and Arabic (`docs/screens/S*_en|ar.png`), including S12b with a real only-admin and Restore. The S13 email code isn't sent locally (the local SMTP login fails); the server side is covered by the SQL tests.
  - Not drawn from the pack yet: S8's "Time format" row (the pack has no such field). For the lead.
  - 21 new widget tests (586 in all).

- **13 Oct, account go-live** (review 27, each step with the founder's yes):
  - Step 1: live Storage has no `objects_owner_fkey` (only `objects_bucketId_fkey`), so purging someone who uploaded Space files won't fail.
  - Step 2: migration 16 pushed (the dry run listed only `20261013130000_account.sql`); the migration list matches, 16 on both sides.
  - Step 3: `support_email` set for Kuwait and Egypt (2 rows).
  - Step 4: S13 on live with a new test account (custom SMTP confirmed by the founder in the dashboard): the delete code arrived and worked, S14 showed, the account was hidden and its phones signed out; after clearing the app's storage and signing in again with an email code the app opened on S14; Restore cleared the date, another account sees the profile again, and the phone registered for pushes again.
  - Step 5: `account-db` and `account` merged into main; 823 SQL checks, 586 Flutter tests.

- **13 Oct, Translate out of the pilot** (founder decision, review 28: the pilot spends no money; Google Cloud Translation asks for a prepayment):
  - Part 3 stopped. Branch `translate` (migration 17 `translate`, the `translate` Edge Function with a stand-in until a key exists, L1–L4 with tests) is pushed and kept, **not merged, not live, not deployed**. When Translate comes back, compare free tiers first (Microsoft Azure Translator is the first candidate).
  - The composer's language sheet (L6) no longer says it is used to offer Translate: one code setting, `AppConfig.translateEnabled = false`. Posts still record their language.

- **13 Oct, week 8 part 4** (reviews 28 and 29; migration 17 **live** 13 Oct; merged into main):
  - Market pack audit (`docs/market-pack-review.md`, for the founder to confirm Kuwait's values): no country fact is typed in Dart or the strings. One gap fixed: the pack's new `time_zone` (Kuwait Asia/Kuwait, Egypt Africa/Cairo), and the one-Useful-notification-a-day rule now counts the author's own day, not UTC's. Migration 17 `20261013150000_market_pack.sql`, `17_market_pack.test.sql`: 10 checks, 833 in all. If Translate comes back, its migration (on `translate`, `20261013140000`) is renamed after this one.
  - Arabic pass (`docs/arabic-strings.md`, 750 strings since week 4, for the founder to read): checked by script (all present, Western digits, glossary, placeholders, no gendered verbs for third persons). Fixed: «دعوة من {name}»; تكليف for "assigned" everywhere; بانتظارك in one help line.
  - Text size 1.3: every widget test can run at 1.3 (`flutter test --dart-define=BV_TEXT_SCALE_PERCENT=130`). It found text cut off in 7 places (Welcome cards, the dial code box, composer templates, badges, chips, the member pass stamp, the W2 header), all fixed with no change at normal size. At 1.3 no text is cut off; 22 tests still fail at 1.3 only because they look for rows that the larger text pushes below the screen.
  - Emulator screenshots (Arabic, and English and Arabic at 1.3): `docs/screens/AR-*`, `AR13-*`, `EN13-*`.
  - Review 29 applied: the lead's Arabic fixes (§1: meanings, no gendered verbs about another person, «مؤكَّد من», «مخطط», «إصدار», «قبل …», plurals for 11 and up, one tanween spelling «يومًا»); in migration 17, Kuwait mobiles may start with 41, and the founder's answers (six more Kuwait areas, 25 in all; the foreman chip «رئيس عمال (فورمن)»; no review flags left for Kuwait; Egypt stays flagged). 839 SQL checks. `AR-activity_ar.png` retaken.

- **13 Oct, part 4 go-live** (review 29 §3, each step with the founder's yes):
  - Migration 17 pushed (the dry run listed only `20261013150000_market_pack.sql`). Read back on live: Kuwait Asia/Kuwait, Egypt Africa/Cairo; Kuwait mobiles 5, 6, 9, 41; Kuwait 25 places, no flags; the foreman chip «رئيس عمال (فورمن)»; Egypt still flagged; the Useful day follows the author's time zone.
  - `arabic-pass` merged into main: 586 Flutter tests, 839 SQL checks. `translate` stays unmerged (review 28); its migration must be renamed after `20261013150000` if it comes back.

- **13 Oct, week 9 part 1: the nightly clean-up is on** (review 30 §1, each step with the founder's yes):
  - `ACCOUNT_PURGE_SECRET` generated into the function secrets and Vault (`account_purge_secret`), never printed; the temporary files deleted.
  - `account-purge` deployed; a manual run answered "purged 0, waiting 0"; a wrong secret gets 403.
  - `supabase/ops/account_cron.sql` run with the project ref filled in only in a temporary copy (deleted): jobs `account-purge` at 02:45 UTC and `reports-prune` at 03:00 UTC.
  - To check after the first night: `cron.job_run_details` for both jobs (status and time only).
- **13 Oct, week 9 part 2: release build** (on `release`, for the lead's review; **no build has gone to testers**):
  - Version 0.9.0+1; `env/prod.json` (git-ignored) with the live keys; no Components screen or debug banner in release.
  - Upload key made outside the repo (`BuildVibes keys` next to the project folder), passwords never printed; the release build signs with it and stops without it. The founder keeps two copies.
  - Firebase Crashlytics in release builds only, sending the error type and stack trace, never the message (no personal text). 2 new tests (588 in all).
  - A signed release APK builds (checked: signed by "CN=BuildVibes, O=AECOX Technology"). Steps for App Distribution and the iOS plan in `docs/release.md`.

- **13 Oct, week 9: release build merged and uploaded** (review 31):
  - UI errors are recorded as non-fatal; `release` merged into main.
  - Release APK 0.9.0 (1), from main at 9d96421, uploaded to Firebase App Distribution with the English and Arabic notes. **Not distributed**: the founder tests alone first, then adds group "week9" and says when.
  - Installed on two emulators (Pixel_8 and Pixel_8_B) for the founder's own test: his account on the first; on the second, the spare account "Delete Test" for join requests and checks.
- **13 Oct, week 9 part 3** (on `test-week9`, for the lead):
  - `docs/test/week9-test-script.md`: one page, English and Arabic, 10 tasks with Easy / Hard / Couldn't and one line each.
  - `supabase/ops/backup.ps1`: roles, schema and data from live into `D:\BuildVibes backups\YYYY-MM-DD\` (refuses a folder inside the repo). First backup made 13 Oct. Restore practised into the local database: every table count matched live; the local copy wiped after (`supabase/ops/restore_check.md`). Vault secrets, cron jobs, functions, Auth settings and Storage files are not in a backup; the restore notes list them.
  - `supabase/ops/pilot_measures.sql`: active Spaces, members per Space, work items opened and checked per day, storage used. Read-only, counts only, for the founder; never shown in the app. All four run on live.
  - **Pausing:** the free plan pauses a project after a week with no activity. Nothing is lost; it is restored from the dashboard. Watch for it in the gap between the test and the pilot.

- **14 Oct, the nightly clean-up's first run:** `account-purge` at 02:45 UTC and `reports-prune` at 03:00 UTC both succeeded.
- **14 Oct, end-to-end test** (on `e2e`, for the lead):
  - `integration_test/main_journey_test.dart` drives the real app on an emulator against the **local** database: Rakesh signs in and asks to join "E2E site" with its code; Omar confirms him as Crew and gives him a work item; Rakesh signs it as done with a photo, writes in chat and posts; Omar checks and closes it. Only the camera and the push prompt are stood in for.
  - `integration_test/run_e2e.ps1` refuses anything but the local stack, resets and seeds it (`supabase/dev/seed_e2e.sql`), waits for the sign-in service, runs the test, then checks the database (Crew pass, item checked with 3 steps, 1 photo, the message, the post). Passed three runs in a row, about 2½ minutes each, on its own emulator `Pixel_8_E2E` (the founder's two emulators keep the release app).
  - It found two bugs, both fixed with tests: unsent work items were shared by every account on a phone; and signing out on a lost connection threw an error. A third (phone sign-in before the market list loads) is noted for after the pilot. See `docs/test/week9-findings.md`.
  - 590 Flutter tests (2 new).

- **15 Oct, new MVP scope and pilot date** (founder decisions, review 32; docs only):
  - The pilot moves to **Monday 1 February 2027** (was 1 January), still four weeks with one real team.
  - New MVP scope per review 32: Work in full in the Daybook design (`docs/product/daybook.md`), Planning (the personal notebook and My calendar) and direct messages are in; the "still out" list is in `CLAUDE.md` and `docs/product/mvp-plan.md` §3.
  - The Space adopts the Daybook design; the rest of the app is being redrawn in it (16–31 Oct). Building waits for review 33 (the database changes and the slices).
  - The plan to 1 February (`docs/product/mvp-plan.md`, "Plan to 1 February") replaces review 30 §8's dates (first closed-test review and first TestFlight by 1 Dec; nothing after 20 Dec). Safety line: any slice not started by 15 Dec moves to after the pilot.
  - The founder keeps testing 0.9.0 (1); the emulators and the live app stay as they are.

- **15 Oct, migration 18, the daybook core** (review 33 A0 and A1, branch `daybook-db`; **not live**, pushing it needs the founder's yes and must list only `20261015120000_daybook.sql`):
  - The rule changes in A0: Crew post work; only the author checks or sends back (a Space admin when the author is gone or owns the item); only the author edits, deletes or cancels; Viewers can't add updates; no new work item cards in chat; `not_as_drawing` renamed to `not_as_asked`.
  - New tables `space_posts` (every existing work item backfilled with the same id), `post_edits` (append-only) and `post_files`; the functions `edit_space_post`, `delete_space_post`, `cancel_space_post`, `daybook_page`, `post_page`; `needs_you()` rewritten. Drafts stay on the phone. Team posts are seen only by the Team, the admins, the author and the owner, and that now covers the old work item tables too.
  - An independent review found 9 real problems; all fixed with tests (a deleted Team turned its posts into Everyone posts; an author lowered to Viewer could still edit; a Viewer could be given posting; an author waiting for account deletion froze their items; Cancel and Check at the same moment; paging skipped posts made at the same moment; the dev seed; weak tests).
  - The app: the reason rename and the retired "Check and close items" right (S17k row, Reassign for the author only). `docs/product/data-model.md` §5, §6, §7, §10, §13 and a new §14.
  - 971 SQL checks in 18 files, 590 Flutter tests.
  - **What changes for testers on 0.9.0 (1) when this goes live:**
    - Send back with "Not as per drawing" still works (the old name is accepted and stored as "Not as asked"; remove that once 0.9.0 is retired).
    - A Lead or admin who didn't write an item no longer sees Check or Send back on it, and it leaves their Needs you. Only its author checks it. An admin checks it when the author has left the Space or is deleting their account, or when the author gave the work to themselves.
    - Crew now see "New work item" and can raise work.
    - A Viewer who writes an update gets the "not allowed" message (the 0.9.0 field is still shown to them).
    - Reassign shows only to the item's author (the admins and Leads who had it through "Check and close items" lose it).
    - On a member's pass (S17k), the "Check and close items" row is always off; switching it does nothing after a refresh.
    - Raising, signing done, checking and sending back post no new card in chat; old cards stay.
    - Team work items disappear from the Work tab, Today and Activity of members outside that Team (admins, the author and the owner still see them).
    - An admin can't delete a Team that has work items; rename it instead.
    - Unchanged: raising (same fields), signing as done, photos, comments by the owner, Leads and Crew, Library, chat, feed and push.
  - **Review 34 applied (15 Oct):** only the author (or an admin acting for them) adds a work item under one (D1); an author lowered to Viewer or with posting switched off counts as gone, so the admin checks, sends back, reassigns and cancels for them (D2); a sole admin's work for themselves is checked by a Lead (D3); an old chat card for an item the reader can't see is a plain "Work item" line (L1). 988 SQL checks, 592 Flutter tests.
  - **15 Oct, migration 18 live** (founder's yes; review 35 approved): `daybook-db` merged into main (08770c5); `supabase db push` listed only `20261015120000_daybook.sql`. Read-only check on live: 0 work items and 0 posts (nothing to backfill), no work item without its post, `post_edits` and `post_files` empty, the chat-card trigger and its function gone, no old reason rows, row-level security on all three tables. The 0.9.0 (1) build on the emulators now talks to the new rules (see the list above); a new build from main is needed for the reason name and the pass screen.

- **15 Oct, migration 19, the other kinds of post** (review 33 A2, branch `post-kinds-db`; **not live**):
  - Checklists, announcements, scheduled activities and file posts: `create_space_post`, `tick_point`, `ack`, `post_acks_for` (the author sees who, never how many), `daybook_extras` (pinned and today's activities), `due_activity_reminders` (cron script written, not run). Tables `post_people`, `checklist_points`, `post_acks`, `activity_reminders`, `post_others`. `edit_space_post` edits points, people, the pin and the time. New notification kinds, and pushes for them and for edits and cancels.
  - The push function has the new texts in English and Arabic (in git, not deployed). Deploy it before migration 19 goes live, or the new pushes fail.
  - An independent review found 4 problems and 11 test gaps; all fixed (notices to people taken out of a Team, a readable "someone acknowledged" marker, Needs you for someone lowered to Viewer, a lock order between Cancel and a tick).
  - For the lead (review 36): ack faces are author-only as A2 says, though the prototype shows Received faces to others; "starts in 30 min" ignores a Space set to Off; On my way from 3 hours before; points on a work item are added by editing it.
  - 1,123 SQL checks in 19 files, 8 push function tests, 592 Flutter tests.
  - **Review 36 R1 (15 Oct):** Received faces on a file post for everyone who can see it; Got it, On my way and In my calendar stay with the author. 1,126 SQL checks.
  - **15 Oct, migration 19 live** (founder's yes; review 36 order): (1) `push` function deployed (version 5); (2) `supabase db push` listed only `20261015180000_post_kinds.sql`; read-only check: the five new tables exist with row-level security on, the app can't run the reminders or read `post_others`; (3) `activity_reminders_cron.sql` run, `cron.job` lists `activity-reminders` active every 5 minutes. `post-kinds-db` merged into main (59fb6f1).
- **16 Oct, migration 21, the notebook and My calendar** (written by the lead, review 37; follow-ups N1–N4 in review 38; approved in review 39):
  - Live with the founder's yes: `notebook-db` merged into main (788ab8e); `supabase db push` listed only `20261015230000_notebook.sql`. Read-only check: `notes`, `note_files` and `deleted_notes` have row-level security on, the app can't read `deleted_notes`, and bucket `notebook-files` exists and is private.
  - On the local stack the notebook test needed `storage.allow_delete_query` for its Storage delete (the cloud stand-in didn't); 1,227 SQL checks in 20 files.
  - Migration 20 goes live after it, never before.
- **16 Oct, migration 20, pages, walk mode, meeting notes, templates, reports and search** (review 33 A3, choices confirmed in review 39; branch `post-pages-db`):
  - Pages inside a post (blocks, saved by version), walk mode and meeting notes (one call, all or nothing), templates with the built-in Daily report, the daily and week reports, sharing a week report in chat, and search across posts, points, chat and Library names (Arabic letter forms folded).
  - A walk or meeting parent is a target: nobody signs or checks it and it never counts as proof (review 39).
  - An independent review found 14 problems and 8 test gaps; all fixed (an owner outside a Team walk got no push; a Team child's id on an Everyone page; a target signed early could still be checked; the week report's coming-up window; work item templates couldn't be used; search across line breaks and harakat in snippets; block ids; old references blocking a save; ids by case; a retry at the same moment).
  - 1,373 SQL checks in 21 files (146 for migration 20).
  - **Live 16 Oct** (founder's yes, review 40): `post-pages-db` merged into main (c96e125); `supabase db push` listed only `20261016120000_post_pages.sql`. Read-only check: `post_templates` has row-level security on and one built-in (`daily_report`); `space_posts` has `blocks`, `blocks_version` and `search_text`; Arabic splits into trigrams on live, so search uses its index.
- **16 Oct, migration 22, direct messages** (review 33 A5, founder decision F10, choices in review 41; branch `dm-db`):
  - Anyone can message anyone; someone with no work link lands in Message requests (reply opens it, Decline hides it quietly, Block stops it). Photos and files from someone new open with one tap. The spam guard warns at 40 new people who never replied and pauses new people at 50, from `app_settings` (changed by SQL, no release). Pushes: one per new person, and like chat in open threads. Reports, the purge, Download my data and the cleanup include direct messages. Files live in the sender's folder and are read through their message.
  - The push function has the new texts (in git, not deployed): deploy it before migration 22 goes live.
  - An independent review found 8 problems and 11 test gaps; all fixed (the sender could read the receiver's row, so a decline, read time and mute showed; the file delete rule compared the wrong column, so a sender could delete a live or reported message's file; the cleanup took a removed message's files during the appeal window; a promoted request could still blur or be declined; a purged side let an outsider through; a request push after 30 days; a double tap; each file once).
  - 1,488 SQL checks in 22 files (115 for migration 22), 9 push function tests.
  - **Review 42 (approved):** R1, the purge removes the person's direct message file rows, so the other person's thread lists no broken files and a message with no words left shows as deleted; R2, `ops/moderation.sql` lists a reported direct message's files. 1,490 SQL checks (117 for migration 22).
  - **Live 16 Oct** (founder's yes, review 42 order): (1) `push` function deployed (version 6); (2) `dm-db` merged into main (9258296), `supabase db push` listed only `20261016180000_dm.sql`; (3) read-only check: `dm_threads`, `dm_members`, `dm_messages`, `dm_attachments` and `app_settings` have row-level security on, `app_settings` has one row (`dm_unanswered_limit`) and the app can't read it, bucket `dm-files` exists and is private. The `orphan_dm_files` cleanup is scheduled later with the other cleanups, with its own yes.
  - With migration 22 live, review 33's database plan (A0–A6) is complete. Next: Part B, slice 1 (the Daybook and the work item loop).
- **16 Oct, slice 1 part 1a, Daybook components** (review 43; branch `slice1-daybook`, app only):
  - Tokens: ExtraBold (800), avatar tints and the small avatar sizes, the paper's radii, shadows and strokes, the light dim, the Send back icon.
  - Components in `lib/shared/widgets/`: torn-edge slip and its parts, ink stamp (lg/md/sm/xs, replaces the old large stamp), paper clip, spine and dots, masthead (full, compact, Home), day divider, post bar (and Viewer pass chip), month drop-down (first weekday from the market pack), day-one card, writing card and toolbar, writing menus, long-press menu with the dim, send-back card (small radio), give-to picker, undo bar.
  - Screenshots, EN and AR at 390×844: `docs/screens/slice1/ds-*.png` (run `flutter test test_screens --update-goldens`).
  - Not yet on the server, to settle before 1b/1d: a due time (only a date today), the Space's start date (day count), weather, undo of a check, a month RPC for the Space (days with posts, something due), the 12/24-hour time format in the market pack.

- **17 Oct, migration 23, Daybook extras** (review 44; branch `daybook-extras-db`, **not live**): an optional due time (`space_posts.due_at`; a timed item is late after its time), "On site since" (`spaces.site_start_date`, set only by a Space admin), and `daybook_month` for the month drop-down (dots, never counts). Undo of a check stays in the app (no server change). An independent review found 1 medium and 3 low problems and test gaps; all fixed (an edit resending the same date dropped the time; a ticked checklist lit its day; a timed item fell out of "coming up" past the reader's midnight; targets lacked the time). 1,563 SQL checks in 23 files (73 for migration 23). Going live needs the founder's yes and must list only `20261017120000_daybook_extras.sql`.
  - **Review 45 M1–M4 (17 Oct):** `daybook_page` returns entries (posts, sign-offs with their photos, note and outcome, updates), with one cursor; the checker's paper clip sits on the latest sign-off; the slip has its first Library files (with revisions) and the last "given to"; the month's dots count sign-offs and updates. Each event row now carries its `space_id`, so the page reads from indexes (about 50 ms a page on a Space with 3,000 items and 9,000 events). An independent review found no leak; its performance finding and test gaps are fixed. 1,612 SQL checks (122 for migration 23).
  - **Live 17 Oct** (founder's yes, review 46): `daybook-extras-db` merged into main; `supabase db push` listed only `20261017120000_daybook_extras.sql`. Read-only check: `space_posts.due_at` and `spaces.site_start_date` exist, `work_item_events.space_id` exists and is not null; `daybook_month`, `set_site_start_date` and the two entry helpers exist. No Edge Function change.
  - Weather is out of the MVP (founder, 17 Oct).

- **17 Oct, slice 1 part 1b, the daybook page** (branch `slice1-daybook`, app only; needs migration 23 live before it ships):
  - The Space's Work tab is now the daybook: newest at the bottom, day dividers, the masthead names the day in view ("day N on site" from "On site since", no weather), the month drop-down jumps to a day (dots from `daybook_month`), the Due today strip (from `my_calendar`), the Late line, day one, a Viewer's read-only bar. Times follow the phone's 12/24-hour setting.
  - Retired from 0.9.0: the Work list (W2) and the New item screen. W3–W5 stay until part 1d (Activity, Needs you, Home and chat still open them).
  - Local seed `supabase/dev/seed_daybook.sql` with the prototype's people and posts.
  - Screenshots: D1-daybook, L1-late-due-today, DY1-yesterday, DY2-calendar, DY3-day-one, V1-viewer (EN and AR).
  - Server gaps (stop rule, left out): the proof slip (sign-off photo, note, time) and file chips aren't in `daybook_page`'s JSON; reassign events neither.

- **17 Oct, slice 1 part 1c, writing in place, with review 45 B1–B3** (branch `slice1-daybook`):
  - The notepad opens a work item card at "Now": title, body, Assign (Lead and Crew only), Location, Due date with an optional time, a cover photo; Post needs a title and an owner. The phone chooses the id; the draft is kept on the phone (per account and Space) and comes back after the app is closed; with no signal the post waits in the outbox ("Waiting to send") and sends later, photos first.
  - B1 one continuous daybook; B2 the Arabic due wording; B3 the daybook reads entries: the proof slip (photo, large stamp, note, the check hint), updates, file chips, "Given to … instead of …"; the clip follows `needs_me` per entry.
  - Screenshots: E1–E7 added; D1, L1, DY1, DY2, DY3, V1 regenerated.

- **17 Oct, slice 1 part 1d, the work item loop, with review 46's 1c fixes** (branch `slice1-daybook`):
  - Review 46: Post is active with a title (no owner opens Assign and posts on the pick); a due date can be removed (writing and Edit, "Edited: due removed"); the Arabic 12-hour ranges; a refused post goes back to a Draft with "Couldn't send. Tap to fix"; a draft is kept as soon as anything is entered; alef names show two letters; "Assign to…".
  - The loop: Sign as done with the camera (pill, or hold the post bar's camera), check by double-tap with a 5-second Undo before anything is sent, long-press menus, send back with one reason, an update by swiping, Edit, Give to someone else, Cancel (also held 5 s with Undo).
  - Retired from 0.9.0: W3–W5, the work item card, the site tag and sign-off strip components and the item route; Activity, Needs you, Home, Library "used in", chat cards and pushes now open the Space's daybook.
  - Screenshots O1–O3, S1, Y1–Y2, B1–B3, X1–X3, E8; earlier ones regenerated.
  - Server gaps (left out): no "can delete" flag on the post JSON (so Delete isn't offered), Discuss in chat (a message can't quote a work item), voice note on a send back, a send-back as its own daybook entry, the push function's item routes (the app maps them to the Space).
- **17 Oct, migration 24, send-backs on the daybook** (review 47; branch `sent-back-db`, **not live**): `daybook_page` returns `sent_back` entries; the owner's clip and Sign as done sit on the latest send-back (never also on the slip); the events index and month dots include send-backs. An independent review found no leak; its two clip findings (an owner who left, a reassign after a send-back) and test gaps are fixed. 1,648 SQL checks in 24 files (36 for migration 24). **Goes live only after an app build that draws send-back entries**, and the push must list only `20261017180000_sent_back.sql`.
  - **Live 17 Oct** (founder's yes, review 48): `sent-back-db` merged into main; `supabase db push` listed only `20261017180000_sent_back.sql`. Read-only check: `work_item_events_daybook_idx` exists and covers done, comment and sent_back. The 1e build (draws send-back entries) goes on the founder's phone the same day.

- **17 Oct, migration 25, fixes from the founder's slice 1 test** (review 51 Part F; branch `test-fixes-db`, **not live**): replies answer any reply on the post, filed under the top comment with the person answered (`reply_to_person`), who gets the notification; `drop_stale_push_tokens()` drops tokens not seen for 30 days (service role, for the nightly cleanup). 1,672 SQL checks in 25 files (24 for migration 25). Live with the founder's yes, as the only file in the push.
  - **Live 18 Oct** (founder's yes, review 52): `test-fixes-db` merged into main; `supabase db push` listed only `20261017220000_test_fixes.sql`. Read-only check: `post_replies.reply_to_person` exists (4 older replies back-filled), `drop_stale_push_tokens` exists and the app can't run it. Scheduling it nightly is a later step, with its own yes.

- **17 Oct, review 47 answers 3 and 5, migration 24 in the app, and slice 1 part 1e** (branch `slice1-daybook`):
  - Answer 3: the proof screen's item name lists your other open items (due soonest first) to prove one instead; × closes it. Proof photos come from the camera only (founder).
  - Answer 5: a refused sign-off keeps its photos on the phone and shows on its proof as "Couldn't send. Tap to fix"; the tap reopens the proof (send again, or for another item; × asks before deleting). A refused check, send-back, cancel, give-to or update says why in plain words ("Couldn't check: this item was cancelled"), and the page reads again.
  - Migration 24: send-backs are their own daybook entries ("Islam Ahmed sent it back", the quote, the reason and note); the proof keeps SENT BACK with "Sent back at 10:12"; Sign as done follows the server's clip (on the latest send-back, never two on one item); paging follows the rows the server returns, so unknown kinds never end it.
  - 1e: the Space header (emblem, name, ⋯) and the Space menu with Space info only (MN1); Space info restyled (SI1) with "On site since" for admins (set and remove; others see it once set), Copy for the invite code, one-choice notifications and who can invite; Needs you across Spaces (NY1, from needs_you(), rows open the Space); Home in Daybook (H1 v3: wordmark, Search, notebook and Messages placeholders, small tabs, masthead, posts on the time spine); the profile in Daybook (R1 v4: proof of work as torn proof cards, projects with CONFIRMED / WAITING) and proof on someone else's profile (PR1); the Space tab bar's chosen tab in orange; Back in app bars is Phosphor's arrow.
  - Not built: Write a post in place (H2): it would replace the composer (C1); see the report.
  - Screenshots: MN1, SI1, NY1, H1, R1, PR1, O4, O5 added; S1 and the others regenerated.

- **17 Oct, review 48's fixes and slice 1 part 1f, write a post in place** (branch `slice1-daybook`, app only):
  - Review 48: Home's masthead shows the date alone ("15 October"); the notebook and Messages icons and their placeholder routes are gone until slices 8 and 3 (Search stays; the placeholder screen stays for Explore); who can invite says "Admins" ("المدراء"); the demo text uses one spelling and title (the profile's proof card has the daybook's "تركيب الجلب عند المحور C7 قبل الصبّ", Rakesh is "راكيش" everywhere).
  - 1f (H2 `2555:35388`): Create, from every tab, opens a post card in place at Now on Home's spine ("You · to everyone", the text, up to four photos from the camera or the phone, the project tag) with the writing toolbar; ⋯ has Project (projects on your profile with a confirmed role) and the post's language (found from the letters, or English or Arabic). It **replaces the composer**: the C1 screen, its route and its strings are gone, and Edit on your own post opens the same card at Now (text and language only, as `edit_post` allows).
  - The phone chooses the post's id; the Draft is kept per account as soon as anything is entered and survives the app being closed; with no signal the post waits on Home ("Waiting to send") and sends later, photos first (the post outbox, now per account, flushed on opening, on coming back and every 30 s); a refused post goes back to its Draft with "Couldn't send. Tap to fix".
  - Left out (not drawn or not on the server): the composer's "Start from" templates (templates are slice 7), files on a post (`create_post` takes photos only, so the paperclip adds a photo from the phone, as in the daybook).
  - Screenshots: H2-write-post, H3-write-post-filled, H4-post-draft, H5-post-waiting, H6-post-could-not-send added; H1, SI1, R1 and PR1 regenerated.

- **17 Oct, slice 1 test fixes, Part B (reliability)** (review 51; branch `slice1-fixes`):
  - Part A causes: F18, the feed list couldn't be pulled when shorter than the screen and never reloaded on return (the server had the post); F12, no app crash on record (the emulator restarted); the three replies were three separate sends.
  - F9: the push setup no longer stops when the phone refuses a token; it retries (2/5/15/30/60 s, and on return to the app), registers on every start, and shows "Notifications aren't reaching this phone · Fix it" (Xiaomi steps) when there's still no token. An anonymous "no token" report goes through Crashlytics (no user id).
  - F11/F18: the daybook and the Home feed read their newest page on open, on return to the app, when shown again and on a push; pull-to-refresh always works; a "New" chip when reading older entries.
  - F17: the outboxes retry by themselves within seconds; "Waiting to send" goes the moment the server accepts it, with no duplicate slip.

- **17 Oct, slice 1 test fixes, Part C (getting around)** (review 51; branch `slice1-fixes`): Home → Spaces has one compact date line, New Space and Enter an invite code always on top, Needs you cards with the Space name first and the whole card tappable, and every Space once under "Your Spaces"; every Activity row opens what it's about (the REV stamp and A–F letters are gone); + offers "Post to everyone" or "Work item in a Space ▸"; a short or long press on any slip gives Add update to the owner, Lead and Crew. Server gaps: no last-activity time per Space, one news row per Space, no create right in `my_spaces()`, no server-side last-opened Space.

- **17 Oct, slice 1 test fixes, Part D (signing and checking)** (review 51; branch `slice1-fixes`): F6 the proof screen opens with "Take a photo" one tap away and a "Without a photo" link (then the note is required; the slip shows the note with no frame); F7 a tap never signs, "Send as done" is held 5 s with "Signed as done · Undo" (Undo sends nothing and reopens the proof with its photos and note); F5 a soft sound and a light haptic when the server accepts a sign-off or a post (haptic only on silent; own-made tone in `assets/sounds/`).

- **18 Oct, slice 1 test fixes, Part E (words and layout)** (review 51; branch `slice1-fixes`): F4 the "site only" wording is gone in EN and AR (a test fails on new "site"/"موقع" strings unless kept on purpose); F15 in the 12-hour clock the period sits on a small second line under the time, so "11:58 مساءً" fits; F19 the feed card and the post page follow H1 (⋯ level with the name, semibold name with the headline, the card hugs short posts, replies as small slips with "Replying to …"); F2's app side works before and after migration 25. F14 left for the founder.

- **18 Oct, F14 (founder's ok):** "Checked" in Arabic is **تم التحقق**, the action **تحقّق**, "Double-tap the photo to check it" **انقر مرتين على الصورة للتحقق**: all 27 app strings, the stamps, the glossary (`CLAUDE.md`, `arabic-glossary.md`) and the push texts (`strings.json`). **Push function deployed 18 Oct** (founder's yes): version 7, from `slice1-fixes`, whose push function differs from main only in those two Arabic texts. The New Space hint is "e.g. Tower B — Design team" / "مثال: البرج B — فريق التصميم".

- **18 Oct, migration 26, daybook cards (v13)** (review 53 Part A, with F30's server side; branch `daybook-cards-db`, **not live**): `space_posts.last_activity_at` (raised by every event, edit, reassignment and cancel; indexed); `daybook_cards` (one card per work item, newest activity first, with its latest proof and outcome, the last 50 history lines and `needs_me`: to_sign, to_check, give_to, to_tick or null); `post_history` for "Show earlier"; `post_cards` gains the latest reply and up to three reply faces, never a count. Sign, check, send back, reassign and add update now lock the post first (no deadlock with cancel; a two-session stress test confirmed it). An independent review found no high or medium problem; its low findings and test gaps are fixed. About 55 ms for a page of 30 cards on 10,000 posts. 1,782 SQL checks in 26 files (110 for migration 26). Open for the lead: a Space admin with a Viewer pass can still be asked to act for a gone author. Live with the founder's yes, as the only file in the push.
  - **Live 18 Oct** (founder's yes, review 54): `daybook-cards-db` merged into main; `supabase db push` listed only `20261018120000_daybook_cards.sql`. Read-only check: `space_posts.last_activity_at` is not null on every post, `space_posts_activity_idx` exists, `daybook_cards` and `post_history` run for the app and not for anon, `post_cards` has `latest_reply` and `reply_faces`. Review 54 accepted the Viewer-admin rule for the pilot.

- **18 Oct, migration numbering (founder):** migration 27 is BuildVibes 360 (model views, review 54 model-views, spec `docs/product/model-views.md`). The clean-up from review 54's "Later" list (each Space's `last_activity_at` on `my_spaces()`, 30 days of Activity with paging, the event id in push data, dropping `daybook_page`, a "more" flag on `post_history`) goes in the migration after it (28).

## Before the pilot (week 11)
- Delete the test accounts push-test-a, push-test-b, push-test-c and "Delete Test" (the S13 test account on the founder's Gmail alias), and their test post, with the admin API.
- With the founder's yes: deploy `account-purge` with `ACCOUNT_PURGE_SECRET`, and run `supabase/ops/account_cron.sql` (account purge and the 12-month report cleanup).
- Turn the phone provider off on the live project (it is on for the test numbers only).
- Upgrade the Supabase project to a paid plan for daily backups.
- The nightly cleanup of loose photos (an Edge Function calling the Storage API with `orphan_space_files()` and `orphan_post_media()`): a live change for the founder's yes.
- Replace the app icon and the notification icon (now a white silhouette of Flutter's default icon) with the BuildVibes logo.

## Next tasks (in order)
1. Spaces (week 4): `spaces-db` merged into main (11 Oct; all 212 SQL checks pass on the Supabase CLI, also from an empty database). Migration 6 is live (pushed with the founder's yes, 11 Oct). App parts 1–3 done (Spaces, week 4).
2. Week 8 is done except Translate, which waits until after the pilot (review 28). Still open from the market pack: the pilot site's own area, if it isn't among Kuwait's 25 places. Next: the lead's plan for weeks 9–11.
3. iPhone push needs the Apple developer account and an APNs key (week 10).
4. Week 10 (App Store work): Arabic texts for the iPhone permission prompts (camera, microphone, photos), in an `ar.lproj/InfoPlist.strings` added to the Xcode project.
4. Ask the founder before scheduling the nightly cleanup (an Edge Function, a live change).
5. A local reviewer in Kuwait and in Egypt confirms the flagged market pack values (phone rules, places, local trade names, popular trades, Egypt's week start). Legal pages are still to be written.
6. Delete account (week 8) must hand Space admin rights over. The database already promotes a Lead when the last admin's account goes.

- **12 Oct, lead (while the founder was out):**
  - Review 12, the week 6 brief, is in `docs/reviews/2026-10-12-12-chat-library.md`, with the Figma frame list in `docs/design/chat/README.md`.
  - Branch `chat-library-db` holds migration 9 (Space chat and Library) and `supabase/tests/09_chat_library.test.sql`.
    - All 408 SQL checks pass on Postgres 16 with a Supabase stand-in.
    - Independent review: 2 medium and 7 low findings, all fixed and re-verified.
    - Not live.
- **15 Oct (evening), migration 21, notebook and My calendar** (review 33 A4; written by the lead in the cloud while the founder's PC was off; branch `notebook-db`, **not live**): `notes`, `note_files`, private bucket `notebook-files`, `save_note`, `delete_note`, `set_note_done`, `pin_note`, `mark_note_put`, `my_calendar`, `orphan_note_files`; the notebook added to Download my data and the account purge. 85 new SQL checks, all 1,211 pass. Independent review: no leak; four smaller fixes made (review 37). Migration 20 must be timestamped after `20261015230000`. Going live needs the founder's yes and must list only `20261015230000_notebook.sql`.
