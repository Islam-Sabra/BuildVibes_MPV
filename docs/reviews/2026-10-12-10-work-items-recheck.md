# Review 10: work items re-check, and week 5 part 2 — 12 Oct 2026

## A. Database (migration 7): passed, so it can go live
I re-ran everything on `work-items-db` at commit 1018920: all 309 SQL checks pass on my side. The independent review re-ran its attacks for all 9 findings of review 09, and every one is now refused while the normal path still works.

**Next steps, with the founder's yes:**
1. Merge `work-items-db` and `work-items` into main.
2. Put migration 7 live.
3. Point the emulator back at the live project, and remove the debug-only http setting if it's no longer needed.

### Follow-ups: one new migration (8) together with part 3
None of these is a security hole, but fix all of them before the pilot.
1. **Stuck items, part 2.** When both the owner and the creator have left, nobody is told.
   - Show "Owner left · reassign" to the creator if they're still active.
   - Otherwise show it to every active member with `check_items` (admins included).
2. **Owner changed to Viewer.**
   - Treat an owner who can no longer mark items done as "owner left": the item drops out of their Needs you, and reassign is offered.
3. **Uploads before the item exists.** A member can list another person's photo folder for an item not yet created and take its id first.
   - Fix: until the item exists, only the uploader can read files in that folder.
   - Also: `create_work_item` refuses an id whose folder holds files uploaded by someone else.
4. **Reassign history.** The 'reassigned' event stores both the previous and the new owner. Show it in Discussion as "Reassigned from A to B".
5. **Storage that never becomes an item.**
   - Limit each person to about 200 MB of photos that aren't linked to an item.
   - Add a nightly cleanup of orphan files older than 7 days: a scheduled function, or a note in `docs/progress.md` if that has to wait for the paid plan.
6. **Events trigger:** the `pg_trigger_depth() > 1` exception would also let through any future trigger that writes events. Narrow it to cascades from deleting a work item or a Space, or to the service role only.

Tests for each, in `08_work_items_followups.test.sql`.

## B. Week 5 part 2 screens: passed, with 2 visual fixes
Checked in English and Arabic against `docs/design/work/`:
- W2;
- W3a, W3b, W3c, W3d, W3e.

The layout, banners per state and role, the sign-off strip and the photo tags are right, and the Arabic is correct (أُنشئ / منجز / تم الفحص, إرجاع, افحص وأغلق, «…»).

1. **The CHECKED stamp is far too small.** In W3d it's a tiny, unreadable label. In Figma it's a large rubber stamp across the top of the site tag:
   - about 30 high;
   - green border 2 px, rotated about −4°;
   - text "CHECKED · 10 OCT · S. AL-MANSOUR" in caps, bold, about 12–13 px.

   Use BvStamp at its large size. This stamp is the proof moment, so it must read clearly. In Arabic: "تم الفحص · 10 أكتوبر · S. Al-Mansour".
2. **The comment box is too heavy.** Figma has a single-line pill "Add a comment" field that grows when typing. The send action is an icon inside the pill, shown only when there's text. Today the app shows a large empty box with "Send" outside it.
