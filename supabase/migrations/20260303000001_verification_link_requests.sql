-- Table for users to request a new verification link (when their email link expired).
-- Admins see these in User Management and can send verification.
CREATE TABLE IF NOT EXISTS public.verification_link_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text NOT NULL,
    requested_at timestamptz NOT NULL DEFAULT now(),
    fulfilled_at timestamptz,
    fulfilled_by uuid REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_verification_link_requests_email ON public.verification_link_requests(email);
CREATE INDEX IF NOT EXISTS idx_verification_link_requests_fulfilled ON public.verification_link_requests(fulfilled_at);
CREATE INDEX IF NOT EXISTS idx_verification_link_requests_requested_at ON public.verification_link_requests(requested_at DESC);

ALTER TABLE public.verification_link_requests ENABLE ROW LEVEL SECURITY;

-- Only admins and super_users can read; inserts done via Edge Function (service role)
CREATE POLICY "Admins can read verification_link_requests"
    ON public.verification_link_requests FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_id = auth.uid() AND role IN ('admin', 'super_user')
        )
    );

-- Only service role can insert/update (Edge Functions use service role)
CREATE POLICY "Service role can manage verification_link_requests"
    ON public.verification_link_requests FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

COMMENT ON TABLE public.verification_link_requests IS 'User requests for a new verification email when their link expired; admins fulfill via User Management.';
