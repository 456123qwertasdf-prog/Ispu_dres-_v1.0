import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

interface AssignmentRequest {
  report_id: string
  responder_id: string
  assigned_by: string
}

interface AssignmentResult {
  assignment_id: string
  report_id: string
  responder_id: string
  status: string
  assigned_at: string
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
    const requestData: AssignmentRequest = await req.json()
    validateAssignmentRequest(requestData)

    // Check if report exists and is assignable
    await validateReportAssignment(supabaseClient, requestData.report_id)

    // Check if responder exists and is available
    await validateResponderAvailability(supabaseClient, requestData.responder_id)

    // Check responder does not already have an active assignment (to another report)
    await checkResponderHasNoOtherActiveAssignment(supabaseClient, requestData.responder_id, requestData.report_id)

    // Check if assignment already exists
    await checkExistingAssignment(supabaseClient, requestData.report_id)

    // Execute assignment transaction
    const result = await executeAssignmentTransaction(supabaseClient, requestData)

    // Get assignment details for real-time events
    const assignmentDetails = await getAssignmentDetailsForEvent(supabaseClient, result.assignment_id)

    // Emit real-time notification
    await emitAssignmentNotification(supabaseClient, result)

    // Emit real-time events
    await emitAssignmentCreatedEvent(supabaseClient, result, assignmentDetails)

    // Log audit event
    await logAssignmentAudit(supabaseClient, requestData, result)

    // Send push notification to responder
    await sendPushNotificationToResponder(supabaseClient, result)

