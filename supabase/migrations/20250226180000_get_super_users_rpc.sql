-- get_super_users: same source for critical report and status-update push (super user receives both)
-- Returns one row per super_user/admin with their OneSignal player_id from onesignal_subscriptions.
-- Used by: notify-superusers-critical-report, update-assignment-status, accept-assignment.

DROP FUNCTION IF EXISTS public.get_super_users();

CREATE OR REPLACE FUNCTION public.get_super_users()
RETURNS TABLE (
  id uuid,
  onesignal_player_id text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    up.user_id AS id,
    (
      SELECT os.player_id
      FROM onesignal_subscriptions os
      WHERE os.user_id = up.user_id
      ORDER BY os.updated_at DESC NULLS LAST
      LIMIT 1
    ) AS onesignal_player_id
  FROM user_profiles up
  WHERE up.role IN ('super_user', 'admin')
    AND up.is_active IS NOT DISTINCT FROM true;
$$;

COMMENT ON FUNCTION public.get_super_users() IS 'Returns super_user/admin user ids and their OneSignal player_id for push notifications (critical report and assignment status updates).';

GRANT EXECUTE ON FUNCTION public.get_super_users() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_super_users() TO authenticated;
