# Supabase Realtime Channels Guide

## Channel Structure

### 1. Public Reports Channel
**Channel:** `public:reports`  
**Purpose:** Public updates for all report changes  
**Access:** Open to all authenticated users

### 2. Private Responder Channels
**Channel:** `private:responder:<responder_id>`  
**Purpose:** Personal notifications for specific responders  
**Access:** Only the assigned responder

### 3. Private Admin Channel
**Channel:** `private:admin`  
**Purpose:** Administrative notifications for all system changes  
**Access:** Users with admin role

## Event Types & Payloads

### Public Reports Channel Events

#### `report.created`
```json
{
  "type": "broadcast",
  "event": "report.created",
  "payload": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "status": "pending",
    "lifecycle_status": "pending",
    "type": "fire",
    "lat": 14.3042,
    "lng": 121.413,
    "message": "Fire emergency at building",
    "reporter_name": "John Doe",
    "created_at": "2025-01-13T10:30:00.000Z",
    "confidence": null,
    "has_image": true
  }
}
```

#### `report.updated`
```json
{
  "type": "broadcast",
  "event": "report.updated",
  "payload": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "status": "classified",
    "lifecycle_status": "assigned",
    "type": "fire",
    "lat": 14.3042,
    "lng": 121.413,
    "ai_confidence": 0.95,
    "ai_model": "emergency-classifier-v2",
    "responder_id": "123e4567-e89b-12d3-a456-426614174001",
    "last_update": "2025-01-13T10:35:00.000Z"
  }
}
```

### Private Responder Channel Events

#### `assignment.created`
```json
{
  "type": "broadcast",
  "event": "assignment.created",
  "payload": {
    "assignment_id": "123e4567-e89b-12d3-a456-426614174002",
    "report_id": "123e4567-e89b-12d3-a456-426614174000",
    "responder_id": "123e4567-e89b-12d3-a456-426614174001",
    "status": "assigned",
    "assigned_at": "2025-01-13T10:30:00.000Z",
    "report": {
      "type": "fire",
      "message": "Fire emergency at building",
      "location": {
        "lat": 14.3042,
        "lng": 121.413
      },
      "created_at": "2025-01-13T10:25:00.000Z"
    },
    "priority": "high"
  }
}
```

#### `assignment.updated`
```json
{
  "type": "broadcast",
  "event": "assignment.updated",
  "payload": {
    "assignment_id": "123e4567-e89b-12d3-a456-426614174002",
    "report_id": "123e4567-e89b-12d3-a456-426614174000",
    "responder_id": "123e4567-e89b-12d3-a456-426614174001",
    "status": "accepted",
    "accepted_at": "2025-01-13T10:32:00.000Z",
    "action": "accept",
    "timestamp": "2025-01-13T10:32:00.000Z"
  }
}
```

### Private Admin Channel Events

#### `assignment.created` (Admin)
```json
{
  "type": "broadcast",
  "event": "assignment.created",
  "payload": {
    "assignment_id": "123e4567-e89b-12d3-a456-426614174002",
    "report_id": "123e4567-e89b-12d3-a456-426614174000",
    "responder_id": "123e4567-e89b-12d3-a456-426614174001",
    "assigned_by": "123e4567-e89b-12d3-a456-426614174003",
    "status": "assigned",
    "assigned_at": "2025-01-13T10:30:00.000Z",
    "report": {
      "type": "fire",
      "message": "Fire emergency at building",
      "location": {
        "lat": 14.3042,
        "lng": 121.413
      },
      "reporter_name": "John Doe"
    }
  }
}
```

#### `assignment.updated` (Admin)
```json
{
  "type": "broadcast",
  "event": "assignment.updated",
  "payload": {
    "assignment_id": "123e4567-e89b-12d3-a456-426614174002",
    "report_id": "123e4567-e89b-12d3-a456-426614174000",
    "responder_id": "123e4567-e89b-12d3-a456-426614174001",
    "status": "accepted",
    "action": "accept",
    "timestamp": "2025-01-13T10:32:00.000Z",
    "responder_name": "Firefighter Smith"
  }
}
```

## Client Subscription Examples

### Basic Setup
```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://your-project.supabase.co',
  'your-anon-key'
)
```

### 1. Public Reports Channel
```javascript
// Subscribe to all report updates
const reportsChannel = supabase
  .channel('public:reports')
  .on('broadcast', { event: 'report.created' }, (payload) => {
    console.log('New report created:', payload)
    // Update map with new marker
    addReportMarker(payload)
  })
  .on('broadcast', { event: 'report.updated' }, (payload) => {
    console.log('Report updated:', payload)
    // Update existing marker or status
    updateReportMarker(payload)
  })
  .subscribe()

// Cleanup
// reportsChannel.unsubscribe()
```

