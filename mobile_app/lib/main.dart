import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/supabase_service.dart';
import 'services/onesignal_service.dart';
import 'services/auto_sync_service.dart';
import 'services/update_check_service.dart';
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Ensure every device gets registered for push (new user, new phone, or late subscription)
      OneSignalService().retrySavePlayerIdToSupabase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'KAPIYU',
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

        // Check if user is authenticated, then run update check before showing any screen
        final isAuthenticated = SupabaseService.isAuthenticated;
        return _UpdateCheckGate(isAuthenticated: isAuthenticated);
      },
    );
  }
}

/// Runs update check once before any screen. If installed version < min_version (from DB),
/// shows full-screen block only—no login, no app use. Old APKs cannot be used.
class _UpdateCheckGate extends StatefulWidget {
  final bool isAuthenticated;

  const _UpdateCheckGate({required this.isAuthenticated});

  @override
  State<_UpdateCheckGate> createState() => _UpdateCheckGateState();
}

class _UpdateCheckGateState extends State<_UpdateCheckGate> {
  bool _checking = true;
  bool _updateRequired = false;
  UpdateCheckResult? _updateResult;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    setState(() => _checking = true);
    final result = await UpdateCheckService.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _updateResult = result;
      _updateRequired = result?.status == UpdateStatus.updateRequired;
    });
    if (!_updateRequired && result != null && result.status == UpdateStatus.updateAvailable) {
      UpdateCheckService.showUpdateDialogIfNeeded(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_updateRequired && _updateResult != null) {
      return _UpdateRequiredScreen(result: _updateResult!);
    }
    // Version check failed (null): block until check succeeds; no bypass so old builds cannot be used
    if (_updateResult == null) {
      return _UpdateCheckFailedScreen(onRetry: _runCheck);
    }
    if (widget.isAuthenticated) {
      return const RoleRouter();
    }
    return const LoginScreen();
  }
}

/// Full-screen block when version is below min_version. App does not work until user updates.
class _UpdateRequiredScreen extends StatelessWidget {
  final UpdateCheckResult result;

  const _UpdateRequiredScreen({required this.result});

  Future<void> _downloadAndInstall(BuildContext context) async {
    final url = result.downloadUrl;
    if (url == null || url.isEmpty) {
      UpdateCheckService.openDownloadUrl(url);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
    double? lastProgress;
    await UpdateCheckService.downloadAndInstallApk(
      url,
      onProgress: (progress) {
        lastProgress = progress;
        _DownloadProgressDialog.updateProgress?.call(progress);
      },
      onInstallError: (message) {
        if (context.mounted) {
          Navigator.of(context).pop(); // close progress dialog
          UpdateCheckService.showInstallErrorDialog(context, message, url);
        }
      },
    );
    if (context.mounted) Navigator.of(context).pop();
    // System installer opens; user taps Install once and old app is replaced (same signing + higher versionCode).
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.system_update_alt, size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'Update required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'You need to update to continue. This version (${result.currentVersion}) can no longer be used. Please install version ${result.latestVersion} or newer.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (result.releaseNotes != null && result.releaseNotes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(result.releaseNotes!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _downloadAndInstall(context),
                  icon: const Icon(Icons.download),
                  label: const Text('Download and install'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => UpdateCheckService.openDownloadUrl(result.downloadUrl),
                  child: const Text('Open in browser instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final VoidCallback? onCancel;

  const _DownloadProgressDialog({this.onCancel});

  static void Function(double)? updateProgress;

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _DownloadProgressDialog.updateProgress = (p) {
      if (mounted) setState(() => _progress = p);
    };
  }

  @override
  void dispose() {
    _DownloadProgressDialog.updateProgress = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Downloading update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _progress.clamp(0.0, 1.0)),
          const SizedBox(height: 16),
          Text('${(_progress * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Shown when version check fails (network/error). User must retry until check succeeds; no bypass.
class _UpdateCheckFailedScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _UpdateCheckFailedScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 72, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 24),
                Text(
                  'Could not check for updates',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Please check your internet connection and try again. You must pass the update check to use the app.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
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
