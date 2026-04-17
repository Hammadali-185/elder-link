import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../karachi_time.dart';

class ApiService {
  /// PC LAN IP where Node listens. Override when building/running:
  /// - Android emulator → `flutter run --dart-define=WATCH_API_HOST=10.0.2.2`
  /// - Physical device: `--dart-define=WATCH_API_HOST=<PC IPv4>` or set in watch Settings.
  /// Default matches common Windows mobile-hotspot gateway (same as mobile app).
  static const String _watchApiHost = String.fromEnvironment(
    'WATCH_API_HOST',
    defaultValue: '192.168.137.1',
  );

  static const String _watchApiPort = String.fromEnvironment(
    'WATCH_API_PORT',
    defaultValue: '5000',
  );

  static const Duration _apiTimeout = Duration(seconds: 30);

  static const String _prefsKeyHost = 'watch_api_host';
  static const String _prefsKeyPort = 'watch_api_port';

  static String _runtimeHost = _watchApiHost;
  static String _runtimePort = _watchApiPort;

  /// Returns normalized host + port, or null if invalid.
  static ({String host, String port})? _normalizeHostPort(String host, String port) {
    var nextHost = host.trim();
    var nextPort = port.trim();
    if (nextHost.isEmpty || nextPort.isEmpty) return null;
    nextHost = nextHost.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');
    nextHost = nextHost.replaceAll(RegExp(r'/+$'), '');
    final hp = nextHost.split(':');
    if (hp.length == 2 && hp[0].isNotEmpty && hp[1].isNotEmpty) {
      nextHost = hp[0];
      nextPort = hp[1];
    }
    nextPort = nextPort.replaceAll(RegExp(r'[^0-9]'), '');
    if (nextHost.isEmpty || nextPort.isEmpty) return null;
    final parsedPort = int.tryParse(nextPort);
    if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) return null;
    return (host: nextHost, port: nextPort);
  }

  /// Load backend host/port from persistent storage (no rebuild needed).
  /// Falls back to compile-time values (`--dart-define`) if not set.
  static Future<void> loadNetworkConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final rawHost = prefs.getString(_prefsKeyHost);
    final rawPort = prefs.getString(_prefsKeyPort);

    if (rawHost != null && rawHost.trim().isNotEmpty && rawPort != null && rawPort.trim().isNotEmpty) {
      final n = _normalizeHostPort(rawHost, rawPort);
      if (n != null) {
        _runtimeHost = n.host;
        _runtimePort = n.port;
        await prefs.setString(_prefsKeyHost, n.host);
        await prefs.setString(_prefsKeyPort, n.port);
      }
    }
  }

  static String get apiHost => _runtimeHost;
  static String get apiPort => _runtimePort;

  static Future<void> saveNetworkConfig({required String host, required String port}) async {
    final n = _normalizeHostPort(host, port);
    if (n == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyHost, n.host);
    await prefs.setString(_prefsKeyPort, n.port);
    await prefs.reload();

    _runtimeHost = n.host;
    _runtimePort = n.port;
  }

  /// Quick check: GET /api/readings. Use after saving backend settings.
  /// Returns a short message for the UI (success or actionable error).
  static Future<String> testBackendConnection() async {
    final uri = Uri.parse('$baseUrl/readings');
    try {
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        return 'Connected (HTTP 200). Backend is reachable.';
      }
      return 'Server replied HTTP ${response.statusCode}. Check backend logs.';
    } on TimeoutException {
      return 'Timed out. Same Wi‑Fi as PC? On PC run: ipconfig → use IPv4. '
          'On PC (Admin PowerShell) allow port 5000: '
          'netsh advfirewall firewall add rule name="ElderLink5000" dir=in action=allow protocol=TCP localport=5000';
    } catch (e) {
      return e.toString();
    }
  }

  static String get baseUrl =>
      kIsWeb ? 'http://127.0.0.1:$_runtimePort/api' : 'http://$_runtimeHost:$_runtimePort/api';

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

  static const String _prefsKeyStableReadingUsername = 'watch_stable_reading_username';
  static const String _prefsKeyActiveElderMongoId = 'watch_active_elder_mongo_id';
  static const String _prefsKeyRecentElderMongoIds = 'watch_recent_elder_mongo_ids';
  static const int _maxRecentElderMongoIds = 10;

  /// Persisted per-install id for MongoDB [Reading.username] / heart alerts — **never** the display name.
  /// Using the literal "Watch User" for everyone caused purge-by-name to miss rows and merge elders.
  static String? _stableReadingUsername;

  /// Server [Elder] document id for the active resident (from sync-from-watch response).
  static String? _activeElderMongoId;

  /// Stable API username (device-scoped). Initialized in [loadSavedUserInfo].
  static String get readingUsernameForApi =>
      _stableReadingUsername ?? 'watch_pending_init';

  /// MongoDB id of the active elder, when known — sent as [elderId] on readings/medicines.
  static String? get activeElderMongoId => _activeElderMongoId;

  /// Elders this device has recently synced as (MRU, capped); used to detect staff meds for another resident.
  static Future<List<String>> getRecentElderMongoIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKeyRecentElderMongoIds);
    if (list == null) return [];
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static Future<void> recordElderInRecentHistory(String mongoId) async {
    final id = mongoId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(_prefsKeyRecentElderMongoIds)?.toList() ?? <String>[];
    list.remove(id);
    list.insert(0, id);
    if (list.length > _maxRecentElderMongoIds) {
      list = list.sublist(0, _maxRecentElderMongoIds);
    }
    await prefs.setStringList(_prefsKeyRecentElderMongoIds, list);
    await prefs.reload();
  }

  static Future<void> removeElderIdFromRecentHistory(String mongoId) async {
    final id = mongoId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(_prefsKeyRecentElderMongoIds)?.toList() ?? <String>[];
    list.remove(id);
    await prefs.setStringList(_prefsKeyRecentElderMongoIds, list);
    await prefs.reload();
  }

  static Future<void> _persistActiveElderMongoId(String id) async {
    final v = id.trim();
    if (v.isEmpty) return;
    _activeElderMongoId = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyActiveElderMongoId, v);
    await prefs.reload();
    await recordElderInRecentHistory(v);
  }

  /// When server says elder is gone: drop from MRU and clear active id if it was this elder.
  static Future<void> _clearActiveElderMongoIdIfMatches(String elderId) async {
    final eid = elderId.trim();
    if (eid.isEmpty) return;
    await removeElderIdFromRecentHistory(eid);
    if (_activeElderMongoId != null && _activeElderMongoId!.trim() == eid) {
      _activeElderMongoId = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyActiveElderMongoId);
      await prefs.reload();
    }
  }

  /// Clears local state when [elderIdUsed] is rejected (404, or 400 invalid id / medicines / elder GET).
  static Future<void> handleInvalidElderReference(
    http.Response response,
    String elderIdUsed,
  ) async {
    final id = elderIdUsed.trim();
    if (id.isEmpty) return;
    final code = response.statusCode;
    if (code == 404) {
      await _clearActiveElderMongoIdIfMatches(id);
      return;
    }
    if (code != 400) return;
    final path = response.request?.url.path ?? '';
    final body = response.body;
    if (path.contains('sync-from-watch')) {
      if (body.contains('Invalid elderId') ||
          body.contains('elderId is required') ||
          body.contains('name does not match elderId')) {
        await _clearActiveElderMongoIdIfMatches(id);
      }
      return;
    }
    final medicines = path.endsWith('medicines') || path.contains('/medicines');
    final elderById = RegExp(r'/elders/[a-fA-F0-9]{24}').hasMatch(path);
    if (medicines || elderById) {
      await _clearActiveElderMongoIdIfMatches(id);
    }
  }

  /// After loading prefs: if a persisted active elder id is invalid on the server, clear it immediately.
  static Future<void> validateStoredActiveElderOnLaunch() async {
    final id = _activeElderMongoId?.trim();
    if (id == null || id.isEmpty) return;
    try {
      final response = await _timed(http.get(
        Uri.parse('$baseUrl/elders/$id'),
        headers: {'Content-Type': 'application/json'},
      ));
      if (response.statusCode != 200) {
        await handleInvalidElderReference(response, id);
      }
    } catch (_) {
      // Offline / timeout: do not clear a possibly valid id.
    }
  }

  /// GET /api/elders/:id — for switching My Info to match server elder.
  /// Prefer [fetchElderByIdResult] when you must distinguish "gone" (404/400) from offline/other errors.
  static Future<Map<String, dynamic>?> fetchElderById(String id) async {
    final r = await fetchElderByIdResult(id);
    return r.data;
  }

  /// Same as [fetchElderById], but [serverRejectedElder] is true when the server rejected this id (404/400);
  /// [handleInvalidElderReference] already prunes MRU / active elder when applicable.
  static Future<({Map<String, dynamic>? data, bool serverRejectedElder})> fetchElderByIdResult(
    String id,
  ) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return (data: null, serverRejectedElder: false);
    }
    try {
      final response = await _timed(http.get(
        Uri.parse('$baseUrl/elders/$trimmed'),
        headers: {'Content-Type': 'application/json'},
      ));
      if (response.statusCode == 404 || response.statusCode == 400) {
        await handleInvalidElderReference(response, trimmed);
        return (data: null, serverRejectedElder: true);
      }
      if (response.statusCode != 200) {
        return (data: null, serverRejectedElder: false);
      }
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return (data: data, serverRejectedElder: false);
      }
      return (data: null, serverRejectedElder: false);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('fetchElderById: $e');
      }
      return (data: null, serverRejectedElder: false);
    }
  }

  static List<String>? _cachedServerElderMongoIds;
  static DateTime? _cachedServerElderMongoIdsAt;
  static const Duration _serverElderIdsCacheTtl = Duration(minutes: 3);

  /// GET /api/elders — all elders (newest first). Cached briefly to avoid hammering the server.
  static Future<List<String>> fetchElderMongoIdsFromServer({bool bypassCache = false}) async {
    if (!bypassCache &&
        _cachedServerElderMongoIds != null &&
        _cachedServerElderMongoIdsAt != null &&
        DateTime.now().difference(_cachedServerElderMongoIdsAt!) < _serverElderIdsCacheTtl) {
      return List<String>.from(_cachedServerElderMongoIds!);
    }
    try {
      final response = await _timed(http.get(
        Uri.parse('$baseUrl/elders'),
        headers: {'Content-Type': 'application/json'},
      ));
      if (response.statusCode != 200) {
        return _cachedServerElderMongoIds ?? <String>[];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return _cachedServerElderMongoIds ?? <String>[];
      }
      final oid = RegExp(r'^[a-fA-F0-9]{24}$');
      final out = <String>[];
      for (final e in decoded) {
        if (e is! Map<String, dynamic>) continue;
        final id = (e['_id'] ?? '').toString();
        if (!oid.hasMatch(id)) continue;
        out.add(id);
      }
      _cachedServerElderMongoIds = out;
      _cachedServerElderMongoIdsAt = DateTime.now();
      return List<String>.from(out);
    } catch (_) {
      return _cachedServerElderMongoIds ?? <String>[];
    }
  }

  /// Fills MRU with elders from the server so the watch can switch to residents created only on mobile.
  static Future<void> mergeRecentHistoryWithServerElders({int maxTotal = _maxRecentElderMongoIds}) async {
    final server = await fetchElderMongoIdsFromServer();
    if (server.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(_prefsKeyRecentElderMongoIds)?.toList() ?? <String>[];
    final seen = <String>{...list};
    for (final id in server) {
      if (list.length >= maxTotal) break;
      if (seen.contains(id)) continue;
      list.add(id);
      seen.add(id);
    }
    await prefs.setStringList(_prefsKeyRecentElderMongoIds, list);
    await prefs.reload();
  }

  /// Medicines for a specific elder (e.g. peer on this device); Karachi [dateYmd] defaults to today.
  static Future<List<WatchMedicine>> getMedicinesForElderId(
    String elderId, {
    String? dateYmd,
  }) async {
    lastMedicinesFetchError = null;
    final eid = elderId.trim();
    if (eid.isEmpty) return [];
    try {
      ensureKarachiTimeZones();
      final queryParams = <String, String>{
        'elderId': eid,
        'date': (dateYmd != null && dateYmd.trim().isNotEmpty)
            ? dateYmd.trim()
            : karachiTodayYmd(),
      };
      final url = '$baseUrl/medicines?${Uri(queryParameters: queryParams).query}';
      final response = await _timed(http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((json) => WatchMedicine.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
      }
      if (response.statusCode == 404 || response.statusCode == 400) {
        await handleInvalidElderReference(response, eid);
        lastMedicinesFetchError = 'Elder not found or invalid';
        return [];
      }
      lastMedicinesFetchError = 'Server returned ${response.statusCode}';
      return [];
    } catch (e) {
      lastMedicinesFetchError = e.toString();
      return [];
    }
  }

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

  /// Applies JSON from [fetchElderById] to local My Info and runs [syncElderProfileToServer] (active id + recent list).
  static Future<bool> applyFetchedElderProfile(Map<String, dynamic> data) async {
    final newName = (data['name'] ?? '').toString().trim();
    if (newName.isEmpty) return false;
    final eid = data['_id']?.toString() ?? data['id']?.toString();
    if (eid != null && eid.trim().isNotEmpty) {
      await _persistActiveElderMongoId(eid.trim());
    }
    updateUserInfo(
      name: newName,
      gender: (data['gender'] ?? 'Male').toString(),
      age: (data['age'] ?? '').toString(),
      disease: data['disease']?.toString(),
      roomNumber: data['roomNumber']?.toString(),
    );
    await syncElderProfileToServer();
    return true;
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

  static Future<void> _ensureStableReadingUsername(SharedPreferences prefs) async {
    var v = prefs.getString(_prefsKeyStableReadingUsername)?.trim();
    if (v == null || v.isEmpty) {
      final r = Random();
      v =
          'watch_${DateTime.now().millisecondsSinceEpoch}_${r.nextInt(0x7fffffff)}';
      await prefs.setString(_prefsKeyStableReadingUsername, v);
    }
    _stableReadingUsername = v;
  }

  static Future<void> loadSavedUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Reload to get latest data (important for Flutter Web)

    await _ensureStableReadingUsername(prefs);

    _activeElderMongoId = prefs.getString(_prefsKeyActiveElderMongoId)?.trim();
    if (_activeElderMongoId != null && _activeElderMongoId!.isEmpty) {
      _activeElderMongoId = null;
    }
    if (_activeElderMongoId != null && _activeElderMongoId!.isNotEmpty) {
      await recordElderInRecentHistory(_activeElderMongoId!);
    }

    userName = prefs.getString('user_name');
    userGender = prefs.getString('user_gender');
    userAge = prefs.getString('user_age');
    userDisease = prefs.getString('user_disease');
    userRoomNumber = prefs.getString('user_room_number');

    // Debug logging
    print('Watch - Loaded saved user info:');
    print('  Stable reading username: $_stableReadingUsername');
    print('  Name: $userName');
    print('  Gender: $userGender');
    print('  Age: $userAge');
    print('  Room: $userRoomNumber');
    print('  Disease: $userDisease');

    await validateStoredActiveElderOnLaunch();
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

  /// Create [Elder] (POST /elders) when no id yet; else update by id (POST /elders/sync-from-watch).
  static Future<void> syncElderProfileToServer() async {
    final name = userName?.trim();
    if (name == null || name.isEmpty) return;
    try {
      final existingId = _activeElderMongoId?.trim();
      if (existingId == null || existingId.isEmpty) {
        final createRes = await _timed(http.post(
          Uri.parse('$baseUrl/elders'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'roomNumber': (userRoomNumber ?? '').trim().isEmpty ? '—' : userRoomNumber!.trim(),
            'age': (userAge ?? '').trim().isEmpty ? '—' : userAge!.trim(),
            'gender': userGender == 'Female' ? 'Female' : 'Male',
            'status': 'stable',
            if (userDisease != null && userDisease!.trim().isNotEmpty)
              'disease': userDisease!.trim(),
            'readingUsername': readingUsernameForApi,
          }),
        ));
        if (createRes.statusCode == 201) {
          try {
            final data = jsonDecode(createRes.body) as Map<String, dynamic>;
            final id = data['_id']?.toString() ?? data['id']?.toString();
            if (id != null && id.isNotEmpty) {
              await _persistActiveElderMongoId(id);
            }
          } catch (_) {}
        }
        if (kDebugMode && createRes.statusCode != 201) {
          // ignore: avoid_print
          print('syncElderProfileToServer create: ${createRes.statusCode} ${createRes.body}');
        }
        return;
      }

      final response = await _timed(http.post(
        Uri.parse('$baseUrl/elders/sync-from-watch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'elderId': existingId,
          'name': name,
          'roomNumber': userRoomNumber ?? '',
          'age': userAge ?? '',
          'gender': userGender ?? 'Male',
          if (userDisease != null && userDisease!.trim().isNotEmpty)
            'disease': userDisease!.trim(),
          'readingUsername': readingUsernameForApi,
        }),
      ));
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final id = data['_id']?.toString() ?? data['id']?.toString();
          if (id != null && id.isNotEmpty) {
            await _persistActiveElderMongoId(id);
          }
        } catch (_) {}
      } else {
        await handleInvalidElderReference(response, existingId);
      }
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
  static Future<Map<String, dynamic>> sendPanicAlert() async {
    try {
      final requestBody = {
        'username': readingUsernameForApi,
        if (_activeElderMongoId != null && _activeElderMongoId!.isNotEmpty)
          'elderId': _activeElderMongoId,
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
    int bp = 0,
    int? bpDiastolic,
    int? heartRate,
    required String status,
    bool vitalsUrgent = false,
    String? alertReason,
    bool emergency = false,
  }) async {
    try {
      final requestBody = {
        'username': readingUsernameForApi,
        if (_activeElderMongoId != null && _activeElderMongoId!.isNotEmpty)
          'elderId': _activeElderMongoId,
        'bp': bp,
        if (bpDiastolic != null && bpDiastolic > 0) 'bpDiastolic': bpDiastolic,
        if (heartRate != null) 'heartRate': heartRate,
        'status': status, // Must be "normal" or "abnormal"
        'emergency': emergency,
        'vitalsUrgent': vitalsUrgent,
        if (alertReason != null && alertReason.isNotEmpty) 'alertReason': alertReason,
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

  // Get medicines for current user (GET /medicines requires elderId only).
  /// [dateYmd] optional `YYYY-MM-DD` in **Asia/Karachi**; defaults to Karachi “today”.
  static Future<List<WatchMedicine>> getMedicines({String? dateYmd}) async {
    lastMedicinesFetchError = null;
    final id = _activeElderMongoId?.trim();
    if (id == null || id.isEmpty) {
      lastMedicinesFetchError =
          'Active elder id required — complete My Info and sync';
      return [];
    }
    try {
      ensureKarachiTimeZones();
      final queryParams = <String, String>{
        'elderId': id,
        'date': (dateYmd != null && dateYmd.trim().isNotEmpty)
            ? dateYmd.trim()
            : karachiTodayYmd(),
      };
      final url = '$baseUrl/medicines?${Uri(queryParameters: queryParams).query}';

      final response = await _timed(http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => WatchMedicine.fromJson(json)).toList();
      }
      if (response.statusCode == 404 || response.statusCode == 400) {
        await handleInvalidElderReference(response, id);
        lastMedicinesFetchError = 'Elder not found or invalid';
        return [];
      }
      lastMedicinesFetchError = 'Server returned ${response.statusCode}';
      return [];
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
    required int heartRate,
  }) async {
    try {
      final requestBody = {
        'username': readingUsernameForApi,
        if (_activeElderMongoId != null && _activeElderMongoId!.isNotEmpty)
          'elderId': _activeElderMongoId,
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
          if (_activeElderMongoId != null && _activeElderMongoId!.isNotEmpty)
            'elderId': _activeElderMongoId,
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

  /// Call periodically while audio is playing so staff "now playing" stays accurate.
  static Future<void> pingMusicSession() async {
    final elderName = userName?.trim();
    final trackId = _activeMusicTrackId;
    if (elderName == null || elderName.isEmpty) return;
    if (trackId == null || trackId.isEmpty) return;
    try {
      await _timed(http.post(
        Uri.parse('$baseUrl/music/heartbeat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'elderName': elderName,
          if (_activeElderMongoId != null && _activeElderMongoId!.isNotEmpty)
            'elderId': _activeElderMongoId,
          'trackId': trackId,
          'at': DateTime.now().toUtc().toIso8601String(),
        }),
      ));
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Music heartbeat error: $e');
      }
    }
  }

  /// [status]: paused | stopped | completed
  static Future<void> endMusicSessionMeta(String status) async {
    final elderName = userName?.trim();
    final trackId = _activeMusicTrackId;
    if (elderName == null || elderName.isEmpty) return;
    if (trackId == null || trackId.isEmpty) return;
    var clearLocal = false;
    try {
      final response = await _timed(http.post(
        Uri.parse('$baseUrl/music/stop'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'elderName': elderName,
          if (_activeElderMongoId != null && _activeElderMongoId!.isNotEmpty)
            'elderId': _activeElderMongoId,
          'trackId': trackId,
          'status': status,
          'stoppedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      ));
      final code = response.statusCode;
      clearLocal = (code >= 200 && code < 300) || code == 404;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Music session end error: $e');
      }
    }
    if (clearLocal) {
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
