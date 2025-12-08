-- Fix assignment table RLS policies to allow proper access
-- Migration: 20250113000015_fix_assignment_rls.sql

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Admins can create assignments" ON public.assignment;
DROP POLICY IF EXISTS "Responders can read own assignments, admins all" ON public.assignment;
DROP POLICY IF EXISTS "Responders can update own assignments, admins all" ON public.assignment;
DROP POLICY IF EXISTS "Admins can delete assignments" ON public.assignment;

-- Create more permissive policies for assignment table
-- Allow authenticated users to read assignments (needed for admin dashboard)
CREATE POLICY "Authenticated users can read assignments" ON public.assignment
    FOR SELECT 
    TO authenticated 
    USING (true);

-- Allow authenticated users to create assignments (needed for assignment functionality)
CREATE POLICY "Authenticated users can create assignments" ON public.assignment
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

-- Allow authenticated users to update assignments (needed for status updates)
CREATE POLICY "Authenticated users can update assignments" ON public.assignment
    FOR UPDATE 
    TO authenticated 
    USING (true);

-- Allow authenticated users to delete assignments (needed for cleanup)
CREATE POLICY "Authenticated users can delete assignments" ON public.assignment
    FOR DELETE 
    TO authenticated 
    USING (true);

-- Ensure service role has full access
CREATE POLICY "Service role full access to assignments" ON public.assignment
    FOR ALL 
    TO service_role 
    USING (true);

-- Add comment for documentation
COMMENT ON TABLE public.assignment IS 'Assignment table with permissive RLS policies for emergency response system';
