-- Image Deduplication System
-- This migration adds image hash-based deduplication to prevent storing duplicate images

-- Add image_hash column to reports table
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS image_hash TEXT;

-- Create image_deduplication table to track image hashes and usage
CREATE TABLE IF NOT EXISTS image_deduplication (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  image_hash TEXT NOT NULL UNIQUE,
  image_path TEXT NOT NULL,
  storage_bucket TEXT NOT NULL DEFAULT 'reports-images',
  reference_count INTEGER DEFAULT 1,
  first_reported_at TIMESTAMPTZ DEFAULT NOW(),
  last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
  file_size BIGINT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_reports_image_hash ON reports(image_hash);
CREATE UNIQUE INDEX IF NOT EXISTS idx_image_deduplication_hash_unique ON image_deduplication(image_hash);
CREATE INDEX IF NOT EXISTS idx_image_deduplication_reference_count ON image_deduplication(reference_count);

-- Add comments
COMMENT ON COLUMN reports.image_hash IS 'SHA-256 hash of the image for deduplication';
COMMENT ON TABLE image_deduplication IS 'Tracks image hashes to prevent duplicate storage';

-- Function to get or create image hash record
CREATE OR REPLACE FUNCTION get_or_create_image_hash(
  p_image_hash TEXT,
  p_image_path TEXT,
  p_storage_bucket TEXT DEFAULT 'reports-images',
  p_file_size BIGINT DEFAULT NULL
)
RETURNS image_deduplication AS $$
DECLARE
  v_record image_deduplication;
BEGIN
  -- Try to get existing record
  SELECT * INTO v_record
  FROM image_deduplication
  WHERE image_hash = p_image_hash
  LIMIT 1;
  
  IF v_record IS NULL THEN
    -- Create new record
    INSERT INTO image_deduplication (
      image_hash,
      image_path,
      storage_bucket,
      file_size,
      reference_count,
      first_reported_at,
      last_accessed_at
    ) VALUES (
      p_image_hash,
      p_image_path,
      p_storage_bucket,
      p_file_size,
      1,
      NOW(),
      NOW()
    )
    RETURNING * INTO v_record;
  ELSE
    -- Update existing record: increment reference count and update last accessed
    UPDATE image_deduplication
    SET 
      reference_count = reference_count + 1,
      last_accessed_at = NOW(),
      updated_at = NOW()
    WHERE image_hash = p_image_hash
    RETURNING * INTO v_record;
  END IF;
  
  RETURN v_record;
END;
$$ LANGUAGE plpgsql;

-- Function to decrement image reference count
CREATE OR REPLACE FUNCTION decrement_image_reference(p_image_hash TEXT)
RETURNS INTEGER AS $$
DECLARE
  v_new_count INTEGER;
BEGIN
  UPDATE image_deduplication
  SET 
    reference_count = GREATEST(0, reference_count - 1),
    updated_at = NOW()
  WHERE image_hash = p_image_hash
  RETURNING reference_count INTO v_new_count;
  
  RETURN COALESCE(v_new_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to get orphaned images (reference_count = 0)
CREATE OR REPLACE FUNCTION get_orphaned_images()
RETURNS TABLE (
  id UUID,
  image_hash TEXT,
  image_path TEXT,
  storage_bucket TEXT,
  file_size BIGINT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    img.id,
    img.image_hash,
    img.image_path,
    img.storage_bucket,
    img.file_size,
    img.created_at
  FROM image_deduplication img
  WHERE img.reference_count = 0
  ORDER BY img.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get deduplication statistics
CREATE OR REPLACE FUNCTION get_deduplication_stats()
RETURNS TABLE (
  total_unique_images BIGINT,
  total_references BIGINT,
  duplicates_prevented BIGINT,
  storage_saved_bytes BIGINT,
  avg_references_per_image DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(DISTINCT img.image_hash) as total_unique_images,
    SUM(img.reference_count) as total_references,
    SUM(img.reference_count) - COUNT(DISTINCT img.image_hash) as duplicates_prevented,
    SUM((img.reference_count - 1) * COALESCE(img.file_size, 0)) as storage_saved_bytes,
    ROUND(AVG(img.reference_count), 2) as avg_references_per_image
  FROM image_deduplication img;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update last_accessed_at when image is referenced
CREATE OR REPLACE FUNCTION update_image_last_accessed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.image_hash IS NOT NULL THEN
    UPDATE image_deduplication
    SET last_accessed_at = NOW()
    WHERE image_hash = NEW.image_hash;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_image_last_accessed
  AFTER INSERT OR UPDATE ON reports
  FOR EACH ROW
  WHEN (NEW.image_hash IS NOT NULL)
  EXECUTE FUNCTION update_image_last_accessed();

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON image_deduplication TO authenticated;
GRANT EXECUTE ON FUNCTION get_or_create_image_hash(TEXT, TEXT, TEXT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_image_reference(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_orphaned_images() TO authenticated;
GRANT EXECUTE ON FUNCTION get_deduplication_stats() TO authenticated;

COMMENT ON FUNCTION get_or_create_image_hash IS 'Get existing image hash record or create new one, incrementing reference count';
COMMENT ON FUNCTION decrement_image_reference IS 'Decrement reference count when report using image is deleted';
COMMENT ON FUNCTION get_orphaned_images IS 'Get images with no references for cleanup';
COMMENT ON FUNCTION get_deduplication_stats IS 'Get statistics about image deduplication savings';

