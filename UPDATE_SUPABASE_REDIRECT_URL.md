# Update Supabase Redirect URL Configuration

## Your Domain
**Production Domain:** `https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev`

## What You Need to Do

### Step 1: Add Redirect URL in Supabase Dashboard

1. Go to your Supabase Dashboard:
   **https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/auth**

2. Scroll down to **"URL Configuration"** section

3. Find **"Redirect URLs"** or **"Site URL"** settings

4. Add these URLs to the allowed redirect URLs list:
   ```
   https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev/reset-password.html
   https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev/login.html
   ```

5. Update **"Site URL"** to:
   ```
   https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev
   ```

6. Click **"Save"**

### Step 2: Verify Email Template

The email template in Supabase Dashboard should already have `{{ .ConfirmationURL }}` which will automatically use the redirect URL you configured.

### Step 3: Test

1. Request a password reset
2. Check the email - the link should point to your domain
3. Click the link - it should go to `reset-password.html` on your domain

## Why This Is Important

Supabase requires you to whitelist redirect URLs for security. If the redirect URL isn't in the allowed list, the password reset link won't work properly.

## Additional Notes

- The code has been updated to use your domain: `https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev/reset-password.html`
- Make sure `reset-password.html` is deployed to your Workers.dev domain
- The email template uses `{{ .ConfirmationURL }}` which Supabase will automatically populate with the correct URL

