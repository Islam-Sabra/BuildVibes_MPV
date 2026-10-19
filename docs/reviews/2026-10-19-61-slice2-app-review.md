# Review 61: slice 2 in the app — 19 Oct 2026

Branch `slice2-app` (4d064a6). Migration 28 is live with S1 (`d6cd3eb`, trigger `when (new.kind = 'received')`). I checked the screenshots in `docs/screens/slice2/` against K1–K4 v13 in EN and AR.

## What held up
- **The kind menu (E6)** and the four writing cards: drafts, the facts line and the send button at Now.
- **Checklist:** "2 of 5 ticked", with the name and time on each ticked point, struck through.
- **Announcement:** pinned, with Got it, and no faces for anyone except the author.
- **Scheduled activity:** the date block, Add to my calendar, On my way in orange on the day, and the On my way lines for the author only.
- **File:** the preview, NEW VERSION REPLACES REV C, "Received by …" with faces and no number, and Received.
- **Attach (K4):** gallery or file, and a file chooser with the Library underneath. Proof stays camera only.
- **Arabic:**
  - mirrored correctly, with the chevrons pointing left;
  - Almarai at the two sizes;
  - the ledger lines are right ("سارة المطيري · تأشير: …", "عمر حداد · في الطريق", "الاستلام: …").
- **Which actions move a card** follows review 60.

## Accepted differences
- **"· checklist" instead of a ref** on a checklist header: right. Refs belong to work items, and the other kinds already show "· scheduled" and "· file". I'll update K1 to match.
- **Taller checklist rows:** right (48-point tap areas).

## Fix before the phone build
### G1. A pinned announcement must not cover the cards
In K1 EN and AR, the pinned announcement sits over the next card, and the checklist's header (author, kind, time) is hidden under it.
- **Layout:** the list always starts **below** the pinned announcement, so no card is ever hidden under it.
- **After you tap Got it,** the announcement folds to **one slim line** under the masthead: the pin, the first line of the text, and ›. Tapping it opens the full announcement, with Got it shown as given.
- **The author** sees the slim line from the start.
- If the author **edits** the announcement, it opens in full again for everyone, until they tap Got it again.
- When the pin ends, the announcement is an ordinary card on its day.
- **Test:** the first card's header is fully visible below a pinned announcement, in EN and AR, at 390×844.

### G2. A checklist card doesn't repeat its ticks
Each ticked point already shows who ticked it and when, so the "Sara Al-Mutairi · ticked: Ceiling paint touch-up" lines under it say the same thing twice.
- **On a checklist card,** the history shows **un-ticks, edits and the other lines**, but not ticks.
- **"Show earlier" and the post page** show everything, ticks included.
- **On a work item with points,** the same rule applies to its ticks.

### G3. The attach sheet promises what the server takes
"PDF, drawings, documents" → **"PDF, like a drawing"** / **"ملف PDF، مثل مخطط"**. The server takes PDF and photos. That is enough for the pilot, since site teams share drawings and letters as PDF, and other formats can't be previewed on a phone.

### G4. The first real model view (founder, 19 Oct, 18:06)
The founder published "Supply Air" from Navisworks. The Library viewer on his phone shows "Supply Air · V1 · 99 KB · from Islam Ahmed" and V1 · CURRENT, so the publish worked end to end. Two problems:
- **The image area is blank white.** Find out which of these it is:
  - the app doesn't load the image;
  - the stored `view.jpg` really is blank (a Navisworks render with nothing in view).
  Download `view.jpg` and `thumb.jpg` from storage, read-only with the founder's session or the service role, and look at them. If the files are fine, fix the viewer. If they are blank, it's the plugin's capture: report it and don't change the app.
- **"Upload a new revision" shows on a model view.** The server refuses it (review 59, L2), so the button only leads to an error. For `source = model_view`, hide it, and show one small grey line instead: **"New versions come from BuildVibes 360"** / **"الإصدارات الجديدة تأتي من BuildVibes 360"**. The full model view screen (the site tag, the model name, comments, Used in) comes with slice 4.

### Also in this round (review 50)
- **F34:** the owner's name stands out on the facts line, in Medium and the primary colour (Almarai Bold in Arabic). The due time is grey, or the primary colour if it's today, or red if it's late. The same goes for Needs you rows and Activity.
- **F35:** keep the ref as it is.
- **F37:** times follow a change to the 24-hour setting without a restart.
- **F38:** Due today drops an item once it is signed as done, and shows it again if it is sent back.
- **F36** (the weekly fold) waits until I draw the folded line.

## Order
1. Fix G1–G3, F34, F37 and F38 on `slice2-app`, then push and send screenshots of K1, the folded announcement and a card with F34, in EN and AR.
2. Put the build on the founder's phone and the emulator for a short slice 2 test. The build number goes up.
3. After the founder's ok, merge `slice2-app` into `main` and close slice 2.
