import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

/** Target: classification should complete within this many milliseconds. */
const CLASSIFICATION_TARGET_MS = 2 * 60 * 1000;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { persistSession: false },
    });

    const cutoff = new Date(Date.now() - CLASSIFICATION_TARGET_MS).toISOString();

    // Reports created >2 min ago that are still pending (no classification result yet)
    const { data: staleReports, error: reportsErr } = await supabase
      .from("reports")
      .select("id, created_at, status")
      .lt("created_at", cutoff)
      .eq("status", "pending");

    if (reportsErr) {
      console.error("Failed to fetch stale reports:", reportsErr);
      return new Response(
        JSON.stringify({ ok: false, error: reportsErr.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!staleReports?.length) {
      return new Response(
        JSON.stringify({ ok: true, alerts_created: 0, message: "No stale reports" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    const reportIds = staleReports.map((r) => r.id);

    // Which of these already have classification_done or classification_failed?
    const { data: pipelineEvents } = await supabase
      .from("audit_log")
      .select("entity_id")
      .eq("entity_type", "report")
      .in("action", ["classification_done", "classification_failed"])
      .in("entity_id", reportIds);

    const completedIds = new Set((pipelineEvents ?? []).map((e: any) => e.entity_id));

    const toAlert = staleReports.filter((r) => !completedIds.has(r.id));
    if (toAlert.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, alerts_created: 0, stale_but_completed: staleReports.length }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    // Avoid duplicate alerts: only insert if we don't already have an alert for this report + type
    const { data: existing } = await supabase
      .from("operational_alerts")
      .select("report_id")
      .eq("alert_type", "classification_overdue")
      .in("report_id", toAlert.map((r) => r.id));

    const alreadyAlerted = new Set((existing ?? []).map((r: any) => r.report_id));
    const toInsert = toAlert.filter((r) => !alreadyAlerted.has(r.id));
    let inserted = 0;

    for (const report of toInsert) {
      const { error: insertErr } = await supabase.from("operational_alerts").insert({
        report_id: report.id,
        alert_type: "classification_overdue",
        message: `Report ${report.id} still pending after >2 minutes; classification_done/failed never recorded.`,
        details: {
          report_created_at: report.created_at,
          cutoff,
          target_seconds: CLASSIFICATION_TARGET_MS / 1000,
        },
      });
      if (!insertErr) inserted++;
      else console.warn("Failed to insert alert for report", report.id, insertErr);
    }

    return new Response(
      JSON.stringify({
        ok: true,
        alerts_created: inserted,
        stale_count: staleReports.length,
        already_completed: completedIds.size,
        report_ids_alerted: toAlert.map((r) => r.id),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (err) {
    console.error("check-report-pipeline-alerts error", err);
    return new Response(
      JSON.stringify({ ok: false, error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
