# Review 101: long lists build only what's on screen; one search wait — 28 Oct 2026

**The lead's technical call** (no product change, no design change, no database change). It's done before the test week (18–24 Jan), when real Spaces will hold weeks of posts.

## A. Long lists build only what's on screen
**The problem:** the Daybook (`daybook_tab.dart`) and a notebook page (`notebook_page_screen.dart`) build every card at once, in a plain `ListView` with all its children. After 4 weeks, a busy Space holds hundreds of cards with stamps and photos, and building them all at once makes opening it slow on a mid-range Android phone.

**The rule:**
- Both screens build their items **lazily**, only those on screen plus a small margin: `ListView.builder` or `CustomScrollView` with slivers.
- The feed already loads in pages, and the chat thread already builds lazily. Leave both as they are.
- **Nothing the user sees changes:**
  - **Daybook:**
    - the order (newest activity at the bottom, at "Now");
    - day dividers, the moved-card traces, pinned announcements, the masthead and month drop-down;
    - jumping to a card from Needs you, search or a notification, and its highlight;
    - "Waiting to send" and the no-signal strip.
  - **Notebook page:**
    - sub-page rows, day groups, Draft cards, "Archived ›";
    - the swipe, selection and keyboard behaviour from review 100;
    - jumping to an entry from Filter or search.
  - Scroll position is kept when a card updates live.
- **The safety net:** all 446 screenshot shots pass **without updating**. If one changes, stop and report it; don't accept it.

**Tests (test first):**
- A widget test with a seeded Space of 500 posts across 30 days. It asserts that only a bounded number of cards are built after the first frame, and that jumping to post 450 builds it and shows it highlighted.
- The same for a notebook page with 300 entries.
- The existing Daybook and notebook tests all still pass.

**A seed for manual testing:**
- `supabase/dev/seed_busy_space.sql`, for local and stand-in use only, never live;
- it makes one Space with 500 posts of every kind, photos as placeholders, over 30 days;
- it makes one notebook with 300 entries over 5 pages.

## B. One search wait
Five searches each wait 300 ms after typing: people, inside a Space, notebook, company picker, add project. Two use `BvAuthSpec.searchDebounce` and three write their own 300.
- Make one token, `BvMotion.searchWait` (300 ms), and use it in all five. Remove the local constants.
- Add a guard test that no `Duration(milliseconds: 300)` used as a search wait remains outside the token.
- Behaviour is unchanged.

## Lead's check (28 Oct, 11:20)
**B, `claude/r101-search-wait` at `d116b5e`: approved.**
- There is one token, `BvMotion.searchWait`, used by the five searches, and the local constants are gone.
- The guard test failed first, and no shot changed.
- It merges into `slice2-app` with the next build. There's no database change.

**A, `claude/r101-lists` at `20b13fc`: stopped correctly. The lead takes option 1, with a precise rule for the paper clip.**
- **The 47 tests** check behaviour, not how many widgets are built. Change them to work with a lazy list:
  - scroll to the card they check (`scrollUntilVisible`, or jump the way the app does);
  - read cards in screen order, not tree order.
  - Every changed test must still assert the same thing. **List each changed test** in the report, with one line on what it asserts before and after, and don't remove an assertion. The lead checks the list.
- **The paper clip:** it must sit on top of the card above, exactly as now.
  - **Don't move or redraw the clip.** Keep the painting order: build the Daybook so the newer card is painted after the older one, as before.
  - For example, use a `CustomScrollView` with a `center` sliver: older days grow upward from the centre, and the newest (at "Now") is painted last. Don't use a `reverse: true` list.
  - The 60 shots must then pass without updating. If any still changes, stop and report it again.
- **Then do the notebook page the same way, and add the seed** (`supabase/dev/seed_busy_space.sql`, local only).

## Lead's second check (28 Oct, 14:45): A approved after K1–K3
**Branch:** `claude/r101-lists` at `7b452c3`.

**What I checked:**
- All 446 shots pass without updating, and 2,324 tests pass.
- **The list of 24 changed tests:** each still asserts what it did before, now in screen order or after scrolling. No assertion was removed, and two were added. Accepted.
- **The Daybook's render code.** I read it:
  - a viewport that corrects "bring into view" for the centre at the foot of the page;
  - a sliver group and a sliver list that paint top to bottom while growing up from Now, and take taps in the reverse order;
  - a padding sliver that keeps a short page at the top.
  - These are custom `Render…` classes over Flutter internals. They keep the prototype's paper clip exactly. **The cost is that they can break on a Flutter upgrade,** so they need guards.
- **The per-row `RepaintBoundary` is gone:** accepted. Only the visible rows paint, so it is cheap.
- **The notebook page** now builds its rows lazily, keyed, so swipe and selection state stays with the right entry: accepted.

