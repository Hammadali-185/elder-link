import 'dart:math' as math;
import 'radial_layout_engine.dart';

/// Strategy-based, scalable layout planner for Home.
///
/// Pure logic only:
/// - no Flutter types
/// - no widget/rendering logic
/// - outputs UI-agnostic geometry (normalized polar positions)
class HomeLayoutPlanner {
  final LayoutPolicy policy;
  final LayoutFeasibility feasibility;

  const HomeLayoutPlanner({
    required this.policy,
    required this.feasibility,
  });

  factory HomeLayoutPlanner.defaults({
    required double minTouchTargetDp,
    required int maxButtonsSafe,
    required int maxButtonsPerPage,
    required double rotationOffset,
  }) {
    return HomeLayoutPlanner(
      policy: LayoutPolicy(
        minTouchTargetDp: minTouchTargetDp,
        maxButtonsSafe: maxButtonsSafe,
        maxButtonsPerPage: maxButtonsPerPage,
        rotationOffset: rotationOffset,
      ),
      feasibility: const LayoutFeasibility(),
    );
  }

  static int _debugRunId = 0;

  LayoutPlan plan(LayoutInputs input) {
    final sw = Stopwatch()..start();
    final runId = ++_debugRunId;

    final strategy = _selectStrategy(input);
    final plan = strategy.buildPlan(input, policy: policy, feasibility: feasibility);

    assert(() {
      sw.stop();
      // ignore: avoid_print
      print(
        '[WATCH][Planner] run=$runId strategy=${strategy.runtimeType} '
        'items=${input.itemCount} mode=${plan.mode} pages=${plan.pages.length} '
        'perPage=${plan.perPage} t=${sw.elapsedMicroseconds}us',
      );
      return true;
    }());

    return plan;
  }

  LayoutStrategy _selectStrategy(LayoutInputs input) {
    if (input.itemCount <= 0) return const ListFallbackStrategy(empty: true);

    // First choose radial vs paged by policy only.
    final wantsPaging = policy.shouldPage(input.itemCount);
    if (!wantsPaging) return const RadialLayoutStrategy();
    return const PagedRadialStrategy();
  }
}

// -------------------------
// Inputs / policy / feasibility
// -------------------------

class LayoutInputs {
  final int itemCount;
  final double baseButtonDiameter;
  final double minGapBetweenButtons;

  /// Returns the maximum safe wheel radius for a given button diameter.
  final double Function(double buttonDiameter) maxSafeWheelRadiusForDiameter;

  const LayoutInputs({
    required this.itemCount,
    required this.baseButtonDiameter,
    required this.minGapBetweenButtons,
    required this.maxSafeWheelRadiusForDiameter,
  });
}

class LayoutPolicy {
  final double minTouchTargetDp;
  final int maxButtonsSafe;
  final int maxButtonsPerPage;
  final double rotationOffset;

  const LayoutPolicy({
    required this.minTouchTargetDp,
    required this.maxButtonsSafe,
    required this.maxButtonsPerPage,
    required this.rotationOffset,
  });

  bool shouldPage(int itemCount) => itemCount > maxButtonsSafe;

  int initialPerPage(int itemCount) => math.min(itemCount, maxButtonsPerPage);

  bool shouldFallbackToList(double buttonDiameter) => buttonDiameter < minTouchTargetDp;
}

class LayoutFeasibility {
  const LayoutFeasibility();

  double minRadiusRequired({
    required int count,
    required double itemDiameter,
    required double gap,
  }) {
    return RadialLayoutEngine.minRadiusForNoOverlap(
      count: count,
      itemDiameter: itemDiameter,
      gap: gap,
    );
  }

  bool canFitWithoutOverlap({
    required int count,
    required double itemDiameter,
    required double gap,
    required double maxAllowedRadius,
  }) {
    return minRadiusRequired(
          count: count,
          itemDiameter: itemDiameter,
          gap: gap,
        ) <=
        maxAllowedRadius;
  }
}

// -------------------------
// Strategies
// -------------------------

abstract class LayoutStrategy {
  const LayoutStrategy();

  LayoutPlan buildPlan(
    LayoutInputs input, {
    required LayoutPolicy policy,
    required LayoutFeasibility feasibility,
  });
}

class RadialLayoutStrategy extends LayoutStrategy {
  const RadialLayoutStrategy();

