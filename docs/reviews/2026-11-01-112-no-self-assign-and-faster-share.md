# Review 112: no work item for yourself, and a faster Space list (1 Nov 2026)

**Founder, 13:06–13:08 (build 880):** "Not allowed to assign myself. I can add a reminder to myself, but assign myself and show it to the team, why?" This **replaces review 50 F69's rule** that a work item may be for yourself.

**Status: decided by the founder. Small job, before review 109.**

## 1. A work item is always for someone else
- **The rule:** a work item's owner (For) is **another member**, never its author. What's yours alone belongs in **My notebook** (a to-do, with its reminder), which nobody else sees.
- **Server:**
  - `create_work_item`, `reassign_work_item`, `create_walk`, `create_from_message`, `share_note_to_space` (as a work item) and the scheduled `create_work_item` refuse an owner equal to the caller (`22023`, "a work item is for someone else");
  - the reminder "Someone" picker keeps its rules (a reminder for yourself is **Me**);
  - pgTAP for each.
- **App:**
  - **The For picker** no longer lists "You" (F69's "You" row goes).
  - **If the only other member** who can own an item is missing (you're alone in the Space), the picker says "Invite someone to give work items to." («ادعُ شخصًا لتعطيه بنود العمل.»), and Send stays off.
  - **The notebook share as a Work item** no longer defaults For to me. For is "Choose", and Post is off until someone is chosen.
  - A walk's lines and "make work items from a message" default each line's owner to Choose, not me.
- **Existing items** that are already for their author stay as they are: nothing is rewritten, and they can still be signed and checked as before. Only new ones and reassignments follow the rule.
- **Messages:** if the server ever refuses, the line is "A work item is for someone else. For yourself, use My notebook." («بند العمل لشخص آخر. لنفسك استخدم دفترك.»)

## 2. The Space list opens faster (technical)
- **Today:** the notebook share's Space list (`workItemSpacesProvider`) calls `fetchSpace` for every Space. That's 4 requests each, so a few seconds with 3 Spaces.
- **Fix:** one call, `my_postable_spaces()` (security definer, `search_path=''`), returns my Spaces with my `create_items` right and the last-used order, in one request. RLS-safe, with pgTAP covering a non-member, a Viewer, and someone who left.
- Keep review 110's loading line, error line, Try again and Crashlytics.

## Tests and shots
- EN and AR: the For picker without You; the alone-in-a-Space line; the notebook share needing Choose; the server refusals.
- Shots into `docs/reviews/shots-112/`. Stop before merging.

## The lead's check of `claude/r112` at `433a29f3` (1 Nov): accepted
- **SQL stand-in:** 3,572 checks pass in 57 files.
- **The rule is a `before insert` trigger on `work_items`,** so it covers every way an item is made, plus Give to and scheduling. A walk's or a message's parent is allowed only inside the server's own batch.
- **Older test files** turn the trigger off for their own setup with `alter table … disable trigger`, a test-only statement. File 58 tests the rule.
- **The shots match** in EN and AR: no "You" in For, Give to or the owner picker; the alone-in-a-Space line with "Post as a Note"; the share's For at Choose; the refusal line.
- **Handovers are confirmed out of scope.** Review 105B's handover of a removed or leaving member's open work to the admin may make the admin the owner of their own item. That's taking over, not giving yourself work, which is what the founder objected to.
- **Next, with the founder's yes:**
  - goldens;
  - merge into `slice2-app`;
  - migration `20261119120000` live;
  - a build on his phone.
