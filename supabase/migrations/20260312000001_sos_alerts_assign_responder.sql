-- Add responder assignment support to sos_alerts so super users can assign responders to SOS.
-- Migration: 20260312000001_sos_alerts_assign_responder.sql

ALTER TABLE public.sos_alerts
ADD COLUMN IF NOT EXISTS assigned_responder_id uuid REFERENCES public.responder(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS assigned_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_sos_alerts_assigned_responder_id ON public.sos_alerts(assigned_responder_id);

COMMENT ON COLUMN public.sos_alerts.assigned_responder_id IS 'Responder assigned to this SOS alert by super user';
COMMENT ON COLUMN public.sos_alerts.assigned_at IS 'When the responder was assigned';
