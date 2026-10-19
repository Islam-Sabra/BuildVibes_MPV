# Review 59: migration 27 (BuildVibes 360) approved — 19 Oct 2026

Branch `model-views-db` (64d1d63). One migration file, `20261019120000_model_views.sql`, and its tests `27_model_views.test.sql`.

## What I checked
- **On the stand-in** (Postgres 16 with the Supabase shim), every migration applies from scratch and **all 1,938 SQL checks pass** (27 files).
- **The three functions it creates again match their previous versions**, apart from the stated additions:
  - `is_referenced_file`, as in migration 18, plus `model_views.thumb_path` (R1);
  - `may_read_file`, as in migration 18, plus the thumb, readable by whoever can read the view;
  - `add_library_file`, as in migration 13, plus the refusal to make an ordinary upload a newer version of a model view (L2).
- **R1–R7 are all in and tested:**
  - **R1:** the thumb counts as used, so it is never cleaned up or counted as a loose upload.
  - **R2:** the chain lock plus the unique index. A second publish waits and gets V2.
  - **R3:** the version is the highest in the chain plus one, removed versions included, so a number is never reused. Supersede points at the newest version that wasn't removed. A Team chain and a whole-Space chain are separate.
  - **R4:** every limit. Camera and comments are cast inside a guarded block, so bad JSON gives the plain message, not a server error.
  - **R5:** `item_id`, `at` and `proof_path` across every version, and only for items the caller may see.
  - **R6:** `may_upload` is unchanged.
  - **R7:** no Activity row, push or post.
- **Access:**
  - `model_views` can only be read, row by row, through `can_read_library_file`;
  - there are no direct writes;
  - a Viewer can't publish (`add_files`);
  - a Team view is only for that Team's members and the admins;
  - a hidden account gets no publish targets.
- **Retry on a weak signal (M1):** the same id from the same person, for the same files, viewpoint, Space and Team, returns the version already published. Any other use of the id is refused.
- **Team deletion:** `model_views.team_id` has no delete action, which is safe because `delete_team` already refuses a Team that has Library files.

**Verdict: approved to go live.** With the founder's yes, the push lists only `20261019120000_model_views.sql`.

## Plugin follow-up (in `..\BuildVibes Navisworks Plugin`, not this repo)
- **P1 (must, before the plugin is given to anyone):** before sending, keep the **latest 20** comments, cut each body to **1,000** characters and each author to **120** (data-model §23, M2). Otherwise a busy viewpoint is refused with "comments are not valid". Add a test with 25 comments, one of them 1,500 characters long.
- **P2:** "Used in" shows each item's ref, title and status, and the site photo from `proof_path` when there is one. The photo is read with the person's own session. With no photo, it shows the status only.
- **P3:** check the plugin's Publish picker against `my_publish_targets()` on the live server: Spaces first, then their Teams, with no counts.

## Noted, no change now
- **`my_model_views` returns only the caller's own publishes.** When two BIM staff share one Navisworks file, each sees "Published" tags only on the views they published themselves. The version chain is still shared, so a colleague's publish correctly becomes V2. If pilot users ask to see their colleagues' publishes, a later migration can return every version the caller can read. Not needed for the pilot.
- **A viewpoint deleted in Navisworks and saved again** gets a new Guid, so its next publish starts again at V1. This is correct: Navisworks treats it as a different viewpoint. Users may ask about it.

## Order
1. With the founder's yes: `supabase db push`, listing only `20261019120000_model_views.sql`. Then merge `model-views-db` into `main`.
2. The plugin: P1–P3, then publish one real view from Navisworks into the pilot Space and check that it appears in `my_model_views`.
3. Then slice 2 (review 56): migration 28 first, then the app.
