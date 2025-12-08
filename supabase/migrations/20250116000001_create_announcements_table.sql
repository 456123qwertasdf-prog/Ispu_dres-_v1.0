-- Create announcements table for admin-created alerts and notifications
-- Migration: 20250116000001_create_announcements_table.sql

-- Create announcements table
CREATE TABLE IF NOT EXISTS public.announcements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    message text NOT NULL,
    type text NOT NULL CHECK (type IN ('emergency', 'weather', 'general', 'maintenance', 'safety')),
    priority text NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'expired')),
    target_audience text NOT NULL DEFAULT 'all' CHECK (target_audience IN ('all', 'students', 'faculty', 'staff', 'responders')),
    created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    expires_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_announcements_type ON public.announcements(type);
CREATE INDEX IF NOT EXISTS idx_announcements_priority ON public.announcements(priority);
CREATE INDEX IF NOT EXISTS idx_announcements_status ON public.announcements(status);
CREATE INDEX IF NOT EXISTS idx_announcements_target_audience ON public.announcements(target_audience);
CREATE INDEX IF NOT EXISTS idx_announcements_created_at ON public.announcements(created_at);
CREATE INDEX IF NOT EXISTS idx_announcements_expires_at ON public.announcements(expires_at);

-- Enable RLS
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- RLS Policies for announcements
-- Allow all authenticated users to read active announcements
CREATE POLICY "Users can read active announcements" ON public.announcements
    FOR SELECT 
    TO authenticated 
    USING (status = 'active' AND (expires_at IS NULL OR expires_at > now()));

-- Allow admins to read all announcements
CREATE POLICY "Admins can read all announcements" ON public.announcements
    FOR SELECT 
    TO authenticated 
    USING (public.is_admin());

-- Allow admins to insert announcements
CREATE POLICY "Admins can insert announcements" ON public.announcements
    FOR INSERT 
    TO authenticated 
    WITH CHECK (public.is_admin());

-- Allow admins to update announcements
CREATE POLICY "Admins can update announcements" ON public.announcements
    FOR UPDATE 
    TO authenticated 
    USING (public.is_admin());

-- Allow admins to delete announcements
CREATE POLICY "Admins can delete announcements" ON public.announcements
    FOR DELETE 
    TO authenticated 
    USING (public.is_admin());

-- Add updated_at trigger
CREATE TRIGGER update_announcements_updated_at 
    BEFORE UPDATE ON public.announcements 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE public.announcements IS 'Admin-created announcements and alerts for all users';
COMMENT ON COLUMN public.announcements.type IS 'Type of announcement (emergency, weather, general, maintenance, safety)';
COMMENT ON COLUMN public.announcements.priority IS 'Priority level (low, medium, high, critical)';
COMMENT ON COLUMN public.announcements.status IS 'Current status (active, inactive, expired)';
COMMENT ON COLUMN public.announcements.target_audience IS 'Target audience (all, students, faculty, staff, responders)';
COMMENT ON COLUMN public.announcements.expires_at IS 'Optional expiration date for the announcement';
