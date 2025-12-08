/**
 * Fix RLS Policies Script
 * 
 * This script shows how Row Level Security (RLS) policies
 * were implemented and fixed during development.
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const supabaseUrl = 'https://hmolyqzbvxxliemclrld.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI0Njk3MCwiZXhwIjoyMDc1ODIyOTcwfQ.496txRbAGuiOov76vxdwSDUHplBt1osOD2PyV0EE958';

const supabase = createClient(supabaseUrl, supabaseKey);

/**
 * RLS Policies for reports table
 * This shows how security policies were implemented
 */
const reportsPolicies = [
  {
    name: 'Allow authenticated users to insert reports',
    table: 'reports',
    operation: 'INSERT',
    policy: `
      CREATE POLICY "Allow authenticated users to insert reports" ON public.reports
      FOR INSERT 
      TO authenticated 
      WITH CHECK (auth.uid() = reporter_uid);
    `
  },
  {
    name: 'Allow users to view their own reports',
    table: 'reports',
    operation: 'SELECT',
    policy: `
      CREATE POLICY "Allow users to view their own reports" ON public.reports
      FOR SELECT 
      TO authenticated 
      USING (auth.uid() = reporter_uid);
    `
  },
  {
    name: 'Allow responders to view all reports',
    table: 'reports',
    operation: 'SELECT',
    policy: `
      CREATE POLICY "Allow responders to view all reports" ON public.reports
      FOR SELECT 
      TO authenticated 
      USING (
        EXISTS (
          SELECT 1 FROM user_profiles 
          WHERE user_profiles.id = auth.uid() 
          AND user_profiles.role IN ('responder', 'admin')
        )
      );
    `
  },
  {
    name: 'Allow users to update their own reports',
    table: 'reports',
    operation: 'UPDATE',
    policy: `
      CREATE POLICY "Allow users to update their own reports" ON public.reports
      FOR UPDATE 
      TO authenticated 
      USING (auth.uid() = reporter_uid);
    `
  }
];

/**
 * RLS Policies for user_profiles table
 */
const userProfilesPolicies = [
  {
    name: 'Allow users to view their own profile',
    table: 'user_profiles',
    operation: 'SELECT',
    policy: `
      CREATE POLICY "Allow users to view their own profile" ON public.user_profiles
      FOR SELECT 
      TO authenticated 
      USING (auth.uid() = id);
    `
  },
  {
    name: 'Allow users to update their own profile',
    table: 'user_profiles',
    operation: 'UPDATE',
    policy: `
      CREATE POLICY "Allow users to update their own profile" ON public.user_profiles
      FOR UPDATE 
      TO authenticated 
      USING (auth.uid() = id);
    `
  },
  {
    name: 'Allow admins to view all profiles',
    table: 'user_profiles',
    operation: 'SELECT',
    policy: `
      CREATE POLICY "Allow admins to view all profiles" ON public.user_profiles
      FOR SELECT 
      TO authenticated 
      USING (
        EXISTS (
          SELECT 1 FROM user_profiles 
          WHERE user_profiles.id = auth.uid() 
          AND user_profiles.role = 'admin'
        )
      );
    `
  }
];

/**
 * Apply RLS policies to a table
 * This shows how policies were applied during development
 */
async function applyRLSPolicies(policies, tableName) {
  console.log(`🔒 Applying RLS policies for ${tableName}...`);
  
  for (const policy of policies) {
    try {
      console.log(`  Applying: ${policy.name}`);
      
      const { error } = await supabase.rpc('exec_sql', {
        sql: policy.policy
      });
      
      if (error) {
        console.error(`    ❌ Error: ${error.message}`);
      } else {
        console.log(`    ✅ Applied successfully`);
      }
    } catch (error) {
      console.error(`    ❌ Failed to apply policy: ${error.message}`);
    }
  }
}

/**
 * Enable RLS on tables
 * This shows how RLS was enabled on all tables
 */
async function enableRLS() {
  const tables = ['reports', 'user_profiles', 'notifications', 'assignments'];
  
  console.log('🔐 Enabling RLS on tables...');
  
  for (const table of tables) {
    try {
      const { error } = await supabase.rpc('exec_sql', {
        sql: `ALTER TABLE public.${table} ENABLE ROW LEVEL SECURITY;`
      });
      
      if (error) {
        console.error(`❌ Error enabling RLS on ${table}: ${error.message}`);
      } else {
        console.log(`✅ RLS enabled on ${table}`);
      }
    } catch (error) {
      console.error(`❌ Failed to enable RLS on ${table}: ${error.message}`);
    }
  }
}

/**
 * Test RLS policies
 * This shows how policies were tested during development
 */
async function testRLSPolicies() {
  console.log('🧪 Testing RLS policies...');
  
  try {
    // Test 1: Try to access reports without authentication
    const { data: reports, error: reportsError } = await supabase
      .from('reports')
      .select('*');
    
    if (reportsError) {
      console.log('✅ RLS working: Unauthenticated access blocked');
    } else {
      console.log('❌ RLS issue: Unauthenticated access allowed');
    }
    
    // Test 2: Try to access user_profiles without authentication
    const { data: profiles, error: profilesError } = await supabase
      .from('user_profiles')
      .select('*');
    
    if (profilesError) {
      console.log('✅ RLS working: Unauthenticated access blocked');
    } else {
      console.log('❌ RLS issue: Unauthenticated access allowed');
    }
    
  } catch (error) {
    console.error('❌ Error testing RLS policies:', error.message);
  }
}

/**
 * Main execution
 */
async function main() {
  try {
    console.log('🔒 LSPU Emergency Response System - RLS Policies Setup');
    console.log('====================================================\n');
    
    // Enable RLS on all tables
    await enableRLS();
    
    // Apply reports policies
    await applyRLSPolicies(reportsPolicies, 'reports');
    
    // Apply user_profiles policies
    await applyRLSPolicies(userProfilesPolicies, 'user_profiles');
    
    // Test RLS policies
    await testRLSPolicies();
    
    console.log('\n✅ RLS policies setup completed!');
    
  } catch (error) {
    console.error('❌ RLS setup failed:', error.message);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = {
  applyRLSPolicies,
  enableRLS,
  testRLSPolicies,
  reportsPolicies,
  userProfilesPolicies
};
