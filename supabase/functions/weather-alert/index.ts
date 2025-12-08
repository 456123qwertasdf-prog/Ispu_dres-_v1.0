import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://hmolyqzbvxxliemclrld.supabase.co";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI0Njk3MCwiZXhwIjoyMDc1ODIyOTcwfQ.496txRbAGuiOov76vxdwSDUHplBt1osOD2PyV0EE958";
const OPENWEATHER_API_KEY = Deno.env.get("OPENWEATHER_API_KEY") || "your_openweather_api_key";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

interface WeatherData {
  main: {
    temp: number;
    feels_like: number;
    humidity: number;
    pressure: number;
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
}

interface WeatherAlert {
  title: string;
  message: string;
  type: string;
  priority: string;
  severity: string;
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE",
      },
    });
  }

  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "POST only" }), { 
        status: 405, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        } 
      });
    }

    const { latitude, longitude, city } = await req.json();
    
    if (!latitude || !longitude) {
      return new Response(JSON.stringify({ error: "latitude and longitude required" }), { 
        status: 400, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        } 
      });
    }

    // Get weather data from OpenWeatherMap API
    const weatherData = await getWeatherData(latitude, longitude);
    
    // Analyze weather conditions for alerts
    const alerts = analyzeWeatherConditions(weatherData, city || "LSPU Campus");
    
    // Create announcements for weather alerts
    const createdAlerts = [];
    
    for (const alert of alerts) {
      try {
        // Check if similar alert already exists (avoid duplicates)
        const { data: existingAlert } = await supabase
          .from("announcements")
          .select("id")
          .eq("type", "weather")
          .eq("title", alert.title)
          .eq("status", "active")
          .gte("created_at", new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString()) // Within last 2 hours
          .single();

        if (existingAlert) {
          console.log(`Weather alert "${alert.title}" already exists, skipping`);
          continue;
        }

        // Create weather announcement
        const { data: announcement, error: createError } = await supabase
          .from("announcements")
          .insert([{
            title: alert.title,
            message: alert.message,
            type: "weather",
            priority: alert.priority,
            target_audience: "all",
            status: "active",
            created_by: "00000000-0000-0000-0000-000000000000", // System user
            expires_at: new Date(Date.now() + 6 * 60 * 60 * 1000).toISOString() // Expires in 6 hours
          }])
          .select()
          .single();

        if (createError) {
          console.error("Failed to create weather alert:", createError);
          continue;
        }

        createdAlerts.push(announcement);

        // Send notifications
        try {
          await fetch(`${SUPABASE_URL}/functions/v1/announcement-notify`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${SERVICE_KEY}`
            },
            body: JSON.stringify({
              announcementId: announcement.id
            })
          });
        } catch (notifyError) {
          console.warn("Failed to send weather alert notifications:", notifyError);
        }

      } catch (error) {
        console.error("Error creating weather alert:", error);
      }
    }

    return new Response(JSON.stringify({ 
      success: true, 
      weather_data: weatherData,
      alerts_created: createdAlerts.length,
      alerts: createdAlerts.map(alert => ({
        id: alert.id,
        title: alert.title,
        priority: alert.priority
      }))
    }), { 
      status: 200, 
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      } 
    });

  } catch (error) {
    console.error("Weather alert error:", error);
    return new Response(JSON.stringify({ 
      error: error.message || "Internal server error" 
    }), { 
      status: 500, 
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      } 
    });
  }
});

// Get weather data from OpenWeatherMap API
async function getWeatherData(latitude: number, longitude: number): Promise<WeatherData> {
  try {
    const response = await fetch(
      `https://api.openweathermap.org/data/2.5/weather?lat=${latitude}&lon=${longitude}&appid=${OPENWEATHER_API_KEY}&units=metric`
    );

    if (!response.ok) {
      throw new Error(`Weather API error: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error("Failed to fetch weather data:", error);
    throw error;
  }
}

// Analyze weather conditions and generate alerts
function analyzeWeatherConditions(weather: WeatherData, location: string): WeatherAlert[] {
  const alerts: WeatherAlert[] = [];
  
  const temperature = weather.main.temp;
  const humidity = weather.main.humidity;
  const windSpeed = weather.wind.speed;
  const visibility = weather.visibility;
  const weatherMain = weather.weather[0]?.main.toLowerCase() || '';
  const weatherDescription = weather.weather[0]?.description.toLowerCase() || '';

  // Temperature alerts
  if (temperature > 35) {
    alerts.push({
      title: "🌡️ Extreme Heat Warning",
      message: `High temperature alert: ${temperature}°C in ${location}. Stay hydrated, avoid prolonged sun exposure, and seek air-conditioned areas.`,
      type: "weather",
      priority: "high",
      severity: "extreme"
    });
  } else if (temperature < 10) {
    alerts.push({
      title: "❄️ Cold Weather Alert",
      message: `Low temperature warning: ${temperature}°C in ${location}. Dress warmly and be cautious of hypothermia.`,
      type: "weather",
      priority: "medium",
      severity: "moderate"
    });
  }

  // Wind alerts
  if (windSpeed > 15) {
    alerts.push({
      title: "💨 Strong Wind Warning",
      message: `Strong winds detected: ${windSpeed} km/h in ${location}. Secure loose objects and be cautious when driving.`,
      type: "weather",
      priority: "medium",
      severity: "moderate"
    });
  }

  // Visibility alerts
  if (visibility < 1000) {
    alerts.push({
      title: "🌫️ Low Visibility Alert",
      message: `Poor visibility conditions in ${location}. Drive carefully and use headlights.`,
      type: "weather",
      priority: "high",
      severity: "moderate"
    });
  }

  // Weather condition alerts
  if (weatherMain.includes('thunderstorm')) {
    alerts.push({
      title: "⛈️ Thunderstorm Warning",
      message: `Thunderstorm conditions in ${location}. Avoid open areas, tall objects, and seek shelter indoors.`,
      type: "weather",
      priority: "critical",
      severity: "extreme"
    });
  }

  if (weatherMain.includes('rain') && weatherDescription.includes('heavy')) {
    alerts.push({
      title: "🌧️ Heavy Rain Alert",
      message: `Heavy rainfall in ${location}. Be cautious of flooding, avoid low-lying areas, and drive carefully.`,
      type: "weather",
      priority: "high",
      severity: "moderate"
    });
  }

  if (weatherMain.includes('snow')) {
    alerts.push({
      title: "❄️ Snow Alert",
      message: `Snow conditions in ${location}. Roads may be slippery, drive with caution and dress warmly.`,
      type: "weather",
      priority: "medium",
      severity: "moderate"
    });
  }

  if (weatherMain.includes('fog')) {
    alerts.push({
      title: "🌫️ Fog Warning",
      message: `Foggy conditions in ${location}. Reduce speed, use low beam headlights, and maintain safe following distance.`,
      type: "weather",
      priority: "medium",
      severity: "moderate"
    });
  }

  // Humidity alerts
  if (humidity > 90) {
    alerts.push({
      title: "💧 High Humidity Alert",
      message: `Very high humidity (${humidity}%) in ${location}. Stay hydrated and be aware of heat stress.`,
      type: "weather",
      priority: "low",
      severity: "low"
    });
  }

  return alerts;
}
