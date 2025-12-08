/**
 * Process AI Reports Script
 * 
 * This script shows how AI analysis was batch processed
 * for existing reports during development.
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const supabaseUrl = 'https://hmolyqzbvxxliemclrld.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI0Njk3MCwiZXhwIjoyMDc1ODIyOTcwfQ.496txRbAGuiOov76vxdwSDUHplBt1osOD2PyV0EE958';

const supabase = createClient(supabaseUrl, supabaseKey);

/**
 * AI Classification Logic
 * This shows the AI logic that was used for batch processing
 */
class AIProcessor {
  constructor() {
    this.emergencyTypes = [
      {
        type: "fire",
        keywords: ["fire", "smoke", "flame", "burn", "blaze", "inferno", "combustion", "arson"],
        priority: 1,
        confidence: 0.9
      },
      {
        type: "medical",
        keywords: ["injury", "ambulance", "blood", "wound", "medical", "hospital", "emergency", "paramedic"],
        priority: 2,
        confidence: 0.85
      },
      {
        type: "flood",
        keywords: [
          "flood", "water", "inundation", "drowning", "tsunami", "storm", "rain", "overflow",
          "flooding", "flooded", "waterlogged", "submerged", "wading", "floodwaters"
        ],
        priority: 3,
        confidence: 0.88
      },
      {
        type: "accident",
        keywords: [
          "car", "vehicle", "crash", "collision", "accident", "traffic", "road", "automobile",
          "motorcycle", "truck", "crash", "collision", "impact", "wreck", "damage"
        ],
        priority: 4,
        confidence: 0.82
      }
    ];
  }

  /**
   * Analyze report and classify emergency type
   * This shows how reports were analyzed during batch processing
   */
  async analyzeReport(report) {
    const imagePath = report.image_path || '';
    const message = report.message || '';
    const location = report.location || '';
    
    // Combine all text for analysis
    const allText = `${imagePath} ${message} ${location}`.toLowerCase();
    
    console.log(`🔍 Analyzing report ${report.id}: ${allText.substring(0, 100)}...`);
    
    // Find best match
    let bestMatch = { type: "other", confidence: 0.5, priority: 999 };
    
    for (const emergency of this.emergencyTypes) {
      const matchCount = emergency.keywords.filter(keyword => allText.includes(keyword)).length;
      const confidence = Math.min(emergency.confidence + (matchCount * 0.05), 1.0);
      
      if (matchCount > 0 && emergency.priority < bestMatch.priority) {
        bestMatch = {
          type: emergency.type,
          confidence: confidence,
          priority: emergency.priority
        };
      }
    }
    
    // Special flood vs accident logic
    if (bestMatch.type === "flood" || bestMatch.type === "accident") {
      const waterIndicators = ["water", "flood", "flooding", "flooded", "submerged", "wading"];
      const accidentIndicators = ["crash", "collision", "impact", "wreck", "damage", "broken"];
      
      const waterCount = waterIndicators.filter(term => allText.includes(term)).length;
      const accidentCount = accidentIndicators.filter(term => allText.includes(term)).length;
      
      if (waterCount > accidentCount && waterCount > 0) {
        bestMatch = {
          type: "flood",
          confidence: Math.min(bestMatch.confidence + 0.1, 1.0),
          priority: 3
        };
      } else if (accidentCount > waterCount && accidentCount > 0) {
        bestMatch = {
          type: "accident",
          confidence: Math.min(bestMatch.confidence + 0.1, 1.0),
          priority: 4
        };
      }
    }
    
    return {
      type: bestMatch.type,
      confidence: bestMatch.confidence,
      details: this.generateDetails(bestMatch.type),
      analysis: `AI analysis: ${bestMatch.type} detected with ${bestMatch.confidence.toFixed(2)} confidence`
    };
  }

  generateDetails(type) {
    const detailsMap = {
      flood: ["flood emergency", "water damage", "flooding", "water emergency"],
      accident: ["vehicle collision", "car accident", "traffic incident", "road accident"],
      fire: ["fire emergency", "fire", "emergency", "fire hazard"],
      medical: ["medical emergency", "injury", "emergency", "medical response"],
      other: ["emergency situation", "general emergency", "emergency response"]
    };
    
    return detailsMap[type] || detailsMap.other;
  }
}

/**
 * Get reports that need AI processing
 * This shows how reports were queried for batch processing
 */
async function getReportsForProcessing() {
  try {
    const { data: reports, error } = await supabase
      .from('reports')
      .select('*')
      .or('type.is.null,type.eq.other,confidence.is.null')
      .order('created_at', { ascending: false });
    
    if (error) {
      throw error;
    }
    
    console.log(`📊 Found ${reports.length} reports for AI processing`);
    return reports || [];
  } catch (error) {
    console.error('❌ Error fetching reports:', error.message);
    return [];
  }
}

/**
 * Update report with AI analysis
 * This shows how reports were updated with AI results
 */
async function updateReportWithAI(reportId, aiResult) {
  try {
    const { error } = await supabase
      .from('reports')
      .update({
        type: aiResult.type,
        confidence: aiResult.confidence,
        ai_labels: aiResult.details,
        ai_analysis: aiResult.analysis,
        ai_timestamp: new Date().toISOString(),
        status: 'classified'
      })
      .eq('id', reportId);
    
    if (error) {
      throw error;
    }
    
    console.log(`✅ Updated report ${reportId} with AI analysis: ${aiResult.type}`);
    return true;
  } catch (error) {
    console.error(`❌ Error updating report ${reportId}:`, error.message);
    return false;
  }
}

/**
 * Process all reports with AI
 * This shows the main batch processing logic
 */
async function processAllReports() {
  console.log('🤖 Starting AI batch processing...');
  
  const processor = new AIProcessor();
  const reports = await getReportsForProcessing();
  
  let processed = 0;
  let errors = 0;
  
  for (const report of reports) {
    try {
      console.log(`\n🔍 Processing report ${report.id}...`);
      
      // Analyze report
      const aiResult = await processor.analyzeReport(report);
      
      // Update report
      const success = await updateReportWithAI(report.id, aiResult);
      
      if (success) {
        processed++;
      } else {
        errors++;
      }
      
      // Small delay to avoid overwhelming the system
      await new Promise(resolve => setTimeout(resolve, 100));
      
    } catch (error) {
      console.error(`❌ Error processing report ${report.id}:`, error.message);
      errors++;
    }
  }
  
  console.log(`\n📊 Batch processing completed:`);
  console.log(`  ✅ Processed: ${processed}`);
  console.log(`  ❌ Errors: ${errors}`);
  console.log(`  📈 Total: ${reports.length}`);
}

/**
 * Main execution
 */
async function main() {
  try {
    console.log('🤖 LSPU Emergency Response System - AI Batch Processing');
    console.log('======================================================\n');
    
    await processAllReports();
    
    console.log('\n🎉 AI batch processing completed!');
    
  } catch (error) {
    console.error('❌ Batch processing failed:', error.message);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = {
  AIProcessor,
  getReportsForProcessing,
  updateReportWithAI,
  processAllReports
};
