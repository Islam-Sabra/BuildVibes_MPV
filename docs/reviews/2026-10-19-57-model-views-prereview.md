# Review 57: BuildVibes 360, a pre-review of the migration 27 spec — 19 Oct 2026

Before Claude Code writes migration 27 (`docs/product/model-views.md`; review 54-model-views), I checked the spec against the live schema (all migrations through 26, on the stand-in). The founder rules and the plugin's function names, arguments and row shapes stay as they are. These are **additions** the migration must include, so it passes review the first time.

## R1. The thumbnail would be deleted after 7 days (must fix)
`is_referenced_file()` counts a `space-files` object as used only if a work item photo, chat attachment, Library file (`library_files.storage_path`) or post file points at it. `thumb.jpg` is referenced only by `model_views.thumb_path`, so:
- `orphan_space_files()` lists it, and the nightly clean-up deletes it after 7 days;
- `loose_uploads()` counts it against the caller's 400-file / 200 MB loose limit forever.

**Fix:** `is_referenced_file()` also returns true for `model_views.thumb_path`.

**Test:**
1. publish a view;
2. age the objects past 7 days;
3. `orphan_space_files()` returns neither `view.jpg` nor `thumb.jpg`;
4. `loose_uploads()` doesn't count them.

## R2. Two publishes at once must not both be V1 (must fix)
"V<n> = 1 + earlier model views of this viewpoint in this Space/Team" has a race. Two publishes of the same viewpoint at the same moment would both read n = 0.

**Fix:**
- `model_views` also stores `space_id`, `team_id` and `version int not null`, copied from the Library row and set by the function;
- a unique index on `(space_id, coalesce(team_id, '00000000-0000-0000-0000-000000000000'), viewpoint_guid, version)`;
- `publish_model_view` takes `pg_advisory_xact_lock` on that key before counting.

**Test:** the second of two publishes gets V2 (or a clean retry), never a second V1.

## R3. What "supersedes" means, exactly
- The version number counts every earlier publish of that viewpoint in that Space/Team, **including ones later removed from the Library**, so a number is never reused.
- `supersedes_id` points at the newest of those that is **not removed**, or is null if there is none.
- A Team view and a whole-Space view of the same viewpoint are separate chains.

Tests for each.

## R4. Limits on what the plugin sends
- `p_camera`:
  - valid JSON and an **object**;
  - at most 4 KB;
  - otherwise "camera is not valid".
- `p_comments`:
  - a JSON array of at most 20 objects, each with `author` (≤ 120) and `body` (≤ 1000), and nothing else;
  - otherwise "comments are not valid".
- `model_title`, `model_file` and `viewpoint_folder`: at most 200 each, trimmed; empty becomes null.
- Image sizes: positive, at most 10000.
- Both files must be `image/jpeg` uploads by the caller, in `<space>/library/<p_id>/`, checked with `is_my_upload` and `upload_mime`, as `add_library_file` does.

## R5. "Used in" must carry the site photo
The spec promises the plugin "Used in KCT-021 · Sent back" **with the site photo**, but `uses` is only `{ref, title, status}`.

**Fix:** each use also carries:
- `item_id`;
- `at`, the item's last activity;
- `proof_path`, the latest sign-off's first photo (`storage_path`), or null.

The plugin reads the photo from storage with the person's own session, under the existing rules. `uses` covers **every version** of the viewpoint, not only the current one.

## R6. No change to `may_upload`
It already lets the uploader put any number of files in an unused `<space>/library/<id>/` folder, and nobody else can add to that folder. So `thumb.jpg` beside `view.jpg` needs no change.

**Test:**
- both files upload before `publish_model_view`;
- a second person can't add a file to that folder;
- after publishing, nothing more can be uploaded there.

## R7. Nothing is posted, and no new notification
`add_library_file` writes no Activity row or push, and neither does `publish_model_view` (founder rule 2). "Activity: same as a new Library file" therefore means none. A test checks that no notification row is written.

## Verdict
Write migration 27 with R1–R7, on `model-views-db`, as the only migration file. Push it for the lead's review; it goes live only with the founder's yes. The plugin needs no change, apart from showing `proof_path` (R5) when it shows "Used in".
