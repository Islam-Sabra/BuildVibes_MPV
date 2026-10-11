# Audit of the old app (11 Oct 2026)

**Old app:** `D:\Projects\00 AECOX Technology\Build-Vibes`. GitHub `Islam-Sabra/Build-Vibes`, branch `main`. The latest checkpoint is `001519b`. Use it for reference only and never edit it.

## What it is
- **Stack:** Flutter (`mobile/`), Riverpod, go_router and Supabase (`supabase/`).
- **Size:** 456 Dart files, about 98,000 lines, and 264 test files.
- **Data mode:** chosen at build time — demo data, local Supabase or hosted Supabase.
- **Backend:** 28 migrations, with tables for:
  - profiles, with experience, projects, credentials, education and evidence;
  - posts, comments, media and files, with an upload pipeline;
  - follows;
  - direct messages;
  - companies;
  - reports;
  - account deletion;
  - reference lists: trades, disciplines, locations, categories;
  - simple `spaces` and `space_members`.

## Verdicts against the signed-off prototype
| Area | Old app | Verdict |
|---|---|---|
| Design system | Old Replit look (navy, slate, Tailwind orange) | Rebuild from the Figma variables. Done here: `lib/core/design/bv_tokens.dart` |
| Navigation | 6 tabs | Rebuild with the 5 tabs |
| Spaces | Self-join only. No admin confirmation, passes, Teams or work items | New schema and screens. This is the core of the MVP |
| Sign-in | Phone code works. Email sign-up uses a password. No Google or Apple | Port the phone code flow. Add Google, Apple and email code. Remove passwords |
| Arabic | Barely present | New, with `flutter gen-l10n` ARB files and full right to left |
| Profile and evidence | Strong | Port the tables. Connect the evidence to checked work items |
| Posts, media, files | Working upload and visibility pipeline | Port |
| Direct messages | Large module | Parked (not in the MVP) |
| Notebook, calendar, library | Present | Parked |
| Project as a shared record | Projects live inside profiles | New `projects` table. Profile projects point to it |

## Worth porting (paths in the old repo)
| What | Where |
|---|---|
| Fonts | `mobile/assets/fonts/` (Plus Jakarta Sans, Noto Sans Arabic) |
| Supabase config and security patterns | `supabase/config.toml` and the row-level security policies in `supabase/migrations/*.sql` |
| Profile tables | `20260708150300_phase_a_001_core_social_schema.sql`, `20260928120000_r2_person_profile_evidence.sql` and the R2 follow-ups |
| Posts, media and files pipeline | `20260821140000_c12f_post_media_storage.sql`, `20260923160000_c15b1_post_file_foundation.sql`, `20260926*` |
| Reports | `20260714130000_c_wp4b_reports_schema.sql`, `20260714140000_c_wp6_reports_insert_grant.sql` |
| Account deletion | `20260715180000_d_wp3_account_deletion_requests.sql` |
| Phone sign-in flow | `mobile/lib/data/repositories/supabase/supabase_phone_auth_repository.dart`, `mobile/lib/features/auth/phone_*` |
| Upload repositories | `mobile/lib/data/repositories/supabase/supabase_post_media_repository.dart`, `supabase_post_file_repository.dart` |
| Edge function | `supabase/functions/create-post-file-signed-url` |

**How to port:** read the old code, then rewrite it to this app's structure and rules — tokens, ARB strings and the market pack. Don't copy whole folders.
