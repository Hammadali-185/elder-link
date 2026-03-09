import 'package:flutter/material.dart';
import 'package:elderlink/screens/home_screen.dart';
import 'package:elderlink/screens/panic_button_screen.dart';
import 'package:elderlink/screens/clock_screen.dart';
import 'package:elderlink/screens/my_info_screen.dart';
import 'package:elderlink/screens/settings_screen.dart';
import 'package:elderlink/screens/medicine_reminder_screen.dart';
import 'package:elderlink/screens/health_monitoring_screen.dart';
import 'package:elderlink/services/settings_service.dart';
import 'package:elderlink/services/api_service.dart' as watch_api;

/// Wrapper screen that displays the watch UI when user selects "Elder" mode
/// This directly uses the watch screens from the watch folder
class ElderHomeScreen extends StatefulWidget {
  const ElderHomeScreen({super.key});

  @override
  State<ElderHomeScreen> createState() => _ElderHomeScreenState();
}

class _ElderHomeScreenState extends State<ElderHomeScreen> {
  int _currentScreen = 0; // 0 = Home
  double _brightness = SettingsService.brightness;
  String _language = SettingsService.language;

  @override
  void initState() {
    super.initState();
    _initializeElderMode();
  }

  Future<void> _initializeElderMode() async {
    // Load watch settings
    await SettingsService.load();
    // Load elder user info from watch ApiService (which uses same backend)
    await watch_api.ApiService.loadSavedUserInfo();
    
    setState(() {
      _brightness = SettingsService.brightness;
      _language = SettingsService.language;
    });
  }

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop(); // Go back to join screen
          },
        ),
        title: const Text(
          'Elder Mode',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
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
    );
  }
}
