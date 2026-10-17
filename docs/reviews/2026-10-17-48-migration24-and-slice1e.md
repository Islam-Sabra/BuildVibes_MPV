# Review 48: migration 24 approved; slice 1e — 17 Oct 2026

## Migration 24 (`sent-back-db`, 6ded778)
On my side, on Postgres 16 with the Supabase stand-in, all migrations apply from scratch and **all 1,648 SQL checks pass** (24 files).

**What held up:**
- `sent_back` entries share the daybook's index and cursor. Each carries the reason, note and time, with the item as the quote.
- **The owner's clip and "Sign as done"** sit on the latest send-back only while the item is open, nothing came after it, and the caller is the owner. Otherwise they stay on the work item slip; for example, once the item has been given to someone else, the slip holds them. They are never shown in both places.
- The month dots include send-backs. Grants are kept (`create or replace`).

**Verdict: approved to go live.** With the founder's yes:
1. Merge `sent-back-db` into `main`.
2. `supabase db push` must list only `20261017180000_sent_back.sql`.
3. Read-only check (names and counts only): the index `work_item_events_daybook_idx` exists.
4. Update `progress.md`, then put the **1e build** on the founder's phone the same day. The 1d build there doesn't know `sent_back` entries; 1e skips kinds it doesn't draw.

## Slice 1e (37b68ec)
I compared MN1, SI1, NY1, H1, R1, PR1, S1 and O4 (EN and AR) with the frames.

**What held up:**
- **Space header** with the floor-plan emblem; the ⋯ menu shows only Space info.
- **Space info:**
  - pass, notifications and who can invite are each one choice (rule 6);
  - the invite code with Copy, and New code;
  - the project chip;
  - "On site since", read-only for non-admins.
- **Needs you:** grouped by Space, with clips and no counts.
- **S1** now matches the frame: the 10:12 send-back slip with the clip and "Sign as done"; the proof keeps SENT BACK and "Sent back at 10:12".
- **O4:** the item switcher on the proof screen.
- **Profile:** "Proof of work" first, with CHECKED stamps. Projects show CONFIRMED or WAITING stamps and no counts. Follower counts are allowed (founder decision, 11 Oct).

**The six points:**
| # | Point | Answer |
|---|---|---|
| 1 | Write a post in place (H2) as its own part, 1f, replacing today's composer | **Yes.** One composer, never two. 1f is the last part of slice 1; the founder tries slice 1 after it. |
| 2 | "from your network" instead of "from people you follow" | **Neither claim:** the feed also shows posts from projects and Spaces, not only people. **Show the date alone:** "15 October". |
| 3 | Name and About, Transfer ownership, Delete Space in Space info | **Keep them.** The last admin can't leave without Transfer. Delete stays red and last. |
| 4 | Notebook and Messages icons open a placeholder | **Hide both** until slices 3 and 8. The search icon stays. |
| 5 | "Only me" under who can invite | **"Admins"** (Arabic **"المدراء"**), because a Space can have several admins. |
| 6 | "On site since", Arabic "في الموقع منذ" | **Accepted as built.** The lead adds the row and the "Admins" wording to SI1 in Figma, so the frame matches the build. |

**Demo text:** keep one spelling and one title across screens.
- R1 (Arabic) has "جلب الأنابيب عند المحور C7 قبل الصب", but the daybook has "تركيب الجلب عند المحور C7 قبل الصبّ". Use the daybook title on the profile too.
- Rakesh is "راكيش" everywhere, including Home's "found this useful" line, which has "راكش".

## Order
1. With the founder's yes: migration 24 goes live, then the 1e build goes on his phone.
2. Points 2, 4 and 5 and the demo text, on `slice1-daybook`.
3. Part 1f, write a post in place (H2 `2555:35388`): it replaces the composer, with drafts and no signal as in 1c. Push, report and send screenshots.
4. Then the founder tries all of slice 1, on his phone and the emulator, from the scenario list.
