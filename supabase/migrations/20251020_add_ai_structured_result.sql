-- Add structured AI analysis JSON column to reports
alter table if exists public.reports
  add column if not exists ai_structured_result jsonb;

-- Helpful index for querying by keys inside the JSON if needed later
-- create index concurrently if not exists idx_reports_ai_structured_result_gin on public.reports using gin (ai_structured_result jsonb_path_ops);

