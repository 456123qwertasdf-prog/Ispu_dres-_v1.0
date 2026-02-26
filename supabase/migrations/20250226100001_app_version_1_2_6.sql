-- Set app_version to 1.2.6. Only the latest version is allowed (enforced by get-app-version Edge Function).
UPDATE public.app_version
SET
  min_version = '1.2.6',
  latest_version = '1.2.6',
  updated_at = now()
WHERE platform = 'android';
