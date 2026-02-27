# In-app update (LSPU DRES)

When users see **"Update required"** and tap **"Download and install"**, the app downloads the APK from the URL in the `app_version` table and asks the system to install it.

## Why "App not installed" appears

Android shows **"App not installed"** when the update APK **cannot replace** the app already on the device. The two main causes:

### 1. **Different signing key (most common)**

The APK at `download_url` **must be signed with the same keystore** as the app currently installed.

- If the device has an app signed with **release** key (from `android/app/key.properties`), the APK you host must be built with **that same** `key.properties` / keystore.
- If you build the update APK on another machine or without `key.properties`, it will be signed with a **debug** or different key → Android blocks the install.

**Fix:** Build the release APK on the same setup that built the app users have (same `key.properties`), then upload that APK to the URL you put in `app_version.download_url`. You must **also** bump the version (see below)—same keystore alone is not enough.

### 2. **Lower or same version code**

The new APK must have **versionCode greater than** the app on the device (and at least as high as `min_version` / `latest_version` in your version check).

- In `pubspec.yaml`, `version: 1.3.5+29` → versionName `1.3.5`, versionCode `29`.
- Each new update must use a **higher** `+number` (e.g. `1.3.6+30`).

**Fix:** Bump `version` in `pubspec.yaml`, run `flutter build apk`, then upload the new APK and update the `app_version` row so `latest_version` / `min_version` and `download_url` point to this build.

**Both** same keystore **and** a higher version are required for the update to install. Fixing only the build (keystore) is not enough—you must still bump the version.

## Checklist when publishing an update

1. Use the **same** `android/app/key.properties` (and keystore file) as the app already in users’ hands.
2. **Bump `version`** in `pubspec.yaml` (e.g. `1.3.6+30`)—required even when fixing signing.
3. Run `flutter build apk` and take the APK from `build/app/outputs/flutter-apk/app-release.apk`.
4. Upload that APK to a stable URL (e.g. Supabase Storage or your server).
5. In the `app_version` table (row for `platform = 'android'`), set:
   - `latest_version` / `min_version_apk` to the new version (e.g. `1.3.6`),
   - `download_url` to the **exact** URL of the uploaded APK.

After that, in-app update should install without "App not installed" (as long as the user has "Install unknown apps" allowed for the app when prompted).
