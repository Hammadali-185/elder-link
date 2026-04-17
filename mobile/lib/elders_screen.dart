import 'package:flutter/material.dart';
import 'dart:async';
import 'account_settings_screen.dart';
import 'services/api_service.dart';
import 'widgets/avatar_widget.dart';

bool _mongoObjectId(String s) {
  final t = s.trim();
  return t.length == 24 && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(t);
}

class EldersScreen extends StatefulWidget {
  final String? staffName;
  
  const EldersScreen({super.key, this.staffName});

  @override
  State<EldersScreen> createState() => _EldersScreenState();
}

class _EldersScreenState extends State<EldersScreen> {
  List<ElderProfile> _elders = [];
  List<ElderProfile> _filteredElders = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadElders();
    _searchController.addListener(_filterElders);
    // Refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadElders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _filterElders() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredElders = _elders;
      } else {
        _filteredElders = _elders.where((elder) {
          return elder.name.toLowerCase().contains(query) ||
                 elder.roomNumber?.toLowerCase().contains(query) == true ||
                 elder.age?.toLowerCase().contains(query) == true;
        }).toList();
      }
    });
  }

  Future<void> _loadElders() async {
    try {
      final readings = await ApiService.getAllReadings();
      final manualElders = await ApiService.getAllElders();
      
      print('Elders Screen - Loading elders:');
      print('  Manual elders: ${manualElders.length}');
      print('  Readings: ${readings.length}');
      
      // Group readings by personName or username to create elder profiles
      final Map<String, ElderProfile> elderMap = {};
      
      // Add elders from watch readings (MongoDB Atlas)
      for (final reading in readings) {
        final display = reading.personName?.trim();
        // Stable API username may be a per-device id; group by display name when set.
        final stableKey = (display != null && display.isNotEmpty)
            ? display
            : reading.username.trim();
        // Skip empty or legacy shared placeholder (replaced by per-device stable usernames on watch).
        if (stableKey.isEmpty || stableKey == 'Watch User') {
          continue;
        }

        final displayName = (display != null && display.isNotEmpty)
            ? display
            : 'Unnamed watch user';

        if (!elderMap.containsKey(stableKey)) {
          elderMap[stableKey] = ElderProfile(
            name: displayName,
            username: reading.username,
            elderReadingUsername: null,
            gender: reading.gender,
            age: reading.age,
            disease: reading.disease,
            roomNumber: reading.roomNumber,
            latestReading: reading,
            totalReadings: 0,
            emergencyCount: 0,
            abnormalCount: 0,
            isManual: false,
          );
          print('  Added watch user from MongoDB: $stableKey (Room: ${reading.roomNumber ?? "N/A"})');
        }
        
        final elder = elderMap[stableKey]!;
        elder.totalReadings++;
        if (reading.emergency) elder.emergencyCount++;
        if (reading.status == 'abnormal') elder.abnormalCount++;
        
        // Update latest reading if this one is newer
        if (reading.timestamp.isAfter(elder.latestReading.timestamp)) {
          elder.latestReading = reading;
        }
      }
      
      // Add or update with manually added elders
      for (final manualElder in manualElders) {
        final key = manualElder.name;
        if (elderMap.containsKey(key)) {
          // Merge gender (and other fields) into existing elder from readings
          final existing = elderMap[key]!;
          if (manualElder.gender != null && manualElder.gender!.isNotEmpty) {
            existing.gender = manualElder.gender;
          }
          if (manualElder.age != null && manualElder.age!.isNotEmpty) {
            existing.age = manualElder.age;
          }
          if (manualElder.roomNumber != null && manualElder.roomNumber!.isNotEmpty) {
            existing.roomNumber = manualElder.roomNumber;
          }
          if (manualElder.id.isNotEmpty) {
            existing.deletableManualId = manualElder.id;
          }
          final ru = manualElder.readingUsername?.trim();
          if (ru != null && ru.isNotEmpty) {
            existing.elderReadingUsername = ru;
          }
        } else {
          // Create new elder from manual entry
          final dummyReading = Reading(
            id: manualElder.id,
            elderId: _mongoObjectId(manualElder.id) ? manualElder.id : null,
            username: manualElder.name.toLowerCase().replaceAll(' ', '_'),
            bp: 0,
            heartRate: 0,
            status: manualElder.status == 'need_attention' ? 'abnormal' : 'normal',
            emergency: false,
            timestamp: manualElder.createdAt,
            personName: manualElder.name,
            gender: manualElder.gender,
            age: manualElder.age,
            disease: manualElder.disease,
            roomNumber: manualElder.roomNumber,
          );
          elderMap[key] = ElderProfile(
            name: manualElder.name,
            username: manualElder.name.toLowerCase().replaceAll(' ', '_'),
            elderReadingUsername: manualElder.readingUsername,
            gender: manualElder.gender,
            age: manualElder.age,
            disease: manualElder.disease,
            roomNumber: manualElder.roomNumber,
            latestReading: dummyReading,
            totalReadings: 0,
            emergencyCount: 0,
            abnormalCount: manualElder.status == 'need_attention' ? 1 : 0,
            isManual: true,
            deletableManualId: manualElder.id.isNotEmpty ? manualElder.id : null,
          );
        }
      }
      
      // Convert to list and sort by latest activity
      final eldersList = elderMap.values.toList();
      eldersList.sort((a, b) => b.latestReading.timestamp.compareTo(a.latestReading.timestamp));
      
      print('  Total unique elders: ${eldersList.length}');
      for (final elder in eldersList) {
        print('    - ${elder.name} (Room: ${elder.roomNumber ?? "N/A"})');
      }
      
      if (mounted) {
        setState(() {
          _elders = eldersList;
          _filteredElders = eldersList;
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

  void _showAddElderDialog() {
    final nameController = TextEditingController();
    final roomController = TextEditingController();
    final ageController = TextEditingController();
    final diseaseController = TextEditingController();
    String selectedStatus = 'stable';
    String selectedGender = 'Male';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Add New Elder',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomController,
                  decoration: const InputDecoration(
                    labelText: 'Room Number *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: diseaseController,
                  decoration: const InputDecoration(
                    labelText: 'Condition/Disease (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Status *',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Stable'),
                        value: 'stable',
                        groupValue: selectedStatus,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedStatus = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Need Attention'),
                        value: 'need_attention',
                        groupValue: selectedStatus,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedStatus = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gender *',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Male'),
                        value: 'Male',
                        groupValue: selectedGender,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedGender = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Female'),
                        value: 'Female',
                        groupValue: selectedGender,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedGender = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
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
                if (nameController.text.trim().isEmpty ||
                    roomController.text.trim().isEmpty ||
                    ageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  isLoading = true;
                });

                try {
                  await ApiService.addElder(
                    name: nameController.text.trim(),
                    roomNumber: roomController.text.trim(),
                    age: ageController.text.trim(),
                    disease: diseaseController.text.trim().isEmpty
                        ? null
                        : diseaseController.text.trim(),
                    status: selectedStatus,
                    gender: selectedGender,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Elder added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadElders();
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
                  : const Text('Add Elder'),
            ),
          ],
        ),
      ),
    );
  }

  void _showElderDetailSheet(ElderProfile elder) {
    const deepMint = Color(0xFF17A2A2);
    final r = elder.latestReading;
    final statusLabel = r.emergency
        ? 'Emergency'
        : (r.status == 'abnormal'
            ? 'Abnormal'
            : (r.status == 'need_attention' ? 'Need attention' : 'Stable'));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewPadding.bottom;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Text(
                  elder.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                if (elder.roomNumber != null && elder.roomNumber!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Room ${elder.roomNumber}',
                      style: TextStyle(color: Colors.black.withOpacity(0.65)),
                    ),
                  ),
                if (elder.gender != null && elder.gender!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Gender: ${elder.gender}',
                    style: TextStyle(color: Colors.black.withOpacity(0.65)),
                  ),
                ],
                if (elder.age != null && elder.age!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Age: ${elder.age}',
                    style: TextStyle(color: Colors.black.withOpacity(0.65)),
                  ),
                ],
                if (elder.disease != null && elder.disease!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Condition: ${elder.disease}',
                    style: TextStyle(color: Colors.black.withOpacity(0.75)),
                  ),
                ],
                const Divider(height: 28),
                Text(
                  'Latest status',
                  style: TextStyle(fontWeight: FontWeight.w700, color: deepMint),
                ),
                const SizedBox(height: 6),
                Text(
                  statusLabel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last reading: ${_formatTime(r.timestamp)}',
                  style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.55)),
                ),
                if (r.bp > 0 || r.heartRate > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (r.bp > 0) 'BP: ${r.bp}',
                      if (r.heartRate > 0) 'HR: ${r.heartRate} BPM',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
                const Divider(height: 28),
                Text(
                  'Totals: ${elder.totalReadings} readings · ${elder.emergencyCount} emergencies · ${elder.abnormalCount} abnormal',
                  style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.6)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int get _totalElders => _elders.length;
  int get _stableElders => _elders.where((e) => e.emergencyCount == 0 && e.abnormalCount == 0).length;
  int get _needAttentionElders => _elders.where((e) => e.emergencyCount > 0 || e.abnormalCount > 0).length;

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
      body: _isLoading && _elders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _elders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load elders',
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
                        onPressed: _loadElders,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadElders,
                  child: Column(
                    children: [
                      // Search bar
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
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by name, room number, or age...',
                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.grey),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Statistics boxes (Total, Stable, Need Attention)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatBox(
                                title: 'Total',
                                value: '$_totalElders',
                                icon: Icons.people,
                                color: deepMint,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatBox(
                                title: 'Stable',
                                value: '$_stableElders',
                                icon: Icons.check_circle,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatBox(
                                title: 'Need Attention',
                                value: '$_needAttentionElders',
                                icon: Icons.warning,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Elders list
                      Expanded(
                        child: _filteredElders.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline, size: 64, color: Colors.grey.withOpacity(0.5)),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchController.text.isNotEmpty
                                          ? 'No elders found'
                                          : 'No elders found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _searchController.text.isNotEmpty
                                          ? 'Try a different search term'
                                          : 'Elders will appear here once they\nsend data from their watch',
                                      textAlign: TextAlign.center,
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
                                itemCount: _filteredElders.length,
                                itemBuilder: (context, index) {
                                  final elder = _filteredElders[index];
                                  return _buildElderCard(elder);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: null,
    );
  }

  Widget _buildStatBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildElderCard(ElderProfile elder) {
    const deepMint = Color(0xFF17A2A2);
    final isEmergency = elder.emergencyCount > 0;
    final isAbnormal = elder.abnormalCount > 0;
    // Condition: critical > attention > stable
    final conditionColor = isEmergency
        ? Colors.red
        : isAbnormal
            ? Colors.orange
            : Colors.green;
    final conditionBgTint = isEmergency
        ? Colors.red.withOpacity(0.08)
        : isAbnormal
            ? Colors.orange.withOpacity(0.08)
            : Colors.green.withOpacity(0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Card content (defines height; padded so bar doesn't overlap)
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Container(
              decoration: BoxDecoration(
                color: conditionBgTint,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () => _showElderDetailSheet(elder),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                children: [
                  // Avatar (gender-based icon: male = blue, female = pink)
                  Builder(
                    builder: (context) {
                      final g = elder.gender?.trim().toLowerCase() ?? '';
                      final isMale = g == 'male' || g == 'm';
                      final isFemale = g == 'female' || g == 'f';
                      final Color bgColor;
                      final Color iconColor;
                      final IconData avatarIcon;
                      if (isMale) {
                        bgColor = Colors.blue.withOpacity(0.25);
                        iconColor = Colors.blue.shade800;
                        avatarIcon = Icons.man;
                      } else if (isFemale) {
                        bgColor = Colors.pink.withOpacity(0.25);
                        iconColor = Colors.pink.shade700;
                        avatarIcon = Icons.woman;
                      } else {
                        bgColor = Colors.grey.withOpacity(0.2);
                        iconColor = Colors.grey.shade700;
                        avatarIcon = Icons.person;
                      }
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: bgColor,
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
                          child: Icon(
                            avatarIcon,
                            size: 24,
                            color: iconColor,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  // Name and info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          elder.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (elder.roomNumber != null && elder.roomNumber!.isNotEmpty)
                              _buildInfoChip(
                                icon: Icons.door_front_door,
                                text: 'Room ${elder.roomNumber}',
                              ),
                            if (elder.gender != null && elder.gender!.isNotEmpty)
                              _buildInfoChip(
                                icon: elder.gender == 'Male' ? Icons.male : Icons.female,
                                text: elder.gender!,
                              ),
                            if (elder.age != null && elder.age!.isNotEmpty)
                              _buildInfoChip(
                                icon: Icons.cake,
                                text: '${elder.age} years',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status indicator
                  if (isEmergency)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning, color: Colors.red, size: 20),
                    )
                  else if (isAbnormal)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.health_and_safety, color: Colors.orange, size: 20),
                    ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.black.withOpacity(0.55), size: 22),
                    onSelected: (value) {
                      if (value == 'purge') _confirmPurgeElder(elder);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'purge',
                        child: Text('Delete elder & all data'),
                      ),
                    ],
                  ),
                ],
              ),
              if (elder.disease != null && elder.disease!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.medical_services, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        elder.disease!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Stats row
              Row(
                children: [
                  _buildStatItem(
                    icon: Icons.favorite,
                    label: 'Readings',
                    value: '${elder.totalReadings}',
                    color: deepMint,
                  ),
                  const SizedBox(width: 16),
                  if (elder.emergencyCount > 0)
                    _buildStatItem(
                      icon: Icons.warning,
                      label: 'Emergencies',
                      value: '${elder.emergencyCount}',
                      color: Colors.red,
                    ),
                  if (elder.abnormalCount > 0) ...[
                    const SizedBox(width: 16),
                    _buildStatItem(
                      icon: Icons.health_and_safety,
                      label: 'Abnormal',
                      value: '${elder.abnormalCount}',
                      color: Colors.orange,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Latest reading info
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.black.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    'Last reading: ${_formatTime(elder.latestReading.timestamp)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                  const Spacer(),
                  if (elder.latestReading.bp > 0)
                    Text(
                      'BP: ${elder.latestReading.bp}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: elder.latestReading.status == 'abnormal' 
                            ? Colors.orange 
                            : deepMint,
                      ),
                    ),
                ],
              ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Left condition bar (same height as card)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: conditionColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
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

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmPurgeElder(ElderProfile elder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete elder & all data?'),
        content: Text(
          'This permanently removes "${elder.name}" from the system:\n\n'
          '· Health readings\n'
          '· Medicines & medicine history\n'
          '· Music session records\n'
          '· Heart alerts\n'
          '· Elder profile\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final result = await ApiService.purgeElderAllData(
        elderName: elder.name,
        elderMongoId: elder.deletableManualId,
        readingUsername: elder.elderReadingUsername ?? elder.username,
      );
      if (!mounted) return;
      final deleted = result['deleted'] as Map<String, dynamic>?;
      final summary = deleted == null
          ? 'Done.'
          : 'Removed ${deleted['readings'] ?? 0} readings, ${deleted['medicines'] ?? 0} medicines, '
              '${deleted['heartAlerts'] ?? 0} heart alerts, ${deleted['musicSessions'] ?? 0} music sessions, '
              '${deleted['medicineEvents'] ?? 0} medicine events, ${deleted['elderRecords'] ?? 0} profile(s).';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${elder.name}: $summary')),
      );
      _loadElders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class ElderProfile {
  String name;
  String username;
  /// Server [Elder.readingUsername] when known (stable watch device id for purge).
  String? elderReadingUsername;
  String? gender;
  String? age;
  String? disease;
  String? roomNumber;
  Reading latestReading;
  int totalReadings;
  int emergencyCount;
  int abnormalCount;
  bool isManual;
  /// MongoDB id for a staff-added elder row; used for DELETE /api/elders/:id.
  String? deletableManualId;

  ElderProfile({
    required this.name,
    required this.username,
    this.elderReadingUsername,
    this.gender,
    this.age,
    this.disease,
    this.roomNumber,
    required this.latestReading,
    required this.totalReadings,
    required this.emergencyCount,
    required this.abnormalCount,
    this.isManual = false,
    this.deletableManualId,
  });
}
