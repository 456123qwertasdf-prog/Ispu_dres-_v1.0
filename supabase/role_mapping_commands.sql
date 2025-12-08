-- Supabase Role Mapping Commands
-- Use these commands in your Supabase dashboard SQL editor or Edge Functions

-- 1. Set default role for authenticated users
-- This sets the default role to 'user' for all authenticated users
UPDATE auth.users 
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"user_role": "user"}'::jsonb
WHERE raw_user_meta_data ->> 'user_role' IS NULL;

-- 2. Grant responder role to specific user (replace with actual user ID)
-- Example: Grant responder role to user with email 'responder@example.com'
UPDATE auth.users 
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"user_role": "responder"}'::jsonb
WHERE email = 'responder@example.com';

-- 3. Grant admin role to specific user (replace with actual user ID)
-- Example: Grant admin role to user with email 'admin@example.com'
UPDATE auth.users 
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"user_role": "admin"}'::jsonb
WHERE email = 'admin@example.com';

-- 4. Create Edge Function to update user roles (optional)
-- This can be used in your application to dynamically assign roles
/*
CREATE OR REPLACE FUNCTION update_user_role(user_email text, new_role text)
RETURNS void AS $$
BEGIN
  UPDATE auth.users 
  SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || 
      jsonb_build_object('user_role', new_role)
  WHERE email = user_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
*/

-- 5. Query to check current user roles
SELECT 
  email,
  raw_user_meta_data ->> 'user_role' as user_role,
  created_at
FROM auth.users 
ORDER BY created_at DESC;

-- 6. Bulk role assignment examples
-- Assign multiple users as responders
UPDATE auth.users 
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"user_role": "responder"}'::jsonb
WHERE email IN ('responder1@example.com', 'responder2@example.com', 'responder3@example.com');

-- Assign multiple users as admins
UPDATE auth.users 
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"user_role": "admin"}'::jsonb
WHERE email IN ('admin1@example.com', 'admin2@example.com');
