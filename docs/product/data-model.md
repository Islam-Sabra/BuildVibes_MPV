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

## 5. Spaces (migration 4)
**Tables:**
- `spaces`: `id`, `name`, `purpose`, `kind` ('project' | 'community'), `access` ('private' | 'open'), `project_id null`, `who_can_invite` ('admins' | 'admins_leads' | 'everyone'), `auto_accept bool` (open communities only), `created_by`.
- `space_members`: `space_id`, `profile_id`, `pass` ('lead' | 'crew' | 'viewer'), `is_admin bool`, `custom jsonb` (fine-tuned rights), `confirmed_by`, `confirmed_at`, `left_at null`.
- `space_invites`: `id`, `space_id`, `code` (6 characters, unique), `created_by`, `expires_at`, `revoked_at`.
- `space_join_requests`: `id`, `space_id`, `profile_id`, `via` ('link' | 'code' | 'request'), `invited_by null`, `status` ('pending' | 'confirmed' | 'declined'), `decided_by`, `decided_at`.
- `teams`: `id`, `space_id`, `name`.
- `team_members`: `team_id`, `profile_id`.
- `space_notification_prefs`: `space_id`, `profile_id`, `level` ('all' | 'needs_you' | 'off').

**Helper functions** (`stable`, `security definer`):
- `is_member(space)`
- `member_pass(space)`
- `is_space_admin(space)`
- `can(space, right)`, where right is one of 'create_items', 'check_items', 'add_files' or 'invite'. It combines the pass presets from `space-project-model.md` with `custom`.

**Business functions:**
- `request_join(code_or_space)`
- `confirm_join(request_id, pass, team_ids[])` — admin only.
- `decline_join(request_id)` — admin only. The person isn't told the reason.
- `set_member_pass(space, profile, pass, custom)`
- `make_admin(space, profile, bool)`
- `leave_space(space)`

**Access:**
- A private Space is invisible to non-members. Selecting it returns nothing, not an error.
- An open community's name and purpose are readable by anyone signed in.
- Only admins change settings, passes and Teams.
- The last admin can't leave or remove themselves.

## 6. Chat (migration 5)
**Tables:**
- `threads`: `id`, `space_id`, `team_id null` (null means Everyone).
- `messages`: `id`, `thread_id`, `author_id`, `body`, `kind` ('text' | 'photo' | 'file' | 'voice' | 'work_item_card' | 'system'), `work_item_id null`, `created_at`, `edited_at`, `deleted_at`.
- `message_attachments`: `message_id`, `storage_path`, `mime`, `bytes`.

**Access:**
- Read: members of the Space. For a Team thread, only that Team's members and the Space admins.
- Write: the same members, except Viewers, who can chat in Everyone (all passes can chat).
- Live updates through Supabase Realtime on `messages`, filtered by thread.

## 7. Work items: the core (migration 6)
**Tables:**
- `work_items`: `id`, `space_id`, `ref` (for example 'KCT-021', unique per Space), `title`, `owner_id`, `created_by`, `team_id null`, `place_text`, `due_date`, `status` ('open' | 'done' | 'checked'), `created_at`.
- `work_item_events`: `id`, `work_item_id`, `actor_id`, `kind` ('raised' | 'done' | 'checked' | 'sent_back' | 'reassigned' | 'comment'), `note`, `reason` ('photo_missing' | 'not_as_drawing' | 'not_finished' | 'other' | null), `created_at`. Append-only: no update and no delete for anyone.
- `work_item_evidence`: `id`, `event_id`, `storage_path`, `kind` ('photo' | 'file' | 'voice'), `taken_at`, `place_text`.
- `work_item_attachments`: links to Library files.
- `shown_work`: `profile_id`, `work_item_id`, `shown bool`. Only for items with status `checked` where the profile was the owner.

**Functions** (the only way to change status):
- `create_work_item(space, title, owner, due, team, place, attachments[])`. Requires `can(space, 'create_items')`. Writes a 'raised' event, and the `ref` is generated.
- `sign_done(item, note, evidence[])`. Only the owner, and only while the item is `open`. Needs a photo or a note. Writes a 'done' event.
- `check_item(item)`. Only the creator, or a Lead with 'check_items' if the admin allowed it, and only while the item is `done`. Writes a 'checked' event.
- `send_back(item, reason, note)`. Same people as `check_item`. Sets status back to `open` and writes a 'sent_back' event with the reason.
- `set_shown_work(item, bool)`. Only the owner of a checked item.

**Access:**
- Read: Space members only.
- `public_shown_work` view: for profiles, it exposes only the title, one photo, the place, who checked it, the date and the project name. It never exposes the discussion, files or Space name for a private Space.

**Needs you** = open items I own, plus done items I can check, plus join requests I can confirm. It's a database view per user.

## 8. Library (migration 6)
**Tables:**
- `library_files`: `id`, `space_id`, `team_id null`, `name`, `storage_path`, `mime`, `bytes`, `uploaded_by`, `rev_label null`.

**Access:**
- Read: members.
- Write: `can(space, 'add_files')`.

**Storage:** the bucket `space-files` is private. Signed URLs are issued by a function that checks membership.

## 9. Feed (migration 7)
**Tables:**
- `posts`: `id`, `author_id`, `body`, `lang`, `project_id null`, `market_id`, `created_at`, `deleted_at`. Posts are public in V1 ("Your network").
- `post_media`: `post_id`, `storage_path`, `kind`, `sort`.
- `comments`: `id`, `post_id`, `author_id`, `body`.
- `useful_marks`: `post_id`, `profile_id`.
- `reports`: `id`, `reporter_id`, `target_kind`, `target_id`, `reason`, `note`, `status`.
- `account_deletion_requests`: port these from the old repo.

**Feed order:** home market first, then the rest. Not filtered.

## 10. Activity (migration 7)
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
