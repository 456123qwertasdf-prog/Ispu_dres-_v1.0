-- Add comprehensive RLS policies for role-based access control
-- Migration: 20250113000002_add_rls_policies.sql

-- Create helper functions for role checking
CREATE OR REPLACE FUNCTION public.user_role()
RETURNS text AS $$
BEGIN
  -- Check for custom claims first
  IF auth.jwt() ->> 'user_role' IS NOT NULL THEN
    RETURN auth.jwt() ->> 'user_role';
  END IF;
  
  -- Default to 'user' for authenticated users
  RETURN 'user';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN public.user_role() = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if user is responder
CREATE OR REPLACE FUNCTION public.is_responder()
RETURNS boolean AS $$
BEGIN
  RETURN public.user_role() = 'responder';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get current user's reporter ID
CREATE OR REPLACE FUNCTION public.current_reporter_id()
RETURNS uuid AS $$
BEGIN
  -- This assumes reporter table has a user_id column linking to auth.users
  -- If not, you may need to adjust this logic
  RETURN (
    SELECT id FROM public.reporter 
    WHERE user_id = auth.uid()
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get current user's responder ID
CREATE OR REPLACE FUNCTION public.current_responder_id()
RETURNS uuid AS $$
BEGIN
  -- This assumes responder table has a user_id column linking to auth.users
  -- If not, you may need to adjust this logic
  RETURN (
    SELECT id FROM public.responder 
    WHERE user_id = auth.uid()
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add user_id columns to reporter and responder tables if they don't exist
ALTER TABLE public.reporter 
ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.responder 
ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

-- Add indexes for user_id columns
CREATE INDEX IF NOT EXISTS idx_reporter_user_id ON public.reporter(user_id);
CREATE INDEX IF NOT EXISTS idx_responder_user_id ON public.responder(user_id);

-- Drop existing policies to recreate them
DROP POLICY IF EXISTS "Allow authenticated users to insert reports" ON public.reports;
DROP POLICY IF EXISTS "Allow authenticated users to select reports" ON public.reports;
DROP POLICY IF EXISTS "Allow authenticated users to update reports" ON public.reports;
DROP POLICY IF EXISTS "Allow service role full access" ON public.reports;
DROP POLICY IF EXISTS "Allow anon users to insert reports" ON public.reports;
DROP POLICY IF EXISTS "Allow anon users to select reports" ON public.reports;

DROP POLICY IF EXISTS "Allow authenticated users to insert reporters" ON public.reporter;
DROP POLICY IF EXISTS "Allow authenticated users to select reporters" ON public.reporter;
DROP POLICY IF EXISTS "Allow authenticated users to update reporters" ON public.reporter;
DROP POLICY IF EXISTS "Allow service role full access to reporters" ON public.reporter;

DROP POLICY IF EXISTS "Allow authenticated users to insert responders" ON public.responder;
DROP POLICY IF EXISTS "Allow authenticated users to select responders" ON public.responder;
DROP POLICY IF EXISTS "Allow authenticated users to update responders" ON public.responder;
DROP POLICY IF EXISTS "Allow service role full access to responders" ON public.responder;

DROP POLICY IF EXISTS "Allow authenticated users to insert assignments" ON public.assignment;
DROP POLICY IF EXISTS "Allow authenticated users to select assignments" ON public.assignment;
DROP POLICY IF EXISTS "Allow authenticated users to update assignments" ON public.assignment;
DROP POLICY IF EXISTS "Allow service role full access to assignments" ON public.assignment;

-- REPORTS TABLE POLICIES
-- Allow users to create reports
CREATE POLICY "Users can create reports" ON public.reports
    FOR INSERT 
    TO authenticated 
    WITH CHECK (public.user_role() IN ('user', 'responder', 'admin'));

-- Allow users to read their own reports, responders to read assigned reports, admins to read all
CREATE POLICY "Users can read own reports, responders assigned reports, admins all" ON public.reports
    FOR SELECT 
    TO authenticated 
    USING (
        public.is_admin() OR
        (public.user_role() = 'user' AND reporter_uid = auth.uid()::text) OR
        (public.is_responder() AND responder_id = public.current_responder_id())
    );

-- Allow users to update their own reports, responders to update assigned reports, admins to update all
CREATE POLICY "Users can update own reports, responders assigned reports, admins all" ON public.reports
    FOR UPDATE 
    TO authenticated 
    USING (
        public.is_admin() OR
        (public.user_role() = 'user' AND reporter_uid = auth.uid()::text) OR
        (public.is_responder() AND responder_id = public.current_responder_id())
    );

-- Allow admins to delete reports
CREATE POLICY "Admins can delete reports" ON public.reports
    FOR DELETE 
    TO authenticated 
    USING (public.is_admin());

-- REPORTER TABLE POLICIES
-- Allow users to create their own reporter profile
CREATE POLICY "Users can create own reporter profile" ON public.reporter
    FOR INSERT 
    TO authenticated 
    WITH CHECK (
        public.user_role() IN ('user', 'responder', 'admin') AND
        (public.user_role() = 'admin' OR user_id = auth.uid())
    );

-- Allow users to read their own profile, admins to read all
CREATE POLICY "Users can read own profile, admins all" ON public.reporter
    FOR SELECT 
    TO authenticated 
    USING (
        public.is_admin() OR
        user_id = auth.uid()
    );

-- Allow users to update their own profile, admins to update all
CREATE POLICY "Users can update own profile, admins all" ON public.reporter
    FOR UPDATE 
    TO authenticated 
    USING (
        public.is_admin() OR
        user_id = auth.uid()
    );

-- RESPONDER TABLE POLICIES
-- Allow admins to create responder profiles
CREATE POLICY "Admins can create responder profiles" ON public.responder
    FOR INSERT 
    TO authenticated 
    WITH CHECK (public.is_admin());

-- Allow responders to read their own profile, admins to read all
CREATE POLICY "Responders can read own profile, admins all" ON public.responder
    FOR SELECT 
    TO authenticated 
    USING (
        public.is_admin() OR
        user_id = auth.uid()
    );

-- Allow responders to update their own profile, admins to update all
CREATE POLICY "Responders can update own profile, admins all" ON public.responder
    FOR UPDATE 
    TO authenticated 
    USING (
        public.is_admin() OR
        user_id = auth.uid()
    );

-- ASSIGNMENT TABLE POLICIES
-- Allow admins to create assignments
CREATE POLICY "Admins can create assignments" ON public.assignment
    FOR INSERT 
    TO authenticated 
    WITH CHECK (public.is_admin());

-- Allow responders to read their own assignments, admins to read all
CREATE POLICY "Responders can read own assignments, admins all" ON public.assignment
    FOR SELECT 
    TO authenticated 
    USING (
        public.is_admin() OR
        responder_id = public.current_responder_id()
    );

-- Allow responders to update their own assignments, admins to update all
CREATE POLICY "Responders can update own assignments, admins all" ON public.assignment
    FOR UPDATE 
    TO authenticated 
    USING (
        public.is_admin() OR
        responder_id = public.current_responder_id()
    );

-- Allow admins to delete assignments
CREATE POLICY "Admins can delete assignments" ON public.assignment
    FOR DELETE 
    TO authenticated 
    USING (public.is_admin());

-- AUDIT_LOG TABLE POLICIES (read-only for most users)
-- Allow admins to read all audit logs
CREATE POLICY "Admins can read all audit logs" ON public.audit_log
    FOR SELECT 
    TO authenticated 
    USING (public.is_admin());

-- Allow service role to insert audit logs (for system operations)
CREATE POLICY "Service role can insert audit logs" ON public.audit_log
    FOR INSERT 
    TO service_role 
    WITH CHECK (true);

-- Allow authenticated users to insert audit logs for their own actions
CREATE POLICY "Users can insert own audit logs" ON public.audit_log
    FOR INSERT 
    TO authenticated 
    WITH CHECK (user_id = auth.uid());

-- Add comments for documentation
COMMENT ON FUNCTION public.user_role() IS 'Returns the user role from JWT claims or defaults to user';
COMMENT ON FUNCTION public.is_admin() IS 'Returns true if user has admin role';
COMMENT ON FUNCTION public.is_responder() IS 'Returns true if user has responder role';
COMMENT ON FUNCTION public.current_reporter_id() IS 'Returns the reporter ID for the current user';
COMMENT ON FUNCTION public.current_responder_id() IS 'Returns the responder ID for the current user';
