# Arabic strings since week 4

> **18 Oct:** "Checked" is now **تم التحقق** and "Check" **تحقّق** (founder, review 50 F14). Older rows below that still say فحص are superseded; the ARB files are the source of truth.

**For:** Islam, to read the Arabic and mark anything to change.
**How:** write the better Arabic next to a row, or under the table. I'll put each change into `lib/l10n/app_ar.arb`.

750 strings, every one added since week 4 (Spaces onwards), in the order the app shows them by area.
Words in `{curly brackets}` are filled in by the app (a name, a date, a number).
A line like `{n, plural, =1{…} other{…}}` holds the forms for different numbers, and `{kind, select, …}` the forms for different things.

**Already checked by script:**
- every English string has an Arabic one;
- digits are Western (0–9);
- the glossary words are used (CLAUDE.md);
- a third person is named with a noun or the passive, never a masculine or feminine verb (review 20).
- Fixes in this pass:
  - «دعوة من {name}» instead of «دعاك {name}»: the inviter is not given a masculine verb;
  - "assigned" and "reassigned" now say تكليف everywhere, matching المكلّف: «تكليف لك بـ{ref} من {name}», the chip «تكليف», «أُعيد تكليف» and «يلزم تكليف شخص آخر»;
  - "Needs you" in the Space notifications help now uses بانتظارك.
- Review 29 (the lead’s language review of this file) is applied: meanings, no gendered verbs about another person, one word for one meaning («مؤكَّد من», «مخطط», «إصدار», «قبل …»), the plural forms for 11 and up, and one tanween spelling («يومًا»).

## Spaces, passes and Teams

