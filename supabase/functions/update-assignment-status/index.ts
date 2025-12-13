import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { encode as base64Encode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID') || '8d6aa625-a650-47ac-b9ba-00a247840952'
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY') || ''

interface StatusUpdateRequest {
  assignment_id: string
  status: 'accepted' | 'enroute' | 'on_scene' | 'resolved'
  responder_id: string
  notes?: string
}

interface StatusUpdateResponse {
  assignment_id: string
  report_id: string
  responder_id: string
  previous_status: string
  new_status: string
  updated_at: string
  notes?: string
}

// Define valid status transitions
const VALID_TRANSITIONS: Record<string, string[]> = {
  'assigned': ['accepted'],
  'accepted': ['enroute'],
  'enroute': ['on_scene'],
  'on_scene': ['resolved'],
  'resolved': [] // Terminal state
}

// Map assignment status to report lifecycle status
const STATUS_TO_LIFECYCLE: Record<string, string> = {
  'accepted': 'accepted',
  'enroute': 'enroute',
  'on_scene': 'on_scene',
  'resolved': 'resolved'
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 405 
      }
    )
  }

  try {
    // Initialize Supabase client with service role
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Parse and validate request
    const requestData: StatusUpdateRequest = await req.json()
    validateStatusUpdateRequest(requestData)

    // Fetch current assignment data
    const currentAssignment = await fetchCurrentAssignment(supabaseClient, requestData.assignment_id)

    // Validate status transition
    validateStatusTransition(currentAssignment.status, requestData.status)

    // Verify responder authorization
    await verifyResponderAuthorization(supabaseClient, requestData.assignment_id, requestData.responder_id)

    // Execute status update transaction
    const result = await executeStatusUpdateTransaction(supabaseClient, requestData, currentAssignment)

    // Log audit event
    await logStatusUpdateAudit(supabaseClient, requestData, currentAssignment, result)

    // Send database notifications
    await sendStatusUpdateDatabaseNotifications(supabaseClient, result, currentAssignment)

    // Emit real-time notifications
    await emitStatusUpdateNotifications(supabaseClient, result, currentAssignment)

    // Send push notification
    await sendStatusUpdatePushNotification(supabaseClient, result, currentAssignment)

    return new Response(
      JSON.stringify({
        success: true,
        data: result,
        message: `Assignment status updated from ${currentAssignment.status} to ${requestData.status}`
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in update-assignment-status function:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})

/**
 * Validate status update request data
 */
function validateStatusUpdateRequest(data: StatusUpdateRequest): void {
  if (!data.assignment_id || typeof data.assignment_id !== 'string') {
    throw new Error('assignment_id is required and must be a string')
  }

  if (!data.status || typeof data.status !== 'string') {
    throw new Error('status is required and must be a string')
  }

  if (!data.responder_id || typeof data.responder_id !== 'string') {
    throw new Error('responder_id is required and must be a string')
  }

  // Validate UUID format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  if (!uuidRegex.test(data.assignment_id)) {
    throw new Error('assignment_id must be a valid UUID')
  }

  if (!uuidRegex.test(data.responder_id)) {
    throw new Error('responder_id must be a valid UUID')
  }

  // Validate status value
  const validStatuses = ['accepted', 'enroute', 'on_scene', 'resolved']
  if (!validStatuses.includes(data.status)) {
    throw new Error(`status must be one of: ${validStatuses.join(', ')}`)
  }

  // Validate notes if provided
  if (data.notes && typeof data.notes !== 'string') {
    throw new Error('notes must be a string if provided')
  }

  if (data.notes && data.notes.length > 1000) {
    throw new Error('notes must be 1000 characters or less')
  }
}

/**
 * Fetch current assignment data
 */
async function fetchCurrentAssignment(
  supabaseClient: any,
  assignmentId: string
): Promise<any> {
  const { data: assignment, error } = await supabaseClient
    .from('assignment')
    .select(`
      id,
      report_id,
      responder_id,
      status,
      assigned_at,
      accepted_at,
      enroute_at,
      on_scene_at,
      resolved_at,
      reports!report_id(
        id,
        lifecycle_status,
        type,
        message,
        location,
        reporter_uid,
        reporter_name,
        user_id
      )
    `)
    .eq('id', assignmentId)
    .single()

  if (error) {
    if (error.code === 'PGRST116') {
      throw new Error('Assignment not found')
    }
    throw new Error(`Failed to fetch assignment: ${error.message}`)
  }

  return assignment
}

/**
 * Validate status transition is allowed
 */
function validateStatusTransition(currentStatus: string, newStatus: string): void {
  const allowedTransitions = VALID_TRANSITIONS[currentStatus]
  
  if (!allowedTransitions) {
    throw new Error(`Invalid current status: ${currentStatus}`)
  }

  if (!allowedTransitions.includes(newStatus)) {
    throw new Error(
      `Invalid status transition from ${currentStatus} to ${newStatus}. ` +
      `Allowed transitions: ${allowedTransitions.join(', ')}`
    )
  }
}

/**
 * Verify responder is authorized to update this assignment
 */
async function verifyResponderAuthorization(
  supabaseClient: any,
  assignmentId: string,
  responderId: string
): Promise<void> {
  const { data: assignment, error } = await supabaseClient
    .from('assignment')
    .select('responder_id')
    .eq('id', assignmentId)
    .single()

  if (error) {
    throw new Error(`Failed to verify assignment: ${error.message}`)
  }

  if (assignment.responder_id !== responderId) {
    throw new Error('Responder is not authorized to update this assignment')
  }
}

/**
 * Execute status update transaction
 */
async function executeStatusUpdateTransaction(
  supabaseClient: any,
  requestData: StatusUpdateRequest,
  currentAssignment: any
): Promise<StatusUpdateResponse> {
  const updatedAt = new Date().toISOString()
  const reportId = currentAssignment.report_id
  const newLifecycleStatus = STATUS_TO_LIFECYCLE[requestData.status]

  // Prepare assignment update data
  const assignmentUpdateData: any = {
    status: requestData.status,
    updated_at: updatedAt
  }

  // Set timestamp fields based on status
  switch (requestData.status) {
    case 'accepted':
      assignmentUpdateData.accepted_at = updatedAt
      break
    case 'enroute':
      assignmentUpdateData.enroute_at = updatedAt
      break
    case 'on_scene':
      assignmentUpdateData.on_scene_at = updatedAt
      break
    case 'resolved':
      assignmentUpdateData.resolved_at = updatedAt
      break
  }

  // Add notes if provided
  if (requestData.notes) {
    assignmentUpdateData.notes = requestData.notes
  }

  // Update assignment
  const { data: updatedAssignment, error: assignmentError } = await supabaseClient
    .from('assignment')
    .update(assignmentUpdateData)
    .eq('id', requestData.assignment_id)
    .select()
    .single()

  if (assignmentError) {
    throw new Error(`Failed to update assignment: ${assignmentError.message}`)
  }

  // Prepare report update data
  const reportUpdateData: any = {
    lifecycle_status: newLifecycleStatus,
    last_update: updatedAt
  }

  // When assignment is resolved, also update the main status field to 'completed'
  if (requestData.status === 'resolved') {
    reportUpdateData.status = 'completed'
  }

  // Update report lifecycle status and main status if resolved
  const { error: reportError } = await supabaseClient
    .from('reports')
    .update(reportUpdateData)
    .eq('id', reportId)

  if (reportError) {
    // Rollback assignment update if report update fails
    await supabaseClient
      .from('assignment')
      .update({
        status: currentAssignment.status,
        updated_at: currentAssignment.updated_at
      })
      .eq('id', requestData.assignment_id)
    
    throw new Error(`Failed to update report: ${reportError.message}`)
  }

  return {
    assignment_id: requestData.assignment_id,
    report_id: reportId,
    responder_id: requestData.responder_id,
    previous_status: currentAssignment.status,
    new_status: requestData.status,
    updated_at: updatedAt,
    notes: requestData.notes
  }
}

/**
 * Log status update audit event
 */
async function logStatusUpdateAudit(
  supabaseClient: any,
  requestData: StatusUpdateRequest,
  currentAssignment: any,
  result: StatusUpdateResponse
): Promise<void> {
  try {
    await supabaseClient
      .from('audit_log')
      .insert({
        entity_type: 'assignment',
        entity_id: requestData.assignment_id,
        action: 'status_update',
        user_id: requestData.responder_id,
        details: {
          assignment_id: requestData.assignment_id,
          report_id: result.report_id,
          responder_id: requestData.responder_id,
          previous_status: result.previous_status,
          new_status: result.new_status,
          notes: requestData.notes,
          updated_at: result.updated_at,
          report_type: currentAssignment.reports?.type,
          report_location: currentAssignment.reports?.location
        },
        created_at: result.updated_at
      })
  } catch (error) {
    console.warn('Failed to log status update audit:', error)
    // Don't throw error as audit logging is not critical
  }
}

/**
 * Send database notifications for status updates
 */
async function sendStatusUpdateDatabaseNotifications(
  supabaseClient: any,
  result: StatusUpdateResponse,
  currentAssignment: any
): Promise<void> {
  try {
    const report = currentAssignment.reports
    // Use user_id (proper UUID) if available, otherwise fall back to reporter_uid
    const reporterUserId = report.user_id || report.reporter_uid

    console.log('Sending database notifications:', {
      report_id: result.report_id,
      reporter_user_id: report.user_id,
      reporter_uid: report.reporter_uid,
      using_user_id: reporterUserId,
      new_status: result.new_status
    })

    // Create notification payload
    const notificationData = {
      assignment_id: result.assignment_id,
      report_id: result.report_id,
      responder_id: result.responder_id,
      previous_status: result.previous_status,
      new_status: result.new_status,
      notes: result.notes,
      updated_at: result.updated_at,
      report_type: report.type,
      report_message: report.message,
      report_location: report.location
    }

    // Get admin users for notification
    const { data: admins } = await supabaseClient
      .from('responder')
      .select('user_id')
      .eq('role', 'admin')
      .limit(5)

    // Notify admins
    if (admins && admins.length > 0) {
      const adminNotifications = admins.map(admin => ({
        user_id: admin.user_id,
        type: 'assignment_status_update',
        title: 'Assignment Status Updated',
        message: `Assignment status changed from ${result.previous_status} to ${result.new_status}`,
        data: notificationData,
        read: false,
        created_at: result.updated_at
      }))

      const { error: adminError } = await supabaseClient
        .from('notifications')
        .insert(adminNotifications)

      if (adminError) {
        console.warn('Failed to insert admin notifications:', adminError)
      } else {
        console.log(`Inserted ${adminNotifications.length} admin notifications`)
      }
    }

    // Notify reporter if they have a user account
    if (reporterUserId) {
      // Create user-friendly status messages
      const statusMessages: Record<string, string> = {
        'accepted': 'A responder has accepted your emergency report',
        'enroute': 'A responder is on the way to your location',
        'on_scene': 'A responder has arrived at your location',
        'resolved': 'Your emergency report has been resolved'
      }

      const statusMessage = statusMessages[result.new_status] || 
        `Your report status has been updated to ${result.new_status}`

      const { error: reporterError } = await supabaseClient
        .from('notifications')
        .insert({
          user_id: reporterUserId,
          type: 'assignment_status_update',
          title: 'Your Report Update',
          message: statusMessage,
          data: notificationData,
          read: false,
          created_at: result.updated_at
        })

      if (reporterError) {
        console.warn('Failed to insert reporter notification:', reporterError, {
          user_id: reporterUserId,
          report_id: result.report_id
        })
      } else {
        console.log('Successfully inserted reporter notification for user:', reporterUserId)
      }
    } else {
      console.warn('No reporter user ID found - cannot send notification', {
        report_id: result.report_id,
        user_id: report.user_id,
        reporter_uid: report.reporter_uid
      })
    }

  } catch (error) {
    console.warn('Failed to send database notifications:', error)
    // Don't throw error as notifications are not critical
  }
}

/**
 * Emit real-time notifications for status updates
 */
async function emitStatusUpdateNotifications(
  supabaseClient: any,
  result: StatusUpdateResponse,
  currentAssignment: any
): Promise<void> {
  try {
    const report = currentAssignment.reports
    // Use user_id (proper UUID) if available, otherwise fall back to reporter_uid
    const reporterUserId = report.user_id || report.reporter_uid

    // Emit to responder's private channel
    await supabaseClient.realtime
      .channel(`private:responder:${result.responder_id}`)
      .send({
        type: 'broadcast',
        event: 'assignment.status_updated',
        payload: {
          assignment_id: result.assignment_id,
          report_id: result.report_id,
          responder_id: result.responder_id,
          previous_status: result.previous_status,
          new_status: result.new_status,
          updated_at: result.updated_at,
          notes: result.notes,
          report: {
            type: report.type,
            message: report.message,
            location: report.location
          }
        }
      })

    // Emit to reporter's private channel if they have a user account
    if (reporterUserId) {
      await supabaseClient.realtime
        .channel(`private:user:${reporterUserId}`)
        .send({
          type: 'broadcast',
          event: 'report.status_updated',
          payload: {
            report_id: result.report_id,
            assignment_id: result.assignment_id,
            previous_status: result.previous_status,
            new_status: result.new_status,
            lifecycle_status: STATUS_TO_LIFECYCLE[result.new_status],
            updated_at: result.updated_at,
            notes: result.notes,
            report: {
              type: report.type,
              message: report.message,
              location: report.location
            }
          }
        })
    }

    // Emit to admin channel
    await supabaseClient.realtime
      .channel('private:admin')
      .send({
        type: 'broadcast',
        event: 'assignment.status_updated',
        payload: {
          assignment_id: result.assignment_id,
          report_id: result.report_id,
          responder_id: result.responder_id,
          previous_status: result.previous_status,
          new_status: result.new_status,
          updated_at: result.updated_at,
          notes: result.notes,
          report: {
            type: report.type,
            message: report.message,
            location: report.location
          }
        }
      })

    // Emit report updated event to public channel
    await supabaseClient.realtime
      .channel('public:reports')
      .send({
        type: 'broadcast',
        event: 'report.updated',
        payload: {
          id: result.report_id,
          status: result.new_status,
          lifecycle_status: STATUS_TO_LIFECYCLE[result.new_status],
          type: report.type,
          lat: report.location?.lat,
          lng: report.location?.lng,
          responder_id: result.responder_id,
          last_update: result.updated_at
        }
      })

  } catch (error) {
    console.warn('Failed to emit status update notifications:', error)
    // Don't throw error as real-time events are not critical
  }
}

/**
 * Send push notification for status update
 */
async function sendStatusUpdatePushNotification(
  supabaseClient: any,
  result: StatusUpdateResponse,
  currentAssignment: any
): Promise<void> {
  try {
    const report = currentAssignment.reports
    // Use user_id (proper UUID) if available, otherwise fall back to reporter_uid
    const reporterUserId = report.user_id || report.reporter_uid

    console.log('Sending push notifications:', {
      report_id: result.report_id,
      reporter_user_id: report.user_id,
      reporter_uid: report.reporter_uid,
      using_user_id: reporterUserId,
      new_status: result.new_status
    })
    
    // Create user-friendly status messages
    const statusMessages: Record<string, { title: string, body: string }> = {
      'accepted': {
        title: 'Responder Accepted Your Report',
        body: 'A responder has accepted your emergency report and will be assisting you shortly.'
      },
      'enroute': {
        title: 'Help is on the Way',
        body: 'A responder is currently enroute to your location.'
      },
      'on_scene': {
        title: 'Responder Arrived',
        body: 'A responder has arrived at your location and is providing assistance.'
      },
      'resolved': {
        title: 'Report Resolved',
        body: 'Your emergency report has been successfully resolved.'
      }
    }

    const statusMessage = statusMessages[result.new_status] || {
      title: 'Report Status Updated',
      body: `Your report status has been updated to ${result.new_status}`
    }

    // Send push notification to responder
    const responderPushPayload = {
      title: 'Assignment Status Updated',
      body: `Status changed from ${result.previous_status} to ${result.new_status}`,
      icon: '/icon-192x192.png',
      data: {
        assignmentId: result.assignment_id,
        reportId: result.report_id,
        previousStatus: result.previous_status,
        newStatus: result.new_status,
        notes: result.notes,
        timestamp: result.updated_at
      }
    }

    const responderPushResponse = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/push-send`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        target: 'responder',
        responder_id: result.responder_id,
        payload: responderPushPayload
      })
    })

    if (!responderPushResponse.ok) {
      console.warn('Failed to send push notification to responder:', await responderPushResponse.text())
    } else {
      const pushResult = await responderPushResponse.json()
      console.log('Push notification sent to responder:', pushResult)
    }

    // Send push notification to reporter if they have a user account
    if (reporterUserId) {
      // Validate that reporterUserId is a valid UUID format
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      const isValidUuid = uuidRegex.test(reporterUserId)

      if (!isValidUuid) {
        console.warn('Reporter user ID is not a valid UUID, skipping push notification:', {
          reporter_user_id: reporterUserId,
          report_id: result.report_id
        })
      } else {
        const reporterPushPayload = {
          title: statusMessage.title,
          body: statusMessage.body,
          icon: '/icon-192x192.png',
          data: {
            reportId: result.report_id,
            assignmentId: result.assignment_id,
            newStatus: result.new_status,
            lifecycleStatus: STATUS_TO_LIFECYCLE[result.new_status],
            timestamp: result.updated_at
          }
        }

        console.log('Sending notifications to reporter:', {
          user_id: reporterUserId,
          report_id: result.report_id,
          new_status: result.new_status
        })

        // Send OneSignal notification directly for mobile devices (primary method)
        // This is the main notification method for mobile apps
        try {
          await sendOneSignalNotificationToReporter(
            supabaseClient,
            reporterUserId,
            statusMessage.title,
            statusMessage.body,
            {
              reportId: result.report_id,
              assignmentId: result.assignment_id,
              newStatus: result.new_status,
              lifecycleStatus: STATUS_TO_LIFECYCLE[result.new_status],
              timestamp: result.updated_at
            }
          )
        } catch (oneSignalError) {
          console.warn('OneSignal notification failed (non-critical):', oneSignalError)
        }

        // Also try web push (for web users, non-blocking)
        // This may fail if user doesn't have web push subscription, which is fine
        try {
          const reporterPushPayload = {
            title: statusMessage.title,
            body: statusMessage.body,
            icon: '/icon-192x192.png',
            data: {
              reportId: result.report_id,
              assignmentId: result.assignment_id,
              newStatus: result.new_status,
              lifecycleStatus: STATUS_TO_LIFECYCLE[result.new_status],
              timestamp: result.updated_at
            }
          }

          const reporterPushResponse = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/push-send`, {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              target: 'user',
              user_id: reporterUserId,
              payload: reporterPushPayload
            })
          })

          if (!reporterPushResponse.ok) {
            const errorText = await reporterPushResponse.text()
            console.warn('Web push notification failed (expected for mobile users):', {
              status: reporterPushResponse.status,
              error: errorText.substring(0, 200), // Limit error text length
              user_id: reporterUserId
            })
          } else {
            const pushResult = await reporterPushResponse.json()
            console.log('Web push notification sent to reporter:', pushResult)
          }
        } catch (webPushError) {
          // Web push is optional, so we just log and continue
          console.warn('Web push notification error (non-critical):', webPushError)
        }
      }
    } else {
      console.warn('No reporter user ID found - cannot send push notification', {
        report_id: result.report_id,
        user_id: report.user_id,
        reporter_uid: report.reporter_uid
      })
    }

  } catch (error) {
    console.warn('Failed to send push notification:', error)
    // Don't throw error as push notifications are not critical
  }
}

