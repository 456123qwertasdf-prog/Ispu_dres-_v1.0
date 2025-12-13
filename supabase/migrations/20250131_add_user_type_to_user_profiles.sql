-- Add user_type column to user_profiles table
-- This allows user_type (student, instructor, faculty_staff, security_guard) to be visible in the table editor

-- Add the column
ALTER TABLE IF EXISTS public.user_profiles
  ADD COLUMN IF NOT EXISTS user_type text;

-- Backfill existing data from auth.users metadata
DO $$
BEGIN
  -- Update existing user_profiles with user_type from auth metadata
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_profiles'
      AND column_name = 'user_type'
  ) THEN
    UPDATE public.user_profiles p
    SET user_type = COALESCE(
      p.user_type,
      (SELECT (u.raw_user_meta_data ->> 'user_type')
       FROM auth.users u
       WHERE u.id = p.user_id),
      'student' -- Default to student if not found
    )
    WHERE p.user_type IS NULL;
  END IF;
END $$;

-- Update handle_new_user() function to include user_type
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    user_role TEXT;
    user_name TEXT;
    user_type_value TEXT;
BEGIN
    -- Get user role from metadata, default to 'citizen'
    user_role := COALESCE(
        NEW.raw_user_meta_data ->> 'role',
        NEW.raw_user_meta_data ->> 'user_role',
        'citizen'
    );
    
    -- Get user name from metadata
    user_name := COALESCE(
        NEW.raw_user_meta_data ->> 'full_name',
        NEW.raw_user_meta_data ->> 'name',
        split_part(NEW.email, '@', 1)
    );
    
    -- Get user_type from metadata, default to 'student'
    user_type_value := COALESCE(
        NEW.raw_user_meta_data ->> 'user_type',
        'student'
    );
    
    -- Insert user profile with user_type
    INSERT INTO public.user_profiles (user_id, role, name, user_type, is_active)
    VALUES (NEW.id, user_role, user_name, user_type_value, true);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update sync_existing_users() function to include user_type
CREATE OR REPLACE FUNCTION public.sync_existing_users()
RETURNS void AS $$
DECLARE
    user_record RECORD;
BEGIN
    -- Loop through all existing users and create profiles if they don't exist
    FOR user_record IN 
        SELECT id, email, raw_user_meta_data, created_at
        FROM auth.users
        WHERE id NOT IN (SELECT user_id FROM public.user_profiles)
    LOOP
        INSERT INTO public.user_profiles (user_id, role, name, user_type, is_active, created_at)
        VALUES (
            user_record.id,
            COALESCE(
                user_record.raw_user_meta_data ->> 'role',
                user_record.raw_user_meta_data ->> 'user_role',
                'citizen'
            ),
            COALESCE(
                user_record.raw_user_meta_data ->> 'full_name',
                user_record.raw_user_meta_data ->> 'name',
                split_part(user_record.email, '@', 1)
            ),
            COALESCE(
                user_record.raw_user_meta_data ->> 'user_type',
                'student'
            ),
            true,
            user_record.created_at
        );
    END LOOP;
    
    -- Also update existing profiles that don't have user_type set
    UPDATE public.user_profiles p
    SET user_type = COALESCE(
        p.user_type,
        (SELECT (u.raw_user_meta_data ->> 'user_type')
         FROM auth.users u
         WHERE u.id = p.user_id),
        'student'
    )
    WHERE p.user_type IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to sync user_type when auth metadata is updated
CREATE OR REPLACE FUNCTION public.sync_user_type_from_auth()
RETURNS TRIGGER AS $$
BEGIN
    -- Update user_profiles when auth user metadata changes
    UPDATE public.user_profiles
    SET user_type = COALESCE(
        NEW.raw_user_meta_data ->> 'user_type',
        OLD.raw_user_meta_data ->> 'user_type',
        'student'
    )
    WHERE user_id = NEW.id
    AND (NEW.raw_user_meta_data ->> 'user_type') IS DISTINCT FROM (OLD.raw_user_meta_data ->> 'user_type');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to sync user_type when auth metadata is updated
DROP TRIGGER IF EXISTS sync_user_type_on_auth_update ON auth.users;
CREATE TRIGGER sync_user_type_on_auth_update
    AFTER UPDATE OF raw_user_meta_data ON auth.users
    FOR EACH ROW
    WHEN (NEW.raw_user_meta_data ->> 'user_type' IS DISTINCT FROM OLD.raw_user_meta_data ->> 'user_type')
    EXECUTE FUNCTION public.sync_user_type_from_auth();

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_type ON public.user_profiles(user_type);

-- Add comment
COMMENT ON COLUMN public.user_profiles.user_type IS 'User type: student, instructor, faculty_staff, or security_guard';
