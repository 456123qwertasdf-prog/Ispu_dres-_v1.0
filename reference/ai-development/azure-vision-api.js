/**
 * Azure Computer Vision API Integration
 * 
 * This file shows how Azure Computer Vision was integrated
 * as the primary AI analysis method in the Edge Function.
 */

class AzureVisionAPI {
  constructor() {
    // Set via environment: AZURE_VISION_KEY, AZURE_VISION_ENDPOINT
    this.apiKey = typeof process !== "undefined" && process.env?.AZURE_VISION_KEY || "YOUR_AZURE_VISION_KEY";
    this.endpoint = typeof process !== "undefined" && process.env?.AZURE_VISION_ENDPOINT || "https://YOUR_REGION.cognitiveservices.azure.com";
  }

  /**
   * Analyze image with Azure Computer Vision
   * This is the primary AI method used in production
   */
  async analyzeWithAzureVision(imageBuffer) {
    try {
      console.log("🔍 Azure Computer Vision Analysis (Primary)");
      
      const response = await fetch(`${this.endpoint}/vision/v3.2/analyze?visualFeatures=Categories,Tags,Description,Objects&details=Landmarks&language=en&model-version=latest`, {
        method: "POST",
        headers: {
          "Ocp-Apim-Subscription-Key": this.apiKey,
          "Content-Type": "application/octet-stream"
        },
        body: imageBuffer
      });

      if (!response.ok) {
        throw new Error(`Azure Vision API error: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      console.log("✅ Azure Vision analysis successful");
      
      return {
        success: true,
        categories: result.categories?.map((c) => c.name) || [],
        tags: result.tags?.map((t) => t.name) || [],
        description: result.description?.captions?.[0]?.text || "",
        objects: result.objects?.map((o) => o.object) || [],
        rawResult: result
      };
    } catch (error) {
      console.log("❌ Azure Vision analysis failed:", error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Map Azure Computer Vision results to emergency types
   * This shows the logic for converting AI results to emergency classifications
   */
  mapAzureVisionToEmergency(azureResult) {
    const { categories, tags, description, objects } = azureResult;
    
    // Combine all text for analysis
    const allText = [
      ...categories,
      ...tags,
      description,
      ...objects
    ].join(' ').toLowerCase();
    
    console.log("🔍 Azure Vision text analysis:", allText);
    
    // Emergency type scoring
    const scores = {
      flood: 0,
      accident: 0,
      fire: 0,
      medical: 0,
      other: 0
    };
    
    // Flood detection
    const floodKeywords = ['water', 'flood', 'rain', 'river', 'wet', 'rainy', 'outdoor'];
    const floodScore = floodKeywords.filter(keyword => allText.includes(keyword)).length;
    scores.flood = floodScore * 0.3;
    
    // Accident detection
    const accidentKeywords = ['car', 'vehicle', 'truck', 'traffic', 'road', 'street', 'accident', 'collision', 'crash'];
    const accidentScore = accidentKeywords.filter(keyword => allText.includes(keyword)).length;
    scores.accident = accidentScore * 0.25;
    
    // Fire detection
    const fireKeywords = ['fire', 'smoke', 'flame', 'burn', 'hot'];
    const fireScore = fireKeywords.filter(keyword => allText.includes(keyword)).length;
    scores.fire = fireScore * 0.4;
    
    // Medical detection
    const medicalKeywords = ['person', 'people', 'group', 'medical', 'health', 'injury'];
    const medicalScore = medicalKeywords.filter(keyword => allText.includes(keyword)).length;
    scores.medical = medicalScore * 0.2;
    
    // Special cases
    if (description.includes('accident') || description.includes('collision')) {
      scores.accident += 0.5;
    }
    
    if (description.includes('flood') || description.includes('water')) {
      scores.flood += 0.5;
    }
    
    if (description.includes('fire') || description.includes('smoke')) {
      scores.fire += 0.5;
    }
    
    // Find the highest scoring type
    const maxScore = Math.max(...Object.values(scores));
    const predictedType = Object.keys(scores).find(key => scores[key] === maxScore);
    
    // Generate confidence based on score
    const confidence = Math.min(maxScore + 0.3, 1.0);
    
    // Generate details
    const details = this.generateEmergencyDetails(predictedType);
    
    return {
      type: predictedType || 'other',
      confidence: confidence,
      details: details,
      analysis: `Azure Computer Vision analysis: ${predictedType} detected with ${confidence.toFixed(2)} confidence`,
      azureVision: {
        categories: categories,
        tags: tags,
        description: description,
        objects: objects
      }
    };
  }

  generateEmergencyDetails(type) {
    const details = {
      flood: [
        "Water detected in image",
        "Flooding conditions identified",
        "Emergency water situation",
        "Potential flood damage"
      ],
      accident: [
        "Vehicle collision detected",
        "Traffic accident identified",
        "Road incident confirmed",
        "Vehicle damage observed"
      ],
      fire: [
        "Fire or smoke detected",
        "Emergency fire situation",
        "Potential fire hazard",
        "Smoke conditions identified"
      ],
      medical: [
        "People detected in image",
        "Potential medical emergency",
        "Human presence identified",
        "Emergency medical situation"
      ],
      other: [
        "General emergency situation",
        "Unspecified emergency type",
        "Emergency conditions detected",
        "Requires further assessment"
      ]
    };
    
    return details[type] || details.other;
  }
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
  module.exports = AzureVisionAPI;
}

// Example usage
if (typeof window !== 'undefined') {
  window.AzureVisionAPI = AzureVisionAPI;
}
