import 'package:shared_preferences/shared_preferences.dart';

class DataSharingService {
  static bool _enabled = false;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('privacy_data_sharing') ?? false;
  }

  static bool get enabled => _enabled;

  // Check if data can be shared
  static bool canShareData() {
    return _enabled;
  }

  // Share anonymized data (mock implementation)
  static Future<void> shareAnonymizedData(Map<String, dynamic> data) async {
    if (!_enabled) {
      print('Data sharing disabled - data not shared');
      return;
    }

    // Anonymize data (remove personal identifiers)
    final anonymized = _anonymizeData(data);
    
    // TODO: Send to research/analytics endpoint
    print('📤 Sharing anonymized data: $anonymized');
    
    // In production, send to your research/analytics API endpoint
  }

  static Map<String, dynamic> _anonymizeData(Map<String, dynamic> data) {
    final anonymized = Map<String, dynamic>.from(data);
    
    // Remove personal identifiers
    anonymized.remove('personName');
    anonymized.remove('username');
    anonymized.remove('email');
    anonymized.remove('phone');
    
    // Keep only aggregated/anonymized data
    return anonymized;
  }
}
