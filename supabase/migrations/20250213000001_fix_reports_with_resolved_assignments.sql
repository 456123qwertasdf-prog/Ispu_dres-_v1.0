-- Fix Reports with Resolved Assignments
-- This migration updates all reports where assignment status is 'resolved' 
-- but report status is still 'assigned' to have status = 'completed'
-- Migration: 20250213000001_fix_reports_with_resolved_assignments.sql

-- Update reports where assignment is resolved but report status is still 'assigned' or other non-completed statuses
-- This fixes the inconsistency where assignment is resolved but report status hasn't been updated
UPDATE public.reports
SET 
    status = 'completed',
    lifecycle_status = 'resolved',
    last_update = COALESCE(
        (SELECT a.resolved_at FROM public.assignment a WHERE a.report_id = reports.id AND a.status = 'resolved' ORDER BY a.updated_at DESC LIMIT 1),
        (SELECT a.updated_at FROM public.assignment a WHERE a.report_id = reports.id AND a.status = 'resolved' ORDER BY a.updated_at DESC LIMIT 1),
        reports.last_update,
        NOW()
    )
WHERE id IN (
    SELECT r.id
    FROM public.reports r
    JOIN public.assignment a ON a.report_id = r.id
    WHERE a.status = 'resolved'
        AND r.status IN ('assigned', 'pending', 'processing', 'classified', 'accepted', 'enroute', 'on_scene')
);

-- Add comment explaining the fix
COMMENT ON TABLE public.reports IS 
    'Emergency reports table. When an assignment is resolved, the report status should be "completed" and lifecycle_status should be "resolved"';

