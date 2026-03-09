import 'dart:async';
import 'package:flutter/services.dart';

/// Heart Rate Service with automatic sensor detection
/// 
/// Automatically detects if a real heart-rate sensor exists:
/// - Uses real sensor data when available
/// - Falls back to mock data (40-130 bpm) when sensor is not available
/// - Updates every 3 seconds
/// - Detects abnormal values (< 50 or > 110 bpm)
class HeartRateService {
  static const MethodChannel _methodChannel = MethodChannel('heart_rate/methods');
  static const EventChannel _eventChannel = EventChannel('heart_rate/stream');
  
  static StreamSubscription<int>? _subscription;
  static bool _isMonitoring = false;
  static bool? _isSensorAvailable;
  
  /// Callback for heart rate updates
  static Function(int)? onHeartRateUpdate;
  
  /// Callback for abnormal heart rate detection
  static Function(int)? onAbnormalHeartRate;
  
  /// Check if heart-rate sensor is available
  /// Returns true if real sensor exists, false if using mock data
  static Future<bool> checkSensorAvailability() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('checkSensor');
      _isSensorAvailable = result ?? false;
      
      if (_isSensorAvailable == true) {
        print('Heart rate sensor detected — using real data');
      } else {
        print('Heart rate sensor NOT available — using mock data');
      }
      
      return _isSensorAvailable ?? false;
    } catch (e) {
      print('Error checking sensor availability: $e');
      _isSensorAvailable = false;
      return false;
    }
  }
  
  /// Start monitoring heart rate
  /// Automatically uses real sensor if available, otherwise uses mock data
  static Future<void> startMonitoring() async {
    if (_isMonitoring) {
      print('Heart rate monitoring already started');
      return;
    }
    
    // Check sensor availability on first start
    if (_isSensorAvailable == null) {
      await checkSensorAvailability();
    }
    
    try {
      // Start monitoring on native side
      await _methodChannel.invokeMethod('startMonitoring');
      
      // Listen to heart rate stream
      _subscription = _eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) => event is int ? event : (event as num).toInt())
          .listen(
            (int heartRate) {
              _isMonitoring = true;
              
              // Notify listeners
              onHeartRateUpdate?.call(heartRate);
              
              // Check for abnormal values
              if (heartRate < 50 || heartRate > 110) {
                print('⚠️ Abnormal heart rate detected: $heartRate bpm');
                onAbnormalHeartRate?.call(heartRate);
              }
            },
            onError: (error) {
              print('Error in heart rate stream: $error');
              _isMonitoring = false;
            },
            cancelOnError: false,
          );
      
      print('Heart rate monitoring started (${_isSensorAvailable == true ? "real sensor" : "mock data"})');
    } catch (e) {
      print('Error starting heart rate monitoring: $e');
      _isMonitoring = false;
    }
  }
  
  /// Stop monitoring heart rate
  static Future<void> stopMonitoring() async {
    if (!_isMonitoring) {
      return;
    }
    
    try {
      await _methodChannel.invokeMethod('stopMonitoring');
      await _subscription?.cancel();
      _subscription = null;
      _isMonitoring = false;
      print('Heart rate monitoring stopped');
    } catch (e) {
      print('Error stopping heart rate monitoring: $e');
    }
  }
  
  /// Check if currently monitoring
  static bool get isMonitoring => _isMonitoring;
  
  /// Check if real sensor is available (null if not checked yet)
  static bool? get isSensorAvailable => _isSensorAvailable;
}
