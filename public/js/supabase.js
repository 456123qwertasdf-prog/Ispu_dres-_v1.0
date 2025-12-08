// LSPU Emergency Response System - Supabase Integration
// Enhanced with AI image processing and real-time notifications

class EmergencyResponseSystem {
  constructor() {
    this.supabase = null;
    this.user = null;
    this.isInitialized = false;
    this.location = null;
    this.watchId = null;
    this.opencageApiKey = 'a8fcf18afc4f4fb8a7aa16d8403ae0a2'; // OpenCage API key for geocoding
    // Connection health tracking to avoid redundant connection tests on every query
    this.dbHealthy = false;
    this.lastDbCheckAt = 0;
  }

  async initialize() {
    try {
      // Load Supabase with fallback
      await this.loadSupabase();
      
      // Initialize Supabase client
      this.supabase = window.supabase.createClient(
        'https://hmolyqzbvxxliemclrld.supabase.co',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyNDY5NzAsImV4cCI6MjA3NTgyMjk3MH0.G2AOT-8zZ5sk8qGQUBifFqq5ww2W7Hxvtux0tlQ0Q-4'
      );

      // Test database connection once at startup
      await this.testDatabaseConnection();
      this.dbHealthy = true;
      this.lastDbCheckAt = Date.now();

      // Check authentication (handle missing session gracefully)
      try {
        await this.checkAuth();
      } catch (error) {
        // Don't fail initialization for missing auth session or invalid user
        if (error.message.includes('Auth session missing') ||
            error.message.includes('User from sub claim in JWT does not exist') ||
            error.message.includes('User not found')) {
          console.log('ℹ️ No valid authenticated user (normal for login page or expired session)');
          // Session will be cleared by checkAuth() if needed
        } else {
          throw error;
        }
      }
      
      // Initialize geolocation
      await this.initializeGeolocation();
      
      this.isInitialized = true;
      console.log('✅ Emergency Response System initialized');

      // Best-effort data bootstrap so dashboards are not empty
      await this.ensureResponderForCurrentUser();
      await this.ensureSeedResponderIfEmpty();
      
      return true;
    } catch (error) {
      console.error('❌ Failed to initialize system:', error);
      this.showError('Failed to initialize the emergency response system. Please refresh the page.');
      return false;
    }
  }

  async testDatabaseConnection() {
    try {
      // Only test connection if we haven't tested recently (throttle to once per minute)
      const now = Date.now();
      if (this.dbHealthy && (now - this.lastDbCheckAt) < 60000) {
        return true; // Skip test if healthy and tested recently
      }
      
      console.log('🔍 Testing database connection...');
      
      // Test basic connection with a simple query
      const { data, error } = await this.supabase
        .from('reports')
        .select('id')
        .limit(1);
      
      if (error) {
        console.error('❌ Database connection test failed:', error);
        this.dbHealthy = false;
        throw new Error(`Database connection failed: ${error.message}`);
      }
      
      console.log('✅ Database connection successful');
      this.dbHealthy = true;
      this.lastDbCheckAt = now;
      return true;
    } catch (error) {
      console.error('❌ Database connection test failed:', error);
      this.dbHealthy = false;
      throw error;
    }
  }

  async loadSupabase() {
    return new Promise((resolve, reject) => {
      if (window.supabase) {
        resolve();
        return;
      }

      const sources = [
        'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
        'https://unpkg.com/@supabase/supabase-js@2/dist/umd/supabase.js',
        'https://cdn.skypack.dev/@supabase/supabase-js@2'
      ];

      let attempts = 0;
      const maxAttempts = sources.length;

      const tryLoad = () => {
        if (attempts >= maxAttempts) {
          reject(new Error('Failed to load Supabase from all sources'));
          return;
        }

        const script = document.createElement('script');
        script.src = sources[attempts];
        script.onload = () => {
          console.log(`✅ Supabase loaded from source ${attempts + 1}`);
          resolve();
        };
        script.onerror = () => {
          attempts++;
          tryLoad();
        };
        document.head.appendChild(script);
      };

      tryLoad();
    });
  }

