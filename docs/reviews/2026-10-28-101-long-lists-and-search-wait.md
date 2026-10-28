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
