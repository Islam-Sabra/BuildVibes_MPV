# Review 28: Translate is out of the pilot

**Founder decision, 13 Oct 2026.** The pilot spends no money. Google Cloud Translation asks for a $30 prepayment on the founder's card, so Translate on posts (L1–L4) waits until after the pilot.
- This replaces the 13 Oct "Translate yes, week 8" decision in review 23 §0 and §6.
- Review 23 §4 (spec), §7 (Google steps) and §8 part 3 stay as the plan for after the pilot.
- When Translate comes back, compare free tiers again before choosing a provider. Microsoft Azure Translator's free tier (2 million characters a month) is the first candidate.

## What changes now
1. **Stop part 3.**
   - If a `translate` branch was started, push it so the work is kept, but don't merge it.
   - Nothing for migration 17 or the `translate` function goes live.
2. **Composer language sheet (L6).** Hide the line "We use this to offer Translate to readers who don't read it." and its Arabic version while Translate is off.
   - Keep the post-language line and the sheet. Each post still records its language, so Translate can use it later.
   - Use one setting in code (for example `kTranslateEnabled = false`) so the line comes back with Translate. The setting is not shown to users.
3. **Docs.** Add a note to `docs/progress.md` that Translate is out of the pilot, and point to this review.
4. **Terms and Privacy draft.** The lead has already removed Google Cloud Translation from the list of companies that handle data.
5. **Next is part 4:** the Arabic pass and the market pack audit (review 23 §5 and §8 part 4).

## Founder side
Don't finish the Google Cloud billing setup, and don't make the prepayment. Nothing is charged if it isn't completed. The Firebase project (pushes) stays on its free plan and doesn't need Cloud billing.