### 2. Private Responder Channel
```javascript
// Subscribe to personal responder notifications
const responderId = '123e4567-e89b-12d3-a456-426614174001'
const responderChannel = supabase
  .channel(`private:responder:${responderId}`)
  .on('broadcast', { event: 'assignment.created' }, (payload) => {
    console.log('New assignment:', payload)
    // Show assignment notification
    showAssignmentNotification(payload)
  })
  .on('broadcast', { event: 'assignment.updated' }, (payload) => {
    console.log('Assignment updated:', payload)
    // Update assignment status
    updateAssignmentStatus(payload)
  })
  .subscribe()
```

### 3. Private Admin Channel
```javascript
// Subscribe to admin notifications
const adminChannel = supabase
  .channel('private:admin')
  .on('broadcast', { event: 'assignment.created' }, (payload) => {
    console.log('Assignment created (admin):', payload)
    // Update admin dashboard
    updateAdminDashboard(payload)
  })
  .on('broadcast', { event: 'assignment.updated' }, (payload) => {
    console.log('Assignment updated (admin):', payload)
    // Update admin dashboard
    updateAdminDashboard(payload)
  })
  .on('broadcast', { event: 'report.created' }, (payload) => {
    console.log('Report created (admin):', payload)
    // Update admin dashboard
    updateAdminDashboard(payload)
  })
  .on('broadcast', { event: 'report.updated' }, (payload) => {
    console.log('Report updated (admin):', payload)
    // Update admin dashboard
    updateAdminDashboard(payload)
  })
  .subscribe()
```

### 4. Complete Client Implementation
```javascript
class EmergencyResponseClient {
  constructor(supabaseClient, userId, userRole) {
    this.supabase = supabaseClient
    this.userId = userId
    this.userRole = userRole
    this.channels = new Map()
  }

  async initialize() {
    // Always subscribe to public reports
    this.subscribeToReports()
    
    // Subscribe based on user role
    if (this.userRole === 'responder') {
      this.subscribeToResponderChannel()
    }
    
    if (this.userRole === 'admin') {
      this.subscribeToAdminChannel()
    }
  }

  subscribeToReports() {
    const channel = this.supabase
      .channel('public:reports')
      .on('broadcast', { event: 'report.created' }, this.handleReportCreated.bind(this))
      .on('broadcast', { event: 'report.updated' }, this.handleReportUpdated.bind(this))
      .subscribe()
    
    this.channels.set('reports', channel)
  }

  subscribeToResponderChannel() {
    const channel = this.supabase
      .channel(`private:responder:${this.userId}`)
      .on('broadcast', { event: 'assignment.created' }, this.handleAssignmentCreated.bind(this))
      .on('broadcast', { event: 'assignment.updated' }, this.handleAssignmentUpdated.bind(this))
      .subscribe()
    
    this.channels.set('responder', channel)
  }

  subscribeToAdminChannel() {
    const channel = this.supabase
      .channel('private:admin')
      .on('broadcast', { event: '*' }, this.handleAdminEvent.bind(this))
      .subscribe()
    
    this.channels.set('admin', channel)
  }

  handleReportCreated(payload) {
    console.log('New report:', payload)
    // Update UI with new report
  }

  handleReportUpdated(payload) {
    console.log('Report updated:', payload)
    // Update UI with report changes
  }

  handleAssignmentCreated(payload) {
    console.log('New assignment:', payload)
    // Show assignment notification
    this.showNotification('New Assignment', `You have been assigned to a ${payload.report.type} report`)
  }

  handleAssignmentUpdated(payload) {
    console.log('Assignment updated:', payload)
    // Update assignment status in UI
  }

  handleAdminEvent(payload) {
    console.log('Admin event:', payload)
    // Update admin dashboard
  }

  showNotification(title, message) {
    // Implement notification display
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(title, { body: message })
    }
  }

  cleanup() {
    this.channels.forEach(channel => channel.unsubscribe())
    this.channels.clear()
  }
}

// Usage
const client = new EmergencyResponseClient(supabase, userId, userRole)
await client.initialize()
```

## Channel Security

### RLS Policies for Realtime
```sql
-- Allow authenticated users to subscribe to public reports
CREATE POLICY "Allow authenticated users to subscribe to reports" ON public.reports
    FOR SELECT 
    TO authenticated 
    USING (true);

-- Allow responders to subscribe to their own channel
CREATE POLICY "Allow responders to subscribe to own channel" ON public.responder
    FOR SELECT 
    TO authenticated 
    USING (user_id = auth.uid());

-- Allow admins to subscribe to admin channel
CREATE POLICY "Allow admins to subscribe to admin channel" ON public.assignment
    FOR SELECT 
    TO authenticated 
    USING (public.is_admin());
```

## Event Flow Summary

1. **Report Created** → `public:reports` → All users + `private:admin`
2. **Assignment Created** → `private:responder:<id>` + `private:admin`
3. **Assignment Updated** → `private:responder:<id>` + `private:admin`
4. **Report Updated** → `public:reports` + `private:admin`

This structure provides real-time updates for all stakeholders while maintaining proper access control and security.
