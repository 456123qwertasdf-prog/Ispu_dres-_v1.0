import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

function generateSecurePassword(length: number = 12): string {
  const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'
  const values = crypto.getRandomValues(new Uint32Array(length))
  return Array.from(values, (value) => charset[value % charset.length]).join('')
}

const REDIRECT_URL = 'https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev/login'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const body = await req.json().catch(() => ({}))
    const { user_id } = body || {}

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: user_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
    const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    if (!SUPABASE_URL || !SERVICE_ROLE) {
      return new Response(
        JSON.stringify({ error: 'Server misconfiguration' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE)

    const { data: userData, error: getUserError } = await supabase.auth.admin.getUserById(user_id)
    const user = userData?.user

    if (getUserError || !user) {
      return new Response(
        JSON.stringify({ error: 'User not found', details: getUserError?.message || 'Unknown' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (user.email_confirmed_at) {
      return new Response(
        JSON.stringify({ success: true, message: 'User is already verified.', already_verified: true }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const email = user.email
    if (!email) {
      return new Response(
        JSON.stringify({ error: 'User has no email' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const newPassword = generateSecurePassword()
    const displayName = user.user_metadata?.full_name || user.user_metadata?.name || email.split('@')[0] || 'User'
    const role = user.user_metadata?.role || 'citizen'

    await supabase.auth.admin.updateUserById(user_id, {
      password: newPassword,
      user_metadata: {
        ...user.user_metadata,
        must_change_password: true,
        temporary_password: newPassword,
      },
    })

    const { data: linkData, error: linkError } = await supabase.auth.admin.generateLink({
      type: 'signup',
      email,
      password: newPassword,
      options: {
        redirectTo: REDIRECT_URL,
        data: {
          full_name: displayName,
          role,
          must_change_password: true,
          temporary_password: newPassword,
        },
      },
    })

    const verificationLink = linkData?.properties?.action_link ?? null

    if (linkError) {
      console.error('Resend verification generateLink error:', linkError)
      return new Response(
        JSON.stringify({ error: 'Failed to generate verification link', details: linkError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { error: inviteError } = await supabase.auth.admin.inviteUserByEmail(email, {
      data: {
        full_name: displayName,
        role,
        must_change_password: true,
        temporary_password: newPassword,
      },
      redirectTo: REDIRECT_URL,
    })

    if (inviteError) {
      console.warn('Resend invite email (may be expected for existing user):', inviteError.message)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'New verification link generated. Invite email may not have been sent for existing user; share the link below if needed.',
          verification_link: verificationLink,
          email,
          temporary_password: newPassword,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Verification email sent successfully.',
        verification_link: verificationLink,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (e) {
    console.error('Resend verification error:', e)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: (e as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
