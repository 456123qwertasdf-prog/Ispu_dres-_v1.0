-- Fix Storage Setup for Emergency Reports
-- This migration uses the correct approach for Supabase storage setup

-- Note: Storage buckets and policies should be created via Supabase Dashboard
-- This SQL file provides the correct RLS policies that can be applied

-- RLS Policies for storage.objects (apply these in Supabase Dashboard SQL Editor)

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Public read access for reports-images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload to reports-images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own files in reports-images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own files in reports-images" ON storage.objects;
DROP POLICY IF EXISTS "Service role full access to reports-images" ON storage.objects;
DROP POLICY IF EXISTS "Anon users can read from reports-images" ON storage.objects;

-- Policy 1: Allow public read access to reports-images bucket
CREATE POLICY "Public read access for reports-images" ON storage.objects
FOR SELECT USING (bucket_id = 'reports-images');

-- Policy 2: Allow authenticated users to upload to reports-images bucket
CREATE POLICY "Authenticated users can upload to reports-images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'reports-images' 
  AND auth.role() = 'authenticated'
);

-- Policy 3: Allow authenticated users to update their own files in reports-images bucket
CREATE POLICY "Users can update their own files in reports-images" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'reports-images' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy 4: Allow authenticated users to delete their own files in reports-images bucket
CREATE POLICY "Users can delete their own files in reports-images" ON storage.objects
FOR DELETE USING (
  bucket_id = 'reports-images' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy 5: Allow service_role full access to reports-images bucket
CREATE POLICY "Service role full access to reports-images" ON storage.objects
FOR ALL USING (
  bucket_id = 'reports-images' 
  AND auth.role() = 'service_role'
);

-- Policy 6: Allow anon users to read from reports-images bucket (for public access)
CREATE POLICY "Anon users can read from reports-images" ON storage.objects
FOR SELECT USING (
  bucket_id = 'reports-images' 
  AND auth.role() = 'anon'
);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
GRANT SELECT ON storage.objects TO anon, authenticated, service_role;
GRANT INSERT ON storage.objects TO authenticated, service_role;
GRANT UPDATE ON storage.objects TO authenticated, service_role;
GRANT DELETE ON storage.objects TO authenticated, service_role;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_storage_objects_bucket_id ON storage.objects(bucket_id);
CREATE INDEX IF NOT EXISTS idx_storage_objects_name ON storage.objects(name);
