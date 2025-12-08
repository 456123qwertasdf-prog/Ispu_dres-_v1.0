-- Classification Corrections and Learning System
-- This migration adds support for admin corrections and adaptive learning

-- Add correction fields to reports table
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS corrected_type TEXT,
ADD COLUMN IF NOT EXISTS corrected_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS corrected_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS correction_reason TEXT,
ADD COLUMN IF NOT EXISTS correction_details JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS ai_features JSONB DEFAULT '{}';

-- Create classification_corrections table for detailed correction history
CREATE TABLE IF NOT EXISTS classification_corrections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  original_type TEXT NOT NULL,
  corrected_type TEXT NOT NULL,
  original_confidence DECIMAL(3,2),
  correction_reason TEXT NOT NULL,
  issue_categories TEXT[] DEFAULT '{}',
  ai_features JSONB DEFAULT '{}', -- Store AI tags, objects, captions for learning
  corrected_by UUID NOT NULL REFERENCES auth.users(id),
  correction_confidence BOOLEAN DEFAULT true, -- Was admin certain about correction?
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create adaptive_classifier_config table for learned rules
CREATE TABLE IF NOT EXISTS adaptive_classifier_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_name TEXT NOT NULL UNIQUE,
  rule_type TEXT NOT NULL CHECK (rule_type IN ('keyword_boost', 'pattern_rule', 'threshold', 'penalty')),
  config_data JSONB NOT NULL DEFAULT '{}',
  pattern_description TEXT,
  learned_from_corrections INTEGER DEFAULT 0, -- How many corrections led to this rule
  confidence_boost DECIMAL(3,2) DEFAULT 0.0,
  is_active BOOLEAN DEFAULT true,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_reports_corrected_by ON reports(corrected_by);
CREATE INDEX IF NOT EXISTS idx_reports_corrected_at ON reports(corrected_at);
CREATE INDEX IF NOT EXISTS idx_reports_ai_features ON reports USING GIN(ai_features);

CREATE INDEX IF NOT EXISTS idx_classification_corrections_report_id ON classification_corrections(report_id);
CREATE INDEX IF NOT EXISTS idx_classification_corrections_original_type ON classification_corrections(original_type);
CREATE INDEX IF NOT EXISTS idx_classification_corrections_corrected_type ON classification_corrections(corrected_type);
CREATE INDEX IF NOT EXISTS idx_classification_corrections_corrected_by ON classification_corrections(corrected_by);
CREATE INDEX IF NOT EXISTS idx_classification_corrections_created_at ON classification_corrections(created_at);
CREATE INDEX IF NOT EXISTS idx_classification_corrections_ai_features ON classification_corrections USING GIN(ai_features);

CREATE INDEX IF NOT EXISTS idx_adaptive_config_rule_type ON adaptive_classifier_config(rule_type);
CREATE INDEX IF NOT EXISTS idx_adaptive_config_is_active ON adaptive_classifier_config(is_active);

-- Add comments for documentation
COMMENT ON COLUMN reports.corrected_type IS 'Admin-corrected emergency type';
COMMENT ON COLUMN reports.corrected_by IS 'Admin who made the correction';
COMMENT ON COLUMN reports.corrected_at IS 'When the correction was made';
COMMENT ON COLUMN reports.correction_reason IS 'Detailed reason for the correction';
COMMENT ON COLUMN reports.correction_details IS 'Additional correction metadata and issue categories';
COMMENT ON COLUMN reports.ai_features IS 'AI analysis features (tags, objects, captions) for learning';

COMMENT ON TABLE classification_corrections IS 'Detailed history of all classification corrections for learning';
COMMENT ON TABLE adaptive_classifier_config IS 'Learned rules and configurations that adapt based on corrections';

-- Function to update corrected_at timestamp
CREATE OR REPLACE FUNCTION update_corrected_at()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.corrected_type IS DISTINCT FROM OLD.corrected_type AND NEW.corrected_type IS NOT NULL THEN
    NEW.corrected_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically set corrected_at
CREATE TRIGGER trigger_update_corrected_at
  BEFORE UPDATE ON reports
  FOR EACH ROW
  WHEN (NEW.corrected_type IS DISTINCT FROM OLD.corrected_type)
  EXECUTE FUNCTION update_corrected_at();

-- Function to automatically create correction record
CREATE OR REPLACE FUNCTION create_correction_record()
RETURNS TRIGGER AS $$
BEGIN
  -- When report is corrected, create a correction record
  IF NEW.corrected_type IS NOT NULL AND 
     (OLD.corrected_type IS NULL OR OLD.corrected_type IS DISTINCT FROM NEW.corrected_type) THEN
    INSERT INTO classification_corrections (
      report_id,
      original_type,
      corrected_type,
      original_confidence,
      correction_reason,
      issue_categories,
      ai_features,
      corrected_by,
      correction_confidence
    ) VALUES (
      NEW.id,
      OLD.type,
      NEW.corrected_type,
      OLD.confidence,
      NEW.correction_reason,
      COALESCE((NEW.correction_details->>'issue_categories')::TEXT[], '{}'),
      COALESCE(NEW.ai_features, '{}'),
      NEW.corrected_by,
      COALESCE((NEW.correction_details->>'correction_confidence')::BOOLEAN, true)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create correction record
CREATE TRIGGER trigger_create_correction_record
  AFTER UPDATE ON reports
  FOR EACH ROW
  WHEN (NEW.corrected_type IS NOT NULL AND 
        (OLD.corrected_type IS NULL OR OLD.corrected_type IS DISTINCT FROM NEW.corrected_type))
  EXECUTE FUNCTION create_correction_record();

-- Function to get correction statistics
CREATE OR REPLACE FUNCTION get_correction_stats()
RETURNS TABLE (
  original_type TEXT,
  corrected_type TEXT,
  correction_count BIGINT,
  avg_confidence DECIMAL,
  common_issues TEXT[]
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cc.original_type,
    cc.corrected_type,
    COUNT(*) as correction_count,
    ROUND(AVG(cc.original_confidence), 3) as avg_confidence,
    ARRAY_AGG(DISTINCT unnest(cc.issue_categories)) as common_issues
  FROM classification_corrections cc
  GROUP BY cc.original_type, cc.corrected_type
  HAVING COUNT(*) > 0
  ORDER BY correction_count DESC;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON classification_corrections TO authenticated;
GRANT SELECT, INSERT, UPDATE ON adaptive_classifier_config TO authenticated;
GRANT EXECUTE ON FUNCTION get_correction_stats() TO authenticated;

COMMENT ON FUNCTION get_correction_stats() IS 'Get statistics about classification corrections for analytics';

