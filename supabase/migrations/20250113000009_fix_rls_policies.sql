-- Fix Row Level Security policies for reports and storage
-- This migration fixes RLS policies that are blocking user access

-- Drop existing policies that might be causing issues
DROP POLICY IF EXISTS "Users can view own reports" ON reports;
DROP POLICY IF EXISTS "Users can insert own reports" ON reports;
DROP POLICY IF EXISTS "Users can update own reports" ON reports;
DROP POLICY IF EXISTS "Users can view all reports" ON reports;
DROP POLICY IF EXISTS "All users can view all reports" ON reports;

-- Drop storage policies
DROP POLICY IF EXISTS "Users can upload images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view images" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload emergency images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view emergency images" ON storage.objects;

-- Create new RLS policies for reports table
-- Allow authenticated users to view their own reports
CREATE POLICY "Users can view own reports" ON reports
    FOR SELECT USING (auth.uid() = reporter_uid);

-- Allow authenticated users to insert their own reports
CREATE POLICY "Users can insert own reports" ON reports
    FOR INSERT WITH CHECK (auth.uid() = reporter_uid);

-- Allow authenticated users to update their own reports
CREATE POLICY "Users can update own reports" ON reports
    FOR UPDATE USING (auth.uid() = reporter_uid);

-- Allow all authenticated users to view all reports (for responders/admins)
CREATE POLICY "All users can view all reports" ON reports
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Create new RLS policies for storage
-- Allow authenticated users to upload images
CREATE POLICY "Users can upload images" ON storage.objects
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Allow authenticated users to view images
CREATE POLICY "Users can view images" ON storage.objects
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Allow authenticated users to update their own images
CREATE POLICY "Users can update own images" ON storage.objects
    FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Allow authenticated users to delete their own images
CREATE POLICY "Users can delete own images" ON storage.objects
    FOR DELETE USING (auth.uid() IS NOT NULL);

-- Ensure RLS is enabled on reports table
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Ensure RLS is enabled on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Add comments for documentation
COMMENT ON POLICY "Users can view own reports" ON reports IS 'Allows users to view their own reports';
COMMENT ON POLICY "Users can insert own reports" ON reports IS 'Allows users to create reports';
COMMENT ON POLICY "Users can update own reports" ON reports IS 'Allows users to update their own reports';
COMMENT ON POLICY "All users can view all reports" ON reports IS 'Allows all authenticated users to view all reports';
COMMENT ON POLICY "Users can upload images" ON storage.objects IS 'Allows authenticated users to upload images';
COMMENT ON POLICY "Users can view images" ON storage.objects IS 'Allows authenticated users to view images';
