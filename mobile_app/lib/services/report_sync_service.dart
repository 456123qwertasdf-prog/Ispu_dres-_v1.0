import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'offline_report_service.dart';
import 'supabase_service.dart';

/// Service for syncing offline reports to the server
class ReportSyncService {
  static final ReportSyncService _instance = ReportSyncService._internal();
  factory ReportSyncService() => _instance;
  ReportSyncService._internal();

  final OfflineReportService _offlineService = OfflineReportService();
  bool _isSyncing = false;

  String get _supabaseUrl => SupabaseService.supabaseUrl;
  String get _supabaseKey => SupabaseService.supabaseAnonKey;

  /// Sync all pending offline reports
  Future<SyncResult> syncPendingReports() async {
    if (_isSyncing) {
      print('⚠️ Sync already in progress');
      return SyncResult(synced: 0, failed: 0, isAlreadyRunning: true);
    }

    _isSyncing = true;

    try {
      final pendingReports = await _offlineService.getPendingReports();
      
      if (pendingReports.isEmpty) {
        print('✅ No pending reports to sync');
        return SyncResult(synced: 0, failed: 0);
      }

      print('📤 Syncing ${pendingReports.length} offline report(s)...');

      int synced = 0;
      int failed = 0;

      for (final report in pendingReports) {
        try {
          final success = await _syncSingleReport(report);
          if (success) {
            synced++;
            // Delete the synced report
            await _offlineService.deleteReport(report['id'] as String);
          } else {
            failed++;
          }
        } catch (e) {
          print('❌ Error syncing report ${report['id']}: $e');
          failed++;
          // Update retry count
          final retryCount = (report['retry_count'] as int? ?? 0) + 1;
          await _offlineService.updateReportStatus(
            report['id'] as String,
            errorMessage: e.toString(),
            retryCount: retryCount,
          );
        }
      }

      print('✅ Sync complete: $synced synced, $failed failed');
      return SyncResult(synced: synced, failed: failed);
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single offline report
  Future<bool> _syncSingleReport(Map<String, dynamic> report) async {
    try {
      // Get image file
      final imageFile = await _offlineService.getImageFile(report['id'] as String);
      if (imageFile == null || !await imageFile.exists()) {
        print('❌ Image file not found for report ${report['id']}');
        return false;
      }

      // Prepare form data
      final formData = _offlineService.toFormData(report);

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_supabaseUrl/functions/v1/submit-report'),
      );

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $_supabaseKey',
      });

      // Add form fields
      formData.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Add image file
      final imageBytes = await imageFile.readAsBytes();
      final filePath = imageFile.path.toLowerCase();
      
      String contentType;
      String extension;
      
      if (filePath.endsWith('.png')) {
        contentType = 'image/png';
        extension = 'png';
      } else if (filePath.endsWith('.webp')) {
        contentType = 'image/webp';
        extension = 'webp';
      } else {
        contentType = 'image/jpeg';
        extension = 'jpg';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'emergency_${report['id']}.$extension',
          contentType: MediaType.parse(contentType),
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Report ${report['id']} synced successfully');
        return true;
      } else {
        print('❌ Failed to sync report ${report['id']}: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Exception syncing report ${report['id']}: $e');
      return false;
    }
  }

  /// Check if sync is in progress
  bool get isSyncing => _isSyncing;
}

/// Result of sync operation
class SyncResult {
  final int synced;
  final int failed;
  final bool isAlreadyRunning;

  SyncResult({
    required this.synced,
    required this.failed,
    this.isAlreadyRunning = false,
  });

  bool get hasResults => synced > 0 || failed > 0;
}
