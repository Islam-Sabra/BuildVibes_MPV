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
  - `custom` holds only the rights changed from the pass preset: `create_items`, `add_files`, `invite`. (`check_items` was removed in migration 18: checking is not a right any more, see §7.)
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
| create items (post work) | ✓ | ✓ (since migration 18) | — | ✓ |
| check or send back an item | its author | its author | — | when the author left, or owns the item themselves |
| edit, delete or cancel a post | its author | its author | — | cancel only, when the author left |
| add an update (comment) | ✓ | ✓ | — | ✓ |
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
- **Work item cards:** migration 18 stopped them. Work lives in the daybook (§14); old cards stay in the threads and still can't be deleted. Until migration 18, raised, done, checked, sent back and reassigned posted a card into the item's Team thread when its owner was in that Team, otherwise into Everyone.
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
Rules from review 08, changed by migration 18 (review 33 A0, below). The app reads the tables; every change is a function.

**Since migration 18 (`20261015120000_daybook.sql`):**
- Every work item is also a daybook post (`space_posts`, §14) with the same id. The old tables are read through the post: only by those who may see it (Team posts: that Team, the Space admins, the author and the owner), never once it is deleted.
- **Crew post work** (Crew preset `create_items` on; an admin can switch it off for one person, which shows the pass as Custom). A Viewer never posts: a custom `create_items` on a Viewer pass is ignored and not stored.
- **Only the author checks or sends back.** A Space admin other than the owner does it when the author is gone, or when the author owns the item themselves; when the Space has no such admin (its only admin gave the work to themselves), any active Lead other than the owner does (review 34 D3).
  - **The author is gone** (`author_is_gone`) when they left the Space, their account is waiting to be deleted, or they can no longer post (lowered to Viewer, or posting switched off; review 34 D2). Then they can't check, send back, reassign or cancel, and the admin acts for them; raised back, it is theirs again. The owner never checks their own work. `check_items` is gone from the rights.
- Send back reasons: 'photo_missing' | 'not_as_asked' | 'not_finished' | 'other'. 'not_as_drawing' was renamed, in old events and stored notifications too.
  - **Old name, for now:** `send_back` still accepts 'not_as_drawing', which the 0.9.0 (1) test build sends, and stores it as 'not_as_asked'. Remove that once 0.9.0 is retired (every tester on a build from this branch or later).
- Only the author edits, deletes or cancels a post (§14). Updates (`add_comment`): the owner, Leads and Crew; Viewers read only.
- Reassign: the author, or a Space admin when the author is gone.
- No chat card for any event.

