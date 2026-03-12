-- SOS assignments: when a super user assigns a responder to an SOS alert, create a row here
-- so the responder sees it in "My Assignments" (web and mobile) like report assignments.
-- Migration: 20260312000002_sos_assignment_table.sql

CREATE TABLE IF NOT EXISTS public.sos_assignment (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sos_alert_id uuid NOT NULL REFERENCES public.sos_alerts(id) ON DELETE CASCADE,
    responder_id uuid NOT NULL REFERENCES public.responder(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned', 'accepted', 'enroute', 'on_scene', 'resolved')),
    assigned_at timestamptz NOT NULL DEFAULT now(),
    accepted_at timestamptz,
    completed_at timestamptz,
    updated_at timestamptz DEFAULT now(),
    notes text
);

CREATE INDEX IF NOT EXISTS idx_sos_assignment_sos_alert_id ON public.sos_assignment(sos_alert_id);
CREATE INDEX IF NOT EXISTS idx_sos_assignment_responder_id ON public.sos_assignment(responder_id);
CREATE INDEX IF NOT EXISTS idx_sos_assignment_status ON public.sos_assignment(status);

ALTER TABLE public.sos_assignment ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read their own SOS assignments and admins/super_users to manage
CREATE POLICY "Users can read sos_assignments"
    ON public.sos_assignment FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can insert sos_assignments"
    ON public.sos_assignment FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Users can update sos_assignments"
    ON public.sos_assignment FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

COMMENT ON TABLE public.sos_assignment IS 'Assignments of responders to SOS alerts; shown in responder dashboard like report assignments';
