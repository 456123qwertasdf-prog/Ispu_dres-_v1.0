-- Enforce unique ID number (student_number), and contact number (phone) for signup.
-- Email uniqueness is already enforced by Supabase Auth.

-- Step 1: Clear duplicate student_number and phone so unique indexes can be created.
-- Keep one row per value (smallest id); set the rest to NULL.
WITH kept_sn AS (
  SELECT DISTINCT ON (trim(student_number)) id
  FROM public.user_profiles
  WHERE student_number IS NOT NULL AND trim(student_number) <> ''
  ORDER BY trim(student_number), id
)
UPDATE public.user_profiles up
SET student_number = NULL
WHERE up.student_number IS NOT NULL AND trim(up.student_number) <> ''
  AND up.id NOT IN (SELECT id FROM kept_sn);

WITH kept_ph AS (
  SELECT DISTINCT ON (trim(regexp_replace(phone, '\s+', '', 'g'))) id
  FROM public.user_profiles
  WHERE phone IS NOT NULL AND trim(phone) <> ''
  ORDER BY trim(regexp_replace(phone, '\s+', '', 'g')), id
)
UPDATE public.user_profiles up
SET phone = NULL
WHERE up.phone IS NOT NULL AND trim(up.phone) <> ''
  AND up.id NOT IN (SELECT id FROM kept_ph);

-- Step 2: Unique constraints (allow multiple NULLs)
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_student_number_unique
  ON public.user_profiles (trim(student_number))
  WHERE student_number IS NOT NULL AND trim(student_number) <> '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_phone_unique
  ON public.user_profiles (trim(regexp_replace(phone, '\s+', '', 'g')))
  WHERE phone IS NOT NULL AND trim(phone) <> '';

-- RPC for signup form: check if student_number or phone is already taken (callable by anon).
-- Returns only booleans; no user data exposed.
CREATE OR REPLACE FUNCTION public.check_signup_unique(p_student_number text, p_phone text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  id_number_taken boolean := false;
  phone_taken boolean := false;
  sn text;
  ph text;
BEGIN
  sn := nullif(trim(p_student_number), '');
  ph := nullif(trim(regexp_replace(p_phone, '\s+', '', 'g')), '');

  IF sn IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE trim(student_number) = sn
    ) INTO id_number_taken;
  END IF;

  IF ph IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE trim(regexp_replace(phone, '\s+', '', 'g')) = ph
    ) INTO phone_taken;
  END IF;

  RETURN jsonb_build_object(
    'id_number_taken', id_number_taken,
    'phone_taken', phone_taken
  );
END;
$$;

COMMENT ON FUNCTION public.check_signup_unique(text, text) IS 'Check if ID number or contact number is already used; for signup uniqueness. Callable by anon.';

-- Grant execute to anon so signup page can call without being logged in
GRANT EXECUTE ON FUNCTION public.check_signup_unique(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_signup_unique(text, text) TO authenticated;

-- Update handle_new_user to set student_number and phone from auth metadata when present
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    user_role TEXT;
    user_name TEXT;
    user_type_value TEXT;
    user_types_value TEXT[];
    user_student_number TEXT;
    user_phone TEXT;
BEGIN
    user_role := COALESCE(
        NEW.raw_user_meta_data ->> 'role',
        NEW.raw_user_meta_data ->> 'user_role',
        'citizen'
    );
    user_name := COALESCE(
        NEW.raw_user_meta_data ->> 'full_name',
        NEW.raw_user_meta_data ->> 'name',
        split_part(NEW.email, '@', 1)
    );
    user_student_number := nullif(trim(NEW.raw_user_meta_data ->> 'student_number'), '');
    user_phone := nullif(trim(regexp_replace(COALESCE(NEW.raw_user_meta_data ->> 'phone', ''), '\s+', '', 'g')), '');

    -- Prefer user_types (JSON array in metadata); fallback to user_type single value
    IF NEW.raw_user_meta_data ? 'user_types' AND jsonb_typeof(NEW.raw_user_meta_data -> 'user_types') = 'array' THEN
        SELECT array_agg(elem::text) INTO user_types_value
        FROM jsonb_array_elements_text(NEW.raw_user_meta_data -> 'user_types') AS elem;
    END IF;
    IF user_types_value IS NULL OR array_length(user_types_value, 1) IS NULL THEN
        user_type_value := COALESCE(
            NEW.raw_user_meta_data ->> 'user_type',
            'student'
        );
        user_types_value := ARRAY[user_type_value];
    ELSE
        user_type_value := user_types_value[1];
    END IF;

    INSERT INTO public.user_profiles (user_id, role, name, user_type, user_types, is_active, student_number, phone)
    VALUES (NEW.id, user_role, user_name, user_type_value, user_types_value, true, user_student_number, user_phone);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
