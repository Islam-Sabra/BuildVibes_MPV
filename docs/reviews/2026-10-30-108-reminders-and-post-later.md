# Review 108: reminders for someone else, and Post later — 30 Oct 2026

**Founder, 20:06–20:21:** from a friend's test. Both are **before the pilot**. **Status: frames drawn, waiting for the founder's ok.**

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
