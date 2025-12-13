-- Add all missing columns to reports_archived table to match reports table
-- This migration fixes the archiving error where columns were missing
-- Migration: 20250201000001_add_ai_features_to_reports_archived.sql

-- Add ai_structured_result column (this is the one causing the current error)
ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS ai_structured_result JSONB;

-- Add classification-related columns
ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS classification_version TEXT DEFAULT 'v1.0';

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS classification_improvements JSONB DEFAULT '{}';

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS confidence_calibration NUMERIC(3, 2);

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS manual_review_required BOOLEAN DEFAULT false;

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS classification_notes TEXT;

-- Add user-related columns
ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS user_role VARCHAR(50) DEFAULT 'citizen';

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS user_id UUID;

-- Add form configuration columns
ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS is_photo_required BOOLEAN DEFAULT true;

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS message_optional BOOLEAN DEFAULT true;

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS auto_location BOOLEAN DEFAULT true;

-- Add correction-related columns
ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS corrected_type TEXT;

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS corrected_by UUID REFERENCES auth.users(id);

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS corrected_at TIMESTAMPTZ;

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS correction_reason TEXT;

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS correction_details JSONB DEFAULT '{}';

-- Add ai_features column (if not already added)
ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS ai_features JSONB DEFAULT '{}';

-- Add image_hash column
ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS image_hash TEXT;

-- Ensure archived_at and archived_by columns exist
ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ DEFAULT now();

ALTER TABLE public.reports_archived 
ADD COLUMN IF NOT EXISTS archived_by UUID REFERENCES auth.users(id);

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_reports_archived_ai_structured_result 
ON public.reports_archived USING GIN(ai_structured_result);

CREATE INDEX IF NOT EXISTS idx_reports_archived_classification_version 
ON public.reports_archived(classification_version);

CREATE INDEX IF NOT EXISTS idx_reports_archived_manual_review 
ON public.reports_archived(manual_review_required);

CREATE INDEX IF NOT EXISTS idx_reports_archived_confidence_calibration 
ON public.reports_archived(confidence_calibration);

CREATE INDEX IF NOT EXISTS idx_reports_archived_user_role 
ON public.reports_archived(user_role);

CREATE INDEX IF NOT EXISTS idx_reports_archived_user_id 
ON public.reports_archived(user_id);

CREATE INDEX IF NOT EXISTS idx_reports_archived_auto_location 
ON public.reports_archived(auto_location);

CREATE INDEX IF NOT EXISTS idx_reports_archived_corrected_by 
ON public.reports_archived(corrected_by);

CREATE INDEX IF NOT EXISTS idx_reports_archived_corrected_at 
ON public.reports_archived(corrected_at);

CREATE INDEX IF NOT EXISTS idx_reports_archived_ai_features 
ON public.reports_archived USING GIN(ai_features);

CREATE INDEX IF NOT EXISTS idx_reports_archived_image_hash 
ON public.reports_archived(image_hash);

CREATE INDEX IF NOT EXISTS idx_reports_archived_archived_at 
ON public.reports_archived(archived_at DESC);

CREATE INDEX IF NOT EXISTS idx_reports_archived_archived_by 
ON public.reports_archived(archived_by);

-- Add comments for documentation
COMMENT ON COLUMN public.reports_archived.ai_structured_result IS 'Structured AI analysis result in JSON format';
COMMENT ON COLUMN public.reports_archived.ai_features IS 'AI analysis features (tags, objects, captions) for learning';
COMMENT ON COLUMN public.reports_archived.user_id IS 'User ID who created the report';
COMMENT ON COLUMN public.reports_archived.image_hash IS 'Hash of the image for deduplication';

