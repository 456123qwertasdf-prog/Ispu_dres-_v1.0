/**
 * Philippines Emergency AI - Specialized for Local Emergency Patterns
 * 
 * This file demonstrates how the AI was customized for Philippine
 * emergency scenarios and local patterns.
 */

class PhilippinesEmergencyAI {
  constructor() {
    this.localPatterns = {
      flood: {
        keywords: [
          'baha', 'tubig', 'ulan', 'bagyo', 'flood', 'water', 'inundation',
          'drowning', 'tsunami', 'storm', 'rain', 'overflow', 'flooding',
          'flooded', 'waterlogged', 'submerged', 'wading', 'floodwaters',
          'inundated', 'water level', 'flood damage', 'flood emergency',
          'water emergency', 'flooding emergency', 'street', 'road',
          'vehicle', 'car', 'truck', 'people', 'person', 'wading', 'walking'
        ],
        confidence: 0.88,
        priority: 3
      },
      accident: {
        keywords: [
          'aksidente', 'banggaan', 'sasakyan', 'kotse', 'truck', 'motor',
          'car', 'vehicle', 'crash', 'collision', 'accident', 'traffic',
          'road', 'automobile', 'motorcycle', 'truck', 'crash', 'collision',
          'impact', 'wreck', 'damage', 'injury', 'emergency vehicle',
          'police', 'ambulance', 'traffic accident', 'road accident',
          'broken', 'damaged', 'crashed', 'overturned', 'collission', 'apopong'
        ],
        confidence: 0.95,
        priority: 4
      },
      fire: {
        keywords: [
          'sunog', 'usok', 'apoy', 'fire', 'smoke', 'flame', 'burn',
          'blaze', 'inferno', 'combustion', 'arson', 'smoke', 'flames',
          'burning', 'hot', 'burn', 'ash'
        ],
        confidence: 0.90,
        priority: 1
      },
      medical: {
        keywords: [
          'sugat', 'sakit', 'ambulansya', 'doktor', 'nars', 'hospital',
          'injury', 'ambulance', 'blood', 'wound', 'medical', 'hospital',
          'emergency', 'paramedic', 'stretcher', 'person', 'people',
          'injured', 'patient', 'doctor', 'nurse'
        ],
        confidence: 0.87,
        priority: 2
      }
    };
  }

  /**
   * Analyze emergency with Philippine context
   * This shows how local patterns were integrated
   */
  async analyzePhilippineEmergency(imageBuffer, imagePath, reportData = {}) {
    const fileName = imagePath.toLowerCase();
    const message = (reportData.message || '').toLowerCase();
    const location = (reportData.location || '').toLowerCase();
    
    // Combine all text sources
    const allText = `${fileName} ${message} ${location}`.toLowerCase();
    
    console.log("🇵🇭 Philippines Emergency AI Analysis:", allText);
    
    // Enhanced scoring with Philippine context
    let bestMatch = { type: "other", confidence: 0.5, priority: 999, details: [] };
    
    for (const [type, pattern] of Object.entries(this.localPatterns)) {
      const matchCount = pattern.keywords.filter(keyword => allText.includes(keyword)).length;
      const confidence = Math.min(pattern.confidence + (matchCount * 0.05), 1.0);
      
      if (matchCount > 0 && pattern.priority < bestMatch.priority) {
        bestMatch = {
          type: type,
          confidence: confidence,
          priority: pattern.priority,
          details: pattern.keywords.filter(keyword => allText.includes(keyword))
        };
      }
    }
    
    // Special Philippine flood vs accident logic
    if (bestMatch.type === "flood" || bestMatch.type === "accident") {
      const waterIndicators = ["baha", "tubig", "water", "flood", "flooding", "flooded", "submerged", "wading", "rain"];
      const accidentIndicators = ["banggaan", "crash", "collision", "impact", "wreck", "damage", "broken", "overturned"];
      
      const waterCount = waterIndicators.filter(term => allText.includes(term)).length;
      const accidentCount = accidentIndicators.filter(term => allText.includes(term)).length;
      
      if (waterCount > accidentCount && waterCount > 0) {
        bestMatch = {
          type: "flood",
          confidence: Math.min(bestMatch.confidence + 0.1, 1.0),
          priority: 3,
          details: [...bestMatch.details, ...waterIndicators.filter(term => allText.includes(term))]
        };
      } else if (accidentCount > waterCount && accidentCount > 0) {
        bestMatch = {
          type: "accident",
          confidence: Math.min(bestMatch.confidence + 0.1, 1.0),
          priority: 4,
          details: [...bestMatch.details, ...accidentIndicators.filter(term => allText.includes(term))]
        };
      }
    }
    
    return {
      type: bestMatch.type,
      confidence: bestMatch.confidence,
      details: bestMatch.details,
      description: this.generatePhilippineDescription(bestMatch.type),
      analysis: `Philippines Emergency AI: ${bestMatch.type} detected with ${bestMatch.confidence.toFixed(2)} confidence`,
      localContext: {
        keywords: bestMatch.details,
        priority: bestMatch.priority,
        region: "Philippines"
      }
    };
  }

  generatePhilippineDescription(type) {
    const descriptions = {
      flood: [
        "Baha emergency detected",
        "Flooding situation in Philippines",
        "Water emergency requiring immediate response",
        "Flood damage assessment needed"
      ],
      accident: [
        "Traffic accident in Philippines",
        "Vehicle collision requiring emergency response",
        "Road accident with potential injuries",
        "Traffic incident needs immediate attention"
      ],
      fire: [
        "Fire emergency in Philippines",
        "Sunog situation requiring fire department",
        "Fire hazard needs immediate response",
        "Emergency fire situation"
      ],
      medical: [
        "Medical emergency in Philippines",
        "Health emergency requiring ambulance",
        "Medical situation needs immediate response",
        "Emergency medical assistance required"
      ],
      other: [
        "General emergency in Philippines",
        "Emergency situation requiring assessment",
        "Urgent situation needs attention",
        "Emergency response required"
      ]
    };
    
    return descriptions[type] || descriptions.other;
  }

  /**
   * Get Philippine emergency response priorities
   * This shows how local emergency priorities were implemented
   */
  getEmergencyPriority(type) {
    const priorities = {
      fire: 1,      // Highest priority
      medical: 2,   // Second priority
      flood: 3,     // Third priority
      accident: 4,  // Fourth priority
      other: 5      // Lowest priority
    };
    
    return priorities[type] || 5;
  }
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
  module.exports = PhilippinesEmergencyAI;
}

// Example usage
if (typeof window !== 'undefined') {
  window.PhilippinesEmergencyAI = PhilippinesEmergencyAI;
}
