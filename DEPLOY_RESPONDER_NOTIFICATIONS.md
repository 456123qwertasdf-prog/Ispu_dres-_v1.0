# Deploy Responder Push Notifications

## Quick Deployment Guide

Follow these steps to deploy the responder push notification system:

### 1. Deploy Edge Functions

```powershell
# Navigate to the project directory
cd lspu_dres

# Deploy the new notification function
npx supabase functions deploy notify-responder-assignment

# Re-deploy the updated assignment function
npx supabase functions deploy assign-responder
```

### 2. Verify Environment Variables

Make sure these environment variables are set in your Supabase project:

```bash
supabase secrets list
```

Required secrets:
- `ONESIGNAL_REST_API_KEY`
- `ONESIGNAL_APP_ID`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

If any are missing, set them:

```powershell
npx supabase secrets set ONESIGNAL_REST_API_KEY=your_key_here
npx supabase secrets set ONESIGNAL_APP_ID=8d6aa625-a650-47ac-b9ba-00a247840952
```

### 3. Update Mobile App

#### Option A: Rebuild APK (Recommended)
```powershell
cd mobile_app
flutter build apk --release
```

The updated OneSignal service will be included in the new build.

#### Option B: Hot Reload (Development Only)
If testing in development mode:
```powershell
cd mobile_app
flutter run
```

### 4. Test the System

#### Quick Test Script

1. **Login as Admin or Super User**
   - Go to admin dashboard
   - Navigate to reports view

2. **Create a Critical Report** (or use existing)
   - Type: Fire or Medical (priority 1-2)
   - Fill in required details

3. **Assign to a Responder**
   - Select a responder from dropdown
   - Click "Assign"
   - Wait 1-2 seconds

4. **Check Responder's Mobile Device**
   - Should receive push notification immediately
   - Notification should show:
     - 🚨 Red notification (for critical)
     - "CRITICAL/HIGH PRIORITY" label
     - Report type and location
     - Response time
   - Emergency sound should play (if enabled)

#### SQL Test Queries

**Check if notification was created:**
```sql
SELECT 
  n.id,
  n.user_id,
  n.type,
  n.title,
  n.message,
  n.data,
  n.created_at,
  u.name as user_name
FROM notifications n
JOIN users u ON n.user_id = u.id
WHERE n.type = 'assignment_created'
ORDER BY n.created_at DESC
LIMIT 5;
```

**Check assignment:**
```sql
SELECT 
  a.id,
  a.report_id,
  a.responder_id,
  a.status,
  r.type as report_type,
  r.priority,
  r.severity,
  resp.name as responder_name
FROM assignment a
JOIN reports r ON a.report_id = r.id
JOIN responder resp ON a.responder_id = resp.id
ORDER BY a.assigned_at DESC
LIMIT 5;
```

**Check OneSignal player IDs:**
```sql
SELECT 
  u.id,
  u.email,
  u.onesignal_player_id,
  r.name as responder_name
FROM users u
LEFT JOIN responder r ON r.user_id = u.id
WHERE r.id IS NOT NULL
AND u.onesignal_player_id IS NOT NULL;
```

### 5. Monitor Logs

**Check Edge Function logs:**

```powershell
# For notify-responder-assignment
npx supabase functions logs notify-responder-assignment --follow

# For assign-responder
npx supabase functions logs assign-responder --follow
```

**Expected log output (success):**
```
✅ Push notification sent to responder: {
  sent: 1,
  is_critical: true,
  responder_name: "John Doe",
  report_type: "fire"
}
```

**Mobile app logs (Flutter):**
```
🚨 Assignment notification tapped:
  - Assignment ID: xxx
  - Report ID: xxx
  - Critical: YES
🔊 Playing emergency sound for CRITICAL/HIGH priority assignment
```

## Testing Scenarios

### Scenario 1: Critical Priority Assignment

**Setup:**
- Report: Fire (priority: 1, severity: CRITICAL)
- Responder: Has OneSignal player ID

