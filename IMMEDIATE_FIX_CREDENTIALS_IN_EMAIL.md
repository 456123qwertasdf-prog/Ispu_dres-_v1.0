# IMMEDIATE FIX: Show Credentials in Email

## The Problem
- ✅ Email is being sent
- ✅ Email link is correct (127.0.0.1:8000) 
- ❌ **Credentials NOT showing in email**
- ✅ Admin popup shows credentials (working)

## Why Credentials Aren't in Email

**Supabase's default invite email template doesn't include passwords.** The custom template you configured in `config.toml` only works for LOCAL Supabase, not hosted Supabase.

For **HOSTED Supabase**, you need to either:
1. **Use Resend API** (easiest, works immediately) ✅
2. **Configure SMTP in Supabase Dashboard** (more complex)

## Quick Fix: Resend API (3 minutes)

### Step 1: Get Resend API Key
1. Go to: https://resend.com/signup
2. Sign up (free account)
3. Dashboard → **API Keys** → **Create API Key**
4. Copy the key (starts with `re_...`)

### Step 2: Add to Supabase
1. Go to: **https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/functions**
2. Click **"Secrets"** tab
3. Click **"Add new secret"**
4. Name: `RESEND_API_KEY`
5. Value: Paste your Resend API key
6. Click **"Save"**

### Step 3: Test
1. Create a new user
2. Check email - credentials will now be there! ✅

## What Happens After Adding Resend

- ✅ Emails sent via Resend (not Supabase default)
- ✅ Credentials shown clearly in email
- ✅ Beautiful formatted email with all info
- ✅ Works immediately, no restart needed

## Why This Works

The code is already set up to use Resend if `RESEND_API_KEY` is configured. Right now it's falling back to Supabase's default invite (which doesn't show credentials). Once you add the Resend API key, it will automatically use Resend and include credentials.

## Alternative: Gmail SMTP (Harder)

If you want to use Gmail SMTP instead:

1. Add `SMTP_PASSWORD` secret to Supabase (you already have it: `dweyrljbbmkjvooz`)
2. Configure SMTP in Supabase Dashboard (Settings → Auth → Email Templates)
3. Upload your custom template via Dashboard
4. More complex setup, Resend is easier

**Recommendation: Use Resend API - it's faster and works immediately!**

