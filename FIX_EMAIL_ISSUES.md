# Fix These 3 Issues

## Issue 1: localhost:54324
**This is NORMAL!** - It's Inbucket, Supabase's email testing server for local development. You can view emails there.

## Issue 2: Email Still Shows localhost:3000
**Problem:** Hosted Supabase project still has old site_url

**Fix:** Update in Supabase Dashboard (NOT just config.toml)

1. Go to: https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld
2. Go to **Settings** → **Auth** → **URL Configuration**
3. Find **"Site URL"**
4. Change from `http://localhost:3000` to `http://127.0.0.1:8000`
5. Find **"Redirect URLs"**
6. Add: `http://127.0.0.1:8000`, `http://127.0.0.1:8000/login.html`
7. Click **Save**

## Issue 3: Credentials NOT in Email
**Problem:** SMTP not configured in hosted Supabase + custom template not being used

**Fix:** 

### Step 1: Add SMTP Password Secret
1. Go to: https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/functions
2. Click **"Secrets"** tab
3. Click **"Add new secret"**
4. Name: `SMTP_PASSWORD`
5. Value: `dweyrljbbmkjvooz` (your App Password, no spaces)
6. Click **Save**

### Step 2: Configure SMTP in Supabase Dashboard
The config.toml changes only work for LOCAL Supabase. For HOSTED Supabase, you need to:

**Option A: Use Supabase Dashboard (if available)**
- Go to Settings → Auth → Email Templates
- Configure SMTP settings there
- Upload custom template

**Option B: Use Resend API (Easier)**
Since hosted Supabase might not use config.toml for SMTP:

1. Sign up at https://resend.com
2. Get API key
3. Add to Supabase Secrets: `RESEND_API_KEY`
4. Done! Emails will have credentials automatically

## Quick Summary

**To Fix Email Link:**
- Update Site URL in Supabase Dashboard → Settings → Auth

**To Fix Credentials in Email:**
- Add `SMTP_PASSWORD` secret
- OR use Resend API (easier for hosted)

**localhost:54324:**
- This is fine - it's just the email testing server

