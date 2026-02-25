import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get all users from user_profiles table
    let { data: userProfiles, error: profilesError } = await supabaseClient
      .from('user_profiles')
      .select('*')
      .order('created_at', { ascending: false })

    // Fetch auth users early so we can sync any missing profiles (e.g. mobile signups)
    const { data: authUsersData, error: authUsersErr } = await supabaseClient.auth.admin.listUsers()
    const authUsers = authUsersErr ? [] : (authUsersData?.users ?? [])

    // Sync auth users that have no profile (e.g. signed up on mobile; trigger may not have run)
    const profileUserIds = new Set((userProfiles ?? []).map((p: any) => p.user_id))
    const missingAuthUsers = authUsers.filter((u: any) => !profileUserIds.has(u.id))
    if (missingAuthUsers.length > 0) {
      const profilesToInsert = missingAuthUsers.map((u: any) => ({
        user_id: u.id,
        role: u.user_metadata?.role || u.user_metadata?.user_role || 'citizen',
        name: u.user_metadata?.full_name || u.user_metadata?.name || u.email?.split('@')[0] || 'Unknown',
        user_type: u.user_metadata?.user_type || 'student',
        student_number: u.user_metadata?.student_number || null,
        is_active: true,
        created_at: u.created_at,
      }))
      const { error: insertErr } = await supabaseClient
        .from('user_profiles')
        .insert(profilesToInsert)
      if (!insertErr) {
        // Re-fetch profiles so the list includes the newly synced users
        const { data: refetched, error: refetchErr } = await supabaseClient
          .from('user_profiles')
          .select('*')
          .order('created_at', { ascending: false })
        if (!refetchErr && refetched) {
          userProfiles = refetched
        }
      }
    }

    if (profilesError) {
      console.error('Error fetching user profiles:', profilesError)
      
      // If user_profiles is empty, try to sync from auth.users
      console.log('User profiles table empty, attempting to sync from auth.users...')
      
      // Get all auth users
      const { data: authUsers, error: authError } = await supabaseClient.auth.admin.listUsers()
      
      if (authError) {
        console.error('Error fetching auth users:', authError)
        return new Response(
          JSON.stringify({ error: 'Failed to fetch users', details: authError.message }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      // Convert auth users to user_profiles format and insert them
      const profilesToInsert = authUsers.users.map((user: any) => ({
        user_id: user.id,
        role: user.user_metadata?.role || user.user_metadata?.user_role || 'citizen',
        name: user.user_metadata?.full_name || user.user_metadata?.name || user.email?.split('@')[0] || 'Unknown',
        user_type: user.user_metadata?.user_type || 'student',
        student_number: user.user_metadata?.student_number || null,
        is_active: true,
        created_at: user.created_at
      }))

      // Insert profiles into user_profiles table
      const { data: insertedProfiles, error: insertError } = await supabaseClient
        .from('user_profiles')
        .insert(profilesToInsert)
        .select()

      if (insertError) {
        console.error('Error inserting user profiles:', insertError)
        return new Response(
          JSON.stringify({ error: 'Failed to sync users', details: insertError.message }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      console.log('Successfully synced users to user_profiles table')
      return new Response(
        JSON.stringify({ users: insertedProfiles }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // If table is empty, bootstrap from auth.users
    let profiles = userProfiles
    if (!profilesError && (!userProfiles || userProfiles.length === 0)) {
      const { data: authBootstrap, error: authBootstrapErr } = await supabaseClient.auth.admin.listUsers()
      if (!authBootstrapErr && authBootstrap?.users) {
        const profilesToInsert = authBootstrap.users.map((user: any) => ({
          user_id: user.id,
          role: user.user_metadata?.role || user.user_metadata?.user_role || 'citizen',
          name: user.user_metadata?.full_name || user.user_metadata?.name || user.email?.split('@')[0] || 'Unknown',
          user_type: user.user_metadata?.user_type || 'student',
          student_number: user.user_metadata?.student_number || null,
          is_active: true,
          created_at: user.created_at
        }))
        const { data: inserted, error: insertErr } = await supabaseClient
          .from('user_profiles')
          .insert(profilesToInsert)
          .select('*')
        if (!insertErr && inserted) {
          profiles = inserted
        }
      }
    }

    // Enrich profiles with email, last_sign_in, and user_type from auth (already fetched above)
    let enriched = profiles
    if (authUsers.length > 0) {
      const authById = new Map(authUsers.map((u: any) => [u.id, u]))
      enriched = profiles.map((p: any) => {
        const au: any = authById.get(p.user_id)
        return {
          ...p,
          email: au?.email || null,
          last_sign_in_at: au?.last_sign_in_at || null,
          user_type: au?.user_metadata?.user_type || null, // Include user type from metadata
          user_metadata: au?.user_metadata || null // Include full metadata for access
        }
      })
    }

    // Return enriched user profiles
    return new Response(
      JSON.stringify({ users: enriched || [] }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
