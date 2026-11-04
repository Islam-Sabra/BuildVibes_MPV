-- Migration 71 (review 118 F3): a vote is acting. Deleting a poll would
-- erase other people's answers, so once anyone other than its creator has
-- voted, holding it offers Archive (post_hold) and delete_space_post refuses
-- it (both read post_has_action). The creator's own vote doesn't count.

-- post_has_action (review 113), as it was, and a poll's votes by others.
create or replace function public.post_has_action(p_post public.space_posts)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.post_has_others(p_post)
      or exists (select 1 from public.check_in_marks k where k.post_id = p_post.id)
      or exists (select 1 from public.poll_votes v
                 join public.poll_options o on o.id = v.option_id
                 where o.post_id = p_post.id and v.profile_id is distinct from p_post.author_id);
$$;
