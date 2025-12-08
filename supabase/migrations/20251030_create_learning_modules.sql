-- Create learning_modules table and storage setup
-- Migration: 20251030_create_learning_modules.sql

-- Table: public.learning_modules
CREATE TABLE IF NOT EXISTS public.learning_modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "order" integer NOT NULL DEFAULT 1,
  title text NOT NULL,
  description text,
  -- Either store a public URL directly or a storage path in the learning-modules bucket
  pdf_url text,
  pdf_path text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Keep full replica identity for realtime
ALTER TABLE public.learning_modules REPLICA IDENTITY FULL;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_learning_modules_order ON public.learning_modules("order");
CREATE INDEX IF NOT EXISTS idx_learning_modules_active ON public.learning_modules(active);

-- updated_at trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_learning_modules_updated_at ON public.learning_modules;
CREATE TRIGGER trg_learning_modules_updated_at
BEFORE UPDATE ON public.learning_modules
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RLS
ALTER TABLE public.learning_modules ENABLE ROW LEVEL SECURITY;

-- Read: allow both anon and authenticated to read only active modules
DROP POLICY IF EXISTS learning_modules_select_active_anon ON public.learning_modules;
CREATE POLICY learning_modules_select_active_anon
ON public.learning_modules
FOR SELECT
TO anon, authenticated
USING (active = true);

-- Insert/Update/Delete: admins only (via is_admin())
DROP POLICY IF EXISTS learning_modules_write_admin ON public.learning_modules;
CREATE POLICY learning_modules_write_admin
ON public.learning_modules
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Storage bucket: learning-modules
-- Create bucket if not exists (idempotent)
INSERT INTO storage.buckets (id, name, public)
SELECT 'learning-modules', 'learning-modules', true
WHERE NOT EXISTS (
  SELECT 1 FROM storage.buckets WHERE id = 'learning-modules'
);

-- Storage policies: allow read to everyone, write only to admins
-- Read objects
DO $$ BEGIN
  BEGIN
    CREATE POLICY learning_modules_storage_read
    ON storage.objects FOR SELECT
    TO anon, authenticated
    USING (bucket_id = 'learning-modules');
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- Write objects (admins only)
DO $$ BEGIN
  BEGIN
    CREATE POLICY learning_modules_storage_write
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'learning-modules' AND public.is_admin()
    );
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$ BEGIN
  BEGIN
    CREATE POLICY learning_modules_storage_update
    ON storage.objects FOR UPDATE TO authenticated
    USING (
      bucket_id = 'learning-modules' AND public.is_admin()
    )
    WITH CHECK (
      bucket_id = 'learning-modules' AND public.is_admin()
    );
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$ BEGIN
  BEGIN
    CREATE POLICY learning_modules_storage_delete
    ON storage.objects FOR DELETE TO authenticated
    USING (
      bucket_id = 'learning-modules' AND public.is_admin()
    );
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;


