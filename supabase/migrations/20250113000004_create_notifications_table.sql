-- Create notifications table with enhanced schema
-- Migration: 20250113000004_create_notifications_table.sql

-- Drop existing notifications table if it exists (from previous migration)
DROP TABLE IF EXISTS public.notifications CASCADE;

-- Create notifications table with enhanced schema
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    target_type text NOT NULL CHECK (target_type IN ('responder', 'reporter', 'admin')),
    target_id uuid NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    payload jsonb,
    is_read boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_target ON public.notifications(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_target_id ON public.notifications(target_id);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for notifications
-- Allow users to read their own notifications
CREATE POLICY "Users can read own notifications" ON public.notifications
    FOR SELECT 
    TO authenticated 
    USING (
        (target_type = 'responder' AND target_id IN (
            SELECT id FROM public.responder WHERE user_id = auth.uid()
        )) OR
        (target_type = 'reporter' AND target_id IN (
            SELECT id FROM public.reporter WHERE user_id = auth.uid()
        )) OR
        (target_type = 'admin' AND public.is_admin())
    );

-- Allow users to update their own notifications
CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE 
    TO authenticated 
    USING (
        (target_type = 'responder' AND target_id IN (
            SELECT id FROM public.responder WHERE user_id = auth.uid()
        )) OR
        (target_type = 'reporter' AND target_id IN (
            SELECT id FROM public.reporter WHERE user_id = auth.uid()
        )) OR
        (target_type = 'admin' AND public.is_admin())
    );

-- Allow service role to insert notifications
CREATE POLICY "Service role can insert notifications" ON public.notifications
    FOR INSERT 
    TO service_role 
    WITH CHECK (true);

-- Allow service role to update notifications
CREATE POLICY "Service role can update notifications" ON public.notifications
    FOR UPDATE 
    TO service_role 
    USING (true);

-- Add updated_at trigger
CREATE TRIGGER update_notifications_updated_at 
    BEFORE UPDATE ON public.notifications 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE public.notifications IS 'Enhanced notifications system for all user types';
COMMENT ON COLUMN public.notifications.target_type IS 'Type of target user (responder, reporter, admin)';
COMMENT ON COLUMN public.notifications.target_id IS 'ID of the target user (responder_id, reporter_id, or admin user_id)';
COMMENT ON COLUMN public.notifications.type IS 'Type of notification (assignment_created, report_updated, etc.)';
COMMENT ON COLUMN public.notifications.payload IS 'Additional notification data in JSON format';
COMMENT ON COLUMN public.notifications.is_read IS 'Whether the notification has been read by the user';
