# Testing Guide: Adaptive Learning & Deduplication System

## Prerequisites

1. ✅ **Apply Database Migrations** (Required!)
   - Go to: https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/sql/new
   - Run `20250121000001_classification_corrections.sql`
   - Run `20250121000002_image_deduplication.sql`

2. ✅ **Edge Functions Deployed** (Already done!)
   - All functions are deployed and ready

3. ✅ **Admin Access**
   - Make sure you're logged in as an admin user

---

## Test 1: Classification Correction System

### Steps:
1. **Open Admin Dashboard**: `public/admin.html`
2. **Find a Report** with AI classification (any report that has been classified)
3. **Click "Correct" button** next to the report
4. **Fill out the correction form**:
   - Select the **correct emergency type** from dropdown
   - Check **issue categories** (optional, but helpful for learning)
   - Enter **detailed correction reason** (minimum 20 characters)
     - Example: *"This is a sports injury on a playing field, not a traffic accident. The image shows an injured knee with visible bruise, no vehicles present, and sports equipment in background."*
5. **Click "Submit Correction"**

### Expected Results:
- ✅ Success message: "Classification corrected successfully! The system will learn from this correction."
- ✅ Report type updates to corrected type
- ✅ Correction stored in database
- ✅ AI features stored for learning

### Verify:
```sql
-- Check if correction was saved
SELECT * FROM classification_corrections ORDER BY created_at DESC LIMIT 1;

-- Check if report was updated
SELECT id, type, corrected_type, correction_reason FROM reports WHERE corrected_type IS NOT NULL;
```

---

## Test 2: Duplicate Image Detection

### Steps:
1. **Submit a report** with an image
2. **Submit the same image again** (same file, different report)
3. Check if the second submission uses the existing image path

### Expected Results:
- ✅ First submission: Image uploaded, `isDuplicate: false`
- ✅ Second submission: Same image hash detected, `isDuplicate: true`, existing path reused
- ✅ Storage only has ONE copy of the image
- ✅ `reference_count` incremented in `image_deduplication` table

### Verify:
```sql
-- Check deduplication stats
SELECT * FROM get_deduplication_stats();

-- Check duplicate images
SELECT image_hash, reference_count, image_path 
FROM image_deduplication 
WHERE reference_count > 1;
```

### Test via API:
```javascript
// In browser console on your app
const formData = new FormData();
const imageFile = document.querySelector('input[type="file"]').files[0]; // Same image
formData.append('image', imageFile);
formData.append('lat', 14.3096);
formData.append('lng', 121.2633);
formData.append('description', 'Test duplicate image');

// Submit same image twice and check response
```

---

## Test 3: Adaptive Learning (Pattern Analysis)

### Steps:
1. **Make 3-5 corrections** with the same pattern
   - Example: Correct 3 "accident" → "medical" (sports injuries)
2. **Wait a few seconds** for background learning to trigger
3. **Call the learning function**:
   ```javascript
   // In browser console
   const { data } = await supabase.functions.invoke('learn-from-corrections');
   console.log(data);
   ```
4. **Check if rules were created**:
   ```sql
   SELECT * FROM adaptive_classifier_config WHERE is_active = true;
   ```

### Expected Results:
- ✅ After 3+ similar corrections, adaptive rule created
- ✅ Rule appears in `adaptive_classifier_config` table
- ✅ Rule is active and will be applied to future classifications

### Verify:
```sql
-- Check created rules
SELECT rule_name, rule_type, learned_from_corrections, is_active 
FROM adaptive_classifier_config 
ORDER BY learned_from_corrections DESC;

-- Check correction patterns
SELECT * FROM get_correction_stats();
```

---

## Test 4: Analyze Corrections Function

### Steps:
1. **Make a few corrections** (at least 2-3)
2. **Call analyze function**:
   ```javascript
   const { data } = await supabase.functions.invoke('analyze-corrections');
   console.log(data);
   ```
3. **Check the analysis results**

### Expected Results:
- ✅ Returns correction patterns
- ✅ Identifies common misclassifications
- ✅ Suggests rule improvements
- ✅ Shows statistics about corrections

