import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/panic_button_screen.dart';
import 'screens/clock_screen.dart';
import 'screens/my_info_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/medicine_reminder_screen.dart';
import 'screens/health_monitoring_screen.dart';
import 'screens/audio_screen.dart';
import 'services/settings_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.load();
  await ApiService.loadSavedUserInfo();
  runApp(const WatchApp());
}

class WatchApp extends StatefulWidget {
  const WatchApp({super.key});

  @override
  State<WatchApp> createState() => _WatchAppState();
}

class _WatchAppState extends State<WatchApp> {
  int _currentScreen = 0; // 0 = Home, 7 = Panic Button
  double _brightness = SettingsService.brightness;
  String _language = SettingsService.language;

  void _navigateToScreen(int screenIndex) {
    setState(() {
      _currentScreen = screenIndex;
    });
  }

  void _goBack() {
    setState(() {
      _currentScreen = 0; // Go back to home
    });
  }

  Widget _getCurrentScreen() {
    switch (_currentScreen) {
      case 2: // Medicine
        return MedicineReminderScreen(onBackTap: _goBack);
      case 3: // Clock
        return ClockScreen(onBackTap: _goBack);
      case 4: // My Info
        return MyInfoScreen(onBackTap: _goBack);
      case 6: // Health Monitoring
        return HealthMonitoringScreen(onBackTap: _goBack);
      case 8: // Settings
        return SettingsScreen(
          onBackTap: _goBack,
          brightness: _brightness,
          language: _language,
          onBrightnessChanged: (val) async {
            await SettingsService.save(brightnessValue: val);
            setState(() {
              _brightness = SettingsService.brightness;
            });
          },
          onLanguageChanged: (val) async {
            await SettingsService.save(languageCode: val);
            setState(() {
              _language = SettingsService.language;
            });
          },
        );
      case 7: // Panic Button
        return PanicButtonScreen(onBackTap: _goBack);
      case 0: // Home
      default:
        return HomeScreen(
          onNavigateToScreen: _navigateToScreen,
          onSettingsTap: () => _navigateToScreen(8),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Watch UI',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ClipOval(
            child: SizedBox(
              width: 360,
              height: 360,
              child: Stack(
                children: [
                  _getCurrentScreen(),
                  // Brightness dimmer overlay (1.0 = no dim)
                  if (_brightness < 1.0)
                    Container(
                      color: Colors.black.withOpacity((1.0 - _brightness).clamp(0.0, 0.8)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
