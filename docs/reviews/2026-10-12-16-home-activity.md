# Review 16: week 7 brief — Home feed and posts, Home Spaces tab, Activity, push (12 Oct 2026)

Week 6 is done (review 15 passed: voice note screenshots c1–c4 checked in English and Arabic).

## 0. Before you start
- Read `docs/design/home/README.md` (frames and what is in the MVP), `docs/product/rules.md` §2 and §5, and `docs/product/data-model.md` §2, §9 and §10.
- Images: ask the founder to tell the lead "export the week 7 images" at the start of each part. Download them from `docs/design/_fetch_home.txt` right away.
- **Three founder decisions are open** (§6). Build everything else; the parts they touch are marked "waits for decision".
- Same working rules as weeks 5–6:
  - every write goes through a `security definer` function with `search_path = ''`;
  - each migration gets SQL tests and goes to the lead before it goes live;
  - nothing goes live without the founder's yes;
  - after every push, check that it really landed on GitHub.

## 1. Scope
**In:**
- **Posts:** write a post with up to 4 photos, an optional project tag, and its language. Edit the text, delete the post.
- **Feed tab (H1 v2):** site update cards, home market first, then "Beyond {market}". Useful, Reply. First load, couldn't load, offline.
- **Post detail (H10v2, H10c):** replies, one level of "Replying to", Useful on posts and replies, delete your own reply.
- **Profile → Posts (R12, R16)** and the **project sheet's posts**.
- **Mute a person** (H8, toast).
- **Home Spaces tab (H1b):** "Your day on site", Needs you, Today in your Spaces, "That's your day". The Profile top bar gets the Spaces icon that opens My Spaces (S1), as in R1 v3.
- **Activity (A1 v2, A2):** Needs you, then "Changes to your record" for the last 7 days.
- **Push notifications:** Android first; iPhone when the Apple developer account exists. Settings → Notifications (S3, S4).

