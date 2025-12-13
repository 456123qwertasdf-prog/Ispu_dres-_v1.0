-- Add missing timestamp columns to assignment table
-- Migration: 20250202000001_add_assignment_timestamp_columns.sql
-- This migration adds enroute_at, on_scene_at, resolved_at, and notes columns
-- to support the full assignment status workflow

-- Add enroute_at timestamp column
ALTER TABLE public.assignment 
ADD COLUMN IF NOT EXISTS enroute_at timestamptz;

-- Add on_scene_at timestamp column
ALTER TABLE public.assignment 
ADD COLUMN IF NOT EXISTS on_scene_at timestamptz;

-- Add resolved_at timestamp column
ALTER TABLE public.assignment 
ADD COLUMN IF NOT EXISTS resolved_at timestamptz;

-- Add notes column for assignment updates
ALTER TABLE public.assignment 
ADD COLUMN IF NOT EXISTS notes text;

-- Add indexes for better query performance on timestamp columns
CREATE INDEX IF NOT EXISTS idx_assignment_enroute_at ON public.assignment(enroute_at);
CREATE INDEX IF NOT EXISTS idx_assignment_on_scene_at ON public.assignment(on_scene_at);
CREATE INDEX IF NOT EXISTS idx_assignment_resolved_at ON public.assignment(resolved_at);

-- Add comments for documentation
COMMENT ON COLUMN public.assignment.enroute_at IS 'Timestamp when responder marked assignment as enroute';
COMMENT ON COLUMN public.assignment.on_scene_at IS 'Timestamp when responder marked assignment as on scene';
COMMENT ON COLUMN public.assignment.resolved_at IS 'Timestamp when assignment was resolved';
COMMENT ON COLUMN public.assignment.notes IS 'Optional notes or comments about the assignment status update';

