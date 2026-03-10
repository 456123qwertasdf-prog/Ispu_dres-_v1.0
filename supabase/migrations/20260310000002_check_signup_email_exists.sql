-- Check if email is already registered in auth.users (so create-user can return ID + phone + email errors in one response).
-- Callable by service_role only (used by create-user Edge Function).
CREATE OR REPLACE FUNCTION public.check_signup_email_exists(p_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users
    WHERE lower(trim(email)) = lower(trim(nullif(p_email, '')))
  );
END;
$$;

COMMENT ON FUNCTION public.check_signup_email_exists(text) IS 'Check if email is already in auth.users; for signup validation. Used by create-user Edge Function.';

GRANT EXECUTE ON FUNCTION public.check_signup_email_exists(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.check_signup_email_exists(text) TO authenticated;
