# Setup Supabase to Send Credentials in Email (No Resend Needed!)

You're absolutely right - **Supabase can send credentials in emails** using its built-in SMTP and custom email templates. You don't need Resend API!

## Quick Setup (5 minutes)

### Step 1: Get Gmail App Password

**If you can't see "App Passwords" option, try these:**

#### Option A: Direct Link (Easiest)
1. Go directly to: **https://myaccount.google.com/apppasswords**
2. Enter your password if prompted
3. You should see the App Passwords page

#### Option B: Through 2-Step Verification
1. Go to https://myaccount.google.com/security
2. Click on **"2-Step Verification"** (click the text, not the toggle)
3. Scroll down on the next page
4. Find **"App Passwords"** section at the bottom
5. Click on it

#### Once you're on App Passwords page:
1. Click **"Select app"** → Choose **"Mail"**
2. Click **"Select device"** → Choose **"Other"** → Type "Supabase"
3. Click **"Generate"**
4. **Copy the 16-character password** (looks like: `abcd efgh ijkl mnop`)

**⚠️ If App Passwords don't appear:**
- Your account might not support them (work/school accounts sometimes don't)
- See `FIND_APP_PASSWORDS_GMAIL.md` for troubleshooting
- Or use Resend API instead (easier, no App Password needed)

### Step 2: Update Supabase Config

Edit `supabase/config.toml` and uncomment/modify these lines (around line 188):

```toml
# Use a production-ready SMTP server
[auth.email.smtp]
enabled = true
host = "smtp.gmail.com"
port = 587
user = "your-email@gmail.com"  # Your Gmail address
pass = "env(SMTP_PASSWORD)"
admin_email = "your-email@gmail.com"
sender_name = "LSPU Emergency Response System"

# Custom email template that includes credentials
[auth.email.template.invite]
subject = "Account Verification - LSPU Emergency Response System"
content_path = "./supabase/templates/verification-with-credentials.html"
```

### Step 3: Add SMTP Password to Supabase

**For Local Development:**
Create a `.env` file in your project root:
```
SMTP_PASSWORD=your-16-char-app-password
```

**For Production/Hosted Supabase:**
1. Go to https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld
2. Go to **Settings** → **Edge Functions** → **Secrets**
3. Click **"Add new secret"**
4. Name: `SMTP_PASSWORD`
5. Value: Paste your 16-character Gmail app password (remove spaces)
6. Click **Save**

### Step 4: Restart Supabase (if local)

```bash
supabase stop
supabase start
```

For hosted Supabase, the config changes might need to be applied via the dashboard or will take effect after deployment.

### Step 5: Test It!

1. Create a new user in User Management
2. Check the email inbox (or Inbucket at `http://localhost:54324` for local)
3. The email should now show:
   - ✅ Email address
   - ✅ Password (from `{{ .UserMetaData.temporary_password }}`)
   - ✅ Role
   - ✅ Verification link
   - ✅ All instructions

## How It Works

1. When you create a user, the password is stored in `user_metadata.temporary_password`
2. Supabase sends the invite email using your custom template
3. The template accesses the password via `{{ .UserMetaData.temporary_password }}`
4. Credentials appear in the email!

## That's It!

No Resend API needed - Supabase handles everything! The custom template we created (`verification-with-credentials.html`) will automatically include the credentials when SMTP is configured.

## Troubleshooting

- **Email not sent?** Check SMTP settings in `config.toml`
- **Password not showing?** Make sure `temporary_password` is in user metadata (it is, by default)
- **Wrong link?** Check `site_url` in `config.toml` (already set to `http://127.0.0.1:8000`)
- **Local development?** Check Inbucket at `http://localhost:54324` to see emails

