# Review 69: the cloud session's work of 20–21 Oct, reviewed by the lead — 21 Oct 2026

Branch `claude/test-tw7wuv` (head `8af5dee`). I read `CLAUDE.md`, `docs/handoff.md` and the end of `docs/progress.md` first. This review covers six things: reviews 67 and 68, migration 32, S7-N, the positioning rule, the business drafts and store sign-in.

**SQL:** on my stand-in (Postgres 16 with `supabase/dev/standin/`), every migration applies from scratch and **all 2,251 checks pass** (32 files, 41 in test 32).

---

## 1. Review 67, the slice 4 plan, checked against P1, P2, V1, LV1, LV2 and S
The plan matches the six frames. The order (P1, P2, LV1, LV2, S, then the V1 fix) is right, and so is the list of what's out of scope.

### 1a. P2, letting someone in: nothing chosen first — **confirmed**
The frame shows the state after tapping Crew, not a default. Letting someone in must be a deliberate choice:
- a Lead by default would hand out checking rights by accident;
- Crew by default would let a stranger with the code post on day one.
- The cost is one tap. Until a pass is chosen, the pill is grey and reads **"Choose a pass"** / **"اختر التصريح"**. After that it reads "Let in as Crew". A wrong pass can be changed later on the member's pass screen.

### 1b. No Add file button in the Library — **changed: a shortcut that still goes through a post**
The rule stands: **every file enters through a post.** That way it's in the daybook, it reaches everyone, it can be marked Received and it goes into the daily report. But a Library with no way to add a file leaves people stuck at the exact place they look for it. So:
- **For people who may add files, the Library has one quiet row at the end, "+ Add a file" / "+ أضف ملفًا".** It doesn't upload on its own. It opens the Work tab's writing card at Now, with the kind set to **Document for receipt** and the file chooser open. The person can switch to Note before posting.
- **"Add a new version" on a file's page (LV2) works the same way.** It opens the writing card as a Document for receipt, with "Replaces Rev D" already set to the version in use.

  **This matters for migration 32:** `library_overview.new_for_me` needs a live file post by someone else. A new version added straight through `add_library_file(p_supersedes)` would have no post, so it would **never** show NEW VERSION and could never be marked Received. **The app must never add a new version without its post.**
- **Figma:** no new frame. The row looks like any Library row: the + icon, the main size and grey text.

### Other points for the build
- **P1:** the invite row shows the code from `current_invite`; the frame's "KCT-4821" is only a placeholder. Someone who may not invite sees no code row. **"+ New team" is for the admin only** (see 3).
- **LV1:** "Rev D · 2 older versions · today" is fine, because the number counts the file's own versions, not people. Faces only, with no "3 received".
- **LV2:** the Received pill acts on `library_file_post`. When there is no post (a PDF that came from chat), show no pill and no "Received by" line, rather than an empty state.
- **S, Search:** it searches after 2 characters, with no result count. Empty shows "Nothing found for “…”". A checklist point shows under its post. An older version never shows (migration 32).
- **Arabic:** there are no AR frames. The build follows the EN frames mirrored, with the glossary's words. The lead checks every Arabic screenshot at 390×844 before the founder's test, in particular:
  - the pass tags: مسؤول / فريق تنفيذ / مُطّلع;
  - "Let in as …" / «اقبله كـ …»;
  - the NEW VERSION stamp «نسخة جديدة»;
  - Received «استلمت».

## 2. Migration 32 and review 68 — **approved to go live**, as already agreed (after 31, as the only file)
- **Every new function** is security definer with `search_path = ''`. `library_file_in_force` is internal (revoked from signed-in people too). The other three are for signed-in people only.
- **`search_space` differs from its previous copy** (`20261016120000_post_pages.sql`) by exactly one line: `and public.library_file_in_force(f.id)`.
- **`can_read_library_file` is false for a deleted file,** so the in-use check treats a deleted newer version as absent, and the recursion through deleted versions (M1) is right.
- **Receipts** come only from posts the caller can see, a blocked person is left out, and receipts belong to one version (its posts). That's right: receiving Rev C is not receiving Rev D.
- **Accepted, as review 68 says:** L1 (two versions replacing the same file) and L3 (a Received on a cancelled post still counts).
- **One app note, not a server change:** a new member who never had the older version still sees NEW VERSION on a file that replaces one, until they tap Received. That's acceptable, because the stamp means "a newer version than before, not yet received by you".
- **The real risk is in the app, not the SQL:** see 1b. Without a post, NEW VERSION never shows.

