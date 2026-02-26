-- Set app_version to 1.2.10 so older versions (1.2.9 and below) are blocked and must update.
UPDATE public.app_version
SET
  min_version = '1.2.10',
  latest_version = '1.2.10',
  updated_at = now()
WHERE platform = 'android';
