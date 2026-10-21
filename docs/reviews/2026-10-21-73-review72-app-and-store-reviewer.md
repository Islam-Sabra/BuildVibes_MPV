# Review 73: review 72's app part, and the store reviewers' sign-in — 21 Oct 2026

Two cloud branches:
- `claude/review72-app` (head `5ee3a3c`, from `slice2-retest` plus migration 33's two commits);
- `claude/store-reviewer` (head `ec8ad35`, from `main`).

I read `CLAUDE.md` and each branch's handoff first.

---

## A. `claude/review72-app`: review 72, the app part
**Verdict: the code and the wording are right. The screenshots aren't on GitHub, so the visual check waits for them (A1).**

### What I checked
- **The strings in both languages** match review 50 and the glossary:
  - "To do:" / «مطلوب منك:»;
  - "Nothing yet today" / «لا شيء بعد اليوم»;
  - New date / Today / Tomorrow / Pick a date / No new date: «موعد جديد / اليوم / غدًا / اختر تاريخًا / بلا موعد جديد»;
  - "new date {date}" / «موعد جديد {date}»;
  - "Done {time} · waiting for your check" / «منجز {time} · بانتظار تحققك».
- **The old keys are removed:** `daybookDueTodayStrip`, the two kind-menu description lines (F63), and `daybookDueStripEarlier`.
- **F61:** the strip is built from its parts (the label, then each item with its own day), so an earlier day is grey whatever the language. That's better than the earlier text search.
- **F62:**
  - nothing is chosen first, and Send back stays off until a date choice is made (rule 6);
  - "Pick a date" uses the writing card's picker, whose earliest day is today, so no date in the past;
  - the call matches migration 33 (`p_due_set`, `p_due`, `p_due_at`).
- **F59:**
  - "Today · date" at Now;
  - a Today divider always, with "Nothing yet today";
  - the "Today ↓" chip only when scrolled back, and the New chip wins when new things arrived;
  - every earlier day keeps its divider.
- **The base:** taken from `slice2-retest`, so the next test build is slice 2 only, and migration 33 was cherry-picked rather than merged. The trial merge into `slice2-app` and its six settled files are written in the handoff. Accepted.
- **SQL:** 2,217 checks on this branch, which is right without migrations 31–32; 2,275 on `slice2-app`.

### Fixes
- **A1. Screenshots:** `docs/screens/review72/` is git-ignored (`.gitignore` keeps only `slice1/` and `slice2/`), so the PNGs were never pushed. Add `!docs/screens/review72/` to `.gitignore`, commit the ten PNGs, push, and tell the founder. The lead checks them against E6 v14 (EN `2598:36360`, AR `2599:833`) and review 50 before the build goes on a phone.

### The two open points (design, the lead's call)
1. **An overflowing To do strip:** two lines and "…" is accepted, **on one condition: the whole strip is tappable.** It opens a sheet titled "To do" / «مطلوب منك» listing every item, oldest first, the day in grey, each row opening its card. No "+ more" and no number. Today a hidden third item can only be reached through Needs you, and that's not enough.
2. **"· no new date" on the history line: keep it.** It records the decision that was made ("Islam Ahmed · Send back: Not finished · no new date"), so nobody wonders where the date went.

---

## B. `claude/store-reviewer`: D4, the store reviewers' sign-in
**Verdict: well built, with one real security hole (B1) to fix before anything goes live, and two smaller fixes.**

### What holds up
- **Secrets:** the email, the user id and the code are Supabase secrets only, never in the app or the repo. The app holds only the email (`REVIEW_EMAIL`), which isn't a secret.
- **One answer:** not the reviewer, switched off, and a wrong code all give the same 401.
- **The code check** is constant-time (hashed, then compared byte by byte). The code must be exactly 6 digits, or the function is off.
- **The account must match:** the account id must carry the reviewer email.
- **The session** is a normal one (a magic link verified on the server). No password is turned on for anyone.
- **Logs:** they record only the outcome.
- **Off between reviews:** clearing `REVIEW_CODE` switches it off.
- **Tests:** 6 Deno and 3 app tests.

### Fixes
- **B1 (high): the 5-try lock can be beaten by sending many tries at once.**
  - **The problem:** the lock lives in the account's `app_metadata`, read, changed and written back by each request. Twenty requests sent together all read "0 fails" and all write "1 fail", so the lock never closes, and the 6-digit code (a million values) can be tried in parallel bursts.
  - **Fix:** keep the count in Postgres, changed atomically. A one-row table `review_sign_in_state` with RLS on and no policies, so only the service role reaches it, plus a function `review_sign_in_try()` that:
    - locks the row (`for update`);
    - refuses while locked;
    - counts the try **before** the code is compared;
    - locks for 15 minutes at 5 fails;
    - also stops at **20 tries in a day**.
    
    After a right code, the function calls `review_sign_in_ok()`, which clears the count. The Edge Function calls these with the service role.
  - **Tests:** 10 tries sent at the same moment: at most 5 are compared, the rest get 429. The daily cap holds. The table can't be read by anon or a signed-in person.
- **B2 (medium): the reviewer and the two demo teammates are visible to real people.**
  - **The problem:** people search, suggestions, follows and new DMs can reach "App Reviewer", "Omar (demo)" and "Sara (demo)". A real member could message an account nobody reads, or follow a demo person. "(demo)" is honest, but it shouldn't be found.
  - **Fix:** the seed and step 1 mark these accounts in `app_metadata` (`demo: true` for the teammates, `review: true` for the reviewer). The server leaves them out of:
    - people search and suggestions;
    - follow;
    - `start_dm` to or from anyone outside the demo Space;
    - the Home feed for everyone else.
    
    It goes in the same migration as B1, with a test that a real member can't find, follow or message them.
- **B3 (low): the app still emails a code to the reviewer address** when that email is typed. Skip sending for the build's reviewer email and go straight to the code screen. A real email is sent to the founder's inbox for nothing, and it can hit the send limit during a review.
- **B4 (low): account deletion during review.** Apple reviewers often try Delete account.
  - **Test:** after the function's sign-in, the app takes the same "restore your account?" path as an email-code sign-in for an account scheduled for deletion.
  - **Go-live step 10:** after each review, check the account isn't scheduled for deletion. If it is, restore it and run the seed again.
- **Accepted:** the timing difference between the reviewer email and any other email (the reviewer path calls the admin API). The email isn't secret: it's written in the review notes.
- **The go-live steps:**
  - step 3 becomes: "a new 6-digit code for each submission, never reused";
  - B1 and B2 are their own migration, numbered when written. The order is 33 (the send-back date), then 34 (3D, review 71), then this one, or whichever is written next takes the next free number.

### The demo teammates and the product rules
"Omar (demo)" and "Sara (demo)" don't break the founder's rules:
- the names say they're demo;
- they have no company (rule 4) and no country or city (rule 5);
- no number is shown anywhere (rule 3);
- the Space is clearly "Demo — Tower A".

The one risk is real people finding them, which B2 closes.

### The store listing leftovers (review 69)
Done right: the D3 note, «المكان المكتوب على بند العمل», and the reviewer sign-in line.

---

## Decisions for the founder
| # | Decision | Recommendation |
|---|---|---|
| D7 | Migration 33 (the send-back date) goes live, so the next build can go on your phone | **Yes.** From the PC: after `supabase test db` on `slice2-app` with `claude/review72-db` merged, push it as the only file, then the read-only check. |

The reviewer sign-in itself goes live only in December, after B1 and B2, with its own yes then.

## Fixes for Claude Code
1. **`claude/review72-app`:**
   - A1, the screenshots on GitHub;
   - point 1: the To do strip opens the full list when tapped.
2. **`claude/store-reviewer`:**
   - B1 and B2 (one migration, not live, with tests);
   - B3, B4, and the step 3 wording.
3. **The PC, after D7:**
   - migration 33 live;
   - a build from `claude/review72-app` on the founder's phone and the emulator.
   
   The founder's test then covers steps 3–7 of build 375, then F59, F61, F62, F63, and F60 with a real phone photo.
