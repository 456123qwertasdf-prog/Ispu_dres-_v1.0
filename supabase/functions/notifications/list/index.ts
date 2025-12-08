import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../../_shared/cors.ts'

interface ListNotificationsRequest {
  target_type: 'responder' | 'reporter' | 'admin'
  target_id?: string
  page?: number
  limit?: number
  unread_only?: boolean
  type?: string
}

interface NotificationResponse {
  id: string
  target_type: string
  target_id: string
  type: string
  title: string
  message: string
  payload: any
  is_read: boolean
  created_at: string
  updated_at: string
}

interface PaginatedResponse {
  notifications: NotificationResponse[]
  pagination: {
    page: number
    limit: number
    total: number
    total_pages: number
    has_next: boolean
    has_prev: boolean
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'GET' && req.method !== 'POST') {
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

    // Parse request parameters
    let requestData: ListNotificationsRequest
    
    if (req.method === 'GET') {
      const url = new URL(req.url)
      requestData = {
        target_type: url.searchParams.get('target_type') as 'responder' | 'reporter' | 'admin',
        target_id: url.searchParams.get('target_id') || undefined,
        page: parseInt(url.searchParams.get('page') || '1'),
        limit: parseInt(url.searchParams.get('limit') || '20'),
        unread_only: url.searchParams.get('unread_only') === 'true',
        type: url.searchParams.get('type') || undefined
      }
    } else {
      requestData = await req.json()
    }

    // Validate request
    validateListRequest(requestData)

    // Get user info for authorization
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      throw new Error('Authentication required')
    }

    // Determine target_id based on user and target_type
    const targetId = await resolveTargetId(supabaseClient, user.id, requestData.target_type, requestData.target_id)

    // Build query
    const query = buildNotificationsQuery(supabaseClient, targetId, requestData)

    // Execute query with pagination
    const result = await executePaginatedQuery(query, requestData.page!, requestData.limit!)

    // Get total count for pagination
    const { count } = await supabaseClient
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('target_type', requestData.target_type)
      .eq('target_id', targetId)
      .modify((query) => {
        if (requestData.unread_only) {
          query.eq('is_read', false)
        }
        if (requestData.type) {
          query.eq('type', requestData.type)
        }
      })

    const total = count || 0
    const totalPages = Math.ceil(total / requestData.limit!)

    const response: PaginatedResponse = {
      notifications: result.data || [],
      pagination: {
        page: requestData.page!,
        limit: requestData.limit!,
        total,
        total_pages: totalPages,
        has_next: requestData.page! < totalPages,
        has_prev: requestData.page! > 1
      }
    }

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in notifications/list function:', error)
    
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
 * Validate list notifications request
 */
function validateListRequest(data: ListNotificationsRequest): void {
  if (!data.target_type || !['responder', 'reporter', 'admin'].includes(data.target_type)) {
    throw new Error('target_type must be responder, reporter, or admin')
  }

  if (data.page && (data.page < 1 || !Number.isInteger(data.page))) {
    throw new Error('page must be a positive integer')
  }

  if (data.limit && (data.limit < 1 || data.limit > 100 || !Number.isInteger(data.limit))) {
    throw new Error('limit must be between 1 and 100')
  }
}

/**
 * Resolve target_id based on user and target_type
 */
async function resolveTargetId(
  supabaseClient: any,
  userId: string,
  targetType: string,
  providedTargetId?: string
): Promise<string> {
  if (providedTargetId) {
    return providedTargetId
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
 * Build notifications query
 */
function buildNotificationsQuery(
  supabaseClient: any,
  targetId: string,
  requestData: ListNotificationsRequest
): any {
  let query = supabaseClient
    .from('notifications')
    .select('*')
    .eq('target_type', requestData.target_type)
    .eq('target_id', targetId)
    .order('created_at', { ascending: false })

  if (requestData.unread_only) {
    query = query.eq('is_read', false)
  }

  if (requestData.type) {
    query = query.eq('type', requestData.type)
  }

  return query
}

/**
 * Execute paginated query
 */
async function executePaginatedQuery(
  query: any,
  page: number,
  limit: number
): Promise<{ data: NotificationResponse[] }> {
  const offset = (page - 1) * limit
  
  return await query
    .range(offset, offset + limit - 1)
}
