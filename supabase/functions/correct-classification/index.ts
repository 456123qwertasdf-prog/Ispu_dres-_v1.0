import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
// deno-types-ignore
declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

interface CorrectionRequest {
  report_id: string;
  corrected_type: string;
  correction_reason: string;
  issue_categories?: string[];
  correction_confidence?: boolean;
  corrected_description?: string; // Optional: allows updating the description part (e.g., "Vehicle Incident")
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    // Get auth token from request
    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Create client with service role key for authenticated operations
    const authToken = authHeader.replace("Bearer ", "");
    const authSupabase = createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { persistSession: false },
    });

    // Get current user using the token
    const { data: { user }, error: userError } = await authSupabase.auth.getUser(authToken);
    if (userError || !user) {
      console.error("Auth error:", userError);
      return new Response(
        JSON.stringify({ error: "Unauthorized", details: userError?.message || "Invalid token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check if user is admin
    const { data: profile, error: profileError } = await authSupabase
      .from("user_profiles")
      .select("role")
      .eq("user_id", user.id)
      .single();

    // Also check user metadata as fallback
    const userRole = profile?.role || 
                     (user.user_metadata?.role) || 
                     (user.user_metadata?.user_role) ||
                     (user.raw_user_meta_data?.role) ||
                     (user.raw_user_meta_data?.user_role);

    if (userRole !== "admin") {
      console.error("Admin check failed:", { 
        profile, 
        profileError, 
        userRole, 
        userMetadata: user.user_metadata,
        rawMetadata: user.raw_user_meta_data 
      });
      return new Response(
        JSON.stringify({ error: "Admin access required. Current role: " + (userRole || "none") }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse request body
    const body: CorrectionRequest = await req.json();
    let { report_id, corrected_type, correction_reason, issue_categories = [], correction_confidence = true, corrected_description } = body;
    
    // Ensure issue_categories is an array (might come as string from JSON)
    if (typeof issue_categories === 'string') {
      try {
        issue_categories = JSON.parse(issue_categories);
      } catch (e) {
        issue_categories = [];
      }
    }
    if (!Array.isArray(issue_categories)) {
      issue_categories = [];
    }

    // Validate required fields
    if (!report_id || !corrected_type || !correction_reason) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: report_id, corrected_type, correction_reason" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Validate correction reason length (minimum 20 characters for detailed explanation)
    if (correction_reason.length < 20) {
      return new Response(
        JSON.stringify({ error: "Correction reason must be at least 20 characters for detailed explanation" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Validate emergency type
    const validTypes = ['flood', 'accident', 'fire', 'medical', 'earthquake', 'storm', 'false_alarm', 'other'];
    if (!validTypes.includes(corrected_type)) {
      return new Response(
        JSON.stringify({ error: `Invalid emergency type. Must be one of: ${validTypes.join(', ')}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get original report
    const { data: report, error: reportError } = await supabase
      .from("reports")
      .select("*")
      .eq("id", report_id)
      .single();

    if (reportError || !report) {
      return new Response(
        JSON.stringify({ error: "Report not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Don't allow correction if already corrected (unless updating)
    if (report.corrected_type && report.corrected_type === corrected_type) {
      return new Response(
        JSON.stringify({ error: "Report already has this correction" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Prepare correction details (for reports.correction_details JSONB field)
    // NOTE: Don't include issue_categories here to avoid trigger casting issues
    const correctionDetails = {
      correction_confidence: correction_confidence,
      original_confidence: report.confidence,
      original_type: report.type,
    };

    // Store AI features for learning
    const aiFeatures = {
      tags: report.ai_labels || [],
      objects: report.ai_objects || [],
      caption: report.ai_description || null,
      people: report.people_count || 0,
      ocr: report.ocr_text || null,
    };

    // Generate updated AI description based on corrected type
    // This ensures the title in my-reports.html updates correctly
    const emergencyTypeNames: Record<string, string> = {
      flood: 'Flood',
      accident: 'Accident',
      fire: 'Fire',
      medical: 'Medical',
      earthquake: 'Earthquake',
      storm: 'Storm',
      false_alarm: 'False Alarm',
      other: 'Other'
    };
    
    const correctedTypeName = emergencyTypeNames[corrected_type] || corrected_type.charAt(0).toUpperCase() + corrected_type.slice(1);
    
    // Update ai_description to reflect corrected type and optional description
    let updatedAiDescription = `${correctedTypeName} Emergency`;
    
    if (corrected_description && corrected_description.trim()) {
      // If admin provided a corrected description, use it
      updatedAiDescription = `${correctedTypeName} Emergency - ${corrected_description.trim()}`;
    } else if (report.ai_description && report.ai_description.includes('-')) {
      // If no custom description provided, try to preserve description part from original
      const parts = report.ai_description.split('-');
      if (parts.length > 1) {
        updatedAiDescription = `${correctedTypeName} Emergency - ${parts.slice(1).join('-').trim()}`;
      }
    }

    // Delete any existing correction record first (from trigger or previous correction)
    await supabase
      .from("classification_corrections")
      .delete()
      .eq("report_id", report_id);

    // Update report with correction
    const { data: updatedReport, error: updateError } = await supabase
      .from("reports")
      .update({
        corrected_type: corrected_type,
        corrected_by: user.id,
        corrected_at: new Date().toISOString(),
        correction_reason: correction_reason,
        correction_details: correctionDetails,
        ai_features: aiFeatures, // Store AI features for learning
        // Update type to corrected type for display
        type: corrected_type,
        // Update ai_description so title updates in my-reports.html
        ai_description: updatedAiDescription,
      })
      .eq("id", report_id)
      .select()
      .single();

    if (updateError) {
      console.error("Error updating report:", updateError);
      return new Response(
        JSON.stringify({ error: `Failed to save correction: ${updateError.message}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Manually insert into classification_corrections with proper TEXT[] format
    // This bypasses the trigger's problematic JSONB->TEXT[] cast
    const { error: correctionInsertError } = await supabase
      .from("classification_corrections")
      .insert({
        report_id: report_id,
        original_type: report.type,
        corrected_type: corrected_type,
        original_confidence: report.confidence,
        correction_reason: correction_reason,
        issue_categories: issue_categories, // Array passed directly - Supabase client handles TEXT[]
        ai_features: aiFeatures,
        corrected_by: user.id,
        correction_confidence: correction_confidence,
      });

    if (correctionInsertError) {
      console.error("Error inserting correction record:", correctionInsertError);
      // Log error details for debugging
      console.error("Issue categories:", issue_categories);
      console.error("Array type:", typeof issue_categories, Array.isArray(issue_categories));
      // Don't fail the whole operation - report update was successful
    }

    // Trigger learning analysis in background (fire and forget)
    // This will analyze corrections and potentially update adaptive config
    fetch(`${SUPABASE_URL}/functions/v1/learn-from-corrections`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${SERVICE_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ triggered_by: "correction" }),
    }).catch(err => {
      console.error("Background learning analysis failed:", err);
      // Non-critical, don't fail the correction
    });

    return new Response(
      JSON.stringify({
        success: true,
        report: {
          id: updatedReport.id,
          original_type: report.type,
          corrected_type: corrected_type,
          corrected_by: user.id,
          corrected_at: updatedReport.corrected_at,
          correction_reason: correction_reason,
        },
        message: "Classification corrected successfully"
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Error correcting classification:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Failed to correct classification" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

