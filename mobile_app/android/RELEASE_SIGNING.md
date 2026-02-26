# Release signing (same keystore = in-app updates work)

When the app is signed with the **same** keystore on your machine and in GitHub Actions, users can tap "Download and install" and the new version replaces the old one without "App not installed."

Do this **once**, then use the same keystore for every release.

---

## 1. Create the keystore (one time)

From your project root (or any folder), run:

```bash
keytool -genkey -v -keystore mobile_app/android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- **Keystore password** and **key password**: choose strong passwords and remember them (you’ll use them in `key.properties` and GitHub Secrets).
- **Alias**: `upload` is fine (or another name; use the same in `keyAlias` and in the GitHub secret `ANDROID_KEY_ALIAS`).
- The file `upload-keystore.jks` is gitignored. **Back it up somewhere safe** (e.g. password manager, secure drive). If you lose it, you cannot sign updates for the same app anymore.

---

## 2. Local release builds

1. Copy the example properties file:
   ```bash
   cp mobile_app/android/key.properties.example mobile_app/android/key.properties
   ```
2. Edit `mobile_app/android/key.properties` and set:
   - `storePassword` = keystore password
   - `keyPassword` = key password
   - `keyAlias` = alias you used (e.g. `upload`)
   - `storeFile=app/upload-keystore.jks` (keep as is if the keystore is at `android/app/upload-keystore.jks`)

3. Build release APK:
   ```bash
   cd mobile_app && flutter build apk --release
   ```
   The APK will be signed with your release key. Do not commit `key.properties` or `upload-keystore.jks`.

---

## 3. GitHub Actions (CI) – same keystore

So that the APK built by the workflow is signed with the **same** key, add these **repository secrets** in GitHub (Settings → Secrets and variables → Actions):

| Secret name | Value |
|-------------|--------|
| `ANDROID_KEYSTORE_BASE64` | Base64 of your `.jks` file (see below) |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password (same as in key.properties) |
| `ANDROID_KEY_PASSWORD` | Key password (same as in key.properties) |
| `ANDROID_KEY_ALIAS` | Key alias (e.g. `upload`) |

### How to get the base64 keystore

**Windows (PowerShell):**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("mobile_app\android\app\upload-keystore.jks"))
```
Copy the output (one long line) into the secret `ANDROID_KEYSTORE_BASE64`.

**macOS / Linux:**
```bash
base64 -i mobile_app/android/app/upload-keystore.jks | tr -d '\n' | pbcopy
```
Paste into the secret (or use the terminal output).

---

## 4. Result

- **Local:** `flutter build apk --release` uses `key.properties` and signs with your keystore.
- **CI:** When the four secrets are set, the workflow decodes the keystore and writes `key.properties` before building, so the APK is signed with the same key.
- **Users:** "Download and install" replaces the app without "App not installed" because every distributed APK has the same signature.

If you don’t add the secrets yet, the workflow still runs and builds with the debug key (current behavior); add the secrets when you’re ready to switch to one release keystore.
