# Feed: the founder's notes for its review (1 Nov 2026, build 880)

These are recorded for the feed's own review, which is next in the polish queue after reviews 109 and 111. **Not designed or built yet.**

1. **The font in feed posts looks like the phone's own font**, not the app's.
   - **Lead's first reading:** the founder types with his keyboard's "Stylish Text", which sends Unicode lookalike letters (𝑡𝑒𝑠𝑡). Our fonts don't have those letters, so the phone draws them with its own font.
   - **Check:** whether ordinary text in a feed post uses Plus Jakarta Sans / Almarai (`BvType`).
   - **Decide:** whether to turn lookalike letters into plain letters when a post is saved (most apps don't) or leave them.
2. **Replies under a short post:** show the latest reply in one line under the post, with a small avatar and name, for example "IA Islam Ahmed: thanks Omar", as other networks do. One tap opens all replies.
3. **Bug:** tapping **Useful** opens the post instead of marking it Useful. The reaction's tap must not fall through to the card.
4. **The feed as a whole needs the same care the Space got:** the card, the reactions, the replies, the short-card rule (review 110 F) and See more.
