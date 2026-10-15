# Review 33: database changes for the new scope, and the 10 build slices — 15 Oct 2026

The design is finished (review 32 scope). This review gives you:
- **Part A:** the database changes, in five migrations (18–22), each on its own branch, for 1–14 Nov.
- **Part B:** the 10 build slices, 15 Nov – 17 Jan, each tested by the founder on the emulator before the next starts.

Design sources: `docs/product/daybook.md` (rules), `docs/product/space-scenarios.md` (every Figma frame), Figma file `IcoK4u8JFO6K8l4YYiHNkm`. Arabic frames are on the AR page.

**Effort:** run Part A with `/effort ultracode` (the security and permission work benefits from parallel checking). Run Part B at `/effort high`.

**Constraints still in force:** nothing goes live without the founder's yes; a migration push must list only the expected file, otherwise stop and send a screenshot; no schema change on live outside reviewed migrations; never print secrets; don't touch the emulators' installed app or the live database while the founder tests 0.9.0 (1).

---

# Part A — database (migrations 18–22)

## A0. Rule changes from the Daybook (read first)
These change rules that are live today (migrations 6–11). They are founder-approved (Daybook, 14–15 Oct).

| Rule | Today | New |
|---|---|---|
| Who can post work (any kind) | Lead only (`create_items`) | **Lead and Crew.** Crew preset gets `create_items: true`. An admin can still switch it off for one person (custom). Viewer never. |
| Who checks or sends back | the creator, or anyone with `check_items` (Leads, admins), never the owner | **The author only.** If the author is no longer an active member, any Space admin acts for them. Never the owner. `check_items` is retired: ignored by `can()`, removed from `pass_rights` presets and the S17k custom list (old values stay harmless in `custom`). |
| Who reassigns | the creator or `check_items` | **The author**; a Space admin only when the author has left. |
| Comments ("updates") | any active member | **The owner, and any Lead or Crew member.** Viewers read only. |
| Editing a work item | not possible | **The author only**, while Open. Locked after Done; Send back reopens it; locked forever after Checked. Every edit is recorded and shown ("Edited: due moved from Sun to Mon") and notifies the owner. |
| Removing | not possible | **Delete** only while nobody else has added anything (no update, tick, acknowledgement, sign-off, child item). After that, **Cancel**: stays in the daybook with a CANCELLED stamp. Author, or a Space admin when the author has left. |
| Work item cards in chat | posted by trigger | **Stop posting new cards.** Work stays in the daybook. Old card messages stay as they are. |
| Send-back reasons | photo_missing, not_as_drawing, not_finished, other | Rename `not_as_drawing` → `not_as_asked` (neutral app words). Migrate existing rows. |

Update `data-model.md` §5 rights table and §7 in the same commit as migration 18.

## A1. Migration 18 — the daybook core (branch `daybook-db`)
**One daybook table for every kind of post.** Work items keep their table and every function and test you already have; a work item becomes a post of kind `work_item` that shares its id.

**Tables:**
- `space_posts`:
  - `id` (chosen by the app; retries are idempotent), `space_id`, `team_id null` (Team audience), `kind` ('work_item' | 'checklist' | 'announcement' | 'activity' | 'file' | 'report'), `author_id`;
  - `title` (1–200), `body` (text, up to 5000), `place_text`, `due_date null`;
  - `parent_id null` (work items under one work item: the parent is a `work_item` post of the same Space; one level only);
  - `source_message_id null` (made from a Space chat message), `quote jsonb null` (`{author_name, text, at}`: a quoted direct message or note the author chose to bring in; copied text, no link to the private thread);
  - `template_id null`, `status` ('live' | 'cancelled'), `cancelled_by`, `cancelled_at`, `edited_at`, `created_at`, `deleted_at`.
