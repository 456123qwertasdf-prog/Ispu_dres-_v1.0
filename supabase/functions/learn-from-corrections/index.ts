import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
// deno-types-ignore
declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

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
    // First, analyze corrections to find patterns
    const analysisResponse = await fetch(`${SUPABASE_URL}/functions/v1/analyze-corrections`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${SERVICE_KEY}`,
        "Content-Type": "application/json",
      },
    });

    if (!analysisResponse.ok) {
      throw new Error("Failed to analyze corrections");
    }

    const analysis = await analysisResponse.json();

    if (!analysis.success || !analysis.statistics?.suggestions) {
      return new Response(
        JSON.stringify({
          success: true,
          rulesCreated: 0,
          rulesUpdated: 0,
          message: "No patterns found to create rules"
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let rulesCreated = 0;
    let rulesUpdated = 0;

    // Process each suggestion
    for (const suggestion of analysis.statistics.suggestions) {
      if (suggestion.priority === "low" && suggestion.occurrences < 5) {
        // Skip low-priority suggestions with few examples
        continue;
      }

      const ruleName = suggestion.suggestedRule.name;
      const ruleData = suggestion.suggestedRule;

      // Check if rule already exists
      const { data: existingRule } = await supabase
        .from("adaptive_classifier_config")
        .select("*")
        .eq("rule_name", ruleName)
        .single();

      if (existingRule) {
        // Update existing rule
        const newVersion = (existingRule.version || 1) + 1;
        const newCorrectionCount = (existingRule.learned_from_corrections || 0) + suggestion.occurrences;
        
        // Increase boost based on more examples
        const currentBoost = existingRule.config_data?.boost || 0;
        const suggestedBoost = ruleData.boost || 0.2;
        const newBoost = Math.min(0.5, Math.max(currentBoost, suggestedBoost)); // Cap at 0.5

        await supabase
          .from("adaptive_classifier_config")
          .update({
            config_data: {
              ...existingRule.config_data,
              ...ruleData.conditions,
              boost: newBoost,
            },
            learned_from_corrections: newCorrectionCount,
            version: newVersion,
            updated_at: new Date().toISOString(),
            is_active: true,
          })
          .eq("id", existingRule.id);

        rulesUpdated++;
      } else {
        // Create new rule
        await supabase
          .from("adaptive_classifier_config")
          .insert({
            rule_name: ruleName,
            rule_type: ruleData.type || "keyword_boost",
            config_data: {
              ...ruleData.conditions,
              boost: ruleData.boost || 0.2,
            },
            pattern_description: ruleData.description,
            learned_from_corrections: suggestion.occurrences,
            confidence_boost: ruleData.boost || 0.2,
            is_active: true,
            version: 1,
          });

        rulesCreated++;
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        rulesCreated: rulesCreated,
        rulesUpdated: rulesUpdated,
        totalPatterns: analysis.statistics.patternsFound,
        message: `Created ${rulesCreated} new rules and updated ${rulesUpdated} existing rules`
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Error learning from corrections:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Failed to learn from corrections" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

