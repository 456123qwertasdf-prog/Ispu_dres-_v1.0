# How to Send Credentials in Email

## Current Problem

The email IS being sent, but **the password is NOT showing** because Supabase's default email template doesn't include it.

## Solution Options

### Option 1: Use Resend API (Easiest - Recommended) ✅

**Resend** is an email service that can send emails with credentials included.

#### Steps:

1. **Sign up for Resend** (free tier available):
   - Go to https://resend.com
   - Create an account
   - Get your API key

2. **Add API Key to Supabase**:
   - Go to your Supabase Dashboard
   - Navigate to: Project Settings → Edge Functions → Secrets
   - Add secret: `RESEND_API_KEY` = `your_resend_api_key`

3. **Verify domain** (optional for production):
   - In Resend dashboard, verify your domain
   - Update the `from` address in `send-email-with-credentials/index.ts`

4. **Test it**:
   - Create a new user
   - The email will be sent via Resend WITH credentials included!

### Option 2: Configure SMTP + Custom Template (For Gmail)

#### Steps:

1. **Enable Gmail App Password**:
   - Go to Google Account → Security
   - Enable 2-Step Verification
   - Generate App Password for "Mail"
   - Copy the 16-character password

2. **Update `supabase/config.toml`**:
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

3. **Set Environment Variable**:
   - Create `.env` file in project root or set in Supabase Dashboard
   - Add: `SMTP_PASSWORD=your-16-char-app-password`

4. **Restart Supabase** (if local):
   ```bash
   supabase stop
   supabase start
   ```

5. **Test it**:
   - Create a new user
   - Check Inbucket at `http://localhost:54324` (local) or Gmail inbox
   - Email should show credentials!

### Option 3: Manual Email (Temporary Solution)

If you can't configure SMTP/Resend right now:

1. When creating a user, the popup shows credentials
2. Copy the email HTML from the API response (check browser console)
3. Send it manually via your email client to the user

## Quick Start: Resend (Recommended)

1. **Sign up**: https://resend.com/signup
2. **Get API key**: Dashboard → API Keys
3. **Add to Supabase**: Dashboard → Settings → Edge Functions → Secrets → Add `RESEND_API_KEY`
4. **Done!** Emails will now include credentials automatically.

## Testing

After setup:
1. Create a test user
2. Check email inbox (or Inbucket at `http://localhost:54324` for local)
3. Email should show:
   - ✅ Email address
   - ✅ Password
   - ✅ Role
   - ✅ Verification link
   - ✅ Instructions

## Current Status

- ✅ Credentials shown to admin (popup)
- ✅ Email sent (but password not visible in default template)
- ⚠️ Need Resend API key OR SMTP config to show password in email

## Need Help?

- **Resend Setup**: See https://resend.com/docs
- **Gmail SMTP**: See `EMAIL_VERIFICATION_SETUP.md`
- **Custom Template**: Already created at `supabase/templates/verification-with-credentials.html`