### Expected Response:
```json
{
  "success": true,
  "patterns": [
    {
      "originalType": "accident",
      "correctedType": "medical",
      "count": 3,
      "avgConfidence": 0.65,
      "commonFeatures": {...},
      "issueCategories": ["wrong-context"]
    }
  ],
  "statistics": {
    "totalCorrections": 3,
    "patternsFound": 1,
    "suggestions": [...]
  }
}
```

---

## Test 5: Automatic Rule Application

### Steps:
1. **Create a correction pattern** (3+ similar corrections)
2. **Trigger learning** (automatically or manually)
3. **Submit a NEW report** with similar features
4. **Check classification** - should use the learned rule

### Expected Results:
- ✅ New classification applies learned rule
- ✅ Classification reasoning includes: "Applied X adaptive rule(s) learned from corrections"
- ✅ Better accuracy for similar cases

### Verify:
- Check classification result for new similar report
- Look for "adaptive rule" in reasoning/analysis

---

## Test 6: Image Deduplication Stats

### Steps:
1. **Call deduplication stats function**:
   ```javascript
   const { data } = await supabase.rpc('get_deduplication_stats');
   console.log(data);
   ```
2. **Check the results**

### Expected Results:
- ✅ Shows total unique images
- ✅ Shows duplicates prevented count
- ✅ Shows storage saved in bytes
- ✅ Shows average references per image

---

## Test 7: Cleanup Orphaned Images

### Steps:
1. **Delete a report** that uses an image
2. **Check reference count** (should decrement)
3. **Delete all reports** using an image
4. **Run cleanup function**:
   ```javascript
   const { data } = await supabase.functions.invoke('cleanup-orphaned-images');
   console.log(data);
   ```

### Expected Results:
- ✅ Orphaned images (reference_count = 0) are deleted from storage
- ✅ Deduplication records cleaned up
- ✅ Storage space freed

---

## Testing Checklist

### Correction System
- [ ] Can open correction modal
- [ ] Can select correct emergency type
- [ ] Can enter detailed reason (validates minimum 20 chars)
- [ ] Can select issue categories
- [ ] Correction saves successfully
- [ ] Report type updates
- [ ] Correction stored in database

### Duplicate Detection
- [ ] Same image submitted twice doesn't create duplicate
- [ ] Image hash computed correctly
- [ ] Reference count increments
- [ ] Storage savings tracked

### Learning System
- [ ] Corrections analyzed correctly
- [ ] Patterns identified (after 3+ similar)
- [ ] Rules auto-created
- [ ] Rules applied to new classifications
- [ ] System learns and improves

### Analytics
- [ ] Correction stats available
- [ ] Deduplication stats available
- [ ] Pattern analysis works
- [ ] Suggestions generated

---

## Quick Test Script

Run this in browser console on admin.html:

```javascript
// 1. Get a report to correct
const { data: reports } = await supabase.from('reports').select('*').limit(1);
const report = reports[0];

// 2. Open correction modal
openCorrectionModal(report.id, report);

// 3. After correction, check stats
const { data: stats } = await supabase.rpc('get_correction_stats');
console.log('Correction Stats:', stats);

// 4. Analyze corrections
const { data: analysis } = await supabase.functions.invoke('analyze-corrections');
console.log('Analysis:', analysis);

// 5. Check deduplication
const { data: dedup } = await supabase.rpc('get_deduplication_stats');
console.log('Deduplication:', dedup);
```

---

## Troubleshooting

### Issue: "Classification corrected successfully" but nothing happens
- **Check**: Database migrations applied?
- **Fix**: Run migrations in Supabase Dashboard SQL Editor

### Issue: Modal doesn't open
- **Check**: Browser console for errors
- **Check**: `openCorrectionModal` function exists
- **Fix**: Make sure admin.html has the correction modal HTML

### Issue: No adaptive rules created
- **Check**: Made at least 3 similar corrections?
- **Check**: Call `learn-from-corrections` function
- **Check**: `adaptive_classifier_config` table exists

### Issue: Duplicate detection not working
- **Check**: `image_hash` column exists in reports table
- **Check**: `get_or_create_image_hash` function exists
- **Fix**: Apply image deduplication migration

---

## Success Indicators

✅ System is working correctly if:
1. You can correct classifications via admin dashboard
2. Same images aren't stored multiple times
3. After 3+ similar corrections, rules are created automatically
4. New similar cases use learned rules
5. Analytics show correction patterns and storage savings

---

Happy Testing! 🚀

