# Remove git lock and sync with remote. Run this in PowerShell *outside* Cursor
# (e.g. Windows PowerShell or Terminal) after closing Cursor if the lock is held.

$repo = "c:\Users\Ducay\Music\lspu_dres _v1.0"
$lock = Join-Path $repo ".git\index.lock"

Set-Location $repo

if (Test-Path $lock) {
  Remove-Item -Force $lock -ErrorAction SilentlyContinue
  if (Test-Path $lock) {
    Write-Host "Lock still held. Close Cursor and any Git apps, then run this script again."
    exit 1
  }
  Write-Host "Removed .git\index.lock"
}

git fetch origin main
git merge origin/main --no-edit
git push
Write-Host "Done."
