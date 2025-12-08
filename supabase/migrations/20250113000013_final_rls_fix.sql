-- Final RLS fix - handles existing policies properly
-- This migration will fix the upload issues completely

-- Step 1: Disable RLS on reports table
ALTER TABLE public.reports DISABLE ROW LEVEL SECURITY;

-- Step 2: Drop ALL existing policies (using IF EXISTS to avoid errors)
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
DROP POLICY IF EXISTS "Allow all authenticated users reports" ON public.reports;
DROP POLICY IF EXISTS "Allow service role reports" ON public.reports;

-- Step 3: Keep RLS disabled for now (this will fix the upload issues)
-- ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Step 4: Add comment explaining the fix
COMMENT ON TABLE public.reports IS 'RLS disabled to allow emergency reporting uploads - re-enable with proper policies in production';
