import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../../_shared/cors.ts'

interface MarkReadRequest {
  notification_ids?: string[]
  target_type?: 'responder' | 'reporter' | 'admin'
  target_id?: string
  mark_all?: boolean
  type?: string
}

interface MarkReadResponse {
  success: boolean
  updated_count: number
  message: string
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
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: {
            Authorization: req.headers.get('Authorization') ?? ''
          }
        }
      }
    )

    // Parse request
    const requestData: MarkReadRequest = await req.json()

    // Validate request
    validateMarkReadRequest(requestData)

    // Get user info for authorization
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      throw new Error('Authentication required')
    }

    // Determine target_id based on user and target_type
    const targetId = await resolveTargetId(supabaseClient, user.id, requestData.target_type, requestData.target_id)

    // Build update query
    const updateQuery = buildUpdateQuery(supabaseClient, targetId, requestData)

    // Execute update
    const { data, error, count } = await updateQuery
      .update({
        is_read: true,
        updated_at: new Date().toISOString()
      })
      .select('id')

    if (error) {
      throw new Error(`Failed to update notifications: ${error.message}`)
    }

    const updatedCount = count || data?.length || 0

    const response: MarkReadResponse = {
      success: true,
      updated_count: updatedCount,
      message: `Successfully marked ${updatedCount} notification(s) as read`
    }

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in notifications/mark-read function:', error)
    
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
 * Validate mark read request
 */
function validateMarkReadRequest(data: MarkReadRequest): void {
  if (data.mark_all) {
    if (!data.target_type || !['responder', 'reporter', 'admin'].includes(data.target_type)) {
      throw new Error('target_type is required when mark_all is true')
    }
  } else if (data.notification_ids) {
    if (!Array.isArray(data.notification_ids) || data.notification_ids.length === 0) {
      throw new Error('notification_ids must be a non-empty array')
    }
    
    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    for (const id of data.notification_ids) {
      if (!uuidRegex.test(id)) {
        throw new Error(`Invalid notification ID format: ${id}`)
      }
    }
  } else {
    throw new Error('Either notification_ids or mark_all must be provided')
  }

  if (data.type && typeof data.type !== 'string') {
    throw new Error('type must be a string')
  }
}

/**
 * Resolve target_id based on user and target_type
 */
async function resolveTargetId(
  supabaseClient: any,
  userId: string,
  targetType?: string,
  providedTargetId?: string
): Promise<string | null> {
  if (providedTargetId) {
    return providedTargetId
  }

  if (!targetType) {
    return null
  }

  switch (targetType) {
    case 'responder':
      const { data: responder } = await supabaseClient
        .from('responder')
        .select('id')
        .eq('user_id', userId)
        .single()
      
      if (!responder) {
        throw new Error('User is not a responder')
      }
      return responder.id

    case 'reporter':
      const { data: reporter } = await supabaseClient
        .from('reporter')
        .select('id')
        .eq('user_id', userId)
        .single()
      
      if (!reporter) {
        throw new Error('User is not a reporter')
      }
      return reporter.id

    case 'admin':
      // For admin, use user_id directly
      return userId

    default:
      throw new Error('Invalid target_type')
  }
}

/**
 * Build update query based on request parameters
 */
function buildUpdateQuery(
  supabaseClient: any,
  targetId: string | null,
  requestData: MarkReadRequest
): any {
  let query = supabaseClient
    .from('notifications')
    .update({}, { count: 'exact' })

  if (requestData.notification_ids) {
    // Update specific notifications by ID
    query = query.in('id', requestData.notification_ids)
  } else if (requestData.mark_all && targetId) {
    // Update all notifications for target
    query = query
      .eq('target_type', requestData.target_type)
      .eq('target_id', targetId)
      .eq('is_read', false) // Only update unread notifications

    if (requestData.type) {
      query = query.eq('type', requestData.type)
    }
  }

  return query
}
