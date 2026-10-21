# Store reviewers' sign-in — how it goes live (D4, review 69 §6)

Built in the cloud on branch `claude/store-reviewer`, 21 Oct 2026. **Nothing is live.** Each step below is a live change and needs the founder's yes, from the PC. Do it before the 13–19 Dec submission, and after migrations 33 and 34 are live (the demo seed sends an item back with a new date; migration 34 holds the try counter and keeps the demo accounts apart).

## What it is
- **`supabase/functions/review-sign-in/`**: one reviewer email and one fixed 6-digit code, both Supabase secrets, give a normal session. Anyone else gets the same answer as a wrong code. The tries are counted in Postgres (migration 34, `review_sign_in_try()` with a row lock), before the code is compared: five tries without a right code lock it for 15 minutes, and 20 tries a day is the most, even when many are sent at once. The logs carry only the outcome, never the email or the code. Tests: `deno test supabase/functions/review-sign-in/check.test.ts`, and `supabase/tests/34_review_sign_in.test.sql`.
- **The app:** only a build with `"REVIEW_EMAIL"` in `env/dev.json` sends that one email's code to the function, and it sends no email code to that address (it goes straight to the code screen). Every other email, and every other build, signs in by email code as today.
- **`supabase/ops/review_demo_seed.sql`:** the demo Space "Demo — Tower A" with two demo teammates who can't sign in. The reviewer is marked `review: true` and the teammates `demo: true` in `app_metadata`; real people can't find, follow or message them or see their posts, and they can't reach real people (migration 34).

## Steps (PC, founder's yes)
1. Create the reviewer account: Authentication → Users → Add user, with an address the founder owns (for example `appreview@<company domain>`), "auto confirm". Copy its id. Mark it as the reviewer in the SQL editor: `update auth.users set raw_app_meta_data = raw_app_meta_data || '{"review": true}' where id = '<the id>';` (the seed in step 5 does it again).
2. Sign in with it once in the app by email code, and give it the name "App Reviewer" in onboarding (country: Kuwait).
3. Secrets (Edge Functions → Secrets): `REVIEW_EMAIL`, `REVIEW_USER_ID`, `REVIEW_CODE`: a new 6-digit code for each submission, never reused (not 123456).
4. `supabase functions deploy review-sign-in` (it takes `verify_jwt = false` from `config.toml`).
5. Run `supabase/ops/review_demo_seed.sql` in the SQL editor, with the reviewer's id on its first line.
6. From the reviewer's phone, post one Document for receipt in the demo Space (the seed can't upload a file).
7. Build the store build with `"REVIEW_EMAIL"` set in `env/dev.json`.
8. App review notes: "Email: [reviewer address]. Code: [the 6 digits]. Sign in, then open the Space ‘Demo — Tower A’."
9. **Between reviews:** clear `REVIEW_CODE`. The function then refuses everyone.
10. **After each review:** check the reviewer account isn't scheduled for deletion (Apple reviewers often try Delete account): `select deletion_scheduled_at from public.profiles where id = '<the id>';`. If it is, restore it (sign in as the reviewer and tap Restore my account, or clear `deletion_scheduled_at`), then delete the demo Space and run the seed again (step 5) so the next review starts from the same Space.
11. After the pilot or if it is ever misused: delete the function, the secrets, the demo Space and the two demo users.
