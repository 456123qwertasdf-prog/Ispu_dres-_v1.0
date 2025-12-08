-- Update reports table with new columns and constraints
-- Migration: 20250113000001_update_reports_table.sql

-- Create enum for lifecycle status
CREATE TYPE lifecycle_status AS ENUM (
    'pending',
    'classified',
    'assigned',
    'accepted',
    'enroute',
    'on_scene',
    'resolved',
    'closed'
);

-- Add new columns to reports table
ALTER TABLE public.reports 
ADD COLUMN IF NOT EXISTS responder_id uuid,
ADD COLUMN IF NOT EXISTS assignment_id uuid,
ADD COLUMN IF NOT EXISTS lifecycle_status lifecycle_status DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS last_update timestamptz DEFAULT now(),
ADD COLUMN IF NOT EXISTS ai_confidence numeric(3,2),
ADD COLUMN IF NOT EXISTS ai_model text,
ADD COLUMN IF NOT EXISTS ai_timestamp timestamptz;

-- Add foreign key constraints
ALTER TABLE public.reports 
ADD CONSTRAINT fk_reports_responder_id 
    FOREIGN KEY (responder_id) REFERENCES public.responder(id) ON DELETE SET NULL;

ALTER TABLE public.reports 
ADD CONSTRAINT fk_reports_assignment_id 
    FOREIGN KEY (assignment_id) REFERENCES public.assignment(id) ON DELETE SET NULL;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_reports_lifecycle_status ON public.reports(lifecycle_status);
CREATE INDEX IF NOT EXISTS idx_reports_responder_id ON public.reports(responder_id);
CREATE INDEX IF NOT EXISTS idx_reports_assignment_id ON public.reports(assignment_id);
CREATE INDEX IF NOT EXISTS idx_reports_last_update ON public.reports(last_update);
CREATE INDEX IF NOT EXISTS idx_reports_ai_confidence ON public.reports(ai_confidence);
CREATE INDEX IF NOT EXISTS idx_reports_ai_timestamp ON public.reports(ai_timestamp);

-- Create trigger to update last_update column when reports are modified
CREATE OR REPLACE FUNCTION update_reports_last_update()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_update = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add trigger for last_update
DROP TRIGGER IF EXISTS update_reports_last_update_trigger ON public.reports;
CREATE TRIGGER update_reports_last_update_trigger
    BEFORE UPDATE ON public.reports
    FOR EACH ROW
    EXECUTE FUNCTION update_reports_last_update();

-- Update existing reports to have last_update set to created_at if not already set
UPDATE public.reports 
SET last_update = created_at 
WHERE last_update IS NULL;

-- Add comments for documentation
COMMENT ON COLUMN public.reports.responder_id IS 'ID of the assigned responder';
COMMENT ON COLUMN public.reports.assignment_id IS 'ID of the assignment record';
COMMENT ON COLUMN public.reports.lifecycle_status IS 'Current status in the report lifecycle';
COMMENT ON COLUMN public.reports.last_update IS 'Timestamp of the last update to the report';
COMMENT ON COLUMN public.reports.ai_confidence IS 'AI classification confidence score (0.00-1.00)';
COMMENT ON COLUMN public.reports.ai_model IS 'AI model used for classification';
COMMENT ON COLUMN public.reports.ai_timestamp IS 'Timestamp when AI classification was performed';
