# Image Classification Analysis & Improvement Plan

## Current System Overview

### Architecture
- **Primary**: Azure Computer Vision v4.0 API
- **Fallback**: Hugging Face models (microsoft/beit-base-patch16-224-pt22k-ft22k)
- **Analysis Methods**: Multi-factor scoring with weighted evidence

### Emergency Types Supported
1. **Flood** - Water emergencies
2. **Accident** - Vehicle/road incidents
3. **Fire** - Fire and smoke emergencies
4. **Medical** - Health emergencies and injuries
5. **Earthquake** - Seismic events
6. **Storm** - Weather emergencies
7. **Non-Emergency** - Normal scenarios
8. **Other** - Unclassified

## Issue Analysis: Injured Knee Classified as "Accident"

### The Problem
- **Image**: Person with injured knee (visible bruise, pain)
- **Classification**: "ACCIDENT Emergency" at 60% confidence
- **Expected**: Should be "MEDICAL Emergency"

### Root Cause
1. **Medical detection is keyword-heavy** - Requires words like "injury", "ambulance", "medical"
2. **Missing visual injury detection** - Doesn't detect body parts, bruises, wounds visually
3. **Accident detection too broad** - Catches sports/activity scenes that should be medical
4. **Injury context not captured** - Sports injury ≠ traffic accident

### Current Medical Detection Logic
```typescript
// Only triggers on keywords:
- 'injury', 'ambulance', 'medical', 'hospital', 'paramedic'
- Medical objects: 'stretcher', 'first aid', 'bandage'
- People presence alone doesn't help without keywords
```

### Missing Elements
- Visual injury detection (bruises, wounds, bandages, casts)
- Body part analysis (knee, arm, leg injuries)
- Pain/distress detection (facial expressions, body posture)
- Sports injury differentiation from traffic accidents

## Improvement Plan

### Phase 1: Enhanced Medical Emergency Detection

#### 1.1 Add Visual Injury Indicators
- Detect body parts with visible injuries
- Look for medical aids (bandages, braces, casts, crutches)
- Analyze body posture indicating pain/distress
- Detect facial expressions showing pain

#### 1.2 Improve Injury Keywords
Add sports/activity injury terms:
- 'bruise', 'bruised', 'swollen', 'wound', 'cut', 'injury'
- 'knee injury', 'ankle injury', 'wrist injury'
- 'limping', 'unable to walk', 'supporting leg'
- 'crutch', 'crutches', 'bandage', 'brace', 'cast', 'splint'

#### 1.3 Context-Aware Classification
- **Sports field + visible injury** = Medical Emergency (not Accident)
- **Road + vehicle damage** = Accident Emergency
- **Sports field + no injury** = Non-Emergency

### Phase 2: Accident Classification Refinement

#### 2.1 Narrow Accident Scope
- Require vehicle/road context
- Penalize sports/activity scenes without vehicles
- Better distinguish: Traffic Accident vs Sports Injury

#### 2.2 Enhanced Penalties
- Strong penalty if: sports field + injury + no vehicle
- Reduce accident score when medical indicators present

### Phase 3: Analytics & Monitoring

#### 3.1 Classification Performance Tracking
Use existing database fields:
- `classification_version`
- `confidence_calibration`
- `manual_review_required`
- `classification_notes`

#### 3.2 Create Analytics Dashboard
Track:
- Classification accuracy by type
- Low confidence cases (< 60%)
- Cases requiring manual review
- Common misclassifications

#### 3.3 Review Past Classifications
Query database to find:
- Medical emergencies classified as accidents
- Low confidence medical cases
- Pattern analysis for improvements

## Implementation Steps

### Step 1: Improve Medical Emergency Detection
Update `analyzeMedicalEmergency()` function with:
1. Visual injury detection patterns
2. Body part analysis
3. Sports injury keywords
4. Better scoring for visible injuries

### Step 2: Refine Accident Detection
Update `analyzeAccidentEmergency()` function to:
1. Require vehicle/road context
2. Penalize sports scenes
3. Check for injury indicators (suggest medical instead)

### Step 3: Add Classification Analytics
1. Query existing classifications
2. Identify patterns
3. Track improvement metrics

### Step 4: Testing
1. Test with injured knee image (should be medical)
2. Test with actual traffic accidents (should stay accident)
3. Test with sports activities without injuries (should be non-emergency)

## Expected Results

### Before Improvements
- Injured knee → "ACCIDENT" (60% confidence) ❌

### After Improvements
- Injured knee → "MEDICAL" (75-85% confidence) ✅
- Traffic accident → "ACCIDENT" (maintained)
- Sports without injury → "NON-EMERGENCY" (maintained)

