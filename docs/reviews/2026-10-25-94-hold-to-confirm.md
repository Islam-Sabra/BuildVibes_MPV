# Review 94: Hold to confirm, for the actions that can't be taken back — 25 Oct 2026

**Why:** on a moving site, with gloves or dust on the screen, one wrong tap can **check** a work item (which locks it), **cancel** one, or **remove someone from a Space**. A confirm dialog after every tap slows everyone down. Holding the button is faster and safe. The idea is borrowed from dqnamo's "Hold to Confirm" (dqnamo.com/kitchen): no code is taken, and it's built natively.

## Where
Only these three actions:
1. **Check** a work item (Done → Checked, which locks it).
2. **Cancel work item** (the author, or someone acting for them).
3. **Remove from Space** (the Space admin, on the People tab's person sheet).

**Never** on routine actions: Sign as done, Send back, a tick, Got it, Received, On my way, Send, a message.

## How it behaves
- **The button reads "Hold to check" / «اضغط مطولًا للتحقق»** (and "Hold to cancel" / «اضغط مطولًا للإلغاء», "Hold to remove" / «اضغط مطولًا للإزالة»).
  - While held, its background **fills from the start side to the end** in **600 ms**. In Arabic it fills right to left.
  - A light haptic tick starts the hold, and a firm one marks the finish.
- **Let go early:**
  - the fill runs back in 150 ms, and nothing happens;
  - the first two times on a phone, a small line under the button says "Keep holding to confirm" / «استمر بالضغط للتأكيد».
- **When the hold completes:**
  - the card shows the result at once (CHECKED stamp, cancelled look, or the person gone);
  - a bar appears at the bottom: "Checked · **Undo**" / «تم التحقق · **تراجع**» (and "Cancelled · Undo" / «أُلغي · تراجع», "Removed · Undo" / «أُزيل · تراجع»), for **5 seconds**.
- **Undo needs no server change:** the action waits **5 seconds in the outbox** before it's sent. Undo takes it out, and the card goes back as it was. After 5 seconds it's sent as now, and it goes through the outbox, so no signal works as for everything else.
  - **Leaving the screen or closing the app during those 5 seconds** sends it: it was confirmed by the hold.
- **Accessibility:** with TalkBack or VoiceOver on, holding isn't practical. A double-tap then opens a short confirm ("Check this work item? It can't be changed after." / «التحقق من بند العمل؟ لا يمكن تغييره بعد ذلك.»), with **Check** / **Not now**.
- **Reduce motion:** no fill animation. The button turns solid at the end of the 600 ms hold.

## The component
- One shared `BvHoldButton` in `lib/shared/widgets/`, built with tokens only (the colour and the 600 ms in `bv_tokens`), used in the three places.
- The 5-second outbox hold is a small addition to the existing outbox: `holdFor: Duration`, which can be cancelled.

## Tests (EN and AR)
- A hold under 600 ms does nothing; a full hold acts.
- The fill direction mirrors in Arabic.
- Undo within 5 s sends nothing to the server, and the card is restored; without Undo it's sent once.
- Leaving the screen sends it.
- With accessibility on, a double-tap gives the dialog.
- With reduce motion on, no animation.
- Sign as done and Send back are unchanged (still one tap).
- **Screenshots** (EN and AR):
  - the button at rest;
  - half held;
  - the Undo bar after Check.
