# Email Verification Explained

## What Does "Accept the Invite" Mean?

**"Accept the Invite"** (or "Verify Email Address") is a verification link that:
1. **Verifies the email address** - Confirms that the email belongs to the user
2. **Activates the account** - Completes the account setup process
3. **Sets up the account** - Allows the user to log in with their credentials

When a user clicks this link, they are taken to your application where they can:
- Verify their email address
- Log in with the credentials provided in the email
- Change their temporary password (if applicable)

## What Should Be in the Email?

The verification email should include:

1. **Login Credentials** (shown clearly):
   - **Email**: The user's email address (e.g., `user@gmail.com`)
   - **Temporary Password**: The auto-generated or admin-provided password (e.g., `Abc123!@#Xyz`)
   - **Role**: The user's assigned role (e.g., Student, Teacher, Admin)

2. **Verification Link** (the "Accept the Invite" button):
   - Clicking this link verifies the email and activates the account
   - The link looks like: `https://your-project.supabase.co/auth/v1/verify?token=...`

3. **Instructions**:
   - How to log in
   - Reminder to change password after first login
   - Contact information if needed

## Current Status

Right now, Supabase is sending the default invite email which:
- ✅ Has the verification link ("Accept the invite")
- ❌ Does NOT show the password in the email body
- ❌ Does NOT show the credentials clearly

## Solution: Configure Custom Email Template

To make the email show credentials properly, you need to:

### Step 1: Configure SMTP in `supabase/config.toml`

Uncomment and configure the SMTP settings:

```toml
[auth.email.smtp]
enabled = true
host = "smtp.gmail.com"
port = 587
user = "your-email@gmail.com"
pass = "env(SMTP_PASSWORD)"
admin_email = "your-email@gmail.com"
sender_name = "LSPU Emergency Response System"
```

### Step 2: Enable Custom Email Template

Uncomment the template configuration:

```toml
[auth.email.template.invite]
subject = "Account Verification - LSPU Emergency Response System"
content_path = "./supabase/templates/verification-with-credentials.html"
```

### Step 3: Set Environment Variable

Create a `.env` file or set in your environment:
```
SMTP_PASSWORD=your-gmail-app-specific-password
```

For Gmail, you'll need to:
1. Enable 2-Step Verification
2. Generate an "App Password" from Google Account settings
3. Use that app password in the config

### Step 4: Restart Supabase

After configuring, restart your Supabase instance:
```bash
supabase stop
supabase start
```

## Testing

After configuration:
1. Create a new user account
2. Check the email inbox (or Inbucket at `http://localhost:54324` in development)
3. The email should now show:
   - ✅ Email address
   - ✅ Temporary password
   - ✅ Role
   - ✅ Verification link ("Accept the Invite" / "Verify Email Address")
   - ✅ Instructions to change password

## Alternative: Manual Email Sending

If you can't configure SMTP right now, the system returns the email HTML content in the API response. You can:
1. Copy the `email_content.html` from the API response
2. Send it manually via your email client
3. Or use the credentials to log in directly (credentials are also in the response)

## What Users Should Do

When users receive the email:

1. **See the credentials** clearly displayed (email and password)
2. **Click "Verify Email Address"** or "Accept the Invite" to verify their email
3. **Log in** using the provided credentials
4. **Change password** immediately after first login for security

The verification link is important because it:
- Confirms the email address is valid
- Completes the account activation
- Usually redirects to your login page or dashboard