| English | Arabic |
|---|---|
| PROJECT SPACES | مساحات المشاريع |
| {count} needs you | {count} بانتظارك |
| Private work | عمل خاص |
| Private work · project Space | عمل خاص · مساحة مشروع |
| Join your first Space | انضم إلى أول مساحة لك |
| A Space is where a project team runs its daily work. Once you join one, your daily report appears here: replies, site updates and anything waiting for you. | المساحة هي المكان الذي يدير فيه فريق المشروع عمله اليومي. عندما تنضم إلى مساحة، يظهر تقريرك اليومي هنا: الردود وتحديثات الموقع وكل ما ينتظرك. |
| Your feed still shows posts, announcements and celebrations from your network. | ستجد في الأخبار منشورات شبكتك وإعلاناتها وتهانيها. |
| Enter an invite code | أدخل رمز الدعوة |
| 6 letters and numbers, from the person who invited you | 6 أحرف وأرقام من الشخص الذي دعاك |
| Invited by {name} | دعوة من {name} |
| Ask to join | اطلب الانضمام |
| This code isn't valid. Check it with the person who sent it. | هذا الرمز غير صالح. تأكد منه مع من أرسله إليك. |
| Too many tries. Try again in an hour. | محاولات كثيرة. حاول مرة أخرى بعد ساعة. |
| You're already in this Space. | أنت عضو في هذه المساحة بالفعل. |
| You can ask again tomorrow. | يمكنك الطلب مرة أخرى غدًا. |
| Request sent. The Space admin will confirm you. | تم إرسال طلبك. سيؤكد مدير المساحة انضمامك. |
| You already asked. Waiting for the Space admin. | طلبت الانضمام من قبل. بانتظار مدير المساحة. |
| Waiting for the Space admin to confirm you | بانتظار تأكيد مدير المساحة |
| Cancel request | إلغاء الطلب |
| Not confirmed | لم يتم التأكيد |
| Dismiss | إخفاء |
| New Space | مساحة جديدة |
| HOW IT WILL APPEAR TO MEMBERS | كيف ستظهر للأعضاء |
| Name | الاسم |
| e.g. Tower B — Site team | مثال: البرج B — فريق الموقع |
| Write a name with at least 2 letters. | اكتب اسمًا من حرفين على الأقل. |
| About (optional) | نبذة (اختياري) |
| Shown to people you invite. | تظهر لمن تدعوهم. |
| Link to a project (optional) | ربط بمشروع (اختياري) |
| Choose a project | اختر مشروعًا |
| Linking a project makes this its project Space. Members you confirm get that project confirmed on their profile. | ربط مشروع يجعل هذه مساحة المشروع، ويظهر المشروع مؤكَّدًا في ملف كل عضو تؤكّده. |
| Create Space | إنشاء المساحة |
| Link a project | ربط بمشروع |
| Search your projects | ابحث في مشاريعك |
| Your role: {role} | دورك: {role} |
| Work | العمل |
| Chat | المحادثة |
| People | الأشخاص |
| Library | المكتبة |
| Invite people | دعوة أشخاص |
| Invite to {space} | دعوة إلى {space} |
| Invite code | رمز الدعوة |
| Works until {date} | صالح حتى {date} |
| Share code | شارك الرمز |
| New code | رمز جديد |
| Make a new code? | إنشاء رمز جديد؟ |
| The old code stops working. | يتوقف الرمز القديم عن العمل. |
| Send the code on WhatsApp or read it out on site. The Space admin confirms each person before they join. | أرسل الرمز عبر واتساب أو اقرأه في الموقع. يؤكد مدير المساحة كل شخص قبل انضمامه. |
| Join {space} on BuildVibes. Invite code: {code} | انضم إلى {space} على BuildVibes. رمز الدعوة: {code} |
| This Space isn't available. | هذه المساحة غير متاحة. |
| You can't do that in this Space. | لا يمكنك القيام بذلك في هذه المساحة. |
| You made many Spaces today. Try again tomorrow. | أنشأت مساحات كثيرة اليوم. حاول مرة أخرى غدًا. |
| INVITE CODE | رمز الدعوة |
| Search members | ابحث في الأعضاء |
| REQUESTS TO JOIN · YOU CONFIRM | طلبات الانضمام · أنت تؤكدها |
| Asked {when} | قُدّم الطلب {when} |
| invite code shared by {name} | رمز دعوة من {name} |
| invite code | رمز دعوة |
| Decline | رفض |
| Confirm | تأكيد |
| Owners | مديرو المساحة |
| Owner | مدير المساحة |
| Members | الأعضاء |
| You | أنت |
| No one matches. | لا يوجد من يطابق البحث. |
| Lead | مسؤول |
| Crew | فريق تنفيذ |
| Viewer | مُطّلع |
| {pass} pass | تصريح {pass} |
| GIVE A PASS FOR THIS SPACE | امنح تصريحًا لهذه المساحة |
| Opens: create items · check and close · files · invite | يتيح: إنشاء البنود · التحقق والإغلاق · الملفات · الدعوة |
| Engineers, supervisors | المهندسون والمشرفون |
| Opens: chat · mark own items done with a photo · files | يتيح: المحادثة · توقيع البنود المكلّف بها كمنجزة بصورة · الملفات |
| Foremen, technicians, subcontractors | رؤساء العمال والفنيون ومقاولو الباطن |
| Opens: read and chat only | يتيح: القراءة والمحادثة فقط |
| Client, supplier | العميل والمورّد |
| Confirm as {pass} | تأكيد بتصريح {pass} |
| {name} joined as {pass}. The Space is open to them now. | تم تأكيد انضمام {name} بتصريح {pass}. أصبحت المساحة متاحة الآن. |
| {name}'s request declined. They aren't told why. | تم رفض طلب {name} دون ذكر السبب. |
| Undo | تراجع |
| This request was already answered. | تمت الإجابة على هذا الطلب بالفعل. |
| Member | العضو |
| THIS PASS OPENS | ما يتيحه هذا التصريح |
| {pass} · CUSTOM | {pass} · مخصّص |
| Confirmed by {name} | مؤكَّد من {name} |
| Confirmed by you | مؤكَّد منك |
| Chat in Everyone and their Teams | المحادثة في «الجميع» والفِرق |
| Mark own items done | توقيع البنود المكلّف بها كمنجزة |
| Add files to the Library | إضافة ملفات إلى المكتبة |
| Create work items | إنشاء بنود عمل |
| Check and close items | التحقق من البنود وإغلاقها |
| Invite people | دعوة أشخاص |
| Always | دائمًا |
| Open | فتح |
| Lock | قفل |
| CHANGE PASS | تغيير التصريح |
| TEAMS | الفِرق |
| Make admin | تعيين كمدير |
| Admins confirm people, give passes and manage the Space. | يؤكد المديرون الأشخاص ويمنحون التصاريح ويديرون المساحة. |
| Remove from Space | إزالة من المساحة |
| Remove {name}? | إزالة {name}؟ |
| Their closed work items stay in the record. | تبقى بنود العمل المغلقة في السجل. |
| {right}: open for {name}. The pass shows as Custom. | فُتحت صلاحية «{right}» لـ{name}. يظهر التصريح كمخصّص. |
| {right}: locked for {name}. | أُقفلت صلاحية «{right}» لـ{name}. |
| {name} now has a {pass} pass. | تصريح {name} الآن: {pass}. |
| {name} is now a Space admin. | {name} الآن من مديري المساحة. |
| {name} is no longer a Space admin. | تمت إزالة {name} من مديري المساحة. |
| Teams saved. | تم حفظ الفِرق. |
| A Space needs an admin. Make someone else an admin first. | تحتاج المساحة إلى مدير. اجعل شخصًا آخر مديرًا أولًا. |
| {name} was removed from the Space. | تمت إزالة {name} من المساحة. |
| Admins have every right in the Space. | لدى المديرين كل الصلاحيات في المساحة. |
| Space info | معلومات المساحة |
| Access | الوصول |
| Private work · linked to {project} | عمل خاص · مرتبط بـ{project} |
| Share the invite code | شارك رمز الدعوة |
| Owners: {names} | مديرو المساحة: {names} |
| Who can invite | من يمكنه الدعوة |
| Every invite still needs a Space admin to confirm the join. | كل انضمام يحتاج إلى تأكيد مدير المساحة. |
| Space admins | مديرو المساحة |
| Only admins share the invite code. | المديرون فقط يشاركون رمز الدعوة. |
| Admins and Leads | المديرون وأصحاب تصريح مسؤول |
| People with a Lead pass can invite their own crews. | يمكن لأصحاب تصريح مسؤول دعوة طواقمهم. |
| Everyone in the Space | كل من في المساحة |
| Anyone can share the code. Admins still confirm each join. | يمكن لأي عضو مشاركة الرمز، ويؤكد المديرون كل انضمام. |
| Notifications | الإشعارات |
| For this Space only. | لهذه المساحة فقط. |
| Everyone posts and my Teams | «الجميع» وفِرقي |
| Messages in Everyone and in your Teams, plus anything that needs you. | رسائل «الجميع» وفِرقك، وكل ما هو بانتظارك. |
| Needs you only | بانتظارك فقط |
| Items you own, items to check and people asking to join. | البنود المكلّف بها، والبنود التي تحتاج تحققًا، وطلبات الانضمام. |
| Off | إيقاف |
| No alerts. Needs you still shows on your Home. | لا تنبيهات. يبقى «بانتظارك» ظاهرًا في الرئيسية. |
| Transfer ownership | نقل إدارة المساحة |
| Delete Space | حذف المساحة |
| Owners only. Removes it for everyone. | للمديرين فقط. تُحذف لدى الجميع. |
| Delete | حذف |
| {space} was deleted. | تم حذف {space}. |
| Leave Space | مغادرة المساحة |
| Leave {space}? | مغادرة {space}؟ |
| Leave | مغادرة |
| You left {space}. | غادرت {space}. |
| Edit | تعديل |
| Edit Space | تعديل المساحة |
| Choose a member to become a Space admin. You will stay in the Space as a member. | اختر عضوًا لتنتقل إليه إدارة المساحة. ستبقى في المساحة كعضو. |
| Transfer to {name} | نقل إلى {name} |
| Transfer to {name}? | نقل الإدارة إلى {name}؟ |
| {name} becomes an admin of {space} and you become a member. | تنتقل إدارة {space} إلى {name} وتصبح أنت عضوًا. |
| Transfer | نقل |
| {name} is now a Space admin. You're a member. | {name} الآن من مديري المساحة، وأنت عضو. |
| Confirm someone into the Space first. | أكّد انضمام شخص إلى المساحة أولًا. |
| Teams | الفِرق |
| {n, plural, =0{No members yet} =1{1 member} other{{n} members}} | {n, plural, =0{لا أعضاء بعد} =1{عضو واحد} =2{عضوان} few{{n} أعضاء} many{{n} عضوًا} other{{n} عضو}} |
| you're in it | أنت فيه |
| New Team | فريق جديد |
| Team name | اسم الفريق |
| e.g. MEP Team | مثال: فريق MEP |
| Everyone in the Space can see Team names and members. Only members see its chat. | يرى كل من في المساحة أسماء الفِرق وأعضاءها. المحادثة لأعضاء الفريق فقط. |
| Add members | إضافة أعضاء |
| {n, plural, =0{Create Team} =1{Create Team · 1 person} other{Create Team · {n} people}} | {n, plural, =0{إنشاء الفريق} =1{إنشاء الفريق · شخص واحد} =2{إنشاء الفريق · شخصان} few{إنشاء الفريق · {n} أشخاص} other{إنشاء الفريق · {n} شخصًا}} |
| Write a Team name. | اكتب اسم الفريق. |
| There's already a Team with this name. | يوجد فريق بهذا الاسم بالفعل. |
| A Team in {space}. Posts and threads for this Team are seen only by its members. | فريق في {space}. منشورات الفريق ومحادثاته لأعضائه فقط. |
| Add people | إضافة أشخاص |
| People in this Team | أعضاء الفريق |
| Rename Team | إعادة تسمية الفريق |
| Delete Team | حذف الفريق |
| Delete {team}? | حذف {team}؟ |
| Its members stay in the Space. | يبقى أعضاؤه في المساحة. |
| No one in this Team yet. | لا أحد في هذا الفريق بعد. |
| Delete {space}? | حذف {space}؟ |
| It's removed for everyone. | ستُحذف لدى الجميع. |
| You will stop seeing its chats and work. To come back, you need a new invite. | لن ترى محادثاتها وأعمالها بعد الآن. للعودة تحتاج إلى دعوة جديدة. |
| Make someone else an admin first, or delete the Space. | اجعل شخصًا آخر مديرًا أولًا، أو احذف المساحة. |
| {name} gave you a work item: {title} | بند عمل لك من {name}: {title} |
| A work item for you: {title} | بند عمل لك: {title} |
| {name} signed a work item as done: {title} | منجز بتوقيع {name}، بانتظار تحقّقك: {title} |
| Signed as done. You check it: {title} | منجز، بانتظار تحقّقك: {title} |
| {name} sent a work item back: {title} | أُرجع إليك بند عمل من {name}: {title} |
| A work item came back to you: {title} | أُرجع إليك بند عمل: {title} |
| The owner left. Reassign it: {title} | لم يعد المكلّف في المساحة. يلزم تكليف شخص آخر: {title} |
| {name} asked to join {space} | طلب انضمام من {name} إلى {space} |
| due {date} | الاستحقاق {date} |
| WORK ITEM · FOR YOU | بند عمل · لك |
| WORK ITEM · YOU CHECK IT | بند عمل · بانتظار تحقّقك |
| WORK ITEM · SENT BACK | بند عمل · مُرجَع |
| WORK ITEM · OWNER LEFT | بند عمل · بلا مكلّف |
| SPACE · REQUEST TO JOIN | مساحة · طلب انضمام |
| Open | فتح |
| Check | تحقّق |
| Review request | راجع الطلب |

