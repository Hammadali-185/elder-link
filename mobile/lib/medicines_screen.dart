import 'package:flutter/material.dart';
import 'dart:async';
import 'account_settings_screen.dart';
import 'services/api_service.dart';
import 'widgets/avatar_widget.dart';

class MedicinesScreen extends StatefulWidget {
  final String? staffName;
  
  const MedicinesScreen({super.key, this.staffName});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  List<Medicine> _medicines = [];
  List<Elder> _elders = [];
  String? _selectedElder;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadMedicines();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadElders(),
      _loadMedicines(),
    ]);
  }

  Future<void> _loadElders() async {
    try {
      // Get both manually added elders and watch users from readings
      final manualElders = await ApiService.getAllElders();
      final readings = await ApiService.getAllReadings();
      
      print('Medicines Screen - Loading elders:');
      print('  Manual elders: ${manualElders.length}');
      print('  Readings: ${readings.length}');
      
      // Extract unique elders from readings (watch users)
      final Set<String> elderNames = {};
      final List<Elder> allElders = List.from(manualElders);
      
      // First, add all manual elder names to the set
      for (final elder in manualElders) {
        elderNames.add(elder.name);
      }
      
      // Then, add watch users from readings
      for (final reading in readings) {
        final name = reading.personName ?? reading.username;
        if (name.isNotEmpty && name != 'Watch User' && !elderNames.contains(name)) {
          elderNames.add(name);
          // Check if this elder is already in manual elders
          final exists = manualElders.any((e) => e.name == name);
          if (!exists) {
            // Create an Elder object from reading data
            allElders.add(Elder(
              id: reading.id,
              name: name,
              roomNumber: reading.roomNumber ?? '',
              age: reading.age ?? '',
              disease: reading.disease,
              status: reading.emergency || reading.status == 'abnormal' ? 'need_attention' : 'stable',
              gender: reading.gender ?? 'Male',
              createdAt: reading.timestamp,
              updatedAt: reading.timestamp,
            ));
            print('  Added watch user: $name (Room: ${reading.roomNumber ?? "N/A"})');
          }
        }
      }
      
      print('  Total elders: ${allElders.length}');
      
      // Debug: Print all elder names
      for (final elder in allElders) {
        print('    - ${elder.name} (Room: ${elder.roomNumber})');
      }
      
      if (mounted) {
        setState(() {
          _elders = allElders;
        });
      }
    } catch (e, stackTrace) {
      print('Error loading elders: $e');
      print('Stack trace: $stackTrace');
      // If error, at least try to get manual elders
      try {
        final manualElders = await ApiService.getAllElders();
        if (mounted) {
          setState(() {
            _elders = manualElders;
            print('Loaded ${manualElders.length} manual elders after error');
          });
        }
      } catch (e2) {
        print('Error loading manual elders: $e2');
        if (mounted) {
          setState(() {
            _elders = [];
          });
        }
      }
    }
  }

  Future<void> _loadMedicines() async {
    try {
      final medicines = await ApiService.getMedicines(
        elderName: _selectedElder,
        date: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _medicines = medicines;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _showAddMedicineDialog() {
    if (_elders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add an elder first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final medicineNameController = TextEditingController();
    final dosageController = TextEditingController();
    final timeController = TextEditingController();
    String? selectedElder;
    String selectedElderRoom = '';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Add Medicine',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Elder *',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedElder,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _elders.map((elder) {
                    return DropdownMenuItem(
                      value: elder.name,
                      child: Text('${elder.name}${elder.roomNumber != null ? ' (Room ${elder.roomNumber})' : ''}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedElder = value;
                      final elder = _elders.firstWhere((e) => e.name == value);
                      selectedElderRoom = elder.roomNumber ?? '';
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: medicineNameController,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage (e.g., 500mg) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time (e.g., 09:00) *',
                    border: OutlineInputBorder(),
                    hintText: 'HH:MM format',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (selectedElder == null ||
                    medicineNameController.text.trim().isEmpty ||
                    dosageController.text.trim().isEmpty ||
                    timeController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validate time format
                final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
                if (!timeRegex.hasMatch(timeController.text.trim())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter time in HH:MM format (e.g., 09:00)'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  isLoading = true;
                });

                try {
                  final scheduledDate = DateTime.now();
                  await ApiService.addMedicine(
                    elderName: selectedElder!,
                    elderRoomNumber: selectedElderRoom.isNotEmpty ? selectedElderRoom : null,
                    medicineName: medicineNameController.text.trim(),
                    dosage: dosageController.text.trim(),
                    time: timeController.text.trim(),
                    scheduledDate: scheduledDate,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Medicine added successfully! Watch user will be notified.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadMedicines();
                  }
                } catch (e) {
                  if (context.mounted) {
                    setDialogState(() {
                      isLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF17A2A2),
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Add Medicine'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const deepMint = Color(0xFF17A2A2);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF6FFFA),
      appBar: AppBar(
        title: const Text(
          'ElderLinks',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF17A2A2),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        centerTitle: false,
        actions: [
          const Icon(Icons.man, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          const Icon(Icons.woman, size: 20, color: Colors.white),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountSettingsScreen(staffName: widget.staffName),
                  ),
                );
              },
              child: const AvatarWidget(size: 40),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter by elder
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedElder,
                decoration: InputDecoration(
                  labelText: _elders.isEmpty ? 'No Elders Found' : 'Filter by Elder',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  helperText: _elders.isEmpty 
                      ? 'Send data from watch app first to see elders'
                      : null,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Elders'),
                  ),
                  if (_elders.isEmpty)
                    const DropdownMenuItem<String>(
                      value: 'no_elders',
                      enabled: false,
                      child: Text('No elders - Send data from watch first'),
                    )
                  else
                    ..._elders.map((elder) {
                      return DropdownMenuItem<String>(
                        value: elder.name,
                        child: Text('${elder.name}${elder.roomNumber != null && elder.roomNumber!.isNotEmpty ? ' (Room ${elder.roomNumber})' : ''}'),
                      );
                    }),
                ],
                onChanged: _elders.isEmpty ? null : (value) {
                  if (value == 'no_elders') return;
                  setState(() {
                    _selectedElder = value;
                  });
                  _loadMedicines();
                },
              ),
            ),
          ),
          // Medicines list
          Expanded(
            child: _isLoading && _medicines.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _medicines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load medicines',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error ?? 'Unknown error',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black.withOpacity(0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadMedicines,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMedicines,
                        child: _medicines.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.medication_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No medicines scheduled',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap + to add a medicine',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _medicines.length,
                                itemBuilder: (context, index) {
                                  final medicine = _medicines[index];
                                  return _buildMedicineCard(medicine);
                                },
                              ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_medicines',
        onPressed: _showAddMedicineDialog,
        backgroundColor: deepMint,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMedicineCard(Medicine medicine) {
    const deepMint = Color(0xFF17A2A2);
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (medicine.status) {
      case 'taken':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Taken';
        break;
      case 'missed':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Missed';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        statusText = 'Pending';
    }

    // Resolve elder gender for avatar (male = blue, female = pink)
    final elder = _elders.where((e) => e.name == medicine.elderName).isEmpty
        ? null
        : _elders.firstWhere((e) => e.name == medicine.elderName);
    final g = elder?.gender.trim().toLowerCase() ?? '';
    final isMale = g == 'male' || g == 'm';
    final isFemale = g == 'female' || g == 'f';
    final Color avatarBg;
    final Color avatarIconColor;
    final IconData avatarIcon;
    if (isMale) {
      avatarBg = Colors.blue.withOpacity(0.25);
      avatarIconColor = Colors.blue.shade800;
      avatarIcon = Icons.man;
    } else if (isFemale) {
      avatarBg = Colors.pink.withOpacity(0.25);
      avatarIconColor = Colors.pink.shade700;
      avatarIcon = Icons.woman;
    } else {
      avatarBg = Colors.grey.withOpacity(0.2);
      avatarIconColor = Colors.grey.shade700;
      avatarIcon = Icons.person;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(avatarIcon, size: 24, color: avatarIconColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.medicineName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicine.elderName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(Icons.science, '${medicine.dosage}'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.access_time, medicine.time),
                if (medicine.elderRoomNumber != null) ...[
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.door_front_door, 'Room ${medicine.elderRoomNumber}'),
                ],
              ],
            ),
            if (medicine.takenAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Taken at: ${_formatTime(medicine.takenAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:$minute $period';
  }
}
