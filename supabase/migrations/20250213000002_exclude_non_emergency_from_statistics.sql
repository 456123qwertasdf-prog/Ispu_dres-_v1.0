-- Exclude non_emergency reports from emergency statistics
-- This migration updates the get_emergency_statistics function to exclude non_emergency reports
-- Migration: 20250213000002_exclude_non_emergency_from_statistics.sql

-- Update the function to exclude non_emergency reports
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
  FROM public.reports
  WHERE COALESCE(type, '') != 'non_emergency'
    AND COALESCE(corrected_type, '') != 'non_emergency';
END;
$$ LANGUAGE plpgsql;

-- Update the comment to reflect the exclusion
COMMENT ON FUNCTION get_emergency_statistics() IS 
    'Returns emergency statistics excluding non_emergency reports. Only counts actual emergency incidents.';

