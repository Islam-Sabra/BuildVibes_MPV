# Product rules for the build

These rules come from the founder's decisions of 8–11 Oct 2026. They apply to every screen, query and string.

## 1. Audience: the whole AEC industry
**Who the users are.** All of these are first-class users:
- engineers and architects
- BIM and digital staff
- site supervisors and foremen
- trades: electrician, plumber, carpenter, mason, finishing, operator or driver
- safety officers
- quantity surveyors
- small subcontractors and one-person businesses
- suppliers
- consultants and developers
- labour who join a Space by invitation

**Test for every screen:**
1. Could a foreman or electrician with a phone and basic reading use it in under a minute?
2. Does it assume a degree, a licence, a long CV, a company page, English or an email address? If so, that part is optional and never blocking.
   - **Accepted exception for the MVP (decision 04, 11 Oct 2026):** sign-in needs an email address, because sign-in is by email code only. Phone sign-in returns after the pilot. Nothing else may need an email.
3. Is the main action one tap, with a plain verb?
4. Can a person with no projects and no confirmations still be found, and still look credible?

**Copy** is plain Arabic and English. Avoid jargon such as "ISO 19650" or "BEP" on general screens.

## 2. No misleading numbers
**Don't show aggregate counts as quality signals:**
- total results
- projects built
- projects confirmed
- company headcount
- Space member counts
- years of experience in headers

**Allowed:**
- statements about the viewer's own relation, preferably with names. Examples: "You both worked on Kuwait City Tower", "Confirmed by Sara Al-Mutairi".
- project years, such as 2023–2026.
- follower counts on profiles (founder decision, 11 Oct).

Ranking never uses volume alone: not follower count, project count or years.

## 3. Disclosure by choice
- **A person's own record** (projects, roles, credentials, links, open to work) is entered by that person to be seen. It shows as they set it.
- **Company business facts** are never computed and shown automatically. This covers project counts, values, clients, headcount, hiring volume and any total. They're hidden by default, and the company admin publishes each one separately.
- **Platform-derived aggregates** (counts, rankings, scores) don't exist in V1.
- **Company names typed by people:**
  - The name is matched against registered companies.
  - On a match, the person can pick it, and it links.
  - With no match, it's saved as **plain text**: `company_name_text`. Never create a company row from typed text.
  - When that company registers later, the person is asked whether to link it. Nothing links automatically.

## 4. Market pack: nothing country-specific in code
**Kuwait and Egypt are the first market packs.** They're data, not code. Later packs (Saudi Arabia, the Gulf, Europe) are added as data and translations.

**A pack holds:**
- id and names
- status: live, coming soon or hidden
- languages and text direction
- phone: dial code, number rules, code channel and fallback
- currency: ISO code, decimals, symbol placement
- calendar: first day of the week, weekend, date formats, digit style
- units
- places (admin levels and the list)
- taxonomy overrides for trades and company kinds
- credentials registry
- legal texts: Terms, Privacy, consent
- launch settings
- compliance flags

**Rules:**
- No country, city, currency, phone format or week rule appears in a widget or a string. Use placeholders such as `{country}`, `{city}` and `{currency}`, filled from the pack.
- Every user has one **home market**. It sets feed order and default filters only, never access. Search, messaging and connections work worldwide.
- At sign-up, the Country field is pre-filled from the device region. It can be changed later in Settings → Language and region.
- The home market must be a live market (Kuwait). Markets that are not open yet show "coming soon". The exception: a person who arrives with a Space invite may choose any country. The server enforces the same rule.
- Arabic names use First name (given names) and Last name (family name). There's no third field.

## 5. Interaction rules
- Choices that exclude each other are one single-choice control: a list, a sheet or radio cards. Never separate switches.
- **No unnecessary settings.**
  - Language has only the app language, plus each post's own language with a Translate option.
  - Links to other sites are links only in V1.
  - Link visibility options: Everyone, Connections only, Only me.
- Sign-in has no passwords. In the MVP it is a 6-digit email code only (decision 04); Google and Apple are built but hidden; phone code comes after the pilot.
- A mobile number given at sign-up is optional and private: never shown on the profile.
- Onboarding is short: name, role or trade, company. Then Home.
- Home has two tabs: Feed (opens first, and social) and Spaces (daily Space activity with Needs you).
- The bottom bar has 5 tabs: Home, Explore, Create, Activity, Profile.
- Light mode only in V1.
