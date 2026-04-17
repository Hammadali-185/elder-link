import 'package:elderlink/karachi_time.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _pushNotifications = true;
  static bool _criticalAlerts = true;
  static bool _medicineReminders = true;
  static bool _healthUpdates = true;
  static bool _initialized = false;
  static bool _permissionRequested = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'elderlink_alerts',
      'ElderLink Alerts',
      description: 'Critical health alerts and emergency notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(androidChannel);
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        print('Notification tapped: ${details.payload}');
      },
    );
    _initialized = true;
  }

  /// Request OS notification permissions (Android 13+/iOS).
  ///
  /// Intentionally separate from [initialize] so app startup is not blocked on
  /// a permission dialog before the first Flutter frame is drawn.
  static Future<void> requestPermissions() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    if (!_initialized) {
      await initialize();
    }
    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    // Android 13+ requires notification permission
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
    }

    // iOS requires permission
    final ios = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      await ios.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _pushNotifications = prefs.getBool('notif_push') ?? true;
    _criticalAlerts = prefs.getBool('notif_critical') ?? true;
    _medicineReminders = prefs.getBool('notif_medicine') ?? true;
    _healthUpdates = prefs.getBool('notif_health') ?? true;
  }

  static bool get pushNotifications => _pushNotifications;
  static bool get criticalAlerts => _criticalAlerts;
  static bool get medicineReminders => _medicineReminders;
  static bool get healthUpdates => _healthUpdates;

  // Check if we should send/show a notification
  static bool shouldNotify(String type) {
    if (!_pushNotifications) return false;

    switch (type) {
      case 'critical':
        return _criticalAlerts;
      case 'medicine':
        return _medicineReminders;
      case 'health':
        return _healthUpdates;
      default:
        return true;
    }
  }

  // Send notification with person details
  static Future<void> sendNotification({
    required String title,
    required String body,
    required String type,
    String? personName,
    String? timestamp,
    Map<String, dynamic>? payload,
    bool androidMaxImportance = false,
  }) async {
    if (!shouldNotify(type)) {
      print('Notification blocked: $type notifications are disabled');
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    // Format notification body with person details
    String notificationBody = body;
    if (personName != null && personName.isNotEmpty) {
      notificationBody = '$personName: $body';
    }
    if (timestamp != null) {
      notificationBody += ' • $timestamp';
    }

    final androidDetails = AndroidNotificationDetails(
      'elderlink_alerts',
      'ElderLink Alerts',
      channelDescription: 'Critical health alerts and emergency notifications',
      importance: androidMaxImportance ? Importance.max : Importance.high,
      priority: androidMaxImportance ? Priority.max : Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      notificationBody,
      details,
      payload: payload != null ? payload.toString() : null,
    );

    print('📢 Notification sent: $title - $notificationBody (Type: $type)');
  }

  // Send panic alert notification
  static Future<void> sendPanicAlert({
    required String personName,
    required DateTime timestamp,
  }) async {
    final timeStr = _formatTime(timestamp);
    await sendNotification(
      title: '🚨 Emergency Alert',
      body: 'Panic button pressed',
      type: 'critical',
      personName: personName,
      timestamp: timeStr,
      payload: {'type': 'panic', 'personName': personName},
    );
  }

  // Send health alert notification
  static Future<void> sendHealthAlert({
    required String personName,
    required String status,
    required int bp,
    int? heartRate,
    required DateTime timestamp,
  }) async {
    final timeStr = _formatTime(timestamp);
    String body;
    final hasHeartRate = (heartRate ?? 0) > 0;
    final hasBp = bp > 0;
    final readingLabel = hasBp && hasHeartRate
        ? 'BP: $bp, HR: $heartRate BPM'
        : hasHeartRate
            ? 'Heart rate: $heartRate BPM'
            : 'BP: $bp';
    if (status == 'abnormal') {
      body = 'Abnormal health reading detected ($readingLabel)';
    } else {
      body = 'Health reading: $readingLabel';
    }

    await sendNotification(
      title: status == 'abnormal' ? '⚠️ Abnormal vitals' : 'Health Update',
      body: body,
      type: 'health',
      personName: personName,
      timestamp: timeStr,
      payload: {
        'type': 'health',
        'personName': personName,
        'status': status,
        'bp': bp,
        'heartRate': heartRate ?? 0,
      },
    );
  }

  static String _vitalsDetail({
    required int systolic,
    required int diastolic,
    int? heartRate,
  }) {
    final parts = <String>[];
    if (systolic > 0 || diastolic > 0) {
      parts.add('BP $systolic/$diastolic');
    }
    if ((heartRate ?? 0) > 0) {
      parts.add('HR $heartRate BPM');
    }
    return parts.isEmpty ? '' : ' (${parts.join(' · ')})';
  }

  /// Warning tier (out of range but not BP crisis band).
  static Future<void> sendVitalsWarningAlert({
    required String personName,
    required String alertReason,
    required DateTime timestamp,
    int systolic = 0,
    int diastolic = 0,
    int? heartRate,
  }) async {
    final timeStr = _formatTime(timestamp);
    final detail = _vitalsDetail(
      systolic: systolic,
      diastolic: diastolic,
      heartRate: heartRate,
    );
    await sendNotification(
      title: '⚠️ Vitals warning',
      body: '$alertReason$detail',
      type: 'health',
      personName: personName,
      timestamp: timeStr,
      androidMaxImportance: true,
      payload: {
        'type': 'vitals_warning',
        'personName': personName,
        'alertReason': alertReason,
      },
    );
  }

  /// Critical BP (e.g. ≥180 systolic or ≥120 diastolic) — highest priority.
  static Future<void> sendCriticalVitalsAlert({
    required String personName,
    required String alertReason,
    required DateTime timestamp,
    int systolic = 0,
    int diastolic = 0,
    int? heartRate,
  }) async {
    final timeStr = _formatTime(timestamp);
    final detail = _vitalsDetail(
      systolic: systolic,
      diastolic: diastolic,
      heartRate: heartRate,
    );
    await sendNotification(
      title: '🚨 Critical vitals',
      body: '$alertReason$detail',
      type: 'critical',
      personName: personName,
      timestamp: timeStr,
      androidMaxImportance: true,
      payload: {
        'type': 'vitals_critical',
        'personName': personName,
        'alertReason': alertReason,
      },
    );
  }

  static String _formatTime(DateTime dateTime) {
    ensureKarachiTimeZones();
    final wall = utcInstantToKarachiWall(dateTime.toUtc());
    final hour = wall.hour;
    final minute = wall.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
