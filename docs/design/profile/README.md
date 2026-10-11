# Profile and project records: Figma reference (signed-off prototype)

The images are 390-wide exports from the Figma page "PROTOTYPE · Full app v1 · EN". The "full-scroll" images show the whole scrolling content of a screen.

| File | Figma frame | What it is |
|---|---|---|
| R1-my-profile-* | Profile · R1 v3 (`2350:38775`) | Your own profile, Overview tab. It includes the proof card "Where it's confirmed", Work you delivered, Open to, About, Featured projects, credentials, tools, languages, links and recommendations. |
| R5-person-profile-visitor-full-scroll | People · Omar Haddad (`2181:16328`) | Someone else's profile as a visitor sees it: Follow, Message about work, Work delivered (only what they chose to show). |
| R8-edit-profile-full | Profile · R8 (`2145:28345`) | Edit profile. |
| RE2-work-you-delivered | RE2 (`2422:29243`) | The owner chooses which checked items to show. Everything is hidden by default. |
| RE1-delivered-work-public | RE1 (`2422:29198`) | Public view of one delivered item: title, photo, place, who checked it and the sign-off. No discussion and no files. |
| PJ1-project-sheet | PJ1 (`2416:31080`) | Shared project record with no owner: the title block, your CV entry, your Spaces on it, people who listed it and chose to show it, companies, and posts. |
| PJ1-E-suggest-an-edit | PJ1-E (`2437:29490`) | Suggest an edit. It goes to back-office review. |
| P13-is-it-already-here | P13 v2 (`2307:37375`) | Search for an existing record before creating a new one, then "This is it · add to my CV". |
| P14-new-project-title-block | P14 v2 (`2307:37248`) | New project record, then "Add to my CV". |

## MVP scope for task 10 (plan week 3)
**In:**
- **Own profile:** header, proof card, Open to, About, experience, projects on the CV, and the share link.
- **Visitor profile:** with Follow. Follower counts are allowed.
- **Edit profile.**
- **Project sheet.**
- **Is it already here?:** then add to CV, or create a new record.
- **Suggest an edit:** stored for review.

**Later:**
- **Work you delivered (RE1/RE2):** needs work items, so it comes in plan week 5. Draw its section with the empty state ("Nothing checked yet").
- **Not in the MVP:** Message about work, recommendations, CV PDF and credentials. Hide them.

**Rules:**
- No aggregate numbers, except follower counts.
- A company name stays plain text unless it matches a registered company.
- Visibility choices are single-choice: Everyone / Connections only / Only me.
