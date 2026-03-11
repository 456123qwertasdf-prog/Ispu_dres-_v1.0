-- Add user_types array to user_profiles; support multiple types per user (e.g. first_aider + responder).
-- Keep user_type as first element for backward compatibility.

-- Add the column
ALTER TABLE IF EXISTS public.user_profiles
  ADD COLUMN IF NOT EXISTS user_types text[] DEFAULT ARRAY['student']::text[];

-- Backfill: convert existing user_type to single-element user_types
UPDATE public.user_profiles
SET user_types = CASE
  WHEN user_type IS NOT NULL AND trim(user_type) <> '' THEN ARRAY[user_type]
  ELSE ARRAY['student']::text[]
END
WHERE user_types IS NULL OR array_length(user_types, 1) IS NULL;

-- Ensure no nulls
UPDATE public.user_profiles SET user_types = ARRAY['student']::text[] WHERE user_types IS NULL;

-- Update handle_new_user() to set user_types (and keep user_type as first for compat)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    user_role TEXT;
    user_name TEXT;
    user_type_value TEXT;
    user_types_value TEXT[];
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
    INSERT INTO public.user_profiles (user_id, role, name, user_type, user_types, is_active)
    VALUES (NEW.id, user_role, user_name, user_type_value, user_types_value, true);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update sync_existing_users() to include user_types
CREATE OR REPLACE FUNCTION public.sync_existing_users()
RETURNS void AS $$
DECLARE
    user_record RECORD;
    ut_arr TEXT[];
    ut_single TEXT;
BEGIN
    FOR user_record IN
        SELECT id, email, raw_user_meta_data, created_at
        FROM auth.users
        WHERE id NOT IN (SELECT user_id FROM public.user_profiles)
    LOOP
        ut_arr := NULL;
        IF user_record.raw_user_meta_data ? 'user_types' AND jsonb_typeof(user_record.raw_user_meta_data -> 'user_types') = 'array' THEN
            SELECT array_agg(elem::text) INTO ut_arr FROM jsonb_array_elements_text(user_record.raw_user_meta_data -> 'user_types') AS elem;
        END IF;
        IF ut_arr IS NULL OR array_length(ut_arr, 1) IS NULL THEN
            ut_single := COALESCE(user_record.raw_user_meta_data ->> 'user_type', 'student');
            ut_arr := ARRAY[ut_single];
        ELSE
            ut_single := ut_arr[1];
        END IF;
        INSERT INTO public.user_profiles (user_id, role, name, user_type, user_types, is_active, created_at)
        VALUES (
            user_record.id,
            COALESCE(user_record.raw_user_meta_data ->> 'role', user_record.raw_user_meta_data ->> 'user_role', 'citizen'),
            COALESCE(user_record.raw_user_meta_data ->> 'full_name', user_record.raw_user_meta_data ->> 'name', split_part(user_record.email, '@', 1)),
            ut_single,
            ut_arr,
            true,
            user_record.created_at
        );
    END LOOP;
    -- Backfill user_types for existing profiles that have user_type but null/empty user_types
    UPDATE public.user_profiles p
    SET user_types = CASE
        WHEN p.user_types IS NULL OR array_length(p.user_types, 1) IS NULL THEN
            COALESCE((SELECT ARRAY[u.raw_user_meta_data ->> 'user_type'] FROM auth.users u WHERE u.id = p.user_id), ARRAY[p.user_type], ARRAY['student']::text[])
        ELSE p.user_types
    END
    WHERE p.user_types IS NULL OR array_length(p.user_types, 1) IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Sync user_types from auth metadata when updated
CREATE OR REPLACE FUNCTION public.sync_user_type_from_auth()
RETURNS TRIGGER AS $$
DECLARE
    new_types TEXT[];
    new_single TEXT;
BEGIN
    IF NEW.raw_user_meta_data ? 'user_types' AND jsonb_typeof(NEW.raw_user_meta_data -> 'user_types') = 'array' THEN
        SELECT array_agg(elem::text) INTO new_types FROM jsonb_array_elements_text(NEW.raw_user_meta_data -> 'user_types') AS elem;
    END IF;
    IF new_types IS NULL OR array_length(new_types, 1) IS NULL THEN
        new_single := COALESCE(NEW.raw_user_meta_data ->> 'user_type', OLD.raw_user_meta_data ->> 'user_type', 'student');
        new_types := ARRAY[new_single];
    ELSE
        new_single := new_types[1];
    END IF;
    UPDATE public.user_profiles
    SET user_type = new_single, user_types = new_types
    WHERE user_id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: fire when user_types or user_type in metadata changes
DROP TRIGGER IF EXISTS sync_user_type_on_auth_update ON auth.users;
CREATE TRIGGER sync_user_type_on_auth_update
    AFTER UPDATE OF raw_user_meta_data ON auth.users
    FOR EACH ROW
    WHEN (
      (NEW.raw_user_meta_data -> 'user_types') IS DISTINCT FROM (OLD.raw_user_meta_data -> 'user_types')
      OR (NEW.raw_user_meta_data ->> 'user_type') IS DISTINCT FROM (OLD.raw_user_meta_data ->> 'user_type')
    )
    EXECUTE FUNCTION public.sync_user_type_from_auth();

CREATE INDEX IF NOT EXISTS idx_user_profiles_user_types ON public.user_profiles USING GIN (user_types);
COMMENT ON COLUMN public.user_profiles.user_types IS 'User types array: e.g. student, instructor, first_aider, responder, fire_volunteer, etc.';