## Work items

| English | Arabic |
|---|---|
| Members are people the Space admin confirmed. Nothing here is visible outside the Space. | الأعضاء أشخاص أكّدهم مدير المساحة. لا يظهر شيء هنا خارج المساحة. |
| All | الكل |
| Mine | الخاصة بي |
| Open | مفتوحة |
| To check | للتحقق |
| Checked | تم التحقق |
| NEEDS YOU | بانتظارك |
| OPEN | مفتوحة |
| WAITING FOR A CHECK | بانتظار التحقق |
| CHECKED THIS WEEK | تم التحقق منها هذا الأسبوع |
| CHECKED EARLIER | تم التحقق منها سابقًا |
| OPEN | مفتوح |
| OPEN · DUE {date} | مفتوح · الاستحقاق {date} |
| OPEN · WAS DUE {date} | مفتوح · كان مستحقًا {date} |
| DONE · YOU CHECK IT | منجز · تتحقّق منه أنت |
| DONE · WAITING FOR A CHECK | منجز · بانتظار التحقق |
| CHECKED · {date} | تم التحقق · {date} |
| Owner: you | المكلّف: أنت |
| Owner: {name} | المكلّف: {name} |
| from you | منك |
| from {name} | من {name} |
| checked by {name} | التحقق: {name} |
| Checked by {name} | التحقق: {name} |
| {n, plural, =0{No photo} =1{1 photo} other{{n} photos}} | {n, plural, =0{بلا صورة} =1{صورة واحدة} =2{صورتان} few{{n} صور} many{{n} صورة} other{{n} صورة}} |
| Sign as done | وقّع كمنجز |
| Check it | تحقّق منه |
| New item | بند جديد |
| No work items yet | لا بنود عمل بعد |
| Raise the first one with New item. The owner signs it as done, then it's checked. | أنشئ أول بند من «بند جديد». يوقّعه المكلّف كمنجز، ثم يُفحص. |
| Items appear here when someone raises one for the team. | تظهر البنود هنا عند إنشاء بند للفريق. |
| Nothing needs you right now. | لا شيء بانتظارك الآن. |
| Nothing here. | لا شيء هنا. |
| OWNER LEFT · REASSIGN | بلا مكلّف · أعد التكليف |
| Reassign | أعد التكليف |
| New work item | بند عمل جديد |
| Take a photo | التقط صورة |
| Choose from gallery | اختر من المعرض |
| Retake | إعادة التصوير |
| Start with a photo of the spot. | ابدأ بصورة للمكان. |
| NEW · {ref} | جديد · {ref} |
| NEW | جديد |
| What needs doing · one line is enough | ما المطلوب · سطر واحد يكفي |
| Write what needs doing. | اكتب ما المطلوب. |
| OWNER · ONE PERSON | المكلّف · شخص واحد |
| DUE | الاستحقاق |
| PLACE ON SITE | المكان في الموقع |
| TEAM | الفريق |
| Choose | اختر |
| Choose who does it. | اختر من سينفّذه. |
| No due date | بلا موعد |
| Today | اليوم |
| Tomorrow | غدًا |
| Pick a date | اختر تاريخًا |
| No Team | بلا فريق |
| e.g. Level 2 · Grid C7 | مثال: الدور 2 · المحور C7 |
| {owner} gets it in Needs you. When it's marked done, you check it. | يصل إلى {owner} في «بانتظارك». وعند توقيعه كمنجز تتحقّق منه أنت. |
| The owner gets it in Needs you. When it's marked done, you check it. | يصل إلى المكلّف في «بانتظارك». وعند توقيعه كمنجز تتحقّق منه أنت. |
| Create item | إنشاء البند |
| Not sent yet | لم يُرسل بعد |
| Retry | إعادة المحاولة |
| Saved on this phone. Retry when the signal is back. | محفوظ على هذا الهاتف. أعد المحاولة عند عودة الإشارة. |
| Sent. | تم الإرسال. |
| SIGN-OFF | التوقيعات |
| EVIDENCE | الإثبات |
| PHOTOS | الصور |
| DISCUSSION | النقاش |
| Add a comment | أضف تعليقًا |
| Send | إرسال |
| No comments yet. | لا تعليقات بعد. |
| Waiting for {name} to check | بانتظار فحص {name} |
| It can be accepted or sent back with a reason. | يمكن قبوله أو إرجاعه مع ذكر السبب. |
| {name} marked this done. Check it. | تم توقيعه كمنجز بواسطة {name}. افحصه. |
| Look at the photo, then accept it or send it back with a reason. | انظر إلى الصورة، ثم اقبله أو أرجعه مع ذكر السبب. |
| Done. Waiting for a check. | منجز. بانتظار التحقق. |
| Closed. It stays in the Space record. | أُغلق. يبقى في سجل المساحة. |
| {name} can show it on their profile as work they delivered. | يمكن عرضه في ملف {name} كعمل منجز. |
| Closed by {name} | الإغلاق: {name} |
| It stays in the Space record. | يبقى في سجل المساحة. |
| Sent back: {reason} | أُرجع: {reason} |
| Photo missing | الصورة غير موجودة |
| Not as per drawing | غير مطابق للمخطط |
| Not finished | غير مكتمل |
| Other | سبب آخر |
| The owner left the Space | المكلّف خارج المساحة الآن |
| Give it to someone else to finish. | كلّف شخصًا آخر بإكماله. |
| CHECKED · {date} · {name} | تم التحقق · {date} · {name} |
| You check it | تتحقّق منه أنت |
| Check and close | افحص وأغلق |
| Send back | إرجاع |
| Reassign to | إعادة التكليف إلى |
| {name} owns it now. | المكلّف الآن: {name}. |
| This item isn't available. | هذا البند غير متاح. |
| Today {time} | اليوم {time} |
| Sign DONE on {ref} | وقّع {ref} كمنجز |
| Your name and the time go on the sign-off. Add a photo or a note so {name} can check it. | يُكتب اسمك والوقت في التوقيع. أضف صورة أو ملاحظة تساعد {name} في الفحص. |
| Add photo | أضف صورة |
| Note | ملاحظة |
| What was done | ما الذي أُنجز |
| Add a photo or a note. | أضف صورة أو ملاحظة. |
| Signed as done. It's waiting for a check. | تم التوقيع كمنجز. بانتظار التحقق. |
| Sign-off not sent yet | التوقيع لم يُرسل بعد |
| Send {ref} back to {name} | إرجاع {ref} إلى {name} |
| The tag goes back to Open with your reason written on it, and into {name}'s Needs you. | يعود البند مفتوحًا مع سببك مكتوبًا عليه، ويصل إلى «بانتظارك» لدى {name}. |
| Reason | السبب |
| Note for {name} | ملاحظة إلى {name} |
| Send back to {name} | إرجاع إلى {name} |
| Choose a reason. | اختر سببًا. |
| Say what is wrong. | اذكر ما الخطأ. |
| Sent back to {name}. | تم الإرجاع إلى {name}. |
| Check and close {ref}? | فحص {ref} وإغلاقه؟ |
| Your name and the time go on the sign-off. It closes and stays in the Space record. | يُكتب اسمك والوقت في التوقيع. يُغلق ويبقى في سجل المساحة. |
| Show on my profile | اعرضه في ملفي |
| Only the title, one photo, the place and who checked it. Never the Space or the discussion. | العنوان وصورة واحدة والمكان ومن فحصه فقط. لا تظهر المساحة ولا النقاش. |
| Reassigned from {from} to {to} | أُعيد التكليف من {from} إلى {to} |
| someone | شخص ما |
| Work you delivered | عمل أنجزته |
| Only work items that were checked and closed in a Space. Everything is hidden until you switch it on. Shown items appear on your profile. | بنود العمل التي فُحصت وأُغلقت في مساحة فقط. كل شيء مخفي حتى تُظهره. تظهر البنود المعروضة في ملفك. |
| SHOWN ON PROFILE | معروض في الملف |
| Hidden · tap to show | مخفي · اضغط للعرض |
| Checked by {name} · {date} | التحقق: {name} · {date} |
| People see who checked each item. Items from a Space you left stay yours to show or hide. | يرى الناس من فحص كل بند. تبقى بنود المساحة التي غادرتها لك لتعرضها أو تخفيها. |
| Nothing yet. Work items you own appear here once they're checked. | لا شيء بعد. تظهر هنا بنودك بعد فحصها. |
| See all | عرض الكل |
| Delivered work | عمل منجز |
| Shown by {name} | من ملف {name} |
| Project | المشروع |
| Place | المكان |
| Checked by | الفحص |
| {name} chose to show this. The discussion, files and the Space stay private. Only the title, photo, place and who checked it are shown. | عُرض هذا باختيار {name}. يبقى النقاش والملفات والمساحة خاصة. يظهر العنوان والصورة والمكان ومن فحصه فقط. |
| CHECKED · {date} | تم التحقق · {date} |
| Close it | أغلقه |
| Nothing shown yet. Tap See all to choose what shows. | لا شيء معروض بعد. اضغط «عرض الكل» لتختار ما يظهر. |
| Checked · {date} | تم التحقق · {date} |
| Checked | تم التحقق |
| Attach to {ref} | إرفاق بـ{ref} |
| From the Space Library | من مكتبة المساحة |
| Drawings and files already shared in this Space | مخططات وملفات تمت مشاركتها في هذه المساحة |
| From your phone | من هاتفك |
| PDF or image · saved to the Space Library too | PDF أو صورة · تُحفظ في مكتبة المساحة أيضًا |
| Take another photo | التقط صورة أخرى |
| Adds to the photos on the tag | تُضاف إلى صور البند |
| ATTACHED | مرفقات |
| From the Space Library | من مكتبة المساحة |
| Attach a drawing or file | إرفاق مخطط أو ملف |
| Attached. | تم الإرفاق. |
| ALSO IN THE TEAM CHAT | أيضًا في محادثة الفريق |

