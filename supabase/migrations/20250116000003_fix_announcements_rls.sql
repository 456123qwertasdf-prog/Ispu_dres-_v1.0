-- Fix announcements RLS policies
-- Migration: 20250116000003_fix_announcements_rls.sql

-- Drop existing policies
DROP POLICY IF EXISTS "Users can read active announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins can read all announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins can insert announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins can update announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins can delete announcements" ON public.announcements;

-- Create simpler RLS policies
-- Allow all authenticated users to read active announcements
CREATE POLICY "Allow read active announcements" ON public.announcements
    FOR SELECT 
    TO authenticated 
    USING (status = 'active' AND (expires_at IS NULL OR expires_at > now()));

-- Allow all authenticated users to insert announcements (for now)
CREATE POLICY "Allow insert announcements" ON public.announcements
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

-- Allow all authenticated users to update announcements (for now)
CREATE POLICY "Allow update announcements" ON public.announcements
    FOR UPDATE 
    TO authenticated 
    USING (true);

-- Allow all authenticated users to delete announcements (for now)
CREATE POLICY "Allow delete announcements" ON public.announcements
    FOR DELETE 
    TO authenticated 
    USING (true);

-- Add comment
COMMENT ON TABLE public.announcements IS 'Announcements table with simplified RLS policies for testing';
