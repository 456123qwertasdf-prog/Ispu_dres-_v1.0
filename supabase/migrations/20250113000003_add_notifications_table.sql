-- Add notifications table for real-time notifications
-- Migration: 20250113000003_add_notifications_table.sql

-- Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    type text NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    data jsonb,
    read boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for notifications
CREATE POLICY "Users can read own notifications" ON public.notifications
    FOR SELECT 
    TO authenticated 
    USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE 
    TO authenticated 
    USING (user_id = auth.uid());

CREATE POLICY "Service role can insert notifications" ON public.notifications
    FOR INSERT 
    TO service_role 
    WITH CHECK (true);

CREATE POLICY "Service role can update notifications" ON public.notifications
    FOR UPDATE 
    TO service_role 
    USING (true);

-- Add updated_at trigger
CREATE TRIGGER update_notifications_updated_at 
    BEFORE UPDATE ON public.notifications 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE public.notifications IS 'Real-time notifications for users';
COMMENT ON COLUMN public.notifications.type IS 'Type of notification (assignment_created, status_update, etc.)';
COMMENT ON COLUMN public.notifications.data IS 'Additional notification data in JSON format';
COMMENT ON COLUMN public.notifications.read IS 'Whether the notification has been read by the user';
