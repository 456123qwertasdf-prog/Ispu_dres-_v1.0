-- Allow multiple assignments per report: primary (main) and backup (assist).
-- Migration: 20250227100001_assignment_role_primary_backup.sql

ALTER TABLE public.assignment
ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'primary'
  CHECK (role IN ('primary', 'backup'));

CREATE INDEX IF NOT EXISTS idx_assignment_role ON public.assignment(role);
COMMENT ON COLUMN public.assignment.role IS 'primary = main assigned responder; backup = additional responder assisting.';
