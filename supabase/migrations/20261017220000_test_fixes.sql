-- Migration 25: fixes from the founder's slice 1 test (review 51, Part F).
-- Branch test-fixes-db. Not live.
--
-- - F2: a reply can answer any reply on the post. Two levels stay on screen:
--   an answer to an answer is filed under the same top comment and keeps
--   the person answered (post_replies.reply_to_person), who gets the
--   post_reply notification (the post's author too, as before).
-- - F9: push tokens a phone hasn't confirmed for 30 days are dropped by
--   drop_stale_push_tokens(), for the nightly cleanup (service role). A token's
--   updated_at is already refreshed by register_push_token on every app start,
--   so it is the "last seen" time; no second column.

alter table public.post_replies add column reply_to_person uuid;
alter table public.post_replies add constraint post_replies_reply_to_person_fkey
  foreign key (reply_to_person) references public.profiles (id) on delete set null;
-- Replies made before this migration: the person answered is the top
-- comment's author.
update public.post_replies r set reply_to_person = t.author_id
from public.post_replies t
where t.id = r.reply_to and r.reply_to_person is null;

-- Replying: to any reply on the post, filed under its top comment, with the person answered (as in 20261012170000_feed.sql, with that change only).
CREATE OR REPLACE FUNCTION public.add_reply(p_id uuid, p_post uuid, p_reply_to uuid, p_body text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me uuid := auth.uid();
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_existing public.post_replies;
  v_target public.post_replies;
  v_under uuid;
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
  -- A reply answers any live reply on the same post. Two levels on screen:
  -- an answer to an answer is filed under the same top comment, and keeps
  -- the person answered (review 50 F2).
  if p_reply_to is not null then
    select * into v_target from public.post_replies r
    where r.id = p_reply_to and r.post_id = p_post
      and r.deleted_at is null and not public.is_blocked_with(r.author_id);
    if v_target.id is null then
      raise exception 'reply to a reply on this post' using errcode = '22023';
    end if;
    v_under := coalesce(v_target.reply_to, v_target.id);
  end if;
  perform pg_advisory_xact_lock(hashtextextended('reply:' || v_me::text, 0));
  if (select count(*) from public.post_replies r
      where r.author_id = v_me and r.created_at > now() - interval '1 hour') >= 60 then
    raise exception 'too many replies, wait a moment' using errcode = 'P0001';
  end if;
  insert into public.post_replies (id, post_id, author_id, reply_to, reply_to_person, body)
  values (p_id, p_post, v_me, v_under, v_target.author_id, v_body);
  return p_id;
end;
$function$;

-- Reply notifications: the person answered gets it (as in 20261012170000_feed.sql, with that change only).
CREATE OR REPLACE FUNCTION public.handle_post_reply_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_post_author uuid;
  v_reply_author uuid;
begin
  select author_id into v_post_author from public.posts where id = new.post_id;
  perform public.add_notification(v_post_author, 'post_reply', new.author_id,
    p_post => new.post_id, p_reply => new.id, p_payload => '{"to": "post"}');
  if new.reply_to is not null then
    -- The person answered, not always the top comment's author (review 50 F2).
    v_reply_author := coalesce(new.reply_to_person,
                               (select author_id from public.post_replies where id = new.reply_to));
    if v_reply_author is distinct from v_post_author then
      perform public.add_notification(v_reply_author, 'post_reply', new.author_id,
        p_post => new.post_id, p_reply => new.id, p_payload => '{"to": "reply"}');
    end if;
  end if;
  return null;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Push tokens nobody has confirmed for a while (F9)
-- ---------------------------------------------------------------------------

-- The app re-registers its token on every start, which refreshes updated_at.
-- A token not seen for p_age belongs to a phone that no longer runs the app.
create function public.drop_stale_push_tokens(p_age interval default interval '30 days')
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  if p_age is null or p_age < interval '7 days' then
    raise exception 'at least 7 days' using errcode = '22023';
  end if;
  delete from public.push_tokens t where t.updated_at < now() - p_age;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke execute on function public.drop_stale_push_tokens(interval) from public, anon, authenticated;
grant execute on function public.drop_stale_push_tokens(interval) to service_role;
