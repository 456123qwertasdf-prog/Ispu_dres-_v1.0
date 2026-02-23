/// Role-based synopsis from report data (mirrors web getSynopsisForRole).
/// Uses last 30 days of reports to build citizen and responder messages.
class SynopsisHelper {
  static const _emergencyTypes = [
    'fire',
    'medical',
    'flood',
    'accident',
    'structural',
    'environmental',
  ];

  static String _getEffectiveType(Map<String, dynamic> r) {
    final t = (r['corrected_type'] ?? r['type'] ?? '').toString().toLowerCase().trim();
    return t;
  }

  /// Returns [citizenMessage, responderMessage] from report list.
  /// Reports should have: type, corrected_type (optional), created_at.
  static Map<String, String> getSynopsisForRole(
    List<dynamic> reports, [
    String role = 'citizen',
  ]) {
    final list = reports is List ? reports : <dynamic>[];
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recent = list.where((r) {
      if (r is! Map<String, dynamic>) return false;
      final createdAt = r['created_at']?.toString();
      if (createdAt == null || createdAt.isEmpty) return false;
      try {
        final d = DateTime.parse(createdAt);
        return d.isAfter(thirtyDaysAgo) || d.isAtSameMomentAs(thirtyDaysAgo);
      } catch (_) {
        return false;
      }
    }).cast<Map<String, dynamic>>().toList();

    final emergencies = recent.where((r) {
      final t = _getEffectiveType(r);
      return t.isNotEmpty && t != 'non_emergency' && t != 'false_alarm';
    }).toList();

    final falseAlarms = recent.where((r) => _getEffectiveType(r) == 'false_alarm').length;

    final byType = <String, int>{};
    for (final r in emergencies) {
      final t = _getEffectiveType(r);
      final key = _emergencyTypes.contains(t) ? t : 'other';
      byType[key] = (byType[key] ?? 0) + 1;
    }

    final typeLabels = <String, String>{
      'fire': 'fire',
      'medical': 'medical',
      'flood': 'flood',
      'accident': 'accident',
      'structural': 'structural',
      'environmental': 'environmental',
      'other': 'other',
    };
    final typesWithCount = byType.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = typesWithCount.isNotEmpty ? typesWithCount.first.key : null;

    // Citizen message
    String citizenMessage = 'No recent emergency reports. Stay alert and report any real emergency you see.';
    if (emergencies.isNotEmpty) {
      final parts = typesWithCount
          .map((e) => '${e.value} ${typeLabels[e.key] ?? e.key}')
          .join(', ');
      String caution = 'Stay alert and follow official advisories.';
      if (top != null) {
        switch (top) {
          case 'medical':
            caution = 'Know where the nearest clinic or hospital is and how to call for help.';
            break;
          case 'fire':
            caution = 'Be aware of evacuation routes and avoid open flames.';
            break;
          case 'flood':
            caution = 'Avoid flooded areas and follow flood advisories.';
            break;
          case 'accident':
            caution = 'Drive safely and report any hazard you see.';
            break;
        }
      }
      citizenMessage = "Be more careful: we've had $parts incident(s) in the last 30 days. $caution";
    }
    if (falseAlarms > 0 && falseAlarms >= emergencies.length) {
      citizenMessage +=
          ' Many reports were false alarms—please only report real emergencies so responders can focus on those in need.';
    }

    // Responder message
    const prepByType = <String, String>{
      'medical': 'Check first aid kits and AED availability. Be ready for medical calls. ',
      'fire': 'Inspect fire equipment and evacuation routes. Prepare extinguishers and muster points. ',
      'flood': 'Be ready for flood response: inspect sandbags, life vests, and flood alert procedures. ',
      'accident': 'Prepare traffic cones and first aid. Ensure vehicle recovery contacts are ready. ',
      'structural': 'Inspect caution tape and hard hats. Be ready for structural assessment support. ',
      'environmental': 'Review heat/cold protocols and weather monitoring. Have drinking water and shade ready. ',
      'other': 'Review general response kits and communication channels. ',
    };
    String responderMessage =
        'No recent emergencies. Keep equipment inspected and stay ready for anything.';
    if (typesWithCount.isNotEmpty) {
      final prepLines = typesWithCount
          .take(4)
          .map((e) => prepByType[e.key] ?? prepByType['other']!)
          .join();
      responderMessage =
          'Prepare and be ready: $prepLines Inspect and prepare so you\'re ready when something happens.';
    }

    return {'citizenMessage': citizenMessage, 'responderMessage': responderMessage};
  }
}
