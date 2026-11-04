-- Migration 70 (review 103, D25, the founder, 4 Nov): Extract text stays
-- hidden until the Google trial starts (about 15 January 2027). The app
-- asks ocr_available() once a start and shows no button while it is false;
-- extract-text answers 503 not_set_up while it is false, even with a key.
-- To turn it on (PC, with the founder's yes), after GOOGLE_VISION_KEY is set:
--   update public.app_settings set value = 'true' where key = 'ocr_enabled';

insert into public.app_settings (key, value) values ('ocr_enabled', 'false'::jsonb)
on conflict (key) do nothing;

-- Whether Extract text is on; off when the row is missing.
create function public.ocr_available()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select s.value = 'true'::jsonb from public.app_settings s
                   where s.key = 'ocr_enabled'), false);
$$;
revoke all on function public.ocr_available() from public, anon;
grant execute on function public.ocr_available() to authenticated;
