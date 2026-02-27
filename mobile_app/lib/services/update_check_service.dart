import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

/// Method channel for installing APK from app cache (reliable with FileProvider).
const _installChannel = MethodChannel('com.example.mobile_app/install');

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

  /// Check if the app can install packages (Android 8+ "Install unknown apps").
  static Future<bool> canRequestPackageInstalls() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final bool? result = await _installChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open system settings so user can allow "Install unknown apps" for this app (Android 8+).
  static Future<void> openInstallUnknownAppsSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _installChannel.invokeMethod('openInstallUnknownAppsSettings');
    } catch (_) {}
  }

  /// APK/ZIP magic bytes (APK is a ZIP file).
  static final _apkMagic = [0x50, 0x4B, 0x03, 0x04];

  static Future<bool> _isValidApkFile(File file) async {
    if (!file.existsSync()) return false;
    if (file.lengthSync() < 100) return false;
    final bytes = await file.openRead(0, 4).first;
    if (bytes.length < 4) return false;
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != _apkMagic[i]) return false;
    }
    return true;
  }

  /// Download APK to app cache and install via FileProvider (reliable on all Android versions).
  /// [onProgress] receives 0.0 to 1.0. On Android only; otherwise opens URL in browser.
  static Future<void> downloadAndInstallApk(
    String? downloadUrl, {
    void Function(double progress)? onProgress,
    void Function(String message)? onInstallError,
  }) async {
    if (downloadUrl == null || downloadUrl.isEmpty) return;
    if (defaultTargetPlatform != TargetPlatform.android) {
      await openDownloadUrl(downloadUrl);
      return;
    }
    try {
      final canInstall = await canRequestPackageInstalls();
      if (!canInstall) {
        onInstallError?.call(
          'Please allow "Install unknown apps" for this app in the next screen, then try Download and install again.',
        );
        await openInstallUnknownAppsSettings();
        return;
      }

      final dir = await getTemporaryDirectory();
      final apkFile = File('${dir.path}/update.apk');
      if (apkFile.existsSync()) apkFile.deleteSync();

      final uri = Uri.parse(downloadUrl);
      final request = http.Request('GET', uri);
      final streamed = await http.Client().send(request);
      final total = streamed.contentLength ?? 0;
      var received = 0;
      final sink = apkFile.openWrite();
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();

      if (!await _isValidApkFile(apkFile)) {
        onInstallError?.call(
          'Downloaded file is not a valid APK (may be incomplete or the link returned a web page). Try "Open in browser" to download and install.',
        );
        return;
      }

      await _installChannel.invokeMethod<void>('installApkFromPath', {'path': apkFile.path});
    } on PlatformException catch (e) {
      debugPrint('UpdateCheck: install error: $e');
      onInstallError?.call(e.message ?? e.code);
    } catch (e, st) {
      debugPrint('UpdateCheck: downloadAndInstallApk error: $e\n$st');
      onInstallError?.call(e.toString());
    }
  }

  /// Show a dialog when install fails. Suggests enabling "Install unknown apps" or using the browser.
  static void showInstallErrorDialog(BuildContext context, String message, String? downloadUrl) {
    final isPermissionMessage = message.contains('Install unknown apps');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Install failed'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPermissionMessage)
                const Text(
                  'Allow this app to install other apps in the settings that just opened, then tap "Download and install" again.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                )
              else ...[
                const Text(
                  'The update could not be installed. You can try "Open in browser" to download the APK and install it from your browser or Files app.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Text('Details: $message', style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
          if (downloadUrl != null && downloadUrl.isNotEmpty)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openDownloadUrl(downloadUrl);
              },
              child: const Text('Open in browser'),
            ),
        ],
      ),
    );
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
                downloadAndInstallApk(
                  result.downloadUrl,
                  onInstallError: (msg) {
                    if (context.mounted) {
                      showInstallErrorDialog(context, msg, result.downloadUrl);
                    }
                  },
                );
              },
              child: const Text('Download and install'),
            ),
          ],
        ),
      ),
    );
    return true;
  }
}
