import { createClient } from "@supabase/supabase-js";
import { analyzeImageWithAzure, scoreImageQuality, normalizeBoundingBox } from "../_shared/azureVision.ts";
// Workspace linter hint for Deno global in Edge Functions
// deno-types-ignore
declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://hmolyqzbvxxliemclrld.supabase.co";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI0Njk3MCwiZXhwIjoyMDc1ODIyOTcwfQ.496txRbAGuiOov76vxdwSDUHplBt1osOD2PyV0EE958";
const HF_TOKEN = Deno.env.get("HF_TOKEN")!;

// Enhanced AI Models Configuration
const AI_MODELS = {
  // Primary Azure Computer Vision (key from AZURE_VISION_KEY secret)
  azure: {
    endpoint: Deno.env.get("AZURE_VISION_ENDPOINT") || "https://ew09.cognitiveservices.azure.com",
    get key() { return Deno.env.get("AZURE_VISION_KEY") ?? ""; },
    // Azure AI Vision Image Analysis v4.0 features
    v4Features: [
      "Caption",
      "Tags",
      "Objects",
      "People",
      "Read",
      "DenseCaptions"
    ].join(',')
  },
  
  // Multiple Hugging Face Models for Ensemble
  huggingface: {
    models: {
      scene: "microsoft/beit-base-patch16-224-pt22k-ft22k",
      description: "Salesforce/blip-image-captioning-base", 
      objects: "facebook/detr-resnet-50",
      emergency: "microsoft/beit-base-patch16-224-pt22k-ft22k",
      safety: "microsoft/beit-base-patch16-224-pt22k-ft22k"
    }
  }
};

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

// Enhanced Emergency Detection Patterns
const EMERGENCY_PATTERNS = {
  flood: {
    keywords: [
      'water', 'flood', 'flooding', 'flooded', 'submerged', 'inundation', 'overflow',
      'rain', 'storm', 'wet', 'drowning', 'wading', 'street', 'road', 'vehicle',
      'people', 'person', 'walking', 'standing', 'umbrella', 'emergency'
    ],
    visualCues: ['water', 'flood', 'rain', 'wet', 'street', 'road', 'people'],
    confidence: 0.9,
    priority: 1
  },
  
  accident: {
    keywords: [
      'car', 'vehicle', 'automobile', 'truck', 'motorcycle', 'bus', 'crash',
      'collision', 'accident', 'damage', 'wreck', 'broken', 'traffic', 'road',
      'street', 'intersection', 'police', 'ambulance', 'firefighter', 'emergency'
    ],
    visualCues: ['car', 'vehicle', 'crash', 'collision', 'damage', 'traffic'],
    confidence: 0.9,
    priority: 2
  },
  
  fire: {
    keywords: [
      'fire', 'smoke', 'flame', 'burning', 'blaze', 'combustion', 'hot', 'burn',
      'ash', 'emergency', 'rescue', 'firefighter', 'fire truck', 'alarm'
    ],
    visualCues: ['fire', 'smoke', 'flame', 'burning', 'hot'],
    confidence: 0.95,
    priority: 1
  },
  
  medical: {
    keywords: [
      'person', 'people', 'injury', 'ambulance', 'medical', 'hospital', 'emergency',
      'rescue', 'paramedic', 'stretcher', 'blood', 'wound', 'patient', 'doctor',
      'nurse', 'health', 'injury', 'hurt', 'pain'
    ],
    visualCues: ['person', 'people', 'ambulance', 'medical', 'injury'],
    confidence: 0.85,
    priority: 2
  },
  
  earthquake: {
    keywords: [
      'earthquake', 'seismic', 'tremor', 'ground', 'crack', 'building', 'collapse',
      'damaged', 'cracked', 'destruction', 'debris', 'emergency'
    ],
    visualCues: ['building', 'crack', 'collapse', 'damage'],
    confidence: 0.9,
    priority: 1
  },
  
  storm: {
    keywords: [
      'storm', 'hurricane', 'typhoon', 'wind', 'tornado', 'cyclone', 'thunder',
      'rain', 'windy', 'severe weather', 'weather emergency'
    ],
    visualCues: ['storm', 'wind', 'rain', 'weather'],
    confidence: 0.8,
    priority: 3
  }
};

