import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const body = await req.json()
    const { userId } = body || {}

    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: userId' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
    const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    if (!SUPABASE_URL || !SERVICE_ROLE) {
      return new Response(
        JSON.stringify({ error: 'Server misconfiguration', details: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      SUPABASE_URL,
      SERVICE_ROLE
    )

    // Delete from user_profiles table (if exists)
    const { error: delProfErr } = await supabase
      .from('user_profiles')
      .delete()
      .eq('user_id', userId)
    
    // Ignore error if profile doesn't exist - continue to delete from archive
    if (delProfErr && delProfErr.code !== 'PGRST116') {
      console.warn('Error deleting from user_profiles:', delProfErr.message)
    }

    // Delete from user_profiles_archived table (if exists)
    const { error: delArchErr } = await supabase
      .from('user_profiles_archived')
      .delete()
      .eq('user_id', userId)
    
    // Ignore error if archived profile doesn't exist
    if (delArchErr && delArchErr.code !== 'PGRST116') {
      console.warn('Error deleting from user_profiles_archived:', delArchErr.message)
    }

    // Delete from Supabase Auth (this is the critical part!)
    const { data: authData, error: authErr } = await supabase.auth.admin.deleteUser(userId)
    
    if (authErr) {
      return new Response(
        JSON.stringify({ 
          error: 'Failed to delete user from authentication', 
          details: authErr.message 
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'User deleted permanently from database and authentication',
        userId: userId
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: e.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

