-- QUICK FIX: Sync assignment status with completed reports
-- Run this directly in Supabase SQL Editor to fix existing data
-- This updates all assignments to 'resolved' where reports are 'completed' but assignments are still 'assigned'

-- Step 1: Check what assignments need to be updated (for visibility)
SELECT 
    a.id as assignment_id,
    a.status as assignment_status,
    r.id as report_id,
    r.status as report_status,
    r.lifecycle_status as report_lifecycle_status
FROM public.assignment a
JOIN public.reports r ON a.report_id = r.id
WHERE (
    r.status = 'completed' 
    OR r.lifecycle_status IN ('resolved', 'closed')
)
AND a.status IN ('assigned', 'accepted', 'enroute', 'on_scene');

-- Step 2: Fix existing data inconsistency - Update assignments to resolved where reports are completed
UPDATE public.assignment
SET 
    status = 'resolved',
    completed_at = COALESCE(
        assignment.completed_at,
        (SELECT COALESCE(r.last_update, r.created_at) 
         FROM public.reports r 
         WHERE r.id = assignment.report_id),
        assignment.assigned_at,
        NOW()
    ),
    updated_at = NOW()
FROM public.reports r
WHERE 
    assignment.report_id = r.id
    AND (
        r.status = 'completed' 
        OR r.lifecycle_status IN ('resolved', 'closed')
    )
    AND assignment.status IN ('assigned', 'accepted', 'enroute', 'on_scene');

-- Step 3: Show results - how many assignments were updated
SELECT 
    COUNT(*) as assignments_updated,
    'Assignments updated to resolved' as message
FROM public.assignment a
JOIN public.reports r ON a.report_id = r.id
WHERE a.status = 'resolved'
    AND (
        r.status = 'completed' 
        OR r.lifecycle_status IN ('resolved', 'closed')
    );

-- Step 4: Show remaining mismatches (should be 0 after fix)
SELECT 
    COUNT(*) as remaining_mismatches,
    'Assignments still mismatched' as message
FROM public.assignment a
JOIN public.reports r ON a.report_id = r.id
WHERE (
    r.status = 'completed' 
    OR r.lifecycle_status IN ('resolved', 'closed')
)
AND a.status IN ('assigned', 'accepted', 'enroute', 'on_scene');

