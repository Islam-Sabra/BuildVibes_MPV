# Review 22: push recheck and go-live plan — 13 Oct 2026

Branches `push-db` (2697493) and `push` (78f21f4). All 635 SQL checks and the 7 message tests pass on my side. The independent review re-ran every probe, and all review 21 fixes hold:
- deleted text leaves the queue;
- retries respect Retry-After and stop after 5 attempts, and a stuck claim is picked up again after a minute;
- old rows and old phones are pruned;
- the function trusts only the row id;
- the narrow dead-token rule, and the constant-time secret check;
- 10 phones per person;
- a push error never blocks a post or a message.

The new functions are service role only. The claim design (a separate "claimed" time, with "sent" set only after a real send) is **accepted**: it is better than my sketch.

The app screenshots pass: the prompt reads "Allow BuildVibes…", and the English "push off" screen has the faded switches.

## A. Last fixes, in place (nothing is live)
1. **Don't use a dashboard webhook.** The dashboard stores the secret header as plain text in the database catalog, readable by every database role. It would also land in any `db pull` or dump.
   - Add `supabase/ops/push_webhook.sql` instead: a `security definer` trigger function on `push_queue` insert. It calls the function with `net.http_post`, reads the secret from Vault (`push_webhook_secret`), sends only `{record: {id}}` with `timeout_milliseconds := 5000`, and raises a warning instead of an error.
   - Not run yet; it's a go-live step.
2. **`SENDER_ID_MISMATCH` must not delete phones.** With the key of another Firebase project, one push would wipe every phone.
   - Remove it from the dead-token rule in `message.ts`; it counts as a failure.
   - Update the test.
3. **A slow send could be sent twice.** Add `signal: AbortSignal.timeout(10_000)` to both `fetch` calls (the Google token and FCM), well inside the 60-second claim window.
4. **After the 5th failed attempt,** `release_push` marks the row finished (`sent_at = now()`) and sets `message_text = null`, so the text doesn't wait a day for the prune. Add a SQL test.

Push both branches. No further lead recheck is needed for these four: they are narrow, and each has a test.

## B. Go-live, in this order (founder's yes given with review 22)
Stop and report after each step. Stop at once if anything differs from the plan.
1. **Migration 14:** the dry run must list only `20261012190000_push.sql`, then push it.
2. **Secrets:**
   - Generate a long random webhook secret. Store it **in Vault** as `push_webhook_secret` and as the function secret `PUSH_WEBHOOK_SECRET`. Never print it.
   - The founder creates the Firebase key (Firebase → Project settings → Service accounts → Generate new private key). He pastes its contents himself into Supabase → Edge Functions → Secrets as `FIREBASE_SERVICE_ACCOUNT`, then deletes the downloaded file. Wait for him.
3. **Deploy** the `push` function (`verify_jwt = false`).
4. **Run** `supabase/ops/push_webhook.sql` and `supabase/ops/push_cron.sql`. Then list `cron.job` and confirm the two jobs.
5. **Phone test:** a real Android phone signed in to a test account. Follow it from a second account → the push arrives, with no Space or project name → tap → the profile opens. Then switch "New followers" off → no push.
6. Merge `push-db` and `push` into main and update `docs/progress.md`.

Week 7 is done after step 6. Week 8 follows: Arabic pass, market pack, privacy, report and block, delete account. The founder's decisions from review 16 §6 (Translate, Save/Share, @mentions) are needed before the week 8 brief.