## Chat and Library

| English | Arabic |
|---|---|
| Everyone | الجميع |
| Team | الفريق |
| You see threads for Everyone and your Teams. | ترى محادثة «الجميع» ومحادثات فِرقك. |
| As a Space admin, you see Everyone and every Team. | بصفتك مدير المساحة، ترى «الجميع» وكل الفِرق. |
| No messages yet. | لا رسائل بعد. |
| You | أنت |
| {name}: {text} | {name}: {text} |
| Photo | صورة |
| File | ملف |
| Voice note | رسالة صوتية |
| Work item update | تحديث بند عمل |
| Today | اليوم |
| Yesterday | أمس |
| Only {team} and the Space admins see this thread. | لا يرى هذه المحادثة إلا {team} ومديرو المساحة. |
| Message | رسالة |
| Send | إرسال |
| Message deleted | حُذفت الرسالة |
| Sending… | جارٍ الإرسال… |
| Not sent | لم تُرسل |
| Retry | إعادة المحاولة |
| Reply | رد |
| Copy | نسخ |
| Copied. | تم النسخ. |
| Delete message | حذف الرسالة |
| Delete this message? | حذف هذه الرسالة؟ |
| Everyone in this thread sees “Message deleted” instead. | سيرى الجميع في هذه المحادثة «حُذفت الرسالة» بدلًا منها. |
| Delete | حذف |
| Replying to {name} | ردًّا على {name} |
| Cancel reply | إلغاء الرد |
| {name} raised a work item | بند عمل جديد من {name} |
| {name} marked a work item done | توقيع كمنجز من {name} |
| {name} checked and closed a work item | فحص وإغلاق من {name} |
| {name} sent a work item back | إرجاع بند عمل من {name} |
| {name} reassigned a work item | إعادة تكليف بند عمل من {name} |
| This work item is no longer in the Space. | لم يعد بند العمل هذا في المساحة. |
| {name} raised {ref} | بند عمل جديد {ref} من {name} |
| {name} marked {ref} done | توقيع {ref} كمنجز من {name} |
| {name} checked and closed {ref} | فحص وإغلاق {ref} من {name} |
| {name} sent {ref} back | إرجاع {ref} من {name} |
| {name} reassigned {ref} | إعادة تكليف {ref} من {name} |
| Add a photo or file | إضافة صورة أو ملف |
| Take a photo | التقط صورة |
| Photo from your phone | صورة من هاتفك |
| PDF from your phone | ملف PDF من هاتفك |
| It goes to the Space Library too. | يُضاف إلى مكتبة المساحة أيضًا. |
| Remove | إزالة |
| Only PDF files and photos. | ملفات PDF والصور فقط. |
| Files up to 25 MB. | حتى 25 ميغابايت للملف. |
| One PDF per message. | ملف PDF واحد في كل رسالة. |
| {size} MB | {size} ميغابايت |
| {size} KB | {size} كيلوبايت |
| Search titles and file names | ابحث في العناوين وأسماء الملفات |
| All | الكل |
| Files | الملفات |
| Recent in this Space | الأحدث في هذه المساحة |
| From chat | من المحادثة |
| No files yet. Drawings and photos shared in this Space appear here. | لا ملفات بعد. تظهر هنا المخططات والصور التي تمت مشاركتها في هذه المساحة. |
| Nothing matches. | لا نتائج. |
| Add file | إضافة ملف |
| Add to the Library | إضافة إلى المكتبة |
| New revision | إصدار جديد |
| Replaces {name}. The old one is kept in the record. | يحل محل {name}. تبقى النسخة القديمة في السجل. |
| Choose a PDF or photo | اختر ملف PDF أو صورة |
| Choose another file | اختر ملفًا آخر |
| Title | العنوان |
| Who sees it | من يراه |
| Only {team} and the Space admins see it. | لا يراه إلا {team} ومديرو المساحة. |
| Revision | الإصدار |
| For example Rev C | مثلًا Rev C |
| What changed | ما الذي تغيّر |
| Upload | رفع |
| Added to the Library. | أُضيف إلى المكتبة. |
| Choose a file first. | اختر ملفًا أولًا. |
| Give it a title. | أضف عنوانًا. |
| from {name} | من {name} |
| {rev} · CURRENT | {rev} · الحالي |
| CURRENT | الحالي |
| Uploaded {date} | رُفع في {date} |
| Used in | مستخدم في |
| superseded, kept in the record | استُبدل، ويبقى في السجل |
| A newer revision replaced this one. | حلّ محله إصدار أحدث. |
| Open the current one | افتح الإصدار الحالي |
| Share in chat | شارك في المحادثة |
| Download | تنزيل |
| Upload a new revision | رفع إصدار جديد |
| Share in which thread? | المشاركة في أي محادثة؟ |
| A Team file is shared in its Team's thread only. | يُشارك ملف الفريق في محادثة فريقه فقط. |
| Shared in {thread}. | تمت المشاركة في {thread}. |
| Saved. | تم الحفظ. |
| This file can't be shown here. Download it to open it. | لا يمكن عرض هذا الملف هنا. نزّله لفتحه. |
| Close | إغلاق |
| Share the file | مشاركة الملف |
| Choose from the Library | اختر من المكتبة |
| Only files for Everyone and for {team} can go on this item. | يمكن إرفاق ملفات «الجميع» وملفات {team} فقط بهذا البند. |
| File removed | تمت إزالة الملف |
| Hold to record a voice note | اضغط مطولًا لتسجيل رسالة صوتية |
| Slide away to cancel | اسحب بعيدًا للإلغاء |
| Release to cancel | ارفع إصبعك للإلغاء |
| Allow the microphone in your phone's settings to record. | اسمح باستخدام الميكروفون من إعدادات هاتفك للتسجيل. |
| Hold a little longer to record. | اضغط مدة أطول قليلًا للتسجيل. |
| Play | تشغيل |
| Pause | إيقاف مؤقت |
| Report message | الإبلاغ عن الرسالة |

