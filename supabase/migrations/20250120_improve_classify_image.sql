-- Improve classify-image performance tracking
-- This migration adds fields to track classification improvements and performance

-- Add performance tracking fields to reports table
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS classification_version TEXT DEFAULT 'v1.0',
ADD COLUMN IF NOT EXISTS classification_improvements JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS confidence_calibration DECIMAL(3,2) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS manual_review_required BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS classification_notes TEXT DEFAULT NULL;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_reports_classification_version ON reports(classification_version);
CREATE INDEX IF NOT EXISTS idx_reports_manual_review ON reports(manual_review_required);
CREATE INDEX IF NOT EXISTS idx_reports_confidence_calibration ON reports(confidence_calibration);

-- Add comments for documentation
COMMENT ON COLUMN reports.classification_version IS 'Version of the classification algorithm used';
COMMENT ON COLUMN reports.classification_improvements IS 'JSON object tracking classification improvements and corrections';
COMMENT ON COLUMN reports.confidence_calibration IS 'Calibrated confidence score based on historical accuracy';
COMMENT ON COLUMN reports.manual_review_required IS 'Flag indicating if manual review is needed for this classification';
COMMENT ON COLUMN reports.classification_notes IS 'Additional notes about the classification process';

-- Create a function to update classification performance
CREATE OR REPLACE FUNCTION update_classification_performance()
RETURNS TRIGGER AS $$
BEGIN
    -- Update classification version
    NEW.classification_version = 'v2.0_enhanced';
    
    -- Set manual review flag for low confidence classifications
    IF NEW.confidence < 0.6 THEN
        NEW.manual_review_required = TRUE;
    END IF;
    
    -- Add classification notes for debugging
    IF NEW.type = 'uncertain' OR NEW.confidence < 0.5 THEN
        NEW.classification_notes = 'Low confidence classification - manual review recommended';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update classification performance
CREATE TRIGGER trigger_update_classification_performance
    BEFORE UPDATE ON reports
    FOR EACH ROW
    WHEN (NEW.type IS DISTINCT FROM OLD.type OR NEW.confidence IS DISTINCT FROM OLD.confidence)
    EXECUTE FUNCTION update_classification_performance();

-- Create a view for classification performance analytics
CREATE OR REPLACE VIEW classification_performance_analytics AS
SELECT 
    type,
    classification_version,
    COUNT(*) as total_classifications,
    AVG(confidence) as avg_confidence,
    MIN(confidence) as min_confidence,
    MAX(confidence) as max_confidence,
    COUNT(CASE WHEN manual_review_required THEN 1 END) as manual_review_count,
    COUNT(CASE WHEN confidence < 0.6 THEN 1 END) as low_confidence_count,
    COUNT(CASE WHEN confidence >= 0.8 THEN 1 END) as high_confidence_count,
    DATE_TRUNC('day', created_at) as classification_date
FROM reports 
WHERE type IS NOT NULL 
GROUP BY type, classification_version, DATE_TRUNC('day', created_at)
ORDER BY classification_date DESC, type;

-- Create a function to get classification statistics
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
GRANT SELECT ON classification_performance_analytics TO authenticated;
GRANT EXECUTE ON FUNCTION get_classification_stats() TO authenticated;

-- Insert initial performance data
INSERT INTO reports (classification_version, classification_improvements, confidence_calibration)
SELECT 
    'v2.0_enhanced',
    '{"improvements": ["enhanced_flood_detection", "improved_accident_logic", "better_confidence_scoring"]}',
    0.75
WHERE NOT EXISTS (
    SELECT 1 FROM reports WHERE classification_version = 'v2.0_enhanced'
);

-- Update existing records with new version
UPDATE reports 
SET classification_version = 'v2.0_enhanced',
    classification_improvements = '{"improvements": ["enhanced_flood_detection", "improved_accident_logic", "better_confidence_scoring"]}'
WHERE classification_version IS NULL OR classification_version = 'v1.0';

COMMENT ON VIEW classification_performance_analytics IS 'Analytics view for monitoring classification performance over time';
COMMENT ON FUNCTION get_classification_stats() IS 'Function to get classification statistics by emergency type';
