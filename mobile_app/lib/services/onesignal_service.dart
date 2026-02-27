import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import 'notification_sound_service.dart';

/// Service to handle OneSignal push notifications
class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  static const String _onesignalAppId = '8d6aa625-a650-47ac-b9ba-00a247840952';
  String? _playerId;
  
  // Callbacks for notification taps
  Function(String reportId, String? assignmentId)? _onAssignmentNotificationTap;
  Function(String announcementId)? _onEmergencyNotificationTap;
  Function(String reportId)? _onReportUpdateNotificationTap;
  Function(String reportId)? _onCriticalReportNotificationTap;
  
  /// Set callback for assignment notification taps (RESPONDER)
  void setOnAssignmentNotificationTap(Function(String reportId, String? assignmentId) callback) {
    _onAssignmentNotificationTap = callback;
  }
  
  /// Set callback for emergency notification taps (ALL USERS)
  void setOnEmergencyNotificationTap(Function(String announcementId) callback) {
    _onEmergencyNotificationTap = callback;
  }
  
  /// Set callback for report update notification taps (CITIZEN - their own reports)
  void setOnReportUpdateNotificationTap(Function(String reportId) callback) {
    _onReportUpdateNotificationTap = callback;
  }
  
  /// Set callback for critical report notification taps (SUPER USER)
  void setOnCriticalReportNotificationTap(Function(String reportId) callback) {
    _onCriticalReportNotificationTap = callback;
  }

  /// Initialize OneSignal SDK
  Future<void> initialize() async {
    try {
      // Initialize notification sound service
      await NotificationSoundService().initialize();
      
      // Set app ID
      OneSignal.initialize(_onesignalAppId);

      // Request permission for notifications
      final permissionGranted = await OneSignal.Notifications.requestPermission(true);
      
      if (permissionGranted) {
        debugPrint('✅ OneSignal notification permission granted');
      } else {
        debugPrint('❌ OneSignal notification permission denied');
        return;
      }

      // Listen for subscription changes FIRST (before checking current state)
      // This ensures we catch the subscription ID when it becomes available
      OneSignal.User.pushSubscription.addObserver((state) {
        final newPlayerId = state.current.id;
        if (newPlayerId != null && newPlayerId.isNotEmpty) {
          if (newPlayerId != _playerId) {
          _playerId = newPlayerId;
          debugPrint('OneSignal Player ID updated: $_playerId');
          _savePlayerIdToSupabase(newPlayerId);
        }
        } else {
          debugPrint('⚠️ OneSignal subscription ID not available yet');
        }
      });

      // Get the current subscription ID (may be null initially)
      final subscription = OneSignal.User.pushSubscription;
      _playerId = subscription.id;
      
      if (_playerId != null && _playerId!.isNotEmpty) {
        debugPrint('OneSignal Player ID (initial): $_playerId');
        // Save player ID to Supabase
        await _savePlayerIdToSupabase(_playerId!);
      } else {
        debugPrint('⚠️ OneSignal subscription ID not ready yet, will save when available');
        // Wait a bit for subscription to be ready (max 5 seconds)
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          final currentId = OneSignal.User.pushSubscription.id;
          if (currentId != null && currentId.isNotEmpty) {
            _playerId = currentId;
            debugPrint('OneSignal Player ID (after wait): $_playerId');
            await _savePlayerIdToSupabase(_playerId!);
            break;
          }
        }
      }

      // Delayed retry so new users / restored sessions get registered (subscription can arrive late)
      Future.delayed(const Duration(seconds: 4), () => retrySavePlayerIdToSupabase());

      // Handle notification received (when app is in foreground or background)
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('OneSignal notification clicked: ${event.notification.body}');
        // Handle notification tap - you can navigate to appropriate screen here
        _handleNotificationTap(event);
        // Also play sound when notification is clicked (for foreground notifications)
        _handleNotificationReceived(event);
      });

    } catch (e) {
      debugPrint('Error initializing OneSignal: $e');
    }
  }

  /// Save player ID to Supabase
  Future<void> _savePlayerIdToSupabase(String playerId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        debugPrint('⚠️ Cannot save OneSignal Player ID: User not authenticated');
        return;
      }

      if (playerId.isEmpty) {
        debugPrint('⚠️ Cannot save OneSignal Player ID: Player ID is empty');
        return;
      }

      debugPrint('💾 Saving OneSignal Player ID to Supabase: $playerId for user: $userId');

      // Save to onesignal_subscriptions table (supports multiple devices per user)
      final response = await SupabaseService.client
          .from('onesignal_subscriptions')
          .upsert({
            'user_id': userId,
            'player_id': playerId,
            'platform': 'android',
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id,player_id')
          .select();
      
      if (response != null && response.isNotEmpty) {
        debugPrint('✅ OneSignal Player ID saved to Supabase: $playerId');
      } else {
        debugPrint('⚠️ OneSignal Player ID save returned null/empty response');
      }
    } catch (e) {
      debugPrint('❌ Error saving OneSignal Player ID: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(OSNotificationClickEvent event) {
    try {
      final data = event.notification.additionalData;
      if (data != null) {
        final type = data['type'] as String?;
        
        // Handle assignment notifications (RESPONDER)
        if (type == 'assignment') {
          final reportId = data['report_id'] as String?;
          final assignmentId = data['assignment_id'] as String?;
          
          if (reportId != null) {
            debugPrint('📱 Assignment notification tapped - Report ID: $reportId');
            if (_onAssignmentNotificationTap != null) {
              _onAssignmentNotificationTap!(reportId, assignmentId);
            }
          }
        }
        // Handle emergency announcements (ALL USERS)
        else if (type == 'emergency' || type == 'announcement') {
          final announcementId = data['announcement_id'] as String?;
          if (announcementId != null) {
            debugPrint('📱 Emergency notification tapped: $announcementId');
            if (_onEmergencyNotificationTap != null) {
              _onEmergencyNotificationTap!(announcementId);
            }
          }
        }
        // Handle report status updates (CITIZEN - their own reports)
        else if (type == 'report_update' || type == 'report_status') {
          final reportId = data['report_id'] as String?;
          if (reportId != null) {
            debugPrint('📱 Report update notification tapped - Report ID: $reportId');
            if (_onReportUpdateNotificationTap != null) {
              _onReportUpdateNotificationTap!(reportId);
            }
          }
        }
        // Handle assignment status updates (CITIZEN - e.g. "Responder is on the way")
        else if (type == 'assignment_status_update') {
          final reportId = data['reportId'] as String? ?? data['report_id'] as String?;
          if (reportId != null) {
            debugPrint('📱 Assignment status update notification tapped (citizen) - Report ID: $reportId');
            if (_onReportUpdateNotificationTap != null) {
              _onReportUpdateNotificationTap!(reportId);
            }
          }
        }
        // Handle critical report notifications (SUPER USER)
        else if (type == 'critical_report' || type == 'high_priority_report') {
          final reportId = data['report_id'] as String?;
          if (reportId != null) {
            debugPrint('📱 Critical report notification tapped - Report ID: $reportId');
            if (_onCriticalReportNotificationTap != null) {
              _onCriticalReportNotificationTap!(reportId);
            }
          }
        }
        // Handle assignment status update for superuser (e.g. "Help is on the Way")
        else if (type == 'assignment_status_update_superuser') {
          final reportId = data['reportId'] as String? ?? data['report_id'] as String?;
          if (reportId != null && _onCriticalReportNotificationTap != null) {
            debugPrint('📱 Superuser status update notification tapped - Report ID: $reportId');
            _onCriticalReportNotificationTap!(reportId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  /// Handle notification received (play custom sound if enabled)
  void _handleNotificationReceived(OSNotificationClickEvent event) {
    try {
      final data = event.notification.additionalData;
      if (data != null) {
        final type = data['type'] as String?;
        
        // Play custom sound for emergency notifications
        if (type == 'emergency') {
          final soundService = NotificationSoundService();
          soundService.playEmergencySound();
        }
      }
    } catch (e) {
      debugPrint('Error handling notification received: $e');
    }
  }

  /// Get current player ID
  String? get playerId => _playerId;

  /// Retry saving player ID to Supabase (call this after login).
  /// Polls for subscription ID a few times so new users get registered even if SDK was slow.
  Future<void> retrySavePlayerIdToSupabase() async {
    if (_playerId != null && _playerId!.isNotEmpty) {
      debugPrint('🔄 Retrying to save OneSignal Player ID after login...');
      await _savePlayerIdToSupabase(_playerId!);
      return;
    }
    // Subscription ID may not be ready yet; poll a few times (new responders often miss otherwise)
    for (int i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: i * 400));
      final currentId = OneSignal.User.pushSubscription.id;
      if (currentId != null && currentId.isNotEmpty) {
        _playerId = currentId;
        debugPrint('🔄 OneSignal Player ID available after retry, saving: $_playerId');
        await _savePlayerIdToSupabase(_playerId!);
        return;
      }
    }
    debugPrint('⚠️ OneSignal Player ID still not available after retries (will save when observer fires)');
  }

  /// Send tags to OneSignal (for user segmentation)
  Future<void> setTag(String key, String value) async {
    try {
      await OneSignal.User.addTags({key: value});
      debugPrint('OneSignal tag set: $key = $value');
    } catch (e) {
      debugPrint('Error setting OneSignal tag: $e');
    }
  }

  /// Set user email (for targeting)
  Future<void> setEmail(String email) async {
    try {
      await OneSignal.User.addEmail(email);
      debugPrint('OneSignal email set: $email');
    } catch (e) {
      debugPrint('Error setting OneSignal email: $e');
    }
  }
}
