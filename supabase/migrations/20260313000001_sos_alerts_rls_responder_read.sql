-- Allow responders (and any authenticated user) to read sos_alerts so that when they
-- load their SOS assignments, the second query (sos_alerts by id) returns rows and
-- the assignment shows in My Assignments. Without this, RLS blocks the select and
-- the responder never sees the SOS in the list.
-- Migration: 20260313000001_sos_alerts_rls_responder_read.sql

ALTER TABLE public.sos_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can read sos_alerts" ON public.sos_alerts;
CREATE POLICY "Authenticated can read sos_alerts"
    ON public.sos_alerts FOR SELECT
    TO authenticated
    USING (true);

-- Allow authenticated users to update sos_alerts (e.g. responder marks resolved)
DROP POLICY IF EXISTS "Authenticated can update sos_alerts" ON public.sos_alerts;
CREATE POLICY "Authenticated can update sos_alerts"
    ON public.sos_alerts FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

COMMENT ON POLICY "Authenticated can read sos_alerts" ON public.sos_alerts IS 'Responders need to read alert details for their SOS assignments';
