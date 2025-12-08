class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final String icon; // success, warning, error, info
  final DateTime timestamp;
  bool read;
  String? announcementId; // For linking to announcements

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
    required this.timestamp,
    this.read = false,
    this.announcementId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'icon': icon,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
      'announcementId': announcementId,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      icon: json['icon'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      read: json['read'] as bool? ?? false,
      announcementId: json['announcementId'] as String?,
    );
  }
}