  @override
  LayoutPlan buildPlan(
    LayoutInputs input, {
    required LayoutPolicy policy,
    required LayoutFeasibility feasibility,
  }) {
    if (input.itemCount <= 0) return const LayoutPlan.empty();

    final radial = _computeRadialMetrics(
      countOnPage: input.itemCount,
      input: input,
      policy: policy,
      feasibility: feasibility,
    );

    if (policy.shouldFallbackToList(radial.buttonDiameter)) {
      return const ListFallbackStrategy().buildPlan(
        input,
        policy: policy,
        feasibility: feasibility,
      );
    }

    final page = _buildRadialPage(
      indices: List.generate(input.itemCount, (i) => i, growable: false),
      count: input.itemCount,
      radial: radial,
      policy: policy,
      input: input,
    );

    final centerDiameter = _centerDiameter(radial, input.minGapBetweenButtons);

    return LayoutPlan(
      mode: LayoutMode.radialSingle,
      perPage: input.itemCount,
      rotationOffset: policy.rotationOffset,
      radial: radial,
      centerDiameter: centerDiameter,
      pages: [page],
    );
  }
}

class PagedRadialStrategy extends LayoutStrategy {
  const PagedRadialStrategy();

  @override
  LayoutPlan buildPlan(
    LayoutInputs input, {
    required LayoutPolicy policy,
    required LayoutFeasibility feasibility,
  }) {
    if (input.itemCount <= 0) return const LayoutPlan.empty();

    var perPage = math.max(1, policy.initialPerPage(input.itemCount));

    var radial = _computeRadialMetrics(
      countOnPage: perPage,
      input: input,
      policy: policy,
      feasibility: feasibility,
    );

    // Reduce per-page count until touch size is acceptable (same behavior as before).
    while (radial.buttonDiameter < policy.minTouchTargetDp && perPage > 4) {
      perPage -= 1;
      radial = _computeRadialMetrics(
        countOnPage: perPage,
        input: input,
        policy: policy,
        feasibility: feasibility,
      );
    }

    if (policy.shouldFallbackToList(radial.buttonDiameter)) {
      return const ListFallbackStrategy().buildPlan(
        input,
        policy: policy,
        feasibility: feasibility,
      );
    }

    final pages = _paginate(input.itemCount, perPage).map((indices) {
      return _buildRadialPage(
        indices: indices,
        count: indices.length,
        radial: radial,
        policy: policy,
        input: input,
      );
    }).toList(growable: false);

    final centerDiameter = _centerDiameter(radial, input.minGapBetweenButtons);

    return LayoutPlan(
      mode: (pages.length <= 1) ? LayoutMode.radialSingle : LayoutMode.radialPaged,
      perPage: perPage,
      rotationOffset: policy.rotationOffset,
      radial: radial,
      centerDiameter: centerDiameter,
      pages: pages,
    );
  }
}

class ListFallbackStrategy extends LayoutStrategy {
  final bool empty;
  const ListFallbackStrategy({this.empty = false});

  @override
  LayoutPlan buildPlan(
    LayoutInputs input, {
    required LayoutPolicy policy,
    required LayoutFeasibility feasibility,
  }) {
    if (empty || input.itemCount <= 0) return const LayoutPlan.empty();

    final indices = List.generate(input.itemCount, (i) => i, growable: false);
    final pages = <LayoutPage>[
      LayoutPage.list(indices: indices),
    ];

    return LayoutPlan(
      mode: LayoutMode.listFallback,
      perPage: input.itemCount,
      rotationOffset: policy.rotationOffset,
      radial: const RadialLayoutMetrics.empty(),
      centerDiameter: 0,
      pages: pages,
    );
  }
}

// -------------------------
// Core computations (shared helpers)
// -------------------------

RadialLayoutMetrics _computeRadialMetrics({
  required int countOnPage,
  required LayoutInputs input,
  required LayoutPolicy policy,
  required LayoutFeasibility feasibility,
}) {
  final maxScale = 1.0;
  final minScale = (policy.minTouchTargetDp / input.baseButtonDiameter)
      .clamp(0.0, 1.0)
      .toDouble();

  bool fits(double scale) {
    final d = input.baseButtonDiameter * scale;
    final rMax = input.maxSafeWheelRadiusForDiameter(d);
    return feasibility.canFitWithoutOverlap(
      count: countOnPage,
      itemDiameter: d,
      gap: input.minGapBetweenButtons * scale,
      maxAllowedRadius: rMax,
    );
  }

  double chosenScale = maxScale;
  if (!fits(chosenScale)) {
    if (!fits(minScale)) {
      chosenScale = minScale;
    } else {
      double low = minScale;
      double high = maxScale;
      for (int i = 0; i < 16; i++) {
        final mid = (low + high) / 2.0;
        if (fits(mid)) {
          low = mid;
        } else {
          high = mid;
        }
      }
      chosenScale = low;
    }
  }

  final diameter = input.baseButtonDiameter * chosenScale;
  final maxSafeRadius = input.maxSafeWheelRadiusForDiameter(diameter);
  final wheelRadius = feasibility
      .minRadiusRequired(
        count: countOnPage,
        itemDiameter: diameter,
        gap: input.minGapBetweenButtons * chosenScale,
      )
      .clamp(0.0, maxSafeRadius);

  return RadialLayoutMetrics(
    buttonScale: chosenScale,
    buttonDiameter: diameter,
    buttonRadius: diameter / 2.0,
    wheelRadius: wheelRadius,
    maxSafeRadius: maxSafeRadius,
  );
}

