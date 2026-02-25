-- Set app_version to 1.2.1 so devices on 1.2.0 or lower get "update required" and cannot use the app until they update.
UPDATE public.app_version
SET
  min_version = '1.2.1',
  latest_version = '1.2.1',
  updated_at = now()
WHERE platform = 'android';