## 3. S7-N, who can make a Team — **business decision** (below), the app's wording is fixed
- **Today:** the server lets only the Space admin create a Team (`create_team`), and the app says so.
- **Why admin-only is safer:** a Team decides who sees what. Team posts are hidden from the rest of the Space, so making one changes visibility for everyone. That's an admin power, like letting people in. For the pilot, with one admin on site, it costs nothing.
- **If the founder agrees:** the S7-N frame's line changes to "The Space admin can do this". The lead updates it in Figma, and there's no server change.

## 4. Positioning and the welcome lines — **business decision** (below)
"The construction community around you." and "Built for {country} construction" don't call BuildVibes an app for sites, so they **don't break the rule.** The wording of the rule needs one adjustment, though:
- **The rule says taglines "say AECO".** But "AECO" is jargon a foreman doesn't know, and rules.md already says to avoid jargon on general screens.
- **Recommendation:**
  - **In the app and in store text people read:** use "construction" / «البناء» as the umbrella word, as the industry in the Gulf already does ("construction industry" covers architects, engineers, consultants and suppliers). Never use "site" as a description of the app.
  - **"AECO" only where professionals or machines read it:** store keywords, the legal "what BuildVibes is" line (spelled out once, as the Terms do), and investor and partner material.
- **So both welcome lines stay.** The store's Apple subtitle changes (see 5c).

## 5. Business drafts, checked against the app's words and the glossary
### 5a. Terms (`docs/legal/terms-draft-en.md`)
Good, plain and close to what the app does. Fixes:
1. **§7 "daily backups":** only promise this once the live project is on a paid Supabase plan with daily backups. On the free plan there are none (business decision D5 below).
2. **§4 "a photo, the place":** say **"the place typed on the work item"**, so nobody reads it as GPS. Photos lose their location (privacy §1).
3. **§3:** add one line: "Who may make a Team, and see a Team's posts, is set by the Space admin."
4. **§10:** "Settings → Help and feedback" exists. Keep it.

### 5b. Privacy (`docs/legal/privacy-draft-en.md`)
1. **The settings paths are wrong:**
   - Download my data and Delete account are under **Settings → Account and security**, not "Settings → Privacy" or "Settings → Account". Fix both in §3 and §4.
2. **Crashlytics** "never … an id" is **not accurate.** Crashlytics keeps a random installation id, the device model, the operating system version and the app version. Write: "Crash reports carry a random install id, the phone model and system version, and where in the app the error happened. Never your name, email or what you typed." The store's data safety must match (5c).
3. **Add the Home feed:** "A post you make **to everyone** in the Home feed can be seen by every signed-in person." Today §2 doesn't say who sees a public post.
4. **Add Activity:** "The people in a Space can see that you marked Received or ticked a point. The author of an announcement or activity sees who tapped Got it or On my way." The receipts and ticks are personal data that others see.
5. **§3 backups:** "[days]" becomes **7** on Supabase Pro (D5).

### 5c. Store listing (`docs/store/listing-draft.md`)
1. **Apple subtitle:** drop "AECO" (jargon, see 4).
   - EN: **"Daily work, checked and proven"** (30 characters).
   - AR: **«العمل اليومي، مُتحقَّق ومُثبَت»**.
2. **"A Lead checks it" is wrong.** In the app, **the person who raised the item** checks it or sends it back, whatever their pass.
   - EN: "The person who raised it checks it, or sends it back with a reason."
   - AR: «ويتحقق منه من أنشأه، أو يُرجعه مع السبب».
3. **Arabic words, to match the app:**
   - "daybook": «في يومية واحدة للفريق», not «دفتر يومي». The app says «يومية فريقك».
   - "Home feed": «الأخبار», not «صفحة رئيسية».
   - "My notebook and My calendar": «دفتري وتقويمي» is fine. The app says «تقويمي».
   - «ومدير المساحة يقبل من ينضم» is fine.
4. **Data safety:**
   - Add **"Device or other IDs: yes"** for Crashlytics, as well as the push token, plus **"Diagnostics"**. Crash logs: collected, **not linked** to the person, for app function.
5. **Delete account path:** **Settings → Account and security → Delete account.** Google also requires a **web page** that explains deletion (D4).
6. **Long description:** "Free during the pilot" is fine for December. Remove it before any public launch.
7. **Keywords:** "AECO" is right here (see 4).

### 5d. Quick guide (`docs/pilot/quick-guide.md`)
1. **Step 3:** "Needs you" isn't inside the Space.
   - EN: "**Home → Spaces: Needs you** lists what is waiting for you. In the Space, the paper clip marks your cards."
   - AR: «**الرئيسية ← المساحات: بانتظارك** فيها ما ينتظرك. وفي المساحة، المشبك يميّز بطاقاتك».
