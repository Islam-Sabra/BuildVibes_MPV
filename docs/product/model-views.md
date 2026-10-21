# Model views (BuildVibes 360 → Space Library)

Founder decisions, 18 Oct 2026. Status: **agreed, in MVP scope** (the founder wants site teams in the pilot to use it). The plugin side is built in `..\BuildVibes Navisworks Plugin`; this file is what the app and backend need.

## What it is
BuildVibes 360 is a Navisworks plugin (2025, 2027) for office and BIM staff. It signs in with the same email code as the app. It lets them publish Navisworks views into a Space so the site team sees the model, not a WhatsApp screenshot.

## Rules (founder)
1. **Drafts stay in Navisworks.** Every capture is a saved viewpoint in the Navisworks file (folder "BuildVibes 360"). Nothing goes to the cloud until it is published.
2. **Only published views go to the BuildVibes cloud**, once. The Space links to that one stored copy.
3. **A published view lands in the Space Library** as a new kind of Library file: **Model view**, next to drawings and photos.
4. **It is not posted to Work, Chat or the Home feed automatically.** A person in the app may use it from the Library (attach it to a work item, share it in chat) like any Library file.
5. **Deleting the viewpoint in Navisworks never deletes the published copy.** The Library keeps it (the record is never lost). Removing it from the Library follows the normal Library rules.
6. **Each published view is a light issue: a title and a version, nothing more** (founder, 18 Oct: "small version of issue, not SaaS"). No status, priority, assignee or forms on the model view itself; action happens through work items made from it in the app.
   - **Title**: written by the publisher (defaults to the viewpoint name), ≤ 120 chars → `library_files.name`.
   - **Version**: automatic. First publish of a viewpoint to a Space/Team is **V1**; publishing the same viewpoint there again is **V2**, **V3**… → `library_files.rev_label`, set by the server, superseding the previous version (existing Library revisions). Older versions stay in the record.
   - **Note**: optional, one line, ≤ 300 chars → `library_files.note`.
7. Who may publish: anyone whose pass allows `add_files` in that Space (same as uploading to the Library). Team files only for that Team's members and admins (same as `add_library_file`).

## Data (proposed migration, for the MVP build to write, test and push with the founder's yes)
- `library_files.source`: add `'model_view'` to the check.
- New table `model_views` (one row per published Library file of source `model_view`):
  - `library_file_id uuid primary key references library_files on delete cascade`
  - `thumb_path text not null` – `<space>/library/<file_id>/thumb.jpg`
  - `camera jsonb not null` – Navisworks `Viewpoint.GetCamera()` (Autodesk common camera); lets the plugin reopen the exact view
  - `viewpoint_guid uuid not null` – the saved viewpoint's Guid inside the Navisworks file
  - `viewpoint_folder text` (≤ 200), `model_title text` (≤ 200), `model_file text` (≤ 200)
  - `comments jsonb not null default '[]'` – Navisworks viewpoint comments `[{author, body}]`, max 20, each ≤ 1000 chars
  - `image_width int`, `image_height int`, `navisworks text` (year)
  - RLS: read when `can_read_library_file(library_file_id)`; no direct writes.
