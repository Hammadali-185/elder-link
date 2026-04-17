import 'api_service.dart';

/// Anonymous / legacy watch rows staff should not see as real residents (dashboard, alerts).
bool isStaffWatchPlaceholder(Reading r) {
  final u = r.username.trim().toLowerCase();
  if (u == 'watch user' || u == 'watch_pending_init') return true;
  final pn = (r.personName ?? '').trim().toLowerCase();
  if (pn == 'watch user') return true;
  return false;
}

/// Dashboard snapshot: last 24h and no watch placeholders.
List<Reading> readingsForStaffDashboard(List<Reading> raw) {
  final cutoff = DateTime.now().subtract(const Duration(hours: 24));
  return raw.where((r) {
    if (isStaffWatchPlaceholder(r)) return false;
    return !r.timestamp.isBefore(cutoff);
  }).toList();
}