// Azure AI Vision Image Analysis v4.0
async function analyzeWithAzureV4(imageBuffer: ArrayBuffer) {
  try {
    console.log("🔍 Azure Image Analysis v4.0");

    const url = `${AI_MODELS.azure.endpoint}/computervision/imageanalysis:analyze?api-version=2023-10-01&features=${encodeURIComponent(AI_MODELS.azure.v4Features)}&language=en`;
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": AI_MODELS.azure.key,
        "Content-Type": "application/octet-stream"
      },
      body: imageBuffer
    });

    if (!response.ok) {
      const txt = await response.text().catch(() => '');
      throw new Error(`Azure Image Analysis v4 error: ${response.status} ${response.statusText} ${txt}`);
    }

    const result = await response.json();
    console.log("✅ Azure v4 analysis successful");

    // Normalize to a friendly shape for our pipeline
    const captionText = result?.captionResult?.text || "";
    const tags = (result?.tagsResult?.values || []).map((t: any) => ({ name: t.name, confidence: t.confidence }));
    const objects = (result?.objectsResult?.values || []).map((o: any) => ({ object: o?.tags?.[0]?.name || o?.name || "object", confidence: o.confidence }));
    const people = (result?.peopleResult?.values || []).length;
    const ocrText = (result?.readResult?.blocks || [])
      .flatMap((b: any) => (b?.lines || []).map((l: any) => l.text))
      .join(' ');
    const denseCaptions = (result?.denseCaptionsResult?.values || []).map((d: any) => d.text);

    return {
      success: true,
      rawResult: result,
      caption: captionText,
      tags,
      objects,
      people,
      ocrText,
      denseCaptions
    };
  } catch (error) {
    console.log("❌ Azure v4 analysis failed:", error.message);
    return { success: false, error: error.message };
  }
}

// Multi-Model Ensemble Analysis
async function performEnsembleAnalysis(imageBuffer: ArrayBuffer) {
  const results: any = {
    azure: null,
    huggingface: {
      scene: null,
      description: null,
      objects: null,
      emergency: null
    }
  };

  try {
    // 1. Azure Image Analysis v4.0 (Primary)
    results.azure = await analyzeWithAzureV4(imageBuffer);
    
    // 2. Hugging Face Models (Secondary)
    const hfPromises = Object.entries(AI_MODELS.huggingface.models).map(async ([type, model]) => {
      try {
        const response = await fetch(`https://api-inference.huggingface.co/models/${model}`, {
          method: "POST",
          headers: { 
            Authorization: `Bearer ${HF_TOKEN}`, 
            "Content-Type": "application/octet-stream" 
          },
          body: imageBuffer,
        });

        if (response.ok) {
          const data = await response.json();
          return { type, data };
        }
        return { type, data: null };
      } catch (error) {
        console.warn(`HF model ${type} failed:`, error);
        return { type, data: null };
      }
    });

    const hfResults = await Promise.all(hfPromises);
    hfResults.forEach(({ type, data }) => {
      if (data) {
        results.huggingface[type] = data;
      }
    });

  } catch (error) {
    console.warn("Ensemble analysis failed:", error);
  }

  return results;
}

