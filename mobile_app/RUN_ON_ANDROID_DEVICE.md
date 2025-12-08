# 📱 Running LSPU DRES App on Physical Android Device

This guide will help you run the Flutter app on your physical Android device.

## ✅ Prerequisites

1. **Flutter SDK** installed and configured
2. **Android Studio** or Android SDK installed
3. **USB debugging enabled** on your Android device
4. **USB cable** to connect your device to your computer

## 🔧 Step 1: Enable Developer Options on Your Android Device

1. Open **Settings** on your Android device
2. Scroll down and tap **About phone** (or **About device**)
3. Find **Build number** and tap it **7 times**
4. You'll see a message saying "You are now a developer!"

## 📲 Step 2: Enable USB Debugging

1. Go back to **Settings**
2. Find **Developer options** (usually under System or Additional settings)
3. Toggle on **Developer options**
4. Enable **USB debugging**
5. Enable **Install via USB** (if available)

## 🔌 Step 3: Connect Your Device

1. Connect your Android device to your computer using a USB cable
2. On your device, you may see a popup asking "Allow USB debugging?" - tap **Allow** (check "Always allow" if you want)
3. On some devices, you may need to change USB mode to **File Transfer** or **MTP**

## ✅ Step 4: Verify Device Connection

Open a terminal/command prompt in the `mobile_app` directory and run:

```bash
flutter devices
```

You should see your device listed, for example:
```
2 connected devices:
SM-G973F (mobile) • R58M123456 • android-arm64 • Android 11 (API 30)
Chrome (web)      • chrome     • web-javascript • Google Chrome 120.0.0.0
```

If your device is not showing:
- Make sure USB debugging is enabled
- Try disconnecting and reconnecting the USB cable
- Check if USB drivers are installed (Windows users may need to install device-specific drivers)
- Try a different USB cable or USB port

## 🚀 Step 5: Run the App

From the `mobile_app` directory, run:

```bash
flutter run
```

Or to run on a specific device if multiple are connected:

```bash
flutter run -d <device-id>
```

Example:
```bash
flutter run -d R58M123456
```

## 📋 Alternative: Using ADB Directly

If `flutter devices` doesn't detect your device, you can check using ADB:

```bash
adb devices
```

If it shows "unauthorized", check your device and allow USB debugging.

## 🔍 Troubleshooting

### Device not detected?
1. **Check USB connection**: Try a different USB cable or port
2. **Install USB drivers**: Windows users may need device-specific drivers from manufacturer
3. **Revoke USB debugging**: In Developer options, tap "Revoke USB debugging authorizations" and reconnect
4. **Check USB mode**: Change to File Transfer/MTP mode in USB settings

### Build errors?
1. Make sure you're in the `mobile_app` directory
2. Run `flutter clean` and then `flutter pub get`
3. Check that all dependencies are installed: `flutter doctor`

### App crashes on launch?
1. Check device logs: `flutter logs` or `adb logcat`
2. Ensure minimum Android version is met (API level 21+)
3. Try `flutter clean` and rebuild

## 📱 Wireless Debugging (Android 11+)

For Android 11 and above, you can also use wireless debugging:

1. Connect device via USB first
2. Go to **Developer options** → **Wireless debugging**
3. Enable it and note the IP address and port
4. Run: `adb connect <IP>:<port>`
5. You can now disconnect USB and run wirelessly

## 🎯 Quick Commands Reference

```bash
# Check Flutter installation
flutter doctor

# Check connected devices
flutter devices

# Run the app
flutter run

# Run on specific device
flutter run -d <device-id>

# View logs
flutter logs

# Clean build
flutter clean
flutter pub get
```

## ✅ Success!

Once the app launches, you should see the LSPU DRES login screen on your device. The app will automatically reload when you save changes (hot reload)!

---

**Note**: Make sure your device and computer are on the same network if you plan to use hot reload over WiFi.

