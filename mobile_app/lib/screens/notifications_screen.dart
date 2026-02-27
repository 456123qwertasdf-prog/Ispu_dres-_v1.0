import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../services/supabase_service.dart';
import 'notification_details_screen.dart';
import 'report_detail_loader_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  List<NotificationModel> _allNotifications = [];
  bool _isLoading = true;
  // Use centralized Supabase service
  String get _supabaseUrl => SupabaseService.supabaseUrl;
  String get _supabaseKey => SupabaseService.supabaseAnonKey;

  // Filter states
  String _readFilter = 'All'; // All, Read, Unread

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _applyFilters() {
    setState(() {
      _notifications = _allNotifications.where((notification) {
        // Apply read filter
        if (_readFilter == 'Read' && !notification.read) return false;
        if (_readFilter == 'Unread' && notification.read) return false;

        return true;
      }).toList();
    });
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First sync announcements from Supabase
      await _syncAnnouncements();
      
      // Then load notifications from local storage
      await _loadNotificationsFromStorage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncAnnouncements() async {
    try {
      // For anonymous access, use only apikey header (not Authorization)
      // Supabase REST API expects apikey for anon role
      final url = Uri.parse('$_supabaseUrl/rest/v1/announcements')
          .replace(queryParameters: {
        'select': '*',
        'status': 'eq.active',
        'order': 'created_at.desc',
      });

      print('Fetching announcements from: $url');
      
      final response = await http.get(
        url,
        headers: {
          'apikey': _supabaseKey,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
      );

      print('Announcements API Response Status: ${response.statusCode}');
      print('Announcements API Response Headers: ${response.headers}');
      
      if (response.statusCode != 200) {
        print('Announcements API Error Response Body: ${response.body}');
      } else {
        print('Announcements API Success - Response length: ${response.body.length}');
      }

      if (response.statusCode == 200) {
        final responseBody = response.body.trim();
        
        if (responseBody.isEmpty || responseBody == '[]' || responseBody == 'null') {
          print('No announcements found (empty response)');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No active announcements found'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          
          // Still load existing notifications from storage
          await _loadNotificationsFromStorage();
          return;
        }

        dynamic decodedResponse;
        try {
          decodedResponse = jsonDecode(responseBody);
        } catch (e) {
          print('Error decoding JSON: $e');
          print('Response body: $responseBody');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error parsing announcements: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final List<dynamic> announcements;
        if (decodedResponse is List) {
          announcements = decodedResponse;
        } else if (decodedResponse is Map && decodedResponse.containsKey('data')) {
          announcements = decodedResponse['data'] as List;
        } else {
          print('Unexpected response format: $decodedResponse');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unexpected response format from server'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        print('Found ${announcements.length} active announcements');
        
        if (announcements.isEmpty) {
          print('No announcements returned from API');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No active announcements available'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          // Still load existing notifications from storage
          await _loadNotificationsFromStorage();
          return;
        }
        
        // Load existing notifications
        final prefs = await SharedPreferences.getInstance();
        final existingNotificationsJson = prefs.getStringList('emergency_notifications') ?? [];
        final existingNotifications = existingNotificationsJson
            .map((json) => NotificationModel.fromJson(jsonDecode(json)))
            .toList();

        final existingAnnouncementIds = existingNotifications
            .where((n) => n.announcementId != null)
            .map((n) => n.announcementId!)
            .toSet();

        // Convert announcements to notifications
        final List<NotificationModel> newNotifications = [];
        for (var announcement in announcements) {
          try {
            print('Processing announcement: ${announcement['id']}');
            final announcementId = announcement['id'].toString();
            
            // Check if announcement already exists
            if (existingAnnouncementIds.contains(announcementId)) {
              print('Announcement $announcementId already exists, skipping');
              continue;
            }

            // Check expiration
            if (announcement['expires_at'] != null && announcement['expires_at'].toString().isNotEmpty) {
              final expiresAt = DateTime.parse(announcement['expires_at']);
              if (DateTime.now().isAfter(expiresAt)) {
                print('Announcement $announcementId expired, skipping');
                continue;
              }
            }

            final announcementType = announcement['type']?.toString() ?? 'general';
            final notificationType = _getAnnouncementNotificationType(announcementType);
            final announcementTitle = announcement['title']?.toString() ?? 'Announcement';
            final notificationTitle = '${_getAnnouncementIcon(announcementType)} $announcementTitle';
            
            // For emergency announcements, include report ID if available
            String message = announcement['message']?.toString() ?? '';
            
            // Always show the full message for now, but handle FIRE reports specially
            if (announcementType == 'emergency' && (message.toUpperCase().contains('FIRE') || message.toUpperCase().contains('EMERGENCY'))) {
              // Try to extract report ID if present
              final reportIdMatch = RegExp(r'Report ID:?\s*([a-f0-9-]+)', caseSensitive: false).firstMatch(message);
              if (reportIdMatch != null) {
                final reportId = reportIdMatch.group(1) ?? '';
                if (reportId.length > 8) {
                  message = 'New emergency report requires attention.\nReport ID: ${reportId.substring(0, 8)}...';
                } else {
                  message = 'New emergency report requires attention.\nReport ID: $reportId';
                }
              } else if (!message.contains('Report ID')) {
                // If no report ID found but it's an emergency, use default message
                message = message.isNotEmpty ? message : 'New emergency report requires attention.';
              }
            }

            final createdAt = announcement['created_at']?.toString() ?? DateTime.now().toIso8601String();

            final notification = NotificationModel(
              id: 'announcement_$announcementId',
              title: notificationTitle,
              message: message,
              type: notificationType,
              icon: _getNotificationIcon(notificationType),
              timestamp: DateTime.parse(createdAt),
              read: false,
              announcementId: announcementId,
            );

            newNotifications.add(notification);
            print('✅ Added notification for announcement $announcementId: $notificationTitle');
          } catch (e, stackTrace) {
            print('❌ Error processing announcement: $e');
            print('Stack trace: $stackTrace');
            print('Announcement data: $announcement');
          }
        }

        print('📊 Created ${newNotifications.length} new notifications from ${announcements.length} announcements');
        print('📊 Existing notifications: ${existingNotifications.length}');

        // Merge with existing notifications
        final allNotifications = [...newNotifications, ...existingNotifications];
        
        // Sort by timestamp (newest first)
        allNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        // Keep only last 50
        final notificationsToSave = allNotifications.take(50).toList();
        
        print('📊 Total notifications after merge: ${notificationsToSave.length}');
        
        // Save to storage
        final prefsSave = await SharedPreferences.getInstance();
        final notificationsJson = notificationsToSave
            .map((n) => jsonEncode(n.toJson()))
            .toList();
        await prefsSave.setStringList('emergency_notifications', notificationsJson);
        
        setState(() {
          _allNotifications = notificationsToSave;
          _notifications = notificationsToSave;
        });
        _applyFilters();
        
        print('✅ Notifications saved and displayed: ${_notifications.length}');
        
        if (mounted) {
          if (newNotifications.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${newNotifications.length} new notification${newNotifications.length > 1 ? 's' : ''} synced'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All announcements are up to date'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        print('Failed to fetch announcements. Status: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sync announcements: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error syncing announcements: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAndResync() async {
    try {
      // Clear all stored notifications
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('emergency_notifications');
      
      setState(() {
        _notifications = [];
      });
      
      // Now sync fresh from server
      await _loadNotifications();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared and resynced'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error clearing and resyncing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadNotificationsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('emergency_notifications') ?? [];
      
      if (notificationsJson.isEmpty) {
        print('No stored notifications found');
        return;
      }
      
      final notifications = notificationsJson
          .map((json) {
            try {
              return NotificationModel.fromJson(jsonDecode(json));
            } catch (e) {
              print('Error parsing notification JSON: $e');
              print('JSON: $json');
              return null;
            }
          })
          .where((n) => n != null)
          .cast<NotificationModel>()
          .toList();
      
      // Sort by timestamp (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('Loaded ${notifications.length} notifications from storage');
      
      setState(() {
        _allNotifications = notifications;
        _notifications = notifications;
      });
      _applyFilters();
    } catch (e) {
      print('Error loading notifications from storage: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    setState(() {
      final allIndex = _allNotifications.indexWhere((n) => n.id == notificationId);
      if (allIndex != -1) {
        _allNotifications[allIndex].read = true;
      }
    });

    await _saveNotifications();
    _applyFilters();
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var notification in _allNotifications) {
        notification.read = true;
      }
    });

    await _saveNotifications();
    _applyFilters();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = _allNotifications
          .map((n) => jsonEncode(n.toJson()))
          .toList();
      await prefs.setStringList('emergency_notifications', notificationsJson);
    } catch (e) {
      print('Error saving notifications: $e');
    }
  }

  String _getAnnouncementNotificationType(String type) {
    switch (type) {
      case 'emergency':
        return 'emergency';
      case 'weather':
        return 'warning';
      case 'maintenance':
        return 'warning';
      case 'safety':
        return 'info';
      default:
        return 'info';
    }
  }

  String _getAnnouncementIcon(String type) {
    switch (type) {
      case 'emergency':
        return '';
      case 'weather':
        return '';
      case 'general':
        return '';
      case 'maintenance':
        return '';
      case 'safety':
        return '';
      default:
        return '';
    }
  }

  String _getNotificationIcon(String type) {
    switch (type) {
      case 'emergency':
        return 'error';
      case 'warning':
        return 'warning';
      case 'info':
        return 'info';
      case 'success':
        return 'success';
      default:
        return 'info';
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'emergency':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      case 'success':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIconData(String icon) {
    switch (icon) {
      case 'error':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}, ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')} ${timestamp.hour >= 12 ? 'PM' : 'AM'}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  int get _unreadCount => _allNotifications.where((n) => !n.read).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1e293b),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3b82f6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              onPressed: _markAllAsRead,
              tooltip: 'Mark All Read',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF3b82f6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading notifications...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Notifications',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'re all caught up! Check back later for updates.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _loadNotifications,
                          icon: const Icon(Icons.sync_rounded, size: 20),
                          label: const Text('Sync Announcements'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3b82f6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _clearAndResync,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Clear All & Resync'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange.shade600,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: const Color(0xFF3b82f6),
                  child: CustomScrollView(
                    slivers: [
                      // Read status filter row
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildFilterChip(
                                  label: 'All',
                                  isSelected: _readFilter == 'All',
                                  onTap: () {
                                    _readFilter = 'All';
                                    _applyFilters();
                                  },
                                  color: const Color(0xFFFF9800),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildFilterChip(
                                  label: 'Read',
                                  isSelected: _readFilter == 'Read',
                                  onTap: () {
                                    _readFilter = 'Read';
                                    _applyFilters();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildFilterChip(
                                  label: 'Unread',
                                  isSelected: _readFilter == 'Unread',
                                  onTap: () {
                                    _readFilter = 'Unread';
                                    _applyFilters();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 8),
                      ),
                      // Notifications list
                      _notifications.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      size: 64,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No notifications found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your filters',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final notification = _notifications[index];
                                    final color = _getNotificationColor(notification.type);
                                    
                                    return _buildModernNotificationCard(
                                      notification,
                                      color,
                                    );
                                  },
                                  childCount: _notifications.length,
                                ),
                              ),
                            ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 20),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildModernNotificationCard(
    NotificationModel notification,
    Color color,
  ) {
    final isUnread = !notification.read;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? color.withOpacity(0.3) : Colors.grey.shade200,
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnread
                ? color.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Mark as read when viewed
            _markAsRead(notification.id);
            // Navigate to report details or notification/announcement details
            if (notification.reportId != null && notification.reportId!.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportDetailLoaderScreen(reportId: notification.reportId!),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationDetailsScreen(
                    notification: notification,
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with gradient background
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getNotificationIconData(notification.icon),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: Colors.grey.shade900,
                                height: 1.3,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3b82f6),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3b82f6).withOpacity(0.4),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatTimestamp(notification.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notification.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: color,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? (color ?? const Color(0xFFFF9800))
              : Colors.grey.shade100,
          border: isSelected
              ? null
              : Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) ...[
              const Icon(
                Icons.check,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF1e293b),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

