# LSPU Emergency Response System v2.0

A modern, AI-powered emergency reporting and response management system built with Supabase, featuring real-time notifications, geolocation tracking, and intelligent image analysis.

## ⚡ Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/lspu-dres.git
   cd lspu-dres
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure environment**
   ```bash
   cp env.template .env
   # Edit .env with your API keys (see SETUP_GUIDE.md)
   ```

4. **Set up database**
   ```bash
   node setup.js
   ```

5. **Start the application**
   ```bash
   # Open public/index.html in your browser
   # Or use a local server: python -m http.server 8000
   ```

📖 **For detailed setup instructions, see [SETUP_GUIDE.md](SETUP_GUIDE.md)**

## 🚀 Features

### For Citizens (User Dashboard)
- **📱 Mobile-First Design**: Responsive interface optimized for mobile devices
- **📷 Photo Upload**: Capture or upload emergency photos with automatic AI analysis
- **📍 Auto-Location**: Automatic geolocation detection with manual override
- **⚡ Real-Time Reporting**: Instant emergency report submission
- **🔔 Status Tracking**: Track your submitted reports in real-time

### For Responders (Responder Dashboard)
- **🚨 Real-Time Alerts**: Instant notifications for new emergencies
- **📊 Status Monitoring**: Live dashboard with emergency statistics
- **🗺️ Location Mapping**: Visual representation of emergency locations
- **📋 Report Management**: Accept and manage emergency assignments
- **🔔 Push Notifications**: Browser notifications for urgent emergencies

### For Administrators (Admin Dashboard)
- **📈 Analytics Dashboard**: Comprehensive statistics and reporting
- **🤖 AI Management**: Monitor and control AI image analysis
- **👥 User Management**: Manage users and permissions
- **⚙️ System Settings**: Configure notifications and AI parameters
- **📊 Data Export**: Export reports and analytics data

## 🧠 AI-Powered Features

### Intelligent Image Analysis
- **🔍 Automatic Classification**: AI analyzes uploaded images to identify emergency types
- **📊 Confidence Scoring**: Provides confidence levels for AI classifications
- **🏷️ Smart Tagging**: Automatically tags images with relevant keywords
- **⚡ Real-Time Processing**: Instant analysis upon image upload

### Emergency Type Detection
- 🔥 Fire Emergencies
- 🏥 Medical Emergencies  
- 🚗 Traffic Accidents
- 🌊 Flood Emergencies
- 🌍 Earthquakes
- ⛈️ Storm Emergencies
- ⚠️ Other Emergencies

## 🛠️ Technology Stack

- **Frontend**: HTML5, CSS3, JavaScript (ES6+)
- **Backend**: Supabase (PostgreSQL, Real-time, Auth, Storage)
- **AI**: Hugging Face Transformers
- **AI/ML**: Microsoft BEIT Image Classification Model
- **Maps**: OpenCage Geocoding API
- **PWA**: Service Workers, Web App Manifest
- **Notifications**: Web Push API

## 📱 Progressive Web App (PWA)

- **📱 Installable**: Can be installed on mobile devices
- **🔄 Offline Support**: Works offline with background sync
- **🔔 Push Notifications**: Real-time emergency alerts
- **⚡ Fast Loading**: Optimized performance and caching

## 🚀 Quick Start

### Prerequisites
- Node.js 16+ 
- Supabase account
- Modern web browser

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd lspu_dres
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure Supabase**
   - Update Supabase URL and keys in `public/js/supabase.js`
   - Set up database tables using the provided migrations
   - Configure storage buckets for image uploads

4. **Start the development server**
   ```bash
   npm run dev
   ```

5. **Access the application**
   - Main App: `http://localhost:8000`
   - Responder Dashboard: `http://localhost:8000/responder.html`
   - Admin Dashboard: `http://localhost:8000/admin.html`

## 🗄️ Database Schema

### Core Tables
- **reports**: Emergency reports with AI analysis
- **users**: User profiles and authentication
- **notifications**: Real-time notification system
- **assignments**: Responder assignments

