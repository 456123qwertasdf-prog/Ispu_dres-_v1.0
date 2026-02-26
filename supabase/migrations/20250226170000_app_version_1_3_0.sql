-- Set app_version to 1.3.0 (responder assignment fix: cannot assign responder who already has active assignment).
UPDATE public.app_version
SET
  min_version = '1.3.0',
  latest_version = '1.3.0',
  updated_at = now()
WHERE platform = 'android';
