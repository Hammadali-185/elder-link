import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoLockService {
  static Timer? _inactivityTimer;
  static DateTime? _lastActivityTime;
  static bool _isLocked = false;
  static Function()? _onLockCallback;

  static Future<void> initialize(Function() onLock) async {
    _onLockCallback = onLock;
    await _checkAutoLock();
  }

  static Future<void> _checkAutoLock() async {
    final prefs = await SharedPreferences.getInstance();
    final autoLockEnabled = prefs.getBool('security_autolock') ?? true;
    final lockMinutes = prefs.getInt('security_autolock_minutes') ?? 5;

    if (!autoLockEnabled) {
      _inactivityTimer?.cancel();
      return;
    }

    // Check every minute if app should lock
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_lastActivityTime != null) {
        final now = DateTime.now();
        final inactiveDuration = now.difference(_lastActivityTime!);
        final lockDuration = Duration(minutes: lockMinutes);

        if (inactiveDuration >= lockDuration && !_isLocked) {
          await lockApp();
        }
      }
    });
  }

  static void updateActivity() {
    _lastActivityTime = DateTime.now();
    _isLocked = false;
  }

  static Future<void> lockApp() async {
    if (_isLocked) return;

    _isLocked = true;
    print('🔒 App auto-locked due to inactivity');
    
    if (_onLockCallback != null) {
      _onLockCallback!();
    }
  }

  static void unlockApp() {
    _isLocked = false;
    updateActivity();
  }

  static bool get isLocked => _isLocked;

  static Future<void> updateSettings() async {
    await _checkAutoLock();
  }

  static void dispose() {
    _inactivityTimer?.cancel();
  }
}
