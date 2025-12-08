-- Sync assignment status with reports status
-- This migration fixes data inconsistency where reports are completed but assignments are still assigned
-- Migration: 20250129000001_sync_assignment_status_with_reports.sql

-- Step 1: Update all assignments to 'resolved' where the report is 'completed' but assignment is still 'assigned'
UPDATE public.assignment
SET 
    status = 'resolved',
    completed_at = COALESCE(
        completed_at,
        (SELECT COALESCE(last_update, created_at) FROM public.reports WHERE id = assignment.report_id),
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

-- Step 2: Create a function to automatically update assignment status when report is completed
CREATE OR REPLACE FUNCTION sync_assignment_status_on_report_complete()
RETURNS TRIGGER AS $$
BEGIN
    -- When a report is marked as completed/resolved/closed, update corresponding assignment
    IF (NEW.status = 'completed' OR NEW.lifecycle_status IN ('resolved', 'closed'))
       AND (OLD.status IS DISTINCT FROM NEW.status OR OLD.lifecycle_status IS DISTINCT FROM NEW.lifecycle_status) THEN
        
        UPDATE public.assignment
        SET 
            status = 'resolved',
            completed_at = COALESCE(completed_at, NEW.last_update, NOW()),
            updated_at = NOW()
        WHERE 
            report_id = NEW.id
            AND status IN ('assigned', 'accepted', 'enroute', 'on_scene');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create trigger to automatically sync assignment status
DROP TRIGGER IF EXISTS trigger_sync_assignment_status_on_report_complete ON public.reports;

CREATE TRIGGER trigger_sync_assignment_status_on_report_complete
    AFTER UPDATE OF status, lifecycle_status ON public.reports
    FOR EACH ROW
    WHEN (
        (NEW.status = 'completed' OR NEW.lifecycle_status IN ('resolved', 'closed'))
        AND (OLD.status IS DISTINCT FROM NEW.status OR OLD.lifecycle_status IS DISTINCT FROM NEW.lifecycle_status)
    )
    EXECUTE FUNCTION sync_assignment_status_on_report_complete();

-- Step 4: Add comment explaining the trigger
COMMENT ON FUNCTION sync_assignment_status_on_report_complete() IS 
    'Automatically updates assignment status to resolved when a report is marked as completed/resolved/closed';

COMMENT ON TRIGGER trigger_sync_assignment_status_on_report_complete ON public.reports IS 
    'Automatically syncs assignment status when report status changes to completed/resolved/closed';

