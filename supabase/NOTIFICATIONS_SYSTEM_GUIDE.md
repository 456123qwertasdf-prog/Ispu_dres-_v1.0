# Notifications System Guide

## Database Schema

### Notifications Table
```sql
CREATE TABLE public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    target_type text NOT NULL CHECK (target_type IN ('responder', 'reporter', 'admin')),
    target_id uuid NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    payload jsonb,
    is_read boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
```

### Key Features
- **Multi-target support**: responder, reporter, admin
- **Rich payloads**: JSONB for complex notification data
- **Read status tracking**: Boolean flag with timestamps
- **RLS security**: Users can only access their own notifications
- **Performance indexes**: Optimized for common queries

## Edge Functions

### 1. List Notifications (`/functions/v1/notifications/list`)

**Purpose**: Retrieve paginated notifications for a user

**Methods**: GET, POST

**Parameters**:
- `target_type` (required): 'responder' | 'reporter' | 'admin'
- `target_id` (optional): Specific target ID (auto-resolved if not provided)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20, max: 100)
- `unread_only` (optional): Filter to unread notifications only
- `type` (optional): Filter by notification type

**Example Requests**:

**GET Request**:
```javascript
const response = await fetch('/functions/v1/notifications/list?target_type=responder&page=1&limit=10&unread_only=true', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
})
```

**POST Request**:
```javascript
const response = await fetch('/functions/v1/notifications/list', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    target_type: 'responder',
    page: 1,
    limit: 20,
    unread_only: true,
    type: 'assignment_created'
  })
})
```

**Response**:
```json
{
  "notifications": [
    {
      "id": "uuid",
      "target_type": "responder",
      "target_id": "uuid",
      "type": "assignment_created",
      "title": "New Assignment",
      "message": "You have been assigned to a fire emergency report",
      "payload": {
        "assignment_id": "uuid",
        "report_id": "uuid",
        "report_type": "fire",
        "priority": "high"
      },
      "is_read": false,
      "created_at": "2025-01-13T10:30:00.000Z",
      "updated_at": "2025-01-13T10:30:00.000Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 45,
    "total_pages": 3,
    "has_next": true,
    "has_prev": false
  }
}
```

### 2. Mark Read (`/functions/v1/notifications/mark-read`)

**Purpose**: Mark notifications as read

**Method**: POST

**Parameters**:
- `notification_ids` (optional): Array of specific notification IDs
- `target_type` (optional): Target type for bulk operations
- `target_id` (optional): Target ID for bulk operations
- `mark_all` (optional): Mark all notifications as read
- `type` (optional): Filter by notification type for bulk operations

**Example Requests**:

**Mark Specific Notifications**:
```javascript
const response = await fetch('/functions/v1/notifications/mark-read', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    notification_ids: ['uuid1', 'uuid2', 'uuid3']
  })
})
```

**Mark All Notifications**:
```javascript
const response = await fetch('/functions/v1/notifications/mark-read', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    target_type: 'responder',
    mark_all: true
  })
})
```

**Mark All of Specific Type**:
```javascript
const response = await fetch('/functions/v1/notifications/mark-read', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    target_type: 'responder',
    mark_all: true,
    type: 'assignment_created'
  })
})
```

**Response**:
```json
{
  "success": true,
  "updated_count": 5,
  "message": "Successfully marked 5 notification(s) as read"
}
```

## Usage Examples

### Client Implementation

```javascript
class NotificationManager {
  constructor(supabaseClient, userRole, userId) {
    this.supabase = supabaseClient
    this.userRole = userRole
    this.userId = userId
  }

  async getNotifications(page = 1, limit = 20, unreadOnly = false) {
    const response = await this.supabase.functions.invoke('notifications/list', {
      body: {
        target_type: this.userRole,
        page,
        limit,
        unread_only: unreadOnly
      }
    })
    
    if (response.error) throw response.error
    return response.data
  }

  async markAsRead(notificationIds) {
    const response = await this.supabase.functions.invoke('notifications/mark-read', {
      body: {
        notification_ids: notificationIds
      }
    })
    
    if (response.error) throw response.error
    return response.data
  }

  async markAllAsRead() {
    const response = await this.supabase.functions.invoke('notifications/mark-read', {
      body: {
        target_type: this.userRole,
        mark_all: true
      }
    })
    
    if (response.error) throw response.error
    return response.data
  }

  async getUnreadCount() {
    const response = await this.getNotifications(1, 1, true)
    return response.pagination.total
  }
}

// Usage
const notificationManager = new NotificationManager(supabase, 'responder', userId)

// Get first page of notifications
const notifications = await notificationManager.getNotifications(1, 20)

// Get only unread notifications
const unreadNotifications = await notificationManager.getNotifications(1, 20, true)

// Mark specific notifications as read
await notificationManager.markAsRead(['uuid1', 'uuid2'])

// Mark all notifications as read
await notificationManager.markAllAsRead()

// Get unread count
const unreadCount = await notificationManager.getUnreadCount()
```

### Real-time Integration

```javascript
// Subscribe to real-time notifications
const notificationsChannel = supabase
  .channel('notifications')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'notifications',
    filter: `target_id=eq.${userId}`
  }, (payload) => {
    console.log('New notification:', payload.new)
    // Update UI with new notification
    addNotificationToUI(payload.new)
  })
  .subscribe()
```

## Notification Types

### Assignment Notifications
- **Type**: `assignment_created`
- **Target**: `responder`
- **Payload**: Assignment details, report context, priority

### Report Notifications
- **Type**: `report_created`
- **Target**: `admin`
- **Payload**: Report details, location, reporter info

### Status Update Notifications
- **Type**: `assignment_updated`
- **Target**: `responder`, `admin`
- **Payload**: Status change, timestamp, action

## Security Features

### Row Level Security (RLS)
- Users can only access their own notifications
- Automatic target_id resolution based on user role
- Secure query building with proper authorization

### Input Validation
- UUID format validation for notification IDs
- Pagination limits (max 100 items per page)
- Required field validation
- Type checking for all parameters

### Error Handling
- Comprehensive error messages
- Proper HTTP status codes
- Graceful failure handling
- Audit logging for security events

## Performance Optimizations

### Database Indexes
- `target_type, target_id` - Primary lookup
- `is_read` - Filter unread notifications
- `created_at` - Order by timestamp
- `type` - Filter by notification type

### Query Optimization
- Efficient pagination with range queries
- Minimal data selection
- Proper ordering for performance
- Count queries for pagination metadata

This notifications system provides a complete solution for managing user notifications with proper security, performance, and real-time capabilities.
