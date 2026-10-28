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
