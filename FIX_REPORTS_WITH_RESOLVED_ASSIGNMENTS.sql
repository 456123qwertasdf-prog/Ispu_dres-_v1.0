-- FIX REPORTS WITH RESOLVED ASSIGNMENTS
-- This script updates all reports where assignment status is 'resolved' 
-- but report status is still 'assigned' to have status = 'completed'
-- Run this directly in Supabase SQL Editor to fix existing data

-- Step 1: Check what reports need to be fixed (for visibility)
SELECT 
    'BEFORE FIX - Reports with resolved assignments but wrong status' as status,
    r.id as report_id,
    r.status as report_status,
    r.lifecycle_status as report_lifecycle_status,
    a.id as assignment_id,
    a.status as assignment_status
FROM public.reports r
JOIN public.assignment a ON a.report_id = r.id
WHERE a.status = 'resolved'
    AND r.status IN ('assigned', 'pending', 'processing', 'classified', 'accepted', 'enroute', 'on_scene');

-- Step 2: Update reports where assignment is resolved but report status is still 'assigned' or other non-completed statuses
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

-- Step 3: Show results - how many reports were updated
SELECT 
    COUNT(*) as reports_updated,
    'Reports updated to completed status' as message
FROM public.reports r
JOIN public.assignment a ON a.report_id = r.id
WHERE a.status = 'resolved'
    AND r.status = 'completed'
    AND r.lifecycle_status = 'resolved';

-- Step 4: Show remaining mismatches (should be 0 after fix)
SELECT 
    'REMAINING MISMATCHES' as status,
    COUNT(*) as count,
    'Reports with resolved assignments but wrong status' as message
FROM public.reports r
JOIN public.assignment a ON a.report_id = r.id
WHERE a.status = 'resolved'
    AND r.status IN ('assigned', 'pending', 'processing', 'classified', 'accepted', 'enroute', 'on_scene');

-- Step 5: Show summary of all resolved assignments and their report statuses
SELECT 
    a.status as assignment_status,
    r.status as report_status,
    r.lifecycle_status as report_lifecycle_status,
    COUNT(*) as count
FROM public.assignment a
JOIN public.reports r ON a.report_id = r.id
WHERE a.status = 'resolved'
GROUP BY a.status, r.status, r.lifecycle_status
ORDER BY count DESC;

