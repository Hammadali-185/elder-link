import 'package:flutter/material.dart';
import 'dart:async';
import 'package:elderlink/karachi_time.dart';
import 'account_settings_screen.dart';
import 'services/api_service.dart';
import 'widgets/avatar_widget.dart';

bool _mongoObjectId(String s) {
  final t = s.trim();
  return t.length == 24 && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(t);
}

class MedicinesScreen extends StatefulWidget {
  final String? staffName;

  /// True when this tab is selected in [StaffHomeScreen]'s bottom nav (IndexedStack keeps this widget alive).
  final bool isActiveTab;

  const MedicinesScreen({
    super.key,
    this.staffName,
    this.isActiveTab = false,
  });

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  List<Medicine> _medicines = [];
  List<Elder> _elders = [];
  /// Mongo [Elder] id for the filter dropdown (never a Reading document id).
  String? _selectedElderId;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  void _syncFilterSelectionAfterEldersLoad() {
    if (_elders.isEmpty) {
      _selectedElderId = null;
      return;
    }
    if (_selectedElderId == null ||
        !_elders.any((e) => e.id == _selectedElderId)) {
      _selectedElderId = _elders.first.id;
    }
  }

  @override
  void initState() {
    super.initState();
    ensureKarachiTimeZones();
    _loadData();
    // Elders list was only loaded once; watch sync updates /api/elders without remounting IndexedStack.
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadData();
    });
  }

  @override
  void didUpdateWidget(MedicinesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActiveTab && !oldWidget.isActiveTab) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadElders();
    await _loadMedicines();
  }

  Future<void> _loadElders() async {
    try {
      // Get both manually added elders and watch users from readings
      final manualElders = await ApiService.getAllElders();
      final readings = await ApiService.getAllReadings();
      
      print('Medicines Screen - Loading elders:');
      print('  Manual elders: ${manualElders.length}');
      print('  Readings: ${readings.length}');
      
      // Extract unique elders from readings (watch users) — case-insensitive dedupe.
      final Set<String> elderKeys = {};
      final List<Elder> allElders = List.from(manualElders);

      String normKey(String s) => s.trim().toLowerCase();

      for (final elder in manualElders) {
        if (elder.name.trim().isNotEmpty) {
          elderKeys.add(normKey(elder.name));
        }
      }

      for (final reading in readings) {
        // Match elders_screen: never surface legacy "Watch User" / anonymous-only rows as a fake elder.
        final display = reading.personName?.trim();
        final stableKey = (display != null && display.isNotEmpty)
            ? display
            : reading.username.trim();
        if (stableKey.isEmpty || stableKey == 'Watch User') continue;

        final linkedElderId = reading.elderId?.trim();
        if (linkedElderId == null ||
            linkedElderId.isEmpty ||
            !_mongoObjectId(linkedElderId)) {
          continue;
        }

        final displayName = (display != null && display.isNotEmpty)
            ? display
            : 'Unnamed watch user';

        final key = normKey(stableKey);
        if (elderKeys.contains(key)) continue;
        elderKeys.add(key);

        final exists = manualElders.any((e) => normKey(e.name) == key);
        if (!exists) {
          allElders.add(Elder(
            id: linkedElderId,
            name: displayName,
            roomNumber: reading.roomNumber ?? '',
            age: reading.age ?? '',
            disease: reading.disease,
            status: reading.emergency || reading.status == 'abnormal'
                ? 'need_attention'
                : 'stable',
            gender: reading.gender ?? 'Male',
            readingUsername: null,
            createdAt: reading.timestamp,
            updatedAt: reading.timestamp,
          ));
          print('  Added watch user from readings: $displayName');
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
          _syncFilterSelectionAfterEldersLoad();
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
            _syncFilterSelectionAfterEldersLoad();
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
      if (_elders.isEmpty || _selectedElderId == null) {
        if (mounted) {
          setState(() {
            _medicines = [];
            _isLoading = false;
            _error = null;
          });
        }
        return;
      }

      Elder? selected;
      for (final e in _elders) {
        if (e.id == _selectedElderId) {
          selected = e;
          break;
        }
      }
      if (selected == null) {
        if (mounted) {
          setState(() {
            _medicines = [];
            _isLoading = false;
            _error = null;
          });
        }
        return;
      }

      if (!_mongoObjectId(selected.id)) {
        if (mounted) {
          setState(() {
            _medicines = [];
            _isLoading = false;
            _error = 'Medicines require a server elder id for this resident';
          });
        }
        return;
      }

      final medicines = await ApiService.getMedicines(
        elderId: selected.id.trim(),
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

    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddMedicineDialog(
        elders: _elders,
        messenger: messenger,
        onSuccess: _loadMedicines,
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
          'ElderLink',
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
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
                value: _elders.any((e) => e.id == _selectedElderId)
                    ? _selectedElderId
                    : null,
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
                      : 'Medicines are scoped by elder id',
                ),
                items: [
                  if (_elders.isEmpty)
                    const DropdownMenuItem<String>(
                      value: 'no_elders',
                      enabled: false,
                      child: Text('No elders - Send data from watch first'),
                    )
                  else
                    ..._elders.map((elder) {
                      return DropdownMenuItem<String>(
                        value: elder.id,
                        child: Text(
                          '${elder.name}${elder.roomNumber.trim().isNotEmpty ? ' (Room ${elder.roomNumber})' : ''}',
                        ),
                      );
                    }),
                ],
                onChanged: _elders.isEmpty ? null : (value) {
                  if (value == null || value == 'no_elders') return;
                  setState(() {
                    _selectedElderId = value;
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
                              onPressed: _loadData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
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
                'Taken at: ${_formatTakenAtDisplay(medicine.takenAt!)}',
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

  /// Backend stores [instant] in UTC; show Asia/Karachi wall time (same as watch/music).
  String _formatTakenAtDisplay(DateTime instant) {
    final wall = utcInstantToKarachiWall(instant);
    final hour = wall.hour;
    final minute = wall.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:$minute $period';
  }
}

/// Controllers are disposed in [State.dispose] after the route unmounts — not in
/// [showDialog]'s future completion, which runs before dependents detach (framework assert).
class _AddMedicineDialog extends StatefulWidget {
  final List<Elder> elders;
  final ScaffoldMessengerState messenger;
  final Future<void> Function() onSuccess;

  const _AddMedicineDialog({
    required this.elders,
    required this.messenger,
    required this.onSuccess,
  });

  @override
  State<_AddMedicineDialog> createState() => _AddMedicineDialogState();
}

class _AddMedicineDialogState extends State<_AddMedicineDialog> {
  static final _timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');

  final List<_MedRowControllers> _rows = [_MedRowControllers()];
  final List<_MedRowControllers> _removedRows = [];
  String? _selectedElderId;
  String _selectedElderRoom = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.elders.isNotEmpty) {
      final e = widget.elders.first;
      _selectedElderId = e.id;
      _selectedElderRoom = e.roomNumber;
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    for (final r in _removedRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _snack(String msg, Color bg) {
    widget.messenger.showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  Future<void> _submit() async {
    if (_selectedElderId == null) {
      _snack('Please select an elder', Colors.red);
      return;
    }

    final toAdd = _rows.where((r) => !r.isBlank).toList();
    if (toAdd.isEmpty) {
      _snack('Add at least one medicine (name, dosage, time)', Colors.red);
      return;
    }

    for (final r in toAdd) {
      final n = r.name.text.trim();
      final d = r.dosage.text.trim();
      final t = r.time.text.trim();
      if (n.isEmpty || d.isEmpty || t.isEmpty) {
        _snack(
          'Each medicine needs name, dosage, and time (or clear unused rows)',
          Colors.red,
        );
        return;
      }
      if (!_timeRegex.hasMatch(t)) {
        _snack('Invalid time for "$n" — use HH:MM (e.g. 09:00)', Colors.red);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      Elder elder;
      try {
        elder = widget.elders.firstWhere((e) => e.id == _selectedElderId);
      } catch (_) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _snack('Selected elder not found; close and try again', Colors.red);
        return;
      }
      if (!_mongoObjectId(elder.id)) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _snack('This elder has no valid server id; cannot add medicine', Colors.red);
        return;
      }
      final scheduledDate = DateTime.now();
      for (final r in toAdd) {
        await ApiService.addMedicine(
          elderId: elder.id.trim(),
          elderRoomNumber:
              _selectedElderRoom.isNotEmpty ? _selectedElderRoom : null,
          medicineName: r.name.text.trim(),
          dosage: r.dosage.text.trim(),
          time: r.time.text.trim(),
          scheduledDate: scheduledDate,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      final msg = toAdd.length == 1
          ? 'Medicine added successfully! Watch user will be notified.'
          : '${toAdd.length} medicines added successfully! Watch user will be notified.';
      widget.messenger.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
      );
      await widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Error: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
              value: widget.elders.any((e) => e.id == _selectedElderId)
                  ? _selectedElderId
                  : null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: widget.elders.map((elder) {
                final room = elder.roomNumber.trim();
                return DropdownMenuItem(
                  value: elder.id,
                  child: Text(
                    room.isNotEmpty
                        ? '${elder.name} (Room $room)'
                        : elder.name,
                  ),
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedElderId = value;
                        final elder = widget.elders.firstWhere(
                          (e) => e.id == value,
                        );
                        _selectedElderRoom = elder.roomNumber;
                      });
                    },
            ),
            const SizedBox(height: 16),
            ..._rows.asMap().entries.expand((entry) {
              final i = entry.key;
              final row = entry.value;
              return [
                if (_rows.length > 1) ...[
                  Row(
                    children: [
                      Text(
                        'Medicine ${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Remove',
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_rows.length <= 1) return;
                                setState(() {
                                  _removedRows.add(_rows.removeAt(i));
                                });
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: row.name,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: row.dosage,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Dosage (e.g., 500mg) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: row.time,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Time (e.g., 09:00) *',
                    border: OutlineInputBorder(),
                    hintText: 'HH:MM format',
                  ),
                ),
                const SizedBox(height: 16),
              ];
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() => _rows.add(_MedRowControllers()));
                      },
                icon: const Icon(Icons.add),
                label: const Text('Add another medicine'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF17A2A2),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Add Medicine'),
        ),
      ],
    );
  }
}

class _MedRowControllers {
  _MedRowControllers()
      : name = TextEditingController(),
        dosage = TextEditingController(),
        time = TextEditingController();

  final TextEditingController name;
  final TextEditingController dosage;
  final TextEditingController time;

  void dispose() {
    name.dispose();
    dosage.dispose();
    time.dispose();
  }

  bool get isBlank =>
      name.text.trim().isEmpty &&
      dosage.text.trim().isEmpty &&
      time.text.trim().isEmpty;
}
