# App version & "Update required" – you shouldn’t update the DB manually

The **GitHub workflow** is supposed to update the database automatically when a new APK is built and pushed. You only need the manual SQL below if that didn’t happen (e.g. one-time fix for a past release).

---

## How it should work (intended flow)

1. **You** bump the version in `mobile_app/pubspec.yaml` (e.g. to `1.2.2+5`), build the APK locally, copy it to `public/lspu-emergency-response.apk`, then commit and push **without** `[skip ci]` in the message (e.g. `chore: release APK 1.2.2`).

2. **GitHub** sees the push to `main` that touched `mobile_app/**` and runs the **Build and push APK** workflow.

3. The workflow **builds** the APK, **copies** it to `public/`, and **commits and pushes** that change with a message that **includes** `[skip ci]` (so that second push does not trigger the workflow again and cause an infinite loop).

4. The workflow then runs the step **“Update app version in Supabase”**: it reads the version from `pubspec.yaml` and **PATCHes the `app_version` table directly** via Supabase’s REST API using the **service role key** (no Edge Function involved).

5. **Result:** The DB is updated automatically. Users on an older app version open the app, it calls `get-app-version`, sees their version is below `min_version`, and shows the “Update required” screen.

So: **your commit** = no `[skip ci]` (so the workflow runs). **The workflow’s own commit** = with `[skip ci]` (so the workflow does not run again).

---

## Why the DB wasn’t updated automatically this time

The release commit used the message **`chore: release APK 1.2.1 [skip ci]`**.

On GitHub, **`[skip ci]`** means “do not run any workflow for this push.” So the **Build and push APK** workflow (and its “Update app version in Supabase” step) never ran. That’s why the DB stayed at 1.2.0 and you had to fix it manually.

---

## One-time setup: GitHub Secret for auto-update

1. In **Supabase**: Dashboard → **Project Settings** → **API** → copy the **`service_role`** key (under "Project API keys").
2. In **GitHub**: repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
3. Name: **`SUPABASE_SERVICE_ROLE_KEY`**, Value: paste the `service_role` key → Save.

After that, the workflow can update `app_version` automatically. No Edge Function or `APP_VERSION_UPDATE_SECRET` needed.

---

## What to do from now on (no manual DB updates)

When **you** push a new release (new APK + version bump), **do not put `[skip ci]` in the commit message**.

- **Good:** `chore: release APK 1.2.2` or `Release APK 1.2.2`
- **Bad:** `chore: release APK 1.2.2 [skip ci]`

Then:

1. The workflow runs (because you changed `mobile_app/` or the workflow file).
2. It builds the APK, updates the repo, and runs **“Update app version in Supabase”** (direct PATCH to the DB with the service role key).
3. With **SUPABASE_SERVICE_ROLE_KEY** set in GitHub Secrets, the workflow updates `app_version` in Supabase for you.

So under normal conditions you **don’t** need to manually update the DB.

---

## One-time fix (only if the workflow didn’t run)

If you already pushed a release **with** `[skip ci]` (like 1.2.1), run this once in **Supabase** → **SQL Editor** so the current version in the DB matches what you released:

```sql
UPDATE public.app_version
SET
  min_version = '1.2.1',
  latest_version = '1.2.1',
  updated_at = now()
WHERE platform = 'android';
```

After that, rely on the workflow for future releases (and avoid `[skip ci]` on release commits).

---

## "App not installed" when using "Download and install"

If users tap **Download and install** and after the download they see **"App not installed"** (without having uninstalled the app), the cause is usually **signing key mismatch**:

- The app they have installed was signed with one key (e.g. from a local build or another machine).
- The APK from the download link is signed with a different key (e.g. from GitHub Actions).
- Android only allows upgrading an app if the new APK is signed with the **same** key.

**What to do:**

1. **For users right now:** In the app we show an "Install failed" dialog with **"Open in browser"**. They should **uninstall the current app**, then use that button to open the link in the browser, download the APK, and install it. After that, future in-app "Download and install" updates will work as long as all APKs come from the same source (same signing key).

2. **For you (one signing key everywhere):** To make in-place updates work for everyone, use the **same** release keystore locally and in CI. Step-by-step: **[mobile_app/android/RELEASE_SIGNING.md](mobile_app/android/RELEASE_SIGNING.md)** — create keystore once, add `key.properties` for local builds, add the four GitHub Secrets so the workflow signs with the same key.
