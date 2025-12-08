# Emergency Sound Alert Setup

## Overview
The mobile app now supports emergency sound alerts! When a super user or admin creates an emergency announcement, the app will automatically play an alert sound on Android devices to notify users/citizens.

## What Was Added

### 1. Audio Package
- Added `audioplayers: ^6.1.0` package to `pubspec.yaml` for sound playback

### 2. Emergency Sound Service
- Created `lib/services/emergency_sound_service.dart`
- Handles playing emergency alert sounds
- Plays sound 3 times to ensure users notice it
- Singleton pattern for efficient resource management

### 3. Integration Points
- **Home Screen**: Plays sound when emergency alert is received via realtime subscription
- **Map Screen**: Plays sound when emergency announcement is received on the map view

### 4. Assets Configuration
- Added `assets/sounds/` directory to `pubspec.yaml`
- Created README in `assets/sounds/README.md` with instructions

## Setup Instructions

### Step 1: Add the Sound File
You need to add an emergency alert sound file:

1. **Download or create** an emergency alert sound file (MP3 format recommended)
2. **Name it**: `emergency_alert.mp3`
3. **Place it in**: `mobile_app/assets/sounds/emergency_alert.mp3`

**Recommended sources for free emergency sounds:**
- [Freesound.org](https://freesound.org) - Search for "emergency alert" or "alarm"
- [Zapsplat](https://www.zapsplat.com) - Free sound effects
- [Pixabay](https://pixabay.com/sound-effects/) - Free sound effects

**Sound characteristics:**
- Duration: 1-2 seconds (will repeat 3 times automatically)
- Format: MP3 (recommended) or other formats supported by audioplayers
- Volume: Should be loud and attention-grabbing

### Step 2: Install Dependencies
Run the following command in the `mobile_app` directory:

```bash
flutter pub get
```

### Step 3: Rebuild the App
Rebuild the app to include the new dependencies and assets:

```bash
flutter run
```

Or build a new APK:

```bash
flutter build apk
```

## How It Works

1. **Admin/Super User creates emergency announcement:**
   - Admin goes to the announcements panel
   - Creates a new announcement with type "emergency"
   - Sets status to "active"

2. **App receives the alert:**
   - The app listens for new announcements via Supabase Realtime
   - When an emergency announcement is detected, it triggers the sound

3. **Sound plays automatically:**
   - The emergency sound plays 3 times
   - Visual alerts (snackbar, dialog) are also shown
   - Works even if the app is in the foreground

## Testing

To test the emergency sound feature:

1. **Add the sound file** (see Step 1 above)
2. **Run the app** on an Android device or emulator
3. **As a super user/admin**, create an emergency announcement:
   - Go to announcements panel
   - Create new announcement
   - Set type to "emergency"
   - Set status to "active"
   - Save
4. **On the user/citizen device**, the sound should play automatically

## Troubleshooting

### No sound plays
- **Check file exists**: Verify `assets/sounds/emergency_alert.mp3` exists
- **Check file name**: Must be exactly `emergency_alert.mp3`
- **Check device volume**: Ensure device volume is not muted
- **Check pubspec.yaml**: Verify assets section includes `- assets/sounds/`
- **Rebuild app**: Run `flutter clean` then `flutter pub get` and rebuild

### Sound file not found error
- Verify the file path in `pubspec.yaml` matches the actual file location
- Make sure you ran `flutter pub get` after adding the file
- Rebuild the app completely

### Sound plays but is too quiet
- The sound service sets volume to maximum (1.0)
- Check device volume settings
- Consider using a louder sound file

### Sound doesn't play on Android
- Ensure device is not in silent/Do Not Disturb mode
- Check app permissions (though audio playback doesn't require special permissions)
- Verify the audioplayers package is properly installed

## Technical Details

### Files Modified
- `pubspec.yaml` - Added audioplayers package and sounds assets
- `lib/services/emergency_sound_service.dart` - New service for sound playback
- `lib/screens/home_screen.dart` - Integrated sound service
- `lib/screens/map_simulation_screen.dart` - Integrated sound service

### Android Permissions
No additional Android permissions are required. The `audioplayers` package handles audio playback automatically.

### Sound Service Features
- **Singleton pattern**: Only one instance manages all sound playback
- **Prevents overlapping**: Won't play multiple sounds simultaneously
- **Error handling**: Gracefully handles missing sound files
- **Volume control**: Sets volume to maximum for emergency alerts

## Future Enhancements

Possible improvements:
- Allow users to customize the alert sound
- Add vibration along with sound
- Support for different alert types (weather, general, etc.)
- Sound settings/preferences screen

