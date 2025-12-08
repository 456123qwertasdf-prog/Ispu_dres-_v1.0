import 'dart:async';
import 'package:flutter/material.dart';
import 'connectivity_service.dart';
import 'report_sync_service.dart';
import 'offline_report_service.dart';

/// Global service that automatically syncs offline reports when connection is restored
/// This runs app-wide and doesn't require any specific screen to be open
class AutoSyncService {
  static final AutoSyncService _instance = AutoSyncService._internal();
  factory AutoSyncService() => _instance;
  AutoSyncService._internal();

  final ConnectivityService _connectivityService = ConnectivityService();
  final ReportSyncService _syncService = ReportSyncService();
  final OfflineReportService _offlineService = OfflineReportService();
  
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize the auto-sync service - call this once in main.dart
  void initialize({GlobalKey<NavigatorState>? navigatorKey}) {
    if (_isInitialized) {
      print('⚠️ AutoSyncService already initialized');
      return;
    }

    _navigatorKey = navigatorKey;
    _isInitialized = true;
    print('🚀 AutoSyncService initialized - monitoring connectivity');

    // Start listening to connectivity changes
    _connectivitySubscription = _connectivityService.onConnectivityChanged.listen(
      (isConnected) async {
        print('🌐 Connectivity changed: ${isConnected ? "ONLINE" : "OFFLINE"}');
        if (isConnected) {
          await _autoSyncOfflineReports();
        }
      },
    );

    // Check for pending reports on app start (if already connected)
    _connectivityService.checkConnectivity().then((isConnected) {
      if (isConnected) {
        print('✅ Already connected on app start - checking for pending reports...');
        _autoSyncOfflineReports();
      }
    });
  }

  /// Automatically sync offline reports when connection is restored
  Future<void> _autoSyncOfflineReports() async {
    try {
      final pendingCount = await _offlineService.getPendingCount();
      if (pendingCount == 0) {
        print('✅ No pending reports to sync');
        return;
      }

      print('📤 Auto-syncing $pendingCount offline report(s)...');
      _showSyncNotification('Syncing $pendingCount offline report(s)...', Colors.blue);

      final result = await _syncService.syncPendingReports();

      if (result.synced > 0) {
        _showSyncNotification(
          '✅ ${result.synced} report(s) synced successfully!',
          Colors.green,
        );
        print('✅ Auto-sync complete: ${result.synced} synced');
      }

      if (result.failed > 0) {
        _showSyncNotification(
          '⚠️ ${result.failed} report(s) failed. Will retry automatically.',
          Colors.orange,
          duration: const Duration(seconds: 5),
        );
        print('⚠️ Auto-sync partial: ${result.failed} failed');
      }
    } catch (e) {
      print('❌ Error during auto-sync: $e');
      _showSyncNotification(
        '❌ Error syncing reports. Will retry when connection is stable.',
        Colors.red,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Show a snackbar notification using the navigator context
  void _showSyncNotification(String message, Color color, {Duration? duration}) {
    if (_navigatorKey?.currentContext == null) {
      print('📢 Sync notification: $message');
      return;
    }

    final context = _navigatorKey!.currentContext!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Manually trigger sync (can be called from UI)
  Future<void> manualSync() async {
    await _autoSyncOfflineReports();
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _isInitialized = false;
    print('🛑 AutoSyncService disposed');
  }
}
