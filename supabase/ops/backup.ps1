# Backup of the live database (review 30 §4). The Supabase free plan has
# no backups of its own.
#
# Run from the project folder, weekly and before every live migration:
#   powershell -File supabase\ops\backup.ps1
# It writes D:\BuildVibes backups\YYYY-MM-DD\ (or the folder you pass with
# -Folder): roles.sql, schema.sql and data.sql. The folder must be outside
# the repo. Never put a backup in git or upload it anywhere: it holds
# everyone's data.
#
# Photos and files in Storage are not in the dump (accepted for the pilot).
# To restore: supabase/ops/restore_check.md.

param(
  [string]$Folder = "D:\BuildVibes backups"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$target = Join-Path $Folder (Get-Date -Format "yyyy-MM-dd")
$full = [System.IO.Path]::GetFullPath($target)
if ($full.StartsWith($repo, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "The backup folder must be outside the repo: $full"
}
New-Item -ItemType Directory -Force $full | Out-Null

Push-Location $repo
try {
  supabase db dump --linked --role-only -f (Join-Path $full "roles.sql")
  if ($LASTEXITCODE -ne 0) { throw "roles dump failed" }
  supabase db dump --linked -f (Join-Path $full "schema.sql")
  if ($LASTEXITCODE -ne 0) { throw "schema dump failed" }
  supabase db dump --linked --data-only --use-copy -f (Join-Path $full "data.sql")
  if ($LASTEXITCODE -ne 0) { throw "data dump failed" }
} finally {
  Pop-Location
}

# Sizes only: the files themselves hold personal data.
Get-ChildItem $full -Filter *.sql | ForEach-Object {
  "{0,-12} {1,10:N0} KB" -f $_.Name, ($_.Length / 1KB)
}
"Backup written to $full"
