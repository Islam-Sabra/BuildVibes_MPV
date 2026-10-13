# Market pack review: Kuwait (and Egypt, for later)

**For:** Islam, to confirm or correct Kuwait's pack before the pilot (1 Jan 2027).
**How:** write "OK" or the right value in the last column. Anything you change, I'll put into the pack.
Egypt is "coming soon" and isn't in the pilot. Its rows are listed so a local can check them later.

## 1. Kuwait: what the pack says

| Field | Value now | Flagged for review | OK / change |
|---|---|---|---|
| Status | Live | | |
| Default language | Arabic | | |
| Dial code | +965 | | |
| Phone rules | 8 digits; mobiles start with 5, 6 or 9; example "5000 0000" | **Yes** | |
| Sign-in code channel (after the pilot; email codes now) | WhatsApp | **Yes** | |
| Currency | KWD, 3 decimals (not shown anywhere in the MVP) | | |
| Week starts on | Sunday | | |
| Weekend | Friday and Saturday | | |
| Time zone | Asia/Kuwait (new) | | |
| Support email | Set on live by SQL (not written in the code) | | |
| Moderation address | Set on live by SQL (private) | | |
| Terms, Privacy and account-deletion pages | Empty until the pages are hosted | **Yes** | |

## 2. Kuwait: places (19, all flagged)

People pick these on "About you" and on projects. Two levels: governorate, then area.

| Place | Arabic | OK / change |
|---|---|---|
| Capital | العاصمة | |
| Kuwait City | مدينة الكويت | |
| Shuwaikh | الشويخ | |
| Hawalli | حولي | |
| Salmiya | السالمية | |
| Jabriya | الجابرية | |
| Rumaithiya | الرميثية | |
| Salwa | سلوى | |
| Mishref | مشرف | |
| Farwaniya (governorate) | الفروانية | |
| Farwaniya (area) | الفروانية | |
| Ahmadi | الأحمدي | |
| Fahaheel | الفحيحيل | |
| Mangaf | المنقف | |
| Mahboula | المهبولة | |
| Jahra (governorate) | الجهراء | |
| Jahra (area) | الجهراء | |
| Mubarak Al-Kabeer | مبارك الكبير | |
| Sabah Al-Salem | صباح السالم | |

Missing an area your pilot team works in? Add it here.

## 3. Kuwait: popular trades (the chips on "Your role")

In this order. One local name is flagged.

| # | Trade | Arabic | Local name | OK / change |
|---|---|---|---|---|
| 1 | BIM specialist | أخصائي BIM | | |
| 2 | Site engineer | مهندس موقع | | |
| 3 | Electrician | كهربائي | | |
| 4 | Steel fixer | حدّاد تسليح | | |
| 5 | Foreman | رئيس عمال | **"فورمن" (flagged)** | |
| 6 | Site manager | مدير موقع | | |
| 7 | Plumber | سبّاك | | |

## 4. Egypt (after the pilot; a local reviewer confirms)

- **Flagged:** phone rules (10 digits; mobiles start with 10, 11, 12 or 15), code channel (WhatsApp), week start (Saturday), legal pages, and status (coming soon).
- **Time zone:** Africa/Cairo, including summer time.
- **Places:** 9, all flagged.
- **Popular trades:** the same 7 as Kuwait, all flagged. The local names "حدّاد مسلّح" (steel fixer) and "سبّاك" (plumber) are drafts.

## 5. The code audit (review 23 §5)

I searched the Dart code, the ARB strings and the SQL for a country, city, currency, dial code, weekday rule, legal link or support contact typed in.

- **Dart and strings:** nothing country-specific is typed in. Every value comes from the pack. Mentions of Kuwait are only in code comments and in one sample on the debug-only Components screen.
- **SQL:** the pack's own data (migration 1 and the trade list) is where these values belong.
- **One real gap, now fixed in migration 17 (`20261013150000_market_pack.sql`, not live):** a post gets one "found this useful" notification a day, and that day started at UTC midnight, which is 3 a.m. in Kuwait. The pack now has a time zone, and that day follows the author's own time zone. Days on the phone ("today" on Home) already use the phone's own midnight.
- **Pack fields the brief asked for:** support email, Terms and Privacy links, moderation address and time zone. All are now in the pack; the moderation address is kept private.
