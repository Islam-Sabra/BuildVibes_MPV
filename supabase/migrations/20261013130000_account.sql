-- Migration 16: account (week 8 part 2). Brief: docs/reviews/2026-10-13-23-week8-brief.md §3 and §10.
--
-- - Deleting an account (founder decision, 4 Oct): hidden at once, restorable
--   for 30 days, then gone for good.
--   - request_account_deletion() needs a sign-in code entered in the last 10
--     minutes (S13: there are no passwords), and is refused while the person
--     is the only admin of a Space with other members (S12b lists them).
--   - While scheduled, the person is hidden from everyone else as a block
--     hides them: profile, posts, replies, follows, CV, shown work, people
--     search, Activity and pushes. Their phones are signed out (tokens go).
--     In Spaces their messages and work stay; their name can't be read, so
--     the app shows "Former member". Restoring brings everything back.
--   - After 30 days the Edge Function account-purge (supabase/functions/
--     account-purge, not deployed) deletes their avatar and post photos
--     through the Storage API, then purge_account() deletes the user. Their
--     own rows cascade; Space records keep them as "Former member" (set
--     null); the last-admin handover runs as for any member who goes.
-- - Download my data (S10, S11): one open request per person; the founder
--   exports it (export_my_data, supabase/ops/export_my_data.sql) and sends it
--   within 7 days.
-- - The market pack gets support_email; legal gains the account deletion
--   page next to Terms and Privacy. Values are set by the founder.
-- - Reports are kept 12 months after a decision (review 23 §10):
--   prune_reports(), run nightly by supabase/ops/account_cron.sql (not run).
-- - Review 26:
--   - M1: a hidden account is no Space admin: it doesn't count as another
--     admin, can't be made admin, and the handover passes it over.
--   - M2: a hidden account can't write (refuse_hidden_writer) until it is
--     restored.
--   - M3: proof stays when the admin who confirmed it is purged.
-- - Review 27: R1 several purged confirmers on one project; R2 a hidden sole
--   admin can't leave; R3 the deletion locks every Space the person is in.
--   - M4, L1: purge_account locks the profile and waits while photos remain.
--   - L2: a purged reporter's reports stay.
--   - L4: the export holds all of the person's own data.

-- ---------------------------------------------------------------------------
-- Tables and columns
-- ---------------------------------------------------------------------------

alter table public.profiles add column deletion_scheduled_at timestamptz;

-- legal (migration 1) also takes "delete_account": {"en": url, "ar": url},
-- the page the stores ask for.
alter table public.markets
  add column support_email text
    check (support_email is null or support_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$');

create table public.data_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'open' check (status in ('open', 'sent')),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  check ((status = 'sent') = (sent_at is not null))
);
-- At most one open request per person.
create unique index data_requests_one_open_idx on public.data_requests (profile_id)
  where status = 'open';

-- Review 26 M3: a confirmation outlives the admin who gave it ("Former
-- member" confirmed it). The foreign key keeps its name: the app embeds the
-- confirmer through it.
alter table public.cv_project_confirmations
  drop constraint cv_project_confirmations_pkey,
  drop constraint cv_project_confirmations_confirmed_by_fkey;
alter table public.cv_project_confirmations
  add column id uuid not null default gen_random_uuid() primary key,
  alter column confirmed_by drop not null,
  add constraint cv_project_confirmations_confirmed_by_fkey
    foreign key (confirmed_by) references public.profiles (id) on delete set null,
  -- Plain unique: several purged confirmers (null) may stay on one CV
  -- project (review 27 R1).
  add constraint cv_project_confirmations_one_per_confirmer
    unique (cv_project_id, confirmed_by);

-- Review 26 L2: a report stays when the person who made it is purged.
alter table public.reports
  drop constraint reports_reporter_id_fkey;
alter table public.reports
  alter column reporter_id drop not null,
  add constraint reports_reporter_id_fkey
    foreign key (reporter_id) references public.profiles (id) on delete set null;

-- ---------------------------------------------------------------------------
-- Hidden while scheduled: the block rules cover it
-- ---------------------------------------------------------------------------

-- True when [p_id]'s account is scheduled for deletion.
create or replace function public.is_hidden_account(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles p
                 where p.id = p_id and p.deletion_scheduled_at is not null);
$$;

-- Every read rule that hides a blocked person (profiles, follows, posts,
-- replies, photos, CV, experience, shown work, feed pages) now also hides a
-- person whose account is scheduled for deletion. Never yourself.
create or replace function public.is_blocked_with(other uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = other)
       or (b.blocker_id = other and b.blocked_id = auth.uid())
  )
  or (other is distinct from auth.uid() and public.is_hidden_account(other));
