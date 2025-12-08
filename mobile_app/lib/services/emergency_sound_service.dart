import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service to handle emergency alert sounds
class EmergencySoundService {
  static final EmergencySoundService _instance = EmergencySoundService._internal();
  factory EmergencySoundService() => _instance;
  EmergencySoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  /// Play emergency alert sound
  /// 
  /// This will play the sound multiple times (3 times) to ensure users notice it
  Future<void> playEmergencySound() async {
    if (_isPlaying) {
      // Already playing, don't interrupt
      return;
    }

    try {
      _isPlaying = true;
      
      // Try to play from assets
      try {
        // Set volume to maximum for emergency alerts
        await _audioPlayer.setVolume(1.0);
        
        // Play the sound 3 times with short pauses between
        for (int i = 0; i < 3; i++) {
          await _audioPlayer.play(AssetSource('sounds/emergency_alert.mp3'));
          
          // Wait for the sound to play (approximately 1 second per play)
          await Future.delayed(const Duration(milliseconds: 1000));
          
          // If this is not the last iteration, wait before next play
          if (i < 2) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }
      } catch (e) {
        // If asset file doesn't exist, log the error
        // The user should add the sound file to assets/sounds/emergency_alert.mp3
        debugPrint('Could not play emergency sound file. Please ensure assets/sounds/emergency_alert.mp3 exists: $e');
        // Note: We don't throw here to prevent app crashes if sound file is missing
      }
    } catch (e) {
      debugPrint('Error playing emergency sound: $e');
    } finally {
      _isPlaying = false;
    }
  }

  /// Play a single emergency alert sound (for quick alerts)
  Future<void> playEmergencySoundOnce() async {
    if (_isPlaying) {
      return;
    }

    try {
      _isPlaying = true;
      await _audioPlayer.play(AssetSource('sounds/emergency_alert.mp3'));
    } catch (e) {
      debugPrint('Error playing emergency sound: $e');
    } finally {
      // Reset after sound duration (approximately 1 second)
      Future.delayed(const Duration(seconds: 1), () {
        _isPlaying = false;
      });
    }
  }

  /// Stop any currently playing emergency sound
  Future<void> stopSound() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('Error stopping emergency sound: $e');
    }
  }

  /// Dispose of the audio player
  void dispose() {
    _audioPlayer.dispose();
  }
}

