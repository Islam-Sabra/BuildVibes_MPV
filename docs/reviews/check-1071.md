# Emulator checks of build 1071 (4 Nov 2026)

For the lead. Build 1071 (`release-1071`, versionCode 1071) on the live server. The founder's phone was not touched; it reconnected over wireless debugging by itself at the start and was disconnected at once, and adb was restarted with mDNS auto-connect off.

- **Pixel_8** (emulator-5554): 1071 installed over 1050, Test Lead still signed in.
- **Pixel_8_B** (emulator-5556): 1071 installed fresh (the old debug build removed), signed in as the founder's test account (Islam Ahmed) with an email code.
- Shared Space: **Test site**. Shots: [`shots-1071/`](shots-1071/), EN and AR for every step.

## Results

| Step | EN | AR | Shots |
|---|---|---|---|
| Scan: Library → Add a file → Scan a document, 3 pages from the virtual scene → Add | Pass | Pass | 01–05 |
| Scan: the Library row with the page 1 thumbnail | Pass | Pass | 06 |
| Scan: the file page (page 1, no ".pdf" in the title) | Pass | Pass | 07 |
| Make it smaller: a 3.0 MB PDF → the offer → before → after (3.0 MB → 17 KB) → Use smaller → added | Pass | Pass | 10, 12, 13 |
| Make it smaller: progress "page 29 of 40" / «صفحة 31 من 40» | Pass | Pass | 15 |
| Too large: 81 MB → Make it smaller → "Still too large (36 MB). The most is 25 MB." with Link folder only | Pass | Pass | 14, 16 |
| Poll live: Pixel_8_B creates; Pixel_8 picks → Vote / «اعتمد اختياري»; Pixel_8_B's card changes without going back | Pass: **3.0 s** | Pass: **3.1 s** | 20–24 |
| Change vote / «غيّر اختياري» | Pass: 3.1 s | Pass: 3.3 s | 25, 26 |
| Take back my vote / «ألغِ اختياري» | Pass: 2.2 s | Pass: 3.0 s | 27, 28 |
| Close (hold → Close poll → confirm); one top answer → DECIDED / «تقرّر» at once | — | Pass | 29–31 |
| Tie → TIED / «تعادل», "Tap the winning answer" → pick → DECIDED on both phones | Pass | Pass | 32, 33 |
| Library offline: network off → add a file → "Waiting for signal" / «بانتظار الإشارة» with Remove | Pass | Pass | 41 |
| Network on → "Uploading 100%" → finishes by itself (4–8 s) | Pass | Pass (7 s) | 42, 43 |
| "Who sees it: Whole Space · Change" | Pass | Pass | 05, 40 |
| Hold a card → the bar | Pass (see 3 below) | Pass (see 3 below) | 29, 50, 51 |
| Swipe Spaces ↔ Explore ↔ Activity ↔ Profile, both ways | Pass | Pass | 54, 55 |
| Swipe Work ↔ Chat, both ways | Pass | Pass | 52, 53 |

The seconds are from Pixel_8's tap to the first change of Pixel_8_B's card on its screen, sampled about every 0.5 s (so each is an upper bound).

## What didn't work, or needs your call

1. **English text in an Arabic poll reads wrongly** (bidi). A question "Pour time on level 4?" shows as «?Pour time on level 4», and the options "7 am" / "9 am" as «am 7» / «am 9», on both phones in Arabic (24, 31, 32). The poll's question and options aren't shown in their own direction. Also «لم يختر بعد: smsmو Islam»: the names and «و» run together in the wrong order.
2. **D23 missed two places:** the Make it smaller offer says "Test-3MB.pdf · 3.0 MB" (10), and the upload row while it waits says "Test-3MB.pdf · Waiting for signal" (41). Both show ".pdf".
3. **The hold bar.**
   - On someone else's note: Pin · Reminder only (50).
   - On my own poll that others voted on, open or closed: Pin · Reminder · (Close poll) · **Delete**, never Archive (29, 51).
   - Review 113's rule was "Delete while nobody acted, else Archive". Either a vote doesn't count as acting, or this is a fault. Your call.
4. **Two checks after a decision:** on Pixel_8, the voter's own answer (Sunday) and the decided one (Monday) both show a check (33 `_pixel8`), so the voter can't tell which is theirs.
5. **Not fully seen:** the upload's percent before 100% (a 3 MB file finishes too fast), and the progress on the 3 MB file (also too fast; the 40-page file shows it).
6. **Extract text on live** answers "Couldn't read this file" (08), as expected without the key. D25 (hidden until the Google trial) is on `claude/r103-d25`, waiting for your check.
7. Older "Test-3MB" files in the Library show white thumbnails: their pages are blank, so that's correct.

## Log

From `adb logcat` on both emulators: no Flutter errors and no crashes. The only error lines are on Pixel_8_B during the offline step, as expected:

```
17:51:11 BV-LIVE daybook:6f20f3ec… channelError error=RealtimeCloseEvent(code: 1002, reason: )
17:53:39 daybook refresh: SpaceException(SpaceFailure.network, … Failed host lookup: 'vnlkthmdoczlyhxpdkux.supabase.co' …)
17:53:43 BV-LIVE daybook:6f20f3ec… channelError error=WebSocketChannelException: … Failed host lookup …
```

Live came back by itself when the network returned (the polls and the upload went on without a restart).

## Set-up notes

- Google's scanner on Pixel_8_B needs a front camera; it was turned on in that emulator's settings (before 1071).
- For a real page, the emulator SDK's virtual-scene poster (`resources/poster.png`, `Toren1BD.posters`) showed a printed delivery note during the scans and was put back right after (same hash as before).
- The test PDFs: `Test-3MB.pdf`, and 24- and 40-page PDFs of photo-like pages (49 and 81 MB). The 24-page one came to 21 MB after compression, which fits (15 `fits`), so the 40-page one shows "still too large".
- Live data made in Test site: three scans, two Test-3MB files, polls TS-008 to TS-010.
