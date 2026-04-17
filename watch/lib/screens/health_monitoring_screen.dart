import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/heart_rate_service.dart';
import '../vitals_rules.dart';

class HealthMonitoringScreen extends StatefulWidget {
  final VoidCallback? onBackTap;
  
  const HealthMonitoringScreen({super.key, this.onBackTap});

  @override
  State<HealthMonitoringScreen> createState() => _HealthMonitoringScreenState();
}

class _HealthMonitoringScreenState extends State<HealthMonitoringScreen> {
  int? _heartRate;
  bool _isHeartRateActive = false;
  String _bloodPressure = '0/0';
  bool _isReadingBP = false;
  bool _readingSent = false;
  bool _isStartingHeartRate = false;
  bool _didRestartHeartRateScan = false;
  bool _heartRateReadingSaved = false;
  String? _sensorStatus;
  String _heartRateStatusText = 'Scanning...';
  Timer? _heartRateLoadingTimer;
  Timer? _heartRateTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _initializeHeartRateMonitoring();
  }

  @override
  void dispose() {
    _heartRateLoadingTimer?.cancel();
    _heartRateTimeoutTimer?.cancel();
    HeartRateService.onHeartRateUpdate = null;
    HeartRateService.stopMonitoring();
    super.dispose();
  }

  Future<void> _initializeHeartRateMonitoring() async {
    _heartRateLoadingTimer?.cancel();
    _heartRateTimeoutTimer?.cancel();
    await HeartRateService.stopMonitoring();

    if (mounted) {
      setState(() {
        _heartRate = null;
        _isHeartRateActive = false;
        _isStartingHeartRate = true;
        _didRestartHeartRateScan = false;
        _heartRateReadingSaved = false;
        _heartRateStatusText = 'Scanning...';
        _sensorStatus = 'Checking watch permission';
      });
    }

    final hasPermission = await HeartRateService.ensurePermissions();
    if (!hasPermission) {
      if (mounted) {
        setState(() {
          _isStartingHeartRate = false;
          _heartRateStatusText = 'Permission needed';
          _sensorStatus = 'Allow heart-rate access on the watch';
        });
      }
      return;
    }

    final hasSensor = await HeartRateService.checkSensorAvailability();
    if (!hasSensor) {
      if (mounted) {
        setState(() {
          _isStartingHeartRate = false;
          _heartRateStatusText = 'Sensor unavailable';
          _sensorStatus = 'No heart-rate sensor found for this app';
        });
      }
      return;
    }

    HeartRateService.onHeartRateUpdate = (int heartRate) {
      _heartRateLoadingTimer?.cancel();
      _heartRateTimeoutTimer?.cancel();
      if (mounted) {
        setState(() {
          _heartRate = heartRate;
          _isHeartRateActive = true;
          _isStartingHeartRate = false;
          _heartRateStatusText = '$heartRate BPM';
          _sensorStatus = 'Live wrist reading';
        });
      }
      if (!_heartRateReadingSaved) {
        _heartRateReadingSaved = true;
        unawaited(_sendHeartRateReading(heartRate));
      }
    };
    
    _heartRateLoadingTimer?.cancel();
    _heartRateLoadingTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted || _isHeartRateActive) return;
      setState(() {
        _heartRateStatusText = 'Loading...';
        _sensorStatus = 'Keep the watch snug on your wrist';
      });
    });

    _heartRateTimeoutTimer?.cancel();
    _heartRateTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _isHeartRateActive) return;
      setState(() {
        _heartRateStatusText = 'Loading...';
        _sensorStatus = 'Re-scanning sensor...';
      });
      _restartHeartRateScan();
    });

    try {
      await HeartRateService.startMonitoring();
      if (mounted) {
        setState(() {
          _isStartingHeartRate = false;
        });
      }
      _heartRateTimeoutTimer?.cancel();
      _heartRateTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!mounted || _isHeartRateActive) return;
        setState(() {
          _isStartingHeartRate = false;
          _heartRateStatusText = 'No reading yet';
          _sensorStatus = 'Try staying still and scan again';
        });
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _isStartingHeartRate = false;
        _heartRateStatusText =
            e.code == 'permission_denied' ? 'Permission needed' : 'Sensor unavailable';
        _sensorStatus = e.message ?? 'Heart-rate scan could not start';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStartingHeartRate = false;
        _heartRateStatusText = 'Sensor unavailable';
        _sensorStatus = 'Heart-rate scan could not start';
      });
    }
  }

  Future<void> _restartHeartRateScan() async {
    if (_didRestartHeartRateScan || _isHeartRateActive) return;
    _didRestartHeartRateScan = true;
    try {
      await HeartRateService.stopMonitoring();
      await HeartRateService.startMonitoring();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStartingHeartRate = false;
        _heartRateStatusText = 'Sensor unavailable';
        _sensorStatus = 'Heart-rate scan could not restart';
      });
    }
  }

  Future<void> _sendHeartRateReading(int heartRate) async {
    final a = VitalsAssessment.forHeartRate(heartRate);

    final result = await ApiService.sendHealthReading(
      heartRate: heartRate,
      status: a.apiStatus,
      vitalsUrgent: a.isCritical,
      alertReason: a.alertReason,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _readingSent = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _readingSent = false;
          });
        }
      });
    } else {
      _heartRateReadingSaved = false;
    }
  }

  void _startBloodPressureReading() {
    setState(() {
      _isReadingBP = true;
      _readingSent = false;
    });

    // Simulate BP reading after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final bp = 120 + (DateTime.now().millisecond % 10);
        final bpLow = 80 + (DateTime.now().millisecond % 5);
        
        setState(() {
          _isReadingBP = false;
          _bloodPressure = '$bp/$bpLow';
        });
        
        _sendHealthReading();
      }
    });
  }

  Future<void> _sendHealthReading() async {
    final bpParts = _bloodPressure.split('/');
    final systolic = int.tryParse(bpParts[0]) ?? 0;
    final diastolic = int.tryParse(bpParts.length > 1 ? bpParts[1] : '0') ?? 0;
    final a = VitalsAssessment.forBloodPressure(systolic, diastolic);

    final result = await ApiService.sendHealthReading(
      bp: systolic,
      bpDiastolic: diastolic,
      status: a.apiStatus,
      vitalsUrgent: a.isCritical,
      alertReason: a.alertReason,
    );
    
    if (mounted) {
      setState(() {
        _readingSent = result['success'] == true;
      });
      
      // Reset sent status after 3 seconds
      if (_readingSent) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _readingSent = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final hr = _heartRate;
    final bpParts = _bloodPressure.split('/');
    final bpSys = int.tryParse(bpParts[0]) ?? 0;
    final bpDia = int.tryParse(bpParts.length > 1 ? bpParts[1] : '0') ?? 0;
    final bpAssess = VitalsAssessment.forBloodPressure(bpSys, bpDia);
    Color bpCardColor = Colors.white70;
    if (bpSys > 0 || bpDia > 0) {
      if (bpAssess.isCritical) {
        bpCardColor = Colors.red;
      } else if (bpAssess.isWarning) {
        bpCardColor = Colors.orange;
      } else {
        bpCardColor = Colors.green;
      }
    }

    return Container(
      width: screenSize.width,
      height: screenSize.height,
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 40, 0, 16),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Health Monitoring',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_readingSent)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Reading sent successfully!',
                              style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildHealthCard(
                    icon: Icons.favorite,
                    label: 'Heart Rate',
                    value: _isHeartRateActive
                        ? '${hr ?? 0} BPM'
                        : _heartRateStatusText,
                    color: (hr != null && hr > 0 && (hr < 60 || hr > 100))
                        ? Colors.orange
                        : (_isHeartRateActive ? Colors.red : Colors.white70),
                    subtitle: _sensorStatus != null
                        ? Text(
                            _sensorStatus!,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    label: _isStartingHeartRate ? 'SCANNING HEART...' : 'SCAN HEART',
                    color: _isStartingHeartRate ? Colors.grey : Colors.red,
                    onTap: _isStartingHeartRate ? null : _initializeHeartRateMonitoring,
                  ),
                  const SizedBox(height: 16),
                  _buildHealthCard(
                    icon: Icons.monitor_heart,
                    label: 'Blood Pressure',
                    value: _isReadingBP ? 'Reading...' : '$_bloodPressure mmHg',
                    color: bpCardColor,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    label: _isReadingBP ? 'READING BP...' : 'MEASURE BP',
                    color: _isReadingBP ? Colors.grey : Colors.green,
                    onTap: _isReadingBP ? null : _startBloodPressureReading,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onBackTap,
                borderRadius: BorderRadius.circular(25),
                splashColor: Colors.white.withValues(alpha: 0.3),
                highlightColor: Colors.white.withValues(alpha: 0.2),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
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

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    Widget? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            subtitle,
          ],
        ],
      ),
    );
  }
}
