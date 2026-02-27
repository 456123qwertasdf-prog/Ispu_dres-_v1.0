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
   - `latest_version` / `min_version` to the new version (e.g. `1.3.6`),
   - `download_url` to the **exact** URL of the uploaded APK.

After that, in-app update should install without "App not installed" (as long as the user has "Install unknown apps" allowed for the app when prompted).

---

## Walkthrough: fix "App not installed" (CI + Supabase)

Use this when users on an older version (e.g. 1.3.6) see "Update required", tap "Download and install", then get "App not installed."

### 1. Same signing key as the app users have

The APK at `download_url` must be signed with the **same** keystore as the app already on devices (e.g. 1.3.6). If that app was built with a **release** key, the update APK must use that key too.

- **If you use GitHub Actions to build the APK:**  
  Add the four release-signing secrets so CI uses your release keystore (see `mobile_app/android/RELEASE_SIGNING.md`):
  - `ANDROID_KEYSTORE_BASE64` (base64 of your `.jks` file)
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_PASSWORD`
  - `ANDROID_KEY_ALIAS` (e.g. `upload`)

  If these are not set, the workflow builds with the **debug** key → "App not installed" when users have a release-signed app.

- **If you build the APK locally:**  
  Use the same `android/app/key.properties` and keystore you used for the build that users have, then upload that APK and set `download_url` to it (or use CI with the secrets above).

### 2. `download_url` must point to that APK

The app reads `min_version`, `latest_version`, and `download_url` from Supabase (via the `get-app-version` function). The URL must be the **exact** URL of the **release-signed** APK.

- **When using the repo workflow:**  
  The workflow now updates Supabase with `min_version`, `latest_version`, and `download_url` after each run. `download_url` is set to  
  `https://github.com/<owner>/<repo>/raw/<branch>/public/lspu-emergency-response.apk`  
  so it always points to the APK that was just built and pushed. No need to set it manually.

- **If you host the APK elsewhere:**  
  In Supabase Dashboard → Table Editor → `app_version`, set `download_url` for the `android` row to that URL.

### 3. Run the build and update

1. In GitHub: **Actions** → **Build and push APK** → **Run workflow** (or push to `main` with changes under `mobile_app/` or `public/` or the workflow file).
2. Wait for the job to finish. It will:
   - Bump the patch version and build the APK (with release key if secrets are set),
   - Push the APK to `public/lspu-emergency-response.apk` in the repo,
   - Update Supabase: `min_version`, `latest_version`, and `download_url` for Android.

### 4. Verify in Supabase (optional)

In **Supabase Dashboard** → **Table Editor** → `app_version`:

- Row `platform = 'android'`: `min_version` and `latest_version` should match the new version (e.g. `1.3.7`).
- `download_url` should be  
  `https://github.com/456123qwertasdf-prog/Ispu_dres-_v1.0/raw/main/public/lspu-emergency-response.apk`  
  (or your repo/branch). That URL must serve the APK that was just built (same signature as the app on users’ devices).

### 5. Result

After the workflow runs **with the four Android secrets set**, the APK in the repo is signed with your release key and Supabase points to it. Users on 1.3.6 who tap "Download and install" will get the new build and it will install over the old one without "App not installed."
