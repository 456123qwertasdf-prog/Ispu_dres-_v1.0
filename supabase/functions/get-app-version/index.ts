import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'GET' && req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  try {
    const url = new URL(req.url)
    let platform = (url.searchParams.get('platform') || 'android').toLowerCase()
    if ((req.method === 'POST')) {
      try {
        const body = await req.json().catch(() => ({}))
        if (body && typeof body.platform === 'string') platform = body.platform.toLowerCase()
      } catch { /* use URL or default */ }
    }
    console.log('[get-app-version] invoked', { platform, method: req.method })

    if (platform !== 'android' && platform !== 'ios') {
      return new Response(
        JSON.stringify({ error: 'Invalid platform. Use android or ios.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    // Select all version-related columns so we support both schemas:
    // - min_version / latest_version (migrations)
    // - min_version_apk / latest_version_apk (some Supabase tables)
    const { data, error } = await supabase
      .from('app_version')
      .select('*')
      .eq('platform', platform)
      .single()

    if (error || !data) {
      console.warn('[get-app-version] DB miss or error, forcing update', { platform, error: error?.message ?? 'no row' })
      // Return high min_version so all clients are told to update (do not use 0.0.0 - that allows old APKs)
      const fallback = {
        min_version: '99.0.0',
        latest_version: '99.0.0',
        force_update: true,
        download_url: null,
        release_notes: 'Please update the app. Version check could not be completed.',
      }
      return new Response(
        JSON.stringify(fallback),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const raw = data as Record<string, unknown>
    const minVersion = (raw.min_version_apk ?? raw.min_version) as string | undefined
    const latestVersion = (raw.latest_version_apk ?? raw.latest_version) as string | undefined
    if (!minVersion || !latestVersion) {
      console.warn('[get-app-version] missing min/latest version in row', raw)
      const fallback = {
        min_version: '99.0.0',
        latest_version: '99.0.0',
        force_update: true,
        download_url: raw.download_url ?? null,
        release_notes: raw.release_notes ?? null,
      }
      return new Response(
        JSON.stringify(fallback),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Only the latest version is allowed to work: require app version >= latest_version
    const effectiveMin = latestVersion
    const payload = {
      min_version: effectiveMin,
      latest_version: latestVersion,
      force_update: true, // always force update when not on latest
      download_url: (raw.download_url as string | null | undefined) ?? null,
      release_notes: (raw.release_notes as string | null | undefined) ?? null,
    }
    console.log('[get-app-version] success (only latest allowed)', { platform, min_version: payload.min_version, latest_version: payload.latest_version })
    return new Response(
      JSON.stringify(payload),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('[get-app-version] error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
