# Fixed: Credentials and Redirect Issues

## Issues Fixed

### 1. ✅ Credentials Not Showing in Email
**Problem**: The default Supabase email template doesn't include the password.

**Solution**: 
- Credentials are now **immediately displayed** in an alert popup when you create a user
- Credentials are also logged to the browser console
- The API response includes credentials directly

### 2. ✅ Redirect URL Wrong (Connection Refused Error)
**Problem**: "Accept the invite" link was pointing to `localhost:3000` but your app runs on port `8000`.

**Solution**:
- Updated `config.toml` to use `http://127.0.0.1:8000`
- Verification links now redirect to `http://127.0.0.1:8000/login.html`
- Added multiple redirect URLs for flexibility

## How to Use

### For Admins Creating Users:

1. **Create a user** in the User Management page
2. **An alert will pop up** showing:
   ```
   User Created Successfully!
   
   📧 Email: user@gmail.com
   🔑 Password: Abc123!@#Xyz
   
   ⚠️ IMPORTANT: 
   - These credentials have been sent to the user's email
   - The user should change their password after first login
   - Share these credentials with the user if email was not received
   ```
3. **Copy the credentials** from the alert
4. **Share with the user** if they didn't receive the email

### For Users Receiving Invitation:

**Option 1: Use the Email Link**
1. Click "Accept the invite" in the email
2. Will redirect to `http://127.0.0.1:8000/login.html`
3. Login with credentials from email (once custom template is configured)

**Option 2: Direct Login**
1. Go to `http://127.0.0.1:8000/login.html`
2. Use credentials provided by admin
3. Login and change password

## Important Notes

### Current Email Behavior
- **Email is sent** with verification link
- **Password is NOT in email yet** (needs custom template + SMTP)
- **Credentials are shown to admin** immediately after creation

### To Show Credentials in Email Too

You need to configure custom email template (see `EMAIL_VERIFICATION_SETUP.md`):

1. Enable SMTP in `supabase/config.toml`
2. Enable custom template in `supabase/config.toml`
3. Restart Supabase

### Restart Supabase (Local Development)

After updating `config.toml`, restart:
```bash
supabase stop
supabase start
```

For production/hosted Supabase, update settings in the dashboard.

## Testing

1. **Create a test user** in User Management
2. **Check the alert** - credentials should be displayed
3. **Check browser console** - credentials logged there too
4. **Click "Accept the invite"** - should redirect to login page on port 8000
5. **Login with credentials** - should work

## Summary

✅ **Credentials**: Now shown immediately to admin when creating user
✅ **Redirect URL**: Fixed to use port 8000 and redirect to login page
✅ **Email Link**: Now redirects correctly after verification

The user can now:
- See credentials immediately (admin shares them)
- Use "Accept the invite" link which redirects to login page
- Login directly with credentials