**Out (don't build any part of it):**
- record cards, hiring notices, Congratulate;
- the Notebook and Messages icons in the Home top bar;
- the guest feed;
- Save, Share, Copy link, "Not interested" (decision 2);
- comment controls (who can comment, hide, pin);
- voice, files or events in posts, and posting as a company;
- Translate (decision 1);
- @mentions (decision 3);
- Report on posts and replies (week 8, with block).

## 2. Feed and posts (migration 12, `feed`)
**Tables:** follow data-model §9, adjusted:
- `posts`: `id` (made in the app, so a retry never posts twice), `author_id`, `body` (max 3000), `lang` ('en' | 'ar'), `project_id null`, `market_id` (the author's home market when posting), `created_at`, `edited_at`, `deleted_at`.
- `post_media`: `post_id`, `storage_path`, `sort`, `width`, `height`. Photos only, max 4.
- `post_replies`: `id`, `post_id`, `author_id`, `reply_to null` (one level only), `body` (max 1000), `created_at`, `deleted_at`.
- `useful_marks`: `target_kind` ('post' | 'reply'), `target_id`, `profile_id`, `created_at`. Primary key on all three, so each person marks a post once.
- `mutes`: `muter_id`, `muted_id`.

**Storage:** a new private bucket `post-media`, with paths `<author>/<post>/<file>`.
- Upload follows the same rules as Space photos: images only, the uploader's own folder, compressed on the phone, kept in the outbox until sent.
- Any signed-in person can read a photo of a post they can see.

**Who sees what:**
- Posts are public to every signed-in person ("Your network"), except:
  - blocked people, in both directions;
  - posts of people you muted (only you stop seeing them);
  - deleted posts.
- The project tag shows only if the project is `active`. A merged project points to the project it was merged into.

**Functions:**
- `create_post(id, body, lang, project_id, media[])`:
  - It needs text or at least one photo.
  - The project must be on the author's CV, with a confirmation, and shown on the profile (C10: "Only projects where you have a confirmed role").
  - Rate limit: 20 posts a day.
- `edit_post(id, body, lang)`: the author only; sets `edited_at`. Photos and the project can't be changed. To change them, delete and post again.
- `delete_post(id)`: the author only.
- `add_reply(id, post, reply_to, body)`: rate limit 60 an hour. `delete_reply(id)`: the author only.
- `mark_useful(kind, id, on)`; `mute(person, on)`.
- `feed_page(cursor)`, 20 per page:
  - First, posts from the viewer's home market from the last 30 days, newest first.
  - Then the divider, then every other post, newest first.
  - The cursor carries the section, `created_at` and `id`.
  - **No ranking by counts, and no follow filter.** For one pilot team, a follow-only feed would be empty.
- **Proof line:** `useful_names(post)` returns at most 2 names, of people the viewer follows who marked the post useful. No names, no line. **Never a count** (rules §2), for the author too.
- `posts_by(person, cursor)` for Profile → Posts, and `posts_tagged(project, cursor)` for the project sheet.

**Screens:**
1. **Card (H1 v2, site update):**
   - The project strip (only when tagged): the project tile, name and place.
     - The chip shows the **project type**. The MVP has no project phase, so never invent "CONSTRUCTION".
     - Tapping the strip opens the project sheet (PJ1).
   - Then the author name and role · company · time.
   - Then the text and the photos: one large photo; 2–4 photos in a grid; tap to view.
   - Then the proof line, and the actions **Useful · Reply**.
   - The `•••` menu:
     - for someone else's post: Mute {name};
     - for your own: Edit post, Delete post.
   - A post with no project and no photo is the text card alone. That's normal.
2. **Divider:** "Beyond {market}", filled from the market pack.
3. **States:**
   - H4 skeleton: until the first page arrives, or 3 seconds at most.
   - H5 "Couldn't load your Feed · Try again".
   - H6 offline banner, with the last loaded page cached on the phone.
   - Empty feed: an `EmptyNote`, "No posts yet. Share what happened on site today.", with **Create**.
4. **Composer (C1 v2 → C2 v2):**
   - The "Posting to" card: "Your network · Everyone", plus " · tagged {project}" when tagged. It opens C3 v2, which has one option.
   - "What happened on site today?"
   - The four "Start from" tiles fill the text with the template's lines, in the app language:
     - Progress update → "Done today:", "Next:", "Holding us up:";
     - Milestone → "What:", "When:", "Who did it:";
     - Site visit → "Where:", "What we found:", "Actions:";
     - Ask the community → "Question:", "Who knows:".
     - The tiles hide once there's text.
   - Footer tools: **Media** and **Project** only.
   - The Post button is disabled until there's text or a photo. The hint line reads "Choose how to start, or just write", or "Posting to {project}" when tagged.
   - **The audience line under the photos replaces the prototype's "The 48 project members will see this":** "Everyone on BuildVibes can see this. It also shows on the project's page." (or "…can see this." with no project). The prototype line breaks rule §2 (a member count) and isn't true: posts are public.
   - Drop the auto tag line ("Tagged Structure · Superstructure"). The MVP has no discipline or phase data.
   - The language line (L5): "Written in English · Change" opens L6.
     - L6 options: Detected automatically / English / العربية. One single-choice control.
     - Detection: Arabic if most letters are Arabic.
   - C10 Tag a project:
     - rows are your confirmed, shown projects;
     - empty: "Add a project on your profile first", which opens the CV project add;
     - keep the line "Work for your team goes in the project's Space as a work item".
   - Close: C13 "Discard this post?" when there's content.
5. **Posting (P3, P3b, C14):** posts go through an outbox like chat messages.
   - The Feed shows "Posting to your network…".
   - On failure: "Couldn't post. Saved as a draft. · Retry". Nothing is lost.
   - Drop "Keep the app open until it finishes": the outbox survives closing the app.
6. **Post detail:**
   - H10v2 for a visitor; H10c for your own post.
   - "Replies", with "Add a comment" at the bottom.
   - Reply on a reply shows "Replying to {name}" (H17).
   - Your reply's `•••` → Delete (H13, H14). Other people's replies get no menu until week 8 (Report).
   - "Edited" label (P2). P6 "Post unavailable" for a deleted or blocked post.
7. **Profile → Posts (R12 own, R16 visitor)** and the **project sheet's posts**: the same card, without the project strip on the project sheet.

## 3. Home Spaces tab and Activity (migration 13, `activity`)
**Tables:**
- `notifications`: `id`, `profile_id`, `kind`, `actor_id`, `space_id null`, `work_item_id null`, `post_id null`, `payload jsonb`, `created_at`, `read_at`.
  - Owner reads only.
  - Written only by triggers, never by the app.
- `space_visits`: `profile_id`, `space_id`, `seen_at`. Set by `mark_space_seen(space)` when you open a Space.
- `push_tokens` and `push_queue`: see §4.

**Kinds and who gets them** (never the actor, never across a block):

| Kind | To | Activity group | Push level (§4) |
|---|---|---|---|
| `item_assigned` (raised or reassigned to you) | the owner | the Space | needs you |
| `item_done` | the creator | the Space | needs you |
| `item_checked` | the owner | the Space | needs you |
| `item_sent_back` | the owner | the Space | needs you |
| `item_comment` | the owner and the creator | the Space | needs you |
| `join_request` | every admin of the Space | the Space | needs you |
| `join_confirmed` | the new member | the Space | needs you |
| `role_confirmed` (proof from a Space or a teammate) | the person | Your record | always |
| `follow` | the person followed | Your network | setting |
| `post_reply` (a reply to your post, or to your reply) | the author | Your posts | setting |
| `post_useful` | the author: one row per post per day, updated, not one per mark | Your posts | none |

A declined join request makes **no** notification. The person sees "Declined" on their request card in My Spaces, as now.

**Functions:**
- `my_activity(cursor)`: the last 7 days, grouped as below.
- `mark_activity_read()`: called when Activity opens.
- `unread_activity()`: a yes/no for the dot on the Activity tab, never a number.
- `home_day()`: the H1b header. It returns:
  - the needs-you count;
  - Spaces with something new since your last visit, today;
  - replies to your chat messages today.
  - Each is your own count, which rules §2 allows.

**Home Spaces tab (H1b, replaces My Spaces in Home):**
1. **Header:**
   - "{WEEKDAY} {D} {MONTH} · {CITY}": the date in the pack's format; the city from your profile place.
   - "Your day on site".
   - The summary line: "● 1 thing needs you · 2 Spaces active · 3 replies". Each part is hidden when it's 0, and the dot and first part are orange.
2. **NEEDS YOU:** `needs_you()`, plus join requests for admins.
   - At most 3 cards, with one **Open** button each.
   - "See all" when there are more; it opens Activity.
3. **TODAY IN YOUR SPACES:** at most 5 rows, one per Space with something new since `space_visits.seen_at`.
   - Each row has the Space tile, the Space name, "Project" when it's linked, one line on the most important change, and the time.
   - Most important first: a work item event, then a Library file, then the last chat message.
   - Tap opens the Space on the tab where the change is.
4. **"That's your day · Nothing else needs you right now"** when Needs you is empty.
5. **Empty:** H1e, as now.
6. **The Spaces tab label** gets the orange dot when Needs you isn't empty, hidden while the tab is open.
7. **Top bar:**
   - Search opens Explore people search.
   - No Notebook or Messages icons.
   - The **Create** button that sits on the Home Spaces tab today moves to the S1 header (see 9).
8. **Profile top bar (R1 v3):** add the Spaces icon (users-three). It opens My Spaces (S1).
9. **The Create tab** opens the composer (C1 v2), as in the prototype, instead of today's sheet.
   - Today's sheet (New Space, Enter an invite code) moves to the **Create** button in the S1 header, so a member can still join a second Space.
   - H1e keeps "Enter an invite code".

**Activity (A1 v2):**
1. **NEEDS YOU:** the same items as Home's Needs you, as A1 cards.
   - Each has an overline, a title, one line and one button.
   - Overlines:
     - "WORK ITEM · FOR YOU";
     - "WORK ITEM · YOU CHECK IT";
     - "WORK ITEM · SENT BACK";
     - "SPACE · REQUEST TO JOIN".
   - Buttons: Open, Check, Review request.
2. **CHANGES TO YOUR RECORD · Last 7 days:**
   - **Groups:** one per Space (title: Space name; line: "Space · your pass: Crew"), then "Your record", "Your network", "Your posts".
   - **Each group** has the REV stamp of its latest letter. Letters run A = oldest in the window.
   - **Each row** has:
     - the letter marker: ink-filled when unread, outlined when read;
     - what happened, with one line of context;
     - a status chip (Assigned, Done, Checked, Sent back, Comment, Approved, Confirmed);
     - the time.
   - **Tap** opens the target: the work item, the Space People tab, the profile, or the post.
3. **A2 empty:** "Nothing needs you right now.", then the MVP ledger:
   - WORK ITEMS: "Someone gives you a work item, or one you raised is done."
   - SPACE REQUESTS: "Someone asks to join a Space you run."
   - YOUR POSTS: "Someone replies to your post."
   - YOUR NETWORK: "Someone follows you."
   - WHILE YOU WAIT: only "Add a project you worked on". "Invite someone you worked with" waits for store links in week 10.

## 4. Push notifications (part 3)
**Setup** (the founder does this; never paste keys into chat):
1. The founder creates a free Firebase project "BuildVibes MVP" and adds the Android app `com.buildvibes.buildvibes`.
2. Put `google-services.json` in `android/app/`, and git-ignore it.
3. The Firebase service-account key goes only into Supabase Edge Function secrets. The founder pastes it himself.
4. iPhone push needs the Apple developer account and an APNs key. Build the code now; switch it on in week 10.

**Server:**
- `push_tokens`: `profile_id`, `token`, `platform`, `locale`, `updated_at`. Upserted by `register_push_token`.
- **Who gets a push:** the trigger that writes a notification also queues a push in `push_queue`, after these checks:
  - the per-Space level (`space_members.notify`):
    - `off`: no push from that Space;
    - `needs_you`: only the needs-you kinds;
    - `all`: plus **new chat messages** in threads you can read.
  - your Settings switches (S3).
  - **Chat messages are push only**, never Activity rows.
  - Throttle chat: at most one push per thread per person every 5 minutes. The Android notification is grouped by thread.
- **Sending:** an Edge Function `push`, called by a database webhook on `push_queue`. It sends through FCM HTTP v1 and deletes tokens FCM reports as dead.
  - Deploying it and adding the webhook are live changes: ask the founder first.
- **Text:**
  - The function holds `strings.json` with English and Arabic, chosen by the recipient's `locale`.
  - **Never name a project, a Space or a work item title** (founder decision; the S3 footer says so). Examples:
    - "Sara Al-Mutairi gave you a work item."
    - "Omar Haddad signed a work item as done. You check it."
    - "Rakesh Nair asked to join a Space you run."
    - "New message from Omar Haddad". The text is shown only when "Show message text on lock screen" is on; it's off by default.
  - The ids for the deep link go in the data part only.

**App:**
- **Ask for permission** the first time the person opens Home after onboarding. Android 13+ shows the system prompt; there's no extra screen.
- A tap on a notification opens the target route: the item, the thread, People, the post or the profile.
- **Settings → Notifications (S3), MVP rows only:**
  - PEOPLE: New followers.
  - YOUR POSTS: Replies.
  - MESSAGES: Show message text on lock screen (off by default).
  - SPACES: a line "Set for each Space in Space info → Notifications" that opens My Spaces.
  - The S3 footer note, as drawn.
  - Work item and join request pushes have no switch here. They follow the per-Space level.
- **S4:** when the phone's permission is off, show the banner "Push notifications are off" with **Open phone settings**. Drop "Email alerts still work": the MVP sends no email alerts.

## 5. Arabic (from the AR frames and the glossary)
**From the AR frames:**
- Feed = الأخبار; Spaces = المساحات; Useful = مفيد; Reply = رد.
- Proof line: Arabic verbs change with gender, and profiles have no gender, so use one neutral form for one or two names: "وجده مفيداً: {a}" and "وجده مفيداً: {a} و{b}". (The AR frame's "وجدا" is right only for two names when one is a man.)
- "Beyond {market}" = "خارج {market}".
- "Your day on site" = يومك في الموقع; Needs you = بانتظارك; "Today in your Spaces" = اليوم في مساحاتك.
- "That's your day" = هذا يومك; "Nothing else needs you right now" = لا شيء آخر بانتظارك الآن.
- Open = فتح; Project = مشروع.

**New, in plain words:**
- Post = نشر; New post = منشور جديد; "What happened on site today?" = ماذا حدث في الموقع اليوم؟
- Replies = الردود; "Add a comment" = أضف تعليقاً; "Replying to {name}" = ردّاً على {name}.
- Edited = معدّل; Mute {name} = كتم {name}.
- "Couldn't post. Saved as a draft." = تعذّر النشر. حُفظ كمسودة.
- Activity = النشاط; "Changes to your record" = تغييرات في سجلك; "Last 7 days" = آخر 7 أيام.
- "Nothing needs you right now." = لا شيء بانتظارك الآن.
- "Push notifications are off" = الإشعارات مغلقة; "Open phone settings" = افتح إعدادات الهاتف.
- **Start from:** تحديث سير العمل، إنجاز مرحلة، زيارة موقع، اسأل المجتمع.
  - Their lines: "تم اليوم:"، "التالي:"، "ما يعيقنا:" / "ماذا:"، "متى:"، "من أنجزه:" / "أين:"، "ماذا وجدنا:"، "الإجراءات:" / "السؤال:"، "من يعرف:".

**Formatting:** Western digits everywhere. REV letters and work item refs (KCT-021) stay Latin.

## 6. Founder decisions (open; build around them)
1. **Translate on posts** (rules §5 promises it).
   - It needs a translation service: Google Cloud Translation. The first 500,000 characters a month are free, then $20 per million.
   - The founder would create a Google Cloud project with billing; the key goes only into Supabase.
   - **Lead's recommendation:** yes, in week 8. It's one Edge Function plus a cache, so each post is translated once per language.
   - The post language (L5, L6) is built now either way.
2. **Save and Share on post cards.**
   - The prototype has no Saved list, and posts have no public web page to link to, so both buttons would lead nowhere.
   - **Lead's recommendation:** hide them for the pilot, and add them with a public post page after the pilot.
3. **@mentions.**
   - The MVP plan lists "Mentions" under Activity, but nothing in chat or posts supports @ yet.
   - **Lead's recommendation:** replace it, for the pilot, with replies to your posts, plus chat pushes by each Space's level. Mentions come after the pilot.

## 7. Parts (stop and report after each, with English and Arabic screenshots at 390×844)
1. **Migration 12 (feed), then the screens:**
   - Feed, card, composer, posting, post detail, replies, Useful, mute.
   - Profile → Posts and the project sheet's posts.
   - Send the migration to the lead before any screen work depends on it going live.
2. **Migration 13 (activity), then the screens:**
   - Home Spaces tab (H1b), Activity (A1 v2, A2).
   - The Profile top bar Spaces icon, and the Create tab opening the composer.
3. **Push:**
   - push tokens, the queue, the Edge Function, permission, deep links, S3, S4;
   - ask the founder before deploying the function or adding the webhook.

## 8. Done when
- `flutter analyze` is clean, and all app and SQL tests pass.
- **SQL tests prove:**
  - a blocked person can't read the blocker's posts, replies or photos;
  - you can't edit or delete someone else's post or reply;
  - Useful counts once per person;
  - a muted person's posts leave only the muter's feed;
  - nobody reads another person's notifications or push tokens;
  - a declined request makes no notification;
  - a Space at `off` queues no push;
  - push text never contains a Space, project or item title.
- **Run this on the emulator** with the three test accounts:
  1. Crew posts with 2 photos and a project tag on a weak signal; it arrives once.
  2. The admin marks it Useful and replies; Crew gets the Activity rows.
  3. The admin gives Crew a work item. Crew's Home Spaces tab shows it under Needs you, and the Activity tab has its dot.
  4. Crew signs it done; the admin gets a push (part 3) that names no Space.
  5. The admin sets the Space to Off; no more pushes come from it.
