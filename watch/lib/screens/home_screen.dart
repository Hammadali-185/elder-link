import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../ui/home_layout_planner.dart';
import '../ui/radial_layout_engine.dart';
import '../ui/watch_scale.dart';
import '../ui/watch_scaffold.dart';
import '../ui/watch_tokens.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onSettingsTap;
  final Function(int)? onNavigateToScreen;
  
  const HomeScreen({super.key, this.onSettingsTap, this.onNavigateToScreen});

  static const Color _centerMint = Color(0xFF6BB86B); // Deeper mint than #90EE90
  static const double _minTouchTargetDp = 40.0; // strict minimum touch target
  static const double _rotationOffset = -math.pi / 2; // start at top

  @override
  Widget build(BuildContext context) {
    final scale = WatchScale.of(context);
    final spacing = WatchSpacing(scale);
    final typography = WatchTypography(scale);
    final iconSizes = WatchIconSizes(scale);

    final items = _buildWheelItems(onNavigateToScreen);

    // Planning inputs: all derived from WatchScale/tokens.
    final baseButtonDiameter = iconSizes.xl;
    final minGapBetweenButtons = spacing.sm;
    final panicTap =
        onNavigateToScreen != null ? () => onNavigateToScreen!(7) : () {};

    const maxButtonsSafe = 10; // policy: do not shrink indefinitely
    const maxButtonsPerPage = 8; // policy: paged wheel upper bound

    final planner = HomeLayoutPlanner.defaults(
      minTouchTargetDp: _minTouchTargetDp,
      maxButtonsSafe: maxButtonsSafe,
      maxButtonsPerPage: maxButtonsPerPage,
      rotationOffset: _rotationOffset,
    );

    final plan = planner.plan(
      LayoutInputs(
        itemCount: items.length,
        baseButtonDiameter: baseButtonDiameter,
        minGapBetweenButtons: minGapBetweenButtons,
        maxSafeWheelRadiusForDiameter: (d) =>
            scale.safeCenterRadius(WatchSafeTier.touch, elementRadius: d / 2.0),
      ),
    );

    // Derive whether center UI can be shown (avoid meaningless tiny center).
    final labelStyle = typography.title(color: Colors.black87);
    final labelFontSize = (labelStyle.fontSize ?? scale.font(20));
    final labelLineHeight = (labelStyle.height ?? 1.15) * labelFontSize;
    final minCenterContentDiameter =
        plan.radial.buttonDiameter + spacing.md + labelLineHeight + spacing.sm;

    final showCenterUI = plan.centerDiameter >= minCenterContentDiameter;

    // Debug warnings for degraded modes.
    assert(() {
      if (plan.mode != LayoutMode.radialSingle) {
        // ignore: avoid_print
        debugPrint(
          '[WATCH][HomeScreen] Mode=${plan.mode} pages=${plan.pages.length} '
          'perPage=${plan.perPage} button=${plan.radial.buttonDiameter.toStringAsFixed(1)} '
          'wheelR=${plan.radial.wheelRadius.toStringAsFixed(1)}',
        );
      }
      if (plan.radial.buttonDiameter < _minTouchTargetDp) {
        // ignore: avoid_print
        debugPrint(
          '[WATCH][HomeScreen][WARN] Touch target violated: '
          '${plan.radial.buttonDiameter.toStringAsFixed(1)} < $_minTouchTargetDp',
        );
      }
      return true;
    }());

    return ColoredBox(
      color: Colors.white,
      child: WatchScaffold(
        // Home has no back button.
        reserveTopBar: false,
        bodyTier: WatchSafeTier.visual,
        bodyPadding: EdgeInsets.zero,
        body: _HomeView(
          scale: scale,
          spacing: spacing,
          typography: typography,
          iconSizes: iconSizes,
          plan: plan,
          showCenterUI: showCenterUI,
          items: items,
          panicTap: panicTap,
        ),
      ),
    );
  }

  List<WheelItem> _buildWheelItems(Function(int)? navigate) {
    // Specs are stable; only callbacks depend on navigation.
    final specs = <_WheelSpec>[
      const _WheelSpec(
        kind: _WheelSpecKind.image,
        imageAsset: 'symbol.jpeg',
        label: 'App',
        color: Color(0xFFF5F5F5),
        screenIndex: null,
        decorative: true,
      ),
      const _WheelSpec(
        kind: _WheelSpecKind.icon,
        icon: Icons.medication,
        label: 'Medicine',
        color: Color(0xFFBDBDBD),
        screenIndex: 2,
      ),
      const _WheelSpec(
        kind: _WheelSpecKind.icon,
        icon: Icons.access_time,
        label: 'Clock',
        color: Color(0xFFFF8C00),
        screenIndex: 3,
      ),
      const _WheelSpec(
        kind: _WheelSpecKind.icon,
        icon: Icons.person,
        label: 'My Info',
        color: Color(0xFF6C757D),
        screenIndex: 4,
      ),
      const _WheelSpec(
        kind: _WheelSpecKind.icon,
        icon: Icons.music_note,
        label: 'Music',
        color: Color(0xFFE0E0E0),
        screenIndex: 5,
      ),
      const _WheelSpec(
        kind: _WheelSpecKind.icon,
        icon: Icons.settings,
        label: 'Settings',
        color: Color(0xFF9E9E9E),
        screenIndex: 8,
      ),
      const _WheelSpec(
        kind: _WheelSpecKind.icon,
        icon: Icons.favorite,
        label: 'Health',
        color: Color(0xFF28A745),
        screenIndex: 6,
      ),
    ];

    return specs
        .map(
          (s) => WheelItem(
            icon: s.icon,
            imageAsset: s.imageAsset,
            color: s.color,
            decorative: s.decorative,
            label: s.label,
            onTap: s.screenIndex == null
                ? () {}
                : (navigate != null ? () => navigate(s.screenIndex!) : () {}),
          ),
        )
        .toList(growable: false);
  }
}

