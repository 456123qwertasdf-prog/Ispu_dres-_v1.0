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
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #1f2937; background-color: #f3f4f6; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 40px auto; background-color: white; border-radius: 16px; overflow: hidden; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04); }
        .header { background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%); color: white; padding: 40px 30px; text-align: center; }
        .header h1 { margin: 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 10px 0 0 0; opacity: 0.95; font-size: 14px; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; font-weight: 600; color: #111827; margin-bottom: 20px; }
        .credentials { background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%); padding: 25px; margin: 25px 0; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }
        .credential-item { margin: 15px 0; }
        .label { font-weight: 600; color: #78350f; font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px; }
        .value { font-family: 'Courier New', monospace; background-color: white; padding: 12px 16px; border-radius: 8px; margin-top: 8px; display: block; font-size: 16px; color: #1f2937; border: 2px solid #fbbf24; font-weight: 600; }
        .button { display: inline-block; background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%); color: white !important; padding: 16px 32px; text-decoration: none; border-radius: 10px; margin: 25px 0; font-weight: 700; font-size: 16px; box-shadow: 0 10px 15px -3px rgba(220, 38, 38, 0.3); transition: all 0.3s; }
        .button:hover { transform: translateY(-2px); box-shadow: 0 20px 25px -5px rgba(220, 38, 38, 0.4); }
        .apk-download { background: linear-gradient(135deg, #10b981 0%, #059669 100%); padding: 20px; margin: 25px 0; border-radius: 12px; text-align: center; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }
        .apk-download h3 { margin: 0 0 12px 0; color: white; font-size: 18px; }
        .apk-download p { margin: 0 0 15px 0; color: rgba(255,255,255,0.95); font-size: 14px; }
        .apk-button { display: inline-block; background-color: white; color: #059669 !important; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: 700; font-size: 15px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }
        .footer { text-align: center; color: #6b7280; font-size: 13px; padding: 30px; background-color: #f9fafb; }
        .warning { background-color: #fef3c7; border-left: 5px solid #f59e0b; padding: 20px; margin: 25px 0; border-radius: 8px; }
        .warning strong { color: #92400e; font-size: 15px; }
        .info-box { background-color: #eff6ff; border-left: 5px solid #3b82f6; padding: 20px; margin: 25px 0; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚨 LSPU Emergency Response</h1>
            <p>Welcome to the Kapiyu Disaster Risk Reduction System</p>
        </div>
        <div class="content">
            <p class="greeting">Hello ${displayName},</p>
            
            <p style="font-size: 15px; line-height: 1.7;">Your account has been successfully created! You can now access the emergency response system.</p>
            
            <div class="credentials">
                <div class="credential-item">
                    <div class="label">📧 Email Address</div>
                    <div class="value">${email}</div>
                </div>
                <div class="credential-item">
                    <div class="label">🔒 Temporary Password</div>
                    <div class="value">${password}</div>
                </div>
                ${role ? `<div class="credential-item">
                    <div class="label">👤 Role</div>
                    <div class="value">${role}</div>
                </div>` : ''}
            </div>
            
            <div class="warning">
                <strong>⚠️ Security Notice:</strong> Please change your password immediately after your first login for your account security.
            </div>
            
            <div style="text-align: center; margin: 30px 0;">
                ${verificationLink ? `
                <p style="font-size: 15px; margin-bottom: 20px;">Click the button below to access the system:</p>
                <a href="${verificationLink}" class="button">🚀 Access System</a>
                ` : `
                <a href="https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev/login" class="button">🚀 Login Now</a>
                `}
            </div>
            
            <div class="apk-download">
                <h3>📱 Download Mobile App</h3>
                <p>Get the LSPU Emergency Response app for Android</p>
                <a href="https://github.com/456123qwertasdf-prog/lspu_dres/raw/master/public/lspu-emergency-response.apk" class="apk-button">⬇️ Download Android APK</a>
            </div>
            
            <div class="info-box">
                <p style="margin: 0; font-size: 14px;"><strong>🌐 Web Login:</strong> <a href="https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev/" style="color: #3b82f6; text-decoration: none;">https://dres-lspu-edu-ph.456123qwert-asdf.workers.dev/</a></p>
            </div>
            
            <p style="margin-top: 30px; font-size: 15px;">Thank you for joining the LSPU Emergency Response System!</p>
            
            <p style="margin-top: 20px; font-size: 14px; color: #6b7280;">Need help? Contact your system administrator.</p>
        </div>
        
        <div class="footer">
            <p style="margin: 5px 0;">This is an automated message. Please do not reply to this email.</p>
            <p style="margin: 5px 0; font-weight: 600;">© ${new Date().getFullYear()} LSPU Emergency Response System - Kapiyu</p>
            <p style="margin: 5px 0;">Disaster Risk Reduction and Emergency Response</p>
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

