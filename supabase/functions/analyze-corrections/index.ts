import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
// deno-types-ignore
declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

interface CorrectionPattern {
  originalType: string;
  correctedType: string;
  count: number;
  avgConfidence: number;
  commonFeatures: Record<string, number>;
  issueCategories: string[];
  examples: any[];
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST" && req.method !== "GET") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    // Get all corrections
    const { data: corrections, error: correctionsError } = await supabase
      .from("classification_corrections")
      .select("*")
      .order("created_at", { ascending: false });

    if (correctionsError) {
      throw new Error(`Failed to fetch corrections: ${correctionsError.message}`);
    }

    if (!corrections || corrections.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          patterns: [],
          statistics: {
            totalCorrections: 0,
            patternsFound: 0,
            suggestions: []
          },
          message: "No corrections found for analysis"
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Group corrections by pattern (original_type -> corrected_type)
    const patternMap = new Map<string, CorrectionPattern>();

    for (const correction of corrections) {
      const patternKey = `${correction.original_type}->${correction.corrected_type}`;
      
      if (!patternMap.has(patternKey)) {
        patternMap.set(patternKey, {
          originalType: correction.original_type,
          correctedType: correction.corrected_type,
          count: 0,
          avgConfidence: 0,
          commonFeatures: {},
          issueCategories: [],
          examples: [],
        });
      }

      const pattern = patternMap.get(patternKey)!;
      pattern.count++;
      pattern.avgConfidence += correction.original_confidence || 0;
      
      // Collect issue categories
      if (correction.issue_categories) {
        pattern.issueCategories.push(...correction.issue_categories);
      }

      // Extract features from AI analysis
      if (correction.ai_features) {
        const features = typeof correction.ai_features === 'string' 
          ? JSON.parse(correction.ai_features) 
          : correction.ai_features;

        // Extract tags
        if (features.tags && Array.isArray(features.tags)) {
          features.tags.forEach((tag: any) => {
            const tagName = typeof tag === 'string' ? tag : tag.name || tag.label || '';
            if (tagName) {
              pattern.commonFeatures[tagName] = (pattern.commonFeatures[tagName] || 0) + 1;
            }
          });
        }

        // Extract objects
        if (features.objects && Array.isArray(features.objects)) {
          features.objects.forEach((obj: any) => {
            const objName = typeof obj === 'string' ? obj : obj.object || obj.name || '';
            if (objName) {
              pattern.commonFeatures[objName] = (pattern.commonFeatures[objName] || 0) + 1;
            }
          });
        }
      }

      // Store example (limit to 5)
      if (pattern.examples.length < 5) {
        pattern.examples.push({
          id: correction.id,
          report_id: correction.report_id,
          reason: correction.correction_reason,
          created_at: correction.created_at,
        });
      }
    }

    // Calculate averages and normalize features
    const patterns: CorrectionPattern[] = Array.from(patternMap.values()).map(pattern => {
      pattern.avgConfidence = pattern.count > 0 ? pattern.avgConfidence / pattern.count : 0;
      
      // Sort features by frequency
      const sortedFeatures = Object.entries(pattern.commonFeatures)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10); // Top 10 features
      
      pattern.commonFeatures = Object.fromEntries(sortedFeatures);

      // Get unique issue categories
      pattern.issueCategories = [...new Set(pattern.issueCategories)];

      return pattern;
    });

    // Sort patterns by count (most common first)
    patterns.sort((a, b) => b.count - a.count);

    // Generate suggestions for rule improvements
    const suggestions: any[] = [];

    for (const pattern of patterns) {
      if (pattern.count >= 3) {
        // Pattern detected 3+ times - suggest rule improvement
        const topFeatures = Object.keys(pattern.commonFeatures).slice(0, 5);
        
        suggestions.push({
          priority: pattern.count >= 10 ? "high" : pattern.count >= 5 ? "medium" : "low",
          pattern: `${pattern.originalType} -> ${pattern.correctedType}`,
          occurrences: pattern.count,
          suggestedRule: {
            type: "keyword_boost",
            name: `boost_${pattern.correctedType}_when_${pattern.originalType}_misclassified`,
            description: `When classified as ${pattern.originalType} but should be ${pattern.correctedType}`,
            conditions: {
              originalType: pattern.originalType,
              correctedType: pattern.correctedType,
              features: topFeatures,
            },
            boost: 0.2 + (pattern.count * 0.01), // Increase boost with more examples
          },
        });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        patterns: patterns,
        statistics: {
          totalCorrections: corrections.length,
          patternsFound: patterns.length,
          topPattern: patterns[0] || null,
          suggestions: suggestions,
        },
        message: `Analyzed ${corrections.length} corrections and found ${patterns.length} patterns`
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Error analyzing corrections:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Failed to analyze corrections" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

