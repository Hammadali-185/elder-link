import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import '../services/api_service.dart';

class MedicineReminderScreen extends StatefulWidget {
  final VoidCallback? onBackTap;
  
  const MedicineReminderScreen({super.key, this.onBackTap});

  @override
  State<MedicineReminderScreen> createState() => _MedicineReminderScreenState();
}

class _MedicineReminderScreenState extends State<MedicineReminderScreen> {
  List<WatchMedicine> _medicines = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  Timer? _checkTimer;
  Set<String> _notifiedMedicines = {};

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    // Refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadMedicines();
    });
    // Check for new medicines every 10 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkForNewMedicines();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    try {
      final medicines = await ApiService.getMedicines(date: DateTime.now());
      if (mounted) {
        setState(() {
          _medicines = medicines;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkForNewMedicines() async {
    try {
      final medicines = await ApiService.getMedicines(date: DateTime.now());
      final previousIds = _medicines.map((m) => m.id).toSet();
      final currentIds = medicines.map((m) => m.id).toSet();
      
      // Check for newly added medicines
      for (final medicine in medicines) {
        if (!previousIds.contains(medicine.id) && medicine.status == 'pending') {
          // New medicine was just added - notify immediately
          _notifyNewMedicine(medicine);
          _notifiedMedicines.add(medicine.id);
        } else if (!_notifiedMedicines.contains(medicine.id) && medicine.status == 'pending') {
          // Check if it's time for the medicine (within 5 minutes of scheduled time)
          final now = DateTime.now();
          final scheduledTime = _parseTime(medicine.time);
          final currentTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
          final timeDifference = scheduledTime.difference(currentTime).inMinutes.abs();
          
          if (timeDifference <= 5) {
            // Notify user it's time to take medicine
            _notifyMedicine(medicine);
            _notifiedMedicines.add(medicine.id);
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _medicines = medicines;
        });
      }
    } catch (e) {
      print('Error checking medicines: $e');
    }
  }

  Future<void> _notifyNewMedicine(WatchMedicine medicine) async {
    // Vibrate pattern for new medicine
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 300, 100, 300, 100, 300], repeat: 0);
    }
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Show notification dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.blue,
          title: const Text(
            '💊 New Medicine Set',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medicine.medicineName,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Dosage: ${medicine.dosage}',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'Take at: ${medicine.time}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will be reminded at the scheduled time.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  Future<void> _notifyMedicine(WatchMedicine medicine) async {
    // Vibrate
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 200, 500], repeat: 0);
    }
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Show notification dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.blue,
          title: const Text(
            '💊 Medicine Reminder',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medicine.medicineName,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Dosage: ${medicine.dosage}',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'Time: ${medicine.time}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
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
        children: [
          // Back button
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
          // Content
          Center(
            child: SizedBox(
              width: 320,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                  : _medicines.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.medication_outlined, color: Colors.grey, size: 48),
                              SizedBox(height: 12),
                              Text(
                                'No medicines scheduled',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
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
                  : Colors.blue,
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
                color: isTaken ? Colors.green : isMissed ? Colors.red : Colors.blue,
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
