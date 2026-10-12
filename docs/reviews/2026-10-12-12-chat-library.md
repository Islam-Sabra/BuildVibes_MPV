# Review 12: week 6 brief — Space chat and Library (12 Oct 2026)

Written by the lead while the founder was out. The database part is drafted, tested and independently reviewed on the branch **`chat-library-db`**: migration 9, 66 new SQL checks, 408 in all. **It is not live.**

## 0. Before you start
1. **Check the branch:** check out `chat-library-db` and run `supabase test db` with the real Supabase tools. All 408 checks must pass.
2. **Things my Postgres stand-in can't fully check**, so check them on yours:
   - The `space-files` bucket update: 25 MB, PDF and audio.
   - Whether Supabase Storage fills `metadata.mimetype` and `metadata.size` at upload. `upload_mime` and the quotas rely on them.
   - The Realtime publication line for `messages`.
3. **Then:** merge it into main. **Ask the founder before `supabase db push`.**
4. **Images:** see `docs/design/chat/README.md`. Ask the founder to have the lead export fresh images, because the Figma links expire.
5. **First, apply review 11 A** (the small migration-9-era follow-ups). Note: migration 9 already redefines `loose_uploads`, `orphan_space_files`, `may_upload`, `may_read_file`, `may_delete_file`, `add_evidence` and `delete_team`. Build on its versions, and number the review 11 A migration after it (`20261012150000_…`).

## 1. Scope
**In:**
- Space chat: an Everyone thread and one thread per Team.
- Text, photos, PDF drawings and voice notes.
- Replies, Copy, and Delete (the author or an admin).
- Work item cards in chat.
- Unread counts.
- The Library: files, Team files, revisions, preview.
- Attaching Library files to work items (W2-A and W3 "Attached").
- "Also in the Team chat" on work items.

**Out:**
- Direct messages: hide "Message" in the actions.
- Report message: week 8, with report and block.
- Library Lists, Notes and Events; the S14k checklists (Notebook isn't in the MVP).
- Editing messages: Figma has none.

## 2. How it works (the server enforces all of this; see data-model §6 and §8)
- **Who chats:** every pass can chat. Photos, files and voice notes need the "add files" pass right, so a Viewer chats in text only. Show the attach button only when `can(space,'add_files')`.
- **Team threads:** only the Team's members and the Space admins see them. The thread list (S7k) comes from `space_threads(space)`: Everyone first, then Teams, each with the last message and the unread count.
- **Sending:**
  1. Make the message id in the app.
  2. Upload any files to `<space>/chat/<id>/<uuid>.<ext>`.
  3. Call `post_message`.

  A retry with the same id is safe: it never posts twice. Pass the file's own name as `name` in the attachment JSON, so PDFs reach the Library with a proper title.
- **Weak signal:** as with work items, a message that fails stays in the thread as "Not sent · Retry", with its photo kept on the phone.
- **Live:** subscribe to Realtime on `messages`, filtered by `thread_id`. Call `mark_thread_read` when the thread is open and when you leave it.
- **Work item cards:** the server posts them, so never post them from the app. A card shows the item's ref, status, title and place, using BvWorkItemCard in its compact chat form (S8k). Tapping it opens the item. A Team item's card goes to the Team thread when its owner is in the Team; otherwise to Everyone.
- **"Also in the Team chat":** on the item page (W3), show this line under Discussion when the item has a Team. Item comments stay on the item; they aren't copied into chat.
- **Deleted messages:** show "Message deleted" in grey, with the author and time. Cards can't be deleted.
- **Library (S13k):**
  - Search, plus "All · Files". Hide Lists, Notes and Events.
  - A row shows the name, Team or Everyone, who added it, "From chat" when it came from chat, and the size.
  - "Add" uploads a PDF or photo to `<space>/library/<id>/…`, then calls `add_library_file`. Set the optional Team, revision label and note there.
  - "Upload a new revision" passes `supersedes`. The old one is shown as "superseded, kept in the record".
- **Preview (F1):**
  - A PDF opens in-app (first page and pinch-zoom is enough), with the revision, size, who added it and the note.
  - "Used in" lists the work items using the file.
  - "Share in chat" posts it into a thread you choose.
  - "Download" saves it to the phone.
- **Attach (W2-A, W3):** "From the Space Library" calls `attach_library_file`. A Team file only goes on that Team's items; the server refuses others, so filter the picker.
- **Voice notes:**
  - Hold to record, up to 2 minutes, AAC/M4A.
  - Show the duration, and play inline.
  - Do this last: if time runs short, it is the first thing to cut (MVP plan, risks).

## 3. Arabic
- Everyone = الجميع; Team = الفريق; Library = المكتبة; Chat = المحادثة; Reply = رد; Copy = نسخ; Delete message = حذف الرسالة.
- "Message deleted" = حُذفت الرسالة.
- "Not sent · Retry" = لم تُرسل · إعادة المحاولة.
- "From chat" = من المحادثة.
- "Superseded, kept in the record" = استُبدل، ويبقى في السجل.
- "Used in" = مستخدم في.
- "Share in chat" = شارك في المحادثة.
- "Also in the Team chat" = أيضاً في محادثة الفريق.
- Timestamps use Western digits. File names, references and revision labels (Rev C) stay Latin.

## 4. Parts (stop and report after each, with English and Arabic screenshots at 390×844)
1. **Thread list and a thread:**
   - S7k, S8k, S9k: text, replies, live updates, unread counts, deleted messages.
   - Work item cards.
   - "Not sent · Retry".
2. **Photos and PDFs in chat; Library and preview:**
   - Photos and PDFs in chat.
   - S13k, F1, Add, new revision.
   - Attaching files to items (W2-A, W3 "Attached").
3. **Voice notes, and the message actions sheet (S8b/S8d).**

## 5. Done when
- `flutter analyze` is clean, and all app and SQL tests pass.
- Run this on the emulator with three test accounts (admin, Crew in a Team, Viewer):
  1. Crew posts a photo in the Team thread; the admin sees it live.
  2. The Viewer can't attach.
  3. Crew shares a PDF; it appears in the Library as "From chat".
  4. The admin attaches it to a Team item; the item's card appears in the Team thread.
  5. The admin deletes the chat message, and the PDF is still readable from the item.
