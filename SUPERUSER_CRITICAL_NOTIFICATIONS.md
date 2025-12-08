# Super User Critical Report Notifications

## Overview

This document describes the automatic push notification system for super users and admins when critical or high-priority emergency reports are created. This ensures that super users can immediately assign responders to urgent situations.

## Features

✅ **Automatic Notifications**: Super users are notified immediately when critical/high reports are classified
✅ **Priority-Based Filtering**: Only critical/high priority reports trigger notifications
✅ **Emergency Alert Style**: Always uses emergency sound and red notifications
✅ **Multiple Recipients**: All super users and admins receive notifications simultaneously
✅ **Rich Information**: Includes report type, location, response time, and priority level
✅ **Action Prompt**: Reminds super users to assign responders immediately

## How It Works

### 1. Notification Flow

```
User submits report with photo
    ↓
AI classifies report type and severity
    ↓
Report assigned priority & severity levels
    ↓
Is Critical/High? (Priority ≤ 2 OR Severity = CRITICAL/HIGH)
    ↓ YES
Push notification sent to all super users/admins
    ↓
Super user receives emergency alert
    ↓
Super user opens app and assigns responder
```

### 2. Trigger Criteria

Notifications are sent when a report meets **ANY** of these conditions:

| Condition | Description | Example |
|-----------|-------------|---------|
| Priority ≤ 2 | Priority level 1 or 2 | Fire (1), Medical (1), Accident (2) |
| Severity = 'CRITICAL' | Critical severity classification | High confidence fire detection |
| Severity = 'HIGH' | High severity classification | Medical emergency with people |

**Report Types That Typically Trigger Notifications:**
- 🔥 **Fire** - Always priority 1, critical
- 🚑 **Medical** - Always priority 1, critical
- 🚗 **Accident** - Priority 2, high (especially with people involved)
- 🏗️ **Earthquake** - Priority 1, critical
- 🌊 **Flood** - Priority 2, high (when severe)

### 3. Notification Content

**Example Notification:**
```
╔════════════════════════════════════════════╗
║ 🚨 NEW CRITICAL REPORT                     ║
║ ⚠️ REQUIRES IMMEDIATE ASSIGNMENT           ║
║                                             ║
║ FIRE report needs immediate attention      ║
║ • Response time: 5 minutes                 ║
║ • Location: 123 Main St, San Pablo City   ║
║                                             ║
║ [Tap to assign responder]                  ║
╚════════════════════════════════════════════╝
```

**Notification includes:**
- 🚨 Emergency icon based on report type
- Report type (FIRE, MEDICAL, etc.)
- "REQUIRES IMMEDIATE ASSIGNMENT" label
- Response time requirement
- Location (if available)
- All metadata for quick action

## Components

### 1. Backend Edge Function
**File**: `lspu_dres/supabase/functions/notify-superusers-critical-report/index.ts`

**Purpose**: Sends push notifications to all super users/admins when a critical report is created

