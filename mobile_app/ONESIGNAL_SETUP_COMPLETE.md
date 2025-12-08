# OneSignal Push Notifications Setup - Complete Guide

## ✅ What's Been Implemented

### 1. Flutter App Integration
- ✅ Added `onesignal_flutter: ^5.0.0` package
- ✅ Created `OneSignalService` to handle initialization and subscriptions
- ✅ Integrated OneSignal in `main.dart`
- ✅ Automatic player ID registration to Supabase

### 2. Supabase Backend
- ✅ Created `onesignal_subscriptions` table migration
- ✅ Created `onesignal-send` Edge Function
- ✅ Updated `announcement-notify` to call OneSignal

## 📋 Next Steps to Complete Setup

### Step 1: Install Flutter Dependencies

```bash
cd mobile_app
flutter pub get
```

### Step 2: Run Database Migration

Apply the OneSignal subscriptions table:

```bash
# If using Supabase CLI locally
supabase db push

# Or apply the migration manually in Supabase Dashboard:
# SQL Editor → Run the migration file:
# supabase/migrations/20250130000001_add_onesignal_subscriptions.sql
```

### Step 3: Add OneSignal REST API Key to Supabase

#### Finding Your OneSignal REST API Key:

1. **In OneSignal Dashboard:**
   - Make sure you're in your app: **Kapiyu** (App ID: `8d6aa625-a650-47ac-b9ba-00a247840952`)
   - Click **"Settings"** in the left sidebar (you should already be there)
   - Look for **"Keys & IDs"** section (usually at the top of Settings page)
   - If you don't see it, try:
     - Click **"Settings"** → **"Platforms"** → Look for **"Keys & IDs"** tab
     - OR go directly to: `https://dashboard.onesignal.com/apps/8d6aa625-a650-47ac-b9ba-00a247840952/settings/keys_and_ids`
   - Find **"REST API Key"** (it's a long string, usually starts with something like `Yj...` or `OG...`)
   - Click the **eye icon** or **"Reveal"** button to show the key
   - Click **"Copy"** to copy the REST API Key

2. **Alternative: If you still can't find it:**
   - Go to: `https://dashboard.onesignal.com/apps/8d6aa625-a650-47ac-b9ba-00a247840952/settings/keys_and_ids`
   - Or navigate: **Settings** → **Keys & IDs** → Look for **"REST API Key"**

#### Adding to Supabase:

3. Go to Supabase Dashboard → **Settings** → **Edge Functions** → **Secrets**
4. Click **"Add new secret"**
5. Add the REST API Key:
   - Name: `ONESIGNAL_REST_API_KEY`
   - Value: (paste your REST API Key you copied)
   - Click **Save**
6. Add the App ID (optional, already set in code):
   - Click **"Add new secret"** again
   - Name: `ONESIGNAL_APP_ID`
   - Value: `8d6aa625-a650-47ac-b9ba-00a247840952`
   - Click **Save**

### Step 4: Deploy Edge Function

```bash
supabase functions deploy onesignal-send
```

### Step 5: Add Custom Sound to Android App

**Important:** For Android push notifications, custom sounds are NOT uploaded to OneSignal dashboard. Unlike iOS, Android requires sound files to be bundled directly in the Android app's native resources. There is no "Notification Sounds" section in OneSignal dashboard for Android.

✅ **Already Set Up:**
- The `res/raw/` directory has been created
- The `emergency_alert.mp3` file has been copied from `assets/sounds/` to `android/app/src/main/res/raw/`

**How It Works:**
1. When OneSignal sends a notification with `android_sound: "emergency_alert"` (as specified in `onesignal-send/index.ts`)
2. Android automatically looks for the sound file in: `res/raw/emergency_alert.mp3`
3. The notification channel `emergency_alerts` (configured in OneSignal payload) is automatically created by OneSignal SDK
4. The custom sound plays when the notification is received

**File Location:**
- Sound file: `mobile_app/android/app/src/main/res/raw/emergency_alert.mp3`
- Supported formats: `.mp3`, `.wav`, or `.ogg`
- File requirements:
  - Duration: 1-30 seconds recommended
  - File size: Keep it small (< 100KB is ideal)

**If you need to replace the sound file:**
1. Copy your new `emergency_alert.mp3` file to: `mobile_app/android/app/src/main/res/raw/emergency_alert.mp3`
2. Make sure the filename is exactly `emergency_alert` (without extension when referenced in code)
3. Rebuild your Android app for the changes to take effect

### Step 6: Test the Integration

1. **Build and run your Flutter app:**
   ```bash
   flutter run
   ```

2. **Check OneSignal Dashboard:**
   - Go to OneSignal Dashboard → Audience
   - You should see your device as a "Subscribed User"
   - Note the Player ID

3. **Verify Supabase:**
   - Check `onesignal_subscriptions` table
   - Your user_id and player_id should be saved

4. **Test Emergency Notification:**
   - As admin, create an emergency announcement
   - The app should receive a push notification
   - Sound should play automatically (even when app is closed)

## 🎯 How It Works

### When App Starts:
1. OneSignal SDK initializes with App ID
2. Requests notification permission
3. Gets Player ID from OneSignal
4. Saves Player ID to Supabase `onesignal_subscriptions` table

### When Admin Creates Emergency Announcement:
1. Admin creates announcement in Supabase
2. `announcement-notify` Edge Function is triggered
3. Function calls `onesignal-send` Edge Function
4. `onesignal-send` gets Player IDs from Supabase
5. Sends notification via OneSignal API
6. OneSignal delivers to Android devices
7. **Sound plays automatically** (even when app is closed!)

## 🔧 Configuration Details

### OneSignal App ID
- App ID: `8d6aa625-a650-47ac-b9ba-00a247840952`
- Already configured in code

### Notification Settings
- **Emergency alerts**: Play `emergency_alert` sound
- **Other announcements**: Play default sound
- **Android Channel**: `emergency_alerts`
- **Priority**: High (10) for emergencies, Normal (5) for others

### Sound File Requirements
- **File name**: `emergency_alert.mp3`
- **Location**: Uploaded to OneSignal Dashboard
- **Duration**: 1-2 seconds recommended
- **Format**: MP3

## 🐛 Troubleshooting

### Can't find REST API Key?

**Direct Link Method:**
1. Go directly to: `https://dashboard.onesignal.com/apps/8d6aa625-a650-47ac-b9ba-00a247840952/settings/keys_and_ids`
2. You should see a section with "REST API Key"
3. Click the eye icon or "Reveal" to show it
4. Copy the key

**Navigation Method:**
1. In OneSignal Dashboard, click **"Settings"** in left sidebar
2. Look for **"Keys & IDs"** tab or section
3. If you see tabs like "Platforms", "Notifications", "Keys & IDs" - click **"Keys & IDs"**
4. The REST API Key should be visible there

**If you still can't find it:**
- Make sure you're logged into the correct OneSignal account
- Make sure you're viewing the correct app: **Kapiyu**
- Try refreshing the page
- The REST API Key might be under **"Account"** → **"Keys & IDs"** (account-level) instead of app-level
- Check if you need to generate a new REST API Key (some accounts require this)

### No notifications received?
1. Check OneSignal Dashboard → Audience → Is device subscribed?   
2. Check Supabase `onesignal_subscriptions` table → Is player_id saved?
3. Check Supabase Edge Function logs → Any errors?
4. Verify `ONESIGNAL_REST_API_KEY` is set in Supabase secrets

### Sound not playing?
1. ✅ Verify sound file exists in `android/app/src/main/res/raw/emergency_alert.mp3`
2. ✅ Check sound name matches: `emergency_alert` (file name without extension)
3. ✅ Rebuild the Android app after adding/updating the sound file
4. ✅ Check device volume is not muted
5. ✅ Check device is not in Do Not Disturb mode
6. ✅ Verify notification channel settings in device Settings → Apps → LSPU DRES → Notifications
7. **Note:** You do NOT need to upload sounds to OneSignal dashboard - they are bundled with the app

### Player ID not saving?
1. Check user is authenticated in Supabase
2. Check RLS policies allow insert/update
3. Check Supabase connection in app

### Edge Function errors?
1. Check Supabase Edge Function logs
2. Verify `ONESIGNAL_REST_API_KEY` secret is set
3. Verify OneSignal App ID is correct
4. Check network connectivity

## 📱 Testing Checklist

- [ ] Flutter app builds and runs
- [ ] OneSignal permission requested on first launch
- [ ] Device appears in OneSignal Dashboard → Audience
- [ ] Player ID saved in Supabase `onesignal_subscriptions` table
- [ ] Emergency announcement triggers notification
- [ ] Notification appears even when app is closed
- [ ] Emergency sound plays automatically
- [ ] Notification tap opens app correctly

## 🎉 Success Indicators

✅ **You'll know it's working when:**
- Device shows in OneSignal Dashboard as "Subscribed"
- Player ID appears in Supabase table
- Emergency announcements trigger push notifications
- Sound plays automatically (even when app closed)
- Notification appears in Android notification tray

## 📚 Additional Resources

- [OneSignal Flutter Documentation](https://documentation.onesignal.com/docs/flutter-sdk-setup)
- [OneSignal REST API](https://documentation.onesignal.com/reference/create-notification)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)

## 🔐 Security Notes

- Never commit `ONESIGNAL_REST_API_KEY` to git
- Store secrets only in Supabase Dashboard → Secrets
- Use environment variables for local development
- OneSignal App ID is public (safe to include in code)

