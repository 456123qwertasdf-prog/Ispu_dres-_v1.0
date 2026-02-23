import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/supabase_service.dart';
import '../services/emergency_sound_service.dart';
import '../services/onesignal_service.dart';
import '../utils/synopsis_helper.dart';
import 'learning_modules_screen.dart';
import 'notifications_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = false;
  String _weatherStatus = 'Loading...';
  DateTime? _lastUpdated;
  Timer? _emergencyPollTimer;
  
  // User profile data
  String _username = 'Kapiyu';
  String _userEmail = 'user@lspu.edu.ph';
  String _userRole = 'citizen';
  bool _isLoadingProfile = false;
  RealtimeChannel? _announcementChannel;
  Map<String, dynamic>? _activeEmergency;
  final Set<String> _dismissedAlertIds = <String>{};
  bool _isAlertDialogVisible = false;
  final EmergencySoundService _soundService = EmergencySoundService();
  
  // SOS Location tracking
  Position? _sosPosition;
  bool _isGettingSosLocation = false;
  bool _sosLocationReady = false;

  // Citizen synopsis (Safety Notice)
  String? _citizenSynopsisMessage;
  bool _synopsisLoaded = false;
  
  // Use centralized Supabase service
  String get _supabaseUrl => SupabaseService.supabaseUrl;
  String get _supabaseKey => SupabaseService.supabaseAnonKey;
  static const String _primaryEmergencyNumber = '09959645319';
  bool get _isResponder => _userRole == 'responder' || _userRole == 'admin';

  @override
  void initState() {
    super.initState();
    
    // Retry saving OneSignal player ID if user is already authenticated
    _retrySaveOneSignalPlayerId();
    
    _loadWeatherData();
    _loadUserProfile();
    _loadActiveEmergencyAlert();
    _subscribeToEmergencyAlerts();
    _startEmergencyPolling();
    _loadCitizenSynopsis();
  }

  Future<void> _loadCitizenSynopsis() async {
    try {
      final reports = await SupabaseService.getReportsForSynopsis();
      final synopsis = SynopsisHelper.getSynopsisForRole(reports, 'citizen');
      if (mounted) {
        setState(() {
          _citizenSynopsisMessage = synopsis['citizenMessage'];
          _synopsisLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _citizenSynopsisMessage = 'Stay alert and report any real emergency you see.';
          _synopsisLoaded = true;
        });
      }
    }
  }
  
  Future<void> _retrySaveOneSignalPlayerId() async {
    final userId = SupabaseService.currentUserId;
    debugPrint('🔍 HomeScreen: Checking OneSignal Player ID save. User ID: $userId');
    
    if (userId != null) {
      debugPrint('✅ User authenticated in HomeScreen, retrying OneSignal Player ID save...');
      await OneSignalService().retrySavePlayerIdToSupabase();
    } else {
      debugPrint('⚠️ HomeScreen: No user ID found, skipping Player ID retry');
    }
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showCallFailure();
      }
    } catch (_) {
      _showCallFailure();
    }
  }

  void _showCallFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to start phone call on this device.')),
    );
  }

  Future<void> _loadWeatherData() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherStatus = 'Loading...';
    });

    try {
      final response = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/enhanced-weather-alert'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_supabaseKey',
        },
        body: jsonEncode({
          'latitude': 14.262585,
          'longitude': 121.398436,
          'city': 'LSPU Sta. Cruz Campus, Laguna, Philippines',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _weatherData = data['weather_data'] ?? data;
          _weatherStatus = 'Live';
          _isLoadingWeather = false;
          _lastUpdated = DateTime.now();
        });
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      setState(() {
        _weatherStatus = 'Error';
        _isLoadingWeather = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load weather data: $e')),
        );
      }
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      // Try to get user ID from Supabase auth or SharedPreferences
      final userId = SupabaseService.currentUserId ?? 
          (await SharedPreferences.getInstance()).getString('user_id');
      final userEmail = SupabaseService.currentUserEmail ?? 
          (await SharedPreferences.getInstance()).getString('user_email');

      if (userId != null && userId.isNotEmpty) {
        // Fetch user profile from Supabase using the client
        final response = await SupabaseService.client
            .from('user_profiles')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (response != null) {
          setState(() {
            _username = response['name'] ?? 'Kapiyu';
            _userEmail = userEmail ?? response['email'] ?? 'user@lspu.edu.ph';
            _userRole = (response['role'] as String?)?.toLowerCase() ?? _userRole;
            _isLoadingProfile = false;
          });
          return;
        }
      }

      // Fallback: Use stored email or default values
      if (userEmail != null && userEmail.isNotEmpty) {
        setState(() {
          _userEmail = userEmail;
          _username = userEmail.split('@')[0];
          _userRole = 'citizen';
          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          _userRole = 'citizen';
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      // On error, keep default values
      setState(() {
        _isLoadingProfile = false;
      });
      // Silently fail - don't show error for profile loading
    }
  }

  Future<void> _syncOneSignalPlayerId() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final userId = SupabaseService.currentUserId;
      
      if (userId == null) {
        Navigator.pop(context); // Close loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Not logged in. Please login first.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      debugPrint('🔄 Manual sync: Saving OneSignal Player ID...');
      await OneSignalService().retrySavePlayerIdToSupabase();
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notifications synced successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadActiveEmergencyAlert() async {
    try {
      final alert = await SupabaseService.client
          .from('announcements')
          .select()
          .eq('status', 'active')
          .eq('type', 'emergency')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted || alert == null) return;

      final alertId = alert['id']?.toString();
      if (alertId != null && !_dismissedAlertIds.contains(alertId)) {
        setState(() {
          _activeEmergency = alert;
        });
      }
    } catch (error) {
      debugPrint('Failed to load active emergency alert: $error');
    }
  }

  void _startEmergencyPolling() {
    _emergencyPollTimer?.cancel();
    // Fallback in case Realtime connection is lost or unavailable.
    _emergencyPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadActiveEmergencyAlert(),
    );
  }

  void _subscribeToEmergencyAlerts() {
    _announcementChannel =
        SupabaseService.client.channel('mobile-admin-announcements-home');

    _announcementChannel?.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'announcements',
      callback: (payload) {
        final record = payload.newRecord;
        if (record != null) {
          _handleIncomingAnnouncement(record, shouldAlertUser: true);
        }
      },
    );

    _announcementChannel?.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'announcements',
      callback: (payload) {
        final record = payload.newRecord;
        if (record == null) return;
        final status = (record['status'] ?? '').toString().toLowerCase();
        if (status != 'active') {
          _handleAnnouncementCleared(record);
        } else {
          _handleIncomingAnnouncement(record);
        }
      },
    );

    _announcementChannel?.subscribe();
  }

  void _handleIncomingAnnouncement(
    Map<String, dynamic> record, {
    bool shouldAlertUser = false,
  }) {
    final type = (record['type'] ?? '').toString().toLowerCase();
    if (type != 'emergency') return;

    final alertId = record['id']?.toString();
    if (alertId == null) return;
    if (_dismissedAlertIds.contains(alertId)) return;
    if (!mounted) return;

    setState(() {
      _activeEmergency = record;
    });

    if (shouldAlertUser) {
      // Play emergency sound alert
      _soundService.playEmergencySound();
      _showEmergencySnack(record);
      _presentEmergencyDialog(record);
    }
  }

  void _handleAnnouncementCleared(Map<String, dynamic> record) {
    final alertId = record['id']?.toString();
    if (alertId == null) return;

    _dismissedAlertIds.remove(alertId);
    if (!mounted) return;

    if (_activeEmergency != null &&
        (_activeEmergency!['id']?.toString() == alertId)) {
      setState(() {
        _activeEmergency = null;
      });
    }
  }

  void _showEmergencySnack(Map<String, dynamic> announcement) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final title = announcement['title']?.toString() ?? 'Emergency Alert';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFb91c1c),
          content: Text('Emergency alert: $title'),
          action: SnackBarAction(
            label: 'OPEN MAP',
            onPressed: () {
              Navigator.pushNamed(context, '/map');
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  Future<void> _presentEmergencyDialog(
      Map<String, dynamic> announcement) async {
    if (!mounted || _isAlertDialogVisible) return;
    _isAlertDialogVisible = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final title = announcement['title']?.toString() ?? 'Emergency Alert';
        final message = announcement['message']?.toString() ??
            'Follow the official instructions immediately.';
        final priority =
            (announcement['priority'] ?? 'critical').toString().toUpperCase();

        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              Text(
                'Priority: $priority',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Later'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/map');
              },
              icon: const Icon(Icons.map),
              label: const Text('Open Map'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    _isAlertDialogVisible = false;
  }

  void _dismissEmergencyAlert() {
    final alertId = _activeEmergency?['id']?.toString();
    if (alertId != null) {
      _dismissedAlertIds.add(alertId);
    }
    if (!mounted) return;
    setState(() {
      _activeEmergency = null;
    });
  }


  @override
  void dispose() {
    _emergencyPollTimer?.cancel();
    _announcementChannel?.unsubscribe();
    if (_announcementChannel != null) {
      SupabaseService.client.removeChannel(_announcementChannel!);
    }
    _soundService.stopSound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/udrrmo-logo.jpg',
                height: 40,
                width: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Kapiyu',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: _selectedIndex == 2 
            ? const Color(0xFFef4444) 
            : const Color(0xFF3b82f6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildModuleTab(),
          _buildCallTab(),
          _buildNotificationTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  Widget _buildHomeTab() {
    final quickActions = <Widget>[
      _buildActionCard(
        icon: Icons.emergency,
        title: 'Report Emergency',
        color: Colors.red,
        onTap: () {
          Navigator.pushNamed(context, '/emergency-report');
        },
      ),
      _buildActionCard(
        icon: Icons.assignment,
        title: 'My Reports',
        color: Colors.blue,
        onTap: () {
          Navigator.pushNamed(context, '/my-reports');
        },
      ),
      _buildActionCard(
        icon: Icons.menu_book,
        title: 'Learning Modules',
        color: Colors.purple,
        onTap: () {
          setState(() {
            _selectedIndex = 1; // Navigate to Module tab
          });
        },
      ),
      _buildSafetyTipsCard(),
    ];

    if (_isResponder) {
      quickActions.add(_buildResponderDashboardCard());
    }

    final quickActionCount = quickActions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_activeEmergency != null) ...[
            _buildEmergencyBanner(),
            const SizedBox(height: 20),
          ],
          // Safety Notice (citizen synopsis)
          _buildSafetyNoticeCard(),
          const SizedBox(height: 20),
          // Daily Weather Outlook
          _buildWeatherDashboard(),
          const SizedBox(height: 24),
          
          // Quick Actions - Modernized
          Row(
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3b82f6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$quickActionCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3b82f6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.95,
            children: quickActions,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBanner() {
    final alert = _activeEmergency;
    if (alert == null) {
      return const SizedBox.shrink();
    }

    final title = alert['title']?.toString() ?? 'Emergency Alert';
    final message = alert['message']?.toString() ??
        'Proceed to the designated evacuation area immediately.';
    final priority =
        (alert['priority'] ?? 'critical').toString().toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFef4444), Color(0xFFb91c1c)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency Alert',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'PRIORITY: $priority',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFb91c1c),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text(
                    'View Evacuation Map',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _dismissEmergencyAlert,
                tooltip: 'Dismiss alert',
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyNoticeCard() {
    final message = _citizenSynopsisMessage ??
        (_synopsisLoaded ? 'Stay alert and report any real emergency you see.' : 'Loading...');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFeff6ff), Color(0xFFf0f9ff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: const Color(0xFF3b82f6), width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: const Color(0xFF3b82f6), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Safety Notice',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e40af),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Based on recent reports in your area',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.15),
                        color.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyTipsCard() {
    return _buildActionCard(
      icon: Icons.shield,
      title: 'Safety Tips',
      color: Colors.green,
      onTap: () {
        Navigator.pushNamed(context, '/safety-tips');
      },
    );
  }

  Widget _buildResponderDashboardCard() {
    return _buildActionCard(
      icon: Icons.dashboard_customize_rounded,
      title: 'Responder Dashboard',
      color: Colors.orange,
      onTap: () {
        Navigator.pushNamed(context, '/responder-dashboard');
      },
    );
  }

  Widget _buildWeatherDashboard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3b82f6).withOpacity(0.08),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with Live badge and Refresh
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Text(
                        'Weather Overview',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e293b),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _weatherStatus == 'Live'
                                ? Colors.green.shade400
                                : _weatherStatus == 'Error'
                                    ? Colors.red.shade400
                                    : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _weatherStatus,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3b82f6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            onPressed: _loadWeatherData,
                            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3b82f6), size: 20),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            tooltip: 'Refresh',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Last updated: ${_getLastUpdated()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content
          if (_isLoadingWeather)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_weatherData == null)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(
                child: Text(
                  'Weather data unavailable',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
          Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Weather Display
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Side: Temperature & Icon
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Location with icon
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 16,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'LSPU Sta. Cruz Campus',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Time indicator
                            Text(
                              'As of ${_getCurrentTime()}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Large Temperature Display with icon
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getTemperature(),
                                  style: const TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1e293b),
                                    height: 1.0,
                                    letterSpacing: -3,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3b82f6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getWeatherIcon(),
                                    color: const Color(0xFF3b82f6),
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Weather Condition
                            Text(
                              _getWeatherCondition(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Day/Night Temperatures
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.wb_sunny_rounded,
                                    size: 16,
                                    color: Colors.orange.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getDayTemperature(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Container(
                                    width: 1,
                                    height: 14,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(width: 14),
                                  Icon(
                                    Icons.nightlight_round,
                                    size: 16,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getNightTemperature(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Weather Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactMetricCard(
                          icon: Icons.water_drop_rounded,
                          label: 'Rain',
                          value: _getRainChance(),
                          subtitle: _getRainChanceDescription(),
                          color: _getRainChanceColor(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactMetricCard(
                          icon: Icons.air_rounded,
                          label: 'Air Quality',
                          value: _getAirQuality(),
                          subtitle: _getAirQualityStatus(),
                          color: _getAirQualityColor(),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Hourly Forecast Section
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: Color(0xFF3b82f6),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Forecast',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e293b),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 130,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _getHourlyForecast().length,
                      itemBuilder: (context, index) {
                        final forecast = _getHourlyForecast()[index];
                        return _buildHourlyForecastCard(forecast);
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecastCard(Map<String, dynamic> forecast) {
    final rainChance = forecast['rainChance'] ?? 0;
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time
          Text(
            forecast['time'] ?? '--:--',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Temperature
          Text(
            forecast['temp'] ?? '--°',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1e293b),
              height: 1.0,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Weather Icon
          Icon(
            forecast['icon'] ?? Icons.wb_sunny,
            color: const Color(0xFF3b82f6),
            size: 30,
          ),
          const SizedBox(height: 6),
          // Rain Percentage
          Text(
            '$rainChance%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: rainChance > 50 
                  ? Colors.blue.shade700 
                  : Colors.grey.shade600,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getLastUpdated() {
    if (_lastUpdated == null) return 'Loading...';
    final hour24 = _lastUpdated!.hour;
    final amPm = hour24 >= 12 ? 'PM' : 'AM';
    return '${_lastUpdated!.month}/${_lastUpdated!.day}/${_lastUpdated!.year}, ${hour24.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}:${_lastUpdated!.second.toString().padLeft(2, '0')} $amPm';
  }

  String _getTemperature() {
    if (_weatherData == null) return '--°C';
    final main = _weatherData!['main'];
    final temp = main?['temp'] ?? 0;
    return '${temp.round()}°C';
  }

  String _getFeelsLike() {
    if (_weatherData == null) return '--°C';
    final main = _weatherData!['main'];
    final feelsLike = main?['feels_like'] ?? main?['temp'] ?? 0;
    return '${feelsLike.round()}°C';
  }

  Color _getTemperatureStatusColor() {
    final value = double.tryParse(_getTemperature().replaceAll('°C', '')) ?? 0;
    if (value < 25) return Colors.blue;
    if (value < 30) return Colors.green;
    if (value < 35) return Colors.orange;
    return Colors.red;
  }

  double? _getRainChancePercentValue() {
    if (_weatherData == null) return null;

    double clampPercent(num chance) {
      final percent = (chance * 100).toDouble();
      if (percent < 0) return 0;
      if (percent > 100) return 100;
      return percent;
    }

    final dynamic forecastSummary = _weatherData!['forecast_summary'];
    if (forecastSummary is Map) {
      final dynamic maxChance = forecastSummary['next_24h_max_rain_chance'];
      if (maxChance is num) {
        return clampPercent(maxChance);
      }

      final dynamic nextForecast = forecastSummary['next_24h_forecast'];
      if (nextForecast is List) {
        double? highestChance;
        for (final entry in nextForecast) {
          if (entry is Map) {
            final dynamic chance = entry['rain_chance'] ?? entry['pop'];
            if (chance is num) {
              if (highestChance == null || chance > highestChance) {
                highestChance = chance.toDouble();
              }
            }
          }
        }
        if (highestChance != null) {
          return clampPercent(highestChance);
        }
      }
    }

    final dynamic pop = _weatherData!['pop'];
    if (pop is num) {
      return clampPercent(pop);
    }

    return null;
  }

  String _getRainChance() {
    final chance = _getRainChancePercentValue();
    if (chance == null) return '--%';
    return '${chance.round()}%';
  }

  String _getRainChanceDescription() {
    final chance = _getRainChancePercentValue();
    if (chance == null) return 'Unavailable';
    if (chance < 30) return 'Low';
    if (chance < 70) return 'Moderate';
    return 'High';
  }

  Color _getRainChanceColor() {
    final chance = _getRainChancePercentValue();
    if (chance == null) return Colors.grey;
    if (chance < 30) return Colors.green;
    if (chance < 70) return Colors.orange;
    return Colors.red;
  }

  String _getRainVolume() {
    if (_weatherData == null) return '-- mm';
    final forecastSummary = _weatherData!['forecast_summary'];
    final forecastRainfall = forecastSummary?['next_24h_forecast'] != null
        ? (forecastSummary['next_24h_forecast'] as List)
            .map((item) => item['rain_volume'] ?? 0.0)
            .fold(0.0, (max, val) => val > max ? val : max)
        : 0.0;
    final rainfall = _weatherData!['rain']?['1h'] ?? forecastRainfall ?? 0.0;
    return '${rainfall.toStringAsFixed(2)} mm';
  }

  String _getRainVolumeStatus() {
    final value = double.tryParse(_getRainVolume().replaceAll(' mm', '')) ?? 0;
    if (value < 1) return 'Light';
    if (value < 5) return 'Moderate';
    return 'Heavy';
  }

  Color _getRainVolumeColor() {
    final value = double.tryParse(_getRainVolume().replaceAll(' mm', '')) ?? 0;
    if (value < 1) return Colors.green;
    if (value < 5) return Colors.orange;
    return Colors.red;
  }

  String _getAirQuality() {
    return 'GOOD'; // Default as per web version
  }

  String _getAirQualityStatus() {
    return 'Healthy';
  }

  Color _getAirQualityColor() {
    return Colors.green;
  }

  String _getHumidity() {
    if (_weatherData == null) return '--%';
    final main = _weatherData!['main'];
    final humidity = main?['humidity'] ?? 0;
    return '${humidity.round()}%';
  }

  String _getWindSpeed() {
    if (_weatherData == null) return '-- km/h';
    final wind = _weatherData!['wind'];
    final speed = wind?['speed'] ?? 0;
    // Convert m/s to km/h if needed (OpenWeatherMap uses m/s)
    final speedKmh = (speed * 3.6).round();
    return '$speedKmh km/h';
  }

  String _getWindDescription() {
    if (_weatherData == null) return 'CALM';
    final wind = _weatherData!['wind'];
    final speed = wind?['speed'] ?? 0;
    final speedKmh = speed * 3.6;
    if (speedKmh < 10) return 'LIGHT WIND';
    if (speedKmh < 20) return 'MODERATE WIND';
    if (speedKmh < 30) return 'STRONG WIND';
    return 'VERY STRONG WIND';
  }

  String _getWeatherCondition() {
    if (_weatherData == null) return 'Clear sky';
    final weather = _weatherData!['weather'];
    if (weather is List && weather.isNotEmpty) {
      return weather[0]['description'] ?? 'Clear sky';
    }
    return 'Clear sky';
  }

  IconData _getWeatherIcon() {
    if (_weatherData == null) return Icons.wb_sunny;
    final weather = _weatherData!['weather'];
    if (weather is List && weather.isNotEmpty) {
      final main = (weather[0]['main'] ?? '').toString().toLowerCase();
      final description = (weather[0]['description'] ?? '').toString().toLowerCase();
      
      if (main.contains('rain') || description.contains('rain') || description.contains('drizzle')) {
        return Icons.grain;
      } else if (main.contains('cloud') || description.contains('cloud')) {
        if (description.contains('broken') || description.contains('scattered')) {
          return Icons.wb_cloudy;
        }
        return Icons.cloud;
      } else if (main.contains('clear') || description.contains('clear') || description.contains('sun')) {
        return Icons.wb_sunny;
      } else if (main.contains('thunderstorm') || description.contains('thunder')) {
        return Icons.flash_on;
      } else if (main.contains('snow') || description.contains('snow')) {
        return Icons.ac_unit;
      } else if (main.contains('mist') || main.contains('fog') || description.contains('mist') || description.contains('fog')) {
        return Icons.blur_on;
      }
    }
    return Icons.wb_sunny;
  }

  String _getDayTemperature() {
    if (_weatherData == null) return '--°';
    final main = _weatherData!['main'];
    final temp = main?['temp'] ?? 0;
    return '${temp.round()}°';
  }

  String _getNightTemperature() {
    if (_weatherData == null) return '--°';
    final main = _weatherData!['main'];
    final tempMin = main?['temp_min'] ?? main?['temp'] ?? 0;
    return '${tempMin.round()}°';
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $amPm';
  }

  List<Map<String, dynamic>> _getHourlyForecast() {
    if (_weatherData == null) return [];
    
    final forecastSummary = _weatherData!['forecast_summary'];
    if (forecastSummary is Map) {
      final nextForecast = forecastSummary['next_24h_forecast'];
      if (nextForecast is List && nextForecast.isNotEmpty) {
        final now = DateTime.now();
        return nextForecast.take(6).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          // Use API timestamp if available, otherwise generate incremental time
          DateTime dateTime;
          if (item['dt'] != null) {
            dateTime = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
          } else {
            // Generate time in 3-hour intervals
            dateTime = now.add(Duration(hours: index * 3));
          }
          
          final hour = dateTime.hour;
          final amPm = hour >= 12 ? 'PM' : 'AM';
          final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
          final timeStr = '${hour12.toString().padLeft(2, '0')} $amPm';
          
          final temp = item['temp'] ?? item['main']?['temp'] ?? 0;
          final rainChance = item['rain_chance'] ?? item['pop'] ?? 0.0;
          final rainChancePercent = (rainChance * 100).round();
          
          // Determine weather icon based on condition
          final weather = item['weather'] ?? item['weather_main'];
          IconData weatherIcon = Icons.wb_sunny;
          if (weather != null) {
            final weatherStr = weather.toString().toLowerCase();
            if (weatherStr.contains('rain') || weatherStr.contains('drizzle')) {
              weatherIcon = Icons.grain;
            } else if (weatherStr.contains('cloud')) {
              weatherIcon = Icons.cloud;
            } else if (weatherStr.contains('clear') || weatherStr.contains('sun')) {
              weatherIcon = Icons.wb_sunny;
            }
          }
          
          return {
            'time': timeStr,
            'temp': '${temp.round()}°',
            'icon': weatherIcon,
            'rainChance': rainChancePercent,
          };
        }).toList();
      }
    }
    
    // Fallback: Generate mock hourly data
    final now = DateTime.now();
    return List.generate(6, (index) {
      final hour = (now.hour + (index * 3)) % 24;
      final amPm = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return {
        'time': '${hour12.toString().padLeft(2, '0')} $amPm',
        'temp': '${(28 + (index % 3) - 1)}°',
        'icon': index % 2 == 0 ? Icons.cloud : Icons.wb_sunny,
        'rainChance': index % 2 == 0 ? 95 : 0,
      };
    });
  }

  Widget _buildCustomBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: 'Module',
                index: 1,
                isHighlighted: true,
              ),
              _buildCallNavButton(),
              _buildNavItem(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications,
                label: 'Notification',
                index: 3,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    bool isHighlighted = false,
  }) {
    final isSelected = _selectedIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          // Refresh profile when profile tab is selected
          if (index == 4) {
            _loadUserProfile();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: isSelected
              ? BoxDecoration(
                  color: const Color(0xFF3b82f6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? const Color(0xFF3b82f6) : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(height: 1),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF3b82f6) : Colors.grey.shade600,
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallNavButton() {
    final isSelected = _selectedIndex == 2;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = 2;
          });
        },
        child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFef4444),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFef4444).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.call,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(height: 1),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Call',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFef4444) : Colors.grey.shade600,
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildModuleTab() {
    return const LearningModulesScreen();
  }

  Widget _buildNotificationTab() {
    return const NotificationsScreen();
  }

  Widget _buildCallTab() {
    // Get location when call tab is accessed
    if (_selectedIndex == 2 && !_sosLocationReady && !_isGettingSosLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getSosLocation();
      });
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFef4444).withOpacity(0.08),
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Animated pulse effect container
            PulsingCallButton(
              onTap: () => _launchPhoneCall(_primaryEmergencyNumber),
            ),
            const SizedBox(height: 24),
            // SOS Button
            _buildSosButton(),
            const SizedBox(height: 32),
            const Text(
              'Emergency Button',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: Color.fromARGB(255, 211, 0, 0),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFef4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFef4444).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 0, 0),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Available only hours time at lspu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromARGB(255, 201, 19, 19),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            // Section header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 0, 0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Other Emergency Services',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Color(0xFF1e293b),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildModernContactCard(
              'Fire Department',
              '117',
              Icons.local_fire_department_rounded,
              const Color.fromARGB(255, 249, 22, 22),
            ),
            const SizedBox(height: 12),
            _buildModernContactCard(
              'Police Department',
              '117',
              Icons.local_police_rounded,
              const Color(0xFF3b82f6),
            ),
            const SizedBox(height: 12),
            _buildModernContactCard(
              'Medical Team',
              '117',
              Icons.medical_services_rounded,
              const Color(0xFF10b981),
            ),
            const SizedBox(height: 12),
            _buildModernContactCard(
              'UDRRMO',
              _primaryEmergencyNumber,
              Icons.shield_rounded,
              const Color(0xFFef4444),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModernContactCard(String name, String number, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchPhoneCall(number),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            number,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(String name, String number, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchPhoneCall(number),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3b82f6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF3b82f6), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        number,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10b981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.call,
                    color: Color(0xFF10b981),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Profile Header - Modernized
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1e3a8a),
                    Color(0xFF3b82f6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3b82f6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF3b82f6).withOpacity(0.2),
                              const Color(0xFF3b82f6).withOpacity(0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 48,
                          color: Color(0xFF3b82f6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _isLoadingProfile
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _username,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                  const SizedBox(height: 6),
                  _isLoadingProfile
                      ? const SizedBox(height: 20)
                      : Column(
                          children: [
                            Text(
                              _userEmail,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Menu Items
            _buildMenuItem(
              icon: Icons.edit,
              title: 'Edit Profile',
              onTap: () async {
                final result = await Navigator.pushNamed(context, '/edit-profile');
                if (result == true) {
                  // Reload profile after editing
                  _loadUserProfile();
                }
              },
            ),
            _buildMenuItem(
              icon: Icons.assignment,
              title: 'My Reports',
              onTap: () {
                Navigator.pushNamed(context, '/my-reports');
              },
            ),
            _buildMenuItem(
              icon: Icons.shield,
              title: 'Safety Tips',
              onTap: () {
                Navigator.pushNamed(context, '/safety-tips');
              },
            ),
            _buildMenuItem(
              icon: Icons.map,
              title: 'Map & Location',
              onTap: () {
                Navigator.pushNamed(context, '/map');
              },
            ),
            _buildMenuItem(
              icon: Icons.notifications_active,
              title: 'Sync Notifications (OneSignal)',
              color: const Color(0xFF10b981),
              onTap: _syncOneSignalPlayerId,
            ),
            const SizedBox(height: 16),
            _buildMenuItem(
              icon: Icons.logout,
              title: 'Logout',
              color: const Color(0xFFef4444),
              onTap: _showLogoutDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (color ?? const Color(0xFF3b82f6)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color ?? const Color(0xFF3b82f6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color ?? Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Sign out from Supabase
              await SupabaseService.signOut();
              // Clear local storage
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_id');
              await prefs.remove('user_email');
              // Navigate to login (AuthWrapper will handle the rest)
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getSosLocation() async {
    if (_isGettingSosLocation) return;
    
    setState(() {
      _isGettingSosLocation = true;
      _sosLocationReady = false;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled. Please enable them to use SOS.'),
            ),
          );
        }
        setState(() {
          _isGettingSosLocation = false;
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied. SOS requires location access.')),
            );
          }
          setState(() {
            _isGettingSosLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable them in settings to use SOS.'),
            ),
          );
        }
        setState(() {
          _isGettingSosLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _sosPosition = position;
        _sosLocationReady = true;
        _isGettingSosLocation = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
      setState(() {
        _isGettingSosLocation = false;
        _sosLocationReady = false;
      });
    }
  }

  Future<void> _sendSosAlert() async {
    if (!_sosLocationReady || _sosPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for location to be detected before sending SOS.'),
          backgroundColor: Colors.orange,
        ),
      );
      // Try to get location if not ready
      if (!_isGettingSosLocation) {
        await _getSosLocation();
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'SOS Emergency',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'This is a LIFE OR DEATH emergency alert. It will be sent immediately to super users. Are you sure you want to send this SOS?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('SEND SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isGettingSosLocation = true;
    });

    try {
      // Get address from coordinates (optional)
      String? address;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _sosPosition!.latitude,
          _sosPosition!.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          address = _formatAddress(place);
        }
      } catch (e) {
        // If geocoding fails, continue without address
        debugPrint('Geocoding failed: $e');
      }

      // Prepare SOS alert data
      final alertData = {
        'latitude': _sosPosition!.latitude,
        'longitude': _sosPosition!.longitude,
        if (address != null) 'location_address': address,
      };

      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId != null) {
        alertData['user_id'] = currentUserId;
        alertData['reporter_uid'] = currentUserId;
      }

      // Get user name if available
      final userName = _username != 'Kapiyu' ? _username : null;
      if (userName != null) {
        alertData['reporter_name'] = userName;
      }

      // Send to submit-sos-alert edge function
      final response = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/submit-sos-alert'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_supabaseKey',
        },
        body: jsonEncode(alertData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚨 SOS Alert sent! Super users have been notified immediately.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to send SOS alert: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SOS alert: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingSosLocation = false;
        });
      }
    }
  }

  String _formatAddress(Placemark place) {
    List<String> parts = [];
    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      parts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      parts.add(place.country!);
    }
    return parts.join(', ');
  }

  Widget _buildSosButton() {
    return Container(
      width: double.infinity,
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _sosLocationReady
              ? [Colors.red.shade700, Colors.red.shade900]
              : [Colors.grey.shade400, Colors.grey.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_sosLocationReady ? Colors.red : Colors.grey).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _sosLocationReady ? _sendSosAlert : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGettingSosLocation) ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Getting Location...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ] else if (_sosLocationReady) ...[
                  const Icon(
                    Icons.sos,
                    size: 32,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'SOS EMERGENCY',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.location_off,
                    size: 28,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Location Required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About LSPU DRES'),
        content: const Text(
          'LSPU Disaster Risk Reduction and Emergency Response System\n\n'
          'Version 1.0.0\n\n'
          'Stay safe and connected with real-time emergency reporting and response management.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Animated Pulsing Call Button Widget
class PulsingCallButton extends StatefulWidget {
  final VoidCallback onTap;
  
  const PulsingCallButton({super.key, required this.onTap});

  @override
  State<PulsingCallButton> createState() => _PulsingCallButtonState();
}

class _PulsingCallButtonState extends State<PulsingCallButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated pulse rings
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulse ring
                  Container(
                    width: 120 + (_animation.value * 60),
                    height: 120 + (_animation.value * 60),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFef4444).withOpacity(0.4 * (1 - _animation.value)),
                        width: 2,
                      ),
                    ),
                  ),
                  // Middle pulse ring
                  Container(
                    width: 120 + (_animation.value * 30),
                    height: 120 + (_animation.value * 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFef4444).withOpacity(0.5 * (1 - _animation.value)),
                        width: 2,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Static icon (always centered) - Now clickable
          GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFef4444).withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFef4444),
                      Color(0xFFdc2626),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFef4444).withOpacity(0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.call_rounded,
                  size: 72,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