2. **Step 5, "For Leads":** it should be **"Raised the item? Check it, or send it back"** / «أنشأت البند؟ تحقّق منه أو أرجِعه». Checking belongs to the author, not to a pass.
3. **Arabic:**
   - «الدفتر اليومي» becomes «يومية الفريق»;
   - «موعد التسليم» becomes «الموعد», as on the card;
   - «اضغط على الصورة مرتين» becomes «انقر مرتين على الصورة», as in the glossary.
4. **Arrows:** in right-to-left, "←" points onward, which is correct.

### 5e. Pilot targets (`docs/product/pilot-targets.md`)
The four measures and their numbers are sensible and match mvp-plan §1:
- none of them measures lateness (F57);
- none is ever shown in the app (rule 3).

**Recommended for approval as written** (D2). One addition: write down the **roster size** in the pilot agreement on day 1, because target 1 depends on it.

## 6. Store reviewers' sign-in — **business decision** (below), with this design
Apple and Google need a working sign-in, and email codes go to an inbox the reviewer can't read. The recommended design is **one reviewer account with a fixed code**:
- **Server:** an Edge Function `review_sign_in(email, code)`.
  - It only answers for **one email**, held in a project secret, never in the app or the repo.
  - It compares the code with a **second secret**. When both match, it issues a normal session for that account, through the admin API, with no password turned on for anyone.
  - It is rate-limited and logged.
- **App:** nothing special. The code screen calls the function only when the typed email equals the reviewer address. Every other email works as today.
- **Data:** the account sits in **one demo Space** with sample work: a work item from each state, a checklist, an announcement, a document, chat and a DM. It is never a member of a real Space.
- **Between reviews,** the function is switched off by clearing the code secret.
- **Store text:** "Email: [reviewer address]. Code: [6 digits]. Sign in, then open the Space ‘Demo — Tower A’."
- **Build:** a small migration-free Edge Function, plus a seed script for the demo Space, each reviewed before going live.

---

## Decisions for the founder
| # | Decision | Recommendation |
|---|---|---|
| D1 | Who can make a Team (S7-N) | **The Space admin only, for the pilot.** Revisit if Leads ask. |
| D2 | Pilot targets | **Approve as written**, and record the roster size on day 1. |
| D3 | Positioning words | **Keep both welcome lines.** In the app and in store text people read, use "construction" / «البناء». "AECO" only in keywords, legal and business documents. |
| D4 | Store sign-in for reviewers | **Yes to one reviewer account with a fixed code** (an Edge Function, secrets on the live project, a demo Space). |
| D5 | Supabase plan | **Move the live project to Pro before the pilot.** It gives daily backups kept 7 days, no pausing, and a backup the Terms can promise. |
| D6 | The blanks | Minimum age **18**. Company name and address, the support email, the WhatsApp help number, and a web page for account deletion (Google). |

## Fixes for Claude Code (on `claude/test-tw7wuv` or the next work branch)
1. **review 67:**
   - P2 "Choose a pass" (1a);
   - Library "+ Add a file" and "Add a new version" both open the writing card as a Document for receipt, and a new version is never added without its post (1b);
   - LV2 with no post shows no Received pill (1, other points).
2. **Terms** 5a.1–5a.3; **Privacy** 5b.1–5b.5; **store listing** 5c.1–5c.6; **quick guide** 5d.1–5d.3.
3. **rules.md:** reword the positioning line as in 4 (after D3).
4. **After D4:** the reviewer Edge Function and the demo Space seed, on their own branch, for the lead's review.
5. **Handoff and progress** updated.

## Lead to-do
- After D1: change the S7-N frame's line to "The Space admin can do this".
- When slice 4 is built: check every Arabic screenshot at 390×844 (no AR frames exist).

## Founder's decisions (21 Oct, 09:24: "ok" to all six)
- **D1:** only the Space admin makes a Team, for the pilot. The lead updates the S7-N frame's line.
- **D2:** the pilot targets are approved as written. The roster size is written down on day 1.
- **D3:** both welcome lines stay. In the app and in store text people read, the umbrella word is "construction" / «البناء». "AECO" only in keywords, legal and business documents. **Claude Code:** reword the positioning line in `rules.md` to say this (fix 3 is unblocked).
- **D4:** yes to one reviewer account with a fixed code (an Edge Function, the email and code as secrets on the live project, a demo Space, switched off between reviews). **Claude Code:** build it on its own branch for the lead's review, before the store submission (13–19 Dec). Its going live needs its own yes.
- **D5:** the live project moves to Supabase Pro before the pilot (daily backups kept 7 days). Founder to do. Then the Terms may say "daily backups", and the Privacy policy "kept for 7 days".
- **D6:** the minimum age is **18**. The founder provides the company name and address, the support email, the WhatsApp help number, and the web page for account deletion.
