import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/heart_rate_service.dart';

class HealthMonitoringScreen extends StatefulWidget {
  final VoidCallback? onBackTap;
  
  const HealthMonitoringScreen({super.key, this.onBackTap});

  @override
  State<HealthMonitoringScreen> createState() => _HealthMonitoringScreenState();
}

class _HealthMonitoringScreenState extends State<HealthMonitoringScreen> {
  int _heartRate = 0;
  bool _isHeartRateActive = false;
  String _bloodPressure = '0/0';
  bool _isReadingBP = false;
  bool _readingSent = false;
  bool _abnormalAlertSent = false;
  String? _sensorStatus;

  @override
  void initState() {
    super.initState();
    _initializeHeartRateMonitoring();
  }

  @override
  void dispose() {
    HeartRateService.stopMonitoring();
    super.dispose();
  }

  Future<void> _initializeHeartRateMonitoring() async {
    // Check sensor availability
    final hasSensor = await HeartRateService.checkSensorAvailability();
    
    if (mounted) {
      setState(() {
        _sensorStatus = hasSensor ? 'Real Sensor' : 'Mock Data';
      });
    }
    
    // Setup callbacks
    HeartRateService.onHeartRateUpdate = (int heartRate) {
      if (mounted) {
        setState(() {
          _heartRate = heartRate;
          _isHeartRateActive = true;
        });
      }
    };
    
    HeartRateService.onAbnormalHeartRate = (int heartRate) {
      _handleAbnormalHeartRate(heartRate);
    };
    
    // Start monitoring
    await HeartRateService.startMonitoring();
  }

  Future<void> _handleAbnormalHeartRate(int heartRate) async {
    // Prevent duplicate alerts
    if (_abnormalAlertSent) return;
    
    _abnormalAlertSent = true;
    
    // Send heart alert to backend
    final username = ApiService.userName?.isNotEmpty == true 
        ? ApiService.userName! 
        : 'Watch User';
    
    final result = await ApiService.sendHeartAlert(
      username: username,
      heartRate: heartRate,
    );
    
    if (mounted) {
      if (result['success'] == true) {
        print('✅ Heart alert sent: $heartRate bpm');
        // Show alert sent indicator
        setState(() {
          _readingSent = true;
        });
        
        // Reset after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _readingSent = false;
              _abnormalAlertSent = false;
            });
          }
        });
      } else {
        print('❌ Failed to send heart alert: ${result['error']}');
        // Reset alert flag after delay to allow retry
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _abnormalAlertSent = false;
            });
          }
        });
      }
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
        
        // Send health reading to backend
        _sendHealthReading(bp);
      }
    });
  }

  Future<void> _sendHealthReading(int bp) async {
    // Use saved name if available
    final username = ApiService.userName?.isNotEmpty == true 
        ? ApiService.userName! 
        : 'Watch User';
    
    // Determine status based on BP (normal: <140/90, abnormal: >=140/90)
    final bpParts = _bloodPressure.split('/');
    final systolic = int.tryParse(bpParts[0]) ?? 0;
    final diastolic = int.tryParse(bpParts.length > 1 ? bpParts[1] : '0') ?? 0;
    final status = (systolic >= 140 || diastolic >= 90) ? 'abnormal' : 'normal';
    
    final result = await ApiService.sendHealthReading(
      username: username,
      bp: bp,
      status: status,
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
    
    return Container(
      width: screenSize.width,
      height: screenSize.height,
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          ClipRect(
            clipBehavior: Clip.hardEdge,
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
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_readingSent)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Reading sent successfully!',
                          style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                _buildHealthCard(
                  icon: Icons.favorite,
                  label: 'Heart Rate',
                  value: _isHeartRateActive 
                      ? '$_heartRate BPM' 
                      : 'Starting...',
                  color: (_heartRate > 0 && (_heartRate < 50 || _heartRate > 110)) 
                      ? Colors.orange 
                      : Colors.red,
                  subtitle: _sensorStatus != null 
                      ? Text(
                          _sensorStatus!,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                _buildHealthCard(
                  icon: Icons.monitor_heart,
                  label: 'Blood Pressure',
                  value: _isReadingBP ? 'Reading...' : '$_bloodPressure mmHg',
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _isReadingBP ? null : _startBloodPressureReading,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _isReadingBP ? Colors.grey : Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _isReadingBP ? 'READING BP...' : 'MEASURE BP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
              ],
            ),
          ),
          // Back button
          Positioned(
            top: 8,
            left: 8,
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
