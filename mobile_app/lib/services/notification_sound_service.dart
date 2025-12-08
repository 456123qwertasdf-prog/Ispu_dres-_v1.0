import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'emergency_sound_service.dart';

/// Service to handle notification sounds
class NotificationSoundService {
  static final NotificationSoundService _instance = NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;
  NotificationSoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  static const MethodChannel _channel = MethodChannel('com.example.mobile_app/sound');
  bool _soundEnabled = true;
  bool _isInitialized = false;

  /// Initialize the service and load preferences
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('notification_sound_enabled') ?? true;
      _isInitialized = true;
      debugPrint('🔔 Notification sound service initialized. Sound enabled: $_soundEnabled');
    } catch (e) {
      debugPrint('❌ Error initializing notification sound service: $e');
      _soundEnabled = true; // Default to enabled
    }
  }

  /// Check if notification sound is enabled
  bool get isSoundEnabled => _soundEnabled;

  /// Toggle notification sound on/off
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_sound_enabled', enabled);
      debugPrint('🔔 Notification sound ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      debugPrint('❌ Error saving notification sound preference: $e');
    }
  }

  /// Play custom emergency sound from Android res/raw/
  Future<void> playEmergencySound() async {
    if (!_soundEnabled) {
      debugPrint('🔕 Notification sound is disabled, skipping sound playback');
      return;
    }

    try {
      // Use platform channel to play sound from Android res/raw/emergency_alert.mp3
      await _channel.invokeMethod('playEmergencySound');
      debugPrint('🔊 Playing emergency notification sound via platform channel');
    } catch (e) {
      debugPrint('❌ Error playing emergency sound via platform channel: $e');
      // Fallback: Try using the existing EmergencySoundService
      try {
        final emergencyService = EmergencySoundService();
        await emergencyService.playEmergencySoundOnce();
        debugPrint('🔊 Played emergency sound via EmergencySoundService fallback');
      } catch (e2) {
        debugPrint('❌ Error in fallback sound playback: $e2');
      }
    }
  }

  /// Play default notification sound
  Future<void> playDefaultSound() async {
    if (!_soundEnabled) {
      return;
    }

    try {
      debugPrint('🔊 Playing default notification sound');
    } catch (e) {
      debugPrint('❌ Error playing default sound: $e');
    }
  }

  /// Stop any currently playing sound
  Future<void> stopSound() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('❌ Error stopping sound: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}

