import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')
const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID')

interface NotifyAssignmentRequest {
  assignment_id: string
  responder_id: string
  report_id: string
}

interface NotificationPayload {
  title: string
  message: string
  priority: number
  sound: string
  data: any
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

    const { assignment_id, responder_id, report_id }: NotifyAssignmentRequest = await req.json()

    if (!assignment_id || !responder_id || !report_id) {
      return new Response(
        JSON.stringify({ error: 'assignment_id, responder_id, and report_id are required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    // Check if OneSignal is configured
    if (!ONESIGNAL_REST_API_KEY || !ONESIGNAL_APP_ID) {
      console.warn('OneSignal not configured, skipping push notification')
      return new Response(
        JSON.stringify({ 
          success: true, 
          sent: 0, 
          message: 'OneSignal not configured' 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Get report details including priority and severity
    const { data: report, error: reportError } = await supabaseClient
      .from('reports')
      .select('id, type, message, location, priority, severity, response_time, emergency_icon, reporter_name, created_at')
      .eq('id', report_id)
      .single()

    if (reportError || !report) {
      throw new Error('Report not found')
    }

    // Get responder details including OneSignal player ID
    const { data: responder, error: responderError } = await supabaseClient
      .from('responder')
      .select('id, name, user_id')
      .eq('id', responder_id)
      .single()

    if (responderError || !responder) {
      throw new Error('Responder not found')
    }

    // Get responder's OneSignal player IDs from onesignal_subscriptions table
    const { data: subscriptions, error: subscriptionError } = await supabaseClient
      .from('onesignal_subscriptions')
      .select('player_id')
      .eq('user_id', responder.user_id)

    if (subscriptionError || !subscriptions || subscriptions.length === 0) {
      console.warn(`No OneSignal player ID found for responder ${responder.name}`)
      return new Response(
        JSON.stringify({ 
          success: true, 
          sent: 0, 
          message: 'Responder has no OneSignal player ID registered' 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Get all player IDs for the responder (they may have multiple devices)
    const playerIds = subscriptions.map(sub => sub.player_id).filter(id => id !== null && id !== '')

    // Determine if this is a critical/high priority assignment
    const isCritical = report.priority <= 2 || report.severity === 'CRITICAL' || report.severity === 'HIGH'
    const priorityLevel = isCritical ? 10 : 7
    const emoji = report.emergency_icon || '🚨'

    // Create notification payload
    const notificationPayload = createNotificationPayload(report, responder, isCritical, emoji, assignment_id)

    // Send OneSignal push notification to all responder devices
    console.log(`Sending notification to ${playerIds.length} device(s) for responder ${responder.name}`)
    
    const result = await sendOneSignalNotification(
      playerIds,
      notificationPayload,
      priorityLevel,
      isCritical
    )

    // Log notification in database for tracking
    await supabaseClient
      .from('notifications')
      .insert({
        target_type: 'responder',
        target_id: responder.user_id,
        type: 'assignment_created',
        title: notificationPayload.title,
        message: notificationPayload.message,
        payload: {
          assignment_id,
          report_id,
          report_type: report.type,
          priority: report.priority,
          severity: report.severity,
          is_critical: isCritical
        },
        is_read: false,
        created_at: new Date().toISOString()
      })

    console.log(`✅ Push notification sent to responder ${responder.name} for ${isCritical ? 'CRITICAL/HIGH' : 'normal'} priority assignment`)

    return new Response(
      JSON.stringify({
        success: true,
        sent: result.sent,
        is_critical: isCritical,
        responder_name: responder.name,
        report_type: report.type,
        message: `Push notification sent successfully`
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error sending responder assignment notification:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})

/**
 * Create notification payload based on report details
 */
function createNotificationPayload(
  report: any,
  responder: any,
  isCritical: boolean,
  emoji: string,
  assignmentId: string
): NotificationPayload {
  const typeLabel = report.type ? report.type.toUpperCase() : 'EMERGENCY'
  const priorityLabel = isCritical ? '🚨 CRITICAL/HIGH PRIORITY' : ''
  
  let title = `${emoji} New Assignment${priorityLabel ? ' - ' + priorityLabel : ''}`
  let message = `You have been assigned to a ${typeLabel} report`

  if (report.response_time) {
    message += ` • Response time: ${report.response_time}`
  }

  if (report.location?.address) {
    message += ` • Location: ${report.location.address}`
  }

  return {
    title,
    message,
    priority: isCritical ? 10 : 7,
    sound: isCritical ? 'emergency_alert' : 'default',
    data: {
      type: 'assignment',
      assignment_id: assignmentId,
      report_id: report.id,
      report_type: report.type,
      priority: report.priority,
      severity: report.severity,
      is_critical: isCritical,
      location: report.location,
      response_time: report.response_time
    }
  }
}

/**
 * Send push notification via OneSignal
 */
async function sendOneSignalNotification(
  playerIds: string[],
  payload: NotificationPayload,
  priorityLevel: number,
  isCritical: boolean
): Promise<{ sent: number }> {
  try {
    const oneSignalPayload: any = {
      app_id: ONESIGNAL_APP_ID,
      include_player_ids: playerIds,
      headings: { en: payload.title },
      contents: { en: payload.message },
      data: payload.data,
      
      // Android-specific settings
      android_channel_id: '62b67b1a-b2c2-4073-92c5-3b1d416a4720',
      ...(isCritical ? {
        android_sound: 'emergency_alert', // Custom emergency sound for critical/high priority
      } : {}),
      priority: priorityLevel,
      android_visibility: 1, // Public notification (show on lock screen)
      android_accent_color: isCritical ? 'FF0000' : 'FF9800', // Red for critical, orange for normal
      
      // iOS-specific settings
      ...(isCritical ? { ios_sound: 'emergency_alert.wav' } : {}),
      ios_badgeType: 'Increase',
      ios_badgeCount: 1,
      
      // Background notification support
      content_available: true,
      
      // Make notification persistent for critical assignments
      ...(isCritical ? {
        android_group: 'critical_assignments',
        android_group_message: { en: 'You have $[notif_count] critical assignments' },
      } : {})
    }

    console.log(`Sending OneSignal notification to ${playerIds.length} device(s):`, {
      title: payload.title,
      is_critical: isCritical,
      priority: priorityLevel
    })

    // Determine auth header format based on API key type
    const isV2Key = ONESIGNAL_REST_API_KEY!.startsWith('os_v2_app_')
    const authHeader = isV2Key 
      ? `Key ${ONESIGNAL_REST_API_KEY}`
      : `Basic ${btoa(ONESIGNAL_REST_API_KEY + ':')}`

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
      console.error('OneSignal API error:', response.status, errorText)
      throw new Error(`OneSignal API error: ${response.status}`)
    }

    const result = await response.json()
    console.log('OneSignal response:', result)

    return {
      sent: result.recipients || 0
    }

  } catch (error) {
    console.error('Failed to send OneSignal notification:', error)
    throw error
  }
}

