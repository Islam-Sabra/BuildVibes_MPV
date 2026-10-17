# Review 51: fix round after the founder's slice 1 test — 17 Oct 2026

The founder tested slice 1 (af2802b) on his Xiaomi and the emulator. Every finding is in **review 50** (F1–F19), with its cause and fix; this review sets the order. Branch `slice1-fixes` from `slice1-daybook`. Push and report after each part.

**What already works on a real phone:**
- writing a work item;
- the camera and proof;
- a push with sound, after F9's phone fix;
- check by double-tap;
- send back, with its own slip;
- sign again, then check;
- no-signal sending;
- the Arabic layout.

## Part A: find the causes first (report before fixing)
1. **F18:** Islam's newest Home post isn't in Omar's feed. Did it reach the server? Does `feed_page` as Omar return it?
2. **F12:** search today's phone and emulator logs for any `FATAL EXCEPTION` in BuildVibes.
3. **F19, the duplicate replies:** the post "good moring" has three replies from Islam ("hello islam" ×2, "helllo islam"), and the founder doesn't remember sending three. From the server rows (ids, times), were they separate sends, or a retry that posted twice?

## Part B: reliability (the pilot depends on it)
- **F9:** pushes.
  - Retry getting the token;
  - re-register on each start;
  - "Notifications aren't reaching this phone", with **Fix it** (Xiaomi steps);
  - tokens not seen for 30 days are dropped;
  - an anonymous "no token" count.
- **F11:** pages are never stale.
  - The daybook **and the Home feed** reload when opened from a push, when the app comes back to the front, and when a push for that Space arrives while it's open.
  - Pull down to refresh.
  - A "New ↓" chip when reading older entries.
- **F17:** "Waiting to send" goes the moment the post is sent, with no duplicate slip.
- Whatever Part A finds for F18, F12 and the duplicates.

## Part C: getting around
- **F3 + F10:** Home → Spaces.
  - One compact header line, without "on site".
  - **Needs you:** the Space name first, then what happened, then ref and time. The whole card opens it, and Open sits on the end side.
  - **Your Spaces:** every Space once, never repeating a Needs you item.
  - **New Space** and **Enter an invite code** always reachable, and large when you have no Space.
- **F13:** every Activity row opens what it's about. Remove "REV F" and the A–F letters, or make their meaning plain.
- **F1:** **+ (Create)** opens a small choice: **"Post to everyone"** or **"Work item in a Space ▸"** (your last Space first, then the list).
  - It's one tap more for a post, and no dead end for a foreman looking for a work item.
  - Inside a Space, the "Work item" bar stays as it is.
- **F16:** long-press any slip → **Add update**, for everyone allowed. A short press shows the same menu until slice 5. The swipe stays only as a shortcut.

## Part D: signing and checking
- **F6:** "Sign as done" offers **"Without a photo"**, with the note required. Camera only when a photo is added.
- **F7:** "Sign as done" only opens the proof screen. After **Send as done**, a 5-second **Undo**, and nothing is sent until it closes.
- **F5:** a short, soft sound with a light haptic when a post or sign-off actually sends; haptic only on silent.

## Part E: words and layout
- **F4:** remove "site only" wording, as listed in review 50, in EN and AR. Grep both ARB files for "site" and "موقع", and list what's left in the report.
- **F15:** the Arabic time column fits "11:58 مساءً", or the period goes on a second line.
- **F14:** "تم الفحص" becomes **"تم التحقق"**, **only after the founder's "ok"**.
  - It covers the stamp, "تحقّق", "انقر مرتين على الصورة للتحقق", and the glossary in `CLAUDE.md` and `arabic-glossary.md`. English stays "Checked".
  - Until he answers, leave it.
- **F19:** the feed card and the post page to H1 (`2564:184` AR, `2555:35276` EN).
  - **Feed card:** ⋯ level with the name, the name in semibold with the headline under it, the body style directly under the author, the card hugging short posts, and the actions at the frame's size.
  - **Post page:** the replies as small slips, with the avatar, the name and time on one line, "Replying to…", the actions under the text, and the frame's reply bar.

## Part F: the server (migration 25, its own branch `test-fixes-db`, not live)
- **F2:** `add_reply` accepts a reply to any reply on the same post.
  - It stores the person answered (`reply_to_person`) and files the reply under the top comment.
  - The `post_reply` notification goes to the person answered (and the post's author, as now).
  - Tests: three levels; the notification goes to the right person; a deleted reply's answers stay put.
- **F9:** `push_tokens.last_seen_at`, refreshed on each start. Tokens not seen for 30 days are dropped by the nightly cleanup (service role).
- Push it alone, then report. It goes live with the founder's yes, as the only file in the push.

## Then
- Install the fixed build on the founder's phone and the emulator.
- The founder repeats the same test: about 15 minutes, now that Omar's account and the Space exist.
- Slice 2 starts after he says slice 1 works.

Not part of this round: **F8**, pages in a work item, which is slice 5.
