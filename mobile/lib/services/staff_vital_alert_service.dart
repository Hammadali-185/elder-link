import 'package:shared_preferences/shared_preferences.dart';

import 'alerts_resolved_prefs.dart';
import 'api_service.dart';
import 'notification_service.dart';

/// Deduplicates staff local notifications for abnormal vitals / panic across the app.
/// IDs are persisted so cold starts do not re-fire alerts for the same readings.
class StaffVitalAlertService {
  static const String _notifiedIdsPrefKey = 'staff_vital_notified_reading_ids';
  static const int _maxTrackedIds = 800;

  /// Call when fresh [readings] are loaded (e.g. dashboard or staff-wide poll).
  static Future<void> processReadings(List<Reading> readings) async {
    final prefs = await SharedPreferences.getInstance();
    final order = List<String>.from(prefs.getStringList(_notifiedIdsPrefKey) ?? []);
    final notified = order.toSet();

    final resolvedList = prefs.getStringList(AlertsResolvedPrefs.resolvedKeysPrefKey);
    final resolved = resolvedList?.toSet() ?? <String>{};

    var changed = false;

    for (final reading in readings) {
      if (reading.id.isEmpty) continue;
      if (resolved.contains(AlertsResolvedPrefs.readingKey(reading))) continue;
      if (notified.contains(reading.id)) continue;

      final personName = reading.personName ?? reading.username;
      if (personName.isEmpty || personName == 'Watch User') continue;

      if (reading.emergency) {
        await NotificationService.sendPanicAlert(
          personName: personName,
          timestamp: reading.timestamp,
        );
      } else if (reading.vitalsUrgent) {
        await NotificationService.sendCriticalVitalsAlert(
          personName: personName,
          alertReason: reading.alertReason ?? 'CRITICAL BLOOD PRESSURE',
          timestamp: reading.timestamp,
          systolic: reading.bp,
          diastolic: reading.bpDiastolic,
          heartRate: reading.heartRate > 0 ? reading.heartRate : null,
        );
      } else if (reading.status == 'abnormal') {
        final reason = reading.alertReason?.trim();
        if (reason != null && reason.isNotEmpty) {
          await NotificationService.sendVitalsWarningAlert(
            personName: personName,
            alertReason: reason,
            timestamp: reading.timestamp,
            systolic: reading.bp,
            diastolic: reading.bpDiastolic,
            heartRate: reading.heartRate > 0 ? reading.heartRate : null,
          );
        } else {
          await NotificationService.sendHealthAlert(
            personName: personName,
            status: reading.status,
            bp: reading.bp,
            heartRate: reading.heartRate > 0 ? reading.heartRate : null,
            timestamp: reading.timestamp,
          );
        }
      } else {
        continue;
      }

      if (notified.add(reading.id)) {
        order.add(reading.id);
        changed = true;
        while (order.length > _maxTrackedIds) {
          final old = order.removeAt(0);
          notified.remove(old);
          changed = true;
        }
      }
    }

    if (changed) {
      await prefs.setStringList(_notifiedIdsPrefKey, order);
    }
  }
}
