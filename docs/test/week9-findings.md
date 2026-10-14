# Week 9 findings

**For:** the founder and the lead. One line per bug: what happens, where it was found, and its state.
Testers' findings go here during the test week (review 30 §5).

| # | Found | What happened | State |
|---|---|---|---|
| 1 | End-to-end test, 14 Oct | **Unsent work showed for the next person on the same phone.** A work item waiting to be sent ("Not sent yet") was kept for the whole phone, not per account. After a sign-out, the next person saw it, with its title, and could try to send it. On a phone a crew shares, that leaks one person's work to another. | Fixed on `e2e`: each account keeps its own unsent items, and the old shared list is cleared. Test: `test/features/work/work_outbox_accounts_test.dart` |
| 2 | End-to-end test, 14 Oct | **Signing out on a weak connection showed an error** although the phone was signed out. The session is removed from the phone first; only the follow-up call to the server failed, and nothing caught it. | Fixed on `e2e`: a lost connection at that last step is ignored, because the server's copy expires by itself |
| 3 | End-to-end test, 14 Oct | **Phone sign-in can show "+" with no country code** when the market list hasn't loaded yet (a slow connection). Send then does nothing and says nothing. Phone sign-in is off in the pilot (email codes), so this doesn't affect testers. | Open, for after the pilot, when phone sign-in comes back |
