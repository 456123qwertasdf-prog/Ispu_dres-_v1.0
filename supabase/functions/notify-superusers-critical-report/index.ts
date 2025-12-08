import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')
const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID')

interface NotifyCriticalReportRequest {
  report_id: string
}

interface ReportData {
  id: string
  type: string
  priority: number
  severity: string
  response_time: string
  emergency_icon: string
  location: any
  message: string
  reporter_name: string
  created_at: string
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

    const { report_id }: NotifyCriticalReportRequest = await req.json()

    if (!report_id) {
      return new Response(
        JSON.stringify({ error: 'report_id is required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    // Get report details
    const { data: report, error: reportError } = await supabaseClient
      .from('reports')
      .select('id, type, message, location, priority, severity, response_time, emergency_icon, reporter_name, created_at')
      .eq('id', report_id)
      .single()

    if (reportError || !report) {
      throw new Error('Report not found')
    }

    // Check if report is critical/high priority
    const isCritical = report.priority <= 2 || report.severity === 'CRITICAL' || report.severity === 'HIGH'

    if (!isCritical) {
      console.log(`Report ${report_id} is not critical/high priority. Skipping super user notification.`)
      return new Response(
        JSON.stringify({ 
          success: true, 
          sent: 0,
          message: 'Report is not critical/high priority, no notification sent' 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Get all super users with their OneSignal player IDs
    const { data: superUsers, error: superUsersError } = await supabaseClient
      .rpc('get_super_users')

    if (superUsersError) {
      console.warn('Failed to fetch super users:', superUsersError)
      return new Response(
        JSON.stringify({ 
          success: true, 
          sent: 0,
          message: 'Failed to fetch super users' 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    if (!superUsers || superUsers.length === 0) {
      console.warn('No super users found in database')
      return new Response(
        JSON.stringify({ 
          success: true, 
          sent: 0,
          message: 'No super users found' 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    console.log(`Found ${superUsers.length} super user records`)

    // Filter to only users with OneSignal player IDs
    const targetUsers = superUsers.filter(user => 
      user.onesignal_player_id !== null && user.onesignal_player_id !== ''
    )

    if (targetUsers.length === 0) {
      console.warn('No super users with OneSignal player IDs found')
      return new Response(
        JSON.stringify({ 
          success: true, 
          sent: 0,
          message: 'No super users with push notifications enabled' 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    console.log(`Found ${targetUsers.length} super users with OneSignal player IDs`)

    // Get player IDs
    const playerIds = targetUsers
      .map(user => user.onesignal_player_id)
      .filter(id => id !== null && id !== '')

    if (playerIds.length === 0) {
      console.warn('No valid OneSignal player IDs found')
      return new Response(
        JSON.stringify({ 
          success: true, 
          sent: 0,
          message: 'No valid OneSignal player IDs' 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Check if OneSignal is configured
    if (!ONESIGNAL_REST_API_KEY || !ONESIGNAL_APP_ID) {
      console.warn('OneSignal not configured, skipping push notification')
      // Still create database notifications
      await createDatabaseNotifications(supabaseClient, targetUsers, report)
      
      return new Response(
        JSON.stringify({ 
          success: true, 
          sent: 0, 
          message: 'OneSignal not configured, database notifications created' 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Create notification payload
    const emoji = report.emergency_icon || '🚨'
    const typeLabel = report.type ? report.type.toUpperCase() : 'EMERGENCY'
    const priorityLabel = '⚠️ REQUIRES IMMEDIATE ASSIGNMENT'
    
    const title = `${emoji} NEW CRITICAL REPORT - ${priorityLabel}`
    const message = `${typeLabel} report needs immediate attention • Response time: ${report.response_time}${report.location?.address ? ' • ' + report.location.address : ''}`

    const notificationData = {
      type: 'critical_report',
      report_id: report.id,
      report_type: report.type,
      priority: report.priority,
      severity: report.severity,
      is_critical: true,
      location: report.location,
      response_time: report.response_time,
      reporter_name: report.reporter_name,
      created_at: report.created_at
    }

    // Send OneSignal push notification
    const result = await sendOneSignalNotification(playerIds, title, message, notificationData)

    // Create database notifications for all super users
    await createDatabaseNotifications(supabaseClient, targetUsers, report)

    console.log(`✅ Critical report notification sent to ${result.sent} super users/admins for report ${report_id}`)

    return new Response(
      JSON.stringify({
        success: true,
        sent: result.sent,
        notified_users: targetUsers.length,
        report_type: report.type,
        priority: report.priority,
        severity: report.severity,
        message: `Push notification sent to ${result.sent} super users/admins`
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error sending critical report notification:', error)
    
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
 * Send push notification via OneSignal
 */
async function sendOneSignalNotification(
  playerIds: string[],
  title: string,
  message: string,
  data: any
): Promise<{ sent: number }> {
  try {
    const oneSignalPayload: any = {
      app_id: ONESIGNAL_APP_ID,
      include_player_ids: playerIds,
      headings: { en: title },
      contents: { en: message },
      data: data,
      
      // Android-specific settings - Always use emergency style for critical reports
      android_channel_id: '62b67b1a-b2c2-4073-92c5-3b1d416a4720',
      android_sound: 'emergency_alert', // Custom emergency sound
      priority: 10, // Maximum priority
      android_visibility: 1, // Public notification (show on lock screen)
      android_accent_color: 'FF0000', // Red for critical
      
      // iOS-specific settings
      ios_sound: 'emergency_alert.wav',
      ios_badgeType: 'Increase',
      ios_badgeCount: 1,
      
      // Background notification support
      content_available: true,
      
      // Make notification persistent and grouped
      android_group: 'critical_reports',
      android_group_message: { en: 'You have $[notif_count] critical reports to assign' },
    }

    console.log(`Sending OneSignal notification to ${playerIds.length} super user(s)`)

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

/**
 * Create database notifications for all super users
 */
async function createDatabaseNotifications(
  supabaseClient: any,
  users: any[],
  report: ReportData
): Promise<void> {
  try {
    const notifications = users.map(user => ({
      target_type: 'admin',
      target_id: user.id,
      type: 'critical_report',
      title: '🚨 New Critical Report',
      message: `${report.type?.toUpperCase() || 'EMERGENCY'} report requires immediate assignment • Response time: ${report.response_time}`,
      payload: {
        report_id: report.id,
        report_type: report.type,
        priority: report.priority,
        severity: report.severity,
        is_critical: true,
        location: report.location,
        response_time: report.response_time
      },
      is_read: false,
      created_at: new Date().toISOString()
    }))

    const { error } = await supabaseClient
      .from('notifications')
      .insert(notifications)

    if (error) {
      console.warn('Failed to create database notifications:', error)
    } else {
      console.log(`Created ${notifications.length} database notifications`)
    }
  } catch (error) {
    console.warn('Failed to create database notifications:', error)
  }
}