$$;

-- Activity, notifications and pushes: none to or from a hidden account.
create or replace function public.blocked_between(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks b
    where (b.blocker_id = p_a and b.blocked_id = p_b)
       or (b.blocker_id = p_b and b.blocked_id = p_a)
  )
  or (p_a is not null and public.is_hidden_account(p_a))
  or (p_b is not null and public.is_hidden_account(p_b));
$$;

-- The invite preview names who shared the code, unless they are hidden.
create or replace function public.invite_preview(p_code text)
returns table (space_name text, invited_by_name text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite public.space_invites;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if public.too_many_code_tries() then
    return;
  end if;
  v_invite := public.live_invite(p_code);
  if v_invite.id is null then
    insert into public.space_code_attempts (profile_id) values (auth.uid());
    return;
  end if;
  return query
  select s.name,
         case when public.is_hidden_account(v_invite.created_by) then null
              else nullif(trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
         end,
         v_invite.expires_at
  from public.spaces s
  left join public.profiles p on p.id = v_invite.created_by
  where s.id = v_invite.space_id;
end;
$$;

-- S7 lists only people you can still see.
create or replace function public.my_blocks()
returns table (profile_id uuid, first_name text, last_name text, headline text, blocked_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.first_name, p.last_name, p.headline, b.created_at
  from public.blocks b
  join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid() and p.deletion_scheduled_at is null
  order by b.created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Hidden accounts can't act (review 26 M1, M2)
-- ---------------------------------------------------------------------------

-- M2: nothing new is written by a hidden account until it is restored.
-- The purge runs without a signed-in user, so it isn't stopped.
create or replace function public.refuse_hidden_writer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and public.is_hidden_account(auth.uid()) then
    raise exception 'restore your account first' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger posts_hidden_writer before insert on public.posts
  for each row execute function public.refuse_hidden_writer();
create trigger post_replies_hidden_writer before insert on public.post_replies
  for each row execute function public.refuse_hidden_writer();
create trigger messages_hidden_writer before insert on public.messages
  for each row execute function public.refuse_hidden_writer();
create trigger follows_hidden_writer before insert on public.follows
  for each row execute function public.refuse_hidden_writer();
create trigger useful_marks_hidden_writer before insert on public.useful_marks
  for each row execute function public.refuse_hidden_writer();
create trigger work_items_hidden_writer before insert on public.work_items
  for each row execute function public.refuse_hidden_writer();
create trigger work_item_events_hidden_writer before insert on public.work_item_events
  for each row execute function public.refuse_hidden_writer();
create trigger library_files_hidden_writer before insert on public.library_files
  for each row execute function public.refuse_hidden_writer();
create trigger space_join_requests_hidden_writer before insert on public.space_join_requests
  for each row execute function public.refuse_hidden_writer();

-- M1: a hidden admin has no admin rights.
create or replace function public.is_space_admin(p_space uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.space_members m
    join public.spaces s on s.id = m.space_id
    where m.space_id = p_space and m.profile_id = auth.uid()
      and m.is_admin and m.left_at is null and s.deleted_at is null
  )
  and not public.is_hidden_account(auth.uid());
$$;

-- M1: a hidden admin isn't "another admin" (leave_space, set_member_admin).
create or replace function public.has_other_admin(p_space uuid, p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.space_members m
                 where m.space_id = p_space and m.profile_id <> p_profile
                   and m.is_admin and m.left_at is null
                   and not public.is_hidden_account(m.profile_id));
$$;

-- M1: when an admin goes, a hidden admin doesn't count, and the next admin
-- is someone who isn't hidden. A hidden member is chosen only when nobody
-- else is left (they may still restore); a Space left with no members is
-- deleted as before.
create or replace function public.handle_space_admin_gone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_next uuid;
begin
  if not old.is_admin or old.left_at is not null then
    return old;
  end if;
  perform 1 from public.spaces where id = old.space_id for update;
  if exists (select 1 from public.space_members m
             where m.space_id = old.space_id and m.is_admin and m.left_at is null
               and not public.is_hidden_account(m.profile_id)) then
    return old;
  end if;
  select m.profile_id into v_next from public.space_members m
  where m.space_id = old.space_id and m.left_at is null
  order by public.is_hidden_account(m.profile_id), (m.pass = 'lead') desc, m.confirmed_at
  limit 1;
  if v_next is null then
    update public.spaces set deleted_at = now()
    where id = old.space_id and deleted_at is null;
  else
    update public.space_members set is_admin = true
    where space_id = old.space_id and profile_id = v_next;
  end if;
  return old;
end;
$$;

-- M1: "Make admin" refuses a hidden person.
create or replace function public.set_member_admin(p_space uuid, p_profile uuid, p_admin boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- One change to a Space's admins at a time.
  perform 1 from public.spaces where id = p_space for update;
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform public.require_active_member(p_space, p_profile);
  if p_admin and public.is_hidden_account(p_profile) then
    raise exception 'this person can''t be made admin' using errcode = 'P0001';
  end if;
  if not p_admin and not public.has_other_admin(p_space, p_profile) then
    raise exception 'a Space needs an admin' using errcode = 'P0001';
  end if;
  update public.space_members set is_admin = p_admin
  where space_id = p_space and profile_id = p_profile;
end;
$$;

-- M1: S15d/e refuses a hidden person.
create or replace function public.transfer_ownership(p_space uuid, p_profile uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- One change to a Space's admins at a time.
  perform 1 from public.spaces where id = p_space for update;
  if not public.is_space_admin(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_profile = auth.uid() then
    raise exception 'choose someone else' using errcode = '22023';
  end if;
  perform public.require_active_member(p_space, p_profile);
  if public.is_hidden_account(p_profile) then
    raise exception 'this person can''t be made admin' using errcode = 'P0001';
  end if;
  update public.space_members set is_admin = true
  where space_id = p_space and profile_id = p_profile;
  update public.space_members set is_admin = false
  where space_id = p_space and profile_id = auth.uid();
end;
$$;

-- R2 (review 27): leaving is refused for the last admin by the person's own
-- membership row, not is_space_admin(): a hidden sole admin has no admin
-- rights but must not leave a Space with nobody to run it.
create or replace function public.leave_space(p_space uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
begin
  -- One change to a Space's admins at a time.
  perform 1 from public.spaces where id = p_space for update;
  if not public.is_member(p_space) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if exists (select 1 from public.space_members
             where space_id = p_space and profile_id = v_me
               and is_admin and left_at is null)
     and not public.has_other_admin(p_space, v_me) then
    raise exception 'a Space needs an admin' using errcode = 'P0001';
  end if;
  update public.space_members set left_at = now(), is_admin = false
  where space_id = p_space and profile_id = v_me;
  delete from public.team_members tm
  using public.teams t
  where t.id = tm.team_id and t.space_id = p_space and tm.profile_id = v_me;
end;
$$;

-- ---------------------------------------------------------------------------
-- Deleting and restoring (the app)
-- ---------------------------------------------------------------------------

-- S12b: the Spaces where you are the only admin and others are still in.
-- Transfer ownership (S15d) in each before deleting.
create or replace function public.account_deletion_blockers()
returns table (space_id uuid, space_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.name
  from public.space_members me
  join public.spaces s on s.id = me.space_id and s.deleted_at is null
  where me.profile_id = auth.uid() and me.is_admin and me.left_at is null
    and not exists (select 1 from public.space_members a
                    where a.space_id = me.space_id and a.is_admin and a.left_at is null
                      and a.profile_id <> auth.uid()
                      and not public.is_hidden_account(a.profile_id))
    and exists (select 1 from public.space_members o
                where o.space_id = me.space_id and o.left_at is null
                  and o.profile_id <> auth.uid()
                  and not public.is_hidden_account(o.profile_id))
  order by s.name;
$$;

-- True when this session entered a sign-in code in the last 10 minutes
-- (the "otp" entry of the token's amr claim): S13 asks for one first.
create or replace function public.signed_in_recently()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((
    select bool_or((a ->> 'method') = 'otp'
                   and (a ->> 'timestamp')::bigint >= extract(epoch from now())::bigint - 600)
    from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
  ), false);
$$;

-- S13 → S14: hide the account now; gone for good in 30 days. Returns when.
create or replace function public.request_account_deletion()
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_at timestamptz;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if not public.signed_in_recently() then
    raise exception 'enter the code we sent to your email first' using errcode = '42501';
  end if;
  -- Review 26 M1, review 27 R3: every Space the person is in, so two admins
  -- can't both pass the check, and nobody is made admin meanwhile. The
  -- same lock as every change to a Space's admins.
  perform 1 from public.spaces s
  where s.id in (select m.space_id from public.space_members m
                 where m.profile_id = v_me and m.left_at is null)
  order by s.id
  for update;
  if exists (select 1 from public.account_deletion_blockers()) then
    raise exception 'transfer your Spaces first' using errcode = 'P0001';
  end if;
  update public.profiles set deletion_scheduled_at = coalesce(deletion_scheduled_at, now())
  where id = v_me
  returning deletion_scheduled_at into v_at;
  -- Every phone stops getting pushes.
  delete from public.push_tokens where profile_id = v_me;
  return v_at + interval '30 days';
end;
$$;

-- S14: "Restore my account", within the 30 days.
create or replace function public.restore_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  update public.profiles set deletion_scheduled_at = null
  where id = auth.uid() and deletion_scheduled_at > now() - interval '30 days';
  if not found then
    raise exception 'nothing to restore' using errcode = 'P0001';
  end if;
end;
$$;

-- Your own account's state: null, or when it goes for good.
create or replace function public.my_account_deletion()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select deletion_scheduled_at + interval '30 days'
  from public.profiles where id = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- Download my data (the app, then the founder)
-- ---------------------------------------------------------------------------

-- S10 → S11. Asking again while one is open returns the same request.
create or replace function public.request_my_data()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  select id into v_id from public.data_requests
  where profile_id = auth.uid() and status = 'open';
  if v_id is null then
    insert into public.data_requests (profile_id) values (auth.uid())
    on conflict do nothing
    returning id into v_id;
    if v_id is null then
      select id into v_id from public.data_requests
      where profile_id = auth.uid() and status = 'open';
    end if;
  end if;
  return v_id;
end;
$$;

-- The founder (service role, supabase/ops/export_my_data.sql): one JSON
-- file of what the person wrote and set, then mark the request sent.
create or replace function public.export_my_data(p_request uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) - 'follower_count' - 'following_count'
                from public.profiles p where p.id = r.profile_id),
    'private', (select to_jsonb(pp) from public.profile_private pp where pp.id = r.profile_id),
    'experience', coalesce((select jsonb_agg(to_jsonb(e)) from public.experience e
                            where e.profile_id = r.profile_id), '[]'),
    'open_to', coalesce((select jsonb_agg(to_jsonb(o)) from public.profile_open_to o
                         where o.profile_id = r.profile_id), '[]'),
    'cv_projects', coalesce((select jsonb_agg(to_jsonb(c)) from public.cv_projects c
                             where c.profile_id = r.profile_id), '[]'),
    'following', coalesce((select jsonb_agg(f.followee_id) from public.follows f
                           where f.follower_id = r.profile_id), '[]'),
    'posts', coalesce((select jsonb_agg(jsonb_build_object(
                         'id', po.id, 'body', po.body, 'lang', po.lang,
                         'created_at', po.created_at, 'deleted_at', po.deleted_at))
                       from public.posts po where po.author_id = r.profile_id), '[]'),
    'replies', coalesce((select jsonb_agg(jsonb_build_object(
                           'id', pr.id, 'post_id', pr.post_id, 'body', pr.body,
                           'created_at', pr.created_at))
                         from public.post_replies pr where pr.author_id = r.profile_id), '[]'),
    'spaces', coalesce((select jsonb_agg(jsonb_build_object(
                          'space', s.name, 'pass', m.pass, 'admin', m.is_admin,
                          'joined_at', m.confirmed_at, 'left_at', m.left_at))
                        from public.space_members m join public.spaces s on s.id = m.space_id
                        where m.profile_id = r.profile_id), '[]'),
    'work_items_raised', coalesce((select jsonb_agg(jsonb_build_object(
                                     'ref', w.ref, 'title', w.title, 'status', w.status,
                                     'created_at', w.created_at))
                                   from public.work_items w where w.created_by = r.profile_id), '[]'),
    'work_items_owned', coalesce((select jsonb_agg(jsonb_build_object(
                                    'ref', w.ref, 'title', w.title, 'status', w.status,
                                    'checked_at', w.checked_at))
                                  from public.work_items w where w.owner_id = r.profile_id), '[]'),
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
                            'id', ms.id, 'kind', ms.kind, 'body', ms.body,
                            'created_at', ms.created_at))
                          from public.messages ms where ms.author_id = r.profile_id), '[]'),
    'work_item_notes', coalesce((select jsonb_agg(jsonb_build_object(
                                   'ref', w.ref, 'kind', e.kind, 'note', e.note,
                                   'created_at', e.created_at))
                                 from public.work_item_events e
                                 join public.work_items w on w.id = e.work_item_id
                                 where e.actor_id = r.profile_id and e.note is not null), '[]'),
    'library_files', coalesce((select jsonb_agg(jsonb_build_object(
                                 'space', s.name, 'name', f.name, 'created_at', f.created_at,
                                 'deleted_at', f.deleted_at))
                               from public.library_files f join public.spaces s on s.id = f.space_id
                               where f.uploaded_by = r.profile_id), '[]'),
    'blocked', coalesce((select jsonb_agg(jsonb_build_object(
                           'profile_id', b.blocked_id, 'created_at', b.created_at))
                         from public.blocks b where b.blocker_id = r.profile_id), '[]'),
    'muted', coalesce((select jsonb_agg(jsonb_build_object(
                         'profile_id', mu.muted_id, 'created_at', mu.created_at))
                       from public.mutes mu where mu.muter_id = r.profile_id), '[]'),
    'useful_marks', coalesce((select jsonb_agg(jsonb_build_object(
                                'target_kind', u.target_kind, 'target_id', u.target_id,
                                'created_at', u.created_at))
                              from public.useful_marks u where u.profile_id = r.profile_id), '[]'),
    'reports_made', coalesce((select jsonb_agg(jsonb_build_object(
                                'target_kind', rp.target_kind, 'reason', rp.reason, 'note', rp.note,
                                'status', rp.status, 'created_at', rp.created_at))
                              from public.reports rp where rp.reporter_id = r.profile_id), '[]'),
    'join_requests', coalesce((select jsonb_agg(jsonb_build_object(
                                 'space', s.name, 'via', j.via, 'status', j.status,
                                 'created_at', j.created_at))
                               from public.space_join_requests j join public.spaces s on s.id = j.space_id
                               where j.profile_id = r.profile_id), '[]'),
    'push_settings', (select to_jsonb(ps) from public.push_settings ps where ps.profile_id = r.profile_id)
  )
  from public.data_requests r
  where r.id = p_request;
$$;

create or replace function public.mark_data_sent(p_request uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.data_requests set status = 'sent', sent_at = now()
  where id = p_request and status = 'open';
$$;

-- ---------------------------------------------------------------------------
-- After 30 days, and the nightly cleanup (service role)
-- ---------------------------------------------------------------------------

-- Accounts due for removal, with their avatar and post photos (the
-- account-purge function deletes those through the Storage API first).
create or replace function public.accounts_due_for_purge()
returns table (profile_id uuid, bucket text, name text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, o.bucket_id, o.name
  from public.profiles p
  left join storage.objects o
    on o.bucket_id in ('avatars', 'post-media')
   and o.name collate "C" >= p.id::text || '/'
   and o.name collate "C" < p.id::text || '0'
  where p.deletion_scheduled_at < now() - interval '30 days'
  order by p.id;
$$;

-- Deletes the user. Their own rows cascade; Space records set null (shown
-- as "Former member"); the last-admin handover runs on their membership
-- rows. Only for an account still due, with the profile locked so a
-- restore can't slip in between (review 26 L1), and only once their
-- avatar and post photos are gone (M4: the function's list may have been
-- cut short; the rest go the next night).
create or replace function public.purge_account(p_id uuid)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform 1 from public.profiles
  where id = p_id and deletion_scheduled_at < now() - interval '30 days'
  for update;
  if not found then
    return false;
  end if;
  if exists (select 1 from storage.objects o
             where o.bucket_id in ('avatars', 'post-media')
               and o.name collate "C" >= p_id::text || '/'
               and o.name collate "C" < p_id::text || '0') then
    return false;
  end if;
  delete from auth.users where id = p_id;
  return true;
end;
$$;

-- Reports are kept 12 months after a decision, then deleted.
create or replace function public.prune_reports()
returns integer
language sql
volatile
security definer
set search_path = ''
as $$
  with gone as (
    delete from public.reports
    where status <> 'open' and decided_at < now() - interval '12 months'
    returning 1
  )
  select count(*)::int from gone;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security and grants
-- ---------------------------------------------------------------------------

alter table public.data_requests enable row level security;

-- Your own requests (S11).
create policy data_requests_read_own on public.data_requests
  for select to authenticated using (profile_id = auth.uid());

revoke all on public.data_requests from anon, authenticated;
grant select on public.data_requests to authenticated;
grant all on public.data_requests to service_role;

revoke execute on function
  public.refuse_hidden_writer(),
  public.is_hidden_account(uuid),
  public.account_deletion_blockers(),
  public.signed_in_recently(),
  public.request_account_deletion(),
  public.restore_account(),
  public.my_account_deletion(),
  public.request_my_data(),
  public.export_my_data(uuid),
  public.mark_data_sent(uuid),
  public.accounts_due_for_purge(),
  public.purge_account(uuid),
  public.prune_reports()
  from public, anon;
-- Internal (it answers about anyone), or the founder's and cron's only.
revoke execute on function
  public.refuse_hidden_writer(),
  public.is_hidden_account(uuid),
  public.export_my_data(uuid),
  public.mark_data_sent(uuid),
  public.accounts_due_for_purge(),
  public.purge_account(uuid),
  public.prune_reports()
  from authenticated;
grant execute on function
  public.account_deletion_blockers(),
  public.signed_in_recently(),
  public.request_account_deletion(),
  public.restore_account(),
  public.my_account_deletion(),
  public.request_my_data()
  to authenticated;
grant execute on function
  public.export_my_data(uuid),
  public.mark_data_sent(uuid),
  public.accounts_due_for_purge(),
  public.purge_account(uuid),
  public.prune_reports()
  to service_role;
