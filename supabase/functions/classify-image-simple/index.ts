import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://hmolyqzbvxxliemclrld.supabase.co";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI0Njk3MCwiZXhwIjoyMDc1ODIyOTcwfQ.496txRbAGuiOov76vxdwSDUHplBt1osOD2PyV0EE958";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

Deno.serve(async (req) => {
  try {
    // Handle CORS preflight requests
    if (req.method === "OPTIONS") {
      return new Response(null, { 
        status: 200,
        headers: corsHeaders 
      });
    }

    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "POST only" }), { 
        status: 405, 
        headers: { 
          "Content-Type": "application/json",
          ...corsHeaders
        } 
      });
    }

    const body = await req.json().catch(() => null);
    const reportId = body?.reportId;
    
    if (!reportId) {
      return new Response(JSON.stringify({ error: "reportId required" }), { 
        status: 400, 
        headers: { 
          "Content-Type": "application/json",
          ...corsHeaders
        } 
      });
    }

    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(reportId)) {
      return new Response(JSON.stringify({ error: "Invalid reportId format. Must be a valid UUID." }), { 
        status: 400, 
        headers: { 
          "Content-Type": "application/json",
          ...corsHeaders
        } 
      });
    }

    // Get the report
    const { data: report, error: fetchErr } = await supabase
      .from("reports")
      .select("*")
      .eq("id", reportId)
      .maybeSingle();

    if (fetchErr) {
      throw new Error("Failed to fetch report: " + JSON.stringify(fetchErr));
    }
    
    if (!report) {
      return new Response(JSON.stringify({ error: "report not found" }), { 
        status: 404, 
        headers: { 
          "Content-Type": "application/json",
          ...corsHeaders
        } 
      });
    }

    // Simple mock classification for testing
    const mockClassification = {
      type: "flood",
      confidence: 0.85,
      details: ["Mock classification for testing", "CORS working properly"],
      analysis: "Simplified function working correctly"
    };

    // Update the report with mock classification
    const { error: updateErr } = await supabase
      .from("reports")
      .update({
        type: mockClassification.type,
        confidence: mockClassification.confidence,
        status: "classified",
        ai_labels: mockClassification.details,
        ai_timestamp: new Date().toISOString(),
        ai_analysis: mockClassification.analysis
      })
      .eq("id", reportId);

    if (updateErr) {
      throw new Error("DB update failed: " + JSON.stringify(updateErr));
    }

    return new Response(JSON.stringify({ ok: true, mapped: mockClassification }), { 
      status: 200, 
      headers: { 
        "Content-Type": "application/json",
        ...corsHeaders
      } 
    });

  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        ...corsHeaders
      }
    });
  }
});
