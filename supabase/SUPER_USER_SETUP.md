# Super User Setup Guide

This guide explains how to set up a super user account in the LSPU Emergency Response System.

## What is a Super User?

A super user is a special role with full system access, including:
- All admin privileges
- User management capabilities
- Role management capabilities
- Ability to bypass restrictions
- Full system configuration access

## Setup Steps

### Step 1: Run the Migration

First, apply the database migration to add the super_user role:

```bash
# If using Supabase CLI locally
supabase db push

# Or run the migration file directly in Supabase SQL Editor
# File: supabase/migrations/20250122000001_add_super_user_role.sql
```

### Step 2: Create the Super User Account

You have two options:

#### Option A: Using the User Management UI (Recommended)

1. Log in as an admin user
2. Navigate to **User Management** page
3. Fill out the registration form:
   - **User Type**: Select any type (e.g., "Admin")
   - **ID Number**: Enter an ID (e.g., "SUPER001")
   - **Firstname**: Enter first name
   - **Lastname**: Enter last name
   - **Gmail**: Enter email (e.g., "superuser@lspu-dres.com")
   - **Password**: Enter a secure password (or leave empty to auto-generate)
   - **Contact Number**: Enter phone number
   - **Role**: Select **"Super User"** from the dropdown
4. Click **"Add"** to create the account
5. Save the credentials shown in the success modal

#### Option B: Using SQL Script

1. Open Supabase SQL Editor
2. Run the script: `supabase/create_super_user_simple.sql`
3. **Important**: First create the user via Supabase Dashboard → Authentication → Add User
   - Email: `superuser@lspu-dres.com` (or your preferred email)
   - Password: Set a secure password
4. Then run the SQL script to set the role and create the profile

### Step 3: Verify the Super User

Run this query to verify the super user was created correctly:

```sql
SELECT 
    u.email,
    u.raw_user_meta_data->>'role' as auth_role,
    up.role as profile_role,
    up.name,
    up.is_active
FROM auth.users u
LEFT JOIN public.user_profiles up ON u.id = up.user_id
WHERE u.raw_user_meta_data->>'role' = 'super_user';
```

## Using the Super User Account

1. Log in with the super user credentials
2. The super user will have access to all admin features
3. The `is_admin()` function will return `true` for super users
4. Super users can manage all users, including other admins

## Security Notes

- **Change the password** after first login
- Store super user credentials securely
- Limit the number of super user accounts
- Use super user account only for system administration tasks
- Regular admin accounts should be used for day-to-day operations

## Troubleshooting

### Super User Can't Access Admin Features

1. Verify the role in `auth.users.raw_user_meta_data->>'role'` is `'super_user'`
2. Verify the role in `user_profiles.role` is `'super_user'`
3. Check that the migration was applied successfully
4. Try logging out and logging back in

### Migration Fails

1. Check if the `user_profiles` table exists
2. Verify you have the necessary permissions
3. Check for any conflicting constraints
4. Review the migration file: `supabase/migrations/20250122000001_add_super_user_role.sql`

## Related Files

- Migration: `supabase/migrations/20250122000001_add_super_user_role.sql`
- SQL Script: `supabase/create_super_user_simple.sql`
- UI: `public/user-management.html` (updated to include super_user option)