enum _WheelSpecKind { icon, image }

class _WheelSpec {
  final _WheelSpecKind kind;
  final IconData? icon;
  final String? imageAsset;
  final String label;
  final Color color;
  final int? screenIndex;
  final bool decorative;

  const _WheelSpec({
    required this.kind,
    this.icon,
    this.imageAsset,
    required this.label,
    required this.color,
    required this.screenIndex,
    this.decorative = false,
  }) : assert(kind != _WheelSpecKind.icon || icon != null),
       assert(kind != _WheelSpecKind.image || imageAsset != null);
}

class _HomeView extends StatefulWidget {
  final WatchScale scale;
  final WatchSpacing spacing;
  final WatchTypography typography;
  final WatchIconSizes iconSizes;
  final LayoutPlan plan;
  final bool showCenterUI;
  final List<WheelItem> items;
  final VoidCallback panicTap;

  const _HomeView({
    required this.scale,
    required this.spacing,
    required this.typography,
    required this.iconSizes,
    required this.plan,
    required this.showCenterUI,
    required this.items,
    required this.panicTap,
  });

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant _HomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.mode != widget.plan.mode ||
        oldWidget.plan.pages.length != widget.plan.pages.length) {
      _syncController();
    }
  }

  void _syncController() {
    final needsPaging =
        widget.plan.mode == LayoutMode.radialPaged && widget.plan.pages.length > 1;
    if (!needsPaging) {
      _pageController?.dispose();
      _pageController = null;
      return;
    }
    _pageController ??= PageController();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _HomePlanRenderer(
      scale: widget.scale,
      spacing: widget.spacing,
      typography: widget.typography,
      iconSizes: widget.iconSizes,
      plan: widget.plan,
      items: widget.items,
      showCenterUI: widget.showCenterUI,
      panicTap: widget.panicTap,
      controller: _pageController,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        final scale = Tween<double>(begin: 0.98, end: 1.0).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey('${widget.plan.mode}|${widget.plan.pages.length}'),
        child: child,
      ),
    );
  }
}

class _HomePlanRenderer extends StatelessWidget {
  final WatchScale scale;
  final WatchSpacing spacing;
  final WatchTypography typography;
  final WatchIconSizes iconSizes;
  final LayoutPlan plan;
  final List<WheelItem> items;
  final bool showCenterUI;
  final VoidCallback panicTap;
  final PageController? controller;

