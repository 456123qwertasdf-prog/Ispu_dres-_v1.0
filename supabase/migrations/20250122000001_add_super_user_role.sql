-- Add super_user role to the system
-- Migration: 20250122000001_add_super_user_role.sql

-- Update user_profiles table to allow 'super_user' role
ALTER TABLE public.user_profiles 
DROP CONSTRAINT IF EXISTS user_profiles_role_check;

ALTER TABLE public.user_profiles 
ADD CONSTRAINT user_profiles_role_check 
CHECK (role IN ('citizen', 'responder', 'admin', 'super_user'));

-- Add super_user to user_roles table
INSERT INTO user_roles (name, description, permissions) VALUES
('super_user', 'Super User - Full system access with all privileges', '{"can_manage": true, "can_view_all": true, "can_assign": true, "can_configure": true, "can_manage_users": true, "can_manage_roles": true, "can_bypass_restrictions": true}')
ON CONFLICT (name) DO UPDATE
SET description = EXCLUDED.description,
    permissions = EXCLUDED.permissions;

-- Update is_admin() function to also recognize super_user
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM auth.users 
    WHERE auth.users.id = auth.uid() 
    AND (
      auth.users.raw_user_meta_data->>'role' = 'admin'
      OR auth.users.raw_user_meta_data->>'role' = 'super_user'
    )
  );
$$;

-- Update user_role() function to handle super_user
CREATE OR REPLACE FUNCTION public.user_role()
RETURNS text AS $$
DECLARE
  user_role_value text;
BEGIN
  -- Check auth.users table first (most reliable)
  SELECT raw_user_meta_data->>'role' INTO user_role_value
  FROM auth.users 
  WHERE id = auth.uid();
  
  -- If found, return it
  IF user_role_value IS NOT NULL THEN
    RETURN user_role_value;
  END IF;
  
  -- Check for custom claims in JWT
  IF auth.jwt() ->> 'user_role' IS NOT NULL THEN
    RETURN auth.jwt() ->> 'user_role';
  END IF;
  
  -- Check user_metadata in JWT
  IF (auth.jwt() -> 'user_metadata' ->> 'role') IS NOT NULL THEN
    RETURN auth.jwt() -> 'user_metadata' ->> 'role';
  END IF;
  
  -- Default to 'citizen' for authenticated users
  RETURN 'citizen';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create is_super_user() function
CREATE OR REPLACE FUNCTION public.is_super_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM auth.users 
    WHERE auth.users.id = auth.uid() 
    AND auth.users.raw_user_meta_data->>'role' = 'super_user'
  );
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.is_super_user() TO authenticated;

-- Update comment
COMMENT ON COLUMN public.user_profiles.role IS 'User role: citizen, responder, admin, or super_user';
COMMENT ON FUNCTION public.is_admin() IS 'Check if current user has admin or super_user role';
COMMENT ON FUNCTION public.is_super_user() IS 'Check if current user has super_user role';

