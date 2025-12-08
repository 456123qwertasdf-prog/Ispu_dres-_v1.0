# Build and Copy APK to Web Public Folder
# This script builds the Flutter APK and copies it to the web public folder

Write-Host "🚀 Starting APK Build Process..." -ForegroundColor Cyan
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "mobile_app")) {
    Write-Host "❌ Error: mobile_app folder not found!" -ForegroundColor Red
    Write-Host "Please run this script from the lspu_dres directory" -ForegroundColor Yellow
    exit 1
}

# Step 1: Navigate to mobile app
Write-Host "📱 Step 1: Building Flutter APK..." -ForegroundColor Green
Set-Location mobile_app

# Step 2: Build the APK
Write-Host "⚙️  Running: flutter build apk --release" -ForegroundColor Yellow
flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error: Flutter build failed!" -ForegroundColor Red
    Set-Location ..
    exit 1
}

Write-Host "✅ APK built successfully!" -ForegroundColor Green
Write-Host ""

# Step 3: Copy APK to public folder
Set-Location ..
$sourcePath = "mobile_app\build\app\outputs\flutter-apk\app-release.apk"
$destPath = "public\lspu-emergency-response.apk"

if (Test-Path $sourcePath) {
    Write-Host "📦 Step 2: Copying APK to public folder..." -ForegroundColor Green
    Copy-Item $sourcePath $destPath -Force
    
    # Get file size
    $fileSize = (Get-Item $destPath).Length / 1MB
    $fileSizeFormatted = "{0:N2} MB" -f $fileSize
    
    Write-Host "✅ APK copied successfully!" -ForegroundColor Green
    Write-Host "📍 Location: $destPath" -ForegroundColor Cyan
    Write-Host "📊 Size: $fileSizeFormatted" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🎉 Done! Your APK is now available for download on the login page!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Start your web server if not already running" -ForegroundColor White
    Write-Host "2. Go to the login page" -ForegroundColor White
    Write-Host "3. Look for the green 'Download Android App' button" -ForegroundColor White
    Write-Host "4. Share the link with your users!" -ForegroundColor White
} else {
    Write-Host "❌ Error: APK file not found at $sourcePath" -ForegroundColor Red
    Write-Host "Make sure the build completed successfully" -ForegroundColor Yellow
    exit 1
}

