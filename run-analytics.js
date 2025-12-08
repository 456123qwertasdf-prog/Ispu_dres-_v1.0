// Quick script to run classification analytics
// Run with: node run-analytics.js

const SUPABASE_URL = 'https://hmolyqzbvxxliemclrld.supabase.co'
const SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI0Njk3MCwiZXhwIjoyMDc1ODIyOTcwfQ.496txRbAGuiOov76vxdwSDUHplBt1osOD2PyV0EE958'

async function runAnalytics() {
  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/analyze-classifications`, {
      method: 'GET',
      headers: {
        'apikey': SERVICE_KEY,
        'Authorization': `Bearer ${SERVICE_KEY}`,
        'Content-Type': 'application/json'
      }
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`HTTP ${response.status}: ${errorText}`)
    }

    const data = await response.json()
    
    console.log('\n' + '='.repeat(80))
    console.log('📊 CLASSIFICATION ANALYTICS RESULTS')
    console.log('='.repeat(80))
    
    console.log('\n📈 SUMMARY:')
    console.log(`  Total Classifications: ${data.summary.totalClassifications}`)
    if (data.summary.totalReportsInDB !== undefined) {
      console.log(`  Total Reports in DB: ${data.summary.totalReportsInDB}`)
    }
    console.log(`  Low Confidence Cases: ${data.summary.lowConfidenceCount}`)
    console.log(`  Potential Misclassifications: ${data.summary.potentialMisclassificationsCount}`)
    console.log(`  Types Analyzed: ${data.summary.typesAnalyzed}`)
    
    if (data.summary.recentReports && data.summary.recentReports.length > 0) {
      console.log('\n📋 RECENT REPORTS:')
      data.summary.recentReports.forEach((report, i) => {
        console.log(`\n  ${i + 1}. Report ID: ${report.id}`)
        console.log(`     Type: ${report.type.toUpperCase()}`)
        console.log(`     Confidence: ${(parseFloat(report.confidence) * 100).toFixed(1)}%`)
        console.log(`     Date: ${new Date(report.createdAt).toLocaleString()}`)
        console.log(`     Has Image: ${report.hasImage ? 'Yes' : 'No'}`)
        if (report.description) {
          console.log(`     Description: ${report.description}`)
        }
      })
    }
    
    console.log('\n📊 CONFIDENCE DISTRIBUTION:')
    const dist = data.analysis.confidenceDistribution
    console.log(`  Very Low (< 50%): ${dist.veryLow}`)
    console.log(`  Low (50-60%): ${dist.low}`)
    console.log(`  Medium (60-80%): ${dist.medium}`)
    console.log(`  High (80-90%): ${dist.high}`)
    console.log(`  Very High (> 90%): ${dist.veryHigh}`)
    
    console.log('\n📋 PERFORMANCE BY TYPE:')
    Object.entries(data.analysis.byType)
      .sort((a, b) => b[1].count - a[1].count)
      .forEach(([type, stats]) => {
        console.log(`\n  ${type.toUpperCase()}:`)
        console.log(`    Count: ${stats.count}`)
        console.log(`    Avg Confidence: ${(stats.avgConfidence * 100).toFixed(1)}%`)
        console.log(`    Low Confidence: ${stats.lowConfidence}`)
        console.log(`    High Confidence: ${stats.highConfidence}`)
      })
    
    if (data.analysis.potentialMisclassifications.length > 0) {
      console.log('\n⚠️  POTENTIAL MISCLASSIFICATIONS:')
      data.analysis.potentialMisclassifications.slice(0, 10).forEach((mis, i) => {
        console.log(`\n  ${i + 1}. Report ID: ${mis.id}`)
        console.log(`     Classified as: ${mis.classifiedAs.toUpperCase()} (${(parseFloat(mis.confidence) * 100).toFixed(1)}%)`)
        console.log(`     Suggested: ${mis.suggestedType.toUpperCase()}`)
        console.log(`     Reason: ${mis.reason}`)
        if (mis.description) {
          console.log(`     Description: ${mis.description.substring(0, 100)}...`)
        }
      })
      if (data.analysis.potentialMisclassifications.length > 10) {
        console.log(`\n  ... and ${data.analysis.potentialMisclassifications.length - 10} more`)
      }
    }
    
    if (data.analysis.lowConfidenceCases.length > 0) {
      console.log('\n📉 LOW CONFIDENCE CASES (< 60%):')
      data.analysis.lowConfidenceCases.slice(0, 10).forEach((case_, i) => {
        console.log(`\n  ${i + 1}. Report ID: ${case_.id}`)
        console.log(`     Type: ${case_.type.toUpperCase()}`)
        console.log(`     Confidence: ${(parseFloat(case_.confidence) * 100).toFixed(1)}%`)
        console.log(`     Date: ${new Date(case_.createdAt).toLocaleString()}`)
      })
      if (data.analysis.lowConfidenceCases.length > 10) {
        console.log(`\n  ... and ${data.analysis.lowConfidenceCases.length - 10} more`)
      }
    }
    
    console.log('\n' + '='.repeat(80))
    console.log('✅ Analytics complete!')
    console.log('='.repeat(80) + '\n')
    
    // Save full results to file
    const fs = require('fs')
    fs.writeFileSync('analytics-results.json', JSON.stringify(data, null, 2))
    console.log('📁 Full results saved to: analytics-results.json\n')
    
  } catch (error) {
    console.error('❌ Error running analytics:', error.message)
    process.exit(1)
  }
}

runAnalytics()

