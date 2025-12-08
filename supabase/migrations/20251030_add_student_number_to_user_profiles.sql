-- Add missing student_number field to active user profiles
ALTER TABLE IF EXISTS public.user_profiles
  ADD COLUMN IF NOT EXISTS student_number text;

-- Optional: backfill from auth metadata when possible
DO $$
BEGIN
  -- Only attempt if column exists (safety) and table not empty
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_profiles'
      AND column_name = 'student_number'
  ) THEN
    UPDATE public.user_profiles p
    SET student_number = COALESCE(
      p.student_number,
      (SELECT (u.raw_user_meta_data ->> 'student_number')
       FROM auth.users u
       WHERE u.id = p.user_id)
    )
    WHERE p.student_number IS NULL;
  END IF;
END $$;

COMMENT ON COLUMN public.user_profiles.student_number IS 'Student number for student users (optional)';


