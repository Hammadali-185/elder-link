import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Keys for alert rows marked resolved on [AlertsScreen]; dashboard uses the same set.
class AlertsResolvedPrefs {
  AlertsResolvedPrefs._();

  static const String resolvedKeysPrefKey = 'alerts_resolved_keys';

  static String readingKey(Reading r) =>
      '${r.id}_${r.timestamp.millisecondsSinceEpoch}';

  /// Bumped after resolved keys are written so [DashboardScreen] can refresh the badge without waiting for its poll timer.
  static final ValueNotifier<int> resolvedKeysRevision = ValueNotifier(0);

  static void markResolvedKeysChanged() {
    resolvedKeysRevision.value++;
  }
}
