# Fix All Email Problems - Step by Step

## The 3 Problems:

1. ✅ **localhost:54324** - This is NORMAL! It's Inbucket (email testing server)
2. ❌ **Email shows localhost:3000** - Need to update Site URL in Supabase Dashboard
3. ❌ **Credentials NOT in email** - Need to configure SMTP or use Resend

---

## Fix #1: Update Site URL (For localhost:3000 Issue)

**The problem:** Hosted Supabase uses its own Site URL, not your config.toml

**The fix:**

1. Go to: **https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/auth**
2. Scroll to **"URL Configuration"** section
3. Find **"Site URL"** field
4. Change from: `http://localhost:3000`
5. Change to: `http://127.0.0.1:8000`
6. Scroll to **"Redirect URLs"** section
7. Add these URLs (one per line):
   ```
   http://127.0.0.1:8000
   http://127.0.0.1:8000/login.html
   http://localhost:8000
   http://localhost:8000/login.html
   ```
8. Click **"Save"** button

**Now emails will use the correct URL!**

---

## Fix #2: Add Credentials to Email

You have 2 options:

### Option A: Use Resend API (EASIEST - Recommended) ✅

1. **Sign up**: https://resend.com/signup
2. **Get API Key**: Dashboard → API Keys → Create API Key
3. **Add to Supabase**:
   - Go to: https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/functions
   - Click **"Secrets"** tab
   - Click **"Add new secret"**
   - Name: `RESEND_API_KEY`
   - Value: Your Resend API key
   - Click **Save**
4. **Test**: Create a new user - email will have credentials!

### Option B: Use Gmail SMTP (More Complex)

**Problem:** Hosted Supabase doesn't use config.toml for SMTP. You need:

1. **Add SMTP Password Secret**:
   - Go to Supabase Dashboard → Settings → Edge Functions → Secrets
   - Add: `SMTP_PASSWORD` = `dweyrljbbmkjvooz`

2. **Configure SMTP in Dashboard** (if available):
   - Some hosted Supabase projects have SMTP settings in dashboard
   - Check: Settings → Auth → Email Templates
   - Configure SMTP there

3. **If Dashboard doesn't have SMTP settings:**
   - You MUST use Resend API (Option A)
   - Or configure via Supabase CLI for hosted project

**Recommendation:** Use Resend API (Option A) - it's easier and works immediately!

---

## Why Admin Sees Credentials But Email Doesn't

- **Admin popup**: Always shows credentials (from API response)
- **Email**: Only shows credentials if:
  - Resend API is configured, OR
  - SMTP + custom template is properly configured in hosted Supabase

Currently, the email uses Supabase's default template (no credentials).

---

## Quick Action Items

1. ✅ Update Site URL in Dashboard → Settings → Auth
2. ✅ Choose: Resend API (easier) OR Gmail SMTP (harder)
3. ✅ Test by creating a new user

After these fixes:
- ✅ Email link will be correct (127.0.0.1:8000)
- ✅ Email will show credentials
- ✅ Everything works!

