import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import webpush from 'https://esm.sh/web-push@3.6.7'
import { corsHeaders } from '../_shared/cors.ts'

interface PushRequest {
  target: 'user' | 'responder' | 'admin' | 'all'
  payload: {
    title: string
    body: string
    icon?: string
    badge?: string
    data?: any
  }
  user_id?: string
  responder_id?: string
}

interface PushSubscription {
  endpoint: string
  keys: {
    p256dh: string
    auth: string
  }
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

    const requestData: PushRequest = await req.json()
    validatePushRequest(requestData)

    // Configure VAPID
    webpush.setVapidDetails(
      'mailto:your-email@example.com',
      Deno.env.get('VAPID_PUBLIC_KEY') ?? '',
      Deno.env.get('VAPID_PRIVATE_KEY') ?? ''
    )

    // Get subscriptions based on target
    const subscriptions = await getSubscriptions(supabaseClient, requestData)
    
    if (subscriptions.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: 'No subscriptions found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Send push notifications
    const results = await sendPushNotifications(subscriptions, requestData.payload)

    return new Response(
      JSON.stringify({
        success: true,
        sent: results.successful,
        failed: results.failed,
        message: `Push notifications sent to ${results.successful} devices`
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('Error in push/send function:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})

function validatePushRequest(data: PushRequest): void {
  if (!data.target || !['user', 'responder', 'admin', 'all'].includes(data.target)) {
    throw new Error('target must be one of: user, responder, admin, all')
  }
  
  if (!data.payload?.title || !data.payload?.body) {
    throw new Error('payload must include title and body')
  }

  if (data.target === 'user' && !data.user_id) {
    throw new Error('user_id required when target is user')
  }

  if (data.target === 'responder' && !data.responder_id) {
    throw new Error('responder_id required when target is responder')
  }
}

async function getSubscriptions(supabaseClient: any, request: PushRequest): Promise<PushSubscription[]> {
  let query = supabaseClient
    .from('notifications_subscriptions')
    .select('endpoint, p256dh_key, auth_key')

  switch (request.target) {
    case 'user':
      query = query.eq('user_id', request.user_id)
      break
    case 'responder':
      // Join with responder table to get user_id
      query = supabaseClient
        .from('notifications_subscriptions')
        .select(`
          endpoint,
          p256dh_key,
          auth_key,
          responder!inner(id)
        `)
        .eq('responder.id', request.responder_id)
      break
    case 'admin':
      // Get admin users (you'll need to define how to identify admins)
      query = query.eq('is_admin', true)
      break
    case 'all':
      // Get all subscriptions
      break
  }

  const { data: subscriptions, error } = await query

  if (error) {
    throw new Error(`Failed to fetch subscriptions: ${error.message}`)
  }

  return subscriptions.map(sub => ({
    endpoint: sub.endpoint,
    keys: {
      p256dh: sub.p256dh_key,
      auth: sub.auth_key
    }
  }))
}

async function sendPushNotifications(
  subscriptions: PushSubscription[], 
  payload: any
): Promise<{ successful: number; failed: number }> {
  const results = await Promise.allSettled(
    subscriptions.map(subscription => 
      webpush.sendNotification(subscription, JSON.stringify(payload))
    )
  )

  const successful = results.filter(r => r.status === 'fulfilled').length
  const failed = results.filter(r => r.status === 'rejected').length

  // Log failed notifications
  results.forEach((result, index) => {
    if (result.status === 'rejected') {
      console.warn(`Push notification failed for subscription ${index}:`, result.reason)
    }
  })

  return { successful, failed }
}
