-- Responder: needs assistance (general)
-- Assignment: needs backup (per incident)
-- Migration: 20250227000001_responder_needs_assistance_assignment_needs_backup.sql

-- Responder: flag and optional timestamp
ALTER TABLE public.responder
ADD COLUMN IF NOT EXISTS needs_assistance boolean DEFAULT false;

ALTER TABLE public.responder
ADD COLUMN IF NOT EXISTS needs_assistance_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_responder_needs_assistance ON public.responder(needs_assistance) WHERE needs_assistance = true;

COMMENT ON COLUMN public.responder.needs_assistance IS 'True when responder has requested assistance or backup (general).';
COMMENT ON COLUMN public.responder.needs_assistance_at IS 'When the responder last requested assistance (cleared when cancelled).';

-- Assignment: backup requested for this incident
ALTER TABLE public.assignment
ADD COLUMN IF NOT EXISTS needs_backup boolean DEFAULT false;

ALTER TABLE public.assignment
ADD COLUMN IF NOT EXISTS needs_backup_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_assignment_needs_backup ON public.assignment(needs_backup) WHERE needs_backup = true;

COMMENT ON COLUMN public.assignment.needs_backup IS 'True when the assigned responder requested backup for this incident.';
COMMENT ON COLUMN public.assignment.needs_backup_at IS 'When backup was requested for this assignment.';
