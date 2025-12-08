-- Add AI analysis fields to reports table
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS ai_description TEXT,
ADD COLUMN IF NOT EXISTS ai_objects JSONB,
ADD COLUMN IF NOT EXISTS ai_analysis TEXT;

-- Add comments for documentation
COMMENT ON COLUMN reports.ai_description IS 'AI-generated description of the image';
COMMENT ON COLUMN reports.ai_objects IS 'AI-detected objects in the image';
COMMENT ON COLUMN reports.ai_analysis IS 'Combined AI analysis text for classification';
