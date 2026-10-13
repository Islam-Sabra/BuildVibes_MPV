# MVP data model and permission rules (lead spec, 11 Oct 2026)

Supabase Postgres. Every table has row-level security (RLS) switched on, with **no** blanket policies.

Every state change that has business rules goes through a Postgres function (`security definer`, with `search_path` set). The app never updates those columns directly:
- joining
- passes
- work item steps
- showing proof

**Conventions:**
- All ids are `uuid default gen_random_uuid()`.
- Rows carry `created_at`/`updated_at` (`timestamptz`).
- Soft delete uses `deleted_at` where history matters.
- Text the user writes is stored as written. Labels come from reference tables with translations.

## 1. Market pack and reference data (migration 1)
**Tables:**
- `markets`:
  - `id text pk` (for example 'kw', 'eg') and `status` ('live' | 'soon' | 'hidden');
  - `name jsonb` ({en, ar}) and `default_locale`;
  - `dial_code`, `phone_rules jsonb`, `code_channel` ('whatsapp' | 'sms');
  - `currency`, `currency_decimals`, `week_start`, `weekend int[]`;
  - `legal jsonb` (urls per language).
- `places`: `id`, `market_id`, `parent_id`, `level` ('city' | 'area'), `name jsonb`, `sort`.
- `role_families`: `id text pk`, `name jsonb`, `sort`.
- `trades`: `id text pk`, `family_id`, `name jsonb`, `sort`.
- `market_trades`: `market_id`, `trade_id`, `visible`, `local_name jsonb`.
- `company_kinds`: `id text pk`, `name jsonb`.
- `project_types`: `id text pk`, `name jsonb`.

**Access:**
- RLS: anyone, signed in or not, can **read** these tables. Nobody can write to them from the app; they're seeded by migration.
- Seed: Kuwait and Egypt packs, with clearly marked placeholder values where a local reviewer must confirm (phone rules, place list, legal URLs). Trades come from the role picker in Figma: Site engineer, Electrician, Steel fixer, Foreman, Site manager, Plumber, Carpenter, Mason, Architect, Design engineer, BIM specialist, Project manager, Supplier or trader, and others in the same families.

## 2. People (migration 2)
**Tables:**
- `profiles`: `id uuid pk references auth.users`, `first_name`, `last_name`, `headline`, `trade_id`, `home_market_id`, `place_id`, `company_id null`, `company_name_text null`, `photo_path`, `about`, `locale` ('en' | 'ar'), `created_at`.
  - Exactly one of `company_id` or `company_name_text` may be set.
- `profile_private`: `id pk/fk`, `phone_e164`, `recovery_email`. Only the owner can read or write it.
- `experience`: `id`, `profile_id`, `title`, `company_id | company_name_text`, `start_month`, `end_month null`, `visibility` ('everyone' | 'connections' | 'only_me').
- `follows`: `follower_id`, `followee_id`, `created_at`, with primary key (`follower_id`, `followee_id`).
- `blocks`: `blocker_id`, `blocked_id`.

**Access:**
- Profiles: any signed-in user can read them, **except** when either side has blocked the other. Only the owner can update their own profile.
- Follower and following counts are allowed on profiles (founder decision). Store them as plain counts computed from `follows`; never use them for ranking.

## 3. Companies (migration 2)
**Tables:**
- `companies`: `id`, `name`, `kind_id`, `market_id`, `place_id`, `logo_path`, `about`, `created_by`, `verified bool`.
- `company_admins`: `company_id`, `profile_id`.

**Access:** anyone can read. Only company admins can write. Never create a company from text a user typed.

## 4. Projects: a shared record with no owner (migration 3)
**Tables:**
- `projects`: `id`, `name`, `type_id`, `market_id`, `place_id`, `location_text`, `start_year`, `end_year null`, `end_expected bool`, `created_by`, `status` ('active' | 'merged'), `merged_into null`.
- `project_edit_suggestions`: `id`, `project_id`, `suggested_by`, `changes jsonb`, `status` ('pending' | 'accepted' | 'rejected'). Reviewed in the back office (service role only).
- `cv_projects`: `id`, `profile_id`, `project_id`, `role_title`, `start_month`, `end_month`, `show_on_profile bool default true`.
- `cv_project_confirmations`: `cv_project_id`, `confirmed_by`, `source` ('space_member' | 'teammate'), `space_id null`.

**Functions:**
- `find_similar_projects(name, place_id)`: the search behind "Is it already here?".

