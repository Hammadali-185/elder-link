import 'package:flutter/material.dart';
import 'watch_scale.dart';
import 'watch_tokens.dart';

/// Reusable back button for the watch UI.
///
/// Intended to be used by [WatchScaffold] top bar zone.
class WatchBackButton extends StatelessWidget {
  final VoidCallback onBack;
  final Color iconColor;

  const WatchBackButton({
    super.key,
    required this.onBack,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final ws = WatchScale.of(context);
    final icons = WatchIconSizes(ws);

    // Hit target: tuned for the 360 base design, clamped to keep it usable.
    // (This clamp is on touch target size, not the watch scaling itself.)
    final hit = ws.space(44).clamp(40.0, 52.0);
    final iconSize = icons.sm; // ~18 on 360

    return SizedBox(
      width: hit,
      height: hit,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(hit / 2),
          splashColor: Colors.white.withOpacity(0.25),
          highlightColor: Colors.white.withOpacity(0.15),
          child: Center(
            child: Icon(
              Icons.arrow_back_ios,
              color: iconColor,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

