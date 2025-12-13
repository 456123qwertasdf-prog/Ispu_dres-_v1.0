import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
}

// Generate a secure random password
function generateSecurePassword(length: number = 12): string {
  const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'
  const values = crypto.getRandomValues(new Uint32Array(length))
  return Array.from(values, (value) => charset[value % charset.length]).join('')
}

Deno.serve(async (req) => {
  // Handle CORS preflight request - must be the FIRST thing checked
  // Match exact pattern from classify-pending which works
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
      },
    })
  }

  try {
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const body = await req.json()
    let {
      email,
      password,
      firstName,
      lastName,
      role,
      phone,
      studentNumber,
      userType
    } = body || {}

    if (!email || !role) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: email, role' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Generate password if not provided (empty string or undefined/null)
    const generatedPassword = (password && password.trim() !== '') ? password : generateSecurePassword()
    const isTemporaryPassword = !password || password.trim() === ''

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

    // Create auth user with metadata
    const displayName = `${firstName ?? ''} ${lastName ?? ''}`.trim()
    const { data: created, error: createErr } = await supabase.auth.admin.createUser({
      email,
      password: generatedPassword,
      email_confirm: false,
      user_metadata: {
        full_name: displayName || (email.split('@')[0] || 'User'),
        role,
        phone: phone ?? '',
        student_number: studentNumber ?? '',
        user_type: userType ?? '', // Store user type (student/teacher/security_guard)
        must_change_password: true,
        temporary_password: generatedPassword // Store actual password, not boolean
      }
    })

    if (createErr || !created?.user) {
      return new Response(
        JSON.stringify({ error: 'Failed to create auth user', details: createErr?.message || 'Unknown' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const userId = created.user.id

    // Insert profile row
    const { data: profile, error: profileErr } = await supabase
      .from('user_profiles')
      .insert([{
        user_id: userId,
        role,
        name: displayName || (email.split('@')[0] || 'Unknown'),
        phone: phone ?? '',
        student_number: studentNumber ?? '',
        user_type: userType ?? 'student', // Add user_type to profile
        is_active: true
      }])
      .select()
      .single()

    if (profileErr) {
      return new Response(
        JSON.stringify({ error: 'User created but profile insert failed', details: profileErr.message, userId }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Generate verification link and send email with credentials
    let verificationLink = null
    try {
      // Generate email verification link (this also creates the invite email but we'll send our own with credentials)
      // Set redirect to login page after verification
      const redirectUrl = `${SUPABASE_URL.replace('/rest/v1', '').replace('https://', 'http://127.0.0.1:8000') || 'http://127.0.0.1:8000/login.html'}`
      const { data: linkData, error: linkError } = await supabase.auth.admin.generateLink({
        type: 'signup',
        email: email,
        password: generatedPassword,
        options: {
          redirectTo: 'http://127.0.0.1:8000/login.html', // Redirect to login page after verification
          data: {
            full_name: displayName || (email.split('@')[0] || 'User'),
            role,
            must_change_password: true,
            temporary_password: generatedPassword // Store password in metadata for template access
          }
        }
      })

      if (linkData?.properties?.action_link) {
        verificationLink = linkData.properties.action_link
      }

      if (linkError) {
        console.error('Error generating verification link:', linkError)
      }

      // IMPORTANT: Update user metadata FIRST to ensure temporary_password is accessible in email template
      // Supabase email templates read from user_metadata, so we need to update it before sending invite
      const { error: updateError } = await supabase.auth.admin.updateUserById(userId, {
        user_metadata: {
          full_name: displayName || (email.split('@')[0] || 'User'),
          role,
          phone: phone ?? '',
          student_number: studentNumber ?? '',
          user_type: userType ?? '', // Store user type in metadata
          must_change_password: true,
          temporary_password: generatedPassword // Store actual password for template access
        }
      })

      if (updateError) {
        console.error('Error updating user metadata:', updateError)
      } else {
        console.log('✅ User metadata updated with temporary_password:', generatedPassword.substring(0, 3) + '***')
      }
      
      // verificationLink was already generated above, use it

      // Send invitation email via Supabase - will use custom template if configured
      // IMPORTANT: The 'data' parameter maps to {{ .Data.* }} in templates
      // However, there's a known issue where inviteUserByEmail might not pass data correctly
      // So we also store it in user_metadata for fallback
      const { data: inviteData, error: inviteError } = await supabase.auth.admin.inviteUserByEmail(email, {
        data: {
          full_name: displayName || (email.split('@')[0] || 'User'),
          role,
          must_change_password: true,
          temporary_password: generatedPassword // This should map to {{ .Data.temporary_password }} in template
        },
        redirectTo: 'http://127.0.0.1:8000/login.html'
      })
      
      if (inviteError) {
        console.error('❌ Error sending invitation email:', inviteError)
        console.log('⚠️  Email may not be sent. Password available in response for manual sharing.')
      } else {
        console.log('✅ Invitation email sent via Supabase')
        console.log('🔑 Password for email:', generatedPassword)
        console.log('📧 Template variable should be: {{ .Data.temporary_password }}')
        console.log('🔗 Verification link:', finalVerificationLink)
        console.log('⚠️  CRITICAL: Make sure custom template is uploaded in Supabase Dashboard!')
        console.log('    Dashboard: https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/auth')
      }

    } catch (emailError) {
      console.error('Email sending error (non-fatal):', emailError)
      // Continue - user is created even if email fails
    }

    // Prepare email content for manual sending if automated email fails
    const emailContent = {
      subject: 'Account Verification - LSPU Emergency Response System',
      html: `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #dc2626; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background-color: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
        .credentials { background-color: white; padding: 20px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #dc2626; }
        .credential-item { margin: 10px 0; }
        .label { font-weight: bold; color: #374151; }
        .value { font-family: monospace; background-color: #f3f4f6; padding: 8px; border-radius: 4px; margin-top: 5px; display: block; }
        .button { display: inline-block; background-color: #dc2626; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
        .footer { text-align: center; color: #6b7280; font-size: 12px; margin-top: 30px; }
        .warning { background-color: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin: 20px 0; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Account Verification - LSPU Emergency Response System</h1>
        </div>
        <div class="content">
            <p>Hello ${displayName},</p>
            
            <p>Your account has been created successfully. Please use the following credentials to log in:</p>
            
            <div class="credentials">
                <div class="credential-item">
                    <span class="label">Email:</span>
                    <span class="value">${email}</span>
                </div>
                <div class="credential-item">
                    <span class="label">Temporary Password:</span>
                    <span class="value">${generatedPassword}</span>
                </div>
                ${role ? `<div class="credential-item">
                    <span class="label">Role:</span>
                    <span class="value">${role}</span>
                </div>` : ''}
            </div>
            
            <div class="warning">
                <strong>⚠️ Important:</strong> For security reasons, please change your password immediately after your first login.
            </div>
            
            ${verificationLink ? `
            <p>Click the button below to verify your email and complete your account setup:</p>
            <a href="${verificationLink}" class="button">Verify Email Address</a>
            <p style="font-size: 12px; color: #6b7280;">Or copy and paste this link into your browser:<br>${verificationLink}</p>
            ` : `
            <p>Please verify your email address by logging in with the credentials above.</p>
            `}
            
            <p>Thank you for joining the LSPU Emergency Response System!</p>
            
            <div class="footer">
                <p>This is an automated message. Please do not reply to this email.</p>
                <p>© ${new Date().getFullYear()} LSPU Emergency Response System</p>
            </div>
        </div>
    </div>
</body>
</html>
      `
    }

    return new Response(
      JSON.stringify({ 
        user: created.user, 
        profile,
        message: 'User created successfully. Verification email sent.',
        password_sent: isTemporaryPassword,
        email: email,
        password: generatedPassword, // Include password directly for admin to see/share
        credentials: {
          email: email,
          password: generatedPassword,
          role: role
        },
        verification_link: verificationLink,
        email_content: emailContent,
        note: isTemporaryPassword 
          ? `Temporary password generated: ${generatedPassword}. User should change it after first login.`
          : 'Password provided by admin. User should change it after first login.'
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


