# 🚨 Responder Push Notifications - Quick Reference Card

## 🎯 What It Does
**Automatically sends push notifications to responders when assigned to reports by admins/super users.**

---

## 📱 Notification Types

### 🚨 CRITICAL/HIGH Priority
**Triggers when:**
- Priority: 1-2
- Severity: CRITICAL or HIGH
- Report types: Fire, Medical, Accident

**Notification style:**
- 🔴 Red color
- 🚨 "CRITICAL/HIGH PRIORITY" label
- 📢 Emergency alert sound
- ⚡ High priority delivery (10)
- 📌 Persistent until opened

**Example:**
```
🚨 New Assignment - 🚨 CRITICAL/HIGH PRIORITY
You have been assigned to a FIRE report
• Response time: 5 minutes
• Location: 123 Main St
```

### 🔔 NORMAL Priority
**Triggers when:**
- Priority: 3-4
- Severity: MEDIUM or LOW
- Report types: Flood, Environmental, Other

**Notification style:**
- 🟠 Orange color
- No priority label
- 🔔 Default sound
- ⚡ Normal priority (7)
- Standard notification

**Example:**
```
🔔 New Assignment
You have been assigned to a FLOOD report
• Response time: 15 minutes
• Location: 456 Oak Ave
```

---

## 🚀 Deploy Commands

```powershell
# Deploy both functions
npx supabase functions deploy notify-responder-assignment
npx supabase functions deploy assign-responder

# Check logs
npx supabase functions logs notify-responder-assignment --follow
```

---

## ✅ Testing Checklist

- [ ] Deploy both Edge Functions
- [ ] Verify environment variables (OneSignal keys)
- [ ] Login to mobile app as responder (gets OneSignal ID)
- [ ] Assign critical report to responder
- [ ] Verify notification received (1-2 seconds)
- [ ] Check emergency sound plays
- [ ] Tap notification (logs data)
- [ ] Check database notification record

---

## 🔍 Quick SQL Checks

**Check recent assignments:**
```sql
SELECT a.id, r.type, r.priority, r.severity, resp.name
FROM assignment a
JOIN reports r ON a.report_id = r.id
JOIN responder resp ON a.responder_id = resp.id
ORDER BY a.assigned_at DESC LIMIT 5;
```

**Check notifications sent:**
```sql
SELECT user_id, type, title, message, created_at
FROM notifications
WHERE type = 'assignment_created'
ORDER BY created_at DESC LIMIT 5;
```

**Check OneSignal player IDs:**
```sql
SELECT u.email, u.onesignal_player_id, r.name
FROM users u
JOIN responder r ON r.user_id = u.id
WHERE u.onesignal_player_id IS NOT NULL;
```

---

## ⚙️ Environment Variables

**Required in Supabase Edge Functions:**
```
ONESIGNAL_REST_API_KEY  ✓ (starts with os_v2_app_)
ONESIGNAL_APP_ID        ✓ 8d6aa625-a650-47ac-b9ba-00a247840952
SUPABASE_URL            ✓ Your Supabase URL
SUPABASE_SERVICE_ROLE_KEY ✓ Service role key
```

**Check with:**
```powershell
npx supabase secrets list
```

---

## 🐛 Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| No notification | No player ID | Responder login to mobile app again |
| Wrong sound | Wrong priority | Check report priority/severity |
| Function fails | Missing env var | Set OneSignal keys |
| Not critical | Priority too high | Set priority to 1-2 |

**Debug logs:**
```powershell
npx supabase functions logs notify-responder-assignment --limit 50
```

---

## 📊 Priority Rules

```
Priority 1 + Any Severity     → CRITICAL ✅
Priority 2 + Any Severity     → CRITICAL ✅
Priority 3 + CRITICAL/HIGH    → CRITICAL ✅
Priority 3 + MEDIUM/LOW       → Normal
Priority 4 + Any Severity     → Normal
```

---

## 📁 Files Modified

**New:**
- `supabase/functions/notify-responder-assignment/index.ts`

**Updated:**
- `supabase/functions/assign-responder/index.ts`
- `mobile_app/lib/services/onesignal_service.dart`

**Docs:**
- `RESPONDER_PUSH_NOTIFICATIONS.md` (technical docs)
- `DEPLOY_RESPONDER_NOTIFICATIONS.md` (deployment guide)
- `RESPONDER_NOTIFICATIONS_SUMMARY.md` (overview)

---

## 🎯 Test Scenario

**Quick Test (2 minutes):**

1. **Login as Admin** → Open admin dashboard
2. **Create Fire Report** → Type: Fire, Location: anywhere
3. **Assign to Responder** → Select responder, click assign
4. **Check Responder Phone** → Should receive red notification within 2 seconds
5. **Verify Sound** → Emergency alert sound should play
6. **Tap Notification** → Opens app (logs assignment details)

**Expected Timeline:**
- 0s: Admin assigns responder
- 0.5s: Assignment created in database
- 1s: Push notification sent to OneSignal
- 1.5s: Responder receives notification
- 2s: Sound plays

---

## 📞 OneSignal Dashboard

**Check delivery status:**
1. Go to https://app.onesignal.com
2. Select your app: `8d6aa625-a650-47ac-b9ba-00a247840952`
3. Click "Messages" → "All Messages"
4. Find recent assignment notification
5. Check delivery stats

---

## 💡 Tips

✅ Test with real device (not emulator) for accurate sound testing
✅ Make sure device is not in Do Not Disturb mode
✅ Check mobile app notification permissions
✅ Use critical reports (Fire, Medical) for testing priority
✅ Monitor Edge Function logs during testing
✅ Keep OneSignal dashboard open to see delivery stats

---

## 🎨 Notification Data Structure

```json
{
  "type": "assignment",
  "assignment_id": "uuid",
  "report_id": "uuid",
  "report_type": "fire",
  "priority": 1,
  "severity": "CRITICAL",
  "is_critical": true,
  "location": {
    "lat": 14.1167,
    "lng": 121.4167,
    "address": "123 Main St"
  },
  "response_time": "5 minutes"
}
```

---

## 📈 Expected Results

**Database:**
- ✅ Assignment record created
- ✅ Report status updated to "assigned"
- ✅ Notification record created
- ✅ Audit log entry created

**OneSignal:**
- ✅ Push notification delivered
- ✅ Delivery confirmed in dashboard
- ✅ Player ID targeted correctly

**Mobile App:**
- ✅ Notification appears on device
- ✅ Correct sound plays
- ✅ Tap opens app
- ✅ Data logged to console

---

## 🔄 Assignment Flow

```
Admin assigns responder
       ↓
assign-responder function
       ↓
Create assignment in DB
       ↓
notify-responder-assignment function
       ↓
Fetch report priority/severity
       ↓
Is Critical? (Priority ≤ 2 or Severity = CRITICAL/HIGH)
       ↓
    Yes → Emergency alert (red, emergency sound)
       ↓
    No → Normal alert (orange, default sound)
       ↓
Send to OneSignal API
       ↓
Responder receives notification
```

---

## 📝 Summary

✅ **Implementation:** Complete
✅ **Documentation:** Complete
✅ **Testing:** Ready
✅ **Deployment:** Ready

**Deploy with:**
```powershell
npx supabase functions deploy notify-responder-assignment && npx supabase functions deploy assign-responder
```

**Then test by assigning a Fire or Medical report to a responder!** 🚀

---

**Need help?** Check `RESPONDER_PUSH_NOTIFICATIONS.md` for full documentation.

