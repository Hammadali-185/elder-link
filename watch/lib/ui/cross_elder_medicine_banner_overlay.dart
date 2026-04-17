import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/cross_elder_medicine_notifier.dart';
import '../services/medicine_schedule_monitor.dart';

/// Tap-only banner (no swipe dismiss). Hidden while a dose-time alarm overlay is active.
class CrossElderMedicineBannerOverlay extends StatelessWidget {
  const CrossElderMedicineBannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final n = CrossElderMedicineNotifier.instance;
    return ValueListenableBuilder<WatchMedicine?>(
      valueListenable: MedicineScheduleMonitor.instance.activeMedicine,
      builder: (context, doseAlarm, _) {
        if (doseAlarm != null) return const SizedBox.shrink();
        return ValueListenableBuilder<CrossElderPending?>(
          valueListenable: n.pending,
          builder: (context, pending, _) {
            if (pending == null) return const SizedBox.shrink();
            return ValueListenableBuilder<bool>(
              valueListenable: n.migrating,
              builder: (context, busy, __) {
                return Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: Material(
                        color: const Color(0xFFE65100).withOpacity(0.96),
                        borderRadius: BorderRadius.circular(10),
                        elevation: 6,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: busy
                              ? null
                              : () async {
                                  await n.migrateToPendingElder();
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  busy ? Icons.hourglass_top : Icons.medication_liquid,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        pending.pendingCount == 1
                                            ? 'Medicine for ${pending.elderName}'
                                            : '${pending.pendingCount} medicines for ${pending.elderName}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        busy ? 'Switching…' : 'Tap to switch to this resident',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.92),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (busy)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(Icons.touch_app, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
