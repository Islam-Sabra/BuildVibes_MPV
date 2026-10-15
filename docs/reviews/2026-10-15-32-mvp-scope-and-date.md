# Review 32: new MVP scope, new pilot date, and the Daybook

**Founder decisions, 15 Oct 2026.** Docs only in this review. No code, no migration, nothing goes live. Do not start building the Daybook yet: review 33 (the build plan with the database changes and the slices) follows once the design is finished on 24–31 Oct.

## 1. What changed
1. **Pilot date:** **Monday 1 February 2027** (was 1 January). Still four weeks with one real team.
2. **Scope:** the founder moved these into the MVP:
   - **Spaces: Work in full**, in the new Daybook design (`docs/product/daybook.md`): writing in place with drafts, the kinds of post (work item, checklist, announcement, scheduled activity, file), opening a post in place (blocks, "/", turn into, tables), work items under one work item, walk mode, templates, the daily report, meeting notes into work items, and the management report.
   - **Planning:** the personal notebook (private notes, checklists, to-dos, pinned notes, "Put in a Space") and My calendar across all Spaces.
   - **Direct messages** between two people.
3. **Still out of the MVP:** export the record as PDF, approval codes, repeating work items, Translate, phone and WhatsApp sign-in, Jobs and hiring, company job management, community question Spaces, sponsored posts, the paid plan, CV import, connected accounts, Explore beyond people search.
4. **Safety line, 15 December 2026:** any build slice not started by then moves to after the pilot. The date does not move again.
5. **Design style:** the Space uses the **Daybook** style. The rest of the app (Home feed, profile, chat, notebook, Space info) is being redrawn in Daybook on 16–31 Oct.
6. **Work item words:** "work item" (بند عمل) everywhere. Never "job" in the app (Jobs is the hiring feature).

## 2. What to do (one commit, then push)
1. **CLAUDE.md:**
   - In "What this is": change "for four weeks from **1 January 2027**" to "for four weeks from **1 February 2027**".
   - In "Scope", "In the MVP", add these bullets after the Spaces bullet:
     - "Work in the Daybook design: writing in place with drafts; work item, checklist, announcement, scheduled activity and file posts; opening a post in place (blocks, /, turn into, tables); work items under one work item; walk mode; templates; daily report; meeting notes into work items; management report (see `docs/product/daybook.md`);"
     - "Planning: the personal notebook and My calendar across all Spaces;"
     - "Direct messages between two people;"
   - Replace the "Not in the MVP" line with: "**Not in the MVP:** export a work item's record as PDF, approval codes, repeating work items, Translate, phone and WhatsApp sign-in, Jobs and hiring, company job management, Explore beyond people search, community question Spaces, CV import, connected accounts, paid plan, sponsored posts."
   - Under "Product docs", add: "The Space Work design is `docs/product/daybook.md`; every prototype scenario is listed in `docs/product/space-scenarios.md`."
2. **docs/product/mvp-plan.md:**
   - Target line: "pilot live on **Monday 1 February 2027**".
   - Section 2: add rows for Work (Daybook, as above), Planning (personal notebook, My calendar) and Direct messages. Change the Work items row to point to `daybook.md`. Remove "Work item cards in the chat" from the Space chat row (work stays in the daybook; a chat message can be turned into a work item).
   - Section 3: replace with the "Still out" list in §1.3 above.
   - Add a section **"Plan to 1 February"** with this table:

     | When | What |
     |---|---|
     | 16–31 Oct | Design finish (lead): Daybook components, the rest of the app in Daybook, notebook, direct messages, Arabic |
     | 1–14 Nov | Database changes for the new scope, every rule enforced and tested on the server (review 33) |
     | by 1 Nov | Founder enrols in the Apple Developer Program and Google Play Console |
     | 15 Nov – 17 Jan | Build in 10 slices; the founder tests each on the emulator before the next starts: 1 daybook and the work item loop · 2 other kinds of post · 3 chat and direct messages · 4 people and Library · 5 opening a post in place · 6 walk mode and work items under one · 7 templates and daily report · 8 personal notebook and My calendar · 9 management report · 10 no signal and notifications |
     | by 15 Dec | First Play closed test and first TestFlight build; safety line for slices not started |
     | 18–24 Jan | Test week with 3–5 real people, then fixes |
     | 25–31 Jan | Freeze: fixes only, backups ready |
     | 1 Feb | Pilot starts |
3. **docs/progress.md:** add a dated note (15 Oct): pilot moved to 1 Feb 2027; new MVP scope per review 32; Daybook design adopted for the Space; build waits for review 33.
4. **Review 30 §8 dates** (first closed-test review and first TestFlight by 1 Dec; nothing after 20 Dec) are replaced by the table above. Note this in `docs/progress.md`; don't edit review 30.
5. Run `flutter analyze` and `flutter test` (they should be unaffected), commit as "docs: MVP scope and pilot date per review 32", push, and report the hash.

## 3. Not now
- No changes to screens, migrations or the live database.
- Keep the emulators and the live app as they are; the founder keeps testing 0.9.0 (1).
