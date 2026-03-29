import 'package:flutter/material.dart';
import 'watch_scale.dart';

/// Root wrapper that enforces the circular watch canvas and provides [WatchScale].
///
/// Phase 0:
/// - Uses MediaQuery to compute shortestSide
/// - Clamps the canvas size to 300..420 logical px via [WatchScale]
/// - Clips content to a perfect circle via [ClipOval]
/// - Injects [WatchScale] through an inherited widget provider
class WatchFrame extends StatelessWidget {
  final Widget child;

  /// Optional background color. Screens usually already paint their own.
  final Color backgroundColor;

  /// Optional overlay widget (e.g. dimmer for brightness).
  final Widget? overlay;

  const WatchFrame({
    super.key,
    required this.child,
    this.backgroundColor = Colors.transparent,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final shortestSide = media.size.shortestSide;
    final watchScale = WatchScale.fromCanvasSize(shortestSide);

    final size = watchScale.canvasSize;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: ColoredBox(
            color: backgroundColor,
            child: WatchScaleProvider(
              data: watchScale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  if (overlay != null) overlay!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