**Access:**
- Projects: anyone signed in can read. Anyone can create one, but only after `find_similar_projects` has been offered (the app enforces this; the server rate-limits it).
- **There is no update policy on projects.** Corrections go through suggestions only.
- `cv_projects`: the owner writes. Others read only when `show_on_profile` is set.

## 5. Spaces (migration 6, `20261011160000_spaces.sql`)
**MVP:** private **work** Spaces only. Community Spaces come after the pilot. The columns `kind` and `access` are there already, but `create_space()` only makes `work` / `private`.

**Tables:**
- `spaces`: `id`, `name`, `about`, `kind` ('work' | 'community'), `access` ('private' | 'invite_only' | 'open'), `project_id null`, `who_can_invite` ('admins' | 'admins_leads' | 'everyone'), `created_by`, `deleted_at` (a soft delete; kept for the record).
- `space_members`: `space_id`, `profile_id`, `pass` ('lead' | 'crew' | 'viewer'), `is_admin bool`, `custom jsonb`, `notify` ('all' | 'needs_you' | 'off'), `confirmed_by`, `confirmed_at`, `left_at null`, `removed_by`.
  - `custom` holds only the rights changed from the pass preset: `create_items`, `check_items`, `add_files`, `invite`.
  - Notification preferences live here, not in a separate table.
- `space_invites`: `id`, `space_id`, `code`, `created_by`, `expires_at` (7 days), `revoked_at`.
  - The code is 6 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (no look-alikes), made from strong random bytes.
  - Only one live invite per Space; a new code revokes the old one.
- `space_join_requests`: `id`, `space_id`, `profile_id`, `via` ('code' | 'link'), `invite_id`, `invited_by`, `status` ('pending' | 'confirmed' | 'declined' | 'cancelled'), `decided_by`, `decided_at`. At most one pending request per person and Space.
- `space_code_attempts`: wrong codes, for the rate limit (10 an hour, shared by `request_join` and `invite_preview`).
- `teams`: `id`, `space_id`, `name` (unique per Space, any case).
- `team_members`: `team_id`, `profile_id`, `added_by`.

**"Owners" in the design are the Space admins.** There can be several. "Transfer ownership" makes someone else an admin and steps you down.

**Rights** (`pass_rights` + `custom`, checked by `member_can` / `can`):

| | Lead | Crew | Viewer | Admin |
|---|---|---|---|---|
| chat | ✓ | ✓ | ✓ | ✓ |
| mark own items done (fixed) | ✓ | ✓ | — | ✓ if Lead or Crew |
| create items | ✓ | — | — | ✓ |
| check others' items | ✓ | — | — | ✓ |
| add files | ✓ | ✓ | — | ✓ |
| invite | if Who can invite allows | | | ✓ |

Who can invite:
- 'admins': only admins.
- 'admins_leads': anyone whose rights include invite (Lead preset, or custom).
- 'everyone': every member.

**Helper functions** (`security definer`, `search_path = ''`):
- `is_member(space)`, `is_space_admin(space)`, `member_pass(space)`, `can(space, right)`;
- `member_rights(space, profile)`, for members of that Space only.

**Business functions** (the only way to write):

