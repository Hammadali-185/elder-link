import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'account_settings_screen.dart';
import 'services/api_service.dart';
import 'widgets/avatar_widget.dart';

class AlertsScreen extends StatefulWidget {
  final String? staffName;
  
  const AlertsScreen({super.key, this.staffName});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Reading> _readings = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  String _filterSegment = 'active'; // 'active' | 'resolved' | 'last7'
  Set<String> _resolvedAlertKeys = {};

  static const String _resolvedPrefKey = 'alerts_resolved_keys';

  @override
  void initState() {
    super.initState();
    _loadReadings();
    _loadResolvedKeys();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadReadings();
    });
  }

  Future<void> _loadResolvedKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_resolvedPrefKey);
      if (list != null && mounted) {
        setState(() => _resolvedAlertKeys = list.toSet());
      }
    } catch (_) {}
  }

  Future<void> _saveResolvedKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_resolvedPrefKey, _resolvedAlertKeys.toList());
    } catch (_) {}
  }

  String _alertKey(Reading r) => '${r.id}_${r.timestamp.millisecondsSinceEpoch}';

  bool _isResolved(Reading r) => _resolvedAlertKeys.contains(_alertKey(r));

  void _markResolved(Reading r, bool resolved) {
    setState(() {
      if (resolved) {
        _resolvedAlertKeys.add(_alertKey(r));
      } else {
        _resolvedAlertKeys.remove(_alertKey(r));
      }
    });
    _saveResolvedKeys();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReadings() async {
    try {
      final readings = await ApiService.getAllReadings();
      if (mounted) {
        setState(() {
          _readings = readings;
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

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final readingDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (readingDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (readingDate.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    const deepMint = Color(0xFF17A2A2);
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // Base list: only alerts (emergencies and abnormal readings)
    var alerts = _readings.where((r) => r.emergency || r.status == 'abnormal').toList();
    alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Most recent first

    // Apply segment filter
    if (_filterSegment == 'active') {
      alerts = alerts.where((r) => !_isResolved(r)).toList();
    } else if (_filterSegment == 'resolved') {
      alerts = alerts.where((r) => _isResolved(r)).toList();
    } else if (_filterSegment == 'last7') {
      alerts = alerts.where((r) => r.timestamp.isAfter(sevenDaysAgo)).toList();
    }

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
          // Refresh button
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadReadings,
          ),
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
      body: _isLoading && _readings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _readings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load alerts',
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
                        onPressed: _loadReadings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReadings,
                  child: CustomScrollView(
                    slivers: [
                      // Filter row as first sliver – nothing can block it
                      SliverToBoxAdapter(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Filter',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _buildFilterChip('Active', 'active', Icons.warning_amber_rounded),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('Resolved', 'resolved', Icons.check_circle_outline),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('Last 7 days', 'last7', Icons.date_range),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (alerts.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, size: 64, color: Colors.green.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  'No Alerts',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'All systems normal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final reading = alerts[index];
                            final personName = reading.personName ?? reading.username;
                            
                            IconData icon;
                            Color iconColor;
                            Color cardColor;
                            String title;
                            String subtitle;

                            if (reading.emergency) {
                              icon = Icons.warning;
                              iconColor = Colors.red;
                              cardColor = Colors.red;
                              title = '🚨 Emergency Alert';
                              subtitle = 'Panic button pressed by $personName';
                            } else {
                              icon = Icons.monitor_heart;
                              iconColor = Colors.orange;
                              cardColor = Colors.orange;
                              title = '⚠️ Abnormal Reading';
                              final parts = <String>[];
                              if (reading.bp > 0) {
                                parts.add('BP: ${reading.bp} mmHg');
                              }
                              if (reading.heartRate > 0) {
                                parts.add('HR: ${reading.heartRate} BPM');
                              }
                              subtitle = '$personName - ${parts.isEmpty ? 'No vitals' : parts.join(' · ')}';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: cardColor.withOpacity(0.5),
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
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: iconColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(icon, color: iconColor, size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: cardColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                subtitle,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black.withOpacity(0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (reading.roomNumber != null && reading.roomNumber!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.door_front_door, size: 16, color: Colors.black.withOpacity(0.5)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Room ${reading.roomNumber}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black.withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDate(reading.timestamp),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black.withOpacity(0.5),
                                          ),
                                        ),
                                        Text(
                                          _formatTime(reading.timestamp),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: cardColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          final resolved = _isResolved(reading);
                                          _markResolved(reading, !resolved);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  resolved
                                                      ? 'Marked as active again'
                                                      : 'Marked as resolved',
                                                ),
                                                backgroundColor: const Color(0xFF17A2A2),
                                              ),
                                            );
                                          }
                                        },
                                        icon: Icon(
                                          _isResolved(reading)
                                              ? Icons.restore
                                              : Icons.check_circle_outline,
                                          size: 18,
                                          color: deepMint,
                                        ),
                                        label: Text(
                                          _isResolved(reading)
                                              ? 'Mark active'
                                              : 'Mark resolved',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF17A2A2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                              },
                              childCount: alerts.length,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _filterSegment == value;
    const deepMint = Color(0xFF17A2A2);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _filterSegment = value),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? deepMint.withOpacity(0.2) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? deepMint : Colors.grey.shade400,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? deepMint : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? deepMint : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
