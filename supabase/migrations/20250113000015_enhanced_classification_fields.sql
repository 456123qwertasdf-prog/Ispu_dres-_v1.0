-- Enhanced Classification Fields Migration
-- This migration adds new fields for priority, status, severity, and enhanced emergency classification

-- Add new columns to reports table for enhanced classification
ALTER TABLE public.reports
ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 4,
ADD COLUMN IF NOT EXISTS severity VARCHAR(20) DEFAULT 'LOW',
ADD COLUMN IF NOT EXISTS response_time VARCHAR(20) DEFAULT '60 minutes',
ADD COLUMN IF NOT EXISTS emergency_color VARCHAR(7) DEFAULT '#808080',
ADD COLUMN IF NOT EXISTS emergency_icon VARCHAR(10) DEFAULT '❓',
ADD COLUMN IF NOT EXISTS recommendations TEXT[] DEFAULT '{}';

-- Create index for priority for faster queries
CREATE INDEX IF NOT EXISTS idx_reports_priority ON public.reports(priority);
CREATE INDEX IF NOT EXISTS idx_reports_severity ON public.reports(severity);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);

-- Update existing reports with default enhanced classification values
UPDATE public.reports 
SET 
  priority = CASE 
    WHEN type = 'fire' THEN 1
    WHEN type = 'medical' THEN 1
    WHEN type = 'accident' THEN 2
    WHEN type = 'flood' THEN 2
    WHEN type = 'structural' THEN 3
    WHEN type = 'environmental' THEN 3
    ELSE 4
  END,
  severity = CASE 
    WHEN confidence >= 0.8 THEN 'CRITICAL'
    WHEN confidence >= 0.6 THEN 'HIGH'
    WHEN confidence >= 0.4 THEN 'MEDIUM'
    ELSE 'LOW'
  END,
  response_time = CASE 
    WHEN type = 'fire' THEN '5 minutes'
    WHEN type = 'medical' THEN '3 minutes'
    WHEN type = 'accident' THEN '10 minutes'
    WHEN type = 'flood' THEN '15 minutes'
    WHEN type = 'structural' THEN '30 minutes'
    WHEN type = 'environmental' THEN '45 minutes'
    ELSE '60 minutes'
  END,
  emergency_color = CASE 
    WHEN type = 'fire' THEN '#FF4444'
    WHEN type = 'medical' THEN '#FF6B6B'
    WHEN type = 'accident' THEN '#FF8C00'
    WHEN type = 'flood' THEN '#4A90E2'
    WHEN type = 'structural' THEN '#8B4513'
    WHEN type = 'environmental' THEN '#32CD32'
    ELSE '#808080'
  END,
  emergency_icon = CASE 
    WHEN type = 'fire' THEN '🔥'
    WHEN type = 'medical' THEN '🚑'
    WHEN type = 'accident' THEN '🚗'
    WHEN type = 'flood' THEN '🌊'
    WHEN type = 'structural' THEN '🏗️'
    WHEN type = 'environmental' THEN '🌿'
    ELSE '❓'
  END
WHERE priority IS NULL OR severity IS NULL;

-- Create a view for enhanced emergency reports
CREATE OR REPLACE VIEW enhanced_emergency_reports AS
SELECT 
  id,
  reporter_name,
  message,
  location,
  image_path,
  type,
  confidence,
  status,
  priority,
  severity,
  response_time,
  emergency_color,
  emergency_icon,
  recommendations,
  ai_description,
  ai_objects,
  ai_analysis,
  created_at,
  ai_timestamp
FROM public.reports
ORDER BY 
  priority ASC,
  confidence DESC,
  created_at DESC;

-- Grant permissions for the view
GRANT SELECT ON enhanced_emergency_reports TO authenticated;
GRANT SELECT ON enhanced_emergency_reports TO service_role;

-- Create a function to get emergency statistics
CREATE OR REPLACE FUNCTION get_emergency_statistics()
RETURNS TABLE (
  total_reports BIGINT,
  critical_count BIGINT,
  high_count BIGINT,
  medium_count BIGINT,
  low_count BIGINT,
  fire_count BIGINT,
  medical_count BIGINT,
  accident_count BIGINT,
  flood_count BIGINT,
  structural_count BIGINT,
  environmental_count BIGINT,
  other_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*) as total_reports,
    COUNT(*) FILTER (WHERE severity = 'CRITICAL') as critical_count,
    COUNT(*) FILTER (WHERE severity = 'HIGH') as high_count,
    COUNT(*) FILTER (WHERE severity = 'MEDIUM') as medium_count,
    COUNT(*) FILTER (WHERE severity = 'LOW') as low_count,
    COUNT(*) FILTER (WHERE type = 'fire') as fire_count,
    COUNT(*) FILTER (WHERE type = 'medical') as medical_count,
    COUNT(*) FILTER (WHERE type = 'accident') as accident_count,
    COUNT(*) FILTER (WHERE type = 'flood') as flood_count,
    COUNT(*) FILTER (WHERE type = 'structural') as structural_count,
    COUNT(*) FILTER (WHERE type = 'environmental') as environmental_count,
    COUNT(*) FILTER (WHERE type = 'other') as other_count
  FROM public.reports;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions for the function
GRANT EXECUTE ON FUNCTION get_emergency_statistics() TO authenticated;
GRANT EXECUTE ON FUNCTION get_emergency_statistics() TO service_role;