| Area | Functions |
|---|---|
| Space | `create_space(name, about, project)`, `update_space`, `set_space_project`, `delete_space`, `set_space_notifications` |
| Invites | `current_invite(space)`, `renew_invite(space)` (admins), `invite_preview(code)` (signed in) |
| Joining | `request_join(code)` (returns a status, never raises for a wrong code), `my_join_requests()`, `cancel_join_request` |
| Admin decisions | `confirm_join(request, pass, team_ids[])`, `decline_join` (the person isn't told why), `undo_decline` |
| Members | `set_member_pass(space, profile, pass, custom)`, `set_member_teams`, `set_member_admin`, `transfer_ownership`, `remove_member`, `leave_space` |
| Teams | `create_team`, `rename_team`, `delete_team`, `set_team_members` |
| Lists | `my_spaces()` |

**Rules:**
- A private Space is invisible to non-members: a select returns nothing, not an error.
- Members see each other and all Teams.
- Join requests are read by the Space's admins. The person who asked sees their own requests through `my_join_requests()`, which never says who decided.
- A Space always keeps an admin:
  - the last admin can't leave or step down;
  - admin changes lock the Space row, so two admins can't leave at the same moment;
  - if the last admin's account is deleted, the longest-serving Lead (or member) becomes admin;
  - a Space left with no members is deleted.
- After a decline, the same person can ask that Space again only after a day.
- The request to join is sent by the app after sign-in, never at sign-up, so an unverified email never reaches an admin.
- **Proof:** in a Space linked to a project, the admin's confirmation of a member confirms that member's CV entry for the project (`cv_project_confirmations`, source 'space_member'). This applies at once, or when they add the project later.
  - It never counts when you confirmed yourself, or when two people confirmed each other.
  - **Founder decision (11 Oct 2026):** a second account made by the same person is accepted as a known gap for the pilot. Every Confirmed row shows who confirmed it ("Confirmed by {name}"), so readers can judge. Revisit after the pilot.
  - Unlinking removes the confirmations from that Space; other Spaces linked to the same project keep theirs.
- **Home country:** a person who is waiting to join a Space, or whom someone else confirmed in one, may choose a home country that is "coming soon" (decision 04). Creating your own Space doesn't count.

## 6. Chat (migration 9, `20261012140000_chat_library.sql`, branch `chat-library-db`)
**Tables:**
- `threads`: one Everyone thread per Space (`team_id` null) and one per Team, made automatically.
- `messages`: `id` (chosen by the app), `thread_id`, `space_id`, `author_id`, `kind` ('text' | 'photo' | 'file' | 'voice' | 'work_item'), `body`, `reply_to` (same thread), `work_item_id`, `work_item_event_id`, `deleted_at`, `deleted_by`. Never edited.
- `message_attachments`: `storage_path` (`<space>/chat/<message_id>/<file>`), `mime`, `bytes`, `width`, `height`, `duration_ms`.
- `thread_reads`: last read time per person and thread.

**Rules:**
- **Reading and writing:** active members; a Team thread only for that Team's members and the Space admins. Every pass can chat.
- **Attachments:** photos, PDFs and voice notes need the "add files" right (Viewers chat in text only). They must be your own uploads under the message's folder, and their type must match the upload. A voice note is sent on its own.
- **Deleting:** the author or a Space admin; it stays as "Message deleted" (no text, files hidden). Work item cards can't be deleted.
- **Work item cards:** raised, done, checked, sent back and reassigned post a card into the item's Team thread when its owner is in that Team, otherwise into Everyone.
- **Limits:** 30 messages a minute (cards don't count). Uploads: 300 files or 500 MB a day per person, plus the migration 8 cap on loose files.
- **Live updates:** Supabase Realtime on `messages`, through the same policy.

**Functions:**
- `post_message(id, thread, body, reply_to, attachments)`: a retry with the same id returns the same message.
- `delete_message`, `mark_thread_read`.
- `share_library_file(id, thread, file, body)` (migration 11, F1 "Share in chat"):
  - posts a message of kind 'file' that points at a Library file (`messages.library_file_id`), so the file isn't uploaded again and no second "From chat" copy is made;
  - a Team's file is shared only in that Team's thread;
  - the caller must be able to read the file, and needs the "add files" right (a Viewer chats in text only, review 14);
  - a retry with the same id returns the same message.
  - `delete_message` (migration 11) also clears `library_file_id`, so a deleted message keeps no link to a file. When a shared file is removed later, the app shows "File removed".
- `space_threads(space)` (S7k): threads with the last message and unread count.

## 7. Work items: the core (migration 7, `20261012120000_work_items.sql`, branch `work-items-db`)
Rules from review 08. The app reads the tables (active Space members only); every change is a function.

**Tables:**
- `spaces` gains `ref_prefix` (2–4 Latin capitals, set when the Space is made: the project's initials, else the Space's, else BV; existing Spaces backfilled) and `next_item_number`.
- `work_items`: `id` (chosen by the app, so photos upload first and retries don't duplicate), `space_id`, `number`, `ref` ('KCT-001'), `title`, `owner_id`, `created_by`, `team_id null`, `place_text`, `due_date`, `status` ('open' | 'done' | 'checked'), `done_at`, `checked_by`, `checked_at`, `shown` (off by default; only when checked).
- `work_item_events`: `kind` ('raised' | 'done' | 'checked' | 'sent_back' | 'comment'), `note`, `reason` ('photo_missing' | 'not_as_drawing' | 'not_finished' | 'other', only on sent_back). Append-only: a trigger refuses every update and delete, except clearing the actor when an account is deleted.
- `work_item_evidence`: photos on the raised and done events, `storage_path` in the private bucket `space-files` at `<space_id>/<item_id>/<file>`.

**Functions:**
- `create_work_item(space, title, owner, due, team, place, evidence, id)`: needs `can(space, 'create_items')`. The owner is one active member whose pass allows "mark own items done" (never a Viewer).
- `sign_done(item, note, evidence)`: the owner, while Open, with a photo or a note.
- `check_item(item)` and `send_back(item, reason, note)`: while Done, by the creator or a member with `check_items` (admins have it), **never by the item's owner**. "Other" needs a note.
- `add_comment(item, note)`: any active member.
- `set_shown_work(item, bool)`: the owner of a Checked item.
- `needs_you()`: open items I own, Done items I may check, join requests I can confirm (kind, Space id, item or request id). `my_spaces()` gains `needs_you` per Space. Since migration 10, `needs_you()` starts from the caller's active memberships, and `my_spaces()` runs it once for all Spaces.

- `reassign_work_item(item, owner)`: while Open, by the creator or a member with `check_items`; the new owner must be able to mark items done; writes a 'reassigned' event. `needs_you()` gives the creator an 'owner_left' row when an Open item's owner is no longer an active member ("Owner left · reassign").

**Photos (review 09):**
- A photo counts only if the file exists in `space-files`, under the item's folder, uploaded by the caller.
- Uploads: the path must be `<space_id>/<item_id>/<file>`; allowed for the item's creator or owner, or, for an item not made yet, someone who can raise items. Never a Viewer. 10 MB; JPEG, PNG, WebP, HEIC.
- No updates: a photo is never replaced or renamed. Each upload has a new name (`<uuid>.jpg`). Delete (Storage API) only your own upload that isn't evidence.

**Follow-ups (migration 8, `20261012130000_work_items_followups.sql`, branch `work-items-followups`, not live yet):**
- "Owner left · reassign" also when the owner can no longer sign (changed to Viewer); it goes to the creator, or, when the creator left too, to every member who may check. The owner's own Needs you drops it.
- Before an item exists, only the uploader reads its folder; `create_work_item` refuses an id whose folder holds someone else's files.
- 'reassigned' events keep `from_owner_id` and `to_owner_id`.
- At most about 200 MB or 400 loose files (not evidence) per person. `orphan_space_files()` lists loose files older than 7 days for a cleanup job (service role, Storage API).
- Migration 10: the totals (`loose_uploads`, `uploads_today`) look only in the folders of the Spaces the caller has been in, through Storage's name index. An index on `owner_id` isn't possible: `storage.objects` belongs to Storage's own role.
- Cleanup (migration 10). SQL can't delete Storage files, so the job:
  1. calls `claim_orphan_files(age, limit)`, which re-checks each file under a per-file lock and writes a claim (`file_cleanup_claims`);
  2. deletes the returned files with the Storage API;
  3. calls `forget_cleanup_claims()`.

  Evidence, chat attachments and Library files can't reference a claimed file (a trigger, under the same lock). A claim whose delete failed stays until the next run. Not scheduled yet (founder).
- The app keeps an unsent item's photos on the phone until it's sent. When the server refuses an earlier upload (cleaned up after a long wait), it uploads the phone copy again, once.
- The append-only rule allows only the service role, cascades from deleting a work item or Space, and clearing a deleted account.
- `my_delivered_work()` (RE2): your Checked items, shown or hidden, even after leaving the Space; your own uploads stay readable to you.
- Your own uploads stay readable to you after you leave the Space. They're your own photos (accepted, review 11).

**Shown work:** the view `public_shown_work` gives signed-in people only the title, one photo path (the Done sign-off's), the place, who checked it, the date and the project name. Never the Space name, the discussion or the files. The photo is only the owner's Done photo (never the one from when the item was raised). Hidden when the owner and the viewer have blocked each other (either side), for deleted accounts, and for deleted Spaces. When the viewer and the **checker** have blocked each other, the item still shows as Checked, without the checker's name (migration 10; the same in `my_delivered_work()`). Storage lets a non-member read exactly that photo, only while it is shown.

## 8. Library (migration 9)
**Tables:**
- `library_files`: `id` (chosen by the app), `space_id`, `team_id` (optional), `name`, `storage_path` (`<space>/library/<id>/<file>`, or the chat path for documents shared in chat), `mime` (images or PDF), `bytes`, `rev_label`, `note`, `supersedes_id` (an older revision of the same Space and Team, kept), `source` ('upload' | 'chat'), `source_message_id`, `uploaded_by`, `deleted_at`.
- `work_item_attachments`: a Library file on a work item ("Used in KCT-021").

**Rules:**
- **Reading:** members; Team files only for that Team and the admins.
- **Adding:** the "add files" right, with your own upload. A Team file needs you in that Team, or an admin.
- **PDFs posted in chat** are added automatically ("From chat").
- **Removing:** the uploader or an admin, never a file a work item uses.
- **Attaching to an item:** the item's creator, owner or a member who may check. A Team file only on that Team's items.
- **Teams:** a Team with chat messages or files can't be deleted; rename it instead.
- **Storage:** private bucket `space-files` (25 MB; images, PDF, audio). Work item folders take photos only. Files are opened through signed URLs, which the read policy checks.
- **File type (accepted for the pilot, review 13):** Storage records the type the app sends with the upload (`metadata.mimetype`), limited to the bucket's list. It doesn't look inside the file. The type checks (`upload_mime`, "evidence must be a photo") rest on that declared type.
- **Cleanup age (migration 11):** `claim_orphan_files` never claims a file younger than one day, whatever age the job asks for, so an upload still going on a weak signal is left alone.

**Functions:**
- `add_library_file`, `delete_library_file`, `attach_library_file`.

## 9. Feed (migration 12, `20261012170000_feed.sql`, branch `feed-db`)
**Tables:**
- `posts`: `id` (made in the app, so a retry posts once), `author_id`, `body` (up to 3000; null once deleted, or for a photo-only post), `lang` ('en' | 'ar'), `project_id`, `market_id` (the author's home market when posting), `created_at`, `edited_at`, `deleted_at`.
- `post_media`: `post_id`, `storage_path`, `sort` (0–3), `width`, `height`. Photos only, at most 4.
- `post_replies`: `id`, `post_id`, `author_id`, `reply_to` (a top-level reply on the same post: one level only, "Replying to"), `body` (up to 1000), `created_at`, `deleted_at`.
- `useful_marks`: `target_kind` ('post' | 'reply'), `target_id`, `profile_id`. The primary key is all three: once per person.
- `mutes`: `muter_id`, `muted_id`.
- Reports on posts and replies come in week 8.

**Who sees what:**
- Posts are public to every signed-in person ("Your network"), except across a block (both ways) and once deleted.
- Muting a person takes their posts out of the muter's feed only; their profile still shows them.
- A deleted post's replies and photos stop showing to anyone. Its photo rows stay, so the cleanup removes the files after the 30-day appeal window.
- You read only your own Useful marks and mutes. Nobody reads a count.

**Photos:** private bucket `post-media`, paths `<author>/<post>/<file>`.
- Upload: `<me>/<post uuid>/<name>.jpg|jpeg|png|webp|heic`, at most 100 photos and 100 MB a day (counted in your own folder only).
- Read: your own uploads, or a photo of a post you may see. No update.
- Delete (Storage API): your own photo that no post uses.
- `orphan_post_media(age)` (service role): claims photos no post uses, older than a day, and the photos of posts deleted over 30 days ago, with the same `file_cleanup_claims` flow as Space files. It runs in the nightly cleanup, which waits for the founder's yes. A claimed photo can't go on a post.

**Functions:**
- `create_post(id, body, lang, project, media)`:
  - needs text or a photo;
  - the photos must be your uploads in `<me>/<id>/`;
  - the project must be on your CV, shown, with a confirmed role (C10);
  - photos must be JPEG, PNG, WebP or HEIC by their stored type;
  - 20 posts a day, counted under a per-person lock so parallel calls can't beat it.
- `edit_post(id, body, lang)`: the author only; sets `edited_at`. Photos and the tag can't change.
- `delete_post(id)`: the author only.
- `add_reply(id, post, reply_to, body)`: 60 an hour (under a per-person lock). `delete_reply(id)`: the author only.
- `mark_useful(kind, id, on)`: not on your own. `mute(person, on)`.
- `feed_page(cursor)`, 20 a page:
  - first, your home market from the last 30 days, newest first; then every other post, newest first;
  - no home market: every post is in the second part;
  - the cursor is `{section, created_at, id, since}`; `since` starts the 30 days and comes back with each page, so the window doesn't move while scrolling;
  - no ranking by counts, no follow filter.
- `posts_by(person, cursor)` (R12/R16). `posts_tagged(project, cursor)` (the project sheet). A tag follows merges to the end of the chain (A into B into C shows C, up to 5 steps).
- `useful_names(post)`: at most two names of people you follow who marked it. Never a count.
- The view `post_cards` (the caller's rights apply) gives a card: author name, headline and company, text, language, photos, the shown project (or the one it was merged into, only if active), and whether you marked it.

## 10. Activity (migration 13, `20261012180000_activity.sql`, branch `activity-db`)
**Tables:**
- `notifications`: `id`, `profile_id` (who it's for), `kind`, `actor_id`, `space_id`, `work_item_id`, `post_id`, `reply_id`, `request_id`, `payload`, `day` (Useful only), `created_at`, `read_at`.
  - Written only by triggers; the app can't insert, change or delete one.
  - Never to the actor, never across a block (either way), and Space news only to people still in the Space.
- `space_visits`: `profile_id`, `space_id`, `seen_at`. Set by `mark_space_seen(space)` when you open a Space.
- `push_tokens` and `push_queue`: section 11.

**Kinds and who gets them:**

| Kind | From | To | Activity group |
|---|---|---|---|
| `item_assigned` | an item raised for you, or reassigned to you | the owner | the Space |
| `item_done` | signed as done | the creator | the Space |
| `item_checked`, `item_sent_back` | checked, or sent back (with the reason) | the owner | the Space |
| `item_comment` | a comment | the owner and the creator | the Space |
| `join_request` | a request to join | every admin | the Space |
| `join_confirmed` | the request confirmed | the new member | the Space |
| `role_confirmed` | proof from a Space or a teammate (the Space is in `payload`) | the person | Your record |
| `follow` | a new follower | the person followed | Your network |
| `post_reply` | a reply to your post, or to your reply | the author(s) | Your posts |
| `post_useful` | Useful on your post: one row per post per day (UTC), moved up by each mark, with no actor kept | the author | Your posts |

A declined request makes no notification. Useful on a reply makes none.
- Repeats merge: asking to join the same Space again within a day updates the admins' row; following again within 7 days adds no row.
- A Useful row names at most two people you follow (`useful_names`): "{a} found your post useful", or "Your post was found useful". Nobody can list who marked a post.

**Access:** each person reads only their own rows and visits.

**Functions:**
- `my_activity(cursor)`: the last 7 days, newest first, 100 at a time (cursor `{at, id}`). Each row has its group, the Space name and your pass, the item's ref and title, the post or reply text (one line), the request's status, the project of a confirmed role, the actor's name, and `seq`, its place in its group (1 = the oldest, letter A). Rows drop out when the post or reply is deleted or you may no longer see the post (a block), you left the Space, you are no longer an admin (requests to join), or you blocked the actor. Useful rows carry `useful_names`.
- `mark_activity_read()`: when Activity opens. `unread_activity()`: yes or no, never a number.
- `home_day(day_start)`: the H1b header: the needs-you count, Spaces with something new today, and replies today to your chat messages. Each is your own count.
- `today_in_spaces(day_start)`: one row per Space with something new since your last visit and today, by someone else: a work item event first, then a Library file, then the last chat message (only threads and files you may read). Newest first; the app shows 5.
- `day_start` is the phone's midnight, so no time zone is typed in SQL; the server keeps it within the last two days.

## 11. Push notifications (migration 14, `20261012190000_push.sql`, branch `push-db`)
**Tables:**
- `push_tokens`: `token` (FCM), `profile_id`, `platform` ('android' | 'ios'), `locale` ('en' | 'ar', the language of its pushes), `updated_at`. You read only your own phones. At most the newest 10 per person; phones not seen for 60 days are removed nightly.
- `push_settings`: the S3 switches: `followers` (on), `replies` (on), `message_text` ("Show message text on lock screen", off). A missing row means the defaults.
- `push_queue`: `profile_id`, `kind`, `actor_id`, `notification_id`, `thread_id`, `data` (ids for the link only), `message_text` (only when the person turned it on; cleared when the message is deleted or the push is sent), `created_at`, `claimed_at`, `attempts`, `not_before` (FCM's Retry-After), `sent_at`, `error`. Service role only.

**Who gets a push** (rows come only from triggers, and only for people with a phone registered):
- Work item kinds and a request to join: by the Space's level (`space_members.notify`): `off` none, `needs_you` and `all` yes.
- A confirmed request and a confirmed role: always. A new follower and a reply: by the S3 switch. Useful: never.
- A chat message: everyone who may read the thread and set the Space to `all`; never the author, never across a block; at most one per thread per person every 5 minutes. Chat makes no Activity row. Work item cards in chat send nothing (their event already did).
- A repeat request to join (after cancelling, within a day) merges into the admins' notification, so it sends no new push.

**Functions:** `register_push_token(token, platform, locale)` (a token from another account moves; the newest 10 are kept), `unregister_push_token(token)` (sign-out), `my_push_settings()`, `set_push_settings(followers, replies, message_text)`.
- Service role only (the push function and cron): `claim_push(id)` takes a row once (unsent, not claimed in the last minute, not asked to wait, under 5 attempts); `finish_push(id, error)` marks it sent and clears its text; `release_push(id, wait, error)` puts it back after a temporary failure; `retry_push_queue()` lists rows to send again (unsent over a minute, under an hour old); `prune_push_queue()` removes rows over a day old and phones not seen for 60 days.
- A push problem never blocks the step that caused it: the queue inserts warn and carry on.

**Sending:** the Edge Function `push` (`supabase/functions/push/`, `verify_jwt = false`), called by a database webhook on `push_queue` inserts and every minute by cron for retries.
- It checks the `x-push-secret` header in constant time (500 when the secret isn't set), reads only the row id, claims the row, and sends from the database copy, so a repeated call sends once.
- FCM 429 and 5xx put the row back (after Retry-After); only an error naming the token (UNREGISTERED, an invalid registration token, SENDER_ID_MISMATCH) deletes it, never a plain 404.
- The text comes from `strings.json` in the phone's language, and never names a project, a Space or a work item.
- Each new row calls it through a trigger (`supabase/ops/push_webhook.sql`) that reads the secret from Vault and sends only `{record: {id}}`; not a dashboard webhook, which would keep the secret in plain text in the catalog. Both fetches give up after 10 seconds, inside the 60-second claim window.
- After the 5th failed attempt a row is finished and its text dropped at once. SENDER_ID_MISMATCH (another project's key) never deletes phones.
- Live, each with the founder's yes: deploying it with its secrets (`FIREBASE_SERVICE_ACCOUNT`, `PUSH_WEBHOOK_SECRET`, and the same value in Vault as `push_webhook_secret`), then running `supabase/ops/push_webhook.sql` and `supabase/ops/push_cron.sql`.

## 12. Safety (migration 15, `20261013120000_safety.sql`, branch `safety-db`)
**Tables:**
- `reports`: `reporter_id`, `target_kind` ('post' | 'reply' | 'profile' | 'message'), `target_id`, `reason` (the six R1 reasons: spam, harassment, misleading, fake, private_info, other), `note` (needed for "other", at most 500), `status` ('open' | 'removed' | 'dismissed'), `created_at`, `decided_at`. One per reporter and thing. Nobody reads reports in the app.
- `content_removals`: `target_kind`, `target_id`, `author_id`, `reason`, `report_id`, `removed_at`, `appeal_note`, `appeal_at`, `appeal_status` ('none' | 'open' | 'upheld' | 'reversed'). The author reads their own rows.
- `removed_content`: the removed text (and, for a chat message, its Library link and the Library copies hidden with it), kept so an appeal can restore it. Service role only.
- `market_moderation`: `market_id`, `email`: where report alerts go. Service role only; never public.
- Activity gets two kinds, `content_removed` and `appeal_decided`, under "Your record"; neither sends a push.

**Hidden for the reporter:** a post, reply or message you reported disappears for you at once: the read rules on posts, replies, messages and their files; `can_see_post`; feed pages, profile and project post lists; the thread list; Home's Today line and replies count; Activity rows for a reply you reported. Everyone else still sees it until it is decided. A chat document's separate Library copy is not hidden by reporting the message.

**Functions:**
- `report(kind, id, reason, note)`: only what you can see, never your own, at most 20 a day; reporting again returns the same report.
- `block(person, on)` and `my_blocks()` (S7): the existing `blocks` table, so every block rule already on the server applies.
- `my_removal(id)` (R3, the author only): what, why, a short copy, and whether an appeal is still open; `appeal(removal, note)`: once, within 14 days, 1–500 characters.
- Service role only (`supabase/ops/moderation.sql`): `decide_report(id, 'remove' | 'dismiss', reason)` (a person can't be removed; every open report on the same thing is decided with it; removing a chat message hides its Library copy too; NULL is refused), `decide_appeal(removal, 'uphold' | 'reverse')` (reverse restores the content as it was), and `report_alert(id)` (the alert's id, kind, reason, time and the market's address; never the content).

**Photos:** the photo cleanup leaves a removed post's photos while its appeal is open, or for 14 days after the removal.

**Alert:** a trigger on new reports (`supabase/ops/report_alert_webhook.sql`, the Vault and `pg_net` pattern of push) calls the Edge Function `report-alert`, which emails the market's moderation address through Resend. Deploying it with its secrets (`REPORT_ALERT_SECRET`, `RESEND_API_KEY`, `ALERT_FROM`) and running the script are live changes for the founder's yes.

## 13. Account (migration 16, `20261013130000_account.sql`, branch `account-db`)
**Columns and tables:**
- `profiles.deletion_scheduled_at`: set when the person asks to delete their account; null otherwise.
- `markets.support_email` (the address S10, S11 and Help show; set by the founder), and `markets.legal` gains `delete_account` (per language) next to `terms` and `privacy`.
- `data_requests`: `profile_id`, `status` ('open' | 'sent'), `created_at`, `sent_at`. At most one open request per person. You read your own; requests are made only through `request_my_data()`.

**Deleting an account (S12b, S13, S14):**
- `account_deletion_blockers()`: the Spaces where you are the only admin and others are still in. Transfer each (S15d) first.
- `request_account_deletion()`: needs a sign-in code entered in the last 10 minutes (the token's `amr` "otp" entry; `signed_in_recently()`), refused while a blocker remains. Hides the account at once, deletes its push tokens, and returns when it goes for good (30 days).
- While scheduled, `is_blocked_with` and `blocked_between` treat the account as blocked by everyone else: profile, posts, replies, follows, CV, shown work, people search, Activity and pushes all leave it out; invite previews don't name it; S7 doesn't list it. In Spaces the messages, work and membership stay, and the name can't be read ("Former member").
- `restore_account()` within the 30 days; `my_account_deletion()` for S14's date.
- After 30 days: the Edge Function `account-purge` (nightly, `supabase/ops/account_cron.sql`) deletes the avatar and post photos through the Storage API (`accounts_due_for_purge()`), then `purge_account(id)` deletes the user. Own rows cascade; Space records set the person to null; the last-admin handover runs if needed. Service role only. Deploying it with `ACCOUNT_PURGE_SECRET` and running the script are live changes for the founder's yes.

**A hidden account can't act (review 26):**
- It has no admin rights (`is_space_admin`), doesn't count as another admin (`has_other_admin`, `account_deletion_blockers`), can't be made admin (`set_member_admin`, `transfer_ownership`), and the last-admin handover passes it over (a hidden member is chosen only if nobody else is left).
- `request_account_deletion()` locks every Space the person is in before the check, so two admins can't both go at once and nobody is made admin meanwhile (review 27 R3).
- `leave_space` refuses the last admin by their own membership row, so a hidden sole admin can't leave (review 27 R2).
- The trigger `refuse_hidden_writer()` refuses new rows from it (42501, "restore your account first") in `posts`, `post_replies`, `messages`, `follows`, `useful_marks`, `work_items`, `work_item_events`, `library_files` and `space_join_requests`.
- `purge_account()` locks the profile (a restore can't slip in) and waits while any avatar or post photo remains.
- Proof stays: `cv_project_confirmations` has an `id` key and `confirmed_by` set null when the confirmer is purged (one row per CV project and confirmer; several purged confirmers may remain). New proof always needs a confirmer who is still there (review 27 R1). A purged reporter's reports stay (`reporter_id` set null).

**Download my data (S10, S11):** `request_my_data()` (asking again returns the open one). The export holds only the person's own data: profile, CV, follows, posts, replies, messages, work items raised and owned, work item notes, Library files uploaded, blocks, mutes, Useful marks, reports made, join requests and push settings. The founder exports with `export_my_data(id)` and marks it sent with `mark_data_sent(id)` (`supabase/ops/export_my_data.sql`), within 7 days. Service role only.

**Reports:** `prune_reports()` deletes reports decided over 12 months ago (nightly, in the same cron script).

## Tests required for every migration (SQL tests in `supabase/tests/`)
- A non-member can't select anything from a private Space: Space, messages, items, files.
- Crew can't create items. Viewer can't sign done. Only the owner can sign done. Only the creator (or an allowed Lead) can check.
- `work_item_events` can't be updated or deleted.
- A blocked user can't read the blocker's profile.
- The public shown-work view leaks nothing beyond its listed fields.
