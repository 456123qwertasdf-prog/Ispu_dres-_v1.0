# Script to push LSPU DRES v1.0 to GitHub
# This script will push to the existing Ispu_dres-_v1.0 repository

Write-Host "Pushing to GitHub repository: Ispu_dres-_v1.0" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: When prompted for credentials:" -ForegroundColor Yellow
Write-Host "  Username: 456123qwertasdf-prog" -ForegroundColor White
Write-Host "  Password: Enter your Personal Access Token (PAT)" -ForegroundColor White
Write-Host ""
Write-Host "If you haven't created a PAT yet, see GITHUB_AUTH_SETUP.md" -ForegroundColor Yellow
Write-Host ""

# Ensure we're on main branch
git branch -M main

# Push to GitHub
Write-Host "Pushing to GitHub..." -ForegroundColor Green
git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Successfully pushed to GitHub!" -ForegroundColor Green
    Write-Host "Repository URL: https://github.com/456123qwertasdf-prog/Ispu_dres-_v1.0" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "Push failed. Please check:" -ForegroundColor Red
    Write-Host "  1. You have created a Personal Access Token" -ForegroundColor Yellow
    Write-Host "  2. The repository exists on GitHub" -ForegroundColor Yellow
    Write-Host "  3. You have the correct permissions" -ForegroundColor Yellow
}

