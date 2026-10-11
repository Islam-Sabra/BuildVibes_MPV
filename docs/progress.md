# MVP progress

Target: pilot live on **Fri 1 Jan 2027**. Weeks start on Sunday.

## Status
| Week | Dates | Plan | Status |
|---|---|---|---|
| 1 | 11–17 Oct | Audit the old app. Set up the new app, backend and repo. Data model and permission rules | Audit done. Flutter project, dependencies, fonts, theme, English/Arabic and the 5-tab shell done. Review 01 applied and pushed. Components done. Supabase linked; migrations 1 and 2 live |
| 2 | 18–24 Oct | BV components in Flutter. Sign-up and sign-in (phone, Google, Apple, email code) | — |
| 3 | 25–31 Oct | Profile, project records, "Is it already here?", Add to my CV | — |
| 4 | 1–7 Nov | Spaces: create, link a project, invite link and code, join requests, passes, Teams | — |
| 5 | 8–14 Nov | Work items: create, Needs you, sign as done with a photo, check or send back, filters | — |
| 6 | 15–21 Nov | Space chat (live), item cards in chat, Library and file preview | — |
| 7 | 22–28 Nov | Home feed and posts, Spaces tab, Activity, push notifications | — |
| 8 | 29 Nov–5 Dec | Arabic pass, market pack, privacy, report and block, delete account | — |
| 9 | 6–12 Dec | Internal test with 3–5 people. Fixes | — |
| 10 | 13–19 Dec | App Store and Google Play submission | — |
| 11 | 20–26 Dec | Pilot prep with the pilot Space admin | — |
| 12 | 27–31 Dec | Buffer | — |

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

## Next tasks (in order)
1. A local reviewer in Kuwait and in Egypt confirms the flagged market pack values (phone rules, sign-in code channel, places, local trade names, Egypt's week start). Legal pages are still to be written.
2. Sign-up and sign-in (week 2): phone code, Google, Apple, email code. Onboarding: name, role or trade, company.
3. Migration 3: projects (data-model §4).