### Fixes
- **K1. Taps go to the card that is drawn on top.**
  - A widget test: tap on the paper clip where it overlaps the card above. The newer card (the clip's own) gets the tap, not the card under it.
  - Plus one tap in the middle of each of three stacked cards, each hitting its own card. EN and AR.
- **K2. A guard for a Flutter upgrade:**
  - a test that fails if `_RenderSliverListTopDown` or `_RenderPageGroup` stops being used by the Daybook;
  - a line in `docs/handoff.md` and in `CLAUDE.md`'s technical section: *"After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101)."*
- **K3. Measured on a phone, not only in tests (PC):**
  - use the busy seed on the local stack, with a profile build on the founder's phone, or a mid-range emulator if the phone isn't reachable;
  - report the time to open the busy Space, and dropped frames while flinging through 500 posts, on `slice2-app` and then on this branch;
  - numbers only, no target. They give a base for the test week.

### Then, with the founder's yes
1. Merge `claude/r101-search-wait` and `claude/r101-lists` into `slice2-app`.
2. Run every check on the merged branch.
3. Make one build on his phone. There's no database change.

## Lead's note on K3 (28 Oct, 15:20): drawing got slower; investigate before the test week
Build 701 (`slice2-app` at `25bc211`) is on the founder's phone. Its behaviour is right, and every shot is unchanged.

**The emulator measure:**
- **Building frames got much cheaper:** 0 slow frames instead of about 500.
- **Opening got faster.**
- **Drawing got slower:** about half the frames went over budget while flinging (1,903 of 3,900), against about 10% before (286 of 2,689). The average draw time is 16 ms, against 10.9 ms.
- The emulator draws through a translation layer, so this isn't proof. But it's a real warning.

**L1. Find the drawing cost** (`superpowers:systematic-debugging`, PC):
1. **Measure on a real phone, without wiping data.** Build a **profile** build signed with the **upload key**, the same signature as the release, so it installs over the release and keeps the data. Measure the busy seed on the local stack, or the founder's own Spaces, then put release 701 back.
   - If a second Android phone is available, use that instead.
2. **Open DevTools on the raster thread** for a few slow frames, and name what costs:
   - the cards' shadows (`BoxShadow` blur);
   - a `saveLayer` (an opacity, a clip with antialiasing, or a `ShaderMask`);
   - the tilted ink stamps;
   - or the custom paint order drawing rows outside the screen (check that `remainingPaintExtent` and the cache area aren't drawn).
3. **Fix the cause.** The target: slow drawing frames **no worse than on `slice2-app` before review 101**, on the same device and seed. The shots stay unchanged.
4. **If that isn't met before 10 January:** the Daybook goes back to the old way of building rows. The notebook keeps its lazy list, which has no paper clip. The lead decides then.

## L1 result (28 Oct, 19:50): no regression on the emulator; confirm on the phone
**Branch:** `claude/r101-l1` at `d3434ee`. No app code changed, and no shot changed.

**The measure:** the Pixel 8 emulator in profile mode, the busy seed, 20 flings, with the before and after builds made from the same settings.

| | Before | After |
|---|---|---|
| Frames that missed a vsync (gap over 25 ms) | 55 of 254 | 1 of 254 |
| Frames that missed two vsyncs | 8 | 0 |

**The cause is found and accepted:**
- Raster time now includes the wait for the next vsync, because every frame is ready on time. Preparing the drawing commands takes about 5 ms.
- Render passes are the same before and after (16 per frame), which rules out shadows, stamps, `saveLayer` and off-screen rows.
- **What the user sees improved.**

**Open:** confirm on the founder's phone (the phone was locked). It takes about 15 minutes with him there, using `tool/perf/record_timeline.dart` on his Space NBKCH SITE TEAM.
- **If his phone also shows few missed vsyncs:** L1 closes.
- **If not:** L1 reopens with the phone's numbers.

**Accepted:** the recorder tool, with `flutter_driver` and `vm_service` as dev dependencies only. It merges with the next build.

**Rule for profile builds:** a profile build signed with the upload key may go on the founder's phone only while he is there, and release goes back on right after. The signing change is never committed.

## L1 closed (28 Oct, 20:20): confirmed on the founder's phone
**Measured on his Xiaomi:** NBKCH SITE TEAM, 10 flings, `claude/r101-l1` at `b45aa2b`.

| | Before review 101 | Now |
|---|---|---|
| Slow builds | 56 | 3 |
| Missed vsyncs | 71 of 520 | 14 of 597 |
| Two vsyncs missed | 37 | 5 |
| Raster time, median | 6.4 ms | 5.9 ms |

- **Drawing costs the same before and after.** Review 101 did what it was for.
- **What's left is noted, with no step now:** 5 misses while opening, and 1–2 per fling back to older posts, as older rows are built (12–16 ms).
  - Look at it again only if the test week's users feel it.
  - Then the first candidates are a larger cache area for the older direction, and decoding photo thumbnails ahead.
- **The recorder** (`claude/r101-l1`) merges with the next build. It's a dev tool only.
