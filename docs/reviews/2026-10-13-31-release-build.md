# Review 31: release build (week 9 part 2)

**Branch checked:** `release` at `ce4d9da`.

**Verdict:** approved, with one small fix. After it, build and send to testers.

## What I checked
- **Signing:**
  - release builds use only the upload key, and stop without it, never falling back to the debug key;
  - the key path (`../../BuildVibes keys`) resolves outside the repo;
  - `*.jks`, `*.keystore` and `android/key.properties` are git-ignored;
  - `docs/release.md` holds no secrets.
- **Crashlytics:**
  - it's off in the manifest until the app turns it on, and on only in release builds;
  - only the error type and stack trace are sent, never the message;
  - no user id, keys or logs are set;
  - the test proves names don't leak.
  - Native Android crashes are reported by the SDK on its own. They carry system messages, not anything users typed, which is accepted.
- **Version:** 0.9.0+1. The env comes from `env/prod.json`. Components and the debug banner are release-hidden, as already checked in review 27.

## Fix
- **Non-fatal UI errors.** In `FlutterError.onError`, record with `fatal: false`.
  - These are UI errors such as a layout overflow, which don't close the app. Marking them fatal would make the crash list look worse than the app is.
  - Keep `fatal: true` in `PlatformDispatcher.onError`.

## Then (stop after each)
1. **Merge `release` into main** after the fix, with analyze and tests run.
2. **Build the release APK** and upload it to Firebase App Distribution, as group "week9".
   - The founder adds the tester emails himself in the Firebase console. They are not sent to Claude Code and not put in the repo.
   - Release notes come in English and Arabic: "Test build 0.9.0. Use the test script you were sent."
3. **The test script, backup and measures** (review 30 parts 3 and 4).
4. **After 03:00 UTC:** read `cron.job_run_details` for `account-purge` and `reports-prune` (status and time only).
