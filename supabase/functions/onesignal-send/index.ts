import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { encode as base64Encode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID') || '8d6aa625-a650-47ac-b9ba-00a247840952'
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY') || ''

interface OneSignalRequest {
  announcementId: string
  targetUserIds?: string[]
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { announcementId, targetUserIds }: OneSignalRequest = await req.json()

    if (!announcementId) {
      return new Response(
        JSON.stringify({ error: 'announcementId required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    if (!ONESIGNAL_REST_API_KEY) {
      console.warn('ONESIGNAL_REST_API_KEY not configured, skipping OneSignal notification')
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: 'OneSignal not configured' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Debug: Log API key presence (first 10 chars only for security)
    console.log('OneSignal API Key check:', {
      hasKey: !!ONESIGNAL_REST_API_KEY,
      keyLength: ONESIGNAL_REST_API_KEY.length,
      keyPrefix: ONESIGNAL_REST_API_KEY.substring(0, 10) + '...',
      appId: ONESIGNAL_APP_ID
    })

    // Get announcement details
    const { data: announcement, error: annError } = await supabaseClient
      .from('announcements')
      .select('*')
      .eq('id', announcementId)
      .single()

    if (annError || !announcement) {
      throw new Error('Announcement not found')
    }

    // Get OneSignal player IDs for target users
    let playerIds: string[] = []
    
    if (targetUserIds && targetUserIds.length > 0) {
      const { data: subscriptions, error: subError } = await supabaseClient
        .from('onesignal_subscriptions')
        .select('player_id, user_id')
        .in('user_id', targetUserIds)
      
      if (subError) {
        console.warn('Error fetching OneSignal subscriptions:', subError)
      } else {
        playerIds = subscriptions?.map(s => s.player_id).filter(Boolean) || []
        console.log(`Found ${playerIds.length} OneSignal subscriptions for ${targetUserIds.length} target users`, {
          targetUserIds,
          foundSubscriptions: subscriptions?.map(s => ({ user_id: s.user_id, player_id: s.player_id })) || []
        })
      }
    } else {
      // Send to all users with OneSignal subscriptions
      const { data: subscriptions, error: subError } = await supabaseClient
        .from('onesignal_subscriptions')
        .select('player_id, user_id')
      
      if (subError) {
        console.warn('Error fetching OneSignal subscriptions:', subError)
      } else {
        playerIds = subscriptions?.map(s => s.player_id).filter(Boolean) || []
        console.log(`Found ${playerIds.length} total OneSignal subscriptions`)
      }
    }

    if (playerIds.length === 0) {
      console.warn('No OneSignal player IDs found in database')
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: 'No OneSignal subscriptions found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Determine if this is an emergency
    const isEmergency = announcement.type === 'emergency'
    const emoji = isEmergency ? '🚨' : '📢'

    // Send notification via OneSignal API
    // Important: content_available: true allows notifications to wake the app in background
    const oneSignalPayload: any = {
      app_id: ONESIGNAL_APP_ID,
      include_player_ids: playerIds,
      headings: { en: `${emoji} ${announcement.title}` },
      contents: { en: announcement.message },
      data: {
        announcement_id: announcement.id,
        type: announcement.type,
        priority: announcement.priority,
      },
      // Android-specific settings
      // OneSignal requires android_channel_id for all Android notifications
      // Use emergency channel for all notifications (configured in OneSignal dashboard)
      android_channel_id: '62b67b1a-b2c2-4073-92c5-3b1d416a4720', // Channel ID from OneSignal dashboard
      ...(isEmergency ? {
        android_sound: 'emergency_alert', // Custom emergency sound
      } : {
        // For non-emergency: use default system sound (don't specify custom sound)
        // android_sound is omitted, so it uses the default notification sound
      }),
      priority: isEmergency ? 10 : 5,
      android_visibility: 1, // Public notification (show on lock screen)
      android_accent_color: isEmergency ? 'FF0000' : '3b82f6', // Red for emergency, blue for others
      // Background notification support
      content_available: true, // Allows notification to wake app in background
      // iOS-specific (if needed later)
      ...(isEmergency ? { ios_sound: 'emergency_alert' } : {}), // Only use custom sound for emergency on iOS too
      ios_badgeType: 'Increase',
      ios_badgeCount: 1,
    }

    console.log(`Sending OneSignal notification to ${playerIds.length} devices:`, {
      announcementId: announcement.id,
      type: announcement.type,
      isEmergency,
      playerIdsCount: playerIds.length
    })

    // OneSignal REST API authorization
    // For new os_v2_app_ keys: Use "Key" format (not Basic auth)
    // For legacy keys: Use "Basic base64(REST_API_KEY:)" format
    // Both use the same endpoint, only auth format differs
    const isV2Key = ONESIGNAL_REST_API_KEY.startsWith('os_v2_app_')
    const authHeader = isV2Key 
      ? `Key ${ONESIGNAL_REST_API_KEY}`  // New v2 format: "Key <API_KEY>"
      : `Basic ${base64Encode(new TextEncoder().encode(`${ONESIGNAL_REST_API_KEY}:`))}`  // Legacy format: "Basic base64(KEY:)"
    
    // Both v2 and legacy keys use the same endpoint
    const apiEndpoint = 'https://onesignal.com/api/v1/notifications'
    
    // Debug: Log authorization header (first 20 chars only)
    console.log('OneSignal auth header:', {
      isV2Key,
      authHeaderFormat: authHeader.substring(0, 30) + '...',
      apiEndpoint
    })
    
    const oneSignalResponse = await fetch(apiEndpoint, {
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(oneSignalPayload),
    })

    if (!oneSignalResponse.ok) {
      const errorText = await oneSignalResponse.text()
      console.error('OneSignal API error:', {
        status: oneSignalResponse.status,
        statusText: oneSignalResponse.statusText,
        error: errorText,
        payload: oneSignalPayload,
        playerIdsCount: playerIds.length,
        hasApiKey: !!ONESIGNAL_REST_API_KEY
      })
      throw new Error(`OneSignal API error: ${oneSignalResponse.status} - ${errorText}`)
    }

    const oneSignalResult = await oneSignalResponse.json()
    console.log('OneSignal API response:', {
      id: oneSignalResult.id,
      recipients: oneSignalResult.recipients,
      errors: oneSignalResult.errors
    })

    return new Response(
      JSON.stringify({
        success: true,
        sent: oneSignalResult.recipients || playerIds.length,
        message: `OneSignal notifications sent to ${oneSignalResult.recipients || playerIds.length} devices`,
        oneSignalId: oneSignalResult.id,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('OneSignal send error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})

