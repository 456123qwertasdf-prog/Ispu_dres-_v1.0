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
    const {
      userId,
      email,
      password,
      firstName,
      lastName,
      role,
      phone,
      studentNumber,
      userType,
      isActive
    } = body || {}

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

    // Update auth user only if fields provided (skip on pure archive/restore)
    const displayName = `${firstName ?? ''} ${lastName ?? ''}`.trim()
    const shouldUpdateAuth = !!(email || password || firstName || lastName || role || phone || studentNumber || userType)
    let authRes: any = null
    if (shouldUpdateAuth) {
      // Get existing user metadata to preserve it
      const { data: existingUser } = await supabase.auth.admin.getUserById(userId)
      const existingMetadata = existingUser?.user?.user_metadata || {}
      
      const authUpdate: any = {
        user_metadata: {
          ...existingMetadata, // Preserve existing metadata
          full_name: displayName || existingMetadata.full_name || undefined,
          role: role ?? existingMetadata.role ?? undefined,
          phone: phone ?? existingMetadata.phone ?? undefined,
          student_number: studentNumber ?? existingMetadata.student_number ?? undefined,
          user_type: userType || existingMetadata.user_type || (studentNumber ? 'student' : undefined) // Always update user_type if provided, or infer from student_number
        }
      }
      if (email) authUpdate.email = email
      if (password) authUpdate.password = password

      const { data, error: authErr } = await supabase.auth.admin.updateUserById(userId, authUpdate)
      authRes = data
      if (authErr) {
        return new Response(
          JSON.stringify({ error: 'Failed to update auth user', details: authErr.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // Move to archive table if isActive === false; restore if isActive === true
    let profile
    if (isActive === false) {
      // Fetch existing profile
      const { data: profCur, error: profCurErr } = await supabase
        .from('user_profiles')
        .select('*')
        .eq('user_id', userId)
        .single()
      if (profCurErr) {
        return new Response(
          JSON.stringify({ error: 'Profile not found for archive', details: profCurErr.message }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      // Insert into archive
      const { error: insArchErr } = await supabase
        .from('user_profiles_archived')
        .upsert([{ 
          user_id: profCur.user_id,
          role: profCur.role,
          name: profCur.name,
          phone: profCur.phone,
          student_number: profCur.student_number,
          is_active: false,
          created_at: profCur.created_at
        }])
      if (insArchErr) {
        return new Response(
          JSON.stringify({ error: 'Failed to archive user', details: insArchErr.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      // Remove from active table
      const { error: delProfErr } = await supabase
        .from('user_profiles')
        .delete()
        .eq('user_id', userId)
      if (delProfErr) {
        return new Response(
          JSON.stringify({ error: 'Failed to remove active profile', details: delProfErr.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    } else {
      // Restore or update active profile
      const profilePayload: any = {}
      if (role !== undefined) profilePayload.role = role
      if (displayName) profilePayload.name = displayName
      if (phone !== undefined) profilePayload.phone = phone
      if (studentNumber !== undefined) profilePayload.student_number = studentNumber
      if (isActive !== undefined) profilePayload.is_active = !!isActive

      // If restoring from archive, move it back
      if (isActive === true) {
        const { data: archived, error: getArchErr } = await supabase
          .from('user_profiles_archived')
          .select('*')
          .eq('user_id', userId)
          .single()
        if (!getArchErr && archived) {
          const toInsert = {
            user_id: archived.user_id,
            role: archived.role,
            name: archived.name,
            phone: archived.phone,
            student_number: archived.student_number,
            is_active: true,
            created_at: archived.created_at
          }
          const { error: insertBackErr } = await supabase
            .from('user_profiles')
            .insert([toInsert])
          if (insertBackErr) {
            // If conflict (duplicate), try updating existing row
            if ((insertBackErr as any).code === '23505') {
              const { error: updErr } = await supabase
                .from('user_profiles')
                .update(toInsert)
                .eq('user_id', userId)
              if (updErr) {
                return new Response(
                  JSON.stringify({ error: 'Failed to update existing profile', details: updErr.message }),
                  { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
              }
            } else {
              return new Response(
                JSON.stringify({ error: 'Failed to restore user', details: insertBackErr.message }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
              )
            }
          }
          await supabase
            .from('user_profiles_archived')
            .delete()
            .eq('user_id', userId)
        }
      }

      // Update active profile if fields provided
      if (Object.keys(profilePayload).length > 0) {
        const { data: prof, error: profErr } = await supabase
          .from('user_profiles')
          .update(profilePayload)
          .eq('user_id', userId)
          .select('*')
          .single()
        if (profErr) {
          return new Response(
            JSON.stringify({ error: 'Failed to update user profile', details: profErr.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }
        profile = prof
      }
    }

    return new Response(
      JSON.stringify({ user: authRes?.user, profile }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: e.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})


