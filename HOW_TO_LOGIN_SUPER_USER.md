# How to Log In as Super User

## Step-by-Step Guide

### Step 1: Apply the Database Migration (First Time Only)

Before creating a super user, you need to apply the migration:

**Option A: Using Supabase CLI (if you have it set up)**
```bash
cd lspu_dres
supabase db push
```

**Option B: Using Supabase Dashboard**
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Open the file: `supabase/migrations/20250122000001_add_super_user_role.sql`
4. Copy and paste the entire content
5. Click **Run** to execute the migration

### Step 2: Create the Super User Account

You have **two options** to create the super user:

---

#### **Option A: Using User Management UI (Easiest - Recommended)**

1. **Log in as an existing admin user**
   - Go to `login.html` in your browser
   - Log in with an admin account

2. **Navigate to User Management**
   - Click on **"User Management"** in the sidebar
   - Or go directly to: `user-management.html`

3. **Fill out the registration form:**
   - **User Type**: Select any (e.g., "Admin")
   - **ID Number**: Enter an ID (e.g., "SUPER001")
   - **Firstname**: Enter first name (e.g., "Super")
   - **Lastname**: Enter last name (e.g., "User")
   - **Gmail**: Enter email (e.g., "superuser@lspu-dres.com")
   - **Password**: 
     - Enter a secure password (e.g., "SuperUser@2024!")
     - OR leave empty to auto-generate (password will be shown in modal)
   - **Contact Number**: Enter phone (e.g., "+639000000000")
   - **Role**: **Select "Super User"** from the dropdown ⭐

4. **Click "Add" button**

5. **Save the credentials**
   - A success modal will appear showing:
     - Email
     - Password (if auto-generated or the one you entered)
   - **IMPORTANT**: Copy these credentials or take a screenshot!

---

#### **Option B: Using SQL Script**

1. **Create the user in Supabase Dashboard:**
   - Go to Supabase Dashboard → **Authentication** → **Users**
   - Click **"Add User"** or **"Invite User"**
   - Enter:
     - **Email**: `superuser@lspu-dres.com` (or your preferred email)
     - **Password**: Set a secure password (e.g., `SuperUser@2024!`)
   - Click **"Create User"**

2. **Set the super_user role:**
   - Go to **SQL Editor** in Supabase Dashboard
   - Open the file: `supabase/create_super_user_simple.sql`
   - **Update the email** in the script (line with `WHERE email = 'superuser@lspu-dres.com'`)
   - Copy and paste the entire script
   - Click **Run**

3. **Verify the user was created:**
   - Run this query to check:
   ```sql
   SELECT 
       u.email,
       u.raw_user_meta_data->>'role' as role,
       up.role as profile_role
   FROM auth.users u
   LEFT JOIN public.user_profiles up ON u.id = up.user_id
   WHERE u.email = 'superuser@lspu-dres.com';
   ```
   - You should see `role` and `profile_role` both as `super_user`

---

### Step 3: Log In with Super User Account

1. **Go to the login page:**
   - Open `login.html` in your browser
   - Or navigate to your application's login URL

2. **Enter credentials:**
   - **Email**: The email you used when creating the account
     - Example: `superuser@lspu-dres.com`
   - **Password**: The password you set (or the auto-generated one)

3. **Click "Sign In" or "Log In"**

4. **You should be redirected to the admin dashboard**
   - Super users have the same access as admins
   - You'll have access to all admin features

---

## Troubleshooting

### ❌ "Invalid login credentials"
- **Check**: Make sure you're using the correct email and password
- **Solution**: If you forgot the password:
  1. Go to Supabase Dashboard → Authentication → Users
  2. Find your super user account
  3. Click on it → **"Reset Password"** or **"Send Password Reset Email"**

### ❌ "User not admin, redirecting to login"
- **Check**: The migration might not have been applied
- **Solution**: 
  1. Verify the migration was run successfully
  2. Check the user's role in database:
     ```sql
     SELECT raw_user_meta_data->>'role' FROM auth.users WHERE email = 'your-email@example.com';
     ```
  3. Should return `super_user`

### ❌ Can't access admin features
- **Check**: User profile might not have the correct role
- **Solution**: Run this SQL to fix it:
  ```sql
  UPDATE public.user_profiles
  SET role = 'super_user'
  WHERE user_id = (SELECT id FROM auth.users WHERE email = 'your-email@example.com');
  ```

### ❌ Migration fails
- **Check**: Make sure you have the necessary permissions
- **Solution**: Run the migration as a database admin or service role

---

## Quick Reference

**Default Super User Credentials** (if using SQL script):
- **Email**: `superuser@lspu-dres.com`
- **Password**: `SuperUser@2024!` (change this after first login!)

**Login URL**: `http://localhost:8000/login.html` (or your server URL)

**After Login**: You'll be redirected to `admin.html` (admin dashboard)

---

## Security Reminder

⚠️ **IMPORTANT**: 
- Change the password after first login
- Don't share super user credentials
- Use super user account only for system administration
- Create regular admin accounts for day-to-day operations

---

## Need Help?

If you're still having issues:
1. Check the browser console for errors (F12 → Console)
2. Verify the migration was applied: Check `user_roles` table for `super_user` entry
3. Check user metadata: Verify `raw_user_meta_data->>'role'` is `'super_user'`

