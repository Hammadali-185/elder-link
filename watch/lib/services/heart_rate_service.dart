import 'dart:async';
import 'package:flutter/services.dart';

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
  static Future<bool> checkSensorAvailability() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('checkSensor');
      _isSensorAvailable = result ?? false;
      
      if (_isSensorAvailable == true) {
        print('Heart rate sensor detected');
      } else {
        print('Heart rate sensor NOT available');
      }
      
      return _isSensorAvailable ?? false;
    } catch (e) {
      print('Error checking sensor availability: $e');
      _isSensorAvailable = false;
      return false;
    }
  }

  static Future<bool> checkPermissions() async {
    try {
      return await _methodChannel.invokeMethod<bool>('checkPermissions') ?? false;
    } catch (e) {
      print('Error checking heart-rate permissions: $e');
      return false;
    }
  }

  static Future<bool> ensurePermissions() async {
    try {
      return await _methodChannel.invokeMethod<bool>('ensurePermissions') ?? false;
    } on PlatformException catch (e) {
      print('Error requesting heart-rate permissions: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      print('Error requesting heart-rate permissions: $e');
      return false;
    }
  }
  
  /// Start monitoring heart rate
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
      _isMonitoring = true;

      await _subscription?.cancel();
      _subscription = null;
      
      // Listen to heart rate stream
      _subscription = _eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) => event is int ? event : (event as num).toInt())
          .listen(
            (int heartRate) {
              _isMonitoring = true;
              
              // Notify listeners
              onHeartRateUpdate?.call(heartRate);
              
              if (heartRate < 60 || heartRate > 100) {
                print('⚠️ Out-of-range heart rate: $heartRate bpm');
              }
            },
            onError: (error) {
              print('Error in heart rate stream: $error');
              _isMonitoring = false;
            },
            cancelOnError: false,
          );
      
      print('Heart rate monitoring started');
    } on PlatformException catch (e) {
      print('Error starting heart rate monitoring: ${e.code} ${e.message}');
      _isMonitoring = false;
      rethrow;
    } catch (e) {
      print('Error starting heart rate monitoring: $e');
      _isMonitoring = false;
      rethrow;
    }
  }
  
  /// Stop monitoring heart rate
  static Future<void> stopMonitoring() async {
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
