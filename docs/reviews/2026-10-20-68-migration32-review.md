# Review 68: migration 32, Library receipts — 20 Oct 2026

An independent check (a separate reviewer, read-only, with probes on the SQL stand-in) of `supabase/migrations/20261022120000_library_receipts.sql` and `supabase/tests/32_library_receipts.test.sql`, written for review 67.

**Verdict: approved after the fixes below. No leaks found.** All 2,251 SQL checks pass (41 in test 32).

## What was checked
- Every new function is security definer with `search_path = ''`. Anon can't run any of them. The in-use check is internal (also refused to signed-in people).
- `search_space` differs from migration 21's copy by one line: the file must be in use.
- A former member, someone outside a Team, a non-member and anon read nothing. Someone across a block is left out of faces and receipts. A post can't carry another Space's file, so receipts come only from the caller's Space.

## Findings
| # | Level | Finding | Done |
|---|---|---|---|
| M1 | Medium | Deleting a middle version (Rev C ← Rev D ← Rev E, Rev D deleted) brought Rev C back into use beside Rev E. | Fixed: a deleted version is see-through (a recursive check). Tested. |
| M2 | Medium | No index on `supersedes_id`: the in-use check read the whole table for each file (2.6 s at 3,000 files). | Fixed: a partial index. |
| L1 | Low | Two versions can replace the same file (older than 32); both show as in use. | Accepted: the app offers a new version only from the one in use. Written in the migration. |
| L2 | Low | Review 67 said 3 faces and a `library_file_page` function. | Review 67 updated: 4 faces; `library_file_receipts` and `library_file_post`, with the versions read from the table under its own read rule. |
| L3 | Low | A Received on a cancelled post still counts for NEW VERSION. | Accepted on purpose (the person has the file). Written in the migration. |
| L4 | Low | Small repeated checks in `library_overview`. | Left: no cost at pilot size. |

## Tests added after the review
A deleted middle version, the four-face limit (newest first), someone who received it twice listed once, the newest live post, and a former member reading nothing.

## Live
Not live. From the PC, after 29, 30 and 31, with the founder's yes, as the only file in the push.
