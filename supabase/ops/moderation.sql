-- Moderation (review 23 §2): the founder's commands, run as the service
-- role (Supabase dashboard → SQL editor, or `supabase db query --linked`).
-- Each command is one step; run only the one you need, with the ids filled in.
-- The reported content is read here only, never in the alert email.

-- 1. Open reports, oldest first, with what was reported.
select r.id as report_id, r.created_at, r.target_kind, r.reason, r.note,
       case r.target_kind
         when 'post' then (select body from public.posts where id = r.target_id)
         when 'reply' then (select body from public.post_replies where id = r.target_id)
         when 'message' then (select body from public.messages where id = r.target_id)
         -- A direct message: only that message, never the thread (migration 22).
         when 'dm_message' then (select body from public.dm_messages where id = r.target_id)
         when 'profile' then (select first_name || ' ' || last_name from public.profiles where id = r.target_id)
       end as content,
       (select count(*) from public.reports o
        where o.target_kind = r.target_kind and o.target_id = r.target_id) as reports_on_it
from public.reports r
where r.status = 'open'
order by r.created_at;

-- 2a. Remove it (a post, reply or message). Every open report on it is
--     decided too, and the author gets R3 in Activity. The reason is
--     optional (default: the report's).
--     Note: a chat PDF that a work item uses stays visible after the
--     message is removed, as with an author's own delete. If it must go,
--     detach it from the work item by hand first (review 25).
-- select public.decide_report('<report_id>', 'remove', null);

-- 2b. Or dismiss it: nothing is removed.
-- select public.decide_report('<report_id>', 'dismiss');

-- 3. Open appeals.
select c.id as removal_id, c.target_kind, c.reason, c.removed_at, c.appeal_at, c.appeal_note,
       rc.body as removed_text
from public.content_removals c
left join public.removed_content rc on rc.removal_id = c.id
where c.appeal_status = 'open'
order by c.appeal_at;

-- 4. Decide an appeal: reverse brings the content back as it was; uphold
--    keeps it removed. The author hears either way.
-- select public.decide_appeal('<removal_id>', 'reverse');
-- select public.decide_appeal('<removal_id>', 'uphold');
