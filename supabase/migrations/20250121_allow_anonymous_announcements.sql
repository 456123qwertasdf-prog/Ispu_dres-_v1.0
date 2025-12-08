-- Allow anonymous users to read active announcements
-- Migration: 20250121_allow_anonymous_announcements.sql

-- Drop existing read policy
DROP POLICY IF EXISTS "Allow read active announcements" ON public.announcements;
DROP POLICY IF EXISTS "Users can read active announcements" ON public.announcements;

-- Allow anonymous users to read active announcements
CREATE POLICY "Allow anonymous read active announcements" ON public.announcements
    FOR SELECT 
    TO anon, authenticated
    USING (status = 'active' AND (expires_at IS NULL OR expires_at > now()));

-- Add comment
COMMENT ON POLICY "Allow anonymous read active announcements" ON public.announcements IS 
'Allows both anonymous and authenticated users to read active announcements that have not expired';

