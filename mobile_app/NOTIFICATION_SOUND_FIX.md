# Notification Sound Fix Guide

## Problem
The notification sound is still playing the default "drop of water" sound instead of the custom emergency sound.

## Solution

### Step 1: Rebuild and Reinstall the App
The notification channel is created in `MainActivity.kt` when the app starts. You MUST:

1. **Clean and rebuild the app:**
   ```bash
   cd mobile_app
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Open the app at least once** - This creates the `emergency_alerts` channel on the device

3. **Close the app completely** (not just minimize)

### Step 2: Verify the Channel Exists
After opening the app, the channel should be created. You can verify by:
- Going to Android Settings > Apps > Your App > Notifications
- You should see "Emergency Alerts" channel listed

### Step 3: Test the Notification
1. Send an emergency notification
2. The custom sound should play

## If It Still Doesn't Work

### Option A: Check for "Could not find android_channel_id" Error
If you see this error in the Supabase logs, it means:
- The app hasn't been opened yet (channel doesn't exist)
- OR the channel ID doesn't match exactly

**Fix:** Make sure:
- The channel ID in `MainActivity.kt` is exactly `"emergency_alerts"` (line 36)
- The channel ID in `onesignal-send/index.ts` is exactly `"emergency_alerts"` (line 132)
- The app has been opened at least once after installation

### Option B: Use Manual Sound Playback (Fallback)
If the channel approach doesn't work, the app will automatically play the sound manually when:
- A notification is clicked (foreground)
- The app is opened after receiving a notification

This is handled by `NotificationSoundService` which uses platform channels to play the sound directly.

## Current Configuration

### Files Modified:
1. **MainActivity.kt** - Creates notification channel with custom sound
2. **onesignal-send/index.ts** - Sends `android_channel_id: "emergency_alerts"` for emergency notifications
3. **notification_sound_service.dart** - Manually plays sound as fallback
4. **onesignal_service.dart** - Plays sound when notifications are clicked

### Sound File Location:
- `android/app/src/main/res/raw/emergency_alert.mp3`
- Protected by `keep.xml` to prevent removal during build

## Testing Checklist

- [ ] App rebuilt with latest changes
- [ ] App opened at least once (to create channel)
- [ ] Sound file exists in `res/raw/emergency_alert.mp3`
- [ ] `keep.xml` exists in `res/raw/`
- [ ] Notification sound toggle is accessible in app
- [ ] Emergency notification sent
- [ ] Custom sound plays (not default sound)

## Troubleshooting

### Still hearing default sound?
1. Check Supabase logs for errors
2. Verify channel exists in Android settings
3. Try uninstalling and reinstalling the app
4. Check that `android_channel_id` is being sent in the payload (check Supabase logs)

### "Could not find android_channel_id" error?
1. Open the app at least once
2. Wait a few seconds after opening
3. Try sending notification again

### Sound plays but is wrong?
- Check that `emergency_alert.mp3` is the correct file
- Verify file is not corrupted
- Try replacing the sound file

