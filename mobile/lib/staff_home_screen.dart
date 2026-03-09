import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import 'elders_screen.dart';
import 'medicines_screen.dart';
import 'alerts_screen.dart';
import 'music_screen.dart';
import 'services/auto_lock_service.dart';
import 'services/analytics_service.dart';
import 'widgets/activity_tracker.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  int _currentIndex = 0;
  String? _staffName;

  @override
  void initState() {
    super.initState();
    _loadStaffName();
    // Track screen view
    AnalyticsService.logScreenView('staff_home');
  }

  @override
  void dispose() {
    AutoLockService.dispose();
    super.dispose();
  }

  Future<void> _loadStaffName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _staffName = prefs.getString('staff_name') ?? prefs.getString('staff_username');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ActivityTracker(
      child: Scaffold(
        body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(staffName: _staffName),
          EldersScreen(staffName: _staffName),
          MedicinesScreen(staffName: _staffName),
          AlertsScreen(staffName: _staffName),
          MusicScreen(staffName: _staffName),
        ],
      ),
      bottomNavigationBar: Material(
        color: const Color(0xFF17A2A2),
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Theme(
            data: Theme.of(context).copyWith(
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF17A2A2),
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.white54,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                AutoLockService.updateActivity();
                final screenNames = ['dashboard', 'elders', 'medicines', 'alerts', 'music'];
                AnalyticsService.logScreenView(screenNames[index]);
                setState(() => _currentIndex = index);
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white54,
              backgroundColor: const Color(0xFF17A2A2),
              elevation: 0,
              selectedFontSize: 13,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
              items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Elders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medication),
              label: 'Medicines',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.music_note),
              label: 'Music',
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
