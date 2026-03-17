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
      userType,
      userTypes,
      leaderId,
      teamName
    } = body || {}

    if (!email || !role) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: email, role' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Only @gmail.com emails are allowed for account creation
    const emailTrimmedForDomain = (email ?? '').toString().trim().toLowerCase()
    if (!emailTrimmedForDomain.endsWith('@gmail.com')) {
      return new Response(
        JSON.stringify({
          error: 'Only Gmail addresses are allowed',
          code: 'INVALID_EMAIL_DOMAIN',
          message: 'Please use a valid @gmail.com email address.',
          errors: [{ code: 'INVALID_EMAIL_DOMAIN', field: 'gmail', message: 'Only @gmail.com addresses are allowed.' }]
        }),
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

    const typesArr = Array.isArray(userTypes) && userTypes.length ? userTypes : (userType ? [userType] : ['student'])
    const displayName = `${firstName ?? ''} ${lastName ?? ''}`.trim()

    const errors: { code: string; field: string; message: string }[] = []

    // Check for duplicate ID number (student_number)
    const studentNum = (studentNumber ?? '').toString().trim()
    if (studentNum) {
      const { data: idExists } = await supabase.rpc('check_student_number_exists', { num: studentNum })
      if (idExists === true) {
        errors.push({
          code: 'STUDENT_NUMBER_EXISTS',
          field: 'studentNumber',
          message: 'This ID number is already registered. Use a different ID number or find the user in the list.'
        })
      }
    }

    // Check for duplicate phone (contact number)
    const phoneStr = (phone ?? '').toString().trim()
    if (phoneStr) {
      const { data: phoneMatch } = await supabase.from('user_profiles').select('user_id').eq('phone', phoneStr).limit(1)
      if (phoneMatch && phoneMatch.length > 0) {
        errors.push({
          code: 'PHONE_EXISTS',
          field: 'contactNumber',
          message: 'This contact number is already registered. Use a different number or find the user in the list.'
        })
      }
    }

    // Check for duplicate email (so we can return it together with ID/phone errors)
    const emailTrimmed = (email ?? '').toString().trim().toLowerCase()
    if (emailTrimmed) {
      try {
        let page = 1
        const perPage = 1000
        let emailExists = false
        while (true) {
          const { data: listData } = await supabase.auth.admin.listUsers({ page: String(page), per_page: String(perPage) })
          const list = (listData as { users?: { email?: string }[]; nextPage?: number }) || {}
          const users = list.users || []
          if (users.some((u) => (u.email || '').trim().toLowerCase() === emailTrimmed)) {
            emailExists = true
            break
          }
          if (users.length < perPage || list.nextPage == null) break
          page = list.nextPage
        }
        if (emailExists) {
          errors.push({
            code: 'EMAIL_EXISTS',
            field: 'gmail',
            message: 'This email is already registered. Use a different email or find the user in the list.'
          })
        }
      } catch (_) {
        // If listUsers fails, we will still detect email duplicate when createUser fails below
      }
    }

    if (errors.length > 0) {
      const codes = errors.map((e) => e.code)
      const codeToLabel = (code: string) =>
        code === 'STUDENT_NUMBER_EXISTS' ? 'ID number' : code === 'PHONE_EXISTS' ? 'Contact number' : code === 'EMAIL_EXISTS' ? 'Email' : code
      const message = errors.length === 1
        ? errors[0].message
        : `The following already exist: ${errors.map((e) => codeToLabel(e.code)).join(', ')}. Please change them or find the user in the list.`
      return new Response(
        JSON.stringify({
          code: codes[0],
          codes,
          errors,
          message,
          error: 'Validation failed'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { data: created, error: createErr } = await supabase.auth.admin.createUser({
      email,
      password: generatedPassword,
      email_confirm: false,
      user_metadata: {
        full_name: displayName || (email.split('@')[0] || 'User'),
        role,
        phone: phone ?? '',
        student_number: studentNumber ?? '',
        user_type: typesArr[0],
        user_types: typesArr,
        must_change_password: true,
        temporary_password: generatedPassword
      }
    })

    if (createErr || !created?.user) {
      const details = createErr?.message || 'Unknown'
      const isDuplicate = /already registered|already exists|duplicate/i.test(details)
      const errList = isDuplicate
        ? [{ code: 'EMAIL_EXISTS', field: 'gmail', message: 'This email is already registered. Use a different email or find the user in the list.' }]
        : []
      return new Response(
        JSON.stringify({
          code: isDuplicate ? 'EMAIL_EXISTS' : 'AUTH_ERROR',
          codes: isDuplicate ? ['EMAIL_EXISTS'] : [],
          errors: errList,
          message: isDuplicate
            ? 'This email is already registered. Use a different email or find the user in the list.'
            : 'Failed to create account. ' + details,
          error: isDuplicate ? 'Email already registered' : 'Failed to create auth user',
          details
        }),
        { status: isDuplicate ? 400 : 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const userId = created.user.id

    const { data: profile, error: profileErr } = await supabase
      .from('user_profiles')
      .insert([{
        user_id: userId,
        role,
        name: displayName || (email.split('@')[0] || 'Unknown'),
        phone: phone ?? '',
        student_number: studentNumber ?? '',
        user_type: typesArr[0],
        user_types: typesArr,
        is_active: true
      }])
      .select()
      .single()

    if (profileErr) {
      const msg = profileErr.message || ''
      const isDuplicate = /duplicate|unique|already exists/i.test(msg)
      let code = 'PROFILE_INSERT_ERROR'
      let field = 'studentNumber'
      let message = 'User account was created but profile could not be saved. Try again or edit the user.'
      if (isDuplicate) {
        if (/student_number|student number|id number/i.test(msg)) {
          code = 'STUDENT_NUMBER_EXISTS'
          field = 'studentNumber'
          message = 'This ID number is already registered. Use a different ID number or find the user in the list.'
        } else if (/phone|contact/i.test(msg)) {
          code = 'PHONE_EXISTS'
          field = 'contactNumber'
          message = 'This contact number is already registered. Use a different number or find the user in the list.'
        } else {
          message = 'This ID number, email, or contact number may already be in use. Check and try again.'
        }
      }
      const errList = isDuplicate ? [{ code, field, message }] : []
      return new Response(
        JSON.stringify({
          code,
          codes: isDuplicate ? [code] : [],
          errors: errList,
          message,
          error: 'Profile insert failed',
          details: msg,
          userId
        }),
        { status: isDuplicate ? 400 : 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // When role is responder, create a responder row so the mobile app dashboard can load
    if (role === 'responder') {
      const responderName = displayName || (email.split('@')[0] || 'Responder')
      const responderPhone = (phone && phone.trim() !== '') ? phone.trim() : `pending-${userId}`
      const { error: responderErr } = await supabase
        .from('responder')
        .insert([{
          user_id: userId,
          name: responderName,
          phone: responderPhone,
          role: 'Emergency Responder',
          status: 'active',
          is_available: true,
          leader_id: (leaderId && leaderId.trim() !== '') ? leaderId : null,
          team_name: (teamName && teamName.trim() !== '') ? teamName.trim() : null
        }])
      if (responderErr) {
        console.error('Responder row insert failed (non-fatal):', responderErr.message)
      }
    }

    // Generate verification link and send email with credentials
    let verificationLink = null
    try {
      // Generate email verification link (this also creates the invite email but we'll send our own with credentials)
      // Set redirect to login page after verification
      const redirectUrl = 'https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev/login'
      const { data: linkData, error: linkError } = await supabase.auth.admin.generateLink({
        type: 'signup',
        email: email,
        password: generatedPassword,
        options: {
          redirectTo: 'https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev/login', // Redirect to login page after verification
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
          user_type: typesArr[0],
          user_types: typesArr,
          must_change_password: true,
          temporary_password: generatedPassword
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
        redirectTo: 'https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev/login'
      })
      
      if (inviteError) {
        console.error('❌ Error sending invitation email:', inviteError)
        console.log('⚠️  Email may not be sent. Password available in response for manual sharing.')
      } else {
        console.log('✅ Invitation email sent via Supabase')
        console.log('🔑 Password for email:', generatedPassword)
        console.log('📧 Template variable should be: {{ .Data.temporary_password }}')
        console.log('🔗 Verification link:', verificationLink)
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


