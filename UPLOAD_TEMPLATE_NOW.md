# ⚠️ CRITICAL: Upload Template to Supabase Dashboard

## Why Password Isn't Showing

The password is being generated correctly, but **Supabase's default template doesn't include it**. You MUST upload the custom template to your hosted Supabase project.

## Step-by-Step: Upload Template (2 minutes)

### Step 1: Open Supabase Dashboard
1. Go to: **https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/auth**
2. Sign in if needed

### Step 2: Find Email Templates Section
1. Scroll down to **"Email Templates"** section
2. Look for **"Invite User"** or **"Invite"** template
3. Click on it

### Step 3: Edit/Customize Template
1. Click **"Edit Template"** or **"Customize"** button
2. You should see a code editor or text area

### Step 4: Copy Template Content
1. Open this file: `supabase/templates/invite-credentials.html`
2. Select ALL content (Ctrl+A)
3. Copy it (Ctrl+C)

### Step 5: Paste into Dashboard
1. In the Supabase Dashboard template editor:
   - Select all existing content (Ctrl+A)
   - Delete it
   - Paste your template (Ctrl+V)
2. Click **"Save"** or **"Update"**

### Step 6: Verify Template Has Password Variable
Make sure your template includes this line:
```html
{{ if .Data.temporary_password }}
<span class="value">{{ .Data.temporary_password }}</span>
```

### Step 7: Test
1. Create a new user in User Management
2. Check email inbox
3. Password should now appear! ✅

## If Template Editor Not Showing

If you don't see a template editor:
1. Check if you're on the hosted project (not local)
2. Make sure SMTP is configured first (Settings → Auth → SMTP)
3. Try refreshing the page
4. Check Supabase documentation for latest UI

## Quick Check: Is Template Uploaded?

After uploading:
- The email should show the password
- The template should include: `{{ .Data.temporary_password }}`

If still not working:
- Check browser console for errors
- Verify SMTP is configured
- Make sure you saved the template changes

