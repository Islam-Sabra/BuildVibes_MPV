# BuildVibes MVP — instructions for Claude

Read this file first in every session. Then read `docs/handoff.md` (where the last session stopped) and `docs/progress.md` (where the build stands).

## What this is
BuildVibes is a mobile-first professional network and site-work app for the whole AECO industry: engineers, BIM staff, site supervisors, foremen, trades, subcontractors, suppliers and labour.

**MVP goal:** one real site team runs its daily work in a BuildVibes Space for four weeks from **1 February 2027**. Members get proof on their profile from work that was checked and closed.

- **Founder:** Islam (BIM Manager, Kuwait). He decides business questions. Technical and product-design calls are Claude's, explained in plain words.
- **Design source of truth:** Figma file `IcoK4u8JFO6K8l4YYiHNkm`, signed off on 11 Oct 2026.
  - English: page "PROTOTYPE · Full app v1 · EN".
  - Arabic: page "PROTOTYPE · Core journeys · AR".
  - The prototype is frozen. If the code and the prototype disagree, the prototype wins, unless the founder says otherwise.
  - **Exception (founder, 18 Oct):** text sizes follow the two-size rule in `BvType` (main 15 / small 12; Arabic 16 / 13, Almarai), even where a frame drawn before 18 Oct shows other sizes. Frames with the old hour spine are redrawn before their slice (review 58).
- **Product docs:** `docs/product/`. Start with `mvp-plan.md`, `space-project-model.md`, `rules.md` and `arabic-glossary.md`. Component specs (sizes, colours, states) are in `components.md`. The database tables and permission rules are in `data-model.md`.
  - The Space Work design is `docs/product/daybook.md`; every prototype scenario is listed in `docs/product/space-scenarios.md`.
- **Old app, for reference only:** `D:\Projects\00 AECOX Technology\Build-Vibes` (GitHub `Islam-Sabra/Build-Vibes`). Port proven parts from it; never edit it. See `docs/product/codebase-audit.md`.

## Scope
**In the MVP:**
- sign-up and sign-in by **6-digit email code only** (no passwords; phone/WhatsApp after the pilot — decision 04);
- Arabic and English, right to left;
- profile with proof from closed work;
- shared project records;
- Spaces: join requests confirmed by the admin, Lead / Crew / Viewer passes, Teams, Chat, work items (Open → Done → Checked), Library;
- Work in the Daybook design: writing in place with drafts; work item, checklist, announcement, scheduled activity and file posts; opening a post in place (blocks, /, turn into, tables); work items under one work item; walk mode; templates; daily report; meeting notes into work items; management report (see `docs/product/daybook.md`);
- Planning: the personal notebook and My calendar across all Spaces;
- Direct messages between two people;
- Home feed and the Spaces tab;
- Activity and push notifications;
- report and block;
- delete account.

**Not in the MVP:** export a work item's record as PDF, approval codes, repeating work items, Translate, phone and WhatsApp sign-in, Jobs and hiring, company job management, Explore beyond people search, community question Spaces, CV import, connected accounts, paid plan, sponsored posts.

Don't build out-of-scope features, even partly, without the founder's yes.

## Product rules (from the founder; never break them)
1. **No generic screens.** Every screen must feel premium (not luxury) and easy, and use the site-paperwork language from the prototype: site tags, stamps, sign-off strip, passes.
2. **Whole-industry audience.** A foreman or electrician with a phone and basic reading must manage every main action in under a minute. Nothing may require a degree, an email, a long CV or English.
3. **No misleading numbers.** No aggregate counts as quality signals: total results, projects built, member counts, years as a rank. Follower counts on profiles are allowed (founder decision, 11 Oct).
4. **Disclosure by choice.**
   - Business facts about companies are hidden unless the company admin publishes them.
   - A company name typed by a person stays plain text unless it matches a registered company. Never create a company from typed text.
5. **Market pack.** Nothing country-specific is typed into code or copy: country, city, currency, phone format, weekend, credential names, legal text. It all comes from market-pack data. Kuwait and Egypt are the first packs.
6. **Choices that exclude each other** are one single-choice control, never separate switches.
7. **No unnecessary settings.** Language has only two things: the app language, and the language each post is written in (with Translate).
8. **Work stays in Spaces.** Work items never leave the Space. Public posts live in the Home feed and can be tagged to a project. A project has no owner and no admin.

