import 'dart:async';

import 'package:flutter/foundation.dart';

import '../karachi_time.dart';
import 'alert_service.dart';
import 'api_service.dart';

/// Polls medicines in the background and fires [AlertService] when **Asia/Karachi**
/// wall time reaches each pending dose `HH:mm` (not when staff adds a medicine).
///
/// UI listens to [activeMedicine]; alarm runs on any screen until user acts.
class MedicineScheduleMonitor {
  MedicineScheduleMonitor._();
  static final MedicineScheduleMonitor instance = MedicineScheduleMonitor._();

  /// Currently shown dose; null = no overlay.
  final ValueNotifier<WatchMedicine?> activeMedicine = ValueNotifier<WatchMedicine?>(null);

  /// Pending dose alarms after the current one (same due window).
  final ValueNotifier<int> medicineQueuedCount = ValueNotifier<int>(0);

  final List<WatchMedicine> _queue = <WatchMedicine>[];

  void _syncQueueCount() {
    medicineQueuedCount.value = _queue.length;
  }

  /// One alert per medicine + calendar day + scheduled HH:mm.
  final Set<String> _firedSlotKeys = <String>{};

  Timer? _timer;
  bool _started = false;

  /// How long after the scheduled minute we still consider "due" (covers poll interval).
  static const int _dueWindowMinutes = 5;

  void start() {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_tick()));
    unawaited(_tick());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _started = false;
    unawaited(AlertService.stopAlert());
  }

  /// Call after My Info name changes so keys/queue reset for the new elder.
  void onUserIdentityChanged() {
    _firedSlotKeys.clear();
    _queue.clear();
    _syncQueueCount();
    if (activeMedicine.value != null) {
      unawaited(AlertService.stopAlert());
      activeMedicine.value = null;
    }
  }

  Future<void> _tick() async {
    final activeId = ApiService.activeElderMongoId?.trim();
    if (activeId == null || activeId.isEmpty) return;

    final now = nowKarachiWallClock();
    final today = DateTime(now.year, now.month, now.day);

    List<WatchMedicine> list;
    try {
      list = await ApiService.getMedicines();
    } catch (_) {
      return;
    }

    for (final m in list) {
      if (m.status != 'pending') continue;

      final sk = utcInstantToKarachiWall(m.scheduledDate.toUtc());
      final scheduledDay = DateTime(sk.year, sk.month, sk.day);
      if (scheduledDay != today) continue;

      if (!_isNowInDueWindow(m.time, now)) continue;

      final key = _slotKey(m, today);
      if (_firedSlotKeys.contains(key)) continue;
      _firedSlotKeys.add(key);
      _enqueue(m);
    }
  }

  static bool _isNowInDueWindow(String timeStr, DateTime now) {
    final parts = timeStr.trim().split(':');
    if (parts.length < 2) return false;
    final h = int.tryParse(parts[0].trim());
    final min = int.tryParse(parts[1].trim().split(RegExp(r'\s')).first);
    if (h == null || min == null) return false;
    if (h < 0 || h > 23 || min < 0 || min > 59) return false;

    final start = DateTime(now.year, now.month, now.day, h, min);
    final end = start.add(const Duration(minutes: _dueWindowMinutes));
    return !now.isBefore(start) && now.isBefore(end);
  }

  static String _slotKey(WatchMedicine m, DateTime day) {
    final t = m.time.trim();
    return '${m.id}_${day.year}-${day.month}-${day.day}_$t';
  }

  void _enqueue(WatchMedicine m) {
    if (activeMedicine.value != null) {
      _queue.add(m);
      return;
    }
    activeMedicine.value = m;
    unawaited(AlertService.startAlert());
  }

  /// Stops sound + vibration only; overlay stays until Taken / Dismiss.
  Future<void> stopAlarmOnly() async {
    await AlertService.stopAlert();
  }

  Future<void> acknowledgeTaken() async {
    final m = activeMedicine.value;
    if (m == null) return;
    await AlertService.stopAlert();
    await ApiService.updateMedicineStatus(m.id, 'taken');
    activeMedicine.value = null;
    _presentNextQueued();
  }

  Future<void> acknowledgeDismiss() async {
    final m = activeMedicine.value;
    if (m == null) return;
    await AlertService.stopAlert();
    activeMedicine.value = null;
    _presentNextQueued();
  }

  void _presentNextQueued() {
    if (_queue.isEmpty) {
      _syncQueueCount();
      return;
    }
    final next = _queue.removeAt(0);
    activeMedicine.value = next;
    _syncQueueCount();
    unawaited(AlertService.startAlert());
  }
}
