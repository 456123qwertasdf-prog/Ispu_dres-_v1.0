# Complete SMTP Setup - Quick Guide

You have your App Password: `dwey rljb bmkj vooz`

Now let's set it up:

## Step 1: Add to Supabase Secrets

### For Hosted/Production Supabase:
1. Go to: https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld
2. Go to **Settings** → **Edge Functions** → **Secrets**
3. Click **"Add new secret"**
4. Name: `SMTP_PASSWORD`
5. Value: `dweyrljbbmkjvooz` (remove spaces, all lowercase)
6. Click **Save**

### For Local Development:
1. Create `.env` file in project root (if not exists)
2. Add this line:
   ```
   SMTP_PASSWORD=dweyrljbbmkjvooz
   ```
3. Save the file

## Step 2: Update config.toml

Edit `supabase/config.toml` and uncomment/update these sections (around line 190):

```toml
[auth.email.smtp]
enabled = true
host = "smtp.gmail.com"
port = 587
user = "your-email@gmail.com"  # Replace with YOUR Gmail address
pass = "env(SMTP_PASSWORD)"
admin_email = "your-email@gmail.com"  # Replace with YOUR Gmail address
sender_name = "LSPU Emergency Response System"

[auth.email.template.invite]
subject = "Account Verification - LSPU Emergency Response System"
content_path = "./supabase/templates/verification-with-credentials.html"
```

**Important:** Replace `your-email@gmail.com` with your actual Gmail address!

## Step 3: Restart Supabase (if local)

```bash
supabase stop
supabase start
```

## Step 4: Test It!

1. Create a new user in User Management
2. Check the email inbox
3. The email should now show:
   - ✅ Email address
   - ✅ Password (credentials!)
   - ✅ Role
   - ✅ Verification link
   - ✅ All instructions

## Troubleshooting

- **Email not sent?** Double-check your Gmail address in config.toml
- **Password format:** Make sure to remove spaces: `dweyrljbbmkjvooz` (all lowercase)
- **For hosted Supabase:** The config.toml changes might need to be applied via dashboard

You're all set! 🎉

