import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://hmolyqzbvxxliemclrld.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyNDY5NzAsImV4cCI6MjA3NTgyMjk3MH0.G2AOT-8zZ5sk8qGQUBifFqq5ww2W7Hxvtux0tlQ0Q-4';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Authentication methods
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Sign up for citizens only with metadata including user type
  static Future<AuthResponse> signUpAsCitizen({
    required String email,
    required String password,
    required String fullName,
    String? userType,
    String? studentNumber,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': 'citizen',
        'user_type': userType ?? 'student', // Default to student if not specified
        if (studentNumber != null && studentNumber.isNotEmpty)
          'student_number': studentNumber,
      },
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static User? get currentUser => client.auth.currentUser;

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // Check if user is authenticated
  static bool get isAuthenticated => client.auth.currentUser != null;

  // Get current user ID
  static String? get currentUserId => client.auth.currentUser?.id;

  // Get current user email
  static String? get currentUserEmail => client.auth.currentUser?.email;

  /// Returns current user role: citizen, responder, or super_user. Null if not logged in.
  static Future<String?> getCurrentUserRole() async {
    final userId = currentUserId;
    if (userId == null) return null;
    try {
      final response = await client
          .from('user_profiles')
          .select('role')
          .eq('user_id', userId)
          .maybeSingle();
      if (response != null && response['role'] != null) {
        return (response['role'] as String?)?.toLowerCase();
      }
      final responderMatch = await client
          .from('responder')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      if (responderMatch != null) return 'responder';
      final metadataRole = currentUser?.userMetadata?['role'] as String?;
      if (metadataRole?.toLowerCase() == 'super_user') return 'super_user';
      return metadataRole?.toLowerCase() ?? 'citizen';
    } catch (_) {
      return null;
    }
  }

  // Resend email verification
  static Future<void> resendEmailVerification({
    required String email,
  }) async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  /// Fetch recent reports for synopsis (type, corrected_type, created_at). Last 30 days filtered in app.
  static Future<List<Map<String, dynamic>>> getReportsForSynopsis() async {
    try {
      final response = await client
          .from('reports')
          .select('id, type, corrected_type, created_at')
          .order('created_at', ascending: false)
          .limit(500);
      final list = response as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch current safety notice (editable by admin). Returns null if none or error.
  static Future<Map<String, dynamic>?> getSafetyNotice() async {
    try {
      final response = await client
          .from('safety_notice')
          .select('id, message, enabled, updated_at')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return null;
    }
  }

  /// Update safety notice (admin/super_user only). Pass null to leave unchanged.
  static Future<void> updateSafetyNotice({
    String? message,
    bool? enabled,
  }) async {
    final notice = await getSafetyNotice();
    if (notice == null) return;
    final id = notice['id'] as String?;
    if (id == null) return;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': currentUserId,
    };
    if (message != null) updates['message'] = message;
    if (enabled != null) updates['enabled'] = enabled;
    await client.from('safety_notice').update(updates).eq('id', id);
  }

  // Reset password
  static Future<void> resetPassword({
    required String email,
  }) async {
    // For mobile, we'll use a deep link that can be handled by the app
    // The app should handle the reset token and show a password reset screen
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.lspu_dres://reset-password',
    );
  }
  
  // Update password (used after clicking reset link)
  static Future<void> updatePassword({
    required String newPassword,
  }) async {
    final response = await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    if (response.user == null) {
      throw Exception('Failed to update password');
    }
  }
}