**Expected:**
- ✅ Push notification sent
- ✅ Red notification color
- ✅ Emergency sound plays
- ✅ Shows "CRITICAL/HIGH PRIORITY"
- ✅ Response time: 5 minutes
- ✅ Database notification created

### Scenario 2: High Priority Assignment

**Setup:**
- Report: Medical (priority: 2, severity: HIGH)
- Responder: Has OneSignal player ID

**Expected:**
- ✅ Push notification sent
- ✅ Red notification color
- ✅ Emergency sound plays
- ✅ Shows "CRITICAL/HIGH PRIORITY"
- ✅ Response time: 3 minutes
- ✅ Database notification created

### Scenario 3: Normal Priority Assignment

**Setup:**
- Report: Environmental (priority: 4, severity: LOW)
- Responder: Has OneSignal player ID

**Expected:**
- ✅ Push notification sent
- ✅ Orange notification color
- ✅ Default sound plays
- ✅ No priority label
- ✅ Response time: 45 minutes
- ✅ Database notification created

### Scenario 4: No OneSignal Player ID

**Setup:**
- Report: Any type
- Responder: No OneSignal player ID

**Expected:**
- ✅ Assignment created successfully
- ⚠️ No push notification sent (logged)
- ✅ Database notification created
- ℹ️ Logs: "Responder has no OneSignal player ID"

## Troubleshooting

### Issue: No push notification received

**Check:**
1. Responder has OneSignal player ID in database
2. Mobile app has notification permissions
3. Edge function logs show success
4. OneSignal dashboard shows delivery

**Fix:**
```sql
-- Check player ID
SELECT u.id, u.email, u.onesignal_player_id 
FROM users u
JOIN responder r ON r.user_id = u.id
WHERE r.id = 'responder_id';

-- If NULL, responder needs to login to mobile app again
```

### Issue: Wrong sound playing

**Check:**
```sql
-- Check report priority
SELECT id, type, priority, severity 
FROM reports 
WHERE id = 'report_id';
```

**Expected:**
- Priority 1-2 or Severity 'CRITICAL'/'HIGH' → Emergency sound
- Priority 3-4 → Default sound

### Issue: Edge function error

**Check logs:**
```powershell
npx supabase functions logs notify-responder-assignment --limit 50
```

**Common errors:**
- Missing environment variables
- Invalid OneSignal API key
- Network timeout
- Report/responder not found

## Rollback (If Needed)

If you need to rollback changes:

### 1. Remove notification call from assign-responder
```typescript
// Comment out this line in assign-responder/index.ts
// await sendPushNotificationToResponder(supabaseClient, result)
```

### 2. Redeploy
```powershell
npx supabase functions deploy assign-responder
```

The assignment system will still work, just without push notifications.

## Performance Notes

- **Latency**: ~1-2 seconds from assignment to notification
- **Reliability**: Non-blocking (won't fail assignment if notification fails)
- **Concurrency**: Supports multiple simultaneous assignments
- **Scalability**: OneSignal handles rate limiting automatically

## Next Steps

After successful deployment:

1. ✅ Test with real responders
2. ✅ Monitor notification delivery rates
3. ✅ Gather feedback on notification content
4. ✅ Add navigation from notification tap (future enhancement)
5. ✅ Add notification actions (Accept/Decline) (future enhancement)

## Support Contacts

- **Supabase Edge Functions**: Check `supabase functions logs`
- **OneSignal Dashboard**: https://app.onesignal.com
- **Mobile App Logs**: `flutter logs` or Android Studio Logcat

---

## Summary

✅ **New Edge Function**: `notify-responder-assignment`
✅ **Updated Function**: `assign-responder` 
✅ **Mobile App**: OneSignal service updated
✅ **Priority System**: Automatic critical/high detection
✅ **Sound System**: Emergency vs default sounds
✅ **Database Logging**: All notifications tracked

**Ready to deploy! 🚀**

