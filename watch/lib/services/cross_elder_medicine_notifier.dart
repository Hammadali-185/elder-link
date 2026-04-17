import 'dart:async';

import 'package:flutter/foundation.dart';

import '../karachi_time.dart';
import 'api_service.dart';
import 'medicine_schedule_monitor.dart';
import 'music_player_service.dart';

/// Pending medicines exist for a **peer** elder (recent on this device) while the watch shows another.
class CrossElderPending {
  CrossElderPending({
    required this.targetElderId,
    required this.elderName,
    required this.pendingCount,
  });

  final String targetElderId;
  final String elderName;
  final int pendingCount;
}

/// Polls peer elders for pending medicines today; drives tap-to-switch banner (not dose-time alarms).
class CrossElderMedicineNotifier {
  CrossElderMedicineNotifier._();
  static final CrossElderMedicineNotifier instance = CrossElderMedicineNotifier._();

  final ValueNotifier<CrossElderPending?> pending = ValueNotifier<CrossElderPending?>(null);
  final ValueNotifier<bool> migrating = ValueNotifier<bool>(false);

  Timer? _timer;
  bool _started = false;
  bool _migrateInProgress = false;

  static const Duration _period = Duration(seconds: 35);

  void start() {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(_period, (_) => unawaited(_tick()));
    unawaited(_tick());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _started = false;
    pending.value = null;
    migrating.value = false;
  }

  static bool _isScheduledKarachiToday(WatchMedicine m) {
    final sk = utcInstantToKarachiWall(m.scheduledDate.toUtc());
    final scheduledDay = DateTime(sk.year, sk.month, sk.day);
    final now = nowKarachiWallClock();
    final today = DateTime(now.year, now.month, now.day);
    return scheduledDay == today;
  }

  Future<void> _tick() async {
    if (_migrateInProgress) return;
    final name = ApiService.userName?.trim();
    if (name == null || name.isEmpty) {
      pending.value = null;
      return;
    }

    final active = ApiService.activeElderMongoId?.trim();
    if (active == null || active.isEmpty) {
      pending.value = null;
      return;
    }

    if (MedicineScheduleMonitor.instance.activeMedicine.value != null) {
      return;
    }

    List<String> recent;
    List<String> serverIds;
    try {
      recent = await ApiService.getRecentElderMongoIds();
      serverIds = await ApiService.fetchElderMongoIdsFromServer();
    } catch (_) {
      return;
    }

    final ordered = <String>[];
    for (final id in recent) {
      final t = id.trim();
      if (t.isEmpty || t == active || ordered.contains(t)) continue;
      ordered.add(t);
    }
    for (final id in serverIds) {
      final t = id.trim();
      if (t.isEmpty || t == active || ordered.contains(t)) continue;
      ordered.add(t);
    }

    CrossElderPending? best;
    for (final eid in ordered) {
      if (eid == active) continue;
      List<WatchMedicine> list;
      try {
        list = await ApiService.getMedicinesForElderId(eid);
      } catch (_) {
        continue;
      }
      final pendingToday = list.where(
        (m) => m.status == 'pending' && _isScheduledKarachiToday(m),
      ).toList();
      if (pendingToday.isEmpty) continue;

      final elderName = pendingToday.first.elderName.trim().isNotEmpty
          ? pendingToday.first.elderName.trim()
          : 'Resident';
      final candidate = CrossElderPending(
        targetElderId: eid,
        elderName: elderName,
        pendingCount: pendingToday.length,
      );
      best ??= candidate;
    }

    pending.value = best;
  }

  /// Load elder from server, update My Info, sync, reset medicine monitor queue.
  Future<bool> migrateToPendingElder() async {
    final p = pending.value;
    if (p == null) return false;
    if (_migrateInProgress) return false;
    _migrateInProgress = true;
    migrating.value = true;
    try {
      final data = await ApiService.fetchElderById(p.targetElderId);
      if (data == null) return false;

      final newName = (data['name'] ?? '').toString().trim();
      if (newName.isEmpty) return false;

      final prevName = ApiService.userName?.trim() ?? '';
      if (prevName.isNotEmpty && prevName != newName) {
        await MusicPlayerService.instance.stop();
      }

      final ok = await ApiService.applyFetchedElderProfile(data);
      if (!ok) return false;

      MedicineScheduleMonitor.instance.onUserIdentityChanged();
      pending.value = null;
      unawaited(_tick());
      return true;
    } finally {
      _migrateInProgress = false;
      migrating.value = false;
    }
  }
}

