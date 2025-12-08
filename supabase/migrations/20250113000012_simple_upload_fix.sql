-- Simple upload fix - only modify reports table
-- This works within standard Supabase permissions

-- Step 1: Disable RLS on reports table only
ALTER TABLE public.reports DISABLE ROW LEVEL SECURITY;

-- Step 2: Drop existing policies on reports table
DROP POLICY IF EXISTS "Users can view own reports" ON public.reports;
DROP POLICY IF EXISTS "Users can insert own reports" ON public.reports;
DROP POLICY IF EXISTS "Users can update own reports" ON public.reports;
DROP POLICY IF EXISTS "All users can view all reports" ON public.reports;
DROP POLICY IF EXISTS "Admins can view all reports" ON public.reports;
DROP POLICY IF EXISTS "Responders can view all reports" ON public.reports;
DROP POLICY IF EXISTS "Admins can update all reports" ON public.reports;
DROP POLICY IF EXISTS "Responders can update all reports" ON public.reports;
DROP POLICY IF EXISTS "Allow authenticated users to insert reports" ON public.reports;
DROP POLICY IF EXISTS "Allow authenticated users to select reports" ON public.reports;
DROP POLICY IF EXISTS "Allow authenticated users to update reports" ON public.reports;
DROP POLICY IF EXISTS "Allow service role full access" ON public.reports;
DROP POLICY IF EXISTS "Allow anon users to insert reports" ON public.reports;
DROP POLICY IF EXISTS "Allow anon users to select reports" ON public.reports;
DROP POLICY IF EXISTS "Citizens can view own reports" ON public.reports;
DROP POLICY IF EXISTS "Citizens can insert own reports" ON public.reports;
DROP POLICY IF EXISTS "Citizens can update own reports" ON public.reports;
DROP POLICY IF EXISTS "Responders can view all reports" ON public.reports;
DROP POLICY IF EXISTS "Responders can update assigned reports" ON public.reports;
DROP POLICY IF EXISTS "Admins can view all reports" ON public.reports;

-- Step 3: Create simple, permissive policy for reports table
CREATE POLICY "Allow all authenticated users reports" ON public.reports
    FOR ALL 
    TO authenticated 
    USING (true) 
    WITH CHECK (true);

CREATE POLICY "Allow service role reports" ON public.reports
    FOR ALL 
    TO service_role 
    USING (true) 
    WITH CHECK (true);

-- Step 4: Re-enable RLS on reports table
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Step 5: Add comments
COMMENT ON POLICY "Allow all authenticated users reports" ON public.reports IS 'Allows all authenticated users full access to reports table';
COMMENT ON POLICY "Allow service role reports" ON public.reports IS 'Allows service role full access to reports table';
