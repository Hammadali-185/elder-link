import 'dart:async';

import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Medicine list only; dose alarms are handled app-wide by MedicineScheduleMonitor.
class MedicineReminderScreen extends StatefulWidget {
  final VoidCallback? onBackTap;

  const MedicineReminderScreen({super.key, this.onBackTap});

  @override
  State<MedicineReminderScreen> createState() => _MedicineReminderScreenState();
}

class _MedicineReminderScreenState extends State<MedicineReminderScreen> {
  List<WatchMedicine> _medicines = [];
  String? _loadError;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadMedicines();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    try {
      final medicines = await ApiService.getMedicines(date: DateTime.now());
      if (!mounted) return;
      setState(() {
        _medicines = medicines;
        _loadError = ApiService.lastMedicinesFetchError;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsTaken(WatchMedicine medicine) async {
    final success = await ApiService.updateMedicineStatus(medicine.id, 'taken');
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine marked as taken'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _loadMedicines();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsMissed(WatchMedicine medicine) async {
    final success = await ApiService.updateMedicineStatus(medicine.id, 'missed');
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine marked as missed'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        _loadMedicines();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        shape: BoxShape.circle,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: SizedBox(
              width: 320,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white70))
                  : _medicines.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _loadError != null ? Icons.cloud_off : Icons.medication_outlined,
                                  color: _loadError != null ? Colors.orange : Colors.grey,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _loadError != null
                                      ? 'Can\'t reach server'
                                      : 'No medicines scheduled',
                                  style: TextStyle(
                                    color: _loadError != null ? Colors.orange : Colors.grey,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (_loadError != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _loadError!,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    textAlign: TextAlign.center,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 60, bottom: 20),
                          child: Column(
                            children: [
                              const Text(
                                'Medicines',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._medicines.map((medicine) => _buildMedicineCard(medicine)),
                            ],
                          ),
                        ),
            ),
          ),
          Positioned(
            top: 28,
            left: 28,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onBackTap,
                borderRadius: BorderRadius.circular(25),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.2),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(WatchMedicine medicine) {
    final isTaken = medicine.status == 'taken';
    final isMissed = medicine.status == 'missed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTaken
              ? Colors.green
              : isMissed
                  ? Colors.red
                  : Colors.white70,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medication,
                color: isTaken ? Colors.green : isMissed ? Colors.red : Colors.white70,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  medicine.medicineName,
                  style: TextStyle(
                    color: isTaken ? Colors.green : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: isTaken ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (isTaken)
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dosage: ${medicine.dosage}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Text(
            'Time: ${medicine.time}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (!isTaken && !isMissed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'TAKEN',
                    Colors.green,
                    () => _markAsTaken(medicine),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'MISSED',
                    Colors.red,
                    () => _markAsMissed(medicine),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
