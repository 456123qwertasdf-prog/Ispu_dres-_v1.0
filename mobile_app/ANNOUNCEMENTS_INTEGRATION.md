# Announcements Integration Guide

## How Announcements Flow from Admin Panel to Mobile App

### 1. Admin Creates Announcement
- Admin goes to `announcements.html`
- Creates a new announcement with:
  - Title
  - Message
  - Type (emergency, weather, general, maintenance, safety)
  - Priority
  - Status (must be "active" to appear in mobile app)
- Announcement is saved to Supabase `announcements` table

### 2. Mobile App Syncs Announcements
The mobile app automatically syncs announcements in several ways:

#### On Screen Load
- When `NotificationsScreen` opens, it calls `_loadNotificationsWithSync()`
- This syncs announcements from Supabase first, then loads notifications

#### Periodic Sync
- Every 2 minutes, the app automatically syncs announcements
- This simulates real-time updates (like the web app)

#### On App Resume
- When the app comes back to foreground, it syncs announcements

#### Manual Sync
- User can pull-to-refresh to manually sync
- User can click "Sync Announcements" button in empty state

### 3. Announcements Converted to Notifications
- `NotificationService.syncAnnouncements()` fetches active announcements
- Filters for `status='active'` and checks expiration dates
- Converts each announcement to a `NotificationModel` with:
  - ID: `announcement_{announcement_id}`
  - Title: Formatted with emoji icon (🚨, 🌤️, 📢, 🔧, 🛡️)
  - Message: From announcement message
  - Type: Formatted type (Emergency, Weather, etc.)
  - Icon: Based on announcement type (error, warning, info)
  - Timestamp: From announcement `created_at`
  - Read status: Preserved if notification already exists

### 4. Notifications Displayed
- All notifications (including announcements) are displayed in `NotificationsScreen`
- Sorted by timestamp (newest first)
- Announcement notifications have emoji icons in the title
- Emergency announcements (especially FIRE) include Report ID in message

## Troubleshooting

### Announcements Not Appearing?

1. **Check Announcement Status**
   - Announcement must have `status='active'` in database
   - Check expiration date - must be in future or null

2. **Check RLS Policies**
   - Ensure anonymous/authenticated users can read announcements
   - Run migration: `supabase/migrations/20250121_allow_anonymous_announcements.sql`

3. **Check Sync Logs**
   - Look for debug prints in console:
     - `🔄 Starting announcement sync...`
     - `✅ Synced X announcements`
     - `📱 Loaded X notifications`

4. **Manual Sync**
   - Pull down to refresh on notifications screen
   - Or click "Sync Announcements" button

5. **Check Network**
   - Ensure mobile app can reach Supabase API
   - Check Supabase URL and API key in `notification_service.dart`

## Code Flow

```
Admin Panel (announcements.html)
    ↓ Creates announcement
Supabase `announcements` table
    ↓ Mobile app syncs
NotificationService.syncAnnouncements()
    ↓ Converts to notifications
SharedPreferences (user-notifications)
    ↓ Loads and displays
NotificationsScreen
    ↓ Shows to user
Mobile App UI
```

## Key Files

- `mobile_app/lib/services/notification_service.dart` - Syncs announcements
- `mobile_app/lib/screens/notifications_screen.dart` - Displays notifications
- `public/announcements.html` - Admin creates announcements
- `public/user.html` - Web app notification system (reference)

