# Change Mobile App Icon Script
# This script automates changing the app icon and rebuilding the APK

param(
    [Parameter(Mandatory=$false)]
    [string]$IconPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseExisting
)

Write-Host "🎨 LSPU Emergency Response - Change App Icon" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "❌ Error: pubspec.yaml not found!" -ForegroundColor Red
    Write-Host "Please run this script from the mobile_app directory" -ForegroundColor Yellow
    exit 1
}

# Create assets/images directory if it doesn't exist
if (-not (Test-Path "assets\images")) {
    Write-Host "📁 Creating assets/images directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "assets\images" -Force | Out-Null
}

# Handle icon file
if ($UseExisting) {
    Write-Host "📱 Using existing app_icon.png..." -ForegroundColor Green
    if (-not (Test-Path "assets\images\app_icon.png")) {
        Write-Host "❌ Error: app_icon.png not found in assets/images/" -ForegroundColor Red
        Write-Host "Please add your icon file first or use -IconPath parameter" -ForegroundColor Yellow
        exit 1
    }
} elseif ($IconPath) {
    # Copy the provided icon
    if (-not (Test-Path $IconPath)) {
        Write-Host "❌ Error: Icon file not found at: $IconPath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "📋 Copying icon file..." -ForegroundColor Green
    Copy-Item $IconPath "assets\images\app_icon.png" -Force
    Write-Host "✅ Icon copied to assets/images/app_icon.png" -ForegroundColor Green
} else {
    # Check if udrrmo-logo.jpg exists
    if (Test-Path "assets\images\udrrmo-logo.jpg") {
        Write-Host "📱 Found udrrmo-logo.jpg - using it as app icon..." -ForegroundColor Green
        Copy-Item "assets\images\udrrmo-logo.jpg" "assets\images\app_icon.png" -Force
        Write-Host "✅ Using UDRRMO logo as app icon" -ForegroundColor Green
    } else {
        Write-Host "❌ Error: No icon file specified!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  .\change-app-icon.ps1 -IconPath 'path\to\icon.png'" -ForegroundColor White
        Write-Host "  .\change-app-icon.ps1 -UseExisting" -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

Write-Host ""

# Step 1: Get dependencies
Write-Host "📦 Step 1: Getting Flutter dependencies..." -ForegroundColor Cyan
flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error: Failed to get dependencies!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Dependencies updated" -ForegroundColor Green
Write-Host ""

# Step 2: Generate launcher icons
Write-Host "🎨 Step 2: Generating launcher icons..." -ForegroundColor Cyan
dart run flutter_launcher_icons

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error: Failed to generate icons!" -ForegroundColor Red
    Write-Host "Make sure flutter_launcher_icons is in your pubspec.yaml" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Launcher icons generated" -ForegroundColor Green
Write-Host ""

# Step 3: Build APK (optional)
if (-not $SkipBuild) {
    Write-Host "🔨 Step 3: Building release APK..." -ForegroundColor Cyan
    Write-Host "(This may take a few minutes...)" -ForegroundColor Yellow
    flutter build apk --release

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error: Failed to build APK!" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ APK built successfully" -ForegroundColor Green
    Write-Host ""

    # Step 4: Copy to public folder
    $sourcePath = "build\app\outputs\flutter-apk\app-release.apk"
    $destPath = "..\public\lspu-emergency-response.apk"

    if (Test-Path $sourcePath) {
        Write-Host "📦 Step 4: Copying APK to public folder..." -ForegroundColor Cyan
        
        # Create public directory if it doesn't exist
        $publicDir = Split-Path $destPath -Parent
        if (-not (Test-Path $publicDir)) {
            New-Item -ItemType Directory -Path $publicDir -Force | Out-Null
        }
        
        Copy-Item $sourcePath $destPath -Force
        
        # Get file size
        $fileSize = (Get-Item $destPath).Length / 1MB
        $fileSizeFormatted = "{0:N2} MB" -f $fileSize
        
        Write-Host "✅ APK copied successfully" -ForegroundColor Green
        Write-Host "📍 Location: $destPath" -ForegroundColor Cyan
        Write-Host "📊 Size: $fileSizeFormatted" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️  Warning: APK file not found at $sourcePath" -ForegroundColor Yellow
    }
} else {
    Write-Host "⏭️  Skipping APK build (use without -SkipBuild to build)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 App icon changed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Check assets/images/app_icon.png to verify your icon" -ForegroundColor White
Write-Host "2. Look in android/app/src/main/res/mipmap-* folders for generated icons" -ForegroundColor White

if (-not $SkipBuild) {
    Write-Host "3. Install the new APK on your device to see the new icon" -ForegroundColor White
    Write-Host "4. Users can download it from your login page!" -ForegroundColor White
} else {
    Write-Host "3. Run this script again without -SkipBuild to build the APK" -ForegroundColor White
}

Write-Host ""
Write-Host "💡 Tip: If the icon doesn't change, uninstall the old app first!" -ForegroundColor Cyan

