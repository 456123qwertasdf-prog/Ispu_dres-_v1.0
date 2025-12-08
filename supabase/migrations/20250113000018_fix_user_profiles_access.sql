-- Fix user profiles access for admin dashboard
-- This migration adds admin access to user_profiles table

-- Add admin policy to read all user profiles
CREATE POLICY "Admins can read all user profiles" ON public.user_profiles
    FOR SELECT 
    TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND (
                auth.users.raw_user_meta_data ->> 'role' = 'admin'
                OR auth.users.raw_user_meta_data ->> 'user_role' = 'admin'
            )
        )
    );

-- Add policy for users to insert their own profile
CREATE POLICY "Users can insert own profile" ON public.user_profiles
    FOR INSERT 
    TO authenticated 
    USING (user_id = auth.uid());

-- Create function to automatically create user profile
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    user_role TEXT;
    user_name TEXT;
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
    
    -- Insert user profile
    INSERT INTO public.user_profiles (user_id, role, name, is_active)
    VALUES (NEW.id, user_role, user_name, true);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically create user profile on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create function to sync existing users to user_profiles
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
        INSERT INTO public.user_profiles (user_id, role, name, is_active, created_at)
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
            true,
            user_record.created_at
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the sync function to create profiles for existing users
SELECT public.sync_existing_users();

-- Add comments
COMMENT ON FUNCTION public.handle_new_user() IS 'Automatically creates user profile when new user signs up';
COMMENT ON FUNCTION public.sync_existing_users() IS 'Syncs existing users to user_profiles table';
