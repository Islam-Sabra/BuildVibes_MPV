-- Download my data (S10, S11): the founder's steps. Send within 7 days.
--
-- Run in the Supabase dashboard (SQL editor) for the BuildVibes MVP project,
-- one query at a time. Nothing here changes data except query 3.

-- 1. Open requests, oldest first, with the address to send to.
select r.id as request_id, r.created_at, u.email
from public.data_requests r
join auth.users u on u.id = r.profile_id
where r.status = 'open'
order by r.created_at;

-- 2. The person's data as one JSON value. Replace <request-id>, copy the
--    result into a file named buildvibes-data.json and email it to the
--    address from query 1 (from the support alias, never in a public post).
select public.export_my_data('<request-id>');

-- 3. After sending: mark it sent (S11 then shows it as sent).
select public.mark_data_sent('<request-id>');
