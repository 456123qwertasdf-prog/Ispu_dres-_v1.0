-- Migration: Add archive fields to emergency_reports table
-- This migration adds support for archiving reports before permanent deletion

-- Add archived_at column to track when a report was archived
ALTER TABLE emergency_reports 
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;

-- Add archived_by column to track who archived the report
ALTER TABLE emergency_reports 
ADD COLUMN IF NOT EXISTS archived_by UUID REFERENCES auth.users(id);

-- Add index for better performance on archive queries
CREATE INDEX IF NOT EXISTS idx_emergency_reports_archived 
ON emergency_reports(archived_at) 
WHERE archived_at IS NOT NULL;

-- Add index for better performance on status filtering
CREATE INDEX IF NOT EXISTS idx_emergency_reports_status 
ON emergency_reports(status);

-- Add index for better performance on type filtering
CREATE INDEX IF NOT EXISTS idx_emergency_reports_type 
ON emergency_reports(type);

-- Add index for better performance on priority filtering
CREATE INDEX IF NOT EXISTS idx_emergency_reports_priority 
ON emergency_reports(priority);

-- Add composite index for common queries
CREATE INDEX IF NOT EXISTS idx_emergency_reports_status_created 
ON emergency_reports(status, created_at DESC);

-- Add comment to document the archive functionality
COMMENT ON COLUMN emergency_reports.archived_at IS 'Timestamp when the report was archived';
COMMENT ON COLUMN emergency_reports.archived_by IS 'User ID who archived the report';

-- Update RLS policies to handle archived reports
-- Allow users to view their own archived reports
CREATE POLICY "Users can view their own archived reports" ON emergency_reports
    FOR SELECT USING (
        auth.uid() = user_id AND status = 'archived'
    );

-- Allow admins to view all archived reports
CREATE POLICY "Admins can view all archived reports" ON emergency_reports
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.raw_user_meta_data->>'role' = 'admin'
        ) AND status = 'archived'
    );

-- Allow admins to archive reports
CREATE POLICY "Admins can archive reports" ON emergency_reports
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.raw_user_meta_data->>'role' = 'admin'
        )
    );

-- Allow admins to restore archived reports
CREATE POLICY "Admins can restore archived reports" ON emergency_reports
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.raw_user_meta_data->>'role' = 'admin'
        ) AND status = 'archived'
    );