- `work_items.id` references `space_posts.id` (backfill a post for every existing item: kind `work_item`, same id, title, author = `created_by`, place, due, team). `work_items` keeps owner, status, number/ref and the sign-off columns. Add `status 'cancelled'` is **not** needed: cancelling is on the post.
- `post_edits`: `id`, `post_id`, `editor_id`, `changes jsonb` (field → {from, to}; for display only), `created_at`. Append-only (same trigger pattern as `work_item_events`).
- `post_files`: photos and files on a post that are not sign-off proof: `post_id`, `storage_path` in `space-files` at `<space>/posts/<post_id>/<file>`, or `library_file_id`; `sort`, `mime`, `bytes`, `width`, `height`.

**Functions (the only way to write):**
- `create_post(id, space, kind, title, body, team, place, due, parent, source_message, quote, template, files)`: needs `can(space, 'create_items')`. Kind-specific fields come in migration 19; this migration accepts kind `work_item` through `create_work_item(…)` (extend it with `body`, `parent`, `source_message`, `quote`, `files`). A child's owner rules are the same as any work item.
- `edit_post(id, changes)`: author only; work items only while Open; writes `post_edits`; raises an `item_edited` notification to the owner (not when the author is the owner).
- `delete_post(id)`: author only, only while nothing has been added by anyone else; soft delete; files go to the cleanup.
- `cancel_post(id, note)`: author, or an admin when the author has left; a Checked item can't be cancelled; children of a cancelled parent are cancelled with it; `item_cancelled` notification to the owner.
- `reassign_work_item`, `check_item`, `send_back`, `add_comment`: apply the A0 rules.
- `daybook_page(space, before, limit)`: posts newest first with author, kind, the latest stamp (done / checked / sent back / cancelled / new version), owner, due, Team, `needs_me` (the paper clip), edit lines, child progress ("2 of 4 checked"), for active members; Team posts only for that Team and the admins.
- `post_page(id)`: one post in full (for opening in place): fields, files, events, edits, children.
- Drop the chat-card trigger (A0). Keep `messages.kind 'work_item'` for history.
- `needs_you()`: Done items where I am the author (or an admin acting for an author who left); open items I own (including sent back); join requests; owner-left rows. Remove the `check_items` branch.

**Drafts stay on the phone** (the writing card, its photos and the kind chip), keyed by the post id the app already chose. No server table: a draft is private by nature and must survive no signal. The app clears it after the server accepts the post.

**Tests:** non-member reads nothing from `space_posts`, `post_edits`, `post_files`; Crew can post; Viewer can't; only the author edits; edit refused after Done and after Checked, allowed again after Send back; delete refused once someone else added an update; cancel by an admin refused while the author is active; check by a Lead who isn't the author refused; check by an admin allowed when the author left; owner never checks; no chat card on a new event; `post_edits` can't be updated or deleted; backfill gives every existing item a post with the same id.

## A2. Migration 19 — the other kinds of post (branch `post-kinds-db`)
**Columns on `space_posts`:**
- announcement: `pinned_until timestamptz null` (pinned under the masthead until then);
- activity (scheduled): `starts_at`, `ends_at null`, `place_text` (already there);
- file: `library_file_id` (the Library file it shares; a new version uses `library_files.supersedes_id`);
- checklist: `due_date` (already there).

**Tables:**
- `post_people`: `post_id`, `profile_id`, `role` ('for' — a checklist's people, an activity's people). Only active members of the Space; Viewers allowed for activities (they can attend), not for checklists.
- `checklist_points`: `id`, `post_id`, `sort`, `text` (1–300), `ticked_by null`, `ticked_at null`. The author edits points (A0 edit rules); ticking is separate.
- `post_acks`: `post_id`, `profile_id`, `kind` ('got_it' | 'received' | 'on_my_way' | 'in_my_calendar'), `created_at`; primary key (post, profile, kind).

