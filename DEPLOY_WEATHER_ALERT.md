# Weather Alert Function Deployment Guide

## 🚀 Deploy Weather Alert Function to Supabase

### Step 1: Install Supabase CLI (if not already installed)
```bash
npm install -g supabase
```

### Step 2: Login to Supabase
```bash
supabase login
```

### Step 3: Link to your project
```bash
supabase link --project-ref hmolyqzbvxxliemclrld
```

### Step 4: Deploy the weather-alert function
```bash
supabase functions deploy weather-alert
```

### Step 5: Set environment variables
```bash
# Set the OpenWeatherMap API key
supabase secrets set OPENWEATHER_API_KEY=d47a28878273fd3d6621539029b64cc1

# Verify secrets are set
supabase secrets list
```

### Step 6: Test the function
```bash
# Run the test script
node test-weather-alert.js
```

## 🧪 Manual Testing

You can also test the function manually using curl:

```bash
curl -X POST 'https://hmolyqzbvxxliemclrld.supabase.co/functions/v1/weather-alert' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyNDY5NzAsImV4cCI6MjA3NTgyMjk3MH0.G2AOT-8zZ5sk8qGQUBifFqq5ww2W7Hxvtux0tlQ0Q-4' \
  -d '{
    "latitude": 14.6042,
    "longitude": 121.1003,
    "city": "LSPU Sta. Cruz Campus"
  }'
```

## 📱 Integration with Frontend

To integrate weather alerts into your admin dashboard, add this button to your announcements page:

```html
<button onclick="checkWeatherAlerts()" class="btn btn-secondary">
    <i class="bi bi-cloud-rain"></i> Check Weather Alerts
</button>
```

And add this JavaScript function:

```javascript
async function checkWeatherAlerts() {
    try {
        // Get current location (you can also use LSPU coordinates)
        const position = await emergencySystem.getCurrentPosition();
        
        const response = await fetch('/functions/v1/weather-alert', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${emergencySystem.supabase.supabaseKey}`
            },
            body: JSON.stringify({
                latitude: position.coords.latitude,
                longitude: position.coords.longitude,
                city: "LSPU Campus"
            })
        });
        
        if (response.ok) {
            const result = await response.json();
            emergencySystem.showSuccess(`Weather check completed. ${result.alerts_created} alerts created.`);
            // Reload announcements to show new weather alerts
            await loadAnnouncements();
        } else {
            throw new Error('Weather alert check failed');
        }
    } catch (error) {
        console.error('Weather alert check failed:', error);
        emergencySystem.showError('Failed to check weather alerts: ' + error.message);
    }
}
```

## 🔧 Troubleshooting

### Function not found (404)
- Make sure the function is deployed: `supabase functions list`
- Check the function name matches exactly: `weather-alert`

### API key issues
- Verify the OpenWeatherMap API key is set: `supabase secrets list`
- Make sure the API key is valid and has sufficient quota

### Database errors
- Ensure the announcements table exists
- Check RLS policies are properly set
- Verify the service role key has proper permissions

## 📊 Expected Behavior

The weather alert function will:
1. Fetch current weather data for the given coordinates
2. Analyze weather conditions (temperature, wind, visibility, precipitation)
3. Create appropriate alerts for extreme conditions
4. Send notifications to all users
5. Return a summary of created alerts

## 🌤️ Weather Alert Types

The function creates alerts for:
- 🌡️ Extreme temperatures (>35°C or <10°C)
- 💨 Strong winds (>15 km/h)
- 🌫️ Low visibility (<1000m)
- ⛈️ Thunderstorms
- 🌧️ Heavy rain
- ❄️ Snow
- 🌫️ Fog
- 💧 High humidity (>90%)