  const _HomePlanRenderer({
    required this.scale,
    required this.spacing,
    required this.typography,
    required this.iconSizes,
    required this.plan,
    required this.items,
    required this.showCenterUI,
    required this.panicTap,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (plan.pages.isEmpty) return const SizedBox.shrink();

    if (plan.mode == LayoutMode.listFallback) {
      return _ListFallbackHome(
        scale: scale,
        spacing: spacing,
        type: typography,
        icons: iconSizes,
        plan: plan,
        items: items,
        panicTap: panicTap,
      );
    }

    if (plan.mode == LayoutMode.radialSingle || plan.pages.length == 1) {
      return _RadialHomeWheel(
        scale: scale,
        spacing: spacing,
        type: typography,
        icons: iconSizes,
        plan: plan,
        showCenterUI: showCenterUI,
        controller: controller,
        items: items,
        panicTap: panicTap,
      );
    }

    return _RadialHomeWheel(
      scale: scale,
      spacing: spacing,
      type: typography,
      icons: iconSizes,
      plan: plan,
      showCenterUI: showCenterUI,
      controller: controller,
      items: items,
      panicTap: panicTap,
    );
  }
}

class _RadialHomeWheel extends StatelessWidget {
  final WatchScale scale;
  final WatchSpacing spacing;
  final WatchTypography type;
  final WatchIconSizes icons;
  final LayoutPlan plan;
  final bool showCenterUI;
  final PageController? controller;
  final List<WheelItem> items;
  final VoidCallback panicTap;

  const _RadialHomeWheel({
    required this.scale,
    required this.spacing,
    required this.type,
    required this.icons,
    required this.plan,
    required this.showCenterUI,
    required this.controller,
    required this.items,
    required this.panicTap,
  });

  @override
  Widget build(BuildContext context) {
    final center = Offset(scale.canvasSize / 2.0, scale.canvasSize / 2.0);

    Widget buildPage(LayoutPage page) {
      final pageItems = page.indices.map((i) => items[i]).toList(growable: false);

      // UI is dumb: uses planner-provided normalized polar positions.
      // Convert normalized radius into pixel radius using current safe radius.
      final radiusPx = plan.radial.maxSafeRadius;

      Widget radialButton(int localIndex) {
        final item = pageItems[localIndex];
        final pos = page.positions[localIndex];
        final cart = RadialLayoutEngine.toCartesian(
          angle: pos.angle,
          radius: (pos.normalizedRadius.clamp(0.0, 1.0)) * radiusPx,
        );
        return Positioned(
          left: center.dx + cart.dx - plan.radial.buttonRadius,
          top: center.dy + cart.dy - plan.radial.buttonRadius,
          child: _RadialCircleButton(
            diameter: plan.radial.buttonDiameter,
            color: item.color,
            icon: item.icon,
            imageAsset: item.imageAsset,
            onTap: item.onTap,
            decorative: item.decorative,
            iconSize: icons.lg * plan.radial.buttonScale,
          ),
        );
      }

      return Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: plan.centerDiameter,
              height: plan.centerDiameter,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: HomeScreen._centerMint,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.06),
                    ],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          for (var i = 0; i < pageItems.length; i++) radialButton(i),
          // Panic must always show on radial home; showCenterUI only gates the title.
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCenterUI) ...[
                  Text(
                    'Elder Mode',
                    style: type.title(color: Colors.black87),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.md),
                ],
                _RadialCircleButton(
                  diameter: plan.radial.buttonDiameter > 0
                      ? plan.radial.buttonDiameter
                      : math.max(HomeScreen._minTouchTargetDp, icons.xl),
                  color: const Color(0xFFDC3545),
                  icon: Icons.warning,
                  iconSize: icons.lg *
                      (plan.radial.buttonScale > 0 ? plan.radial.buttonScale : 1.0),
                  onTap: panicTap,
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (plan.pages.isEmpty) {
      return const SizedBox.shrink();
    }

    if (plan.mode == LayoutMode.radialSingle || plan.pages.length == 1) {
      return buildPage(plan.pages.single);
    }

    return PageView.builder(
      controller: controller,
      itemCount: plan.pages.length,
      itemBuilder: (context, index) => buildPage(plan.pages[index]),
    );
  }
}

