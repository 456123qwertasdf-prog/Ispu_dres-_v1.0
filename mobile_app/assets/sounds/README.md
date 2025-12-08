# Emergency Sound File

## Adding the Emergency Alert Sound

To enable emergency alert sounds in the mobile app, you need to add an audio file named `emergency_alert.mp3` to this directory.

### Requirements:
- **File name**: `emergency_alert.mp3`
- **Format**: MP3 (recommended) or other formats supported by audioplayers package
- **Location**: `assets/sounds/emergency_alert.mp3`
- **Recommended duration**: 1-2 seconds (will be played 3 times automatically)

### Where to Get Emergency Alert Sounds:

1. **Free sound libraries:**
   - [Freesound.org](https://freesound.org) - Search for "emergency alert" or "alarm"
   - [Zapsplat](https://www.zapsplat.com) - Free sound effects
   - [Pixabay](https://pixabay.com/sound-effects/) - Free sound effects

2. **System sounds:**
   - You can use Android system notification sounds
   - Extract from Android system files (requires root access)

3. **Create your own:**
   - Use audio editing software like Audacity
   - Record or generate an alert tone

### Recommended Sound Characteristics:
- **Loud and attention-grabbing**: Should be clearly audible even in noisy environments
- **Distinctive**: Should be easily recognizable as an emergency alert
- **Not too long**: 1-2 seconds is ideal (will repeat 3 times)
- **Clear frequency range**: Should work well on mobile device speakers

### Example Search Terms:
- "emergency alert"
- "alarm sound"
- "warning beep"
- "siren short"
- "alert tone"

### After Adding the File:

1. Make sure the file is named exactly: `emergency_alert.mp3`
2. The file is already registered in `pubspec.yaml` under assets
3. Run `flutter pub get` to refresh dependencies
4. Rebuild the app: `flutter run` or build a new APK

### Testing:

After adding the sound file, test it by:
1. Having an admin/super user create an emergency announcement
2. The sound should play automatically when the alert is received
3. The sound will play 3 times to ensure users notice it

### Troubleshooting:

- **No sound plays**: Check that the file exists and is named correctly
- **Sound doesn't play on Android**: Ensure device volume is not muted
- **File not found error**: Verify the file path in `pubspec.yaml` matches the actual file location

