# Deploy Super User Critical Report Notifications

## Quick Deployment Guide

Follow these steps to deploy the super user critical report notification system:

### 1. Deploy Edge Functions

```powershell
# Navigate to the project directory
cd lspu_dres

# Deploy the new super user notification function
npx supabase functions deploy notify-superusers-critical-report

# Re-deploy the updated classify-image function
npx supabase functions deploy classify-image
```

### 2. Verify Environment Variables

Make sure these environment variables are set in your Supabase project:

```bash
supabase secrets list
```

Required secrets:
- `ONESIGNAL_REST_API_KEY` ✓
- `ONESIGNAL_APP_ID` ✓
- `SUPABASE_URL` ✓
- `SUPABASE_SERVICE_ROLE_KEY` ✓

All should already be configured from the responder notification setup.

### 3. Verify Super User Roles

Check that super users are properly configured:

```sql
-- Run this in Supabase SQL Editor
SELECT 
  u.id,
  u.email,
  u.raw_user_meta_data->>'role' as role,
  u.onesignal_player_id,
  CASE 
    WHEN u.onesignal_player_id IS NOT NULL THEN '✅ Ready'
    ELSE '⚠️ Needs mobile app login'
  END as status
FROM auth.users u
WHERE u.raw_user_meta_data->>'role' IN ('super_user', 'admin')
ORDER BY u.email;
```

**If any super users don't have OneSignal player IDs:**
1. Have them login to the mobile app
2. Wait 5 seconds for player ID to be saved
3. Re-run the query to verify

### 4. Update Mobile App (Optional)

The mobile app changes are already included from the responder notification update. If you haven't rebuilt recently:

```powershell
cd mobile_app
flutter build apk --release
```

### 5. Test the System

#### Quick Test Scenario

**Method 1: Using Mobile App (Recommended)**

1. **Login as a citizen** on mobile app
2. **Take a photo** of fire, ambulance, or accident (real or stock photo)
3. **Submit the report** via mobile app
4. **Wait 5-10 seconds** for AI classification
5. **Check super user phone**:
   - Should receive notification immediately
   - Red notification with emergency alert sound
   - Shows "REQUIRES IMMEDIATE ASSIGNMENT"

**Method 2: Using Web Interface**

1. **Login as a citizen** on web interface
2. **Upload an image** of fire/medical emergency
3. **Submit report**
4. **Wait for classification**
5. **Check super user phone**

#### Test SQL Queries

**Check if notification was triggered:**
```sql
SELECT 
  n.id,
  n.type,
  n.title,
  n.message,
  n.data,
  n.created_at,
  u.email as recipient
FROM notifications n
JOIN auth.users u ON n.user_id = u.id
WHERE n.type = 'critical_report'
ORDER BY n.created_at DESC
LIMIT 5;
```

**Check report classification:**
```sql
SELECT 
  id,
  type,
  priority,
  severity,
  response_time,
  created_at,
  ai_timestamp,
  status,
  CASE 
    WHEN priority <= 2 OR severity IN ('CRITICAL', 'HIGH')
    THEN '🚨 Should notify super users'
    ELSE '🔔 No notification'
  END as notification_expected
FROM reports
ORDER BY created_at DESC
LIMIT 5;
```

**Check classification logs:**
```sql
SELECT 
  r.id,
  r.type,
  r.priority,
  r.severity,
  r.created_at,
  r.ai_timestamp,
  (r.ai_timestamp - r.created_at) as classification_time,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM notifications n 
      WHERE n.type = 'critical_report' 
      AND n.data->>'report_id' = r.id::text
    )
    THEN '✅ Notification sent'
    ELSE '❌ No notification'
  END as notification_status
FROM reports r
WHERE r.created_at > NOW() - INTERVAL '1 hour'
ORDER BY r.created_at DESC;
```

### 6. Monitor Logs

**Check Edge Function logs:**

```powershell
# For super user notification function
npx supabase functions logs notify-superusers-critical-report --follow

# For classify-image function
npx supabase functions logs classify-image --follow
```

**Expected log output (success):**