  async checkAuth() {
    try {
      const { data: { user }, error } = await this.supabase.auth.getUser();
      
      if (error) {
        // Handle auth session missing gracefully - this is normal for login page
        if (error.message.includes('Auth session missing')) {
          console.log('ℹ️ No authenticated user (normal for login page)');
          this.user = null;
          this.updateUIForGuestUser();
          return;
        }
        
        // Handle invalid user (user deleted but token still exists)
        if (error.message.includes('User from sub claim in JWT does not exist') || 
            error.message.includes('User not found') ||
            error.status === 403) {
          console.warn('⚠️ User in token no longer exists. Clearing session...');
          await this.supabase.auth.signOut();
          this.user = null;
          this.updateUIForGuestUser();
          
          // Redirect to login if not already on login page
          if (!window.location.pathname.includes('login.html')) {
            console.log('🔄 Redirecting to login page...');
            window.location.href = 'login.html';
          }
          return;
        }
        
        throw error;
      }
      
      this.user = user;
      
      if (user) {
        console.log('✅ User authenticated:', user.email);
        this.updateUIForAuthenticatedUser();
      } else {
        console.log('ℹ️ No authenticated user');
        this.updateUIForGuestUser();
      }
    } catch (error) {
      console.error('❌ Auth check failed:', error);
      
      // Handle auth session missing gracefully - this is normal for login page
      if (error.message.includes('Auth session missing')) {
        console.log('ℹ️ No authenticated user (normal for login page)');
        this.user = null;
        this.updateUIForGuestUser();
        return;
      }
      
      // Handle invalid user (user deleted but token still exists)
      if (error.message.includes('User from sub claim in JWT does not exist') || 
          error.message.includes('User not found') ||
          error.status === 403) {
        console.warn('⚠️ User in token no longer exists. Clearing session...');
        try {
          await this.supabase.auth.signOut();
        } catch (signOutError) {
          console.error('Error during sign out:', signOutError);
        }
        this.user = null;
        this.updateUIForGuestUser();
        
        // Redirect to login if not already on login page
        if (!window.location.pathname.includes('login.html')) {
          console.log('🔄 Redirecting to login page...');
          window.location.href = 'login.html';
        }
        return;
      }
      
      throw error;
    }
  }

  async ensureResponderForCurrentUser() {
    try {
      if (!this.user) return;
      const role = this.user?.user_metadata?.role;
      if (role !== 'responder') return;

      const userId = this.user.id;
      const { data: existing, error: findErr } = await this.supabase
        .from('responder')
        .select('id')
        .eq('user_id', userId)
        .limit(1);

      if (findErr) {
        console.warn('⚠️ ensureResponderForCurrentUser lookup failed:', findErr.message);
        return;
      }
      if (existing && existing.length > 0) return;

      const displayName = this.user.user_metadata?.full_name || this.user.email.split('@')[0];
      const { error: insertErr } = await this.supabase
        .from('responder')
        .insert([{
          name: displayName,
          phone: '09100000000',
          role: 'responder',
          status: 'active',
          is_available: true,
          user_id: userId
        }]);

      if (insertErr) {
        console.warn('⚠️ ensureResponderForCurrentUser insert failed (likely RLS):', insertErr.message);
      } else {
        console.log('✅ Responder record created for current user');
      }
    } catch (e) {
      console.warn('⚠️ ensureResponderForCurrentUser error:', e);
    }
  }

  async ensureSeedResponderIfEmpty() {
    try {
      if (!this.user) return;
      const role = this.user?.user_metadata?.role;
      if (role !== 'admin' && role !== 'super_user') return;

      const { data: countData, error: cntErr } = await this.supabase
        .from('responder')
        .select('id', { count: 'exact', head: true });

      if (cntErr) {
        console.warn('⚠️ ensureSeedResponderIfEmpty count failed:', cntErr.message);
        return;
      }

      const total = countData?.length ?? 0; // head:true returns no rows; rely on count via error object not available in UMD
      // Fallback: query one row to determine emptiness
      let isEmpty = false;
      if (total === 0) {
        const { data: oneRow, error: oneErr } = await this.supabase
          .from('responder')
          .select('id')
          .limit(1);
        if (!oneErr && (!oneRow || oneRow.length === 0)) isEmpty = true;
      }

      if (!isEmpty) return;

      const { error: seedErr } = await this.supabase
        .from('responder')
        .insert([{
          name: 'Demo Responder',
          phone: '09123456789',
          role: 'responder',
          status: 'active',
          is_available: true
        }]);

      if (seedErr) {
        console.warn('⚠️ ensureSeedResponderIfEmpty insert failed (likely RLS):', seedErr.message);
      } else {
        console.log('✅ Seeded first responder so admin dashboard is populated');
      }
    } catch (e) {
      console.warn('⚠️ ensureSeedResponderIfEmpty error:', e);
    }
  }

  async signIn(email, password) {
    try {
      const { data, error } = await this.supabase.auth.signInWithPassword({
        email,
        password
      });

      if (error) throw error;

      this.user = data.user;
      this.updateUIForAuthenticatedUser();
      
      this.showSuccess('Successfully signed in!');
      return data;
    } catch (error) {
      console.error('❌ Sign in failed:', error);
      this.showError('Sign in failed: ' + error.message);
      throw error;
    }
  }

  async signUp(email, password, userData = {}) {
    try {
      const { data, error } = await this.supabase.auth.signUp({
        email,
        password,
        options: {
          data: userData
        }
      });

      if (error) throw error;

      this.showSuccess('Account created! Please check your email to verify your account.');
      return data;
    } catch (error) {
      console.error('❌ Sign up failed:', error);
      this.showError('Sign up failed: ' + error.message);
      throw error;
    }
  }

