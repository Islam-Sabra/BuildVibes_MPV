# Review 115: Library uploads, who sees it, swipes, and small items (3 Nov)

**Status:** the founder's comments and the lead's calls, approved ("ok good", 17:08). Build after the founder's next phone checks. No new frames: each item reuses an existing screen; the shots show the change.

## 1. Library uploads like posts (the lead's call, after libfix)
- **Progress:** a file added in the Library appears in its folder or list at once, with "Uploading 40%" («جارٍ الرفع ٤٠٪» with Western digits: «جارٍ الرفع 40%»). The person can leave the screen; the upload carries on.
- **No signal:** the file waits on the phone and sends when signal returns, through the same outbox as posts. It shows "Waiting for signal" («بانتظار الإشارة»). It can be removed while waiting.
- **Failure:** "Couldn't upload · Tap to fix" opens the same line as the composer (Try again · Remove), with the size and type messages from review 113.
- **Tests:**
  - progress shown;
  - offline → queued → sent when back;
  - removing while waiting;
  - the start-up clean-up never deletes a queued Library file (B2's pending check).

## 2. Who sees it, in the Library's main list (founder, 17:07)
- Adding a file at the Library's top level shows one line before the upload starts: **"Who sees it: Whole Space · Change"** («من يراه: المساحة كلها · تغيير»).
- **Change** opens the folder choice: **Whole Space · A Team · A person · Only me**, as one single-choice control (rule 6).
  - Anything other than Whole Space puts the file in a matching folder: an existing one if there is one, otherwise a new one.
  - New folder names: "My files" («ملفاتي») for Only me, the person's or the Team's name for the others.
- Inside a folder nothing changes: the file takes the folder's sharing.
- **Tests:** the default, each choice, and the folder made only once.

## 3. Swipes (founder, 15:40)
- **Between the bottom tabs** (Spaces · Explore · Activity · Profile), on each tab's main screen only. The direction is mirrored in Arabic. Not inside a Space, a post, a sheet or the composer.
- **In a Space, between Work and Chat.** The switch at the top follows the swipe. Anything that already scrolls sideways (photos, chips, tables) keeps its own swipe, and nothing swipes while the composer is open.
- Android's back gesture from the screen edge must keep working.
- **Tests:** a swipe moves the tab, and in Arabic it is mirrored. Inside a Space, a swipe on a photo strip doesn't change the page.

## 4. Small items
- **"Whole Space" everywhere:** the template picker still says "Everyone".
- **Alerts setup on Xiaomi-type phones:** a fifth line, **"Lock BuildVibes in recent apps"** («اقفل BuildVibes في التطبيقات الأخيرة»), with a short how-to: open recent apps, hold the card, tap the lock. This is because B3 showed MIUI's SwipeUpClean closing the app 1.4 s after Home. No phone reports it, so it ticks on return.
- **The chat outbox:** a message that failed before 1015 (a 9.1 MB PDF on the founder's phone) must show as "Couldn't send · Tap to fix" in its Chat. Check that one still waiting is visible and can be retried or removed.

## Order
`claude/r115`, test first. `flutter analyze`, `flutter test`, emulator checks, shots in `docs/reviews/shots-115/`. Push, report, stop.

## The lead's check of `claude/r115` at `6be33c04` (3 Nov)
- **What was checked:** all 20 shots viewed (EN/AR), and the report read against this review. Accepted: Parts 1, 2 and 4, the merge note, and the chat outbox fix (it can never stick on "Sending…" again).
- **The swipe conflict, the lead's call:**
  - **One gesture model.** Hold a card = its actions. Swipe sideways = change page.
  - **Cards stop having their own sideways swipes.** Pin, Reminder and Archive move into the **hold bar** that review 113 made for Archive and Delete.
  - The hold bar shows only what that person may do on that post: Pin · Reminder · Archive or Delete. The order: Pin, Reminder, then Archive or Delete last, in red.
  - So swiping Work ↔ Chat works anywhere on the page, and never opens Archive by surprise.
  - **Tests:**
    - a swipe on a card changes the page;
    - the hold bar holds Pin, Reminder and Archive/Delete by rights;
    - the old card-swipe tests are removed.
- **Small fixes:**
  - The Xiaomi lock line's button says **"Show me"** («أرني»), not "Turn on", because it opens a how-to.
  - **The chat thread for the whole Space is called "Whole Space"** («المساحة كلها»), not "Everyone", in the thread list, the thread's header and the Chat tab. That makes one word in the whole app.
  - The DM thread's old "Not sent · Retry" uses the same "Couldn't send · Tap to fix" line and sheet as Space chat.
- **Noticed, not part of 115:** the Explore tab shows "This part of the app is being built." Explore's people search is in the MVP: it is planned in the polish round, before the freeze.
- **Verdict:** fix the above on `claude/r115`, then merge and build with the founder's yes.

## 5. "Italic" text in the notebook (founder, 17:42; the lead's call)
- **What the screenshot shows:** the notebook's typed letters ("xdfgh", "ffds") are drawn in a serif italic. The app's own numbers ("1.", "2.") and the screen's labels are drawn in Plus Jakarta Sans.
- **Why (the lead, from the code):** the notebook's text styles all come from `BvType`, and nothing in `lib/` sets italic outside Chat. So these are not normal letters. They are **Unicode "mathematical" letters** (𝑥𝑑𝑓𝑔ℎ, U+1D400–1D7FF), which some keyboards' "font" or "style" feature types instead of plain letters. The phone draws them with its own maths font. The Feed showed the same on 1 Nov.
- **Fix, test first:**
  - a `plainLetters()` function maps the Mathematical Alphanumeric Symbols (U+1D400–1D7FF), the fullwidth Latin letters (U+FF21–FF5A), the letterlike italic h (U+210E) and its siblings to plain letters and digits;
  - applied **when text is saved**, everywhere people type: notebook blocks and titles, posts and work items, Chat and DMs, comments, names and profile text;
  - it never touches symbols site work needs: ², ³, °, ½, µ, ±, ×, Arabic and Arabic-Indic text;
  - **no general NFKC:** it would turn m² into m2.
- **Tests:**
  - math italic and bold, script, fullwidth → plain;
  - m², 25°C, ½, «النص العربي» → unchanged;
  - a saved notebook block comes back plain.
- **Existing text:** fixed the next time it's saved. No data migration.
