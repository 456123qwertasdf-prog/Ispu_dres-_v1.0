import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

interface ETARequest {
  responder_id: string
  report_id: string
}

interface Location {
  lat: number
  lng: number
}

interface ETAResponse {
  distance_km: number
  eta_minutes: number
  responder_location: Location
  report_location: Location
  calculation_method: 'straight_line' | 'routing_api'
  average_speed_kmph: number
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 405 
      }
    )
  }

  try {
    // Initialize Supabase client with service role
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Parse and validate request
    const requestData: ETARequest = await req.json()
    validateETARequest(requestData)

    // Fetch responder and report data
    const { responderLocation, reportLocation } = await fetchResponderAndReport(supabaseClient, requestData)

    // Calculate straight-line distance using Haversine formula
    const distanceKm = calculateHaversineDistance(responderLocation, reportLocation)

    // Calculate ETA based on average speed
    const averageSpeedKmh = 30 // Default average speed in km/h (configurable)
    const etaMinutes = (distanceKm / averageSpeedKmh) * 60

    const response: ETAResponse = {
      distance_km: Math.round(distanceKm * 100) / 100, // Round to 2 decimal places
      eta_minutes: Math.round(etaMinutes),
      responder_location: responderLocation,
      report_location: reportLocation,
      calculation_method: 'straight_line',
      average_speed_kmph: averageSpeedKmh
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: response
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in estimate-eta function:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})

/**
 * Validate ETA request data
 */
function validateETARequest(data: ETARequest): void {
  if (!data.responder_id || typeof data.responder_id !== 'string') {
    throw new Error('responder_id is required and must be a string')
  }

  if (!data.report_id || typeof data.report_id !== 'string') {
    throw new Error('report_id is required and must be a string')
  }

  // Validate UUID format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  if (!uuidRegex.test(data.responder_id)) {
    throw new Error('responder_id must be a valid UUID')
  }

  if (!uuidRegex.test(data.report_id)) {
    throw new Error('report_id must be a valid UUID')
  }
}

/**
 * Fetch responder and report location data
 */
async function fetchResponderAndReport(
  supabaseClient: any,
  requestData: ETARequest
): Promise<{ responderLocation: Location; reportLocation: Location }> {
  // Fetch responder location
  const { data: responder, error: responderError } = await supabaseClient
    .from('responder')
    .select('id, last_location')
    .eq('id', requestData.responder_id)
    .single()

  if (responderError) {
    if (responderError.code === 'PGRST116') {
      throw new Error('Responder not found')
    }
    throw new Error(`Failed to fetch responder: ${responderError.message}`)
  }

  if (!responder.last_location || !responder.last_location.lat || !responder.last_location.lng) {
    throw new Error('Responder location not available')
  }

  // Fetch report location
  const { data: report, error: reportError } = await supabaseClient
    .from('reports')
    .select('id, lat, lng')
    .eq('id', requestData.report_id)
    .single()

  if (reportError) {
    if (reportError.code === 'PGRST116') {
      throw new Error('Report not found')
    }
    throw new Error(`Failed to fetch report: ${reportError.message}`)
  }

  if (!report.lat || !report.lng) {
    throw new Error('Report location not available')
  }

  return {
    responderLocation: {
      lat: responder.last_location.lat,
      lng: responder.last_location.lng
    },
    reportLocation: {
      lat: report.lat,
      lng: report.lng
    }
  }
}

/**
 * Calculate distance between two points using Haversine formula
 * Returns distance in kilometers
 */
function calculateHaversineDistance(point1: Location, point2: Location): number {
  const R = 6371 // Earth's radius in kilometers
  const dLat = toRadians(point2.lat - point1.lat)
  const dLng = toRadians(point2.lng - point1.lng)
  
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(point1.lat)) * Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(point1.lat)) * Math.cos(toRadians(point2.lat)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2)
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  const distance = R * c
  
  return distance
}

/**
 * Convert degrees to radians
 */
function toRadians(degrees: number): number {
  return degrees * (Math.PI / 180)
}

