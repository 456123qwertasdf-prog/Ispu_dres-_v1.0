-- One-time sync: set all assignments to 'resolved' where the report is already completed/resolved/closed.
-- When a report is completed (e.g. by one responder), other team members' assignments should auto-resolve
-- via trigger_sync_assignment_status_on_report_complete. This migration fixes any existing rows that
-- were left in assigned/accepted/enroute/on_scene (e.g. before the trigger existed or due to timing).
-- Migration: 20260311000002_sync_assignments_for_completed_reports.sql

UPDATE public.assignment
SET
    status = 'resolved',
    completed_at = COALESCE(
        assignment.completed_at,
        (SELECT COALESCE(r.last_update, r.created_at) FROM public.reports r WHERE r.id = assignment.report_id),
        assignment.assigned_at,
        NOW()
    ),
    updated_at = NOW()
WHERE
    report_id IN (
        SELECT id FROM public.reports
        WHERE status = 'completed'
           OR lifecycle_status = 'resolved'
           OR lifecycle_status = 'closed'
    )
    AND status IN ('assigned', 'accepted', 'enroute', 'on_scene');
