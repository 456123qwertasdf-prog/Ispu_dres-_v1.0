-- Fix Announcements Table Permissions
-- Run this in your Supabase SQL Editor

-- 1. Create is_admin function
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM auth.users 
    WHERE auth.users.id = auth.uid() 
    AND auth.users.raw_user_meta_data->>'role' = 'admin'
  );
$$;

-- 2. Grant execute permission
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- 3. Drop existing policies
DROP POLICY IF EXISTS "Users can read active announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins can read all announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins can insert announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins can update announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins can delete announcements" ON public.announcements;

-- 4. Create new simplified policies
-- Allow all authenticated users to read active announcements
CREATE POLICY "Allow read active announcements" ON public.announcements
    FOR SELECT 
    TO authenticated 
    USING (status = 'active' AND (expires_at IS NULL OR expires_at > now()));

-- Allow all authenticated users to insert announcements
CREATE POLICY "Allow insert announcements" ON public.announcements
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

-- Allow all authenticated users to update announcements
CREATE POLICY "Allow update announcements" ON public.announcements
    FOR UPDATE 
    TO authenticated 
    USING (true);

-- Allow all authenticated users to delete announcements
CREATE POLICY "Allow delete announcements" ON public.announcements
    FOR DELETE 
    TO authenticated 
    USING (true);

-- 5. Verify the policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'announcements';
