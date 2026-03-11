-- Operational observability: pipeline events index and alerts table
-- Pipeline events are logged to audit_log (entity_type='report', action in classification_started, classification_done, classification_failed, notify_superusers_called, notify_superusers_failed).
-- This index speeds up queries for "reports that never got classification_done/failed" and pipeline metrics.

CREATE INDEX IF NOT EXISTS idx_audit_log_entity_type_action
  ON public.audit_log (entity_type, action)
  WHERE entity_type = 'report';

-- Table for operational alerts (e.g. classification >2min, notification failed)
-- The check-report-pipeline-alerts edge function inserts here when it detects overdue/failed pipeline stages.
CREATE TABLE IF NOT EXISTS public.operational_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid REFERENCES public.reports(id) ON DELETE SET NULL,
  alert_type text NOT NULL,
  message text,
  details jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_operational_alerts_report_id ON public.operational_alerts(report_id);
CREATE INDEX IF NOT EXISTS idx_operational_alerts_created_at ON public.operational_alerts(created_at);
CREATE INDEX IF NOT EXISTS idx_operational_alerts_alert_type ON public.operational_alerts(alert_type);

ALTER TABLE public.operational_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access to operational_alerts" ON public.operational_alerts
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Admins can read operational_alerts" ON public.operational_alerts
  FOR SELECT USING (public.is_admin());

COMMENT ON TABLE public.operational_alerts IS 'Alerts when report pipeline exceeds SLA (e.g. classification >2min) or notification fails. Populated by check-report-pipeline-alerts function.';
