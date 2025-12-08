-- Allow admin and super_user to insert notifications from client (for broadcasts)
-- This relies on public.is_admin(), which treats super_user as admin.

DROP POLICY IF EXISTS "Admins can insert notifications" ON public.notifications;

CREATE POLICY "Admins can insert notifications" ON public.notifications
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_admin());

-- Note: existing service_role insert policy remains in place for Edge Functions.


