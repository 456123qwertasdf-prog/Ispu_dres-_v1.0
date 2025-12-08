-- LMS quizzes and results
-- Migration: 20251031_create_lms_quizzes.sql

-- A quiz attaches to one module
CREATE TABLE IF NOT EXISTS public.lms_quizzes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module_id uuid NOT NULL REFERENCES public.learning_modules(id) ON DELETE CASCADE,
  pass_score integer NOT NULL DEFAULT 70,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lms_quizzes_module ON public.lms_quizzes(module_id);
ALTER TABLE public.lms_quizzes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  BEGIN
    CREATE POLICY lms_quizzes_select_all ON public.lms_quizzes FOR SELECT TO anon, authenticated USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$ BEGIN
  BEGIN
    CREATE POLICY lms_quizzes_manage_admin ON public.lms_quizzes FOR ALL TO authenticated USING (public.is_admin() OR (auth.jwt() -> 'user_metadata' ->> 'role') IN ('admin','responder')) WITH CHECK (public.is_admin() OR (auth.jwt() -> 'user_metadata' ->> 'role') IN ('admin','responder'));
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- Questions
CREATE TABLE IF NOT EXISTS public.lms_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id uuid NOT NULL REFERENCES public.lms_quizzes(id) ON DELETE CASCADE,
  question_text text NOT NULL,
  question_type text NOT NULL DEFAULT 'mcq' -- mcq | tf
);
CREATE INDEX IF NOT EXISTS idx_lms_questions_quiz ON public.lms_questions(quiz_id);
ALTER TABLE public.lms_questions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  BEGIN
    CREATE POLICY lms_questions_select_all ON public.lms_questions FOR SELECT TO anon, authenticated USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$ BEGIN
  BEGIN
    CREATE POLICY lms_questions_manage_admin ON public.lms_questions FOR ALL TO authenticated USING (public.is_admin() OR (auth.jwt() -> 'user_metadata' ->> 'role') IN ('admin','responder')) WITH CHECK (public.is_admin() OR (auth.jwt() -> 'user_metadata' ->> 'role') IN ('admin','responder'));
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- Options
CREATE TABLE IF NOT EXISTS public.lms_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL REFERENCES public.lms_questions(id) ON DELETE CASCADE,
  option_text text NOT NULL,
  is_correct boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_lms_options_question ON public.lms_options(question_id);
ALTER TABLE public.lms_options ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  BEGIN
    CREATE POLICY lms_options_select_all ON public.lms_options FOR SELECT TO anon, authenticated USING (true);
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$ BEGIN
  BEGIN
    CREATE POLICY lms_options_manage_admin ON public.lms_options FOR ALL TO authenticated USING (public.is_admin() OR (auth.jwt() -> 'user_metadata' ->> 'role') IN ('admin','responder')) WITH CHECK (public.is_admin() OR (auth.jwt() -> 'user_metadata' ->> 'role') IN ('admin','responder'));
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- Results
CREATE TABLE IF NOT EXISTS public.lms_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  module_id uuid NOT NULL REFERENCES public.learning_modules(id) ON DELETE CASCADE,
  score integer NOT NULL,
  passed boolean NOT NULL,
  taken_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lms_results_user ON public.lms_results(user_id);
CREATE INDEX IF NOT EXISTS idx_lms_results_module ON public.lms_results(module_id);
ALTER TABLE public.lms_results ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  BEGIN
    CREATE POLICY lms_results_select_own ON public.lms_results FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_admin());
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$ BEGIN
  BEGIN
    CREATE POLICY lms_results_insert_own ON public.lms_results FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;