**Tables:**
- `spaces` gains `ref_prefix` (2–4 Latin capitals, set when the Space is made: the project's initials, else the Space's, else BV; existing Spaces backfilled) and `next_item_number`.
- `work_items`: `id` (chosen by the app, so photos upload first and retries don't duplicate), `space_id`, `number`, `ref` ('KCT-001'), `title`, `owner_id`, `created_by`, `team_id null`, `place_text`, `due_date`, `status` ('open' | 'done' | 'checked'), `done_at`, `checked_by`, `checked_at`, `shown` (off by default; only when checked).
- `work_item_events`: `kind` ('raised' | 'done' | 'checked' | 'sent_back' | 'comment'), `note`, `reason` ('photo_missing' | 'not_as_asked' | 'not_finished' | 'other', only on sent_back; 'not_as_drawing' until migration 18). Append-only: a trigger refuses every update and delete, except clearing the actor when an account is deleted.
- `work_item_evidence`: photos on the raised and done events, `storage_path` in the private bucket `space-files` at `<space_id>/<item_id>/<file>`.

**Functions:**
- `create_work_item(space, title, owner, due, team, place, evidence, id, body, parent, source_message, quote, files)` (the last five since migration 18): needs `can(space, 'create_items')`. The owner is one active member whose pass allows "mark own items done" (never a Viewer). Title 2–140 characters.
- `sign_done(item, note, evidence)`: the owner, while Open, with a photo or a note.
- `check_item(item)` and `send_back(item, reason, note)`: while Done, by the author; a Space admin when the author left or owns the item (migration 18). **Never by the item's owner.** "Other" needs a note.
- `add_comment(item, note)`: the owner, Leads and Crew who can see the item, while it is live (migration 18; before, any active member).
- `set_shown_work(item, bool)`: the owner of a Checked item.
- `needs_you()`: open items I own, Done items I may check, join requests I can confirm (kind, Space id, item or request id). `my_spaces()` gains `needs_you` per Space. Since migration 10, `needs_you()` starts from the caller's active memberships, and `my_spaces()` runs it once for all Spaces.

- `reassign_work_item(item, owner)`: while Open, by the author, or a Space admin when the author left (migration 18); the new owner must be able to mark items done; writes a 'reassigned' event. `needs_you()` gives the creator an 'owner_left' row when an Open item's owner is no longer an active member ("Owner left · reassign").

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
- **Teams:** a Team with chat messages, files or daybook posts (migration 18) can't be deleted; rename it instead.
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
| `item_edited`, `item_cancelled` | the author edited or cancelled it (migration 18; push since migration 19) | the owner; for a checklist or an activity, its people and calendar adds (migration 19) | the Space |
| `announcement_new` | an announcement (migration 19) | its audience: Everyone, or the Team and the admins | the Space |
| `checklist_for_you`, `activity_invited` | a checklist or an activity is for you (migration 19) | its people | the Space |
| `file_new_version` | a new version of a file you marked Received (migration 19) | those people | the Space |
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
- Work item kinds (edits and cancels too, since migration 19), the new post kinds (`announcement_new`, `checklist_for_you`, `activity_invited`) and a request to join: by the Space's level (`space_members.notify`): `off` none, `needs_you` and `all` yes.
- `file_new_version`: only at `all` (migration 19).
- `activity_starting` (migration 19): always, once per person and start time, from `due_activity_reminders()`; no Activity row. The text names nobody.
- A push about a daybook post opens its Space for now; the data carries `space_post_id`.
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
- The trigger `refuse_hidden_writer()` refuses new rows from it (42501, "restore your account first") in `posts`, `post_replies`, `messages`, `follows`, `useful_marks`, `work_items`, `work_item_events`, `library_files`, `space_join_requests`, and since migration 18 `space_posts`, `post_edits` and `post_files`.
- `purge_account()` locks the profile (a restore can't slip in) and waits while any avatar or post photo remains.
- Proof stays: `cv_project_confirmations` has an `id` key and `confirmed_by` set null when the confirmer is purged (one row per CV project and confirmer; several purged confirmers may remain). New proof always needs a confirmer who is still there (review 27 R1). A purged reporter's reports stay (`reporter_id` set null).

**Download my data (S10, S11):** `request_my_data()` (asking again returns the open one). The export holds only the person's own data: profile, CV, follows, posts, replies, messages, work items raised and owned, work item notes, daybook posts and edits (migration 18), acknowledgements, ticks and the posts they were for (migration 19), Library files uploaded, blocks, mutes, Useful marks, reports made, join requests and push settings. The founder exports with `export_my_data(id)` and marks it sent with `mark_data_sent(id)` (`supabase/ops/export_my_data.sql`), within 7 days. Service role only.

**Reports:** `prune_reports()` deletes reports decided over 12 months ago (nightly, in the same cron script).

## 14. Daybook (migration 18, `20261015120000_daybook.sql`, branch `daybook-db`, live 15 Oct)
Rules from review 33 (A0, A1 and the 15 Oct clarifications) and `docs/product/daybook.md`. The daybook is the Space's list of posts, newest first. A work item is one kind of post.

**Tables:**
- `space_posts`: `id` (chosen by the app, so a retry is the same post), `space_id`, `team_id` (null is Everyone), `kind` ('work_item' | 'checklist' | 'announcement' | 'activity' | 'file' | 'report'), `author_id`, `title` (1–200), `body` (≤5000), `place_text` (≤80), `due_date`, `parent_id` (a work item under one work item), `source_message_id` (made from a Space chat message), `quote` (words copied from a direct message or note: `author_name`, `text` 1–3000, `at`; never a link to the private thread), `template_id` (migration 20), `status` ('live' | 'cancelled'), `cancelled_by`, `cancelled_at`, `cancel_note` (≤500), `edited_at`, `created_at`, `deleted_at`.
  - A work item is a post of kind 'work_item' with the same id (`work_items.id` references `space_posts.id`, on delete cascade). Every existing item was backfilled with its title, place, due date, Team, author and time.
- `post_edits`: `post_id`, `editor_id`, `changes` (field → `{from, to}`, for showing "Edited: due moved from Sun to Mon"), `created_at`. Append-only (a trigger), like `work_item_events`.
- `post_files`: a post's own photos and PDFs (not sign-off proof): `post_id`, either `storage_path` (`<space>/posts/<post>/<file>`, unique) or `library_file_id`, `added_by`, `sort`, `mime`, `bytes`, `width`, `height`. At most 10 per post. A file claimed by the cleanup can't be added.
- Drafts stay on the phone, keyed by the post id the app chose. No table.

**Who sees a post:** active members of the Space, while it isn't deleted. A Team post only that Team, the Space admins, its author and (for a work item) its owner. A Team with posts (deleted or cancelled ones too) can't be deleted (`delete_team`, P0001), so a Team post never becomes an Everyone post; rename the Team instead. The same rule now covers `work_items`, its events, proof photos and attachments, Today, Activity and the post's files (before migration 18 every member read every work item).

**Names:** `space_person_name(id)` gives no name across a block or for a hidden account ("Former member" in the app).

**Functions** (the only way to write; the app reads through the two page functions):

| Function | Rule |
|---|---|
| `create_work_item(…, body, parent, source_message, quote, files)` | Lead and Crew (`create_items`). `parent`: a live, top-level work item (one level only) that the caller wrote, or acts for as an admin when its author is gone (review 34 D1); the Team is inherited. `source_message`: a chat message the caller can read, not a card; a Team thread's message makes a Team post. A retry with the same id returns the same post; someone else's id is refused. |
| `edit_space_post(post, changes)` | Author only, while they may still post (not lowered to Viewer, posting not switched off; files need the files right), and while editable: a work item while Open (locked after Done, open again after Send back, locked for good after Checked); other kinds while live. Keys: `title`, `body`, `place`, `due`, `add_files`, `remove_files`. Every change goes into `post_edits` and tells the owner (`item_edited`). The owner is changed with Reassign, not by editing. Checklist points come in migration 19 (a ticked point can't be removed or reworded). |
| `delete_space_post(post)` | Author only, and only while nobody else has added anything: no update, sign-off, check or file by someone else, and no work item under it, whoever made it (migration 19 adds ticks and acknowledgements). A soft delete: the post leaves the daybook, Needs you, Today and Activity, and its files are released for the cleanup. |
| `cancel_space_post(post, note)` | The author, or a Space admin when the author is gone (left, or their account is waiting to be deleted). Not a Checked item; it locks the work items first, so a sign-off or check running at the same moment finishes before it. The post stays with a CANCELLED stamp; work items under it that aren't Checked are cancelled with it; each owner is told (`item_cancelled`). Nothing can be signed, checked or added after. |
| `daybook_page(space, before, limit, before_id)` | The posts the caller may see, newest first (at most 100). The next page passes the last post's time and id, so posts made at the same moment aren't skipped. Each post has: stamp, paper clip (`needs_me`), cover photo, progress of the items under it, last edits. |
| `post_page(post)` | One post in full: files, record of events, attachments, items under it, parent, all edits. |
| `needs_you()` | Open items I own; Done items I check (I'm the author, or an admin acting for an author who is gone or owns it); "Owner left" for whoever acts for the author; join requests I can confirm. |

Pushes for `item_edited` and `item_cancelled` come in migration 19.

**Files:** uploads to `<space>/posts/<post>/<file>` (JPEG, PNG, WebP, HEIC or PDF): before the post exists, whoever may post (their own folder only); after, its author while it can be edited. Reads follow the post. A Library file on a live post can't be deleted, and stays when its chat message is removed (`library_file_in_use`).

## 15. Other kinds of post (migration 19, `20261015180000_post_kinds.sql`, branch `post-kinds-db`, live 15 Oct)
Rules from review 33 A2 and its clarifications. Checklists, announcements, scheduled activities and file posts live in the daybook (§14) next to work items, with the same reading, Team and edit rules.

**Columns on `space_posts`:** `pinned_until` (announcements), `starts_at` and `ends_at` (activities; ends after it starts, within a day) and `library_file_id` (file posts; the Library file can't be deleted while a post shares it).

**Tables:**
- `post_people`: who a checklist or an activity is for (role 'for'). Active members only; Lead or Crew for a checklist (they tick), anyone for an activity (a Viewer attends). On a Team post, Team members or Space admins only. A purged person is removed.
- `checklist_points`: `post_id` (a checklist, or a work item), `sort`, `text` (1–300), `ticked_by`, `ticked_at`. A tick keeps its time when the person is purged ("Former member").
- `post_acks`: `post_id`, `profile_id`, `kind` ('got_it' on announcements, 'received' on files, 'on_my_way' and 'in_my_calendar' on activities); one per person and kind. You read only your own.
- `activity_reminders`: one "starts in 30 min" push per person and start time. Service role only.
- `post_others`: the first tick or acknowledgement by someone other than the author. It ends Delete for good, even if taken back. Nobody reads it but the database's own functions, since it would tell readers that someone acknowledged.
- `notifications.space_post_id`: the post a notification is about, when it isn't a work item.

**Who does what:**

| | Rule |
|---|---|
| Post any kind | Lead and Crew (`create_items`); a file post also needs the files right and a Library file the caller can read in that Space, a Team file only on that Team's post. A Team post only from inside the Team (or a Space admin). The id is the app's; a retry is the same post. |
| Checklist | One or more people, 1 to 50 points, an optional due date. |
| Announcement | Everyone or one Team; pinned until a time in the next 90 days, or not pinned. |
| Scheduled activity | Starts in the future; place and people optional. Editable until it ends. |
| File | Shares one Library file; its title is the file's name unless the author writes one. A new version is a new file post of a file that replaces the older one (`library_files.supersedes_id`): NEW VERSION stamp, "Replaces Rev C". |
| Tick a point (`tick_point`) | The author, its people and any Lead or Crew member; never a Viewer (an admin's Viewer pass included). Untick: whoever ticked it, or the author (an admin when the author is gone). A work item's points only while it is Open. |
| Edit (`edit_space_post`) | The author. New keys: `points` ({add, edit, remove, order}; a ticked point can't be removed or reworded, but can be moved), `people` ({add, remove}), `pinned_until`, `starts_at` and `ends_at`. A key that doesn't fit the kind is refused. Place: work items, checklists, activities. Due: work items, checklists. |
| Acknowledge (`ack`) | Any active member who can read the post, Viewers too; taken back with `p_on` false. On my way from 3 hours before the start to the end; In my calendar until the end. Nothing on a cancelled post. |
| Who acknowledged (`post_acks_for`) | Faces and names, never a number (rule 3). Received on a file post: everyone who can see the post, so the crew sees who has the new revision (review 36 R1, as the prototype shows). Got it, On my way and In my calendar: the author only (an admin when the author is gone; `may_see_acks`). |
| Delete | Ends at any tick or acknowledgement by someone else, as well as the §14 rules. |
| Cancel | As §14; a checklist's or an activity's people and calendar adds are told. |

**Reading:** `space_post_json` adds the pin (while pinned), the activity's time, its people, the points' progress ("2 of 5 ticked"; every point with who ticked it when opened), the file (name, revision, size, what it replaces, whether a newer one exists), and the caller's own acknowledgements. `daybook_extras(space, from, to)` gives what sits above the list: pinned announcements, and activities starting between the phone's day start and end.

**Needs you:** a live checklist I'm for, while I can still tick (not lowered to Viewer) and a point is unticked ('checklist_for_you', with the new last column `space_post_id`).

**Notifications** (see §10 and §11): `announcement_new` (its audience), `checklist_for_you` and `activity_invited` (its people, also when added later), `file_new_version` (whoever marked an older version Received and can see the new post), and `item_edited` / `item_cancelled` also to a checklist's or an activity's people and calendar adds. Every fan-out goes only to people who can still see the post (someone taken out of its Team hears nothing). `activity_starting`: `due_activity_reminders()` (service role, cron every 5 minutes in `supabase/ops/activity_reminders_cron.sql`, not run yet) pushes to the people and calendar adds of activities starting in 25 to 35 minutes, once per person and start time, even when the Space is set to Off; no Activity row.

**Live, each with its own yes:** deploy the push function with the new texts first, then push migration 19, then run `supabase/ops/activity_reminders_cron.sql`.

## 16. Notebook and My calendar (migration 21, `20261015230000_notebook.sql`, branch `notebook-db`, live 16 Oct)
Rules from review 33 A4. Written by the lead on 15 Oct (review 37), follow-ups in review 38. **21 before 20; 20 is built on 21** (both replace `export_my_data`, and 20 has the later timestamp).

**Tables (owner only: nobody else reads them, not even a Space admin):**
- `notes`: `id` (chosen by the app), `owner_id`, `kind` ('text' | 'checklist' | 'todo' | 'voice'), `body` (≤5000), `points` (a checklist's: `[{text, done}]`, 1–50, text 1–300), `due_at` and `done_at` (to-dos only), `pinned`, `remind_at`, `put_in_post_id` (the post it was put in), `created_at`, `updated_at`. Deleting a note removes its words and files.
- `deleted_notes`: only the id of a deleted note (`id`, `owner_id`, `created_at`, `deleted_at`), so it can't come back. It replaces A4's `deleted_at`: a deleted note is gone, only its id stays. Nobody reads it; only `delete_note` writes it (review 38 N3).
- `note_files`: a note's photos or its one recording: `note_id`, `storage_path` (unique), `kind` ('photo' | 'voice'), `mime` (from Storage), `bytes`, `width`, `height`, `duration_ms`, `sort`. At most 10 per note. A file the cleanup has claimed can't be added.
- Bucket `notebook-files` (private, 25 MB; photos and voice): `<me>/<note_id>/<file>`. Read only your own folder; upload only into your own folder (not into the folder of someone else's note), at most 200 files and 200 MB a day; delete only your own file that no note uses; no update.

**Functions:**

| Function | Rule |
|---|---|
| `save_note(id, kind, body, points, due_at, remind_at, pinned, files)` | New or your own. Text: words or a photo; checklist: 1–50 points; to-do: words, an optional time; voice: one recording. A recording only on a voice note. Changing the kind clears what no longer fits. `pinned` null keeps the pin; `files` null keeps the files, a list replaces them (your uploads in that note's folder only). At most 500 new notes a day, deleted ones included, under a per-person lock that also turns a retry of the same id into an update. Saving a deleted note changes nothing and returns null, so the app drops its queued edit. A hidden account can't write. |
| `delete_note(id)` | Yours. Its id is kept in `deleted_notes`. Its files are released (the app deletes them with the Storage API; the cleanup takes any left behind). |
| `set_note_done(id, on)`, `pin_note(id, on)` | Yours; done only on a to-do. |
| `mark_note_put(note, post)` | Yours, and a post you wrote. "Put in a Space" itself is done in the app: it opens that Space's writing card with the note's words. The note stays private. |
| `my_calendar(from_day, to_day, from, to)` | Up to 62 days (both ends included); the phone sends its own days and midnights, so no time zone is typed in SQL. Each row has the post's `place` (null for a to-do; CAL1 shows it). Rows: `work_item` (live, mine to sign or written by me, due then, not yet Checked, with `needs_me`), `checklist` (live, I'm for it, due then, with `needs_me`), `activity` (live, I'm in it or put it in my calendar, starting then), `todo` (my notebook to-dos due then, done ones marked). Only Spaces I'm still in; Team posts as §14. No colour: the app gives each Space its colour. |

"Remind me" is a local notification on the phone; `remind_at` is kept so the app can set it again after a reinstall. No server push.

**Cleanup (service role):** `orphan_note_files(age)` claims notebook files no note uses, older than a day, under the same per-file lock; the job deletes them with the Storage API and calls `forget_cleanup_claims()` (now also for `notebook-files`). Scheduled with the other cleanups, with the founder's yes.

**Account:** `export_my_data` includes the notes and their file names. `accounts_due_for_purge` lists `notebook-files` too, and `purge_account` waits until they are gone; the notes go with the account.

## 17. Pages, walk mode, meeting notes, templates, reports and search (migration 20, `20261016120000_post_pages.sql`, branch `post-pages-db`, live 16 Oct)
Rules from review 33 A3 and its clarifications; choices confirmed in review 39. **Goes live after migration 21** (review 38 N1); its copy of `export_my_data` is 21's plus pages and templates.

**A post's page** (opening it in place, N1–N5):
- `space_posts.blocks` (a list, at most 100 KB) and `blocks_version`. Title, words, place, due and points stay the post's own fields.
- Blocks, each `{id, type, ...}` with its own id: `text` (up to 2000), `heading` (1–200, level 1 or 2), `toggle` (1–200, holding text, headings, tables, photos and files; one level), `table` (1–20 rows of 1–8 cells of up to 200 characters, every row as wide), `photo` (`path`: a photo of this post), `file` (`library_file_id`: a Library file on this post), `checklist_ref` (`point_ids`: points of this work item or checklist, each in one block only), `child_item` (`post_id`: a work item under this top-level work item, for the same readers: an Everyone page never shows a Team's work item), `item_ref` (`post_id`, in a report only: a work item of the Space its readers may all see). At most 200 blocks, toggle children included; block ids are lower-case uuids. A reference already on the saved page is kept even if its work item goes, so a page never stops saving (readers' views leave it out). Any kind but a file post has a page.
- `validate_blocks(post, blocks)` checks all of this; a template's page holds words only.
- `save_blocks(post, blocks, base_version, add_files)`: the author while they may post, under the edit rules (a work item only while Open). A save from an older version is refused with `40001`; the app reloads and applies its change again. `add_files` adds the post's own files in the same step. One `post_edits` row per save (`page: {from, to}`); a work item's owner hears of page saves at most once in 10 minutes.
- A photo, file or point the page shows can't be removed by an edit (`P0001`), and a Library file a page shows stays in the Library.
- "Turn into" happens in the app: a point is added with `edit_space_post`, a work item under this one with `create_work_item`, then the page is saved.
- Reading: the slip gains `has_page`, `template_id` and, for a walk, `children.rows` (the first 10 work items under it: title, status, owner, photo); the opened post gains `blocks`, `blocks_version`, `refs` (a report's work items, as this reader may see them) and, under `under`, each item's owner and photo.

**Walk mode and meeting notes** (R1, R1b, R3):
- `create_walk(space, parent, title, items, place, team)`: one parent work item and, under it, one work item per photo (`{id, line, owner, photo}`, 1–30, each photo uploaded to that item's post folder first).
- `create_from_message(space, message, parent, title, lines)`: from a text message the caller can read (not reported, not by someone blocked), one parent and one work item per line (`{id, text, owner}`, 1–30). All of them record the message; a Team thread's message keeps them in that Team.
- Both: Lead and Crew (`create_items`), a Team walk only from inside the Team; all or nothing; the same parent id again returns it. The parent is a work item owned by its author: a **target** (`is_target`, review 39). While it has work items under it, nobody is asked to sign or check it, it can't be signed as done or checked, and so it never counts as proof on a profile; its progress is theirs ("3 of 5 checked"). Each owner gets one push for the whole batch, opening the parent, or their own work item when they can't see the parent (someone outside a Team walk's Team); each work item still has its Activity row. A retry running at the same moment waits and returns the parent.

**Templates** (`post_templates`): `id`, `space_id` (null for a built-in), `team_id` (the Team of the post it came from), `kind` (work item, checklist, announcement, report), `builtin_key`, `name` (1–60), `blocks` (words only), `fields` (`{title, body, points}`), `created_by`, `deleted_at`.
- The one built-in is the **Daily report** (`daily_report`), with three headings stored as keys, `on_site`, `done_today` and `problems` (as the prototype's R2; the app gives the words in each language).
- `save_template(id, space, from_post, name)`: a Lead or a Space admin, at most 50 in a Space; only the words come (no photos, files or work items; points as text). `delete_template(id)`: a Lead or a Space admin; built-ins stay. `space_templates(space)`: the built-ins and the Space's own (a Team's only for that Team and the admins).
- `create_space_post` gains `template` (the same kind and audience) and `blocks`, and posts kind `report`. `create_work_item` gains `template` (a work item template), `blocks` and `points`.

**Reports:**
- A **daily report** is a post of kind `report`, usually from the Daily report template. `daily_report_fill(space, team, from, to)` gives what was checked that day (title, ref, owner, checker, the Done photo) for "Done today", only work all the report's readers may see (an Everyone report never brings in a Team's work). Share as PDF is made on the phone.
- `week_report(space, today, from, to)` (MR1, up to 7 days; the phone sends its own days and midnights): needs a decision (late, sent back, waiting for a check; never a target), checked this week (with the Done photo and who checked), targets (work items with work items under them still to check, and their progress), coming up (activities and due dates in the next 7 days from now). Each person sees only what they may read; rows with names, never per-person totals (rule 3); at most 30 a section.
- `share_week_report(id, thread, week_start)`: a chat message of kind `report` with `messages.report_week`; whoever taps it opens the week report with their own rights. The 0.9.0 app shows such a message as an empty bubble.

**Search** (`search_space(space, q)`): posts (title, words and page), checklist points, chat messages and Library file names the caller may read, newest first, 30 at most; 2 to 100 characters, `%` and `_` as typed. Never private notes or direct messages. Space content of someone blocked stays, without the name (as chat and the daybook).
- `search_fold(text)`: lower case, without tatweel, harakat or direction marks; أ/إ/آ/ٱ to ا, ى to ي, ة to ه, ؤ/ئ to ء, Arabic digits to 0–9; spaces and line breaks as one space. The same folding for what is stored and what is typed (review 39). No stemming. The snippet finds the match in the text as written.
- Stored, indexed columns `search_text` (trigram) on `space_posts`, `checklist_points`, `messages` and `library_files`. If `search_fold` changes, a migration recomputes them by touching every row (for example `update public.messages set body = body`).

## 18. Direct messages (migration 22, `20261016180000_dm.sql`, branch `dm-db`, live 16 Oct)
Rules from review 33 A5, founder decision F10 and review 41 (`space-scenarios.md`, "Direct messages and Space info"): **we manage, we don't block.** Anyone can message anyone, as much as they like, with photos, files and voice notes.

**Work link:** the two are active members of the same Space (any pass, a deleted Space doesn't count), or each follows the other. Without one, the receiver gets a **Message request**.

**Tables** (written only through the functions; the two people read them):
- `dm_threads`: one per pair (`a_id < b_id`, unique), `started_by`, `created_at`, `last_message_at`. A purged person becomes null and the other keeps the thread ("Former member"); a thread with both purged goes.
- `dm_members`: each person's `state` ('open' | 'request' | 'declined'), `last_read_at`, `declined_at`, `request_pushed_at`, `muted`. **Each person reads only their own row**, so the other never learns a decline, a read time (no read receipts) or a mute.
- `dm_messages`: `id` (the app's), `thread_id`, `author_id`, `kind` ('text' | 'photo' | 'file' | 'voice'), `body` (up to 3000), `reply_to` (same thread), `created_at`, `deleted_at`. Never edited.
- `dm_attachments`: `message_id`, `storage_path`, `name`, `mime`, `bytes`, `width`, `height`, `duration_ms`, `sort`. At most 10 a message; a voice note on its own. Never copied to a Library.
- Bucket `dm-files` (private, 25 MB; photos, PDF, voice) at **`<author>/<message>/<file>`**, not A5's `<thread>/…`: a new thread's id is only known once its first message is sent, and the purge finds a person's files by their own folder. Upload into your own folder for a message not sent yet, within the daily cap shared with Space files (300 files, 500 MB). **A file is read through its message** (review 41): only the two people, never across a block, not once the message is deleted, not by someone who reported it; its sender too. Your own upload is readable before it is sent. Delete only your own file that no live message uses.
- `app_settings`: `key`, `value`. Nobody reads it from the app; the founder changes it by SQL (with a yes), no release. `dm_unanswered_limit = {"limit": 50, "warn_at": 40, "days": 30}`.

**Who sees what:** only the two people, and never across a block (either way): the thread is hidden from both and nothing can be sent. Someone waiting for account deletion stays in the thread as "Former member" and can't be messaged or write.

**Requests:**
- Replying opens the thread; there is no Accept button. A request also becomes a thread as soon as the two get a work link (joining a Space, a follow back), and **stays open if the link ends** (review 41).
- `decline_dm(thread)` ("Not in your Spaces · Decline · Block" on a request, review 41): it leaves the receiver's lists quietly; the sender isn't told. If the sender writes again it is a request again, with no push for 30 days after the decline. Block stops it for good.
- Photos and files from someone you haven't answered come with `tap_to_show` (shown blurred until tapped).

**Spam guard:** `dm_unanswered_count(sender, days)` counts the people the sender started a thread with in the last `days` who are still in request or declined and never wrote back. Starting a thread with a **new** person (no work link): from `warn_at` such people, `start_dm` returns a warning; from `limit`, it makes nothing and returns state `paused` with `until`, the day one frees up. Existing threads are never affected, and someone with a work link is never counted.

**Functions:**

| Function | Rule |
|---|---|
| `start_dm(thread, to, message, body, attachments)` | Finds the pair's thread or makes one (the app's id); both starting at once make one. Not yourself, a missing or hidden person, or across a block (all the same `42501`). Returns `{thread, state, warning, until}`. |
| `send_dm(id, thread, body, reply_to, attachments)` | One of the two; 30 messages a minute; a retry with the same id is the same message. |
| `delete_dm(id)` | Your own; "Message deleted"; its files go to the cleanup. |
| `mark_dm_read(thread)`, `decline_dm(thread)`, `mute_dm(thread, on)` | Yours. Mute is in the thread's ⋯ menu (with Report the person and Block); muted, no pushes from it. |
| `my_dm_threads(before, before_id, limit)` | Open threads newest first (the other person, last message, an unread dot, muted), and on the first page the Message requests row (the newest request only, **never a count**). |
| `my_dm_requests()`, `dm_thread_page(thread, before, before_id, limit)`, `dm_shared_space(thread)` | Requests; a thread's messages, newest first, with files and `tap_to_show`; the first Space both are in, for "Both in …" (never a count). |

**Push:** `dm_request` once per new person (none within 30 days of a decline), never with text; `dm_message` in an open thread like Space chat, at most one per thread every 5 minutes, with the text only if the person turned on "Show message text" (S3). Not when muted, declined, across a block or to a hidden account. No Activity rows. A push opens `/messages/<thread>`. The push function needs these texts deployed before the migration goes live.

**Reports:** `report('dm_message', id)` by the person it was sent to hides it for them at once; `decide_report` removes it and keeps its words for an appeal, like a Space message (`content_removals` and `removed_content`); `decide_appeal` can bring it back. Moderation (`ops/moderation.sql`) sees only that message and its files (the paths in `dm-files`), never the thread.

**Account:** `export_my_data` has the messages the person sent (never those they received) and their threads; `accounts_due_for_purge` and `purge_account` include `dm-files`, and the purge then removes the person's file rows, so a message of theirs with no words left shows as "Message deleted" while their words stay for the other person (review 42); `orphan_dm_files(age)` claims files no live message uses for the cleanup job (scheduled with the other cleanups, with the founder's yes), keeping a removed message's files while its removal can be appealed (14 days).

**Live, each with its own yes:** deploy the push function with the direct message texts, then push migration 22.

**Put in a Space and Save to my notebook** happen in the app: a work item with the message as its `quote` (§14), or `save_note` with its words (§16). The message stays private.

## 19. Daybook extras (migration 23, `20261017120000_daybook_extras.sql`, branch `daybook-extras-db`, not live)
Answers in review 44 (questions 2, 3, 5).

**A due time.** `space_posts.due_at` (optional) sits next to `due_date` on work items and checklists. The phone sends both, its own date and its own time, so no time zone goes in SQL. `due_at_fits(day, at)` (a table check too) only lets a time that falls on that date somewhere on Earth (UTC−12 to UTC+14); a time needs a date.
- `create_work_item(…, p_due_at)` and `create_space_post(…, p_due_at)` (checklists only) take it.
- `edit_space_post`: `due` and `due_at` change together. A new date alone has no time (the same date sent again keeps it); a time alone keeps the date; clearing the date clears the time. The Edited line keeps its shape, `due: {from, to}`, with `from_at` and `to_at` when a time is involved; a time-only change has `from` equal to `to`, so the app reads `from_at`/`to_at` first.
- **Late** (`is_late`): a timed item is late after its time; a date-only item is late from the day after its date (the phone's today), as before. In `week_report`, a timed item is late after its time, and is "coming up" until then, whatever the reader's today; every list with a due date carries `due_at`.
- `my_calendar` puts a work item's or checklist's time in `starts_at`, as a to-do's. `space_post_json` and Download my data carry `due_at`.
- `work_items.due_date` keeps the date only (it mirrors `space_posts.due_date`).

**On site since.** `spaces.site_start_date` (optional) is set only by a Space admin with `set_site_start_date(space, day)`: not before 2000 and at most a year ahead; null clears it. Members read it with the Space. The daybook counts "day N" from it (that day is day 1); without it, the line shows only the date. It is never counted from the Space's creation date (rule 3).

**The month drop-down.** `daybook_month(space, from_day, to_day, from, to)` covers at most 62 days. A non-member gets nothing.
- `posts` rows: the quarter hours (`at`, rounded down to 15 minutes, distinct) with a post the caller can see, as the daybook page lists them. The phone groups them by its own days; every time zone is a whole number of quarter hours from UTC.
- `due` rows: the days (`day`) with a live work item that isn't checked, or a live checklist with a point not ticked, the caller can see.
- A dot per day, never a count. A Team's posts follow `can_see_space_post`.

**Undo of a check** needs nothing on the server: the app holds the check for the undo bar's 5 seconds, then sends it (review 44, answer 4). The same applies to every action with an undo bar.

## Tests required for every migration (SQL tests in `supabase/tests/`)
- A non-member can't select anything from a private Space: Space, messages, items, files.
- Search, the week and daily reports and templates never show a Team's posts to someone outside the Team.
- Viewer can't create items or sign done. Only the owner can sign done. Only the author checks (a Space admin when the author left or owns the item); the owner never checks.
- `work_item_events` and `post_edits` can't be updated or deleted.
- A blocked user can't read the blocker's profile.
- The public shown-work view leaks nothing beyond its listed fields.
