-- Set app_version to 1.2.7 so older versions (e.g. 1.2.6) are blocked and must update.
UPDATE public.app_version
SET
  min_version = '1.2.7',
  latest_version = '1.2.7',
  updated_at = now()
WHERE platform = 'android';
