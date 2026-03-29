import 'package:flutter/material.dart';
import 'watch_back_button.dart';
import 'watch_scale.dart';
import 'watch_tokens.dart';

/// Structured scaffold for watch screens.
///
/// Phase 0 contract:
/// - Provides a top bar zone (optional back button + title)
/// - Provides a safe body zone constrained by [WatchScale.safeRect]
/// - Provides optional bottom actions
///
/// This does NOT require or refactor internal screen layouts.
class WatchScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final VoidCallback? onBack;
  final Widget? bottomActions;

  final WatchSafeTier bodyTier;
  final Alignment bodyAlignment;

  /// Optional padding applied inside the safeRect body bounds.
  /// Default: a small padding tuned for readability.
  final EdgeInsetsGeometry? bodyPadding;

  /// If false, top bar takes zero height even when [title]/[onBack] are provided.
  final bool reserveTopBar;

  const WatchScaffold({
    super.key,
    required this.body,
    this.title,
    this.onBack,
    this.bottomActions,
    this.bodyTier = WatchSafeTier.visual,
    this.bodyAlignment = Alignment.center,
    this.bodyPadding,
    this.reserveTopBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final ws = WatchScale.of(context);
    final spacing = WatchSpacing(ws);
    final type = WatchTypography(ws);

    final safeBodyRect = ws.safeRect(bodyTier);
    final showTopBar = reserveTopBar && (onBack != null || title != null);

    // Top bar height tokenized from spacing.
    final topBarHeight = showTopBar ? ws.space(56).clamp(46.0, 70.0) : 0.0;

    final defaultBodyPadding = EdgeInsets.symmetric(
      horizontal: spacing.md,
      vertical: spacing.sm,
    );

    return SizedBox(
      width: ws.canvasSize,
      height: ws.canvasSize,
      child: Column(
        children: [
          if (showTopBar)
            SizedBox(
              height: topBarHeight,
              child: Row(
                children: [
                  if (onBack != null)
                    Padding(
                      padding: EdgeInsets.only(left: spacing.sm),
                      child: WatchBackButton(onBack: onBack!),
                    ),
                  if (onBack == null) SizedBox(width: spacing.md),
                  Expanded(
                    child: Center(
                      child: title == null
                          ? const SizedBox.shrink()
                          : Text(
                              title!,
                              style: type.title(size: 18),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: safeBodyRect.width,
                height: safeBodyRect.height,
                child: Align(
                  alignment: bodyAlignment,
                  child: Padding(
                    padding: bodyPadding ?? defaultBodyPadding,
                    child: body,
                  ),
                ),
              ),
            ),
          ),
          if (bottomActions != null)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: bottomActions!,
            ),
        ],
      ),
    );
  }
}

