# QUICK FIX: Send Credentials in Email

## Current Problem
- ✅ Email is being sent
- ❌ Credentials NOT showing in email
- ❌ Link pointing to wrong URL (localhost:3000)

## Solution: Configure Resend API (5 minutes)

### Step 1: Get Resend API Key
1. Go to https://resend.com/signup
2. Sign up (free account works)
3. Go to Dashboard → API Keys
4. Click "Create API Key"
5. Copy the key (starts with `re_...`)

### Step 2: Add to Supabase
1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld
2. Go to **Settings** → **Edge Functions** → **Secrets**
3. Click **"Add new secret"**
4. Name: `RESEND_API_KEY`
5. Value: Paste your Resend API key
6. Click **Save**

### Step 3: Test
1. Create a new user in User Management
2. Check the email - it should now show:
   - ✅ Email address
   - ✅ Password
   - ✅ Verification link (corrected to 127.0.0.1:8000)
   - ✅ Login instructions

## What Will Change

**Before (Current):**
- Email sent but NO credentials shown
- Link points to localhost:3000 (doesn't work)

**After (With Resend):**
- ✅ Email sent WITH credentials clearly shown
- ✅ Link points to correct URL (127.0.0.1:8000/login.html)
- ✅ Beautiful email with all info

## Alternative: Gmail SMTP (If you prefer)

If you want to use Gmail instead of Resend:

1. **Get Gmail App Password:**
   - Google Account → Security → 2-Step Verification (enable it)
   - Then App Passwords → Generate for "Mail"
   - Copy the 16-character password

2. **Update `supabase/config.toml`:**
   ```toml
   [auth.email.smtp]
   enabled = true
   host = "smtp.gmail.com"
   port = 587
   user = "your-email@gmail.com"
   pass = "env(SMTP_PASSWORD)"
   admin_email = "your-email@gmail.com"
   sender_name = "LSPU Emergency Response System"

   [auth.email.template.invite]
   subject = "Account Verification - LSPU Emergency Response System"
   content_path = "./supabase/templates/verification-with-credentials.html"
   ```

3. **Add SMTP_PASSWORD to Supabase secrets:**
   - Settings → Edge Functions → Secrets
   - Add: `SMTP_PASSWORD` = your-16-char-app-password

4. **Restart Supabase** (if local):
   ```bash
   supabase stop
   supabase start
   ```

## Which to Choose?

- **Resend**: Easier, faster setup, works immediately ✅ Recommended
- **Gmail SMTP**: More control, uses your own email, but requires more setup

## Need Help?

The code is already set up - you just need to add the API key!