**Key Features**:
- Fetches all users with 'super_user' or 'admin' role
- Filters for users with OneSignal player IDs
- Checks if report is critical/high priority
- Sends emergency-style push notifications
- Creates database notification records
- Non-blocking (won't fail classification if notification fails)

**Triggered By**: Called automatically by `classify-image` function after classifying a critical/high priority report

### 2. Classification Function Update
**File**: `lspu_dres/supabase/functions/classify-image/index.ts`

**Changes**:
- Added `notifySuperUsersIfCritical()` function
- Automatically calls notification function after classification
- Checks priority and severity before notifying
- Non-blocking (classification succeeds even if notification fails)

### 3. Mobile App Handler
**File**: `lspu_dres/mobile_app/lib/services/onesignal_service.dart`

**Changes**:
- Updated `_handleNotificationTap()` to handle `critical_report` type
- Updated `_handleNotificationReceived()` to always play emergency sound for critical reports
- Logs report details for debugging
- Ready for navigation integration

## Configuration

### Required Environment Variables

Make sure these are set in your Supabase Edge Functions:

```bash
ONESIGNAL_REST_API_KEY=your_rest_api_key
ONESIGNAL_APP_ID=your_app_id
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

### Database Requirements

**Users Table**: Must have `onesignal_player_id` column and role metadata
```sql
-- Check super users with OneSignal
SELECT 
  u.id, 
  u.email, 
  u.raw_user_meta_data->>'role' as role,
  u.onesignal_player_id
FROM auth.users u
WHERE u.raw_user_meta_data->>'role' IN ('super_user', 'admin')
AND u.onesignal_player_id IS NOT NULL;
```

**Notifications Table**: Stores notification history
```sql
SELECT * FROM notifications WHERE type = 'critical_report';
```

## Testing

### Test Critical Report Notification

1. **Login as a citizen** (or use mobile app)
2. **Submit a report** with an image showing fire, medical emergency, or accident
3. **Wait for AI classification** (5-10 seconds)
4. **Expected Result** (for super users):
   - Push notification received with 🚨 red styling
   - Emergency alert sound plays
   - Shows "REQUIRES IMMEDIATE ASSIGNMENT"
   - Shows report type, location, and response time
   - Notification persists until acknowledged

### Test Non-Critical Report

1. **Submit a report** with low priority type (environmental, storm)
2. **Wait for classification**
3. **Expected Result**:
   - No notification sent to super users
   - Report appears in system normally
   - Super users can still view and assign manually

### Testing Checklist

- [ ] Super user has OneSignal player ID saved in database
- [ ] Super user role is set correctly (`super_user` or `admin`)
- [ ] Submit critical report (fire, medical, accident)
- [ ] AI classifies report with critical/high priority
- [ ] Push notification received on super user's mobile device
- [ ] Emergency sound plays
- [ ] Notification shows correct report details
- [ ] Notification tap opens app (logs data)
- [ ] Database notification created

## Troubleshooting

### No Notification Received (Super User)

1. **Check Super User Role**:
```sql
SELECT email, raw_user_meta_data->>'role' as role
FROM auth.users
WHERE id = 'your_user_id';
```
Should return `super_user` or `admin`

2. **Check OneSignal Player ID**:
```sql
SELECT email, onesignal_player_id 
FROM auth.users 
WHERE raw_user_meta_data->>'role' IN ('super_user', 'admin');
```
Should have a valid player ID

3. **Check Report Priority**:
```sql
SELECT id, type, priority, severity 
FROM reports 
WHERE id = 'report_id';
```
Should have `priority <= 2` OR `severity IN ('CRITICAL', 'HIGH')`

4. **Check Edge Function Logs**:
```powershell
npx supabase functions logs notify-superusers-critical-report --limit 50
npx supabase functions logs classify-image --limit 50
```

### Notification for Non-Critical Report

If super users are receiving notifications for low-priority reports:

1. Check the priority calculation in `classify-image/index.ts`
2. Verify the report type and severity classification
3. Review AI classification confidence levels

### Multiple Notifications

This is expected behavior - all super users and admins receive the notification so anyone can assign the responder.

## SQL Helper Queries

### Check who will receive notifications
```sql
-- Get all super users and admins with push notifications enabled
SELECT 
  u.id,
  u.email,
  u.raw_user_meta_data->>'role' as role,
  u.onesignal_player_id,
  CASE WHEN u.onesignal_player_id IS NOT NULL 
    THEN '✅ Will receive' 
    ELSE '❌ No push' 
  END as notification_status
FROM auth.users u
WHERE u.raw_user_meta_data->>'role' IN ('super_user', 'admin')
ORDER BY u.email;
```

### Check recent critical reports
```sql
SELECT 
  r.id,
  r.type,
  r.priority,
  r.severity,
  r.created_at,
  r.status,
  CASE 
    WHEN r.priority <= 2 OR r.severity IN ('CRITICAL', 'HIGH')
    THEN '🚨 Notification sent'
    ELSE '🔔 No notification'
  END as notification_status
FROM reports r
ORDER BY r.created_at DESC
LIMIT 10;
```

### Check notification delivery
```sql
SELECT 
  n.id,
  n.type,
  n.title,
  n.message,
  n.read,
  n.created_at,
  u.email,
  u.raw_user_meta_data->>'role' as user_role
FROM notifications n
JOIN auth.users u ON n.user_id = u.id
WHERE n.type = 'critical_report'
ORDER BY n.created_at DESC
LIMIT 10;
```

## Performance Notes

- **Latency**: ~3-5 seconds from report submission to notification
  - Report submission: <1s
  - AI classification: 2-4s
  - Notification send: <1s
- **Reliability**: Non-blocking (won't fail report classification if notification fails)
- **Concurrency**: Supports multiple simultaneous critical reports
- **Scalability**: OneSignal handles rate limiting automatically
- **Battery Impact**: Minimal for recipients

## Workflow Example

### Scenario: Fire Report Submitted

```
09:00:00 - Citizen submits fire report with photo
09:00:01 - Report saved to database (status: pending)
09:00:02 - AI classification triggered
09:00:03 - Azure Vision analyzes image
09:00:04 - Classification: Fire, confidence: 0.95
09:00:05 - Priority: 1, Severity: CRITICAL
09:00:06 - Report status updated to "classified"
09:00:06 - notifySuperUsersIfCritical() called
09:00:07 - 3 super users found with OneSignal IDs
09:00:08 - Push notifications sent via OneSignal
09:00:09 - Database notifications created
09:00:10 - Super users receive notifications on phones
09:00:11 - Emergency sound plays
09:00:15 - Super user opens app
09:00:20 - Super user views report
09:00:30 - Super user assigns responder
```

## Security Considerations

1. **Role Verification**: Function checks user role before sending notifications
2. **Service Role**: Uses service role key to query all users securely
3. **Player ID Privacy**: OneSignal player IDs not exposed to clients
4. **Database Notifications**: All notifications logged for audit trail

## Future Enhancements

### TODO: Auto-Assignment
For extremely critical reports, automatically assign nearest available responder and notify both super user and responder.

### TODO: Escalation
If no super user responds within X minutes, escalate to all admins or trigger additional alerts.

### TODO: Analytics
Track super user response times, assignment rates, and notification effectiveness.

### TODO: Custom Filters
Allow super users to customize which types of critical reports they want to be notified about.

## API Reference

### Notify Super Users Function

**Endpoint**: `POST /functions/v1/notify-superusers-critical-report`

**Request Body**:
```json
{
  "report_id": "uuid"
}
```

**Response**:
```json
{
  "success": true,
  "sent": 3,
  "notified_users": 3,
  "report_type": "fire",
  "priority": 1,
  "severity": "CRITICAL",
  "message": "Push notification sent to 3 super users/admins"
}
```

**Error Response**:
```json
{
  "success": false,
  "error": "Report not found"
}
```

## Integration with Responder Assignment

Once a super user receives the notification and assigns a responder:

1. Super user notification alerts them of critical report
2. Super user opens app and views report details
3. Super user assigns responder from dashboard
4. **Responder receives assignment notification** (from previous feature)
5. Both notifications work together for complete emergency response workflow

## Support

For issues or questions:
1. Check Edge Function logs: `supabase functions logs`
2. Check mobile app logs: `flutter logs`
3. Verify super user roles in database
4. Verify OneSignal dashboard for delivery status
5. Review this documentation

## Summary

✅ **Super users notified immediately for critical/high reports**
✅ **Automatic detection based on priority and severity**
✅ **Emergency alert style (red, emergency sound)**
✅ **All super users/admins receive notification**
✅ **Non-blocking (won't fail classification)**
✅ **Database logging for audit trail**
✅ **Works seamlessly with responder assignment notifications**

The system ensures that urgent emergencies are brought to super users' attention immediately, enabling faster responder assignment and better emergency response times! 🚀

