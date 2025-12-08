import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get authenticated user
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { 
          status: 401, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Parse request body
    const body = await req.json().catch(() => ({}))
    const { 
      limit = 50, 
      offset = 0,
      unreadOnly = false,
      markAsRead = false,
      notificationIds = []
    } = body

    console.log(`📥 Sync notifications request from user ${user.id}`)
    console.log(`   - Limit: ${limit}, Offset: ${offset}`)
    console.log(`   - Unread only: ${unreadOnly}`)
    console.log(`   - Mark as read: ${markAsRead}`)

    // First, determine user's target_type and target_id
    let targetType = 'reporter' // Default
    let targetId = user.id

    // Check if user is a responder
    const { data: responder } = await supabaseClient
      .from('responder')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle()

    if (responder) {
      targetType = 'responder'
      targetId = responder.id
    }

    // Check if user is super_user or admin
    const userRole = user.user_metadata?.role?.toLowerCase()
    if (userRole === 'super_user' || userRole === 'admin') {
      targetType = 'admin'
      targetId = user.id
    }

    console.log(`   - Target: ${targetType}:${targetId}`)

    // Build query
    let query = supabaseClient
      .from('notifications')
      .select('*', { count: 'exact' })
      .eq('target_type', targetType)
      .eq('target_id', targetId)
      .order('created_at', { ascending: false })

    // Apply filters
    if (unreadOnly) {
      query = query.eq('is_read', false)
    }

    // Apply pagination
    query = query.range(offset, offset + limit - 1)

    // Execute query
    const { data: notifications, error: fetchError, count } = await query

    if (fetchError) {
      console.error('Error fetching notifications:', fetchError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch notifications', details: fetchError }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log(`✅ Found ${notifications?.length || 0} notifications (total: ${count})`)

    // Mark notifications as read if requested
    if (markAsRead && notificationIds.length > 0) {
      const { error: updateError } = await supabaseClient
        .from('notifications')
        .update({ is_read: true })
        .in('id', notificationIds)
        .eq('target_type', targetType)
        .eq('target_id', targetId)

      if (updateError) {
        console.error('Error marking notifications as read:', updateError)
      } else {
        console.log(`✅ Marked ${notificationIds.length} notifications as read`)
      }
    }

    // Get unread count
    const { count: unreadCount } = await supabaseClient
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('target_type', targetType)
      .eq('target_id', targetId)
      .eq('is_read', false)

    return new Response(
      JSON.stringify({
        success: true,
        notifications: notifications || [],
        total: count || 0,
        unreadCount: unreadCount || 0,
        targetType,
        targetId
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Sync notifications error:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error', 
        details: error instanceof Error ? error.message : String(error) 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

