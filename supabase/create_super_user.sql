-- Create Super User Account
-- This script creates a super user account in the database
-- Run this script in your Supabase SQL editor or via psql

-- Replace these values with your desired super user credentials
DO $$
DECLARE
    v_email TEXT := 'superuser@lspu-dres.com';
    v_password TEXT := 'SuperUser@2024!';  -- Change this to a secure password
    v_firstname TEXT := 'Super';
    v_lastname TEXT := 'User';
    v_phone TEXT := '+639000000000';
    v_user_id UUID;
BEGIN
    -- Create auth user with super_user role
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        email_change,
        email_change_token_new,
        recovery_token
    )
    VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        v_email,
        crypt(v_password, gen_salt('bf')),
        NOW(),
        jsonb_build_object(
            'role', 'super_user',
            'full_name', v_firstname || ' ' || v_lastname,
            'firstname', v_firstname,
            'lastname', v_lastname,
            'phone', v_phone
        ),
        NOW(),
        NOW(),
        '',
        '',
        '',
        ''
    )
    ON CONFLICT (email) DO UPDATE
    SET 
        raw_user_meta_data = jsonb_build_object(
            'role', 'super_user',
            'full_name', v_firstname || ' ' || v_lastname,
            'firstname', v_firstname,
            'lastname', v_lastname,
            'phone', v_phone
        ),
        updated_at = NOW()
    RETURNING id INTO v_user_id;

    -- If user already exists, get the ID
    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id
        FROM auth.users
        WHERE email = v_email;
    END IF;

    -- Create or update user profile
    INSERT INTO public.user_profiles (
        user_id,
        role,
        name,
        phone,
        is_active,
        created_at,
        updated_at
    )
    VALUES (
        v_user_id,
        'super_user',
        v_firstname || ' ' || v_lastname,
        v_phone,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE
    SET 
        role = 'super_user',
        name = v_firstname || ' ' || v_lastname,
        phone = v_phone,
        is_active = true,
        updated_at = NOW();

    RAISE NOTICE 'Super user created/updated successfully!';
    RAISE NOTICE 'Email: %', v_email;
    RAISE NOTICE 'Password: %', v_password;
    RAISE NOTICE 'User ID: %', v_user_id;
    RAISE NOTICE '';
    RAISE NOTICE 'IMPORTANT: Change the password after first login!';
END $$;

-- Alternative: If you prefer to use Supabase Admin API instead
-- You can use the create-user edge function with:
-- {
--   "email": "superuser@lspu-dres.com",
--   "password": "YourSecurePassword123!",
--   "firstName": "Super",
--   "lastName": "User",
--   "role": "super_user",
--   "phone": "+639000000000",
--   "studentNumber": "",
--   "userType": "admin"
-- }

