-- Create learning_progress table for per-user LMS progress
-- Migration: 20251030_create_learning_progress.sql

-- Enum-like status via text with check constraint
CREATE TABLE IF NOT EXISTS public.learning_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  module_id uuid NOT NULL REFERENCES public.learning_modules(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'not_started', -- not_started | in_progress | completed
  progress integer NOT NULL DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  score integer CHECK (score >= 0 AND score <= 100),
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT learning_progress_user_module_unique UNIQUE (user_id, module_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_learning_progress_user ON public.learning_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_learning_progress_module ON public.learning_progress(module_id);
CREATE INDEX IF NOT EXISTS idx_learning_progress_status ON public.learning_progress(status);

-- updated_at trigger
DROP FUNCTION IF EXISTS public.set_updated_at_progress CASCADE;
CREATE OR REPLACE FUNCTION public.set_updated_at_progress()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_learning_progress_updated_at ON public.learning_progress;
CREATE TRIGGER trg_learning_progress_updated_at
BEFORE UPDATE ON public.learning_progress
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_progress();

-- RLS
ALTER TABLE public.learning_progress ENABLE ROW LEVEL SECURITY;

-- Users can select their own progress
DO $$ BEGIN
  BEGIN
    CREATE POLICY learning_progress_select_own
    ON public.learning_progress FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- Users can insert/update their own progress rows
DO $$ BEGIN
  BEGIN
    CREATE POLICY learning_progress_write_own
    ON public.learning_progress FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$ BEGIN
  BEGIN
    CREATE POLICY learning_progress_update_own
    ON public.learning_progress FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- Admins can view all
DO $$ BEGIN
  BEGIN
    CREATE POLICY learning_progress_admin_all
    ON public.learning_progress FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;


