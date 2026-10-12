# Review 20: migration 13 recheck and week 7 part 2 (Home Spaces tab, Activity) — 12 Oct 2026

## A. Migration 13 (`activity-db`, dc94167): passed, with one small fix
All 577 SQL checks pass on my side. The independent review re-ran every probe, and all six review 19 fixes hold:
- Useful keeps no marker;
- repeat requests merge into one row;
- a repeat follow within 7 days makes no new row;
- blocked post rows are hidden;
- former admins see no requests;
- `today_in_spaces` takes 6 ms.

The per-thread rewrite still hides:
- Team threads from people outside the Team;
- deleted messages, blocked authors and your own messages;
- Spaces you left.

The `home_day` counts mean the same as before.

**Fix in place (still not live):**
1. **A real new request merges silently into a row the admin already read.** E asks to join, the admin confirms, E leaves and asks again the same day. The admin's row is reused, but it stays read, keeps its old time, and the Activity dot stays off.
   - Merge only when the earlier request was **cancelled**.
   - When merging, set `read_at = null` so the dot comes back.
   - Test: confirm, leave, request again gives the admin a new unread row.

**With the founder's yes**, after fix 1:
1. Push migration 13. The push must list only `20261012180000_activity.sql`.
2. Merge `activity-db` and `activity`.

**Later, not now:** `today_in_spaces` reads every work item event on the platform from the last 2 days. That's 53 ms at 200,000 events, which is fine for the pilot. If it grows, add `space_id` to `work_item_events` with an index on `(space_id, created_at)`.

## B. Part 1 retakes: passed
- C13 shows "Keep editing" / "متابعة التعديل".
- P3b shows "Retry" / "إعادة المحاولة".
- The composer's L6 has "Detected automatically" with the detected language and the line under the title, in English and Arabic.

## C. Part 2 screens: passed, with 2 fixes
These match their frames in English and Arabic:
- **H1b:** the date line, "Your day on site", the summary line, Needs you cards with Open, Today in your Spaces, "That's your day", and the search-only top bar.
- **A1:** Needs you, then the groups with REV stamps, letter markers and chips.
- **A2:** the MVP ledger.
- **Elsewhere:** the Spaces icon on Profile (R1), My Spaces with Create (New Space, Enter an invite code), and the dots.

**Fixes:**
1. **Arabic lines that mix in English names, titles or refs come out scrambled.** Examples:
   - A1 Needs you: "Sami Al-Mansour: Confirm … من بند عمل لك";
   - the H1b "Today" row: "Omar Haddad: Gate 3 من KCT-005 بند جديد".
   - Wrap every inserted value (`{name}`, `{title}`, `{ref}`, `{space}`) in Unicode isolates, U+2068 … U+2069, in one shared helper, so each one keeps its own direction inside the sentence.
   - Apply the same helper to the chat cards and the work item lines that already insert names.
   - Add a widget test that renders one mixed line in Arabic.
2. **H1b "Today" times** use the frame's form: "3h ago" / "قبل 3 ساعات", "Yesterday" / "أمس". Cards and replies keep the short form from review 18.

**Your Arabic strings:** accepted. Names and verbs in the noun or passive form work for both genders. The founder may still change any wording.
