import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elderlink/karachi_time.dart';

class ApiService {
  static const String _prefsKeyHost = 'mobile_api_host';
  static const String _prefsKeyPort = 'mobile_api_port';

  /// Build-time override, e.g. Android emulator → `MOBILE_API_HOST=10.0.2.2`
  /// Default `192.168.137.1` is the usual Windows mobile-hotspot gateway (physical phone).
  static const String _envHost = String.fromEnvironment(
    'MOBILE_API_HOST',
    defaultValue: '192.168.137.1',
  );
  static const String _envPort = String.fromEnvironment(
    'MOBILE_API_PORT',
    defaultValue: '5000',
  );

  static String _runtimeHost = _envHost;
  static String _runtimePort = _envPort;

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

  /// Call from [main] before [runApp]. Loads saved host/port for physical APKs.
  static Future<void> loadNetworkConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final rawHost = prefs.getString(_prefsKeyHost);
    final rawPort = prefs.getString(_prefsKeyPort);
    if (rawHost != null && rawHost.trim().isNotEmpty && rawPort != null && rawPort.trim().isNotEmpty) {
      final n = _normalizeHostPort(rawHost, rawPort);
      if (n != null) {
        var host = n.host;
        final port = n.port;
        // On a real phone, 127.0.0.1 / localhost is the device, not the laptop (older APKs defaulted wrong).
        if (!kIsWeb && (host == '127.0.0.1' || host == 'localhost')) {
          host = _envHost;
        }
        _runtimeHost = host;
        _runtimePort = port;
        await prefs.setString(_prefsKeyHost, host);
        await prefs.setString(_prefsKeyPort, port);
      }
    }
  }

  static String get apiHost => _runtimeHost.trim();
  static String get apiPort => _runtimePort.trim();

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

  /// Web: `localhost` + server PNA header avoids Chrome "Failed to fetch" to loopback.
  /// Native: saved host/port or dart-define; default LAN IP for hotspot (not 127.0.0.1 — that is the phone itself).
  ///
  /// Use [pathSegments] under `/api/...` so paths are never built from fragile string concat
  /// (avoids rare `purge- elder` style URLs if host/port ever contained stray whitespace).
  static Uri _apiUri(List<String> pathAfterApi) {
    final port = int.tryParse(_runtimePort.trim()) ?? 5000;
    if (kIsWeb) {
      return Uri(
        scheme: 'http',
        host: 'localhost',
        port: port,
        pathSegments: ['api', ...pathAfterApi],
      );
    }
    return Uri(
      scheme: 'http',
      host: _runtimeHost.trim(),
      port: port,
      pathSegments: ['api', ...pathAfterApi],
    );
  }

  static String get baseUrl => _apiUri([]).toString();

  /// GET /api/backend-info - confirms the host:port is ElderLink (not another app on 5000).
  static Future<String> probeElderLinkBackend() async {
    final uri = _apiUri(['backend-info']);
    try {
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return 'backend-info HTTP ${response.statusCode}. Body: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}';
      }
      final map = jsonDecode(response.body);
      if (map is! Map) return 'backend-info: unexpected JSON shape';
      if (map['service'] != 'elderlink') {
        return 'This server is not ElderLink (service=${map['service']}). Wrong process on this port?';
      }
      return 'ElderLink OK. backend-info returned service=elderlink.';
    } on TimeoutException {
      return 'backend-info timed out. Check IP/port and Wi-Fi.';
    } catch (e) {
      return 'backend-info error: $e';
    }
  }

  /// GET /api/purge-elder - must return JSON when delete-from-app will work.
  static Future<String> probePurgeElderGet() async {
    final uri = _apiUri(['purge-elder']);
    try {
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return 'purge-elder GET HTTP ${response.statusCode}. If HTML "Cannot GET", this is not ElderLink or routes are missing. Body snippet: ${response.body.length > 160 ? response.body.substring(0, 160) : response.body}';
      }
      final map = jsonDecode(response.body);
      if (map is! Map || map['ok'] != true) {
        return 'purge-elder GET: unexpected JSON (expected ok: true)';
      }
      return 'purge-elder GET OK (JSON). Delete-from-app should reach the server.';
    } on TimeoutException {
      return 'purge-elder GET timed out.';
    } catch (e) {
      return 'purge-elder GET error: $e';
    }
  }

  /// Full check for Backend settings screen (ASCII only in messages).
  static Future<String> runBackendPurgeDiagnostics() async {
    final a = await probeElderLinkBackend();
    final b = await probePurgeElderGet();
    return '$a\n$b\nbaseUrl=$baseUrl';
  }

  static const Duration _apiTimeout = Duration(seconds: 30);

  static Future<http.Response> _timed(Future<http.Response> future) {
    return future.timeout(
      _apiTimeout,
      onTimeout: () => throw TimeoutException('Request timed out after $_apiTimeout', _apiTimeout),
    );
  }

  static const String _prefsKeyActiveElderMongoId = 'mobile_active_elder_mongo_id';

  static String? _activeElderMongoId;

  /// Optional persisted active elder (e.g. resident session); cleared when the server rejects that id.
  static String? get activeElderMongoId => _activeElderMongoId;

  static Future<void> persistActiveElderMongoId(String id) async {
    final v = id.trim();
    if (v.isEmpty) return;
    _activeElderMongoId = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyActiveElderMongoId, v);
    await prefs.reload();
  }

  static Future<void> _clearActiveElderMongoIdIfMatches(String elderId) async {
    final eid = elderId.trim();
    if (eid.isEmpty) return;
    if (_activeElderMongoId != null && _activeElderMongoId!.trim() == eid) {
      _activeElderMongoId = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyActiveElderMongoId);
      await prefs.reload();
    }
  }

  /// Clears persisted active elder when [elderIdUsed] is rejected (404, or 400 invalid id / medicines / elder GET).
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
    } catch (_) {}
  }

  static Future<String> testBackendConnection() async {
    final uri = Uri.parse('$baseUrl/readings');
    try {
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        return 'Connected (HTTP 200). Backend is reachable.';
      }
      return 'Server replied HTTP ${response.statusCode}.';
    } on TimeoutException {
      return 'Timed out. On a real phone, set Backend to your PC IP (e.g. laptop hotspot 192.168.137.1).';
    } catch (e) {
      return e.toString();
    }
  }

  static void debugLogEndpoint() {
    if (kDebugMode) {
      // ignore: avoid_print
      print('ApiService: baseUrl=$baseUrl');
    }
  }

  // Fetch all readings
  static Future<List<Reading>> getAllReadings() async {
    try {
      print('Fetching readings from: $baseUrl/readings');
      // No custom headers on GET — avoids CORS preflight on Flutter web / Chrome.
      final response = await http.get(Uri.parse('$baseUrl/readings'));

      print('Readings response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Readings fetched: ${data.length}');
        final readings = data.map((json) => Reading.fromJson(json)).toList();
        
        // Debug: Print first few readings
        if (readings.isNotEmpty) {
          print('Sample reading: ${readings.first.personName ?? readings.first.username}');
        }
        
        return readings;
      } else {
        print('Failed to load readings: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load readings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching readings: $e');
      // Return empty list instead of throwing to prevent UI crashes
      return [];
    }
  }

  // Fetch readings by username
  static Future<List<Reading>> getReadingsByUser(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/readings/user/$username'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Reading.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load readings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching readings: $e');
      throw Exception('Failed to fetch readings: $e');
    }
  }

  // Fetch all elders
  static Future<List<Elder>> getAllElders() async {
    try {
      print('Fetching elders from: $baseUrl/elders');
      final response = await http.get(Uri.parse('$baseUrl/elders'));

      print('Elders response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Manual elders fetched: ${data.length}');
        return data.map((json) => Elder.fromJson(json)).toList();
      } else {
        print('Failed to load elders: ${response.statusCode} - ${response.body}');
        // Return empty list instead of throwing
        return [];
      }
    } catch (e) {
      print('Error fetching elders: $e');
      // Return empty list instead of throwing to prevent UI crashes
      return [];
    }
  }

  /// Deletes an elder record from the server (manual elders from staff app).
  static Future<void> deleteElder(String id) async {
    if (id.isEmpty) {
      throw Exception('Invalid elder id');
    }
    try {
      final response = await http.delete(Uri.parse('$baseUrl/elders/$id'));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete elder: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting elder: $e');
      rethrow;
    }
  }

  /// Removes readings, medicines, music sessions, heart alerts, medicine events, and elder profile for this person.
  ///
  /// [readingUsername]: value from [Reading.username] for this elder (watch stable id or legacy "Watch User").
  /// Sends it to the backend so rows with empty personName tied to that device are purged.
  static Future<Map<String, dynamic>> purgeElderAllData({
    required String elderName,
    String? elderMongoId,
    String? readingUsername,
  }) async {
    final trimmed = elderName.trim();
    if (trimmed.isEmpty) {
      throw Exception('Elder name is required');
    }
    try {
      final body = <String, dynamic>{'elderName': trimmed};
      if (elderMongoId != null && elderMongoId.isNotEmpty) {
        body['elderId'] = elderMongoId;
      }
      final ru = readingUsername?.trim();
      if (ru != null && ru.isNotEmpty) {
        body['readingUsername'] = ru;
      }
      // Hyphen-free paths first (some stacks mis-handle `-` in paths). Then legacy paths.
      final uris = <Uri>[
        _apiUri(['readings', 'admin', 'purgeelder']),
        _apiUri(['purge_elder']),
        _apiUri(['elders', 'purge']),
        _apiUri(['purge-elder']),
        _apiUri(['readings', 'admin', 'purge-elder']),
      ];
      // ignore: avoid_print
      print('purgeElderAllData baseUrl=$baseUrl');
      for (final u in uris) {
        // ignore: avoid_print
        print('purge try POST $u');
      }
      http.Response? lastResponse;
      Uri? lastAttemptUri;
      Object? networkError;
      for (final uri in uris) {
        lastAttemptUri = uri;
        try {
          final r = await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 25));
          lastResponse = r;
          if (r.statusCode == 200) {
            return jsonDecode(r.body) as Map<String, dynamic>;
          }
          if (r.statusCode != 404) {
            throw Exception('Purge failed: ${r.statusCode} ${r.body}');
          }
        } catch (e) {
          if (e is Exception &&
              e.toString().startsWith('Exception: Purge failed:') &&
              !e.toString().contains('404')) {
            rethrow;
          }
          networkError = e;
        }
      }
      final tail = networkError != null ? ' Network: $networkError' : '';
      throw Exception(
        'Purge failed: all purge URLs returned 404 or failed. '
        'last POST tried: $lastAttemptUri. '
        'Last response: ${lastResponse?.statusCode} ${lastResponse?.body}$tail. '
        'Restart Node from elderlink/backend. In phone browser open '
        'http://${apiHost}:${apiPort}/api/backend-info then '
        'http://${apiHost}:${apiPort}/api/purge-elder '
        '(both must return JSON). Backend settings: Verify ElderLink and purge API.',
      );
    } catch (e) {
      print('Error purging elder: $e');
      rethrow;
    }
  }

  // Add new elder
  static Future<Elder> addElder({
    required String name,
    required String roomNumber,
    required String age,
    String? disease,
    required String status,
    required String gender,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/elders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'roomNumber': roomNumber,
          'age': age,
          'disease': disease,
          'status': status,
          'gender': gender,
        }),
      );

      if (response.statusCode == 201) {
        return Elder.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to add elder: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding elder: $e');
      throw Exception('Failed to add elder: $e');
    }
  }

  static String _ymdKarachi(DateTime dt) {
    final wall = utcInstantToKarachiWall(dt.toUtc());
    final m = wall.month.toString().padLeft(2, '0');
    final d = wall.day.toString().padLeft(2, '0');
    return '${wall.year}-$m-$d';
  }

  // Get medicines (server requires elderId only).
  static Future<List<Medicine>> getMedicines({
    required String elderId,
    DateTime? date,
  }) async {
    try {
      final id = elderId.trim();
      if (id.isEmpty) {
        throw Exception('elderId is required');
      }
      String url = '$baseUrl/medicines';
      final queryParams = <String, String>{'elderId': id};

      if (date != null) {
        ensureKarachiTimeZones();
        queryParams['date'] = _ymdKarachi(date);
      }

      url += '?${Uri(queryParameters: queryParams).query}';

      final response = await _timed(http.get(Uri.parse(url)));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Medicine.fromJson(json)).toList();
      }
      if (response.statusCode == 404 || response.statusCode == 400) {
        await handleInvalidElderReference(response, id);
      }
      throw Exception('Failed to load medicines: ${response.statusCode}');
    } catch (e) {
      print('Error fetching medicines: $e');
      throw Exception('Failed to fetch medicines: $e');
    }
  }

  // Add medicine (elderId required; server sets denormalized elderName).
  static Future<Medicine> addMedicine({
    required String elderId,
    String? elderRoomNumber,
    required String medicineName,
    required String dosage,
    required String time,
    String frequency = "daily",
    required DateTime scheduledDate,
  }) async {
    try {
      final id = elderId.trim();
      if (id.isEmpty) {
        throw Exception('elderId is required');
      }
      final roomOpt = elderRoomNumber?.trim();
      final response = await _timed(http.post(
        Uri.parse('$baseUrl/medicines'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'elderId': id,
          if (roomOpt != null && roomOpt.isNotEmpty) 'elderRoomNumber': roomOpt,
          'medicineName': medicineName,
          'dosage': dosage,
          'time': time,
          'frequency': frequency,
          'scheduledDate': scheduledDate.toIso8601String(),
        }),
      ));

      if (response.statusCode == 201) {
        return Medicine.fromJson(jsonDecode(response.body));
      }
      if (response.statusCode == 404 ||
          response.statusCode == 400 ||
          response.statusCode == 409) {
        await handleInvalidElderReference(response, id);
      }
      throw Exception('Failed to add medicine: ${response.statusCode}');
    } catch (e) {
      print('Error adding medicine: $e');
      throw Exception('Failed to add medicine: $e');
    }
  }

  // Update medicine status
  static Future<Medicine> updateMedicineStatus(String medicineId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/medicines/$medicineId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        return Medicine.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update medicine status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating medicine status: $e');
      throw Exception('Failed to update medicine status: $e');
    }
  }

  // ========== ELDER USER METHODS ==========
  // Elder user info (for watch UI mode)
  static String? elderUserName;
  static String? elderUserGender;
  static String? elderUserAge;
  static String? elderUserDisease;
  static String? elderUserRoomNumber;

  static void updateElderUserInfo({
    required String name,
    required String gender,
    required String age,
    String? disease,
    String? roomNumber,
  }) {
    elderUserName = name.trim();
    elderUserGender = gender.trim();
    elderUserAge = age.trim();
    elderUserDisease = disease?.trim().isEmpty == true ? null : disease?.trim();
    elderUserRoomNumber = roomNumber?.trim().isEmpty == true ? null : roomNumber?.trim();
    _persistElderUserInfo();
  }

  static Map<String, dynamic> _elderUserInfoPayload() {
    return {
      if (elderUserName != null && elderUserName!.isNotEmpty) 'personName': elderUserName,
      if (elderUserGender != null && elderUserGender!.isNotEmpty) 'gender': elderUserGender,
      if (elderUserAge != null && elderUserAge!.isNotEmpty) 'age': elderUserAge,
      if (elderUserDisease != null && elderUserDisease!.isNotEmpty) 'disease': elderUserDisease,
      if (elderUserRoomNumber != null && elderUserRoomNumber!.isNotEmpty) 'roomNumber': elderUserRoomNumber,
    };
  }

  static Future<void> loadSavedElderUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    _activeElderMongoId = prefs.getString(_prefsKeyActiveElderMongoId)?.trim();
    if (_activeElderMongoId != null && _activeElderMongoId!.isEmpty) {
      _activeElderMongoId = null;
    }

    elderUserName = prefs.getString('elder_user_name');
    elderUserGender = prefs.getString('elder_user_gender');
    elderUserAge = prefs.getString('elder_user_age');
    elderUserDisease = prefs.getString('elder_user_disease');
    elderUserRoomNumber = prefs.getString('elder_user_room_number');
    
    print('Elder - Loaded saved user info:');
    print('  Name: $elderUserName');
    print('  Gender: $elderUserGender');
    print('  Age: $elderUserAge');
    print('  Room: $elderUserRoomNumber');

    await validateStoredActiveElderOnLaunch();
  }

  static Future<void> _persistElderUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('elder_user_name', elderUserName ?? '');
    await prefs.setString('elder_user_gender', elderUserGender ?? '');
    await prefs.setString('elder_user_age', elderUserAge ?? '');
    await prefs.setString('elder_user_disease', elderUserDisease ?? '');
    await prefs.setString('elder_user_room_number', elderUserRoomNumber ?? '');
    await prefs.reload();
  }

  // Send panic alert (elder)
  static Future<Map<String, dynamic>> sendPanicAlert({
    required String username,
  }) async {
    try {
      final requestBody = {
        'username': username,
        'bp': 0,
        'status': 'abnormal',
        'emergency': true,
        ..._elderUserInfoPayload(),
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/readings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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

  // Send health reading (elder)
  static Future<Map<String, dynamic>> sendHealthReading({
    required String username,
    required int bp,
    required String status,
  }) async {
    try {
      final requestBody = {
        'username': username,
        'bp': bp,
        'status': status,
        'emergency': false,
        ..._elderUserInfoPayload(),
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/readings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Send heart alert (elder)
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
        ..._elderUserInfoPayload(),
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/heart-alert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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

  /// [elderMongoId] must be the server Elder `_id`.
  static Future<List<WatchMedicine>> getElderMedicines({
    required String elderMongoId,
    DateTime? date,
  }) async {
    try {
      final id = elderMongoId.trim();
      if (id.isEmpty) return [];
      String url = '$baseUrl/medicines';
      final queryParams = <String, String>{'elderId': id};

      if (date != null) {
        queryParams['date'] = date.toIso8601String().split('T')[0];
      }

      url += '?${Uri(queryParameters: queryParams).query}';

      final response = await _timed(http.get(Uri.parse(url)));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => WatchMedicine.fromJson(json)).toList();
      }
      if (response.statusCode == 404 || response.statusCode == 400) {
        await handleInvalidElderReference(response, id);
      }
      return [];
    } catch (e) {
      print('Error fetching elder medicines: $e');
      return [];
    }
  }

  // Update medicine status (elder - returns bool for watch UI)
  static Future<bool> updateElderMedicineStatus(String medicineId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/medicines/$medicineId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating elder medicine status: $e');
      return false;
    }
  }

  /// Staff dashboard: music analytics (metadata only; no audio URLs or files).
  static Future<MusicDashboardSummary?> getMusicDashboard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/music-sessions/dashboard'),
      );
      if (response.statusCode != 200) return null;
      return MusicDashboardSummary.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      print('Error music dashboard: $e');
      return null;
    }
  }
}

