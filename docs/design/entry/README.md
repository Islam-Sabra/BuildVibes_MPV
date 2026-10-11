# Entry and onboarding: Figma reference (signed-off prototype)

Frames on the Figma page "PROTOTYPE · Full app v1 · EN". The PNGs in this folder are 390×844 exports from Figma.

| File | Figma frame | What it does |
|---|---|---|
| E1-welcome | Entry · E1 · Welcome (`2145:4`) | Wordmark and a "Starting in {country}" pill, which is a label from the device region, never hard-coded. Rotating audience cards: engineers, site crews and trades, and so on. Buttons: Create account, Sign in. "Skip to Home" lets people browse first as a guest. |
| E2-join-or-sign-in | E2 v3 (`2233:31717`) | Main path: "Continue with phone number". Then "or continue with" Google, Apple and LinkedIn, using their real logos. "Use email instead". The line "No password. We never post for you or read your contacts." Terms text. |
| E2p-enter-phone | E2p (`2232:31614`) | Phone field with the dial code from the market pack. "We send a 6-digit code on WhatsApp", with an SMS fallback link and a link to use email instead. |
| E3-enter-code | E3 v2 (`2232:32151`) | 6-digit code input, a resend timer and "Use a different number". It must work with the phone's automatic code fill. |
| E3e-enter-code-email | E3e (`2438:29963`) | The same as E3, for the email code. |
| E9-about-you | E9 v2 (`2232:31762`) | First name and last name side by side (no third field). Country, pre-filled from the dial code ("You can change it in Settings"). Role. Company (optional, a searchable select; with no match it's saved as plain text). Recovery email (optional). |
| E9b-your-role | E9b v2 (`2386:30321`) | Search, then groups of trade chips from the `trades` table: popular in {country}, site and trades, engineering and design, management and supply. "Not in the list? Type it in search and add it as your role." |
| E10-people-to-follow | E10 v2 (`2386:68841`) | Step 2 of 2. Suggestions with a reason each: your company, worked near you, Spaces for your role. Skip goes to Home. |

**Arabic versions** are on the Figma page "PROTOTYPE · Core journeys · AR", in the first row. They use the same layout, mirrored, and the wording follows `docs/product/arabic-glossary.md`.

**MVP notes:**
- **LinkedIn** isn't in the MVP. Hide its button, but keep the layout ready for it.
- **Google and Apple** sign-in need provider keys from the founder. Build the flows, and keep the buttons hidden behind a flag until the keys exist.
- **Phone codes** use Supabase test phone numbers during development, so no SMS cost. The real provider (WhatsApp or SMS) is a founder decision, needed before the internal test in week 9.
- **Email codes** use the 6-digit email code (OTP), never a password.
- **Guests:** "Skip to Home" opens Home as a guest. Any action that needs an account shows the join wall (prototype frame H7).
