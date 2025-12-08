-- LMS core: courses and module enhancements
-- Migration: 20251031_create_lms_core.sql

-- Courses table
CREATE TABLE IF NOT EXISTS public.lms_courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.lms_courses ENABLE ROW LEVEL SECURITY;

-- Anyone can read courses; admins/responders can manage
DO $$ BEGIN
  BEGIN
    CREATE POLICY lms_courses_select_all ON public.lms_courses FOR SELECT TO anon, authenticated USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$ BEGIN
  BEGIN
    CREATE POLICY lms_courses_manage_admin ON public.lms_courses FOR ALL TO authenticated USING (public.is_admin() OR (auth.jwt() -> 'user_metadata' ->> 'role') IN ('admin','responder')) WITH CHECK (public.is_admin() OR (auth.jwt() -> 'user_metadata' ->> 'role') IN ('admin','responder'));
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- Add course linkage and module metadata to learning_modules
ALTER TABLE public.learning_modules
  ADD COLUMN IF NOT EXISTS course_id uuid REFERENCES public.lms_courses(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS estimated_minutes integer,
  ADD COLUMN IF NOT EXISTS quiz_required boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS pass_score integer DEFAULT 70;

CREATE INDEX IF NOT EXISTS idx_learning_modules_course ON public.learning_modules(course_id);


