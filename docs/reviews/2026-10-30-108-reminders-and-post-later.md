# Review 108: reminders for someone else, and Post later — 30 Oct 2026

**Founder, 20:06–20:21:** from a friend's test. Both are **before the pilot**. **Status: frames approved (founder, 30 Oct 20:25). Build before the pilot, after review 107 is live.**

## 1. Reminder: For Me · Someone (RM1, RM2)
- **Frames:** RM1 EN `2701:39107`, AR `2701:39374`; RM2 EN `2701:39185`, AR `2701:39452`.

**The Reminder sheet** is the same one the swipe opens. At its top is one single choice (rule 6): **Me · Someone**.
- **Me** works as now: a notification on my own phone.
- **Someone** is offered only to the item's **creator, its owner or a Lead**. Everyone else sees only Me.
  - **Who:** one or more people, from the Give to picker. Only members who can see the item; the owner is pre-selected.
  - **When:** one choice of **Tomorrow 7:00 · 1 h before due · Pick…** (the time picker). "1 h before due" shows only when the item has a time. The times are in the Space's time zone.
  - **Note:** optional, up to 140 characters.
  - **Set reminder.**

**The server sends it** at that time as a push notification: "Reminder from {name}: {item title} · due {time}", plus the note. Tapping it opens the item.
- It is sent once per person per reminder.
- **It is not sent** if the item is already Done, Checked or cancelled by then, or if the person has left the Space.

**On the opened item, a "Reminders" line** lists who and when. The person who set a reminder, the creator or a Lead can remove one.
- At most 5 Someone reminders wait on an item at a time.
- Personal "Me" reminders aren't listed for others.

**Server (one migration):**
- table `work_item_reminders`: post, set by, remind at, note, recipients;
- RLS: readable by the setter, the recipients, the creator, the owner and Leads of that Space;
- written only through security definer functions `set_work_reminder` and `remove_work_reminder`, which check the role and that the recipients are members who can see the item;
- the cron function `due_work_reminders()` runs every 5 minutes, sends through the existing push path and marks each as sent.
- pgTAP covers it, including non-members, Viewers and Crew who aren't the creator or the owner.

## 2. Post later (PL1, PL2)
- **Frames:** PL1 EN `2701:39253`, AR `2701:39520`; PL2 EN `2701:39329`, AR `2701:39596`.

**Where it applies:** the writing bar of the **Feed, a Space and a notebook share** gets a **clock** beside Send.
- Tapping the clock opens **Post later**: one choice of **Tomorrow 7:00 · {next working day} 7:00 · Pick…**. The working days come from the market pack, never typed in code.
- The line "It goes out at that time, even if your phone is off." Then **Schedule**.

**Scheduled** (PL2) lists my waiting posts, each with **Post now · Edit · Cancel**.
- It opens from Profile → Scheduled, and from a small "{n} scheduled" line in the Space when I have one waiting there.

**At the time, the server publishes it** exactly as if it were sent then:
- its time is the publishing time;
- the Space's rules are checked **again** at that moment (still a member, still allowed to post this kind). If not, it isn't published and I get a notification "Couldn't post: …".

**What can be scheduled:** posts, announcements, checklists and work items (a scheduled work item is created and given at that time), Feed posts, and notebook shares.

**Server (in the same migration):**
- table `scheduled_posts`: the full payload of the existing create call, its target, the time and its state;
- owner-only RLS; written only through `schedule_post`, `update_scheduled_post`, `cancel_scheduled_post` and `post_scheduled_now`;
- the cron function `publish_due_posts()` runs every 5 minutes and calls the same create functions as the author, so every permission is checked again.
- pgTAP covers it.

**Not in this review:** repeating posts and repeating work items (still out of the MVP).

## The lead's check of `claude/r108` at `a97e8c4` (31 Oct)
- **Checked:** the SQL stand-in passes 3,370 checks in 55 files; all RM1, RM2, PL1, PL2, PL2b and OB1 shots match the frames in EN and AR; two code reviews (spec, and standards with security).
- **Security passed:** RLS on both tables, no client writes, security definer with `search_path=''`, the cron functions revoked from clients, the create call replayed as the author, injection-safe `scheduled_call_sql`.
- **Accepted as built:**
  - `/scheduled-posts`;
  - Edit changes only the time;
  - the reminder push hides the title and note unless lock-screen text is on (migration 14's rule);
  - the Profile clock shows only while something waits;
  - the grey pill.

**Fix before merging (V1–V10), test first:**
- **V1. Post later race.** Lock the row in `my_waiting_scheduled` (`for update`). Every state update also requires `state = 'waiting'`. A test covers Post now or Cancel against a row the cron already posted: no double post, no false "Couldn't post".
- **V2. A failed post can be cleared.** On a failed card, **Post now** retries and **Cancel** removes it. A failed row no longer keeps the Profile clock showing once cancelled.
- **V3. One clock and one calendar per place.**
  - Reminders' **Pick…** uses the Space's time zone, like Tomorrow 7:00.
  - **Post later in a Space** uses the Space's time zone and the Space's market weekend. In the Feed and a notebook share, it uses the phone's zone and the person's own market.
  - Morning 7:00 is one shared spec constant, not typed in two files.
- **V4. Reminder limits.**
  - Lock the post row before counting the 5 waiting reminders.
  - Add a per-setter cap of **20 Someone reminders a day** ("You've set the most reminders for today").
- **V5. Setter must still be there.** `due_work_reminders` also skips a reminder whose setter has left the Space, or is no longer the creator, the owner or a Lead.
- **V6. Push text.** `clockIn` falls back to UTC on a bad time zone instead of dropping the push. The reminder sheet shows the full name, not a first-name split (it breaks names like «عبد الله»).
- **V7. The clock on a work item with Library files or a Space place stays off**, accepted for the MVP. Tapping it shows one line instead of doing nothing: "Items with files or a place can't be scheduled yet." («لا يمكن جدولة بند فيه ملفات أو مكان حاليًا.»)
- **V8. The note mark.** The publishing step marks the note "Went into a Space" when a scheduled post came from My notebook through the writing card.
- **V9. Small server tidy-ups:**
  - revoke `can_read_work_reminder` from `authenticated`;
  - make `scheduled_call_sql` match one exact function signature per name;
  - make `schedule_post` answer `not allowed` on an id another author owns.
- **V10. pgTAP adds:**
  - a cancelled item;
  - a soft-deleted Space;
  - an author who lost the pass without leaving;
  - the per-setter cap;
  - the setter who left;
  - a failed post that is retried and then cancelled.

Then fresh shots of anything that changed into `docs/reviews/shots-108b/`. Stop again before merging.

### V1–V10 done (`claude/r108` at `4a262c9`): accepted (31 Oct)
- **SQL stand-in:** 3,400 checks pass.
- **Spot-checked in the migration:**
  - the scheduled row and the post are locked (`for update`);
  - every state change requires `state = 'waiting'`;
  - the 20-a-day cap counts the last 24 hours;
  - `due_work_reminders` requires the setter to still be in the Space as a Lead, the creator or the owner.
- **The 8 new shots match:** PL2c failed card (Post now · Cancel), RM1b full names, RM1c daily limit line, PL1b the "can't be scheduled yet" line.
- **Accepted:** the 24-hour window; no second "Couldn't post" push on a failed retry; the pinned signatures, with the note kept in the handoff.
- **Next, with the founder's yes:**
  - goldens from shots-108, shots-108b and shots-107b;
  - merge into `slice2-app`;
  - migration `20261117120000` live;
  - the two cron jobs from `supabase/ops/`;
  - deploy `push`;
  - a build.