LayoutPage _buildRadialPage({
  required List<int> indices,
  required int count,
  required RadialLayoutMetrics radial,
  required LayoutPolicy policy,
  required LayoutInputs input,
}) {
  if (count <= 0) return const LayoutPage.list(indices: []);

  // Planner owns edge cases:
  // - 1 item: center
  // - 2-3 items: "balanced" radius (use max safe radius as before)
  // - >=4: computed wheel radius
  final normalizedRadius = switch (count) {
    1 => 0.0,
    2 || 3 => 1.0,
    _ => radial.maxSafeRadius <= 0 ? 0.0 : (radial.wheelRadius / radial.maxSafeRadius),
  };

  final angles = (count == 1)
      ? const <double>[0.0]
      : RadialLayoutEngine.evenAngles(count: count, rotationOffset: policy.rotationOffset);

  final positions = List.generate(
    count,
    (i) => LayoutItemPosition(
      index: indices[i],
      angle: angles[i],
      normalizedRadius: normalizedRadius,
    ),
    growable: false,
  );

  return LayoutPage.radial(indices: indices, positions: positions);
}

double _centerDiameter(RadialLayoutMetrics radial, double gap) {
  return math.max(0.0, (radial.wheelRadius - radial.buttonRadius - gap) * 2.0);
}

List<List<int>> _paginate(int itemCount, int perPage) {
  final pages = <List<int>>[];
  for (int start = 0; start < itemCount; start += perPage) {
    final end = math.min(start + perPage, itemCount);
    pages.add(List.generate(end - start, (i) => start + i, growable: false));
  }
  return pages;
}

// -------------------------
// Models (UI-agnostic)
// -------------------------

enum LayoutMode { radialSingle, radialPaged, listFallback }

class LayoutPlan {
  final LayoutMode mode;
  final int perPage;
  final double rotationOffset;
  final RadialLayoutMetrics radial;
  final double centerDiameter;
  final List<LayoutPage> pages;

  const LayoutPlan({
    required this.mode,
    required this.perPage,
    required this.rotationOffset,
    required this.radial,
    required this.centerDiameter,
    required this.pages,
  });

  const LayoutPlan.empty()
      : mode = LayoutMode.listFallback,
        perPage = 0,
        rotationOffset = 0,
        radial = const RadialLayoutMetrics.empty(),
        centerDiameter = 0,
        pages = const [];
}

enum LayoutPageKind { radial, list }

class LayoutPage {
  final LayoutPageKind kind;
  final List<int> indices;
  final List<LayoutItemPosition> positions; // only for radial

  const LayoutPage._({
    required this.kind,
    required this.indices,
    required this.positions,
  });

  const LayoutPage.radial({
    required List<int> indices,
    required List<LayoutItemPosition> positions,
  }) : this._(
          kind: LayoutPageKind.radial,
          indices: indices,
          positions: positions,
        );

  const LayoutPage.list({required List<int> indices})
      : this._(
          kind: LayoutPageKind.list,
          indices: indices,
          positions: const [],
        );
}

/// UI-agnostic polar position.
///
/// - [angle] in radians.
/// - [normalizedRadius] in 0..1 space, relative to the maximum safe radius.
class LayoutItemPosition {
  final int index;
  final double angle;
  final double normalizedRadius;

  const LayoutItemPosition({
    required this.index,
    required this.angle,
    required this.normalizedRadius,
  });
}

class RadialLayoutMetrics {
  final double buttonScale;
  final double buttonDiameter;
  final double buttonRadius;
  final double wheelRadius;
  final double maxSafeRadius;

  const RadialLayoutMetrics({
    required this.buttonScale,
    required this.buttonDiameter,
    required this.buttonRadius,
    required this.wheelRadius,
    required this.maxSafeRadius,
  });

  const RadialLayoutMetrics.empty()
      : buttonScale = 1,
        buttonDiameter = 0,
        buttonRadius = 0,
        wheelRadius = 0,
        maxSafeRadius = 0;
}