/*
 * ============================================================================
 * ROUTING API INTEGRATION GUIDE
 * ============================================================================
 * 
 * To replace straight-line distance with actual routing (OSRM/Mapbox/Google):
 * 
 * 1. INSTALL ROUTING SERVICE:
 *    - OSRM: Free, self-hosted option
 *    - Mapbox: Commercial, high-quality routing
 *    - Google Maps: Commercial, comprehensive
 * 
 * 2. REPLACE calculateHaversineDistance() with routing API call:
 * 
 *    async function calculateRoutingDistance(
 *      point1: Location, 
 *      point2: Location,
 *      routingService: 'osrm' | 'mapbox' | 'google'
 *    ): Promise<{ distance_km: number; duration_minutes: number }> {
 *      
 *      if (routingService === 'osrm') {
 *        // OSRM Example
 *        const response = await fetch(
 *          `http://router.project-osrm.org/route/v1/driving/${point1.lng},${point1.lat};${point2.lng},${point2.lat}?overview=false&alternatives=false&steps=false`
 *        )
 *        const data = await response.json()
 *        return {
 *          distance_km: data.routes[0].distance / 1000,
 *          duration_minutes: data.routes[0].duration / 60
 *        }
 *      }
 *      
 *      if (routingService === 'mapbox') {
 *        // Mapbox Example
 *        const accessToken = Deno.env.get('MAPBOX_ACCESS_TOKEN')
 *        const response = await fetch(
 *          `https://api.mapbox.com/directions/v5/mapbox/driving/${point1.lng},${point1.lat};${point2.lng},${point2.lat}?access_token=${accessToken}`
 *        )
 *        const data = await response.json()
 *        return {
 *          distance_km: data.routes[0].distance / 1000,
 *          duration_minutes: data.routes[0].duration / 60
 *        }
 *      }
 *      
 *      if (routingService === 'google') {
 *        // Google Maps Example
 *        const apiKey = Deno.env.get('GOOGLE_MAPS_API_KEY')
 *        const response = await fetch(
 *          `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${point1.lat},${point1.lng}&destinations=${point2.lat},${point2.lng}&key=${apiKey}`
 *        )
 *        const data = await response.json()
 *        return {
 *          distance_km: data.rows[0].elements[0].distance.value / 1000,
 *          duration_minutes: data.rows[0].elements[0].duration.value / 60
 *        }
 *      }
 *    }
 * 
 * 3. UPDATE MAIN FUNCTION:
 *    Replace the straight-line calculation with:
 *    
 *    const routingResult = await calculateRoutingDistance(responderLocation, reportLocation, 'osrm')
 *    const response: ETAResponse = {
 *      distance_km: Math.round(routingResult.distance_km * 100) / 100,
 *      eta_minutes: Math.round(routingResult.duration_minutes),
 *      responder_location: responderLocation,
 *      report_location: reportLocation,
 *      calculation_method: 'routing_api',
 *      average_speed_kmph: null // Not applicable for routing API
 *    }
 * 
 * 4. ENVIRONMENT VARIABLES:
 *    Add to your Supabase project settings:
 *    - MAPBOX_ACCESS_TOKEN (for Mapbox)
 *    - GOOGLE_MAPS_API_KEY (for Google Maps)
 * 
 * 5. ERROR HANDLING:
 *    Add fallback to straight-line distance if routing API fails:
 *    
 *    try {
 *      const routingResult = await calculateRoutingDistance(responderLocation, reportLocation, 'osrm')
 *      // Use routing result
 *    } catch (error) {
 *      console.warn('Routing API failed, falling back to straight-line:', error)
 *      const distanceKm = calculateHaversineDistance(responderLocation, reportLocation)
 *      const etaMinutes = (distanceKm / 30) * 60
 *      // Use straight-line result
 *    }
 * 
 * 6. PERFORMANCE CONSIDERATIONS:
 *    - Cache routing results for repeated requests
 *    - Set appropriate timeouts for API calls
 *    - Consider rate limiting for external APIs
 *    - Use batch requests when possible
 * 
 * ============================================================================
 */
