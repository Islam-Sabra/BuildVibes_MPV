# Review 71: the lead's review of review 70 (3D model views) — 21 Oct 2026

Review 70 (`docs/reviews/2026-10-20-70-model-views-3d.md`, branch `model-views-3d-notes`, commit 8b7b201) is the plan for the founder's decision of 20 Oct: **3D goes into the pilot**, as an optional part of a published model view. The founder rules in it (optional per view, the scope is a section box or a room, the same title and version, Library only, never auto-posted) stand. **The plan is approved with the changes below.**

## Changes
1. **Migration number:** 29 is the live slice 2 migration. The 3D server work is **migration 34** (33 is the send-back date, review 72, written first), on `model-views-3d-db`. Wherever review 70 says "migration 29", read 34.
2. **Merging the notes branch:** `model-views-3d-notes` was cut from an older `main`. Against today's `main` it also shows old copies of the handoff, the legal drafts and the store listing. **Don't merge the branch.** Cherry-pick only its two files (review 70 and the 3D section of `model-views.md`) onto `main`.
3. **Order (this fits the plan of 19 Oct, review 56: model views in the app come with the Library screens):**
   1. **A phone spike first, half a day, after the slice 2 retest.** Open the proven 4.8 MB room-size GLB in a WebView with the bundled three.js page on the founder's Xiaomi. Measure:
      - the time to the first frame;
      - the frame rate while orbiting;
      - the memory used.
      
      **Pass:** first frame under 4 s and at least 30 fps while orbiting. If it fails, decide on the tool before anything is built (for example, a lower triangle cap from the plugin).
   2. **Migration 34** (server), reviewed by the lead, live with the founder's yes, as the only file.
   3. **Plugin Part C** on the PC.
   4. **The viewer (Part B) inside slice 4:** the model view's page is the LV2 file page, so the viewer is built with it, not before.
4. **Migration 34, additions to Part A:**
   - **`may_upload`:** confirm that `view.glb` beside `view.jpg` and `thumb.jpg` in the unused `<space>/library/<p_id>/` folder needs no change (as review 57 R6). Test it.
   - **Retry (review 59 M1):** a retry with the same id must also match `glb_path`, or it returns a different publish.
   - **The size cap belongs on the bucket too.** `p_glb_bytes ≤ 20 MB` is only what the plugin claims, so also check the real stored size (`storage.objects.metadata->>'size'`, as `upload_mime` reads the mime).
   - **`box_size_m`:** exactly 3 positive values, each at most 100 m.
   - **`scope_label`:** at most 120 characters, trimmed. It's required when `p_scope = 'room'`.
   - **`my_model_views.has_3d`:** add it to the plugin contract in `data-model.md` §23.
5. **The viewer's safety (Part B):**
   - The three.js page and its scripts ship as app assets. The WebView loads **only** that local page, with no network: block every navigation and every request that isn't the app's own asset.
   - The GLB is handed over from the app's cache, never fetched by the page.
   - The page talks to the app through one message channel, with exactly two messages: element tapped and BIM view. Nothing else is accepted.
   - Three.js r128 is MIT-licensed. Record its source and licence in `assets/SOURCE.md`, as the fonts are recorded.
6. **No counts:** "3D · 4.8 MB" is the file's size, which is fine. Don't show the triangle count to users; it's a technical figure and stays in the plugin.
7. **Storage note:** with D5 (Supabase Pro, review 69), storage is 100 GB, not 1 GB, so the "about 200 views" limit no longer applies. Keep the 20 MB cap for phones on mobile data.
8. **Arabic:**
   - "View in 3D" / «عرض ثلاثي الأبعاد»;
   - "BIM view" / «عرض BIM» (BIM stays in Latin, as the glossary says);
   - the element sheet's labels for name, category and level: «الاسم»، «الفئة»، «المستوى».

## Not a founder decision
Everything here is technical or a matter of order within the decision he already made. Nothing new for him to decide.
