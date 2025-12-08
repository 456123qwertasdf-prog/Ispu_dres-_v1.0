# How to Find App Passwords in Gmail

## The Problem
You have 2-Step Verification enabled, but you can't see "App passwords" option.

## Solution: Where to Find App Passwords

### Method 1: Direct Link (Easiest)
1. Go directly to: **https://myaccount.google.com/apppasswords**
2. You should see the App Passwords page
3. If it asks for your password, enter it
4. You'll see the App Passwords section

### Method 2: Through Security Settings
1. Go to: https://myaccount.google.com/security
2. Scroll down to **"2-Step Verification"** section
3. Click on **"2-Step Verification"** (not the toggle, but the text itself)
4. On the next page, scroll down
5. Look for **"App passwords"** section at the bottom
6. Click **"App passwords"**

### Method 3: Search for It
1. On the Security page, look for the search box at the top
2. Type "app passwords" or "application passwords"
3. Click the result that appears

## If App Passwords Still Don't Appear

### Check 1: Is 2-Step Verification Actually Active?
- Make sure 2-Step Verification toggle is **ON** (you have it ON)
- Sometimes it needs to be fully set up (not just enabled)
- Try turning it off and back on

### Check 2: Are You Using a Work/School Account?
- Work/school Google accounts (Google Workspace) might not have App Passwords
- You may need to use OAuth instead
- Contact your IT admin if this is a work account

### Check 3: Account Type
- Some Google accounts don't support App Passwords
- If you're using a child account or managed account, App Passwords might be disabled

### Check 4: Try Different Browser/Device
- Sometimes the UI doesn't load correctly
- Try a different browser or incognito mode
- Clear browser cache

## Alternative: Use OAuth Instead of App Password

If App Passwords don't work, you can use OAuth:

1. **Enable "Less secure app access"** (if available)
   - This is usually found under Security → Less secure app access
   - Note: Google is phasing this out, so it might not be available

2. **Use OAuth2** with Supabase
   - More complex setup but more secure
   - Requires additional configuration

## Quick Test Link

Try this direct link: **https://myaccount.google.com/apppasswords**

If it says "App Passwords aren't available for your account", then:
- Your account type doesn't support it
- You'll need to use a different method (OAuth or different email service)

## For Your Supabase Setup

If you can't get App Passwords:

**Option A: Use a Different Email Service**
- Use SendGrid, Mailgun, or AWS SES
- These don't require App Passwords
- Similar SMTP setup in config.toml

**Option B: Use Resend API** (what we discussed earlier)
- No SMTP needed
- Just add API key to Supabase
- Works immediately

**Option C: Use Supabase's Default Email** (without credentials)
- Use default Supabase email for verification
- Share credentials manually (shown in popup)
- Not ideal but works

Let me know which path you want to take!

