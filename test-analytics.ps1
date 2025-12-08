# Test Classification Analytics Function
$headers = @{
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyNDY5NzAsImV4cCI6MjA3NTgyMjk3MH0.G2AOT-8zZ5sk8qGQUBifFqq5ww2W7Hxvtux0tlQ0Q-4"
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyNDY5NzAsImV4cCI6MjA3NTgyMjk3MH0.G2AOT-8zZ5sk8qGQUBifFqq5ww2W7Hxvtux0tlQ0Q-4"
    "Content-Type" = "application/json"
}

try {
    Write-Host "📊 Calling analyze-classifications function..." -ForegroundColor Cyan
    $response = Invoke-WebRequest -Uri "https://hmolyqzbvxxliemclrld.supabase.co/functions/v1/analyze-classifications" -Method GET -Headers $headers
    
    $data = $response.Content | ConvertFrom-Json
    
    Write-Host "`n✅ Analysis Complete!" -ForegroundColor Green
    Write-Host "`n📈 Summary:" -ForegroundColor Yellow
    Write-Host "  Total Classifications: $($data.summary.totalClassifications)"
    Write-Host "  Low Confidence Cases: $($data.summary.lowConfidenceCount)"
    Write-Host "  Potential Misclassifications: $($data.summary.potentialMisclassificationsCount)"
    
    Write-Host "`n📊 Performance by Type:" -ForegroundColor Yellow
    $data.analysis.byType.PSObject.Properties | ForEach-Object {
        $type = $_.Name
        $stats = $_.Value
        Write-Host "  $type : $($stats.count) cases, Avg: $([math]::Round($stats.avgConfidence * 100, 1))%, Low: $($stats.lowConfidence), High: $($stats.highConfidence)"
    }
    
    if ($data.analysis.potentialMisclassifications.Count -gt 0) {
        Write-Host "`n⚠️ Potential Misclassifications:" -ForegroundColor Red
        $data.analysis.potentialMisclassifications | ForEach-Object {
            Write-Host "  - ID: $($_.id.Substring(0,8))... | Classified: $($_.classifiedAs) → Should be: $($_.suggestedType) | Reason: $($_.reason)"
        }
    }
    
    Write-Host "`n💾 Saving full report to classification-analysis-report.json..." -ForegroundColor Cyan
    $data | ConvertTo-Json -Depth 10 | Out-File -FilePath "classification-analysis-report.json" -Encoding UTF8
    Write-Host "✅ Report saved!" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception
}

