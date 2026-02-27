import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { encode as base64Encode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID') || '8d6aa625-a650-47ac-b9ba-00a247840952'
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY') || ''

interface AcceptAssignmentRequest {
  assignment_id: string
  responder_id: string
  action: 'accept' | 'decline'
}

interface AssignmentResult {
  assignment_id: string
  report_id: string
  responder_id: string
  status: string
  action: string
  timestamp: string
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
    const requestData: AcceptAssignmentRequest = await req.json()
    validateAcceptAssignmentRequest(requestData)

    // Get assignment details and validate
    const assignment = await getAssignmentDetails(supabaseClient, requestData.assignment_id)
    validateAssignmentAction(assignment, requestData.responder_id, requestData.action)

    // Execute the action (accept or decline)
    const result = await executeAssignmentAction(supabaseClient, requestData, assignment)

    // Send notifications
    await sendActionNotifications(supabaseClient, result, assignment)

    // Emit real-time events
    await emitAssignmentUpdatedEvent(supabaseClient, result, assignment)

    // Log audit event
    await logAssignmentActionAudit(supabaseClient, requestData, result)

    return new Response(
      JSON.stringify({
        success: true,
        assignment: result,
        message: `Assignment ${requestData.action}ed successfully`
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in accept-assignment function:', error)
    
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
 * Validate accept assignment request data
 */
function validateAcceptAssignmentRequest(data: AcceptAssignmentRequest): void {
  if (!data.assignment_id || typeof data.assignment_id !== 'string') {
    throw new Error('assignment_id is required and must be a string')
  }

  if (!data.responder_id || typeof data.responder_id !== 'string') {
    throw new Error('responder_id is required and must be a string')
  }

  if (!data.action || !['accept', 'decline'].includes(data.action)) {
    throw new Error('action must be either "accept" or "decline"')
  }

  // Validate UUID format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  if (!uuidRegex.test(data.assignment_id)) {
    throw new Error('assignment_id must be a valid UUID')
  }

  if (!uuidRegex.test(data.responder_id)) {
    throw new Error('responder_id must be a valid UUID')
  }
}

/**
 * Get assignment details and validate
 */
async function getAssignmentDetails(
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
      completed_at,
      reports!report_id(
        id,
        type,
        message,
        location,
        reporter_uid,
        reporter_name,
        lifecycle_status,
        created_at
      ),
      responder!responder_id(id, name)
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
 * Validate assignment action
 */
function validateAssignmentAction(
  assignment: any,
  responderId: string,
  action: string
): void {
  // Check if assignment belongs to the responder
  if (assignment.responder_id !== responderId) {
    throw new Error('Assignment does not belong to this responder')
  }

  // Check if assignment is in a valid state for action
  if (assignment.status !== 'assigned') {
    throw new Error(`Assignment cannot be ${action}ed. Current status: ${assignment.status}`)
  }

  // Check if report is still active
  if (assignment.reports.lifecycle_status === 'resolved' || 
      assignment.reports.lifecycle_status === 'closed') {
    throw new Error('Cannot modify assignment for resolved or closed report')
  }
}

/**
 * Execute assignment action (accept or decline)
 */
async function executeAssignmentAction(
  supabaseClient: any,
  requestData: AcceptAssignmentRequest,
  assignment: any
): Promise<AssignmentResult> {
  const timestamp = new Date().toISOString()

  if (requestData.action === 'accept') {
    return await acceptAssignment(supabaseClient, requestData, assignment, timestamp)
  } else {
    return await declineAssignment(supabaseClient, requestData, assignment, timestamp)
  }
}

/**
 * Accept assignment logic
 */
async function acceptAssignment(
  supabaseClient: any,
  requestData: AcceptAssignmentRequest,
  assignment: any,
  timestamp: string
): Promise<AssignmentResult> {
  // Update assignment status
  const { error: assignmentError } = await supabaseClient
    .from('assignment')
    .update({
      status: 'accepted',
      accepted_at: timestamp
    })
    .eq('id', requestData.assignment_id)

  if (assignmentError) {
    throw new Error(`Failed to update assignment: ${assignmentError.message}`)
  }

  // Update report lifecycle status
  const { error: reportError } = await supabaseClient
    .from('reports')
    .update({
      lifecycle_status: 'accepted',
      last_update: timestamp
    })
    .eq('id', assignment.report_id)

  if (reportError) {
    throw new Error(`Failed to update report: ${reportError.message}`)
  }

  // Set responder as unavailable
  const { error: responderError } = await supabaseClient
    .from('responder')
    .update({
      is_available: false,
      updated_at: timestamp
    })
    .eq('id', requestData.responder_id)

  if (responderError) {
    throw new Error(`Failed to update responder availability: ${responderError.message}`)
  }

  return {
    assignment_id: requestData.assignment_id,
    report_id: assignment.report_id,
    responder_id: requestData.responder_id,
    status: 'accepted',
    action: 'accept',
    timestamp
  }
}

/**
 * Decline assignment logic
 */
async function declineAssignment(
  supabaseClient: any,
  requestData: AcceptAssignmentRequest,
  assignment: any,
  timestamp: string
): Promise<AssignmentResult> {
  // Update assignment status
  const { error: assignmentError } = await supabaseClient
    .from('assignment')
    .update({
      status: 'cancelled'
    })
    .eq('id', requestData.assignment_id)

  if (assignmentError) {
    throw new Error(`Failed to update assignment: ${assignmentError.message}`)
  }

  // Unassign report (set responder_id and assignment_id to null)
  const { error: reportError } = await supabaseClient
    .from('reports')
    .update({
      responder_id: null,
      assignment_id: null,
      lifecycle_status: 'classified', // Back to classified for reassignment
      last_update: timestamp
    })
    .eq('id', assignment.report_id)

  if (reportError) {
    throw new Error(`Failed to unassign report: ${reportError.message}`)
  }

  // TODO: Implement reassignment logic
  // This could trigger automatic reassignment to another available responder
  await triggerReassignment(supabaseClient, assignment.report_id)

  return {
    assignment_id: requestData.assignment_id,
    report_id: assignment.report_id,
    responder_id: requestData.responder_id,
    status: 'cancelled',
    action: 'decline',
    timestamp
  }
}

/**
 * Trigger reassignment logic (stub for future implementation)
 */
async function triggerReassignment(
  supabaseClient: any,
  reportId: string
): Promise<void> {
  try {
    // TODO: Implement automatic reassignment logic
    // 1. Find next available responder
    // 2. Create new assignment
    // 3. Notify new responder
    
    console.log(`Reassignment triggered for report ${reportId}`)
    
    // For now, just log that reassignment is needed
    await supabaseClient
      .from('audit_log')
      .insert({
        entity_type: 'report',
        entity_id: reportId,
        action: 'reassignment_needed',
        details: {
          reason: 'responder_declined',
          timestamp: new Date().toISOString()
        },
        created_at: new Date().toISOString()
      })
    
  } catch (error) {
    console.warn('Failed to trigger reassignment:', error)
    // Don't throw error as reassignment is not critical
  }
}

/**
 * Send notifications for assignment action
 */
async function sendActionNotifications(
  supabaseClient: any,
  result: AssignmentResult,
  assignment: any
): Promise<void> {
  try {
    const report = assignment.reports
    const action = result.action
    const status = result.status

    // Get admin users from responder table (legacy)
    const { data: admins } = await supabaseClient
      .from('responder')
      .select('user_id')
      .eq('role', 'admin')
      .limit(5)

    // Get super users and admins from user_profiles (so super_user gets notified too)
    const { data: superProfiles, error: profileError } = await supabaseClient
      .from('user_profiles')
      .select('user_id')
      .in('role', ['super_user', 'admin'])

    // Get reporter user_id if available
    const reporterUserId = report.reporter_uid

    const responderName = assignment.responder?.name || 'A responder'
    const reportTypeLabel = report.type || 'emergency'

    // Create notification payload (include responder_name for super user tracking)
    const notificationData = {
      assignment_id: result.assignment_id,
      report_id: result.report_id,
      responder_id: result.responder_id,
      responder_name: responderName,
      action: action,
      status: status,
      report_type: report.type,
      report_message: report.message,
      timestamp: result.timestamp
    }

    // Notify admins (from responder table) - insert with target_type/target_id for schema compatibility
    if (admins && admins.length > 0) {
      const adminNotifications = admins.map(admin => ({
        target_type: 'admin',
        target_id: admin.user_id,
        type: 'assignment_action',
        title: action === 'accept' ? `${responderName} accepted` : `Assignment ${action}ed`,
        message: action === 'accept'
          ? `${responderName} accepted the assignment for the ${reportTypeLabel} report.`
          : `${responderName} declined the assignment for the ${reportTypeLabel} report.`,
        payload: notificationData,
        is_read: false,
        created_at: result.timestamp
      }))
      await supabaseClient.from('notifications').insert(adminNotifications)
    }

    // Notify super users / admins from user_profiles (ensures super_user gets in-app + push) — include who accepted/declined
    if (!profileError && superProfiles && superProfiles.length > 0) {
      const superTitle = action === 'accept' ? `${responderName} accepted` : `${responderName} declined`
      const superMessage = action === 'accept'
        ? `${responderName} accepted the assignment for the ${reportTypeLabel} report. You can track this assignment in the dashboard.`
        : `${responderName} declined the assignment for the ${reportTypeLabel} report. Reassignment may be needed.`
      const superUserNotifications = superProfiles.map((p: { user_id: string }) => ({
        target_type: 'admin',
        target_id: p.user_id,
        type: 'assignment_action',
        title: superTitle,
        message: superMessage,
        payload: notificationData,
        is_read: false,
        created_at: result.timestamp
      }))
      await supabaseClient.from('notifications').insert(superUserNotifications)
      // Send OneSignal push to super users when responder accepts/declines — tell them who
      if (action === 'accept') {
        try {
          await sendOneSignalToSuperusers(
            supabaseClient,
            `${responderName} accepted the assignment`,
            `${responderName} accepted the ${reportTypeLabel} report. Track status in the dashboard.`,
            {
              type: 'assignment_status_update_superuser',
              reportId: result.report_id,
              assignmentId: result.assignment_id,
              responder_name: responderName,
              newStatus: 'accepted',
              timestamp: result.timestamp
            }
          )
        } catch (pushErr) {
          console.warn('Superuser OneSignal push (accept) failed (non-critical):', pushErr)
        }
      } else {
        try {
          await sendOneSignalToSuperusers(
            supabaseClient,
            `${responderName} declined the assignment`,
            `${responderName} declined the ${reportTypeLabel} report. Reassignment may be needed.`,
            {
              type: 'assignment_status_update_superuser',
              reportId: result.report_id,
              assignmentId: result.assignment_id,
              responder_name: responderName,
              newStatus: 'cancelled',
              timestamp: result.timestamp
            }
          )
        } catch (pushErr) {
          console.warn('Superuser OneSignal push (decline) failed (non-critical):', pushErr)
        }
      }
    }

    // Notify reporter if they have a user account
    if (reporterUserId) {
      await supabaseClient
        .from('notifications')
        .insert({
          user_id: reporterUserId,
          type: 'assignment_action',
          title: `Your report update`,
          message: `Responder ${action}ed your ${report.type || 'emergency'} report`,
          data: notificationData,
          read: false,
          created_at: result.timestamp
        })
    }

    // Emit real-time event
    await supabaseClient.realtime
      .channel('assignment_updates')
      .send({
        type: 'broadcast',
        event: 'assignment_action',
        payload: {
          ...notificationData,
          report: {
            type: report.type,
            message: report.message,
            location: report.location
          }
        }
      })

  } catch (error) {
    console.warn('Failed to send action notifications:', error)
    // Don't throw error as notifications are not critical
  }
}

/**
 * Send OneSignal push to super users / admins (user_profiles + onesignal_subscriptions).
 */
async function sendOneSignalToSuperusers(
  supabaseClient: any,
  title: string,
  message: string,
  data: Record<string, unknown>
): Promise<void> {
  if (!ONESIGNAL_REST_API_KEY || !ONESIGNAL_APP_ID) return

  const { data: superProfiles, error: profileError } = await supabaseClient
    .from('user_profiles')
    .select('user_id')
    .in('role', ['super_user', 'admin'])

  if (profileError || !superProfiles?.length) {
    console.log('No super users/admins to notify for accept action')
    return
  }

  const superUserIds = superProfiles.map((p: { user_id: string }) => p.user_id).filter(Boolean)
  if (superUserIds.length === 0) return

  const { data: subscriptions, error: subError } = await supabaseClient
    .from('onesignal_subscriptions')
    .select('player_id')
    .in('user_id', superUserIds)

  if (subError || !subscriptions?.length) {
    console.log('No OneSignal subscriptions for super users - log in on mobile app to receive push')
    return
  }

  const playerIds = subscriptions.map((s: { player_id: string }) => s.player_id).filter(Boolean)
  if (playerIds.length === 0) return

  const isV2Key = ONESIGNAL_REST_API_KEY.startsWith('os_v2_app_')
  const authHeader = isV2Key
    ? `Key ${ONESIGNAL_REST_API_KEY}`
    : `Basic ${base64Encode(new TextEncoder().encode(`${ONESIGNAL_REST_API_KEY}:`))}`

  const payload = {
    app_id: ONESIGNAL_APP_ID,
    include_player_ids: playerIds,
    headings: { en: `✅ ${title}` },
    contents: { en: message },
    data: { ...data, type: 'assignment_status_update_superuser' },
    android_channel_id: '62b67b1a-b2c2-4073-92c5-3b1d416a4720',
    priority: 8,
    android_visibility: 1,
    android_accent_color: '3b82f6',
    ios_badgeType: 'Increase',
    ios_badgeCount: 1,
    content_available: true,
  }

  const response = await fetch('https://api.onesignal.com/notifications', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': authHeader },
    body: JSON.stringify(payload),
  })

  if (!response.ok) {
    console.warn('OneSignal superuser (accept) API error:', response.status, await response.text())
    return
  }
  const result = await response.json()
  console.log('OneSignal accept notification sent to superusers:', { id: result.id, recipients: result.recipients })
}

/**
 * Emit real-time assignment updated event
 */
async function emitAssignmentUpdatedEvent(
  supabaseClient: any,
  result: AssignmentResult,
  assignment: any
): Promise<void> {
  try {
    const report = assignment.reports

    // Emit to responder's private channel
    await supabaseClient.realtime
      .channel(`private:responder:${result.responder_id}`)
      .send({
        type: 'broadcast',
        event: 'assignment.updated',
        payload: {
          assignment_id: result.assignment_id,
          report_id: result.report_id,
          responder_id: result.responder_id,
          status: result.status,
          action: result.action,
          timestamp: result.timestamp
        }
      })

    // Emit to admin channel
    await supabaseClient.realtime
      .channel('private:admin')
      .send({
        type: 'broadcast',
        event: 'assignment.updated',
        payload: {
          assignment_id: result.assignment_id,
          report_id: result.report_id,
          responder_id: result.responder_id,
          status: result.status,
          action: result.action,
          timestamp: result.timestamp,
          responder_name: assignment.responder_name
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
          status: result.status,
          lifecycle_status: result.status,
          type: report.type,
          lat: report.location?.lat,
          lng: report.location?.lng,
          responder_id: result.responder_id,
          last_update: result.timestamp
        }
      })

  } catch (error) {
    console.warn('Failed to emit assignment updated event:', error)
    // Don't throw error as real-time events are not critical
  }
}

/**
 * Log assignment action audit event
 */
async function logAssignmentActionAudit(
  supabaseClient: any,
  requestData: AcceptAssignmentRequest,
  result: AssignmentResult
): Promise<void> {
  try {
    await supabaseClient
      .from('audit_log')
      .insert({
        entity_type: 'assignment',
        entity_id: result.assignment_id,
        action: result.action,
        user_id: requestData.responder_id,
        details: {
          report_id: result.report_id,
          responder_id: result.responder_id,
          status: result.status,
          timestamp: result.timestamp
        },
        created_at: new Date().toISOString()
      })
  } catch (error) {
    console.warn('Failed to log assignment action audit:', error)
    // Don't throw error as audit logging is not critical
  }
}