### Key Features
- **Row Level Security (RLS)**: Secure data access
- **Real-time subscriptions**: Live updates
- **File storage**: Secure image uploads
- **AI integration**: Automated image analysis

## 🔧 Configuration

### Environment Variables
```bash
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
HF_TOKEN=your_huggingface_token
OPENCAGE_API_KEY=your_opencage_api_key
```

### Supabase Functions
- `classify-image`: AI image analysis
- `classify-pending`: Batch processing
- `submit-report`: Report submission
- `assign-responder`: Assignment management

## 📊 AI Image Analysis

### Supported Models
- **Microsoft BEIT**: Primary image classification model
- **Custom Emergency Detection**: Specialized emergency type recognition
- **Confidence Scoring**: Reliability metrics for AI predictions

### Analysis Pipeline
1. **Image Upload**: User uploads emergency photo
2. **AI Processing**: Automatic image analysis
3. **Classification**: Emergency type identification
4. **Confidence Scoring**: Reliability assessment
5. **Notification**: Alert relevant responders

## 🔔 Real-Time Features

### Live Updates
- **Report Status**: Real-time status changes
- **New Emergencies**: Instant notifications
- **Responder Assignments**: Live assignment updates
- **System Statistics**: Live dashboard metrics

### Notification Types
- **Browser Notifications**: Web push notifications
- **In-App Alerts**: Real-time UI updates
- **Email Notifications**: Email alerts (configurable)
- **SMS Notifications**: SMS alerts (configurable)

## 📱 Mobile Optimization

### Responsive Design
- **Mobile-First**: Optimized for mobile devices
- **Touch-Friendly**: Large buttons and touch targets
- **Offline Support**: Works without internet connection
- **Fast Loading**: Optimized performance

### PWA Features
- **Installable**: Add to home screen
- **Offline Mode**: Background sync
- **Push Notifications**: Emergency alerts
- **App-like Experience**: Native app feel

## 🔒 Security Features

### Authentication
- **Supabase Auth**: Secure user authentication
- **Role-Based Access**: Different access levels
- **Session Management**: Secure session handling

### Data Protection
- **Row Level Security**: Database-level security
- **Encrypted Storage**: Secure file storage
- **HTTPS Only**: Secure connections
- **Input Validation**: Data sanitization

## 📈 Analytics & Reporting

### Dashboard Metrics
- **Total Reports**: Overall emergency count
- **Response Times**: Average response metrics
- **AI Accuracy**: Classification performance
- **User Activity**: Usage statistics

### Export Features
- **CSV Export**: Data export capabilities
- **Report Generation**: Automated reports
- **Analytics Dashboard**: Visual analytics
- **Performance Metrics**: System performance

## 🚀 Deployment

### Production Setup
1. **Configure Supabase**: Set up production database
2. **Deploy Functions**: Deploy Supabase Edge Functions
3. **Configure Storage**: Set up file storage buckets
4. **Set Environment Variables**: Configure production settings
5. **Deploy Frontend**: Deploy to hosting platform

### Recommended Hosting
- **Vercel**: Frontend deployment
- **Netlify**: Alternative frontend hosting
- **Supabase**: Backend and database
- **Cloudflare**: CDN and performance

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Code Standards
- **ES6+ JavaScript**: Modern JavaScript features
- **CSS Grid/Flexbox**: Modern layout techniques
- **Accessibility**: WCAG compliance
- **Performance**: Optimized loading times

## 📞 Support

### Documentation
- **API Documentation**: Comprehensive API docs
- **User Guides**: Step-by-step instructions
- **Video Tutorials**: Visual learning resources
- **FAQ**: Frequently asked questions

### Contact
- **Email**: support@lspu-dres.com
- **GitHub Issues**: Bug reports and feature requests
- **Documentation**: Comprehensive guides
- **Community**: Developer community

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- **Supabase**: Backend infrastructure
- **Hugging Face**: AI model hosting
- **OpenCage**: Geocoding services
- **LSPU Community**: Testing and feedback

---

**LSPU Emergency Response System v2.0** - Empowering communities with AI-driven emergency response technology.
