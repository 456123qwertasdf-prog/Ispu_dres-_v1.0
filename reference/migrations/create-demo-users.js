/**
 * Create Demo Users Script
 * 
 * This script shows how demo users were created for testing
 * the role-based authentication system.
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const supabaseUrl = 'https://hmolyqzbvxxliemclrld.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI0Njk3MCwiZXhwIjoyMDc1ODIyOTcwfQ.496txRbAGuiOov76vxdwSDUHplBt1osOD2PyV0EE958';

const supabase = createClient(supabaseUrl, supabaseKey);

/**
 * Demo users for testing the system
 * This shows the user roles and metadata structure
 */
const demoUsers = [
  {
    email: 'citizen@lspu-dres.com',
    password: 'citizen123',
    user_metadata: {
      full_name: 'Juan Dela Cruz',
      role: 'citizen',
      phone: '+63 912 345 6789',
      verified: true
    }
  },
  {
    email: 'responder@lspu-dres.com',
    password: 'responder123',
    user_metadata: {
      full_name: 'Maria Santos',
      role: 'responder',
      phone: '+63 912 345 6790',
      department: 'Emergency Response',
      verified: true
    }
  },
  {
    email: 'admin@lspu-dres.com',
    password: 'admin123',
    user_metadata: {
      full_name: 'Dr. Pedro Rodriguez',
      role: 'admin',
      phone: '+63 912 345 6791',
      department: 'System Administration',
      verified: true
    }
  }
];

/**
 * Create demo users in Supabase Auth
 * This shows how users were created with specific roles
 */
async function createDemoUsers() {
  console.log('🚀 Creating demo users...');
  
  for (const user of demoUsers) {
    try {
      console.log(`Creating user: ${user.email}`);
      
      const { data, error } = await supabase.auth.admin.createUser({
        email: user.email,
        password: user.password,
        email_confirm: true,
        user_metadata: user.user_metadata
      });
      
      if (error) {
        console.error(`❌ Error creating ${user.email}:`, error.message);
      } else {
        console.log(`✅ Created user: ${user.email} (${user.user_metadata.role})`);
      }
    } catch (error) {
      console.error(`❌ Failed to create ${user.email}:`, error.message);
    }
  }
  
  console.log('✅ Demo users creation completed!');
}

/**
 * Create user profiles in the database
 * This shows how user profiles were created
 */
async function createUserProfiles() {
  console.log('👥 Creating user profiles...');
  
  const profiles = [
    {
      id: 'citizen-profile-id',
      full_name: 'Juan Dela Cruz',
      role: 'citizen',
      phone: '+63 912 345 6789',
      verified: true,
      created_at: new Date().toISOString()
    },
    {
      id: 'responder-profile-id',
      full_name: 'Maria Santos',
      role: 'responder',
      phone: '+63 912 345 6790',
      department: 'Emergency Response',
      verified: true,
      created_at: new Date().toISOString()
    },
    {
      id: 'admin-profile-id',
      full_name: 'Dr. Pedro Rodriguez',
      role: 'admin',
      phone: '+63 912 345 6791',
      department: 'System Administration',
      verified: true,
      created_at: new Date().toISOString()
    }
  ];
  
  for (const profile of profiles) {
    try {
      const { error } = await supabase
        .from('user_profiles')
        .insert([profile]);
        
      if (error) {
        console.error(`❌ Error creating profile for ${profile.full_name}:`, error.message);
      } else {
        console.log(`✅ Created profile: ${profile.full_name} (${profile.role})`);
      }
    } catch (error) {
      console.error(`❌ Failed to create profile for ${profile.full_name}:`, error.message);
    }
  }
}

/**
 * Main execution
 */
async function main() {
  try {
    console.log('🎯 LSPU Emergency Response System - Demo Users Setup');
    console.log('==================================================\n');
    
    // Create demo users
    await createDemoUsers();
    
    // Create user profiles
    await createUserProfiles();
    
    console.log('\n🎉 Demo users setup completed!');
    console.log('\n📋 Demo User Credentials:');
    console.log('==========================');
    console.log('Citizen: citizen@lspu-dres.com / citizen123');
    console.log('Responder: responder@lspu-dres.com / responder123');
    console.log('Admin: admin@lspu-dres.com / admin123');
    
  } catch (error) {
    console.error('❌ Setup failed:', error.message);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = {
  createDemoUsers,
  createUserProfiles,
  demoUsers
};
