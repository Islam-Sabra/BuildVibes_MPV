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
| Email | On. 6-digit code, valid 10 minutes, 1 minute between codes, confirmation required. Sender: Resend SMTP, `BuildVibes <no-reply@mail.aecox.com>` (saved by the founder, 11 Oct). Code email in English and Arabic (no link) applied 11 Oct with the founder's yes. Limit 30 emails an hour (config.toml proposes 60; not applied) |
| Phone | New phone sign-ups off (decision 04, 11 Oct). Existing test accounts can still sign in. Placeholder Twilio account (no real messages) |
| Test phone numbers | +965 50000001, +965 50000002, +965 50000003, +20 1000000001, +91 9800000001 — code 123456 |
| Google, Apple, LinkedIn | Off |
| Redirect URLs | `com.buildvibes.buildvibes://login-callback` |
| Authenticator app (MFA TOTP) | On (restored) |
| Migrations applied | 1 market pack, 2 people and companies, 3 sign-up gate and onboarding, 4 profiles and projects, 5 email sign-in (both pushed with the founder's yes, 11 Oct) |
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

## Next tasks (in order)
1. Decision 04: the founder confirms the test code email (sent 11 Oct) arrived in the inbox, not spam. Optional: raise the email limit from 30 to 60 an hour (needs the founder's yes).
2. A local reviewer in Kuwait and in Egypt confirms the flagged market pack values (phone rules, places, local trade names, popular trades, Egypt's week start). Legal pages are still to be written.
3. Spaces (week 4): create, link a project, invite link and code, join requests, passes, Teams. Teammate confirmations for CV projects come with it.
