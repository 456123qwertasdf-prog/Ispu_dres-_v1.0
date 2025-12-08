# Responder Push Notifications Setup

## Overview

This document describes the push notification system for responders when they are assigned to emergency reports by admins or super users. The system automatically sends push notifications with special handling for critical and high-priority reports.

## Features

✅ **Automatic Push Notifications**: Responders receive instant push notifications when assigned to a report
✅ **Priority-Based Alerts**: Critical/high priority reports trigger emergency sounds and red notifications
✅ **Rich Notification Data**: Includes report type, location, response time, and priority level
✅ **Cross-Platform**: Works on both Android and iOS (when configured)
✅ **Persistent for Critical**: Critical assignments are grouped and persistent until acknowledged

## How It Works

### 1. Assignment Flow

```
Admin/Super User assigns responder
    ↓
Assignment created in database
    ↓
Push notification sent via OneSignal
    ↓
Responder receives notification on mobile device
    ↓
Responder taps notification → Opens assignment/report details
```

### 2. Priority Levels

The system recognizes the following priority levels:

| Priority | Severity | Notification Style | Sound |
|----------|----------|-------------------|-------|
| 1-2 | CRITICAL, HIGH | 🚨 Red, High Priority | Emergency Alert |
| 3 | MEDIUM | 🔔 Orange, Normal | Default |
| 4 | LOW | 🔔 Orange, Normal | Default |

### 3. Notification Content

**Critical/High Priority Example:**
```
🚨 New Assignment - 🚨 CRITICAL/HIGH PRIORITY
You have been assigned to a FIRE report
• Response time: 5 minutes
• Location: [Address]
```

**Normal Priority Example:**
```
🔔 New Assignment
You have been assigned to a FLOOD report
• Response time: 15 minutes
• Location: [Address]
```

## Components

### 1. Backend Edge Function
**File**: `lspu_dres/supabase/functions/notify-responder-assignment/index.ts`

**Purpose**: Sends push notifications to responders via OneSignal

**Key Features**:
- Fetches report details (type, priority, severity, location)
- Gets responder's OneSignal player ID
- Determines if assignment is critical/high priority
- Sends customized push notification
- Logs notification in database

**Triggered By**: Called automatically by `assign-responder` function after assignment creation

### 2. Assignment Function Update
**File**: `lspu_dres/supabase/functions/assign-responder/index.ts`

