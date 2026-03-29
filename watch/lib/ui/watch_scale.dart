import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Which safe region to use for a given UI element.
///
/// - [visual]  : readable text/content (more conservative)
/// - [touch]   : interactive controls (hit targets should not clip)
/// - [edgeTight]: decorative/non-critical elements can be closer to the edge
enum WatchSafeTier {
  visual,
  touch,
  edgeTight,
}

/// Provides watch-specific scaling + safe area helpers.
///
/// Phase 0 guarantees:
/// - Canvas is clamped to a realistic watch range: 300..420 logical px
/// - Scaling is computed from the clamped canvas, not arbitrary per-value clamps
/// - Safe area supports multiple tiers, plus rect + radial helpers
class WatchScale {
  static const double baseCanvas = 360.0;
  static const double minCanvas = 300.0;
  // Allow larger round Wear OS displays (e.g. ~450x450 logical px).
  static const double maxCanvas = 450.0;

  final double rawCanvasSize; // incoming shortestSide before clamping
  final double canvasSize; // clamped shortestSide used by layout
  final double canvasScale; // canvasSize / baseCanvas

  // Safe insets (derived proportionally from base design, tuned for a 360 canvas)
  final double visualSafeInset;
  final double touchSafeInset;
  final double edgeTightInset;

  const WatchScale._({
    required this.rawCanvasSize,
    required this.canvasSize,
    required this.canvasScale,
    required this.visualSafeInset,
    required this.touchSafeInset,
    required this.edgeTightInset,
  });

  factory WatchScale.fromCanvasSize(double rawCanvasSize) {
    final clamped = rawCanvasSize.clamp(minCanvas, maxCanvas);
    final s = clamped / baseCanvas;

    // Base insets tuned for the existing 360x360 design.
    // Since canvasScale itself is derived from a realistic canvas range,
    // these behave predictably without per-value "arbitrary" clamps.
    const visualBaseInset = 14.0;
    const touchBaseInset = 22.0;
    const edgeTightBaseInset = 10.0;

    return WatchScale._(
      rawCanvasSize: rawCanvasSize,
      canvasSize: clamped,
      canvasScale: s,
      visualSafeInset: visualBaseInset * s,
      touchSafeInset: touchBaseInset * s,
      edgeTightInset: edgeTightBaseInset * s,
    );
  }

  static WatchScale of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<WatchScaleProvider>();
    assert(inherited != null, 'WatchScale not found. Wrap with WatchFrame.');
    return inherited!.data;
  }

  /// Scale a spacing value (margins, gaps, paddings).
  double space(double value) => value * canvasScale;

  /// Scale a font size.
  ///
  /// Uses a dampened exponent so fonts stay readable as the canvas grows,
  /// and don't become too small as the canvas shrinks.
  double font(double value) => value * math.pow(canvasScale, 0.85).toDouble();

  /// Scale an icon size.
  double icon(double value) => value * math.pow(canvasScale, 0.95).toDouble();

  /// Percent helpers on the square canvas.
  /// - percent is expected to be within 0.0..1.0
  double wp(double percent) => canvasSize * percent;
  double hp(double percent) => canvasSize * percent;

  double safeInset(WatchSafeTier tier) {
    switch (tier) {
      case WatchSafeTier.visual:
        return visualSafeInset;
      case WatchSafeTier.touch:
        return touchSafeInset;
      case WatchSafeTier.edgeTight:
        return edgeTightInset;
    }
  }

  double safeRadius(WatchSafeTier tier) => (canvasSize / 2.0) - safeInset(tier);

  /// Uniform safe padding based on a tier.
  ///
  /// Use this when your layout is axis-aligned and you need a conservative
  /// inset from the circle boundary.
  EdgeInsets safePadding(WatchSafeTier tier) => EdgeInsets.all(safeInset(tier));

  /// Axis-aligned inscribed safe square bounds (within the circle).
  ///
  /// Intended use:
  /// - Columns
  /// - Text blocks
  /// - Forms
  /// - Any layout that assumes left/right/top/bottom edges should be safe
  ///
  /// Not intended use:
  /// - radial/angle-based placement (use [radialOffset]/[safeCenterRadius] instead)
  Rect safeRect(WatchSafeTier tier) {
    final inset = safeInset(tier);
    final side = canvasSize - inset * 2.0;
    final left = inset;
    return Rect.fromLTWH(left, left, side, side);
  }

  /// Radial-safe helper: returns the maximum radial distance such that the
  /// center point of an element of [elementRadius] stays within safe bounds.
  double safeCenterRadius(
    WatchSafeTier tier, {
    required double elementRadius,
  }) {
    return safeRadius(tier) - elementRadius;
  }

  /// Convenience for wheel/radial placement.
  ///
  /// Returns the placement center point for an element at [angleRad] with its
  /// radial distance being [radiusFraction] of [safeRadius(tier)].
  Offset radialOffset(
    double angleRad, {
    required double radiusFraction,
    required WatchSafeTier tier,
  }) {
    final r = safeRadius(tier) * radiusFraction;
    final cx = canvasSize / 2.0;
    final cy = canvasSize / 2.0;
    return Offset(cx + r * math.cos(angleRad), cy + r * math.sin(angleRad));
  }
}

/// Internal inherited widget used by [WatchFrame] to inject [WatchScale].
class WatchScaleProvider extends InheritedWidget {
  final WatchScale data;

  const WatchScaleProvider({
    required this.data,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant WatchScaleProvider oldWidget) =>
      oldWidget.data.canvasSize != data.canvasSize;
}

