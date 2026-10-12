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
| 7 | 22–28 Nov | Home feed and posts, Spaces tab, Activity, push notifications | — |
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
| Migrations applied | 1 market pack, 2 people and companies, 3 sign-up gate and onboarding, 4 profiles and projects, 5 email sign-in, 6 Spaces (all pushed with the founder's yes, 11 Oct), 7 work items, 8 work item follow-ups and Work you delivered (founder's yes, 12 Oct) |
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

## Next tasks (in order)
1. Spaces (week 4): `spaces-db` merged into main (11 Oct; all 212 SQL checks pass on the Supabase CLI, also from an empty database). Migration 6 is live (pushed with the founder's yes, 11 Oct). App parts 1–3 done (Spaces, week 4).
2. The lead reviews migration 11 and chat part 2 (`chat-part2`). Then, with the founder's yes, put migration 11 live and merge.
3. Week 6 part 3: voice notes.
4. Ask the founder before scheduling the nightly cleanup (an Edge Function, a live change).
5. A local reviewer in Kuwait and in Egypt confirms the flagged market pack values (phone rules, places, local trade names, popular trades, Egypt's week start). Legal pages are still to be written.
6. Delete account (week 8) must hand Space admin rights over. The database already promotes a Lead when the last admin's account goes.

- **12 Oct, lead (while the founder was out):**
  - Review 12, the week 6 brief, is in `docs/reviews/2026-10-12-12-chat-library.md`, with the Figma frame list in `docs/design/chat/README.md`.
  - Branch `chat-library-db` holds migration 9 (Space chat and Library) and `supabase/tests/09_chat_library.test.sql`.
    - All 408 SQL checks pass on Postgres 16 with a Supabase stand-in.
    - Independent review: 2 medium and 7 low findings, all fixed and re-verified.
    - Not live.

