-- Setup Storage Bucket for Emergency Reports
-- This migration sets up the reports-images bucket with proper RLS policies

-- Create the storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'reports-images',
  'reports-images',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for storage access

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

-- Create a function to get public URL for storage objects
CREATE OR REPLACE FUNCTION get_public_url(bucket_name text, object_path text)
RETURNS text AS $$
BEGIN
  RETURN format('https://hmolyqzbvxxliemclrld.supabase.co/storage/v1/object/public/%s/%s', bucket_name, object_path);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to upload file to storage
CREATE OR REPLACE FUNCTION upload_to_storage(
  bucket_name text,
  object_path text,
  file_data bytea,
  content_type text DEFAULT 'image/jpeg'
)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  -- This function would need to be implemented in the application layer
  -- as Supabase doesn't allow direct file uploads via SQL
  RETURN json_build_object(
    'success', false,
    'message', 'Use Supabase client to upload files'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
GRANT SELECT ON storage.objects TO anon, authenticated, service_role;
GRANT INSERT ON storage.objects TO authenticated, service_role;
GRANT UPDATE ON storage.objects TO authenticated, service_role;
GRANT DELETE ON storage.objects TO authenticated, service_role;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_storage_objects_bucket_id ON storage.objects(bucket_id);
CREATE INDEX IF NOT EXISTS idx_storage_objects_name ON storage.objects(name);

-- Insert some sample data to test the setup
INSERT INTO storage.objects (bucket_id, name, owner, metadata)
VALUES (
  'reports-images',
  'emergency-reports/test-image.jpg',
  auth.uid(),
  '{"size": 0, "mimetype": "image/jpeg"}'::jsonb
) ON CONFLICT DO NOTHING;