## Home feed and posts

| English | Arabic |
|---|---|
| Feed | الأخبار |
| Spaces | المساحات |
| Beyond {market} | خارج {market} |
| No posts yet. Share what happened on site today. | لا منشورات بعد. شارك ما حدث في الموقع اليوم. |
| Couldn't load your Feed | تعذّر تحميل الأخبار |
| Check your connection and try again. Nothing was lost. | تحقّق من الاتصال وحاول مرة أخرى. لم يُفقد شيء. |
| You're offline. Showing what you already loaded. | أنت غير متصل. نعرض ما حمّلته من قبل. |
| New post | منشور جديد |
| Useful | مفيد |
| Reply | رد |
| {a} found this useful | مفيد لـ{a} |
| {a} and {b} found this useful | مفيد لـ{a} و{b} |
| Edited | معدّل |
| Post options | خيارات المنشور |
| Mute {name} | كتم {name} |
| Muted {name} | تم كتم {name} |
| Undo | تراجع |
| Edit post | تعديل المنشور |
| Delete post | حذف المنشور |
| Delete this post? | حذف هذا المنشور؟ |
| It's removed from the Feed, your profile and the project's page. | سيُحذف من الأخبار وملفك وصفحة المشروع. |
| Post deleted. | حُذف المنشور. |
| Open photo | فتح الصورة |
| Post | منشور |
| Replies | الردود |
| No replies yet. | لا ردود بعد. |
| Add a comment | أضف تعليقًا |
| Write a reply | اكتب ردًا |
| Replying to {name} | ردًّا على {name} |
| Cancel reply | إلغاء الرد |
| Send | إرسال |
| Comment options | خيارات التعليق |
| Delete comment | حذف التعليق |
| Delete comment? | حذف التعليق؟ |
| It will be removed from this post for everyone. | سيُحذف من هذا المنشور لدى الجميع. |
| This post isn't available | هذا المنشور غير متاح |
| It may have been deleted, or you may not have access to it. | ربما حُذف، أو ليس لديك صلاحية الوصول إليه. |
| Back to Home | العودة إلى الرئيسية |
| Posting to your network… | جارٍ النشر لشبكتك… |
| Couldn't post. Saved as a draft. | تعذّر النشر. حُفظ كمسودة. |
| Check your connection and try again. | تحقق من اتصالك وحاول مرة أخرى. |
| Discard draft | حذف المسودة |
| POSTING TO | النشر إلى |
| Your network | شبكتك |
| Everyone | الجميع |
| tagged {project} | مرتبط بـ{project} |
| What happened on site today? | ماذا حدث في الموقع اليوم؟ |
| START FROM | ابدأ من |
| Media | الوسائط |
| Project | المشروع |
| Post | نشر |
| Save | حفظ |
| Choose how to start, or just write | اختر طريقة البدء، أو اكتب مباشرة |
| Posting to {project} | النشر إلى {project} |
| Everyone on BuildVibes can see this. | يمكن لأي شخص على BuildVibes رؤية هذا. |
| Everyone on BuildVibes can see this. It also shows on the project's page. | يمكن لأي شخص على BuildVibes رؤية هذا. ويظهر أيضًا في صفحة المشروع. |
| Written in {lang, select, ar{Arabic} other{English}} | مكتوب {lang, select, ar{بالعربية} other{بالإنجليزية}} |
| Change | تغيير |
| English | English |
| العربية | العربية |
| Detected automatically | يُحدَّد تلقائيًا |
| Language of this post | لغة هذا المنشور |
| We use this to offer Translate to readers who don't read it. | نستخدمها لنعرض الترجمة على القرّاء الذين لا يقرؤون هذه اللغة. |
| {lang, select, ar{Arabic} other{English}} | {lang, select, ar{العربية} other{الإنجليزية}} |
| Up to 4 photos. | حتى 4 صور. |
| Remove photo | إزالة الصورة |
| Post to | النشر إلى |
| WHO SEES IT | من يراه |
| Followers and Explore · anyone can see | المتابعون والاستكشاف · يمكن لأي شخص الرؤية |
| Posts are public and can be tagged to a project. Work for your team goes in the project's Space as a work item. | المنشورات عامة ويمكن ربطها بمشروع. عمل فريقك يذهب إلى مساحة المشروع كبند عمل. |
| Your day on site | يومك في الموقع |
| {n, plural, =1{1 thing needs you} other{{n} things need you}} | {n, plural, =1{شيء واحد بانتظارك} =2{شيئان بانتظارك} few{{n} أشياء بانتظارك} other{{n} شيئًا بانتظارك}} |
| {n, plural, =1{1 Space active} other{{n} Spaces active}} | {n, plural, =1{مساحة واحدة نشطة} =2{مساحتان نشطتان} few{{n} مساحات نشطة} many{{n} مساحة نشطة} other{{n} مساحة نشطة}} |
| {n, plural, =1{1 reply} other{{n} replies}} | {n, plural, =1{ردّ واحد} =2{ردّان} few{{n} ردود} other{{n} ردًّا}} |
| NEEDS YOU | بانتظارك |
| See all | عرض الكل |
| TODAY IN YOUR SPACES | اليوم في مساحاتك |
| That's your day | هذا يومك |
| Nothing else needs you right now | لا شيء آخر بانتظارك الآن |
| Project | مشروع |
| Search people | ابحث عن أشخاص |
| My Spaces | مساحاتي |
| {event, select, done{{name} signed {ref} as done} checked{{name} checked {ref}} sent_back{{name} sent {ref} back} comment{{name} commented on {ref}} reassigned{{name} reassigned {ref}} other{{name} raised {ref}}}: {title} | {event, select, done{{ref} منجز بتوقيع {name}} checked{فحص {ref} من {name}} sent_back{إرجاع {ref} من {name}} comment{تعليق من {name} على {ref}} reassigned{إعادة تكليف {ref} من {name}} other{بند جديد {ref} من {name}}}: {title} |
| {name} added {file} | ملف جديد من {name}: {file} |
| {name}: {text} | {name}: {text} |
| {kind, select, photo{{name} sent a photo} voice{{name} sent a voice note} file{{name} sent a file} other{{name} posted in chat}} | {kind, select, photo{صورة من {name}} voice{رسالة صوتية من {name}} file{ملف من {name}} other{رسالة من {name}}} |
| Report post | الإبلاغ عن المنشور |
| Report reply | الإبلاغ عن الرد |
| Language and region | اللغة والمنطقة |
| Left to right | من اليسار إلى اليمين |
| Right to left | من اليمين إلى اليسار |