  async signOut() {
    try {
      console.log('🚪 Signing out...');
      
      const { error } = await this.supabase.auth.signOut();
      if (error) throw error;

      this.user = null;
      this.updateUIForGuestUser();
      
      console.log('✅ Successfully signed out');
      this.showSuccess('Successfully signed out!');
      
      // Redirect to login page after successful sign out
      setTimeout(() => {
        console.log('🔄 Redirecting to login page...');
        window.location.href = 'login.html';
      }, 1000); // Small delay to show success message
      
    } catch (error) {
      console.error('❌ Sign out failed:', error);
      this.showError('Sign out failed: ' + error.message);
      
      // Even if sign out fails, redirect to login page
      setTimeout(() => {
        console.log('🔄 Redirecting to login page despite error...');
        window.location.href = 'login.html';
      }, 2000);
      
      throw error;
    }
  }

  async initializeGeolocation() {
    if (!navigator.geolocation) {
      console.warn('⚠️ Geolocation not supported');
      return;
    }

    try {
      // Use a more conservative approach with better error handling
      const position = await this.getCurrentPosition();
      this.location = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        accuracy: position.coords.accuracy
      };
      
      console.log('✅ Location obtained:', this.location);
      
      // Only start watching if we successfully got initial position
      this.watchId = navigator.geolocation.watchPosition(
        (position) => {
          const newLocation = {
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
            accuracy: position.coords.accuracy
          };
          
          // Only update and log if location has changed significantly
          if (!this.location || 
              Math.abs(this.location.latitude - newLocation.latitude) > 0.001 ||
              Math.abs(this.location.longitude - newLocation.longitude) > 0.001) {
            this.location = newLocation;
            console.log('📍 Location updated:', this.location);
          }
        },
        (error) => {
          // Handle specific geolocation errors more gracefully
          if (error.code === 3) { // TIMEOUT
            console.warn('⚠️ Location timeout - this is normal, continuing without location tracking');
          } else {
            console.warn('⚠️ Location watch error:', error);
          }
        },
        {
          enableHighAccuracy: false, // Reduced accuracy for better performance
          timeout: 10000, // Reduced timeout to 10 seconds
          maximumAge: 300000 // 5 minutes cache time
        }
      );
    } catch (error) {
      // Handle geolocation errors more gracefully
      if (error.code === 3) { // TIMEOUT
        console.warn('⚠️ Location timeout - continuing without location tracking');
      } else {
        console.warn('⚠️ Geolocation failed:', error);
        this.showWarning('Location access denied. You can still report emergencies manually.');
      }
    }
  }

  getCurrentPosition() {
    return new Promise((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 30000
      });
    });
  }

  // Method to set OpenCage API key for geocoding
  setOpenCageApiKey(apiKey) {
    this.opencageApiKey = apiKey;
    console.log('✅ OpenCage API key configured');
  }

  async getAddressFromCoordinates(lat, lng) {
    try {
      // Skip geocoding if no API key is configured
      if (!this.opencageApiKey || this.opencageApiKey === 'YOUR_OPENCAGE_API_KEY') {
        console.log('⚠️ OpenCage API key not configured, skipping geocoding');
        return `Location: ${lat.toFixed(6)}, ${lng.toFixed(6)}`;
      }
      
      const response = await fetch(
        `https://api.opencagedata.com/geocode/v1/json?q=${lat}+${lng}&key=${this.opencageApiKey}`
      );
      const data = await response.json();
      
      if (data.results && data.results.length > 0) {
        return data.results[0].formatted;
      }
      return `${lat.toFixed(6)}, ${lng.toFixed(6)}`;
    } catch (error) {
      console.warn('⚠️ Address lookup failed:', error);
      return `${lat.toFixed(6)}, ${lng.toFixed(6)}`;
    }
  }

  async submitEmergencyReport(reportData) {
    try {
      if (!this.user) {
        throw new Error('You must be signed in to submit a report');
      }

      // Add location data if available (using JSONB location field)
      if (this.location) {
        reportData.location = JSON.stringify({
          latitude: this.location.latitude,
          longitude: this.location.longitude,
          accuracy: this.location.accuracy,
          address: this.location.address || 'Location detected'
        });
      }

      // Add user data and new flow settings
      reportData.reporter_uid = this.user.id; // Use reporter_uid instead of user_id
      reportData.status = 'pending';
      reportData.lifecycle_status = 'pending';

      console.log('📝 Submitting report:', reportData);

      const { data, error } = await this.supabase
        .from('reports')
        .insert([reportData])
        .select()
        .single();

      if (error) throw error;

      console.log('✅ Report submitted:', data);

      // Trigger AI analysis
      await this.triggerAIAnalysis(data.id);

      this.showSuccess('Emergency report submitted successfully! Admin will review and assign responders...');
      return data;
    } catch (error) {
      console.error('❌ Report submission failed:', error);
      this.showError('Failed to submit report: ' + error.message);
      throw error;
    }
  }

  async triggerAIAnalysis(reportId) {
    try {
      console.log('🤖 Triggering AI analysis for report:', reportId);
      
      const { data, error } = await this.supabase.functions.invoke('classify-image', {
        body: { reportId }
      });

      if (error) throw error;

      console.log('✅ AI analysis completed:', data);
      return data;
    } catch (error) {
      console.error('❌ AI analysis failed:', error);
      // Don't throw error here as the report is still submitted
      console.warn('⚠️ Report submitted but AI analysis failed');
    }
  }

  async uploadImage(file) {
    try {
      const fileExt = file.name.split('.').pop();
      const fileName = `${Date.now()}.${fileExt}`;
      const filePath = `emergency-reports/${fileName}`;

      console.log('📤 Uploading image:', fileName);

      const { data, error } = await this.supabase.storage
        .from('reports-images')
        .upload(filePath, file);

      if (error) throw error;

      console.log('✅ Image uploaded:', data);
      
      // Get the public URL for the uploaded image
      const { data: urlData } = this.supabase.storage
        .from('reports-images')
        .getPublicUrl(data.path);
      
      return urlData.publicUrl;
    } catch (error) {
      console.error('❌ Image upload failed:', error);
      this.showError('Failed to upload image: ' + error.message);
      throw error;
    }
  }

  // Helper function to enrich reports with responder names
  async enrichReportsWithResponderNames(reports) {
    if (!reports || reports.length === 0) return reports;
    
    return await Promise.all(reports.map(async (report) => {
      // If responder is already joined, use that name
      if (report.responder) {
        report.responder_name = report.responder.name;
      }
      
      // If no responder_name yet, try to get it from assignments
      if (!report.responder_name && report.id) {
        try {
          const { data: assignments, error: assignError } = await this.supabase
            .from('assignment')
            .select(`
              responder:responder!assignment_responder_id_fkey (
                id,
                name,
                role
              )
            `)
            .eq('report_id', report.id)
            .order('assigned_at', { ascending: false })
            .limit(1);
          
          if (!assignError && assignments && assignments.length > 0 && assignments[0]?.responder?.name) {
            report.responder_name = assignments[0].responder.name;
            report.responder_id = assignments[0].responder.id;
          }
        } catch (err) {
          console.warn('⚠️ Failed to fetch assignment for report:', report.id, err);
        }
      }
      
      return report;
    }));
  }

  async getReports(filters = {}) {
    try {
      console.log('🔍 Fetching reports with filters:', filters);

      // Throttle connection checks to at most once per minute to prevent UI stalls
      const oneMinuteMs = 60 * 1000;
      if (!this.dbHealthy || Date.now() - this.lastDbCheckAt > oneMinuteMs) {
        try {
          await this.testDatabaseConnection();
          this.dbHealthy = true;
          this.lastDbCheckAt = Date.now();
        } catch (err) {
          // Log but don't block fetching; backend may still be reachable for reads
          console.warn('⚠️ Skipping strict DB health requirement for fetch:', err?.message || err);
        }
      }
      
      let query = this.supabase
        .from('reports')
        .select(`
          *,
          responder:responder_id (
            id,
            name,
            phone,
            role
          )
        `)
        .order('created_at', { ascending: false });

      // Apply filters
      if (filters.status) {
        query = query.eq('status', filters.status);
      }
      if (filters.type) {
        query = query.eq('type', filters.type);
      }
      if (filters.user_id) {
        query = query.eq('reporter_uid', filters.user_id);
      }

      const { data, error } = await query;

      if (error) {
        console.error('❌ Failed to fetch reports:', error);
        console.error('Error details:', {
          message: error.message,
          details: error.details,
          hint: error.hint,
          code: error.code
        });
        
        // If RLS policy error, try to get reports without filters
        if (error.message.includes('row-level security policy')) {
          console.log('⚠️ RLS policy blocking access, trying alternative approach...');
          
          // For admin, super_user and responder roles, try to get all reports
          const userRole = this.user?.user_metadata?.role;
          if (userRole === 'admin' || userRole === 'super_user' || userRole === 'responder') {
            console.log('🔧 Admin/Responder detected, trying to access all reports...');
            
            // Try without user_id filter for admin/responder
            const { data: allData, error: allError } = await this.supabase
              .from('reports')
              .select(`
                *,
                responder:responder_id (
                  id,
                  name,
                  phone,
                  role
                )
              `)
              .order('created_at', { ascending: false });
              
            if (allError) {
              console.error('❌ Alternative approach failed:', allError.message);
              this.showError('Failed to load reports: ' + allError.message);
              throw allError;
            }
            
            console.log('✅ Alternative approach successful:', allData.length, 'reports');
            // Enrich reports with responder names
            return await this.enrichReportsWithResponderNames(allData || []);
          }
        }
        
        this.showError('Failed to load reports: ' + error.message);
        throw error;
      }

      console.log('✅ Reports loaded successfully:', data.length);
      
      // Enrich reports with responder names
      return await this.enrichReportsWithResponderNames(data || []);
    } catch (error) {
      console.error('❌ Failed to fetch reports:', error);
      this.showError('Failed to load reports: ' + error.message);
      throw error;
    }
  }

  async getReportById(id) {
    try {
      const { data, error } = await this.supabase
        .from('reports')
        .select(`
          *,
          responder:responder_id (
            id,
            name,
            phone,
            role
          )
        `)
        .eq('id', id)
        .single();

      if (error) throw error;

      // Add responder_name to the report data for backward compatibility
      if (data.responder) {
        data.responder_name = data.responder.name;
      }

      return data;
    } catch (error) {
      console.error('❌ Failed to fetch report:', error);
      this.showError('Failed to load report: ' + error.message);
      throw error;
    }
  }

  // Responder Management Functions
  async getResponders(filters = {}) {
    try {
      console.log('🔍 Fetching responders with filters:', filters);
      
      let query = this.supabase
        .from('responder')
        .select('*')
        .order('created_at', { ascending: false });

      // Apply filters
      if (filters.status) {
        query = query.eq('status', filters.status);
      }
      if (filters.role) {
        query = query.eq('role', filters.role);
      }
      if (filters.is_available !== undefined) {
        query = query.eq('is_available', filters.is_available);
      }

      const { data, error } = await query;

      if (error) {
        console.error('❌ Failed to fetch responders:', error);
        this.showError('Failed to load responders: ' + error.message);
        throw error;
      }

      console.log('✅ Responders loaded successfully:', data.length);
      return data || [];
    } catch (error) {
      console.error('❌ Failed to fetch responders:', error);
      this.showError('Failed to load responders: ' + error.message);
      throw error;
    }
  }

  async getResponderById(id) {
    try {
      const { data, error } = await this.supabase
        .from('responder')
        .select('*')
        .eq('id', id)
        .single();

      if (error) {
        console.error('❌ Failed to fetch responder:', error);
        this.showError('Failed to load responder: ' + error.message);
        throw error;
      }

      return data;
    } catch (error) {
      console.error('❌ Failed to fetch responder:', error);
      this.showError('Failed to load responder: ' + error.message);
      throw error;
    }
  }

  async getResponderAssignments(responderId) {
    try {
      const { data, error } = await this.supabase
        .from('assignment')
        .select(`
          *,
          reports:reports!assignment_report_id_fkey (
            id,
            message,
            type,
            status,
            created_at,
            location
          )
        `)
        .eq('responder_id', responderId)
        .order('created_at', { ascending: false });

      if (error) {
        console.error('❌ Failed to fetch responder assignments:', error);
        throw error;
      }

      return data || [];
    } catch (error) {
      console.error('❌ Failed to fetch responder assignments:', error);
      throw error;
    }
  }

  async updateResponderStatus(responderId, status, isAvailable = null) {
    try {
      const updateData = { status };
      if (isAvailable !== null) {
        updateData.is_available = isAvailable;
      }

      const { data, error } = await this.supabase
        .from('responder')
        .update(updateData)
        .eq('id', responderId)
        .select();

      if (error) {
        console.error('❌ Failed to update responder status:', error);
        this.showError('Failed to update responder status: ' + error.message);
        throw error;
      }

      console.log('✅ Responder status updated successfully');
      return data;
    } catch (error) {
      console.error('❌ Failed to update responder status:', error);
      this.showError('Failed to update responder status: ' + error.message);
      throw error;
    }
  }

  async updateReportStatus(id, status, notes = '') {
    try {
      const updateData = {
        status
      };
      
      // Note: Only update fields that exist in the database schema
      // 'notes' and 'updated_at' fields don't exist in the reports table
      
      const { data, error } = await this.supabase
        .from('reports')
        .update(updateData)
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;

      console.log('✅ Report status updated:', data);
      return data;
    } catch (error) {
      console.error('❌ Failed to update report:', error);
      this.showError('Failed to update report: ' + error.message);
      throw error;
    }
  }

  async subscribeToNotifications(callback) {
    try {
      const channel = this.supabase
        .channel('emergency-notifications')
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'reports'
        }, callback)
        .subscribe();

      console.log('🔔 Subscribed to notifications');
      return channel;
    } catch (error) {
      console.error('❌ Failed to subscribe to notifications:', error);
      throw error;
    }
  }

  async sendNotification(title, message, type = 'info') {
    try {
      if ('Notification' in window) {
        if (Notification.permission === 'granted') {
          new Notification(title, {
            body: message,
            icon: '/images/emergency-icon.png'
          });
        } else if (Notification.permission !== 'denied') {
          const permission = await Notification.requestPermission();
          if (permission === 'granted') {
            new Notification(title, {
              body: message,
              icon: '/images/emergency-icon.png'
            });
          }
        }
      }
    } catch (error) {
      console.error('❌ Failed to send notification:', error);
    }
  }

  updateUIForAuthenticatedUser() {
    // Update UI elements for authenticated user
    const authElements = document.querySelectorAll('[data-auth="required"]');
    authElements.forEach(el => el.style.display = 'block');

    const guestElements = document.querySelectorAll('[data-auth="guest"]');
    guestElements.forEach(el => el.style.display = 'none');

    // Update user info
    const userInfoElements = document.querySelectorAll('[data-user-info]');
    userInfoElements.forEach(el => {
      if (el.dataset.userInfo === 'email') {
        el.textContent = this.user.email;
      }
    });
  }

  updateUIForGuestUser() {
    // Update UI elements for guest user
    const authElements = document.querySelectorAll('[data-auth="required"]');
    authElements.forEach(el => el.style.display = 'none');

    const guestElements = document.querySelectorAll('[data-auth="guest"]');
    guestElements.forEach(el => el.style.display = 'block');
  }

  showSuccess(message) {
    this.showAlert(message, 'success');
  }

  showError(message) {
    this.showAlert(message, 'error');
  }

  showWarning(message) {
    this.showAlert(message, 'warning');
  }

  showInfo(message) {
    this.showAlert(message, 'info');
  }

  showAlert(message, type = 'info') {
    // Create alert element
    const alert = document.createElement('div');
    alert.className = `alert alert-${type}`;
    alert.innerHTML = `
      <div class="flex items-center gap-4">
        <span>${message}</span>
        <button onclick="this.parentElement.parentElement.remove()" class="ml-auto text-gray-500 hover:text-gray-700">
          ×
        </button>
      </div>
    `;

    // Add to page
    const container = document.querySelector('.alerts-container') || document.body;
    container.insertBefore(alert, container.firstChild);

    // Auto remove after 5 seconds
    setTimeout(() => {
      if (alert.parentElement) {
        alert.remove();
      }
    }, 5000);
  }

  // Archive Management Functions
  async getArchivedReports() {
    try {
      console.log('🔍 Fetching archived reports...');
      
      const { data, error } = await this.supabase
        .from('reports_archived')
        .select('*')
        .order('archived_at', { ascending: false });

      if (error) {
        console.error('❌ Failed to fetch archived reports:', error);
        this.showError('Failed to load archived reports: ' + error.message);
        throw error;
      }

      console.log('✅ Archived reports loaded successfully:', data.length);
      return data || [];
    } catch (error) {
      console.error('❌ Failed to fetch archived reports:', error);
      this.showError('Failed to load archived reports: ' + error.message);
      throw error;
    }
  }

  async archiveReport(reportId) {
    try {
      console.log('📁 Archiving report:', reportId);
      
      // First, get the report data
      const { data: report, error: fetchError } = await this.supabase
        .from('reports')
        .select('*')
        .eq('id', reportId)
        .single();

      if (fetchError) throw fetchError;

      // Insert into archived table
      const { data: archivedData, error: archiveError } = await this.supabase
        .from('reports_archived')
        .insert([{
          ...report,
          archived_at: new Date().toISOString(),
          archived_by: this.user?.id
        }]);

      if (archiveError) throw archiveError;

      // Delete from main reports table
      const { error: deleteError } = await this.supabase
        .from('reports')
        .delete()
        .eq('id', reportId);

      if (deleteError) throw deleteError;

      console.log('✅ Report archived successfully');
      return archivedData;
    } catch (error) {
      console.error('❌ Failed to archive report:', error);
      this.showError('Failed to archive report: ' + error.message);
      throw error;
    }
  }

  async restoreFromArchive(reportId) {
    try {
      console.log('🔄 Restoring report from archive:', reportId);
      
      // Get archived report
      const { data: archivedReport, error: fetchError } = await this.supabase
        .from('reports_archived')
        .select('*')
        .eq('id', reportId)
        .single();

      if (fetchError) {
        console.error('❌ Failed to fetch archived report:', fetchError);
        throw fetchError;
      }

      if (!archivedReport) {
        throw new Error('Archived report not found');
      }

      console.log('📄 Retrieved archived report:', archivedReport.id);

      // Remove archived fields and prepare data for restoration
      const { archived_at, archived_by, ...reportData } = archivedReport;
      
      // Handle foreign key constraints by checking if referenced records exist
      if (reportData.assignment_id) {
        const { data: assignmentExists } = await this.supabase
          .from('assignment')
          .select('id')
          .eq('id', reportData.assignment_id)
          .single();
          
        if (!assignmentExists) {
          console.log('⚠️ Assignment not found, removing assignment_id reference');
          reportData.assignment_id = null;
        }
      }
      
      if (reportData.responder_id) {
        const { data: responderExists } = await this.supabase
          .from('responder')
          .select('id')
          .eq('id', reportData.responder_id)
          .single();
          
        if (!responderExists) {
          console.log('⚠️ Responder not found, removing responder_id reference');
          reportData.responder_id = null;
        }
      }
      
      // First, check if report already exists in main table
      const { data: existingReport } = await this.supabase
        .from('reports')
        .select('id')
        .eq('id', reportData.id)
        .single();

      let restoredData;
      
      if (existingReport) {
        // Report already exists, update it instead
        console.log('📝 Report already exists, updating instead of inserting');
        const { data: updatedData, error: updateError } = await this.supabase
          .from('reports')
          .update(reportData)
          .eq('id', reportData.id)
          .select()
          .single();
          
        if (updateError) {
          console.error('❌ Update error details:', updateError);
          throw updateError;
        }
        restoredData = updatedData;
      } else {
        // Report doesn't exist, insert it
        console.log('➕ Inserting new report');
        
        try {
          const { data: insertedData, error: insertError } = await this.supabase
            .from('reports')
            .insert([reportData])
            .select()
            .single();
            
          if (insertError) {
            console.error('❌ Insert error details:', insertError);
            throw insertError;
          }
          restoredData = insertedData;
        } catch (insertError) {
          // If insert fails due to foreign key constraints, try with minimal data
          if (insertError.code === '23503') {
            console.log('🔄 Retrying with minimal data due to foreign key constraint');
            
            // Create minimal report data without foreign key references
            const minimalData = {
              id: reportData.id,
              reporter_uid: reportData.reporter_uid,
              reporter_name: reportData.reporter_name,
              message: reportData.message,
              location: reportData.location,
              image_path: reportData.image_path,
              type: reportData.type,
              confidence: reportData.confidence,
              status: reportData.status || 'pending',
              created_at: reportData.created_at,
              ai_labels: reportData.ai_labels,
              ai_timestamp: reportData.ai_timestamp,
              ai_confidence: reportData.ai_confidence,
              ai_model: reportData.ai_model,
              ai_description: reportData.ai_description,
              ai_objects: reportData.ai_objects,
              ai_analysis: reportData.ai_analysis,
              priority: reportData.priority,
              severity: reportData.severity,
              response_time: reportData.response_time,
              emergency_color: reportData.emergency_color,
              emergency_icon: reportData.emergency_icon,
              recommendations: reportData.recommendations,
              lifecycle_status: reportData.lifecycle_status,
              last_update: reportData.last_update
              // Exclude responder_id and assignment_id to avoid foreign key issues
            };
            
            const { data: minimalInsertedData, error: minimalInsertError } = await this.supabase
              .from('reports')
              .insert([minimalData])
              .select()
              .single();
              
            if (minimalInsertError) {
              console.error('❌ Minimal insert error details:', minimalInsertError);
              throw minimalInsertError;
            }
            restoredData = minimalInsertedData;
          } else {
            throw insertError;
          }
        }
      }

      // Delete from archived table only after successful restore
      const { error: deleteError } = await this.supabase
        .from('reports_archived')
        .delete()
        .eq('id', reportId);

      if (deleteError) {
        console.warn('⚠️ Failed to delete from archive, but report was restored:', deleteError);
        // Don't throw here as the main operation succeeded
      }

      console.log('✅ Report restored successfully');
      return restoredData;
    } catch (error) {
      console.error('❌ Failed to restore report:', error);
      this.showError('Failed to restore report: ' + (error.message || 'Unknown error'));
      throw error;
    }
  }

  async deleteArchivedReport(reportId) {
    try {
      console.log('🗑️ Deleting archived report:', reportId);
      
      const { error } = await this.supabase
        .from('reports_archived')
        .delete()
        .eq('id', reportId);

      if (error) throw error;

      console.log('✅ Archived report deleted successfully');
    } catch (error) {
      console.error('❌ Failed to delete archived report:', error);
      this.showError('Failed to delete archived report: ' + error.message);
      throw error;
    }
  }

  async clearAllArchived() {
    try {
      console.log('🗑️ Clearing all archived reports...');
      
      const { error } = await this.supabase
        .from('reports_archived')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all records

      if (error) throw error;

      console.log('✅ All archived reports cleared');
    } catch (error) {
      console.error('❌ Failed to clear archived reports:', error);
      this.showError('Failed to clear archived reports: ' + error.message);
      throw error;
    }
  }

  // Report Management Functions
  async deleteReport(reportId) {
    try {
      console.log('🗑️ Deleting report:', reportId);
      
      const { error } = await this.supabase
        .from('reports')
        .delete()
        .eq('id', reportId);

      if (error) throw error;

      console.log('✅ Report deleted successfully');
    } catch (error) {
      console.error('❌ Failed to delete report:', error);
      this.showError('Failed to delete report: ' + error.message);
      throw error;
    }
  }

  async editReport(reportId, updateData) {
    try {
      console.log('✏️ Editing report:', reportId, updateData);
      
      const { data, error } = await this.supabase
        .from('reports')
        .update(updateData)
        .eq('id', reportId)
        .select()
        .single();

      if (error) throw error;

      console.log('✅ Report updated successfully');
      return data;
    } catch (error) {
      console.error('❌ Failed to edit report:', error);
      this.showError('Failed to edit report: ' + error.message);
      throw error;
    }
  }

  // User Management Functions
  async getUsers(filters = {}) {
    try {
      console.log('🔍 Fetching users with filters:', filters);
      
      // Try to get users from auth system first
      try {
        const users = await this.getAllUsers();
        
        // Transform auth users to our format
        const transformedUsers = users.map(user => ({
          id: user.id,
          email: user.email,
          name: user.user_metadata?.full_name || user.email.split('@')[0],
          role: user.user_metadata?.role || 'citizen',
          phone: user.user_metadata?.phone || '',
          department: user.user_metadata?.department || '',
          is_active: user.user_metadata?.is_active !== false, // Default to true if not set
          created_at: user.created_at,
          last_sign_in_at: user.last_sign_in_at
        }));

        // Apply filters
        let filteredUsers = transformedUsers;
        if (filters.role) {
          filteredUsers = transformedUsers.filter(user => user.role === filters.role);
        }
        if (filters.is_active !== undefined) {
          filteredUsers = transformedUsers.filter(user => user.is_active === filters.is_active);
        }

        console.log('✅ Users loaded successfully:', filteredUsers.length);
        return filteredUsers;
      } catch (authError) {
        console.warn('⚠️ Auth approach failed, trying fallback:', authError);
        return await this.getUsersFromAuth(filters);
      }
    } catch (error) {
      console.error('❌ Failed to fetch users:', error);
      console.log('🔄 Trying fallback approach...');
      return await this.getUsersFromAuth(filters);
    }
  }

  // Get users from auth system using a different approach
  async getUsersFromAuth(filters = {}) {
    try {
      console.log('🔍 Trying to get users from auth system...');
      
      // Since we can't access auth.users directly, let's try to get user data
      // from the reports table where we can see who submitted reports
      const { data: reports, error: reportsError } = await this.supabase
        .from('reports')
        .select('reporter_uid, reporter_name')
        .not('reporter_uid', 'is', null);

      if (reportsError) {
        console.error('❌ Failed to get reports for user counting:', reportsError);
        return [];
      }

      // Extract unique users from reports
      const uniqueUsers = new Map();
      reports.forEach(report => {
        if (report.reporter_uid && report.reporter_name) {
          uniqueUsers.set(report.reporter_uid, {
            id: report.reporter_uid,
            user_id: report.reporter_uid,
            role: 'citizen', // Assume all report submitters are citizens
            name: report.reporter_name,
            is_active: true,
            created_at: new Date().toISOString()
          });
        }
      });

      const users = Array.from(uniqueUsers.values());
      
      // Apply filters
      let filteredUsers = users;
      if (filters.role) {
        filteredUsers = users.filter(user => user.role === filters.role);
      }
      if (filters.is_active !== undefined) {
        filteredUsers = users.filter(user => user.is_active === filters.is_active);
      }

      console.log('✅ Users extracted from reports:', filteredUsers.length);
      return filteredUsers;
      
    } catch (error) {
      console.error('❌ Auth approach also failed:', error);
      return [];
    }
  }


  // Assignment Functions
  async assignResponder(reportId, responderId) {
    try {
      console.log('👥 Assigning responder:', responderId, 'to report:', reportId);
      
      // Create assignment record
      const { data: assignment, error: assignmentError } = await this.supabase
        .from('assignment')
        .insert([{
          report_id: reportId,
          responder_id: responderId,
          status: 'assigned',
          assigned_at: new Date().toISOString()
        }])
        .select()
        .single();

      if (assignmentError) throw assignmentError;

      // Update report with assignment
      const { error: updateError } = await this.supabase
        .from('reports')
        .update({
          responder_id: responderId,
          assignment_id: assignment.id,
          status: 'assigned'
        })
        .eq('id', reportId);

      if (updateError) throw updateError;

      console.log('✅ Responder assigned successfully');
      return assignment;
    } catch (error) {
      console.error('❌ Failed to assign responder:', error);
      this.showError('Failed to assign responder: ' + error.message);
      throw error;
    }
  }


  cleanup() {
    if (this.watchId) {
      navigator.geolocation.clearWatch(this.watchId);
    }
  }
}

// Initialize global instance
window.emergencySystem = new EmergencyResponseSystem();

// Auto-initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  window.emergencySystem.initialize();
});

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
  window.emergencySystem.cleanup();
});
