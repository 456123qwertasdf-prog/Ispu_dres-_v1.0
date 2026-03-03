import 'package:intl/intl.dart';

/// Report created_at from the API is stored as the submitter's local time with
/// a UTC suffix (+00/Z). To show the correct time we strip the timezone and
/// parse as local so the hour/minute display matches (e.g. 15:18 → 3:18 PM).
class ReportDateHelper {
  static final DateFormat _displayFormat =
      DateFormat('MMM d, yyyy • h:mm a');
  static final DateFormat _shortFormat = DateFormat('MMM d, h:mm a');

  /// Parses API created_at string (e.g. "2026-03-03T15:18:54.636660Z") as
  /// local time (strip Z/offset so 15:18 is not converted again).
  static DateTime? parseReportCreatedAt(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    String s = dateStr.trim();
    if (s.endsWith('Z')) {
      s = s.substring(0, s.length - 1);
    } else {
      final offsetMatch = RegExp(r'[+-]\d{2}:?\d{2}$').firstMatch(s);
      if (offsetMatch != null) {
        s = s.substring(0, offsetMatch.start);
      }
    }
    return DateTime.tryParse(s);
  }

  /// Formats API created_at string for display (e.g. "Mar 3, 2026 • 3:18 PM").
  static String formatReportCreatedAt(String? dateStr) {
    final date = parseReportCreatedAt(dateStr);
    if (date == null) return 'Unknown';
    return _displayFormat.format(date);
  }

  /// Short format for lists (e.g. "Mar 3, 3:18 PM").
  static String formatReportCreatedAtShort(String? dateStr) {
    final date = parseReportCreatedAt(dateStr);
    if (date == null) return '—';
    return _shortFormat.format(date);
  }

  /// Use when you already have a DateTime from [parseReportCreatedAt]
  /// (no toLocal() so the time is shown as-is).
  static String formatReportCreatedAtDateTime(DateTime? date) {
    if (date == null) return 'Unknown';
    return _displayFormat.format(date);
  }
}
