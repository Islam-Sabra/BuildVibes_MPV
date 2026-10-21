# Store listing — draft (21 Oct 2026)

For the App Store and Google Play submission (13–19 Dec). For the founder and the lead to approve. Positioning (rules.md): the whole AECO industry, never "site".

Rules kept:
- no numbers as proof (no "10,000 engineers", no ratings, no "most popular"; rule 3);
- no country in the text: the stores choose the countries (rule 5);
- the glossary's words.

## Name and short lines

| Field | Limit | English | Arabic |
|---|---|---|---|
| App name | 30 | BuildVibes | BuildVibes |
| Apple subtitle | 30 | Daily work, checked and proven | العمل اليومي، مُتحقَّق ومُثبَت |
| Google short description | 80 | Your team's daily work, checked and closed, and proof of it on your profile. | عمل فريقك اليومي، يُنجز ويُتحقق منه، وإثباته في ملفك الشخصي. |

The app name stays Latin in Arabic too, as the brand.

## Long description

### English
BuildVibes is where the AECO industry works and shows its work: architects, engineers, BIM staff, contractors, foremen, trades, suppliers and labour.

**Run your team's work in a Space**
- Write a work item in place, give it to someone, and set a date.
- The owner signs it as done with a photo. The person who raised it checks it, or sends it back with a reason.
- Checklists, announcements, scheduled activities and files, in one daybook.
- Chat with the whole Space or one Team. Photos, files and voice notes.
- Passes for each person: Lead, Crew or Viewer. The Space admin lets people in.

**Proof that is yours**
- Work that was checked and closed can go on your profile, if you choose.
- Only the title, a photo, the place and who checked it are shown. The discussion, the files and the Space stay private.

**Made for real work**
- Arabic and English, right to left.
- Keeps working on a weak signal: your post waits, then sends.
- Sign in with a 6-digit code sent to your email. No password.
- Direct messages, a Home feed and project records.
- My notebook and My calendar across all your Spaces.

**Private by design**
- Work stays in its Space.
- The app removes the location from photos before they leave your phone.
- Report and block anyone. Delete your account from Settings.

Free during the pilot.

### Arabic
BuildVibes هو المكان الذي يعمل فيه قطاع العمارة والهندسة والبناء والتشغيل ويُظهر عمله: معماريون، مهندسون، فرق BIM، مقاولون، رؤساء عمال، حِرفيون، موردون وعمال.

**أدِر عمل فريقك في مساحة**
- اكتب بند عمل في مكانه، وكلّف به شخصاً، وحدّد موعداً.
- يوقّع المكلّف كمنجز مع صورة. ويتحقق منه من أنشأه، أو يُرجعه مع السبب.
- قوائم تحقق، إعلانات، أنشطة مجدولة وملفات، في يومية واحدة للفريق.
- محادثة مع المساحة كلها أو مع فريق. صور وملفات ورسائل صوتية.
- تصريح لكل شخص: مسؤول أو فريق تنفيذ أو مُطّلع. ومدير المساحة يقبل من ينضم.

**إثبات يخصك**
- العمل الذي تم التحقق منه وأُغلق يمكن أن يظهر في ملفك، إذا اخترت ذلك.
- يظهر العنوان والصورة والمكان ومن تحقق منه فقط. النقاش والملفات والمساحة تبقى خاصة.

**مصمم للعمل الحقيقي**
- العربية والإنجليزية، من اليمين إلى اليسار.
- يعمل مع الإشارة الضعيفة: ينتظر منشورك ثم يُرسَل.
- الدخول برمز من 6 أرقام يصل إلى بريدك. بلا كلمة مرور.
- رسائل مباشرة، والأخبار، وسجلات المشاريع.
- دفتري وتقويمي عبر كل مساحاتك.

**الخصوصية أولاً**
- العمل يبقى في مساحته.
- يزيل التطبيق الموقع من الصور قبل أن تغادر هاتفك.
- أبلغ عن أي شخص أو احظره. احذف حسابك من الإعدادات.

مجاني خلال المرحلة التجريبية.

**[Founder]** "Free during the pilot" is for the December submission. Remove it, in both languages, before any public launch.

**[Lead]** Check the Arabic against `arabic-glossary.md` and the app's strings before it is final (e.g. the app's words for "daybook", "My notebook" and "My calendar").

## Apple keywords (100 characters, comma separated, no spaces)
- **EN:** `AECO,construction,engineering,BIM,architect,contractor,foreman,work items,checklist,daily report`
- **AR:** `بناء,هندسة,مقاولات,مشاريع,BIM,معماري,مقاول,بند عمل,قائمة تحقق,تقرير يومي,إثبات`

Both are under 100 characters; count again after any edit.

## Category
Apple: Business (secondary: Productivity). Google: Business.

## Data safety (Google) and privacy labels (Apple)
Taken from `docs/legal/privacy-draft-en.md`. Change both together.

| Data | Collected | Linked to the person | Why | Optional |
|---|---|---|---|---|
| Email address | Yes | Yes | Sign-in | No |
| Name, photo, role, company | Yes | Yes | The profile | Photo, company: yes |
| Mobile number | Yes | Yes | Private to the person | Yes |
| Photos | Yes | Yes | Posts, proof, chat | Yes |
| Audio (voice notes) | Yes | Yes | Chat, notebook | Yes |
| Files and documents | Yes | Yes | The Library, chat | Yes |
| Messages in the app | Yes | Yes | Chat and direct messages | Yes |
| Other content (posts, work items) | Yes | Yes | The app's work | Yes |
| Device or other IDs: push token | Yes | Yes | Notifications | Yes (push off) |
| Device or other IDs: Crashlytics install id | Yes | **No** | App function (crash reports) | No |
| Diagnostics: crash logs | Yes | **No** | App function: fix crashes (install id, phone model, system version; no name, no email, no text) | No |
| Location | **No** | — | Removed from photos on the phone | — |
| Contacts, browsing, ads ID, purchases | **No** | — | — | — |

- Shared with third parties: **no**. The service providers that run the app for us don't count as sharing.
- Used for tracking or ads: **no**.
- Encrypted in transit: **yes**.
- The person can delete their data: **yes**, in the app (Settings → Account and security → Delete account). Google also requires a web page that explains how to delete an account (**[Founder]**: a page on the website, D6).

## What the founder still needs to provide
- A support web page and the privacy policy's URL (after the lawyer).
- Screenshots: 6.7" iPhone and an Android phone, in English and Arabic. Re-shoot them on the PC from the screen tests.
- A demo account for the store reviewers, with an email code they can use. **[Lead]** How do reviewers sign in when there's no password? A reviewer test account with a fixed code, on the live project, needs the founder's yes.
