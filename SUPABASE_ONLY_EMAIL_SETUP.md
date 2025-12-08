# Configure Supabase Built-in Email (No Resend)

## Step 1: Add SMTP Password to Supabase Secrets

1. Go to: **https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/functions**
2. Click **"Secrets"** tab  
3. Click **"Add new secret"**
4. Name: `SMTP_PASSWORD`
5. Value: `dweyrljbbmkjvooz` (remove spaces)
6. Click **"Save"**

## Step 2: Configure SMTP in Supabase Dashboard

1. Go to: **https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/auth**
2. Look for **"SMTP Settings"** or **"Email Settings"** section
3. Enable **"Custom SMTP"** or **"SMTP"**
4. Enter these settings:
   - **Host:** `smtp.gmail.com`
   - **Port:** `587`
   - **Username:** `456123qwert.asdf@gmail.com`
   - **Password:** `dweyrljbbmkjvooz` (or reference the secret)
   - **Sender Email:** `456123qwert.asdf@gmail.com`
   - **Sender Name:** `LSPU Emergency Response System`
5. Click **"Save"**

## Step 3: Upload Custom Email Template

1. Still in **Settings → Auth**
2. Find **"Email Templates"** or **"Templates"** section
3. Click on **"Invite"** or **"Invite User"** template
4. Click **"Edit"** or **"Customize"**
5. You need to upload/configure the custom template

**Option A: If there's an upload option:**
- Upload `supabase/templates/verification-with-credentials.html`

**Option B: If you need to paste the content:**
- Open `supabase/templates/verification-with-credentials.html`
- Copy all the HTML content
- Paste into the template editor
- Save

## Step 4: Verify Template Has Correct Variables

Your template must include:
- `{{ .Email }}` - User email
- `{{ .UserMetaData.temporary_password }}` - The password (IMPORTANT!)
- `{{ .UserMetaData.role }}` - User role  
- `{{ .ConfirmationURL }}` - Verification link

## Step 5: Restart/Apply Changes

For hosted Supabase, changes usually apply immediately after saving in the dashboard.

## Step 6: Test

1. Create a new user
2. Check email inbox
3. Credentials should now be in the email!

## If Dashboard Doesn't Have SMTP Settings

Some Supabase projects might need to configure via API or CLI:

### Via Supabase Management API:
You may need to use Supabase's management API to configure SMTP settings.

### Via config.toml (for local only):
The `config.toml` settings work for local Supabase. For hosted, use dashboard.

## Important

The `config.toml` file you edited is correct, but for **hosted Supabase projects**, you must configure SMTP through the **Dashboard**, not just the config file.

Your custom template (`verification-with-credentials.html`) is ready and has the correct variables - it just needs to be uploaded/configured in the dashboard.

