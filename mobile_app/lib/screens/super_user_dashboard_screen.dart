import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/onesignal_service.dart';
import '../utils/synopsis_helper.dart';
import 'super_user_reports_screen.dart';
import 'super_user_announcements_screen.dart';

class SuperUserDashboardScreen extends StatefulWidget {
  const SuperUserDashboardScreen({super.key});

  @override
  State<SuperUserDashboardScreen> createState() => _SuperUserDashboardScreenState();
}

class _SuperUserDashboardScreenState extends State<SuperUserDashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _isLoadingStats = true;
  bool _isLoadingAlerts = false;
  
  // Stats
  int _totalCitizens = 0;
  int _activeReports = 0;
  int _totalUsers = 0;
  
  // Active alerts
  List<Map<String, dynamic>> _activeAlerts = [];
  
  // Readiness synopsis (prepare / be ready / inspect)
  String? _responderSynopsisMessage;
  
  // Safety Notice (citizen) — editable by admin/super_user
  String? _safetyNoticeMessage;
  bool _safetyNoticeEnabled = true;
  bool _safetyNoticeSaving = false;
  final TextEditingController _safetyNoticeController = TextEditingController();
  
  // User info
  String _userEmail = 'Super User';
  
  // Realtime subscriptions
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _announcementsChannel;
  
  // Use centralized Supabase service
  String get _supabaseUrl => SupabaseService.supabaseUrl;
  String get _supabaseKey => SupabaseService.supabaseAnonKey;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadStats();
    _loadActiveAlerts();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _notificationsChannel?.unsubscribe();
    _announcementsChannel?.unsubscribe();
    _safetyNoticeController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscriptions() {
    // Subscribe to notifications table for super user
    _notificationsChannel = SupabaseService.client
        .channel('super-user-notifications-mobile')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_type',
            value: 'admin',
          ),
          callback: (payload) {
            debugPrint('🔔 New notification received: ${payload.newRecord}');
            _showNotificationSnackbar(payload.newRecord);
            _syncNotifications();
          },
        )
        .subscribe();

    // Subscribe to announcements table
    _announcementsChannel = SupabaseService.client
        .channel('super-user-announcements-mobile')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            debugPrint('📢 Announcement updated: ${payload.newRecord}');
            _loadActiveAlerts();
          },
        )
        .subscribe();

    debugPrint('✅ Realtime subscriptions setup complete');
  }

  Future<void> _syncNotifications() async {
    try {
      final response = await SupabaseService.client.functions.invoke(
        'sync-notifications',
        body: {
          'limit': 20,
          'unreadOnly': false,
        },
      );

      debugPrint('✅ Synced notifications: ${response.data}');
    } catch (e) {
      debugPrint('❌ Failed to sync notifications: $e');
    }
  }

  void _showNotificationSnackbar(Map<String, dynamic> notification) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['title'] ?? 'New Notification',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (notification['message'] != null)
              Text(notification['message']),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _loadUserInfo() async {
    final email = SupabaseService.currentUserEmail;
    if (email != null) {
      setState(() {
        _userEmail = email;
      });
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      // Get all users
      final usersResponse = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/get-users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_supabaseKey',
        },
        body: jsonEncode({}),
      );

      if (usersResponse.statusCode == 200) {
        final usersData = jsonDecode(usersResponse.body);
        final users = usersData['users'] as List? ?? [];
        final totalUsers = users.length;
        final citizens = users.where((u) {
          final role = (u['role'] ?? u['user_metadata']?['role'] ?? 'citizen').toString().toLowerCase();
          return role == 'citizen';
        }).length;

        setState(() {
          _totalUsers = totalUsers;
          _totalCitizens = citizens;
        });
      }

      // Get active reports
      final reportsResponse = await SupabaseService.client
          .from('reports')
          .select('id, status')
          .neq('status', 'resolved')
          .neq('status', 'closed');

      if (reportsResponse != null) {
        final reports = reportsResponse as List;
        setState(() {
          _activeReports = reports.length;
        });
      }

      // Load readiness synopsis (prepare / be ready / inspect)
      try {
        final synopsisReports = await SupabaseService.getReportsForSynopsis();
        final synopsis = SynopsisHelper.getSynopsisForRole(synopsisReports, 'super_user');
        if (mounted) {
          setState(() => _responderSynopsisMessage = synopsis['responderMessage']);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _responderSynopsisMessage = 'Keep equipment inspected and stay ready for anything.');
        }
      }
      // Load safety notice (citizen) for editing
      try {
        final notice = await SupabaseService.getSafetyNotice();
        if (mounted && notice != null) {
          setState(() {
            _safetyNoticeEnabled = notice['enabled'] == true;
            _safetyNoticeMessage = notice['message']?.toString();
            _safetyNoticeController.text = _safetyNoticeMessage ?? '';
          });
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _sendQuickAlert(String templateKey) async {
    final templates = {
      'fire': {
        'title': 'Fire Emergency Alert',
        'message': '🔥 FIRE EMERGENCY: A fire-related hazard has been reported on campus. Stay calm, move away from the affected area, and follow instructions from emergency personnel and campus authorities.',
        'type': 'emergency',
        'priority': 'critical',
      },
      'earthquake': {
        'title': 'Earthquake Safety Alert',
        'message': '⚠️ EARTHQUAKE ALERT: If you feel strong shaking, DROP, COVER, and HOLD ON. After the shaking stops, move calmly to an open, safe area and wait for instructions from authorities.',
        'type': 'emergency',
        'priority': 'critical',
      },
    };

    final template = templates[templateKey];
    if (template == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Alert'),
        content: Text('Send "${template['title']}" to all users?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = SupabaseService.currentUser;
      
      final announcementPayload = {
        'title': template['title'],
        'message': template['message'],
        'type': template['type'],
        'priority': template['priority'],
        'target_audience': 'all',
        'status': 'active',
        if (currentUser?.id != null) 'created_by': currentUser!.id,
      };

      final response = await SupabaseService.client
          .from('announcements')
          .insert([announcementPayload])
          .select()
          .single();

      // Send push notifications to all users
      try {
        await SupabaseService.client.functions.invoke(
          'announcement-notify',
          body: {'announcementId': response['id']},
        );
        debugPrint('✅ Push notifications sent for announcement: ${response['id']}');
      } catch (notifyError) {
        debugPrint('⚠️ Failed to send push notifications: $notifyError');
        // Don't fail the whole operation if notifications fail
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Alert sent to all users!'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadStats();
      await _loadActiveAlerts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadActiveAlerts() async {
    setState(() {
      _isLoadingAlerts = true;
    });

    try {
      final response = await SupabaseService.client
          .from('announcements')
          .select('*')
          .order('created_at', ascending: false)
          .limit(20);

      if (response != null) {
        final allAlerts = response as List;
        final critical = allAlerts.where((a) {
          final type = (a['type'] ?? '').toString().toLowerCase();
          final priority = (a['priority'] ?? '').toString().toLowerCase();
          return type == 'emergency' || priority == 'critical';
        }).toList();

        if (mounted) {
          setState(() {
            _activeAlerts = List<Map<String, dynamic>>.from(critical);
            _isLoadingAlerts = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading active alerts: $e');
      if (mounted) {
        setState(() {
          _isLoadingAlerts = false;
        });
      }
    }
  }

  Future<void> _resolveAlert(String alertId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Alert'),
        content: const Text('Mark this alert as resolved for all users?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.client
          .from('announcements')
          .update({'status': 'inactive'})
          .eq('id', alertId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert marked as resolved'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadActiveAlerts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resolve alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getAnnouncementIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'emergency':
        return '🚨';
      case 'weather':
        return '🌤️';
      case 'general':
        return '📢';
      case 'maintenance':
        return '🔧';
      case 'safety':
        return '🛡️';
      default:
        return '📢';
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
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
      debugPrint('❌ Error syncing OneSignal Player ID: $e');
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
              await SupabaseService.signOut();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
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
              'Super User',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF3b82f6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardTab(),
          _buildReportsTab(),
          _buildQuickAlertsTab(),
          _buildAnnouncementsTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1e293b),
                    Color(0xFF0f172a),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shield,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Super User Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3b82f6), Color(0xFF2563eb)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Premium Access',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 20),
                  Text(
                    'Logged in as',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userEmail,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Grid
            if (_isLoadingStats)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
                children: [
                  _buildStatCard(
                    title: 'Total Citizens',
                    value: _totalCitizens.toString(),
                    icon: Icons.people,
                    color: const Color(0xFF3b82f6),
                  ),
                  _buildStatCard(
                    title: 'Active Reports',
                    value: _activeReports.toString(),
                    icon: Icons.assignment,
                    color: const Color(0xFFef4444),
                  ),
                  _buildStatCard(
                    title: 'Total Users',
                    value: _totalUsers.toString(),
                    icon: Icons.person,
                    color: const Color(0xFF10b981),
                  ),
                  _buildStatCard(
                    title: 'System Status',
                    value: 'Online',
                    icon: Icons.check_circle,
                    color: const Color(0xFF10b981),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            _buildSafetyNoticeAdminCard(),
            const SizedBox(height: 24),
            _buildReadinessNoticeCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyNoticeAdminCard() {
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
                'Safety Notice (Citizen)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e40af),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Turn off or edit below. This is what citizens see on Home—when disabled, the notice is hidden for everyone.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Show safety notice to citizens', style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
              const Spacer(),
              Switch(
                value: _safetyNoticeEnabled,
                onChanged: (v) => setState(() => _safetyNoticeEnabled = v),
                activeColor: const Color(0xFF3b82f6),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _safetyNoticeController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Leave empty to use auto-generated message from recent reports.',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _safetyNoticeSaving ? null : _saveSafetyNotice,
              icon: _safetyNoticeSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save, size: 20),
              label: Text(_safetyNoticeSaving ? 'Saving...' : 'Save Safety Notice'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSafetyNotice() async {
    setState(() => _safetyNoticeSaving = true);
    try {
      await SupabaseService.updateSafetyNotice(
        message: _safetyNoticeController.text.trim().isEmpty ? null : _safetyNoticeController.text.trim(),
        enabled: _safetyNoticeEnabled,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safety notice saved.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _safetyNoticeSaving = false);
    }
  }

  Widget _buildReadinessNoticeCard() {
    final message = _responderSynopsisMessage ??
        'Keep equipment inspected and stay ready for anything.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFf0fdf4), Color(0xFFecfdf5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: const Color(0xFF059669), width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: const Color(0xFF059669), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Readiness Notice',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Based on recent system reports (last 30 days)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

  Widget _buildReportsTab() {
    return const SuperUserReportsScreen();
  }

  Widget _buildAnnouncementsTab() {
    return const SuperUserAnnouncementsScreen();
  }

  Widget _buildQuickAlertsTab() {
    return RefreshIndicator(
      onRefresh: _loadActiveAlerts,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFf59e0b).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bolt,
                          color: Color(0xFFf59e0b),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Quick One-Tap Alerts',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1e293b),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Send predefined emergency alerts to all users with a single tap.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Alert Buttons
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Column(
                children: [
                  _buildAlertButton(
                    icon: Icons.local_fire_department,
                    title: 'Fire Emergency Alert',
                    subtitle: 'Send fire emergency alert to all users',
                    color: const Color(0xFFef4444),
                    onTap: () => _sendQuickAlert('fire'),
                  ),
                  const SizedBox(height: 16),
                  _buildAlertButton(
                    icon: Icons.warning,
                    title: 'Earthquake Safety Alert',
                    subtitle: 'Send earthquake safety alert to all users',
                    color: const Color(0xFFf97316),
                    onTap: () => _sendQuickAlert('earthquake'),
                  ),
                ],
              ),

            // Active Critical Alerts Section
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.timeline,
                        color: Color(0xFFef4444),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Active Critical Alerts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e293b),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: _isLoadingAlerts
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 20),
                        onPressed: _isLoadingAlerts ? null : _loadActiveAlerts,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingAlerts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_activeAlerts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No critical alerts at this time.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    ..._activeAlerts.map((alert) => _buildActiveAlertCard(alert)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlertCard(Map<String, dynamic> alert) {
    final alertId = alert['id']?.toString() ?? '';
    final title = alert['title']?.toString() ?? 'Untitled Alert';
    final type = alert['type']?.toString() ?? '';
    final status = (alert['status']?.toString() ?? 'active').toLowerCase();
    final createdAt = alert['created_at']?.toString();
    final isActive = status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFef4444).withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFFef4444).withOpacity(0.2) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFef4444).withOpacity(0.1) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getAnnouncementIcon(type),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Started: ${_formatDateTime(createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (!isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status == 'expired' ? 'EXPIRED' : 'RESOLVED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Action Button
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilledButton(
                onPressed: () => _resolveAlert(alertId),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16a34a),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text(
                  'Resolve',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Profile Header
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
                        Icons.shield,
                        size: 48,
                        color: Color(0xFF3b82f6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Super User',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Premium Access',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Menu Items
          _buildMenuItem(
            icon: Icons.map,
            title: 'Map View',
            color: Colors.green,
            onTap: () {
              Navigator.pushNamed(context, '/super-user-map');
            },
          ),
          _buildMenuItem(
            icon: Icons.warning,
            title: 'SOS Alerts',
            color: const Color(0xFFef4444),
            onTap: () {
              Navigator.pushNamed(context, '/super-user-sos-alerts');
            },
          ),
          _buildMenuItem(
            icon: Icons.warning_amber,
            title: 'Early Warning',
            color: Colors.orange,
            onTap: () {
              Navigator.pushNamed(context, '/super-user-early-warning');
            },
          ),
          const SizedBox(height: 16),
          _buildMenuItem(
            icon: Icons.refresh,
            title: 'Refresh Stats',
            onTap: _loadStats,
          ),
          _buildMenuItem(
            icon: Icons.notifications_active,
            title: 'Sync Notifications (OneSignal)',
            color: const Color(0xFF10b981),
            onTap: _syncOneSignalPlayerId,
          ),
          _buildMenuItem(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon')),
              );
            },
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
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade900,
              fontSize: 24,
              fontWeight: FontWeight.bold,
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
            child: Row(
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
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                color.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.send,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Dashboard',
                index: 0,
                isEmergency: false,
              ),
              _buildNavItem(
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment,
                label: 'Reports',
                index: 1,
                isEmergency: false,
              ),
              _buildNavItem(
                icon: Icons.bolt_outlined,
                activeIcon: Icons.bolt,
                label: 'Alerts',
                index: 2,
                isEmergency: true,
              ),
              _buildNavItem(
                icon: Icons.campaign_outlined,
                activeIcon: Icons.campaign,
                label: 'Announcements',
                index: 3,
                isEmergency: false,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 4,
                isEmergency: false,
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
    required bool isEmergency,
  }) {
    final isSelected = _selectedIndex == index;
    final emergencyColor = const Color(0xFFef4444);
    final normalColor = const Color(0xFF3b82f6);
    
    // Special handling for emergency Alerts tab - make it like the Call button
    if (isEmergency) {
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedIndex = index;
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
                  color: emergencyColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: emergencyColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: Colors.white,
                  size: 20,
                ),
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
                      color: isSelected ? emergencyColor : Colors.grey.shade600,
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
    
    // Regular nav items
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: isSelected
              ? BoxDecoration(
                  color: normalColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? normalColor : Colors.grey.shade600,
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
                      color: isSelected ? normalColor : Colors.grey.shade600,
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
}

