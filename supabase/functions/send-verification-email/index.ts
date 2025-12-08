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
      email,
      password,
      firstName,
      lastName,
      role,
      verificationLink
    } = body || {}

    if (!email || !password) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: email, password' }),
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
    
    const displayName = `${firstName ?? ''} ${lastName ?? ''}`.trim() || email.split('@')[0]
    
    // Create HTML email content with credentials
    const emailHtml = `
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
                    <span class="value">${password}</span>
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

    // Send email using Supabase invite with custom metadata
    // Note: The password will be in metadata but Supabase default template won't show it
    // We need to use a custom email template or external service for production
    const { data: inviteData, error: inviteError } = await supabase.auth.admin.inviteUserByEmail(email, {
      data: {
        full_name: displayName,
        role: role || 'user',
        temporary_password: password, // Store in metadata for custom template access
        verification_link: verificationLink
      },
      redirectTo: verificationLink || undefined
    })

    // IMPORTANT: Supabase's default invite template doesn't include the password
    // For the password to appear in the email, you need to:
    // 1. Configure custom email template in config.toml pointing to verification-with-credentials.html
    // 2. Enable SMTP in config.toml
    // OR use an external email service like Resend
    
    if (inviteError) {
      console.error('Invite email error:', inviteError)
      
      // Try to send via generateLink as fallback
      const { data: linkData, error: linkError } = await supabase.auth.admin.generateLink({
        type: 'signup',
        email: email,
        password: password,
        options: {
          data: {
            full_name: displayName,
            role: role || 'user',
            temporary_password: password
          }
        }
      })

      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'Email invite attempted. Note: Default template may not show password.',
          verificationLink: linkData?.properties?.action_link,
          emailHtml: emailHtml, // Return HTML for manual sending
          note: 'Configure custom email template with SMTP to show credentials in email. See EMAIL_VERIFICATION_SETUP.md',
          credentials: {
            email: email,
            password: password
          }
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Even if invite succeeds, the default template won't show password
    // Return the email HTML and credentials so they can be sent manually or via custom template
    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Invitation email sent. Note: Configure custom template to show credentials.',
        email: email,
        verificationLink: verificationLink,
        emailHtml: emailHtml, // Include HTML with credentials
        credentials: {
          email: email,
          password: password,
          note: 'These credentials are included in emailHtml above'
        },
        setupNote: 'To show credentials in email, configure custom template in config.toml and enable SMTP'
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

