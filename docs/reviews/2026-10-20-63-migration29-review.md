# Review 63: migration 29 (slice 2 live) approved, with two changes — 20 Oct 2026

Branch `slice2-live-db` (355233f). One migration file, `20261020120000_slice2_live.sql`, and its tests, `29_slice2_live.test.sql`.

## What I checked
- **On the stand-in**, every migration applies from scratch and **all 2,158 SQL checks pass** (29 files, 108 for migration 29). The stand-in is now in `supabase/dev/standin/`, so a cloud session can run it again.
- **What changed:** I compared each rewritten function with its version after migration 28. The only changes are the ones the header describes:
  - `create_space_post`: `note` added to the kinds;
  - `edit_space_post`: the unpin path for an admin acting for a gone author;
  - `ack`: an acknowledgement given again after an edit takes the new time;
  - `space_post_json`: `my_ack_at`.
- **The Note:** the existing "what each kind takes" rules already refuse people, points, a pin, times, a place, a due date and a Library file on a note. Several things leave a note out, and should:
  - `ack`, `save_template`, `card_needs_me` and `daybook_month`;
  - the cancel loop, which only tells a checklist's or an activity's people.
  
  Every function that names `announcement` or `checklist` and not `note` was checked; none is missing it.
- **N2, unpin:**
  - only exactly `{"pinned_until": null}` passes, on an announcement, through `acts_for_author`. That rule already refuses a hidden account and anyone who isn't a member;
  - the author's own path is unchanged;
  - `post_is_editable` has no age limit on announcements, so an old pin can always be taken down.
- **N1, live channels:**
  - the policies are `to authenticated` only, and the row's topic must equal `realtime.topic()`;
  - anything that isn't `daybook:<uuid>` is false, never a cast error;
  - the read rule is `is_member`, the same as `daybook_cards`.
- **One topic per Space, not one per Team** (review 62 asked for a Team topic): accepted. The message is only a post id, and a member outside a Team gets nothing from the re-read. A second channel would add work and protect nothing.

## R1. Chat must go private too, before public channels are turned off (must change)
The plan is: ship the app with `private: true`, then turn off public channels on the live project. But the chat's live updates use another channel, `thread:<thread id>` (`chat_repository.dart`, Postgres changes on `messages`). With public channels off, a private channel can only be joined through a policy on `realtime.messages`. The policies only allow `daybook:` topics, so **chat would stop updating live** on the day the setting changes.

**Change (in migration 29, since it isn't live):**
- Allow the thread topic too: `thread:<uuid>` when `can_use_thread(id)` (a Team thread stays in its Team). One function can answer for both prefixes. Keep the `extension` and `topic = realtime.topic()` rules.
- The app joins `thread:` with `private: true` in the same build as `daybook:`.
- **Tests:** SQL checks as for the daybook topic (a member of the thread yes; someone outside the Team, someone who left, a non-member and anon no). Then the same end-to-end check against the local Realtime server: with public access off, a chat message still arrives live.
- The Direct messages table is in the publication, but the app has no live channel for it today. When it gets one, it needs its own topic rule.

## R2. Received keeps its first time (must change)
`ack` now moves `created_at` for **every** kind when the post was edited after it. Review 61 G1 asked for this only for Got it, so an edited announcement opens again. For a **Document for receipt**, the time of Received is the record of when the document was received. Tapping Received again after the author fixed the title would quietly overwrite that time. The `post_acks_activity` trigger only fires on insert, so nobody would be told either.

**Change:** only Got it is re-timed:
`on conflict (post_id, profile_id, kind) do update set created_at = now() where a.kind = 'got_it' and a.created_at < v_post.edited_at`.

On My way and In my calendar don't need it: they belong to the activity's time, not its words.

**Test:** give Received, edit the document's title, give Received again. Its time hasn't moved, and nothing new appears in the history.

## R3. Any member can ring every open daybook (low, app side)
The send policy lets any member, a Viewer included, broadcast any post id on the Space's topic. Each one makes every open daybook in the Space read the page again. Nothing leaks, because the re-read uses the server's rules. But a stuck loop or a spammer would hammer `daybook_cards`.

**App:** gather the signals for a Space and read the page at most once a second. No server change.

## R4. Someone removed keeps the signal until their sign-in refreshes (low, accepted)
Realtime checks the policy when someone joins, and again when their sign-in token refreshes (about an hour). So someone removed from the Space may still get post ids for up to an hour, but no content. Accepted for the pilot.

## The open question: how a Note goes into the daily report (decided)
- `daily_report_fill` gains a `notes` list. Each entry is one of that day's live notes that **everyone who reads the report may see**: the title, the author, the time and the first photo. As with work, an Everyone report never brings in a Team's notes.
- The app offers them under **On site** / the matching Arabic heading. The writer can remove any of them before posting.
- This goes in **migration 30**, with the app work for the report. It doesn't hold up migration 29.

## Verdict
**Approved once R1 and R2 are in** and all SQL checks pass. The order:
1. With the founder's yes, the push lists only `20261020120000_slice2_live.sql`. Nothing changes for build 349: the public topics stay open.
2. The app build joins `daybook:` and `thread:` with `private: true`, and gathers re-reads (R3).
3. Once that build is on every test phone, public channels are turned off on the live project. This is a live setting and needs its own yes from the founder.