**classify-image logs:**
```
🚨 Report xxx is CRITICAL/HIGH priority. Notifying super users...
✅ Super user notification sent: {
  success: true,
  sent: 3,
  notified_users: 3
}
```

**notify-superusers-critical-report logs:**
```
Report xxx is critical/high priority
Found 3 super users with OneSignal player IDs
Sending OneSignal notification to 3 super user(s)
✅ Critical report notification sent to 3 super users/admins
```

**Mobile app logs (Flutter):**
```
🚨 CRITICAL REPORT notification tapped:
  - Report ID: xxx
  - Type: fire
  - Priority: 1
  - Severity: CRITICAL
  ⚠️ ACTION REQUIRED: Assign responder immediately!
🚨 Playing emergency sound for CRITICAL REPORT (super user alert)
```

## Testing Scenarios

### Scenario 1: Fire Report (Priority 1, Critical)

**Setup:**
- Submit report with fire image
- AI classifies as "fire"
- Priority: 1, Severity: CRITICAL

**Expected:**
- ✅ AI classification succeeds
- ✅ Report marked as "classified"
- ✅ notifySuperUsersIfCritical() called
- ✅ All super users receive push notification
- ✅ Emergency sound plays
- ✅ Notification shows "REQUIRES IMMEDIATE ASSIGNMENT"
- ✅ Response time: "5 minutes"
- ✅ Database notifications created

### Scenario 2: Medical Report (Priority 1, Critical)

**Setup:**
- Submit report with ambulance/medical image
- AI classifies as "medical"
- Priority: 1, Severity: CRITICAL

**Expected:**
- Same as Scenario 1
- Response time: "3 minutes"

### Scenario 3: Environmental Report (Priority 3-4, Low)

**Setup:**
- Submit report with tree/environmental image
- AI classifies as "environmental"
- Priority: 4, Severity: LOW

**Expected:**
- ✅ AI classification succeeds
- ✅ Report marked as "classified"
- ❌ No notification sent to super users (not critical)
- ℹ️ Logs: "Report is not critical/high priority. Skipping super user notification."

### Scenario 4: No Super Users with OneSignal

**Setup:**
- No super users have logged into mobile app
- Submit critical report

**Expected:**
- ✅ AI classification succeeds
- ⚠️ No push notifications sent (no player IDs)
- ✅ Database notifications still created
- ℹ️ Logs: "No super users with OneSignal player IDs found"

## Troubleshooting

### Issue: No push notification received (super user)

**Check 1: Is user a super user?**
```sql
SELECT email, raw_user_meta_data->>'role' as role
FROM auth.users
WHERE email = 'superuser@example.com';
```
Should return `super_user` or `admin`

**Check 2: Does user have OneSignal player ID?**
```sql
SELECT email, onesignal_player_id
FROM auth.users
WHERE email = 'superuser@example.com';
```
Should have a valid player ID (not NULL)

**Fix:** Have super user login to mobile app again

### Issue: Notification sent for non-critical report

**Check report classification:**
```sql
SELECT id, type, priority, severity
FROM reports
WHERE id = 'report_id';
```

**Review classification logic:**
- Priority should be 3-4 for non-critical
- Severity should be 'MEDIUM' or 'LOW'

**If incorrect:**
- Review AI classification in `classify-image/index.ts`
- Check `calculateSeverityFromImage()` function

### Issue: Function error in logs

**Check logs for specific error:**
```powershell
npx supabase functions logs notify-superusers-critical-report --limit 100
```

**Common errors:**
- Missing environment variables → Set with `supabase secrets set`
- Invalid OneSignal API key → Verify in OneSignal dashboard
- Network timeout → Check Supabase/OneSignal connectivity
- Report not found → Verify report ID exists

### Issue: Notification sent but no sound

**Check device settings:**
1. Notification permissions enabled for app
2. Sound enabled for notifications
3. Do Not Disturb mode disabled
4. Volume turned up

**Check app settings:**
```dart
final soundService = NotificationSoundService();
final isEnabled = soundService.isSoundEnabled;
```

