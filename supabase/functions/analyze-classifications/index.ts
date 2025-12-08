import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    })
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    
    if (!SUPABASE_URL || !SERVICE_KEY) {
      return new Response(
        JSON.stringify({ error: 'Missing Supabase credentials' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { persistSession: false },
    })

    // Get all classifications with their details
    const { data: reports, error } = await supabase
      .from('reports')
      .select('id, type, confidence, created_at, ai_labels, ai_analysis, ai_description, image_path')
      .not('type', 'is', null)
      .order('created_at', { ascending: false })
      .limit(1000)
    
    // Also get total count without limit
    const { count: totalCount } = await supabase
      .from('reports')
      .select('*', { count: 'exact', head: true })
      .not('type', 'is', null)

    if (error) {
      throw error
    }

    // Analyze classification performance
    const analysis = {
      total: reports?.length || 0,
      byType: {} as Record<string, { count: number; avgConfidence: number; lowConfidence: number; highConfidence: number }>,
      lowConfidenceCases: [] as any[],
      potentialMisclassifications: [] as any[],
      confidenceDistribution: {
        veryLow: 0,   // < 0.5
        low: 0,       // 0.5 - 0.6
        medium: 0,    // 0.6 - 0.8
        high: 0,      // 0.8 - 0.9
        veryHigh: 0   // > 0.9
      }
    }

    // Process each report
    reports?.forEach((report: any) => {
      const type = report.type || 'other'
      const confidence = report.confidence || 0

      // Initialize type stats if needed
      if (!analysis.byType[type]) {
        analysis.byType[type] = {
          count: 0,
          avgConfidence: 0,
          lowConfidence: 0,
          highConfidence: 0
        }
      }

      analysis.byType[type].count++
      analysis.byType[type].avgConfidence += confidence
      
      if (confidence < 0.6) {
        analysis.byType[type].lowConfidence++
        analysis.lowConfidenceCases.push({
          id: report.id,
          type,
          confidence: confidence.toFixed(2),
          createdAt: report.created_at,
          description: report.ai_description
        })
      }
      
      if (confidence >= 0.8) {
        analysis.byType[type].highConfidence++
      }

      // Confidence distribution
      if (confidence < 0.5) analysis.confidenceDistribution.veryLow++
      else if (confidence < 0.6) analysis.confidenceDistribution.low++
      else if (confidence < 0.8) analysis.confidenceDistribution.medium++
      else if (confidence < 0.9) analysis.confidenceDistribution.high++
      else analysis.confidenceDistribution.veryHigh++

      // Potential misclassifications - check for keywords that suggest different type
      const desc = String(report.ai_description || '').toLowerCase()
      const labels = Array.isArray(report.ai_labels) ? report.ai_labels.map((l: any) => String(l).toLowerCase()).join(' ') : ''
      const allText = `${desc} ${labels}`.toLowerCase()

      // Check for medical keywords in non-medical classifications
      if (type !== 'medical' && /(injury|injured|bruise|bruised|swollen|wound|hurt|pain|crutch|bandage|cast|brace|knee|ankle)/.test(allText)) {
        analysis.potentialMisclassifications.push({
          id: report.id,
          classifiedAs: type,
          suggestedType: 'medical',
          confidence: confidence.toFixed(2),
          reason: 'Contains medical injury keywords',
          description: report.ai_description
        })
      }

      // Check for accident keywords in medical classifications (sports injuries)
      if (type === 'accident' && /(sports|sport|athletic|field|stadium|gym|playing|game|match|practice|training)/.test(allText) && 
          !/(car|vehicle|truck|motorcycle|bus|road|street|highway|traffic)/.test(allText)) {
        analysis.potentialMisclassifications.push({
          id: report.id,
          classifiedAs: type,
          suggestedType: 'medical',
          confidence: confidence.toFixed(2),
          reason: 'Sports context without vehicle - likely sports injury, not traffic accident',
          description: report.ai_description
        })
      }
    })

    // Calculate averages
    Object.keys(analysis.byType).forEach(type => {
      if (analysis.byType[type].count > 0) {
        analysis.byType[type].avgConfidence = analysis.byType[type].avgConfidence / analysis.byType[type].count
      }
    })

    // Get recent reports for context
    const recentReports = reports?.slice(0, 20).map((r: any) => ({
      id: r.id,
      type: r.type,
      confidence: (r.confidence || 0).toFixed(2),
      createdAt: r.created_at,
      hasImage: !!r.image_path,
      description: r.ai_description ? String(r.ai_description).substring(0, 150) : null
    })) || []

    return new Response(
      JSON.stringify({
        success: true,
        analysis,
        summary: {
          totalClassifications: analysis.total,
          totalReportsInDB: totalCount || 0,
          lowConfidenceCount: analysis.lowConfidenceCases.length,
          potentialMisclassificationsCount: analysis.potentialMisclassifications.length,
          typesAnalyzed: Object.keys(analysis.byType).length,
          recentReports: recentReports
        }
      }, null, 2),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('Error analyzing classifications:', error)
    return new Response(
      JSON.stringify({ error: 'Failed to analyze classifications', details: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