## Activity and notifications

| English | Arabic |
|---|---|
| Someone | أحدهم |
| NEEDS YOU · {n} | بانتظارك · {n} |
| CHANGES TO YOUR RECORD | تغييرات في سجلك |
| Last 7 days | آخر 7 أيام |
| Space · your pass: {pass} | مساحة · تصريحك: {pass} |
| Your record | سجلك |
| Your network | شبكتك |
| Your posts | منشوراتك |
| REV {letter} | REV {letter} |
| {name} gave you {ref} | تكليف لك بـ{ref} من {name} |
| {name} signed {ref} as done | {ref} منجز بتوقيع {name} |
| {name} checked {ref} | فحص {ref} من {name} |
| {name} sent {ref} back | إرجاع {ref} من {name} |
| {name} commented on {ref} | تعليق من {name} على {ref} |
| {name} asked to join | طلب انضمام من {name} |
| You're in {space} | تم تأكيد انضمامك إلى {space} |
| Confirmed by {name} | مؤكَّد من {name} |
| {name} confirmed your role | تأكيد دورك من {name} |
| New follower: {name} | متابِع جديد: {name} |
| {name} replied to your post | ردّ من {name} على منشورك |
| {name} replied to you | ردّ من {name} عليك |
| {a} found your post useful | منشورك مفيد لـ{a} |
| {a} and {b} found your post useful | منشورك مفيد لـ{a} و{b} |
| Your post was found useful | منشورك مفيد للآخرين |
| Assigned | تكليف |
| Done | منجز |
| Checked | تم التحقق |
| Sent back | مُرجَع |
| Comment | تعليق |
| Approved | مقبول |
| Confirmed | مؤكَّد |
| Nothing needs you right now. | لا شيء بانتظارك الآن. |
| When someone needs an answer from you, it waits here. This is what will show up. | ما يحتاج ردّك ينتظرك هنا. هذا ما سيظهر: |
| PEOPLE | الأشخاص |
| New followers | متابِعون جدد |
| YOUR POSTS | منشوراتك |
| Replies | الردود |
| MESSAGES | الرسائل |
| Show message text on lock screen | إظهار نص الرسالة على شاشة القفل |
| SPACES | المساحات |
| Set for each Space in Space info → Notifications | لكل مساحة من معلومات المساحة ← الإشعارات |
| Notifications never name a project, a Space or a work item. | لا تذكر الإشعارات اسم مشروع أو مساحة أو بند عمل. |
| Push notifications are off | الإشعارات متوقفة |
| You will miss work items and messages. Turn them on in your phone settings. | ستفوتك بنود العمل والرسائل. فعّلها من إعدادات الهاتف. |
| Open phone settings | افتح إعدادات الهاتف |
| {kind, select, post{Your post was removed} reply{Your reply was removed} other{Your message was removed}} | {kind, select, post{أُزيل منشورك} reply{أُزيل ردّك} other{أُزيلت رسالتك}} |
| {result, select, reversed{Your appeal: it's back} other{Your appeal: the removal stands}} | {result, select, reversed{اعتراضك: أُعيد المحتوى} other{اعتراضك: يبقى محذوفًا}} |
| Removed | محذوف |
| Restored | مُستعاد |

## Report, block and removals

| English | Arabic |
|---|---|
| {kind, select, post{Report this post} reply{Report this reply} message{Report this message} other{Report this account}} | {kind, select, post{الإبلاغ عن هذا المنشور} reply{الإبلاغ عن هذا الرد} message{الإبلاغ عن هذه الرسالة} other{الإبلاغ عن هذا الحساب}} |
| The person won't be told who reported. Choose what fits best. | لن يُعرف من أبلغ. اختر الأنسب. |
| Spam or scam | رسائل مزعجة أو احتيال |
| Fake offers, unwanted promotion | عروض وهمية، ترويج غير مرغوب |
| Harassment or abuse | مضايقة أو إساءة |
| Insults, threats, targeting someone | إهانات أو تهديدات أو استهداف شخص |
| Wrong or misleading | خاطئ أو مضلل |
| Claims that are false | ادعاءات غير صحيحة |
| This isn't real | هذا غير حقيقي |
| A fake person, company or project | شخص أو شركة أو مشروع وهمي |
| Shares private information | كشف معلومات خاصة |
| Documents, plans or details not meant to be public | مستندات أو مخططات أو تفاصيل ليست للنشر |
| Something else | شيء آخر |
| Tell us in a few words | أخبرنا بكلمات قليلة |
| What's wrong? | ما المشكلة؟ |
| A few words | بضع كلمات |
| Send report | إرسال البلاغ |
| Report sent | تم إرسال البلاغ |
| We'll review it and may remove anything that breaks the rules. The person isn't told who reported. | سنراجعه وقد نزيل ما يخالف القواعد. لن يُعرف من أبلغ. |
| Done | تم |
| Block this account | حظر هذا الحساب |
| {name} blocked | تم حظر {name} |
| Blocked accounts | الحسابات المحظورة |
| {n} BLOCKED | المحظورون · {n} |
| Nobody blocked | لا أحد محظور |
| Unblock | إلغاء الحظر |
| {name} unblocked | تم إلغاء حظر {name} |
| Blocked accounts can't follow you or see your posts. They are not told. | لا تستطيع الحسابات المحظورة متابعتك أو رؤية منشوراتك، ولا يصلها أي إشعار. |
| {kind, select, post{Removed post} reply{Removed reply} other{Removed message}} | {kind, select, post{منشور محذوف} reply{رد محذوف} other{رسالة محذوفة}} |
| {kind, select, post{We removed your post} reply{We removed your reply} other{We removed your message}} | {kind, select, post{أزلنا منشورك} reply{أزلنا ردّك} other{أزلنا رسالتك}} |
| It was reported for {reason}, and our review agreed. Only you can see this notice. | تم الإبلاغ عن المحتوى بسبب {reason}، وتأكدنا من ذلك بعد المراجعة. لا يرى هذا الإشعار غيرك. |
| {reason, select, spam{spam or a scam} harassment{harassment or abuse} misleading{being wrong or misleading} fake{not being real} private_info{sharing private information} other{something else}} | {reason, select, spam{رسائل مزعجة أو احتيال} harassment{مضايقة أو إساءة} misleading{معلومات خاطئة أو مضللة} fake{أنه غير حقيقي} private_info{كشف معلومات خاصة} other{أمر آخر}} |
| {kind, select, post{Your post} reply{Your reply} other{Your message}} · {date} | {kind, select, post{منشورك} reply{ردّك} other{رسالتك}} · {date} |
| You have 14 days to appeal. We'll look at it again. | أمامك 14 يومًا للاعتراض. سنراجعه مرة أخرى. |
| Appeal this decision | اعترض على القرار |
| You appealed on {date}. We'll tell you the result in Activity. | اعترضت في {date}. سنخبرك بالنتيجة في النشاط. |
| The 14 days to appeal have passed. | انتهت مدة الاعتراض (14 يومًا). |
| We looked at it again: the removal stands. | راجعناه مرة أخرى: يبقى محذوفًا. |
| We looked at it again and brought it back. | راجعناه مرة أخرى وأعدناه. |
| This notice isn't available. | هذا الإشعار غير متاح. |
| Appeal | اعتراض |
| Tell us why this was a mistake | أخبرنا لماذا كان هذا خطأ |
| Add anything that helps the reviewer. Don't include other people's private details. | أضف ما يساعد المراجعة. لا تذكر تفاصيل خاصة بأشخاص آخرين. |
| Your explanation | توضيحك |
| Up to 500 characters | حتى 500 حرف |
| Send appeal | إرسال الاعتراض |
| Appeal received | تم استلام الاعتراض |
| We'll look at it again. We'll tell you the result in Activity, usually within 3 days. | سنراجعه مرة أخرى، وسنخبرك بالنتيجة في النشاط، عادةً خلال 3 أيام. |

## Settings and account

| English | Arabic |
|---|---|
| Notifications | الإشعارات |
| View profile | عرض الملف |
| YOUR SETTINGS, IN WORDS | ملخّص إعداداتك |
| PRIVACY | الخصوصية |
| NOTIFICATIONS | الإشعارات |
| LANGUAGE | اللغة |
| {n, plural, =1{1 blocked account} other{{n} blocked accounts}} | {n, plural, =1{حساب محظور واحد} =2{حسابان محظوران} few{{n} حسابات محظورة} many{{n} حسابًا محظورًا} other{{n} حساب محظور}} |
| {what}. Work items, chat and the Library stay inside each Space. | {what}. بنود العمل والمحادثة والمكتبة تبقى داخل كل مساحة. |
| New followers: {followers}. Replies: {replies}. Message text on the lock screen: {lockText}. | إشعارات المتابعين الجدد: {followers}. إشعارات الردود: {replies}. نص الرسائل على شاشة القفل: {lockText}. |
| on | مفعّلة |
| off | متوقفة |
| shown | ظاهر |
| hidden | مخفي |
| {language}. The week starts on {weekday}, in {country} time. | {language}. يبدأ الأسبوع يوم {weekday}، بتوقيت {country}. |
| {language}. | {language}. |
| ACCOUNT | الحساب |
| Account and security | الحساب والأمان |
| Download my data, delete account | تنزيل البيانات، حذف الحساب |
| Privacy and safety | الخصوصية والأمان |
| SUPPORT | الدعم |
| Help and feedback | المساعدة والملاحظات |
| About BuildVibes and legal | عن BuildVibes والشروط |
| Terms, privacy policy | الشروط وسياسة الخصوصية |
| Terms of use | شروط الاستخدام |
| Privacy policy | سياسة الخصوصية |
| These pages are on their way. Write to us with any question. | هذه الصفحات قيد الإعداد. يسعدنا تلقي أي سؤال. |
| This couldn't be opened on this phone. | تعذّر فتح هذا على الهاتف. |
| Sign out of BuildVibes? | تسجيل الخروج من BuildVibes؟ |
| You'll need a code sent to your email to sign in again. | للدخول مرة أخرى يلزم رمز يُرسل إلى البريد الإلكتروني. |
| YOUR DATA | بياناتك |
| Download my data | تنزيل بياناتي |
| We email you a copy within 7 days | نرسل نسخة بالبريد خلال 7 أيام |
| DANGER ZONE | منطقة الخطر |
| Delete account | حذف الحساب |
| Removed after 30 days. You can restore it until then. | يُحذف بعد 30 يومًا، ويمكن استعادته قبل ذلك. |
| SAFETY | الأمان |
| Work items, chat and the Library stay inside each Space. Only its members see them. | بنود العمل والمحادثة والمكتبة تبقى داخل كل مساحة، ولا يراها إلا أعضاؤها. |
| REGION | المنطقة |
| Country | الدولة |
| Week starts on | بداية الأسبوع |
| Arabic switches the whole app to right-to-left. Your posts keep the language they were written in. | العربية تجعل التطبيق كله من اليمين إلى اليسار. تبقى المنشورات باللغة التي كُتبت بها. |
| Get a copy of your data | نسخة من بياناتك |
| We email you a file with everything below, within 7 days. | نرسل بالبريد ملفًا فيه كل ما يلي، خلال 7 أيام. |
| WHAT IS INCLUDED | ما يشمله |
| Profile and settings | الملف والإعدادات |
| Posts and replies | المنشورات والردود |
| Messages you sent | الرسائل المرسلة منك |
| Your work items and notes | بنود العمل والملاحظات الخاصة بك |
| Request my data | طلب بياناتي |
| We send it to {email}. | نرسلها إلى {email}. |
| Request received | وصل الطلب |
| We will email {email} within 7 days. | سنراسل {email} خلال 7 أيام. |
| Before you delete | قبل الحذف |
| Your profile is hidden right away. You have 30 days to change your mind. | يُخفى ملفك فورًا، ولديك 30 يومًا لتغيير رأيك. |
| WHAT HAPPENS | ما الذي يحدث |
| Profile, posts and replies are removed | يُحذف الملف والمنشورات والردود |
| Work and files in a Space stay there | العمل والملفات في المساحة تبقى فيها |
| Shown as a former member | باسم «عضو سابق» |
| Messages you sent stay in the Space's chat | الرسائل المرسلة تبقى في محادثة المساحة |
| Continue | متابعة |
| Keep my account | إبقاء حسابي |
| Transfer ownership first | نقل الإدارة أولًا |
| You are the only admin of a Space that has other members. Make someone else its admin before you delete your account. | لا مدير لهذه المساحة غيرك، وفيها أعضاء آخرون. يلزم نقل إدارتها إلى عضو آخر قبل حذف الحساب. |
| ONLY ADMIN | المدير الوحيد |
| Confirm it's you | تأكيد الهوية |
| Enter the code we sent to {email}. | يُرجى إدخال الرمز المرسل إلى {email}. |
| Delete my account | حذف حسابي |
| Your account will be removed on {date}. Sign in before then to restore it. | سيُحذف الحساب في {date}. يمكن استعادته بالدخول قبل ذلك. |
| Deletion scheduled | الحذف مجدول |
| Your account will be deleted on {date}. Your profile is hidden. Restore it any time before then. | سيُحذف الحساب في {date}. الملف مخفي الآن، ويمكن استعادته في أي وقت قبل ذلك. |
| Restore my account | استعادة حسابي |
| Former member | عضو سابق |

## Other

| English | Arabic |
|---|---|
| just now | الآن |
| {n, plural, =1{1 min ago} other{{n} min ago}} | {n, plural, =1{قبل دقيقة} =2{قبل دقيقتين} few{قبل {n} دقائق} other{قبل {n} دقيقة}} |
| {n}h ago | {n, plural, =1{قبل ساعة} =2{قبل ساعتين} few{قبل {n} ساعات} other{قبل {n} ساعة}} |
| yesterday | أمس |
| {n, plural, =1{1 day ago} other{{n} days ago}} | {n, plural, =1{قبل يوم} =2{قبل يومين} few{قبل {n} أيام} other{قبل {n} يومًا}} |
| {a} and {b} | {a} و{b} |
| {names} and others | {names} وآخرون |
| you | أنت |
| Confirmed by {names} | مؤكَّد من {names} |
| Progress update | تحديث سير العمل |
| Done today · Next · Holding us up | تم اليوم · التالي · ما يعيقنا |
| Done today: Next: Holding us up: | تم اليوم: التالي: ما يعيقنا: |
| Milestone | إنجاز مرحلة |
| What · When · Who did it | ماذا · متى · من أنجزه |
| What: When: Who did it: | ماذا: متى: من أنجزه: |
| Site visit | زيارة موقع |
| Where · What we found · Actions | أين · ماذا وجدنا · الإجراءات |
| Where: What we found: Actions: | أين: ماذا وجدنا: الإجراءات: |
| Ask the community | اسأل المجتمع |
| Question · Who knows | السؤال · من يعرف |
| Question: Who knows: | السؤال: من يعرف: |
| Link a project | ربط بمشروع |
| Only projects where you have a confirmed role. | المشاريع التي لديك فيها دور مؤكَّد فقط. |
| Add a project on your profile first | أضف مشروعًا في ملفك أولًا |
| Work for your team goes in the project's Space as a work item | عمل فريقك يذهب إلى مساحة المشروع كبند عمل |
| No project | بدون مشروع |
| Discard this post? | حذف هذا المنشور؟ |
| Your text, photo and project link will be lost. | سيُحذف النص والصور ورابط المشروع. |
| Discard | حذف |
| POSTS | المنشورات |
| No posts tagged with this project yet. | لا منشورات مرتبطة بهذا المشروع بعد. |
| now | الآن |
| {n}m | {n} د |
| {n}h | {n} س |
| Keep editing | متابعة التعديل |
| WORK ITEMS | بنود العمل |
| Someone gives you a work item, or one you raised is done. | تكليف لك ببند عمل، أو توقيع بند أنشأته كمنجز. |
| SPACE REQUESTS | طلبات المساحات |
| Someone asks to join a Space you run. | طلب انضمام إلى مساحة تديرها. |
| YOUR POSTS | منشوراتك |
| Someone replies to your post. | ردّ على منشورك. |
| YOUR NETWORK | شبكتك |
| Someone follows you. | متابِع جديد لك. |
| WHILE YOU WAIT | أثناء الانتظار |
| Add a project you worked on | أضف مشروعًا عملت فيه |
| Just now | الآن |
| {n, plural, =1{1 min ago} other{{n} min ago}} | {n, plural, =1{قبل دقيقة} =2{قبل دقيقتين} few{قبل {n} دقائق} other{قبل {n} دقيقة}} |
| {n}h ago | {n, plural, =1{قبل ساعة} =2{قبل ساعتين} few{قبل {n} ساعات} other{قبل {n} ساعة}} |
| Yesterday | أمس |
| {n, plural, =1{1 day ago} other{{n} days ago}} | {n, plural, =1{قبل يوم} =2{قبل يومين} few{قبل {n} أيام} other{قبل {n} يومًا}} |
| Report account | الإبلاغ عن الحساب |
