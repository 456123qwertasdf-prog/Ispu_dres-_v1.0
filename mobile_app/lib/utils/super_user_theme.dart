import 'package:flutter/material.dart';

/// Super User mobile theme — matches public/super-user.html and css/su-header-shared.css.
/// Use across all Super User screens for consistent branding.
class SuTheme {
  SuTheme._();

  static const Color primary = Color(0xFF2563eb);
  static const Color primaryLight = Color(0xFF3b82f6);
  static const Color bg = Color(0xFFf1f5f9);
  static const Color headerStart = Color(0xFF0f172a);
  static const Color headerEnd = Color(0xFF1e3a8a);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1e293b);
  static const Color textMuted = Color(0xFF64748b);

  /// App bar gradient matching web Super User header.
  static const LinearGradient appBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerStart, headerEnd],
  );

  /// Header/card gradient for dashboard-style cards.
  static const LinearGradient headerCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerStart, headerEnd],
  );

  /// Standard card decoration: white, rounded, subtle shadow.
  static BoxDecoration cardDecoration({
    Color? color,
    Border? border,
    List<BoxShadow>? shadow,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(20),
      border: border,
      boxShadow: shadow ??
          [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
    );
  }

  /// Filter chip selected state.
  static BoxDecoration filterChipSelected = BoxDecoration(
    color: primary,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: primary.withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  /// Filter chip unselected state.
  static BoxDecoration filterChipUnselected(Color? unselectedColor) =>
      BoxDecoration(
        color: unselectedColor ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      );

  /// Section container for filter chips / toolbar (elevated, rounded).
  static BoxDecoration filterBarDecoration = BoxDecoration(
    color: surface,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 12,
        offset: const Offset(0, 2),
      ),
    ],
  );
}