class MusicNowPlayingDto {
  final String sessionId;
  final String elderId;
  final String elderName;
  final String trackId;
  final String title;
  final String artist;
  final String category;
  final DateTime playStart;

  MusicNowPlayingDto({
    required this.sessionId,
    required this.elderId,
    required this.elderName,
    required this.trackId,
    required this.title,
    required this.artist,
    required this.category,
    required this.playStart,
  });

  factory MusicNowPlayingDto.fromJson(Map<String, dynamic> j) {
    return MusicNowPlayingDto(
      sessionId: j['sessionId'] as String? ?? '',
      elderId: j['elderId'] as String? ?? '',
      elderName: j['elderName'] as String? ?? '',
      trackId: j['trackId'] as String? ?? '',
      title: j['title'] as String? ?? '',
      artist: j['artist'] as String? ?? '',
      category: j['category'] as String? ?? '',
      playStart: DateTime.tryParse(j['playStart'] as String? ?? '') ?? DateTime.now().toUtc(),
    );
  }
}

class ElderListeningTodayDto {
  final String elderId;
  final String elderName;
  final int totalSeconds;

  ElderListeningTodayDto({
    required this.elderId,
    required this.elderName,
    required this.totalSeconds,
  });

  factory ElderListeningTodayDto.fromJson(Map<String, dynamic> j) {
    return ElderListeningTodayDto(
      elderId: j['elderId'] as String? ?? '',
      elderName: j['elderName'] as String? ?? '',
      totalSeconds: (j['totalSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class LastPlayedElderDto {
  final String elderId;
  final String elderName;
  final DateTime lastPlayedAt;
  final DateTime? lastStartedAt;
  final DateTime? lastStoppedAt;
  final String? title;
  final String? category;

  LastPlayedElderDto({
    required this.elderId,
    required this.elderName,
    required this.lastPlayedAt,
    this.lastStartedAt,
    this.lastStoppedAt,
    this.title,
    this.category,
  });

  factory LastPlayedElderDto.fromJson(Map<String, dynamic> j) {
    final startedAtRaw = j['lastStartedAt'] as String?;
    final stoppedAtRaw = j['lastStoppedAt'] as String?;
    return LastPlayedElderDto(
      elderId: j['elderId'] as String? ?? '',
      elderName: j['elderName'] as String? ?? '',
      lastPlayedAt:
          DateTime.tryParse(j['lastPlayedAt'] as String? ?? '') ?? DateTime.now().toUtc(),
      lastStartedAt: startedAtRaw == null ? null : DateTime.tryParse(startedAtRaw),
      lastStoppedAt: stoppedAtRaw == null ? null : DateTime.tryParse(stoppedAtRaw),
      title: j['title'] as String?,
      category: j['category'] as String?,
    );
  }
}

class MusicDashboardSummary {
  final DateTime generatedAt;
  final DateTime utcDayStart;
  final int activeListenersCount;
  final List<MusicNowPlayingDto> nowPlaying;
  final List<ElderListeningTodayDto> listeningTodaySecondsByElder;
  final String? mostPlayedCategory;
  final int? mostPlayedCategorySeconds;
  final List<LastPlayedElderDto> lastPlayedByElder;

  MusicDashboardSummary({
    required this.generatedAt,
    required this.utcDayStart,
    required this.activeListenersCount,
    required this.nowPlaying,
    required this.listeningTodaySecondsByElder,
    required this.mostPlayedCategory,
    required this.mostPlayedCategorySeconds,
    required this.lastPlayedByElder,
  });

  factory MusicDashboardSummary.fromJson(Map<String, dynamic> j) {
    final mpc = j['mostPlayedCategoryToday'] as Map<String, dynamic>?;
    return MusicDashboardSummary(
      generatedAt: DateTime.tryParse(j['generatedAt'] as String? ?? '') ?? DateTime.now().toUtc(),
      utcDayStart: DateTime.tryParse(j['utcDayStart'] as String? ?? '') ?? DateTime.now().toUtc(),
      activeListenersCount: (j['activeListenersCount'] as num?)?.toInt() ?? 0,
      nowPlaying: (j['nowPlaying'] as List<dynamic>? ?? [])
          .map((e) => MusicNowPlayingDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      listeningTodaySecondsByElder:
          (j['listeningTodaySecondsByElder'] as List<dynamic>? ?? [])
              .map((e) => ElderListeningTodayDto.fromJson(e as Map<String, dynamic>))
              .toList(),
      mostPlayedCategory: mpc?['category'] as String?,
      mostPlayedCategorySeconds: (mpc?['totalSeconds'] as num?)?.toInt(),
      lastPlayedByElder: (j['lastPlayedByElder'] as List<dynamic>? ?? [])
          .map((e) => LastPlayedElderDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Elder {
  final String id;
  final String name;
  final String roomNumber;
  final String age;
  final String? disease;
  final String status; // "stable" or "need_attention"
  final String gender; // "Male" or "Female"
  /// Stable watch [Reading.username] stored on server for purge of anonymous rows.
  final String? readingUsername;
  final DateTime createdAt;
  final DateTime updatedAt;

  Elder({
    required this.id,
    required this.name,
    required this.roomNumber,
    required this.age,
    this.disease,
    required this.status,
    required this.gender,
    this.readingUsername,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Elder.fromJson(Map<String, dynamic> json) {
    return Elder(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      roomNumber: json['roomNumber'] ?? '',
      age: json['age'] ?? '',
      disease: json['disease'],
      status: json['status'] ?? 'stable',
      gender: json['gender'] ?? 'Male',
      readingUsername: json['readingUsername'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }
}

class Medicine {
  final String id;
  final String? elderId;
  final String elderName;
  final String? elderRoomNumber;
  final String medicineName;
  final String dosage;
  final String time;
  final String frequency;
  final String status; // "pending", "taken", "missed"
  final DateTime? takenAt;
  final DateTime scheduledDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Medicine({
    required this.id,
    this.elderId,
    required this.elderName,
    this.elderRoomNumber,
    required this.medicineName,
    required this.dosage,
    required this.time,
    this.frequency = "daily",
    this.status = "pending",
    this.takenAt,
    required this.scheduledDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['_id'] ?? json['id'] ?? '',
      elderId: json['elderId']?.toString(),
      elderName: json['elderName'] ?? '',
      elderRoomNumber: json['elderRoomNumber'],
      medicineName: json['medicineName'] ?? '',
      dosage: json['dosage'] ?? '',
      time: json['time'] ?? '',
      frequency: json['frequency'] ?? 'daily',
      status: json['status'] ?? 'pending',
      takenAt: json['takenAt'] != null ? DateTime.parse(json['takenAt']) : null,
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'])
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }
}

class Reading {
  final String id;
  final String? elderId;
  final String username;
  final int bp;
  final int bpDiastolic;
  final int heartRate;
  final String status;
  final bool emergency;
  final bool vitalsUrgent;
  final String? alertReason;
  final DateTime timestamp;
  final String? personName;
  final String? gender;
  final String? age;
  final String? disease;
  final String? roomNumber;

  Reading({
    required this.id,
    this.elderId,
    required this.username,
    required this.bp,
    this.bpDiastolic = 0,
    required this.heartRate,
    required this.status,
    required this.emergency,
    this.vitalsUrgent = false,
    this.alertReason,
    required this.timestamp,
    this.personName,
    this.gender,
    this.age,
    this.disease,
    this.roomNumber,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: json['_id'] ?? json['id'] ?? '',
      elderId: json['elderId']?.toString(),
      username: json['username'] ?? '',
      bp: json['bp'] ?? 0,
      bpDiastolic: (json['bpDiastolic'] as num?)?.toInt() ?? 0,
      heartRate: (json['heartRate'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'normal',
      emergency: json['emergency'] ?? false,
      vitalsUrgent: json['vitalsUrgent'] ?? false,
      alertReason: json['alertReason'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      personName: json['personName'],
      gender: json['gender'],
      age: json['age'],
      disease: json['disease'],
      roomNumber: json['roomNumber'],
    );
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
