# The end-to-end journey (integration_test/main_journey_test.dart), on an
# emulator, against the LOCAL Supabase only. From the project folder:
#   powershell -File integration_test\run_e2e.ps1 [-Device emulator-5558]
#
# It wipes the local database (supabase db reset --local), loads
# supabase/dev/seed_e2e.sql, runs the test, then checks in the database that
# the journey really happened. Use an emulator that has no release app on it:
# the test installs a debug build, which can't sit beside the release one.

param(
  [string]$Device = "emulator-5558"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repo

$envFile = Join-Path $repo "env\local.json"
$cfg = Get-Content $envFile -Raw | ConvertFrom-Json
if ($cfg.SUPABASE_URL -notmatch '^http://(10\.0\.2\.2|127\.0\.0\.1|localhost):') {
  throw "env/local.json must point at the local Supabase, not $($cfg.SUPABASE_URL)"
}

supabase db reset --local
if ($LASTEXITCODE -ne 0) { throw "local reset failed" }
Get-Content -Raw "supabase\dev\seed_e2e.sql" |
  docker exec -i supabase_db_BuildVibes_MVP psql -U postgres -d postgres -q
if ($LASTEXITCODE -ne 0) { throw "seed failed" }

# The reset restarts the sign-in service: wait until it answers.
$health = ($cfg.SUPABASE_URL -replace '10\.0\.2\.2', '127.0.0.1') + "/auth/v1/health"
$ready = $false
for ($i = 0; $i -lt 60 -and -not $ready; $i++) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Headers @{ apikey = $cfg.SUPABASE_ANON_KEY } $health
    $ready = $r.StatusCode -eq 200
  } catch { Start-Sleep -Seconds 2 }
}
if (-not $ready) { throw "the local sign-in service didn't start" }

flutter test integration_test/main_journey_test.dart -d $Device `
  --dart-define-from-file=env/local.json
if ($LASTEXITCODE -ne 0) { throw "the journey failed on the emulator" }

# What the journey left behind, checked on the server.
$check = @"
select
  (select pass from public.space_members m join public.profiles p on p.id = m.profile_id
   where p.first_name = 'Rakesh' and m.left_at is null) as rakesh_pass,
  (select status from public.work_items where title = 'E2E rebar check level 3') as item,
  (select count(*) from public.work_item_events e join public.work_items w on w.id = e.work_item_id
   where w.title = 'E2E rebar check level 3') as item_events,
  (select count(*) from public.messages where body = 'E2E concrete at 7') as message,
  (select count(*) from public.posts where body = 'E2E first pour on the podium is done') as post,
  (select count(*) from storage.objects where bucket_id = 'space-files') as photos;
"@
$row = $check | docker exec -i supabase_db_BuildVibes_MVP psql -U postgres -d postgres -At -F ","
"rakesh_pass,item,item_events,message,post,photos = $row"
$parts = $row.Split(",")
if ($parts[0] -ne "crew" -or $parts[1] -ne "checked" -or [int]$parts[2] -lt 3 -or
    $parts[3] -ne "1" -or $parts[4] -ne "1" -or [int]$parts[5] -lt 1) {
  throw "the database doesn't show the whole journey"
}
"End-to-end journey passed."
