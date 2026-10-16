# Review 40: migration 20 (pages, walk mode, templates, reports, search) — 16 Oct 2026

Branch `post-pages-db` (a7abe2c), rebased on main after migration 21 went live. On my side all migrations apply from scratch and **all 1,373 SQL checks pass** (21 files; 146 for migration 20).

**What I checked:**
- **Order:** the branch contains main (migration 21 live), so this push is in order.
- **Grants:** the internal helpers (`validate_blocks`, `is_target`, `batch_pushes`, `done_photo_path`, `may_manage_templates`, `block_text_ok`) are closed to the app; nothing is open to signed-out callers; `post_templates` has row-level security.
- **Search:** every kind of hit (posts, points, chat, Library) is filtered twice, the second time with the full read rules on at most 120 rows, so Team posts, deleted posts, Team chat and Team files can't leak; reported messages stay hidden for the reporter.
- **Targets (review 39 point 2):** a walk or meeting parent can't be signed or checked while it has live work items under it, so it can never become proof; Needs you and the week report leave it out.
- **Templates:** a Team template is read only by that Team and the admins.
- The independent review's 14 fixes and 8 test gaps are in, with tests.

**Verdict: approved.**

## Going live (founder's yes)
1. Merge `post-pages-db` into `main`.
2. `supabase db push` must list only `20261016120000_post_pages.sql`; otherwise stop and send a screenshot.
3. Read-only check (names and counts only): `post_templates` exists with row-level security on and one built-in template (Daily report); `space_posts` has the page columns.
4. Update `progress.md`, commit, push.

## Next
Migration 22, direct messages (review 33 A5, with founder decision F10 as written in `docs/product/space-scenarios.md`: managed, not blocked; the spam guard counts new people who never replied). Branch `dm-db`, built on main, timestamp after `20261016120000`, data-model §18. Same routine: tests, independent review, push the branch, not live.
