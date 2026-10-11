# MVP progress

Target: pilot live on **Fri 1 Jan 2027**. Weeks start on Sunday.

## Status
| Week | Dates | Plan | Status |
|---|---|---|---|
| 1 | 11–17 Oct | Audit the old app. Set up the new app, backend and repo. Data model and permission rules | Audit done. Flutter project, dependencies, fonts, theme, English/Arabic and the 5-tab shell done. Review 01 applied and pushed. Waiting for: `env/dev.json` with the anon key |
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

## Next tasks (in order)
1. Shared components, each with a golden or widget test in English and Arabic:
   - button (primary, secondary)
   - list row (chevron, switch, value, none)
   - chip
   - text field
   - select
   - bottom sheet
   - site tag (work item card)
   - stamp
   - sign-off strip
   - pass card
2. Supabase: link the new project. Write the first migration: profiles, markets and reference lists, ported from the old repo.
