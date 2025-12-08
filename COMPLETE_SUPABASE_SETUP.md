# Complete Supabase Email Setup (No Resend)

## Current Status
- ✅ Code updated to use Supabase only (no Resend)
- ✅ Password stored in `user_metadata.temporary_password`
- ✅ Custom template ready with credentials
- ⚠️ Need to configure SMTP in Supabase Dashboard

## Setup Steps

### Step 1: Add SMTP Password Secret ✅

1. Go to: **https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/functions**
2. Click **"Secrets"** tab
3. Add secret: `SMTP_PASSWORD` = `dweyrljbbmkjvooz`
4. Save

### Step 2: Configure SMTP in Dashboard

1. Go to: **https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/auth**
2. Find **"SMTP Settings"** or **"Email Configuration"**
3. Enable SMTP and enter:
   - **Host:** `smtp.gmail.com`
   - **Port:** `587`
   - **Username:** `456123qwert.asdf@gmail.com`
   - **Password:** `dweyrljbbmkjvooz` (or reference SMTP_PASSWORD secret)
   - **Sender:** `456123qwert.asdf@gmail.com`
4. Save

### Step 3: Configure Custom Email Template

**Option A: Via Dashboard (Recommended)**
1. Go to **Settings → Auth → Email Templates**
2. Click **"Invite"** or **"Invite User"** template
3. Click **"Edit"** or **"Customize"**
4. Upload or paste content from `supabase/templates/verification-with-credentials.html`
5. Save

**Option B: Template Content**
Copy the HTML from `supabase/templates/verification-with-credentials.html` and paste it into the template editor in the dashboard.

### Step 4: Verify Template Variables

Your template should include:
- ✅ `{{ .Email }}` - User email
- ✅ `{{ .UserMetaData.temporary_password }}` - Password (CRITICAL!)
- ✅ `{{ .UserMetaData.role }}` - Role
- ✅ `{{ .ConfirmationURL }}` - Verification link

### Step 5: Test

1. Create a new user
2. Check email
3. Credentials should be in the email!

## Why Credentials Aren't Showing Yet

The email is using Supabase's **default template** because:
1. SMTP might not be fully configured in dashboard
2. Custom template might not be uploaded in dashboard

**For hosted Supabase:** The `config.toml` file is mainly for local development. You MUST configure SMTP and upload the template via the **Dashboard**.

## What Your Code Does Now

1. Creates user with `temporary_password` in metadata ✅
2. Calls `inviteUserByEmail` with metadata ✅
3. Supabase sends email using:
   - Default template (if custom not configured) ❌ No credentials
   - Custom template (if configured in dashboard) ✅ Shows credentials

## Next Steps

1. ✅ Add `SMTP_PASSWORD` secret (if not done)
2. ✅ Configure SMTP in Dashboard
3. ✅ Upload custom template in Dashboard
4. ✅ Test - credentials should appear!

Your custom template is ready - you just need to configure it in the Supabase Dashboard!

