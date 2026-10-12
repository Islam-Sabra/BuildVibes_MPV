# Review 09: work items database (migration 7) and the Work tab — 12 Oct 2026

**Verdict: not ready to go live yet.** The steps, roles, numbering and read access are right, and all 277 SQL checks pass on my side too. An independent review found holes, though, mostly in photo storage. They decide whether "proof" can be faked, so fix all of them on `work-items-db`, add tests, push, and tell the founder so the lead can re-check.

## Must fix (blocks going live)
1. **Evidence can be swapped after the check.**
   - **Problem:** `space_files_update_own` lets the uploader replace or rename a photo at any time, even after the item is Checked and shown on a profile.
   - **Fix:** drop the update policy. Upload with names that never repeat (`<space>/<item>/<uuid>.jpg`), so a retry uploads a new name. Also refuse delete on any path that a `work_item_evidence` row points at.
2. **A made-up path counts as a photo.**
   - **Problem:** `add_evidence` / `sign_done` only check the path prefix. B signed done with `never-uploaded.jpg` and no note, and it became the public photo.
   - **Fix:** require the object to exist in `storage.objects` (bucket `space-files`), with `owner_id = auth.uid()::text`, under `<space>/<item>/`.
   - The same check applies to photos at creation.
3. **Any member (even a Viewer) can upload anywhere in the Space.**
   - **Fix:** the insert policy needs the path shape `<space_id>/<item_uuid>/<file>`, and the caller must be one of:
     - creating that item (a client-generated uuid not yet used, and `can(space,'create_items')`);
     - its owner (for done evidence);
     - its creator.
   - Viewers can't upload.
   - Add a size limit on the bucket (for example 10 MB) and allowed types: image/jpeg, png, webp, heic.

## Should fix now
4. **Items get stuck when the owner leaves or is removed.** There is no way to reassign them.
   - **Add `reassign_work_item(item, new_owner)`:**
     - the creator, or a member with `check_items`, may reassign;
     - it works only while the item is Open;
     - the new owner must be allowed to mark items done;
     - it writes a 'reassigned' event.
   - **Needs you:** Open items whose owner is no longer an active member go into the creator's Needs you, labelled "Owner left · reassign".
5. **The public photo must be the owner's Done photo.** `shown_work_photo` falls back to the creator's photo from when the item was raised. Use only `kind = 'done'` evidence. If there is no done photo, the public card shows none.
6. **Blocks:** `public_shown_work` must hide rows when either side has blocked the other (`not is_blocked_with(owner_id)`), the same as profiles.
7. **Deleted Spaces:** `is_shown_photo` must ignore items in a deleted Space, so their photos stop being readable.
8. **Speed:** the storage read rule calls `is_shown_photo` for every file. Look up `work_item_evidence.storage_path` first (it has a unique index), then join the item, and don't scan all shown items.

## Small
9. **Pass changed to Viewer:** `sign_done` must check `member_can(space, owner, 'mark_done')`. An owner changed to Viewer can't sign.
10. **Deleted accounts:** `public_shown_work` filters `owner_id is not null`.
11. **Hard deletes:** the append-only trigger blocks cascades, so hard deletes from the service role fail. Let the trigger pass when the current role is the service role, or when the delete comes from a cascade. Keep it closed for the app.

## Tests to add (`07_work_items.test.sql`)
For each finding above: the attack is refused and the normal path still works. That covers:
- updating or deleting evidence;
- a made-up path;
- a Viewer upload;
- an upload outside an item folder;
- reassigning, and the "Owner left" Needs you row;
- the done-photo rule;
- blocks;
- deleted-Space photos;
- a Viewer signing;
- the deleted owner.

## Work tab (S20): passed, one fix
Checked against `docs/design/work/S20-work-*`, in English and Arabic: the title block, the privacy line, the five filters, the sections, the cards, the red overdue line and the empty state. All are correct, and the Arabic reads well (المكلّف, «…» quotes, dates).

**Fix:** the "New item" button covers the bottom of the last card ("Photos of upstands before the s…"). Add bottom padding to the list, the button's height plus 16, so the last card can scroll clear of it.
