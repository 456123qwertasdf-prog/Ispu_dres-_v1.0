# 🎨 How to Change Your Mobile App Icon/Logo

## ✅ Setup Complete!

I've already configured your app to easily change icons using the `flutter_launcher_icons` package.

## 📱 Quick Start - Change Icon in 3 Steps

### Option 1: Use the Automation Script (Easiest!)

1. Place your new icon image (PNG, 1024x1024px recommended) in the mobile app folder
2. Run this command:

```powershell
cd lspu_dres\mobile_app
.\change-app-icon.ps1 -IconPath "path\to\your\icon.png"
```

### Option 2: Manual Method

**Step 1: Prepare Your Icon**
- Create or get a PNG image (1024x1024 pixels recommended)
- Name it `app_icon.png`
- Place it in `lspu_dres/mobile_app/assets/images/`

**Step 2: Generate the Icons**

```powershell
cd lspu_dres\mobile_app
flutter pub get
dart run flutter_launcher_icons
```

**Step 3: Rebuild Your APK**

```powershell
flutter build apk --release
copy build\app\outputs\flutter-apk\app-release.apk ..\public\lspu-emergency-response.apk
```

Done! 🎉

## 🎯 Using Your Current UDRRMO Logo

You already have `udrrmo-logo.jpg` in your assets. To use it:

```powershell
# Convert to PNG if needed (or just copy if it works)
copy assets\images\udrrmo-logo.jpg assets\images\app_icon.png

# Or if you want to use it directly, update pubspec.yaml:
# Change: image_path: "assets/images/app_icon.png"
# To: image_path: "assets/images/udrrmo-logo.jpg"

# Then generate icons
flutter pub get
dart run flutter_launcher_icons
```

## 🎨 Icon Requirements

### Recommended Specifications:
- **Format**: PNG (with transparency if needed)
- **Size**: 1024x1024 pixels (minimum)
- **Aspect Ratio**: Square (1:1)
- **File Size**: Under 1 MB
- **Background**: Can be transparent or solid color

### What Gets Generated:
The `flutter_launcher_icons` package will automatically create:
- ✅ Multiple sizes for different screen densities
- ✅ Adaptive icons for Android 8.0+ (with background color)
- ✅ Legacy icons for older Android versions
- ✅ All required mipmap folders

## 🔧 Advanced Configuration

Edit `pubspec.yaml` to customize:

```yaml
flutter_launcher_icons:
  android: true                              # Enable Android icon generation
  ios: false                                 # iOS icon generation (if needed)
  image_path: "assets/images/app_icon.png"  # Your icon file
  adaptive_icon_background: "#dc2626"        # Background color (red)
  adaptive_icon_foreground: "assets/images/app_icon.png"  # Foreground image
```

### Change Background Color:

The `adaptive_icon_background` uses hex colors:
- Red (Emergency): `#dc2626` (current)
- Blue (Professional): `#2563eb`
- Green (Safety): `#059669`
- Orange (Alert): `#ea580c`
- Custom: Any hex color code

## 📋 Icon Design Tips

### Best Practices:
1. **Keep it simple** - Small icons need clear, recognizable shapes
2. **High contrast** - Make sure the icon stands out
3. **No text** - Text becomes unreadable at small sizes
4. **Consistent style** - Match your app's theme
5. **Test on device** - Check how it looks on a real phone

### For Emergency Apps:
- Use red, orange, or yellow for urgency
- Include recognizable emergency symbols (siren, alert, shield)
- Make it instantly recognizable
- Ensure it works well on light and dark backgrounds

## 🖼️ Creating an Icon from Scratch

### Option 1: Use Online Tools
- [Canva](https://www.canva.com/) - Free design tool
- [Figma](https://www.figma.com/) - Professional design tool
- [IconKitchen](https://icon.kitchen/) - Android icon generator

### Option 2: Use Your Logo
If you have a logo:
1. Export as PNG at 1024x1024px
2. Ensure there's padding around the edges (about 10%)
3. Make background transparent or solid color
4. Save as `app_icon.png`

### Option 3: Hire a Designer
- Fiverr - $5-50 for app icons
- Upwork - Professional designers
- 99designs - Icon design contests

## 🔄 After Changing the Icon

1. **Clear old app data** (if testing):
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Regenerate icons**:
   ```bash
   dart run flutter_launcher_icons
   ```

3. **Rebuild APK**:
   ```bash
   flutter build apk --release
   ```

4. **Copy to public folder**:
   ```bash
   copy build\app\outputs\flutter-apk\app-release.apk ..\public\lspu-emergency-response.apk
   ```

5. **Test on device**: Install the new APK and check the icon on your home screen

## 📱 Icon Sizes Generated

The package automatically generates these sizes:
- mipmap-mdpi: 48x48px
- mipmap-hdpi: 72x72px
- mipmap-xhdpi: 96x96px
- mipmap-xxhdpi: 144x144px
- mipmap-xxxhdpi: 192x192px

## ❓ Troubleshooting

### Icon not changing?
1. Uninstall the old app completely
2. Rebuild and reinstall
3. Clear device cache

### Build errors?
```bash
flutter clean
flutter pub get
dart run flutter_launcher_icons
```

### Icon looks pixelated?
- Use a higher resolution source image (2048x2048px)
- Ensure the source is PNG, not JPEG
- Check that the image isn't being stretched

## 🎉 You're All Set!

Your app is now configured to easily change icons. Just replace the icon file and run the generation command whenever you want to update it!

---

**Need Help?** Let me know if you have any issues changing the icon!

