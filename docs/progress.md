# MVP progress

Target: pilot live on **Fri 1 Jan 2027**. Weeks start on Sunday.

## Status
| Week | Dates | Plan | Status |
|---|---|---|---|
| 1 | 11–17 Oct | Audit the old app. Set up the new app, backend and repo. Data model and permission rules | Audit done. Repo skeleton and tokens done. GitHub repo created. Supabase project created. Waiting for: `flutter create`, first push, `env/dev.json` with the anon key |
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

## Next tasks (in order)
1. **Founder, in Cursor's terminal, inside this folder:**
   `flutter create --org com.buildvibes --project-name buildvibes --platforms android,ios .`
   This keeps the files already here and adds the Flutter project files.
2. Add the dependencies:
   - `flutter_riverpod`
   - `go_router`
   - `supabase_flutter`
   - `flutter_localizations`
   - `intl`
   - `image_picker`
   - `file_picker`
   - `url_launcher`
   - `shared_preferences`
3. Copy the fonts from the old repo's `mobile/assets/fonts/` to `assets/fonts/`, and register them in `pubspec.yaml`. The family names must match `BvFonts`.
4. `lib/core/theme/bv_theme.dart`: a `ThemeData` built only from `bv_tokens.dart`.
5. Localisation setup: `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, and a language switch for testing.
6. The app shell: 5 tabs (Home, Explore, Create, Activity, Profile) with `go_router`, matching the Figma bottom bar.
7. Shared components, each with a golden or widget test in English and Arabic:
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
8. Supabase: link the new project. Write the first migration: profiles, markets and reference lists, ported from the old repo.