    return new Response(
      JSON.stringify({
        success: true,
        assignment: result,
        message: 'Responder assigned successfully'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in assign-responder function:', error)
    
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
 * Validate assignment request data
 */
function validateAssignmentRequest(data: AssignmentRequest): void {
  if (!data.report_id || typeof data.report_id !== 'string') {
    throw new Error('report_id is required and must be a string')
  }

  if (!data.responder_id || typeof data.responder_id !== 'string') {
    throw new Error('responder_id is required and must be a string')
  }

  if (!data.assigned_by || typeof data.assigned_by !== 'string') {
    throw new Error('assigned_by is required and must be a string')
  }

  // Validate UUID format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  if (!uuidRegex.test(data.report_id)) {
    throw new Error('report_id must be a valid UUID')
  }

  if (!uuidRegex.test(data.responder_id)) {
    throw new Error('responder_id must be a valid UUID')
  }

  if (!uuidRegex.test(data.assigned_by)) {
    throw new Error('assigned_by must be a valid UUID')
  }
}

/**
 * Validate that report exists and can be assigned
 */
async function validateReportAssignment(
  supabaseClient: any,
  reportId: string
): Promise<void> {
  const { data: report, error } = await supabaseClient
    .from('reports')
    .select('id, lifecycle_status, responder_id, assignment_id')
    .eq('id', reportId)
    .single()

  if (error) {
    if (error.code === 'PGRST116') {
      throw new Error('Report not found')
    }
    throw new Error(`Failed to fetch report: ${error.message}`)
  }

  if (report.assignment_id) {
    throw new Error('Report is already assigned to a responder')
  }

  if (report.lifecycle_status === 'resolved' || report.lifecycle_status === 'closed') {
    throw new Error('Cannot assign responder to resolved or closed report')
  }
}

/**
 * Validate that responder exists and is available
 */
async function validateResponderAvailability(
  supabaseClient: any,
  responderId: string
): Promise<void> {
  const { data: responder, error } = await supabaseClient
    .from('responder')
    .select('id, name, is_available, status')
    .eq('id', responderId)
    .single()

  if (error) {
    if (error.code === 'PGRST116') {
      throw new Error('Responder not found')
    }
    throw new Error(`Failed to fetch responder: ${error.message}`)
  }

  if (!responder.is_available) {
    throw new Error('Responder is not available for assignment')
  }

  if (responder.status !== 'active') {
    throw new Error('Responder is not active')
  }
}

const ACTIVE_ASSIGNMENT_STATUSES = ['assigned', 'accepted', 'enroute', 'in_progress', 'on_scene']

/**
 * Check that responder has no other active assignment (to a different report).
 * A responder can only have one active assignment at a time.
 */
async function checkResponderHasNoOtherActiveAssignment(
  supabaseClient: any,
  responderId: string,
  reportId: string
): Promise<void> {
  const { data: otherAssignments, error } = await supabaseClient
    .from('assignment')
    .select('id, report_id, status')
    .eq('responder_id', responderId)
    .neq('report_id', reportId)
    .in('status', ACTIVE_ASSIGNMENT_STATUSES)
    .limit(1)

  if (error) {
    throw new Error(`Failed to check responder assignments: ${error.message}`)
  }

  if (otherAssignments && otherAssignments.length > 0) {
    throw new Error('Responder already has an active assignment. They must finish it before being assigned to another report.')
  }
}

/**
 * Check if assignment already exists for this report
 */
async function checkExistingAssignment(
  supabaseClient: any,
  reportId: string
): Promise<void> {
  const { data: existingAssignment, error } = await supabaseClient
    .from('assignment')
    .select('id, status')
    .eq('report_id', reportId)
    .in('status', ['assigned', 'accepted', 'enroute', 'on_scene'])
    .single()

  if (error && error.code !== 'PGRST116') {
    throw new Error(`Failed to check existing assignment: ${error.message}`)
  }

  if (existingAssignment) {
    throw new Error('Report already has an active assignment')
  }
}

/**
 * Execute assignment transaction with atomicity
 */
async function executeAssignmentTransaction(
  supabaseClient: any,
  requestData: AssignmentRequest
): Promise<AssignmentResult> {
  const assignedAt = new Date().toISOString()

  // Use a transaction to ensure atomicity
  const { data: assignment, error: assignmentError } = await supabaseClient
    .from('assignment')
    .insert({
      report_id: requestData.report_id,
      responder_id: requestData.responder_id,
      status: 'assigned',
      assigned_at: assignedAt
    })
    .select()
    .single()

  if (assignmentError) {
    throw new Error(`Failed to create assignment: ${assignmentError.message}`)
  }

  // Update report with assignment details
  const { error: reportError } = await supabaseClient
    .from('reports')
    .update({
      responder_id: requestData.responder_id,
      assignment_id: assignment.id,
      lifecycle_status: 'assigned',
      last_update: assignedAt
    })
    .eq('id', requestData.report_id)

  if (reportError) {
    // Rollback assignment if report update fails
    await supabaseClient
      .from('assignment')
      .delete()
      .eq('id', assignment.id)
    
    throw new Error(`Failed to update report: ${reportError.message}`)
  }

  return {
    assignment_id: assignment.id,
    report_id: requestData.report_id,
    responder_id: requestData.responder_id,
    status: 'assigned',
    assigned_at: assignedAt
  }
}

/**
 * Emit real-time notification to responder
 */
async function emitAssignmentNotification(
  supabaseClient: any,
  assignment: AssignmentResult
): Promise<void> {
  try {
    // Get report details for notification
    const { data: report, error: reportError } = await supabaseClient
      .from('reports')
      .select('id, type, message, location, created_at')
      .eq('id', assignment.report_id)
      .single()

    if (reportError) {
      console.warn('Failed to fetch report details for notification:', reportError)
      return
    }

    // Get responder details
    const { data: responder, error: responderError } = await supabaseClient
      .from('responder')
      .select('id, name, user_id')
      .eq('id', assignment.responder_id)
      .single()

    if (responderError) {
      console.warn('Failed to fetch responder details for notification:', responderError)
      return
    }

    // Create notification payload
    const notification = {
      type: 'assignment_created',
      assignment_id: assignment.assignment_id,
      report_id: assignment.report_id,
      responder_id: assignment.responder_id,
      report_type: report.type,
      report_message: report.message,
      report_location: report.location,
      assigned_at: assignment.assigned_at,
      priority: 'high'
    }

    // Emit real-time event
    await supabaseClient.realtime
      .channel('responder_assignments')
      .send({
        type: 'broadcast',
        event: 'assignment_created',
        payload: notification
      })

    // Also insert into notifications table for persistence
    await supabaseClient
      .from('notifications')
      .insert({
        target_type: 'responder',
        target_id: responder.user_id,
        type: 'assignment_created',
        title: 'New Assignment',
        message: `You have been assigned to a ${report.type || 'emergency'} report`,
        payload: notification,
        is_read: false,
        created_at: assignedAt
      })

  } catch (error) {
    console.warn('Failed to emit assignment notification:', error)
    // Don't throw error as notification is not critical for assignment
  }
}

/**
 * Get assignment details for real-time events
 */
async function getAssignmentDetailsForEvent(
  supabaseClient: any,
  assignmentId: string
): Promise<any> {
  try {
    const { data: assignment, error } = await supabaseClient
      .from('assignment')
      .select(`
        id,
        report_id,
        responder_id,
        status,
        assigned_at,
        reports!report_id(
          id,
          type,
          message,
          location,
          reporter_name,
          lifecycle_status
        )
      `)
      .eq('id', assignmentId)
      .single()

    if (error) {
      console.warn('Failed to get assignment details:', error)
      return null
    }

    return assignment
  } catch (error) {
    console.warn('Failed to get assignment details:', error)
    return null
  }
}

/**
 * Emit real-time assignment created event
 */
async function emitAssignmentCreatedEvent(
  supabaseClient: any,
  result: AssignmentResult,
  assignmentDetails: any
): Promise<void> {
  try {
    if (!assignmentDetails) return

    const report = assignmentDetails.reports

    // Emit to responder's private channel
    await supabaseClient.realtime
      .channel(`private:responder:${result.responder_id}`)
      .send({
        type: 'broadcast',
        event: 'assignment.created',
        payload: {
          assignment_id: result.assignment_id,
          report_id: result.report_id,
          responder_id: result.responder_id,
          status: result.status,
          assigned_at: result.assigned_at,
          report: {
            type: report.type,
            message: report.message,
            location: report.location,
            created_at: report.created_at
          },
          priority: 'high'
        }
      })

    // Emit to admin channel
    await supabaseClient.realtime
      .channel('private:admin')
      .send({
        type: 'broadcast',
        event: 'assignment.created',
        payload: {
          assignment_id: result.assignment_id,
          report_id: result.report_id,
          responder_id: result.responder_id,
          assigned_by: result.assigned_by,
          status: result.status,
          assigned_at: result.assigned_at,
          report: {
            type: report.type,
            message: report.message,
            location: report.location,
            reporter_name: report.reporter_name
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
          status: 'assigned',
          lifecycle_status: 'assigned',
          type: report.type,
          lat: report.location?.lat,
          lng: report.location?.lng,
          responder_id: result.responder_id,
          last_update: result.assigned_at
        }
      })

  } catch (error) {
    console.warn('Failed to emit assignment created event:', error)
    // Don't throw error as real-time events are not critical
  }
}

/**
 * Log assignment audit event
 */
async function logAssignmentAudit(
  supabaseClient: any,
  requestData: AssignmentRequest,
  result: AssignmentResult
): Promise<void> {
  try {
    await supabaseClient
      .from('audit_log')
      .insert({
        entity_type: 'assignment',
        entity_id: result.assignment_id,
        action: 'created',
        user_id: requestData.assigned_by,
        details: {
          report_id: requestData.report_id,
          responder_id: requestData.responder_id,
          status: 'assigned',
          assigned_at: result.assigned_at
        },
        created_at: new Date().toISOString()
      })
  } catch (error) {
    console.warn('Failed to log assignment audit:', error)
    // Don't throw error as audit logging is not critical
  }
}

/**
 * Send push notification to responder about new assignment
 */
async function sendPushNotificationToResponder(
  supabaseClient: any,
  result: AssignmentResult
): Promise<void> {
  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!SUPABASE_URL || !SERVICE_KEY) {
      console.warn('Supabase URL or Service Key not configured')
      return
    }

    // Call the notify-responder-assignment function
    const response = await fetch(`${SUPABASE_URL}/functions/v1/notify-responder-assignment`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SERVICE_KEY}`
      },
      body: JSON.stringify({
        assignment_id: result.assignment_id,
        responder_id: result.responder_id,
        report_id: result.report_id
      })
    })

    if (response.ok) {
      const notificationResult = await response.json()
      console.log(`✅ Push notification sent to responder:`, notificationResult)
    } else {
      const errorText = await response.text()
      console.warn('Failed to send push notification:', response.status, errorText)
    }
  } catch (error) {
    console.warn('Failed to send push notification to responder:', error)
    // Don't throw error as push notification is not critical for assignment
  }
}
