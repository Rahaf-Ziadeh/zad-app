import 'package:flutter/material.dart';

/// Responsive breakpoints for ZAD web/tablet layout.
///
/// Mobile  < 900 dp  → BottomNavigationBar, unchanged design
/// Desktop ≥ 900 dp  → NavigationRail sidebar, content centered ≤ 1100 dp
class AppBreakpoints {
  AppBreakpoints._();

  static const double desktop = 900.0;
  static const double maxContentWidth = 1100.0;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  /// Horizontal padding that centers content within [maxContentWidth].
  static double contentPadding(double availableWidth) {
    if (availableWidth <= maxContentWidth) return 0.0;
    return (availableWidth - maxContentWidth) / 2;
  }
}