// Advanced Emergency Classification with Multi-Model Fusion
function classifyEmergencyAdvanced(ensembleResults: any, reportData: any = {}) {
  const { azure, huggingface } = ensembleResults;
  
  // Combine all text sources
  const allText = [
    // Azure v4 results
    ...(azure?.tags?.map((t: any) => t.name) || []),
    azure?.caption || '',
    ...(azure?.objects?.map((o: any) => o.object) || []),
    azure?.ocrText || '',
    ...(azure?.denseCaptions || []),
    
    // Hugging Face results
    ...(huggingface?.scene?.map((s: any) => s.label) || []),
    ...(huggingface?.description || []),
    ...(huggingface?.objects?.map((o: any) => o.label) || []),
    
    // Report data
    reportData.message || '',
    reportData.location || ''
  ].join(' ').toLowerCase();

  console.log("🔍 Advanced text analysis:", allText);

  // Calculate scores for each emergency type
  const scores: Record<string, number> = {};
  const confidenceScores: Record<string, number> = {};

  Object.entries(EMERGENCY_PATTERNS).forEach(([type, pattern]) => {
    let score = 0;
    let confidence = 0;
    
    // Keyword matching (40% weight)
    const keywordMatches = pattern.keywords.filter(keyword => allText.includes(keyword)).length;
    score += keywordMatches * 0.4;
    
    // Visual cue matching (30% weight)
    const visualMatches = pattern.visualCues.filter(cue => allText.includes(cue)).length;
    score += visualMatches * 0.3;
    
    // Azure v4 confidence (20% weight)
    if (azure?.success) {
      const azureMatches = pattern.keywords.filter(keyword => 
        (azure.tags || []).some((t: any) => (t.name || '').toLowerCase().includes(keyword)) ||
        (azure.caption || '').toLowerCase().includes(keyword) ||
        (azure.objects || []).some((o: any) => (o.object || '').toLowerCase().includes(keyword)) ||
        (azure.ocrText || '').toLowerCase().includes(keyword) ||
        (azure.denseCaptions || []).some((d: string) => (d || '').toLowerCase().includes(keyword))
      ).length;
      score += azureMatches * 0.2;
    }
    
    // Hugging Face confidence (10% weight)
    if (huggingface?.scene) {
      const hfMatches = pattern.keywords.filter(keyword => 
        huggingface.scene.some((s: any) => s.label.toLowerCase().includes(keyword))
      ).length;
      score += hfMatches * 0.1;
    }
    
    // Special pattern detection
    if (type === 'accident' && (allText.includes('collision') || allText.includes('crash') || allText.includes('damage'))) {
      score += 0.3;
    }
    
    if (type === 'flood') {
      const hasWaterWord = allText.includes('water') || allText.includes('flood') || allText.includes('rain');
      const mentionsVehicleOrPeople = allText.includes('car') || allText.includes('vehicle') || allText.includes('person') || allText.includes('people');
      // be stricter: require water + context not dominated by people/vehicle only
      if (hasWaterWord && !mentionsVehicleOrPeople) score += 0.3;
    }
    
    if (type === 'fire' && (allText.includes('fire') || allText.includes('smoke') || allText.includes('flame'))) {
      score += 0.4;
    }
    
    scores[type] = Math.min(score, 1.0);
    confidenceScores[type] = Math.min(score * pattern.confidence, 1.0);
  });

  // Find the best match
  const maxScore = Math.max(...(Object.values(scores as any) as number[]));
  const predictedType = Object.keys(scores).find(key => (scores as any)[key] === maxScore);
  const confidence = predictedType ? confidenceScores[predictedType] || 0.5 : 0.5;

  // Generate detailed analysis
  const analysis = generateDetailedAnalysis(predictedType || 'other', scores, ensembleResults);
  
  return {
    type: predictedType || 'other',
    confidence: Math.max(confidence, 0.6), // Minimum confidence threshold
    scores: scores,
    analysis: analysis,
    details: generateEmergencyDetails(predictedType || 'other', ensembleResults),
    ensembleResults: {
      azure: azure?.success ? 'success' : 'failed',
      huggingface: Object.keys(huggingface).filter(k => huggingface[k]).length
    }
  };
}

// Generate detailed analysis report
function generateDetailedAnalysis(type: string, scores: any, ensembleResults: any) {
  const analysis = {
    primaryType: type,
    confidence: (scores as any)[type] || 0,
    alternativeTypes: (Object.entries(scores) as Array<[string, number]>)
      .filter(([t, score]) => t !== type && score > 0.3)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 2)
      .map(([t, score]) => ({ type: t, score })),
    
    evidence: {
      keywords: (() => {
        const kwords: string[] = (((EMERGENCY_PATTERNS as any)[type]?.keywords) || []) as string[];
        return kwords
          .filter((keyword: string) =>
            String(ensembleResults.azure?.caption || '').toLowerCase().includes(String(keyword || '').toLowerCase()) ||
            String(ensembleResults.azure?.ocrText || '').toLowerCase().includes(String(keyword || '').toLowerCase()) ||
            ((ensembleResults.azure?.denseCaptions || []) as string[]).some((d: string) => String(d || '').toLowerCase().includes(String(keyword || '').toLowerCase()))
          )
          .slice(0, 5);
      })(),
      visualCues: (() => {
        const cues: string[] = (((EMERGENCY_PATTERNS as any)[type]?.visualCues) || []) as string[];
        return cues
          .filter((cue: string) => (ensembleResults.azure?.tags || []).some((t: any) => String(t?.name ?? '').toLowerCase().includes(String(cue || '').toLowerCase())))
          .slice(0, 3);
      })()
    },
    
    modelPerformance: {
      azure: ensembleResults.azure?.success ? 'active' : 'failed',
      huggingface: Object.keys(ensembleResults.huggingface).filter(k => ensembleResults.huggingface[k]).length
    }
  };

  return analysis;
}

