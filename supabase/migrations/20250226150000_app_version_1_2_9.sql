-- Set app_version to 1.2.9 so older versions (1.2.8 and below) are blocked and must update.
UPDATE public.app_version
SET
  min_version = '1.2.9',
  latest_version = '1.2.9',
  updated_at = now()
WHERE platform = 'android';
