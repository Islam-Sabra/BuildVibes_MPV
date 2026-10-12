-- Migration 12: the feed (week 7 part 1). Brief: docs/reviews/2026-10-12-16-home-activity.md §2.
--
-- - Posts are public to every signed-in person ("Your network"), except
--   across a block (both ways) and once deleted. Muting a person takes
--   their posts out of the muter's feed only.
-- - A post has text and/or up to 4 photos, an optional project tag (a
--   project on the author's CV, confirmed and shown) and its language.
--   The text can be edited; photos and the tag can't.
-- - Replies, one level of "Replying to". Useful on posts and replies,
--   once per person. Nobody ever reads a count (rules §2): the proof line
--   names at most two people the viewer follows.
-- - Feed order: the viewer's home market from the last 30 days, newest
--   first; then every other post, newest first. No ranking, no follow
--   filter.
-- - Photos: private bucket "post-media", paths <author>/<post>/<file>.
-- Every write goes through a function; the app only reads.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.posts (
  -- Chosen by the app, so a retry never posts twice.
  id uuid primary key,
  author_id uuid not null references public.profiles (id) on delete cascade,
  -- Null once deleted, or for a photo-only post.
  body text check (body is null or length(body) between 1 and 3000),
  lang text not null check (lang in ('en', 'ar')),
  project_id uuid references public.projects (id) on delete set null,
  -- The author's home market when posting: the feed's first section.
  market_id text references public.markets (id),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);
create index posts_feed_idx on public.posts (created_at desc, id desc)
  where deleted_at is null;
create index posts_market_idx on public.posts (market_id, created_at desc, id desc)
  where deleted_at is null;
create index posts_author_idx on public.posts (author_id, created_at desc, id desc)
  where deleted_at is null;
create index posts_project_idx on public.posts (project_id, created_at desc, id desc)
  where deleted_at is null;

create table public.post_media (
  post_id uuid not null references public.posts (id) on delete cascade,
  storage_path text not null unique,
  sort smallint not null check (sort between 0 and 3),
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  primary key (post_id, sort)
);

create table public.post_replies (
  id uuid primary key,
  post_id uuid not null references public.posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  -- The reply this one answers ("Replying to {name}"), on the same post.
  reply_to uuid references public.post_replies (id) on delete set null,
  body text check (body is null or length(body) between 1 and 1000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((deleted_at is null) = (body is not null))
);
create index post_replies_post_idx on public.post_replies (post_id, created_at);
create index post_replies_author_idx on public.post_replies (author_id, created_at desc);

create table public.useful_marks (
  target_kind text not null check (target_kind in ('post', 'reply')),
  target_id uuid not null,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  -- Once per person.
  primary key (target_kind, target_id, profile_id)
);
create index useful_marks_profile_idx on public.useful_marks (profile_id);

create table public.mutes (
  muter_id uuid not null references public.profiles (id) on delete cascade,
  muted_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (muter_id, muted_id),
  check (muter_id <> muted_id)
);

-- ---------------------------------------------------------------------------
-- Who sees what
-- ---------------------------------------------------------------------------

-- A post the caller may see: not deleted, and no block either way.
create or replace function public.can_see_post(p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.posts p
    where p.id = p_post and p.deleted_at is null
      and (p.author_id = auth.uid() or not public.is_blocked_with(p.author_id)));
$$;

-- The project a tag shows: the project, or the one it was merged into;
-- null unless that one is active.
create or replace function public.shown_project(p_project uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p.status = 'active' then p.id
    when m.status = 'active' then m.id
  end
  from public.projects p
  left join public.projects m on m.id = p.merged_into
  where p.id = p_project;
$$;

-- The project is on the caller's CV, shown, with a confirmed role (C10).
create or replace function public.may_tag_project(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.cv_projects c
    join public.cv_project_confirmations k on k.cv_project_id = c.id
    where c.profile_id = auth.uid() and c.project_id = p_project
      and c.show_on_profile);
$$;

-- ---------------------------------------------------------------------------
-- Photos: bucket "post-media"
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-media', 'post-media', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

-- Upload: your own folder only, a sane daily amount.
create or replace function public.may_upload_post_media(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and split_part(p_name, '/', 1) = auth.uid()::text
    and array_length(string_to_array(p_name, '/'), 1) = 3
    and p_name not like '%..%'
    and (select count(*) from storage.objects o
         where o.bucket_id = 'post-media' and o.owner_id = auth.uid()::text
           and o.created_at > now() - interval '1 day') < 100;
$$;

-- Read: your own uploads, or a photo of a post you may see.
create or replace function public.may_read_post_media(p_name text, p_owner text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_owner = auth.uid()::text
    or exists (select 1 from public.post_media m
               where m.storage_path = p_name and public.can_see_post(m.post_id));
$$;

create policy post_media_read on storage.objects
  for select to authenticated
  using (bucket_id = 'post-media' and public.may_read_post_media(name, owner_id));
create policy post_media_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'post-media' and public.may_upload_post_media(name));
-- No update policy: a photo is never replaced. No delete for now; a
-- deleted post's photos stop being readable by anyone but their author.

-- ---------------------------------------------------------------------------
-- Writing
-- ---------------------------------------------------------------------------

-- C1/C2: text and/or up to 4 photos already uploaded to
-- <me>/<p_id>/, an optional project tag, the post's language. A retry
-- with the same id returns the same post.
create or replace function public.create_post(
  p_id uuid,
  p_body text,
  p_lang text,
  p_project uuid default null,
  p_media jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_count int := coalesce(jsonb_array_length(p_media), 0);
  v_existing public.posts;
  v_m jsonb;
  v_path text;
  v_n int := 0;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  select * into v_existing from public.posts where id = p_id;
  if v_existing.id is not null then
    if v_existing.author_id = v_me then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_body is null and v_count = 0 then
    raise exception 'write something or add a photo' using errcode = '22023';
  end if;
  if length(v_body) > 3000 then
    raise exception 'post too long' using errcode = '22023';
  end if;
  if v_count > 4 then
    raise exception 'at most 4 photos' using errcode = '22023';
  end if;
  if p_lang is null or p_lang not in ('en', 'ar') then
    raise exception 'choose the post language' using errcode = '22023';
  end if;
  if p_project is not null and not public.may_tag_project(p_project) then
    raise exception 'only projects where you have a confirmed role'
      using errcode = '42501';
  end if;
  if (select count(*) from public.posts p
      where p.author_id = v_me and p.created_at > now() - interval '1 day') >= 20 then
    raise exception 'too many posts today' using errcode = 'P0001';
  end if;
  for v_m in select * from jsonb_array_elements(coalesce(p_media, '[]'::jsonb)) loop
    v_path := v_m ->> 'path';
    if v_path is null
       or v_path not like v_me::text || '/' || p_id::text || '/%'
       or v_path like '%..%'
       or not exists (
         select 1 from storage.objects o
         where o.bucket_id = 'post-media' and o.name = v_path
           and o.owner_id = v_me::text
           and coalesce(o.metadata ->> 'mimetype', 'image/') like 'image/%') then
      raise exception 'photo not uploaded' using errcode = '22023';
    end if;
  end loop;

  insert into public.posts (id, author_id, body, lang, project_id, market_id)
  values (p_id, v_me, v_body, p_lang, p_project,
          (select home_market_id from public.profiles where id = v_me));
  for v_m in select * from jsonb_array_elements(coalesce(p_media, '[]'::jsonb)) loop
    insert into public.post_media (post_id, storage_path, sort, width, height)
    values (p_id, v_m ->> 'path', v_n,
            nullif(v_m ->> 'width', '')::int, nullif(v_m ->> 'height', '')::int);
    v_n := v_n + 1;
  end loop;
  return p_id;
end;
$$;

-- P2: the author changes the text and its language. Photos and the tag
-- stay; to change those, delete and post again.
create or replace function public.edit_post(p_id uuid, p_body text, p_lang text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post public.posts;
  v_body text := nullif(trim(coalesce(p_body, '')), '');
begin
  select * into v_post from public.posts where id = p_id for update;
  if v_post.id is null or v_post.author_id is distinct from auth.uid()
     or v_post.deleted_at is not null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_body is null and not exists (select 1 from public.post_media m where m.post_id = p_id) then
    raise exception 'write something or add a photo' using errcode = '22023';
  end if;
  if length(v_body) > 3000 then
    raise exception 'post too long' using errcode = '22023';
  end if;
  if p_lang is null or p_lang not in ('en', 'ar') then
    raise exception 'choose the post language' using errcode = '22023';
  end if;
  update public.posts set body = v_body, lang = p_lang, edited_at = now()
  where id = p_id;
end;
$$;

-- H11: the author deletes the post. Its text goes; its photos stop
-- showing; replies go with it.
create or replace function public.delete_post(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post public.posts;
begin
  select * into v_post from public.posts where id = p_id for update;
  if v_post.id is null or v_post.author_id is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_post.deleted_at is not null then
    return;
  end if;
  update public.posts set deleted_at = now(), body = null where id = p_id;
  delete from public.post_media where post_id = p_id;
end;
$$;

-- H10: a reply to a post, or to another reply on it ("Replying to"). A
-- retry with the same id returns the same reply.
create or replace function public.add_reply(
  p_id uuid,
  p_post uuid,
  p_reply_to uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_existing public.post_replies;
begin
  if v_me is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  select * into v_existing from public.post_replies where id = p_id;
  if v_existing.id is not null then
    if v_existing.author_id = v_me and v_existing.post_id = p_post then
      return v_existing.id;
    end if;
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.can_see_post(p_post) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_body is null or length(v_body) > 1000 then
    raise exception 'write a reply of up to 1000 characters' using errcode = '22023';
  end if;
  if p_reply_to is not null and not exists (
       select 1 from public.post_replies r
       where r.id = p_reply_to and r.post_id = p_post and r.deleted_at is null
         and not public.is_blocked_with(r.author_id)) then
    raise exception 'reply to a reply on this post' using errcode = '22023';
  end if;
  if (select count(*) from public.post_replies r
      where r.author_id = v_me and r.created_at > now() - interval '1 hour') >= 60 then
    raise exception 'too many replies, wait a moment' using errcode = 'P0001';
  end if;
  insert into public.post_replies (id, post_id, author_id, reply_to, body)
  values (p_id, p_post, v_me, p_reply_to, v_body);
  return p_id;
end;
$$;

-- H13/H14: the author deletes a reply.
create or replace function public.delete_reply(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reply public.post_replies;
begin
  select * into v_reply from public.post_replies where id = p_id for update;
  if v_reply.id is null or v_reply.author_id is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.post_replies set deleted_at = now(), body = null
  where id = p_id and deleted_at is null;
end;
$$;

-- Useful on a post or a reply: once per person, never your own.
create or replace function public.mark_useful(p_kind text, p_id uuid, p_on boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author uuid;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_kind = 'post' then
    if not public.can_see_post(p_id) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    select author_id into v_author from public.posts where id = p_id;
  elsif p_kind = 'reply' then
    select r.author_id into v_author from public.post_replies r
    where r.id = p_id and r.deleted_at is null
      and public.can_see_post(r.post_id) and not public.is_blocked_with(r.author_id);
    if v_author is null then
      raise exception 'not allowed' using errcode = '42501';
    end if;
  else
    raise exception 'post or reply' using errcode = '22023';
  end if;
  if v_author = auth.uid() then
    raise exception 'not on your own' using errcode = '22023';
  end if;
  if p_on then
    insert into public.useful_marks (target_kind, target_id, profile_id)
    values (p_kind, p_id, auth.uid())
    on conflict do nothing;
  else
    delete from public.useful_marks
    where target_kind = p_kind and target_id = p_id and profile_id = auth.uid();
  end if;
end;
$$;

-- H8: mute a person (their posts leave your feed only), or unmute.
create or replace function public.mute(p_person uuid, p_on boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or p_person is null or p_person = auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_on then
    insert into public.mutes (muter_id, muted_id) values (auth.uid(), p_person)
    on conflict do nothing;
  else
    delete from public.mutes where muter_id = auth.uid() and muted_id = p_person;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------

-- A post card: author, text, photos, the shown project, and whether the
-- caller marked it Useful. No counts. Row-level security applies (the
-- caller's own view).
create view public.post_cards
with (security_invoker = true) as
  select p.id,
         p.author_id,
         a.first_name as author_first_name,
         a.last_name as author_last_name,
         a.headline as author_headline,
         coalesce(co.name, a.company_name_text) as author_company,
         a.photo_path as author_photo,
         p.body,
         p.lang,
         sp.id as project_id,
         sp.name as project_name,
         sp.type_id as project_type_id,
         sp.place_id as project_place_id,
         sp.location_text as project_location,
         p.market_id,
         p.created_at,
         p.edited_at,
         coalesce((
           select jsonb_agg(jsonb_build_object('path', m.storage_path,
                    'width', m.width, 'height', m.height) order by m.sort)
           from public.post_media m where m.post_id = p.id), '[]'::jsonb) as media,
         exists (select 1 from public.useful_marks u
                 where u.target_kind = 'post' and u.target_id = p.id
                   and u.profile_id = auth.uid()) as my_useful
  from public.posts p
  join public.profiles a on a.id = p.author_id
  left join public.companies co on co.id = a.company_id
  left join public.projects sp on sp.id = public.shown_project(p.project_id);

-- The page after [p_cursor] ({"section", "created_at", "id"}), 20 posts:
-- the caller's home market from the last 30 days, then the rest
-- ("Beyond {market}"). Muted people and blocks left out.
create or replace function public.feed_page(p_cursor jsonb default null)
returns table (section text, post_id uuid, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_market text := (select home_market_id from public.profiles where id = v_me);
  v_since timestamptz := now() - interval '30 days';
  v_section text := coalesce(p_cursor ->> 'section', 'home');
  v_at timestamptz := (p_cursor ->> 'created_at')::timestamptz;
  v_id uuid := (p_cursor ->> 'id')::uuid;
  v_left int := 20;
  v_n int;
begin
  if v_me is null then
    return;
  end if;
  if v_section = 'home' then
    return query
      select 'home'::text, p.id, p.created_at
      from public.posts p
      where p.deleted_at is null
        and p.market_id is not distinct from v_market and p.created_at > v_since
        and (v_at is null or (p.created_at, p.id) < (v_at, v_id))
        and (p.author_id = v_me or not public.is_blocked_with(p.author_id))
        and not exists (select 1 from public.mutes mu
                        where mu.muter_id = v_me and mu.muted_id = p.author_id)
      order by p.created_at desc, p.id desc
      limit v_left;
    get diagnostics v_n = row_count;
    v_left := v_left - v_n;
    if v_left = 0 then
      return;
    end if;
    -- The home section ended: the rest starts from the top.
    v_at := null;
    v_id := null;
  end if;
  return query
    select 'beyond'::text, p.id, p.created_at
    from public.posts p
    where p.deleted_at is null
      and not (p.market_id is not distinct from v_market and p.created_at > v_since)
      and (v_at is null or (p.created_at, p.id) < (v_at, v_id))
      and (p.author_id = v_me or not public.is_blocked_with(p.author_id))
      and not exists (select 1 from public.mutes mu
                      where mu.muter_id = v_me and mu.muted_id = p.author_id)
    order by p.created_at desc, p.id desc
    limit v_left;
end;
$$;

-- R12/R16: a person's posts, 20 a page after [p_cursor] ({"created_at",
-- "id"}). You opened their profile, so a mute doesn't hide them here.
create or replace function public.posts_by(p_person uuid, p_cursor jsonb default null)
returns table (post_id uuid, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.created_at
  from public.posts p
  where p.author_id = p_person and p.deleted_at is null
    and (p_person = auth.uid() or not public.is_blocked_with(p_person))
    and (p_cursor is null
         or (p.created_at, p.id) < ((p_cursor ->> 'created_at')::timestamptz,
                                    (p_cursor ->> 'id')::uuid))
  order by p.created_at desc, p.id desc
  limit 20;
$$;

-- The project sheet's posts: tagged with the project, or with one that
-- was merged into it.
create or replace function public.posts_tagged(p_project uuid, p_cursor jsonb default null)
returns table (post_id uuid, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.created_at
  from public.posts p
  where public.shown_project(p.project_id) = p_project and p.deleted_at is null
    and (p.author_id = auth.uid() or not public.is_blocked_with(p.author_id))
    and (p_cursor is null
         or (p.created_at, p.id) < ((p_cursor ->> 'created_at')::timestamptz,
                                    (p_cursor ->> 'id')::uuid))
  order by p.created_at desc, p.id desc
  limit 20;
$$;

-- The proof line: at most two names of people the caller follows who
-- marked the post Useful. Never a count, for the author too.
create or replace function public.useful_names(p_post uuid)
returns table (name text)
language sql
stable
security definer
set search_path = ''
as $$
  select nullif(trim(coalesce(pr.first_name, '') || ' ' || coalesce(pr.last_name, '')), '')
  from public.useful_marks u
  join public.follows f on f.followee_id = u.profile_id and f.follower_id = auth.uid()
  join public.profiles pr on pr.id = u.profile_id
  where u.target_kind = 'post' and u.target_id = p_post
    and public.can_see_post(p_post)
    and not public.is_blocked_with(u.profile_id)
  order by u.created_at desc
  limit 2;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security and grants
-- ---------------------------------------------------------------------------

alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.post_replies enable row level security;
alter table public.useful_marks enable row level security;
alter table public.mutes enable row level security;

create policy posts_read on public.posts
  for select to authenticated
  using (deleted_at is null
         and (author_id = auth.uid() or not public.is_blocked_with(author_id)));
create policy post_media_rows_read on public.post_media
  for select to authenticated
  using (public.can_see_post(post_id));
create policy post_replies_read on public.post_replies
  for select to authenticated
  using (deleted_at is null and public.can_see_post(post_id)
         and (author_id = auth.uid() or not public.is_blocked_with(author_id)));
-- Only your own marks and mutes: whether you marked it, whom you muted.
create policy useful_marks_read_own on public.useful_marks
  for select to authenticated using (profile_id = auth.uid());
create policy mutes_read_own on public.mutes
  for select to authenticated using (muter_id = auth.uid());

revoke all on public.posts, public.post_media, public.post_replies,
  public.useful_marks, public.mutes, public.post_cards from anon, authenticated;
grant select on public.posts, public.post_media, public.post_replies,
  public.useful_marks, public.mutes, public.post_cards to authenticated;
grant all on public.posts, public.post_media, public.post_replies,
  public.useful_marks, public.mutes to service_role;

revoke execute on function
  public.can_see_post(uuid),
  public.shown_project(uuid),
  public.may_tag_project(uuid),
  public.may_upload_post_media(text),
  public.may_read_post_media(text, text),
  public.create_post(uuid, text, text, uuid, jsonb),
  public.edit_post(uuid, text, text),
  public.delete_post(uuid),
  public.add_reply(uuid, uuid, uuid, text),
  public.delete_reply(uuid),
  public.mark_useful(text, uuid, boolean),
  public.mute(uuid, boolean),
  public.feed_page(jsonb),
  public.posts_by(uuid, jsonb),
  public.posts_tagged(uuid, jsonb),
  public.useful_names(uuid)
  from public, anon;

grant execute on function
  -- Policies and the post_cards view call these as the signed-in user.
  public.can_see_post(uuid),
  public.shown_project(uuid),
  public.may_tag_project(uuid),
  public.may_upload_post_media(text),
  public.may_read_post_media(text, text),
  public.create_post(uuid, text, text, uuid, jsonb),
  public.edit_post(uuid, text, text),
  public.delete_post(uuid),
  public.add_reply(uuid, uuid, uuid, text),
  public.delete_reply(uuid),
  public.mark_useful(text, uuid, boolean),
  public.mute(uuid, boolean),
  public.feed_page(jsonb),
  public.posts_by(uuid, jsonb),
  public.posts_tagged(uuid, jsonb),
  public.useful_names(uuid)
  to authenticated;
