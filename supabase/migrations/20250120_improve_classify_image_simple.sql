-- Simple migration to add classification improvement fields
-- This migration only adds the new fields without modifying existing ones

-- Add performance tracking fields to reports table (only if they don't exist)
DO $$ 
BEGIN
    -- Add classification_version column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reports' AND column_name = 'classification_version') THEN
        ALTER TABLE reports ADD COLUMN classification_version TEXT DEFAULT 'v1.0';
    END IF;
    
    -- Add classification_improvements column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reports' AND column_name = 'classification_improvements') THEN
        ALTER TABLE reports ADD COLUMN classification_improvements JSONB DEFAULT '{}';
    END IF;
    
    -- Add confidence_calibration column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reports' AND column_name = 'confidence_calibration') THEN
        ALTER TABLE reports ADD COLUMN confidence_calibration DECIMAL(3,2) DEFAULT NULL;
    END IF;
    
    -- Add manual_review_required column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reports' AND column_name = 'manual_review_required') THEN
        ALTER TABLE reports ADD COLUMN manual_review_required BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add classification_notes column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reports' AND column_name = 'classification_notes') THEN
        ALTER TABLE reports ADD COLUMN classification_notes TEXT DEFAULT NULL;
    END IF;
END $$;

-- Add indexes for performance (only if they don't exist)
CREATE INDEX IF NOT EXISTS idx_reports_classification_version ON reports(classification_version);
CREATE INDEX IF NOT EXISTS idx_reports_manual_review ON reports(manual_review_required);
CREATE INDEX IF NOT EXISTS idx_reports_confidence_calibration ON reports(confidence_calibration);

-- Add comments for documentation
COMMENT ON COLUMN reports.classification_version IS 'Version of the classification algorithm used';
COMMENT ON COLUMN reports.classification_improvements IS 'JSON object tracking classification improvements and corrections';
COMMENT ON COLUMN reports.confidence_calibration IS 'Calibrated confidence score based on historical accuracy';
COMMENT ON COLUMN reports.manual_review_required IS 'Flag indicating if manual review is needed for this classification';
COMMENT ON COLUMN reports.classification_notes IS 'Additional notes about the classification process';

-- Create a simple function to get classification statistics
CREATE OR REPLACE FUNCTION get_classification_stats()
RETURNS TABLE (
    emergency_type TEXT,
    total_count BIGINT,
    avg_confidence DECIMAL,
    high_confidence_count BIGINT,
    low_confidence_count BIGINT,
    manual_review_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.type as emergency_type,
        COUNT(*) as total_count,
        ROUND(AVG(r.confidence), 3) as avg_confidence,
        COUNT(CASE WHEN r.confidence >= 0.8 THEN 1 END) as high_confidence_count,
        COUNT(CASE WHEN r.confidence < 0.6 THEN 1 END) as low_confidence_count,
        COUNT(CASE WHEN r.manual_review_required THEN 1 END) as manual_review_count
    FROM reports r
    WHERE r.type IS NOT NULL
    GROUP BY r.type
    ORDER BY total_count DESC;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_classification_stats() TO authenticated;

-- Update existing records with new version
UPDATE reports 
SET classification_version = 'v2.0_enhanced',
    classification_improvements = '{"improvements": ["enhanced_flood_detection", "improved_accident_logic", "better_confidence_scoring"]}'
WHERE classification_version IS NULL OR classification_version = 'v1.0';

COMMENT ON FUNCTION get_classification_stats() IS 'Function to get classification statistics by emergency type';
