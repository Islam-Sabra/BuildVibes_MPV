-- Review 103, D25: Extract text stays hidden until the founder starts the
-- Google trial. app_settings 'ocr_enabled' (false at first) is read by
-- ocr_available(), signed-in callers only; one SQL line turns it on.
-- Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select is((select value from public.app_settings where key = 'ocr_enabled'), 'false'::jsonb,
  'the flag is there, off');
select ok(not has_function_privilege('anon', 'public.ocr_available()', 'execute'),
  'the signed out can''t ask');
select ok(has_function_privilege('authenticated', 'public.ocr_available()', 'execute'),
  'a signed-in person can');

select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000073", "role": "authenticated"}', true);
set local role authenticated;
select is(public.ocr_available(), false, 'off by default');
reset role;

update public.app_settings set value = 'true' where key = 'ocr_enabled';
set local role authenticated;
select is(public.ocr_available(), true, 'on after the one SQL line');
reset role;

delete from public.app_settings where key = 'ocr_enabled';
set local role authenticated;
select is(public.ocr_available(), false, 'no row: off');
reset role;

select * from finish();
rollback;
