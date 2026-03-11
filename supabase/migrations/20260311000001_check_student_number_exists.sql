-- RPC for mobile sign-up: check if ID number (student_number) is already registered.
-- Callable by anon so sign-up form can block duplicates without exposing user data.
CREATE OR REPLACE FUNCTION public.check_student_number_exists(num text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE student_number IS NOT NULL
      AND trim(student_number) <> ''
      AND trim(lower(student_number)) = trim(lower(num))
  );
$$;

COMMENT ON FUNCTION public.check_student_number_exists(text) IS 'Returns true if the given ID number (student_number) is already in user_profiles. Used by mobile sign-up to prevent duplicate ID registration.';

-- Allow anon and authenticated to call (anon for sign-up screen)
GRANT EXECUTE ON FUNCTION public.check_student_number_exists(text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_student_number_exists(text) TO authenticated;
