# check-report-pipeline-alerts

Runs pipeline observability checks and inserts into `operational_alerts` when:

- **classification_overdue**: A report is still `pending` more than 2 minutes after `created_at` and has no `classification_done` or `classification_failed` event in `audit_log`.

Duplicate alerts for the same report are avoided (only one alert per report per type).

## Schedule (e.g. every 5 minutes)

- **Supabase Dashboard**: Project → Edge Functions → `check-report-pipeline-alerts` → can be triggered manually or via cron.
- **External cron**: Call `POST https://<project>.supabase.co/functions/v1/check-report-pipeline-alerts` with `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>` every 5 minutes.
- **pg_cron** (if enabled): Use a DB job that calls `net.http_post` to the function URL, or run a small worker that invokes this function on an interval.

## Pipeline events (audit_log)

The classify-image function logs to `audit_log` with `entity_type = 'report'` and actions:

- `classification_started`
- `classification_done` (with `classification_duration_ms`, `report_created_at` in details)
- `classification_failed` (with `error`, `report_created_at`)
- `notify_superusers_called` (with `duration_ms`, `sent`)
- `notify_superusers_failed` (with `duration_ms`, `error`)

Query timing: time from report created to super user notified = (timestamp of `notify_superusers_called`) − `reports.created_at`.
