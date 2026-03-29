import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  /// PC LAN IP where Node listens. Override when building/running:
  /// - Android emulator → host: `flutter run --dart-define=WATCH_API_HOST=10.0.2.2`
  /// - Physical watch / phone on Wi‑Fi: `--dart-define=WATCH_API_HOST=<your PC LAN IP>`
  static const String _watchApiHost = String.fromEnvironment(
    'WATCH_API_HOST',
    defaultValue: '192.168.100.112',
  );

  static const String _watchApiPort = String.fromEnvironment(
    'WATCH_API_PORT',
    defaultValue: '5000',
  );

  static const Duration _apiTimeout = Duration(seconds: 20);

  static String get baseUrl => kIsWeb
      ? 'http://127.0.0.1:$_watchApiPort/api'
      : 'http://$_watchApiHost:$_watchApiPort/api';

  /// Set when the last medicines GET failed (network, timeout, or non-200). Cleared on success.
  static String? lastMedicinesFetchError;

  static Future<http.Response> _timed(Future<http.Response> future) {
    return future.timeout(
      _apiTimeout,
      onTimeout: () => throw TimeoutException('Request timed out after $_apiTimeout', _apiTimeout),
    );
  }

  static void debugLogEndpoint() {
    if (kDebugMode) {
      // ignore: avoid_print
      print('ApiService: baseUrl=$baseUrl');
    }
  }

  // Basic user info to include with alerts/readings
  static String? userName;
  static String? userGender;
  static String? userAge;
  static String? userDisease; // optional
  static String? userRoomNumber; // optional

  static void updateUserInfo({
    required String name,
    required String gender,
    required String age,
    String? disease,
    String? roomNumber,
  }) {
    userName = name.trim();
    userGender = gender.trim();
    userAge = age.trim();
    userDisease = disease?.trim().isEmpty == true ? null : disease?.trim();
    userRoomNumber = roomNumber?.trim().isEmpty == true ? null : roomNumber?.trim();
    _persistUserInfo();
  }

  static Map<String, dynamic> _userInfoPayload() {
    return {
      if (userName != null && userName!.isNotEmpty) 'personName': userName,
      if (userGender != null && userGender!.isNotEmpty) 'gender': userGender,
      if (userAge != null && userAge!.isNotEmpty) 'age': userAge,
      if (userDisease != null && userDisease!.isNotEmpty) 'disease': userDisease,
      if (userRoomNumber != null && userRoomNumber!.isNotEmpty) 'roomNumber': userRoomNumber,
    };
  }

  static Future<void> loadSavedUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Reload to get latest data (important for Flutter Web)
    
    userName = prefs.getString('user_name');
    userGender = prefs.getString('user_gender');
    userAge = prefs.getString('user_age');
    userDisease = prefs.getString('user_disease');
    userRoomNumber = prefs.getString('user_room_number');
    
    // Debug logging
    print('Watch - Loaded saved user info:');
    print('  Name: $userName');
    print('  Gender: $userGender');
    print('  Age: $userAge');
    print('  Room: $userRoomNumber');
    print('  Disease: $userDisease');
  }

  static Future<void> _persistUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', userName ?? '');
    await prefs.setString('user_gender', userGender ?? '');
    await prefs.setString('user_age', userAge ?? '');
    await prefs.setString('user_disease', userDisease ?? '');
    await prefs.setString('user_room_number', userRoomNumber ?? '');
    
    // Reload to ensure persistence (important for Flutter Web)
    await prefs.reload();
    
    // Debug logging
    print('Watch - Saved user info:');
    print('  Name: $userName');
    print('  Gender: $userGender');
    print('  Age: $userAge');
    print('  Room: $userRoomNumber');
    print('  Disease: $userDisease');
  }

  /// Upsert [Elder] on the server from My Info so staff Medicines screen can select this person.
  static Future<void> syncElderProfileToServer() async {
    final name = userName?.trim();
    if (name == null || name.isEmpty) return;
    try {
      final response = await _timed(http.post(
        Uri.parse('$baseUrl/elders/sync-from-watch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'roomNumber': userRoomNumber ?? '',
          'age': userAge ?? '',
          'gender': userGender ?? 'Male',
          if (userDisease != null && userDisease!.trim().isNotEmpty)
            'disease': userDisease!.trim(),
        }),
      ));
      if (kDebugMode && response.statusCode != 200 && response.statusCode != 201) {
        // ignore: avoid_print
        print('syncElderProfileToServer: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('syncElderProfileToServer error: $e');
      }
    }
  }

  // Send panic alert
  static Future<Map<String, dynamic>> sendPanicAlert({
    required String username,
  }) async {
    try {
      final requestBody = {
        'username': username,
        'bp': 0, // Required by schema
        'status': 'abnormal', // Must be "normal" or "abnormal"
        'emergency': true,
        // timestamp will be set automatically by Mongoose default
        ..._userInfoPayload(),
      };
      
      print('Sending panic alert with data: $requestBody');
      
      final response = await _timed(http.post(
        Uri.parse('$baseUrl/readings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': response.body};
      }
    } catch (e) {
      print('Error sending panic alert: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Send health reading
  static Future<Map<String, dynamic>> sendHealthReading({
    required String username,
    int bp = 0,
    int? heartRate,
    required String status,
  }) async {
    try {
      final requestBody = {
        'username': username,
        'bp': bp,
        if (heartRate != null) 'heartRate': heartRate,
        'status': status, // Must be "normal" or "abnormal"
        'emergency': false,
        // timestamp will be set automatically by Mongoose default
        ..._userInfoPayload(),
      };
      
      final response = await _timed(http.post(
        Uri.parse('$baseUrl/readings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ));

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get medicines for current user
  static Future<List<WatchMedicine>> getMedicines({DateTime? date}) async {
    lastMedicinesFetchError = null;
    try {
      String url = '$baseUrl/medicines';
      final queryParams = <String, String>{};
      
      if (userName != null && userName!.isNotEmpty) {
        queryParams['elderName'] = userName!;
      }
      
      if (date != null) {
        queryParams['date'] = date.toIso8601String().split('T')[0];
      }
      
      if (queryParams.isNotEmpty) {
        url += '?${Uri(queryParameters: queryParams).query}';
      }
      
      final response = await _timed(http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => WatchMedicine.fromJson(json)).toList();
      } else {
        lastMedicinesFetchError = 'Server returned ${response.statusCode}';
        return [];
      }
    } catch (e) {
      print('Error fetching medicines: $e');
      lastMedicinesFetchError = e.toString();
      return [];
    }
  }

  // Update medicine status
  static Future<bool> updateMedicineStatus(String medicineId, String status) async {
    try {
      final response = await _timed(http.put(
        Uri.parse('$baseUrl/medicines/$medicineId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      ));

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating medicine status: $e');
      return false;
    }
  }

  // Send heart alert (abnormal heart rate detected)
  static Future<Map<String, dynamic>> sendHeartAlert({
    required String username,
    required int heartRate,
  }) async {
    try {
      final requestBody = {
        'username': username,
        'heartRate': heartRate,
        'status': 'abnormal',
        'timestamp': DateTime.now().toIso8601String(),
        ..._userInfoPayload(),
      };
      
      print('Sending heart alert: $requestBody');
      
      final response = await _timed(http.post(
        Uri.parse('$baseUrl/heart-alert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': response.body};
      }
    } catch (e) {
      print('Error sending heart alert: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Currently reported music track; metadata only, never audio bytes.
  static String? _activeMusicTrackId;

  static Future<void> startMusicSessionMeta({
    required String trackId,
    required String title,
    String? artist,
    required String category,
  }) async {
    final elderName = userName?.trim();
    if (elderName == null || elderName.isEmpty) return;
    try {
      final response = await _timed(http.post(
        Uri.parse('$baseUrl/music/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'elderName': elderName,
          'trackId': trackId,
          'title': title,
          'artist': artist ?? '',
          'category': category,
          'startedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      ));
      if (response.statusCode == 201 || response.statusCode == 200) {
        _activeMusicTrackId = trackId;
      } else if (kDebugMode) {
        // ignore: avoid_print
        print('Music session start failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Music session start error: $e');
      }
    }
  }

  /// [status]: paused | stopped | completed
  static Future<void> endMusicSessionMeta(String status) async {
    final elderName = userName?.trim();
    final trackId = _activeMusicTrackId;
    if (elderName == null || elderName.isEmpty) return;
    if (trackId == null || trackId.isEmpty) return;
    try {
      await _timed(http.post(
        Uri.parse('$baseUrl/music/stop'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'elderName': elderName,
          'trackId': trackId,
          'status': status,
          'stoppedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      ));
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Music session end error: $e');
      }
    } finally {
      _activeMusicTrackId = null;
    }
  }
}

class WatchMedicine {
  final String id;
  final String elderName;
  final String medicineName;
  final String dosage;
  final String time;
  final String status;
  final DateTime scheduledDate;

  WatchMedicine({
    required this.id,
    required this.elderName,
    required this.medicineName,
    required this.dosage,
    required this.time,
    required this.status,
    required this.scheduledDate,
  });

  factory WatchMedicine.fromJson(Map<String, dynamic> json) {
    return WatchMedicine(
      id: json['_id'] ?? json['id'] ?? '',
      elderName: json['elderName'] ?? '',
      medicineName: json['medicineName'] ?? '',
      dosage: json['dosage'] ?? '',
      time: json['time'] ?? '',
      status: json['status'] ?? 'pending',
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'])
          : DateTime.now(),
    );
  }
}
