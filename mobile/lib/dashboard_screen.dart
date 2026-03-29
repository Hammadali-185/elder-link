import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'account_settings_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';
import 'services/data_sharing_service.dart';
import 'services/auto_lock_service.dart';
import 'widgets/avatar_widget.dart';

class DashboardScreen extends StatefulWidget {
  final String? staffName;

  const DashboardScreen({super.key, this.staffName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Reading> _readings = [];
  Set<String> _notifiedReadings = {}; // Track which readings we've already notified
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  MusicDashboardSummary? _musicSummary;
  String? _musicLoadNote;
  @override
  void initState() {
    super.initState();
    _loadReadings();
    AnalyticsService.logScreenView('dashboard');
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadReadings();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReadings() async {
    try {
      // Update activity for auto-lock
      AutoLockService.updateActivity();

      final readings = await ApiService.getAllReadings();
      if (mounted) {
        setState(() {
          _readings = readings;
          _isLoading = false;
          _error = null;
        });
        
        // Check for new readings and send notifications with person details
        for (final reading in readings) {
          // Skip if we've already notified about this reading
          if (_notifiedReadings.contains(reading.id)) continue;
          
          final personName = reading.personName ?? reading.username;
          
          if (reading.emergency) {
            // Panic button alert
            await NotificationService.sendPanicAlert(
              personName: personName,
              timestamp: reading.timestamp,
            );
            _notifiedReadings.add(reading.id);
          } else if (reading.status == 'abnormal') {
            // Abnormal health reading
            await NotificationService.sendHealthAlert(
              personName: personName,
              status: reading.status,
              bp: reading.bp,
              heartRate: reading.heartRate,
              timestamp: reading.timestamp,
            );
            _notifiedReadings.add(reading.id);
          }
        }
        
        // Share data if enabled
        if (DataSharingService.canShareData() && readings.isNotEmpty) {
          final latestReading = readings.first;
          await DataSharingService.shareAnonymizedData({
            'bp': latestReading.bp,
            'heartRate': latestReading.heartRate,
            'status': latestReading.status,
            'timestamp': latestReading.timestamp.toIso8601String(),
          });
        }
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

  String _formatListenDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0m';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  // ignore: unused_element
  Widget _buildMusicAnalyticsSection(Color deepMint) {
    final m = _musicSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.headphones, color: deepMint, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Music activity (elders)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          m != null
              ? 'Updates every ~15s · times in UTC'
              : (_musicLoadNote ?? 'Loading…'),
          style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55)),
        ),
        const SizedBox(height: 12),
        if (m != null) ...[
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Listening now',
                  '${m.activeListenersCount}',
                  Icons.hearing,
                  deepMint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Top category (today)',
                  m.mostPlayedCategory != null
                      ? m.mostPlayedCategory!.replaceAll('_', ' ')
                      : '—',
                  Icons.category,
                  Colors.deepPurple,
                ),
              ),
            ],
          ),
          if (m.mostPlayedCategorySeconds != null &&
              m.mostPlayedCategorySeconds! > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Top category time today: ${_formatListenDuration(m.mostPlayedCategorySeconds!)}',
              style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.6)),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Now playing',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          if (m.nowPlaying.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'No active listeners',
                style: TextStyle(color: Colors.black.withOpacity(0.5)),
              ),
            )
          else
            ...m.nowPlaying.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: deepMint.withOpacity(0.35), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.elderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.85),
                          ),
                        ),
                        if (n.artist.isNotEmpty)
                          Text(
                            n.artist,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Category: ${n.category.replaceAll('_', ' ')} · Started ${n.playStart.toUtc().toIso8601String().substring(11, 19)} UTC',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          const Text(
            'Listening today (per elder)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          if (m.listeningTodaySecondsByElder.isEmpty)
            Text(
              'No sessions started yet today (UTC)',
              style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.5)),
            )
          else
            ...m.listeningTodaySecondsByElder.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.elderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _formatListenDuration(e.totalSeconds),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: deepMint,
                        ),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 16),
          const Text(
            'Last played (any track)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          if (m.lastPlayedByElder.isEmpty)
            Text(
              'No history yet',
              style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.5)),
            )
          else
            ...m.lastPlayedByElder.take(8).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.elderName,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        e.lastPlayedAt.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  int get _criticalAlertsCount {
    return _readings.where((r) => r.emergency || r.status == 'abnormal').length;
  }

  List<Reading> get _recentReadings {
    final sorted = List<Reading>.from(_readings);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(5).toList();
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
    
    if (readingDate == today) {
      return 'Today';
    } else if (readingDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _formatReadingSummary(Reading reading) {
    final parts = <String>[];
    if (reading.bp > 0) {
      parts.add('BP: ${reading.bp}');
    }
    if (reading.heartRate > 0) {
      parts.add('HR: ${reading.heartRate} BPM');
    }
    if (parts.isEmpty) {
      return 'No vitals';
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF90EE90);
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
      body: SafeArea(
          child: _isLoading && _readings.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _readings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load data',
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
                            onPressed: () {
                              AutoLockService.updateActivity();
                              _loadReadings();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () {
                        AutoLockService.updateActivity();
                        return _loadReadings();
                      },
                      child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top greeting
                          Text(
                            '${_getGreeting()}, ${widget.staffName ?? "Staff"} — welcome back.',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Welcome banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  mint.withOpacity(0.4),
                                  deepMint.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.8)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _readings.isEmpty
                                      ? 'No data available yet'
                                      : 'Here\'s today\'s care snapshot.',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Everything you need to know at a glance.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Critical Alerts Badge
                          if (_criticalAlertsCount > 0)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.warning, color: Colors.red, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$_criticalAlertsCount Critical Alert${_criticalAlertsCount > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Please review now.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'All systems normal',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          // Section title
                          const Text(
                            'Elder Health Trend',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Recent changes at a glance',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Statistics Cards
                          if (_readings.isNotEmpty) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Total Readings',
                                    '${_readings.length}',
                                    Icons.favorite,
                                    Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    'Normal',
                                    '${_readings.where((r) => r.status == 'normal').length}',
                                    Icons.check_circle,
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Abnormal',
                                    '${_readings.where((r) => r.status == 'abnormal').length}',
                                    Icons.warning,
                                    Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    'Emergencies',
                                    '${_readings.where((r) => r.emergency).length}',
                                    Icons.emergency,
                                    Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Blood Pressure Statistics
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBPStatCard(
                                    'Avg BP',
                                    _getAverageBP(),
                                    Icons.monitor_heart,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildBPStatCard(
                                    'Latest BP',
                                    _getLatestBP(),
                                    Icons.trending_up,
                                    _getLatestBPColor(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBPStatCard(
                                    'Avg HR',
                                    _getAverageHeartRate(),
                                    Icons.favorite,
                                    Colors.pink,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildBPStatCard(
                                    'Latest HR',
                                    _getLatestHeartRate(),
                                    Icons.monitor_heart_outlined,
                                    _getLatestHeartRateColor(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // BP Trend by Elder
                            if (_getElderBPData().isNotEmpty) ...[
                              const Text(
                                'Blood Pressure by Elder',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._getElderBPData().map((data) => _buildElderBPCard(data)),
                              const SizedBox(height: 16),
                            ],
                            if (_getElderHeartRateData().isNotEmpty) ...[
                              const Text(
                                'Heart Rate by Elder',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._getElderHeartRateData().map((data) => _buildElderHeartRateCard(data)),
                              const SizedBox(height: 16),
                            ],
                            // Abnormal Activity Graph
                            if (_getAbnormalActivityData().isNotEmpty) ...[
                              const Text(
                                'Abnormal Activity Trend',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Real-time monitoring of abnormal readings',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildAbnormalActivityGraph(),
                              const SizedBox(height: 24),
                            ],
                          ],
                          // Recent Activity Section
                          const Text(
                            'Recent Activity',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_recentReadings.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'No recent activity',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._recentReadings.map((reading) {
                              IconData icon;
                              Color iconColor;
                              String title;

                              if (reading.emergency) {
                                icon = Icons.emergency;
                                iconColor = Colors.red;
                                title = 'Emergency alert — ${reading.personName ?? reading.username}';
                              } else if (reading.status == 'abnormal') {
                                icon = Icons.warning;
                                iconColor = Colors.orange;
                                title = 'Abnormal reading — ${reading.personName ?? reading.username} (${_formatReadingSummary(reading)})';
                              } else {
                                icon = Icons.favorite;
                                iconColor = Colors.green;
                                title = 'Normal reading — ${reading.personName ?? reading.username} (${_formatReadingSummary(reading)})';
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildActivityItem(
                                  icon: icon,
                                  iconColor: iconColor,
                                  title: title,
                                  time: _formatTime(reading.timestamp),
                                  date: _formatDate(reading.timestamp),
                                ),
                              );
                            }),
                          const SizedBox(height: 28),
                          // Primary CTA
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _criticalAlertsCount > 0 ? Colors.red : deepMint,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 2,
                              ),
                              onPressed: () {
                                // Navigate to alerts
                              },
                              child: Text(
                                _criticalAlertsCount > 0
                                    ? 'View $_criticalAlertsCount Alert${_criticalAlertsCount > 1 ? 's' : ''}'
                                    : 'View All Readings',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Secondary CTA
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: deepMint,
                                side: BorderSide(color: deepMint, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                // Navigate to timeline
                              },
                              child: const Text(
                                'Open Care Timeline',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBPStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
          if (value != 'N/A' && label == 'Latest BP')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'mmHg',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildElderBPCard(Map<String, dynamic> data) {
    final elderName = data['elderName'] as String;
    final latestBP = data['latestBP'] as int;
    final avgBP = data['avgBP'] as int;
    final status = data['status'] as String;
    final roomNumber = data['roomNumber'] as String?;
    final timestamp = data['timestamp'] as DateTime;
    
    final bpColor = latestBP >= 140 ? Colors.red : (latestBP >= 120 ? Colors.orange : Colors.green);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bpColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bpColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.monitor_heart,
              color: bpColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      elderName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (roomNumber != null && roomNumber.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Room $roomNumber',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'BP: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      '$latestBP mmHg',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: bpColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Avg: $avgBP',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'abnormal' 
                  ? Colors.orange.withOpacity(0.15)
                  : Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: status == 'abnormal' ? Colors.orange : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElderHeartRateCard(Map<String, dynamic> data) {
    final elderName = data['elderName'] as String;
    final latestHeartRate = data['latestHeartRate'] as int;
    final avgHeartRate = data['avgHeartRate'] as int;
    final status = data['status'] as String;
    final roomNumber = data['roomNumber'] as String?;
    final timestamp = data['timestamp'] as DateTime;

    final heartRateColor =
        latestHeartRate < 50 || latestHeartRate > 110 ? Colors.orange : Colors.pink;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: heartRateColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: heartRateColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.favorite,
              color: heartRateColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      elderName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (roomNumber != null && roomNumber.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Room $roomNumber',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'HR: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      '$latestHeartRate BPM',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: heartRateColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Avg: $avgHeartRate',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'abnormal'
                  ? Colors.orange.withOpacity(0.15)
                  : Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: status == 'abnormal' ? Colors.orange : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Get average BP from all readings
  String _getAverageBP() {
    final readingsWithBP = _readings.where((r) => r.bp > 0).toList();
    if (readingsWithBP.isEmpty) return 'N/A';
    
    final avg = readingsWithBP.map((r) => r.bp).reduce((a, b) => a + b) / readingsWithBP.length;
    return '${avg.round()}';
  }

  // Get latest BP value
  String _getLatestBP() {
    final readingsWithBP = _readings.where((r) => r.bp > 0).toList();
    if (readingsWithBP.isEmpty) return 'N/A';
    
    readingsWithBP.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return '${readingsWithBP.first.bp}';
  }

  // Get color for latest BP (red if high, green if normal)
  Color _getLatestBPColor() {
    final readingsWithBP = _readings.where((r) => r.bp > 0).toList();
    if (readingsWithBP.isEmpty) return Colors.grey;
    
    readingsWithBP.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final latestBP = readingsWithBP.first.bp;
    
    if (latestBP >= 140) return Colors.red;
    if (latestBP >= 120) return Colors.orange;
    return Colors.green;
  }

  String _getAverageHeartRate() {
    final readingsWithHeartRate = _readings.where((r) => r.heartRate > 0).toList();
    if (readingsWithHeartRate.isEmpty) return 'N/A';

    final avg = readingsWithHeartRate
            .map((r) => r.heartRate)
            .reduce((a, b) => a + b) /
        readingsWithHeartRate.length;
    return '${avg.round()}';
  }

  String _getLatestHeartRate() {
    final readingsWithHeartRate = _readings.where((r) => r.heartRate > 0).toList();
    if (readingsWithHeartRate.isEmpty) return 'N/A';

    readingsWithHeartRate.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return '${readingsWithHeartRate.first.heartRate}';
  }

  Color _getLatestHeartRateColor() {
    final readingsWithHeartRate = _readings.where((r) => r.heartRate > 0).toList();
    if (readingsWithHeartRate.isEmpty) return Colors.grey;

    readingsWithHeartRate.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final latestHeartRate = readingsWithHeartRate.first.heartRate;

    if (latestHeartRate < 50 || latestHeartRate > 110) return Colors.orange;
    return Colors.pink;
  }

  // Get BP data grouped by elder
  List<Map<String, dynamic>> _getElderBPData() {
    final Map<String, List<Reading>> elderReadings = {};
    
    // Group readings by elder name
    for (final reading in _readings.where((r) => r.bp > 0)) {
      final elderName = reading.personName ?? reading.username;
      if (!elderReadings.containsKey(elderName)) {
        elderReadings[elderName] = [];
      }
      elderReadings[elderName]!.add(reading);
    }
    
    // Get latest BP for each elder
    final List<Map<String, dynamic>> bpData = [];
    elderReadings.forEach((elderName, readings) {
      readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final latestReading = readings.first;
      final avgBP = readings.map((r) => r.bp).reduce((a, b) => a + b) / readings.length;
      
      bpData.add({
        'elderName': elderName,
        'latestBP': latestReading.bp,
        'avgBP': avgBP.round(),
        'timestamp': latestReading.timestamp,
        'status': latestReading.status,
        'roomNumber': latestReading.roomNumber,
      });
    });
    
    // Sort by timestamp (most recent first)
    bpData.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    
    return bpData.take(5).toList(); // Show top 5
  }

  List<Map<String, dynamic>> _getElderHeartRateData() {
    final Map<String, List<Reading>> elderReadings = {};

    for (final reading in _readings.where((r) => r.heartRate > 0)) {
      final elderName = reading.personName ?? reading.username;
      elderReadings.putIfAbsent(elderName, () => []);
      elderReadings[elderName]!.add(reading);
    }

    final List<Map<String, dynamic>> heartRateData = [];
    elderReadings.forEach((elderName, readings) {
      readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final latestReading = readings.first;
      final avgHeartRate =
          readings.map((r) => r.heartRate).reduce((a, b) => a + b) / readings.length;

      heartRateData.add({
        'elderName': elderName,
        'latestHeartRate': latestReading.heartRate,
        'avgHeartRate': avgHeartRate.round(),
        'timestamp': latestReading.timestamp,
        'status': latestReading.status,
        'roomNumber': latestReading.roomNumber,
      });
    });

    heartRateData.sort(
      (a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
    );

    return heartRateData.take(5).toList();
  }

  // Get abnormal activity data for graph (grouped by hour)
  List<Map<String, dynamic>> _getAbnormalActivityData() {
    final abnormalReadings = _readings.where((r) => r.status == 'abnormal' || r.emergency).toList();
    if (abnormalReadings.isEmpty) return [];
    
    // Group by hour for the last 24 hours
    final now = DateTime.now();
    final Map<String, int> hourlyData = {};
    
    // Initialize last 24 hours with 0
    for (int i = 23; i >= 0; i--) {
      final hour = now.subtract(Duration(hours: i));
      final hourKey = '${hour.hour.toString().padLeft(2, '0')}:00';
      hourlyData[hourKey] = 0;
    }
    
    // Count abnormal readings per hour
    for (final reading in abnormalReadings) {
      final hour = DateTime(reading.timestamp.year, reading.timestamp.month, 
                           reading.timestamp.day, reading.timestamp.hour);
      final hourKey = '${hour.hour.toString().padLeft(2, '0')}:00';
      
      // Only include if within last 24 hours
      if (now.difference(hour).inHours <= 24) {
        hourlyData[hourKey] = (hourlyData[hourKey] ?? 0) + 1;
      }
    }
    
    // Convert to list format for graph
    final List<Map<String, dynamic>> graphData = [];
    hourlyData.forEach((hour, count) {
      graphData.add({
        'hour': hour,
        'count': count,
      });
    });
    
    // Sort by hour
    graphData.sort((a, b) {
      final hourA = int.parse(a['hour'].toString().split(':')[0]);
      final hourB = int.parse(b['hour'].toString().split(':')[0]);
      return hourA.compareTo(hourB);
    });
    
    return graphData;
  }

  Widget _buildAbnormalActivityGraph() {
    final graphData = _getAbnormalActivityData();
    if (graphData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No abnormal activity to display',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }
    
    final maxCount = graphData.map((d) => d['count'] as int).reduce((a, b) => a > b ? a : b);
    final maxY = maxCount > 0 ? (maxCount + 1).toDouble() : 5.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Abnormal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Emergency',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                'Last 24 hours',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= graphData.length) return const Text('');
                        final hour = graphData[value.toInt()]['hour'] as String;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            hour,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black.withOpacity(0.6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxY > 5 ? 2 : 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() != value || value < 0) return const Text('');
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: (graphData.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: graphData.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        (entry.value['count'] as int).toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.red.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final index = touchedSpot.x.toInt();
                        if (index >= graphData.length) return null;
                        final hour = graphData[index]['hour'] as String;
                        final count = graphData[index]['count'] as int;
                        return LineTooltipItem(
                          '$hour\n$count abnormal',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
    String? date,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withOpacity(0.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

}
