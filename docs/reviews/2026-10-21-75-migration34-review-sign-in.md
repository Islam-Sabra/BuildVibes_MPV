# Review 75: migration 34 (store-reviewer sign-in) approved, with B5 — 21 Oct 2026

Branch `claude/store-reviewer` (da98999). This covers migration `20261024120000_review_sign_in.sql`, its tests `34_review_sign_in.test.sql`, the `review-sign-in` function and the app's B3 and B4 changes.

## What I checked
- **On the stand-in,** every migration applies from scratch and **all 2,336 SQL checks pass** (34 files; 61 are new).
- **The re-created functions** differ from their previous versions only by the stated line:
  - `start_dm` against migration 22 (`20261016180000_dm.sql`);
  - `feed_page` and `posts_tagged` against migration 15 (`safety`);
  - the three policies against their latest definitions.
- **B1, the try counter:**
  - one row, locked `for update`, so tries sent at the same moment queue;
  - a try counts before the code is compared, and only `review_sign_in_ok()` clears it;
  - 5 tries without a right code lock it for 15 minutes, with at most 20 tries per UTC day;
  - the table has RLS on, no policies and no grants, and the two functions are for the service role only.
  
  The race from review 73 is closed. The code comparison is constant-time (SHA-256 of both, then XOR), and nothing is logged except the verdict.
- **B2, demo accounts apart:**
  - `demo_apart` covers profiles, follows, posts, Home, a project's posts and a new DM;
  - only the service role can set the `app_metadata` flags, so nobody can mark themselves a demo account.
- **B3:** no email code is sent to the reviewer address, and the code screen comes straight away.
- **B4:** the function's session goes through `setSession`, the same path as an email code.

## B5. Shared records made by a demo account stay among demo accounts (must, before the reviewer goes live)
A store reviewer clicks through everything, and both of these are shared records:
- `create_project` (up to 10 a day) makes a **project record every real person sees** in project search, in "similar projects" and when tagging;
- `register_company` (up to 5 a day) makes a **company every real person sees**, including signed-out people. By rule 4, a person's typed company name then turns into a link to the reviewer's "Test Co".

**Fix (migration 34, before it goes live):**
- Add `is_demo boolean not null default false` to `projects` and `companies`. A `before insert` trigger sets it from `is_demo_account(created_by)`. Nobody can change it afterwards.
- **Read policies:**
  - `projects_read`: `not is_demo or public.is_demo_account(auth.uid())`;
  - `companies_read`: the same, and signed-out readers never see a demo company.
- **Every security-definer function that reads `projects` or `companies`** gets the same line, because RLS doesn't cover them. At least these:
  - `find_similar_projects`;
  - the typed-company match;
  - project and company pages;
  - the project picker when tagging;
  - `shown_project` and merges, so a real project is never merged into a demo one and the other way round.
  
  List them all in the migration header.
- **Seed:** the demo project and company in `review_demo_seed.sql` come out as `is_demo`.
- **Tests:**
  - a project and a company made by the reviewer are invisible to a real person, both in direct reads and through each function above, and also to a signed-out reader;
  - the reviewer and the demo teammates see them;
  - a real project stays visible to the reviewer.

## Noted, no change
- **The reviewer address can be probed.** Five wrong codes for the reviewer address give 429, while any other address always gets 401. The address isn't secret, since it's given to Apple and Google, and the 429 tells a human reviewer to wait. Accepted.
- **Someone could lock the reviewer out.** The address is in the store build, so someone who finds it can use up the day's 20 tries, and the reviewer is then refused until midnight UTC. The chance of them guessing the code is negligible. The function is off between reviews (REVIEW_CODE cleared). **Add a step to `docs/store/review-sign-in.md`**: if the review team reports "try later", the founder runs, from the PC:
  ```sql
  update public.review_sign_in_state set fails = 0, locked_until = null, day_tries = 0;
  ```
  Then reply to the review team.
- **Speed:** `profiles_read` now looks up `auth.users` twice for each profile row. That's fine at pilot scale. If people search slows down later, cache the caller's flag once per query.

## Verdict
**Approved once B5 is in** and all SQL checks pass. With the founder's yes:
1. Push only `20261024120000_review_sign_in.sql`.
2. Deploy `review-sign-in` and set its secrets.
3. Run the seed.

Each of these is a separate live step from the PC. The sign-in stays off (no REVIEW_CODE) until the first store submission.
