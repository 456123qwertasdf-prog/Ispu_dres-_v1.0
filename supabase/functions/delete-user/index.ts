import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
}

// Run delete and ignore non-fatal errors (missing table, no rows, RLS, etc.)
async function deleteWhere(
  supabase: ReturnType<typeof createClient>,
  table: string,
  column: string,
  value: string,
  optional = true
): Promise<{ error?: string }> {
  const { error } = await supabase.from(table).delete().eq(column, value)
  if (error && optional) {
    if (error.code !== 'PGRST116' && error.code !== '42P01') {
      console.warn(`Delete ${table}.${column}=*:`, error.message)
    }
    return {}
  }
  if (error) return { error: error.message }
  return {}
}

// Update column to null where column = value (for optional FKs we want to keep rows)
async function nullWhere(
  supabase: ReturnType<typeof createClient>,
  table: string,
  column: string,
  value: string,
  optional = true
): Promise<{ error?: string }> {
  const { error } = await supabase.from(table).update({ [column]: null }).eq(column, value)
  if (error && optional) {
    if (error.code !== 'PGRST116' && error.code !== '42P01') {
      console.warn(`Null ${table}.${column}=*:`, error.message)
    }
    return {}
  }
  if (error) return { error: error.message }
  return {}
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

    // ---- 1. Unlink or remove references to this user ----
    await deleteWhere(supabase, 'classification_corrections', 'corrected_by', userId)
    await nullWhere(supabase, 'reports_archived', 'corrected_by', userId)
    await nullWhere(supabase, 'reports_archived', 'archived_by', userId)
    await nullWhere(supabase, 'reports_archived', 'user_id', userId)

    // ---- 2. Delete user-owned data (order respects FKs) ----
    await deleteWhere(supabase, 'reports', 'user_id', userId)
    await deleteWhere(supabase, 'learning_progress', 'user_id', userId)
    await deleteWhere(supabase, 'lms_results', 'user_id', userId)
    await deleteWhere(supabase, 'notifications', 'user_id', userId)
    await deleteWhere(supabase, 'notifications_subscriptions', 'user_id', userId)
    await deleteWhere(supabase, 'audit_log', 'user_id', userId)
    await deleteWhere(supabase, 'onesignal_subscriptions', 'user_id', userId)

    // Responder and reporter (may be referenced by assignment; CASCADE will clean assignment when responder/reporter row is removed)
    const { data: responderRows } = await supabase.from('responder').select('id').eq('user_id', userId)
    const responderIds = (responderRows || []).map((r: { id: string }) => r.id)
    for (const rid of responderIds) {
      await deleteWhere(supabase, 'assignment', 'responder_id', rid)
    }
    await deleteWhere(supabase, 'responder', 'user_id', userId)
    await deleteWhere(supabase, 'reporter', 'user_id', userId)

    await deleteWhere(supabase, 'announcements', 'created_by', userId)

    // ---- 3. Profiles (current and archived) ----
    const { error: delProfErr } = await supabase
      .from('user_profiles')
      .delete()
      .eq('user_id', userId)
    if (delProfErr && delProfErr.code !== 'PGRST116') {
      console.warn('Error deleting from user_profiles:', delProfErr.message)
    }

    const { error: delArchErr } = await supabase
      .from('user_profiles_archived')
      .delete()
      .eq('user_id', userId)
    if (delArchErr && delArchErr.code !== 'PGRST116') {
      console.warn('Error deleting from user_profiles_archived:', delArchErr.message)
    }

    // ---- 4. Delete from Supabase Auth (must be last) ----
    const { error: authErr } = await supabase.auth.admin.deleteUser(userId)

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
        userId
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
