# Review 119 — signed-in devices, with one main device (proposal)

**From:** the founder, 4 Nov 2026: "show the number of devices connected, make one main device, and from it remove other devices or other links."
**Status:** recorded, with the lead's proposal. **Not scheduled** until the founder answers the three decisions at the end. Frames get drawn after that.

## Why it matters on site
- Phones get lost, shared and swapped on site.
- Today, a stolen phone keeps the account open (sign-in is by email code, and the session refreshes itself). Nobody can close it remotely.

## What the person sees
- **Where:** Settings → Account → **Signed-in devices** «الأجهزة المسجّل دخولها» (N).
  - The number of one's own devices is private, not a quality signal, so rule 3 is fine.
- **One row per device**, as a pass card:
  - name (phone model, e.g. "Xiaomi Redmi Note 12"; the person can rename it), Android, iPhone or Web;
  - the app version;
  - last active ("Active now", "2 days ago");
  - a **This device** «هذا الجهاز» tag;
  - a **Main device** «الجهاز الرئيسي» stamp.
- **On the main device:**
  - each other row offers **Remove** «إزالة»;
  - the bottom offers **Sign out all other devices** «سجّل خروج كل الأجهزة الأخرى»;
  - **Make main** moves the stamp to another device.
- **On any other device:**
  - the list is read-only, plus **Sign out of this device**;
  - **Make this the main device**, which needs a fresh 6-digit email code. This also covers a lost main phone.
  - Both devices get a notice: "Islam's phone is now the main device".
- **"Other links"** = any other signed-in place: a second phone, a tablet, the web build. All show in the same list.

## How it works (technical, the lead's call)
- **Table `user_devices`:** id, profile_id, auth `session_id` (from the JWT claim), name, platform, app_version, is_main, created_at, last_seen_at.
  - One main per person: a partial unique index.
  - RLS: read own rows only; no direct writes. Everything goes through security-definer functions with `search_path=''`.
- **`register_device()`:**
  - called after sign-in and on app resume (throttled);
  - the first device becomes main;
  - it returns `removed` if this session was closed, and the app then signs out at once.
- **`remove_device(id)` / `remove_other_devices()`:**
  - main only, checked in SQL;
  - deletes that row in `auth.sessions` (its refresh tokens go with it);
  - deletes that device's push tokens (`push_tokens` gets a `device_id`);
  - sends a realtime broadcast to the removed device.
- **`make_main(id)`:** from the main device only. **`claim_main()`:** needs a fresh email-code sign-in (session age under 5 minutes, checked in SQL).
- **The removed device:**
  - it signs out within seconds if online (broadcast or resume), and at the latest when its access token expires (1 hour);
  - on sign-out the app wipes local data: drafts, the outbox, the file cache, notification tokens;
  - an offline phone can't be reached until it goes online. Its screen lock is the only guard until then. The help line says so.
- **Tests:**
  - pgTAP: a non-owner can't see or remove; a non-main device can't remove; claim needs a fresh code.
  - widget tests in EN/AR.

## Decisions for the founder (recommendation first)
1. **Which device is main at the start?** Recommended: **the first device that signs in**. Changed by "Make main", or by a fresh email code.
2. **Lost main phone?** Recommended: **any device can take over with a fresh email code**. Whoever has the email already has the account (sign-in is by email code), so this adds no new weakness.
3. **When?** Recommended: **before the pilot, after Space, Profile and Notebook are signed off.** It's about one table, five functions and one screen.
