import 'package:flutter/material.dart';
import '../services/notification_sound_service.dart';

/// Widget to toggle notification sound on/off
class NotificationSettingsWidget extends StatefulWidget {
  const NotificationSettingsWidget({super.key});

  @override
  State<NotificationSettingsWidget> createState() => _NotificationSettingsWidgetState();
}

class _NotificationSettingsWidgetState extends State<NotificationSettingsWidget> {
  final NotificationSoundService _soundService = NotificationSoundService();
  bool _soundEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _soundService.initialize();
    setState(() {
      _soundEnabled = _soundService.isSoundEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleSound(bool enabled) async {
    setState(() {
      _soundEnabled = enabled;
    });
    await _soundService.setSoundEnabled(enabled);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled 
              ? '🔔 Notification sound enabled' 
              : '🔕 Notification sound disabled',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ListTile(
        leading: CircularProgressIndicator(),
        title: Text('Loading settings...'),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          _soundEnabled ? Icons.volume_up : Icons.volume_off,
          color: _soundEnabled ? Colors.green : Colors.grey,
        ),
        title: const Text('Notification Sound'),
        subtitle: Text(
          _soundEnabled 
            ? 'Emergency alerts will play custom sound' 
            : 'Notification sounds are disabled',
        ),
        trailing: Switch(
          value: _soundEnabled,
          onChanged: _toggleSound,
        ),
      ),
    );
  }
}

