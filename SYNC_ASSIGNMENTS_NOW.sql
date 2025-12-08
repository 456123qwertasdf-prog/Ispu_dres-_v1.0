-- SYNC ASSIGNMENTS WITH REPORTS - COMPREHENSIVE FIX
-- Run this in Supabase SQL Editor to fix all mismatches

-- First, let's see what needs to be fixed
SELECT 
    'BEFORE FIX - Mismatched Assignments' as status,
    COUNT(*) as count
FROM public.assignment a
JOIN public.reports r ON a.report_id = r.id
WHERE (
    r.status = 'completed' 
    OR r.lifecycle_status IN ('resolved', 'closed')
)
AND a.status IN ('assigned', 'accepted', 'enroute', 'on_scene');

-- Now fix ALL assignments where reports are completed
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

-- Show results
SELECT 
    'AFTER FIX - Resolved Assignments' as status,
    COUNT(*) as count
FROM public.assignment a
JOIN public.reports r ON a.report_id = r.id
WHERE a.status = 'resolved'
    AND (
        r.status = 'completed' 
        OR r.lifecycle_status IN ('resolved', 'closed')
    );

-- Check for any remaining mismatches (should be 0)
SELECT 
    'REMAINING ISSUES' as status,
    COUNT(*) as count
FROM public.assignment a
JOIN public.reports r ON a.report_id = r.id
WHERE (
    r.status = 'completed' 
    OR r.lifecycle_status IN ('resolved', 'closed')
)
AND a.status IN ('assigned', 'accepted', 'enroute', 'on_scene');

