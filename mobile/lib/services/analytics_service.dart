import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsService {
  static bool _enabled = true;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('privacy_analytics') ?? true;
  }

  static bool get enabled => _enabled;

  // Log an event (mock implementation - replace with actual analytics service)
  static Future<void> logEvent(String eventName, {Map<String, dynamic>? parameters}) async {
    if (!_enabled) {
      print('Analytics disabled - event not logged: $eventName');
      return;
    }

    // TODO: Integrate with actual analytics service (Firebase Analytics, Google Analytics, etc.)
    print('📊 Analytics Event: $eventName ${parameters != null ? '- $parameters' : ''}');
    
    // In production, use:
    // - Firebase Analytics: FirebaseAnalytics.instance.logEvent(name: eventName, parameters: parameters);
    // - Google Analytics: analytics.logEvent(name: eventName, parameters: parameters);
  }

  // Log screen view
  static Future<void> logScreenView(String screenName) async {
    if (!_enabled) return;
    await logEvent('screen_view', parameters: {'screen_name': screenName});
  }
}
