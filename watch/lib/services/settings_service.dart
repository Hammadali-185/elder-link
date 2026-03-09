import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyBrightness = 'ui_brightness';
  static const _keyLanguage = 'ui_language';

  static double brightness = 1.0; // 0.0 - 1.0
  static String language = 'en'; // 'en' or 'ur'

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    brightness = prefs.getDouble(_keyBrightness) ?? 1.0;
    language = prefs.getString(_keyLanguage) ?? 'en';
  }

  static Future<void> save({
    double? brightnessValue,
    String? languageCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (brightnessValue != null) {
      brightness = brightnessValue.clamp(0.2, 1.0);
      await prefs.setDouble(_keyBrightness, brightness);
    }
    if (languageCode != null) {
      language = languageCode;
      await prefs.setString(_keyLanguage, language);
    }
  }
}
