# Review 27: migration 16 recheck, and week 8 part 2 screens

**Branches checked:** `account-db` at `efecb71` and `account` at `9936f5a`.
**Verdict:**
- Review 26's fixes M1–M4, L1, L2 and L4 are in place and correct. The harness passes 818 checks.
- Three more fixes are needed before migration 16 goes live: R1 and R2 (medium), and R3 (low). Make them **inside migration 16**. Migration 16 is not live yet, so don't add a new migration file.
- Part 2 screens pass in English and Arabic. No changes are needed.
- After R1–R3 are in, with tests, no further lead recheck is needed. Go to the go-live steps.

## Fixes (inside migration 16)

### R1 (medium): a second confirmer's purge fails every night
- **What breaks:** member M is confirmed for project P by admin A in Space S1, and by admin B in Space S2. After A is purged, B's purge fails with `duplicate key … cv_project_confirmations_one_per_confirmer (…, null)`.
- **Why it matters:** B's account is never deleted, and that breaks the 30-day promise in the Terms.
- **Cause:** `unique nulls not distinct` treats two purged confirmers as the same person.
- **Fix:**
  1. Use a plain unique constraint, which allows several null confirmers:
     ```sql
     alter table public.cv_project_confirmations
       add constraint cv_project_confirmations_one_per_confirmer
       unique (cv_project_id, confirmed_by);
     ```
  2. Put `is_space_proof` back to its original body (`p_confirmer is not null and …`), so nothing ever inserts null confirmer rows. The null branch you added only re-inserts rows that already exist.
- **Accepted side effect:** relinking a Space to another project (`set_space_project`) drops proof whose confirmer is gone.
- **Test:** two confirmers in two Spaces are purged one after the other. Check that:
  - both purges succeed;
  - M keeps 2 confirmation rows;
  - running `add_space_confirmations` again adds no duplicates.

### R2 (medium): a hidden sole admin can leave, and the Space then has no admin forever
- **What breaks:** H is hidden (deletion scheduled) and is the sole admin, and V is a visible member. `leave_space` passes because `is_space_admin(H)` is now false. The result is 0 admins and 1 active member. When H is purged later, the handover never runs, because H's row is no longer an admin row.
- **How it happens without a race:**
  1. Admin M schedules deletion while the other members are hidden.
  2. M is purged, and the handover makes the hidden member H admin.
  3. Another hidden member restores their account.
  4. H leaves.
- **Fix:** in `leave_space`, check the person's own membership row instead of `is_space_admin`. Keep the rest of the body:
  ```sql
  if exists (select 1 from public.space_members
             where space_id = p_space and profile_id = v_me
               and is_admin and left_at is null)
     and not public.has_other_admin(p_space, v_me) then
    raise exception 'a Space needs an admin' using errcode = 'P0001';
  end if;
  ```
- **Test:** a hidden sole admin with one visible member calls `leave_space`. The call must fail with P0001, and the Space must still have 1 admin.

### R3 (low): the deletion lock misses Spaces where the person is not yet admin
- **What breaks:** while Omar's deletion request is in flight, sole admin Rakesh runs `transfer_ownership(S, Omar)`. The transfer succeeds, and Omar ends up as the hidden sole admin of a Space with members. `set_member_admin(…, true)` has the same race.
- **Fix:** in `request_account_deletion`, lock every Space where the person is an **active member**: drop `and m.is_admin` from the lock subquery. The admin change then waits for the deletion to finish, sees that Omar is hidden, and refuses.
- **Test:** none is needed for the race itself. Keep the existing test showing that `transfer_ownership` to a hidden member fails.

### Your handover choice is accepted
When only hidden members remain, you make a hidden member admin. Keep that.
- **Rights:** they have no admin rights while hidden.
- **If they restore:** they become a real admin.
- **If they are purged:** the handover runs again, or the Space is deleted when nobody is left.
- **Why it can't stall:** with R1 and R2 fixed, every hidden admin either restores or is purged within about 30 days.

## Part 2 screens: pass
I checked Settings v2, S2, S5, S8, S10/S11, S12, S12b with transfer, S13, S14 and S15 against Figma, in English and Arabic.
- **Components row:** it appears only in debug builds (`kDebugMode`), so it's fine.
- **Help and feedback:** it reads the pack's `support_email` and hides the row when that is empty. The `support@example.com` in the screenshot came from local data, so it's fine.
- **S8 without Time format:** accepted.
- **S10 "we email you a file within 7 days":** accepted. The founder runs `supabase/ops/export_my_data.sql` by hand.
- **S13 (re-confirm by code):** this is untested end to end, because local email isn't set up. Test it on live after go-live (step 4 below).

## Go-live (each step with the founder's yes; stop and report after each)
1. **Storage foreign key.** On live, run:
   `select conname from pg_constraint where conrelid = 'storage.objects'::regclass and contype = 'f'`
   If `objects_owner_fkey` is there, report it and stop. Don't change it.
2. **Push migration 16.** The dry run must list only `20261013130000_account.sql`. If it lists anything else, stop and screenshot.
3. **Set the support address.** By SQL on live, set `support_email = 'support@aecox.com'` for **both packs (Kuwait and Egypt)**. The address is the same in every market. The legal URLs wait until the pages are hosted.
4. **S13 live test.** Use test account push-test-c:
   1. Open Delete account. The code email arrives (check the spam folder too).
   2. Enter the code. The account shows as scheduled.
   3. Restore it by signing in again.
   4. Report each step.
5. **Merge.** Merge `account-db`, then `account`, into main. Run `flutter analyze` and `flutter test`, push, and update `docs/progress.md`.

**Not yet:** don't deploy `account-purge` and don't run `account_cron.sql`. Each needs its own yes, closer to the pilot.

## Next
Part 3 is **Translate on posts** (review 23 §7).
- The founder must first create the Google Cloud Translation key: he follows the steps in review 23 §7 and pastes the key into Supabase secrets himself.
- Build the part with mocks until the key is set.
