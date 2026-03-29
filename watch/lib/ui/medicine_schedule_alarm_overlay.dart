import 'package:flutter/material.dart';

import '../services/medicine_schedule_monitor.dart';
import '../services/api_service.dart';

/// Drawn **outside** [WatchFrame] so [ClipOval] does not cut off buttons.
/// Place as a direct child of a [Stack] (this widget returns [Positioned.fill] when active).
class MedicineScheduleAlarmOverlay extends StatelessWidget {
  const MedicineScheduleAlarmOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WatchMedicine?>(
      valueListenable: MedicineScheduleMonitor.instance.activeMedicine,
      builder: (context, m, _) {
        if (m == null) return const SizedBox.shrink();
        return Positioned.fill(
          child: Material(
            color: Colors.black.withOpacity(0.94),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_active, color: Colors.amber.shade400, size: 44),
                          const SizedBox(height: 8),
                          const Text(
                            'MEDICINE TIME',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            m.medicineName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Time: ${m.time}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.orange.shade200,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Dosage: ${m.dosage}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 15),
                          ),
                          const SizedBox(height: 20),
                          // Primary: stop sound/vibration — largest, impossible to miss
                          SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                elevation: 6,
                                textStyle: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              onPressed: () => MedicineScheduleMonitor.instance.stopAlarmOnly(),
                              child: const Text('STOP ALARM'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Alarm keeps until you tap STOP, Taken, or Dismiss',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade800,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              icon: const Icon(Icons.check_circle, size: 26),
                              label: const Text('Taken'),
                              onPressed: () async {
                                await MedicineScheduleMonitor.instance.acknowledgeTaken();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Marked as taken'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade200,
                                side: BorderSide(color: Colors.orange.shade400, width: 2),
                                textStyle: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              icon: const Icon(Icons.close, size: 26),
                              label: const Text('Dismiss'),
                              onPressed: () => MedicineScheduleMonitor.instance.acknowledgeDismiss(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
