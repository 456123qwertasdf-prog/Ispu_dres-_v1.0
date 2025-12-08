import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

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
      reports!inner(
        id,
        lifecycle_status,
        type,
        message,
        location
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

  // Update report lifecycle status
  const { error: reportError } = await supabaseClient
    .from('reports')
    .update({
      lifecycle_status: newLifecycleStatus,
      last_update: updatedAt
    })
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
 * Emit real-time notifications for status updates
 */
async function emitStatusUpdateNotifications(
  supabaseClient: any,
  result: StatusUpdateResponse,
  currentAssignment: any
): Promise<void> {
  try {
    const report = currentAssignment.reports

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
    
    // Prepare push notification payload
    const pushPayload = {
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

    // Send push notification to responder
    const pushResponse = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/push-send`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        target: 'responder',
        responder_id: result.responder_id,
        payload: pushPayload
      })
    })

    if (!pushResponse.ok) {
      console.warn('Failed to send push notification:', await pushResponse.text())
    } else {
      const pushResult = await pushResponse.json()
      console.log('Push notification sent:', pushResult)
    }

  } catch (error) {
    console.warn('Failed to send push notification:', error)
    // Don't throw error as push notifications are not critical
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
