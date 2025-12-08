import { createClient } from "@supabase/supabase-js";
// deno-types-ignore
declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

interface AdaptiveRule {
  id: string;
  rule_name: string;
  rule_type: 'keyword_boost' | 'pattern_rule' | 'threshold' | 'penalty';
  config_data: any;
  confidence_boost: number;
  is_active: boolean;
}

/**
 * Load active adaptive rules from database
 */
export async function loadAdaptiveRules(): Promise<AdaptiveRule[]> {
  try {
    const { data: rules, error } = await supabase
      .from("adaptive_classifier_config")
      .select("*")
      .eq("is_active", true)
      .order("learned_from_corrections", { ascending: false });

    if (error) {
      console.error("Error loading adaptive rules:", error);
      return [];
    }

    return rules || [];
  } catch (error) {
    console.error("Error loading adaptive rules:", error);
    return [];
  }
}

/**
 * Apply adaptive rules to classification scores
 */
export function applyAdaptiveRules(
  scores: Record<string, number>,
  originalType: string,
  aiFeatures: any,
  rules: AdaptiveRule[]
): Record<string, number> {
  const updatedScores = { ...scores };

  for (const rule of rules) {
    if (rule.rule_type === 'keyword_boost') {
      const config = rule.config_data || {};
      
      // Check if this rule applies to current classification
      if (config.originalType === originalType && config.correctedType) {
        // Check if features match
        const features = extractFeatures(aiFeatures);
        const hasMatchingFeatures = config.features && config.features.some((feat: string) =>
          features.some((f: string) => f.toLowerCase().includes(feat.toLowerCase()))
        );

        if (hasMatchingFeatures || !config.features) {
          // Apply boost to corrected type
          const boost = rule.confidence_boost || config.boost || 0.2;
          updatedScores[config.correctedType] = (updatedScores[config.correctedType] || 0) + boost;
          
          // Optionally reduce score of original type
          if (config.originalType !== config.correctedType) {
            updatedScores[config.originalType] = Math.max(0, (updatedScores[config.originalType] || 0) - (boost * 0.5));
          }
        }
      }
    } else if (rule.rule_type === 'pattern_rule') {
      const config = rule.config_data || {};
      
      // Pattern-based rules (e.g., sports field + injury = medical)
      if (matchesPattern(aiFeatures, config)) {
        const boost = rule.confidence_boost || 0.2;
        if (config.boostType) {
          updatedScores[config.boostType] = (updatedScores[config.boostType] || 0) + boost;
        }
      }
    }
  }

  return updatedScores;
}

/**
 * Extract features from AI analysis
 */
function extractFeatures(aiFeatures: any): string[] {
  const features: string[] = [];

  if (!aiFeatures) return features;

  // Extract tags
  if (aiFeatures.tags && Array.isArray(aiFeatures.tags)) {
    aiFeatures.tags.forEach((tag: any) => {
      const tagName = typeof tag === 'string' ? tag : tag.name || tag.label || '';
      if (tagName) features.push(tagName.toLowerCase());
    });
  }

  // Extract objects
  if (aiFeatures.objects && Array.isArray(aiFeatures.objects)) {
    aiFeatures.objects.forEach((obj: any) => {
      const objName = typeof obj === 'string' ? obj : obj.object || obj.name || '';
      if (objName) features.push(objName.toLowerCase());
    });
  }

  // Extract from caption
  if (aiFeatures.description || aiFeatures.caption) {
    const text = (aiFeatures.description || aiFeatures.caption || '').toLowerCase();
    features.push(...text.split(/\s+/));
  }

  return features;
}

/**
 * Check if AI features match a pattern
 */
function matchesPattern(aiFeatures: any, pattern: any): boolean {
  const features = extractFeatures(aiFeatures);
  const allText = features.join(' ');

  // Check required keywords
  if (pattern.requiredKeywords) {
    const hasAll = pattern.requiredKeywords.every((keyword: string) =>
      allText.includes(keyword.toLowerCase())
    );
    if (!hasAll) return false;
  }

  // Check excluded keywords
  if (pattern.excludedKeywords) {
    const hasExcluded = pattern.excludedKeywords.some((keyword: string) =>
      allText.includes(keyword.toLowerCase())
    );
    if (hasExcluded) return false;
  }

  // Check context patterns (e.g., sports field + injury)
  if (pattern.contextPatterns) {
    const matchesContext = pattern.contextPatterns.every((patternStr: string) => {
      const regex = new RegExp(patternStr, 'i');
      return regex.test(allText);
    });
    if (!matchesContext) return false;
  }

  return true;
}

