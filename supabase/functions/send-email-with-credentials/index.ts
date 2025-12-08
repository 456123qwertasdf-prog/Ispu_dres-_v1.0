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

    const displayName = `${firstName ?? ''} ${lastName ?? ''}`.trim() || email.split('@')[0]
    
    // Create email HTML with credentials
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
            <p style="font-size: 12px; color: #6b7280;">Or copy and paste this link into your browser:<br><a href="${verificationLink}">${verificationLink}</a></p>
            <p style="margin-top: 20px;"><strong>Or login directly:</strong> <a href="http://127.0.0.1:8000/login.html">http://127.0.0.1:8000/login.html</a></p>
            ` : `
            <p>Please verify your email address by logging in with the credentials above at <a href="http://127.0.0.1:8000/login.html">http://127.0.0.1:8000/login.html</a></p>
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

    // Try to send via Resend (if API key is configured)
    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
    
    if (RESEND_API_KEY) {
      try {
        const resendResponse = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${RESEND_API_KEY}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            from: 'LSPU Emergency Response System <onboarding@resend.dev>',
            to: email,
            subject: 'Account Verification - LSPU Emergency Response System',
            html: emailHtml
          })
        })

        if (resendResponse.ok) {
          const resendData = await resendResponse.json()
          return new Response(
            JSON.stringify({ 
              success: true, 
              message: 'Email sent successfully with credentials via Resend',
              email: email,
              emailId: resendData.id
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }
      } catch (resendError) {
        console.error('Resend email error:', resendError)
        // Try to get error details
        try {
          const errorText = await resendResponse?.text()
          console.error('Resend error details:', errorText)
        } catch (e) {
          // Ignore
        }
      }
    }
    
    // If Resend is not configured or failed, log clear instructions
    if (!RESEND_API_KEY) {
      console.error('❌ RESEND_API_KEY not found in environment variables!')
      console.error('❌ Email will NOT contain credentials.')
      console.error('📝 To fix: Add RESEND_API_KEY secret to Supabase Edge Functions')
    }

    // Fallback: Use Supabase invite (will send email but password won't show in default template)
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
    const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    
    if (SUPABASE_URL && SERVICE_ROLE) {
      const supabase = createClient(SUPABASE_URL, SERVICE_ROLE)
      
      // Don't send via Supabase invite - it won't show credentials
      // Instead, return the email HTML so it can be sent via Resend or manually
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Email NOT sent with credentials. Resend API not configured. Please configure Resend API key or SMTP.',
          email: email,
          credentials: {
            email: email,
            password: password
          },
          emailHtml: emailHtml,
          subject: 'Account Verification - LSPU Emergency Response System',
          setupInstructions: 'To send emails with credentials: 1) Sign up at resend.com, 2) Get API key, 3) Add RESEND_API_KEY secret to Supabase Edge Functions'
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // If all else fails, return email HTML for manual sending
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: 'Could not send email automatically. Please send manually.',
        email: email,
        credentials: {
          email: email,
          password: password
        },
        emailHtml: emailHtml,
        subject: 'Account Verification - LSPU Emergency Response System',
        instructions: 'Copy the emailHtml content and send it manually to the user via your email client'
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

