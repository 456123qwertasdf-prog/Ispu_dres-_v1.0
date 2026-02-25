-- Bump app version so in-app update check shows "update available" for 1.1.x installs
UPDATE public.app_version
SET
  min_version = '1.2.0',
  latest_version = '1.2.0',
  updated_at = now()
WHERE platform = 'android';
