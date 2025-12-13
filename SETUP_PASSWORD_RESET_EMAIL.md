# Setup Password Reset Email Template

## Problem
The password reset email is being sent but doesn't have a clickable link - just text saying "Reset Password".

## Solution
Configure a custom password reset email template in Supabase Dashboard.

## Quick Setup Steps

### Step 1: Go to Supabase Dashboard
1. Go to: **https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/auth**
2. Scroll down to **"Email Templates"** section

### Step 2: Configure Password Reset Template
1. Find the **"Recovery"** or **"Password Reset"** template
2. Click **"Edit"** or **"Customize"**
3. You have two options:

   **Option A: Upload Template File**
   - Click **"Upload Template"** (if available)
   - Upload: `supabase/templates/password-reset.html`
   
   **Option B: Copy & Paste Content**
   - Open `supabase/templates/password-reset.html` in your editor
   - Copy ALL the HTML content
   - Paste into the template editor in Supabase Dashboard
   - Make sure to preserve all the HTML structure

### Step 3: Verify Template Variables
Make sure the template includes:
- ✅ `{{ .ConfirmationURL }}` - This is the clickable reset link (CRITICAL!)
- ✅ `{{ .Email }}` - User's email address
- ✅ `{{ .UserMetaData.full_name }}` - User's name (optional)

### Step 4: Set Subject Line
- **Subject:** `Reset Your Password - LSPU Emergency Response System`

### Step 5: Save and Test
1. Click **"Save"** in the Supabase Dashboard
2. Test by requesting a password reset
3. Check your email - you should now see a clickable "Reset Password" button!

## What the Template Includes

✅ **Clickable "Reset Password" button** - Large, prominent button with the reset link
✅ **Fallback link text** - If button doesn't work, users can copy/paste the URL
✅ **Security warnings** - Reminds users about link expiration and security
✅ **Professional design** - Matches your LSPU Emergency Response System branding
✅ **Mobile-friendly** - Responsive design that works on all devices

## Important Notes

- The template uses `{{ .ConfirmationURL }}` which Supabase automatically populates with the secure reset link
- The link expires after 1 hour for security
- Make sure SMTP is configured (you already have this set up)
- Changes in the dashboard apply immediately - no restart needed

## Troubleshooting

**If the link still doesn't appear:**
1. Double-check that `{{ .ConfirmationURL }}` is in the template (exactly as shown)
2. Make sure you saved the template in the dashboard
3. Try requesting a new password reset email
4. Check spam folder (the email might be flagged)

**If emails go to spam:**
- This is normal for Gmail - users can click "Not spam"
- Consider verifying your domain in Gmail for better deliverability

