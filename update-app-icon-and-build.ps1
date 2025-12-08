# One-Click: Update App Icon and Build APK
# This script does everything in one go!

Write-Host "🚀 One-Click App Icon Update & Build" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "mobile_app")) {
    Write-Host "❌ Error: mobile_app folder not found!" -ForegroundColor Red
    Write-Host "Please run this script from the lspu_dres directory" -ForegroundColor Yellow
    exit 1
}

# Navigate to mobile app
Set-Location mobile_app

Write-Host "🎨 Using UDRRMO logo as app icon..." -ForegroundColor Green
Write-Host ""

# Run the change icon script
.\change-app-icon.ps1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Something went wrong!" -ForegroundColor Red
    Set-Location ..
    exit 1
}

Set-Location ..

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "🎉 ALL DONE! Your app has a new icon!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ App icon changed to UDRRMO logo" -ForegroundColor Green
Write-Host "✅ APK built with new icon" -ForegroundColor Green
Write-Host "✅ APK copied to public/lspu-emergency-response.apk" -ForegroundColor Green
Write-Host "✅ Ready for download on login page!" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Your users can now download the updated app from the login page!" -ForegroundColor Cyan