/**
 * Send OneSignal notification directly to reporter
 */
async function sendOneSignalNotificationToReporter(
  supabaseClient: any,
  reporterUserId: string,
  title: string,
  message: string,
  data: any
): Promise<void> {
  try {
    if (!ONESIGNAL_REST_API_KEY) {
      console.warn('ONESIGNAL_REST_API_KEY not configured, skipping OneSignal notification')
      return
    }

    // Get OneSignal player IDs for the reporter
    const { data: subscriptions, error: subError } = await supabaseClient
      .from('onesignal_subscriptions')
      .select('player_id, user_id')
      .eq('user_id', reporterUserId)

    if (subError) {
      console.warn('Error fetching OneSignal subscriptions for reporter:', subError)
      return
    }

    if (!subscriptions || subscriptions.length === 0) {
      console.warn('No OneSignal subscriptions found for reporter:', reporterUserId)
      return
    }

    const playerIds = subscriptions.map(s => s.player_id).filter(Boolean)
    
    if (playerIds.length === 0) {
      console.warn('No valid OneSignal player IDs found for reporter:', reporterUserId)
      return
    }

    console.log(`Sending OneSignal notification to ${playerIds.length} device(s) for reporter:`, {
      user_id: reporterUserId,
      player_ids_count: playerIds.length
    })

    // Determine if this is a critical status (resolved is important)
    const isImportant = data.newStatus === 'resolved' || data.newStatus === 'on_scene'
    const emoji = isImportant ? '✅' : '📢'

    // Build OneSignal payload
    const oneSignalPayload: any = {
      app_id: ONESIGNAL_APP_ID,
      include_player_ids: playerIds,
      headings: { en: `${emoji} ${title}` },
      contents: { en: message },
      data: {
        ...data,
        type: 'assignment_status_update'
      },
      // Android-specific settings
      android_channel_id: '62b67b1a-b2c2-4073-92c5-3b1d416a4720',
      ...(isImportant ? {
        android_sound: 'emergency_alert', // Custom sound for important updates
      } : {}),
      priority: isImportant ? 10 : 5,
      android_visibility: 1, // Public notification (show on lock screen)
      android_accent_color: isImportant ? '3b82f6' : '3b82f6', // Blue accent
      // iOS-specific settings
      ...(isImportant ? { ios_sound: 'emergency_alert.wav' } : {}),
      ios_badgeType: 'Increase',
      ios_badgeCount: 1,
      // Background notification support
      content_available: true,
    }

    // Determine auth header format based on API key type
    const isV2Key = ONESIGNAL_REST_API_KEY.startsWith('os_v2_app_')
    const authHeader = isV2Key 
      ? `Key ${ONESIGNAL_REST_API_KEY}`  // New v2 format
      : `Basic ${base64Encode(new TextEncoder().encode(`${ONESIGNAL_REST_API_KEY}:`))}`  // Legacy format

    const response = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader
      },
      body: JSON.stringify(oneSignalPayload)
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('OneSignal API error:', {
        status: response.status,
        statusText: response.statusText,
        error: errorText
      })
      throw new Error(`OneSignal API error: ${response.status} - ${errorText}`)
    }

    const result = await response.json()
    console.log('OneSignal notification sent successfully:', {
      id: result.id,
      recipients: result.recipients,
      user_id: reporterUserId
    })

  } catch (error) {
    console.error('Failed to send OneSignal notification to reporter:', error)
    // Don't throw - this is non-critical
  }
}