class _ListFallbackHome extends StatelessWidget {
  final WatchScale scale;
  final WatchSpacing spacing;
  final WatchTypography type;
  final WatchIconSizes icons;
  final LayoutPlan plan;
  final List<WheelItem> items;
  final VoidCallback panicTap;

  const _ListFallbackHome({
    required this.scale,
    required this.spacing,
    required this.type,
    required this.icons,
    required this.plan,
    required this.items,
    required this.panicTap,
  });

  @override
  Widget build(BuildContext context) {
    // SafeRect visual tier for readable list UI
    final rect = scale.safeRect(WatchSafeTier.visual);

    final flatItems = plan.pages
        .expand((p) => p.indices)
        .map((i) => items[i])
        .toList(growable: false);

    return Center(
      child: SizedBox(
        width: rect.width,
        height: rect.height,
        child: Column(
          children: [
            Text('Elder Mode', style: type.title(color: Colors.black87)),
            SizedBox(height: spacing.sm),
            _RadialCircleButton(
              diameter: math.max(HomeScreen._minTouchTargetDp, icons.xl),
              color: const Color(0xFFDC3545),
              icon: Icons.warning,
              iconSize: icons.lg,
              onTap: panicTap,
            ),
            SizedBox(height: spacing.md),
            Expanded(
              child: ListView.separated(
                itemCount: flatItems.length,
                separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
                itemBuilder: (context, i) {
                  final item = flatItems[i];
                  return _ListTileButton(
                    item: item,
                    minTouch: HomeScreen._minTouchTargetDp,
                    iconSize: icons.md,
                    textStyle: type.body(color: Colors.black87),
                    spacing: spacing,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTileButton extends StatelessWidget {
  final WheelItem item;
  final double minTouch;
  final double iconSize;
  final TextStyle textStyle;
  final WatchSpacing spacing;

  const _ListTileButton({
    required this.item,
    required this.minTouch,
    required this.iconSize,
    required this.textStyle,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: minTouch,
      child: Material(
        color: item.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(spacing.md),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(spacing.md),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.md),
            child: Row(
              children: [
                if (item.imageAsset != null)
                  ClipOval(
                    child: Image.asset(
                      item.imageAsset!,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Icon(item.icon, color: item.color, size: iconSize),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    item.label,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WheelItem {
  final IconData? icon;
  final String? imageAsset;
  final Color color;
  final VoidCallback onTap;
  final bool decorative;
  final String label;

  const WheelItem({
    this.icon,
    this.imageAsset,
    required this.color,
    required this.onTap,
    this.decorative = false,
    this.label = '',
  }) : assert(icon != null || imageAsset != null);
}

// NOTE:
// HomeScreen previously embedded planner + math engine types inside this file.
// Those responsibilities are now moved to:
// - `ui/home_layout_planner.dart` (pure planning + models)
// - `ui/radial_layout_engine.dart` (pure geometry math)

class _RadialCircleButton extends StatelessWidget {
  final double diameter;
  final Color color;
  final IconData? icon;
  final String? imageAsset;
  final double iconSize;
  final VoidCallback onTap;

  /// If true, reduces the visual emphasis slightly (still tappable).
  final bool decorative;

  const _RadialCircleButton({
    required this.diameter,
    required this.color,
    required this.onTap,
    required this.iconSize,
    this.icon,
    this.imageAsset,
    this.decorative = false,
  });

  @override
  Widget build(BuildContext context) {
    final ws = WatchScale.of(context);
    final spacing = WatchSpacing(ws);
    final borderWidth = ws.space(2);
    final bg = decorative ? color.withOpacity(0.16) : color.withOpacity(0.20);
    final innerPadding = spacing.xs;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(diameter / 2),
        splashColor: color.withOpacity(0.25),
        highlightColor: color.withOpacity(0.12),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: color, width: borderWidth),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: imageAsset != null
                ? Padding(
                    padding: EdgeInsets.all(innerPadding),
                    child: ClipOval(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: Image.asset(imageAsset!),
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: color,
                    size: iconSize,
                  ),
          ),
        ),
      ),
    );
  }
}