**Functions:**
- `create_post(…)` now takes `pinned_until`, `starts_at`, `ends_at`, `library_file_id`, `people[]`, `points[]` per kind. Rules: an announcement or a file needs `create_items`; a file post also needs `add_files` and a file the caller can read in that Space (and Team); an activity's `starts_at` is in the future.
- `tick_point(point, on)`: the author, the checklist's people, and any Lead or Crew; untick only by whoever ticked or the author. Never a Viewer.
- `ack(post, kind, on)`: `got_it` on announcements, `received` on files, `on_my_way` and `in_my_calendar` on activities; any active member who can read the post.
- `post_acks_for(post)`: **the author only** sees who (faces, names). Everyone sees their own acks. No counts anywhere (product rule 3).
- `due_activity_reminders()` (service role, cron every 5 minutes): for activities starting in 25–35 minutes, one push to its people and to whoever added it to their calendar ("starts in 30 min"); once per person per activity.

**Notifications and push (extend the §10 and §11 tables):**

| Kind | To | Push |
|---|---|---|
| `announcement_new` | the audience (Everyone or the Team) | by the Space level: `all` and `needs_you` |
| `checklist_for_you` | its people | `all` and `needs_you` |
| `activity_invited` | its people | `all` and `needs_you` |
| `activity_starting` | its people and calendar adds | always (once), no Activity row |
| `file_new_version` | everyone who marked the older version Received | `all` only |
| `item_edited`, `item_cancelled` | the owner | `all` and `needs_you` |

Push text from `strings.json`, never naming a project, Space or item (as today).

**Tests:** non-member reads nothing from the three tables; a Viewer can't tick; only the author reads `post_acks_for`; a file post can't point at another Space's file or a Team file outside its Team; the reminder sends once.

