-- Add Super User: 456123qwert.asdf@gmail.com
-- Role: super_user | Password: Qwert123!
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New query).
--
-- If you get permission errors on auth.users (e.g. on hosted Supabase):
-- 1. Create the user first: Dashboard → Authentication → Users → Add user
--    Email: 456123qwert.asdf@gmail.com, Password: Qwert123!
-- 2. Then run the "Alternative: set role for existing user" block below instead.

DO $$
DECLARE
    v_email TEXT := '456123qwert.asdf@gmail.com';
    v_password TEXT := 'Qwert123!';
    v_fullname TEXT := 'Super User';
    v_phone TEXT := '';
    v_user_id UUID;
BEGIN
    -- Check if auth user already exists
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email LIMIT 1;

    IF v_user_id IS NOT NULL THEN
        -- Update existing auth user to super_user
        UPDATE auth.users
        SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
                'role', 'super_user',
                'full_name', v_fullname,
                'firstname', 'Super',
                'lastname', 'User'
            ),
            updated_at = NOW()
        WHERE id = v_user_id;
    ELSE
        -- Create new auth user with super_user role
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
                'full_name', v_fullname,
                'firstname', 'Super',
                'lastname', 'User',
                'phone', v_phone
            ),
            NOW(),
            NOW(),
            '',
            '',
            '',
            ''
        )
        RETURNING id INTO v_user_id;
    END IF;

    -- Create or update user profile (super_user)
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
        v_fullname,
        NULLIF(TRIM(v_phone), ''),
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE
    SET
        role = 'super_user',
        name = v_fullname,
        phone = NULLIF(TRIM(v_phone), ''),
        is_active = true,
        updated_at = NOW();

    RAISE NOTICE 'Super user created/updated successfully.';
    RAISE NOTICE 'Email: %', v_email;
    RAISE NOTICE 'Password: %', v_password;
    RAISE NOTICE 'User ID: %', v_user_id;
END $$;

-- Alternative: set role for existing user (run this if you created the user in Dashboard first)
-- UPDATE auth.users
-- SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
--         'role', 'super_user',
--         'full_name', 'Super User',
--         'firstname', 'Super',
--         'lastname', 'User'
--     ),
--     updated_at = NOW()
-- WHERE email = '456123qwert.asdf@gmail.com';
--
-- INSERT INTO public.user_profiles (user_id, role, name, is_active)
-- SELECT id, 'super_user', COALESCE(raw_user_meta_data->>'full_name', 'Super User'), true
-- FROM auth.users WHERE email = '456123qwert.asdf@gmail.com'
-- ON CONFLICT (user_id) DO UPDATE SET role = 'super_user', is_active = true, updated_at = NOW();
