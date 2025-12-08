#!/usr/bin/env node

/**
 * LSPU Emergency Response System v2.0 - Setup Script
 * 
 * This script helps set up the development environment and configure
 * the emergency response system.
 */

const fs = require('fs');
const path = require('path');

console.log('🚨 LSPU Emergency Response System v2.0 Setup');
console.log('==============================================\n');

// Check if we're in the right directory
const requiredFiles = ['package.json', 'public/index.html', 'supabase'];
const missingFiles = requiredFiles.filter(file => !fs.existsSync(file));

if (missingFiles.length > 0) {
  console.error('❌ Error: Missing required files:', missingFiles.join(', '));
  console.error('Please run this script from the project root directory.');
  process.exit(1);
}

console.log('✅ Project structure verified');

// Create .env file if it doesn't exist
const envPath = '.env';
if (!fs.existsSync(envPath)) {
  const envContent = `# LSPU Emergency Response System - Environment Variables
# Copy this file to .env.local and fill in your actual values

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

# Hugging Face AI Configuration
HF_TOKEN=your-huggingface-token-here
HF_MODEL=microsoft/beit-base-patch16-224-pt22k-ft22k

# OpenCage Geocoding API
OPENCAGE_API_KEY=your-opencage-api-key-here

# VAPID Keys for Push Notifications (generate with: npx web-push generate-vapid-keys)
VAPID_PUBLIC_KEY=your-vapid-public-key-here
VAPID_PRIVATE_KEY=your-vapid-private-key-here
VAPID_EMAIL=your-email@example.com
`;

  fs.writeFileSync(envPath, envContent);
  console.log('📝 Created .env file with template configuration');
} else {
  console.log('✅ .env file already exists');
}

// Create images directory if it doesn't exist
const imagesDir = path.join('public', 'images');
if (!fs.existsSync(imagesDir)) {
  fs.mkdirSync(imagesDir, { recursive: true });
  console.log('📁 Created images directory');
}

// Create placeholder images
const placeholderImages = [
  { name: 'favicon.ico', content: 'data:image/x-icon;base64,AAABAAEAEBAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' },
  { name: 'emergency-icon.png', content: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' },
  { name: 'icon-192.png', content: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' },
  { name: 'icon-512.png', content: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' }
];

placeholderImages.forEach(img => {
  const imgPath = path.join(imagesDir, img.name);
  if (!fs.existsSync(imgPath)) {
    // For now, just create empty files - in production, you'd have actual images
    fs.writeFileSync(imgPath, '');
    console.log(`📷 Created placeholder: ${img.name}`);
  }
});

// Check if node_modules exists
if (!fs.existsSync('node_modules')) {
  console.log('\n📦 Installing dependencies...');
  console.log('Run: npm install');
} else {
  console.log('✅ Dependencies already installed');
}

// Display setup instructions
console.log('\n🎯 Setup Instructions:');
console.log('=====================');
console.log('1. Install dependencies: npm install');
console.log('2. Configure Supabase:');
console.log('   - Create a new Supabase project');
console.log('   - Run the migrations in supabase/migrations/');
console.log('   - Set up storage buckets for images');
console.log('   - Update SUPABASE_URL and keys in .env');
console.log('3. Configure AI services:');
console.log('   - Get Hugging Face token from https://huggingface.co/settings/tokens');
console.log('   - Get OpenCage API key from https://opencagedata.com/api');
console.log('   - Update HF_TOKEN and OPENCAGE_API_KEY in .env');
console.log('4. Generate VAPID keys for push notifications:');
console.log('   - Run: npx web-push generate-vapid-keys');
console.log('   - Update VAPID keys in .env');
console.log('5. Start development server: npm run dev');
console.log('6. Open http://localhost:8000 in your browser');

console.log('\n📚 Documentation:');
console.log('================');
console.log('- README.md: Complete setup and usage guide');
console.log('- supabase/migrations/: Database schema');
console.log('- supabase/functions/: Edge functions for AI processing');

console.log('\n🚀 Quick Start:');
console.log('==============');
console.log('1. npm install');
console.log('2. Configure .env file');
console.log('3. npm run dev');
console.log('4. Open http://localhost:8000');

console.log('\n✅ Setup script completed!');
console.log('Happy coding! 🎉');