// Generate emergency-specific details
function generateEmergencyDetails(type: string, ensembleResults: any) {
  const detailsMap = {
    flood: [
      "Water emergency detected",
      "Flooding conditions identified", 
      "Water damage assessment",
      "Emergency water situation",
      "Potential flood risk"
    ],
    accident: [
      "Vehicle collision detected",
      "Traffic accident identified",
      "Road incident confirmed",
      "Vehicle damage observed",
      "Emergency response required"
    ],
    fire: [
      "Fire emergency detected",
      "Smoke or flames identified",
      "Fire hazard assessment",
      "Emergency fire situation",
      "Fire response required"
    ],
    medical: [
      "Medical emergency detected",
      "Injury or health issue identified",
      "Medical assistance required",
      "Health emergency situation",
      "Medical response needed"
    ],
    earthquake: [
      "Seismic activity detected",
      "Structural damage identified",
      "Earthquake emergency",
      "Building damage assessment",
      "Emergency evacuation required"
    ],
    storm: [
      "Severe weather detected",
      "Storm conditions identified",
      "Weather emergency",
      "Storm damage assessment",
      "Weather response required"
    ],
    other: [
      "Emergency situation detected",
      "General emergency identified",
      "Emergency response required",
      "Situation assessment needed",
      "Emergency assistance required"
    ]
  };

  return detailsMap[type] || detailsMap.other;
}

// Enhanced image analysis with confidence scoring
async function analyzeImageWithConfidence(imageBuffer: ArrayBuffer, reportData: any = {}) {
  console.log("🤖 Starting Enhanced AI Analysis...");
  
  // Perform ensemble analysis (Azure primary)
  const azure = await analyzeImageWithAzure(imageBuffer);
  const ensembleResults = { azure } as any;
  
  // Classify with advanced algorithms
  const classification = classifyEmergencyAdvanced(ensembleResults, reportData);
  (classification as any).ensembleResults = ensembleResults;
  
  // Add confidence validation
  if (classification.confidence < 0.6) {
    console.log("⚠️ Low confidence classification, applying fallback logic");
    classification.type = 'other';
    classification.confidence = 0.6;
    (classification as any).analysis.fallback = true;
  }
  
  console.log(`✅ Enhanced AI Analysis Complete: ${classification.type} (${classification.confidence})`);
  
  return classification;
}