## A3. Migration 20 — opening a post in place, templates, reports, search (branch `post-pages-db`)
**Page blocks (the Notion depth):**
- `space_posts.blocks jsonb` with `blocks_version int`. Block types: `text`, `heading`, `toggle` (with children), `table` (rows × cells, text only, at most 20 × 8), `photo` (a `post_files` row), `file` (a Library file), `checklist_ref` (points live in `checklist_points`, so ticks never rewrite the author's page), `child_item` (a child work item id).
- Validate shape in SQL (a `validate_blocks(jsonb)` function): known types only, size at most 200 blocks / 100 KB, references must belong to the same post or Space.
- `save_blocks(post, blocks, base_version)`: author only, same lock rules as edits; refuses if `base_version` is stale (the app reloads and re-applies). Writes one `post_edits` row per save ("Page edited").
- **Turn into** (text ↔ checklist point ↔ work item under this one) is done in the app, then saved with `save_blocks`; turning into a child work item calls `create_work_item` with `parent` first.

**Batch creation (one call, all or nothing, idempotent by the parent id):**
- `create_walk(space, parent_id, title, items[])`: walk mode. Each item: id, one line, owner, one photo (already uploaded). Makes one parent post with a child work item per photo.
- `create_from_message(space, message, parent_id, title, lines[])`: meeting notes. Each line: id, text, owner. The caller must be able to read the message and have `create_items`.

**Templates:**
- `post_templates`: `id`, `space_id null` (null = a built-in template seeded by migration, neutral words, `name jsonb` {en, ar}), `kind`, `name`, `blocks jsonb`, `fields jsonb` (default title, points), `created_by`, `deleted_at`.
- Built-in seed: **Daily report** only (blocks: "Done today", "Tomorrow", "Notes"). Trade names only in templates a Space makes itself.
- `save_template(id, space, from_post, name)` and `delete_template(id)`: Leads and admins of that Space. Everyone in the Space reads its templates and the built-ins.

**Daily report:** a post of kind `report` from the Daily report template. `daily_report_fill(space, day_start)` returns what was Checked that day (title, ref, owner, the Done photo path) for the app to drop into "Done today". **Share as PDF is made on the phone** (no server work).

**Week report (management report):** `week_report(space, week_start)`, read-only, for any active member:
- Needs a decision: late open items, sent-back items, Done items waiting for a check;
- Checked this week: title, Done photo path, checker, day;
- Targets: parent items with child progress;
- Coming up: activities and due dates in the next 7 days.
- No per-person totals, no scores (product rule 3). `week_start` comes from the app using the market pack's `week_start`; no time zone typed in SQL (same as `home_day`).
- **Share in chat:** `share_week_report(id, thread, week_start)` posts a message of kind `report` with `{week_start}`; it opens the report for whoever taps it (still filtered by their rights).

**Search:** `search_space(space, q)`: titles, bodies, checklist points, chat messages and Library file names the caller may read, newest first, 30 results. `pg_trgm` index on `space_posts.title`, `messages.body`, `library_files.name`. Arabic and English as typed (no stemming).

**Tests:** blocks of an unknown type or over the limit refused; a stale `base_version` refused; a non-author can't save blocks; `create_walk` twice with the same id makes one set; `create_from_message` refused for a message the caller can't read; a Crew member can't save a template; search never returns a Team item to a non-Team member.

## A4. Migration 21 — the notebook and My calendar (branch `notebook-db`)
**Tables (owner-only RLS on all of them; nobody else, not even an admin, can read):**
- `notes`: `id` (chosen by the app), `owner_id`, `kind` ('text' | 'checklist' | 'todo' | 'voice'), `body`, `points jsonb` (checklist: [{text, done}] — private, so a plain document is enough), `due_at null` (a to-do's time), `done_at null`, `pinned bool`, `remind_at null`, `put_in_post_id null` (set when "Put in a Space" was posted), `created_at`, `updated_at`, `deleted_at`.
- Bucket `notebook-files` (private): `<me>/<note_id>/<file>`, voice and photos, 25 MB; read and write only your own folder.

**Functions:** `save_note(…)`, `delete_note(id)`, `set_note_done(id, on)`, `pin_note(id, on)`. Rate limit 500 notes a day.
- **Put in a Space** is done in the app: it opens that Space's writing card with the note's text (and points) filled in. When the post is accepted, `mark_note_put(note, post)` sets `put_in_post_id`. The note stays private; the post is a new, separate record.
- **Remind me** uses a local notification on the phone (`remind_at` is stored so it can be re-scheduled after a reinstall). No server push.

**My calendar:** `my_calendar(from_date, to_date)` (at most 62 days):
- work items I own or authored with a due date (not cancelled, not Checked), with the Space name and colour, `needs_me`;
- checklists I am "for" with a due date;
- activities I am in or added to my calendar;
- my notebook to-dos with a `due_at`.
Only Spaces I am still in. The week strip and weekend shading use the market pack (`week_start`, `weekend`).

**Data export and deletion:** add notes to `export_my_data` and to `purge_account` (own rows cascade; the purge deletes `notebook-files/<id>/` through the Storage API like avatars, and waits while any remain).

**Tests:** another user, a Space admin and a signed-out caller read nothing from `notes` or `notebook-files`; `my_calendar` never returns a Space the caller left; the range limit holds.

## A5. Migration 22 — direct messages (branch `dm-db`)
**Founder decision F10 (15 Oct): we manage, we don't block.** Anyone can message anyone, as many messages as they like, with photos and files. A person with no work link to you lands in Message requests. Details in `space-scenarios.md` → "Direct messages and Space info".

**Work link** = the two share an active Space, **or** follow each other (both directions). Otherwise a new thread starts as a request for the receiver.

**Tables:**
- `dm_threads`: `id`, `a_id`, `b_id` (a < b, unique pair), `started_by`, `created_at`, `last_message_at`.
- `dm_members`: `thread_id`, `profile_id`, `state` ('open' | 'request' | 'declined'), `last_read_at`, `declined_at`, `muted bool`. The starter is 'open'; the receiver is 'open' when there is a work link, else 'request'.
- `dm_messages`: `id` (chosen by the app), `thread_id`, `author_id`, `kind` ('text' | 'photo' | 'file' | 'voice'), `body` (up to 3000), `reply_to`, `created_at`, `deleted_at`. Never edited.
- `dm_attachments`: `message_id`, `storage_path` in bucket `dm-files` (private) at `<thread>/<message_id>/<file>`, `mime`, `bytes`, `width`, `height`, `duration_ms`. Photos, PDF, voice; 25 MB.
- `app_settings`: `key text pk`, `value jsonb`; service role writes, nobody reads from the app except through functions. Seed `dm_unanswered_limit = {"limit": 50, "warn_at": 40, "days": 30}`.

**Rules:**
- **Reading and writing:** the two people only. Never across a block (either way) — a block hides the thread from both and refuses new messages. A hidden (deleting) account can't write (add to `refuse_hidden_writer`).
- **Request state:** the receiver sees the thread in Message requests. **Replying** turns it to 'open'. **Declining** sets 'declined': the thread leaves their list quietly; the sender is not told. If the sender writes again later, it shows as a request again, with no push for 30 days after the decline. Block stops it for good.
- **Photos and files from someone in 'request' state** are returned with `tap_to_show = true` (the app shows them blurred until tapped).
- **Spam guard:** `dm_unanswered_count(sender)` = distinct people the sender started a thread with in the last `days` who are still in 'request' or 'declined' and never replied. `start_dm` returns `warning` at `warn_at` and refuses a **new** person at `limit` (`dm_paused`, with the day it frees up). Existing threads are never affected. The limit is changed only by SQL on `app_settings` (founder's yes), no app release.
- **Limits:** 30 messages a minute per sender (like chat); uploads share the person's daily upload cap.
- **Push:** a new request: one push to the receiver, once per sender (none within 30 days of a decline). An open thread: like Space chat, at most one push per thread per person every 5 minutes, text only if the person turned on message text. No Activity rows for DMs.
- **Reports:** `reports.target_kind` gains 'dm_message' (the receiver reports; the reported message hides for the reporter at once). `decide_report` copies the text to `removed_content` like a Space message. Moderation sees only the reported message, never the thread.
- **Account deletion:** while scheduled, the person shows as "Former member" in threads and can't be messaged; `purge_account` deletes their `dm-files` uploads through the Storage API and sets `author_id` null; their sent messages are included in `export_my_data`.

**Functions:** `start_dm(id, to_profile, first_message_id, body, attachments)` (finds or makes the thread; returns `{thread, state, warning}`), `send_dm(id, thread, body, reply_to, attachments)`, `delete_dm(id)` (author only; "Message deleted"), `mark_dm_read(thread)`, `decline_dm(thread)`, `my_dm_threads(cursor)` (open threads newest first, then a `requests` summary: count is **not** returned — the app shows the row, not a number), `my_dm_requests()`, `dm_shared_space(thread)` (the first Space the two share, for "Both in …"; never a count).
- **Put in a Space** from a DM is done in the app: it opens the chosen Space's writing card with `quote` filled in (A1). The DM stays private.

**Tests:** a third person reads nothing from any DM table or `dm-files`; a blocked pair can't send either way; a receiver with no work link gets 'request'; a shared Space gives 'open'; one-way follow gives 'request'; decline hides the thread and sends no push on the next message; the 41st new unanswered person returns a warning and the 51st is refused while an existing thread still works; changing `app_settings` changes the limit without a migration; a 'request' attachment comes back with `tap_to_show`.

## A6. Order, branches and going live
1. Migrations 18 → 22 in order, one branch each, each with its SQL tests in `supabase/tests/` and an update to `data-model.md` (new §14–§17; edits to §5, §7, §10, §11, §12, §13).
2. After each branch: `flutter analyze`, `flutter test`, SQL tests, push the branch, report the hash. I review each (reviews 34+), as before.
3. Live: each migration needs the founder's yes; the push must list only that migration file. The cron job for `due_activity_reminders` and the new storage buckets go live with migration 19 and 21 respectively, each with its own yes.
4. Target: all five reviewed by **14 Nov**.

---

# Part B — the 10 build slices (15 Nov – 17 Jan)

Each slice ends with: analyze and tests clean, English and Arabic at 390×844 against the Figma frames listed, commit, push, `progress.md` updated, and a short note to the founder of what to try on the emulator (the scenario names from the index). The next slice starts after the founder says it works.

| # | Slice | Figma frames (scenario index) | Server (Part A) | Done when the founder can… |
|---|---|---|---|---|
| 1 | **Daybook and the work item loop** | D1 `2518:33001`, E1–E5, O1–O3, B1–B3, S1–S2, L1–L2, Y1–Y3, MN1 `2566:35619`, SI1 `2562:35576`; DS · Daybook components | A1 | write a work item in place, close the app and find the draft, post; Omar signs as done with the camera; check by double-tap with Undo; send back with a reason; add an update by swiping; edit, give to someone else, cancel; see Late and Due today |
| 2 | **Other kinds of post** | K1–K4 | A2 | post a checklist and tick it, an announcement with Got it, a scheduled activity with On my way and the reminder, a file with a new version and Received |
| 3 | **Chat and direct messages** | S7–S8m, DM1–DM6 | A5 (chat is live) | chat in the Space; message a teammate; receive a request from someone new, tap to show a photo, reply or decline; hold a message → Put in a Space |
| 4 | **People and Library** | P1–P3, Library, LV, Search | A3 search; people already live | let someone in with one pass choice, see a Viewer's read-only daybook, open file versions, search the Space |
| 5 | **Opening a post in place** | N1–N5 | A3 blocks | open a slip into its page, add blocks with + and /, drag, turn a line into a checklist point or a work item under this one, add a table |
| 6 | **Walk mode and work items under one** | R1, R1b, N5 target | A3 batch | walk the site, one photo and one line each, finish into one post with a work item per photo; see "2 of 4 checked" |
| 7 | **Templates and the daily report** | R2 | A3 templates | save a post as a template, start from it, fill the daily report from the day and share it as PDF |
| 8 | **My notebook and My calendar** | NB1, NB2, CAL1 | A4 | write private notes, to-dos with a time and a reminder, voice notes; put a note in a Space; see all Spaces and to-dos in the week |
| 9 | **Week report and meeting notes** | MR1 `2566:35515`, R3, R3b | A3 reports, batch | open the week report from ⋯, share it in chat; turn chat lines into work items with owners |
| 10 | **No signal and notifications** | OF, ER, NT1, NT2 | A2 pushes; existing push | post with no signal and see it wait then send; a failed photo retries; a push opens the exact slip; Needs you across Spaces |

Also in slice 1: Home H1 v3 and profile R1 v4 restyled in Daybook (no server change), and the Home app bar icons (messages, notebook) routed to placeholders until slices 3 and 8.

**Safety line, 15 Dec:** a slice not started by then moves to after the pilot (review 32). Slices are ordered so the pilot works even if 9 and 10's extras slip; slice 10's no-signal basics are already in slice 1 (app-chosen ids and the local draft).

**Out (don't build, even partly):** export a work item's record as PDF, approval codes, repeating work items, Translate, and the rest of the review 32 list.

## Clarifications (15 Oct, after Claude Code's questions)
1. **`edit_post`** changes title, text, place and due date. Changing the owner stays with `reassign_work_item` (it records "Given to … instead of …"). Agreed. Also include in edits, so the Daybook's "author edits files and points" holds:
   - migration 18: adding and removing the post's own files (`post_files`), while editable, recorded in `post_edits`;
   - migration 19: adding, rewording, reordering and removing checklist points (a ticked point can't be removed or reworded).
2. **"Something added by someone else"** (ends Delete): any update, sign-off or event by another person, or **any** child work item (whoever made it, since its owner was already told). Events by the author alone (raised, reassigned, edits) don't count. Migration 19 adds: any tick, and any acknowledgement (Got it, Received, On my way, In my calendar) by another person.
3. **Team posts** are visible only to that Team and the Space admins, as work items are today. Agreed; the same applies to `daybook_page`, `post_page`, `week_report`, `search_space` and `my_calendar`.

## Start now
Begin migration 18 on branch `daybook-db` with `/effort ultracode`. Report the hash and test counts when it's pushed.
