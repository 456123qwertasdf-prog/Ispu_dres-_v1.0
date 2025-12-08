# Email Verification Setup Guide

This guide explains how to configure Gmail verification with credentials for user management.

## Overview

The user management system now includes:
- **Automatic password generation** if no password is provided when creating a user
- **Email verification** with login credentials sent to the user's Gmail
- **Password change reminders** prompting users to change their temporary password after first login

## How It Works

1. When an admin creates a new user account:
   - If a password is provided, it will be used
   - If no password is provided, a secure 12-character password is auto-generated
   - The system sends a verification email with:
     - Login credentials (email and password)
     - Verification link
     - Instructions to change password after first login

2. The user receives an email with:
   - Their email address
   - Temporary/temporary password
   - Role information
   - Link to verify their email address
   - Security reminder to change password

## Email Configuration

### Option 1: Using Supabase Default Email (Recommended for Development)

Supabase's default email service will send verification emails. To ensure passwords are included:

1. Configure SMTP in `supabase/config.toml`:
   ```toml
   [auth.email.smtp]
   enabled = true
   host = "smtp.gmail.com"  # Or your SMTP provider
   port = 587
   user = "your-email@gmail.com"
   pass = "env(SMTP_PASSWORD)"
   admin_email = "your-email@gmail.com"
   sender_name = "LSPU Emergency Response System"
   ```

2. Use custom email template:
   ```toml
   [auth.email.template.invite]
   subject = "Account Verification - LSPU Emergency Response System"
   content_path = "./supabase/templates/verification-with-credentials.html"
   ```

3. Set environment variable:
   ```bash
   SMTP_PASSWORD=your-app-specific-password
   ```

### Option 2: Using Third-Party Email Service (Recommended for Production)

For production, consider using:
- **Resend** (recommended)
- **SendGrid**
- **AWS SES**
- **Mailgun**

These services provide better deliverability and analytics.

## Configuration Steps

1. **Enable Email Confirmations** (if needed):
   ```toml
   [auth.email]
   enable_confirmations = true  # Set to true to require email confirmation
   ```

2. **Configure SMTP** (see Option 1 above)

3. **Update Site URL**:
   ```toml
   [auth]
   site_url = "https://your-domain.com"
   additional_redirect_urls = ["https://your-domain.com/*"]
   ```

## Testing

1. In development, Supabase uses Inbucket for email testing
2. Access Inbucket at `http://localhost:54324`
3. All emails sent during development will appear here

## Security Notes

- Temporary passwords are auto-generated with 12 characters including special characters
- Passwords are marked as temporary in user metadata
- Users are prompted to change password after first login
- Email credentials are sent securely via the configured email service

## Troubleshooting

### Emails Not Sending
- Check SMTP configuration in `config.toml`
- Verify SMTP credentials are correct
- Check Supabase logs for email sending errors
- Ensure email service (Inbucket) is running in development

### Password Not in Email
- Ensure custom email template is configured
- Check that `temporary_password` is in user metadata
- Verify SMTP is properly configured

### Verification Links Not Working
- Check `site_url` in `config.toml`
- Verify redirect URLs are configured correctly
- Ensure verification link expiration is set appropriately

## API Response

When creating a user, the API returns:
```json
{
  "user": {...},
  "profile": {...},
  "message": "User created successfully. Verification email sent.",
  "password_sent": true,
  "email": "user@example.com",
  "verification_link": "https://...",
  "email_content": {
    "subject": "...",
    "html": "..."
  }
}
```

The `email_content` field contains the email HTML that can be used for manual sending if automated email fails.

