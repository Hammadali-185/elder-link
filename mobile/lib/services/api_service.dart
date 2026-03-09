import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Backend API base URL - update this to match your server IP
  // For local development: http://192.168.100.112:5000/api
  // For production: replace with your actual server URL
  static const String baseUrl = 'http://192.168.100.112:5000/api';

  // Fetch all readings
  static Future<List<Reading>> getAllReadings() async {
    try {
      print('Fetching readings from: $baseUrl/readings');
      final response = await http.get(
        Uri.parse('$baseUrl/readings'),
        headers: {'Content-Type': 'application/json'},
      );

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
        headers: {'Content-Type': 'application/json'},
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
      final response = await http.get(
        Uri.parse('$baseUrl/elders'),
        headers: {'Content-Type': 'application/json'},
      );

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

  // Get medicines
  static Future<List<Medicine>> getMedicines({String? elderName, DateTime? date}) async {
    try {
      String url = '$baseUrl/medicines';
      final queryParams = <String, String>{};
      
      if (elderName != null) {
        queryParams['elderName'] = elderName;
      }
      
      if (date != null) {
        queryParams['date'] = date.toIso8601String().split('T')[0];
      }
      
      if (queryParams.isNotEmpty) {
        url += '?${Uri(queryParameters: queryParams).query}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Medicine.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load medicines: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching medicines: $e');
      throw Exception('Failed to fetch medicines: $e');
    }
  }

  // Add medicine
  static Future<Medicine> addMedicine({
    required String elderName,
    String? elderRoomNumber,
    required String medicineName,
    required String dosage,
    required String time,
    String frequency = "daily",
    required DateTime scheduledDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/medicines'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'elderName': elderName,
          'elderRoomNumber': elderRoomNumber,
          'medicineName': medicineName,
          'dosage': dosage,
          'time': time,
          'frequency': frequency,
          'scheduledDate': scheduledDate.toIso8601String(),
        }),
      );

      if (response.statusCode == 201) {
        return Medicine.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to add medicine: ${response.statusCode}');
      }
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

  // Get medicines for current elder user
  static Future<List<WatchMedicine>> getElderMedicines({DateTime? date}) async {
    try {
      String url = '$baseUrl/medicines';
      final queryParams = <String, String>{};
      
      if (elderUserName != null && elderUserName!.isNotEmpty) {
        queryParams['elderName'] = elderUserName!;
      }
      
      if (date != null) {
        queryParams['date'] = date.toIso8601String().split('T')[0];
      }
      
      if (queryParams.isNotEmpty) {
        url += '?${Uri(queryParameters: queryParams).query}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => WatchMedicine.fromJson(json)).toList();
      } else {
        return [];
      }
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
}

class Elder {
  final String id;
  final String name;
  final String roomNumber;
  final String age;
  final String? disease;
  final String status; // "stable" or "need_attention"
  final String gender; // "Male" or "Female"
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
  final String username;
  final int bp;
  final String status;
  final bool emergency;
  final DateTime timestamp;
  final String? personName;
  final String? gender;
  final String? age;
  final String? disease;
  final String? roomNumber;

  Reading({
    required this.id,
    required this.username,
    required this.bp,
    required this.status,
    required this.emergency,
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
      username: json['username'] ?? '',
      bp: json['bp'] ?? 0,
      status: json['status'] ?? 'normal',
      emergency: json['emergency'] ?? false,
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
