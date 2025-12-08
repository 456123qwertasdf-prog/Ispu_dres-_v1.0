# 🚨 LSPU DRES Emergency Response System - Setup Guide

This guide will help you set up the LSPU DRES Emergency Response System on your local machine or server.

## 📋 Prerequisites

Before you begin, make sure you have:
- [Node.js](https://nodejs.org/) (version 16 or higher)
- [Git](https://git-scm.com/) installed
- A code editor (VS Code recommended)
- Internet connection for API services

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/lspu-dres.git
cd lspu-dres
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Configure Environment Variables
```bash
# Copy the environment template
cp env.template .env

# Edit the .env file with your API keys
# Use any text editor to open .env and fill in your keys
```

### 4. Set Up Supabase Database
```bash
# Run the setup script
node setup.js
```

### 5. Start the Application
```bash
# For development
npm start

# Or open public/index.html in your browser
```

## 🔑 API Keys Setup

### Required API Keys

#### 1. Supabase (Required)
- **What it's for**: Database and authentication
- **How to get it**:
  1. Go to [supabase.com](https://supabase.com)
  2. Create a new project
  3. Go to Settings → API
  4. Copy the URL and anon key
- **Where to put it**: In your `.env` file:
  ```
  SUPABASE_URL=your_supabase_url_here
  SUPABASE_ANON_KEY=your_supabase_anon_key_here
  ```

#### 2. Hugging Face (Required for AI)
- **What it's for**: AI image classification
- **How to get it**:
  1. Go to [huggingface.co](https://huggingface.co)
  2. Create an account
  3. Go to Settings → Access Tokens
  4. Create a new token
- **Where to put it**: In your `.env` file:
  ```
  HF_TOKEN=your_huggingface_token_here
  ```

#### 3. OpenCage (Required for location)
- **What it's for**: Reverse geocoding (converting coordinates to addresses)
- **How to get it**:
  1. Go to [opencagedata.com](https://opencagedata.com)
  2. Sign up for a free account
  3. Get your API key from the dashboard
- **Where to put it**: In your `.env` file:
  ```
  OPENCAGE_API_KEY=your_opencage_api_key_here
  ```

### Optional API Keys

#### 4. Azure Computer Vision (Optional - Alternative AI)
- **What it's for**: Alternative AI image analysis
- **How to get it**:
  1. Go to [portal.azure.com](https://portal.azure.com)
  2. Create a Cognitive Services resource
  3. Get the API key and endpoint
- **Where to put it**: In your `.env` file:
  ```
  AZURE_VISION_API_KEY=your_azure_vision_api_key_here
  AZURE_VISION_ENDPOINT=your_azure_vision_endpoint_here
  ```

#### 5. Mapbox (Optional - Advanced mapping)
- **What it's for**: Advanced mapping features
- **How to get it**:
  1. Go to [mapbox.com](https://mapbox.com)
  2. Create an account
  3. Get your access token
- **Where to put it**: In your `.env` file:
  ```
  MAPBOX_ACCESS_TOKEN=your_mapbox_token_here
  ```

## 🗄️ Database Setup

### Automatic Setup (Recommended)
```bash
node setup.js
```

### Manual Setup
1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Run the migration files in order:
   - `supabase/migrations/20250113000000_add_new_tables.sql`
   - `supabase/migrations/20250113000001_update_reports_table.sql`
   - (and so on...)

## 🌐 Deployment Options

### Option 1: GitHub Pages (Free)
1. Push your code to GitHub
2. Go to Settings → Pages
3. Select source branch
4. Your site will be available at `https://yourusername.github.io/lspu-dres`

### Option 2: Netlify (Free)
1. Connect your GitHub repository to Netlify
2. Set build command: `npm install`
3. Set publish directory: `public`
4. Deploy!

### Option 3: Vercel (Free)
1. Connect your GitHub repository to Vercel
2. Set framework: Static
3. Set output directory: `public`
4. Deploy!

## 🔧 Configuration Files

### Environment Variables (.env)
```bash
# Copy from env.template
cp env.template .env

# Edit with your actual keys
```

### Supabase Configuration
- Update `public/js/supabase.js` with your Supabase URL and keys
- Or use environment variables

## 🧪 Testing

### Test the System
```bash
# Run the test script
node test-system.js
```

### Test Individual Components
1. **Authentication**: Try logging in/out
2. **Image Upload**: Test emergency report submission
3. **AI Classification**: Check if images are properly analyzed
4. **Notifications**: Test push notifications

## 🐛 Troubleshooting

### Common Issues

#### 1. "API key not found" errors
- **Solution**: Make sure your `.env` file is properly configured
- **Check**: Ensure no spaces around the `=` sign in `.env`

#### 2. Database connection errors
- **Solution**: Verify your Supabase URL and keys
- **Check**: Make sure your Supabase project is active

#### 3. AI classification not working
- **Solution**: Check your Hugging Face token
- **Check**: Ensure you have internet connection

#### 4. Location services not working
- **Solution**: Verify your OpenCage API key
- **Check**: Make sure you're using HTTPS (required for geolocation)

### Getting Help
1. Check the [Issues](https://github.com/yourusername/lspu-dres/issues) page
2. Review the logs in browser console
3. Verify all API keys are correct
4. Ensure all dependencies are installed

## 📚 Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Hugging Face API Docs](https://huggingface.co/docs/api-inference)
- [OpenCage API Documentation](https://opencagedata.com/api)
- [Web Push Notifications](https://web.dev/push-notifications-overview/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Need help?** Open an issue on GitHub or contact the development team.