**Verify sound file exists:**
- `android/app/src/main/res/raw/emergency_alert.mp3`

## Complete Workflow Test

### End-to-End Test (5 minutes)

1. **Preparation** (1 min)
   - Verify super user has OneSignal player ID
   - Have super user phone ready
   - Have citizen account or mobile app ready

2. **Submit Critical Report** (1 min)
   - Login as citizen on mobile app
   - Take photo of fire/ambulance (or use stock photo)
   - Submit report
   - Note the time

3. **Wait for Classification** (10 seconds)
   - Watch Edge Function logs
   - Should see classification complete

4. **Verify Super User Notification** (30 seconds)
   - Check super user phone
   - Should receive red notification
   - Should hear emergency sound
   - Tap notification to open app

5. **Verify in Database** (2 min)
   - Run test SQL queries above
   - Verify notification record exists
   - Verify report has correct priority/severity

6. **Assign Responder** (1 min)
   - Super user opens reports dashboard
   - Finds critical report
   - Assigns responder
   - Responder should also receive notification (from previous feature)

## Performance Benchmarks

| Stage | Expected Time | Notes |
|-------|--------------|-------|
| Report submission | <1 second | Upload to storage |
| AI classification | 2-4 seconds | Azure Vision analysis |
| Priority/severity calculation | <1 second | Algorithmic |
| Super user notification | <1 second | OneSignal API |
| **Total (submit → notify)** | **3-6 seconds** | End-to-end |
| Responder assignment | <2 seconds | Manual action |
| Responder notification | <1 second | From previous feature |
| **Total (submit → responder notified)** | **6-9 seconds** | Complete workflow |

## Rollback (If Needed)

If you need to rollback changes:

### 1. Remove notification call from classify-image

```typescript
// Comment out this line in classify-image/index.ts (around line 3158)
// await notifySuperUsersIfCritical(reportId, severityAnalysis);
```

### 2. Redeploy classify-image

```powershell
npx supabase functions deploy classify-image
```

### 3. Optionally remove the notification function

```powershell
npx supabase functions delete notify-superusers-critical-report
```

The classification system will still work normally, just without super user notifications.

## Success Criteria

✅ **All criteria must pass:**

- [ ] Super users exist with `super_user` or `admin` role
- [ ] Super users have OneSignal player IDs in database
- [ ] Super user notification function deployed
- [ ] Classify-image function updated and deployed
- [ ] Test critical report submitted
- [ ] Report classified correctly (priority ≤ 2 or severity CRITICAL/HIGH)
- [ ] Super users receive push notification within 10 seconds
- [ ] Emergency sound plays on super user devices
- [ ] Notification shows correct report details
- [ ] Database notification records created
- [ ] Edge Function logs show success
- [ ] Complete workflow (submit → classify → notify → assign → responder notified) works

## Next Steps After Deployment

1. ✅ Train super users on the new notification system
2. ✅ Monitor notification delivery rates
3. ✅ Gather feedback on notification content
4. ✅ Track super user response times
5. ✅ Optimize priority/severity thresholds if needed
6. ✅ Consider auto-assignment for extremely critical cases (future)

## Support Contacts

- **Supabase Edge Functions**: Check `supabase functions logs`
- **OneSignal Dashboard**: https://app.onesignal.com
- **Mobile App Logs**: `flutter logs` or Android Studio Logcat
- **Database Queries**: Supabase SQL Editor

---

## Summary

✅ **New Edge Function**: `notify-superusers-critical-report`
✅ **Updated Function**: `classify-image`
✅ **Mobile App**: OneSignal service updated (same update as responder notifications)
✅ **Priority Detection**: Automatic critical/high detection
✅ **Sound System**: Emergency alert for all critical report notifications
✅ **Database Logging**: All notifications tracked

**Ready to deploy! 🚀**

### Quick Deploy Command

```powershell
# Deploy everything at once
npx supabase functions deploy notify-superusers-critical-report && npx supabase functions deploy classify-image

# Then test by submitting a fire or medical report
```

**The system is ready! Super users will now be alerted immediately when critical emergencies are reported.** 🚨

