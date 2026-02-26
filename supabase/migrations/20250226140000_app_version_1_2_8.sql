-- Set app_version to 1.2.8 so older versions (1.2.7 and below) are blocked and must update.
UPDATE public.app_version
SET
  min_version = '1.2.8',
  latest_version = '1.2.8',
  updated_at = now()
WHERE platform = 'android';
