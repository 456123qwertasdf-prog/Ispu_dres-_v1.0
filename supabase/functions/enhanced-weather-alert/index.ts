import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://hmolyqzbvxxliemclrld.supabase.co";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI0Njk3MCwiZXhwIjoyMDc1ODIyOTcwfQ.496txRbAGuiOov76vxdwSDUHplBt1osOD2PyV0EE958";
// Single weather API key (WeatherAPI.com) - use for all weather when set; works with Zyla-issued keys too
const WEATHER_API_KEY = Deno.env.get("WEATHER_API_KEY") || "";
const ACCUWEATHER_API_KEY = Deno.env.get("ACCUWEATHER_API_KEY") || "";
const ACCUWEATHER_BASE = "https://dataservice.accuweather.com";
const WEATHERAPI_BASE = "https://api.weatherapi.com/v1";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

interface EnhancedWeatherData {
  main: {
    temp: number;
    feels_like: number;
    humidity: number;
    pressure: number;
    temp_min?: number; // night low (from forecast)
    temp_max?: number; // day high (from forecast)
  };
  weather: Array<{
    main: string;
    description: string;
    icon: string;
  }>;
  wind: {
    speed: number;
    deg: number;
  };
  visibility: number;
  rain?: {
    "1h": number;
  };
  clouds: {
    all: number;
  };
  pop?: number; // Probability of precipitation (rain chance)
  alerts?: Array<{
    sender_name: string;
    event: string;
    start: number;
    end: number;
    description: string;
    tags: string[];
  }>;
  forecast_summary?: {
    next_24h_max_rain_chance: number;
    next_24h_avg_rain_chance: number;
    next_24h_forecast: Array<{
      time: string;
      temp: number;
      rain_chance: number;
      description: string;
      rain_volume: number;
    }>;
  } | null;
}