- Storage (bucket `space-files`, existing rules): `<space>/library/<file_id>/view.jpg` (full image, JPEG ≈ 1920 px wide) and `<space>/library/<file_id>/thumb.jpg` (480 px). `may_upload` must accept the second file (`thumb.jpg`) in the same folder.
- Function `publish_model_view(p_id uuid, p_space uuid, p_team uuid, p_name text, p_note text, p_image_path text, p_thumb_path text, p_bytes bigint, p_camera text, p_viewpoint_guid uuid, p_viewpoint_folder text, p_model_title text, p_model_file text, p_comments text, p_image_width int, p_image_height int, p_navisworks text)` → table `(library_file_id uuid, rev_label text)`. `p_camera` and `p_comments` arrive as JSON **text** (the plugin can't embed raw JSON) and are cast to jsonb inside, rejecting invalid JSON. Same checks as `add_library_file` (pass, Team, `is_my_upload`, mime `image/jpeg`, path `<space>/library/<p_id>/view.jpg`), plus: the thumb `<space>/library/<p_id>/thumb.jpg` uploaded by the caller; Sets `rev_label` to `V<n>` (n = 1 + the number of earlier model views of this viewpoint in this Space/Team) and supersedes the current one automatically (so `p_supersedes` is not needed and is dropped from the signature). Inserts the Library row (`source = 'model_view'`, `name = p_name` (the title), `note = p_note`) and the `model_views` row in one transaction. Activity: same as a new Library file.
- Function `my_publish_targets()` returns rows `(space_id uuid, space_name text, team_id uuid, team_name text)`: one row per Space where the caller may publish (`team_id` null = whole Space), plus one row per Team in it that the caller may publish to. Ordered by space name, then whole Space first, then team name. No member counts (product rule 3).
- Function `my_model_views(p_viewpoint_guids uuid[])` returns rows `(library_file_id uuid, viewpoint_guid uuid, title text, rev_label text, space_id uuid, space_name text, team_id uuid, team_name text, created_at timestamptz, is_current boolean, uses jsonb)` for the caller's own published views of those viewpoints, newest first. `uses` = `[{ref, title, status}]` from `work_item_attachments` (only items the caller can read). Drives the plugin's "Published" tag and, later, the responses panel.
- Tests: non-member can't publish or read; Viewer pass can't publish; Team view not readable outside the Team; a deleted viewpoint has no effect; supersede only within the same Space/Team and viewpoint.

## App (Library)
- A Model view shows its title and version ("V2") like a drawing's revision, as an image card with a small "Model view · BuildVibes 360" site tag, the model name and who published it. Opening it shows the full image (zoom), the note, the Navisworks comments, and "Used in" work items, like other Library files.
- From it, a person can attach it to a work item or share it in chat (existing actions). Nothing new is posted on publish.
- No new settings.

## Site replies (two-way)
Uses what exists: when someone in the app makes a work item that uses the model view, site signs it done with a photo or sends it back. The plugin reads those work items through `my_model_views(...)` and shows them per viewpoint ("Used in KCT-021 · Sent back" with the site photo). Opening one in Navisworks jumps to the stored camera.

## Plugin (built in the plugin repo)
- Snapshot → saved viewpoint in folder "BuildVibes 360" (reminds the person to save the NWF/NWD).
- Publish → pick Space (and Team), name and note → render JPEG + thumb → upload both → `publish_model_view`. Tags the viewpoint "Published" from `my_model_views`.
- Export images to the PC stays as a secondary button.

## 3D (founder decision, 20 Oct 2026: in the pilot)
- A published model view may carry an optional 3D piece of the model: `view.glb` next to `view.jpg` and `thumb.jpg`.
- Scope chosen by the publisher:
  - the viewpoint's **section box**; or
  - a **room** (Revit rooms in the NWD).

  Never the whole model.
- The room scope reaches into the ceiling void and the slab above (+1.5 m) and adds a 0.3 m margin around.
- Contents:
  - only the elements visible in the viewpoint, in their Navisworks colours;
  - cut exactly at the box faces.
- GLB format (BuildVibes 360 writer):
  - metres, Y-up, centred on the box;
  - 16-bit positions (KHR_mesh_quantization, node scale = half box size);
  - 16-bit indices in chunks of ≤ 65,535 vertices;
  - `_FEATURE_ID_0` per vertex = element index;
  - `extras.buildvibes`:
    - `elements[i] = [name, category, level]`;
    - `camera {eye, dir, up, perspective, fov}` in file coordinates;
    - `scope`, `box_size_m`, `model`, `navisworks`.
- Limits: the plugin refuses more than 1.5 M triangles ("pick a smaller room or box"). The server caps 20 MB and 2 M triangles.
- Same title and version as the image; no extra post or Activity.
- App: a "View in 3D" button with its size, downloaded on tap, cached for offline use; opens at the BIM camera; tap identifies the element. Details: review 70.
- Measured on NBK (20 Oct): a 10 m room box is 351k triangles and 4.8 MB, exported in about 7 s.
