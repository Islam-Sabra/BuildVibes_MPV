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

## 6. Chat (week 6, after work items)
**Tables:**
- `threads`: `id`, `space_id`, `team_id null` (null means Everyone).
- `messages`: `id`, `thread_id`, `author_id`, `body`, `kind` ('text' | 'photo' | 'file' | 'voice' | 'work_item_card' | 'system'), `work_item_id null`, `created_at`, `edited_at`, `deleted_at`.
- `message_attachments`: `message_id`, `storage_path`, `mime`, `bytes`.

**Access:**
- Read: members of the Space. For a Team thread, only that Team's members and the Space admins.
- Write: the same members, except Viewers, who can chat in Everyone (all passes can chat).
- Live updates through Supabase Realtime on `messages`, filtered by thread.

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
- `needs_you()`: open items I own, Done items I may check, join requests I can confirm (kind, Space id, item or request id). `my_spaces()` gains `needs_you` per Space.

- `reassign_work_item(item, owner)`: while Open, by the creator or a member with `check_items`; the new owner must be able to mark items done; writes a 'reassigned' event. `needs_you()` gives the creator an 'owner_left' row when an Open item's owner is no longer an active member ("Owner left · reassign").

**Photos (review 09):**
- A photo counts only if the file exists in `space-files`, under the item's folder, uploaded by the caller.
- Uploads: the path must be `<space_id>/<item_id>/<file>`; allowed for the item's creator or owner, or, for an item not made yet, someone who can raise items. Never a Viewer. 10 MB; JPEG, PNG, WebP, HEIC.
- No updates: a photo is never replaced or renamed. Each upload has a new name (`<uuid>.jpg`). Delete (Storage API) only your own upload that isn't evidence.

**Shown work:** the view `public_shown_work` gives signed-in people only the title, one photo path (the Done sign-off's), the place, who checked it, the date and the project name. Never the Space name, the discussion or the files. The photo is only the owner's Done photo (never the one from when the item was raised). Hidden when either side blocked the other, for deleted accounts, and for deleted Spaces. Storage lets a non-member read exactly that photo, only while it is shown.

## 8. Library (migration 8)
**Tables:**
- `library_files`: `id`, `space_id`, `team_id null`, `name`, `storage_path`, `mime`, `bytes`, `uploaded_by`, `rev_label null`.

**Access:**
- Read: members.
- Write: `can(space, 'add_files')`.

**Storage:** the bucket `space-files` is private. Signed URLs are issued by a function that checks membership.

## 9. Feed (migration 9)
**Tables:**
- `posts`: `id`, `author_id`, `body`, `lang`, `project_id null`, `market_id`, `created_at`, `deleted_at`. Posts are public in V1 ("Your network").
- `post_media`: `post_id`, `storage_path`, `kind`, `sort`.
- `comments`: `id`, `post_id`, `author_id`, `body`.
- `useful_marks`: `post_id`, `profile_id`.
- `reports`: `id`, `reporter_id`, `target_kind`, `target_id`, `reason`, `note`, `status`.
- `account_deletion_requests`: port these from the old repo.

**Feed order:** home market first, then the rest. Not filtered.

## 10. Activity (migration 9)
**Tables:**
- `notifications`: `id`, `profile_id`, `kind`, `payload jsonb`, `read_at`. Written by triggers on work item events, join requests, mentions and follows.
- `push_tokens`.

**Access:** owner only.

## Tests required for every migration (SQL tests in `supabase/tests/`)
- A non-member can't select anything from a private Space: Space, messages, items, files.
- Crew can't create items. Viewer can't sign done. Only the owner can sign done. Only the creator (or an allowed Lead) can check.
- `work_item_events` can't be updated or deleted.
- A blocked user can't read the blocker's profile.
- The public shown-work view leaks nothing beyond its listed fields.
