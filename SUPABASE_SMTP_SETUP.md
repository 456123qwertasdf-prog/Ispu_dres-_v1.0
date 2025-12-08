# Configure Supabase SMTP to Send Credentials in Email

## Step-by-Step Setup

### Step 1: Add SMTP Password Secret

1. Go to: **https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/functions**
2. Click **"Secrets"** tab
3. Click **"Add new secret"**
4. Name: `SMTP_PASSWORD`
5. Value: `dweyrljbbmkjvooz` (your App Password - remove spaces, lowercase)
6. Click **"Save"**

### Step 2: Configure SMTP in Supabase Dashboard

1. Go to: **https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/auth**
2. Scroll to **"SMTP Settings"** section
3. Enable **"Custom SMTP"**
4. Fill in the SMTP settings:
   - **SMTP Host:** `smtp.gmail.com`
   - **SMTP Port:** `587`
   - **SMTP User:** `456123qwert.asdf@gmail.com`
   - **SMTP Password:** `dweyrljbbmkjvooz` (or use secret reference if available)
   - **Sender Email:** `456123qwert.asdf@gmail.com`
   - **Sender Name:** `LSPU Emergency Response System`
5. Click **"Save"**

### Step 3: Configure Custom Email Template

1. Still in **Settings → Auth**
2. Find **"Email Templates"** section
3. Click on **"Invite User"** template
4. Click **"Edit"** or **"Customize"**
5. You have two options:

   **Option A: Upload Custom Template**
   - Click **"Upload Template"** or **"Custom Template"**
   - Upload the file: `supabase/templates/verification-with-credentials.html`
   
   **Option B: Edit Template Directly**
   - Click **"Edit Template"**
   - Replace the content with the template that includes credentials
   - Make sure it includes: `{{ .UserMetaData.temporary_password }}`
6. Click **"Save"**

### Step 4: Verify Template Variables

Make sure your custom template includes these variables:
- `{{ .Email }}` - User's email
- `{{ .UserMetaData.temporary_password }}` - The password
- `{{ .UserMetaData.role }}` - User role
- `{{ .ConfirmationURL }}` - Verification link

### Step 5: Test

1. Create a new user in User Management
2. Check email inbox
3. Email should show credentials!

## Alternative: Use Supabase CLI (If Dashboard doesn't work)

If the dashboard doesn't have SMTP settings:

1. **Deploy config.toml changes:**
   ```bash
   supabase link --project-ref hmolyqzbvxxliemclrld
   supabase db push
   ```

2. **Set environment variables via CLI:**
   ```bash
   supabase secrets set SMTP_PASSWORD=dweyrljbbmkjvooz
   ```

## Troubleshooting

- **Template not loading?** Make sure template path is correct in config.toml
- **SMTP not working?** Check that SMTP_PASSWORD secret is added
- **Credentials still not showing?** Verify template has `{{ .UserMetaData.temporary_password }}`
- **For hosted:** Make sure to configure in Dashboard, not just config.toml

## Important Note

For **hosted Supabase projects**, the `config.toml` file is mainly for local development. The dashboard settings take precedence for hosted projects.

