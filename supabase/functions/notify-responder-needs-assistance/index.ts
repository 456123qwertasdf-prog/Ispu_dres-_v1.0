import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')
const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID')

interface NotifyRequest {
  kind: 'assistance' | 'backup'
  responder_id: string
  assignment_id?: string
  report_id?: string
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

    const { kind, responder_id, assignment_id, report_id }: NotifyRequest = await req.json()

    if (!responder_id || !kind) {
      return new Response(
        JSON.stringify({ error: 'responder_id and kind (assistance|backup) are required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    const { data: responder, error: rErr } = await supabaseClient
      .from('responder')
      .select('id, name, role')
      .eq('id', responder_id)
      .single()

    if (rErr || !responder) {
      return new Response(
        JSON.stringify({ error: 'Responder not found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 404 }
      )
    }

    let reportType = 'Incident'
    let reportId = report_id || null
    if (report_id) {
      const { data: report } = await supabaseClient
        .from('reports')
        .select('id, type')
        .eq('id', report_id)
        .single()
      if (report) {
        reportType = (report.type || 'Incident').toString()
        reportId = report.id
      }
    }

    const isBackup = kind === 'backup'
    const title = isBackup
      ? '🆘 Responder requested backup'
      : '🆘 Responder needs assistance'
    const message = isBackup && reportId
      ? `${responder.name} (${responder.role}) requested backup for ${reportType} incident.`
      : `${responder.name} (${responder.role}) needs assistance.`

    const { data: superUsers, error: superUsersError } = await supabaseClient.rpc('get_super_users')
    if (superUsersError || !superUsers?.length) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: 'No super users to notify' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    const notifications = superUsers.map((user: { id: string }) => ({
      target_type: 'admin',
      target_id: user.id,
      type: 'responder_needs_assistance',
      title,
      message,
      payload: {
        kind,
        responder_id: responder.id,
        responder_name: responder.name,
        responder_role: responder.role,
        assignment_id: assignment_id || null,
        report_id: reportId,
        report_type: reportType,
      },
      is_read: false,
      created_at: new Date().toISOString(),
    }))

    await supabaseClient.from('notifications').insert(notifications)

    const targetUsers = superUsers.filter(
      (u: { onesignal_player_id?: string }) => u.onesignal_player_id
    )
    const playerIds = targetUsers
      .map((u: { onesignal_player_id: string }) => u.onesignal_player_id)
      .filter(Boolean)

    if (playerIds.length === 0 || !ONESIGNAL_REST_API_KEY || !ONESIGNAL_APP_ID) {
      return new Response(
        JSON.stringify({
          success: true,
          sent: 0,
          notified_users: superUsers.length,
          message: 'Database notifications created; push skipped (no player IDs or OneSignal not configured)',
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    const notificationData = {
      type: 'responder_needs_assistance',
      kind,
      responder_id: responder.id,
      responder_name: responder.name,
      assignment_id: assignment_id || null,
      report_id: reportId,
    }

    const oneSignalPayload: any = {
      app_id: ONESIGNAL_APP_ID,
      include_player_ids: playerIds,
      headings: { en: title },
      contents: { en: message },
      data: notificationData,
      android_channel_id: '62b67b1a-b2c2-4073-92c5-3b1d416a4720',
      android_sound: 'emergency_alert',
      priority: 10,
      android_visibility: 1,
      android_accent_color: 'FF9800',
      ios_sound: 'emergency_alert.wav',
      ios_badgeType: 'Increase',
      ios_badgeCount: 1,
      content_available: true,
    }

    const isV2Key = ONESIGNAL_REST_API_KEY.startsWith('os_v2_app_')
    const authHeader = isV2Key
      ? `Key ${ONESIGNAL_REST_API_KEY}`
      : `Basic ${btoa(ONESIGNAL_REST_API_KEY + ':')}`

    const response = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
      body: JSON.stringify(oneSignalPayload),
    })

    if (!response.ok) {
      const errText = await response.text()
      console.error('OneSignal error:', response.status, errText)
      return new Response(
        JSON.stringify({
          success: true,
          sent: 0,
          notified_users: superUsers.length,
          message: 'Database notifications created; push failed: ' + errText,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    const result = await response.json()
    const sent = result.recipients ?? 0

    return new Response(
      JSON.stringify({
        success: true,
        sent,
        notified_users: superUsers.length,
        message: `Push sent to ${sent} super user(s); in-app notifications for ${superUsers.length}`,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error) {
    console.error('notify-responder-needs-assistance error:', error)
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
