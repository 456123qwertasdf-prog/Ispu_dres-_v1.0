-- Create Demo Responder Account (Security Guard)
-- This script creates a responder account with user_type = security_guard for demo/testing.
-- Run this script in your Supabase SQL editor or via psql.

DO $$
DECLARE
    v_email TEXT := 'securityguard@lspu-dres.com';
    v_password TEXT := 'DemoGuard@2024!';  -- Change this after first login if needed
    v_fullname TEXT := 'Demo Security Guard';
    v_phone TEXT := '+639123456789';
    v_user_id UUID;
BEGIN
    -- Check if auth user already exists (auth.users may not have ON CONFLICT on email)
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email LIMIT 1;

    IF v_user_id IS NOT NULL THEN
        -- Update existing auth user
        UPDATE auth.users
        SET raw_user_meta_data = jsonb_build_object(
                'role', 'responder',
                'user_type', 'security_guard',
                'full_name', v_fullname,
                'phone', v_phone
            ),
            updated_at = NOW()
        WHERE id = v_user_id;
    ELSE
        -- Create new auth user with responder role and security_guard user_type
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
                'role', 'responder',
                'user_type', 'security_guard',
                'full_name', v_fullname,
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

    -- Create or update user profile (responder, security_guard)
    INSERT INTO public.user_profiles (
        user_id,
        role,
        name,
        user_type,
        phone,
        is_active,
        created_at,
        updated_at
    )
    VALUES (
        v_user_id,
        'responder',
        v_fullname,
        'security_guard',
        v_phone,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE
    SET
        role = 'responder',
        name = v_fullname,
        user_type = 'security_guard',
        phone = v_phone,
        is_active = true,
        updated_at = NOW();

    -- Create or update responder row (for dashboard, assignments, availability)
    IF EXISTS (SELECT 1 FROM public.responder WHERE user_id = v_user_id) THEN
        UPDATE public.responder
        SET name = v_fullname, phone = v_phone, role = 'Security Guard',
            status = 'active', is_available = true, updated_at = NOW()
        WHERE user_id = v_user_id;
    ELSE
        INSERT INTO public.responder (user_id, name, phone, role, status, is_available, created_at, updated_at)
        VALUES (v_user_id, v_fullname, v_phone, 'Security Guard', 'active', true, NOW(), NOW());
    END IF;

    RAISE NOTICE 'Demo responder (Security Guard) created/updated successfully.';
    RAISE NOTICE 'Email: %', v_email;
    RAISE NOTICE 'Password: %', v_password;
    RAISE NOTICE 'User ID: %', v_user_id;
    RAISE NOTICE 'Login as this user to use the responder dashboard.';
END $$;
