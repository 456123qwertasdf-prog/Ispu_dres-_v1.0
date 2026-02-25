-- Editable Safety Notice (citizen-facing). Admin/super_user can edit message and disable showing.
CREATE TABLE IF NOT EXISTS public.safety_notice (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    message text,
    enabled boolean NOT NULL DEFAULT true,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by uuid REFERENCES auth.users(id)
);

ALTER TABLE public.safety_notice ENABLE ROW LEVEL SECURITY;

-- Anyone (anon + authenticated) can read so mobile and web can show the notice when enabled
CREATE POLICY "Allow read safety_notice" ON public.safety_notice
    FOR SELECT TO anon, authenticated USING (true);

-- Only admin or super_user can update (insert/update/delete)
CREATE POLICY "Allow admin update safety_notice" ON public.safety_notice
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Seed single row when table is empty
INSERT INTO public.safety_notice (message, enabled)
SELECT null, true
WHERE NOT EXISTS (SELECT 1 FROM public.safety_notice LIMIT 1);

COMMENT ON TABLE public.safety_notice IS 'Editable safety notice shown to citizens on home. When enabled and message is set, it overrides auto-generated synopsis. Only admin/super_user can edit or disable.';