interface WeatherAlert {
  type: string;
  priority: string;
  title: string;
  message: string;
  expires_at: string;
}

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Validate request method
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Parse and validate request body
    let requestData;
    try {
      requestData = await req.json();
    } catch (error) {
      return new Response(JSON.stringify({ error: 'Invalid JSON in request body' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { latitude, longitude, city } = requestData;
    
    if (!latitude || !longitude) {
      return new Response(JSON.stringify({ error: 'latitude and longitude required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Use new LSPU coordinates if not provided
  const finalLatitude = latitude || 14.262585;
  const finalLongitude = longitude || 121.398436;
    const finalCity = city || "LSPU Sta. Cruz Campus, Laguna, Philippines";

    console.log(`🌤️ Fetching weather data for: ${finalCity} (${finalLatitude}, ${finalLongitude})`);

    // Get enhanced weather data
    const weatherData = await getEnhancedWeatherData(finalLatitude, finalLongitude);
    
    // Analyze weather conditions for comprehensive alerts
    const alerts = analyzeEnhancedWeatherConditions(weatherData, finalCity);
    
    // Create weather alerts in database
    const alertsCreated = await createWeatherAlerts(alerts);
    
    // Send notifications for new alerts
    if (alertsCreated > 0) {
      await sendWeatherNotifications(alerts);
    }

    return new Response(JSON.stringify({
      success: true,
      weather_data: weatherData,
      alerts_created: alertsCreated,
      alerts: alerts
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const stack = error instanceof Error ? error.stack : undefined;
    console.error('❌ Enhanced weather alert error:', message, stack || '');
    return new Response(JSON.stringify({
      error: 'Internal server error',
      details: message,
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

// -------- WeatherAPI.com (single key for all weather; preferred when WEATHER_API_KEY is set) --------
async function getWeatherApiData(latitude: number, longitude: number): Promise<Record<string, unknown>> {
  const q = `${latitude},${longitude}`;
  const url = `${WEATHERAPI_BASE}/forecast.json?key=${encodeURIComponent(WEATHER_API_KEY)}&q=${encodeURIComponent(q)}&days=3`;
  const res = await fetch(url);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`WeatherAPI.com failed: ${res.status} ${text.slice(0, 200)}`);
  }
  return (await res.json()) as Record<string, unknown>;
}

function normalizeWeatherApiToEnhanced(raw: Record<string, unknown>, latitude: number, longitude: number): EnhancedWeatherData {
  const current = (raw?.current ?? {}) as Record<string, unknown>;
  const location = (raw?.location ?? {}) as Record<string, unknown>;
  const forecast = (raw?.forecast ?? {}) as Record<string, unknown>;
  const forecastday = (forecast?.forecastday ?? []) as Record<string, unknown>[];

  const temp = Number(current?.temp_c ?? 0);
  const feelsLike = Number(current?.feelslike_c ?? temp);
  const humidity = Number(current?.humidity ?? 0);
  const pressure = Number(current?.pressure_mb ?? 1013);
  const windKph = Number(current?.wind_kph ?? 0);
  const windDeg = Number(current?.wind_degree ?? 0);
  const visibilityKm = Number(current?.vis_km ?? 10);
  const cloudCover = Number(current?.cloud ?? 0);
  const condition = (current?.condition ?? {}) as Record<string, unknown>;
  const weatherText = String(condition?.text ?? "Clear");
  const weatherCode = Number(condition?.code ?? 1000);

  const precipMm = Number(current?.precip_mm ?? 0);
  let pop = 0;
  const hourly: Array<{ time: string; temp: number; rain_chance: number; description: string; rain_volume: number }> = [];
  if (forecastday.length > 0) {
    const day1 = forecastday[0];
    const hourArr = (day1?.hour ?? []) as Record<string, unknown>[];
    for (let i = 0; i < Math.min(24, hourArr.length); i++) {
      const h = hourArr[i];
      const t = Number(h?.temp_c ?? temp);
      const chance = Number(h?.chance_of_rain ?? 0);
      const cond = (h?.condition ?? {}) as Record<string, unknown>;
      const desc = String(cond?.text ?? weatherText);
      const rainMm = Number(h?.precip_mm ?? 0);
      pop += chance;
      hourly.push({
        time: String(h?.time ?? "").slice(11, 16),
        temp: t,
        rain_chance: chance / 100,
        description: desc,
        rain_volume: rainMm,
      });
    }
    pop = hourly.length > 0 ? pop / hourly.length / 100 : 0;
  }

  const maxRainChance = hourly.length > 0 ? Math.max(...hourly.map((x) => x.rain_chance)) : 0;
  const temp_min = hourly.length > 0 ? Math.min(...hourly.map((x) => x.temp)) : temp;
  const temp_max = hourly.length > 0 ? Math.max(...hourly.map((x) => x.temp)) : temp;

  return {
    main: { temp, feels_like: feelsLike, humidity, pressure, temp_min, temp_max },
    weather: [{ main: weatherText, description: weatherText, icon: String(weatherCode) }],
    wind: { speed: windKph / 3.6, deg: windDeg },
    visibility: visibilityKm * 1000,
    rain: precipMm > 0 ? { "1h": precipMm } : undefined,
    clouds: { all: cloudCover },
    pop,
    alerts: [],
    forecast_summary: hourly.length > 0 ? {
      next_24h_max_rain_chance: maxRainChance,
      next_24h_avg_rain_chance: maxRainChance,
      next_24h_forecast: hourly,
    } : null,
  };
}

function buildCacheRowFromWeatherApi(raw: Record<string, unknown>, latitude: number, longitude: number): Record<string, unknown> {
  const current = (raw?.current ?? {}) as Record<string, unknown>;
  const condition = (current?.condition ?? {}) as Record<string, unknown>;
  const forecast = (raw?.forecast ?? {}) as Record<string, unknown>;
  const forecastday = (forecast?.forecastday ?? []) as Record<string, unknown>[];
  const day1 = forecastday[0];
  const hourArr = (day1?.hour ?? []) as Record<string, unknown>[];
  const hourly = hourArr.slice(0, 24).map((h: Record<string, unknown>) => ({
    time: String(h?.time ?? "").slice(11, 16),
    temp: Number(h?.temp_c ?? 0),
    rain_chance: Number(h?.chance_of_rain ?? 0),
    description: String((h?.condition as Record<string, unknown>)?.text ?? "Clear"),
    rain_volume: Number(h?.precip_mm ?? 0),
  }));
  const maxRain = hourly.length > 0 ? Math.max(...hourly.map((x: { rain_chance: number }) => x.rain_chance)) : 0;

  return {
    latitude,
    longitude,
    last_updated: new Date().toISOString(),
    data_source: "weatherapi",
    temperature: Number(current?.temp_c ?? 0),
    feels_like: Number(current?.feelslike_c ?? current?.temp_c ?? 0),
    humidity: Number(current?.humidity ?? 0),
    pressure: Number(current?.pressure_mb ?? 1013),
    weather_text: String(condition?.text ?? "Clear"),
    weather_icon: String(condition?.code ?? 1000),
    wind_speed: Number(current?.wind_kph ?? 0),
    wind_direction: Number(current?.wind_degree ?? 0),
    visibility: Number(current?.vis_km ?? 10),
    rain_1h: Number(current?.precip_mm ?? 0),
    cloud_cover: Number(current?.cloud ?? 0),
    rain_probability: maxRain,
    weather_alerts: [],
    hourly_forecast: hourly,
    daily_forecast: [],
  };
}

// -------- AccuWeather API (fallback when WEATHER_API_KEY not set) --------
async function getAccuWeatherLocationKey(lat: number, lon: number): Promise<string> {
  const q = `${lat},${lon}`;
  const url = `${ACCUWEATHER_BASE}/locations/v1/cities/geoposition/search?apikey=${ACCUWEATHER_API_KEY}&q=${encodeURIComponent(q)}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`AccuWeather location failed: ${res.status}`);
  const data = await res.json();
  const key = data?.Key ?? data?.key;
  if (!key) throw new Error('AccuWeather location key not found');
  return String(key);
}

async function getAccuWeatherCurrentConditions(locationKey: string): Promise<Record<string, unknown>> {
  const url = `${ACCUWEATHER_BASE}/currentconditions/v1/${locationKey}?apikey=${ACCUWEATHER_API_KEY}&details=true`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`AccuWeather current conditions failed: ${res.status}`);
  const arr = await res.json();
  if (!Array.isArray(arr) || arr.length === 0) throw new Error('AccuWeather current conditions empty');
  return arr[0] as Record<string, unknown>;
}

async function getAccuWeather12HourForecast(locationKey: string): Promise<unknown[]> {
  const url = `${ACCUWEATHER_BASE}/forecasts/v1/hourly/12hour/${locationKey}?apikey=${ACCUWEATHER_API_KEY}&metric=true&details=true`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`AccuWeather hourly forecast failed: ${res.status}`);
  const arr = await res.json();
  return Array.isArray(arr) ? arr : [];
}

function normalizeAccuWeatherToEnhanced(
  current: Record<string, unknown>,
  hourly: unknown[],
  latitude: number,
  longitude: number
): EnhancedWeatherData {
  const temp = Number((current?.Temperature as { Metric?: { Value?: number } })?.Metric?.Value ?? 0);
  const realFeel = (current?.RealFeelTemperature as { Metric?: { Value?: number } })?.Metric?.Value ?? temp;
  const humidity = Number(current?.RelativeHumidity ?? 0);
  const pressure = Number((current?.Pressure as { Metric?: { Value?: number } })?.Metric?.Value ?? 1013);
  const windSpeedKmh = Number((current?.Wind as { Speed?: { Metric?: { Value?: number } } })?.Speed?.Metric?.Value ?? 0);
  const windDeg = Number((current?.Wind as { Direction?: { Degrees?: number } })?.Direction?.Degrees ?? 0);
  const visibilityKm = Number((current?.Visibility as { Metric?: { Value?: number } })?.Metric?.Value ?? 10);
  const cloudCover = Number(current?.CloudCover ?? 0);
  const weatherText = String(current?.WeatherText ?? 'Clear');
  const weatherIcon = Number(current?.WeatherIcon ?? 1);
  const hasPrecip = Boolean(current?.HasPrecipitation);
  const precip1h = hasPrecip ? Number((current?.PrecipitationSummary as { PastHour?: { Metric?: { Value?: number } } })?.PastHour?.Metric?.Value ?? 0) : 0;
  const pop = hourly.length > 0
    ? (hourly as Record<string, unknown>[]).reduce((sum: number, h: Record<string, unknown>) => sum + (Number((h?.PrecipitationProbability ?? 0)) || 0), 0) / Math.max(hourly.length, 1) / 100
    : 0;

  const next24hForecast = (hourly as Record<string, unknown>[]).slice(0, 12).map((h) => {
    const dt = (h?.DateTime as string) || new Date().toISOString();
    const t = (h?.Temperature as { Value?: number })?.Value ?? temp;
    const rainChancePct = Number(h?.PrecipitationProbability ?? 0);
    const phrase = (h?.IconPhrase as string) || weatherText;
    return {
      time: new Date(dt).toISOString().slice(11, 16),
      temp: t,
      rain_chance: rainChancePct / 100,
      description: phrase,
      rain_volume: 0,
    };
  });

  const maxRainChance = next24hForecast.length > 0
    ? Math.max(...next24hForecast.map((x) => x.rain_chance))
    : 0;

  // Day high / night low from next 12h hourly (for day/night labels in app)
  const hourlyTemps = next24hForecast.map((x) => x.temp);
  const temp_min = hourlyTemps.length > 0 ? Math.min(...hourlyTemps) : temp;
  const temp_max = hourlyTemps.length > 0 ? Math.max(...hourlyTemps) : temp;

  return {
    main: {
      temp,
      feels_like: realFeel,
      humidity,
      pressure,
      temp_min,
      temp_max,
    },
    weather: [{ main: weatherText, description: weatherText, icon: String(weatherIcon) }],
    wind: { speed: windSpeedKmh / 3.6, deg: windDeg },
    visibility: visibilityKm * 1000,
    rain: precip1h > 0 ? { "1h": precip1h } : undefined,
    clouds: { all: cloudCover },
    pop,
    alerts: [],
    forecast_summary: {
      next_24h_max_rain_chance: maxRainChance,
      next_24h_avg_rain_chance: maxRainChance,
      next_24h_forecast: next24hForecast,
    },
  };
}

function buildCacheRowFromAccuWeather(
  current: Record<string, unknown>,
  hourly: unknown[],
  latitude: number,
  longitude: number
): Record<string, unknown> {
  const temp = Number((current?.Temperature as { Metric?: { Value?: number } })?.Metric?.Value ?? 0);
  const realFeel = (current?.RealFeelTemperature as { Metric?: { Value?: number } })?.Metric?.Value ?? temp;
  const humidity = Number(current?.RelativeHumidity ?? 0);
  const pressure = Number((current?.Pressure as { Metric?: { Value?: number } })?.Metric?.Value ?? 1013);
  const windSpeedKmh = Number((current?.Wind as { Speed?: { Metric?: { Value?: number } } })?.Speed?.Metric?.Value ?? 0);
  const windDeg = Number((current?.Wind as { Direction?: { Degrees?: number } })?.Direction?.Degrees ?? 0);
  const visibilityKm = Number((current?.Visibility as { Metric?: { Value?: number } })?.Metric?.Value ?? 10);
  const cloudCover = Number(current?.CloudCover ?? 0);
  const weatherText = String(current?.WeatherText ?? 'Clear');
  const weatherIcon = Number(current?.WeatherIcon ?? 1);
  const hasPrecip = Boolean(current?.HasPrecipitation);
  const precip1h = hasPrecip ? Number((current?.PrecipitationSummary as { PastHour?: { Metric?: { Value?: number } } })?.PastHour?.Metric?.Value ?? 0) : 0;
  const hourlyArr = (hourly as Record<string, unknown>[]).slice(0, 12).map((h) => ({
    time: (h?.DateTime as string)?.slice(11, 16) ?? '',
    temp: (h?.Temperature as { Value?: number })?.Value ?? temp,
    rain_chance: Number(h?.PrecipitationProbability ?? 0),
    description: (h?.IconPhrase as string) ?? weatherText,
    rain_volume: 0,
  }));
  const maxRain = hourlyArr.length > 0 ? Math.max(...hourlyArr.map((x) => x.rain_chance)) : 0;

  return {
    latitude,
    longitude,
    last_updated: new Date().toISOString(),
    data_source: 'accuweather',
    temperature: temp,
    feels_like: realFeel,
    humidity,
    pressure,
    weather_text: weatherText,
    weather_icon: weatherIcon,
    wind_speed: windSpeedKmh,
    wind_direction: windDeg,
    visibility: visibilityKm,
    rain_1h: precip1h,
    cloud_cover: cloudCover,
    rain_probability: maxRain,
    weather_alerts: [],
    hourly_forecast: hourlyArr,
    daily_forecast: [],
  };
}

// Get enhanced weather data from cache; when missing or stale use WEATHER_API_KEY (WeatherAPI.com) or AccuWeather
async function getEnhancedWeatherData(latitude: number, longitude: number): Promise<EnhancedWeatherData> {
  try {
    console.log(`🔍 Looking for weather cache at (${latitude}, ${longitude})`);

    const { data: allCache } = await supabase
      .from('weather_cache')
      .select('*');

    console.log(`📊 Found ${allCache?.length || 0} cache entries`);

    const latDiff = (c: { latitude: number }) => Math.abs(c.latitude - latitude);
    const lonDiff = (c: { longitude: number }) => Math.abs(c.longitude - longitude);
    const cachedWeather = allCache?.find((c) => latDiff(c) < 0.001 && lonDiff(c) < 0.001);

    const threeHoursInMs = 3 * 60 * 60 * 1000;
    const isStale = cachedWeather
      ? Date.now() - new Date(cachedWeather.last_updated).getTime() > threeHoursInMs
      : true;
    const dataSource = (cachedWeather?.data_source ?? '') as string;
    const isFromAccuWeather = dataSource.toLowerCase() === 'accuweather';
    const isFromWeatherapi = dataSource.toLowerCase() === 'weatherapi';

    // Prefer WEATHER_API_KEY (WeatherAPI.com) for all weather when set
    if (WEATHER_API_KEY) {
      const useCache = cachedWeather && isFromWeatherapi && !isStale;
      if (!useCache) {
        const reason = !cachedWeather ? 'missing' : !isFromWeatherapi ? 'replacing source (' + dataSource + ')' : 'stale';
        console.log(`🌤️ Fetching from WeatherAPI.com (cache ${reason})`);
        const raw = await getWeatherApiData(latitude, longitude);
        const normalized = normalizeWeatherApiToEnhanced(raw, latitude, longitude);
        const cacheRow = buildCacheRowFromWeatherApi(raw, latitude, longitude);
        try {
          await supabase.from('weather_cache').upsert([cacheRow], {
            onConflict: 'latitude,longitude',
            ignoreDuplicates: false,
          });
        } catch (upsertErr) {
          console.warn('⚠️ Weather cache upsert failed:', upsertErr);
        }
        return normalized;
      }
      console.log(`✅ Using cached weather data from ${cachedWeather.data_source} (updated: ${cachedWeather.last_updated})`);
    } else {
      // No WEATHER_API_KEY: use AccuWeather only; only accept AccuWeather cache
      const useCache = cachedWeather && isFromAccuWeather && !isStale;
      if (!ACCUWEATHER_API_KEY) {
        if (!cachedWeather) {
          throw new Error('Weather cache not available and no API key set. Set WEATHER_API_KEY or ACCUWEATHER_API_KEY in Supabase secrets.');
        }
        if (isFromWeatherapi || !isFromAccuWeather) {
          throw new Error('Weather cache is from another source (' + dataSource + '). Set WEATHER_API_KEY for WeatherAPI.com or ACCUWEATHER_API_KEY for AccuWeather.');
        }
        if (isStale) {
          throw new Error('Weather cache is stale (updated: ' + cachedWeather.last_updated + '). Set WEATHER_API_KEY or ACCUWEATHER_API_KEY to refresh.');
        }
        console.log(`✅ Using cached weather data from ${cachedWeather.data_source} (updated: ${cachedWeather.last_updated})`);
      } else if (!useCache) {
        const reason = !cachedWeather ? 'missing' : !isFromAccuWeather ? 'replacing old source (' + dataSource + ')' : 'stale';
        console.log(`🌤️ Fetching from AccuWeather (cache ${reason})`);
        const locationKey = await getAccuWeatherLocationKey(latitude, longitude);
        const [current, hourly] = await Promise.all([
          getAccuWeatherCurrentConditions(locationKey),
          getAccuWeather12HourForecast(locationKey),
        ]);
        const normalized = normalizeAccuWeatherToEnhanced(current, hourly, latitude, longitude);
        const cacheRow = buildCacheRowFromAccuWeather(current, hourly, latitude, longitude);

        try {
          await supabase.from('weather_cache').upsert([cacheRow], {
            onConflict: 'latitude,longitude',
            ignoreDuplicates: false,
          });
        } catch (upsertErr) {
          console.warn('⚠️ Weather cache upsert failed (table may not exist or lack columns):', upsertErr);
        }

        return normalized;
      } else {
        console.log(`✅ Using cached weather data from ${cachedWeather.data_source} (updated: ${cachedWeather.last_updated})`);
      }
    }

    // Process hourly forecast for 24h summary
    let forecastSummary: {
      next_24h_max_rain_chance: number;
      next_24h_avg_rain_chance: number;
      next_24h_forecast: Array<{
        time: string;
        temp: number;
        rain_chance: number;
        description: string;
        rain_volume: number;
      }>;
    } | null = null;
    
    if (cachedWeather.hourly_forecast && Array.isArray(cachedWeather.hourly_forecast)) {
      const next24Hours = cachedWeather.hourly_forecast.slice(0, 24);
      const rainChances = next24Hours.map(item => item.rain_chance || 0);
      const maxRainChance = Math.max(...rainChances) / 100; // Convert from percentage
      const avgRainChance = rainChances.reduce((sum, chance) => sum + chance, 0) / rainChances.length / 100;
      
      forecastSummary = {
        next_24h_max_rain_chance: maxRainChance,
        next_24h_avg_rain_chance: avgRainChance,
        next_24h_forecast: next24Hours.map(item => ({
          time: item.time,
          temp: item.temp,
          rain_chance: (item.rain_chance || 0) / 100,
          description: item.description,
          rain_volume: item.rain_volume || 0
        }))
      };
    } else if (cachedWeather.daily_forecast && Array.isArray(cachedWeather.daily_forecast)) {
      // Fallback to daily forecast if hourly not available (AccuWeather free tier)
      const today = cachedWeather.daily_forecast[0];
      const maxRainChance = (today?.rain_probability || 0) / 100;
      
      forecastSummary = {
        next_24h_max_rain_chance: maxRainChance,
        next_24h_avg_rain_chance: maxRainChance,
        next_24h_forecast: []
      };
    }

    // Day high / night low from cached hourly forecast (same as fresh AccuWeather)
    const cachedHourly = cachedWeather.hourly_forecast && Array.isArray(cachedWeather.hourly_forecast) ? cachedWeather.hourly_forecast : [];
    const cachedTemps = cachedHourly.map((h: { temp?: number }) => h.temp ?? cachedWeather.temperature);
    const temp_min = cachedTemps.length > 0 ? Math.min(...cachedTemps) : cachedWeather.temperature;
    const temp_max = cachedTemps.length > 0 ? Math.max(...cachedTemps) : cachedWeather.temperature;

    // Normalize cached data to EnhancedWeatherData format
    return {
      main: {
        temp: cachedWeather.temperature,
        feels_like: cachedWeather.feels_like,
        humidity: cachedWeather.humidity,
        pressure: cachedWeather.pressure,
        temp_min,
        temp_max,
      },
      weather: [{
        main: cachedWeather.weather_text,
        description: cachedWeather.weather_text,
        icon: cachedWeather.weather_icon
      }],
      wind: {
        speed: cachedWeather.wind_speed / 3.6, // Convert km/h to m/s for consistency
        deg: cachedWeather.wind_direction
      },
      visibility: cachedWeather.visibility * 1000, // Convert km to meters
      rain: cachedWeather.rain_1h ? { "1h": cachedWeather.rain_1h } : undefined,
      clouds: {
        all: cachedWeather.cloud_cover
      },
      pop: (cachedWeather.rain_probability || 0) / 100,
      alerts: cachedWeather.weather_alerts || [],
      forecast_summary: forecastSummary || null
    };

  } catch (error) {
    console.error('❌ Error fetching weather data from cache:', error);
    throw error;
  }
}

// Analyze enhanced weather conditions for comprehensive alerts
function analyzeEnhancedWeatherConditions(data: EnhancedWeatherData, city: string): WeatherAlert[] {
  const alerts: WeatherAlert[] = [];
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 6 * 60 * 60 * 1000); // 6 hours from now

  // Temperature and Heat Index Analysis
  const temp = data.main.temp;
  const heatIndex = data.main.feels_like;
  const humidity = data.main.humidity;

  if (heatIndex >= 40) {
    alerts.push({
      type: "weather",
      priority: "high",
      title: "🌡️ Extreme Heat Warning",
      message: `Extreme heat index of ${Math.round(heatIndex)}°C detected in ${city}. Avoid outdoor activities and stay hydrated.`,
      expires_at: expiresAt.toISOString()
    });
  } else if (heatIndex >= 35) {
    alerts.push({
      type: "weather",
      priority: "medium",
      title: "🌡️ High Heat Advisory",
      message: `High heat index of ${Math.round(heatIndex)}°C in ${city}. Take precautions and stay cool.`,
      expires_at: expiresAt.toISOString()
    });
  }

  // Rain Analysis
  const rainVolume = data.rain?.["1h"] || 0;
  const rainChance = (data.pop || 0) * 100;
  const maxRainChance = (data.forecast_summary?.next_24h_max_rain_chance ?? 0) * 100;

  if (rainVolume >= 7.5) {
    alerts.push({
      type: "weather",
      priority: "high",
      title: "🌧️ Heavy Rainfall Warning",
      message: `Heavy rainfall of ${rainVolume}mm/hour detected in ${city}. Risk of flooding. Avoid low-lying areas.`,
      expires_at: expiresAt.toISOString()
    });
  } else if (rainVolume >= 2.5) {
    alerts.push({
      type: "weather",
      priority: "medium",
      title: "🌧️ Moderate Rainfall Alert",
      message: `Moderate rainfall of ${rainVolume}mm/hour in ${city}. Stay indoors if possible.`,
      expires_at: expiresAt.toISOString()
    });
  }

  if (maxRainChance >= 80) {
    alerts.push({
      type: "weather",
      priority: "medium",
      title: "🌦️ High Rain Probability",
      message: `Very high chance of rain (${Math.round(maxRainChance)}%) expected in ${city} within 24 hours.`,
      expires_at: expiresAt.toISOString()
    });
  }

  // Wind Analysis
  const windSpeed = data.wind.speed * 3.6; // Convert m/s to km/h
  if (windSpeed >= 50) {
    alerts.push({
      type: "weather",
      priority: "high",
      title: "💨 Strong Wind Warning",
      message: `Strong winds of ${Math.round(windSpeed)} km/h in ${city}. Secure loose objects and avoid outdoor activities.`,
      expires_at: expiresAt.toISOString()
    });
  } else if (windSpeed >= 30) {
    alerts.push({
      type: "weather",
      priority: "medium",
      title: "💨 Wind Advisory",
      message: `Moderate winds of ${Math.round(windSpeed)} km/h in ${city}. Be cautious outdoors.`,
      expires_at: expiresAt.toISOString()
    });
  }

  // Thunderstorm Analysis
  const weatherMain = data.weather[0]?.main?.toLowerCase() || '';
  const weatherDescription = data.weather[0]?.description?.toLowerCase() || '';
  
  if (weatherMain.includes('thunderstorm') || weatherDescription.includes('thunderstorm')) {
    alerts.push({
      type: "weather",
      priority: "high",
      title: "⛈️ Thunderstorm Warning",
      message: `Thunderstorm activity detected in ${city}. Seek shelter immediately and avoid open areas.`,
      expires_at: expiresAt.toISOString()
    });
  }

  // Visibility Analysis
  const visibility = data.visibility / 1000; // Convert to km
  if (visibility < 1) {
    alerts.push({
      type: "weather",
      priority: "high",
      title: "🌫️ Dense Fog Warning",
      message: `Very poor visibility (${visibility.toFixed(1)}km) in ${city}. Drive with extreme caution.`,
      expires_at: expiresAt.toISOString()
    });
  } else if (visibility < 5) {
    alerts.push({
      type: "weather",
      priority: "medium",
      title: "🌫️ Reduced Visibility",
      message: `Reduced visibility (${visibility.toFixed(1)}km) in ${city}. Drive carefully.`,
      expires_at: expiresAt.toISOString()
    });
  }

  // Air Quality Analysis (Simplified)
  const aqi = calculateSimplifiedAQI(data.main.pressure, humidity);
  if (aqi >= 150) {
    alerts.push({
      type: "weather",
      priority: "medium",
      title: "🌫️ Poor Air Quality",
      message: `Poor air quality detected in ${city}. Limit outdoor activities, especially for sensitive individuals.`,
      expires_at: expiresAt.toISOString()
    });
  }

  // Official Weather Alerts
  if (data.alerts && data.alerts.length > 0) {
    data.alerts.forEach(alert => {
      alerts.push({
        type: "weather",
        priority: "high",
        title: `⚠️ ${alert.event}`,
        message: `${alert.description} - Valid until ${new Date(alert.end * 1000).toLocaleString()}`,
        expires_at: expiresAt.toISOString()
      });
    });
  }

  return alerts;
}

// Calculate simplified AQI based on pressure and humidity
function calculateSimplifiedAQI(pressure: number, humidity: number): number {
  // Simplified AQI calculation based on atmospheric conditions
  // This is a basic approximation - real AQI requires pollutant measurements
  const baseAQI = 50; // Base good air quality
  const pressureFactor = Math.max(0, (1013 - pressure) / 10); // Higher pressure = better air
  const humidityFactor = Math.max(0, (humidity - 60) / 20); // Higher humidity = worse air
  
  return Math.round(baseAQI + pressureFactor + humidityFactor);
}

// Create weather alerts in database
async function createWeatherAlerts(alerts: WeatherAlert[]): Promise<number> {
  if (alerts.length === 0) return 0;

  let alertsCreated = 0;
  const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);

  for (const alert of alerts) {
    try {
      // Check for duplicate alerts within 2 hours
      const { data: existingAlerts } = await supabase
        .from('announcements')
        .select('id')
        .eq('type', 'weather')
        .eq('title', alert.title)
        .gte('created_at', twoHoursAgo.toISOString());

      if (existingAlerts && existingAlerts.length > 0) {
        console.log(`⚠️ Duplicate alert prevented: ${alert.title}`);
        continue;
      }

      // Create new alert
      const { error } = await supabase
        .from('announcements')
        .insert({
          title: alert.title,
          message: alert.message,
          type: alert.type,
          priority: alert.priority,
          status: 'active',
          target_audience: 'all',
          created_by: null, // system-generated; created_by is UUID, not the string 'system'
          expires_at: alert.expires_at
        });

      if (error) {
        console.error('❌ Error creating weather alert:', error);
      } else {
        alertsCreated++;
        console.log(`✅ Weather alert created: ${alert.title}`);
      }
    } catch (error) {
      console.error('❌ Error processing weather alert:', error);
    }
  }

  return alertsCreated;
}

// Send weather notifications
async function sendWeatherNotifications(alerts: WeatherAlert[]): Promise<void> {
  if (alerts.length === 0) return;

  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/announcement-notify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SERVICE_KEY}`
      },
      body: JSON.stringify({
        type: 'weather',
        alerts: alerts
      })
    });

    if (!response.ok) {
      console.error('❌ Error sending weather notifications:', response.statusText);
    } else {
      console.log('✅ Weather notifications sent successfully');
    }
  } catch (error) {
    console.error('❌ Error sending weather notifications:', error);
  }
}