/*
 * ============================================================================
 * SAMPLE SQL UPDATES
 * ============================================================================
 * 
 * The function performs the following SQL operations:
 * 
 * 1. UPDATE assignment table:
 *    UPDATE assignment 
 *    SET status = 'enroute',
 *        enroute_at = '2025-01-13T10:30:00Z',
 *        updated_at = '2025-01-13T10:30:00Z',
 *        notes = 'Responder is on the way'
 *    WHERE id = 'assignment-uuid-here';
 * 
 * 2. UPDATE reports table:
 *    UPDATE reports 
 *    SET lifecycle_status = 'enroute',
 *        last_update = '2025-01-13T10:30:00Z'
 *    WHERE id = 'report-uuid-here';
 * 
 * 3. INSERT into audit_log:
 *    INSERT INTO audit_log (
 *        entity_type,
 *        entity_id,
 *        action,
 *        user_id,
 *        details,
 *        created_at
 *    ) VALUES (
 *        'assignment',
 *        'assignment-uuid-here',
 *        'status_update',
 *        'responder-uuid-here',
 *        '{
 *            "assignment_id": "assignment-uuid-here",
 *            "report_id": "report-uuid-here",
 *            "responder_id": "responder-uuid-here",
 *            "previous_status": "accepted",
 *            "new_status": "enroute",
 *            "notes": "Responder is on the way",
 *            "updated_at": "2025-01-13T10:30:00Z",
 *            "report_type": "emergency",
 *            "report_location": {"lat": 14.123, "lng": 121.456}
 *        }',
 *        '2025-01-13T10:30:00Z'
 *    );
 * 
 * ============================================================================
 * SAMPLE RESPONSE JSON
 * ============================================================================
 * 
 * Success Response:
 * {
 *   "success": true,
 *   "data": {
 *     "assignment_id": "123e4567-e89b-12d3-a456-426614174000",
 *     "report_id": "987fcdeb-51a2-43d1-9f12-345678901234",
 *     "responder_id": "456e7890-e89b-12d3-a456-426614174001",
 *     "previous_status": "accepted",
 *     "new_status": "enroute",
 *     "updated_at": "2025-01-13T10:30:00Z",
 *     "notes": "Responder is on the way"
 *   },
 *   "message": "Assignment status updated from accepted to enroute"
 * }
 * 
 * Error Response:
 * {
 *   "success": false,
 *   "error": "Invalid status transition from resolved to enroute. Allowed transitions: "
 * }
 * 
 * ============================================================================
 * USAGE EXAMPLES
 * ============================================================================
 * 
 * 1. Accept Assignment:
 *    curl -X POST https://your-project.supabase.co/functions/v1/update-assignment-status \
 *      -H "Authorization: Bearer YOUR_ANON_KEY" \
 *      -H "Content-Type: application/json" \
 *      -d '{
 *        "assignment_id": "123e4567-e89b-12d3-a456-426614174000",
 *        "status": "accepted",
 *        "responder_id": "456e7890-e89b-12d3-a456-426614174001"
 *      }'
 * 
 * 2. Update to En Route:
 *    curl -X POST https://your-project.supabase.co/functions/v1/update-assignment-status \
 *      -H "Authorization: Bearer YOUR_ANON_KEY" \
 *      -H "Content-Type: application/json" \
 *      -d '{
 *        "assignment_id": "123e4567-e89b-12d3-a456-426614174000",
 *        "status": "enroute",
 *        "responder_id": "456e7890-e89b-12d3-a456-426614174001",
 *        "notes": "Leaving station now"
 *      }'
 * 
 * 3. Mark as On Scene:
 *    curl -X POST https://your-project.supabase.co/functions/v1/update-assignment-status \
 *      -H "Authorization: Bearer YOUR_ANON_KEY" \
 *      -H "Content-Type: application/json" \
 *      -d '{
 *        "assignment_id": "123e4567-e89b-12d3-a456-426614174000",
 *        "status": "on_scene",
 *        "responder_id": "456e7890-e89b-12d3-a456-426614174001",
 *        "notes": "Arrived at location, assessing situation"
 *      }'
 * 
 * 4. Resolve Assignment:
 *    curl -X POST https://your-project.supabase.co/functions/v1/update-assignment-status \
 *      -H "Authorization: Bearer YOUR_ANON_KEY" \
 *      -H "Content-Type: application/json" \
 *      -d '{
 *        "assignment_id": "123e4567-e89b-12d3-a456-426614174000",
 *        "status": "resolved",
 *        "responder_id": "456e7890-e89b-12d3-a456-426614174001",
 *        "notes": "Incident resolved, no further action needed"
 *      }'
 * 
 * ============================================================================
 */
