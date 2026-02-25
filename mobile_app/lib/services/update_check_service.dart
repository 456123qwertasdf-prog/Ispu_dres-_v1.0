import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supabase_service.dart';

/// Result of checking for app updates.
enum UpdateStatus {
  upToDate,
  updateAvailable,
  updateRequired,
}

class UpdateCheckResult {
  final UpdateStatus status;
  final String currentVersion;
  final String latestVersion;
  final bool forceUpdate;
  final String? downloadUrl;
  final String? releaseNotes;

  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    required this.latestVersion,
    required this.forceUpdate,
    this.downloadUrl,
    this.releaseNotes,
  });
}

class UpdateCheckService {
  static const String _functionName = 'get-app-version';

  /// Compare two semver-like versions (e.g. "1.1.0"). Returns -1 if a < b, 0 if equal, 1 if a > b.
  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final len = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (int i = 0; i < len; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av < bv) return -1;
      if (av > bv) return 1;
    }
    return 0;
  }

  /// Check for updates. Call after user is authenticated (uses Supabase client for invoke).
  static Future<UpdateCheckResult?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final platform = defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';

      final response = await SupabaseService.client.functions.invoke(
        _functionName,
        queryParameters: {'platform': platform},
      );

      if (response.data == null) {
        debugPrint('UpdateCheck: no data from get-app-version');
        return null;
      }

      final data = response.data is Map ? response.data as Map : jsonDecode(response.data.toString()) as Map;
      final minVersion = (data['min_version'] as String?) ?? '0.0.0';
      final latestVersion = (data['latest_version'] as String?) ?? currentVersion;
      final forceUpdate = (data['force_update'] as bool?) ?? false;
      final downloadUrl = data['download_url'] as String?;
      final releaseNotes = data['release_notes'] as String?;

      if (_compareVersions(currentVersion, minVersion) < 0) {
        return UpdateCheckResult(
          status: UpdateStatus.updateRequired,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          forceUpdate: true,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
        );
      }
      if (_compareVersions(currentVersion, latestVersion) < 0) {
        return UpdateCheckResult(
          status: UpdateStatus.updateAvailable,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          forceUpdate: forceUpdate,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
        );
      }
      return UpdateCheckResult(
        status: UpdateStatus.upToDate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        forceUpdate: false,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
      );
    } catch (e, st) {
      debugPrint('UpdateCheck error: $e\n$st');
      return null;
    }
  }

  /// Open the download URL (APK or store link) in browser.
  static Future<void> openDownloadUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Show update dialog if result is updateAvailable or updateRequired. Returns true if dialog was shown.
  static bool showUpdateDialogIfNeeded(BuildContext context, UpdateCheckResult? result) {
    if (result == null || result.status == UpdateStatus.upToDate) return false;
    final isRequired = result.status == UpdateStatus.updateRequired;
    showDialog(
      context: context,
      barrierDismissible: !isRequired,
      builder: (ctx) => PopScope(
        canPop: !isRequired,
        child: AlertDialog(
          title: Text(isRequired ? 'Update required' : 'Update available'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRequired
                      ? 'You need to update to continue. This version can no longer be used. Please update from the link below.'
                      : 'A new version of KAPIYU (${result.latestVersion}) is available. You have ${result.currentVersion}.',
                ),
                if (result.releaseNotes != null && result.releaseNotes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('What\'s new:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(result.releaseNotes!),
                ],
              ],
            ),
          ),
          actions: [
            if (!isRequired)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openDownloadUrl(result.downloadUrl);
              },
              child: const Text('Download update'),
            ),
          ],
        ),
      ),
    );
    return true;
  }
}
