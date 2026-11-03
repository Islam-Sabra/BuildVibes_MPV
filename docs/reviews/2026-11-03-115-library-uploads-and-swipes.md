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