**Changes**:
- Added `sendPushNotificationToResponder()` function
- Automatically calls notification function after assignment creation
- Non-blocking (won't fail assignment if notification fails)

### 3. Mobile App Handler
**File**: `lspu_dres/mobile_app/lib/services/onesignal_service.dart`

**Changes**:
- Updated `_handleNotificationTap()` to handle assignment notifications
- Updated `_handleNotificationReceived()` to play appropriate sounds:
  - Emergency sound for critical/high priority
  - Default sound for normal priority
- Logs notification details for debugging

## Configuration

### Required Environment Variables

Make sure these are set in your Supabase Edge Functions:

```bash
ONESIGNAL_REST_API_KEY=your_rest_api_key
ONESIGNAL_APP_ID=your_app_id
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

### OneSignal Setup

1. **Android Channel**: Already configured with ID `62b67b1a-b2c2-4073-92c5-3b1d416a4720`
2. **Emergency Sound**: Custom sound file `emergency_alert.mp3` for critical assignments
3. **Player IDs**: Automatically saved when responders login to mobile app

### Database Requirements

**Users Table**: Must have `onesignal_player_id` column
```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS onesignal_player_id TEXT;
```

**Notifications Table**: Stores notification history
```sql
-- Already exists in your schema
SELECT * FROM notifications WHERE type = 'assignment_created';
```

## Testing

### Test Critical/High Priority Assignment

1. **Create a high-priority report** (Fire, Medical, or set priority to 1-2)
2. **Assign to a responder** via admin/super user dashboard
3. **Expected Result**:
   - Responder receives push notification with 🚨 red styling
   - Emergency alert sound plays (if sound enabled)
   - Notification shows "CRITICAL/HIGH PRIORITY" label
   - Notification persists until acknowledged

### Test Normal Priority Assignment

1. **Create a normal-priority report** (Environmental, or set priority to 3-4)
2. **Assign to a responder** via admin/super user dashboard
3. **Expected Result**:
   - Responder receives push notification with 🔔 orange styling
   - Default notification sound plays
   - Notification shows standard assignment message

### Testing Checklist

- [ ] Responder has OneSignal player ID saved in database
- [ ] Assignment creates notification in `notifications` table
- [ ] Push notification received on mobile device
- [ ] Notification tap opens app (currently logs, navigation TODO)
- [ ] Critical assignments play emergency sound
- [ ] Normal assignments play default sound
- [ ] Notification includes report type, location, and response time

## Troubleshooting

### No Notification Received

1. **Check OneSignal Player ID**:
```sql
SELECT id, name, user_id FROM responder WHERE id = 'responder_id';
SELECT id, onesignal_player_id FROM users WHERE id = 'user_id';
```

2. **Check Edge Function Logs**:
```bash
supabase functions logs notify-responder-assignment
```

3. **Verify OneSignal Configuration**:
- App ID matches in mobile app and environment variables
- REST API key is valid (starts with `os_v2_app_` or legacy format)
- Check OneSignal dashboard for delivery status

### Notification Received but No Sound

1. **Check Device Settings**:
   - Notification permissions enabled
   - Sound enabled for app notifications
   - Do Not Disturb mode disabled

2. **Check App Settings**:
```dart
final soundService = NotificationSoundService();
final isEnabled = soundService.isSoundEnabled;
```

3. **Verify Sound Files**:
   - `emergency_alert.mp3` exists in `android/app/src/main/res/raw/`
   - Sound file name matches in OneSignal payload

### Wrong Sound Playing

Check the priority and severity values:
```sql
SELECT id, type, priority, severity FROM reports WHERE id = 'report_id';
```

Critical assignments should have:
- `priority <= 2` OR `severity = 'CRITICAL'` OR `severity = 'HIGH'`

## Future Enhancements

### TODO: Navigation from Notification
Currently, tapping a notification only logs the data. To add navigation:

1. Create a `NavigationService` with a global navigator key
2. Update `_handleNotificationTap()` in `onesignal_service.dart`:
```dart
if (type == 'assignment') {
  NavigationService.navigateToAssignment(assignmentId);
}
```

3. Create assignment detail screen if not exists

### TODO: Notification Actions
Add quick actions to notifications:
- "Accept Assignment" button
- "Decline Assignment" button
- "View on Map" button

### TODO: Notification Grouping
Group multiple assignments for the same responder:
- Show count of pending assignments
- Group by priority (critical vs normal)

## API Reference

### Notify Responder Assignment Function

**Endpoint**: `POST /functions/v1/notify-responder-assignment`

**Request Body**:
```json
{
  "assignment_id": "uuid",
  "responder_id": "uuid",
  "report_id": "uuid"
}
```

**Response**:
```json
{
  "success": true,
  "sent": 1,
  "is_critical": true,
  "responder_name": "John Doe",
  "report_type": "fire",
  "message": "Push notification sent successfully"
}
```

## Support

For issues or questions:
1. Check Edge Function logs: `supabase functions logs`
2. Check mobile app logs: `flutter logs`
3. Verify OneSignal dashboard for delivery status
4. Review this documentation

## Summary

✅ **Push notifications for responder assignments implemented**
✅ **Priority-based alert system (critical/high vs normal)**
✅ **Automatic notification sending on assignment creation**
✅ **Mobile app sound handling based on priority**
✅ **Database logging for notification history**
✅ **Non-blocking (won't fail assignments if notifications fail)**

The system is production-ready and will automatically notify responders when assigned to reports, with special handling for critical and high-priority emergencies! 🚀

