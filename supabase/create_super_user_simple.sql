-- Simple Super User Creation Script
-- This uses Supabase's built-in functions to create a super user
-- Run this in Supabase SQL Editor

-- Step 1: Create the auth user (you'll need to do this via Supabase Dashboard or Edge Function)
-- The password will need to be set via Supabase Auth Admin API

-- Step 2: After creating the user via Dashboard/API, run this to set the role:
-- Replace 'superuser@lspu-dres.com' with your actual email

UPDATE auth.users
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || 
    jsonb_build_object(
        'role', 'super_user',
        'full_name', 'Super User',
        'firstname', 'Super',
        'lastname', 'User'
    )
WHERE email = 'superuser@lspu-dres.com';

-- Step 3: Create/update the user profile
INSERT INTO public.user_profiles (
    user_id,
    role,
    name,
    is_active
)
SELECT 
    id,
    'super_user',
    COALESCE(raw_user_meta_data->>'full_name', 'Super User'),
    true
FROM auth.users
WHERE email = 'superuser@lspu-dres.com'
ON CONFLICT (user_id) DO UPDATE
SET 
    role = 'super_user',
    is_active = true,
    updated_at = NOW();

-- Verify the super user was created
SELECT 
    u.email,
    u.raw_user_meta_data->>'role' as role,
    up.role as profile_role,
    up.name,
    up.is_active
FROM auth.users u
LEFT JOIN public.user_profiles up ON u.id = up.user_id
WHERE u.email = 'superuser@lspu-dres.com';

