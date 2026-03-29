import 'package:flutter/material.dart';
import 'watch_scale.dart';

/// Spacing scale presets (scale-aware).
class WatchSpacing {
  final WatchScale s;
  const WatchSpacing(this.s);

  double get xs => s.space(4);
  double get sm => s.space(8);
  double get md => s.space(12);
  double get lg => s.space(16);
  double get xl => s.space(24);
}

/// Typography presets (scale-aware).
///
/// Includes line-height scaling via the `height` property.
class WatchTypography {
  final WatchScale s;
  const WatchTypography(this.s);

  double _lineHeight(double baseHeight) {
    // Keep typography rhythm consistent across sizes.
    // height is a multiplier; baseHeight is tuned for the 360 design.
    if (s.canvasScale <= 1) return baseHeight;
    // Slightly increase line height when canvas grows.
    return baseHeight * (1.0 + (s.canvasScale - 1.0) * 0.08);
  }

  TextStyle caption({Color color = Colors.white70}) => TextStyle(
        color: color,
        fontSize: s.font(11),
        height: _lineHeight(1.25),
        fontWeight: FontWeight.w600,
      );

  TextStyle body({Color color = Colors.white, FontWeight? weight}) => TextStyle(
        color: color,
        fontSize: s.font(14),
        height: _lineHeight(1.25),
        fontWeight: weight ?? FontWeight.w500,
      );

  TextStyle title({
    Color color = Colors.white,
    double size = 20,
    FontWeight? weight,
  }) =>
      TextStyle(
        color: color,
        fontSize: s.font(size),
        height: _lineHeight(1.15),
        fontWeight: weight ?? FontWeight.w700,
      );

  TextStyle headline({
    Color color = Colors.white,
    double size = 24,
    FontWeight? weight,
  }) =>
      TextStyle(
        color: color,
        fontSize: s.font(size),
        height: _lineHeight(1.05),
        fontWeight: weight ?? FontWeight.w800,
      );
}

/// Icon size presets (scale-aware).
class WatchIconSizes {
  final WatchScale s;
  const WatchIconSizes(this.s);

  double get xs => s.icon(14);
  double get sm => s.icon(18);
  double get md => s.icon(26);
  double get lg => s.icon(34);
  double get xl => s.icon(44);
}

