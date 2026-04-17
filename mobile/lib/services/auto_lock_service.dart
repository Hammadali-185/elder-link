import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AutoLockService {
  static Timer? _inactivityTimer;
  static DateTime? _lastActivityTime;
  static bool _isLocked = false;
  static void Function()? _onLockCallback;

  static Future<void> initialize(void Function() onLock) async {
    _onLockCallback = onLock;
    await _restartTimerIfNeeded();
  }

  /// Starts or stops the periodic check from current prefs. Safe to call after settings change.
  static Future<void> _restartTimerIfNeeded() async {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;

    final prefs = await SharedPreferences.getInstance();
    final autoLockEnabled = prefs.getBool('security_autolock') ?? true;
    if (!autoLockEnabled) {
      return;
    }

    // Frequent ticks so short timeouts (e.g. 1 min) and setting changes apply reliably.
    _inactivityTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _tick();
    });
  }

  static Future<void> _tick() async {
    if (_isLocked) return;

    final prefs = await SharedPreferences.getInstance();
    final autoLockEnabled = prefs.getBool('security_autolock') ?? true;
    if (!autoLockEnabled) {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
      return;
    }

    final lockMinutes = prefs.getInt('security_autolock_minutes') ?? 5;
    final last = _lastActivityTime;
    if (last == null) return;

    final inactive = DateTime.now().difference(last);
    if (inactive >= Duration(minutes: lockMinutes)) {
      await lockApp();
    }
  }

  static void updateActivity() {
    _lastActivityTime = DateTime.now();
    _isLocked = false;
  }

  static Future<void> lockApp() async {
    if (_isLocked) return;

    _isLocked = true;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    print('🔒 App auto-locked due to inactivity');
    
    _onLockCallback?.call();
  }

  static void unlockApp() {
    _isLocked = false;
    updateActivity();
  }

  static bool get isLocked => _isLocked;

  static Future<void> updateSettings() async {
    await _restartTimerIfNeeded();
  }

  static void dispose() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _onLockCallback = null;
  }
}
