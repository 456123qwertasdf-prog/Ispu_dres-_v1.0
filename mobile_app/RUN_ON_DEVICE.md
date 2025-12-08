# 📱 Running on Physical Android Device

This guide will help you run the LSPU DRES mobile app on your physical Android device.

## Prerequisites

1. **Flutter SDK** - Make sure Flutter is installed and set up
   ```bash
   flutter doctor
   ```

2. **Android Studio** or **Android SDK** installed

3. **USB Cable** to connect your Android device to your computer

4. **Physical Android Device** with:
   - Android 5.0 (API level 21) or higher
   - USB Debugging enabled

## Step-by-Step Instructions

### Step 1: Enable Developer Options on Your Android Device

1. Go to **Settings** → **About phone**
2. Find **Build number** (might be under "Software information")
3. Tap **Build number** **7 times** until you see "You are now a developer!"

### Step 2: Enable USB Debugging

1. Go back to **Settings**
2. Find **Developer options** (usually under System or Advanced)
3. Enable **USB debugging**
4. Enable **Install via USB** (if available)
5. Optionally enable **Stay awake** (to keep screen on while charging)

### Step 3: Connect Your Device

1. Connect your Android device to your computer using a USB cable
2. On your device, when prompted, tap **"Allow USB debugging"** and check **"Always allow from this computer"**
3. Tap **OK**

### Step 4: Verify Device Connection

Open terminal/PowerShell in the `mobile_app` directory and run:

```bash
flutter devices
```

You should see your Android device listed. Example:
```
SM-G991B (mobile) • RF8R90ABC123 • android-arm64 • Android 12 (API 31)
```

If your device doesn't appear:
- Make sure USB debugging is enabled
- Try a different USB cable (some cables are charge-only)
- Check if your device driver is installed (Windows)
- Try revoking USB debugging authorizations and reconnect

### Step 5: Run the App

From the `mobile_app` directory, run:

```bash
flutter run
```

Or specify your device explicitly:

```bash
flutter run -d <device-id>
```

Replace `<device-id>` with your device ID from `flutter devices` command.

### Step 6: Wait for Build and Install

- Flutter will build the app (this may take a few minutes the first time)
- The app will be installed on your device automatically
- The app will launch automatically

## Troubleshooting

### Device Not Detected

**Windows:**
1. Install Android USB drivers for your device
2. Open Device Manager and check if your device appears under "Portable Devices" or "Other devices"
3. If there's a yellow warning, install the appropriate driver

**macOS/Linux:**
Usually works out of the box. If not:
```bash
# macOS
brew install android-platform-tools

# Linux (Ubuntu/Debian)
sudo apt-get install android-tools-adb
```

### Build Errors

If you encounter build errors:

1. **Clean the project:**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Check Flutter doctor:**
   ```bash
   flutter doctor -v
   ```

3. **Update dependencies:**
   ```bash
   flutter pub upgrade
   ```

### App Crashes on Launch

- Check device logs:
  ```bash
  flutter logs
  ```
- Make sure your device has sufficient storage
- Ensure Android version is 5.0+ (API 21+)

### Permission Issues

The app requests internet permissions automatically. For location features, ensure:
- Location services are enabled on your device
- App permissions are granted when prompted

## Hot Reload & Development

Once the app is running:

- Press **`r`** in the terminal for hot reload
- Press **`R`** for hot restart
- Press **`q`** to quit

## Building Release APK (Optional)

To build an APK you can install manually:

```bash
flutter build apk
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

## Wireless Debugging (Android 11+)

If you prefer wireless debugging:

1. Connect device via USB first
2. Run: `adb tcpip 5555`
3. Disconnect USB
4. Run: `adb connect <device-ip-address>:5555`
   - Find IP address: Settings → About phone → Status → IP address
5. Now run `flutter run` wirelessly

---

**Need help?** Check [Flutter's official documentation](https://docs.flutter.dev/get-started/install) or run `flutter doctor` to diagnose issues.

