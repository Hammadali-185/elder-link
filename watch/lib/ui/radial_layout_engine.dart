import 'dart:math' as math;

/// Pure radial geometry engine.
///
/// Reusable for ANY radial layout:
/// - No Flutter imports
/// - No UI modes / paging / touch targets
/// - Only geometry primitives
class RadialLayoutEngine {
  const RadialLayoutEngine();

  static const double tau = math.pi * 2.0;

  /// Returns N angles evenly spaced around the circle, starting at [rotationOffset].
  static List<double> evenAngles({
    required int count,
    double rotationOffset = 0.0,
  }) {
    if (count <= 0) return const [];
    final step = tau / count;
    return List.generate(count, (i) => (step * i) + rotationOffset, growable: false);
  }

  /// Minimum radius required so that adjacent items separated by angle step
  /// have chord distance >= (diameter + gap).
  ///
  /// chord = 2r*sin(pi/N)
  /// r >= (diameter + gap) / (2*sin(pi/N))
  static double minRadiusForNoOverlap({
    required int count,
    required double itemDiameter,
    required double gap,
  }) {
    if (count <= 1) return 0.0;
    final sinTerm = math.sin(math.pi / count);
    if (sinTerm <= 0) return double.infinity;
    return (itemDiameter + gap) / (2.0 * sinTerm);
  }

  /// Converts a polar coordinate into a cartesian offset from center.
  static CartesianOffset toCartesian({
    required double angle,
    required double radius,
  }) {
    return CartesianOffset(
      dx: radius * math.cos(angle),
      dy: radius * math.sin(angle),
    );
  }

  /// Converts multiple polar coordinates into cartesian offsets.
  static List<CartesianOffset> toCartesianList({
    required List<double> angles,
    required List<double> radii,
  }) {
    final n = math.min(angles.length, radii.length);
    return List.generate(
      n,
      (i) => toCartesian(angle: angles[i], radius: radii[i]),
      growable: false,
    );
  }

  // Back-compat aliases for existing call sites (kept intentionally).
  static List<double> angles({required int count, required double rotationOffset}) =>
      evenAngles(count: count, rotationOffset: rotationOffset);
}

class CartesianOffset {
  final double dx;
  final double dy;

  const CartesianOffset({required this.dx, required this.dy});
}

