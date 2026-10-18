# Arabic: decisions and glossary (approved by the founder, 10 Oct 2026)

- Use simple standard Arabic, not dialect.
- Use Western digits (0–9).
- Codes, file names, URLs, and tool and standard names stay in Latin script, for example KCT-021, MEP, BIM, Revit, ISO 19650 and Rev C.
- When a line mixes Arabic with a leading Latin code, start it with a right-to-left mark (U+200F) so it reads right to left. In Flutter, prefer `Directionality` with `TextDirection.rtl` and `Bidi` helpers rather than raw marks.
- The Figma page "PROTOTYPE · Core journeys · AR" is the visual reference for right-to-left layout. Its two hidden text nodes, "i18n · part A" and "i18n · part B", hold the full English→Arabic string tables (about 480 strings) used for the core journeys. Use them to seed `app_ar.arb`.

| English | Arabic |
|---|---|
| Space | مساحة |
| Space admin | مدير المساحة |
| Work item | بند عمل |
| Owner (of a work item) | المكلّف |
| Sign as done | وقّع كمنجز |
| Done | منجز |
| Checked | تم التحقق |
| Check (the action) | تحقّق |
| Double-tap the photo to check it | انقر مرتين على الصورة للتحقق |
| Send back | إرجاع |
| Lead / Crew / Viewer | مسؤول / فريق تنفيذ / مُطّلع |
| Pass | تصريح |
| Needs you | بانتظارك |
| Project sheet / record | سجل المشروع |
| Open (status) | مفتوح (in chips: مفتوحة) |
| Sign-off | التوقيعات |
| Evidence | الإثبات |
| Raised | أُنشئ |
| Due | الاستحقاق |
| Library | المكتبة |
| Chat | المحادثة |
| People | الأشخاص |
| Work (tab) | العمل |

"Owner" of a work item is المكلّف, not مسؤول, so that it doesn't clash with the Lead pass.

**18 Oct (founder, review 50 F14):** "Checked" is **تم التحقق**, not تم الفحص: it fits office work (drawings, submittals) as well as site work. Avoid مُراجَع (too close to مُرجَع, Sent back) and مُعتمد (a formal approval; approval codes are out of the MVP).
