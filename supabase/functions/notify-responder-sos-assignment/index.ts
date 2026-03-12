import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')
const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID')

interface NotifySOSAssignmentRequest {
  sos_alert_id: string
  sos_assignment_id: string
  responder_id: string
}

interface NotificationPayload {
  title: string
  message: string
  priority: number
  sound: string
  data: Record<string, unknown>
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 405 }
    )
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { sos_alert_id, sos_assignment_id, responder_id }: NotifySOSAssignmentRequest = await req.json()

    if (!sos_alert_id || !sos_assignment_id || !responder_id) {
      return new Response(
        JSON.stringify({ error: 'sos_alert_id, sos_assignment_id, and responder_id are required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    if (!ONESIGNAL_REST_API_KEY || !ONESIGNAL_APP_ID) {
      console.warn('OneSignal not configured, skipping SOS push notification')
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: 'OneSignal not configured' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    const { data: alert, error: alertError } = await supabaseClient
      .from('sos_alerts')
      .select('id, reporter_name, location_address, latitude, longitude, status, created_at')
      .eq('id', sos_alert_id)
      .single()

    if (alertError || !alert) {
      throw new Error('SOS alert not found')
    }

    const { data: responder, error: responderError } = await supabaseClient
      .from('responder')
      .select('id, name, user_id')
      .eq('id', responder_id)
      .single()

    if (responderError || !responder) {
      throw new Error('Responder not found')
    }

    const { data: subscriptions, error: subscriptionError } = await supabaseClient
      .from('onesignal_subscriptions')
      .select('player_id')
      .eq('user_id', responder.user_id)

    if (subscriptionError || !subscriptions || subscriptions.length === 0) {
      console.warn(`No OneSignal player ID found for responder ${responder.name}`)
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: 'Responder has no OneSignal player ID registered' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    const playerIds = subscriptions.map((sub: { player_id: string }) => sub.player_id).filter((id: string) => id !== null && id !== '')

    const payload = createSOSNotificationPayload(alert, responder, sos_assignment_id)

    console.log(`Sending SOS notification to ${playerIds.length} device(s) for responder ${responder.name}`)

    const result = await sendOneSignalNotification(playerIds, payload, 10, true)

    await supabaseClient
      .from('notifications')
      .insert({
        target_type: 'responder',
        target_id: responder.user_id,
        type: 'sos_assignment_created',
        title: payload.title,
        message: payload.message,
        payload: {
          sos_assignment_id,
          sos_alert_id,
          responder_id,
          reporter_name: alert.reporter_name,
          location_address: alert.location_address,
          is_sos: true
        },
        is_read: false,
        created_at: new Date().toISOString()
      })

    console.log(`✅ SOS push notification sent to responder ${responder.name}`)

    return new Response(
      JSON.stringify({
        success: true,
        sent: result.sent,
        responder_name: responder.name,
        message: 'SOS push notification sent successfully'
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error) {
    console.error('Error sending SOS responder assignment notification:', error)
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message || 'Internal server error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})

function createSOSNotificationPayload(
  alert: { id: string; reporter_name?: string; location_address?: string; latitude?: number; longitude?: number },
  _responder: { id: string; name: string },
  sosAssignmentId: string
): NotificationPayload {
  const reporter = alert.reporter_name || 'Anonymous'
  const location = alert.location_address || (alert.latitude != null && alert.longitude != null
    ? `${alert.latitude.toFixed(5)}, ${alert.longitude.toFixed(5)}`
    : 'Location unknown')

  return {
    title: '🚨 SOS Assignment',
    message: `You have been assigned to an SOS alert from ${reporter} • ${location}`,
    priority: 10,
    sound: 'emergency_alert',
    data: {
      type: 'sos_assignment',
      sos_assignment_id: sosAssignmentId,
      sos_alert_id: alert.id,
      reporter_name: reporter,
      location_address: location,
      is_sos: true
    }
  }
}

async function sendOneSignalNotification(
  playerIds: string[],
  payload: NotificationPayload,
  priorityLevel: number,
  isCritical: boolean
): Promise<{ sent: number }> {
  const oneSignalPayload: Record<string, unknown> = {
    app_id: ONESIGNAL_APP_ID,
    include_player_ids: playerIds,
    headings: { en: payload.title },
    contents: { en: payload.message },
    data: payload.data,
    android_channel_id: '62b67b1a-b2c2-4073-92c5-3b1d416a4720',
    ...(isCritical ? { android_sound: 'emergency_alert' } : {}),
    priority: priorityLevel,
    android_visibility: 1,
    android_accent_color: 'FF0000',
    ...(isCritical ? { ios_sound: 'emergency_alert.wav' } : {}),
    ios_badgeType: 'Increase',
    ios_badgeCount: 1,
    content_available: true,
    ...(isCritical ? {
      android_group: 'sos_assignments',
      android_group_message: { en: 'You have $[notif_count] SOS assignment(s)' }
    } : {})
  }

  const isV2Key = ONESIGNAL_REST_API_KEY!.startsWith('os_v2_app_')
  const authHeader = isV2Key
    ? `Key ${ONESIGNAL_REST_API_KEY}`
    : `Basic ${btoa(ONESIGNAL_REST_API_KEY + ':')}`

  const response = await fetch('https://api.onesignal.com/notifications', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': authHeader },
    body: JSON.stringify(oneSignalPayload)
  })

  if (!response.ok) {
    const errorText = await response.text()
    console.error('OneSignal API error:', response.status, errorText)
    throw new Error(`OneSignal API error: ${response.status}`)
  }

  const result = await response.json()
  return { sent: result.recipients || 0 }
}