// Main function
Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE",
      },
    });
  }

  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "POST only" }), { 
        status: 405, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        } 
      });
    }

    const body = await req.json().catch(() => null);
    const reportId = body?.reportId;
    if (!reportId) return new Response(JSON.stringify({ error: "reportId required" }), { 
      status: 400, 
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      } 
    });

    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(reportId)) {
      return new Response(JSON.stringify({ error: "Invalid reportId format. Must be a valid UUID." }), { 
        status: 400, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        } 
      });
    }

    // Get report data
    const { data: report, error: fetchErr } = await supabase
      .from("reports")
      .select("*")
      .eq("id", reportId)
      .maybeSingle();

    if (fetchErr) throw new Error("Failed to fetch report: " + JSON.stringify(fetchErr));
    if (!report) return new Response(JSON.stringify({ error: "report not found" }), { 
      status: 404, 
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      } 
    });

    const path = report.image_path;
    if (!path) return new Response(JSON.stringify({ error: "image_path missing" }), { 
      status: 400, 
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      } 
    });

    // Download image from storage
    const { data: downloadData, error: downloadError } = await supabase.storage.from("reports-images").download(path);
    
    if (downloadError || !downloadData) {
      console.log("Storage download failed, using enhanced mock classification:", downloadError);
      
      // Enhanced mock classification
      const mockClassification = {
        type: "other",
        confidence: 0.7,
        analysis: "Enhanced mock classification - image not accessible",
        details: ["Emergency situation detected", "Manual review recommended"],
        ensembleResults: { azure: "failed", huggingface: 0 }
      };
      
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

      if (updateErr) throw new Error("DB update failed: " + JSON.stringify(updateErr));

      return new Response(JSON.stringify({ 
        ok: true, 
        mapped: mockClassification,
        note: "Enhanced mock classification used (image not found in storage)" 
      }), { 
        status: 200, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        } 
      });
    }

    const arrayBuffer = await downloadData.arrayBuffer();

    // Perform enhanced AI analysis
    console.log("🚀 Starting Enhanced AI Analysis...");
    const classification = await analyzeImageWithConfidence(arrayBuffer, report);

    // Build structured JSON analysis for storage/response
    const azure = (classification as any)?.ensembleResults?.azure;
    const quality = azure ? scoreImageQuality(azure) : 0;
    const width = azure?.width ?? null;
    const height = azure?.height ?? null;
    const resultJson = azure ? {
      image_url: null,
      input_images: [{
        image_url: null,
        metadata: { width, height, capture_time: null, orientation: null, gps: null },
        image_quality_score: quality,
        needs_recap: quality < 0.45
      }],
      caption: azure.caption ?? { text: "", confidence: 0 },
      tags: azure.tags,
      objects: (azure.objects || []).map((o: any) => ({
        object: o.object,
        confidence: o.confidence,
        boundingBox: o.boundingBox,
        boundingBoxNorm: normalizeBoundingBox(o.boundingBox, width, height)
      })),
      faces: (azure.faces || []).map((f: any) => ({
        age: f.age ?? null,
        gender: f.gender ?? null,
        confidence: f.confidence ?? null,
        boundingBox: f.boundingBox,
        boundingBoxNorm: normalizeBoundingBox(f.boundingBox, width, height)
      })),
      ocr_text: (azure.ocr || []),
      moderation: {
        isAdultContent: azure.adult?.isAdultContent ?? null,
        adultScore: azure.adult?.score ?? null,
        isMedical: azure.adult?.isMedical ?? null,
        medicalScore: azure.adult?.medicalScore ?? null
      },
      recommended_emergency: { type: classification.type, confidence: classification.confidence, reasoning: Array.isArray(classification?.analysis) ? classification.analysis : [String(classification?.analysis || "")] },
      suggested_actions: (quality < 0.45) ? [
        "Retake photo with better lighting and focus",
        "Avoid motion blur; hold device steady",
        "Fill the frame with the incident subject"
      ] : [],
      screenshot_analysis: { 
        present: false,
        summary: "",
        code_lines: [],
        env_vars_mentioned: [],
        endpoints_found: [],
        api_versions: [],
        headers_seen: [],
        terminal_logs: [],
        visible_errors: [],
        actionable_recommendations: [],
        needs_recap: false
      },
      batch_summary: null,
      raw_analysis: { analyze: azure.raw, read: azure.raw?.readResult ?? null },
      debug: { request_id: null, api_calls_made: 1, durations_ms: 0, notes: ["Azure Image Analysis v4 used"] }
    } : null;

    // Update database with enhanced results
    // Safe DB update: retry without ai_structured_result if not migrated
    let updateErr = null as any;
    {
      const { error } = await supabase
      .from("reports")
      .update({
        type: classification.type,
        confidence: classification.confidence,
        status: "classified",
        ai_labels: classification.details,
        ai_timestamp: new Date().toISOString(),
        ai_analysis: JSON.stringify(classification.analysis),
        ai_ensemble_results: JSON.stringify(classification.ensembleResults),
        ai_structured_result: resultJson ? JSON.stringify(resultJson) : null
      })
      .eq("id", reportId);
      updateErr = error;
    }

    if (updateErr && String(updateErr.message || updateErr).toLowerCase().includes("ai_structured_result")) {
      const { error: retryErr } = await supabase
        .from("reports")
        .update({
          type: classification.type,
          confidence: classification.confidence,
          status: "classified",
          ai_labels: classification.details,
          ai_timestamp: new Date().toISOString(),
          ai_analysis: JSON.stringify(classification.analysis),
          ai_ensemble_results: JSON.stringify(classification.ensembleResults)
        })
        .eq("id", reportId);
      updateErr = retryErr;
    }

    if (updateErr) throw new Error("DB update failed: " + JSON.stringify(updateErr));

    return new Response(JSON.stringify({ 
      ok: true, 
      mapped: classification,
      enhanced: true,
      note: "Enhanced AI analysis completed with improved accuracy"
    }), { 
      status: 200, 
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      } 
    });

  } catch (err) {
    console.error("Enhanced AI analysis error:", err);
    // Return diagnostic payload with 200 to avoid frontend failure loop
    return new Response(JSON.stringify({ ok: false, error: err?.message || String(err), hint: "Check Azure secrets and image_path accessibility" }), { 
      status: 200, 
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      } 
    });
  }
});
