# Decision 04: sign-in by email code only for the MVP (founder, 11 Oct 2026)

**Founder decision:** the MVP signs in with a **6-digit email code only**. There is no phone, WhatsApp or SMS sign-in in the MVP; it comes back later. Google and Apple stay hidden (built, behind the flag).

Email is sent through **Resend**, from the founder's domain **aecox.com**. The proposed sender is `BuildVibes <no-reply@mail.aecox.com>`. Setup is in progress with the founder.

## Changes in the app
1. **E2 Join or sign in:** the main button becomes **"Continue with email"** (Arabic: **"المتابعة بالبريد الإلكتروني"**). Remove "Use email instead". Keep the line "No password. We never post for you or read your contacts."
2. **Phone screens (E2p, E3 for phone):** keep the code, but hide them behind a feature flag (`phoneSignIn = false`). Delete nothing.
3. **E9 About you:**
   - Country is pre-filled from the device region, not from a dial code. The helper text becomes "You can change it in Settings."
   - Remove the recovery-email field, since email is now the sign-in.
   - Add an **optional mobile number** field. It's private, for future phone sign-in and account recovery. It's never shown on the profile.
4. **Who can sign up:** sign-up by email is open to anyone.
   - The **home market** must be a live market (Kuwait). Egypt shows "coming soon".
   - The exception: a person who arrives with a **Space invite** can complete sign-up whatever country they choose.
   - The server enforces the same rule.
5. **Email template** (Supabase Auth, "Magic link / OTP"):
   - The code (`{{ .Token }}`) is shown large, with a short line in English and Arabic.
   - There's no link to click.
   - Code length is 6, and it expires after 10 minutes.
   - **Ask the founder before changing live settings.** Write the intended values in `supabase/config.toml`.

## Docs
- Update `CLAUDE.md`, `docs/product/mvp-plan.md`, `docs/product/rules.md` and `docs/design/entry/README.md`: sign-in is email code only in the MVP.
- Phone sign-in moves to "after the pilot".

## Known risk (accepted by the founder)
Some foremen and labour may not use email. Mitigations:
- most Android phones already have a Gmail account, so Google sign-in can be switched on later;
- the Space admin can help people join on site;
- phone sign-in returns after the pilot if this proves to be a barrier.

## Status update (11 Oct, 17:00)
- Resend domain **mail.aecox.com is verified**: DKIM, SPF and return-path records were added in Cloudflare. DMARC was deliberately not added, because the root domain also carries the founder's Zoho mail.
- The founder has **saved Custom SMTP in Supabase**: host `smtp.resend.com`, port 465, user `resend`, sender `BuildVibes <no-reply@mail.aecox.com>`, password = a Resend sending-only key.
  - **Don't change these.** The key is never stored in the repo.
- **Still to do when you apply this decision** (ask the founder before each live change):
  - the OTP email template;
  - OTP length (6) and expiry (10 minutes);
  - the email rate limit;
  - then a real test: send a code to the founder's own address and confirm with him that it arrived (inbox, not spam).
