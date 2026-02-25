import 'dart:convert';

/// Lightweight representation of a latitude/longitude pair.
class CoordinatePoint {
  const CoordinatePoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

dynamic _decodeIfJson(dynamic value) {
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Not JSON - ignore.
    }
  }
  return value;
}

CoordinatePoint? coordinateFrom(dynamic source) {
  if (source == null) return null;
  final dynamic decoded = _decodeIfJson(source);

  if (decoded is Map<String, dynamic>) {
    // GeoJSON { type, coordinates }
    if (decoded['coordinates'] is List) {
      final coords = decoded['coordinates'] as List;
      if (coords.length >= 2) {
        final lng = _toDouble(coords[0]);
        final lat = _toDouble(coords[1]);
        if (lat != null && lng != null) {
          return CoordinatePoint(latitude: lat, longitude: lng);
        }
      }
    }

    final lat = _toDouble(decoded['lat'] ?? decoded['latitude']);
    final lng = _toDouble(decoded['lng'] ?? decoded['longitude']);
    if (lat != null && lng != null) {
      return CoordinatePoint(latitude: lat, longitude: lng);
    }
  } else if (decoded is List && decoded.length >= 2) {
    final lat = _toDouble(decoded[0]);
    final lng = _toDouble(decoded[1]);
    if (lat != null && lng != null) {
      return CoordinatePoint(latitude: lat, longitude: lng);
    }
  }

  return null;
}

class ResponderProfile {
  const ResponderProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.isAvailable,
    required this.status,
    this.phone,
    this.lastLocation,
    this.teamName,
    this.leaderName,
  });

  final String id;
  final String name;
  final String role;
  final bool isAvailable;
  final String status;
  final String? phone;
  final dynamic lastLocation;
  final String? teamName;
  final String? leaderName;

  factory ResponderProfile.fromMap(Map<String, dynamic> map) {
    String? leaderName;
    final leader = map['leader'];
    if (leader is Map<String, dynamic> && leader['name'] != null) {
      leaderName = leader['name']?.toString();
    }
    return ResponderProfile(
      id: map['id']?.toString() ?? '',
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Responder',
      role: (map['role'] as String?)?.isNotEmpty == true
          ? map['role'] as String
          : 'Responder',
      isAvailable: map['is_available'] == true,
      status: (map['status'] as String?)?.isNotEmpty == true
          ? map['status'] as String
          : (map['is_available'] == true ? 'available' : 'unavailable'),
      phone: map['phone'] as String?,
      lastLocation: map['last_location'],
      teamName: (map['team_name'] as String?)?.trim().isNotEmpty == true
          ? map['team_name'] as String
          : null,
      leaderName: leaderName?.trim().isNotEmpty == true ? leaderName : null,
    );
  }

  CoordinatePoint? get coordinates => coordinateFrom(lastLocation);

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'R';
    }
    final chars = parts.take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '');
    final initials = chars.join();
    return initials.isNotEmpty ? initials : 'R';
  }

  ResponderProfile copyWith({
    bool? isAvailable,
    String? status,
    dynamic lastLocation,
    String? teamName,
    String? leaderName,
  }) {
    return ResponderProfile(
      id: id,
      name: name,
      role: role,
      phone: phone,
      isAvailable: isAvailable ?? this.isAvailable,
      status: status ?? this.status,
      lastLocation: lastLocation ?? this.lastLocation,
      teamName: teamName ?? this.teamName,
      leaderName: leaderName ?? this.leaderName,
    );
  }
}

class AssignmentReportSummary {
  const AssignmentReportSummary({
    required this.id,
    this.type,
    this.message,
    this.status,
    this.reporterName,
    this.createdAt,
    this.location,
    this.imagePath,
  });

  final String id;
  final String? type;
  final String? message;
  final String? status;
  final String? reporterName;
  final DateTime? createdAt;
  final dynamic location;
  final String? imagePath;

  factory AssignmentReportSummary.fromMap(Map<String, dynamic> map) {
    return AssignmentReportSummary(
      id: map['id']?.toString() ?? '',
      type: map['type'] as String?,
      message: map['message'] as String?,
      status: map['status'] as String?,
      reporterName: map['reporter_name'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      location: map['location'],
      imagePath: map['image_path'] as String?,
    );
  }

  CoordinatePoint? get coordinates => coordinateFrom(location);
}

class ResponderAssignment {
  const ResponderAssignment({
    required this.id,
    required this.status,
    required this.assignedAt,
    required this.report,
    this.acceptedAt,
    this.completedAt,
    this.notes,
  });

  final String id;
  final String status;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? notes;
  final AssignmentReportSummary report;

  factory ResponderAssignment.fromMap(Map<String, dynamic> map) {
    final reportData = (map['reports'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final notesStr = map['notes'] as String?;
    final notes = (notesStr != null && notesStr.trim().isNotEmpty) ? notesStr.trim() : null;

    return ResponderAssignment(
      id: map['id']?.toString() ?? '',
      status: (map['status'] as String? ?? 'assigned').toLowerCase(),
      assignedAt: map['assigned_at'] != null
          ? DateTime.tryParse(map['assigned_at'].toString())
          : null,
      acceptedAt: map['accepted_at'] != null
          ? DateTime.tryParse(map['accepted_at'].toString())
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'].toString())
          : null,
      notes: notes,
      report: AssignmentReportSummary.fromMap(
        Map<String, dynamic>.from(reportData),
      ),
    );
  }

  bool get isCompleted =>
      status == 'resolved' || status == 'completed' || status == 'closed';

  bool get isActive =>
      status == 'assigned' ||
      status == 'accepted' ||
      status == 'enroute' ||
      status == 'on_scene' ||
      status == 'in_progress';

  Duration? get responseDuration {
    if (assignedAt == null || completedAt == null) return null;
    return completedAt!.difference(assignedAt!);
  }
}

