import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/supabase_service.dart';
import 'services/onesignal_service.dart';
import 'services/auto_sync_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/emergency_report_screen.dart';
import 'screens/safety_tips_screen.dart';
import 'screens/my_reports_screen.dart';
import 'screens/learning_modules_screen.dart';
import 'screens/responder_dashboard_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/map_simulation_screen.dart';
import 'screens/super_user_dashboard_screen.dart';
import 'screens/super_user_reports_screen.dart';
import 'screens/super_user_announcements_screen.dart';
import 'screens/super_user_map_screen.dart';
import 'screens/super_user_early_warning_screen.dart';
import 'screens/super_user_sos_alerts_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseService.initialize();
  
  // Initialize OneSignal for push notifications
  await OneSignalService().initialize();
  
  // Initialize auto-sync service for offline reports
  AutoSyncService().initialize(navigatorKey: navigatorKey);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'LSPU DRES',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3b82f6), // Web admin blue
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: _AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/emergency-report': (context) => const EmergencyReportScreen(),
        '/safety-tips': (context) => const SafetyTipsScreen(),
        '/learning-modules': (context) => const LearningModulesScreen(),
        '/my-reports': (context) => const MyReportsScreen(),
        '/responder-dashboard': (context) => const ResponderDashboardScreen(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/map': (context) => const MapSimulationScreen(),
        '/super-user': (context) => const SuperUserDashboardScreen(),
        '/super-user-reports': (context) => const SuperUserReportsScreen(),
        '/super-user-announcements': (context) => const SuperUserAnnouncementsScreen(),
        '/super-user-map': (context) => const SuperUserMapScreen(),
        '/super-user-early-warning': (context) => const SuperUserEarlyWarningScreen(),
        '/super-user-sos-alerts': (context) => const SuperUserSOSAlertsScreen(),
      },
    );
  }
}

class _AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SupabaseService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check if user is authenticated
        if (SupabaseService.isAuthenticated) {
          return const RoleRouter();
        }

        return const LoginScreen();
      },
    );
  }
}

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  bool _isLoading = true;
  String? _role;

  @override
  void initState() {
    super.initState();
    _determineRole();
  }

  Future<void> _determineRole() async {
    try {
      // Small delay to ensure auth state is fully ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      final userId = SupabaseService.currentUserId;
      debugPrint('🔍 RoleRouter: Checking user authentication. User ID: $userId');
      
      if (userId == null) {
        debugPrint('⚠️ RoleRouter: No user ID found, user not authenticated');
        setState(() {
          _role = null;
          _isLoading = false;
        });
        return;
      }

      // Retry saving OneSignal player ID if user is already authenticated
      debugPrint('✅ User already authenticated (ID: ${userId.substring(0, 8)}...), retrying OneSignal Player ID save...');
      await OneSignalService().retrySavePlayerIdToSupabase();

      final response = await SupabaseService.client
          .from('user_profiles')
          .select('role')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['role'] != null) {
        _role = (response['role'] as String?)?.toLowerCase();
      } else {
        final responderMatch = await SupabaseService.client
            .from('responder')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (responderMatch != null) {
          _role = 'responder';
        } else {
          final metadataRole =
              SupabaseService.currentUser?.userMetadata?['role'] as String?;
          _role = metadataRole?.toLowerCase();
        }
      }

      // Check for super_user in metadata if not found in profile
      if (_role != 'super_user') {
        final metadataRole =
            SupabaseService.currentUser?.userMetadata?['role'] as String?;
        if (metadataRole?.toLowerCase() == 'super_user') {
          _role = 'super_user';
        }
      }

      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      _role = null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Route super_user to super user dashboard
    if (_role == 'super_user') {
      return const SuperUserDashboardScreen();
    }

    if (_role == 'responder' || _role == 'admin') {
      return const ResponderDashboardScreen();
    }

    return const HomeScreen();
  }
}