## How Claude works with the founder
- When he asks a question, answer it. Don't change code in the same turn.
- A bare "ok" means go with Claude's recommendation.
- Bring him business decisions only, each with a recommendation. Decide technical matters yourself.
- Be direct and structured, with no flattery. He writes in English or Egyptian/Gulf Arabic.
- "Handoff" or "frozen" means don't change it until he says it's done.

## Technical decisions (made; don't reopen without a reason)
- **App:** Flutter (stable), Dart 3. State with `flutter_riverpod`, navigation with `go_router`, backend with `supabase_flutter`.
- **Backend:** a new Supabase project, "BuildVibes MVP". Schema lives in `supabase/migrations/`.
  - Every permission is enforced on the server with row-level security and Postgres functions, never only in the app.
  - Space passes (Lead / Crew / Viewer) and admin rights are checked in SQL.
- **Secrets:** never committed. Use `--dart-define-from-file=env/dev.json`; `env/*.json` is git-ignored and `env/example.json` documents the keys.
- **Design tokens:** `lib/core/design/bv_tokens.dart`, generated from the Figma variables. Widgets never contain raw colours, font sizes or magic spacing numbers.
- **Localisation:**
  - `flutter gen-l10n` with ARB files in `lib/l10n/` (`app_en.arb`, `app_ar.arb`).
  - No string is typed in a widget.
  - Western digits in Arabic.
  - Use `Directionality`-aware widgets (`EdgeInsetsDirectional`, `AlignmentDirectional`, `start`/`end`), never `left`/`right`.
  - Arrow and chevron icons flip in right-to-left.
- **Fonts:** Plus Jakarta Sans (Latin) and **Almarai** (Arabic, Regular and Bold; founder's choice, 18 Oct, replacing Noto Sans Arabic), in `assets/fonts/`. Almarai is subset to Arabic so Latin words and digits inside Arabic text still use Plus Jakarta Sans; source and OFL licence in `assets/fonts/SOURCE.md`.
- **Folders:**
  - `lib/core/` (design, theme, routing, l10n, config, market pack)
  - `lib/data/` (models, repositories, Supabase)
  - `lib/features/<feature>/` (screens and widgets)
  - `lib/shared/widgets/` (BV components: buttons, list rows, chips, site tag, stamp, sign-off strip, pass card, sheets)
- **Components first:** build each Figma component once in `lib/shared/widgets/`, then compose screens from them.

## Glossary (use these exact words)
| English | Arabic |
|---|---|
| Space | مساحة |
| Space admin | مدير المساحة |
| Work item | بند عمل |
| Owner of a work item | المكلّف |
| Sign as done | وقّع كمنجز |
| Done | منجز |
| Checked | تم التحقق |
| Send back | إرجاع |
| Lead / Crew / Viewer | مسؤول / فريق تنفيذ / مُطّلع |
| Pass | تصريح |
| Needs you | بانتظارك |
| Project record | سجل المشروع |

## Reviews from the lead
- Claude (lead, in the founder's main chat) reviews each step against Figma and writes the findings to `docs/reviews/NN-*.md`.
- When the founder says "apply review NN", do every fix in that file, then continue the plan.
- Icons: Phosphor (regular weight), through `lib/core/design/bv_icons.dart`. Never use Material `Icons.*`. The Phosphor font is bundled in `assets/fonts/` because the `phosphor_flutter` package (2.1.0, the latest) does not compile on Flutter 3.44; see `assets/fonts/SOURCE.md`.
- After every finished task: `flutter analyze`, `flutter test`, commit, then **`git push`**.

## Working from more than one place
The founder's PC, cloud sessions and the lead's chat in the Claude project all work on the same GitHub repo. GitHub is the only shared copy.
- **Start:** `git fetch`, read `docs/handoff.md`, and work only on a branch it doesn't give to another place.
- **Stop:** commit, push, and rewrite `docs/handoff.md`: what was done, what is next, and who has which branch.
- **A cloud session** pushes only to its own `claude/...` branch. The PC merges that branch into the work branch next time.
- **Live changes** (`supabase db push`, function deploys, project settings) happen only from the PC, with the founder's yes.

## Definition of done for every task
1. `flutter analyze` shows no issues, and `flutter test` passes.
2. New logic has tests. Every new table has row-level security, and a test proves a non-member can't read or write it.
3. The screen matches its Figma frame, in English and in Arabic, at 390×844.
4. There are no hard-coded strings, colours, sizes or country facts.
5. Commit in small steps with clear messages, then update `docs/progress.md`.
