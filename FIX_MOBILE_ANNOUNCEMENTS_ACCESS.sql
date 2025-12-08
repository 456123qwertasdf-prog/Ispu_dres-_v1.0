-- Fix Announcements RLS for Mobile App Access
-- This allows anonymous users (mobile app) to read active announcements
-- Safe to run - only modifies read policies, doesn't delete data

-- Step 1: Drop old read-only policies (safe - using IF EXISTS)
DROP POLICY IF EXISTS "Allow read active announcements" ON public.announcements;
DROP POLICY IF EXISTS "Users can read active announcements" ON public.announcements;
DROP POLICY IF EXISTS "Allow anonymous read active announcements" ON public.announcements;

-- Step 2: Create new policy that allows both anonymous and authenticated users to read active announcements
CREATE POLICY "Allow anonymous read active announcements" ON public.announcements
    FOR SELECT 
    TO anon, authenticated
    USING (
        status = 'active' 
        AND (expires_at IS NULL OR expires_at > now())
    );

-- Step 3: Add comment for documentation
COMMENT ON POLICY "Allow anonymous read active announcements" ON public.announcements IS 
'Allows both anonymous (mobile app) and authenticated (web app) users to read active announcements that have not expired';

-- Step 4: Verify the policy was created (optional - just shows the policy details)
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'announcements' 
AND policyname = 'Allow anonymous read active announcements';

